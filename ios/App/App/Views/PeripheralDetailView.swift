import SwiftUI

struct PeripheralDetailView: View {
    @EnvironmentObject var ble: BLEModel
    let peripheral: PeripheralSnapshot

    private var current: PeripheralSnapshot {
        ble.peripheral(id: peripheral.id) ?? peripheral
    }

    private var insight: PeripheralInsight {
        PeripheralAnalyzer.insight(for: current)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                header
                if let apple = current.appleInfo { appleCard(apple) }
                if current.appleInfo == nil, let battery = current.batteryPercent {
                    batteryCard(battery)
                }
                insightCard
                if !deviceInfoRows.isEmpty { deviceInfoCard }
                servicesCard
                if let hex = current.manufacturerDataHex { rawCard(hex) }
                connectPanel
            }
            .padding(16)
        }
        .pageBackground()
        .navigationTitle(current.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - 头部

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Theme.indigo.opacity(0.12))
                        .frame(width: 52, height: 52)
                    Image(systemName: "headphones")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(Theme.indigo)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(current.name)
                        .font(.title3.weight(.bold))
                        .fixedSize(horizontal: false, vertical: true)
                    Text(shortIdentifier)
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 4)
                VStack(alignment: .trailing, spacing: 5) {
                    SignalBars(bars: PeripheralAnalyzer.signalBars(rssi: current.rssi))
                    Text(PeripheralAnalyzer.signalLabel(rssi: current.rssi))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 6) {
                Badge(text: current.linkState.label,
                      color: current.linkState == .connected ? Theme.green : Theme.accent)
                if current.isSystemConnected {
                    Badge(text: "系统已连接", color: Theme.green)
                }
                if current.isDemo {
                    Badge(text: "模拟数据", color: .secondary)
                }
            }
        }
        .card()
    }

    private var shortIdentifier: String {
        if current.id.hasPrefix("DEMO-") { return "模拟设备 · \(current.id)" }
        return String(current.id.prefix(8)) + "…"
    }

    // MARK: - Apple 广播

    private func appleCard(_ apple: AppleProximityInfo) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "apple.logo")
                    .font(.subheadline)
                    .foregroundStyle(Theme.indigo)
                Text("Apple 私有广播")
                    .font(.headline)
                Spacer()
                Badge(text: apple.modelName, color: Theme.indigo)
            }

            VStack(spacing: 8) {
                BudBatteryRow(title: "左耳", percent: apple.leftPercent, charging: apple.leftCharging)
                BudBatteryRow(title: "右耳", percent: apple.rightPercent, charging: apple.rightCharging)
                BudBatteryRow(title: "充电盒", percent: apple.casePercent, charging: apple.caseCharging)
            }

            Divider()

            InfoRow(title: "佩戴", value: apple.earText)
            InfoRow(title: "盒盖", value: apple.lidOpen ? "打开" : "闭合")
            InfoRow(title: "颜色", value: apple.colorName)
            InfoRow(title: "连接状态", value: apple.connectionState)
            InfoRow(title: "型号 ID", value: String(format: "0x%04X", apple.modelID))

            Text("Apple 用厂商 ID 0x004C 的私有邻近报文广播这些状态，"
                + "不是标准蓝牙协议。新固件可能改为加密广播，电量读数偶尔会失真。")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineSpacing(2)
        }
        .card()
    }

    // MARK: - 电量（非 Apple 设备）

    private func batteryCard(_ percent: Int) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "battery.75")
                    .font(.subheadline)
                    .foregroundStyle(Theme.green)
                Text("电池电量（GATT 0x2A19）").font(.headline)
                Spacer()
                Text("\(percent)%")
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(Theme.green)
            }
            BatteryBar(percent: percent)
        }
        .card()
    }

    // MARK: - 协议画像

    private var insightCard: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack {
                Text("协议画像").font(.headline)
                Spacer()
                Badge(text: insight.supportsLEAudio ? "LE Audio 就绪" : "经典蓝牙音频",
                      color: insight.supportsLEAudio ? Theme.green : Theme.orange)
            }
            InfoRow(title: "音频链路", value: insight.audioLinkGuess, titleWidth: 72)
            InfoRow(title: "BLE 角色", value: insight.bleRole, titleWidth: 72)
            InfoRow(title: "协议", value: insight.protocolNames.joined(separator: " + "), titleWidth: 72)
            if let vendor = insight.vendor {
                InfoRow(title: "厂商", value: vendor, titleWidth: 72)
            }
            Divider()
            ForEach(insight.notes.indices, id: \.self) { index in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "info.circle")
                        .font(.caption)
                        .foregroundStyle(Theme.accent)
                        .padding(.top, 1)
                    Text(insight.notes[index])
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .card()
    }

    // MARK: - 设备信息

    private var deviceInfoRows: [(String, String)] {
        DeviceInfoField.allCases.compactMap { field in
            guard let value = current.deviceInfo[field.rawValue], !value.isEmpty else { return nil }
            return (field.title, value)
        }
    }

    private var deviceInfoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("设备信息（GATT 0x180A）").font(.headline)
            ForEach(deviceInfoRows.indices, id: \.self) { index in
                InfoRow(title: deviceInfoRows[index].0, value: deviceInfoRows[index].1, titleWidth: 72)
            }
        }
        .card()
    }

    // MARK: - 服务列表

    private var servicesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("GATT 服务与特征值").font(.headline)
                Spacer()
                Text("\(current.services.count) 项")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if current.services.isEmpty {
                Text(current.linkState == .connected
                     ? "已连接，但还没有读到服务列表。系统或其他 App 可能占用了 GATT 会话。"
                     : "连接后即可读取服务列表。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(current.services) { service in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text(service.name)
                                .font(.subheadline.weight(.semibold))
                                .lineLimit(2)
                            if service.leAudioRelated {
                                Badge(text: "LE Audio", color: Theme.green)
                            }
                            Spacer(minLength: 4)
                            Text(service.uuid)
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        if let note = service.note {
                            Text(note)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        ForEach(service.characteristics) { characteristic in
                            characteristicRow(characteristic)
                        }
                    }
                    .padding(12)
                    .background(Color.primary.opacity(0.035))
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                }
            }
        }
        .card()
    }

    private func characteristicRow(_ characteristic: GATTCharacteristicSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(characteristic.name)
                    .font(.caption.weight(.medium))
                    .lineLimit(1)
                Spacer(minLength: 4)
                if let value = characteristic.valueText {
                    Text(value)
                        .font(.caption.monospacedDigit().weight(.semibold))
                        .foregroundStyle(Theme.accent)
                        .lineLimit(1)
                }
            }
            HStack(spacing: 6) {
                Text(characteristic.uuid)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer(minLength: 4)
                Text(characteristic.properties.joined(separator: " · "))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
            if characteristic.valueText == nil, let hex = characteristic.valueHex {
                Text(hex)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 5)
    }

    // MARK: - 原始广播

    private func rawCard(_ hex: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("广播原始字节").font(.headline)
            Text(hex)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
            Text(current.appleInfo != nil
                 ? "厂商 ID 0x004C（Apple 私有广播）"
                 : "厂商 ID 非 0x004C（标准广播 / 其他厂商）")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .card()
    }

    // MARK: - 连接

    private var connectPanel: some View {
        VStack(spacing: 10) {
            if current.isDemo {
                Text("模拟设备：真实连接与读取请在 iPhone 上运行。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if current.linkState == .connecting {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("正在连接并读取服务…")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } else if current.linkState != .connected {
                Button {
                    ble.connect(current.id)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "link")
                        Text(current.linkState == .failed ? "重试连接" : "连接并读取 GATT")
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Theme.indigo)
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                }
                .buttonStyle(.plain)
            }

            if let error = current.lastError {
                Text(error)
                    .font(.caption2)
                    .foregroundStyle(Theme.red)
                    .multilineTextAlignment(.center)
            }
        }
    }
}
