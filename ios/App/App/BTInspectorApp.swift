import SwiftUI

@main
struct BTInspectorApp: App {
    @StateObject private var app = AppModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(app)
                .environmentObject(app.route)
                .environmentObject(app.ble)
                .onAppear { app.start() }
                .onChange(of: scenePhase) { phase in
                    // 从后台回来时刷新：系统可能在后台改了路由/连接
                    if phase == .active {
                        app.route.refresh()
                        app.ble.refreshSystemPeripherals()
                    }
                }
        }
    }
}

/// 三个页签：当前链路 / 附近设备 / 协议百科。
/// selectedTab 放在 AppModel 里，供 SmokeTour 按页签巡访。
struct RootView: View {
    @EnvironmentObject var app: AppModel

    var body: some View {
        TabView(selection: $app.selectedTab) {
            RouteView()
                .tabItem { Label("当前链路", systemImage: "waveform") }
                .tag(0)
            ScanView()
                .tabItem { Label("附近设备", systemImage: "antenna.radiowaves.left.and.right") }
                .tag(1)
            HandbookView()
                .tabItem { Label("协议百科", systemImage: "book.closed") }
                .tag(2)
        }
        .tint(Theme.accent)
    }
}
