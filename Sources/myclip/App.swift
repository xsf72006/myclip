import SwiftUI
import AppKit

@main
struct MyClipApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        Settings { SettingsView(model: delegate.settingsModel) }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let store = HistoryStore()
    var monitor: ClipboardMonitor!
    var panelController: PanelController!
    var hotkey: HotKeyManager!
    var statusItem: NSStatusItem!
    lazy var settingsModel: SettingsModel = SettingsModel(hotkey: hotkey)

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        panelController = PanelController(store: store)
        monitor = ClipboardMonitor(store: store)
        monitor.start()

        hotkey = HotKeyManager(panelController: panelController)
        hotkey.register()

        setupStatusItem()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
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

        statusItem.menu = menu
    }

    @objc private func showPanel() { panelController.show() }
    @objc private func clearHistory() { store.clear() }
    @objc private func openSettings() {
        NSApp.activate(ignoringOtherApps: true)
        if #available(macOS 14, *) {
            // macOS 14+ replaces the old `showSettingsWindow:` selector path.
            // Use the public Settings scene by sending the same selector the
            // menu sends from a normal app.
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        }
    }
}
