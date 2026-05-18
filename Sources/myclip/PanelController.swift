import AppKit
import SwiftUI
import ApplicationServices

@MainActor
final class PanelController {
    private var panel: NSPanel?
    private var eventMonitor: Any?
    private var previousApp: NSRunningApplication?

    let store: HistoryStore
    let coordinator: PanelCoordinator

    init(store: HistoryStore) {
        self.store = store
        self.coordinator = PanelCoordinator()
    }

    func toggle() {
        if let panel, panel.isVisible { hide() } else { show() }
    }

    func show() {
        // Capture frontmost BEFORE we activate ourselves so paste-back can
        // return focus to the user's previous app.
        previousApp = NSWorkspace.shared.frontmostApplication

        let panel = panel ?? makePanel()
        self.panel = panel

        coordinator.query = ""
        coordinator.ensureValidSelection(in: store.items)
        coordinator.focusToken &+= 1   // signals ContentView to re-focus search

        if let screen = NSScreen.screens.first(where: { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) })
            ?? NSScreen.main {
            let size = panel.frame.size
            let x = screen.frame.midX - size.width / 2
            let y = screen.frame.midY - size.height / 2
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }

        if eventMonitor == nil {
            eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                self?.handle(event) ?? event
            }
        }

        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    func hide() {
        panel?.orderOut(nil)
        if let m = eventMonitor {
            NSEvent.removeMonitor(m)
            eventMonitor = nil
        }
    }

    private func handle(_ event: NSEvent) -> NSEvent? {
        guard panel?.isVisible == true else { return event }
        switch event.keyCode {
        case 53:                     // Escape
            hide()
            return nil
        case 126:                    // Up arrow
            coordinator.moveSelection(in: store.items, delta: -1)
            return nil
        case 125:                    // Down arrow
            coordinator.moveSelection(in: store.items, delta: 1)
            return nil
        case 36, 76:                 // Return / Enter
            useSelected()
            return nil
        default:
            return event
        }
    }

    private func useSelected() {
        guard let id = coordinator.selection,
              let item = store.items.first(where: { $0.id == id }) else { return }

        let prev = previousApp

        // 1. Promote in store BEFORE clipboard write — combined with the
        //    self-write skip in ClipboardMonitor this avoids both duplicates
        //    and lets the picked item rise to the top of history.
        store.moveToTop(item)

        // 2. Write to clipboard, record the changeCount so monitor skips it.
        writeToPasteboard(item)

        // 3. Close our UI first so the previous app can take focus cleanly.
        hide()

        // 4. Re-activate the user's previous app, then post ⌘V to paste.
        guard let prev,
              prev.processIdentifier != ProcessInfo.processInfo.processIdentifier else { return }
        prev.activate()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            Self.simulatePaste()
        }
    }

    private func writeToPasteboard(_ item: ClipItem) {
        let pb = NSPasteboard.general
        pb.clearContents()
        switch item.kind {
        case .text:
            if let s = item.text { pb.setString(s, forType: .string) }
        case .image:
            if let url = store.imageURL(for: item),
               let data = try? Data(contentsOf: url) {
                pb.setData(data, forType: .png)
            }
        }
        store.lastSelfWrittenChangeCount = pb.changeCount
    }

    /// Synthesise a ⌘V keystroke into whatever app is currently frontmost.
    /// Requires Accessibility permission; on first call macOS shows the
    /// standard prompt and we silently no-op (user falls back to manual ⌘V).
    private static func simulatePaste() {
        let trusted = AXIsProcessTrustedWithOptions([
            kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true
        ] as CFDictionary)
        guard trusted else { return }

        let source = CGEventSource(stateID: .combinedSessionState)
        let vKey: CGKeyCode = 9   // V
        if let down = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: true) {
            down.flags = .maskCommand
            down.post(tap: .cghidEventTap)
        }
        if let up = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: false) {
            up.flags = .maskCommand
            up.post(tap: .cghidEventTap)
        }
    }

    private func makePanel() -> NSPanel {
        let content = ContentView(store: store, coordinator: coordinator) { [weak self] item in
            // Context-menu "Copy": same paste-back path as Enter.
            self?.coordinator.selection = item.id
            self?.useSelected()
        }
        let hosting = NSHostingController(rootView: content)
        hosting.view.frame = NSRect(x: 0, y: 0, width: 720, height: 460)

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 460),
            styleMask: [.titled, .fullSizeContentView, .nonactivatingPanel, .resizable, .closable],
            backing: .buffered,
            defer: false
        )
        panel.contentViewController = hosting
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.level = .floating
        panel.hidesOnDeactivate = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        return panel
    }
}
