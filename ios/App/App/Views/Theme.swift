import SwiftUI
import UIKit

/// 全局配色。深色/浅色两套都由系统色与固定渐变组成，避免纯白刺眼。
enum Theme {
    static let page = Color(uiColor: .systemGroupedBackground)
    static let card = Color(uiColor: .secondarySystemGroupedBackground)
    // 动态色：浅色模式用更深的色调保证 WCAG AA 对比度（截图目检时
    // 亮青色/亮绿色在浅底上只有 2.1:1），深色模式再提亮。
    static let accent = dynamic(light: (0.03, 0.48, 0.62), dark: (0.36, 0.81, 0.89))
    static let indigo = dynamic(light: (0.22, 0.24, 0.66), dark: (0.52, 0.55, 0.96))
    static let green = dynamic(light: (0.04, 0.45, 0.27), dark: (0.30, 0.84, 0.56))
    static let orange = dynamic(light: (0.63, 0.31, 0.02), dark: (0.98, 0.68, 0.30))
    static let red = dynamic(light: (0.72, 0.12, 0.16), dark: (0.96, 0.42, 0.45))
    /// 中性灰标签（"模拟数据"/"不可连接"）。系统 secondaryLabel 在浅色卡片上
    /// 只有 2.7:1，小字号读不清，这里压深到 4.6:1 以上。
    static let grey = dynamic(light: (0.36, 0.37, 0.40), dark: (0.74, 0.76, 0.80))

    /// 小字号的“次要文字”比系统 secondaryLabel 深一点，保证可读性。
    static let secondaryText = Color.primary.opacity(0.66)
    static let tertiaryText = Color.primary.opacity(0.55)

    static func dynamic(light: (Double, Double, Double), dark: (Double, Double, Double)) -> Color {
        Color(uiColor: UIColor { traits in
            let value = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: value.0, green: value.1, blue: value.2, alpha: 1)
        })
    }

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
                .foregroundStyle(Theme.secondaryText)
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
                    .fill(index < bars ? Theme.accent : Color.secondary.opacity(0.28))
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
                .foregroundStyle(Theme.secondaryText)
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
                    .foregroundStyle(Theme.secondaryText)
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
            .foregroundStyle(Theme.secondaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
    }
}

/// smoke 巡访专用：`AppModel.scrollToBottomTick` 每加一，页面滚到内容末尾。
/// 页面内容末尾需要带 `.id(SmokeScroll.anchorID)`，否则 proxy 找不到锚点。
enum SmokeScroll {
    static let anchorID = "smoke-bottom-anchor"
}

extension View {
    func followSmokeScrollTick(_ tick: Int) -> some View {
        modifier(FollowSmokeScroll(tick: tick))
    }
}

private struct FollowSmokeScroll: ViewModifier {
    let tick: Int

    func body(content: Content) -> some View {
        ScrollViewReader { proxy in
            content
                // 只能监听"变化"，不能用 .task(id:)：页面后出现时 id 已经 >0，
                // 会在展示瞬间就把首屏滚到底，首张截图拍不到页面顶部。
                .onChange(of: tick) { newValue in
                    guard newValue > 0 else { return }
                    // 等页签切换 / 导航推入后的布局稳定再滚
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            proxy.scrollTo(SmokeScroll.anchorID, anchor: .bottom)
                        }
                    }
                }
        }
    }
}
