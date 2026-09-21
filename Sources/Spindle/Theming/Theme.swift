import SwiftUI

/// A data-driven skin. Adding a new colourway means adding a `Theme`
/// value to `ThemeCatalog` — no view code changes.
struct Theme: Identifiable, Equatable, Codable {
    let id: String
    let name: String

    /// Body gradient, top to bottom.
    let bodyTop: HexColor
    let bodyBottom: HexColor
    /// Thin outline around the body.
    let bodyBorder: HexColor

    /// Bezel surrounding the screen.
    let screenBezel: HexColor
    /// Shown behind artwork and in the idle state.
    let screenBackground: HexColor
    let screenText: HexColor
    let screenSecondaryText: HexColor

    let wheelTop: HexColor
    let wheelBottom: HexColor
    let wheelBorder: HexColor
    let wheelLabel: HexColor

    let centerButtonTop: HexColor
    let centerButtonBottom: HexColor

    /// True for skins whose body is dark, so shadows and highlights can adapt.
    let isDarkBody: Bool

    /// Glass skins let the wallpaper through: the window puts a blurred
    /// vibrancy layer behind them and the body colours act as a tint rather
    /// than an opaque fill.
    let isGlass: Bool

    /// Declared last with a default so the built-in skins need not restate it.
    var borderWidth: Double = 1
}

/// A `Codable` colour stored as a hex string so themes stay plain data.
///
/// Accepts `RRGGBB` or `RRGGBBAA`. The alpha form is what makes the glass
/// skins expressible as data rather than special-cased in the views.
struct HexColor: Equatable, Codable, ExpressibleByStringLiteral {
    let hex: String

    init(_ hex: String) { self.hex = hex }
    init(stringLiteral value: String) { self.hex = value }

    /// Builds a hex value from a colour, optionally overriding its alpha.
    /// Used by the custom skin editor, where opacity is its own slider.
    init(nsColor: NSColor, alpha: Double? = nil) {
        let srgb = nsColor.usingColorSpace(.sRGB) ?? nsColor
        let components = [srgb.redComponent, srgb.greenComponent, srgb.blueComponent]
        let rgb = components
            .map { String(format: "%02X", Int(($0 * 255).rounded())) }
            .joined()
        let resolved = alpha ?? Double(srgb.alphaComponent)
        let alphaHex = String(format: "%02X", Int((resolved.clamped(to: 0...1) * 255).rounded()))
        self.hex = rgb + alphaHex
    }

    /// The colour with any alpha discarded, for colour wells that edit hue
    /// separately from an opacity slider.
    var opaqueColor: Color {
        let srgb = nsColor.usingColorSpace(.sRGB) ?? nsColor
        return Color(nsColor: NSColor(
            srgbRed: srgb.redComponent,
            green: srgb.greenComponent,
            blue: srgb.blueComponent,
            alpha: 1
        ))
    }

    /// A copy with its HSB brightness replaced, keeping hue, saturation and
    /// alpha. Used to give the colour wheel a stable starting brightness.
    func withBrightness(_ brightness: Double) -> HexColor {
        let srgb = nsColor.usingColorSpace(.sRGB) ?? nsColor
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var current: CGFloat = 0
        var alpha: CGFloat = 0
        srgb.getHue(&hue, saturation: &saturation, brightness: &current, alpha: &alpha)
        let adjusted = NSColor(
            hue: hue,
            saturation: saturation,
            brightness: CGFloat(brightness.clamped(to: 0...1)),
            alpha: alpha
        )
        return HexColor(nsColor: adjusted)
    }

    /// Perceived brightness, used to pick contrasting label colours.
    var brightness: Double {
        let srgb = nsColor.usingColorSpace(.sRGB) ?? nsColor
        return 0.299 * srgb.redComponent + 0.587 * srgb.greenComponent + 0.114 * srgb.blueComponent
    }

    var color: Color {
        Color(nsColor: nsColor)
    }

    var nsColor: NSColor {
        let cleaned = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        guard let value = UInt32(cleaned, radix: 16) else { return .magenta }

        switch cleaned.count {
        case 6:
            return NSColor(
                srgbRed: channel(value >> 16),
                green: channel(value >> 8),
                blue: channel(value),
                alpha: 1.0
            )
        case 8:
            return NSColor(
                srgbRed: channel(value >> 24),
                green: channel(value >> 16),
                blue: channel(value >> 8),
                alpha: channel(value)
            )
        default:
            // Loudly wrong, so a bad hex is obvious in the UI.
            return .magenta
        }
    }

    private func channel(_ shifted: UInt32) -> CGFloat {
        CGFloat(shifted & 0xFF) / 255.0
    }
}

extension Theme {
    var bodyGradient: LinearGradient {
        LinearGradient(
            colors: [bodyTop.color, bodyBottom.color],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    var wheelGradient: LinearGradient {
        LinearGradient(
            colors: [wheelTop.color, wheelBottom.color],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    var centerButtonGradient: LinearGradient {
        LinearGradient(
            colors: [centerButtonTop.color, centerButtonBottom.color],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}
