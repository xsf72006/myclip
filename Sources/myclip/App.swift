import AppKit
import ServiceManagement

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let store: HistoryStore
    let panelController: PanelController
    let hotkey: HotKeyManager
    lazy var settingsModel: SettingsModel = SettingsModel(hotkey: hotkey)

    private var monitor: ClipboardMonitor?
    private var statusItem: NSStatusItem?
    private var settingsWindow: NSWindow?

    override init() {
        self.store = HistoryStore()
        self.panelController = PanelController(store: store)
        self.hotkey = HotKeyManager(panelController: panelController)
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupMainMenu()
        // Opening one window dismisses the other, so the panel and Settings
        // are never on screen at the same time.
        panelController.onShow = { [weak self] in self?.settingsWindow?.orderOut(nil) }
        migrateFromLaunchAgentIfNeeded()
        monitor = ClipboardMonitor(store: store)
        monitor?.start()
        hotkey.register()
        setupStatusItem()
        if isInstalledInApplications() {
            registerForLoginStartup()
        }
    }

    private func isInstalledInApplications() -> Bool {
        Bundle.main.bundlePath.hasPrefix("/Applications/")
    }

    /// Older installs registered a user LaunchAgent at
    /// ~/Library/LaunchAgents/com.myclip.agent.plist. We've moved to
    /// SMAppService, so on first launch of the new build we bootout the old
    /// agent and remove its plist. No-op if it was never installed.
    private func migrateFromLaunchAgentIfNeeded() {
        let oldPlist = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Library/LaunchAgents/com.myclip.agent.plist")
        guard FileManager.default.fileExists(atPath: oldPlist.path) else { return }

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        task.arguments = ["bootout", "gui/\(getuid())/com.myclip.agent"]
        try? task.run()
        task.waitUntilExit()

        try? FileManager.default.removeItem(at: oldPlist)
        NSLog("myclip: migrated from LaunchAgent to SMAppService")
    }

    private func registerForLoginStartup() {
        let svc = SMAppService.mainApp
        guard svc.status != .enabled else { return }
        do {
            try svc.register()
        } catch {
            NSLog("myclip: SMAppService register failed: \(error.localizedDescription)")
        }
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem = item
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "myclip")
        }
        let menu = NSMenu()

        let showItem = NSMenuItem(title: "Show myclip", action: #selector(showPanel), keyEquivalent: "")
        showItem.target = self
        menu.addItem(showItem)

        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        let clearItem = NSMenuItem(title: "Clear history", action: #selector(clearHistory), keyEquivalent: "")
        clearItem.target = self
        menu.addItem(clearItem)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit myclip", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        item.menu = menu
    }

    /// An accessory (LSUIElement) app shows no menu bar, but a main menu with a
    /// standard Edit submenu is still what routes ⌘A/⌘C/⌘V/⌘X/⌘Z to the field
    /// editor — without it those shortcuts are dead in the search field.
    private func setupMainMenu() {
        let mainMenu = NSMenu()
        let editItem = NSMenuItem()
        mainMenu.addItem(editItem)
        let edit = NSMenu(title: "Edit")
        editItem.submenu = edit
        edit.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        let redo = edit.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        edit.addItem(.separator())
        edit.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        NSApp.mainMenu = mainMenu
    }

    @objc private func showPanel() { panelController.show() }
    @objc private func clearHistory() { store.clear() }

    @objc private func openSettings() {
        panelController.dismissForAppWindow()
        if settingsWindow == nil {
            let vc = SettingsViewController(model: settingsModel)
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 460, height: 340),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            window.title = "myclip"
            window.contentViewController = vc
            window.center()
            window.isReleasedWhenClosed = false
            settingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }
}
