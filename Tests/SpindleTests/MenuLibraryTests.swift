import Foundation
import Testing
@testable import Spindle

/// A library that answers from fixtures, synchronously, and records what it was
/// asked to play instead of playing it.
final class StubLibrary: MusicLibraryProviding {
    var playlistsResult: Result<[LibraryPlaylist], MusicLibraryError>
    var tracksResult: Result<[LibraryTrack], MusicLibraryError>

    private(set) var playedAll: [Int?] = []
    /// What a play request carried, recorded rather than performed.
    struct PlayRequest: Equatable {
        var playlist: Int?
        var track: Int
    }

    private(set) var playedPlaylistTracks: [PlayRequest] = []
    private(set) var playedLibraryTracks: [PlayRequest] = []

    init(
        playlists: [LibraryPlaylist] = StubLibrary.samplePlaylists,
        tracks: [LibraryTrack] = StubLibrary.sampleTracks
    ) {
        self.playlistsResult = .success(playlists)
        self.tracksResult = .success(tracks)
    }

    func playlists(completion: @escaping (Result<[LibraryPlaylist], MusicLibraryError>) -> Void) {
        completion(playlistsResult)
    }

    func tracks(
        playlistIndex: Int?,
        completion: @escaping (Result<[LibraryTrack], MusicLibraryError>) -> Void
    ) {
        completion(tracksResult)
    }

    func play(
        playlistIndex: Int, trackIndex: Int,
        completion: ((MusicLibraryError?) -> Void)?
    ) {
        playedPlaylistTracks.append(PlayRequest(playlist: playlistIndex, track: trackIndex))
        completion?(nil)
    }

    func playFromLibrary(
        trackIndex: Int, completion: ((MusicLibraryError?) -> Void)?
    ) {
        playedLibraryTracks.append(PlayRequest(playlist: nil, track: trackIndex))
        completion?(nil)
    }

    func playAll(playlistIndex: Int?, completion: ((MusicLibraryError?) -> Void)?) {
        playedAll.append(playlistIndex)
        completion?(nil)
    }

    /// Records which covers were asked for, so tests can show that browsing a
    /// list does not fire one query per row.
    private(set) var artworkRequests: [PlayRequest] = []
    var artworkResult: Data?

    func artwork(playlistIndex: Int?, trackIndex: Int, completion: @escaping (Data?) -> Void) {
        artworkRequests.append(PlayRequest(playlist: playlistIndex, track: trackIndex))
        completion(artworkResult)
    }

    static let samplePlaylists = [
        LibraryPlaylist(index: 1, name: "Top 2000"),
        LibraryPlaylist(index: 2, name: "Focus")
    ]

    static let sampleTracks = [
        LibraryTrack(index: 1, name: "Sultans of Swing", artist: "Dire Straits", album: "Dire Straits"),
        LibraryTrack(index: 2, name: "Romeo and Juliet", artist: "Dire Straits", album: "Making Movies"),
        LibraryTrack(index: 3, name: "Beyond the Sea", artist: "Robbie Williams", album: "Swing")
    ]
}

@Suite("Menu library levels")
@MainActor
struct MenuLibraryTests {

    /// Walks the menu down a path of row titles, selecting each in turn.
    private func descend(_ model: MenuViewModel, through titles: [String]) {
        for title in titles {
            guard let index = model.rows.firstIndex(where: { $0.title == title }) else {
                Issue.record("no row titled \(title) in \(model.rows.map(\.title))")
                return
            }
            model.moveSelection(by: index - model.selection)
            _ = model.activateSelection()
        }
    }

