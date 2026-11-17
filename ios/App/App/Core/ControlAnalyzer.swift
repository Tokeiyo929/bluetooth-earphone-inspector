import Foundation

/// 这台耳机「App 能控制什么」的可测试快照。
struct ControlCapabilities: Equatable {
    var volumeAvailable: Bool
    var volumeDetail: String
    var mediaTransportAvailable: Bool
    var mediaTransportDetail: String
    var noiseControlAvailable: Bool
    var noiseControlDetail: String
    var vendorWritableCount: Int
    var vendorWritableDetail: String
}

enum ControlAnalyzer {

    /// 只挑「当前链路这台」设备：先按音频端口名精确匹配，匹配不到才退到已连接设备。
    /// 避免把旁边另一副耳机的 MCS/LE Audio 能力算到当前耳机头上（演示数据里就有这种坑）。
    static func relevantPeripherals(in peripherals: [PeripheralSnapshot],
                                    routeName: String?) -> [PeripheralSnapshot] {
        if let routeName {
            let named = peripherals.filter { $0.name == routeName }
            if !named.isEmpty { return named }
        }
        let connected = peripherals.filter { $0.isSystemConnected || $0.linkState == .connected }
        return connected.isEmpty ? peripherals : connected
    }

    static func hasLEAudio(_ peripheral: PeripheralSnapshot) -> Bool {
        let fromServices = peripheral.services.contains { service in
            guard let short = BluetoothProtocolCatalog.shortUUID(service.uuid) else { return false }
            return BluetoothProtocolCatalog.leAudioServiceUUIDs.contains(short)
        }
        let fromAdvert = peripheral.advertisedServiceUUIDs.contains { uuid in
            guard let short = BluetoothProtocolCatalog.shortUUID(uuid) else { return false }
            return BluetoothProtocolCatalog.leAudioServiceUUIDs.contains(short)
        }
        return fromServices || fromAdvert
    }

    /// 找出暴露了标准 MCS 控制点（0x2BA4）的设备；没有就返回 nil。
    static func mcsPeripheral(in peripherals: [PeripheralSnapshot]) -> PeripheralSnapshot? {
        for peripheral in peripherals {
            for service in peripheral.services {
                guard let short = BluetoothProtocolCatalog.shortUUID(service.uuid),
                      short == 0x1848 || short == 0x1849 else { continue }
                if service.characteristics.contains(where: {
                    BluetoothProtocolCatalog.shortUUID($0.uuid) == 0x2BA4
                }) {
                    return peripheral
                }
            }
        }
        return nil
    }

    /// 音量永远可用（系统输出音量）；播放/降噪看设备与服务。
    static func capabilities(in peripherals: [PeripheralSnapshot]) -> ControlCapabilities {
        let mcs = mcsPeripheral(in: peripherals)
        let vendorWritable = vendorWritableCharacteristics(in: peripherals)

        return ControlCapabilities(
            volumeAvailable: true,
            volumeDetail: "系统音量滑杆；走 A2DP 时绝对音量会同步到耳机",
            mediaTransportAvailable: mcs != nil,
            mediaTransportDetail: mcs != nil
                ? "App 可直接发播放/暂停/切歌（标准 MCS 0x2BA4）"
                : "系统 AVRCP：耳机按键/锁屏可控制，App 没有公开发送 API",
            noiseControlAvailable: false,
            noiseControlDetail: "厂商私有协议（iOS 无统一 API），需厂商 App",
            vendorWritableCount: vendorWritable.count,
            vendorWritableDetail: vendorWritable.isEmpty
                ? "没有发现厂商私有可写通道"
                : "\(vendorWritable.count) 个可写特征：\(vendorWritable.prefix(2).joined(separator: "、"))"
        )
    }

    /// 厂商私有服务（128-bit）里带写权限的特征名。
    static func vendorWritableCharacteristics(in peripherals: [PeripheralSnapshot]) -> [String] {
        var names: [String] = []
        for peripheral in peripherals {
            for service in peripheral.services where BluetoothProtocolCatalog.shortUUID(service.uuid) == nil {
                for characteristic in service.characteristics {
                    let writable = characteristic.properties.contains { $0.contains("可写") }
                    guard writable else { continue }
                    let label = "\(service.name)/\(characteristic.name)"
                    if !names.contains(label) { names.append(label) }
                }
            }
        }
        return names
    }
}
