import AppKit
import SwiftUI

/// Hosting view that responds to the very first click.
///
/// The widget belongs to a background agent app, so clicking it is almost
/// always a "first mouse" event — another app has focus. By default AppKit
/// swallows that click to focus the window, which would make every wheel
/// button need two clicks. Accepting it keeps the wheel feeling physical.
final class WidgetHostingView<Content: View>: NSHostingView<Content> {

    /// Scrolling anywhere on the body turns the wheel. SwiftUI has no scroll
    /// hook on macOS, and a sibling AppKit catcher cannot have one either — a
    /// view that refuses hit testing to stay click-through stops receiving
    /// scroll events as well. Unhandled scrolls bubble up the responder chain
    /// to here, which is the one place that sees all of them.
    var onScroll: ((Double) -> Void)?
    /// Fires when the gesture finishes, so partial travel can be discarded.
    var onScrollEnded: (() -> Void)?

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    /// ⌘-drag always moves the widget, lock or no lock.
    ///
    /// Without it, a locked widget can only be moved by finding the toggle in
    /// Settings first — which is exactly the complaint. The modifier is claimed
    /// before SwiftUI sees the event, so it works over the wheel and the screen
    /// as well as the bare body.
    override func mouseDown(with event: NSEvent) {
        guard event.modifierFlags.contains(.command) else {
            super.mouseDown(with: event)
            return
        }
        window?.performDrag(with: event)
    }

    override func scrollWheel(with event: NSEvent) {
        guard let amount = ScrollNormalisation.amount(for: event) else {
            super.scrollWheel(with: event)
            return
        }
        onScroll?(amount)
        if event.phase == .ended || event.momentumPhase == .ended {
            onScrollEnded?()
        }
    }

    @MainActor @preconcurrency
    required init(rootView: Content) {
        super.init(rootView: rootView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used; the widget is built in code")
    }
}
