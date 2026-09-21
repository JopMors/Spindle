import AppKit
import Foundation

/// Best-effort read of Music's current shuffle and repeat setting.
///
/// MediaRemote can *set* both but exposes no readable value, so the widget
/// normally shows what it last set. That drifts if the setting is changed in
/// Music directly, which this corrects at launch.
///
/// Deliberately silent: it asks whether Automation is already permitted and
/// gives up if it is not, rather than raising a permission prompt for a pair of
/// status glyphs. The prompt belongs to the menu, where the user asked for it.
enum PlaybackModeReader {

    private static let musicBundleID = "com.apple.Music"

    /// Nil when Music is not running, not scriptable, or not yet permitted.
    static func currentModes() -> (shuffle: ShuffleMode, repeatMode: RepeatMode)? {
        guard isAutomationAlreadyPermitted else { return nil }
        guard let descriptor = run("""
        tell application "Music" to get {shuffle enabled, song repeat as string}
        """) else { return nil }

        guard descriptor.numberOfItems >= 2,
              let shuffleOn = descriptor.atIndex(1)?.booleanValue,
              let repeatName = descriptor.atIndex(2)?.stringValue else { return nil }

        return (shuffleOn ? .songs : .off, repeatMode(named: repeatName))
    }

    private static func repeatMode(named name: String) -> RepeatMode {
        switch name.lowercased() {
        case "one": return .one
        case "all": return .all
        default: return .off
        }
    }

    /// Asks TCC without offering to prompt. `askUserIfNeeded: false` is the
    /// whole point — anything else would put a dialog in front of the user at
    /// launch.
    private static var isAutomationAlreadyPermitted: Bool {
        guard NSWorkspace.shared.runningApplications.contains(where: {
            $0.bundleIdentifier == musicBundleID
        }) else { return false }

        var target = AEAddressDesc()
        let created = musicBundleID.withCString { pointer in
            AECreateDesc(typeApplicationBundleID, pointer, strlen(pointer), &target)
        }
        guard created == noErr else { return false }
        defer { AEDisposeDesc(&target) }

        return AEDeterminePermissionToAutomateTarget(
            &target, typeWildCard, typeWildCard, false
        ) == noErr
    }

    private static func run(_ source: String) -> NSAppleEventDescriptor? {
        guard let script = NSAppleScript(source: source) else { return nil }
        var errorInfo: NSDictionary?
        let descriptor = script.executeAndReturnError(&errorInfo)
        guard errorInfo == nil else {
            Diagnostics.log("mode read failed: \(errorInfo ?? [:])")
            return nil
        }
        return descriptor
    }
}