    @Test("A playlist lists Play Playlist above its tracks")
    func playlistOffersPlayAll() {
        let model = MenuViewModel(library: StubLibrary())

        descend(model, through: ["Music", "Playlists", "Top 2000"])

        #expect(model.rows.first?.title == "Play Playlist")
        #expect(model.rows.map(\.title) == [
            "Play Playlist", "Sultans of Swing", "Romeo and Juliet", "Beyond the Sea"
        ])
    }

    @Test("Choosing it plays the whole playlist, not a track")
    func playsWholePlaylist() {
        let library = StubLibrary()
        let model = MenuViewModel(library: library)
        descend(model, through: ["Music", "Playlists", "Focus"])

        // "Focus" is playlist 2 in the fixtures.
        #expect(model.activateSelection() == .playAll(playlistIndex: 2))
        #expect(library.playedAll.isEmpty, "the model reports, the owner plays")
    }

    @Test("Picking a track out of the playlist still works")
    func playsSingleTrack() {
        let model = MenuViewModel(library: StubLibrary())
        descend(model, through: ["Music", "Playlists", "Top 2000"])

        model.moveSelection(by: 2)

        #expect(model.activateSelection() == .playPlaylistTrack(playlistIndex: 1, trackIndex: 2))
    }

    @Test("Songs offers Play All, meaning the whole library")
    func songsOffersPlayAll() {
        let model = MenuViewModel(library: StubLibrary())

        descend(model, through: ["Music", "Songs"])

        #expect(model.rows.first?.title == "Play All")
        #expect(model.activateSelection() == .playAll(playlistIndex: nil))
    }

    @Test("Artists and albums have no Play All, having no container to play")
    func groupedLevelsHaveNoPlayAll() {
        let model = MenuViewModel(library: StubLibrary())

        descend(model, through: ["Music", "Artists", "Dire Straits"])

        #expect(model.rows.map(\.title) == ["Sultans of Swing", "Romeo and Juliet"])
        #expect(model.activateSelection() == .playLibraryTrack(index: 1))
    }

    @Test("Artists and albums are deduplicated and sorted")
    func groupsAreDeduplicated() {
        let model = MenuViewModel(library: StubLibrary())

        descend(model, through: ["Music", "Artists"])
        #expect(model.rows.map(\.title) == ["Dire Straits", "Robbie Williams"])

        _ = model.goBack()
        descend(model, through: ["Albums"])
        #expect(model.rows.map(\.title) == ["Dire Straits", "Making Movies", "Swing"])
    }

    @Test("An empty playlist offers nothing to play")
    func emptyPlaylistHasNoPlayAll() {
        let library = StubLibrary()
        library.tracksResult = .success([])
        let model = MenuViewModel(library: library)

        descend(model, through: ["Music", "Playlists", "Top 2000"])

        #expect(model.rows.isEmpty)
    }

    @Test("A refused Automation prompt shows on the screen instead of empty rows")
    func surfacesPermissionError() {
        let library = StubLibrary()
        library.playlistsResult = .failure(.notAuthorised)
        let model = MenuViewModel(library: library)

        descend(model, through: ["Music", "Playlists"])

        #expect(model.rows.isEmpty)
        #expect(model.errorMessage == MusicLibraryError.notAuthorised.screenMessage)
    }
}

@Suite("Play-all reaches the library")
@MainActor
struct PlayAllDispatchTests {

    @Test("Selecting Play Playlist asks the library to play that container")
    func dispatchesPlayAll() {
        let defaults = UserDefaults(suiteName: "nl.jopmors.Spindle.playAllTests") ?? .standard
        defer {
            defaults.removePersistentDomain(forName: "nl.jopmors.Spindle.playAllTests")
            UserDefaults.standard.removeSuite(named: "nl.jopmors.Spindle.playAllTests")
        }
        let settings = AppSettings(defaults: defaults)
        settings.isWheelClickEnabled = false
        let library = StubLibrary()
        let device = SpindleViewModel(settings: settings, library: library, modes: NoopModes())

        device.showMenu()
        // Music → Playlists → Top 2000 → Play Playlist
        for titles in [["Music"], ["Playlists"], ["Top 2000"], ["Play Playlist"]] {
            let index = device.menu.rows.firstIndex { $0.title == titles[0] } ?? 0
            device.menu.moveSelection(by: index - device.menu.selection)
            device.centerButtonPressed { _ in }
        }

        #expect(library.playedAll == [1])
        // Playing drops back to Now Playing, as the device did.
        #expect(device.mode == .nowPlaying)
    }

    @Test("Picking a song plays it out of the real playlist and queues the rest")
    func queuesRestByDefault() {
        withDevice { device, library, settings in
            #expect(settings.queuesRestOfList, "on by default: playback stops dead without it")
            playPath(device, ["Music", "Playlists", "Top 2000", "Romeo and Juliet"])

            // The real playlist, the real track. Nothing copied anywhere.
            #expect(library.playedPlaylistTracks == [.init(playlist: 1, track: 2)])
            #expect(device.queue.isActive, "the rest of the playlist is queued")
            #expect(device.queuePosition == QueuePosition(cursor: 1, count: 3))
        }
    }

