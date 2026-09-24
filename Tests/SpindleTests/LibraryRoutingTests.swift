import Foundation
import Testing
@testable import Spindle

/// The note-button toggle also decides whose library the menu browses.
@Suite("Library routing")
@MainActor
struct LibraryRoutingTests {

    private static let suiteName = "nl.jopmors.Spindle.routingTests"

    private func withDevice(
        _ body: (SpindleViewModel, AppSettings, LibraryRouter, StubLibrary, StubLibrary) throws -> Void
    ) rethrows {
        let defaults = UserDefaults(suiteName: Self.suiteName) ?? .standard
        defer {
            defaults.removePersistentDomain(forName: Self.suiteName)
            UserDefaults.standard.removeSuite(named: Self.suiteName)
        }
        let settings = AppSettings(defaults: defaults)
        settings.isWheelClickEnabled = false
        let music = StubLibrary()
        let spotify = StubLibrary(playlists: [LibraryPlaylist(index: 1, name: "Spotify Mix")])
        let router = LibraryRouter(music: music, spotify: spotify)
        let device = SpindleViewModel(settings: settings, library: router, modes: SilentModes())
        try body(device, settings, router, music, spotify)
    }

    private final class SilentModes: PlaybackModeSetting {
        func setShuffle(_ mode: ShuffleMode) {}
        func setRepeat(_ mode: RepeatMode) {}
    }

    @Test("Each toggle position picks a library", arguments: [
        (WheelSourceTarget.appleMusic, "com.spotify.client" as String?, LibrarySource.music),
        (.spotify, "com.apple.Music", .spotify),
        (.media, "com.spotify.client", .spotify),
        (.media, "com.apple.Music", .music),
        (.media, "com.google.Chrome", .music),
        (.media, nil, .music)
    ])
    func resolves(target: WheelSourceTarget, playing: String?, expected: LibrarySource) {
        #expect(LibrarySource.resolve(target: target, nowPlayingBundleID: playing) == expected)
    }

    @Test("Opening the menu on Spotify browses Spotify")
    func menuFollowsToggle() {
        withDevice { device, settings, router, music, spotify in
            settings.wheelSourceTarget = .spotify

            device.showMenu()

            #expect(router.source == .spotify)
            _ = device.menu.activateSelection()          // Music
            _ = device.menu.activateSelection()          // Playlists
            #expect(device.menu.rows.map(\.title) == ["Spotify Mix"])
        }
    }

    @Test("Changing the toggle with the menu open starts it again on the new library")
    func toggleWhileBrowsing() {
        withDevice { device, settings, router, _, _ in
            device.showMenu()
            _ = device.menu.activateSelection()
            #expect(device.menu.level == .music)

            settings.wheelSourceTarget = .spotify

            #expect(router.source == .spotify)
            #expect(device.menu.level == .main)
        }
    }

    @Test("A queue keeps playing from the library it was started in")
    func queueSticksToItsLibrary() {
        withDevice { device, settings, router, music, spotify in
            router.source = .music
            device.queue.play(
                trackIndex: 1, from: .library, tracks: StubLibrary.sampleTracks, completion: { _ in }
            )

            router.source = .spotify
            device.queue.skipForward()

            #expect(music.playedLibraryTracks.map(\.track) == [1, 2])
            #expect(spotify.playedLibraryTracks.isEmpty)
        }
    }
}
