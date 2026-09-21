import SwiftUI

/// A volume bar you can actually grab.
///
/// The wheel sets volume, which is faithful but invisible: nothing on screen
/// says so. This is the same bar drawn either way — inside the overlay that
/// appears while the wheel turns, and, if you turn it on, permanently under the
/// scrubber.
struct VolumeSlider: View {
    let level: Double
    let theme: Theme
    let metrics: SpindleMetrics
    let width: CGFloat
    /// Nil makes the bar a read-out rather than a control.
    var onScrub: ((Double) -> Void)?

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(theme.screenText.color.opacity(0.28))
                Capsule()
                    .fill(theme.screenText.color)
                    .frame(width: geometry.size.width * clamped(level))
            }
            // The bar is a few points tall; without a bigger hit area it is
            // almost impossible to grab with a mouse.
            .contentShape(Rectangle().inset(by: -metrics.progressBarHeight * 2))
            // High priority so it beats the tap on the screen behind it.
            .highPriorityGesture(scrub(in: geometry.size.width))
        }
        .frame(width: width, height: metrics.progressBarHeight * 1.4)
    }

    /// Jumps to wherever you press and keeps following the cursor, which is how
    /// a slider behaves everywhere else on the system.
    private func scrub(in width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard let onScrub, width > 0 else { return }
                onScrub(clamped(value.location.x / width))
            }
    }

    private func clamped(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }
}
