import Foundation

/// Sets shuffle and repeat through MediaRemote.
///
/// `MRMediaRemoteSetShuffleMode` and `MRMediaRemoteSetRepeatMode` work from an
/// ordinary unentitled process — verified against Music.app on macOS 26.5.2 —
/// so unlike *reading* now-playing state this needs no perl detour and no
/// Automation permission, and it reaches any player, not just Music.
///
/// There is no matching read: the registration APIs take a block whose shape is
/// undocumented, so the current setting is remembered on our side instead.
/// Seam over the MediaRemote setters, so tests can exercise mode cycling
/// without reaching out and changing what the machine is actually playing.
protocol PlaybackModeSetting: AnyObject {
    func setShuffle(_ mode: ShuffleMode)
    func setRepeat(_ mode: RepeatMode)
}

final class PlaybackModeController: PlaybackModeSetting {

    private typealias SetModeFn = @convention(c) (Int32) -> Void

    private let setShuffleMode: SetModeFn?
    private let setRepeatMode: SetModeFn?

    var isAvailable: Bool { setShuffleMode != nil && setRepeatMode != nil }

    init() {
        let path = "/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote"
        let handle = dlopen(path, RTLD_NOW)
        setShuffleMode = Self.lookup(handle, "MRMediaRemoteSetShuffleMode")
        setRepeatMode = Self.lookup(handle, "MRMediaRemoteSetRepeatMode")
    }

    private static func lookup(_ handle: UnsafeMutableRawPointer?, _ name: String) -> SetModeFn? {
        guard let handle, let symbol = dlsym(handle, name) else { return nil }
        return unsafeBitCast(symbol, to: SetModeFn.self)
    }

    func setShuffle(_ mode: ShuffleMode) {
        guard let setShuffleMode else {
            Diagnostics.log("MRMediaRemoteSetShuffleMode unavailable")
            return
        }
        setShuffleMode(Int32(mode.rawValue))
    }

    func setRepeat(_ mode: RepeatMode) {
        guard let setRepeatMode else {
            Diagnostics.log("MRMediaRemoteSetRepeatMode unavailable")
            return
        }
        setRepeatMode(Int32(mode.rawValue))
    }
}
