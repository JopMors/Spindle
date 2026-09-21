import AppKit

/// Brings whatever is playing to the front.
///
/// The bottom wheel button used to open Music unconditionally, which is wrong
/// on a widget that deliberately reads from every player on the system: if you
/// are listening in Spotify, Music is not the app you want.
///
/// The identifier comes from the adapter — MediaRemote will not tell an
/// ordinary process which app owns the audio — and Music is the fallback when
/// nothing has reported yet.
enum SourceAppLauncher {

    static let fallbackBundleIdentifier = "com.apple.Music"
    private static let fallbackPath = "/System/Applications/Music.app"

    static func open(bundleIdentifier: String?) {
        let identifier = bundleIdentifier ?? fallbackBundleIdentifier
        guard let url = applicationURL(for: identifier) else {
            NSLog("Spindle: could not locate \(identifier)")
            return
        }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.openApplication(at: url, configuration: configuration) { _, error in
            if let error {
                NSLog("Spindle: could not open \(identifier): \(error.localizedDescription)")
            }
        }
    }

    private static func applicationURL(for identifier: String) -> URL? {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: identifier) {
            return url
        }
        guard identifier != fallbackBundleIdentifier else {
            // Older installs and odd system layouts.
            return FileManager.default.fileExists(atPath: fallbackPath)
                ? URL(fileURLWithPath: fallbackPath) : nil
        }
        // The reported app is not installed under that identifier any more;
        // better to open something than nothing.
        return applicationURL(for: fallbackBundleIdentifier)
    }
}
