import Foundation

/// Bluetooth SIG 注册的厂商 ID（Company Identifier）与 USB-IF 厂商 ID 的常用子集。
/// 完整列表 4000+ 项，这里只收耳机/音频链路里会出现的方案商与品牌；
/// 未收录的 ID 在 UI 上直接显示十六进制，不硬猜。
/// 数据来源：Bluetooth SIG assigned_numbers/company_identifiers（tools/ 里可复现）。
enum CompanyIdentifiers {

    struct Vendor: Equatable {
        let name: String
        /// 中文备注，便于在 UI 上一眼认出。
        let hint: String
        /// true = 芯片/模组方案商；false = 品牌方（可能采购别家芯片）。
        let isModuleVendor: Bool

        var display: String {
            hint.isEmpty ? name : "\(name)（\(hint)）"
        }
    }

    /// Bluetooth SIG Company Identifier → 厂商。
    static let vendors: [UInt16: Vendor] = [
        0x0006: Vendor(name: "Microsoft", hint: "", isModuleVendor: false),
        0x000A: Vendor(name: "Qualcomm Technologies International", hint: "高通 / 原 CSR", isModuleVendor: true),
        0x000F: Vendor(name: "Broadcom", hint: "博通", isModuleVendor: true),
        0x001D: Vendor(name: "Qualcomm", hint: "高通", isModuleVendor: true),
        0x0046: Vendor(name: "MediaTek", hint: "联发科 / 原 Ralink", isModuleVendor: true),
        0x004C: Vendor(name: "Apple", hint: "自研", isModuleVendor: true),
        0x0057: Vendor(name: "Harman International", hint: "哈曼 / JBL 母公司", isModuleVendor: false),
        0x0059: Vendor(name: "Nordic Semiconductor", hint: "Nordic", isModuleVendor: true),
        0x005D: Vendor(name: "Realtek Semiconductor", hint: "瑞昱", isModuleVendor: true),
        0x0075: Vendor(name: "Samsung Electronics", hint: "三星", isModuleVendor: false),
        0x0094: Vendor(name: "Airoha Technology", hint: "络达", isModuleVendor: true),
        0x009E: Vendor(name: "Bose", hint: "Bose", isModuleVendor: false),
        0x00D7: Vendor(name: "Qualcomm Technologies", hint: "高通", isModuleVendor: true),
        0x00E0: Vendor(name: "Google", hint: "", isModuleVendor: false),
        0x012D: Vendor(name: "Sony", hint: "索尼", isModuleVendor: false),
        0x0211: Vendor(name: "Telink Semiconductor", hint: "泰凌微", isModuleVendor: true),
        0x02B0: Vendor(name: "Bestechnic", hint: "恒玄", isModuleVendor: true),
        0x03E0: Vendor(name: "Actions Technology", hint: "炬芯", isModuleVendor: true),
        0x05D6: Vendor(name: "Zhuhai Jieli Technology", hint: "杰理", isModuleVendor: true),
        0x05F0: Vendor(name: "Beken", hint: "博通集成", isModuleVendor: true),
        0x07E3: Vendor(name: "Airoha Technology", hint: "络达", isModuleVendor: true),
        0x0CAC: Vendor(name: "Shokz", hint: "韶音", isModuleVendor: false),
        0x0CC2: Vendor(name: "Anker Innovations", hint: "Anker / Soundcore", isModuleVendor: false),
        0x0E66: Vendor(name: "Baseus", hint: "倍思", isModuleVendor: false)
    ]

    /// USB-IF 厂商 ID（PnP ID 的来源 0x02 时使用）。
    static let usbVendors: [UInt16: Vendor] = [
        0x0A12: Vendor(name: "Cambridge Silicon Radio", hint: "高通 / 原 CSR", isModuleVendor: true)
    ]

    /// 厂商 ID 的展示文本；未收录时只给十六进制，不编名字。
    static func display(id: UInt16, source: UInt8) -> String {
        let table = source == 0x02 ? usbVendors : vendors
        if let vendor = table[id] {
            return "\(vendor.display) · 0x\(String(format: "%04X", id))"
        }
        return "未收录厂商 · 0x\(String(format: "%04X", id))"
    }

    static func vendor(id: UInt16, source: UInt8) -> Vendor? {
        (source == 0x02 ? usbVendors : vendors)[id]
    }
}
