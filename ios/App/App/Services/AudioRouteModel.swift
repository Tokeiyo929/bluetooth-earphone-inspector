import AVFoundation
import Combine
import Foundation

/// 读取 AVAudioSession 的真实音频路由，并生成结论。
final class AudioRouteModel: ObservableObject {
    @Published private(set) var snapshot: AudioRouteSnapshot = .empty
    @Published private(set) var verdict: ProtocolVerdict = RouteAnalyzer.verdict(for: .empty)
    @Published private(set) var sessionNote: String?
    @Published private(set) var lastUpdated: Date?

    private let session = AVAudioSession.sharedInstance()
    private var observer: NSObjectProtocol?
    private let isDemo: Bool

    init(demo: Bool) {
        isDemo = demo
    }

    func start() {
        if isDemo {
            applyDemo()
            return
        }
        configureSession()
        observer = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refresh()
        }
        refresh()
    }

    deinit {
        if let observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    func applyDemo() {
        snapshot = DemoData.route()
        verdict = RouteAnalyzer.verdict(for: snapshot)
        sessionNote = "演示数据：模拟器没有蓝牙硬件，真实数值请装到 iPhone 上看。"
        lastUpdated = Date()
    }

    func refresh() {
        if isDemo {
            applyDemo()
            return
        }
        let route = session.currentRoute
        func port(_ description: AVAudioSessionPortDescription) -> RoutePortInfo {
            RoutePortInfo(
                name: description.portName,
                type: description.portType.rawValue,
                // 端口 uid 只用于列表 identity，不展示；用名称+类型拼出来，
                // 避免依赖 AVAudioSessionPortDescription.uid 的 Swift 命名差异。
                uid: description.portName + "|" + description.portType.rawValue,
                channels: description.channels?.count ?? 0
            )
        }
        snapshot = AudioRouteSnapshot(
            outputs: route.outputs.map(port),
            inputs: route.inputs.map(port),
            availableInputs: (session.availableInputs ?? []).map(port)
        )
        verdict = RouteAnalyzer.verdict(for: snapshot)
        lastUpdated = Date()
    }

    private func configureSession() {
        do {
            // 不激活会话，避免打断正在播放的音乐；playAndRecord + allowBluetoothA2DP
            // 才能同时看到 HFP 麦克风和 A2DP 输出。
            try session.setCategory(
                .playAndRecord,
                mode: .default,
                options: [.allowBluetooth, .allowBluetoothA2DP, .mixWithOthers]
            )
        } catch {
            sessionNote = "音频会话设置失败：\(error.localizedDescription)"
        }
    }
}
