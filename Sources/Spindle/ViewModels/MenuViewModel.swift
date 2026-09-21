import AppKit
import Combine
import Foundation

/// Drives the menu on the original's screen: where we are, what is listed, and
/// which row is highlighted.
///
/// Knows nothing about playback — selecting a row returns a `MenuAction` for
/// the owner to carry out.
@MainActor
final class MenuViewModel: ObservableObject {

    @Published private(set) var stack: [MenuLevel] = [.main]
    @Published private(set) var rows: [MenuRow] = []
    @Published private(set) var selection = 0
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    /// Cover art for whatever track is highlighted, shown behind the list.
    @Published private(set) var previewArtwork: NSImage?

    /// Each preview is a round trip to Music, so it is optional and the caller
    /// owns the switch.
    var isArtworkPreviewEnabled = true {
        didSet {
            guard isArtworkPreviewEnabled != oldValue else { return }
            if isArtworkPreviewEnabled { schedulePreview() } else { clearPreview() }
        }
    }

    /// Values shown on the Shuffle and Repeat rows, supplied by the owner.
    var shuffleLabel = ShuffleMode.off.label
    var repeatLabel = RepeatMode.off.label

    var level: MenuLevel { stack.last ?? .main }
    var canGoBack: Bool { stack.count > 1 }

    /// Every track of the container this level came out of, in the container's
    /// own order — the whole playlist, or the whole library. The owner needs
    /// these to keep playing after a hand-picked song, so they are the unfiltered
    /// list even on an Artist or Album level.
    var containerTracks: [LibraryTrack] { loadedTracks }

    private let library: MusicLibraryProviding
    private let preview: MenuArtworkPreview
    /// Tracks of the level currently shown, for playback and for grouping.
    private var loadedTracks: [LibraryTrack] = []
    private var loadedPlaylists: [LibraryPlaylist] = []
    /// Remembers where the highlight was on each level we came from.
    private var selectionStack: [Int] = []

    /// `artworkSettleDelay` is injectable only so tests need not wait on the
    /// real one.
    init(
        library: MusicLibraryProviding,
        artworkSettleDelay: Duration = MenuArtworkPreview.defaultSettleDelay
    ) {
        self.library = library
        self.preview = MenuArtworkPreview(library: library, settleDelay: artworkSettleDelay)
        rebuildStaticRows()
    }

    // MARK: - Navigation

    func reset() {
        stack = [.main]
        selectionStack = []
        selection = 0
        errorMessage = nil
        rebuildStaticRows()
    }

    func moveSelection(by steps: Int) {
        guard !rows.isEmpty else { return }
        selection = min(max(selection + steps, 0), rows.count - 1)
        schedulePreview()
    }

    func goBack() -> Bool {
        guard canGoBack else { return false }
        stack.removeLast()
        selection = selectionStack.popLast() ?? 0
        errorMessage = nil
        reload()
        return true
    }

    /// Returns what the highlighted row wants done, and navigates if that is
    /// all it needs.
    func activateSelection() -> MenuAction? {
        guard selection < rows.count else { return nil }
        let action = self.action(for: rows[selection])
        if case .push(let level) = action {
            push(level)
            return nil
        }
        return action
    }

    /// Moves the highlight onto a row and activates it, so clicking a line on
    /// the screen behaves exactly like scrolling down to it and pressing the
    /// centre button.
    func activate(rowID: String) -> MenuAction? {
        guard let index = rows.firstIndex(where: { $0.id == rowID }) else { return nil }
        selection = index
        schedulePreview()
        return activateSelection()
    }

    private func push(_ level: MenuLevel) {
        selectionStack.append(selection)
        stack.append(level)
        selection = 0
        errorMessage = nil
        reload()
    }

    // MARK: - Row construction

    /// Reloads the current level, hitting Music.app only when it has to.
    func reload() {
        guard level.needsLibrary else {
            rebuildStaticRows()
            return
        }
        switch level {
        case .playlists:
            loadPlaylists()
        case .playlist(let index, _):
            loadTracks(playlistIndex: index)
        case .artists, .albums, .songs:
            loadTracks(playlistIndex: nil)
        case .artist, .album:
            // Grouped from tracks already in hand.
            rebuildGroupedRows()
        default:
            rebuildStaticRows()
        }
    }

    func refreshModeLabels() {
        guard case .main = level else { return }
        rebuildStaticRows()
    }

    private func rebuildStaticRows() {
        switch level {
        case .main:
            rows = MenuRowCatalog.main(shuffleLabel: shuffleLabel, repeatLabel: repeatLabel)
        case .music:
            rows = MenuRowCatalog.music
        default:
            rows = []
        }
        clampSelection()
    }

    private func rebuildGroupedRows() {
        switch level {
        case .artists:
            rows = groupRows(by: \.artist)
        case .albums:
            rows = groupRows(by: \.album)
        case .songs:
            rows = withPlayAll("Play All", trackRows(loadedTracks))
        case .artist(let name):
            rows = trackRows(loadedTracks.filter { $0.artist == name })
        case .album(let name):
            rows = trackRows(loadedTracks.filter { $0.album == name })
        case .playlist:
            rows = withPlayAll("Play Playlist", trackRows(loadedTracks))
        default:
            break
        }
        clampSelection()
    }

