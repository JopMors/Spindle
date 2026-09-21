import SwiftUI

/// The physical display: background, rounded clip, bezel and shadow.
///
/// Whatever is on the screen — now playing, a menu, an error — is composed in
/// by the caller, so the chrome is defined exactly once.
struct ScreenFrame<Content: View>: View {
    let theme: Theme
    let metrics: SpindleMetrics
    @ViewBuilder var content: Content

    var body: some View {
        ZStack {
            theme.screenBackground.color
            content
        }
        .frame(width: metrics.screenWidth, height: metrics.screenHeight)
        .clipShape(RoundedRectangle(cornerRadius: metrics.screenCornerRadius, style: .continuous))
        .overlay(bezel)
        .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
    }

    private var bezel: some View {
        RoundedRectangle(cornerRadius: metrics.screenCornerRadius, style: .continuous)
            .strokeBorder(theme.screenBezel.color, lineWidth: metrics.bezelWidth)
    }
}

/// Idle and error presentation, shared so both look consistent.
struct StatusMessageView: View {
    let symbol: String
    let title: String
    let detail: String?
    let theme: Theme
    let metrics: SpindleMetrics

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.system(size: metrics.titleFontSize * 1.8, weight: .light))
            Text(title)
                .font(.system(size: metrics.titleFontSize, weight: .medium))
            if let detail {
                Text(detail)
                    .font(.system(size: metrics.artistFontSize * 0.9))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(theme.screenSecondaryText.color)
                    .padding(.horizontal, 8)
            }
        }
        .foregroundStyle(theme.screenText.color.opacity(0.85))
    }
}
