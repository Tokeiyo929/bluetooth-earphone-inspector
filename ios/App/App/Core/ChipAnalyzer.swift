import Foundation

/// 一条「芯片/方案商」线索：来自设备自报、PnP ID、广播厂商 ID 或私有服务。
struct ChipClue: Equatable, Identifiable {
    var id: String { source + "|" + field + "|" + value }
    var source: String
    var field: String
    var value: String
}

/// 芯片与蓝牙版本的推断结果。iOS 读不到裸片型号，这里只做「有证据的推断」。
struct ChipInsight: Equatable {
    var brand: String?
    var moduleVendor: String?
    var chipFamily: String?
    var confidence: String
    var clues: [ChipClue]
    var versionVerdict: String
    var versionEvidence: [String]
    var notes: [String]

    var hasAnyClue: Bool { !clues.isEmpty }

    var confidenceLabel: String {
        switch confidence {
        case "高": return "高置信"
        case "中": return "中置信"
        case "低": return "低置信"
        default: return "无自报"
        }
    }
}

enum ChipAnalyzer {

    // MARK: - 线索表

    /// 型号/固件字符串里常见的芯片料号 → 方案商与系列。
    /// 只认具体料号，避免把品牌名误当成芯片。
    private static let chipFamilies: [(token: String, vendor: String, family: String)] = [
        ("bes2300", "恒玄 Bestechnic", "BES2300 系列"),
        ("bes2500", "恒玄 Bestechnic", "BES2500 系列"),
        ("bes2600", "恒玄 Bestechnic", "BES2600 系列"),
        ("bes2700", "恒玄 Bestechnic", "BES2700 系列"),
        ("ab1536", "络达 Airoha", "AB1536 系列"),
        ("ab1562", "络达 Airoha", "AB1562 系列"),
        ("ab1565", "络达 Airoha", "AB1565 系列"),
        ("ab1585", "络达 Airoha", "AB1585 系列"),
        ("ab1588", "络达 Airoha", "AB1588 系列"),
        ("rtl8763", "瑞昱 Realtek", "RTL8763 系列"),
        ("rtl8773", "瑞昱 Realtek", "RTL8773 系列"),
        ("qcc3020", "高通 Qualcomm", "QCC3020"),
        ("qcc3034", "高通 Qualcomm", "QCC3034"),
        ("qcc3040", "高通 Qualcomm", "QCC3040"),
        ("qcc3050", "高通 Qualcomm", "QCC3050"),
        ("qcc3056", "高通 Qualcomm", "QCC3056"),
        ("qcc5124", "高通 Qualcomm", "QCC5124"),
        ("qcc5141", "高通 Qualcomm", "QCC5141"),
        ("qcc5171", "高通 Qualcomm", "QCC5171"),
        ("ats2831", "炬芯 Actions", "ATS2831"),
        ("ats2835", "炬芯 Actions", "ATS2835"),
        ("ats2851", "炬芯 Actions", "ATS2851"),
        ("bk3266", "博通集成 Beken", "BK3266"),
        ("bk3288", "博通集成 Beken", "BK3288"),
        ("bk3298", "博通集成 Beken", "BK3298"),
        ("ac692", "杰理 JieLi", "AC692x"),
        ("ac693", "杰理 JieLi", "AC693x"),
        ("ac695", "杰理 JieLi", "AC695x"),
        ("ac696", "杰理 JieLi", "AC696x"),
        ("ac7006", "杰理 JieLi", "AC7006"),
        ("ac701", "杰理 JieLi", "AC701x"),
        ("nrf52", "Nordic", "nRF52 系列"),
        ("nrf53", "Nordic", "nRF53 系列"),
        ("mt28", "联发科 MediaTek", "MT28xx")
    ]

    /// 厂商名关键字（设备自报字符串）。
    private static let vendorKeywords: [(token: String, vendor: String, isModule: Bool)] = [
        ("bestechnic", "恒玄 Bestechnic", true),
        ("恒玄", "恒玄 Bestechnic", true),
        ("airoha", "络达 Airoha", true),
        ("络达", "络达 Airoha", true),
        ("realtek", "瑞昱 Realtek", true),
        ("瑞昱", "瑞昱 Realtek", true),
        ("qualcomm", "高通 Qualcomm", true),
        ("cambridge silicon", "高通 Qualcomm（原 CSR）", true),
        ("高通", "高通 Qualcomm", true),
        ("nordic semiconductor", "Nordic", true),
        ("actions technology", "炬芯 Actions", true),
        ("炬芯", "炬芯 Actions", true),
        ("jieli", "杰理 JieLi", true),
        ("杰理", "杰理 JieLi", true),
        ("beken", "博通集成 Beken", true),
        ("博通集成", "博通集成 Beken", true),
        ("telink", "泰凌微 Telink", true),
        ("泰凌", "泰凌微 Telink", true),
        ("mediatek", "联发科 MediaTek", true),
        ("联发科", "联发科 MediaTek", true),
        ("apple", "Apple 自研", true),
        ("sony", "Sony（品牌）", false),
        ("bose", "Bose（品牌）", false),
        ("samsung", "Samsung（品牌）", false),
        ("baseus", "倍思 Baseus（品牌）", false),
        ("soundcore", "Soundcore（品牌）", false),
        ("anker", "Anker（品牌）", false),
        ("harman", "Harman（品牌）", false),
        ("jbl", "JBL（品牌）", false),
        ("edifier", "漫步者 Edifier（品牌）", false)
    ]