    private func groupRows(by field: KeyPath<LibraryTrack, String>) -> [MenuRow] {
        let names = Set(loadedTracks.map { $0[keyPath: field] })
            .filter { !$0.isEmpty }
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
        return names.map { MenuRow(id: MenuRowID.group($0), title: $0) }
    }

    private func trackRows(_ tracks: [LibraryTrack]) -> [MenuRow] {
        tracks.map {
            MenuRow(id: MenuRowID.track($0.index), title: $0.name, accessory: .none)
        }
    }

    /// Puts "Play Playlist" above the track list, so the whole thing can be
    /// started without picking a track out of it. Only where there is a real
    /// container to play — an artist or album is a grouping we made on this
    /// side, and Music has nothing to queue from it.
    private func withPlayAll(_ title: String, _ tracks: [MenuRow]) -> [MenuRow] {
        guard !tracks.isEmpty else { return tracks }
        return [MenuRow(id: MenuRowID.playAll, title: title, accessory: .none)] + tracks
    }

    private func clampSelection() {
        selection = min(max(selection, 0), max(rows.count - 1, 0))
        schedulePreview()
    }

    // MARK: - Artwork preview

    /// Asks for the highlighted track's cover, once the highlight settles.
    private func schedulePreview() {
        guard isArtworkPreviewEnabled, let trackIndex = selectedTrackIndex else {
            clearPreview()
            return
        }
        preview.request(
            playlistIndex: containerPlaylistIndex,
            trackIndex: trackIndex
        ) { [weak self] image in
            self?.previewArtwork = image
        }
    }

    private func clearPreview() {
        preview.cancel()
        previewArtwork = nil
    }

    /// Only track rows have a cover; Playlists, Shuffle and the rest do not.
    private var selectedTrackIndex: Int? {
        guard selection < rows.count else { return nil }
        return identifier(rows[selection].id, prefix: "track:")
    }

    /// Which container the highlighted track is addressed in. Artist and album
    /// levels are groupings of the library, so they resolve to the library.
    private var containerPlaylistIndex: Int? {
        if case .playlist(let index, _) = level { return index }
        return nil
    }

    // MARK: - Loading

    private func loadPlaylists() {
        isLoading = true
        library.playlists { [weak self] result in
            guard let self else { return }
            self.isLoading = false
            switch result {
            case .success(let playlists):
                self.loadedPlaylists = playlists
                self.rows = playlists.map {
                    MenuRow(id: MenuRowID.playlist($0.index), title: $0.name)
                }
                self.clampSelection()
            case .failure(let error):
                self.fail(with: error)
            }
        }
    }

    private func loadTracks(playlistIndex: Int?) {
        isLoading = true
        library.tracks(playlistIndex: playlistIndex) { [weak self] result in
            guard let self else { return }
            self.isLoading = false
            switch result {
            case .success(let tracks):
                self.loadedTracks = tracks
                self.rebuildGroupedRows()
            case .failure(let error):
                self.fail(with: error)
            }
        }
    }

    private func fail(with error: MusicLibraryError) {
        errorMessage = error.screenMessage
        rows = []
    }

    // MARK: - Row → action

    /// Rows whose meaning never depends on where we are.
    private static let fixedActions: [String: MenuAction] = [
        MenuRowID.music: .push(.music),
        MenuRowID.shuffle: .cycleShuffle,
        MenuRowID.repeatMode: .cycleRepeat,
        MenuRowID.settings: .openSettings,
        MenuRowID.nowPlaying: .showNowPlaying,
        MenuRowID.playlists: .push(.playlists),
        MenuRowID.artists: .push(.artists),
        MenuRowID.albums: .push(.albums),
        MenuRowID.songs: .push(.songs)
    ]

    private func action(for row: MenuRow) -> MenuAction? {
        if let fixed = Self.fixedActions[row.id] { return fixed }
        if row.id == MenuRowID.playAll { return playAllAction }
        return dynamicAction(for: row)
    }

    private var playAllAction: MenuAction? {
        switch level {
        case .playlist(let index, _): return .playAll(playlistIndex: index)
        case .songs: return .playAll(playlistIndex: nil)
        default: return nil
        }
    }

    private func dynamicAction(for row: MenuRow) -> MenuAction? {
        if let index = identifier(row.id, prefix: "playlist:") {
            let name = loadedPlaylists.first { $0.index == index }?.name ?? "Playlist"
            return .push(.playlist(index: index, name: name))
        }
        if let index = identifier(row.id, prefix: "track:") {
            if case .playlist(let playlistIndex, _) = level {
                return .playPlaylistTrack(playlistIndex: playlistIndex, trackIndex: index)
            }
            return .playLibraryTrack(index: index)
        }
        if row.id.hasPrefix("group:") {
            let name = String(row.id.dropFirst("group:".count))
            if case .artists = level { return .push(.artist(name)) }
            if case .albums = level { return .push(.album(name)) }
        }
        return nil
    }

    private func identifier(_ id: String, prefix: String) -> Int? {
        guard id.hasPrefix(prefix) else { return nil }
        return Int(id.dropFirst(prefix.count))
    }
}
