import AppKit

/// Borderless, transparent panel that hosts the widget.
///
/// A panel rather than a window so it can take clicks without stealing focus
/// from whatever the user is actually working in.
final class FloatingPanel: NSPanel {

    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        isOpaque = false
        backgroundColor = .clear
        isMovableByWindowBackground = true
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        animationBehavior = .utilityWindow

        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
    }

    /// Borderless panels refuse key status by default, which would stop the
    /// click wheel from receiving mouse events.
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    func apply(placement: AppSettings.Placement) {
        level = Self.level(for: placement)
        // On the desktop the widget reads as part of the wallpaper, so it gets
        // only the soft shadow the stock widgets have.
        hasShadow = true
    }

    private static func level(for placement: AppSettings.Placement) -> NSWindow.Level {
        switch placement {
        case .floating:
            return .floating
        case .normal:
            return .normal
        case .desktop:
            // Just above the desktop icons: behind every app window, but still
            // in front of Finder's desktop so clicks reach the click wheel.
            let desktopIcons = CGWindowLevelForKey(.desktopIconWindow)
            return NSWindow.Level(rawValue: Int(desktopIcons) + 1)
        }
    }
}