    // MARK: - 主入口

    static func insight(for peripheral: PeripheralSnapshot) -> ChipInsight {
        var clues: [ChipClue] = []
        var brand: String?
        var moduleVendor: String?
        var chipFamily: String?
        var confidence = "无"

        func addClue(_ source: String, _ field: String, _ value: String) {
            guard !value.isEmpty else { return }
            clues.append(ChipClue(source: source, field: field, value: value))
        }

        // 1. 设备信息（DIS 0x180A）
        let infoFields: [(String, DeviceInfoField)] = [
            ("制造商", .manufacturer),
            ("型号", .model),
            ("固件版本", .firmware),
            ("硬件版本", .hardware),
            ("软件版本", .software)
        ]
        for (title, field) in infoFields {
            if let value = peripheral.deviceInfo[field.rawValue], !value.isEmpty {
                addClue("设备信息 0x180A", title, value)
            }
        }

        // 2. PnP ID（0x2A23）：厂商 ID 能追到方案商
        if let pnp = peripheral.deviceInfo[DeviceInfoField.pnp.rawValue], !pnp.isEmpty {
            if let source = parsePnP(text: pnp, key: "来源 0x"),
               let vendorID = parsePnP(text: pnp, key: "厂商 0x") {
                let display = CompanyIdentifiers.display(id: vendorID, source: UInt8(source))
                addClue("PnP ID 0x2A23", "厂商 ID", display)
                if let vendor = CompanyIdentifiers.vendor(id: vendorID, source: UInt8(source)),
                   vendor.isModuleVendor {
                    if moduleVendor == nil { moduleVendor = vendor.display }
                    if confidence == "无" || confidence == "低" { confidence = "中" }
                }
            } else {
                addClue("PnP ID 0x2A23", "原始值", pnp)
            }
        }

        // 3. 广播厂商 ID（manufacturer data 前 2 字节，小端）
        if let hex = peripheral.manufacturerDataHex, let first = firstBytes(hex, count: 2) {
            let id = UInt16(first[0]) | UInt16(first[1]) << 8
            let display = CompanyIdentifiers.display(id: id, source: 0x01)
            addClue("广播厂商 ID", "0x\(String(format: "%04X", id))", display)
            if let vendor = CompanyIdentifiers.vendor(id: id, source: 0x01) {
                if vendor.isModuleVendor {
                    if moduleVendor == nil { moduleVendor = vendor.display }
                    if confidence == "无" || confidence == "低" { confidence = "中" }
                } else if brand == nil {
                    brand = vendor.display
                }
            }
        }

        // 4. 私有 128-bit 服务
        let privateServices = peripheral.services.filter {
            BluetoothProtocolCatalog.shortUUID($0.uuid) == nil
        }
        if !privateServices.isEmpty {
            let names = privateServices.prefix(2).map(\.name).joined(separator: "、")
            addClue("GATT 服务", "厂商私有服务", "\(privateServices.count) 项 · \(names)")
        }

        // 5. 从型号/固件/名称里找具体料号
        let searchText = [
            peripheral.name,
            peripheral.deviceInfo[DeviceInfoField.manufacturer.rawValue] ?? "",
            peripheral.deviceInfo[DeviceInfoField.model.rawValue] ?? "",
            peripheral.deviceInfo[DeviceInfoField.firmware.rawValue] ?? "",
            peripheral.deviceInfo[DeviceInfoField.hardware.rawValue] ?? "",
            peripheral.deviceInfo[DeviceInfoField.software.rawValue] ?? ""
        ].joined(separator: " · ").lowercased()

        for entry in chipFamilies where searchText.contains(entry.token) {
            chipFamily = "\(entry.family) · \(entry.vendor)"
            moduleVendor = entry.vendor
            confidence = "高"
            addClue("型号/固件字符串", "料号", "\(entry.token.uppercased())")
            break
        }

        // 6. 厂商名关键字
        for entry in vendorKeywords where searchText.contains(entry.token) {
            if entry.isModule {
                if moduleVendor == nil { moduleVendor = entry.vendor }
                if confidence == "无" || confidence == "低" { confidence = "中" }
            } else if brand == nil {
                brand = entry.vendor
                if confidence == "无" { confidence = "低" }
            }
        }

        // 7. Apple 私有广播：品牌可确定，芯片型号仍不可读
        if peripheral.appleInfo != nil {
            if brand == nil { brand = "Apple（私有邻近广播）" }
            if moduleVendor == nil { moduleVendor = "Apple 自研" }
            if confidence == "无" || confidence == "低" { confidence = "中" }
        }

        let version = versionInsight(for: peripheral)
        var notes: [String] = [
            "iOS 没有公开 API 读取蓝牙芯片型号。上面这些是设备自报的 GATT 信息、PnP ID 与广播厂商 ID，"
                + "能指认「方案商」，不一定能指认裸片型号。"
        ]
        if let chipFamily = chipFamily {
            notes.append("料号字符串命中：\(chipFamily)。这是目前最硬的芯片线索。")
        } else if let moduleVendor = moduleVendor {
            notes.append("推断到方案商：\(moduleVendor)。若型号/固件里出现 BES2300、AB1562、QCC3040、"
                + "RTL8763 这类料号，才能进一步指认芯片系列。")
        }
        if brand != nil, moduleVendor == nil {
            notes.append("只识别到品牌方。品牌方可能采购多家芯片，单凭厂商名不能断定芯片。")
        }
        notes.append("厂商 ID 既可能是芯片/模组厂，也可能是品牌方；App 不把品牌名硬说成芯片。")
        notes.append("商家说的「蓝牙 5.2」无法从 iPhone 系统界面直接读出；"
            + "LE Audio 是唯一能被 App 验证的 5.2 能力，没有 LE Audio 不能反证它低于 5.2。")

        return ChipInsight(
            brand: brand,
            moduleVendor: moduleVendor,
            chipFamily: chipFamily,
            confidence: confidence,
            clues: clues,
            versionVerdict: version.verdict,
            versionEvidence: version.evidence,
            notes: notes
        )
    }

