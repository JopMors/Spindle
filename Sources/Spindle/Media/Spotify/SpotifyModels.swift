import Foundation

/// What can go wrong talking to Spotify, before it is turned into something
/// the screen can show.
enum SpotifyError: Error, Equatable {
    /// No Client ID, or never signed in.
    case notConnected
    /// The browser round trip failed or was declined.
    case authorization(String)
    case rateLimited
    case http(Int)
    case invalidResponse

    var message: String {
        switch self {
        case .notConnected: return "Connect Spotify in Settings"
        case .authorization(let detail): return detail
        case .rateLimited: return "Spotify is busy, try again shortly"
        case .http(let status): return "Spotify answered \(status)"
        case .invalidResponse: return "Spotify sent something unexpected"
        }
    }
}

// MARK: - Domain

/// A track the menu can list and Spotify can play.
struct SpotifyTrack: Equatable {
    let uri: String
    let name: String
    let artist: String
    let album: String
    let artworkURL: URL?
    var lastPlayed: Date? = nil
    /// When it was liked. Only known for Liked Songs.
    var dateAdded: Date? = nil

    func played(at date: Date?) -> SpotifyTrack {
        SpotifyTrack(uri: uri, name: name, artist: artist, album: album,
                     artworkURL: artworkURL, lastPlayed: date, dateAdded: dateAdded)
    }

    func added(at date: Date?) -> SpotifyTrack {
        SpotifyTrack(uri: uri, name: name, artist: artist, album: album,
                     artworkURL: artworkURL, lastPlayed: lastPlayed, dateAdded: date)
    }
}

/// One entry of the listening history.
struct SpotifyPlay: Equatable {
    let uri: String
    let playedAt: Date
}

/// A playlist whose tracks Spotify will actually hand over.
struct SpotifyPlaylist: Equatable {
    let id: String
    let uri: String
    let name: String
}

// MARK: - Wire format

/// One page of any paged Spotify list.
struct SpotifyPage<Item: Decodable>: Decodable {
    let items: [Item]
    let next: URL?
}

struct SpotifyUser: Decodable {
    let id: String
}

struct SpotifyPlaylistObject: Decodable {
    let id: String
    let name: String
    let uri: String
    let collaborative: Bool?
    let owner: SpotifyUser
}

/// A playlist entry. Since February 2026 the content is under `item`; the old
/// `track` key is still sent but deprecated, so it is only a fallback.
///
/// Entries that fail to decode — episodes in odd shapes, removed tracks — are
/// read as empty rather than failing the whole page.
struct SpotifyPlaylistItem: Decodable {
    let content: SpotifyTrackObject?

    private enum CodingKeys: String, CodingKey { case item, track }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let item = try? container.decodeIfPresent(SpotifyTrackObject.self, forKey: .item)
        let track = try? container.decodeIfPresent(SpotifyTrackObject.self, forKey: .track)
        content = (item ?? nil) ?? (track ?? nil)
    }
}

/// A Liked Songs entry.
struct SpotifySavedTrack: Decodable {
    let track: SpotifyTrackObject?
    let addedAt: Date?

    private enum CodingKeys: String, CodingKey { case track, addedAt }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        track = (try? container.decodeIfPresent(SpotifyTrackObject.self, forKey: .track)) ?? nil
        addedAt = (try? container.decodeIfPresent(Date.self, forKey: .addedAt)) ?? nil
    }

    var libraryTrack: SpotifyTrack? {
        track?.libraryTrack?.added(at: addedAt)
    }
}

/// A recently-played entry.
struct SpotifyPlayHistoryItem: Decodable {
    let track: SpotifyTrackObject
    let playedAt: Date
}

struct SpotifyTrackObject: Decodable {
    struct Artist: Decodable { let name: String }
    struct Image: Decodable {
        let url: URL
        let width: Int?
    }
    struct Album: Decodable {
        let name: String
        let images: [Image]?
    }

    let type: String?
    let uri: String
    let name: String
    let isLocal: Bool?
    let artists: [Artist]?
    let album: Album?

    /// Covers come in several sizes; about 300 px is plenty for the screen and
    /// a fraction of the 640 px download.
    private static let preferredArtworkWidth = 300

    /// Nil for anything the menu should not offer: episodes, and local files,
    /// which Spotify cannot be asked to play by URI.
    var libraryTrack: SpotifyTrack? {
        guard type == nil || type == "track", isLocal != true,
              uri.hasPrefix("spotify:track:") else { return nil }
        return SpotifyTrack(
            uri: uri,
            name: name,
            artist: artists?.first?.name ?? "",
            album: album?.name ?? "",
            artworkURL: artworkURL
        )
    }

    private var artworkURL: URL? {
        let images = album?.images ?? []
        let fitting = images
            .filter { ($0.width ?? 0) >= Self.preferredArtworkWidth }
            .min { ($0.width ?? 0) < ($1.width ?? 0) }
        return (fitting ?? images.first)?.url
    }
}

/// What the token endpoint returns.
struct SpotifyTokenResponse: Decodable {
    let accessToken: String
    let expiresIn: Int
    let refreshToken: String?
}
