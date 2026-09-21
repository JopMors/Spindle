import Foundation
import Testing
@testable import Spindle

@Suite("Elapsed extrapolation")
struct ElapsedProjectionTests {

    private let base = Date(timeIntervalSince1970: 1_000_000)

    @Test("Projects forward from the reading's own timestamp while playing")
    func projectsWhilePlaying() {
        // Arrange
        let state = NowPlaying(
            isPlaying: true, duration: 200, elapsed: 30, elapsedAt: base, playbackRate: 1
        )

        // Act
        let elapsed = state.elapsed(at: base.addingTimeInterval(5))

        // Assert
        #expect(elapsed == 35)
    }

    @Test("Holds still when paused, however long ago the reading was")
    func freezesWhenPaused() {
        let state = NowPlaying(
            isPlaying: false, duration: 200, elapsed: 30, elapsedAt: base, playbackRate: 0
        )

        #expect(state.elapsed(at: base.addingTimeInterval(600)) == 30)
    }

    @Test("Never runs past the end of the track")
    func clampsToDuration() {
        let state = NowPlaying(
            isPlaying: true, duration: 100, elapsed: 95, elapsedAt: base, playbackRate: 1
        )

        #expect(state.elapsed(at: base.addingTimeInterval(120)) == 100)
        #expect(state.progress(at: base.addingTimeInterval(120)) == 1)
    }

    @Test("Honours a playback rate other than 1")
    func respectsPlaybackRate() {
        let state = NowPlaying(
            isPlaying: true, duration: 200, elapsed: 10, elapsedAt: base, playbackRate: 2
        )

        #expect(state.elapsed(at: base.addingTimeInterval(10)) == 30)
    }

    @Test("Falls back to the raw reading with no timestamp")
    func withoutTimestamp() {
        let state = NowPlaying(isPlaying: true, duration: 200, elapsed: 42)

        #expect(state.elapsed(at: base.addingTimeInterval(60)) == 42)
    }
}

@Suite("Time formatting")
struct TimeFormattingTests {

    @Test("Formats under and over an hour")
    func formatsDurations() {
        #expect(TimeFormatting.duration(0) == "0:00")
        #expect(TimeFormatting.duration(9) == "0:09")
        #expect(TimeFormatting.duration(83) == "1:23")
        #expect(TimeFormatting.duration(3661) == "1:01:01")
    }

    @Test("Clamps negative elapsed to zero rather than showing -0:01")
    func clampsNegative() {
        #expect(TimeFormatting.duration(-5) == "0:00")
    }

    @Test("Remaining counts down with a leading minus")
    func formatsRemaining() {
        #expect(TimeFormatting.remaining(elapsed: 60, duration: 200) == "-2:20")
        #expect(TimeFormatting.remaining(elapsed: 250, duration: 200) == "-0:00")
        #expect(TimeFormatting.remaining(elapsed: 10, duration: nil) == nil)
    }

    @Test("Queue position is one-based and hidden for a single track")
    func formatsQueuePosition() {
        #expect(TimeFormatting.queuePosition(index: 0, count: 82) == "1 of 82")
        #expect(TimeFormatting.queuePosition(index: 81, count: 82) == "82 of 82")
        #expect(TimeFormatting.queuePosition(index: 0, count: 1) == nil)
        #expect(TimeFormatting.queuePosition(index: nil, count: 82) == nil)
        #expect(TimeFormatting.queuePosition(index: 99, count: 82) == nil)
    }
}

@Suite("Playback modes")
struct PlaybackModeTests {

    @Test("Shuffle toggles between off and songs")
    func shuffleToggle() {
        #expect(ShuffleMode.off.toggled == .songs)
        #expect(ShuffleMode.songs.toggled == .off)
        #expect(ShuffleMode.albums.toggled == .off)
    }

    @Test("Repeat cycles off, all, one")
    func repeatCycle() {
        #expect(RepeatMode.off.cycled == .all)
        #expect(RepeatMode.all.cycled == .one)
        #expect(RepeatMode.one.cycled == .off)
    }

    @Test("Raw values are MediaRemote's own mode numbers")
    func rawValuesMatchMediaRemote() {
        // Verified against Music.app: 1 turns each off, 2 and 3 are the on
        // variants. Changing these silently breaks both controls.
        #expect(ShuffleMode.off.rawValue == 1)
        #expect(ShuffleMode.songs.rawValue == 3)
        #expect(RepeatMode.off.rawValue == 1)
        #expect(RepeatMode.one.rawValue == 2)
        #expect(RepeatMode.all.rawValue == 3)
    }

    @Test("Only repeat draws a glyph when it is off")
    func statusGlyphs() {
        #expect(RepeatMode.off.symbolName == nil)
        #expect(RepeatMode.all.symbolName == "repeat")
        #expect(RepeatMode.one.symbolName == "repeat.1")
        #expect(ShuffleMode.off.isOn == false)
        #expect(ShuffleMode.albums.isOn)
    }
}

@Suite("Adapter parsing of playback position")
struct PositionParsingTests {

    @Test("Decodes timestamp, rate and queue position")
    func parsesPositionFields() {
        let line = """
        {"type":"now-playing","title":"Heartless","isPlaying":true,"duration":211,\
        "elapsed":170.7,"timestamp":1000000,"playbackRate":1,"queueIndex":2,"queueCount":82}
        """

        guard case .nowPlaying(let snapshot) = NowPlayingParser.parse(line: line) else {
            Issue.record("expected a now-playing message")
            return
        }
        #expect(snapshot.elapsedAt == Date(timeIntervalSince1970: 1_000_000))
        #expect(snapshot.playbackRate == 1)
        #expect(snapshot.queueIndex == 2)
        #expect(snapshot.queueCount == 82)
    }

    @Test("A missing timestamp merges as 'measured now' rather than nil")
    func fillsMissingTimestamp() {
        let snapshot = NowPlayingSnapshot(
            title: "Song", artist: nil, album: nil, isPlaying: true,
            duration: 100, elapsed: 5, hasContent: true,
            artworkData: nil, artworkChanged: true
        )

        let merged = NowPlayingParser.merge(previous: .idle, snapshot: snapshot)

        // Without this the progress bar would never advance for backends that
        // do not report a timestamp.
        #expect(merged.elapsedAt != nil)
    }
}
