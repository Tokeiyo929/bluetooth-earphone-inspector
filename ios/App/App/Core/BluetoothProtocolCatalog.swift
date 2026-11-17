import Foundation

/// 音频端口的大类。判定只依赖 AVAudioSession 的端口类型字符串，
/// 不依赖 UIKit/CoreBluetooth，方便在 L1 隔离测试里覆盖。
enum AudioPortClass: String, Equatable {
    case a2dp
    case hfp
    case leAudio
    case airPlay
    case wired
    case speaker
    case receiver
    case microphone
    case other
    case none

    var isBluetooth: Bool {
        switch self {
        case .a2dp, .hfp, .leAudio: return true
        default: return false
        }
    }
}

/// 一条蓝牙音频协议的百科条目。
struct ProtocolProfile: Equatable, Identifiable {
    var id: String { code }
    let code: String
    let name: String
    let englishName: String
    let layer: String
    let usage: String
    let codec: String
    let icon: String
    let detail: String
}

/// 静态目录：音频协议、GATT 服务的中文名、常见厂商私有服务。
/// 标准 16-bit UUID 的名字来自 `GATTUUIDs.swift`（由 SIG 分配号生成）。
enum BluetoothProtocolCatalog {

    // MARK: - 音频协议

    static let profiles: [ProtocolProfile] = [
        ProtocolProfile(
            code: "A2DP",
            name: "高级音频分发协议",
            englishName: "Advanced Audio Distribution Profile",
            layer: "经典蓝牙 BR/EDR",
            usage: "音乐 / 媒体（单向高质量音频）",
            codec: "SBC / AAC；安卓侧还可协商 aptX、LDAC",
            icon: "music.note",
            detail: "蓝牙耳机听歌的主通道。把手机里的立体声音频压缩后单向推给耳机，"
                + "码率远高于通话协议。iPhone 与绝大多数耳机协商 AAC，不支持时回退 SBC。"
        ),
        ProtocolProfile(
            code: "HFP",
            name: "免提协议",
            englishName: "Hands-Free Profile",
            layer: "经典蓝牙 BR/EDR",
            usage: "通话 / 麦克风（双向语音）",
            codec: "CVSD / mSBC 语音编码",
            icon: "phone.fill",
            detail: "负责麦克风和通话。带宽窄，用来听歌会明显发闷。"
                + "来电时系统会从 A2DP 切到 HFP，挂断后再切回去。"
        ),
        ProtocolProfile(
            code: "AVRCP",
            name: "音视频遥控协议",
            englishName: "Audio/Video Remote Control Profile",
            layer: "经典蓝牙 BR/EDR",
            usage: "播放 / 暂停 / 上一首 / 音量 / 曲目信息",
            codec: "不承载音频",
            icon: "playpause.fill",
            detail: "耳机上的按键就是通过它在控制手机播放器。"
                + "它自己不传声音，只传遥控命令。"
        ),
        ProtocolProfile(
            code: "HSP",
            name: "耳机协议（老式）",
            englishName: "Headset Profile",
            layer: "经典蓝牙 BR/EDR",
            usage: "基础通话",
            codec: "CVSD",
            icon: "ear",
            detail: "比 HFP 更老的免提方案，只保证最基本的接听/挂断。"
                + "现代耳机几乎都同时支持 HFP。"
        ),
        ProtocolProfile(
            code: "SPP",
            name: "串口协议",
            englishName: "Serial Port Profile",
            layer: "经典蓝牙 BR/EDR",
            usage: "厂商 App 的控制通道（旧设备常见）",
            codec: "不承载音频",
            icon: "cable.connector",
            detail: "模拟一条串口，厂商 App 用它下发降噪、EQ 等设置。"
                + "近年的耳机更多改用 BLE GATT 承载同样的控制。"
        ),
        ProtocolProfile(
            code: "BLE GATT",
            name: "低功耗通用属性协议",
            englishName: "Generic Attribute Profile",
            layer: "低功耗 BLE",
            usage: "控制、电量、设备信息、固件升级",
            codec: "不承载音频（LE Audio 除外）",
            icon: "dot.radiowaves.left.and.right",
            detail: "BLE 设备用「服务 / 特征值」组织数据。耳机通常在这里暴露电量、"
                + "设备信息与厂商私有控制服务；LE Audio 也建立在 GATT 之上。"
        ),
        ProtocolProfile(
            code: "LE Audio",
            name: "低功耗音频",
            englishName: "LE Audio (LC3)",
            layer: "低功耗 BLE · ISO 同步通道",
            usage: "音乐 / 通话 / 广播音频 / 多耳同步",
            codec: "LC3（强制）",
            icon: "waveform.badge.plus",
            detail: "新一代蓝牙音频标准。用 LC3 编解码 + 同步通道（ISO）传输，"
                + "延迟更低、更省电，还能让左右耳真正同步，并支持广播音频。"
                + "GATT 里出现 PACS(0x1850)、ASCS(0x184E)、CSIS(0x1846) 即可判定支持。"
        )
    ]

