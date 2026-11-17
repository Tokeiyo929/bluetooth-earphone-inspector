import Combine
import CoreBluetooth
import Foundation

/// BLE 扫描与 GATT 读取。经典蓝牙（A2DP/HFP）不经过这里，见 AudioRouteModel。
final class BLEModel: NSObject, ObservableObject {
    @Published private(set) var peripherals: [PeripheralSnapshot] = []
    @Published private(set) var isScanning = false
    @Published private(set) var stateText = "正在准备蓝牙…"

    private var central: CBCentralManager?
    private var cbPeripherals: [String: CBPeripheral] = [:]
    private var lastBroadcast: [String: Date] = [:]
    private let isDemo: Bool

    init(demo: Bool) {
        isDemo = demo
        super.init()
    }

    func start() {
        if isDemo {
            peripherals = DemoData.peripherals()
            isScanning = true
            stateText = demoStateText
            return
        }
        central = CBCentralManager(
            delegate: self,
            queue: .main,
            options: [CBCentralManagerOptionShowPowerAlertKey: false]
        )
    }

    // MARK: - 对外操作

    var canScan: Bool {
        if isDemo { return true }
        return central?.state == .poweredOn
    }

    func peripheral(id: String) -> PeripheralSnapshot? {
        peripherals.first { $0.id == id }
    }

    private var demoStateText: String {
        let system = peripherals.filter { $0.isSystemConnected }.count
        return "演示数据 · 共 \(peripherals.count) 台，其中 \(system) 台系统已连接"
    }

    func toggleScan() {
        if isDemo {
            isScanning.toggle()
            if isScanning {
                peripherals = DemoData.peripherals()
                stateText = demoStateText
            } else {
                stateText = "演示数据 · 扫描已停止"
            }
            return
        }
        if isScanning {
            stopScan()
        } else {
            startScan()
        }
    }

