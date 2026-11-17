import Foundation

/// Apple「邻近配对」广播解出来的耳机状态。
/// 这是 Apple 私有格式（厂商 ID 0x004C），不是标准蓝牙协议；
/// 解析规则参考开源项目 LibrePods 对 0x07 邻近报文的拆解。
struct AppleProximityInfo: Equatable {
    var modelID: UInt16
    var modelName: String
    var paired: Bool
    var leftPercent: Int?
    var rightPercent: Int?
    var casePercent: Int?
    var leftCharging: Bool
    var rightCharging: Bool
    var caseCharging: Bool
    var leftInEar: Bool
    var rightInEar: Bool
    var lidOpen: Bool
    var colorName: String
    var connectionState: String
    var rawHex: String

    var batteryLines: [String] {
        var lines: [String] = []
        lines.append("左耳 \(AppleAdvertisement.percentText(leftPercent))\(leftCharging ? " · 充电中" : "")")
        lines.append("右耳 \(AppleAdvertisement.percentText(rightPercent))\(rightCharging ? " · 充电中" : "")")
        lines.append("充电盒 \(AppleAdvertisement.percentText(casePercent))\(caseCharging ? " · 充电中" : "")")
        return lines
    }

    var earText: String {
        if leftInEar && rightInEar { return "双耳佩戴中" }
        if leftInEar { return "仅左耳佩戴" }
        if rightInEar { return "仅右耳佩戴" }
        return "未佩戴（摘下或在盒中）"
    }
}

enum AppleAdvertisement {

    static let companyID: UInt16 = 0x004C
    static let proximityType: UInt8 = 0x07

    /// 型号 ID → 名称。ID 取自 Apple 广播，覆盖 AirPods 全系。
    static let modelNames: [UInt16: String] = [
        0x0220: "AirPods（第 1 代）",
        0x0F20: "AirPods（第 2 代）",
        0x1320: "AirPods（第 3 代）",
        0x1920: "AirPods 4",
        0x1B20: "AirPods 4（主动降噪）",
        0x0E20: "AirPods Pro",
        0x1420: "AirPods Pro 2",
        0x2420: "AirPods Pro 2（USB-C）",
        0x0A20: "AirPods Max",
        0x1F20: "AirPods Max（USB-C）"
    ]

    static let colorNames: [Int: String] = [
        0x00: "白色", 0x01: "黑色", 0x02: "红色", 0x03: "蓝色",
        0x04: "粉色", 0x05: "灰色", 0x06: "银色", 0x07: "金色",
        0x08: "玫瑰金", 0x09: "深空灰", 0x0A: "深蓝", 0x0B: "浅蓝", 0x0C: "黄色"
    ]

    static let connectionStates: [Int: String] = [
        0x00: "未连接", 0x04: "空闲", 0x05: "播放音乐", 0x06: "通话中",
        0x07: "来电响铃", 0x09: "正在挂断", 0xFF: "未知"
    ]

    /// 解析 CoreBluetooth 的 `CBAdvertisementDataManufacturerDataKey` 原始字节。
    /// iOS 交付的数据带 2 字节厂商 ID（0x4C 0x00）；也兼容不带厂商 ID 的形态。
    static func parse(_ data: Data) -> AppleProximityInfo? {
        let bytes = [UInt8](data)
        guard bytes.count >= 2 else { return nil }

        let base: Int
        if bytes[0] == 0x4C, bytes[1] == 0x00 {
            base = 2
        } else if bytes[0] == proximityType {
            base = 0
        } else {
            return nil
        }
        guard bytes.count >= base + 11, bytes[base] == proximityType else { return nil }

        // base + 1 = 报文长度；base + 2 = 是否已配对；base + 3/4 = 型号 ID
        let paired = bytes[base + 2] == 1
        let modelID = UInt16(bytes[base + 3]) << 8 | UInt16(bytes[base + 4])
        let status = bytes[base + 5]
        let podsBattery = bytes[base + 6]
        let flagsCase = bytes[base + 7]
        let lid = bytes[base + 8]
        let color = Int(bytes[base + 9])
        let connection = Int(bytes[base + 10])

        let primaryLeft = (status >> 5) & 0x01 == 1
        let thisInCase = (status >> 6) & 0x01 == 1
        let xorFactor = primaryLeft != thisInCase
        let isFlipped = !primaryLeft

        let leftInEar = xorFactor ? (status & 0x08) != 0 : (status & 0x02) != 0
        let rightInEar = xorFactor ? (status & 0x02) != 0 : (status & 0x08) != 0

        let leftNibble = isFlipped ? (podsBattery >> 4) & 0x0F : podsBattery & 0x0F
        let rightNibble = isFlipped ? podsBattery & 0x0F : (podsBattery >> 4) & 0x0F
        let caseNibble = flagsCase & 0x0F
        let chargingFlags = (flagsCase >> 4) & 0x0F

        let leftCharging = isFlipped ? (chargingFlags & 0x02) != 0 : (chargingFlags & 0x01) != 0
        let rightCharging = isFlipped ? (chargingFlags & 0x01) != 0 : (chargingFlags & 0x02) != 0
        let caseCharging = (chargingFlags & 0x04) != 0
        let lidOpen = (lid >> 3) & 0x01 == 0

        return AppleProximityInfo(
            modelID: modelID,
            modelName: modelName(modelID),
            paired: paired,
            leftPercent: decodeNibble(leftNibble),
            rightPercent: decodeNibble(rightNibble),
            casePercent: decodeNibble(caseNibble),
            leftCharging: leftCharging,
            rightCharging: rightCharging,
            caseCharging: caseCharging,
            leftInEar: leftInEar,
            rightInEar: rightInEar,
            lidOpen: lidOpen,
            colorName: colorNames[color] ?? "未知颜色",
            connectionState: connectionStates[connection] ?? "未知状态（\(connection)）",
            rawHex: hexString(bytes)
        )
    }

    /// Apple 的电量用 4 bit 表示：0…9 → 0%…90%，A…E 表示满电，F 表示未知/未放入。
    static func decodeNibble(_ value: UInt8) -> Int? {
        switch value {
        case 0...9: return Int(value) * 10
        case 0x0A...0x0E: return 100
        default: return nil
        }
    }

    static func percentText(_ percent: Int?) -> String {
        guard let percent else { return "未知" }
        return "\(percent)%"
    }

    static func modelName(_ id: UInt16) -> String {
        modelNames[id] ?? "Apple 耳机（型号 0x\(String(format: "%04X", id))）"
    }

    static func hexString(_ bytes: [UInt8]) -> String {
        bytes.map { String(format: "%02X", $0) }.joined(separator: " ")
    }

    static func hexString(_ data: Data) -> String {
        hexString([UInt8](data))
    }
}
