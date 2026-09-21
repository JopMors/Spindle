import SwiftUI

/// The scrubber from the original's Now Playing screen: a thin track with elapsed
/// on the left and time remaining, counting down, on the right.
///
/// The elapsed value is extrapolated from the last reading rather than polled,
/// so this only needs a slow tick to stay accurate.
struct PlaybackProgressView: View {
    let elapsed: TimeInterval?
    let duration: TimeInterval?
    let progress: Double?
    let theme: Theme
    let metrics: SpindleMetrics
    /// Seconds from the start of the track. Nil makes the bar a read-out.
    var onSeek: ((TimeInterval) -> Void)?

    /// Where the finger is while dragging, so the bar follows the cursor
    /// instead of snapping back to a now-stale elapsed reading between updates.
    @State private var scrubbing: Double?

    var body: some View {
        VStack(spacing: 1) {
            track
            labels
        }
    }

    private var shownProgress: Double { scrubbing ?? progress ?? 0 }

    private var track: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(theme.screenText.color.opacity(0.25))
                Capsule()
                    .fill(theme.screenText.color.opacity(0.9))
                    .frame(width: geometry.size.width * shownProgress)
            }
            // The bar is a few points tall. Without a taller hit area it is
            // effectively impossible to grab.
            .contentShape(Rectangle().inset(by: -metrics.progressBarHeight * 2))
            // High priority so it beats the tap on the screen behind it,
            // which opens the menu.
            .highPriorityGesture(scrub(in: geometry.size.width))
        }
        .frame(height: metrics.progressBarHeight)
    }

    /// Seeks only on release. Seeking on every frame of the drag floods the
    /// player with requests and makes the audio stutter while you aim.
    private func scrub(in width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard onSeek != nil, duration != nil, width > 0 else { return }
                scrubbing = min(max(value.location.x / width, 0), 1)
            }
            .onEnded { _ in
                defer { scrubbing = nil }
                guard let onSeek, let duration, let target = scrubbing else { return }
                onSeek(target * duration)
            }
    }

    private var labels: some View {
        HStack {
            Text(TimeFormatting.duration(elapsed ?? 0))
            Spacer(minLength: 4)
            if let remaining = TimeFormatting.remaining(elapsed: elapsed, duration: duration) {
                Text(remaining)
            }
        }
        .font(.system(size: metrics.statusFontSize, weight: .medium).monospacedDigit())
        .foregroundStyle(theme.screenSecondaryText.color)
    }
}
