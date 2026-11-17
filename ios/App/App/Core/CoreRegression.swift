import Foundation

/// 纯逻辑回归：被 `tests/CoreTests.swift`（L1 swiftc 隔离）与 App 内 `-autoTest` 共用。
enum CoreRegression {

    struct Result {
        let name: String
        let passed: Bool
        let detail: String
    }

    static func run() -> [Result] {
        var results: [Result] = []
        func check(_ name: String, _ body: () throws -> Void) {
            do {
                try body()
                results.append(Result(name: name, passed: true, detail: ""))
            } catch {
                results.append(Result(name: name, passed: false, detail: error.localizedDescription))
            }
        }
        func require(_ condition: Bool, _ message: @autoclosure () -> String) throws {
            guard condition else {
                throw NSError(domain: "CoreRegression", code: 1,
                              userInfo: [NSLocalizedDescriptionKey: message()])
            }
        }
        func snapshot(outputType: String,
                      outputName: String = "测试耳机",
                      inputType: String? = nil,
                      availableInputTypes: [String] = []) -> AudioRouteSnapshot {
            var inputs: [RoutePortInfo] = []
            if let inputType {
                inputs = [RoutePortInfo(name: "测试耳机", type: inputType, uid: "in", channels: 1)]
            }
            return AudioRouteSnapshot(
                outputs: [RoutePortInfo(name: outputName, type: outputType, uid: "out", channels: 2)],
                inputs: inputs,
                availableInputs: availableInputTypes.map {
                    RoutePortInfo(name: "可用输入", type: $0, uid: "avail", channels: 1)
                }
            )
        }

        func testPeripheral(deviceInfo: [String: String] = [:],
                            advertised: [String] = [],
                            manufacturerHex: String? = nil,
                            name: String = "测试耳机") -> PeripheralSnapshot {
            PeripheralSnapshot(
                id: "TEST",
                name: name,
                rssi: -50,
                isConnectable: true,
                advertisedServiceUUIDs: advertised,
                manufacturerDataHex: manufacturerHex,
                appleInfo: nil,
                services: [],
                deviceInfo: deviceInfo,
                batteryPercent: nil,
                linkState: .discovered,
                isSystemConnected: false,
                lastError: nil,
                isDemo: true
            )
        }

        // MARK: UUID 规整

        check("UUID: 4 位短码补全成标准 128-bit") {
            try require(BluetoothProtocolCatalog.canonicalUUID("180f")
                        == "0000180F-0000-1000-8000-00805F9B34FB",
                        "得到 \(BluetoothProtocolCatalog.canonicalUUID("180f"))")
        }
        check("UUID: 8 位十六进制补全") {
            try require(BluetoothProtocolCatalog.canonicalUUID("0000180A")
                        == "0000180A-0000-1000-8000-00805F9B34FB",
                        "得到 \(BluetoothProtocolCatalog.canonicalUUID("0000180A"))")
        }
        check("UUID: 短码与完整串都解析出 16-bit 值") {
            try require(BluetoothProtocolCatalog.shortUUID("1850") == 0x1850, "短码失败")
            try require(BluetoothProtocolCatalog.shortUUID("0000184E-0000-1000-8000-00805F9B34FB") == 0x184E,
                        "完整串失败")
        }
        check("UUID: 128-bit 厂商 UUID 返回 nil") {
            try require(BluetoothProtocolCatalog.shortUUID("DF21FE2C-2515-4FDB-9D62-7A3F06C401E8") == nil,
                        "厂商 UUID 不应解析成 16-bit")
        }

        // MARK: 服务名

        check("服务名: 常用耳机服务有中文名") {
            try require(BluetoothProtocolCatalog.serviceDisplayName("180F") == "电池", "180F")
            try require(BluetoothProtocolCatalog.serviceDisplayName("184E").contains("音频流控制"), "184E")
            try require(BluetoothProtocolCatalog.serviceDisplayName("1850").contains("PACS"), "1850")
        }
        check("服务名: 未收录的 16-bit 服务给出明确标注") {
            try require(BluetoothProtocolCatalog.serviceDisplayName("FFE0").contains("未收录"), "FFE0")
        }
        check("服务名: 未知 128-bit 标为厂商私有，已知厂商有名字") {
            try require(BluetoothProtocolCatalog.serviceDisplayName("DEADBEEF-0000-0000-0000-000000000000")
                        == "厂商私有服务", "未知 UUID")
            try require(BluetoothProtocolCatalog.serviceDisplayName("7905F431-B5CE-4E99-A40F-4B1E122D00D0")
                        .contains("ANCS"), "ANCS")
        }
        check("服务说明: LE Audio 关键服务都有解释") {
            try require(BluetoothProtocolCatalog.serviceNote("1850") != nil, "1850")
            try require(BluetoothProtocolCatalog.serviceNote("184E") != nil, "184E")
            try require(BluetoothProtocolCatalog.serviceNote("1846") != nil, "1846")
        }

        // MARK: Apple 广播

        check("Apple 广播: 型号与三段电量") {
            guard let data = DemoData.peripherals().first(where: { $0.hasAppleBroadcast })?.appleInfo else {
                try require(false, "演示数据里没有 Apple 设备")
                return
            }
            try require(data.modelID == 0x1420, "型号 ID 得到 \(String(format: "%04X", data.modelID))")
            try require(data.modelName.contains("AirPods Pro 2"), "得到 \(data.modelName)")
            try require(data.leftPercent == 70, "左耳 \(String(describing: data.leftPercent))")
            try require(data.rightPercent == 80, "右耳 \(String(describing: data.rightPercent))")
            try require(data.casePercent == 90, "盒 \(String(describing: data.casePercent))")
            try require(data.connectionState == "播放音乐", "得到 \(data.connectionState)")
            try require(data.colorName == "白色", "得到 \(data.colorName)")
            try require(!data.lidOpen, "0x08 的 lid 字节应判为盒盖闭合")
            try require(data.leftInEar && data.rightInEar, "双耳佩戴")
            try require(!data.leftCharging && !data.rightCharging && !data.caseCharging, "不应在充电")
        }
        check("Apple 广播: 不带厂商 ID 前缀也能解析") {
            let raw = Data([0x4C, 0x00, 0x07, 0x19, 0x01, 0x14, 0x20, 0x2A, 0x87, 0x09, 0x08, 0x00, 0x05])
            let noCompany = raw.dropFirst(2)
            guard let info = AppleAdvertisement.parse(Data(noCompany)) else {
                try require(false, "去前缀后解析失败")
                return
            }
            try require(info.modelID == 0x1420, "型号 ID 得到 \(info.modelID)")
            try require(info.leftPercent == 70, "左耳 \(String(describing: info.leftPercent))")
        }
        check("Apple 广播: 非 Apple 厂商数据返回 nil") {
            try require(AppleAdvertisement.parse(Data([0x59, 0x00, 0x01, 0x02, 0x03, 0x04, 0x05,
                                                       0x06, 0x07, 0x08, 0x09, 0x0A, 0x0B])) == nil,
                        "Nordic 厂商数据不应解析成 Apple")
        }
        check("Apple 广播: 字节不足返回 nil") {
            try require(AppleAdvertisement.parse(Data([0x4C, 0x00, 0x07, 0x19])) == nil, "太短应返回 nil")
        }
        check("Apple 电量: nibble 边界") {
            try require(AppleAdvertisement.decodeNibble(0) == 0, "0 → 0")
            try require(AppleAdvertisement.decodeNibble(9) == 90, "9 → 90")
            try require(AppleAdvertisement.decodeNibble(0x0A) == 100, "A → 100")
            try require(AppleAdvertisement.decodeNibble(0x0E) == 100, "E → 100")
            try require(AppleAdvertisement.decodeNibble(0x0F) == nil, "F → nil")
        }
        check("Apple 型号: 未知 ID 有兜底文案") {
            try require(AppleAdvertisement.modelName(0x9999).contains("0x9999"), "兜底文案")
        }

        // MARK: 路由判定

        check("端口分类: 四种蓝牙端口") {
            try require(RouteAnalyzer.classify(typeRaw: "BluetoothA2DPOutput") == .a2dp, "A2DP")
            try require(RouteAnalyzer.classify(typeRaw: "BluetoothHFP") == .hfp, "HFP")
            try require(RouteAnalyzer.classify(typeRaw: "BluetoothLE") == .leAudio, "LE")
            try require(RouteAnalyzer.classify(typeRaw: "BluetoothA2DP").isBluetooth, "isBluetooth")
        }
        check("端口分类: 非蓝牙端口") {
            try require(RouteAnalyzer.classify(typeRaw: "Speaker") == .speaker, "Speaker")
            try require(RouteAnalyzer.classify(typeRaw: "Headphones") == .wired, "Headphones")
            try require(RouteAnalyzer.classify(typeRaw: "") == .none, "空串")
            try require(!RouteAnalyzer.classify(typeRaw: "Speaker").isBluetooth, "扬声器不应算蓝牙")
        }
        check("结论: A2DP 音乐链路 + HFP 麦克风") {
            let verdict = RouteAnalyzer.verdict(for: snapshot(
                outputType: "BluetoothA2DPOutput",
                inputType: "BluetoothHFP",
                availableInputTypes: ["BluetoothHFP", "BuiltInMic"]
            ))
            try require(verdict.profileCode == "A2DP", "得到 \(verdict.profileCode)")
            try require(verdict.tone == "a2dp", "色调 \(verdict.tone)")
            try require(verdict.isBluetoothActive, "应判定为蓝牙链路")
            try require(verdict.evidence.joined().contains("HFP"), "证据里应提到麦克风")
            try require(verdict.codecNote.contains("AAC"), "编解码提示应提到 AAC")
        }
        check("结论: 只有 HFP 输出时判为通话链路") {
            let verdict = RouteAnalyzer.verdict(for: snapshot(outputType: "BluetoothHFP"))
            try require(verdict.profileCode == "HFP", "得到 \(verdict.profileCode)")
            try require(verdict.summary.contains("语音带宽"), "文案应解释音质变差")
        }
        check("结论: LE Audio 输出") {
            let verdict = RouteAnalyzer.verdict(for: snapshot(outputType: "BluetoothLE"))
            try require(verdict.profileCode == "LE Audio", "得到 \(verdict.profileCode)")
            try require(verdict.codecNote.contains("LC3"), "编解码提示应提到 LC3")
        }
        check("结论: 没有蓝牙输出时给出中性提示") {
            let verdict = RouteAnalyzer.verdict(for: snapshot(outputType: "Speaker"))
            try require(!verdict.isBluetoothActive, "不应判定为蓝牙")
            try require(verdict.profileCode == "—", "得到 \(verdict.profileCode)")
            try require(verdict.summary.contains("回到本页"), "应提示用户刷新")
        }
        check("结论: 演示数据走 A2DP") {
            let verdict = RouteAnalyzer.verdict(for: DemoData.route())
            try require(verdict.profileCode == "A2DP", "得到 \(verdict.profileCode)")
            try require(verdict.title.contains("A2DP"), "标题 \(verdict.title)")
        }
        check("路由明细: 包含输出/输入/可用输入") {
            let rows = RouteAnalyzer.detailRows(DemoData.route())
            let keys = rows.map { $0.0 }
            try require(keys.contains("输出端口"), "缺输出端口")
            try require(keys.contains("输入端口"), "缺输入端口")
            try require(keys.contains("可用输入"), "缺可用输入")
            try require(rows.map { $0.1 }.joined().contains("BluetoothA2DPOutput"), "缺端口类型原文")
        }

        // MARK: 芯片与版本线索

        check("芯片: 广播厂商 ID 0x05F0 → Beken") {
            guard let liberty = DemoData.peripherals().first(where: { $0.id == "DEMO-L4NC" }) else {
                try require(false, "缺 Liberty 演示设备")
                return
            }
            let insight = ChipAnalyzer.insight(for: liberty)
            try require(insight.moduleVendor?.contains("Beken") == true,
                        "得到 \(String(describing: insight.moduleVendor))")
            try require(insight.clues.contains { $0.value.contains("Beken") }, "线索里应有厂商名")
        }
        check("芯片: 料号 BES2500 → 恒玄 BES2500 系列") {
            let peripheral = testPeripheral(deviceInfo: [DeviceInfoField.firmware.rawValue: "BES2500YP"])
            let insight = ChipAnalyzer.insight(for: peripheral)
            try require(insight.chipFamily?.contains("BES2500") == true,
                        "得到 \(String(describing: insight.chipFamily))")
            try require(insight.confidence == "高", "置信 \(insight.confidence)")
        }
        check("芯片: 料号 AB1562 → 络达") {
            let peripheral = testPeripheral(deviceInfo: [DeviceInfoField.model.rawValue: "AB1562M"])
            let insight = ChipAnalyzer.insight(for: peripheral)
            try require(insight.chipFamily?.contains("AB1562") == true,
                        "得到 \(String(describing: insight.chipFamily))")
        }
        check("芯片: PnP 厂商 0x0094 → 络达") {
            let pnp = "来源 0x01 · 厂商 0x0094 · 产品 0x0001 · 版本 1"
            let peripheral = testPeripheral(deviceInfo: [DeviceInfoField.pnp.rawValue: pnp])
            let insight = ChipAnalyzer.insight(for: peripheral)
            try require(insight.moduleVendor?.contains("Airoha") == true,
                        "得到 \(String(describing: insight.moduleVendor))")
        }
        check("芯片: 品牌名不冒充芯片") {
            guard let sony = DemoData.peripherals().first(where: { $0.id == "DEMO-XM5" }) else {
                try require(false, "缺 Sony 演示设备")
                return
            }
            let insight = ChipAnalyzer.insight(for: sony)
            try require(insight.brand?.contains("Sony") == true,
                        "得到 \(String(describing: insight.brand))")
            try require(insight.moduleVendor == nil, "Sony 只是品牌名，不应推断出方案商")
        }
        check("版本: LE Audio 服务 → 至少 5.2") {
            guard let sony = DemoData.peripherals().first(where: { $0.id == "DEMO-XM5" }) else {
                try require(false, "缺 Sony 演示设备")
                return
            }
            let insight = ChipAnalyzer.insight(for: sony)
            try require(insight.versionVerdict.contains("5.2"), "得到 \(insight.versionVerdict)")
        }
        check("版本: 没有 LE Audio → 无法验证 5.2") {
            guard let baseus = DemoData.peripherals().first(where: { $0.id == "DEMO-BOWIE30" }) else {
                try require(false, "缺倍思演示设备")
                return
            }
            let insight = ChipAnalyzer.insight(for: baseus)
            try require(insight.versionVerdict.contains("无法验证"), "得到 \(insight.versionVerdict)")
            try require(insight.versionEvidence.joined().contains("不等于"), "应说明没证据不等于低于 5.2")
        }
        check("线索解析: PnP 文本 / 广播字节") {
            try require(ChipAnalyzer.parsePnP(text: "来源 0x02 · 厂商 0x0A12", key: "厂商 0x") == 0x0A12,
                        "PnP 厂商解析")
            try require(ChipAnalyzer.parsePnP(text: "来源 0x02 · 厂商 0x0A12", key: "来源 0x") == 0x02,
                        "PnP 来源解析")
            try require(ChipAnalyzer.firstBytes("F0 05 01", count: 2) == [0xF0, 0x05], "广播字节解析")
            try require(ChipAnalyzer.firstBytes("F0", count: 2) == nil, "字节不足应返回 nil")
        }

        // MARK: 当前链路页：版本卡 + 控制台

        check("版本卡: A2DP 且无 LE Audio → 未验证") {
            let hint = VersionAnalyzer.hint(for: DemoData.route(), leAudioOverBLE: false)
            try require(!hint.verified, "不应判定为已验证")
            try require(hint.badge == "未验证", "得到 \(hint.badge)")
            try require(hint.evidence.joined().contains("不等于"), "应说明没证据不等于低于 5.2")
        }
        check("版本卡: LE Audio 端口 → ≥5.2") {
            let hint = VersionAnalyzer.hint(for: snapshot(outputType: "BluetoothLE"), leAudioOverBLE: false)
            try require(hint.verified, "LE Audio 端口应确认 5.2")
            try require(hint.badge == "≥5.2", "得到 \(hint.badge)")
        }
        check("版本卡: BLE 侧发现 LE Audio 服务也能确认") {
            let hint = VersionAnalyzer.hint(for: DemoData.route(), leAudioOverBLE: true)
            try require(hint.verified, "BLE 侧证据应采信")
            try require(hint.title.contains("5.2"), "标题 \(hint.title)")
        }
        check("控制台: 音量恒可用") {
            let capabilities = ControlAnalyzer.capabilities(in: DemoData.peripherals())
            try require(capabilities.volumeAvailable, "音量应可用")
        }
        check("控制台: 只认当前链路这台设备") {
            let airpodsRelevant = ControlAnalyzer.relevantPeripherals(
                in: DemoData.peripherals(),
                routeName: "小明の AirPods Pro 2"
            )
            try require(airpodsRelevant.count == 1, "应只返回 1 台")
            try require(airpodsRelevant[0].hasAppleBroadcast, "应命中 AirPods")
            try require(ControlAnalyzer.mcsPeripheral(in: airpodsRelevant) == nil,
                        "AirPods 不能借用旁边 Sony 的 MCS")
            try require(!ControlAnalyzer.hasLEAudio(airpodsRelevant[0]),
                        "AirPods 演示数据没有 LE Audio")

            let sonyRelevant = ControlAnalyzer.relevantPeripherals(
                in: DemoData.peripherals(),
                routeName: "WH-1000XM5"
            )
            try require(sonyRelevant.count == 1 && sonyRelevant[0].id == "DEMO-XM5", "应命中 Sony")
            try require(ControlAnalyzer.hasLEAudio(sonyRelevant[0]), "Sony 应有 LE Audio 证据")
            try require(ControlAnalyzer.mcsPeripheral(in: sonyRelevant) != nil, "Sony 应有 MCS")
        }
        check("控制台: Sony 暴露 MCS → 播放可直控") {
            try require(ControlAnalyzer.mcsPeripheral(in: DemoData.peripherals())?.id == "DEMO-XM5",
                        "应找到 Sony 的 MCS")
            let capabilities = ControlAnalyzer.capabilities(in: DemoData.peripherals())
            try require(capabilities.mediaTransportAvailable, "MCS 存在时应可直控")
        }
        check("控制台: 只有 AirPods 时没有 MCS") {
            guard let airpods = DemoData.peripherals().first(where: { $0.hasAppleBroadcast }) else {
                try require(false, "缺 AirPods 演示设备")
                return
            }
            let capabilities = ControlAnalyzer.capabilities(in: [airpods])
            try require(!capabilities.mediaTransportAvailable, "Apple 演示设备不应有 MCS")
            try require(capabilities.mediaTransportDetail.contains("AVRCP"), "应说明走系统 AVRCP")
        }
        check("控制台: 厂商私有可写通道有计数") {
            let capabilities = ControlAnalyzer.capabilities(in: DemoData.peripherals())
            try require(capabilities.vendorWritableCount > 0, "AirPods 私有服务应统计出可写特征")
            try require(!capabilities.noiseControlAvailable, "降噪不应假装可直控")
        }

        // MARK: 特征值解码

        check("解码: 电池 2A19") {
            try require(PeripheralAnalyzer.decodeValue(uuid: "2A19", data: Data([0x41])) == "65%", "41 → 65%")
        }
        check("解码: 设备信息字符串 2A29/2A24") {
            try require(PeripheralAnalyzer.decodeValue(uuid: "2A29",
                                                       data: Data("Sony Corporation".utf8)) == "Sony Corporation",
                        "2A29")
            try require(PeripheralAnalyzer.decodeValue(uuid: "2A24",
                                                       data: Data(" WH-1000XM5 \n".utf8)) == "WH-1000XM5",
                        "2A24 应去掉首尾空白")
        }
        check("解码: PnP ID 2A23") {
            let text = PeripheralAnalyzer.decodeValue(
                uuid: "2A23",
                data: Data([0x01, 0x4C, 0x00, 0x20, 0x14, 0x02, 0x00])
            )
            try require(text?.contains("厂商 0x004C") == true, "得到 \(String(describing: text))")
            try require(text?.contains("产品 0x1420") == true, "得到 \(String(describing: text))")
        }
        check("解码: 未知 UUID 返回 nil，让 UI 只显示 hex") {
            try require(PeripheralAnalyzer.decodeValue(uuid: "FFE1", data: Data([0x01])) == nil, "FFE1")
        }
        check("解码: 设备信息字段映射") {
            let pair = PeripheralAnalyzer.deviceInfoPair(uuid: "2A26", data: Data("2.1.0".utf8))
            try require(pair?.0 == .firmware, "得到 \(String(describing: pair?.0))")
            try require(pair?.1 == "2.1.0", "得到 \(String(describing: pair?.1))")
        }
        check("特征值属性: 位掩码 → 中文") {
            let names = PeripheralAnalyzer.propertyNames(rawValue: 0x02 | 0x08 | 0x10)
            try require(names == ["可读", "可写", "通知"], "得到 \(names)")
            try require(PeripheralAnalyzer.propertyNames(rawValue: 0x100).contains { $0.contains("需加密") },
                        "加密通知")
        }
        check("属性: 只主动读设备信息/电池/外观") {
            try require(PeripheralAnalyzer.shouldRead(uuid: "2A19"), "2A19")
            try require(PeripheralAnalyzer.shouldRead(uuid: "2A29"), "2A29")
            try require(!PeripheralAnalyzer.shouldRead(uuid: "2B93"), "2B93 不应读")
        }

        // MARK: 协议画像

        check("画像: Sony 演示设备支持 LE Audio") {
            guard let sony = DemoData.peripherals().first(where: { $0.id == "DEMO-XM5" }) else {
                try require(false, "缺 Sony 演示设备")
                return
            }
            let insight = PeripheralAnalyzer.insight(for: sony)
            try require(insight.supportsLEAudio, "应支持 LE Audio")
            try require(insight.protocolNames.contains(where: { $0.contains("LE Audio") }), "协议列表")
            try require(insight.leAudioServices.count >= 3, "至少 3 个 LE Audio 服务，得到 \(insight.leAudioServices)")
            try require(insight.vendor == "Sony Corporation", "厂商 \(String(describing: insight.vendor))")
        }
        check("画像: 倍思演示设备不支持 LE Audio，提示音频走经典蓝牙") {
            guard let baseus = DemoData.peripherals().first(where: { $0.id == "DEMO-BOWIE30" }) else {
                try require(false, "缺倍思演示设备")
                return
            }
            let insight = PeripheralAnalyzer.insight(for: baseus)
            try require(!insight.supportsLEAudio, "不应支持 LE Audio")
            try require(insight.audioLinkGuess.contains("A2DP"), "得到 \(insight.audioLinkGuess)")
            try require(insight.notes.joined().contains("0x1850"), "应解释缺失的服务")
        }
        check("画像: Apple 广播设备厂商识别为 Apple") {
            guard let airpods = DemoData.peripherals().first(where: { $0.hasAppleBroadcast }) else {
                try require(false, "缺 Apple 演示设备")
                return
            }
            try require(PeripheralAnalyzer.vendor(for: airpods) == "Apple Inc.", "厂商")
            try require(PeripheralAnalyzer.insight(for: airpods).notes.joined().contains("邻近广播"), "应解释 Apple 广播")
        }
        check("画像: 不可连接设备给出提示") {
            guard let liberty = DemoData.peripherals().first(where: { $0.id == "DEMO-L4NC" }) else {
                try require(false, "缺 Liberty 演示设备")
                return
            }
            let insight = PeripheralAnalyzer.insight(for: liberty)
            try require(insight.notes.joined().contains("不可连接"), "应提示不可连接")
        }

        // MARK: 信号与列表文案

        check("信号: RSSI 阈值") {
            try require(PeripheralAnalyzer.signalBars(rssi: -50) == 4, "-50 → 4")
            try require(PeripheralAnalyzer.signalBars(rssi: -67) == 3, "-67 → 3")
            try require(PeripheralAnalyzer.signalBars(rssi: -78) == 2, "-78 → 2")
            try require(PeripheralAnalyzer.signalBars(rssi: -95) == 0, "-95 → 0")
            try require(PeripheralAnalyzer.signalBars(rssi: nil) == 0, "nil → 0")
        }
        check("信号: 文案包含 dBm 与质量") {
            try require(PeripheralAnalyzer.signalLabel(rssi: -52).contains("-52 dBm"), "文案")
            try require(PeripheralAnalyzer.signalLabel(rssi: -52).contains("很强"), "质量")
        }
        check("列表副标题: 有厂商型号时优先显示") {
            guard let sony = DemoData.peripherals().first(where: { $0.id == "DEMO-XM5" }) else {
                try require(false, "缺 Sony")
                return
            }
            try require(sony.subtitle == "Sony Corporation · WH-1000XM5", "得到 \(sony.subtitle)")
        }
        check("演示数据: 4 台设备、覆盖 Apple/LE Audio/弱信号/长名字") {
            let peripherals = DemoData.peripherals()
            try require(peripherals.count >= 4, "只有 \(peripherals.count) 台")
            try require(peripherals.contains(where: { $0.hasAppleBroadcast }), "缺 Apple 设备")
            try require(peripherals.contains(where: { PeripheralAnalyzer.insight(for: $0).supportsLEAudio }),
                        "缺 LE Audio 设备")
            try require(peripherals.contains(where: { ($0.rssi ?? 0) <= -85 }), "缺弱信号设备")
            try require(peripherals.contains(where: { $0.name.count >= 18 }), "缺长名字设备")
            try require(Set(peripherals.map(\.name)).count == peripherals.count, "名字应唯一")
        }
        check("百科: 7 条音频协议可查") {
            try require(BluetoothProtocolCatalog.profiles.count >= 7, "只配了 \(BluetoothProtocolCatalog.profiles.count) 条")
            try require(BluetoothProtocolCatalog.profile(for: "a2dp")?.code == "A2DP", "大小写不敏感查找")
            try require(BluetoothProtocolCatalog.profiles.allSatisfy { !$0.detail.isEmpty }, "每条都要有解释")
        }
        check("端口中文标签") {
            try require(BluetoothProtocolCatalog.portTypeLabel("BluetoothA2DPOutput").contains("A2DP"), "A2DP")
            try require(BluetoothProtocolCatalog.portTypeLabel("Speaker") == "内置扬声器", "Speaker")
        }

        return results
    }
}
