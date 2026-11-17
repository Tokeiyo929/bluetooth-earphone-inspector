import Foundation

/// L1 核心回归入口：与 App 内 -autoTest 共用 CoreRegression。
/// CI: swiftc -DDEBUG <pure core files> tests/CoreTests.swift -o /tmp/bt-core-tests
@main
enum CoreTests {
    static func main() {
        setvbuf(stdout, nil, _IOLBF, 0)
        var failures = 0
        let results = CoreRegression.run()
        for result in results {
            print((result.passed ? "PASS" : "FAIL") + " " + result.name
                  + (result.passed ? "" : " —— \(result.detail)"))
            if !result.passed { failures += 1 }
        }
        print(failures == 0 ? "RESULT: ALL PASS" : "RESULT: \(failures) FAILURES")
        exit(failures == 0 ? 0 : 1)
    }
}