    static func profile(for code: String) -> ProtocolProfile? {
        profiles.first { $0.code.caseInsensitiveCompare(code) == .orderedSame }
    }

    // MARK: - GATT 服务名

    /// 音频/耳机场景里最常用的服务，给中文名；其余回落到 SIG 官方英文名。
    static let serviceNamesZH: [UInt16: String] = [
        0x1800: "通用访问（GAP）",
        0x1801: "通用属性（GATT）",
        0x180A: "设备信息",
        0x180F: "电池",
        0x1812: "人机接口（HID）",
        0x181A: "环境感知",
        0x1843: "音频输入控制（AICS）",
        0x1844: "音量控制（VCS）",
        0x1845: "音量偏移控制（VOCS）",
        0x1846: "协调集识别（CSIS，左右耳同步）",
        0x1848: "媒体控制（MCS）",
        0x1849: "通用媒体控制（GMCS）",
        0x184B: "电话承载（TBS）",
        0x184C: "通用电话承载（GTBS）",
        0x184D: "麦克风控制（MICS）",
        0x184E: "音频流控制（ASCS）",
        0x184F: "广播音频扫描（BASS）",
        0x1850: "已发布音频能力（PACS / LC3）",
        0x1851: "基础音频公告",
        0x1852: "广播音频公告",
        0x1853: "通用音频（CAS）",
        0x1854: "助听器接入（HAS）",
        0x1855: "电话与媒体音频（TMAS）",
        0x1858: "游戏音频（GMAS）",
        0xFE2C: "Google Fast Pair（快速配对）",
        0xFE59: "Nordic 安全 DFU（固件升级）"
    ]

    /// 耳机里常见的厂商私有服务（128-bit）。
    static let vendorServiceNames: [String: String] = [
        "7905F431-B5CE-4E99-A40F-4B1E122D00D0": "Apple 通知中心（ANCS）",
        "89D3502B-0F36-433A-8EF4-C502AD55F8DC": "Apple 媒体服务（AMS）",
        "DF21FE2C-2515-4FDB-9D62-7A3F06C401E8": "Sony 耳机控制"
    ]

    /// 判定 LE Audio 支持的关键服务（PACS/ASCS/CSIS/CAS/TMAS）。
    static let leAudioServiceUUIDs: Set<UInt16> = [
        0x1846, 0x184E, 0x1850, 0x1853, 0x1855, 0x1858
    ]

    /// 用来判定「控制类」服务的 UUID，用于给用户解释 BLE 在做什么。
    static let controlServiceUUIDs: Set<UInt16> = [
        0x180F, 0x1812, 0x1844, 0x1848, 0x1849, 0x184B, 0x184C, 0x184D, 0x184E, 0x1850
    ]

    static let characteristicNamesZH: [UInt16: String] = [
        0x2A00: "设备名称",
        0x2A01: "外观",
        0x2A04: "首选连接参数",
        0x2A05: "服务变更",
        0x2A19: "电池电量",
        0x2A23: "PnP ID（厂商/产品编号）",
        0x2A24: "型号",
        0x2A25: "序列号",
        0x2A26: "固件版本",
        0x2A27: "硬件版本",
        0x2A28: "软件版本",
        0x2A29: "制造商",
        0x2A2A: "IEEE 认证数据"
    ]

