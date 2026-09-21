import AppKit
import Foundation
import Testing
@testable import Spindle

// swift-testing rather than XCTest: this machine has Command Line Tools only,
// which ships Testing.framework but not XCTest.

@Suite("Adapter stream parsing")
struct NowPlayingParserTests {

    @Test("Decodes a complete now-playing frame")
    func parsesFullFrame() {
        // Arrange
        let line = """
        {"type":"now-playing","title":"What It Is","artist":"Mark Knopfler",\
        "album":"Private Investigations","isPlaying":true,"duration":298.25,\
        "elapsed":12.5,"hasContent":true,"artwork":"YWJj","artworkChanged":true}
        """

        // Act
        let message = NowPlayingParser.parse(line: line)

        // Assert
        guard case .nowPlaying(let snapshot) = message else {
            Issue.record("expected a now-playing message, got \(String(describing: message))")
            return
        }
        #expect(snapshot.title == "What It Is")
        #expect(snapshot.artist == "Mark Knopfler")
        #expect(snapshot.album == "Private Investigations")
        #expect(snapshot.isPlaying)
        #expect(snapshot.duration == 298.25)
        #expect(snapshot.elapsed == 12.5)
        #expect(snapshot.artworkData == Data(base64Encoded: "YWJj"))
        #expect(snapshot.artworkChanged)
    }

    @Test("Decodes an error frame")
    func parsesErrorMessage() {
        let line = #"{"type":"error","message":"MediaRemote unavailable"}"#

        #expect(NowPlayingParser.parse(line: line) == .failure("MediaRemote unavailable"))
    }

    @Test("Ignores non-JSON noise on the stream", arguments: [
        "Use of uninitialized value in print",
        "",
        "   ",
        "{ not json"
    ])
    func ignoresNoise(line: String) {
        // perl can write warnings to the same stdout the adapter uses.
        #expect(NowPlayingParser.parse(line: line) == nil)
    }

    @Test("Ignores unknown message types")
    func ignoresUnknownType() {
        #expect(NowPlayingParser.parse(line: #"{"type":"heartbeat"}"#) == nil)
    }

    @Test("Treats JSON null and blank strings as absent")
    func normalisesEmptyFields() {
        let line = #"{"type":"now-playing","title":null,"artist":"  ","isPlaying":false}"#

        guard case .nowPlaying(let snapshot) = NowPlayingParser.parse(line: line) else {
            Issue.record("expected a now-playing message")
            return
        }
        #expect(snapshot.title == nil)
        #expect(snapshot.artist == nil)
    }
}

@Suite("Snapshot merging")
struct NowPlayingMergeTests {

    @Test("Carries artwork forward when the adapter says it is unchanged")
    func carriesArtworkForward() {
        // Arrange
        let existing = Data([0x01, 0x02, 0x03])
        let previous = NowPlaying(
            title: "Old", artist: "Artist", artworkData: existing, isPlaying: true
        )
        let snapshot = NowPlayingSnapshot(
            title: "Old", artist: "Artist", album: nil, isPlaying: false,
            duration: nil, elapsed: nil, hasContent: true,
            artworkData: nil, artworkChanged: false
        )

        // Act
        let merged = NowPlayingParser.merge(previous: previous, snapshot: snapshot)

        // Assert
        #expect(merged.artworkData == existing)
        #expect(merged.isPlaying == false)
    }

    @Test("Reads which app is playing, and holds on to it")
    func readsSourceApp() throws {
        // The adapter resolves this inside perl; MediaRemote refuses it to
        // ordinary processes, so the widget has no other way to know.
        let line = """
        {"type":"now-playing","title":"A","isPlaying":true,"hasContent":true,\
        "sourceBundleID":"com.spotify.client"}
        """
        let message = try #require(NowPlayingParser.parse(line: line))
        guard case .nowPlaying(let snapshot) = message else {
            Issue.record("expected a now-playing message")
            return
        }
        #expect(snapshot.sourceBundleID == "com.spotify.client")

        let playing = NowPlayingParser.merge(previous: .idle, snapshot: snapshot)
        #expect(playing.sourceBundleID == "com.spotify.client")

        // A frame can arrive before the source resolves; losing it would send
        // the bottom button back to Music mid-session.
        let withoutSource = NowPlayingSnapshot(
            title: "B", artist: nil, album: nil, isPlaying: true,
            duration: nil, elapsed: nil, hasContent: true,
            artworkData: nil, artworkChanged: false
        )
        let merged = NowPlayingParser.merge(previous: playing, snapshot: withoutSource)
        #expect(merged.sourceBundleID == "com.spotify.client")
    }

