import Foundation

/// Shuffle setting, mirroring the original's Settings → Shuffle menu.
///
/// Raw values are MediaRemote's own mode numbers, verified against Music.app on
/// macOS 26.5.2: 1 leaves shuffle off, 2 and 3 both switch it on.
enum ShuffleMode: Int, CaseIterable, Codable {
    case off = 1
    case albums = 2
    case songs = 3

    var label: String {
        switch self {
        case .off: return "Off"
        case .albums: return "Albums"
        case .songs: return "Songs"
        }
    }

    var isOn: Bool { self != .off }

    /// The original's centre-press cycle. Albums is reachable from the menu only,
    /// because cycling through three states from the wheel is a guessing game.
    var toggled: ShuffleMode { isOn ? .off : .songs }
}

/// Repeat setting, mirroring the original's Settings → Repeat menu.
enum RepeatMode: Int, CaseIterable, Codable {
    case off = 1
    case one = 2
    case all = 3

    var label: String {
        switch self {
        case .off: return "Off"
        case .one: return "One"
        case .all: return "All"
        }
    }

    var isOn: Bool { self != .off }

    /// Off → All → One → Off, which is the order the original cycled them in.
    var cycled: RepeatMode {
        switch self {
        case .off: return .all
        case .all: return .one
        case .one: return .off
        }
    }

    /// SF Symbol shown in the status bar, or nil when repeat is off.
    var symbolName: String? {
        switch self {
        case .off: return nil
        case .one: return "repeat.1"
        case .all: return "repeat"
        }
    }
}
