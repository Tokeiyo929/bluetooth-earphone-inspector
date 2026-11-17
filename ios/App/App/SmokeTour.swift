import Foundation

/// `-autoSmoke` 全页面截图巡访。
/// 握手协议：App 写 tmp/smoke/now-<name> → runner 截图 → 写回 ack-<name> → 下一页。
/// 目录名是 smoke（不是参数名 -autoSmoke），与 tests/run_simulator_tests.sh 保持一致。
final class SmokeTour {
    static let shared = SmokeTour()
    static let pages = ["01-route", "02-scan", "03-detail-airpods", "04-detail-sony", "05-handbook"]

    private weak var app: AppModel?

    private var smokeDir: URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("smoke", isDirectory: true)
    }

    func begin(app: AppModel) {
        self.app = app
        try? FileManager.default.createDirectory(at: smokeDir, withIntermediateDirectories: true)
        for name in Self.pages {
            try? FileManager.default.removeItem(at: smokeDir.appendingPathComponent("now-\(name)"))
            try? FileManager.default.removeItem(at: smokeDir.appendingPathComponent("ack-\(name)"))
            try? FileManager.default.removeItem(at: smokeDir.appendingPathComponent("bottom-\(name)"))
            try? FileManager.default.removeItem(at: smokeDir.appendingPathComponent("ack-bottom-\(name)"))
        }
        try? FileManager.default.removeItem(at: smokeDir.appendingPathComponent("done.txt"))
        try? FileManager.default.removeItem(at: smokeDir.appendingPathComponent("result.txt"))
        print("BT SMOKE: begin pages=\(Self.pages)")
        runPage(0)
    }

    // MARK: - 逐页

    private func runPage(_ index: Int) {
        guard index < Self.pages.count else {
            finish()
            return
        }
        guard let app else {
            fail("AppModel 丢失")
            return
        }
        let name = Self.pages[index]
        app.selectedTab = tab(for: name)

        let path: [String]
        switch name {
        case "03-detail-airpods": path = ["DEMO-AP2"]
        case "04-detail-sony": path = ["DEMO-XM5"]
        default: path = []
        }

        print("BT SMOKE: page \(name)")
        // 先让页签切换生效，再设置导航路径，最后留时间给 SwiftUI 布局
        delay(0.6) { [weak self] in
            app.scanPath = path
            self?.delay(1.4) { [weak self] in
                self?.showMarker(index)
            }
        }
    }

    private func tab(for name: String) -> Int {
        if name == "01-route" { return 0 }
        if name == "05-handbook" { return 2 }
        return 1
    }

    private func showMarker(_ index: Int) {
        let name = Self.pages[index]
        writeMarker("now-\(name)")
        waitForAck(name) { [weak self] in
            self?.scrollToBottom(index)
        }
    }

    /// 首屏拍完后滚到底，再喊 runner 拍第二张。
    /// App 会一直等到 `ack-bottom-<name>` 才翻页，所以第二张不可能拍到下一页。
    private func scrollToBottom(_ index: Int) {
        guard let app else {
            fail("AppModel 丢失")
            return
        }
        let name = Self.pages[index]
        app.scrollToBottomTick += 1
        // 等滚动动画结束
        delay(0.8) { [weak self] in
            guard let self else { return }
            self.writeMarker("bottom-\(name)")
            self.waitForAck("bottom-\(name)") { [weak self] in
                self?.runPage(index + 1)
            }
        }
    }

    private func waitForAck(_ name: String, then: @escaping () -> Void) {
        waitUntil(
            timeout: 120,
            check: { [weak self] in
                guard let self else { return false }
                return FileManager.default.fileExists(
                    atPath: self.smokeDir.appendingPathComponent("ack-\(name)").path
                )
            },
            onTimeout: { "runner 未 ack \(name)" },
            then: then
        )
    }

    // MARK: - 轮询小工具

    private func delay(_ seconds: TimeInterval, then: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: then)
    }

    private func waitUntil(timeout: TimeInterval,
                           check: @escaping () -> Bool,
                           onTimeout: @escaping () -> String,
                           then: @escaping () -> Void) {
        let deadline = Date().addingTimeInterval(timeout)
        poll(deadline: deadline, check: check, onTimeout: onTimeout, then: then)
    }

    private func poll(deadline: Date,
                      check: @escaping () -> Bool,
                      onTimeout: @escaping () -> String,
                      then: @escaping () -> Void) {
        if check() {
            then()
            return
        }
        if Date() >= deadline {
            fail(onTimeout())
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            self?.poll(deadline: deadline, check: check, onTimeout: onTimeout, then: then)
        }
    }

    private func writeMarker(_ name: String) {
        FileManager.default.createFile(atPath: smokeDir.appendingPathComponent(name).path, contents: nil)
        print("BT SMOKE: marker \(name)")
    }

    private func write(_ file: String, _ content: String) {
        try? content.data(using: .utf8)?.write(
            to: smokeDir.appendingPathComponent(file),
            options: .atomic
        )
    }

    private func finish() {
        print("BT SMOKE: finish")
        write("result.txt", "RESULT: ALL PASS")
        write("done.txt", "PASS")
        exit(0)
    }

    private func fail(_ message: String) {
        print("BT SMOKE: FAIL \(message)")
        write("result.txt", "FAIL smoke —— \(message)\nRESULT: 1 FAILURES")
        write("done.txt", "FAIL")
        exit(1)
    }
}