    @Test("Clears artwork when a track genuinely has none")
    func clearsArtworkWhenChangedToNone() {
        let previous = NowPlaying(artworkData: Data([0xFF]), isPlaying: true)
        let snapshot = NowPlayingSnapshot(
            title: "New", artist: nil, album: nil, isPlaying: true,
            duration: nil, elapsed: nil, hasContent: true,
            artworkData: nil, artworkChanged: true
        )

        #expect(NowPlayingParser.merge(previous: previous, snapshot: snapshot).artworkData == nil)
    }

    @Test("Returns idle when the adapter reports no content")
    func returnsIdleWithoutContent() {
        let previous = NowPlaying(title: "Old", artworkData: Data([0xFF]), isPlaying: true)
        let snapshot = NowPlayingSnapshot(
            title: nil, artist: nil, album: nil, isPlaying: false,
            duration: nil, elapsed: nil, hasContent: false,
            artworkData: nil, artworkChanged: true
        )

        #expect(NowPlayingParser.merge(previous: previous, snapshot: snapshot) == .idle)
    }
}

@Suite("NowPlaying model")
struct NowPlayingModelTests {

    @Test("Is idle when both title and artist are missing")
    func idleDetection() {
        #expect(NowPlaying.idle.isIdle)
        #expect(NowPlaying(title: "", artist: "", isPlaying: false).isIdle)
        #expect(NowPlaying(title: "Song", isPlaying: false).isIdle == false)
    }

    @Test("Progress needs a usable duration")
    func progressRequiresDuration() {
        #expect(NowPlaying(isPlaying: false).progress == nil)
        #expect(NowPlaying(isPlaying: false, duration: 0, elapsed: 5).progress == nil)
        #expect(NowPlaying(isPlaying: true, duration: 100, elapsed: 25).progress == 0.25)
    }

    @Test("Progress is clamped to 0...1")
    func progressIsClamped() {
        #expect(NowPlaying(isPlaying: true, duration: 100, elapsed: 150).progress == 1)
        #expect(NowPlaying(isPlaying: true, duration: 100, elapsed: -10).progress == 0)
    }
}

@Suite("Theme catalog")
struct ThemeCatalogTests {

    @Test("Unknown identifiers fall back to the default skin")
    func lookupFallsBack() {
        #expect(ThemeCatalog.theme(withID: "nope") == ThemeCatalog.fallback)
    }

    @Test("Every skin has a unique identifier")
    func identifiersAreUnique() {
        let ids = ThemeCatalog.all.map(\.id)
        #expect(Set(ids).count == ids.count)
    }

    @Test("Hex colours parse with and without a leading hash")
    func hexParsing() {
        #expect(abs(HexColor("FF0000").nsColor.redComponent - 1.0) < 0.001)
        #expect(abs(HexColor("#00FF00").nsColor.greenComponent - 1.0) < 0.001)
    }

    @Test("Malformed hex is visibly wrong rather than silently black")
    func malformedHexFallsBack() {
        #expect(HexColor("xyz").nsColor == NSColor.magenta)
    }

    @Test("Eight-digit hex carries alpha")
    func hexAlpha() {
        #expect(abs(HexColor("FFFFFF80").nsColor.alphaComponent - 0.502) < 0.01)
        #expect(abs(HexColor("FFFFFF").nsColor.alphaComponent - 1.0) < 0.001)
    }

    @Test("Colour round-trips through the hex form")
    func colorRoundTrip() {
        let hex = HexColor(nsColor: NSColor(srgbRed: 0.2, green: 0.4, blue: 0.6, alpha: 1), alpha: 0.5)
        let back = hex.nsColor
        #expect(abs(back.redComponent - 0.2) < 0.01)
        #expect(abs(back.blueComponent - 0.6) < 0.01)
        #expect(abs(back.alphaComponent - 0.5) < 0.01)
    }
}

@Suite("Settings")
@MainActor
struct AppSettingsTests {

    private func makeDefaults() -> UserDefaults {
        UserDefaults(suiteName: "nl.jopmors.Spindle.tests") ?? .standard
    }

    private func clean(_ defaults: UserDefaults) {
        defaults.removePersistentDomain(forName: "nl.jopmors.Spindle.tests")
        try? FileManager.default.removeItem(
            at: FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Preferences/nl.jopmors.Spindle.tests.plist")
        )
    }

    @Test("Opacity is clamped so the widget can never vanish")
    func opacityFloor() {
        let defaults = makeDefaults()
        defer { clean(defaults) }
        defaults.set(0.0, forKey: "widget.overallOpacity")

        #expect(AppSettings(defaults: defaults).overallOpacity == AppSettings.minOpacity)
    }

