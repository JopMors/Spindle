import Foundation

/// One row on the original's screen.
struct MenuRow: Equatable, Identifiable {
    enum Accessory: Equatable {
        /// The chevron that meant "this goes somewhere".
        case chevron
        /// A settable value shown on the right, as the original's Settings did.
        case value(String)
        case none
    }

    let id: String
    let title: String
    var accessory: Accessory = .chevron
}

/// Where the menu currently is. Each case knows how to title itself; the rows
/// come from `MenuScreenModel`, which is what holds the library data.
enum MenuLevel: Equatable {
    case main
    case music
    case playlists
    case playlist(index: Int, name: String)
    case artists
    case artist(String)
    case albums
    case album(String)
    case songs

    var title: String {
        switch self {
        case .main: return "Spindle"
        case .music: return "Music"
        case .playlists: return "Playlists"
        case .playlist(_, let name): return name
        case .artists: return "Artists"
        case .artist(let name): return name
        case .albums: return "Albums"
        case .album(let name): return name
        case .songs: return "Songs"
        }
    }

    /// True where the rows come from Music.app rather than being static.
    var needsLibrary: Bool {
        switch self {
        case .main, .music: return false
        default: return true
        }
    }
}

/// What selecting a row asked for. Kept separate from the model so the view
/// model can act on it without the menu knowing about playback.
enum MenuAction: Equatable {
    case push(MenuLevel)
    case pop
    case playLibraryTrack(index: Int)
    case playPlaylistTrack(playlistIndex: Int, trackIndex: Int)
    /// Plays a whole container from the top. `nil` is the entire library.
    case playAll(playlistIndex: Int?)
    case cycleShuffle
    case cycleRepeat
    case openSettings
    case showNowPlaying
}

/// Identifiers for the static rows, so selection stays a lookup rather than a
/// string comparison against display text.
enum MenuRowID {
    static let music = "music"
    static let shuffle = "shuffle"
    static let repeatMode = "repeat"
    static let settings = "settings"
    static let nowPlaying = "now-playing"
    static let playlists = "playlists"
    static let artists = "artists"
    static let albums = "albums"
    static let songs = "songs"
    static let playAll = "play-all"

    static func track(_ index: Int) -> String { "track:\(index)" }
    static func playlist(_ index: Int) -> String { "playlist:\(index)" }
    static func group(_ name: String) -> String { "group:\(name)" }
}