    // MARK: - UUID 工具

    /// 把 CBUUID 的短格式（"180F"）补成标准 128-bit 字符串。
    static func canonicalUUID(_ uuid: String) -> String {
        let upper = uuid.uppercased()
        if upper.count == 4 {
            return "0000\(upper)-0000-1000-8000-00805F9B34FB"
        }
        if upper.count == 8 {
            return "\(upper)-0000-1000-8000-00805F9B34FB"
        }
        return upper
    }

    /// 标准 16-bit UUID → 数值；128-bit 厂商 UUID 返回 nil。
    static func shortUUID(_ uuid: String) -> UInt16? {
        let canonical = canonicalUUID(uuid)
        let suffix = "-0000-1000-8000-00805F9B34FB"
        guard canonical.count == 36, canonical.hasSuffix(suffix) else { return nil }
        let head = canonical.prefix(8)
        guard head.hasPrefix("0000") else { return nil }
        return UInt16(head.dropFirst(4), radix: 16)
    }

    /// 服务名的展示文本：中文优先，其次 SIG 英文名，最后标注私有/未知。
    static func serviceDisplayName(_ uuid: String) -> String {
        if let short = shortUUID(uuid) {
            if let zh = serviceNamesZH[short] { return zh }
            if let official = GATTUUIDs.serviceNames[short] { return official }
            return "未收录的 16-bit 服务（0x\(String(format: "%04X", short))）"
        }
        if let vendor = vendorServiceNames[canonicalUUID(uuid)] { return vendor }
        return "厂商私有服务"
    }

    static func serviceNote(_ uuid: String) -> String? {
        guard let short = shortUUID(uuid) else {
            return vendorServiceNames[canonicalUUID(uuid)] == nil ? "128-bit 自定义服务，通常是厂商 App 的控制通道" : nil
        }
        switch short {
        case 0x180A: return "型号、固件、序列号等身份信息"
        case 0x180F: return "电量百分比，可读 0x2A19"
        case 0x1812: return "把按键/滚轮伪装成输入设备"
        case 0x1846: return "左右耳协调集，LE Audio 多耳同步的基础"
        case 0x184E: return "LE Audio 音频流的端点（ASE）"
        case 0x1850: return "LE Audio 编解码能力（PAC），支持即说明可用 LC3"
        case 0x1844, 0x1845: return "LE Audio 音量控制"
        case 0x1848, 0x1849: return "LE Audio 媒体播放控制"
        case 0x184B, 0x184C: return "LE Audio 通话承载"
        case 0x1853: return "LE Audio 通用音频服务"
        case 0xFE2C: return "安卓体系的快速配对广播"
        default: return nil
        }
    }

    static func characteristicDisplayName(_ uuid: String) -> String {
        if let short = shortUUID(uuid) {
            if let zh = characteristicNamesZH[short] { return zh }
            if let official = GATTUUIDs.characteristicNames[short] { return official }
            return "未收录特征值（0x\(String(format: "%04X", short))）"
        }
        return "厂商私有特征值"
    }

    /// 端口类型字符串 → 中文标签。
    static func portTypeLabel(_ raw: String) -> String {
        if raw.localizedCaseInsensitiveContains("BluetoothA2DP") { return "蓝牙 A2DP（经典蓝牙音频）" }
        if raw.localizedCaseInsensitiveContains("BluetoothHFP") { return "蓝牙 HFP（免提/通话）" }
        if raw.localizedCaseInsensitiveContains("BluetoothLE") { return "蓝牙 LE 音频" }
        if raw == "Speaker" { return "内置扬声器" }
        if raw == "Receiver" { return "听筒" }
        if raw == "Headphones" { return "有线耳机 / 耳机口" }
        if raw == "HeadsetMic" { return "有线耳机麦克风" }
        if raw == "BuiltInMic" { return "机身麦克风" }
        if raw == "AirPlay" { return "AirPlay" }
        if raw == "USBAudio" { return "USB 音频" }
        if raw == "CarAudio" { return "车载音频" }
        if raw == "HDMI" { return "HDMI" }
        if raw == "LineOut" { return "线路输出" }
        return raw.isEmpty ? "未知端口" : raw
    }
}