    func startScan() {
        guard let central, central.state == .poweredOn else {
            stateText = "蓝牙不可用，暂时无法扫描"
            return
        }
        // 重新扫描时清掉旧的「仅发现」记录，保留已连接/系统连接的设备
        peripherals.removeAll { !$0.isSystemConnected && $0.linkState != .connected }
        isScanning = true
        stateText = "正在扫描附近的 BLE 广播…"
        central.scanForPeripherals(
            withServices: nil,
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]
        )
    }

    func stopScan() {
        central?.stopScan()
        isScanning = false
        stateText = "扫描已停止 · 共 \(peripherals.count) 台"
    }

    func connect(_ id: String) {
        guard !isDemo else { return }
        guard let central, let peripheral = cbPeripherals[id] else {
            update(id) { $0.lastError = "设备引用已失效，请重新扫描" }
            return
        }
        update(id) {
            $0.linkState = .connecting
            $0.lastError = nil
        }
        central.connect(peripheral, options: nil)
    }

    /// 系统已通过 BLE 连接的设备（例如耳机在系统里保持的 BLE 链路）。
    func refreshSystemPeripherals() {
        guard !isDemo, let central, central.state == .poweredOn else { return }
        let interested = [
            CBUUID(string: "180F"),
            CBUUID(string: "180A"),
            CBUUID(string: "184E"),
            CBUUID(string: "1850")
        ]
        let connected = central.retrieveConnectedPeripherals(withServices: interested)
        for peripheral in connected {
            cbPeripherals[peripheral.identifier.uuidString] = peripheral
            upsertSystemPeripheral(peripheral)
        }
    }

    // MARK: - 内部

    private func update(_ id: String, _ mutate: (inout PeripheralSnapshot) -> Void) {
        guard let index = peripherals.firstIndex(where: { $0.id == id }) else { return }
        var snapshot = peripherals[index]
        mutate(&snapshot)
        peripherals[index] = snapshot
    }

    private func upsertSystemPeripheral(_ peripheral: CBPeripheral) {
        let id = peripheral.identifier.uuidString
        if let index = peripherals.firstIndex(where: { $0.id == id }) {
            var snapshot = peripherals[index]
            snapshot.isSystemConnected = true
            if snapshot.name == "未知设备", let name = peripheral.name, !name.isEmpty {
                snapshot.name = name
            }
            peripherals[index] = snapshot
        } else {
            peripherals.append(PeripheralSnapshot(
                id: id,
                name: peripheral.name ?? "已连接的 BLE 设备",
                rssi: nil,
                isConnectable: true,
                advertisedServiceUUIDs: [],
                manufacturerDataHex: nil,
                appleInfo: nil,
                services: [],
                deviceInfo: [:],
                batteryPercent: nil,
                linkState: .connected,
                isSystemConnected: true,
                lastError: nil,
                isDemo: false
            ))
        }
    }

    private func recordDiscovery(_ peripheral: CBPeripheral,
                                 advertisementData: [String: Any],
                                 rssi: NSNumber) {
        let id = peripheral.identifier.uuidString
        cbPeripherals[id] = peripheral

        let localName = advertisementData[CBAdvertisementDataLocalNameKey] as? String
        let name = localName ?? peripheral.name ?? "未知设备"
        let serviceUUIDs = (advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID])?
            .map { $0.uuidString } ?? []
        let manufacturer = advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data
        let connectable = (advertisementData[CBAdvertisementDataIsConnectable] as? NSNumber)?.boolValue ?? true
        let apple = manufacturer.flatMap { AppleAdvertisement.parse($0) }
        let rssiValue = rssi.intValue

        if let index = peripherals.firstIndex(where: { $0.id == id }) {
            var snapshot = peripherals[index]
            // 高频广播（开 AllowDuplicates）时抑制无意义的 UI 抖动
            if snapshot.appleInfo == apple,
               let oldRSSI = snapshot.rssi,
               abs(oldRSSI - rssiValue) <= 2,
               let last = lastBroadcast[id],
               Date().timeIntervalSince(last) < 0.8 {
                return
            }
            if name != "未知设备" { snapshot.name = name }
            snapshot.rssi = rssiValue
            if !serviceUUIDs.isEmpty { snapshot.advertisedServiceUUIDs = serviceUUIDs }
            snapshot.manufacturerDataHex = manufacturer.map { AppleAdvertisement.hexString($0) }
            snapshot.appleInfo = apple
            snapshot.isConnectable = connectable
            peripherals[index] = snapshot
        } else {
            peripherals.append(PeripheralSnapshot(
                id: id,
                name: name,
                rssi: rssiValue,
                isConnectable: connectable,
                advertisedServiceUUIDs: serviceUUIDs,
                manufacturerDataHex: manufacturer.map { AppleAdvertisement.hexString($0) },
                appleInfo: apple,
                services: [],
                deviceInfo: [:],
                batteryPercent: nil,
                linkState: .discovered,
                isSystemConnected: false,
                lastError: nil,
                isDemo: false
            ))
        }
        lastBroadcast[id] = Date()
    }
}

// MARK: - CBCentralManagerDelegate

extension BLEModel: CBCentralManagerDelegate {

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            if CBManager.authorization == .denied {
                stateText = "蓝牙权限被拒绝：设置 → 隐私与安全性 → 蓝牙"
            } else {
                stateText = "蓝牙已就绪"
            }
            refreshSystemPeripherals()
            if isScanning {
                stateText = "正在扫描附近的 BLE 广播…"
                central.scanForPeripherals(
                    withServices: nil,
                    options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]
                )
            }
        case .poweredOff:
            stateText = "蓝牙已关闭：请在控制中心打开蓝牙"
            isScanning = false
        case .unauthorized:
            stateText = "未授权使用蓝牙：设置 → 隐私与安全性 → 蓝牙"
            isScanning = false
        case .unsupported:
            stateText = "此设备不支持 BLE（模拟器没有蓝牙硬件）"
            isScanning = false
        case .resetting:
            stateText = "蓝牙正在重置…"
        case .unknown:
            stateText = "蓝牙状态未知"
        @unknown default:
            stateText = "蓝牙状态异常"
        }
    }

    func centralManager(_ central: CBCentralManager,
                        didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any],
                        rssi RSSI: NSNumber) {
        recordDiscovery(peripheral, advertisementData: advertisementData, rssi: RSSI)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.delegate = self
        let id = peripheral.identifier.uuidString
        update(id) {
            $0.linkState = .connected
            $0.isSystemConnected = false
            $0.lastError = nil
        }
        peripheral.discoverServices(nil)
    }

    func centralManager(_ central: CBCentralManager,
                        didFailToConnect peripheral: CBPeripheral,
                        error: Error?) {
        update(peripheral.identifier.uuidString) {
            $0.linkState = .failed
            $0.lastError = error?.localizedDescription ?? "连接失败（设备可能只接受系统连接）"
        }
    }

    func centralManager(_ central: CBCentralManager,
                        didDisconnectPeripheral peripheral: CBPeripheral,
                        error: Error?) {
        update(peripheral.identifier.uuidString) {
            $0.linkState = .disconnected
            if let error { $0.lastError = error.localizedDescription }
        }
    }
}

