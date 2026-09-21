import SwiftUI

/// The volume bar that appears over Now Playing while the wheel is moving, and
/// fades out again a moment after you stop.
///
/// The bar inside it is draggable. It used to refuse hit testing entirely,
/// which meant the only way to set volume was a gesture nothing advertised.
struct VolumeOverlay: View {
    let level: Double
    let theme: Theme
    let metrics: SpindleMetrics
    var onScrub: ((Double) -> Void)?

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: symbolName)
                .font(.system(size: metrics.titleFontSize, weight: .medium))
            VolumeSlider(
                level: level,
                theme: theme,
                metrics: metrics,
                width: metrics.screenWidth * 0.55,
                onScrub: onScrub
            )
        }
        .foregroundStyle(theme.screenText.color)
        .padding(.horizontal, metrics.bodyPadding * 0.7)
        .padding(.vertical, metrics.bodyPadding * 0.5)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(.black.opacity(0.62))
        )
    }

    private var symbolName: String {
        switch level {
        case ..<0.01: return "speaker.slash.fill"
        case ..<0.34: return "speaker.wave.1.fill"
        case ..<0.67: return "speaker.wave.2.fill"
        default: return "speaker.wave.3.fill"
        }
    }
}
