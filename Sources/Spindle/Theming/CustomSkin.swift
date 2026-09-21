import AppKit

/// The user-editable skin.
///
/// Rather than exposing all thirteen theme colours, a handful of knobs derive a
/// complete, coherent `Theme`. That keeps the settings panel usable and means
/// the views still consume a plain `Theme` like any built-in skin.
struct CustomSkin: Equatable, Codable {

    static let themeID = "custom"
    static let themeName = "Custom"

    /// Base colour of the body.
    var tint: HexColor = "1C1C1E"
    var bodyOpacity: Double = 0.55

    var borderColor: HexColor = "FFFFFF"
    var borderOpacity: Double = 0.15
    var borderWidth: Double = 1

    /// Opacity of the click wheel surface.
    var wheelOpacity: Double = 0.15
    /// How much the screen is darkened behind the artwork.
    var screenOpacity: Double = 0.45
    /// Strength of the scrim behind the title text.
    var textScrimOpacity: Double = 0.75

    /// Whether the wallpaper is blurred behind the body.
    var isGlass: Bool = true

    // MARK: - Derived theme

    var theme: Theme {
        let base = tint.nsColor
        let isDark = tint.brightness < 0.55
        let label = isDark ? NSColor.white : NSColor.black

        return Theme(
            id: Self.themeID,
            name: Self.themeName,
            bodyTop: HexColor(nsColor: base, alpha: bodyOpacity),
            bodyBottom: HexColor(nsColor: shaded(base), alpha: bodyOpacity),
            bodyBorder: HexColor(nsColor: borderColor.nsColor, alpha: borderOpacity),
            screenBezel: HexColor(nsColor: label, alpha: 0.08),
            screenBackground: HexColor(nsColor: .black, alpha: screenOpacity),
            screenText: "FFFFFF",
            screenSecondaryText: "FFFFFFB3",
            wheelTop: HexColor(nsColor: label, alpha: wheelOpacity),
            wheelBottom: HexColor(nsColor: label, alpha: wheelOpacity * 0.55),
            wheelBorder: HexColor(nsColor: label, alpha: min(1, wheelOpacity * 1.4)),
            wheelLabel: HexColor(nsColor: label, alpha: 0.85),
            centerButtonTop: HexColor(nsColor: label, alpha: min(1, wheelOpacity * 1.5)),
            centerButtonBottom: HexColor(nsColor: label, alpha: wheelOpacity * 0.8),
            isDarkBody: isDark,
            isGlass: isGlass,
            borderWidth: borderWidth
        )
    }

    /// Slightly darker variant, so the body keeps a gradient rather than
    /// reading as one flat fill.
    private func shaded(_ color: NSColor) -> NSColor {
        let srgb = color.usingColorSpace(.sRGB) ?? color
        return srgb.blended(withFraction: 0.35, of: .black) ?? srgb
    }
}
