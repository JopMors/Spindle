import Foundation

/// Whose library the menu browses.
enum LibrarySource: String, Equatable {
    case music
    case spotify

    /// Follows the note-button toggle. Media means whatever is playing, so the
    /// menu browses Spotify while Spotify plays and Music the rest of the time
    /// — a browser has no library to browse.
    static func resolve(target: WheelSourceTarget, nowPlayingBundleID: String?) -> LibrarySource {
        switch target {
        case .appleMusic: return .music
        case .spotify: return .spotify
        case .media:
            return nowPlayingBundleID == WheelSourceTarget.spotifyBundleIdentifier ? .spotify : .music
        }
    }
}

/// A library whose source can be switched.
protocol LibrarySwitching: MusicLibraryProviding {
    var source: LibrarySource { get set }
}

/// Hands every request to Music or Spotify, whichever is selected.
///
/// Sits where `MusicLibrary` used to, so the menu, the queue and the preview
/// need not know that there is more than one library.
final class LibraryRouter: LibrarySwitching {

    var source: LibrarySource = .music

    private let music: MusicLibraryProviding
    private let spotify: MusicLibraryProviding

    init(music: MusicLibraryProviding, spotify: MusicLibraryProviding) {
        self.music = music
        self.spotify = spotify
    }

    private var current: MusicLibraryProviding {
        switch source {
        case .music: return music
        case .spotify: return spotify
        }
    }

    /// The library itself rather than the router, so a queue keeps talking to
    /// the library it started in after the toggle moves.
    var playbackTarget: MusicLibraryProviding { current }

    func playlists(completion: @escaping (Result<[LibraryPlaylist], MusicLibraryError>) -> Void) {
        current.playlists(completion: completion)
    }

    func tracks(
        playlistIndex: Int?,
        completion: @escaping (Result<[LibraryTrack], MusicLibraryError>) -> Void
    ) {
        current.tracks(playlistIndex: playlistIndex, completion: completion)
    }

    func play(playlistIndex: Int, trackIndex: Int, completion: ((MusicLibraryError?) -> Void)?) {
        current.play(playlistIndex: playlistIndex, trackIndex: trackIndex, completion: completion)
    }

    func playFromLibrary(trackIndex: Int, completion: ((MusicLibraryError?) -> Void)?) {
        current.playFromLibrary(trackIndex: trackIndex, completion: completion)
    }

    func playAll(playlistIndex: Int?, completion: ((MusicLibraryError?) -> Void)?) {
        current.playAll(playlistIndex: playlistIndex, completion: completion)
    }

    func artwork(playlistIndex: Int?, trackIndex: Int, completion: @escaping (Data?) -> Void) {
        current.artwork(playlistIndex: playlistIndex, trackIndex: trackIndex, completion: completion)
    }
}
