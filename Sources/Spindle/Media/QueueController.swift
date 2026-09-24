import Combine
import Foundation

/// Where the widget is in its own queue, zero-based, for the status bar.
struct QueuePosition: Equatable {
    let cursor: Int
    let count: Int
}

/// Owns the widget's queue and hands the next track to Music as the current one
/// ends. See `PlaybackQueue` for why the widget has to keep the order itself.
///
/// Music is only ever given one track at a time, out of the real playlist, so
/// next and previous have to come through here too — Music's own next-track
/// would just replay the single track it was handed.
@MainActor
final class QueueController: ObservableObject {

    @Published private(set) var position: QueuePosition?

    /// How far before the end of a track the next one is started. Music needs a
    /// moment to begin, and with repeat All it would otherwise loop the single
    /// track it was given for an audible instant.
    private static let handOffLead: TimeInterval = 0.4
    /// How long a title may disagree with the queue before we assume the user
    /// started something else and stop following along. Music keeps reporting
    /// the outgoing track for a moment after being asked for the next one.
    private static let settleWindow: TimeInterval = 4

    private let library: MusicLibraryProviding
    private let settings: AppSettings
    private let now: () -> Date

    private var queue: PlaybackQueue?
    /// The library the current queue came from. Pinned when playback starts,
    /// so moving the source toggle mid-queue cannot send the next track's
    /// position to a different library.
    private var target: MusicLibraryProviding?
    private var advanceTask: Task<Void, Never>?
    /// While this is in the future, a title that does not match the queue is
    /// Music catching up rather than the user intervening.
    private var settlesBy: Date?

    var isActive: Bool { queue != nil }

    init(
        library: MusicLibraryProviding,
        settings: AppSettings,
        now: @escaping () -> Date = Date.init
    ) {
        self.library = library
        self.settings = settings
        self.now = now
    }

    // MARK: - Starting

    /// Plays a hand-picked track out of its real container and keeps the rest of
    /// that container queued behind it.
    func play(
        trackIndex: Int,
        from container: QueueContainer,
        tracks: [LibraryTrack],
        completion: @escaping (MusicLibraryError?) -> Void
    ) {
        guard let queue = PlaybackQueue.picking(
            trackIndex: trackIndex, from: tracks, in: container, shuffle: settings.shuffleMode
        ) else {
            // The menu's track list and the container disagree; play the track
            // anyway rather than refusing the press.
            playOnce(trackIndex: trackIndex, in: container, completion: completion)
            return
        }
        target = library.playbackTarget
        adopt(queue, completion: completion)
    }

    /// Plays one track and queues nothing behind it.
    func playOnce(
        trackIndex: Int,
        in container: QueueContainer,
        completion: @escaping (MusicLibraryError?) -> Void
    ) {
        relinquish()
        target = library.playbackTarget
        send(trackIndex: trackIndex, in: container, completion: completion)
    }

    /// Music is playing something we did not queue — Play Playlist, or anything
    /// started elsewhere. Stop following.
    func relinquish() {
        advanceTask?.cancel()
        advanceTask = nil
        queue = nil
        target = nil
        settlesBy = nil
        position = nil
    }

    // MARK: - Following along

    /// Fresh playback data: re-arm the hand-off for the end of this track.
    func update(_ nowPlaying: NowPlaying) {
        guard let queue, let expected = queue.current else { return }
        guard nowPlaying.title == expected.name else {
            if let settlesBy, now() < settlesBy { return }
            relinquish()
            return
        }
        settlesBy = nil
        position = QueuePosition(cursor: queue.cursor, count: queue.count)
        arm(after: remaining(of: nowPlaying))
    }

    // MARK: - Skipping

    /// Repeat One pins the queue to one track, which is right when a track ends
    /// but not when the button is pressed on purpose.
    func skipForward() {
        guard let queue else { return }
        let mode: RepeatMode = settings.repeatMode == .one ? .all : settings.repeatMode
        guard let next = queue.advanced(repeatMode: mode) else { return }
        adopt(next) { _ in }
    }

    func skipBackward() {
        guard let queue else { return }
        adopt(queue.rewound()) { _ in }
    }

    /// Internal rather than private so tests can drive the hand-off without
    /// waiting on a real timer.
    func advance() {
        guard let queue else { return }
        guard let next = queue.advanced(repeatMode: settings.repeatMode) else {
            relinquish()
            return
        }
        adopt(next) { _ in }
    }

    // MARK: - Plumbing

    private func adopt(
        _ next: PlaybackQueue,
        completion: @escaping (MusicLibraryError?) -> Void
    ) {
        guard let track = next.current else {
            relinquish()
            return
        }
        advanceTask?.cancel()
        advanceTask = nil
        queue = next
        position = QueuePosition(cursor: next.cursor, count: next.count)
        settlesBy = now().addingTimeInterval(Self.settleWindow)
        send(trackIndex: track.index, in: next.container, completion: completion)
    }

    private func send(
        trackIndex: Int,
        in container: QueueContainer,
        completion: @escaping (MusicLibraryError?) -> Void
    ) {
        let library = target ?? self.library
        switch container {
        case .playlist(let index):
            library.play(playlistIndex: index, trackIndex: trackIndex, completion: completion)
        case .library:
            library.playFromLibrary(trackIndex: trackIndex, completion: completion)
        }
    }

    /// Nil while paused or without a duration, which cancels the hand-off until
    /// the next update brings playback back.
    private func remaining(of nowPlaying: NowPlaying) -> TimeInterval? {
        guard nowPlaying.isPlaying,
              let duration = nowPlaying.duration, duration > 0,
              let elapsed = nowPlaying.elapsed(at: now()) else { return nil }
        return max(duration - elapsed - Self.handOffLead, 0)
    }

    private func arm(after remaining: TimeInterval?) {
        advanceTask?.cancel()
        advanceTask = nil
        guard let remaining else { return }
        advanceTask = Task { [weak self] in
            if remaining > 0 {
                try? await Task.sleep(for: .seconds(remaining))
            }
            guard !Task.isCancelled else { return }
            self?.advance()
        }
    }

    func stop() {
        advanceTask?.cancel()
        advanceTask = nil
    }
}
