import SwiftUI

/// The whole widget: body, screen and click wheel.
struct SpindleView: View {
    @ObservedObject var viewModel: NowPlayingViewModel
    @ObservedObject var settings: AppSettings
    @ObservedObject var device: SpindleViewModel

    private var metrics: SpindleMetrics { settings.metrics }
    private var theme: Theme { settings.theme }

    var body: some View {
        VStack(spacing: 0) {
            screen
            Spacer(minLength: 0)
            ClickWheelView(
                theme: theme,
                metrics: metrics,
                isPlaying: viewModel.nowPlaying.isPlaying,
                isSelecting: device.mode == .menu,
                onCommand: { device.transport($0) { viewModel.send($0) } },
                onMenu: device.menuButtonPressed,
                onCenter: { device.centerButtonPressed { viewModel.send($0) } },
                onOpenSource: { SourceAppLauncher.open(bundleIdentifier: viewModel.nowPlaying.sourceBundleID) },
                onRotate: device.wheelScrolled(by:),
                onRotateEnded: device.resetWheelTravel
            )
            Spacer(minLength: 0)
        }
        .padding(metrics.bodyPadding)
        .frame(width: metrics.bodyWidth, height: metrics.bodyHeight)
        .background(bodyBackground)
        .animation(.easeInOut(duration: 0.28), value: viewModel.artworkGeneration)
        .animation(.easeInOut(duration: 0.2), value: viewModel.nowPlaying.isPlaying)
        .preferredColorScheme(settings.colorScheme)
    }

    @ViewBuilder
    private var screen: some View {
        ZStack {
            if device.mode == .menu {
                ScreenFrame(theme: theme, metrics: metrics) {
                    MenuScreen(
                        model: device.menu,
                        theme: theme,
                        metrics: metrics,
                        onSelectRow: device.rowTapped
                    )
                }
                .transition(.opacity)
            } else {
                nowPlayingScreen
                    // Clicking the screen opens the menu. The top button does
                    // the same thing, but nothing about it says so.
                    .contentShape(Rectangle())
                    .onTapGesture { device.screenTapped() }
                    .transition(.opacity)
            }
            if let level = device.volumeOverlay {
                VolumeOverlay(
                    level: level,
                    theme: theme,
                    metrics: metrics,
                    onScrub: device.setVolume
                )
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.18), value: device.mode)
        .animation(.easeInOut(duration: 0.18), value: device.volumeOverlay == nil)
    }

    private var nowPlayingScreen: some View {
        ScreenView(
            nowPlaying: viewModel.nowPlaying,
            artwork: viewModel.artwork,
            artworkGeneration: viewModel.artworkGeneration,
            errorMessage: viewModel.errorMessage,
            theme: theme,
            metrics: metrics,
            scrimOpacity: settings.customSkin.textScrimOpacity,
            isMonochrome: settings.isArtworkMonochrome,
            shuffle: device.shuffle,
            repeatMode: device.repeatMode,
            showsPlaybackDetail: settings.showsPlaybackDetail,
            queuePosition: device.queuePosition,
            showsVolumeSlider: settings.showsVolumeSlider,
            volume: device.volume,
            onVolume: device.setVolume,
            onSeek: { viewModel.seek(to: $0) }
        )
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(
            cornerRadius: metrics.cornerRadius(forRequested: settings.cornerRadius),
            style: .continuous
        )
    }

    /// Glass skins only tint: the blur behind them comes from the window's
    /// vibrancy layer, and the window server draws the shadow.
    ///
    /// Neither branch draws its own drop shadow. The window is exactly the size
    /// of the body, so a SwiftUI shadow has nowhere to fall and gets clipped
    /// into a dark rim around the edge — which is what the solid skins used to
    /// show. `FloatingPanel.hasShadow` gives us the real one, outside the frame.
    @ViewBuilder
    private var bodyBackground: some View {
        if theme.isGlass {
            shape
                .fill(theme.bodyGradient)
                .overlay(shape.strokeBorder(theme.bodyBorder.color, lineWidth: theme.borderWidth))
                .overlay(specularHighlight)
        } else {
            shape
                .fill(theme.bodyGradient)
                .overlay(shape.strokeBorder(theme.bodyBorder.color, lineWidth: theme.borderWidth))
                .overlay(glossHighlight)
        }
    }

    /// Thin bright rim along the top edge, the tell-tale of a glass surface.
    private var specularHighlight: some View {
        shape
            .strokeBorder(
                LinearGradient(
                    colors: [.white.opacity(0.45), .white.opacity(0.05), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                lineWidth: 1
            )
            .blendMode(.plusLighter)
            .allowsHitTesting(false)
    }

    /// Sheen across the top of the solid skins, as on the real polycarbonate.
    private var glossHighlight: some View {
        shape
            .fill(
                LinearGradient(
                    colors: [.white.opacity(theme.isDarkBody ? 0.10 : 0.55), .clear],
                    startPoint: .top,
                    endPoint: .center
                )
            )
            .allowsHitTesting(false)
    }
}
