import Foundation

/// 与 CoreBluetooth 解耦的蓝牙对象快照，UI 和测试都只吃这个结构。
enum LinkState: String, Equatable {
    case discovered
    case connecting
    case connected
    case failed
    case disconnected

    var label: String {
        switch self {
        case .discovered: return "已发现"
        case .connecting: return "连接中…"
        case .connected: return "已连接"
        case .failed: return "连接失败"
        case .disconnected: return "已断开"
        }
    }
}

struct GATTCharacteristicSnapshot: Equatable, Identifiable {
    var id: String { uuid }
    var uuid: String
    var name: String
    var properties: [String]
    var valueText: String?
    var valueHex: String?
}

struct GATTServiceSnapshot: Equatable, Identifiable {
    var id: String { uuid }
    var uuid: String
    var name: String
    var note: String?
    var isPrimary: Bool
    var characteristics: [GATTCharacteristicSnapshot]

    var leAudioRelated: Bool {
        guard let short = BluetoothProtocolCatalog.shortUUID(uuid) else { return false }
        return BluetoothProtocolCatalog.leAudioServiceUUIDs.contains(short)
    }
}

struct PeripheralSnapshot: Equatable, Identifiable {
    var id: String
    var name: String
    var rssi: Int?
    var isConnectable: Bool
    var advertisedServiceUUIDs: [String]
    var manufacturerDataHex: String?
    var appleInfo: AppleProximityInfo?
    var services: [GATTServiceSnapshot]
    var deviceInfo: [String: String]
    var batteryPercent: Int?
    var linkState: LinkState
    var isSystemConnected: Bool
    var lastError: String?
    var isDemo: Bool

    var hasAppleBroadcast: Bool { appleInfo != nil }

    /// 列表副标题：优先显示厂商/型号，其次显示广播里看到的服务。
    var subtitle: String {
        if let apple = appleInfo { return "\(apple.modelName) · Apple 私有广播" }
        if let manufacturer = deviceInfo["manufacturer"], !manufacturer.isEmpty {
            if let model = deviceInfo["model"], !model.isEmpty {
                return "\(manufacturer) · \(model)"
            }
            return manufacturer
        }
        if !advertisedServiceUUIDs.isEmpty {
            return advertisedServiceUUIDs.prefix(3)
                .map { BluetoothProtocolCatalog.serviceDisplayName($0) }
                .joined(separator: " / ")
        }
        return "广播里没有服务列表"
    }
}

/// 设备信息服务里我们主动读取的字段。
enum DeviceInfoField: String, CaseIterable {
    case manufacturer = "manufacturer"
    case model = "model"
    case serial = "serial"
    case firmware = "firmware"
    case hardware = "hardware"
    case software = "software"
    case pnp = "pnp"
    case deviceName = "deviceName"

    var title: String {
        switch self {
        case .manufacturer: return "制造商"
        case .model: return "型号"
        case .serial: return "序列号"
        case .firmware: return "固件版本"
        case .hardware: return "硬件版本"
        case .software: return "软件版本"
        case .pnp: return "PnP ID"
        case .deviceName: return "设备名称"
        }
    }

    var characteristic: UInt16 {
        switch self {
        case .manufacturer: return 0x2A29
        case .model: return 0x2A24
        case .serial: return 0x2A25
        case .firmware: return 0x2A26
        case .hardware: return 0x2A27
        case .software: return 0x2A28
        case .pnp: return 0x2A23
        case .deviceName: return 0x2A00
        }
    }

    static func field(for characteristicShortUUID: UInt16) -> DeviceInfoField? {
        allCases.first { $0.characteristic == characteristicShortUUID }
    }
}

/// 一台设备的协议画像。
struct PeripheralInsight: Equatable {
    var supportsLEAudio: Bool
    var leAudioServices: [String]
    var audioLinkGuess: String
    var protocolNames: [String]
    var vendor: String?
    var bleRole: String
    var notes: [String]
}

enum PeripheralAnalyzer {

    // MARK: - 协议画像

    static func insight(for peripheral: PeripheralSnapshot) -> PeripheralInsight {
        var allUUIDs = peripheral.services.map(\.uuid)
        allUUIDs.append(contentsOf: peripheral.advertisedServiceUUIDs)
        var seen = Set<String>()
        let uniqueUUIDs = allUUIDs.filter { uuid in
            let key = BluetoothProtocolCatalog.canonicalUUID(uuid)
            return seen.insert(key).inserted
        }

        var leAudioServices: [String] = []
        var hasFastPair = false
        var hasHID = false
        for uuid in uniqueUUIDs {
            guard let short = BluetoothProtocolCatalog.shortUUID(uuid) else { continue }
            if BluetoothProtocolCatalog.leAudioServiceUUIDs.contains(short) {
                let name = BluetoothProtocolCatalog.serviceDisplayName(uuid)
                if !leAudioServices.contains(name) { leAudioServices.append(name) }
            }
            if short == 0xFE2C { hasFastPair = true }
            if short == 0x1812 { hasHID = true }
        }

        let supportsLEAudio = !leAudioServices.isEmpty
        var protocols: [String] = ["BLE GATT"]
        protocols.append(supportsLEAudio ? "LE Audio（LC3）" : "经典蓝牙 A2DP / HFP（推测）")

        var notes: [String] = []
        if supportsLEAudio {
            notes.append("发现 \(leAudioServices.joined(separator: "、"))，音频可以走 LE Audio 的 LC3 编码。")
        } else {
            notes.append("没有发现 PACS(0x1850)/ASCS(0x184E) 这类 LE Audio 服务："
                + "音频大概率仍走经典蓝牙 A2DP/HFP，BLE 只承担控制、电量与固件升级。")
        }
        if hasFastPair {
            notes.append("广播了 Google Fast Pair（0xFE2C），安卓手机可快速配对。")
        }
        if hasHID {
            notes.append("暴露了 HID 服务：耳机按键可能以「输入设备」形式上报。")
        }
        if peripheral.hasAppleBroadcast {
            notes.append("带 Apple 私有邻近广播，可直接读出型号与左右耳/充电盒电量。")
        }
        if !peripheral.isConnectable && peripheral.linkState != .connected {
            notes.append("广播标注为不可连接，本 App 只能被动监听它的广播。")
        }
        if peripheral.services.isEmpty && peripheral.linkState == .connected {
            notes.append("已连接但服务列表为空，可能被系统或其他 App 占用了 GATT 会话。")
        }

        return PeripheralInsight(
            supportsLEAudio: supportsLEAudio,
            leAudioServices: leAudioServices,
            audioLinkGuess: supportsLEAudio
                ? "LE Audio（LC3）优先，兼容经典蓝牙"
                : "经典蓝牙 A2DP / HFP（BLE 仅用于控制）",
            protocolNames: protocols,
            vendor: vendor(for: peripheral),
            bleRole: supportsLEAudio ? "音频 + 控制通道" : "控制 / 电量通道",
            notes: notes
        )
    }

