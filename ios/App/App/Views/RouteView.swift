import AVFAudio
import Combine
import SwiftUI
import UIKit

struct RouteView: View {
    @EnvironmentObject var app: AppModel
    @EnvironmentObject var routeModel: AudioRouteModel
    @EnvironmentObject var ble: BLEModel
    @State private var systemVolume: Float = AVAudioSession.sharedInstance().outputVolume
    @State private var isPlaying = false

    private var verdict: ProtocolVerdict { routeModel.verdict }
    private var snapshot: AudioRouteSnapshot { routeModel.snapshot }
    private var detailRows: [(String, String)] { RouteAnalyzer.detailRows(snapshot) }

    private var versionHint: VersionHint {
        VersionAnalyzer.hint(for: snapshot, leAudioOverBLE: bleLEAudioEvidence)
    }

    /// 只认当前链路这台设备；旁边另一副 LE Audio 耳机不能替它作证。
    private var relevantPeripherals: [PeripheralSnapshot] {
        ControlAnalyzer.relevantPeripherals(in: ble.peripherals,
                                            routeName: snapshot.bluetoothOutput?.name)
    }

    private var bleLEAudioEvidence: Bool {
        guard snapshot.hasBluetoothOutput else { return false }
        return relevantPeripherals.contains { ControlAnalyzer.hasLEAudio($0) }
    }

    private var controls: ControlCapabilities {
        ControlAnalyzer.capabilities(in: relevantPeripherals)
    }

    private var mcsDevice: PeripheralSnapshot? {
        ControlAnalyzer.mcsPeripheral(in: relevantPeripherals)
    }

