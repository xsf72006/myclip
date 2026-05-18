import AppKit
import SwiftUI

@MainActor
final class PanelController {
    private var panel: NSPanel?
    private var eventMonitor: Any?

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
        let panel = panel ?? makePanel()
        self.panel = panel

        coordinator.query = ""
        coordinator.ensureValidSelection(in: store.items)

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
        copyToPasteboard(item)
        hide()
    }

    private func copyToPasteboard(_ item: ClipItem) {
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
    }

    private func makePanel() -> NSPanel {
        let content = ContentView(store: store, coordinator: coordinator) { [weak self] item in
            self?.copyToPasteboard(item)
            self?.hide()
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
