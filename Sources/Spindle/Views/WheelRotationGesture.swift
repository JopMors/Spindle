import AppKit
import SwiftUI

/// Turns a circular drag over the wheel into scroll amounts.
///
/// The original's wheel measured *angle*, not distance, so dragging across the ring
/// gives a different result depending on where you start. Tracking the angle
/// from the wheel's centre reproduces that: a slow arc near the top edge and a
/// fast one near the bottom both advance by the same amount for the same sweep.
struct WheelRotationGesture: ViewModifier {
    let diameter: CGFloat
    /// Ignore drags that land on the centre button, which is a plain press.
    let deadZoneRadius: CGFloat
    let onRotate: (Double) -> Void
    let onEnded: () -> Void

    @State private var lastAngle: Double?

    /// Scroll units per radian, chosen so a quarter turn is roughly a detent
    /// per 15°, close to the real wheel's resolution.
    private static let unitsPerRadian: Double = 12

    func body(content: Content) -> some View {
        content.gesture(
            DragGesture(minimumDistance: 2)
                .onChanged { value in track(value.location) }
                .onEnded { _ in
                    lastAngle = nil
                    onEnded()
                }
        )
    }

    private func track(_ location: CGPoint) {
        let centre = CGPoint(x: diameter / 2, y: diameter / 2)
        let dx = location.x - centre.x
        let dy = location.y - centre.y
        guard hypot(dx, dy) > deadZoneRadius else { return }

        let angle = atan2(dy, dx)
        defer { lastAngle = angle }
        guard let lastAngle else { return }

        // Unwrap across the ±π seam, otherwise one drag past the top of the
        // wheel reads as a full turn backwards.
        var delta = angle - lastAngle
        if delta > .pi { delta -= 2 * .pi }
        if delta < -.pi { delta += 2 * .pi }

        onRotate(delta * Self.unitsPerRadian)
    }
}

extension View {
    func wheelRotation(
        diameter: CGFloat,
        deadZoneRadius: CGFloat,
        onRotate: @escaping (Double) -> Void,
        onEnded: @escaping () -> Void
    ) -> some View {
        modifier(WheelRotationGesture(
            diameter: diameter,
            deadZoneRadius: deadZoneRadius,
            onRotate: onRotate,
            onEnded: onEnded
        ))
    }
}

/// Normalises a scroll event into the wheel's own units.
///
/// A trackpad reports many small precise deltas per flick while a notched mouse
/// reports a few large ones, so the two are scaled to meet in the middle.
enum ScrollNormalisation {
    private static let preciseScale: Double = 0.6
    private static let notchedScale: Double = 3

    static func amount(for event: NSEvent) -> Double? {
        // Vertical or horizontal, whichever moved: a click wheel has no axis.
        let delta = event.scrollingDeltaY != 0 ? event.scrollingDeltaY : event.scrollingDeltaX
        guard delta != 0 else { return nil }
        return Double(delta) * (event.hasPreciseScrollingDeltas ? preciseScale : notchedScale)
    }
}
