import Foundation

/// 当前链路页上的「蓝牙版本 5.2？」结论。
struct VersionHint: Equatable {
    var title: String
    var badge: String
    var verified: Bool
    var evidence: [String]
    var action: String
}

enum VersionAnalyzer {

    /// 两条证据任一成立即可确认 ≥5.2：
    /// 1) 当前音频端口是 LE Audio；2) BLE 侧发现 LE Audio 服务。
    static func hint(for snapshot: AudioRouteSnapshot, leAudioOverBLE: Bool) -> VersionHint {
        let routeLine: String
        if let output = snapshot.bluetoothOutput {
            routeLine = "当前音频链路：\(output.name) · "
                + BluetoothProtocolCatalog.portTypeLabel(output.type)
        } else if let output = snapshot.outputs.first {
            routeLine = "当前音频输出：\(output.name) · "
                + BluetoothProtocolCatalog.portTypeLabel(output.type)
        } else {
            routeLine = "当前没有音频输出"
        }

        if snapshot.hasLEAudio || leAudioOverBLE {
            return VersionHint(
                title: "至少 Bluetooth 5.2",
                badge: "≥5.2",
                verified: true,
                evidence: [
                    routeLine,
                    snapshot.hasLEAudio
                        ? "音频端口类型是 BluetoothLE，正在用 LE Audio 链路"
                        : "BLE 侧发现了 LE Audio 服务（PACS / ASCS / CSIS）",
                    "LE Audio 由 Bluetooth 5.2 引入，能跑起来即说明核心规格至少 5.2"
                ],
                action: "这是系统里唯一能验证 5.2 的硬证据。"
            )
        }

        return VersionHint(
            title: "无法确认是否 5.2",
            badge: "未验证",
            verified: false,
            evidence: [
                routeLine,
                "iOS 不公开协商后的 Bluetooth 核心规格版本，设置里也不显示",
                "当前没有 LE Audio 端口，BLE 侧也没有发现 PACS / ASCS / CSIS 服务",
                "没有 LE Audio 不等于低于 5.2：很多 5.2 耳机只在经典 A2DP 上工作"
            ],
            action: "打开「附近设备」→ 点耳机 → 看「蓝牙版本」；或核对包装/厂商规格。"
        )
    }
}
