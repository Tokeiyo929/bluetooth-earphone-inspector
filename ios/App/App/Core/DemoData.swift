import Foundation

/// 模拟器没有蓝牙硬件，`-demo` / `-autoSmoke` 用这份拟真数据驱动界面。
/// 数据刻意做得不整齐：长名字、空名字、弱信号、不同厂商、有无 LE Audio 都有。
enum DemoData {

    // MARK: - 当前音频路由

    static func route() -> AudioRouteSnapshot {
        AudioRouteSnapshot(
            outputs: [
                RoutePortInfo(
                    name: "小明の AirPods Pro 2",
                    type: "BluetoothA2DPOutput",
                    uid: "DEMO-A2DP-1",
                    channels: 2
                )
            ],
            inputs: [
                RoutePortInfo(name: "小明の AirPods Pro 2", type: "BluetoothHFP", uid: "DEMO-HFP-1", channels: 1)
            ],
            availableInputs: [
                RoutePortInfo(name: "小明の AirPods Pro 2", type: "BluetoothHFP", uid: "DEMO-HFP-1", channels: 1),
                RoutePortInfo(name: "iPhone 麦克风", type: "BuiltInMic", uid: "DEMO-MIC-1", channels: 1)
            ]
        )
    }

    // MARK: - 附近设备

    static func peripherals() -> [PeripheralSnapshot] {
        [airPodsPro2, sonyXM5, baseusBowie30, soundcoreLiberty4NC]
    }

    /// Apple 私有邻近广播样例：0x1420 = AirPods Pro 2。
    /// 双耳佩戴、盒盖闭合、左 70% / 右 80% / 盒 90%、正在播放音乐。
    static let airPodsManufacturerHex = "4C 00 07 19 01 14 20 2A 87 09 08 00 05"

    private static let airPodsPro2: PeripheralSnapshot = {
        let manufacturer = Data([0x4C, 0x00, 0x07, 0x19, 0x01, 0x14, 0x20, 0x2A, 0x87, 0x09, 0x08, 0x00, 0x05])
        return PeripheralSnapshot(
            id: "DEMO-AP2",
            name: "小明の AirPods Pro 2",
            rssi: -52,
            isConnectable: true,
            advertisedServiceUUIDs: [
                "180A", "180F",
                "7905F431-B5CE-4E99-A40F-4B1E122D00D0",
                "89D3502B-0F36-433A-8EF4-C502AD55F8DC"
            ],
            manufacturerDataHex: AppleAdvertisement.hexString(manufacturer),
            appleInfo: AppleAdvertisement.parse(manufacturer),
            services: [
                service("180A", chars: [
                    char("2A29", properties: ["可读"], text: "Apple Inc.", hex: "41 70 70 6C 65 20 49 6E 63 2E"),
                    char("2A24", properties: ["可读"], text: "A2698"),
                    char("2A25", properties: ["可读"], text: "H2Y0G7X9JQ1P"),
                    char("2A26", properties: ["可读"], text: "6B34"),
                    char("2A27", properties: ["可读"], text: "1.0.0"),
                    char("2A28", properties: ["可读"], text: "6B34")
                ]),
                service("180F", chars: [
                    char("2A19", properties: ["可读", "通知"], text: "80%", hex: "50")
                ]),
                service("7905F431-B5CE-4E99-A40F-4B1E122D00D0", chars: [
                    char("9FBF120D-6301-42D9-8C58-25E6C34A05D1", properties: ["通知"]),
                    char("22EAC6E9-24D6-4BB5-BE44-B36ACE7C7BFB", properties: ["可写"]),
                    char("D8CAFC5B-F4C9-4E0C-A3A3-8B0B5D8F27D5", properties: ["通知"])
                ]),
                service("89D3502B-0F36-433A-8EF4-C502AD55F8DC", chars: [
                    char("2F7E18D1-9E5D-4A1D-9A8E-2F1C3C0F53C4", properties: ["可写"]),
                    char("C6B2F19E-4A5B-4D7C-9E1F-3A2B4C5D6E7F", properties: ["通知"])
                ]),
                service("74EC2172-0BAD-4D04-8EF8-9773D641530E", chars: [
                    char("74EC2173-0BAD-4D04-8EF8-9773D641530E", properties: ["可读", "通知"], hex: "01 00 00 00")
                ])
            ],
            deviceInfo: [
                DeviceInfoField.manufacturer.rawValue: "Apple Inc.",
                DeviceInfoField.model.rawValue: "A2698",
                DeviceInfoField.serial.rawValue: "H2Y0G7X9JQ1P",
                DeviceInfoField.firmware.rawValue: "6B34",
                DeviceInfoField.hardware.rawValue: "1.0.0",
                DeviceInfoField.software.rawValue: "6B34"
            ],
            batteryPercent: 80,
            linkState: .connected,
            isSystemConnected: true,
            lastError: nil,
            isDemo: true
        )
    }()

