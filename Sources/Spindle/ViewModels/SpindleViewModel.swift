import Combine
import Foundation

/// What the screen is showing.
enum ScreenMode: Equatable {
    case nowPlaying
    case menu
}

/// The device itself: which screen is up, what the wheel does right now, and
/// the shuffle and repeat settings.
///
/// The wheel's meaning depends on the screen, exactly as it did on the original —
/// volume on Now Playing, selection in a menu — and that routing lives here so
/// neither the view nor the gesture recogniser has to know about it.
@MainActor
final class SpindleViewModel: ObservableObject {

    @Published private(set) var mode: ScreenMode = .nowPlaying
    @Published private(set) var shuffle: ShuffleMode
    @Published private(set) var repeatMode: RepeatMode

    /// Set briefly after a volume change so the screen can show the level.
    @Published private(set) var volumeOverlay: Double?

    /// System output volume, for the permanent slider. Re-read on every
    /// playback update, since anything on the machine can change it.
    @Published private(set) var volume: Double = Double(VolumeController.currentVolume() ?? 0.5)

    /// Where we are in the widget's own queue, when it owns one. Preferred over
    /// MediaRemote's count, which only ever sees the single track we hand over.
    @Published private(set) var queuePosition: QueuePosition?

    let menu: MenuViewModel

    /// Called when a menu row asks for the settings window.
    var onOpenSettings: (() -> Void)?

    private let settings: AppSettings
    private let modes: PlaybackModeSetting
    private let library: MusicLibraryProviding
    let queue: QueueController
    private let clicker = WheelClicker()
    private var volumeOverlayTask: Task<Void, Never>?
    private var cancellables: Set<AnyCancellable> = []

    /// Wheel travel needed for one step, in scroll units. Trackpads report
    /// small continuous deltas, so this is accumulated rather than counted.
    private static let detentThreshold: Double = 4
    /// Volume moved per detent — about thirty detents end to end.
    private static let volumeStep: Float = 0.033
    private static let overlayDuration: Duration = .seconds(1.2)

    private var accumulatedScroll: Double = 0

    /// Who is playing, for the Media position of the source toggle.
    private var nowPlayingBundleID: String?

