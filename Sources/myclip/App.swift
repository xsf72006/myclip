import SwiftUI
import AppKit

@main
struct MyClipApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate

    // No real scene — settings opens via a custom NSWindow from AppDelegate
    // because SwiftUI's `Settings` scene + .accessory activation policy is
    // unreliable for menu-bar apps.
    var body: some Scene {
        Settings { EmptyView() }
    }
}

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
        monitor = ClipboardMonitor(store: store)
        monitor?.start()
        hotkey.register()
        setupStatusItem()
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
                contentRect: NSRect(x: 0, y: 0, width: 440, height: 260),
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
