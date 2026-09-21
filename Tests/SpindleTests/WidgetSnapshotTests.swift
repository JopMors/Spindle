import AppKit
import SwiftUI
import Testing
@testable import Spindle

/// Renders the widget to PNGs under `.build/preview/` so the design can be
/// inspected without launching the app. Also asserts the rendered pixel size,
/// which is what "match the clock widget's width" actually means.
@Suite("Widget snapshots")
@MainActor
struct WidgetSnapshotTests {

    private static let outputDirectory = URL(fileURLWithPath: ".build/preview", isDirectory: true)

    @Test("Renders at the small-widget width")
    func rendersAtSmallWidgetWidth() async throws {
        try await withIsolatedDefaults { defaults in
            let settings = AppSettings(defaults: defaults)
            let image = try render(settings: settings, name: "default-skin")

            #expect(settings.width == AppSettings.defaultWidth)
            #expect(abs(image.size.width - AppSettings.defaultWidth) < 1)
        }
    }

    @Test("Renders the black & white album cover")
    func rendersMonochromeArtwork() async throws {
        try await withIsolatedDefaults { defaults in
            let settings = AppSettings(defaults: defaults)
            settings.isArtworkMonochrome = true
            _ = try render(settings: settings, name: "monochrome-artwork")
        }
    }

