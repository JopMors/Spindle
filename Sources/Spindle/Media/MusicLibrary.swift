import Foundation

/// A track as the menu needs it: what to show, and enough to play it again.
///
/// `index` is the track's one-based position in its containing playlist, which
/// is how playback addresses it. Addressing by position rather than by name
/// avoids quoting user data back into AppleScript source entirely.
struct LibraryTrack: Equatable, Identifiable {
    let index: Int
    let name: String
    let artist: String
    let album: String

    var id: Int { index }
}

/// A named playlist and its position in Music's list.
struct LibraryPlaylist: Equatable, Identifiable {
    let index: Int
    let name: String

    var id: Int { index }
}

enum MusicLibraryError: LocalizedError, Equatable {
    case notAuthorised
    case musicUnavailable
    case spotifyNotConnected
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .notAuthorised:
            return "Allow Spindle to control Music in System Settings → Privacy & Security → Automation."
        case .musicUnavailable:
            return "The Music app is not available."
        case .spotifyNotConnected:
            return "Connect Spotify in Spindle's Settings to browse it."
        case .failed(let detail):
            return detail
        }
    }

    /// Short enough for the original's screen.
    var screenMessage: String {
        switch self {
        case .notAuthorised: return "Allow Automation for Music in System Settings"
        case .musicUnavailable: return "Music is unavailable"
        case .spotifyNotConnected: return SpotifyError.notConnected.message
        case .failed(let detail): return detail
        }
    }
}

/// The menu's view of the library. A protocol so the navigation, grouping and
/// row-building logic can be tested without Music.app and without playing
/// anything on the machine running the tests.
protocol MusicLibraryProviding: AnyObject {
    func playlists(completion: @escaping (Result<[LibraryPlaylist], MusicLibraryError>) -> Void)
    func tracks(
        playlistIndex: Int?,
        completion: @escaping (Result<[LibraryTrack], MusicLibraryError>) -> Void
    )
    func play(
        playlistIndex: Int,
        trackIndex: Int,
        completion: ((MusicLibraryError?) -> Void)?
    )
    func playFromLibrary(
        trackIndex: Int,
        completion: ((MusicLibraryError?) -> Void)?
    )
    func playAll(playlistIndex: Int?, completion: ((MusicLibraryError?) -> Void)?)
    /// Cover art for one track, or nil when it has none. Nil playlist means the
    /// whole library, as everywhere else here.
    func artwork(playlistIndex: Int?, trackIndex: Int, completion: @escaping (Data?) -> Void)
    /// The library a queue should keep playing from. Itself, except for a
    /// router, which answers with whichever library it is pointing at now.
    var playbackTarget: MusicLibraryProviding { get }
}

extension MusicLibraryProviding {
    var playbackTarget: MusicLibraryProviding { self }
}

/// Reads playlists and tracks out of Music.app, and starts playback.
///
/// Everything runs on a private serial queue: `NSAppleScript` blocks, and a
/// cold Music.app can take a moment to answer, which must never be on the main
/// thread when the widget is meant to keep animating.
final class MusicLibrary: MusicLibraryProviding {

    private let queue = DispatchQueue(label: "nl.jopmors.spindle.library")

    // MARK: - Reads

    func playlists(completion: @escaping (Result<[LibraryPlaylist], MusicLibraryError>) -> Void) {
        run(script: Self.playlistsScript) { result in
            completion(result.map { descriptor in
                Self.strings(from: descriptor).enumerated().map { offset, name in
                    LibraryPlaylist(index: offset + 1, name: name)
                }
            })
        }
    }

    /// All tracks of one playlist, or of the whole library when `playlist` is
    /// nil. One call fetches every field; Artists, Albums and Songs are then
    /// groupings of the same array rather than three more round trips.
    func tracks(
        playlistIndex: Int?,
        completion: @escaping (Result<[LibraryTrack], MusicLibraryError>) -> Void
    ) {
        let container = playlistIndex.map { "user playlist \($0)" } ?? "library playlist 1"
        run(script: Self.tracksScript(container: container)) { result in
            completion(result.map(Self.tracks(from:)))
        }
    }

    /// Cover art for a single track.
    ///
    /// Music hands this back as JPEG bytes — verified at 1200x1200 on a real
    /// track — so it goes straight into `NSImage`. One round trip per track,
    /// which is why the caller debounces and caches rather than asking for a
    /// whole list at once.
    func artwork(
        playlistIndex: Int?,
        trackIndex: Int,
        completion: @escaping (Data?) -> Void
    ) {
        let container = playlistIndex.map { "user playlist \($0)" } ?? "library playlist 1"
        let source = """
        tell application "Music"
            set theTrack to track \(trackIndex) of \(container)
            if (count of artworks of theTrack) is 0 then return missing value
            return data of artwork 1 of theTrack
        end tell
        """
        run(script: source) { result in
            guard case .success(let descriptor) = result else {
                completion(nil)
                return
            }
            let data = descriptor.data
            completion(data.isEmpty ? nil : data)
        }
    }

