import Foundation

/// Spotify behind the same interface as Music, so the menu, the queue and the
/// artwork preview work on it unchanged.
///
/// The menu addresses everything by one-based position, as Music does. Spotify
/// addresses by URI, so this remembers the last lists it handed out and maps
/// positions back to URIs when asked to play. Liked Songs stand in for the
/// library that Artists, Albums and Songs are grouped from.
///
/// Every completion runs on the main queue, and the caches are only touched
/// there.
final class SpotifyLibrary: MusicLibraryProviding {

    typealias ImageLoader = (URL, @escaping (Data?) -> Void) -> Void

    private let catalog: SpotifyCatalog
    private let player: SpotifyPlaying
    private let loadImage: ImageLoader

    private var playlistCache: [SpotifyPlaylist] = []
    /// Keyed by playlist position; nil is Liked Songs.
    private var trackCache: [Int?: [SpotifyTrack]] = [:]

    init(
        catalog: SpotifyCatalog,
        player: SpotifyPlaying = SpotifyAppleScriptPlayer(),
        loadImage: @escaping ImageLoader = SpotifyLibrary.fetchImage
    ) {
        self.catalog = catalog
        self.player = player
        self.loadImage = loadImage
    }

    // MARK: - Reads

    func playlists(completion: @escaping (Result<[LibraryPlaylist], MusicLibraryError>) -> Void) {
        fetch({ try await self.catalog.playlists() }) { [weak self] result in
            completion(result.map { playlists in
                self?.playlistCache = playlists
                return playlists.enumerated().map { LibraryPlaylist(index: $0.offset + 1, name: $0.element.name) }
            })
        }
    }

    func tracks(
        playlistIndex: Int?,
        completion: @escaping (Result<[LibraryTrack], MusicLibraryError>) -> Void
    ) {
        let playlistID: String?
        if let playlistIndex {
            guard let playlist = playlist(at: playlistIndex) else {
                completion(.failure(.failed("That playlist is gone")))
                return
            }
            playlistID = playlist.id
        } else {
            playlistID = nil
        }

        fetch({ [catalog] in
            if let playlistID { return try await catalog.playlistTracks(id: playlistID) }
            return try await catalog.savedTracks()
        }) { [weak self] result in
            completion(result.map { tracks in
                self?.trackCache[playlistIndex] = tracks
                return tracks.enumerated().map { offset, track in
                    LibraryTrack(index: offset + 1, name: track.name, artist: track.artist, album: track.album)
                }
            })
        }
    }

    func artwork(playlistIndex: Int?, trackIndex: Int, completion: @escaping (Data?) -> Void) {
        guard let url = track(trackIndex, in: playlistIndex)?.artworkURL else {
            completion(nil)
            return
        }
        loadImage(url) { data in
            DispatchQueue.main.async { completion(data) }
        }
    }

    // MARK: - Playback

    /// Plays inside the playlist, so Spotify's own Up Next is the playlist too
    /// if the widget ever stops handing it tracks.
    func play(playlistIndex: Int, trackIndex: Int, completion: ((MusicLibraryError?) -> Void)?) {
        guard let track = track(trackIndex, in: playlistIndex) else {
            completion?(.failed("Open the playlist again"))
            return
        }
        player.play(uri: track.uri, context: playlist(at: playlistIndex)?.uri) { completion?($0) }
    }

    func playFromLibrary(trackIndex: Int, completion: ((MusicLibraryError?) -> Void)?) {
        guard let track = track(trackIndex, in: nil) else {
            completion?(.failed("Open Songs again"))
            return
        }
        player.play(uri: track.uri, context: nil) { completion?($0) }
    }

    /// A playlist goes to Spotify whole. Liked Songs have no playlist URI, so
    /// they start from the top inside the account's collection instead.
    func playAll(playlistIndex: Int?, completion: ((MusicLibraryError?) -> Void)?) {
        if let playlistIndex {
            guard let playlist = playlist(at: playlistIndex) else {
                completion?(.failed("That playlist is gone"))
                return
            }
            player.play(uri: playlist.uri, context: nil) { completion?($0) }
            return
        }
        guard let first = track(1, in: nil) else {
            completion?(.failed("No liked songs"))
            return
        }
        fetch({ try await self.catalog.currentUserID() }) { [player] result in
            let context = (try? result.get()).map { "spotify:user:\($0):collection" }
            player.play(uri: first.uri, context: context) { completion?($0) }
        }
    }

    // MARK: - Lookup

    private func playlist(at index: Int) -> SpotifyPlaylist? {
        playlistCache.indices.contains(index - 1) ? playlistCache[index - 1] : nil
    }

    private func track(_ index: Int, in playlistIndex: Int?) -> SpotifyTrack? {
        guard let tracks = trackCache[playlistIndex], tracks.indices.contains(index - 1) else { return nil }
        return tracks[index - 1]
    }

    // MARK: - Plumbing

    /// Runs `work` off the main thread and delivers its result back on it,
    /// translated into the errors the menu already knows how to show.
    private func fetch<T>(
        _ work: @escaping () async throws -> T,
        completion: @escaping (Result<T, MusicLibraryError>) -> Void
    ) {
        Task.detached {
            let result: Result<T, MusicLibraryError>
            do {
                result = .success(try await work())
            } catch SpotifyError.notConnected {
                result = .failure(.spotifyNotConnected)
            } catch let error as SpotifyError {
                result = .failure(.failed(error.message))
            } catch {
                NSLog("Spindle: Spotify request failed: \(error)")
                result = .failure(.failed("Could not reach Spotify"))
            }
            DispatchQueue.main.async { completion(result) }
        }
    }

    static func fetchImage(_ url: URL, completion: @escaping (Data?) -> Void) {
        URLSession.shared.dataTask(with: url) { data, response, error in
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            if let error { NSLog("Spindle: Spotify cover failed: \(error.localizedDescription)") }
            completion((200..<300).contains(status) ? data : nil)
        }.resume()
    }
}
