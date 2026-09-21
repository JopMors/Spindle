import Foundation

/// Formats playback times the way the original did: elapsed counting up on the
/// left, time *remaining* counting down on the right with a leading minus.
enum TimeFormatting {

    /// `m:ss`, or `h:mm:ss` past an hour. Negative input clamps to zero, which
    /// is what a stale elapsed reading can produce right after a track change.
    static func duration(_ seconds: TimeInterval) -> String {
        let total = Int(max(seconds, 0).rounded(.down))
        let (hours, minutes, secs) = (total / 3600, (total % 3600) / 60, total % 60)
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%d:%02d", minutes, secs)
    }

    /// Remaining time, rendered as `-1:23`. Returns nil without a duration.
    static func remaining(elapsed: TimeInterval?, duration: TimeInterval?) -> String? {
        guard let duration, duration > 0 else { return nil }
        let left = duration - max(elapsed ?? 0, 0)
        return "-" + self.duration(max(left, 0))
    }

    /// The original's queue counter, one-based: "3 of 82".
    static func queuePosition(index: Int?, count: Int?) -> String? {
        guard let count, count > 1 else { return nil }
        guard let index, index >= 0, index < count else { return nil }
        return "\(index + 1) of \(count)"
    }
}
