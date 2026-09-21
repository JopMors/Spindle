import AppKit
import Testing
@testable import Spindle

@Suite("HexColor")
struct HexColorTests {

    private func hsb(_ color: HexColor) -> ColorWheelPicker.Components {
        let srgb = color.nsColor.usingColorSpace(.sRGB) ?? color.nsColor
        var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0, alpha: CGFloat = 0
        srgb.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        return .init(hue: hue, saturation: saturation, brightness: brightness)
    }

    @Test("Sets brightness while keeping hue and saturation")
    func setsBrightnessKeepingHue() {
        // Arrange
        let original: HexColor = "00FF00"

        // Act
        let adjusted = original.withBrightness(0.5)

        // Assert
        let result = hsb(adjusted)
        #expect(abs(result.brightness - 0.5) < 0.01)
        #expect(abs(result.hue - 1.0 / 3.0) < 0.01)
        #expect(abs(result.saturation - 1) < 0.01)
    }

    @Test("Leaves the original colour untouched")
    func doesNotMutateOriginal() {
        let original: HexColor = "1C1C1E"
        _ = original.withBrightness(0.5)
        #expect(original.hex == "1C1C1E")
    }
}
