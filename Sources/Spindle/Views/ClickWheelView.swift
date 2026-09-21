import SwiftUI

/// The click wheel. Centre plays/pauses or selects, left/right skip, top is
/// MENU, and the bottom brings whatever is playing to the front.
///
/// Dragging round the ring scrolls, as the real wheel did: volume on the Now
/// Playing screen, the highlight when a menu is up.
struct ClickWheelView: View {
    let theme: Theme
    let metrics: SpindleMetrics
    let isPlaying: Bool
    let isSelecting: Bool
    let onCommand: (TransportCommand) -> Void
    let onMenu: () -> Void
    let onCenter: () -> Void
    let onOpenSource: () -> Void
    let onRotate: (Double) -> Void
    let onRotateEnded: () -> Void

    @State private var pressed: WheelButton?

    enum WheelButton: Hashable {
        case menu, previous, next, openSource, center
    }

    var body: some View {
        ZStack {
            wheelSurface
                .wheelRotation(
                    diameter: metrics.wheelDiameter,
                    deadZoneRadius: metrics.centerButtonDiameter / 2,
                    onRotate: onRotate,
                    onEnded: onRotateEnded
                )
            buttons
            centerButton
        }
        .frame(width: metrics.wheelDiameter, height: metrics.wheelDiameter)
    }

    private var wheelSurface: some View {
        Circle()
            .fill(theme.wheelGradient)
            .overlay(Circle().strokeBorder(theme.wheelBorder.color, lineWidth: theme.borderWidth))
            .shadow(color: .black.opacity(theme.isDarkBody ? 0.5 : 0.18), radius: 3, y: 2)
    }

    private var buttons: some View {
        ZStack {
            wheelButton(.menu, symbol: nil, label: "MENU")
                .offset(y: -metrics.wheelButtonOffset)
            wheelButton(.previous, symbol: "backward.end.fill", label: nil)
                .offset(x: -metrics.wheelButtonOffset)
            wheelButton(.next, symbol: "forward.end.fill", label: nil)
                .offset(x: metrics.wheelButtonOffset)
            wheelButton(.openSource, symbol: "music.note", label: nil)
                .offset(y: metrics.wheelButtonOffset)
        }
    }

    private func wheelButton(_ button: WheelButton, symbol: String?, label: String?) -> some View {
        Group {
            if let label {
                Text(label)
                    .font(.system(size: metrics.wheelGlyphSize * 0.8, weight: .semibold))
                    .tracking(0.5)
            } else if let symbol {
                Image(systemName: symbol)
                    .font(.system(size: metrics.wheelGlyphSize, weight: .medium))
            }
        }
        .foregroundStyle(theme.wheelLabel.color)
        .frame(width: metrics.wheelButtonSize, height: metrics.wheelButtonSize)
        .contentShape(Rectangle())
        .scaleEffect(pressed == button ? 0.86 : 1)
        .opacity(pressed == button ? 0.55 : 1)
        .pressAction(
            onPress: { press(button) },
            onRelease: { release(button, action: { perform(button) }) }
        )
    }

    private var centerButton: some View {
        Circle()
            .fill(theme.centerButtonGradient)
            .overlay(Circle().strokeBorder(theme.wheelBorder.color.opacity(0.7), lineWidth: theme.borderWidth))
            .frame(width: metrics.centerButtonDiameter, height: metrics.centerButtonDiameter)
            .overlay(centerGlyph)
            .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
            .scaleEffect(pressed == .center ? 0.93 : 1)
            .pressAction(
                onPress: { press(.center) },
                onRelease: { release(.center, action: onCenter) }
            )
    }

    /// Becomes the select glyph in a menu, where centre no longer plays.
    private var centerGlyph: some View {
        Image(systemName: isSelecting ? "circle.fill" : (isPlaying ? "pause.fill" : "play.fill"))
            .font(.system(size: metrics.wheelGlyphSize * (isSelecting ? 0.5 : 1.1), weight: .semibold))
            .foregroundStyle(theme.wheelLabel.color.opacity(0.75))
            .contentTransition(.symbolEffect(.replace))
    }

    // MARK: - Interaction

    private func press(_ button: WheelButton) {
        withAnimation(.spring(response: 0.16, dampingFraction: 0.6)) { pressed = button }
    }

    private func release(_ button: WheelButton, action: () -> Void) {
        withAnimation(.spring(response: 0.24, dampingFraction: 0.7)) { pressed = nil }
        action()
    }

    private func perform(_ button: WheelButton) {
        switch button {
        case .menu: onMenu()
        case .previous: onCommand(.previousTrack)
        case .next: onCommand(.nextTrack)
        case .openSource: onOpenSource()
        case .center: onCenter()
        }
    }
}

private extension View {
    /// Fires `onPress` as soon as the finger lands and `onRelease` on lift,
    /// which reads far more like a physical button than `Button` does.
    func pressAction(onPress: @escaping () -> Void, onRelease: @escaping () -> Void) -> some View {
        modifier(PressActionModifier(onPress: onPress, onRelease: onRelease))
    }
}

private struct PressActionModifier: ViewModifier {
    let onPress: () -> Void
    let onRelease: () -> Void

    @State private var isPressed = false

    func body(content: Content) -> some View {
        content.gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    guard !isPressed else { return }
                    isPressed = true
                    onPress()
                }
                .onEnded { _ in
                    isPressed = false
                    onRelease()
                }
        )
    }
}
