import SwiftUI
import MediaPlayer

/// 系统音量滑杆。MPVolumeView 是公开 API，改的是系统输出音量；
/// A2DP 的绝对音量会把变化同步到耳机。
struct SystemVolumeSlider: UIViewRepresentable {
    func makeUIView(context: Context) -> MPVolumeView {
        let view = MPVolumeView(frame: .zero)
        view.showsRouteButton = false
        view.setContentHuggingPriority(.defaultLow, for: .horizontal)
        return view
    }

    func updateUIView(_ uiView: MPVolumeView, context: Context) {}
}
