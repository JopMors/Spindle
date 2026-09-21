import Foundation

/// Decodes the adapter's newline-delimited JSON and merges frames into state.
///
/// Pure, synchronous and dependency-free so it can be unit tested without
/// spawning a process.
enum NowPlayingParser {

    /// Parses one line from the adapter. Returns `nil` for blank lines and
    /// anything that is not valid JSON (the adapter shares stdout with perl,
    /// which can emit stray warnings).
    static func parse(line: String) -> AdapterMessage? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let data = trimmed.data(using: .utf8) else { return nil }
        guard let object = try? JSONSerialization.jsonObject(with: data),
              let json = object as? [String: Any] else { return nil }

        switch json["type"] as? String {
        case "error":
            return .failure(json["message"] as? String ?? "Unknown adapter error")
        case "now-playing":
            return .nowPlaying(snapshot(from: json))
        default:
            return nil
        }
    }

    private static func snapshot(from json: [String: Any]) -> NowPlayingSnapshot {
        NowPlayingSnapshot(
            title: string(json["title"]),
            artist: string(json["artist"]),
            album: string(json["album"]),
            isPlaying: json["isPlaying"] as? Bool ?? false,
            duration: number(json["duration"]),
            elapsed: number(json["elapsed"]),
            hasContent: json["hasContent"] as? Bool ?? true,
            artworkData: artwork(json["artwork"]),
            artworkChanged: json["artworkChanged"] as? Bool ?? true,
            elapsedAt: date(json["timestamp"]),
            playbackRate: number(json["playbackRate"]),
            queueIndex: integer(json["queueIndex"]),
            queueCount: integer(json["queueCount"]),
            sourceBundleID: string(json["sourceBundleID"])
        )
    }

    /// Applies a snapshot on top of existing state, carrying artwork forward
    /// when the adapter signalled that it is unchanged.
    static func merge(previous: NowPlaying, snapshot: NowPlayingSnapshot) -> NowPlaying {
        guard snapshot.hasContent else { return .idle }

        let artwork: Data?
        if snapshot.artworkChanged {
            artwork = snapshot.artworkData
        } else {
            artwork = snapshot.artworkData ?? previous.artworkData
        }

        return NowPlaying(
            title: snapshot.title,
            artist: snapshot.artist,
            album: snapshot.album,
            artworkData: artwork,
            isPlaying: snapshot.isPlaying,
            duration: snapshot.duration,
            elapsed: snapshot.elapsed,
            // Absent timestamp means the reading is as of now.
            elapsedAt: snapshot.elapsedAt ?? Date(),
            playbackRate: snapshot.playbackRate,
            queueIndex: snapshot.queueIndex,
            queueCount: snapshot.queueCount,
            // Carried forward: a frame can arrive before the source has been
            // resolved, and losing it would flip the button back to Music.
            sourceBundleID: snapshot.sourceBundleID ?? previous.sourceBundleID
        )
    }

    // MARK: - Field coercion

    /// JSON `null` decodes to `NSNull`, and empty strings should read as absent.
    private static func string(_ value: Any?) -> String? {
        guard let text = value as? String else { return nil }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func number(_ value: Any?) -> Double? {
        (value as? NSNumber)?.doubleValue
    }

    private static func integer(_ value: Any?) -> Int? {
        (value as? NSNumber)?.intValue
    }

    private static func date(_ value: Any?) -> Date? {
        guard let seconds = (value as? NSNumber)?.doubleValue, seconds > 0 else { return nil }
        return Date(timeIntervalSince1970: seconds)
    }

    private static func artwork(_ value: Any?) -> Data? {
        guard let base64 = value as? String, !base64.isEmpty else { return nil }
        return Data(base64Encoded: base64)
    }
}
