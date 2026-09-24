import Foundation

/// Starts playback in Spotify. A protocol so tests record rather than play.
protocol SpotifyPlaying: AnyObject {
    /// Plays `uri` — a track or a whole playlist — optionally inside `context`,
    /// so Spotify's own Up Next follows on from it.
    func play(uri: String, context: String?, completion: @escaping (MusicLibraryError?) -> Void)
}

/// Plays through Spotify's AppleScript `play track … in context …`.
///
/// Unlike the Web API's player endpoints this needs neither Premium nor an
/// extra scope, and it drives the desktop app the widget is already showing.
final class SpotifyAppleScriptPlayer: SpotifyPlaying {

    private let queue = DispatchQueue(label: "nl.jopmors.spindle.spotify-player")

    func play(uri: String, context: String?, completion: @escaping (MusicLibraryError?) -> Void) {
        // URIs come from the Web API, so they are checked before they are
        // written into script source.
        guard Self.isSafeURI(uri), context.map(Self.isSafeURI) ?? true else {
            completion(.failed("Spotify sent an unplayable link"))
            return
        }
        let contextClause = context.map { " in context \"\($0)\"" } ?? ""
        let source = "tell application \"Spotify\" to play track \"\(uri)\"\(contextClause)"
        queue.async {
            let error = Self.execute(source)
            DispatchQueue.main.async { completion(error) }
        }
    }

    /// `spotify:` followed by the characters Spotify IDs and usernames use.
    static func isSafeURI(_ uri: String) -> Bool {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: ":._-"))
        return uri.hasPrefix("spotify:")
            && uri.unicodeScalars.allSatisfy { $0.isASCII && allowed.contains($0) }
    }

    private static func execute(_ source: String) -> MusicLibraryError? {
        guard let script = NSAppleScript(source: source) else {
            return .failed("Could not compile the Spotify command")
        }
        var errorInfo: NSDictionary?
        script.executeAndReturnError(&errorInfo)
        guard let errorInfo else { return nil }

        let code = errorInfo[NSAppleScript.errorNumber] as? Int ?? 0
        let message = errorInfo[NSAppleScript.errorMessage] as? String ?? "AppleScript failed"
        NSLog("Spindle: Spotify AppleScript failed (\(code)): \(message)")
        switch code {
        case -1743, -1744:
            return .failed("Allow Automation for Spotify in System Settings")
        case -600, -609, -1728, -10814:
            return .failed("Spotify is unavailable")
        default:
            return .failed(message)
        }
    }
}