    init(
        settings: AppSettings,
        library: MusicLibraryProviding = MusicLibrary(),
        modes: PlaybackModeSetting = PlaybackModeController()
    ) {
        self.settings = settings
        self.library = library
        self.modes = modes
        self.shuffle = settings.shuffleMode
        self.repeatMode = settings.repeatMode
        self.menu = MenuViewModel(library: library)
        self.queue = QueueController(library: library, settings: settings)
        menu.shuffleLabel = shuffle.label
        menu.repeatLabel = repeatMode.label
        queue.$position.assign(to: &$queuePosition)
        menu.isArtworkPreviewEnabled = settings.showsMenuArtwork
        // Settings has no per-property publisher, and the menu needs to follow
        // the toggle while it is open.
        settings.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                guard let self else { return }
                self.menu.isArtworkPreviewEnabled = self.settings.showsMenuArtwork
            }
            .store(in: &cancellables)
        // Fires with the new value, so the menu can switch straight away.
        settings.$wheelSourceTarget
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self] target in
                guard let self, self.mode == .menu else { return }
                self.selectLibrary(for: target)
            }
            .store(in: &cancellables)
    }

    /// Follows playback so the queue knows when a track is about to end.
    func observeNowPlaying(_ publisher: Published<NowPlaying>.Publisher) {
        publisher
            .sink { [weak self] state in
                guard let self else { return }
                self.queue.update(state)
                self.nowPlayingBundleID = state.sourceBundleID
                // Anything on the machine can move the system volume; this is
                // the only regular tick the widget has to notice.
                if let level = VolumeController.currentVolume() {
                    self.volume = Double(level)
                }
            }
            .store(in: &cancellables)
    }

    /// Corrects the remembered shuffle and repeat setting against Music, when
    /// Automation happens to be permitted already. Never prompts.
    func seedModesFromSystem() {
        guard let actual = PlaybackModeReader.currentModes() else { return }
        shuffle = actual.shuffle
        repeatMode = actual.repeatMode
        settings.shuffleMode = actual.shuffle
        settings.repeatMode = actual.repeatMode
        menu.shuffleLabel = actual.shuffle.label
        menu.repeatLabel = actual.repeatMode.label
        Diagnostics.log("seeded modes from Music: shuffle=\(actual.shuffle) repeat=\(actual.repeatMode)")
    }

    // MARK: - Screen

    func showMenu() {
        guard mode != .menu else { return }
        selectLibrary(for: settings.wheelSourceTarget)
        menu.reset()
        menu.shuffleLabel = shuffle.label
        menu.repeatLabel = repeatMode.label
        menu.refreshModeLabels()
        mode = .menu
    }

    func showNowPlaying() {
        mode = .nowPlaying
    }

    /// Points the menu at the library the toggle asks for. Resolved when the
    /// menu opens, not continuously, so Media cannot swap libraries under the
    /// highlight because a browser tab started playing.
    private func selectLibrary(for target: WheelSourceTarget) {
        guard var switching = library as? LibrarySwitching else { return }
        let wanted = LibrarySource.resolve(target: target, nowPlayingBundleID: nowPlayingBundleID)
        guard wanted != switching.source else { return }
        switching.source = wanted
        menu.libraryChanged()
        Diagnostics.log("menu library: \(wanted.rawValue)")
    }

    /// The MENU button: up one level, and off the menu entirely from the top.
    func menuButtonPressed() {
        click()
        Diagnostics.log("MENU pressed, mode=\(mode) level=\(menu.level.title)")
        guard mode == .menu else {
            showMenu()
            return
        }
        if !menu.goBack() {
            showNowPlaying()
        }
    }

    /// Next and previous have to come through the queue while the widget owns
    /// one: Music was handed a single track, so its own next-track would only
    /// replay it. Everything else goes straight to the media backend.
    func transport(_ command: TransportCommand, otherwise send: (TransportCommand) -> Void) {
        guard queue.isActive else {
            send(command)
            return
        }
        switch command {
        case .nextTrack: queue.skipForward()
        case .previousTrack: queue.skipBackward()
        case .togglePlayPause: send(command)
        }
    }

    /// The centre button: play/pause on Now Playing, select in a menu.
    func centerButtonPressed(transport: (TransportCommand) -> Void) {
        click()
        guard mode == .menu else {
            transport(.togglePlayPause)
            return
        }
        guard let action = menu.activateSelection() else { return }
        perform(action)
    }

    // MARK: - The screen as a control

    /// A click straight on a menu row.
    ///
    /// The wheel is faithful but opaque — people could not work out how to get
    /// anywhere from the top button. Clicking what you can see costs nothing
    /// and does not take the wheel away from anyone who prefers it.
    func rowTapped(_ id: String) {
        click()
        guard let action = menu.activate(rowID: id) else { return }
        perform(action)
    }

    /// Clicking the Now Playing screen opens the menu, the same as MENU does.
    func screenTapped() {
        guard mode == .nowPlaying else { return }
        menuButtonPressed()
    }

    // MARK: - Wheel

    /// Accumulated scroll from the trackpad or a circular drag. Positive is
    /// clockwise, which means louder or further down a list.
    func wheelScrolled(by amount: Double) {
        guard settings.isWheelScrollEnabled else { return }
        accumulatedScroll += amount
        while abs(accumulatedScroll) >= Self.detentThreshold {
            let direction = accumulatedScroll > 0 ? 1 : -1
            accumulatedScroll -= Double(direction) * Self.detentThreshold
            stepWheel(direction)
        }
    }

    func resetWheelTravel() {
        accumulatedScroll = 0
    }

    private func stepWheel(_ direction: Int) {
        click()
        Diagnostics.log("wheel step \(direction > 0 ? "+1" : "-1") mode=\(mode)")
        switch mode {
        case .menu:
            menu.moveSelection(by: direction)
        case .nowPlaying:
            adjustVolume(direction)
        }
    }

    private func adjustVolume(_ direction: Int) {
        let delta = Self.volumeStep * Float(direction)
        guard let level = VolumeController.adjustVolume(by: delta) else { return }
        apply(volume: Double(level))
    }

    /// Dragging the volume bar, rather than turning the wheel.
    func setVolume(_ level: Double) {
        let clamped = min(max(level, 0), 1)
        guard VolumeController.setVolume(Float(clamped)) else { return }
        apply(volume: clamped)
    }

    private func apply(volume level: Double) {
        volume = level
        volumeOverlay = level
        volumeOverlayTask?.cancel()
        volumeOverlayTask = Task { [weak self] in
            try? await Task.sleep(for: Self.overlayDuration)
            guard !Task.isCancelled else { return }
            self?.volumeOverlay = nil
        }
    }

    private func click() {
        guard settings.isWheelClickEnabled else { return }
        clicker.volume = Float(settings.wheelClickVolume)
        clicker.click()
    }

    // MARK: - Playback modes

    func cycleShuffle() {
        apply(shuffle: shuffle.toggled)
    }

    func cycleRepeat() {
        apply(repeatMode: repeatMode.cycled)
    }

    func apply(shuffle newValue: ShuffleMode) {
        shuffle = newValue
        settings.shuffleMode = newValue
        modes.setShuffle(newValue)
        menu.shuffleLabel = newValue.label
        menu.refreshModeLabels()
    }

    func apply(repeatMode newValue: RepeatMode) {
        repeatMode = newValue
        settings.repeatMode = newValue
        modes.setRepeat(newValue)
        menu.repeatLabel = newValue.label
        menu.refreshModeLabels()
    }

    // MARK: - Menu actions

    private func perform(_ action: MenuAction) {
        switch action {
        case .cycleShuffle:
            cycleShuffle()
        case .cycleRepeat:
            cycleRepeat()
        case .openSettings:
            onOpenSettings?()
        case .showNowPlaying:
            showNowPlaying()
        case .playLibraryTrack(let index):
            startTrack(index, in: .library)
        case .playPlaylistTrack(let playlistIndex, let trackIndex):
            startTrack(trackIndex, in: .playlist(index: playlistIndex))
        case .playAll(let playlistIndex):
            // The container goes to Music whole, so Music owns the queue here
            // and the widget has nothing to follow.
            queue.relinquish()
            library.playAll(playlistIndex: playlistIndex) { [weak self] _ in
                self?.showNowPlaying()
            }
        case .push, .pop:
            break
        }
    }

    private func startTrack(_ index: Int, in container: QueueContainer) {
        let finish: (MusicLibraryError?) -> Void = { [weak self] _ in self?.showNowPlaying() }
        guard settings.queuesRestOfList else {
            queue.playOnce(trackIndex: index, in: container, completion: finish)
            return
        }
        queue.play(
            trackIndex: index,
            from: container,
            tracks: menu.containerTracks,
            completion: finish
        )
    }

    func stop() {
        volumeOverlayTask?.cancel()
        queue.stop()
        clicker.stop()
    }
}
