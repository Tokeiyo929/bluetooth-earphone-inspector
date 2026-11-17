import Foundation

/// `-autoTest`：进程内自测。跑与 L1 完全相同的核心回归，再验证真实
/// AVAudioSession / 模型查询路径，写 tmp/autotest/result.txt + done.txt 后退出。
final class AutoTest {

    func run(app: AppModel) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("autotest", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? FileManager.default.removeItem(at: directory.appendingPathComponent("result.txt"))
        try? FileManager.default.removeItem(at: directory.appendingPathComponent("done.txt"))

        var lines: [String] = []
        var failures = 0

        for result in CoreRegression.run() {
            let line = (result.passed ? "PASS" : "FAIL") + " " + result.name
                + (result.passed ? "" : " —— \(result.detail)")
            lines.append(line)
            if !result.passed { failures += 1 }
        }

        // 真实 AVAudioSession：模拟器也会报告内置扬声器输出
        let snapshot = app.route.snapshot
        let outputNames = snapshot.outputs.map { "\($0.name)[\($0.type)]" }.joined(separator: " / ")
        let hasOutput = !snapshot.outputs.isEmpty
        lines.append((hasOutput ? "PASS" : "FAIL") + " 真实 AVAudioSession 报告输出端口：\(outputNames)")
        if !hasOutput { failures += 1 }

        let verdictOK = !app.route.verdict.title.isEmpty && !app.route.verdict.summary.isEmpty
        lines.append((verdictOK ? "PASS" : "FAIL") + " 结论卡片文案完整（\(app.route.verdict.title)）")
        if !verdictOK { failures += 1 }

        // 演示设备可被详情页按 id 取回
        let ids = app.ble.peripherals.map(\.id)
        let lookupOK = ids.allSatisfy { app.ble.peripheral(id: $0) != nil }
        lines.append((lookupOK ? "PASS" : "FAIL") + " 附近设备按 id 可查询（\(ids.count) 台）")
        if !lookupOK { failures += 1 }

        lines.append(failures == 0 ? "RESULT: ALL PASS" : "RESULT: \(failures) FAILURES")
        write(lines.joined(separator: "\n") + "\n", to: directory.appendingPathComponent("result.txt"))
        write(failures == 0 ? "PASS" : "FAIL", to: directory.appendingPathComponent("done.txt"))

        print("BT AUTOTEST RESULT:")
        print(lines.joined(separator: "\n"))
        exit(failures == 0 ? 0 : 1)
    }

    private func write(_ text: String, to url: URL) {
        try? text.data(using: .utf8)?.write(to: url, options: .atomic)
    }
}