    private static let sonyXM5: PeripheralSnapshot = {
        PeripheralSnapshot(
            id: "DEMO-XM5",
            name: "WH-1000XM5",
            rssi: -61,
            isConnectable: true,
            advertisedServiceUUIDs: ["180A", "180F", "1850", "184E", "1846"],
            manufacturerDataHex: nil,
            appleInfo: nil,
            services: [
                service("180A", chars: [
                    char("2A29", properties: ["可读"], text: "Sony Corporation"),
                    char("2A24", properties: ["可读"], text: "WH-1000XM5"),
                    char("2A25", properties: ["可读"], text: "S01-6102938"),
                    char("2A26", properties: ["可读"], text: "2.1.0")
                ]),
                service("180F", chars: [
                    char("2A19", properties: ["可读", "通知"], text: "65%", hex: "41")
                ]),
                service("1850", chars: [
                    char("2BC9", properties: ["可读"], hex: "01 06 00 00 00 00 04 00 03 00 00 00"),
                    char("2BCA", properties: ["可读"], hex: "03 00 00 00"),
                    char("2BCD", properties: ["可读", "通知"], hex: "01 00")
                ]),
                service("184E", chars: [
                    char("2BC4", properties: ["可读"], hex: "01 01 00 00"),
                    char("2BC6", properties: ["可写"]),
                    char("2BC5", properties: ["可读", "通知"], hex: "01 03 00 00")
                ]),
                service("1846", chars: [
                    char("2B84", properties: ["可读"], hex: "11 22 33 44 55 66 77 88 99 AA BB CC DD EE FF 00"),
                    char("2B85", properties: ["可读"], hex: "02"),
                    char("2B87", properties: ["可读"], hex: "01")
                ]),
                service("1844", chars: [
                    char("2B7D", properties: ["通知"], hex: "64 00"),
                    char("2B7E", properties: ["可写"]),
                    char("2B7F", properties: ["可读"], hex: "00")
                ]),
                service("1848", chars: [
                    char("2B93", properties: ["可读"], text: "WH-1000XM5"),
                    char("2BA3", properties: ["通知"], hex: "00"),
                    char("2BA4", properties: ["可写"])
                ]),
                service("184B", chars: [
                    char("2B9D", properties: ["可读"], hex: "01 00 03 00")
                ])
            ],
            deviceInfo: [
                DeviceInfoField.manufacturer.rawValue: "Sony Corporation",
                DeviceInfoField.model.rawValue: "WH-1000XM5",
                DeviceInfoField.serial.rawValue: "S01-6102938",
                DeviceInfoField.firmware.rawValue: "2.1.0"
            ],
            batteryPercent: 65,
            linkState: .connected,
            isSystemConnected: false,
            lastError: nil,
            isDemo: true
        )
    }()

    private static let baseusBowie30: PeripheralSnapshot = {
        PeripheralSnapshot(
            id: "DEMO-BOWIE30",
            name: "倍思 Bowie 30（左耳）",
            rssi: -78,
            isConnectable: true,
            advertisedServiceUUIDs: ["180A", "180F", "FFE0"],
            manufacturerDataHex: nil,
            appleInfo: nil,
            services: [
                service("180A", chars: [
                    char("2A29", properties: ["可读"], text: "Baseus"),
                    char("2A24", properties: ["可读"], text: "Bowie 30"),
                    char("2A26", properties: ["可读"], text: "1.0.4")
                ]),
                service("180F", chars: [
                    char("2A19", properties: ["可读", "通知"], text: "40%", hex: "28")
                ]),
                service("FFE0", chars: [
                    char("FFE1", properties: ["可读", "可写", "通知"], hex: "A1 02 00 01")
                ])
            ],
            deviceInfo: [
                DeviceInfoField.manufacturer.rawValue: "Baseus",
                DeviceInfoField.model.rawValue: "Bowie 30",
                DeviceInfoField.firmware.rawValue: "1.0.4"
            ],
            batteryPercent: 40,
            linkState: .discovered,
            isSystemConnected: false,
            lastError: nil,
            isDemo: true
        )
    }()

    /// 长名字 + 弱信号：用来验证列表换行与截断。
    private static let soundcoreLiberty4NC: PeripheralSnapshot = {
        PeripheralSnapshot(
            id: "DEMO-L4NC",
            name: "Soundcore Liberty 4 NC · 左耳（L）",
            rssi: -89,
            isConnectable: false,
            advertisedServiceUUIDs: ["180F"],
            manufacturerDataHex: "F0 05 01 02 03",
            appleInfo: nil,
            services: [
                service("180F", chars: [
                    char("2A19", properties: ["可读"], text: "55%", hex: "37")
                ])
            ],
            deviceInfo: [:],
            batteryPercent: 55,
            linkState: .discovered,
            isSystemConnected: false,
            lastError: nil,
            isDemo: true
        )
    }()

    // MARK: - 构造小工具

    private static func service(_ uuid: String,
                                 chars: [GATTCharacteristicSnapshot],
                                 primary: Bool = true) -> GATTServiceSnapshot {
        GATTServiceSnapshot(
            uuid: uuid,
            name: BluetoothProtocolCatalog.serviceDisplayName(uuid),
            note: BluetoothProtocolCatalog.serviceNote(uuid),
            isPrimary: primary,
            characteristics: chars
        )
    }

    private static func char(_ uuid: String,
                             properties: [String],
                             text: String? = nil,
                             hex: String? = nil) -> GATTCharacteristicSnapshot {
        GATTCharacteristicSnapshot(
            uuid: uuid,
            name: BluetoothProtocolCatalog.characteristicDisplayName(uuid),
            properties: properties,
            valueText: text,
            valueHex: hex
        )
    }
}