    @Test("Fresh installs get the documented defaults")
    func freshDefaults() {
        let defaults = makeDefaults()
        defer { clean(defaults) }
        clean(defaults)
        let settings = AppSettings(defaults: defaults)

        #expect(settings.width == AppSettings.defaultWidth)
        #expect(settings.cornerRadius == AppSettings.defaultCornerRadius)
        #expect(settings.overallOpacity == 1.0)
        // Unlocked: dragging is the first thing anyone tries, and a widget that
        // silently refuses to move reads as broken.
        #expect(settings.isPositionLocked == false)
        #expect(settings.placement == .desktop)
        #expect(settings.isArtworkMonochrome == false)
        #expect(settings.wheelClickVolume == 0.6)
    }

    @Test("A rename carries the old settings over instead of resetting them")
    func migratesLegacySettings() {
        let defaults = makeDefaults()
        defer { clean(defaults) }
        clean(defaults)

        // Invented names, never the real ones. `setPersistentDomain` and
        // `removePersistentDomain` act on the named domain for the whole user,
        // so seeding the actual legacy identifiers here would wipe the
        // preferences of the installed app.
        let newer = "nl.jopmors.Spindle.tests.legacyNewer"
        let older = "nl.jopmors.Spindle.tests.legacyOlder"
        defaults.setPersistentDomain(["widget.width": 300.0], forName: newer)
        defaults.setPersistentDomain(
            ["widget.width": 999.0, "theme.id": "mini-green"], forName: older
        )
        defer {
            defaults.removePersistentDomain(forName: newer)
            defaults.removePersistentDomain(forName: older)
        }

        #expect(SettingsMigration.run(into: defaults, from: [newer, older]) == 2)
        // The app has been renamed twice, so the same key exists in two old
        // domains. The more recent one has to win.
        #expect(AppSettings(defaults: defaults).width == 300)
        #expect(AppSettings(defaults: defaults).selectedThemeID == "mini-green")

        // Once only: a second pass must not undo later changes.
        defaults.set(200.0, forKey: "widget.width")
        #expect(SettingsMigration.run(into: defaults, from: [newer, older]) == 0)
        #expect(AppSettings(defaults: defaults).width == 200)
    }

    @Test("Corner radius is held to what the width can round")
    func cornerRadiusClamped() {
        // A body cannot round its corners past the screen sitting inside it:
        // above bodyPadding + screenCornerRadius the screen's own corner gets
        // cut off, which showed up in the menu.
        let small = SpindleMetrics(bodyWidth: SpindleMetrics.smallWidgetWidth)

        #expect(small.maxCornerRadius < AppSettings.maxCornerRadius)
        #expect(small.cornerRadius(forRequested: AppSettings.maxCornerRadius)
                == small.maxCornerRadius)
        // Under the ceiling the request is honoured untouched.
        #expect(small.cornerRadius(forRequested: 6) == 6)
        // Wider bodies can round more, so the stored value is never destroyed.
        let huge = SpindleMetrics(bodyWidth: SpindleMetrics.mediumWidgetWidth)
        #expect(huge.maxCornerRadius > small.maxCornerRadius)
    }

    @Test("Width is clamped to the supported range")
    func widthClamped() {
        let defaults = makeDefaults()
        defer { clean(defaults) }
        defaults.set(9999.0, forKey: "widget.width")

        #expect(AppSettings(defaults: defaults).width == SpindleMetrics.maxWidth)
    }
}

@Suite("Custom skin")
struct CustomSkinTests {

    @Test("Derives a theme carrying the editable values")
    func derivesTheme() {
        var skin = CustomSkin()
        skin.borderWidth = 3.5
        skin.isGlass = false

        let theme = skin.theme

        #expect(theme.id == CustomSkin.themeID)
        #expect(theme.borderWidth == 3.5)
        #expect(theme.isGlass == false)
    }

    @Test("Opacity sliders reach the derived colours")
    func opacityApplies() {
        var skin = CustomSkin()
        skin.bodyOpacity = 0.25

        #expect(abs(skin.theme.bodyTop.nsColor.alphaComponent - 0.25) < 0.01)
    }

    @Test("Light tints get dark labels, dark tints get light ones")
    func labelContrast() {
        var light = CustomSkin()
        light.tint = "FFFFFF"
        var dark = CustomSkin()
        dark.tint = "101014"

        #expect(light.theme.isDarkBody == false)
        #expect(dark.theme.isDarkBody)
        #expect(light.theme.wheelLabel.brightness < dark.theme.wheelLabel.brightness)
    }

    @Test("Survives a round trip through its stored JSON form")
    func codableRoundTrip() throws {
        var skin = CustomSkin()
        skin.tint = "112233"
        skin.wheelOpacity = 0.42

        let data = try JSONEncoder().encode(skin)
        let restored = try JSONDecoder().decode(CustomSkin.self, from: data)

        #expect(restored == skin)
    }
}
