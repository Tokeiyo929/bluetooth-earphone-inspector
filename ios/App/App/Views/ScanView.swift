import SwiftUI

struct ScanView: View {
    @EnvironmentObject var app: AppModel
    @EnvironmentObject var ble: BLEModel

    private var systemList: [PeripheralSnapshot] {
        ble.peripherals.filter(\.isSystemConnected)
    }

    private var nearbyList: [PeripheralSnapshot] {
        ble.peripherals.filter { !$0.isSystemConnected }
    }

    var body: some View {
        NavigationStack(path: $app.scanPath) {
            ScrollView {
                VStack(spacing: 16) {
                    if app.demoMode { DemoBanner() }
                    controlCard
                    if !systemList.isEmpty {
                        SectionHeader(text: "系统已连接（BLE 链路）")
                        VStack(spacing: 10) {
                            ForEach(systemList) { peripheral in
                                rowLink(peripheral)
                            }
                        }
                    }
                    if !nearbyList.isEmpty {
                        SectionHeader(text: "附近设备 · \(nearbyList.count) 台")
                        VStack(spacing: 10) {
                            ForEach(nearbyList) { peripheral in
                                rowLink(peripheral)
                            }
                        }
                    } else {
                        emptyCard
                    }
                    explainerCard
                }
                .padding(16)
            }
            .pageBackground()
            .navigationTitle("附近设备")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: String.self) { id in
                if let peripheral = ble.peripheral(id: id) {
                    PeripheralDetailView(peripheral: peripheral)
                } else {
                    Text("设备已离开范围")
                        .foregroundStyle(.secondary)
                        .padding()
                }
            }
            .refreshable { app.refreshAll() }
        }
    }

    private func rowLink(_ peripheral: PeripheralSnapshot) -> some View {
        NavigationLink(value: peripheral.id) {
            PeripheralRow(peripheral: peripheral)
                .card(padding: 12)
        }
        .buttonStyle(.plain)
    }

    private var controlCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: ble.isScanning ? "antenna.radiowaves.left.and.right" : "bluetooth")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(ble.isScanning ? Theme.accent : Color.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(ble.isScanning ? "正在扫描…" : "BLE 扫描")
                        .font(.headline)
                    Text(ble.stateText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }

            Button {
                ble.toggleScan()
            } label: {
                HStack(spacing: 8) {
                    if ble.isScanning {
                        ProgressView().tint(.white).scaleEffect(0.7)
                    } else {
                        Image(systemName: "dot.radiowaves.left.and.right")
                    }
                    Text(ble.isScanning ? "停止扫描" : (app.demoMode ? "重新模拟扫描" : "开始扫描"))
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    LinearGradient(colors: [Theme.indigo, Theme.accent],
                                   startPoint: .leading, endPoint: .trailing)
                )
                .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                .opacity(ble.canScan ? 1 : 0.4)
            }
            .buttonStyle(.plain)
            .disabled(!ble.canScan)
        }
        .card()
    }

    private var emptyCard: some View {
        VStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(.secondary)
            Text("还没有扫描到设备")
                .font(.subheadline.weight(.semibold))
            Text("把耳机放回充电盒再打开盖子，或戴上耳机，它就会开始广播。")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .card()
    }

    private var explainerCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("为什么有的耳机扫不到？").font(.headline)
            Text("BLE 扫描只能看到正在广播低功耗蓝牙的设备。"
                + "只用经典蓝牙（BR/EDR）的廉价耳机不会出现在这里，"
                + "但它们的 A2DP / HFP 链路仍可以在「当前链路」里判定。")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineSpacing(2)
            Text("连接后读取的是标准 GATT 服务：设备信息、电池、以及 LE Audio 的 PACS/ASCS 等。"
                + "部分耳机被系统独占 GATT 会话时，读到的服务可能不全。")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineSpacing(2)
        }
        .card()
    }
}

struct PeripheralRow: View {
    let peripheral: PeripheralSnapshot

    private var insight: PeripheralInsight {
        PeripheralAnalyzer.insight(for: peripheral)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill((peripheral.hasAppleBroadcast ? Theme.indigo : Theme.accent).opacity(0.12))
                    .frame(width: 46, height: 46)
                Image(systemName: "headphones")
                    .font(.system(size: 19, weight: .medium))
                    .foregroundStyle(peripheral.hasAppleBroadcast ? Theme.indigo : Theme.accent)
            }

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(peripheral.name)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    if insight.supportsLEAudio {
                        Badge(text: "LE Audio", color: Theme.green)
                    }
                }
                Text(peripheral.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(peripheral.linkState.label)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    if peripheral.isSystemConnected {
                        Badge(text: "系统已连接", color: Theme.green)
                    }
                    if !peripheral.isConnectable {
                        Badge(text: "不可连接", color: .secondary)
                    }
                    if let battery = peripheral.batteryPercent {
                        Text("电量 \(battery)%")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer(minLength: 4)

            VStack(alignment: .trailing, spacing: 6) {
                SignalBars(bars: PeripheralAnalyzer.signalBars(rssi: peripheral.rssi))
                Text(peripheral.rssi.map { "\($0) dBm" } ?? "—")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
    }
}
