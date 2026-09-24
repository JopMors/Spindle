import Foundation
import Testing
@testable import Spindle

/// The bottom wheel button can be pinned to one app or left to follow
/// whatever is playing.
@Suite("Wheel source target")
@MainActor
struct WheelSourceTargetTests {

    private static let suiteName = "nl.jopmors.Spindle.sourceTargetTests"

    private func withDefaults(_ body: (UserDefaults) throws -> Void) rethrows {
        let defaults = UserDefaults(suiteName: Self.suiteName) ?? .standard
        defer {
            defaults.removePersistentDomain(forName: Self.suiteName)
            UserDefaults.standard.removeSuite(named: Self.suiteName)
        }
        try body(defaults)
    }

    @Test("Apple Music ignores what is playing")
    func appleMusicIsPinned() {
        let identifier = WheelSourceTarget.appleMusic.bundleIdentifier(nowPlaying: "com.google.Chrome")

        #expect(identifier == "com.apple.Music")
    }

    @Test("Spotify ignores what is playing")
    func spotifyIsPinned() {
        let identifier = WheelSourceTarget.spotify.bundleIdentifier(nowPlaying: "com.apple.Music")

        #expect(identifier == "com.spotify.client")
    }

    @Test("Media follows whatever is playing")
    func mediaFollowsNowPlaying() {
        let identifier = WheelSourceTarget.media.bundleIdentifier(nowPlaying: "com.google.Chrome")

        #expect(identifier == "com.google.Chrome")
    }

    @Test("Media with nothing reported leaves the fallback to the launcher")
    func mediaWithNothingPlaying() {
        #expect(WheelSourceTarget.media.bundleIdentifier(nowPlaying: nil) == nil)
    }

    @Test("Defaults to media, which is how the button always behaved")
    func defaultsToMedia() {
        withDefaults { defaults in
            #expect(AppSettings(defaults: defaults).wheelSourceTarget == .media)
        }
    }

    @Test("The choice survives a relaunch")
    func persists() {
        withDefaults { defaults in
            AppSettings(defaults: defaults).wheelSourceTarget = .spotify

            #expect(AppSettings(defaults: defaults).wheelSourceTarget == .spotify)
        }
    }
}
