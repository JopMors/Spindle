import CoreGraphics

/// Layout constants for the widget body, driven by the widget's width.
///
/// Width is the primary dimension because the widget is meant to line up with
/// the macOS widget grid: 155pt matches a small widget (the clock), 329pt a
/// medium one (the calendar). Everything else scales from it.
struct SpindleMetrics {

    /// Width of a standard small macOS widget — the default, so the widget sits
    /// flush under the calendar widget.
    static let smallWidgetWidth: Double = 155
    /// Width of a standard medium macOS widget.
    static let mediumWidgetWidth: Double = 329

    /// The size the proportions were drawn at, and the middle of the preset
    /// ladder. Without it the jump from small to medium is 2.1×, which is a
    /// long way on a 14" screen.
    static let mediumWidth: Double = 224
    static let largeWidth: Double = 275

    static let minWidth: Double = 120
    static let maxWidth: Double = 340

    let bodyWidth: CGFloat

    /// Base dimensions the proportions were designed at.
    private enum Base {
        static let bodyWidth: Double = 224
        static let bodyHeight: Double = 376
        static let bodyPadding: Double = 16
        static let screenHeight: Double = 168
        static let screenCornerRadius: Double = 14
        static let bezelWidth: Double = 5
        static let wheelDiameter: Double = 158
        static let centerButtonDiameter: Double = 60
        static let wheelGlyph: Double = 13
        static let titleFont: Double = 13
        static let artistFont: Double = 11
        static let statusFont: Double = 9
        static let statusBarHeight: Double = 16
        static let progressBarHeight: Double = 4
        static let menuRowHeight: Double = 20
    }

    init(bodyWidth: Double) {
        self.bodyWidth = CGFloat(bodyWidth)
    }

    /// How much the design is scaled from its base size.
    var scale: CGFloat { bodyWidth / CGFloat(Base.bodyWidth) }

    private func value(_ base: Double) -> CGFloat { CGFloat(base) * scale }

    var bodyHeight: CGFloat { value(Base.bodyHeight) }
    var bodyPadding: CGFloat { value(Base.bodyPadding) }
    var screenWidth: CGFloat { bodyWidth - bodyPadding * 2 }
    var screenHeight: CGFloat { value(Base.screenHeight) }
    var screenCornerRadius: CGFloat { value(Base.screenCornerRadius) }
    var bezelWidth: CGFloat { value(Base.bezelWidth) }
    var wheelDiameter: CGFloat { value(Base.wheelDiameter) }
    var centerButtonDiameter: CGFloat { value(Base.centerButtonDiameter) }
    var wheelGlyphSize: CGFloat { value(Base.wheelGlyph) }
    var titleFontSize: CGFloat { value(Base.titleFont) }
    var artistFontSize: CGFloat { value(Base.artistFont) }
    var statusFontSize: CGFloat { value(Base.statusFont) }
    var statusBarHeight: CGFloat { value(Base.statusBarHeight) }
    var progressBarHeight: CGFloat { value(Base.progressBarHeight) }
    var menuRowHeight: CGFloat { value(Base.menuRowHeight) }

    /// Horizontal inset for text drawn on the screen.
    ///
    /// The bezel is an overlay, so it sits on top of whatever the screen is
    /// showing, and the rounded corner cuts further in on the top and bottom
    /// rows. Text has to clear both or its first character vanishes under the
    /// bezel — obvious on skins with a light bezel, invisible on dark ones,
    /// which is why it survived this long. The corner term is the inset needed
    /// at 45° around the arc.
    var screenTextInset: CGFloat { bezelWidth + screenCornerRadius * 0.3 }

    /// The largest body radius the padding can absorb.
    ///
    /// Corners have to be concentric. The screen sits `bodyPadding` inside the
    /// body, so any body radius above `bodyPadding + screenCornerRadius` curves
    /// in past the screen's own corner and cuts it off — most visibly in the
    /// menu, where the screen has a solid background rather than artwork.
    ///
    /// At the small-widget width that ceiling is about 21pt, well under the
    /// 40pt the slider used to offer.
    var maxCornerRadius: CGFloat { bodyPadding + screenCornerRadius }

    /// The requested radius, held to what this width can actually round.
    /// Clamped on the way out rather than on the way in, so widening the widget
    /// again restores the radius the user asked for.
    func cornerRadius(forRequested requested: Double) -> CGFloat {
        min(CGFloat(requested), maxCornerRadius)
    }

    /// Rows that fit in the menu list, once the title bar is taken off.
    var menuVisibleRows: Int {
        max(Int((screenHeight - statusBarHeight) / menuRowHeight), 1)
    }

    /// Tappable region size for each wheel button.
    var wheelButtonSize: CGFloat { (wheelDiameter - centerButtonDiameter) / 2 }

    /// Distance from wheel centre to each button's centre.
    var wheelButtonOffset: CGFloat { (wheelDiameter + centerButtonDiameter) / 4 }

    /// The window is exactly the body: the drop shadow is drawn by the window
    /// server, not reserved inside the content.
    var windowSize: CGSize {
        CGSize(width: bodyWidth, height: bodyHeight)
    }
}
