import Foundation

/// Where a queue's tracks came from, so the next one can be addressed in the
/// user's own library rather than in a copy of it.
enum QueueContainer: Equatable {
    case playlist(index: Int)
    case library
}

/// The running order the widget keeps for itself.
///
/// Music.app cannot be asked to start a playlist anywhere but its first track.
/// Verified on macOS 26.5.2: `current playlist` is read-only, there is no queue
/// command, playing a range of tracks queues nothing, and stepping forward with
/// `next track` is throttled to roughly one step per half second — unusable
/// across a few hundred tracks. Copying the list into a working playlist did
/// make Music own the queue, at the cost of a duplicate playlist in the library.
///
/// So the widget owns the order instead and plays each track straight out of the
/// real container as the one before it ends. Nothing is written to the library.
struct PlaybackQueue: Equatable {
    let container: QueueContainer
    /// Tracks in playing order. Each `index` is its position in `container`.
    let tracks: [LibraryTrack]
    let cursor: Int

    var current: LibraryTrack? {
        tracks.indices.contains(cursor) ? tracks[cursor] : nil
    }

    var count: Int { tracks.count }

    /// The order that follows picking a track by hand.
    ///
    /// Unshuffled that is the container's own order, starting where the user
    /// pointed. Shuffled it is the chosen track first and the rest in random
    /// order: picking a song is a request for *that* song, and shuffle governs
    /// only what comes after it.
    static func picking(
        trackIndex: Int,
        from tracks: [LibraryTrack],
        in container: QueueContainer,
        shuffle: ShuffleMode,
        shuffling: ([LibraryTrack]) -> [LibraryTrack] = { $0.shuffled() }
    ) -> PlaybackQueue? {
        guard let cursor = tracks.firstIndex(where: { $0.index == trackIndex }) else { return nil }
        guard shuffle.isOn else {
            return PlaybackQueue(container: container, tracks: tracks, cursor: cursor)
        }
        let rest = Array(tracks[..<cursor]) + Array(tracks[(cursor + 1)...])
        return PlaybackQueue(
            container: container,
            tracks: [tracks[cursor]] + shuffling(rest),
            cursor: 0
        )
    }

    /// The queue after the current track finishes, or nil when playback should
    /// stop — which is what repeat Off means at the end of a list.
    func advanced(repeatMode: RepeatMode) -> PlaybackQueue? {
        guard repeatMode != .one else { return self }
        let next = cursor + 1
        if next < tracks.count { return moved(to: next) }
        return repeatMode == .all ? moved(to: 0) : nil
    }

    /// One step back. At the first track it returns itself, so the button
    /// restarts the song rather than doing nothing, as the original's did.
    func rewound() -> PlaybackQueue {
        moved(to: max(cursor - 1, 0))
    }

    private func moved(to cursor: Int) -> PlaybackQueue {
        PlaybackQueue(container: container, tracks: tracks, cursor: cursor)
    }
}
