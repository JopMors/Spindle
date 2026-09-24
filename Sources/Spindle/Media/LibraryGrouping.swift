import Foundation

/// How Artists and Albums are ordered: what you played most recently first.
///
/// A group counts from its most recently played track. Groups with no known
/// play follow, most recently added first — Spotify only reports the last 50
/// plays, so this keeps the rest of the list meaningful — and anything with no
/// dates at all ends A to Z.
enum LibraryGrouping {

    static func recentFirst(_ tracks: [LibraryTrack], by field: KeyPath<LibraryTrack, String>) -> [String] {
        var groups: [String: Recency] = [:]
        for track in tracks {
            let name = track[keyPath: field]
            guard !name.isEmpty else { continue }
            groups[name, default: Recency()].include(track)
        }
        return groups
            .sorted { lhs, rhs in lhs.value.isMoreRecent(than: rhs.value, tieBreak: (lhs.key, rhs.key)) }
            .map(\.key)
    }

    private struct Recency {
        var lastPlayed: Date?
        var dateAdded: Date?

        mutating func include(_ track: LibraryTrack) {
            lastPlayed = latest(lastPlayed, track.lastPlayed)
            dateAdded = latest(dateAdded, track.dateAdded)
        }

        func isMoreRecent(than other: Recency, tieBreak names: (String, String)) -> Bool {
            if let order = Self.newerFirst(lastPlayed, other.lastPlayed) { return order }
            if let order = Self.newerFirst(dateAdded, other.dateAdded) { return order }
            return names.0.localizedCaseInsensitiveCompare(names.1) == .orderedAscending
        }

        /// Nil when the two do not decide it. A date beats no date.
        private static func newerFirst(_ lhs: Date?, _ rhs: Date?) -> Bool? {
            switch (lhs, rhs) {
            case let (l?, r?) where l != r: return l > r
            case (.some, nil): return true
            case (nil, .some): return false
            default: return nil
            }
        }

        private func latest(_ lhs: Date?, _ rhs: Date?) -> Date? {
            guard let lhs else { return rhs }
            guard let rhs else { return lhs }
            return max(lhs, rhs)
        }
    }
}