    /// Two bugs met here. A solid skin used to draw its own drop shadow inside
    /// a window sized exactly to the body, which clipped into a dark rim; and a
    /// corner radius above what the padding could absorb cut the corners off
    /// the menu's screen. Both are edge effects, so they need a real render.
    @Test("A solid skin at maximum roundness has clean edges")
    func rendersSolidSkinAtMaximumRoundness() async throws {
        try await withIsolatedDefaults { defaults in
            let settings = AppSettings(defaults: defaults)
            settings.selectedThemeID = "mini-blue"
            settings.width = SpindleMetrics.smallWidgetWidth
            settings.cornerRadius = AppSettings.maxCornerRadius

            try await renderMenu(settings: settings, name: "solid-max-radius-menu")

            // The request is kept, but what gets drawn is what fits.
            #expect(settings.cornerRadius == AppSettings.maxCornerRadius)
            #expect(settings.metrics.cornerRadius(forRequested: settings.cornerRadius)
                    == settings.metrics.maxCornerRadius)
            #expect(settings.theme.isGlass == false)
        }
    }

    @Test("Renders the permanent volume bar and the playing bars")
    func rendersVolumeAndPlayingBars() async throws {
        try await withIsolatedDefaults { defaults in
            let settings = AppSettings(defaults: defaults)
            settings.showsVolumeSlider = true
            settings.width = SpindleMetrics.mediumWidth

            _ = try render(settings: settings, name: "volume-and-playing-bars")
        }
    }

    @Test("Renders a menu with the highlighted track's cover behind it")
    func rendersMenuArtwork() async throws {
        try await withIsolatedDefaults { defaults in
            let settings = AppSettings(defaults: defaults)
            settings.width = SpindleMetrics.mediumWidth

            try await renderMenu(
                settings: settings,
                name: "menu-artwork",
                descend: ["Music", "Playlists", "Top 2000"],
                artwork: StubMediaService.sample.artworkData,
                // Past "Play Playlist" and onto a track, which is the only
                // kind of row that has a cover.
                highlightOffset: 1
            )
        }
    }

    @Test("Renders the main menu")
    func rendersMainMenu() async throws {
        try await withIsolatedDefaults { defaults in
            try await renderMenu(settings: AppSettings(defaults: defaults), name: "main-menu")
        }
    }

    /// A custom skin can set the screen background to fully transparent. The
    /// selected row used to draw its label in that colour, which made the
    /// highlighted line invisible.
    @Test("Selected menu row stays legible with a transparent screen background")
    func rendersMenuOnTransparentScreen() async throws {
        try await withIsolatedDefaults { defaults in
            let settings = AppSettings(defaults: defaults)
            var skin = CustomSkin()
            skin.screenOpacity = 0
            settings.customSkin = skin
            settings.selectedThemeID = CustomSkin.themeID

            try await renderMenu(settings: settings, name: "menu-transparent-screen")

            // The label is inverted against the highlight bar, which is drawn
            // from the screen text colour, not against the background.
            #expect(settings.theme.screenText.brightness > 0.55)
            #expect(settings.theme.screenBackground.nsColor.alphaComponent == 0)
        }
    }

    @Test("Renders a playlist with Play Playlist at the top")
    func rendersPlaylistMenu() async throws {
        try await withIsolatedDefaults { defaults in
            try await renderMenu(
                settings: AppSettings(defaults: defaults),
                name: "playlist-menu",
                descend: ["Music", "Playlists", "Top 2000"]
            )
        }
    }

    @Test("Renders the colour wheel for review")
    func rendersColorWheel() throws {
        let view = ColorWheelPicker(color: .constant("3478F6"))
            .padding(16)
            .background(Color(nsColor: .windowBackgroundColor))

        let renderer = ImageRenderer(content: AnyView(view))
        renderer.scale = 2
        guard let image = renderer.nsImage else {
            Issue.record("ImageRenderer produced no image for the colour wheel")
            return
        }
        try write(image: image, name: "color-wheel")
    }

    @Test("Renders every skin for review")
    func rendersAllSkins() async throws {
        for theme in ThemeCatalog.all + [CustomSkin().theme] {
            try await withIsolatedDefaults { defaults in
                let settings = AppSettings(defaults: defaults)
                settings.selectedThemeID = theme.id
                _ = try render(settings: settings, name: "skin-\(theme.id)")
            }
        }
    }

    // MARK: - Helpers

    /// One fixed, self-cleaning defaults domain so snapshots never read or
    /// write real settings — and never leave a plist behind in
    /// ~/Library/Preferences, which a per-run suite name does.
    private static let snapshotSuite = "nl.jopmors.Spindle.snapshots"

    private func withIsolatedDefaults<T>(_ body: (UserDefaults) async throws -> T) async rethrows -> T {
        let name = Self.snapshotSuite
        guard let defaults = UserDefaults(suiteName: name) else {
            return try await body(.standard)
        }
        defer {
            defaults.removePersistentDomain(forName: name)
            UserDefaults.standard.removeSuite(named: name)
            try? FileManager.default.removeItem(at: Self.suitePlistURL(name))
        }
        return try await body(defaults)
    }

    private static func suitePlistURL(_ name: String) -> URL {
        FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Preferences/\(name).plist")
    }

    private func render(settings: AppSettings, name: String) throws -> NSImage {
        let viewModel = NowPlayingViewModel(service: StubMediaService())
        viewModel.start()
        let device = SpindleViewModel(settings: settings)
        let content = SpindleView(viewModel: viewModel, settings: settings, device: device)

        let renderer = ImageRenderer(content: AnyView(backdrop(content: content, settings: settings)))
        renderer.scale = 2

        guard let image = renderer.nsImage else {
            Issue.record("ImageRenderer produced no image for \(name)")
            throw SnapshotError.renderFailed
        }

        try write(image: image, name: name)
        return image
    }

    /// Glass only reads correctly against something; a plain gradient stands in
    /// for the wallpaper that the real vibrancy layer would blur.
    /// Renders the menu hierarchy, which no now-playing state can reach.
    /// `descend` walks down row titles before the shot is taken.
    private func renderMenu(
        settings: AppSettings,
        name: String,
        descend: [String] = [],
        artwork: Data? = nil,
        highlightOffset: Int = 0
    ) async throws {
        let viewModel = NowPlayingViewModel(service: StubMediaService())
        viewModel.start()
        let library = StubLibrary()
        library.artworkResult = artwork
        let device = SpindleViewModel(settings: settings, library: library, modes: SilentModes())
        device.showMenu()
        for title in descend {
            let index = device.menu.rows.firstIndex { $0.title == title } ?? 0
            device.menu.moveSelection(by: index - device.menu.selection)
            device.centerButtonPressed { _ in }
        }
        device.menu.moveSelection(by: highlightOffset)
        // The cover is fetched only once the highlight settles, so the shot has
        // to wait for it or it captures the menu without one.
        if artwork != nil {
            for _ in 0..<200 where device.menu.previewArtwork == nil {
                try await Task.sleep(for: .milliseconds(10))
            }
        }
        let content = SpindleView(viewModel: viewModel, settings: settings, device: device)

        let renderer = ImageRenderer(content: AnyView(backdrop(content: content, settings: settings)))
        renderer.scale = 2
        guard let image = renderer.nsImage else {
            Issue.record("ImageRenderer produced no image for \(name)")
            return
        }
        try write(image: image, name: name)
    }

    private func backdrop(content: SpindleView, settings: AppSettings) -> some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.13, green: 0.15, blue: 0.22),
                         Color(red: 0.30, green: 0.24, blue: 0.34)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            content
        }
        .frame(width: settings.width, height: settings.metrics.bodyHeight)
    }

    private func write(image: NSImage, name: String) throws {
        try FileManager.default.createDirectory(
            at: Self.outputDirectory, withIntermediateDirectories: true
        )
        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let png = bitmap.representation(using: .png, properties: [:]) else {
            throw SnapshotError.encodeFailed
        }
        try png.write(to: Self.outputDirectory.appendingPathComponent("\(name).png"))
    }

    private enum SnapshotError: Error {
        case renderFailed
        case encodeFailed
    }
}

/// Feeds the view model fixed state without touching MediaRemote.
private final class StubMediaService: MediaService {
    var onUpdate: ((NowPlaying) -> Void)?
    var onFailure: ((MediaServiceError) -> Void)?
    var backendDescription: String { "Stub" }

    /// Emits synchronously so a snapshot taken right after `start()` shows
    /// real content rather than the idle state.
    func start() { onUpdate?(Self.sample) }
    func stop() {}
    func send(_ command: TransportCommand) {}
    func seek(to seconds: TimeInterval) {}

    static let sample = NowPlaying(
        title: "Money For Nothing",
        artist: "Dire Straits",
        album: "Brothers In Arms",
        artworkData: artworkPNG(),
        isPlaying: true,
        duration: 502,
        elapsed: 140
    )

    private static func artworkPNG() -> Data? {
        let size = NSSize(width: 300, height: 300)
        let image = NSImage(size: size)
        image.lockFocus()
        NSGradient(colors: [.systemTeal, .systemIndigo])?.draw(
            in: NSRect(origin: .zero, size: size), angle: 45
        )
        image.unlockFocus()
        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff) else { return nil }
        return bitmap.representation(using: .png, properties: [:])
    }
}
