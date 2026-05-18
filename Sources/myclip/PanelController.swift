import AppKit
import SwiftUI
import ApplicationServices
import Carbon.HIToolbox

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
        previousApp = NSWorkspace.shared.frontmostApplication

        let panel = panel ?? makePanel()
        self.panel = panel

        coordinator.query = ""
        coordinator.showAll = false
        coordinator.ensureValidSelection(in: store.items)
        coordinator.focusToken &+= 1

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
            pasteSelected()
            return nil
        default:
            return event
        }
    }

    // MARK: - Pick actions

    /// Enter / context-menu "Paste": move to top, write to clipboard, hide,
    /// re-activate the previous app, post ⌘V.
    func pasteSelected() {
        guard let item = currentSelection() else { return }
        let prev = previousApp
        store.moveToTop(item)
        writeToPasteboard(item)
        hide()

        guard let prev,
              prev.processIdentifier != ProcessInfo.processInfo.processIdentifier else { return }
        prev.activate()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            Self.simulatePaste()
        }
    }

    /// Context-menu "Copy": move to top + write to clipboard only. No app
    /// activation, no synthetic ⌘V — user paste manually wherever they want.
    func copyItem(_ item: ClipItem) {
        store.moveToTop(item)
        writeToPasteboard(item)
        hide()
    }

    func pasteItem(_ item: ClipItem) {
        coordinator.selection = item.id
        pasteSelected()
    }

    private func currentSelection() -> ClipItem? {
        guard let id = coordinator.selection else { return nil }
        return store.items.first(where: { $0.id == id })
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
    /// Looks up the keyCode for "v" in the active keyboard layout so this
    /// works on Dvorak / Colemak / AZERTY, not just US QWERTY.
    /// Requires Accessibility permission; on first call macOS shows the
    /// standard prompt and we silently no-op until granted.
    private static func simulatePaste() {
        let trusted = AXIsProcessTrustedWithOptions([
            kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true
        ] as CFDictionary)
        guard trusted else { return }

        // Fall back to position 9 (V on US QWERTY) if layout lookup fails.
        let vKey = keyCodeForCharacter("v") ?? 9
        let source = CGEventSource(stateID: .combinedSessionState)
        if let down = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: true) {
            down.flags = .maskCommand
            down.post(tap: .cghidEventTap)
        }
        if let up = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: false) {
            up.flags = .maskCommand
            up.post(tap: .cghidEventTap)
        }
    }

    /// Find the physical keyCode that produces `char` under the current
    /// keyboard layout. Iterates the layout map via UCKeyTranslate.
    private static func keyCodeForCharacter(_ char: String) -> CGKeyCode? {
        guard let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
              let layoutPtr = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData)
        else { return nil }
        let layoutData = Unmanaged<CFData>.fromOpaque(layoutPtr).takeUnretainedValue() as Data
        let kbType = UInt32(LMGetKbdType())
        let target = char.lowercased()

        return layoutData.withUnsafeBytes { raw -> CGKeyCode? in
            guard let base = raw.baseAddress else { return nil }
            let keyboardPtr = base.assumingMemoryBound(to: UCKeyboardLayout.self)
            for kc in CGKeyCode(0)..<CGKeyCode(128) {
                var dead: UInt32 = 0
                var chars = [UniChar](repeating: 0, count: 4)
                var actual = 0
                let status = UCKeyTranslate(
                    keyboardPtr,
                    kc,
                    UInt16(kUCKeyActionDown),
                    0,
                    kbType,
                    OptionBits(kUCKeyTranslateNoDeadKeysMask),
                    &dead,
                    4,
                    &actual,
                    &chars
                )
                if status == noErr, actual > 0,
                   String(utf16CodeUnits: chars, count: actual).lowercased() == target {
                    return kc
                }
            }
            return nil
        }
    }

    // MARK: - Panel construction

    private func makePanel() -> NSPanel {
        let content = ContentView(
            store: store,
            coordinator: coordinator,
            onPaste: { [weak self] item in self?.pasteItem(item) },
            onCopy:  { [weak self] item in self?.copyItem(item) }
        )
        let hosting = NSHostingController(rootView: content)

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
