import AppKit
import Foundation
import Testing
@testable import Spindle

/// Artists and Albums list what was played most recently first; Playlists
/// stay alphabetical.
@Suite("Recent ordering")
@MainActor
struct RecentOrderingTests {

    private static func day(_ n: Int) -> Date { Date(timeIntervalSince1970: Double(n) * 86_400) }

    private static let tracks = [
        LibraryTrack(index: 1, name: "A", artist: "Blur", album: "Parklife",
                     lastPlayed: day(3), dateAdded: day(1)),
        LibraryTrack(index: 2, name: "B", artist: "Oasis", album: "Morning Glory",
                     lastPlayed: day(9), dateAdded: day(1)),
        LibraryTrack(index: 3, name: "C", artist: "Blur", album: "13",
                     lastPlayed: nil, dateAdded: day(8)),
        LibraryTrack(index: 4, name: "D", artist: "Adele", album: "21",
                     lastPlayed: nil, dateAdded: day(2)),
        LibraryTrack(index: 5, name: "E", artist: "Coldplay", album: "Parachutes",
                     lastPlayed: nil, dateAdded: nil),
        LibraryTrack(index: 6, name: "F", artist: "Beck", album: "Odelay",
                     lastPlayed: nil, dateAdded: nil),
        LibraryTrack(index: 7, name: "G", artist: "", album: "")
    ]

    @Test("Played groups come first, most recent play on top")
    func playedFirst() {
        let artists = LibraryGrouping.recentFirst(Self.tracks, by: \.artist)

        #expect(Array(artists.prefix(2)) == ["Oasis", "Blur"])
    }

    @Test("Never-played groups follow, most recently added first, then A to Z")
    func unplayedAfter() {
        let albums = LibraryGrouping.recentFirst(Self.tracks, by: \.album)

        #expect(albums == ["Morning Glory", "Parklife", "13", "21", "Odelay", "Parachutes"])
    }

    @Test("A group counts its most recent track, not its first")
    func groupUsesLatestTrack() {
        // Blur's played track is day 3; its unplayed one being added on day 8
        // does not pull it above anything played.
        let artists = LibraryGrouping.recentFirst(Self.tracks, by: \.artist)

        #expect(artists == ["Oasis", "Blur", "Adele", "Beck", "Coldplay"])
    }

    @Test("The menu's Artists screen uses that order")
    func menuArtists() {
        let library = StubLibrary(tracks: Self.tracks)
        let model = MenuViewModel(library: library, artworkSettleDelay: .zero)

        open(model, ["Music", "Artists"])

        #expect(model.rows.map(\.title) == ["Oasis", "Blur", "Adele", "Beck", "Coldplay"])
    }

    @Test("Playlists stay alphabetical whatever order the library gives")
    func playlistsAlphabetical() {
        let library = StubLibrary(playlists: [
            LibraryPlaylist(index: 1, name: "Top 2000"),
            LibraryPlaylist(index: 2, name: "focus"),
            LibraryPlaylist(index: 3, name: "Chill")
        ])
        let model = MenuViewModel(library: library, artworkSettleDelay: .zero)

        open(model, ["Music", "Playlists"])

        #expect(model.rows.map(\.title) == ["Chill", "focus", "Top 2000"])
        #expect(model.rows.map(\.id) == ["playlist:3", "playlist:2", "playlist:1"])
    }

    @Test("Music's played and added dates are read, missing values as nil")
    func readsMusicDates() {
        let list = { (items: [NSAppleEventDescriptor]) -> NSAppleEventDescriptor in
            let descriptor = NSAppleEventDescriptor.list()
            for (offset, item) in items.enumerated() { descriptor.insert(item, at: offset + 1) }
            return descriptor
        }
        let text = { (value: String) in NSAppleEventDescriptor(string: value) }
        let missing = NSAppleEventDescriptor(typeCode: 0x6D73_6E67) // 'msng'
        let result = list([
            list([text("One"), text("Two")]),
            list([text("U2"), text("Blur")]),
            list([text("Achtung"), text("Parklife")]),
            list([NSAppleEventDescriptor(date: Self.day(5)), missing]),
            list([NSAppleEventDescriptor(date: Self.day(1)), NSAppleEventDescriptor(date: Self.day(2))])
        ])

        let tracks = MusicLibrary.tracks(from: result)

        #expect(tracks.map(\.lastPlayed) == [Self.day(5), nil])
        #expect(tracks.map(\.dateAdded) == [Self.day(1), Self.day(2)])
    }

    private func open(_ model: MenuViewModel, _ titles: [String]) {
        for title in titles {
            guard let row = model.rows.first(where: { $0.title == title }) else {
                Issue.record("no row titled \(title) in \(model.rows.map(\.title))")
                return
            }
            _ = model.activate(rowID: row.id)
        }
    }
}
