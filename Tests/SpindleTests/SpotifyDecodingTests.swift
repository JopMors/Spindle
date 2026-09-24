import Foundation
import Testing
@testable import Spindle

/// Spotify's JSON, as documented after the February 2026 changes.
@Suite("Spotify decoding")
struct SpotifyDecodingTests {

    private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        try SpotifyWebAPI.decoder.decode(T.self, from: Data(json.utf8))
    }

    @Test("Playlist items are read from `item`, falling back to `track`")
    func playlistItems() throws {
        let page = try decode(SpotifyPage<SpotifyPlaylistItem>.self, """
        {"next": null, "items": [
          {"item": {"type": "track", "uri": "spotify:track:1", "name": "One",
                    "is_local": false, "artists": [{"name": "U2"}, {"name": "Mary J"}],
                    "album": {"name": "Achtung", "images": [
                        {"url": "https://i.scdn.co/big", "width": 640},
                        {"url": "https://i.scdn.co/mid", "width": 300},
                        {"url": "https://i.scdn.co/small", "width": 64}]}}},
          {"track": {"type": "track", "uri": "spotify:track:2", "name": "Two",
                     "artists": [{"name": "Blur"}], "album": {"name": "Blur", "images": []}}}
        ]}
        """)

        let tracks = page.items.compactMap(\.content).compactMap(\.libraryTrack)

        #expect(tracks == [
            SpotifyTrack(
                uri: "spotify:track:1", name: "One", artist: "U2", album: "Achtung",
                artworkURL: URL(string: "https://i.scdn.co/mid")
            ),
            SpotifyTrack(uri: "spotify:track:2", name: "Two", artist: "Blur", album: "Blur", artworkURL: nil)
        ])
    }

    @Test("Episodes, local files and removed tracks are left out rather than failing the page")
    func skipsWhatCannotPlay() throws {
        let page = try decode(SpotifyPage<SpotifyPlaylistItem>.self, """
        {"next": "https://api.spotify.com/v1/playlists/x/items?offset=50", "items": [
          {"item": {"type": "episode", "uri": "spotify:episode:9", "name": "Pod"}},
          {"item": {"type": "track", "uri": "spotify:local:a:b:c:1", "name": "Mine",
                    "is_local": true, "artists": [], "album": {"name": "", "images": []}}},
          {"item": null},
          {"item": {"type": "track", "uri": "spotify:track:3", "name": "Three",
                    "artists": [{"name": "Muse"}], "album": {"name": "Absolution", "images": []}}}
        ]}
        """)

        let tracks = page.items.compactMap(\.content).compactMap(\.libraryTrack)

        #expect(tracks.map(\.uri) == ["spotify:track:3"])
        #expect(page.next?.absoluteString == "https://api.spotify.com/v1/playlists/x/items?offset=50")
    }

    @Test("Liked songs come wrapped in `track`")
    func savedTracks() throws {
        let page = try decode(SpotifyPage<SpotifySavedTrack>.self, """
        {"next": null, "items": [
          {"added_at": "2026-01-01T00:00:00Z",
           "track": {"type": "track", "uri": "spotify:track:4", "name": "Four",
                     "artists": [{"name": "Oasis"}], "album": {"name": "Morning Glory", "images": []}}}
        ]}
        """)

        #expect(page.items.compactMap(\.track).compactMap(\.libraryTrack).map(\.name) == ["Four"])
    }

    @Test("Only playlists whose tracks Spotify will hand over are listed")
    func readablePlaylists() throws {
        let page = try decode(SpotifyPage<SpotifyPlaylistObject>.self, """
        {"next": null, "items": [
          {"id": "a1", "name": "Mine", "uri": "spotify:playlist:a1", "collaborative": false,
           "owner": {"id": "jop"}},
          {"id": "b2", "name": "Followed", "uri": "spotify:playlist:b2", "collaborative": false,
           "owner": {"id": "spotify"}},
          {"id": "c3", "name": "Shared", "uri": "spotify:playlist:c3", "collaborative": true,
           "owner": {"id": "friend"}}
        ]}
        """)

        let readable = SpotifyWebAPI.readable(page.items, userID: "jop")

        #expect(readable == [
            SpotifyPlaylist(id: "a1", uri: "spotify:playlist:a1", name: "Mine"),
            SpotifyPlaylist(id: "c3", uri: "spotify:playlist:c3", name: "Shared")
        ])
    }

    @Test("A next link off Spotify's API host is not followed")
    func refusesForeignNextLink() {
        #expect(SpotifyWebAPI.isTrustedPageURL(URL(string: "https://api.spotify.com/v1/me/tracks?offset=50")!))
        #expect(!SpotifyWebAPI.isTrustedPageURL(URL(string: "https://evil.example/v1/me/tracks")!))
        #expect(!SpotifyWebAPI.isTrustedPageURL(URL(string: "http://api.spotify.com/v1/me/tracks")!))
    }
}
