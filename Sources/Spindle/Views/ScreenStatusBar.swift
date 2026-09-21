import SwiftUI

/// The strip across the top of every screen: playback state on the left,
/// shuffle and repeat on the right. On the real device this also carried the
/// battery; here the left slot doubles as the screen's title when browsing.
struct ScreenStatusBar: View {
    let title: String?
    let isPlaying: Bool
    let showsPlaybackGlyph: Bool
    let shuffle: ShuffleMode
    let repeatMode: RepeatMode
    let theme: Theme
    let metrics: SpindleMetrics

    var body: some View {
        HStack(spacing: 4) {
            if showsPlaybackGlyph {
                PlayingBars(
                    isPlaying: isPlaying,
                    color: theme.screenText.color.opacity(0.9),
                    size: metrics.statusFontSize * 0.9
                )
            }
            if let title {
                Text(title)
                    .font(.system(size: metrics.statusFontSize, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            Spacer(minLength: 2)
            modeGlyphs
        }
        .foregroundStyle(theme.screenText.color.opacity(0.9))
        .padding(.horizontal, metrics.screenTextInset)
        .frame(height: metrics.statusBarHeight)
    }

    private var modeGlyphs: some View {
        HStack(spacing: 3) {
            if shuffle.isOn {
                Image(systemName: "shuffle")
            }
            if let symbol = repeatMode.symbolName {
                Image(systemName: symbol)
            }
        }
        .font(.system(size: metrics.statusFontSize * 0.9, weight: .semibold))
        .transition(.opacity)
    }
}