    @Test("The queue advances through the same real playlist")
    func advancesInPlace() {
        withDevice { device, library, _ in
            playPath(device, ["Music", "Playlists", "Top 2000", "Romeo and Juliet"])
            device.queue.advance()

            #expect(library.playedPlaylistTracks == [
                .init(playlist: 1, track: 2), .init(playlist: 1, track: 3)
            ])
            #expect(device.queuePosition == QueuePosition(cursor: 2, count: 3))
        }
    }

    @Test("With repeat off the queue lets go at the end of the playlist")
    func stopsAtTheEnd() {
        withDevice { device, library, settings in
            settings.repeatMode = .off
            playPath(device, ["Music", "Playlists", "Top 2000", "Beyond the Sea"])
            device.queue.advance()

            #expect(library.playedPlaylistTracks == [.init(playlist: 1, track: 3)])
            #expect(device.queue.isActive == false)
            #expect(device.queuePosition == nil)
        }
    }

    @Test("Repeat All wraps round to the top of the playlist")
    func wrapsWithRepeatAll() {
        withDevice { device, library, settings in
            settings.repeatMode = .all
            playPath(device, ["Music", "Playlists", "Top 2000", "Beyond the Sea"])
            device.queue.advance()

            #expect(library.playedPlaylistTracks.last == .init(playlist: 1, track: 1))
            #expect(device.queuePosition == QueuePosition(cursor: 0, count: 3))
        }
    }

    @Test("Next and previous move the queue, not Music's single track")
    func skipsThroughTheQueue() {
        withDevice { device, library, _ in
            playPath(device, ["Music", "Playlists", "Top 2000", "Romeo and Juliet"])

            var sentToBackend: [TransportCommand] = []
            device.transport(.nextTrack) { sentToBackend.append($0) }
            #expect(library.playedPlaylistTracks.last == .init(playlist: 1, track: 3))

            device.transport(.previousTrack) { sentToBackend.append($0) }
            #expect(library.playedPlaylistTracks.last == .init(playlist: 1, track: 2))

            // Music was handed one track, so its own next-track would replay it.
            #expect(sentToBackend.isEmpty)
            device.transport(.togglePlayPause) { sentToBackend.append($0) }
            #expect(sentToBackend == [.togglePlayPause], "play/pause still goes to Music")
        }
    }

    @Test("Clicking a row does what scrolling to it and pressing centre does")
    func clickingARowSelectsAndActivates() {
        withDevice { device, library, _ in
            device.showMenu()
            #expect(device.menu.selection == 0)

            // Straight to a row three down, without touching the wheel.
            device.rowTapped(MenuRowID.settings)
            #expect(device.menu.selection == 3, "the highlight follows the click")

            device.rowTapped(MenuRowID.music)
            device.rowTapped(MenuRowID.playlists)
            device.rowTapped(MenuRowID.playlist(2))
            device.rowTapped(MenuRowID.playAll)

            // "Focus" is playlist 2 in the fixtures.
            #expect(library.playedAll == [2])
            #expect(device.mode == .nowPlaying)
        }
    }

    @Test("Clicking the Now Playing screen opens the menu")
    func clickingTheScreenOpensTheMenu() {
        withDevice { device, _, _ in
            #expect(device.mode == .nowPlaying)
            device.screenTapped()
            #expect(device.mode == .menu)

            // Only one way: from inside the menu, rows handle their own clicks.
            device.screenTapped()
            #expect(device.mode == .menu)
        }
    }

    @Test("Turning the setting off plays the song only, and queues nothing")
    func honoursTheSetting() {
        withDevice { device, library, settings in
            settings.queuesRestOfList = false
            playPath(device, ["Music", "Playlists", "Top 2000", "Romeo and Juliet"])

            #expect(library.playedPlaylistTracks == [.init(playlist: 1, track: 2)])
            #expect(device.queue.isActive == false)
        }
    }

    @Test("Play Playlist hands the whole container to Music and lets go")
    func playAllDoesNotQueue() {
        withDevice { device, library, _ in
            playPath(device, ["Music", "Playlists", "Top 2000", "Play Playlist"])

            #expect(library.playedAll == [1])
            #expect(library.playedPlaylistTracks.isEmpty)
            // Music owns the queue for a whole playlist, so the widget must not
            // also be handing tracks over.
            #expect(device.queue.isActive == false)
        }
    }

    private func playPath(_ device: SpindleViewModel, _ titles: [String]) {
        device.showMenu()
        for title in titles {
            let index = device.menu.rows.firstIndex { $0.title == title } ?? 0
            device.menu.moveSelection(by: index - device.menu.selection)
            device.centerButtonPressed { _ in }
        }
    }

    private func withDevice(_ body: (SpindleViewModel, StubLibrary, AppSettings) -> Void) {
        let name = "nl.jopmors.Spindle.queueTests"
        let defaults = UserDefaults(suiteName: name) ?? .standard
        defer {
            defaults.removePersistentDomain(forName: name)
            UserDefaults.standard.removeSuite(named: name)
            try? FileManager.default.removeItem(
                at: FileManager.default.homeDirectoryForCurrentUser
                    .appendingPathComponent("Library/Preferences/\(name).plist")
            )
        }
        let settings = AppSettings(defaults: defaults)
        settings.isWheelClickEnabled = false
        let library = StubLibrary()
        body(SpindleViewModel(settings: settings, library: library, modes: NoopModes()), library, settings)
    }

    private final class NoopModes: PlaybackModeSetting {
        func setShuffle(_ mode: ShuffleMode) {}
        func setRepeat(_ mode: RepeatMode) {}
    }
}

/// Swallows mode changes so snapshots never reach MediaRemote.
final class SilentModes: PlaybackModeSetting {
    func setShuffle(_ mode: ShuffleMode) {}
    func setRepeat(_ mode: RepeatMode) {}
}
