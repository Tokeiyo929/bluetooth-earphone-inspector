import Foundation

/// 一个音频端口（AVAudioSessionPortDescription 的可测试快照）。
struct RoutePortInfo: Equatable, Identifiable {
    var id: String { uid + "|" + name + "|" + type }
    var name: String
    var type: String
    var uid: String
    var channels: Int
}

/// 当前音频路由快照。
struct AudioRouteSnapshot: Equatable {
    var outputs: [RoutePortInfo]
    var inputs: [RoutePortInfo]
    var availableInputs: [RoutePortInfo]

    static let empty = AudioRouteSnapshot(outputs: [], inputs: [], availableInputs: [])

    var hasBluetoothOutput: Bool {
        outputs.contains { RouteAnalyzer.classify(typeRaw: $0.type).isBluetooth }
    }

    var bluetoothOutput: RoutePortInfo? {
        outputs.first { RouteAnalyzer.classify(typeRaw: $0.type).isBluetooth }
    }

    var hasHFPInput: Bool {
        inputs.contains { RouteAnalyzer.classify(typeRaw: $0.type) == .hfp }
            || availableInputs.contains { RouteAnalyzer.classify(typeRaw: $0.type) == .hfp }
    }

    var hasLEAudio: Bool {
        outputs.contains { RouteAnalyzer.classify(typeRaw: $0.type) == .leAudio }
    }
}

/// 结论卡片的数据。UI 只负责着色，文字都在这里生成，方便测试。
struct ProtocolVerdict: Equatable {
    var profileCode: String
    var title: String
    var badge: String
    var layer: String
    var summary: String
    var evidence: [String]
    var codecNote: String
    var icon: String
    var tone: String        // a2dp | hfp | le | none
    var isBluetoothActive: Bool
}

enum RouteAnalyzer {

    // MARK: - 端口分类

    static func classify(typeRaw: String) -> AudioPortClass {
        let raw = typeRaw.trimmingCharacters(in: .whitespacesAndNewlines)
        if raw.isEmpty { return .none }
        if raw == "BluetoothA2DPOutput" || raw == "BluetoothA2DP" { return .a2dp }
        if raw == "BluetoothHFP" { return .hfp }
        if raw == "BluetoothLE" { return .leAudio }
        if raw == "AirPlay" { return .airPlay }
        if raw == "Headphones" || raw == "LineOut" || raw == "USBAudio"
            || raw == "CarAudio" || raw == "HDMI" || raw == "DisplayPort" { return .wired }
        if raw == "Speaker" { return .speaker }
        if raw == "Receiver" { return .receiver }
        if raw.hasSuffix("Mic") || raw == "BuiltInMic" { return .microphone }
        // 未来系统如果新增端口，用关键字兜底，避免把蓝牙误判成“其他”
        if raw.localizedCaseInsensitiveContains("BluetoothA2DP") { return .a2dp }
        if raw.localizedCaseInsensitiveContains("BluetoothHFP") { return .hfp }
        if raw.localizedCaseInsensitiveContains("BluetoothLE") { return .leAudio }
        return .other
    }

    /// 输出端口的一句话描述（用于列表行）。
    static func outputSummary(_ snapshot: AudioRouteSnapshot) -> String {
        guard let output = snapshot.outputs.first else { return "没有音频输出" }
        return "\(output.name) · \(BluetoothProtocolCatalog.portTypeLabel(output.type))"
    }

    // MARK: - 结论

