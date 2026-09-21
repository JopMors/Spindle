import SwiftUI

/// The little equaliser in the corner of the status bar.
///
/// It replaces the play/pause glyph that used to sit there. That glyph showed
/// the same state as the centre button directly below it, and being a familiar
/// symbol it read as a second, broken control. Bars carry the same information
/// and could not be mistaken for something to press: moving means playing.
struct PlayingBars: View {
    let isPlaying: Bool
    let color: Color
    /// Height of the tallest bar.
    let size: CGFloat

    /// Offsets so the bars do not rise and fall as one block.
    private static let phases: [Double] = [0, 0.37, 0.72, 0.19]
    private static let period: Double = 0.9
    /// Fast enough to read as motion rather than steps, slow enough that a
    /// widget sitting on the desktop all day is not redrawing constantly.
    private static let tick: Double = 0.09
    private static let restingHeight: Double = 0.38

    var body: some View {
        if isPlaying {
            TimelineView(.periodic(from: .now, by: Self.tick)) { context in
                bars(at: context.date.timeIntervalSinceReferenceDate)
            }
        } else {
            bars(at: nil)
        }
    }

    /// A paused widget shows the bars at rest, so the space does not jump when
    /// playback stops.
    private func bars(at time: Double?) -> some View {
        HStack(alignment: .bottom, spacing: size * 0.14) {
            ForEach(Self.phases.indices, id: \.self) { index in
                Capsule()
                    .fill(color)
                    .frame(
                        width: size * 0.2,
                        height: size * height(index: index, at: time)
                    )
            }
        }
        .frame(height: size, alignment: .bottom)
    }

    private func height(index: Int, at time: Double?) -> CGFloat {
        guard let time else { return CGFloat(Self.restingHeight) }
        let progress = time / Self.period + Self.phases[index]
        // |sin| rather than sin, so a bar bounces off the floor instead of
        // inverting through it.
        let wave = abs(sin(progress * .pi))
        return CGFloat(Self.restingHeight + (1 - Self.restingHeight) * wave)
    }
}
