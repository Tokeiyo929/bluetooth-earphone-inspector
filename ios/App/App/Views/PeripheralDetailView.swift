import SwiftUI

struct PeripheralDetailView: View {
    @EnvironmentObject var app: AppModel
    @EnvironmentObject var ble: BLEModel
    let peripheral: PeripheralSnapshot

    @State private var isPlaying = false

    private var current: PeripheralSnapshot {
        ble.peripheral(id: peripheral.id) ?? peripheral
    }

    private var insight: PeripheralInsight {
        PeripheralAnalyzer.insight(for: current)
    }

    private var chip: ChipInsight {
        ChipAnalyzer.insight(for: current)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                header
                if let apple = current.appleInfo { appleCard(apple) }
                if current.appleInfo == nil, let battery = current.batteryPercent {
                    batteryCard(battery)
                }
                chipCard
                insightCard
                if hasMediaControl { mediaControlCard }
                if !deviceInfoRows.isEmpty { deviceInfoCard }
                servicesCard
                if let hex = current.manufacturerDataHex { rawCard(hex) }
                connectPanel
            }
            .padding(16)
            .padding(.bottom, 24)
            .id(SmokeScroll.anchorID)
        }
        .pageBackground()
        .navigationTitle(current.name)
        .navigationBarTitleDisplayMode(.inline)
        .followSmokeScrollTick(app.scrollToBottomTick)
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
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                    Text(shortIdentifier)
                        .font(.caption2.monospaced())
                        .foregroundStyle(Theme.secondaryText)
                }
                Spacer(minLength: 4)
                VStack(alignment: .trailing, spacing: 5) {
                    SignalBars(bars: PeripheralAnalyzer.signalBars(rssi: current.rssi))
                    Text(PeripheralAnalyzer.signalLabel(rssi: current.rssi))
                        .font(.caption2)
                        .foregroundStyle(Theme.secondaryText)
                }
            }

            HStack(spacing: 6) {
                if current.isSystemConnected {
                    Badge(text: "系统 BLE 链路", color: Theme.green)
                } else {
                    Badge(text: current.linkState.label,
                          color: current.linkState == .connected ? Theme.green : Theme.accent)
                }
                if current.isDemo {
                    Badge(text: "模拟数据", color: Theme.grey)
                }
            }
        }
        .card()
    }

    private var shortIdentifier: String {
        if current.id.hasPrefix("DEMO-") { return "模拟设备 · \(current.id)" }
        return current.id.count <= 12 ? current.id : String(current.id.prefix(8)) + "…"
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
                .foregroundStyle(Theme.secondaryText)
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
                        .foregroundStyle(Theme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .card()
    }

    // MARK: - 芯片与版本线索

    private var chipCard: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(spacing: 8) {
                Image(systemName: "cpu")
                    .font(.subheadline)
                    .foregroundStyle(Theme.indigo)
                Text("芯片与版本线索").font(.headline)
                Spacer(minLength: 4)
                Badge(text: chip.confidenceLabel,
                      color: chip.confidence == "高" ? Theme.green
                        : chip.confidence == "中" ? Theme.orange : Theme.grey)
            }

            if let brand = chip.brand {
                InfoRow(title: "品牌", value: brand, titleWidth: 64)
            }
            if let vendor = chip.moduleVendor {
                InfoRow(title: "方案商", value: vendor, titleWidth: 64)
            }
            if let family = chip.chipFamily {
                InfoRow(title: "芯片系列", value: family, titleWidth: 64)
            }
            if chip.brand == nil && chip.moduleVendor == nil && chip.chipFamily == nil {
                Text("设备没有自报厂商/型号，也没有厂商广播 ID —— 芯片只能靠厂商或拆机确认。")
                    .font(.footnote)
                    .foregroundStyle(Theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if chip.hasAnyClue {
                Divider()
                Text("原始线索")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.secondaryText)
                ForEach(Array(chip.clues.prefix(6))) { clue in
                    VStack(alignment: .leading, spacing: 1) {
                        Text("\(clue.source) · \(clue.field)")
                            .font(.caption2)
                            .foregroundStyle(Theme.tertiaryText)
                        Text(clue.value)
                            .font(.caption)
                            .foregroundStyle(Theme.secondaryText)
                            .textSelection(.enabled)
                    }
                    .padding(.vertical, 1)
                }
            }

            Divider()

            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "number")
                    .font(.caption)
                    .foregroundStyle(chip.versionVerdict.contains("5.2") ? Theme.green : Theme.orange)
                    .padding(.top, 1)
                VStack(alignment: .leading, spacing: 2) {
                    Text("蓝牙版本")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.secondaryText)
                    Text(chip.versionVerdict)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color.primary)
                }
            }
            ForEach(chip.versionEvidence.indices, id: \.self) { index in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "checkmark.circle")
                        .font(.caption2)
                        .foregroundStyle(Theme.secondaryText)
                        .padding(.top, 2)
                    Text(chip.versionEvidence[index])
                        .font(.caption)
                        .foregroundStyle(Theme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Divider()
            ForEach(chip.notes.indices, id: \.self) { index in
                Text(chip.notes[index])
                    .font(.caption2)
                    .foregroundStyle(Theme.tertiaryText)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .card()
    }

    // MARK: - 标准 MCS 播放控制

    private var mediaControlService: GATTServiceSnapshot? {
        current.services.first {
            guard let short = BluetoothProtocolCatalog.shortUUID($0.uuid) else { return false }
            return short == 0x1848 || short == 0x1849
        }
    }

    private var hasMediaControl: Bool {
        guard let service = mediaControlService else { return false }
        return service.characteristics.contains {
            BluetoothProtocolCatalog.shortUUID($0.uuid) == 0x2BA4
        }
    }

    private var mediaControlCard: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(spacing: 8) {
                Image(systemName: "play.circle")
                    .font(.subheadline)
                    .foregroundStyle(Theme.accent)
                Text("播放控制").font(.headline)
                Spacer()
                Badge(text: "标准 MCS", color: Theme.green)
            }

            HStack(spacing: 10) {
                controlButton("backward.fill") {
                    ble.writeMediaControl(0x04, peripheralID: current.id)
                }
                controlButton(isPlaying ? "pause.fill" : "play.fill") {
                    let opcode: UInt8 = isPlaying ? 0x02 : 0x01
                    isPlaying.toggle()
                    ble.writeMediaControl(opcode, peripheralID: current.id)
                }
                controlButton("forward.fill") {
                    ble.writeMediaControl(0x05, peripheralID: current.id)
                }
            }

            if let message = ble.controlMessage {
                Text(message)
                    .font(.caption2)
                    .foregroundStyle(Theme.secondaryText)
            }

            Text("用的是蓝牙标准的 Media Control Service（0x1848）控制点 0x2BA4。"
                + "降噪、通透、EQ 属于厂商私有协议，iOS 没有统一 API；"
                + "这类功能要用厂商 App（如 Sony Headphones Connect）。")
                .font(.caption2)
                .foregroundStyle(Theme.tertiaryText)
                .lineSpacing(2)
        }
        .card()
    }

    private func controlButton(_ systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Theme.accent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(Theme.accent.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
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
                    .foregroundStyle(Theme.secondaryText)
            }

            if current.services.isEmpty {
                Text(current.linkState == .connected
                     ? "已连接，但还没有读到服务列表。系统或其他 App 可能占用了 GATT 会话。"
                     : "连接后即可读取服务列表。")
                    .font(.footnote)
                    .foregroundStyle(Theme.secondaryText)
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
                                .foregroundStyle(Theme.secondaryText)
                                .lineLimit(1)
                        }
                        if let note = service.note {
                            Text(note)
                                .font(.caption2)
                                .foregroundStyle(Theme.secondaryText)
                        }
                        ForEach(service.characteristics) { characteristic in
                            characteristicRow(characteristic)
                        }
                    }
                    .padding(12)
                    .background(Color.primary.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.07), lineWidth: 1)
                    )
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
                    .foregroundStyle(Theme.secondaryText)
                    .lineLimit(1)
                Spacer(minLength: 4)
                Text(characteristic.properties.joined(separator: " · "))
                    .font(.caption2)
                    .foregroundStyle(Theme.tertiaryText)
                    .lineLimit(1)
            }
            if characteristic.valueText == nil, let hex = characteristic.valueHex {
                Text(hex)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(Theme.secondaryText)
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
                .foregroundStyle(Theme.secondaryText)
                .textSelection(.enabled)
            Text(current.appleInfo != nil
                 ? "厂商 ID 0x004C（Apple 私有广播）"
                 : "厂商 ID 非 0x004C（标准广播 / 其他厂商）")
                .font(.caption2)
                .foregroundStyle(Theme.tertiaryText)
        }
        .card()
    }

    // MARK: - 连接

    private var connectPanel: some View {
        VStack(spacing: 10) {
            if current.isDemo {
                Text("模拟设备：真实连接与读取请在 iPhone 上运行。")
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryText)
            } else if current.linkState == .connecting {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("正在连接并读取服务…")
                        .font(.footnote)
                        .foregroundStyle(Theme.secondaryText)
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
