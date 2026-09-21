import AppKit
import Combine
import SwiftUI

/// Owns the floating panel: sizing, placement, glass backing and position
/// persistence.
@MainActor
final class WidgetWindowController: NSObject, NSWindowDelegate {

    private let settings: AppSettings
    private let viewModel: NowPlayingViewModel
    private let device: SpindleViewModel

    private var panel: FloatingPanel?
    private var glassBacking: GlassBackingView?
    private var cancellables = Set<AnyCancellable>()

    private enum Key {
        static let originX = "widget.origin.x"
        static let originY = "widget.origin.y"
    }

    /// Gap from the screen edge used when no saved position exists.
    private static let defaultInset: CGFloat = 40

    init(settings: AppSettings, viewModel: NowPlayingViewModel, device: SpindleViewModel) {
        self.settings = settings
        self.viewModel = viewModel
        self.device = device
        super.init()
        observeSettings()
    }

    var isVisible: Bool { panel?.isVisible ?? false }

    // MARK: - Presentation

    func show() {
        let panel = panel ?? makePanel()
        self.panel = panel
        applyCurrentSettings(to: panel)
        panel.orderFrontRegardless()
        Diagnostics.log("""
            shown at \(panel.frame) placement=\(settings.placement.rawValue) \
            locked=\(settings.isPositionLocked) movable=\(panel.isMovableByWindowBackground) \
            skin=\(settings.theme.id)
            """)
    }

    func hide() {
        panel?.orderOut(nil)
    }

    func toggle() {
        if isVisible {
            hide()
        } else {
            show()
        }
    }

    private func makePanel() -> FloatingPanel {
        let size = settings.metrics.windowSize
        let panel = FloatingPanel(contentRect: NSRect(origin: .zero, size: size))
        panel.delegate = self

        let container = NSView(frame: NSRect(origin: .zero, size: size))
        container.autoresizingMask = [.width, .height]

        let backing = GlassBackingView(
            cornerRadius: settings.metrics.cornerRadius(forRequested: settings.cornerRadius)
        )
        backing.frame = container.bounds
        backing.autoresizingMask = [.width, .height]
        container.addSubview(backing)
        glassBacking = backing

        let hosting = WidgetHostingView(rootView: rootView)
        hosting.frame = container.bounds
        hosting.autoresizingMask = [.width, .height]
        hosting.onScroll = { [weak device] amount in device?.wheelScrolled(by: amount) }
        hosting.onScrollEnded = { [weak device] in device?.resetWheelTravel() }
        container.addSubview(hosting)

        panel.contentView = container
        panel.setFrameOrigin(restoredOrigin(for: size))
        return panel
    }

    private var rootView: some View {
        SpindleView(viewModel: viewModel, settings: settings, device: device)
    }

    /// Pushes the whole settings state onto the window. Cheap and idempotent,
    /// so it can simply run whenever anything changes.
    private func applyCurrentSettings(to panel: FloatingPanel) {
        panel.apply(placement: settings.placement)
        panel.isMovableByWindowBackground = !settings.isPositionLocked
        panel.alphaValue = settings.overallOpacity

        glassBacking?.isHidden = !settings.theme.isGlass
        glassBacking?.update(
            cornerRadius: settings.metrics.cornerRadius(forRequested: settings.cornerRadius)
        )

        let size = settings.metrics.windowSize
        if abs(panel.frame.width - size.width) > 0.5 || abs(panel.frame.height - size.height) > 0.5 {
            resize(to: size)
        }
    }

    // MARK: - Settings reactions

    private func observeSettings() {
        // `theme` is derived from several stored properties, so observing each
        // one individually would miss custom-skin edits. One coalesced apply on
        // any change is simpler and cannot fall out of sync.
        settings.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                guard let self, let panel = self.panel else { return }
                self.applyCurrentSettings(to: panel)
            }
            .store(in: &cancellables)
    }

    /// Grows or shrinks around the top-left corner, so the widget does not
    /// appear to drift while the size slider moves.
    private func resize(to size: CGSize) {
        guard let panel else { return }
        let frame = panel.frame
        let origin = NSPoint(x: frame.minX, y: frame.maxY - size.height)
        panel.setFrame(NSRect(origin: origin, size: size), display: true, animate: false)
        persistOrigin(origin)
    }

    // MARK: - Position persistence

    func windowDidMove(_ notification: Notification) {
        guard let panel else { return }
        persistOrigin(panel.frame.origin)
    }

    private func persistOrigin(_ origin: NSPoint) {
        let defaults = UserDefaults.standard
        defaults.set(Double(origin.x), forKey: Key.originX)
        defaults.set(Double(origin.y), forKey: Key.originY)
    }

    private func restoredOrigin(for size: CGSize) -> NSPoint {
        let defaults = UserDefaults.standard
        guard let x = defaults.object(forKey: Key.originX) as? Double,
              let y = defaults.object(forKey: Key.originY) as? Double else {
            return defaultOrigin(for: size)
        }

        let origin = NSPoint(x: x, y: y)
        // A display may have been disconnected since the position was saved.
        let isOnScreen = NSScreen.screens.contains { screen in
            screen.visibleFrame.intersects(NSRect(origin: origin, size: size))
        }
        return isOnScreen ? origin : defaultOrigin(for: size)
    }

    /// Middle of the left edge, which is where the widget is meant to live.
    private func defaultOrigin(for size: CGSize) -> NSPoint {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else {
            return NSPoint(x: 200, y: 200)
        }
        let visible = screen.visibleFrame
        return NSPoint(
            x: visible.minX + Self.defaultInset,
            y: visible.midY - size.height / 2
        )
    }
}