    // MARK: - 版本判定

    /// 蓝牙核心规格版本不公开；LE Audio 服务是 5.2 的可验证结果。
    static func versionInsight(for peripheral: PeripheralSnapshot) -> (verdict: String, evidence: [String]) {
        var uuids = peripheral.services.map(\.uuid)
        uuids.append(contentsOf: peripheral.advertisedServiceUUIDs)
        var seen = Set<String>()
        let unique = uuids.filter { seen.insert(BluetoothProtocolCatalog.canonicalUUID($0)).inserted }

        var leAudioNames: [String] = []
        for uuid in unique {
            guard let short = BluetoothProtocolCatalog.shortUUID(uuid),
                  BluetoothProtocolCatalog.leAudioServiceUUIDs.contains(short) else { continue }
            let name = BluetoothProtocolCatalog.serviceDisplayName(uuid)
            if !leAudioNames.contains(name) { leAudioNames.append(name) }
        }

        if !leAudioNames.isEmpty {
            return (
                "至少 Bluetooth 5.2（发现 LE Audio 服务）",
                [
                    "发现 LE Audio 服务：\(leAudioNames.joined(separator: "、"))",
                    "LE Audio 由 Bluetooth 5.2 引入；设备能暴露这些服务，说明核心规格至少是 5.2",
                    "若系统音频端口同时出现 BluetoothLE，说明当前就在用 LE Audio 链路"
                ]
            )
        }
        return (
            "无法验证（没有 5.2 的硬证据）",
            [
                "iOS 不向 App 公开协商后的 Bluetooth 核心规格版本",
                "系统「设置 → 蓝牙」也只显示名称和电量，不显示 5.x 版本号",
                "这台设备没有暴露 PACS(0x1850) / ASCS(0x184E) / CSIS(0x1846) 等 LE Audio 服务",
                "很多 5.2 耳机只在经典蓝牙上跑 A2DP，所以「没证据」不等于「低于 5.2」"
            ]
        )
    }

    // MARK: - 解析小工具

    /// 从 "来源 0x01 · 厂商 0x0094 · …" 这种文本里取数值。
    static func parsePnP(text: String, key: String) -> UInt16? {
        for part in text.components(separatedBy: "·") {
            let trimmed = part.trimmingCharacters(in: .whitespaces)
            guard let range = trimmed.range(of: key) else { continue }
            let digits = String(trimmed[range.upperBound...]).trimmingCharacters(in: .whitespaces)
            return UInt16(digits, radix: 16)
        }
        return nil
    }

    /// 十六进制字节串（"4C 00 07…"）→ 前 N 个字节。
    static func firstBytes(_ hex: String, count: Int) -> [UInt8]? {
        let tokens = hex.split(whereSeparator: { $0 == " " || $0 == "\n" || $0 == "-" })
        guard tokens.count >= count else { return nil }
        var bytes: [UInt8] = []
        for token in tokens.prefix(count) {
            guard let byte = UInt8(token, radix: 16) else { return nil }
            bytes.append(byte)
        }
        return bytes
    }
}
