import AppKit

/// Per-app transport control via Apple Events.
///
/// Only used when MediaRemote refuses a command. Covers Music and Spotify,
/// which is the practical limit of the public scripting APIs.
enum AppleScriptController {

    /// Apps we can drive, in priority order.
    private enum Target: String, CaseIterable {
        case spotify = "Spotify"
        case music = "Music"

        var bundleIdentifier: String {
            switch self {
            case .spotify: return "com.spotify.client"
            case .music: return "com.apple.Music"
            }
        }
    }

    /// Sends `command` to the first running target that is actually playing,
    /// falling back to the first running target. Returns true if a script ran
    /// without error.
    @discardableResult
    static func send(_ command: TransportCommand) -> Bool {
        guard let target = preferredTarget() else { return false }
        return run(script: "tell application \"\(target.rawValue)\" to \(action(for: command))")
    }

    /// Seeking, for the rare player MediaRemote will not seek for us.
    ///
    /// Both targets spell it the same way, and both refuse it while paused, so
    /// the caller gets `false` rather than a silent no-op.
    @discardableResult
    static func seek(to seconds: TimeInterval) -> Bool {
        guard let target = preferredTarget() else { return false }
        return run(
            script: "tell application \"\(target.rawValue)\" to set player position to \(seconds)"
        )
    }

    private static func action(for command: TransportCommand) -> String {
        switch command {
        case .togglePlayPause: return "playpause"
        case .nextTrack: return "next track"
        case .previousTrack: return "previous track"
        }
    }

    private static func preferredTarget() -> Target? {
        let running = Target.allCases.filter { isRunning($0) }
        guard !running.isEmpty else { return nil }
        return running.first { isPlaying($0) } ?? running.first
    }

    private static func isRunning(_ target: Target) -> Bool {
        !NSRunningApplication
            .runningApplications(withBundleIdentifier: target.bundleIdentifier)
            .isEmpty
    }

    private static func isPlaying(_ target: Target) -> Bool {
        let script = "tell application \"\(target.rawValue)\" to return player state as text"
        return output(of: script)?.contains("playing") == true
    }

    // MARK: - Script execution

    /// Runs a script, discarding the result. Errors are logged, never thrown:
    /// a failed transport command should not take the widget down.
    @discardableResult
    private static func run(script source: String) -> Bool {
        output(of: source) != nil
    }

    private static func output(of source: String) -> String? {
        guard let script = NSAppleScript(source: source) else { return nil }
        var error: NSDictionary?
        let result = script.executeAndReturnError(&error)
        if let error {
            let code = error[NSAppleScript.errorNumber] as? Int ?? 0
            // -1743 is "not authorised to send Apple events" — the user has not
            // granted Automation permission yet.
            let detail = error[NSAppleScript.errorMessage] as? String ?? "unknown"
            NSLog("Spindle: AppleScript failed (\(code)): \(detail)")
            return nil
        }
        return result.stringValue ?? ""
    }
}
