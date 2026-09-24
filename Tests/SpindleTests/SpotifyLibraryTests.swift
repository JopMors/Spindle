import Foundation
import Testing
@testable import Spindle

/// Answers from fixtures instead of the Web API.
final class FakeSpotifyCatalog: SpotifyCatalog, @unchecked Sendable {
    var playlistsResult: Result<[SpotifyPlaylist], SpotifyError> = .success(FakeSpotifyCatalog.playlists)
    var tracksByPlaylist: [String: [SpotifyTrack]] = ["p1": FakeSpotifyCatalog.tracks]
    var savedResult: Result<[SpotifyTrack], SpotifyError> = .success(FakeSpotifyCatalog.tracks)
    var userIDResult: Result<String, SpotifyError> = .success("jop")

    func playlists() async throws -> [SpotifyPlaylist] { try playlistsResult.get() }

    func playlistTracks(id: String) async throws -> [SpotifyTrack] {
        tracksByPlaylist[id] ?? []
    }

    func savedTracks() async throws -> [SpotifyTrack] { try savedResult.get() }

    func currentUserID() async throws -> String { try userIDResult.get() }

    static let playlists = [
        SpotifyPlaylist(id: "p1", uri: "spotify:playlist:p1", name: "Road Trip"),
        SpotifyPlaylist(id: "p2", uri: "spotify:playlist:p2", name: "Focus")
    ]

    static let tracks = [
        SpotifyTrack(uri: "spotify:track:t1", name: "Sultans of Swing", artist: "Dire Straits",
                     album: "Dire Straits", artworkURL: URL(string: "https://i.scdn.co/t1")),
        SpotifyTrack(uri: "spotify:track:t2", name: "Beyond the Sea", artist: "Robbie Williams",
                     album: "Swing", artworkURL: nil)
    ]
}

/// Records what would have been sent to Spotify.
final class RecordingSpotifyPlayer: SpotifyPlaying {
    struct Request: Equatable {
        var uri: String
        var context: String?
    }

    private(set) var requests: [Request] = []

    func play(uri: String, context: String?, completion: @escaping (MusicLibraryError?) -> Void) {
        requests.append(Request(uri: uri, context: context))
        completion(nil)
    }
}

@Suite("Spotify library")
@MainActor
struct SpotifyLibraryTests {

    private let catalog = FakeSpotifyCatalog()
    private let player = RecordingSpotifyPlayer()

    private func makeLibrary(image: Data? = nil) -> (SpotifyLibrary, () -> [URL]) {
        var requested: [URL] = []
        let library = SpotifyLibrary(catalog: catalog, player: player) { url, completion in
            requested.append(url)
            completion(image)
        }
        return (library, { requested })
    }

    private func playlists(_ library: SpotifyLibrary) async -> Result<[LibraryPlaylist], MusicLibraryError> {
        await withCheckedContinuation { continuation in
            library.playlists { continuation.resume(returning: $0) }
        }
    }

    private func tracks(_ library: SpotifyLibrary, playlist: Int?) async -> Result<[LibraryTrack], MusicLibraryError> {
        await withCheckedContinuation { continuation in
            library.tracks(playlistIndex: playlist) { continuation.resume(returning: $0) }
        }
    }

    private func awaitCompletion(_ start: (@escaping (MusicLibraryError?) -> Void) -> Void) async -> MusicLibraryError? {
        await withCheckedContinuation { continuation in
            start { continuation.resume(returning: $0) }
        }
    }

    @Test("Playlists are numbered from one, like Music's")
    func numbersPlaylists() async {
        let (library, _) = makeLibrary()

        let result = await playlists(library)

        #expect(result == .success([
            LibraryPlaylist(index: 1, name: "Road Trip"),
            LibraryPlaylist(index: 2, name: "Focus")
        ]))
    }

    @Test("Liked Songs stand in for the library")
    func likedSongsAreTheLibrary() async {
        let (library, _) = makeLibrary()

        let result = await tracks(library, playlist: nil)

        #expect(result == .success([
            LibraryTrack(index: 1, name: "Sultans of Swing", artist: "Dire Straits", album: "Dire Straits"),
            LibraryTrack(index: 2, name: "Beyond the Sea", artist: "Robbie Williams", album: "Swing")
        ]))
    }

    @Test("A playlist track plays by its URI, inside its playlist")
    func playsPlaylistTrack() async {
        let (library, _) = makeLibrary()
        _ = await playlists(library)
        _ = await tracks(library, playlist: 1)

        let error = await awaitCompletion { library.play(playlistIndex: 1, trackIndex: 2, completion: $0) }

        #expect(error == nil)
        #expect(player.requests == [.init(uri: "spotify:track:t2", context: "spotify:playlist:p1")])
    }

    @Test("A liked song plays by its URI")
    func playsLikedSong() async {
        let (library, _) = makeLibrary()
        _ = await tracks(library, playlist: nil)

        _ = await awaitCompletion { library.playFromLibrary(trackIndex: 1, completion: $0) }

        #expect(player.requests == [.init(uri: "spotify:track:t1", context: nil)])
    }

    @Test("Play Playlist hands Spotify the whole playlist")
    func playsWholePlaylist() async {
        let (library, _) = makeLibrary()
        _ = await playlists(library)

        _ = await awaitCompletion { library.playAll(playlistIndex: 2, completion: $0) }

        #expect(player.requests == [.init(uri: "spotify:playlist:p2", context: nil)])
    }

    @Test("Play All on Songs starts Liked Songs from the top, in their context")
    func playsAllLikedSongs() async {
        let (library, _) = makeLibrary()
        _ = await tracks(library, playlist: nil)

        _ = await awaitCompletion { library.playAll(playlistIndex: nil, completion: $0) }

        #expect(player.requests == [.init(uri: "spotify:track:t1", context: "spotify:user:jop:collection")])
    }

    @Test("A track the menu never listed is refused, not guessed at")
    func refusesUnknownTrack() async {
        let (library, _) = makeLibrary()

        let error = await awaitCompletion { library.play(playlistIndex: 1, trackIndex: 1, completion: $0) }

        #expect(error != nil)
        #expect(player.requests.isEmpty)
    }

    @Test("Without a sign-in the screen says where to connect")
    func notConnected() async {
        catalog.playlistsResult = .failure(.notConnected)
        let (library, _) = makeLibrary()

        let result = await playlists(library)

        #expect(result == .failure(.spotifyNotConnected))
    }

    @Test("Artwork comes from the cover URL Spotify listed")
    func artworkFromListedCover() async {
        let (library, requested) = makeLibrary(image: Data([1, 2, 3]))
        _ = await tracks(library, playlist: nil)

        let data = await withCheckedContinuation { continuation in
            library.artwork(playlistIndex: nil, trackIndex: 1) { continuation.resume(returning: $0) }
        }

        #expect(data == Data([1, 2, 3]))
        #expect(requested() == [URL(string: "https://i.scdn.co/t1")!])
    }

    @Test("A track with no cover asks for nothing")
    func noArtwork() async {
        let (library, requested) = makeLibrary(image: Data([1]))
        _ = await tracks(library, playlist: nil)

        let data = await withCheckedContinuation { continuation in
            library.artwork(playlistIndex: nil, trackIndex: 2) { continuation.resume(returning: $0) }
        }

        #expect(data == nil)
        #expect(requested().isEmpty)
    }
}
