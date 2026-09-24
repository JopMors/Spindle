import Foundation

/// Hands out a valid access token, refreshing it when asked to.
protocol SpotifyTokenProviding: AnyObject {
    func accessToken(forceRefresh: Bool) async throws -> String
}

/// The menu's view of a Spotify account. A protocol so `SpotifyLibrary` can be
/// tested without the network.
protocol SpotifyCatalog: AnyObject {
    /// Only the playlists whose tracks Spotify will return.
    func playlists() async throws -> [SpotifyPlaylist]
    func playlistTracks(id: String) async throws -> [SpotifyTrack]
    /// Liked Songs, which stand in for Music's library.
    func savedTracks() async throws -> [SpotifyTrack]
    func currentUserID() async throws -> String
}

/// Reads playlists and Liked Songs from the Spotify Web API.
///
/// Read-only on purpose: playback goes through Spotify's own AppleScript, which
/// needs no extra scope and works without the Web API's Premium-only player
/// endpoints.
final class SpotifyWebAPI: SpotifyCatalog {

    static let baseURL = URL(string: "https://api.spotify.com/v1/")!
    private static let pageLimit = 50
    /// 10 000 items. A ceiling so a looping `next` link cannot run forever.
    private static let maxPages = 200

    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()

    private let tokens: SpotifyTokenProviding
    private let session: URLSession

    init(tokens: SpotifyTokenProviding, session: URLSession = .shared) {
        self.tokens = tokens
        self.session = session
    }

    // MARK: - SpotifyCatalog

    func playlists() async throws -> [SpotifyPlaylist] {
        let userID = try await currentUserID()
        let objects: [SpotifyPlaylistObject] = try await allPages(of: "me/playlists")
        return Self.readable(objects, userID: userID)
    }

    func playlistTracks(id: String) async throws -> [SpotifyTrack] {
        guard Self.isSafeIdentifier(id) else { throw SpotifyError.invalidResponse }
        let items: [SpotifyPlaylistItem] = try await allPages(
            of: "playlists/\(id)/items", extraQuery: [URLQueryItem(name: "additional_types", value: "track")]
        )
        return items.compactMap(\.content).compactMap(\.libraryTrack)
    }

    func savedTracks() async throws -> [SpotifyTrack] {
        let items: [SpotifySavedTrack] = try await allPages(of: "me/tracks")
        return items.compactMap(\.track).compactMap(\.libraryTrack)
    }

    /// Not cached: one small request, and signing in as someone else must not
    /// leave the previous account's playlists filtered in.
    func currentUserID() async throws -> String {
        let user: SpotifyUser = try await get(Self.baseURL.appendingPathComponent("me"))
        return user.id
    }

    // MARK: - Rules

    /// Since February 2026 Spotify returns a playlist's contents only to its
    /// owner and collaborators, so listing any other playlist would open onto
    /// an empty screen.
    static func readable(_ objects: [SpotifyPlaylistObject], userID: String) -> [SpotifyPlaylist] {
        objects
            .filter { $0.owner.id == userID || $0.collaborative == true }
            .map { SpotifyPlaylist(id: $0.id, uri: $0.uri, name: $0.name) }
    }

    /// Paging links come from the response, so they are checked before the
    /// access token is sent anywhere with them.
    static func isTrustedPageURL(_ url: URL) -> Bool {
        url.scheme == "https" && url.host == baseURL.host
    }

    static func isSafeIdentifier(_ id: String) -> Bool {
        !id.isEmpty && id.unicodeScalars.allSatisfy { CharacterSet.alphanumerics.contains($0) }
    }

    // MARK: - Transport

    private func allPages<Item: Decodable>(
        of path: String,
        extraQuery: [URLQueryItem] = []
    ) async throws -> [Item] {
        var components = URLComponents(
            url: Self.baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false
        )!
        components.queryItems = [URLQueryItem(name: "limit", value: String(Self.pageLimit))] + extraQuery
        var next = components.url
        var collected: [Item] = []
        var pages = 0

        while let url = next, pages < Self.maxPages {
            let page: SpotifyPage<Item> = try await get(url)
            collected += page.items
            next = page.next.flatMap { Self.isTrustedPageURL($0) ? $0 : nil }
            pages += 1
        }
        return collected
    }

    /// One authorised GET. A 401 gets one retry with a fresh token, since an
    /// access token can lapse between being handed out and being used.
    private func get<T: Decodable>(_ url: URL, isRetry: Bool = false) async throws -> T {
        let token = try await tokens.accessToken(forceRefresh: isRetry)
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)
        guard let status = (response as? HTTPURLResponse)?.statusCode else {
            throw SpotifyError.invalidResponse
        }
        switch status {
        case 200..<300:
            do {
                return try Self.decoder.decode(T.self, from: data)
            } catch {
                NSLog("Spindle: could not decode \(url.path): \(error)")
                throw SpotifyError.invalidResponse
            }
        case 401 where !isRetry:
            return try await get(url, isRetry: true)
        case 401:
            throw SpotifyError.notConnected
        case 429:
            throw SpotifyError.rateLimited
        default:
            NSLog("Spindle: Spotify answered \(status) for \(url.path)")
            throw SpotifyError.http(status)
        }
    }
}
