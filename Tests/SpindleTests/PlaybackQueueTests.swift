import Foundation
import Testing
@testable import Spindle

@Suite("The widget's own running order")
struct PlaybackQueueTests {

    private static let tracks = (1...5).map {
        LibraryTrack(index: $0, name: "Track \($0)", artist: "A", album: "B")
    }

    private func queue(pickingTrack index: Int, shuffle: ShuffleMode = .off) -> PlaybackQueue? {
        PlaybackQueue.picking(
            trackIndex: index,
            from: Self.tracks,
            in: .playlist(index: 3),
            shuffle: shuffle,
            // Fixed order so the assertions are about the arrangement, not luck.
            shuffling: { $0.reversed() }
        )
    }

    @Test("Unshuffled it is the playlist's own order, starting where you pointed")
    func keepsPlaylistOrder() throws {
        let queue = try #require(self.queue(pickingTrack: 4))

        #expect(queue.tracks.map(\.index) == [1, 2, 3, 4, 5])
        #expect(queue.cursor == 3)
        #expect(queue.current?.index == 4)
        #expect(queue.count == 5)
    }

    @Test("Shuffled it is the chosen track first and the rest in random order")
    func picksChosenTrackFirst() throws {
        let queue = try #require(self.queue(pickingTrack: 4, shuffle: .songs))

        // Picking a song is a request for *that* song; shuffle governs what
        // comes after it.
        #expect(queue.current?.index == 4)
        #expect(queue.cursor == 0)
        #expect(queue.tracks.map(\.index) == [4, 5, 3, 2, 1])
        #expect(Set(queue.tracks.map(\.index)) == Set(1...5), "the whole list, still")
    }

    @Test("Advancing walks the playlist one track at a time")
    func advancesByOne() throws {
        let queue = try #require(self.queue(pickingTrack: 2)).advanced(repeatMode: .off)

        #expect(queue?.current?.index == 3)
    }

    @Test("Repeat Off stops at the end of the list, All wraps, One holds")
    func honoursRepeat() throws {
        let last = try #require(queue(pickingTrack: 5))

        #expect(last.advanced(repeatMode: .off) == nil)
        #expect(last.advanced(repeatMode: .all)?.current?.index == 1)
        #expect(last.advanced(repeatMode: .one)?.current?.index == 5)
    }

    @Test("Previous at the first track restarts it, as the original's did")
    func rewindClampsAtTheTop() throws {
        let first = try #require(queue(pickingTrack: 1))

        #expect(first.rewound().current?.index == 1)
        #expect(try #require(queue(pickingTrack: 3)).rewound().current?.index == 2)
    }

    @Test("A track the container does not hold builds no queue")
    func refusesUnknownTrack() {
        #expect(queue(pickingTrack: 99) == nil)
    }
}

@Suite("Following playback")
@MainActor
struct QueueFollowTests {

    private static let tracks = (1...3).map {
        LibraryTrack(index: $0, name: "Track \($0)", artist: "A", album: "B")
    }

    private func playing(_ title: String, elapsed: TimeInterval, duration: TimeInterval) -> NowPlaying {
        NowPlaying(
            title: title,
            isPlaying: true,
            duration: duration,
            elapsed: elapsed,
            elapsedAt: Date(timeIntervalSince1970: 1_000),
            playbackRate: 1
        )
    }

    /// A controller wired to a stub library and a frozen clock.
    private func withController(
        _ body: (QueueController, StubLibrary, AppSettings) -> Void
    ) {
        let name = "nl.jopmors.Spindle.followTests"
        let defaults = UserDefaults(suiteName: name) ?? .standard
        defer {
            defaults.removePersistentDomain(forName: name)
            UserDefaults.standard.removeSuite(named: name)
        }
        let library = StubLibrary()
        let settings = AppSettings(defaults: defaults)
        let controller = QueueController(
            library: library,
            settings: settings,
            now: { Date(timeIntervalSince1970: 1_000) }
        )
        body(controller, library, settings)
    }

    private func start(_ controller: QueueController) {
        controller.play(
            trackIndex: 2, from: .playlist(index: 7), tracks: Self.tracks, completion: { _ in }
        )
    }

    @Test("The counter reads the real position in the real playlist")
    func reportsTruePosition() {
        withController { controller, library, _ in
            start(controller)

            #expect(library.playedPlaylistTracks == [.init(playlist: 7, track: 2)])
            #expect(controller.position == QueuePosition(cursor: 1, count: 3))
        }
    }

    @Test("A title that stays foreign past the settling window hands control back")
    func relinquishesWhenTheUserTakesOver() {
        withController { controller, _, _ in
            start(controller)
            // Music keeps reporting the outgoing track for a moment, so a
            // mismatch inside the window is not the user intervening.
            controller.update(playing("Something Else", elapsed: 0, duration: 200))
            #expect(controller.isActive, "still settling")

            // Same frozen clock, but the window has been cleared by a match
            // first, so the next mismatch is real.
            controller.update(playing("Track 2", elapsed: 0, duration: 200))
            controller.update(playing("Something Else", elapsed: 0, duration: 200))

            #expect(controller.isActive == false)
            #expect(controller.position == nil)
        }
    }

    @Test("Playing one song only never follows anything")
    func playOnceDoesNotFollow() {
        withController { controller, library, _ in
            controller.playOnce(trackIndex: 3, in: .library, completion: { _ in })

            #expect(library.playedLibraryTracks == [.init(playlist: nil, track: 3)])
            #expect(controller.isActive == false)
            #expect(controller.position == nil)
        }
    }

    @Test("A deliberate skip ignores Repeat One, which would pin it in place")
    func skipEscapesRepeatOne() {
        withController { controller, library, settings in
            settings.repeatMode = .one
            start(controller)

            // Ending a track under Repeat One replays it…
            controller.advance()
            #expect(library.playedPlaylistTracks.last == .init(playlist: 7, track: 2))

            // …but pressing next means next.
            controller.skipForward()
            #expect(library.playedPlaylistTracks.last == .init(playlist: 7, track: 3))
        }
    }
}
