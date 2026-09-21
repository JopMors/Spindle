import Foundation

/// What the views render. Deliberately backend-agnostic: nothing here reveals
/// whether the data came from MediaRemote, the perl adapter, or AppleScript.
struct NowPlaying: Equatable {
    var title: String?
    var artist: String?
    var album: String?
    var artworkData: Data?
    var isPlaying: Bool
    var duration: TimeInterval?
    var elapsed: TimeInterval?
    /// When `elapsed` was measured. Elapsed is a reading at a point in time,
    /// not a live value, so the progress bar has to extrapolate from here.
    var elapsedAt: Date?
    var playbackRate: Double?
    /// Position in the playback queue, as the original's "3 of 82".
    var queueIndex: Int?
    var queueCount: Int?
    /// Which app owns the audio. Read inside the adapter, because MediaRemote
    /// refuses it to ordinary processes exactly as it refuses the now-playing
    /// dictionary.
    var sourceBundleID: String?

    static let idle = NowPlaying(isPlaying: false)

    /// True when there is nothing worth showing on the screen.
    var isIdle: Bool {
        title?.isEmpty != false && artist?.isEmpty != false
    }

    var progress: Double? {
        guard let duration, duration > 0, let elapsed else { return nil }
        return min(max(elapsed / duration, 0), 1)
    }

    /// Elapsed time extrapolated to `date`, so the counter ticks between the
    /// adapter's updates instead of freezing until the next notification.
    func elapsed(at date: Date) -> TimeInterval? {
        guard let elapsed else { return nil }
        guard isPlaying, let elapsedAt else { return elapsed }
        let rate = playbackRate ?? 1
        let projected = elapsed + date.timeIntervalSince(elapsedAt) * max(rate, 0)
        guard let duration, duration > 0 else { return max(projected, 0) }
        return min(max(projected, 0), duration)
    }

    func progress(at date: Date) -> Double? {
        guard let duration, duration > 0, let elapsed = elapsed(at: date) else { return nil }
        return min(max(elapsed / duration, 0), 1)
    }
}

/// One decoded message from the adapter stream.
enum AdapterMessage: Equatable {
    case nowPlaying(NowPlayingSnapshot)
    case failure(String)
}

/// A single frame from the adapter, before artwork carry-over is applied.
///
/// The adapter omits artwork when it has not changed, so `artworkData` being
/// `nil` while `artworkChanged` is `false` means "reuse what you already have".
struct NowPlayingSnapshot: Equatable {
    var title: String?
    var artist: String?
    var album: String?
    var isPlaying: Bool
    var duration: TimeInterval?
    var elapsed: TimeInterval?
    var hasContent: Bool
    var artworkData: Data?
    var artworkChanged: Bool
    /// Declared last with defaults so the existing call sites stay valid.
    var elapsedAt: Date?
    var playbackRate: Double?
    var queueIndex: Int?
    var queueCount: Int?
    var sourceBundleID: String?
}

/// Transport actions the click wheel can trigger.
enum TransportCommand: Equatable {
    case togglePlayPause
    case nextTrack
    case previousTrack
}