    // MARK: - Playback

    /// Plays exactly one track, out of the user's own playlist. Continuing on
    /// through the rest of that playlist is `QueueController`'s job, because
    /// Music cannot be asked to queue from anywhere but a playlist's first
    /// track — see `PlaybackQueue`.
    func play(
        playlistIndex: Int,
        trackIndex: Int,
        completion: ((MusicLibraryError?) -> Void)? = nil
    ) {
        play(
            container: "user playlist \(playlistIndex)",
            trackIndex: trackIndex,
            completion: completion
        )
    }

    func playFromLibrary(
        trackIndex: Int,
        completion: ((MusicLibraryError?) -> Void)? = nil
    ) {
        play(
            container: "library playlist 1",
            trackIndex: trackIndex,
            completion: completion
        )
    }

    /// Plays a whole playlist rather than one track out of it, so Music queues
    /// the rest behind it and shuffle and repeat have something to work on.
    /// `nil` plays the entire library.
    func playAll(playlistIndex: Int?, completion: ((MusicLibraryError?) -> Void)? = nil) {
        let container = playlistIndex.map { "user playlist \($0)" } ?? "library playlist 1"
        let source = """
        tell application "Music"
            play \(container)
        end tell
        """
        run(script: source) { result in
            completion?(result.error)
        }
    }

    private func play(
        container: String,
        trackIndex: Int,
        completion: ((MusicLibraryError?) -> Void)?
    ) {
        let source = """
        tell application "Music"
            play track \(trackIndex) of \(container)
        end tell
        """
        run(script: source) { result in
            completion?(result.error)
        }
    }

    // MARK: - Scripts

    private static let playlistsScript = """
    tell application "Music" to get name of every user playlist
    """

    private static func tracksScript(container: String) -> String {
        // Three parallel lists in one round trip. Asking for the fields track
        // by track takes seconds on a real library; this takes milliseconds.
        //
        // The plural has to stay a *reference* — binding `every track` to a
        // variable first resolves it to object specifiers, and Music then
        // refuses to read `name` off the list.
        """
        tell application "Music"
            set thePlaylist to \(container)
            return {name of every track of thePlaylist, \
        artist of every track of thePlaylist, \
        album of every track of thePlaylist}
        end tell
        """
    }

    // MARK: - Descriptor decoding

    private static func strings(from descriptor: NSAppleEventDescriptor) -> [String] {
        guard descriptor.numberOfItems > 0 else {
            return descriptor.stringValue.map { [$0] } ?? []
        }
        return (1...descriptor.numberOfItems).compactMap {
            descriptor.atIndex($0)?.stringValue
        }
    }

    private static func tracks(from descriptor: NSAppleEventDescriptor) -> [LibraryTrack] {
        guard descriptor.numberOfItems >= 3,
              let names = descriptor.atIndex(1),
              let artists = descriptor.atIndex(2),
              let albums = descriptor.atIndex(3) else { return [] }

        let nameList = strings(from: names)
        let artistList = strings(from: artists)
        let albumList = strings(from: albums)

        return nameList.enumerated().map { offset, name in
            LibraryTrack(
                index: offset + 1,
                name: name,
                artist: offset < artistList.count ? artistList[offset] : "",
                album: offset < albumList.count ? albumList[offset] : ""
            )
        }
    }

    // MARK: - Execution

    private func run(
        script source: String,
        completion: @escaping (Result<NSAppleEventDescriptor, MusicLibraryError>) -> Void
    ) {
        queue.async {
            let result = Self.execute(source)
            DispatchQueue.main.async { completion(result) }
        }
    }

    private static func execute(
        _ source: String
    ) -> Result<NSAppleEventDescriptor, MusicLibraryError> {
        guard let script = NSAppleScript(source: source) else {
            return .failure(.failed("Could not compile the query"))
        }
        var errorInfo: NSDictionary?
        let descriptor = script.executeAndReturnError(&errorInfo)
        guard let errorInfo else { return .success(descriptor) }

        let code = errorInfo[NSAppleScript.errorNumber] as? Int ?? 0
        let message = errorInfo[NSAppleScript.errorMessage] as? String ?? "AppleScript failed"
        switch code {
        case -1743, -1744:
            return .failure(.notAuthorised)
        case -600, -609, -1728:
            return .failure(.musicUnavailable)
        default:
            return .failure(.failed(message))
        }
    }
}

private extension Result where Failure == MusicLibraryError {
    var error: MusicLibraryError? {
        if case .failure(let error) = self { return error }
        return nil
    }
}
