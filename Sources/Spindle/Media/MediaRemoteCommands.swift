import Foundation

/// Sends transport commands through MediaRemote.
///
/// Unlike *reading* now-playing info, `MRMediaRemoteSendCommand` still works
/// from an ordinary unentitled app on macOS 15.4+ (verified on 26.5.2), so this
/// needs no perl detour. Falls back to AppleScript when the symbol is missing.
final class MediaRemoteCommands {

    /// MediaRemote command identifiers.
    private enum Command: Int {
        case play = 0
        case pause = 1
        case togglePlayPause = 2
        case nextTrack = 4
        case previousTrack = 5
    }

    private typealias SendCommandFn = @convention(c) (Int32, CFDictionary?) -> Bool
    private typealias SetElapsedFn = @convention(c) (Double) -> Void

    private let handle: UnsafeMutableRawPointer?
    private let sendCommand: SendCommandFn?
    private let setElapsed: SetElapsedFn?

    /// True when MediaRemote accepted the symbol lookup at load time.
    var isAvailable: Bool { sendCommand != nil }
    var canSeek: Bool { setElapsed != nil }

    init() {
        let path = "/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote"
        handle = dlopen(path, RTLD_NOW)
        if let handle, let symbol = dlsym(handle, "MRMediaRemoteSendCommand") {
            sendCommand = unsafeBitCast(symbol, to: SendCommandFn.self)
        } else {
            sendCommand = nil
        }
        if let handle, let symbol = dlsym(handle, "MRMediaRemoteSetElapsedTime") {
            setElapsed = unsafeBitCast(symbol, to: SetElapsedFn.self)
        } else {
            setElapsed = nil
        }
    }

    /// Seeks the current track, in seconds from its start.
    ///
    /// `MRMediaRemoteSetElapsedTime` works unentitled — verified on macOS
    /// 26.5.2 by seeking Music from 304.5s to 95s from an ordinary process —
    /// so unlike *reading* now-playing state this needs no perl detour, and it
    /// reaches any player on the system media controls, not just Music.
    @discardableResult
    func seek(to seconds: TimeInterval) -> Bool {
        guard let setElapsed else { return false }
        setElapsed(max(seconds, 0))
        return true
    }

    /// Returns true when the command was accepted by MediaRemote.
    @discardableResult
    func send(_ command: TransportCommand) -> Bool {
        guard let sendCommand else { return false }
        return sendCommand(Int32(Self.identifier(for: command).rawValue), nil)
    }

    private static func identifier(for command: TransportCommand) -> Command {
        switch command {
        case .togglePlayPause: return .togglePlayPause
        case .nextTrack: return .nextTrack
        case .previousTrack: return .previousTrack
        }
    }
}