    private var heroVersionText: String {
        versionHint.verified ? "5.2 已确认" : "5.2 未验证"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if app.demoMode { DemoBanner() }
                    hero
                    controlCard
                    versionCard
                    detailCard
                    evidenceCard
                    footer
                }
                .padding(16)
                .padding(.bottom, 24)
                .id(SmokeScroll.anchorID)
            }
            .pageBackground()
            .navigationTitle("当前链路")
            .navigationBarTitleDisplayMode(.inline)
            .refreshable { app.refreshAll() }
            .followSmokeScrollTick(app.scrollToBottomTick)
        }
    }

    // MARK: - 结论卡

    private var hero: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                ZStack {
                    Circle().fill(Color.white.opacity(0.18)).frame(width: 40, height: 40)
                    Image(systemName: verdict.icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("当前音频链路")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.white.opacity(0.72))
                    Text(verdict.layer)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.55))
                }
                Spacer()
                HStack(spacing: 5) {
                    Circle()
                        .fill(verdict.isBluetoothActive ? Theme.green : Color.white.opacity(0.4))
                        .frame(width: 6, height: 6)
                    Text(verdict.isBluetoothActive ? "实时" : "待连接")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white.opacity(0.9))
                }
            }

            Text(verdict.title)
                .font(.system(size: 29, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                Text(verdict.profileCode)
                    .font(.system(.footnote, design: .monospaced).weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.2))
                    .clipShape(Capsule())
                Text(verdict.badge)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.88))
                Spacer(minLength: 6)
                // 5.2 结论直接放在结论卡上，不用往下翻
                Text(heroVersionText)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(versionHint.verified ? 0.30 : 0.16))
                    .clipShape(Capsule())
            }

            Text(verdict.summary)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.92))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .background(Theme.gradient(verdict.tone))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: Theme.tone(verdict.tone).opacity(0.28), radius: 18, y: 8)
        .accessibilityElement(children: .combine)
    }

    // MARK: - 明细

    private var detailCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("路由明细").font(.headline)
                Spacer()
                if let updated = routeModel.lastUpdated {
                    Text("更新 \(Self.timeFormatter.string(from: updated))")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(Theme.secondaryText)
                }
            }
            ForEach(detailRows.indices, id: \.self) { index in
                InfoRow(title: detailRows[index].0, value: detailRows[index].1)
            }
            Divider()
            Text("来源：AVAudioSession.currentRoute / availableInputs")
                .font(.caption2)
                .foregroundStyle(Theme.secondaryText)
        }
        .card()
    }

    // MARK: - 蓝牙版本 5.2？

    private var versionCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "number")
                    .font(.subheadline)
                    .foregroundStyle(versionHint.verified ? Theme.green : Theme.orange)
                Text("蓝牙版本 5.2？").font(.headline)
                Spacer(minLength: 4)
                Badge(text: versionHint.badge,
                      color: versionHint.verified ? Theme.green : Theme.orange)
            }

            Text(versionHint.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.primary)

            ForEach(versionHint.evidence.indices, id: \.self) { index in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: versionHint.verified
                          ? "checkmark.circle.fill" : "exclamationmark.circle")
                        .font(.caption)
                        .foregroundStyle(versionHint.verified ? Theme.green : Theme.orange)
                        .padding(.top, 1)
                    Text(versionHint.evidence[index])
                        .font(.caption)
                        .foregroundStyle(Theme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Divider()
            Text(versionHint.action)
                .font(.caption2)
                .foregroundStyle(Theme.tertiaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .card()
    }

    // MARK: - 控制台（所有能调的功能）

    private var controlCard: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(spacing: 8) {
                Image(systemName: "slider.horizontal.3")
                    .font(.subheadline)
                    .foregroundStyle(Theme.accent)
                Text("控制台").font(.headline)
                Spacer(minLength: 4)
                Badge(text: controls.mediaTransportAvailable ? "MCS 可写" : "音量可调",
                      color: controls.mediaTransportAvailable ? Theme.green : Theme.accent)
            }

            HStack(spacing: 10) {
                Image(systemName: "speaker.fill")
                    .font(.caption2)
                    .foregroundStyle(Theme.tertiaryText)
                SystemVolumeSlider()
                    .frame(height: 30)
                Text("\(Int((systemVolume * 100).rounded()))%")
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(Theme.secondaryText)
                    .frame(width: 40, alignment: .trailing)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            // MPVolumeView 在模拟器里不画轨道，给它垫一层可见面板，
            // 免得看着像一条空白
            .background(Color.primary.opacity(0.045))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.07), lineWidth: 1)
            )
            .onReceive(Self.volumePublisher) { systemVolume = $0 }

            HStack(spacing: 10) {
                transportButton("backward.fill", enabled: controls.mediaTransportAvailable) {
                    guard let device = mcsDevice else { return }
                    ble.writeMediaControl(0x04, peripheralID: device.id)
                }
                transportButton(isPlaying ? "pause.fill" : "play.fill",
                                enabled: controls.mediaTransportAvailable) {
                    guard let device = mcsDevice else { return }
                    let opcode: UInt8 = isPlaying ? 0x02 : 0x01
                    isPlaying.toggle()
                    ble.writeMediaControl(opcode, peripheralID: device.id)
                }
                transportButton("forward.fill", enabled: controls.mediaTransportAvailable) {
                    guard let device = mcsDevice else { return }
                    ble.writeMediaControl(0x05, peripheralID: device.id)
                }
            }

            if let message = ble.controlMessage {
                Text(message)
                    .font(.caption2)
                    .foregroundStyle(Theme.secondaryText)
            }

            if !controls.mediaTransportAvailable {
                Text("没有发现标准 MCS 控制点（0x2BA4）：这三个按钮置灰，"
                    + "播放/暂停仍可用锁屏或耳机按键——iOS 没给第三方 App 发送 AVRCP 的 API。")
                    .font(.caption2)
                    .foregroundStyle(Theme.tertiaryText)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()

            capabilityRow(title: "音量",
                          available: controls.volumeAvailable,
                          status: controls.volumeAvailable ? "可用" : "不可用",
                          detail: controls.volumeDetail,
                          tone: Theme.green)
            capabilityRow(title: "播放 / 暂停 / 切歌",
                          available: controls.mediaTransportAvailable,
                          status: controls.mediaTransportAvailable ? "App 可直控" : "系统 AVRCP",
                          detail: controls.mediaTransportDetail,
                          tone: controls.mediaTransportAvailable ? Theme.green : Theme.orange)
            capabilityRow(title: "降噪 / 通透 / EQ",
                          available: controls.noiseControlAvailable,
                          status: "厂商 App",
                          detail: controls.noiseControlDetail,
                          tone: Theme.orange)
            capabilityRow(title: "厂商私有通道",
                          available: controls.vendorWritableCount > 0,
                          status: controls.vendorWritableCount > 0
                            ? "\(controls.vendorWritableCount) 个可写" : "无",
                          detail: controls.vendorWritableDetail,
                          tone: Theme.indigo)
        }
        .card()
    }

    private func transportButton(_ systemName: String,
                                 enabled: Bool,
                                 action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(enabled ? Theme.accent : Theme.tertiaryText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background((enabled ? Theme.accent : Theme.grey).opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    private func capabilityRow(title: String,
                               available: Bool,
                               status: String,
                               detail: String,
                               tone: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Image(systemName: available ? "checkmark.circle.fill" : "minus.circle")
                    .font(.caption2)
                    .foregroundStyle(tone)
                Text(title)
                    .font(.caption.weight(.semibold))
                Spacer(minLength: 4)
                Text(status)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(tone)
            }
            Text(detail)
                .font(.caption2)
                .foregroundStyle(Theme.tertiaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 2)
    }

    private var evidenceCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("判定依据").font(.headline)
            ForEach(verdict.evidence.indices, id: \.self) { index in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(Theme.tone(verdict.tone))
                        .padding(.top, 1)
                    Text(verdict.evidence[index])
                        .font(.footnote)
                        .foregroundStyle(Theme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Divider()
            Text(verdict.codecNote)
                .font(.caption)
                .foregroundStyle(Theme.secondaryText)
                .lineSpacing(2)
        }
        .card()
    }

    private var footer: some View {
        VStack(spacing: 10) {
            Button {
                app.refreshAll()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise")
                    Text("重新检测")
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.accent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(Theme.card)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)

            Button {
                openSettings()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "gearshape")
                    Text("打开系统设置")
                }
                .font(.footnote.weight(.medium))
                .foregroundStyle(Theme.secondaryText)
            }
            .buttonStyle(.plain)

            if let note = routeModel.sessionNote {
                Text(note)
                    .font(.caption2)
                    .foregroundStyle(Theme.secondaryText)
                    .multilineTextAlignment(.center)
            }

            Text("构建 \(buildNumber) · 蓝牙耳机协议观察器")
                .font(.caption2)
                .foregroundStyle(Theme.tertiaryText)
        }
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hans_CN")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    /// outputVolume 是 KVO 可观察的公开属性；拖滑杆时同步刷新百分比。
    private static let volumePublisher = AVAudioSession.sharedInstance()
        .publisher(for: \.outputVolume)

    private var buildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "BTBuild") as? String ?? "dev"
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
