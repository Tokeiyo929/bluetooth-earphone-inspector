import SwiftUI
import UIKit

/// 全局配色。深色/浅色两套都由系统色与固定渐变组成，避免纯白刺眼。
enum Theme {
    static let page = Color(uiColor: .systemGroupedBackground)
    static let card = Color(uiColor: .secondarySystemGroupedBackground)
    static let accent = Color(red: 0.10, green: 0.74, blue: 0.90)
    static let indigo = Color(red: 0.35, green: 0.36, blue: 0.92)
    static let green = Color(red: 0.16, green: 0.76, blue: 0.46)
    static let orange = Color(red: 0.98, green: 0.60, blue: 0.18)
    static let red = Color(red: 0.94, green: 0.30, blue: 0.34)

    static func tone(_ name: String) -> Color {
        switch name {
        case "a2dp": return accent
        case "hfp": return orange
        case "le": return green
        default: return Color(uiColor: .secondaryLabel)
        }
    }

    static func gradient(_ tone: String) -> LinearGradient {
        let colors: [Color]
        switch tone {
        case "a2dp":
            colors = [Color(red: 0.05, green: 0.16, blue: 0.30), Color(red: 0.04, green: 0.45, blue: 0.55)]
        case "hfp":
            colors = [Color(red: 0.24, green: 0.12, blue: 0.06), Color(red: 0.62, green: 0.28, blue: 0.08)]
        case "le":
            colors = [Color(red: 0.04, green: 0.20, blue: 0.15), Color(red: 0.05, green: 0.42, blue: 0.35)]
        default:
            colors = [Color(red: 0.12, green: 0.14, blue: 0.21), Color(red: 0.22, green: 0.25, blue: 0.34)]
        }
        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

extension View {
    /// 统一圆角卡片。
    func card(padding: CGFloat = 16) -> some View {
        self
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.05), lineWidth: 1)
            )
    }

    func pageBackground() -> some View {
        background(Theme.page.ignoresSafeArea())
    }
}

struct Badge: View {
    let text: String
    var color: Color = Theme.accent
    var filled: Bool = false

    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(filled ? color : color.opacity(0.14))
            .foregroundStyle(filled ? Color.white : color)
            .clipShape(Capsule())
            .fixedSize(horizontal: true, vertical: false)
    }
}

struct InfoRow: View {
    let title: String
    let value: String
    var titleWidth: CGFloat = 84

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text(title)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(width: titleWidth, alignment: .leading)
            Text(value)
                .font(.footnote)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
    }
}

struct SignalBars: View {
    let bars: Int

    var body: some View {
        HStack(alignment: .bottom, spacing: 2.5) {
            ForEach(0..<4) { index in
                Capsule()
                    .fill(index < bars ? Theme.accent : Color.secondary.opacity(0.22))
                    .frame(width: 3.5, height: CGFloat(5 + index * 3))
            }
        }
        .frame(height: 14)
        .accessibilityLabel("信号 \(bars) 格")
    }
}

struct BatteryBar: View {
    let percent: Int?
    var color: Color = Theme.green

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.secondary.opacity(0.18))
                Capsule()
                    .fill(batteryColor)
                    .frame(width: geometry.size.width * CGFloat(percent ?? 0) / 100)
            }
        }
        .frame(height: 6)
    }

    private var batteryColor: Color {
        guard let percent else { return Color.secondary.opacity(0.4) }
        if percent <= 20 { return Theme.red }
        if percent <= 40 { return Theme.orange }
        return color
    }
}

struct BudBatteryRow: View {
    let title: String
    let percent: Int?
    let charging: Bool

    var body: some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 52, alignment: .leading)
            BatteryBar(percent: percent)
            Text(AppleAdvertisement.percentText(percent))
                .font(.caption.monospacedDigit().weight(.semibold))
                .frame(width: 40, alignment: .trailing)
            Image(systemName: charging ? "bolt.fill" : "bolt.slash")
                .font(.caption2)
                .foregroundStyle(charging ? Theme.green : Color.secondary.opacity(0.35))
        }
    }
}

struct DemoBanner: View {
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.footnote)
                .foregroundStyle(Theme.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text("演示数据")
                    .font(.footnote.weight(.semibold))
                Text("模拟器没有蓝牙硬件；装到 iPhone 后显示真实扫描结果。")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .card(padding: 12)
    }
}

struct SectionHeader: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
    }
}