// MARK: - CBPeripheralDelegate

extension BLEModel: CBPeripheralDelegate {

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        let id = peripheral.identifier.uuidString
        guard let services = peripheral.services else {
            if let error { update(id) { $0.lastError = error.localizedDescription } }
            return
        }
        update(id) { snapshot in
            snapshot.services = services.map { service in
                GATTServiceSnapshot(
                    uuid: service.uuid.uuidString,
                    name: BluetoothProtocolCatalog.serviceDisplayName(service.uuid.uuidString),
                    note: BluetoothProtocolCatalog.serviceNote(service.uuid.uuidString),
                    isPrimary: service.isPrimary,
                    characteristics: []
                )
            }
        }
        for service in services {
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverCharacteristicsFor service: CBService,
                    error: Error?) {
        let id = peripheral.identifier.uuidString
        guard let characteristics = service.characteristics else { return }
        update(id) { snapshot in
            guard let index = snapshot.services.firstIndex(where: { $0.uuid == service.uuid.uuidString }) else {
                return
            }
            snapshot.services[index].characteristics = characteristics.map { characteristic in
                GATTCharacteristicSnapshot(
                    uuid: characteristic.uuid.uuidString,
                    name: BluetoothProtocolCatalog.characteristicDisplayName(characteristic.uuid.uuidString),
                    properties: PeripheralAnalyzer.propertyNames(rawValue: Int(characteristic.properties.rawValue)),
                    valueText: nil,
                    valueHex: nil
                )
            }
        }
        for characteristic in characteristics {
            let uuid = characteristic.uuid.uuidString
            if PeripheralAnalyzer.shouldRead(uuid: uuid), characteristic.properties.contains(.read) {
                peripheral.readValue(for: characteristic)
            }
        }
        if let error {
            update(id) { $0.lastError = error.localizedDescription }
        }
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didUpdateValueFor characteristic: CBCharacteristic,
                    error: Error?) {
        guard let data = characteristic.value else { return }
        let id = peripheral.identifier.uuidString
        let uuid = characteristic.uuid.uuidString
        let text = PeripheralAnalyzer.decodeValue(uuid: uuid, data: data)
        let hex = AppleAdvertisement.hexString(data)

        update(id) { snapshot in
            for serviceIndex in snapshot.services.indices {
                if let charIndex = snapshot.services[serviceIndex].characteristics
                    .firstIndex(where: { $0.uuid == uuid }) {
                    snapshot.services[serviceIndex].characteristics[charIndex].valueText = text
                    snapshot.services[serviceIndex].characteristics[charIndex].valueHex = hex
                }
            }
            if let short = BluetoothProtocolCatalog.shortUUID(uuid) {
                if short == 0x2A19, let percent = data.first {
                    snapshot.batteryPercent = Int(percent)
                }
                if let pair = PeripheralAnalyzer.deviceInfoPair(uuid: uuid, data: data) {
                    snapshot.deviceInfo[pair.0.rawValue] = pair.1
                }
            }
        }
    }
}