    static func verdict(for snapshot: AudioRouteSnapshot) -> ProtocolVerdict {
        let bluetoothOutput = snapshot.bluetoothOutput

        if let output = bluetoothOutput {
            let portClass = classify(typeRaw: output.type)
            let hfpLine = snapshot.hasHFPInput
                ? "麦克风：HFP 免提协议在线，来电时会自动切到通话通道"
                : "未发现蓝牙麦克风：通话可能回落到手机听筒（或该耳机没有麦克风）"

            switch portClass {
            case .a2dp:
                return ProtocolVerdict(
                    profileCode: "A2DP",
                    title: "A2DP · 音乐链路",
                    badge: "媒体输出",
                    layer: "经典蓝牙 BR/EDR",
                    summary: "iPhone 正通过 A2DP 把音乐送到「\(output.name)」。"
                        + "这是蓝牙耳机日常听歌的主通道，音质取决于双方协商出的编解码器。",
                    evidence: [
                        "AVAudioSession.currentRoute 的输出端口是 \(output.type)",
                        "输出端口名：\(output.name)，\(output.channels) 声道",
                        hfpLine,
                        snapshot.hasLEAudio ? "同时存在 LE Audio 端点" : "未走 LE Audio / 低功耗音频"
                    ],
                    codecNote: "iOS 不向第三方 App 公开 A2DP 编解码协商结果。iPhone 对蓝牙耳机通常使用 AAC，"
                        + "不支持时回退 SBC；LE Audio 链路才用 LC3。",
                    icon: "music.note",
                    tone: "a2dp",
                    isBluetoothActive: true
                )
            case .leAudio:
                return ProtocolVerdict(
                    profileCode: "LE Audio",
                    title: "LE Audio · 低功耗音频",
                    badge: "新一代音频",
                    layer: "BLE 同步通道（ISO）",
                    summary: "当前走 LE Audio，用 LC3 编解码和同步通道（ISO）传输，"
                        + "延迟更低、左右耳同步由协议保证。",
                    evidence: [
                        "AVAudioSession.currentRoute 的输出端口是 \(output.type)",
                        "输出端口名：\(output.name)，\(output.channels) 声道",
                        hfpLine,
                        "LE Audio 的麦克风同样走 ISO 通道，而不是经典蓝牙 HFP"
                    ],
                    codecNote: "LE Audio 的强制编解码器是 LC3，iOS 不提供协商细节。",
                    icon: "waveform.badge.plus",
                    tone: "le",
                    isBluetoothActive: true
                )
            case .hfp:
                return ProtocolVerdict(
                    profileCode: "HFP",
                    title: "HFP · 通话链路",
                    badge: "免提 / 通话",
                    layer: "经典蓝牙 BR/EDR",
                    summary: "当前音频输出走 HFP 免提协议。通常出现在通话中，"
                        + "或耳机只支持免提、没有 A2DP 音乐通道。音乐被压到语音带宽，会明显发闷。",
                    evidence: [
                        "AVAudioSession.currentRoute 的输出端口是 \(output.type)",
                        "输出端口名：\(output.name)，\(output.channels) 声道",
                        "HFP 同一时刻只承载一条窄带语音链路",
                        "若正在播放音乐，说明耳机可能缺少 A2DP 支持"
                    ],
                    codecNote: "HFP 使用 CVSD 或 mSBC 语音编码，是双向语音通道，不适合听歌。",
                    icon: "phone.fill",
                    tone: "hfp",
                    isBluetoothActive: true
                )
            default:
                return ProtocolVerdict(
                    profileCode: "Bluetooth",
                    title: "蓝牙音频输出（类型未知）",
                    badge: "未识别",
                    layer: "蓝牙",
                    summary: "输出端口是蓝牙类型，但系统报告的类型字符串不在已知列表里：\(output.type)。",
                    evidence: [
                        "端口名：\(output.name)",
                        hfpLine
                    ],
                    codecNote: "iOS 新增端口类型时可能需要更新本 App 的识别表。",
                    icon: "bluetooth",
                    tone: "none",
                    isBluetoothActive: true
                )
            }
        }

        // 没有蓝牙输出
        let outputLine: String
        if let output = snapshot.outputs.first {
            outputLine = "当前输出：\(output.name)（\(BluetoothProtocolCatalog.portTypeLabel(output.type))）"
        } else {
            outputLine = "系统没有报告任何音频输出端口"
        }
        return ProtocolVerdict(
            profileCode: "—",
            title: "还没有蓝牙音频链路",
            badge: "未连接",
            layer: "本机输出",
            summary: "戴上耳机、在系统里连上之后回到本页，就能看到它实际使用的蓝牙协议。",
            evidence: [
                outputLine,
                snapshot.outputs.isEmpty ? "AVAudioSession 尚未激活或处于无声状态" : "输出端口不属于蓝牙类型",
                snapshot.hasHFPInput ? "已有 HFP 麦克风可用，说明蓝牙通话通道已就绪" : "没有蓝牙麦克风可用"
            ],
            codecNote: "小贴士：A2DP 负责听歌，HFP 负责通话；同一副耳机通常两条链路都支持。",
            icon: "headphones",
            tone: "none",
            isBluetoothActive: false
        )
    }

    /// 供 UI 的「路由明细」使用。
    static func detailRows(_ snapshot: AudioRouteSnapshot) -> [(String, String)] {
        var rows: [(String, String)] = []
        if let output = snapshot.outputs.first {
            rows.append(("输出端口", output.name))
            rows.append(("端口类型", "\(output.type) · \(BluetoothProtocolCatalog.portTypeLabel(output.type))"))
            rows.append(("声道数", "\(output.channels)"))
        } else {
            rows.append(("输出端口", "无"))
        }
        if let input = snapshot.inputs.first {
            rows.append(("输入端口", "\(input.name) · \(BluetoothProtocolCatalog.portTypeLabel(input.type))"))
        } else {
            rows.append(("输入端口", snapshot.availableInputs.isEmpty ? "无" : "未激活（可用输入如下）"))
        }
        if !snapshot.availableInputs.isEmpty {
            rows.append(("可用输入", snapshot.availableInputs.map(\.name).joined(separator: " / ")))
        }
        rows.append(("蓝牙链路", snapshot.hasBluetoothOutput ? "存在" : "不存在"))
        return rows
    }
}
