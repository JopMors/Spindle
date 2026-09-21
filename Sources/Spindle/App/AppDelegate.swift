import AppKit

/// Wires the object graph together and owns the app's top-level controllers.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    private let settings = AppSettings()
    private lazy var service: MediaService = MediaRemoteAdapterService()
    private lazy var viewModel = NowPlayingViewModel(service: service)
    private lazy var device = SpindleViewModel(settings: settings)

    private var widgetController: WidgetWindowController?
    private var settingsController: SettingsWindowController?
    private var menuBarController: MenuBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Agent app: no Dock icon, lives in the menu bar.
        NSApp.setActivationPolicy(.accessory)

        let settingsController = SettingsWindowController(
            settings: settings,
            backendDescription: viewModel.backendDescription
        )
        self.settingsController = settingsController

        // Reaching Settings from the original's own menu, rather than the wheel's
        // MENU button, which now walks the menu hierarchy.
        device.onOpenSettings = { settingsController.show() }

        let widgetController = WidgetWindowController(
            settings: settings,
            viewModel: viewModel,
            device: device
        )
        self.widgetController = widgetController

        menuBarController = MenuBarController(
            settings: settings,
            device: device,
            onToggleWidget: { widgetController.toggle() },
            onOpenSettings: { settingsController.show() },
            isWidgetVisible: { widgetController.isVisible }
        )

        // The queue hands the next track to Music as the current one ends, so
        // it has to see every playback update.
        device.observeNowPlaying(viewModel.$nowPlaying)

        widgetController.show()
        viewModel.start()
        device.seedModesFromSystem()
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Without this the perl helper would outlive the app.
        viewModel.stop()
        device.stop()
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool { true }
}
