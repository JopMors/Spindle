import AppKit

/// Rounded vibrancy layer that sits behind the SwiftUI body.
///
/// SwiftUI's `Material` blurs its own window's backdrop, which is not what a
/// desktop widget needs. `NSVisualEffectView` with `.behindWindow` blending
/// blurs whatever is actually behind the window — the wallpaper — which is how
/// the stock widgets get their look.
final class GlassBackingView: NSVisualEffectView {

    init(cornerRadius: CGFloat) {
        super.init(frame: .zero)
        material = .hudWindow
        blendingMode = .behindWindow
        // Keep the blur alive even when the app is not frontmost; a desktop
        // widget is never frontmost.
        state = .active
        wantsLayer = true
        layer?.cornerRadius = cornerRadius
        layer?.cornerCurve = .continuous
        layer?.masksToBounds = true
        maskImage = nil
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used; the widget is built in code")
    }

    func update(cornerRadius: CGFloat) {
        layer?.cornerRadius = cornerRadius
    }
}