    static func vendor(for peripheral: PeripheralSnapshot) -> String? {
        if let manufacturer = peripheral.deviceInfo["manufacturer"], !manufacturer.isEmpty {
            return manufacturer
        }
        if peripheral.appleInfo != nil { return "Apple" }
        return nil
    }

    // MARK: - 特征值属性

    /// CBCharacteristicProperties.rawValue → 中文标签。
    static func propertyNames(rawValue: Int) -> [String] {
        var names: [String] = []
        if rawValue & 0x01 != 0 { names.append("广播") }
        if rawValue & 0x02 != 0 { names.append("可读") }
        if rawValue & 0x04 != 0 { names.append("可写（无响应）") }
        if rawValue & 0x08 != 0 { names.append("可写") }
        if rawValue & 0x10 != 0 { names.append("通知") }
        if rawValue & 0x20 != 0 { names.append("指示") }
        if rawValue & 0x40 != 0 { names.append("签名写") }
        if rawValue & 0x80 != 0 { names.append("扩展") }
        if rawValue & 0x100 != 0 { names.append("通知（需加密）") }
        if rawValue & 0x200 != 0 { names.append("指示（需加密）") }
        return names
    }

    // MARK: - 特征值解码

    /// 把特征值字节解成人类可读文本。未知 UUID 返回 nil，由 UI 只显示 hex。
    static func decodeValue(uuid: String, data: Data) -> String? {
        guard let short = BluetoothProtocolCatalog.shortUUID(uuid) else { return nil }
        let bytes = [UInt8](data)
        switch short {
        case 0x2A19:
            guard let first = bytes.first else { return nil }
            return "\(first)%"
        case 0x2A00, 0x2A24, 0x2A25, 0x2A26, 0x2A27, 0x2A28, 0x2A29:
            guard let text = String(data: data, encoding: .utf8) else { return nil }
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        case 0x2A23:
            guard bytes.count >= 7 else { return nil }
            let source = bytes[0]
            let vendor = UInt16(bytes[1]) | UInt16(bytes[2]) << 8
            let product = UInt16(bytes[3]) | UInt16(bytes[4]) << 8
            let version = UInt16(bytes[5]) | UInt16(bytes[6]) << 8
            return String(format: "来源 0x%02X · 厂商 0x%04X · 产品 0x%04X · 版本 %d",
                          source, vendor, product, version)
        case 0x2A01:
            guard bytes.count >= 2 else { return nil }
            let value = UInt16(bytes[0]) | UInt16(bytes[1]) << 8
            return String(format: "外观代码 0x%04X", value)
        case 0x2A05:
            return bytes.isEmpty ? nil : "服务变更标记 \(bytes.map(String.init).joined(separator: ","))"
        default:
            return nil
        }
    }

    /// 设备信息服务的特征值 → 结构化字段。
    static func deviceInfoPair(uuid: String, data: Data) -> (DeviceInfoField, String)? {
        guard let short = BluetoothProtocolCatalog.shortUUID(uuid),
              let field = DeviceInfoField.field(for: short),
              let text = decodeValue(uuid: uuid, data: data) else { return nil }
        return (field, text)
    }

    // MARK: - 信号强度

    /// RSSI（负 dBm）→ 0…4 格信号。
    static func signalBars(rssi: Int?) -> Int {
        guard let rssi else { return 0 }
        if rssi >= -55 { return 4 }
        if rssi >= -67 { return 3 }
        if rssi >= -78 { return 2 }
        if rssi >= -90 { return 1 }
        return 0
    }

    static func signalLabel(rssi: Int?) -> String {
        guard let rssi else { return "信号未知" }
        let quality: String
        switch signalBars(rssi: rssi) {
        case 4: quality = "很强"
        case 3: quality = "良好"
        case 2: quality = "一般"
        case 1: quality = "偏弱"
        default: quality = "很弱"
        }
        return "\(rssi) dBm · \(quality)"
    }

    static func batteryText(_ percent: Int?) -> String {
        guard let percent else { return "未知" }
        return "\(percent)%"
    }

    /// 判断某个特征值是否值得主动读取。
    static func shouldRead(uuid: String) -> Bool {
        guard let short = BluetoothProtocolCatalog.shortUUID(uuid) else { return false }
        if DeviceInfoField.field(for: short) != nil { return true }
        return short == 0x2A19 || short == 0x2A01
    }
}
