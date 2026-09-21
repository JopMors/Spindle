import SwiftUI

/// User-facing customisation, persisted to `UserDefaults`.
///
/// Every property writes through on change, so whatever you set in the settings
/// panel is what you get on the next launch — there is no separate "apply".
@MainActor
final class AppSettings: ObservableObject {

    enum Appearance: String, CaseIterable, Identifiable {
        case matchSystem
        case light
        case dark

        var id: String { rawValue }

        var label: String {
            switch self {
            case .matchSystem: return "Match System"
            case .light: return "Light"
            case .dark: return "Dark"
            }
        }
    }

    /// Where the widget sits in the window stack.
    enum Placement: String, CaseIterable, Identifiable {
        case desktop
        case floating
        case normal

        var id: String { rawValue }

        var label: String {
            switch self {
            case .desktop: return "On Desktop"
            case .floating: return "Always on Top"
            case .normal: return "Normal"
            }
        }

        var detail: String {
            switch self {
            case .desktop: return "Sits on the wallpaper, behind your windows."
            case .floating: return "Stays above every other window."
            case .normal: return "Behaves like a regular window."
            }
        }
    }

    static let minCornerRadius: Double = 0
    static let maxCornerRadius: Double = 40
    static let defaultWidth: Double = 164
    static let defaultCornerRadius: Double = 26
    /// Floor for overall opacity, so the widget can never be made invisible
    /// and impossible to find again.
    static let minOpacity: Double = 0.2

    @Published var selectedThemeID: String {
        didSet { defaults.set(selectedThemeID, forKey: Key.themeID) }
    }

    @Published var customSkin: CustomSkin {
        didSet { persistCustomSkin() }
    }

    /// Body width in points. Matches the macOS widget grid.
    @Published var width: Double {
        didSet { defaults.set(width, forKey: Key.width) }
    }

    @Published var cornerRadius: Double {
        didSet { defaults.set(cornerRadius, forKey: Key.cornerRadius) }
    }

    /// Transparency of the entire widget, artwork included. Applied to the
    /// window itself rather than the views, so nothing is left fully opaque.
    @Published var overallOpacity: Double {
        didSet { defaults.set(overallOpacity, forKey: Key.overallOpacity) }
    }

    /// Renders the album cover in black and white. Applies to every skin, so
    /// it lives here rather than on the custom skin.
    @Published var isArtworkMonochrome: Bool {
        didSet { defaults.set(isArtworkMonochrome, forKey: Key.artworkMonochrome) }
    }

    @Published var placement: Placement {
        didSet { defaults.set(placement.rawValue, forKey: Key.placement) }
    }

    /// Off by default: dragging a thing on your desktop is the first thing
    /// anyone tries, and having that silently do nothing reads as broken. Turn
    /// it on once the widget is where you want it. ⌘-drag works either way.
    @Published var isPositionLocked: Bool {
        didSet { defaults.set(isPositionLocked, forKey: Key.positionLocked) }
    }

    @Published var appearance: Appearance {
        didSet { defaults.set(appearance.rawValue, forKey: Key.appearance) }
    }

    /// Status bar, scrubber and elapsed/remaining times over the artwork.
    @Published var showsPlaybackDetail: Bool {
        didSet { defaults.set(showsPlaybackDetail, forKey: Key.playbackDetail) }
    }

    /// Scrolling over the wheel changes volume, as it did on the device.
    @Published var isWheelScrollEnabled: Bool {
        didSet { defaults.set(isWheelScrollEnabled, forKey: Key.wheelScroll) }
    }

    /// The tick a mechanical detent makes.
    @Published var isWheelClickEnabled: Bool {
        didSet { defaults.set(isWheelClickEnabled, forKey: Key.wheelClick) }
    }

    /// How loud that tick is, 0…1.
    @Published var wheelClickVolume: Double {
        didSet { defaults.set(wheelClickVolume, forKey: Key.wheelClickVolume) }
    }

    /// Shows the highlighted track's cover behind the menu. Each one is a
    /// round trip to Music, so it can be switched off.
    @Published var showsMenuArtwork: Bool {
        didSet { defaults.set(showsMenuArtwork, forKey: Key.menuArtwork) }
    }

    /// Keeps a volume bar on screen permanently, rather than only while the
    /// wheel is turning. Off by default: the overlay is enough once you know
    /// the wheel does volume, and the screen is small.
    @Published var showsVolumeSlider: Bool {
        didSet { defaults.set(showsVolumeSlider, forKey: Key.volumeSlider) }
    }

    /// Whether picking a song out of a list leaves the rest of that list
    /// queued behind it. See `PlaybackQueue` — the widget keeps that order
    /// itself and writes nothing to the library either way.
    @Published var queuesRestOfList: Bool {
        didSet { defaults.set(queuesRestOfList, forKey: Key.queueRest) }
    }

    /// Remembered on our side: MediaRemote can set these but exposes no
    /// readable current value. See `PlaybackModeController`.
    @Published var shuffleMode: ShuffleMode {
        didSet { defaults.set(shuffleMode.rawValue, forKey: Key.shuffleMode) }
    }

    @Published var repeatMode: RepeatMode {
        didSet { defaults.set(repeatMode.rawValue, forKey: Key.repeatMode) }
    }

