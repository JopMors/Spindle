import AppKit

// Explicit AppKit entry point rather than the SwiftUI `App` lifecycle: the
// widget is a custom NSPanel and the app is a menu-bar agent, both of which are
// simpler to control directly.
// Before anything reads a setting: the app used to have a different bundle
// identifier, and UserDefaults is keyed by it.
SettingsMigration.run()

let application = NSApplication.shared
// Top-level code is not actor-isolated, but it does run on the main thread,
// which is exactly what the main-actor-isolated delegate requires.
let delegate = MainActor.assumeIsolated { AppDelegate() }
application.delegate = delegate
application.run()
