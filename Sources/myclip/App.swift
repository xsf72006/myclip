import SwiftUI
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
        Fonts.registerBundled()
        NSApp.setActivationPolicy(.accessory)
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

    @objc private func showPanel() { panelController.show() }
    @objc private func clearHistory() { store.clear() }

    @objc private func openSettings() {
        if settingsWindow == nil {
            let hosting = NSHostingController(rootView: SettingsView(model: settingsModel))
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 460, height: 280),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            window.title = "myclip"
            window.contentViewController = hosting
            window.center()
            window.isReleasedWhenClosed = false
            settingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }
}