    /// Mirrors `SMAppService`, which is the real source of truth — writing here
    /// registers or unregisters the login item.
    @Published var launchesAtLogin: Bool {
        didSet {
            guard launchesAtLogin != LaunchAtLogin.isEnabled else { return }
            let resulting = LaunchAtLogin.set(launchesAtLogin)
            if resulting != launchesAtLogin { launchesAtLogin = resulting }
        }
    }

    private let defaults: UserDefaults

    private enum Key {
        static let themeID = "theme.id"
        static let customSkin = "theme.customSkin"
        static let width = "widget.width"
        static let cornerRadius = "widget.cornerRadius"
        static let overallOpacity = "widget.overallOpacity"
        static let artworkMonochrome = "screen.artworkMonochrome"
        static let placement = "widget.placement"
        static let positionLocked = "widget.positionLocked"
        static let appearance = "widget.appearance"
        static let playbackDetail = "screen.playbackDetail"
        static let wheelScroll = "wheel.scroll"
        static let wheelClick = "wheel.click"
        static let wheelClickVolume = "wheel.clickVolume"
        static let volumeSlider = "screen.volumeSlider"
        static let menuArtwork = "menu.artwork"
        static let queueRest = "playback.queueRest"
        static let shuffleMode = "playback.shuffleMode"
        static let repeatMode = "playback.repeatMode"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        self.selectedThemeID = defaults.string(forKey: Key.themeID) ?? ThemeCatalog.fallback.id
        self.customSkin = Self.loadCustomSkin(from: defaults)

        let storedWidth = defaults.object(forKey: Key.width) as? Double ?? Self.defaultWidth
        self.width = storedWidth.clamped(to: SpindleMetrics.minWidth...SpindleMetrics.maxWidth)

        let storedRadius = defaults.object(forKey: Key.cornerRadius) as? Double
            ?? Self.defaultCornerRadius
        self.cornerRadius = storedRadius.clamped(to: Self.minCornerRadius...Self.maxCornerRadius)

        let storedOpacity = defaults.object(forKey: Key.overallOpacity) as? Double ?? 1.0
        self.overallOpacity = storedOpacity.clamped(to: Self.minOpacity...1.0)

        self.isArtworkMonochrome = defaults.bool(forKey: Key.artworkMonochrome)

        let storedPlacement = defaults.string(forKey: Key.placement) ?? ""
        self.placement = Placement(rawValue: storedPlacement) ?? .desktop

        self.isPositionLocked = defaults.object(forKey: Key.positionLocked) as? Bool ?? false

        let storedAppearance = defaults.string(forKey: Key.appearance) ?? ""
        self.appearance = Appearance(rawValue: storedAppearance) ?? .matchSystem

        self.showsPlaybackDetail = defaults.object(forKey: Key.playbackDetail) as? Bool ?? true
        self.isWheelScrollEnabled = defaults.object(forKey: Key.wheelScroll) as? Bool ?? true
        self.isWheelClickEnabled = defaults.object(forKey: Key.wheelClick) as? Bool ?? true
        let storedClickVolume = defaults.object(forKey: Key.wheelClickVolume) as? Double ?? 0.6
        self.wheelClickVolume = storedClickVolume.clamped(to: 0...1)
        self.showsVolumeSlider = defaults.object(forKey: Key.volumeSlider) as? Bool ?? false
        self.showsMenuArtwork = defaults.object(forKey: Key.menuArtwork) as? Bool ?? true
        self.queuesRestOfList = defaults.object(forKey: Key.queueRest) as? Bool ?? true

        let storedShuffle = defaults.object(forKey: Key.shuffleMode) as? Int ?? 0
        self.shuffleMode = ShuffleMode(rawValue: storedShuffle) ?? .off

        let storedRepeat = defaults.object(forKey: Key.repeatMode) as? Int ?? 0
        self.repeatMode = RepeatMode(rawValue: storedRepeat) ?? .off

        self.launchesAtLogin = LaunchAtLogin.isEnabled
    }

    // MARK: - Derived

    /// The active skin. Computed rather than stored so edits to `customSkin`
    /// take effect immediately without a second source of truth.
    var theme: Theme {
        selectedThemeID == CustomSkin.themeID ? customSkin.theme : ThemeCatalog.theme(withID: selectedThemeID)
    }

    /// Built-in skins plus the live custom one, for the picker grid.
    var availableThemes: [Theme] {
        ThemeCatalog.all + [customSkin.theme]
    }

    var isCustomSkinSelected: Bool { selectedThemeID == CustomSkin.themeID }

    var colorScheme: ColorScheme? {
        switch appearance {
        case .matchSystem: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    var metrics: SpindleMetrics { SpindleMetrics(bodyWidth: width) }

    // MARK: - Custom skin persistence

    private func persistCustomSkin() {
        guard let data = try? JSONEncoder().encode(customSkin) else {
            NSLog("Spindle: could not encode custom skin")
            return
        }
        defaults.set(data, forKey: Key.customSkin)
    }

    private static func loadCustomSkin(from defaults: UserDefaults) -> CustomSkin {
        guard let data = defaults.data(forKey: Key.customSkin),
              let skin = try? JSONDecoder().decode(CustomSkin.self, from: data) else {
            return CustomSkin()
        }
        return skin
    }
}

extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
