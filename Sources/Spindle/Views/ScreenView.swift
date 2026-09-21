import SwiftUI

/// The original's display: full-bleed album artwork with the status bar, title and
/// scrubber laid over it, or an idle/error state.
struct ScreenView: View {
    let nowPlaying: NowPlaying
    let artwork: NSImage?
    let artworkGeneration: Int
    let errorMessage: String?
    let theme: Theme
    let metrics: SpindleMetrics
    let scrimOpacity: Double
    let isMonochrome: Bool
    let shuffle: ShuffleMode
    let repeatMode: RepeatMode
    let showsPlaybackDetail: Bool
    /// The widget's own queue, when it owns one. Preferred over MediaRemote's
    /// count, which only sees the one track the widget hands to Music.
    var queuePosition: QueuePosition?
    /// A permanent volume bar under the scrubber, off unless asked for.
    var showsVolumeSlider = false
    var volume: Double = 0
    var onVolume: ((Double) -> Void)?
    /// Dragging the scrubber jumps to that point in the track.
    var onSeek: ((TimeInterval) -> Void)?

    var body: some View {
        ScreenFrame(theme: theme, metrics: metrics) { content }
    }

    @ViewBuilder
    private var content: some View {
        if let errorMessage {
            StatusMessageView(
                symbol: "exclamationmark.triangle",
                title: "No media source",
                detail: errorMessage,
                theme: theme,
                metrics: metrics
            )
        } else if nowPlaying.isIdle {
            StatusMessageView(
                symbol: "music.note",
                title: "Not Playing",
                detail: nil,
                theme: theme,
                metrics: metrics
            )
        } else {
            trackContent
        }
    }

    /// Artwork fills the whole screen; everything else sits on top, the text
    /// behind a scrim so it stays legible over bright album covers.
    private var trackContent: some View {
        ZStack(alignment: .bottom) {
            artworkView
            textScrim
            if showsPlaybackDetail {
                VStack(spacing: 0) {
                    statusBar
                    Spacer(minLength: 0)
                }
            }
            overlayText
                .padding(.horizontal, metrics.bodyPadding * 0.5)
                .padding(.bottom, metrics.bodyPadding * 0.4)
        }
    }

    private var queueCounter: String? {
        guard let queuePosition else {
            return TimeFormatting.queuePosition(
                index: nowPlaying.queueIndex, count: nowPlaying.queueCount
            )
        }
        return TimeFormatting.queuePosition(
            index: queuePosition.cursor, count: queuePosition.count
        )
    }

    private var statusBar: some View {
        ScreenStatusBar(
            title: queueCounter,
            isPlaying: nowPlaying.isPlaying,
            showsPlaybackGlyph: true,
            shuffle: shuffle,
            repeatMode: repeatMode,
            theme: theme,
            metrics: metrics
        )
        .background(
            LinearGradient(colors: [.black.opacity(scrimOpacity * 0.9), .clear],
                           startPoint: .top, endPoint: .bottom)
        )
    }

    private var artworkView: some View {
        Group {
            if let artwork {
                Image(nsImage: artwork)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                ZStack {
                    theme.screenBezel.color.opacity(0.25)
                    Image(systemName: "music.note")
                        .font(.system(size: metrics.titleFontSize * 1.8))
                        .foregroundStyle(theme.screenSecondaryText.color)
                }
            }
        }
        .frame(width: metrics.screenWidth, height: metrics.screenHeight)
        .clipped()
        // Only the cover is desaturated; the title stays legible white.
        .grayscale(isMonochrome ? 1 : 0)
        .animation(.easeInOut(duration: 0.25), value: isMonochrome)
        // Re-identify on track change so the transition actually runs.
        .id(artworkGeneration)
        .transition(.asymmetric(
            insertion: .opacity.combined(with: .scale(scale: 1.04)),
            removal: .opacity
        ))
    }

    private var textScrim: some View {
        LinearGradient(
            colors: [.clear, .black.opacity(scrimOpacity)],
            startPoint: .center,
            endPoint: .bottom
        )
        .allowsHitTesting(false)
    }

    private var overlayText: some View {
        VStack(spacing: 1) {
            MarqueeText(
                text: nowPlaying.title ?? "Unknown Track",
                font: .system(size: metrics.titleFontSize, weight: .semibold),
                color: theme.screenText.color,
                width: metrics.screenWidth - metrics.bodyPadding
            )
            MarqueeText(
                text: nowPlaying.artist ?? "Unknown Artist",
                font: .system(size: metrics.artistFontSize),
                color: theme.screenSecondaryText.color,
                width: metrics.screenWidth - metrics.bodyPadding
            )
            if showsPlaybackDetail {
                progress.padding(.top, 2)
            }
            if showsVolumeSlider {
                volumeBar.padding(.top, 3)
            }
        }
        .shadow(color: .black.opacity(0.6), radius: 2, y: 1)
    }

    private var volumeBar: some View {
        HStack(spacing: 4) {
            Image(systemName: "speaker.fill")
                .font(.system(size: metrics.statusFontSize * 0.85))
                .foregroundStyle(theme.screenSecondaryText.color)
            VolumeSlider(
                level: volume,
                theme: theme,
                metrics: metrics,
                width: metrics.screenWidth - metrics.bodyPadding * 2,
                onScrub: onVolume
            )
        }
    }

    /// Only ticks while playing; a paused widget has nothing to recount.
    @ViewBuilder
    private var progress: some View {
        if nowPlaying.isPlaying {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                progressBar(at: context.date)
            }
        } else {
            progressBar(at: Date())
        }
    }

    private func progressBar(at date: Date) -> some View {
        PlaybackProgressView(
            elapsed: nowPlaying.elapsed(at: date),
            duration: nowPlaying.duration,
            progress: nowPlaying.progress(at: date),
            theme: theme,
            metrics: metrics,
            onSeek: onSeek
        )
    }
}
