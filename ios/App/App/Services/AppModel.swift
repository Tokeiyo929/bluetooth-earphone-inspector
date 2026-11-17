import Combine
import Foundation

/// 顶层模型：把音频路由、BLE、页签与导航路径串起来。
/// 同时处理 `-demo` / `-autoTest` / `-autoSmoke` 三种启动参数。
final class AppModel: ObservableObject {
    let route: AudioRouteModel
    let ble: BLEModel
    /// 是否使用演示数据（用于界面提示；-autoTest 只让 BLE 走演示，音频走真实 API）
    let demoMode: Bool

    @Published var selectedTab: Int = 0
    @Published var scanPath: [String] = []
    /// smoke 巡访用：每加一，当前页滚到内容末尾，拍"整页"第二张图。
    @Published var scrollToBottomTick: Int = 0

    private var started = false

    init() {
        let args = ProcessInfo.processInfo.arguments
        let plainDemo = args.contains("-demo")
        let smoke = args.contains("-autoSmoke")
        let autoTest = args.contains("-autoTest")

        demoMode = plainDemo || smoke
        route = AudioRouteModel(demo: plainDemo || smoke)
        ble = BLEModel(demo: plainDemo || smoke || autoTest)
    }

    func start() {
        guard !started else { return }
        started = true
        route.start()
        ble.start()

        let args = ProcessInfo.processInfo.arguments
        if args.contains("-autoTest") {
            AutoTest().run(app: self)
        } else if args.contains("-autoSmoke") {
            SmokeTour.shared.begin(app: self)
        }
    }

    func refreshAll() {
        route.refresh()
        ble.refreshSystemPeripherals()
        if ble.canScan && !ble.isScanning {
            ble.startScan()
        }
    }
}
