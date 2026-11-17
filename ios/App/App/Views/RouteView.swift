import Combine
import SwiftUI
import UIKit

struct RouteView: View {
    @EnvironmentObject var app: AppModel
    @EnvironmentObject var routeModel: AudioRouteModel
    @State private var systemVolume: Float = AVAudioSession.sharedInstance().outputVolume

    private var verdict: ProtocolVerdict { routeModel.verdict }
    private var snapshot: AudioRouteSnapshot { routeModel.snapshot }
    private var detailRows: [(String, String)] { RouteAnalyzer.detailRows(snapshot) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if app.demoMode { DemoBanner() }
                    hero
                    detailCard
                    volumeCard
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

    // MARK: - 音量与控制边界

    private var volumeCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.subheadline)
                    .foregroundStyle(Theme.accent)
                Text("耳机音量").font(.headline)
                Spacer(minLength: 4)
                Text(snapshot.hasBluetoothOutput ? "A2DP 绝对音量" : "系统输出音量")
                    .font(.caption2)
                    .foregroundStyle(Theme.secondaryText)
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

            Text("拖动滑杆调节系统音量。走 A2DP 时，iPhone 会把音量同步给耳机（绝对音量协议），"
                + "所以这副滑杆实际控制的就是耳机音量。")
                .font(.caption2)
                .foregroundStyle(Theme.secondaryText)
                .lineSpacing(2)

            Divider()

            Text("控制边界")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.secondaryText)
            Text("播放/暂停/切歌由蓝牙 AVRCP 交给系统与耳机按键；"
                + "降噪、通透、EQ、固件升级属于厂商私有 BLE 协议，iOS 没有统一 API。"
                + "本 App 能直接发的是「音量」；耳机若暴露标准 MCS，详情页还能发播放控制。")
                .font(.caption2)
                .foregroundStyle(Theme.tertiaryText)
                .lineSpacing(2)
        }
        .card()
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
