import AppKit

/// Status-bar item: show/hide, the playback and wheel adjustments, launch at
/// login, settings and quit.
///
/// MENU on the click wheel now walks the original's own menu, so this is where the
/// app's own controls live.
@MainActor
final class MenuBarController: NSObject, NSMenuDelegate {

    private let statusItem: NSStatusItem
    private let settings: AppSettings
    private let device: SpindleViewModel
    private let onToggleWidget: () -> Void
    private let onOpenSettings: () -> Void
    private let isWidgetVisible: () -> Bool

    private var toggleItem: NSMenuItem?
    private var shuffleItems: [ShuffleMode: NSMenuItem] = [:]
    private var repeatItems: [RepeatMode: NSMenuItem] = [:]
    private var checkboxes: [NSMenuItem: KeyPath<AppSettings, Bool>] = [:]

    init(
        settings: AppSettings,
        device: SpindleViewModel,
        onToggleWidget: @escaping () -> Void,
        onOpenSettings: @escaping () -> Void,
        isWidgetVisible: @escaping () -> Bool
    ) {
        self.settings = settings
        self.device = device
        self.onToggleWidget = onToggleWidget
        self.onOpenSettings = onOpenSettings
        self.isWidgetVisible = isWidgetVisible
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        configure()
    }

    private func configure() {
        // A plain dial, matching the app icon. The obvious SF Symbol here is
        // named after Apple's product, which is the association this app is
        // deliberately not making.
        let image = NSImage(
            systemSymbolName: "smallcircle.filled.circle", accessibilityDescription: "Spindle"
        ) ?? NSImage(systemSymbolName: "music.note", accessibilityDescription: "Spindle")
        image?.isTemplate = true
        statusItem.button?.image = image
        statusItem.menu = makeMenu()
    }

    // MARK: - Menu construction

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()
        menu.delegate = self
        menu.autoenablesItems = false

        toggleItem = menu.add("Hide Widget", #selector(toggleWidget), target: self)
        menu.addItem(.separator())

        menu.addItem(submenu(title: "Shuffle", items: ShuffleMode.allCases.map { mode in
            let item = NSMenuItem(title: mode.label, action: #selector(setShuffle(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = mode.rawValue
            shuffleItems[mode] = item
            return item
        }))

        menu.addItem(submenu(title: "Repeat", items: RepeatMode.allCases.map { mode in
            let item = NSMenuItem(title: mode.label, action: #selector(setRepeat(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = mode.rawValue
            repeatItems[mode] = item
            return item
        }))

        menu.addItem(.separator())
        addCheckbox(to: menu, title: "Show Progress & Status",
                    action: #selector(togglePlaybackDetail), keyPath: \.showsPlaybackDetail)
        addCheckbox(to: menu, title: "Wheel Scrolls Volume",
                    action: #selector(toggleWheelScroll), keyPath: \.isWheelScrollEnabled)
        addCheckbox(to: menu, title: "Wheel Click Sound",
                    action: #selector(toggleWheelClick), keyPath: \.isWheelClickEnabled)
        addCheckbox(to: menu, title: "Continue List After a Song",
                    action: #selector(toggleQueueRest), keyPath: \.queuesRestOfList)
        addCheckbox(to: menu, title: "Lock Position",
                    action: #selector(togglePositionLock), keyPath: \.isPositionLocked)

        menu.addItem(.separator())
        addCheckbox(to: menu, title: "Launch at Login",
                    action: #selector(toggleLaunchAtLogin), keyPath: \.launchesAtLogin)
        menu.add("Settings…", #selector(openSettings), target: self, key: ",")

        menu.addItem(.separator())
        menu.add("Quit Spindle", #selector(quit), target: self, key: "q")
        return menu
    }

    private func submenu(title: String, items: [NSMenuItem]) -> NSMenuItem {
        let parent = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        let child = NSMenu()
        items.forEach { child.addItem($0) }
        parent.submenu = child
        return parent
    }

    private func addCheckbox(
        to menu: NSMenu, title: String, action: Selector, keyPath: KeyPath<AppSettings, Bool>
    ) {
        let item = menu.add(title, action, target: self)
        checkboxes[item] = keyPath
    }

    // MARK: - State

    func menuWillOpen(_ menu: NSMenu) {
        toggleItem?.title = isWidgetVisible() ? "Hide Widget" : "Show Widget"
        for (mode, item) in shuffleItems {
            item.state = device.shuffle == mode ? .on : .off
        }
        for (mode, item) in repeatItems {
            item.state = device.repeatMode == mode ? .on : .off
        }
        for (item, keyPath) in checkboxes {
            item.state = settings[keyPath: keyPath] ? .on : .off
        }
    }

    // MARK: - Actions

    @objc private func toggleWidget() { onToggleWidget() }
    @objc private func openSettings() { onOpenSettings() }
    @objc private func quit() { NSApp.terminate(nil) }

    @objc private func setShuffle(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? Int,
              let mode = ShuffleMode(rawValue: raw) else { return }
        device.apply(shuffle: mode)
    }

    @objc private func setRepeat(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? Int,
              let mode = RepeatMode(rawValue: raw) else { return }
        device.apply(repeatMode: mode)
    }

    @objc private func togglePlaybackDetail() {
        settings.showsPlaybackDetail.toggle()
    }

    @objc private func toggleWheelScroll() {
        settings.isWheelScrollEnabled.toggle()
    }

    @objc private func toggleWheelClick() {
        settings.isWheelClickEnabled.toggle()
    }

    @objc private func toggleQueueRest() {
        settings.queuesRestOfList.toggle()
    }

    @objc private func togglePositionLock() {
        settings.isPositionLocked.toggle()
    }

    @objc private func toggleLaunchAtLogin() {
        settings.launchesAtLogin.toggle()
    }
}

private extension NSMenu {
    /// Adds a targeted item and hands it back, which keeps the menu assembly
    /// above readable as a list rather than four lines per entry.
    @discardableResult
    func add(
        _ title: String, _ action: Selector, target: AnyObject, key: String = ""
    ) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = target
        addItem(item)
        return item
    }
}
