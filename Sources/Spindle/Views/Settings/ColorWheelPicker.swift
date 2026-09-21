import AppKit
import SwiftUI

/// An HSB colour wheel: hue around the circumference, saturation from the
/// centre outwards, with brightness on its own slider.
///
/// Drag anywhere on the wheel to pick. The system colour panel is still
/// available alongside it for precise values and eyedropper picking.
struct ColorWheelPicker: View {
    @Binding var color: HexColor
    var diameter: CGFloat = 132

    private var radius: CGFloat { diameter / 2 }

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            wheel
            VStack(alignment: .leading, spacing: 10) {
                brightnessSlider
                preview
            }
        }
    }

    // MARK: - Wheel

    private var wheel: some View {
        ZStack {
            hueRing
            saturationFade
            brightnessShade
            knob
        }
        .frame(width: diameter, height: diameter)
        .contentShape(Circle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in select(at: value.location) }
        )
    }

    private var hueRing: some View {
        Circle().fill(
            AngularGradient(
                colors: stride(from: 0.0, through: 1.0, by: 1.0 / 12.0)
                    .map { Color(hue: $0, saturation: 1, brightness: 1) },
                center: .center
            )
        )
    }

    /// White in the middle fading out, which is the saturation axis.
    private var saturationFade: some View {
        Circle().fill(
            RadialGradient(
                colors: [.white, .white.opacity(0)],
                center: .center,
                startRadius: 0,
                endRadius: radius
            )
        )
    }

    /// Darkens the whole wheel so it previews the chosen brightness.
    private var brightnessShade: some View {
        Circle()
            .fill(.black.opacity(1 - components.brightness))
            .allowsHitTesting(false)
    }

    private var knob: some View {
        Circle()
            .strokeBorder(.white, lineWidth: 2)
            .background(Circle().fill(color.opaqueColor))
            .frame(width: 16, height: 16)
            .shadow(color: .black.opacity(0.5), radius: 2)
            .offset(knobOffset)
            .allowsHitTesting(false)
    }

    private var knobOffset: CGSize {
        let angle = components.hue * 2 * .pi
        let distance = components.saturation * radius
        return CGSize(width: cos(angle) * distance, height: sin(angle) * distance)
    }

    // MARK: - Brightness

    private var brightnessSlider: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Brightness")
                .font(.caption)
                .foregroundStyle(.secondary)
            Slider(
                value: Binding(
                    get: { components.brightness },
                    set: { update(brightness: $0) }
                ),
                in: 0...1
            )
            .frame(width: 130)
        }
    }

    private var preview: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(color.opaqueColor)
                .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(.secondary.opacity(0.4), lineWidth: 1))
                .frame(width: 34, height: 24)
            ColorPicker("", selection: Binding(
                get: { color.opaqueColor },
                set: { color = HexColor(nsColor: NSColor($0), alpha: 1) }
            ), supportsOpacity: false)
            .labelsHidden()
        }
    }

    // MARK: - Colour maths

    /// Hue, saturation and brightness of the bound colour.
    struct Components {
        var hue: Double
        var saturation: Double
        var brightness: Double
    }

    private var components: Components {
        let srgb = color.nsColor.usingColorSpace(.sRGB) ?? color.nsColor
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        srgb.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        return Components(
            hue: Double(hue),
            saturation: Double(saturation),
            brightness: Double(brightness)
        )
    }

    /// Maps a point in the wheel to hue (angle) and saturation (distance).
    private func select(at point: CGPoint) {
        let dx = point.x - radius
        let dy = point.y - radius
        let distance = min(sqrt(dx * dx + dy * dy), radius)

        var angle = atan2(dy, dx)
        if angle < 0 { angle += 2 * .pi }

        apply(
            hue: angle / (2 * .pi),
            saturation: radius > 0 ? distance / radius : 0,
            brightness: max(components.brightness, 0.05)
        )
    }

    private func update(brightness: Double) {
        apply(hue: components.hue, saturation: components.saturation, brightness: brightness)
    }

    private func apply(hue: Double, saturation: Double, brightness: Double) {
        let picked = NSColor(
            hue: CGFloat(hue),
            saturation: CGFloat(saturation),
            brightness: CGFloat(brightness),
            alpha: 1
        )
        color = HexColor(nsColor: picked, alpha: 1)
    }
}
