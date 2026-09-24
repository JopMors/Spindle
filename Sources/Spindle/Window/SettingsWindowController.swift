import AppKit
import SwiftUI

/// Hosts the settings panel in a standard, closable utility window.
@MainActor
final class SettingsWindowController {

    private let settings: AppSettings
    private let spotify: SpotifyAuthorizer
    private let backendDescription: String
    private var window: NSWindow?

    init(settings: AppSettings, spotify: SpotifyAuthorizer, backendDescription: String) {
        self.settings = settings
        self.spotify = spotify
        self.backendDescription = backendDescription
    }

    func show() {
        let window = window ?? makeWindow()
        self.window = window
        // Settings is a real window, so the app must come forward for it.
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.center()
    }

    private func makeWindow() -> NSWindow {
        let view = SettingsView(
            settings: settings,
            spotify: spotify,
            backendDescription: backendDescription
        )
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 480),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Spindle Settings"
        window.contentView = NSHostingView(rootView: view)
        window.isReleasedWhenClosed = false
        window.setContentSize(window.contentView?.fittingSize ?? window.frame.size)
        return window
    }
}
