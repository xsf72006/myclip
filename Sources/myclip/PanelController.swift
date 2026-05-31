import AppKit
import DesignSystem
import ApplicationServices
import Carbon.HIToolbox

private extension String {
    /// Minimal shell-quoting for a path going through `sh -c`. We only need
    /// to wrap in single quotes and escape any embedded single quotes.
    var shellQuoted: String {
        "'" + replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}

@MainActor
final class PanelController {
    private var panel: NSPanel?
    private var eventMonitor: Any?
    private var previousApp: NSRunningApplication?
    /// Invoked at the start of show() so the app can dismiss its other window
    /// (Settings) first — keeps the panel and Settings mutually exclusive.
    var onShow: (() -> Void)?

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
        onShow?()
        previousApp = NSWorkspace.shared.frontmostApplication

        let panel = panel ?? makePanel()
        self.panel = panel

        coordinator.query = ""
        // Always open on the first (newest) row, not wherever we left off last
        // time. nil + ensureValidSelection snaps selection to the first row.
        coordinator.selection = nil
        coordinator.hoverArmed = false
        coordinator.ensureValidSelection(in: store.items, query: coordinator.query)
        coordinator.focusToken &+= 1

        if let screen = NSScreen.screens.first(where: { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) })
            ?? NSScreen.main {
            let size = panel.frame.size
            let x = screen.frame.midX - size.width / 2
            let y = screen.frame.midY - size.height / 2
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }

        if eventMonitor == nil {
            eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .mouseMoved]) { [weak self] event in
                // Must return handle()'s result directly: `?? event` would turn a
                // consumed (nil) key back into a pass-through, leaking Esc/arrows/
                // Enter to the search field editor.
                guard let self else { return event }
                return self.handle(event)
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
        // Hand focus back to whatever app was frontmost when we opened, so its
        // text caret comes alive again. Covers Esc (and Copy); the paste path
        // re-activates prev itself before posting ⌘V, so this is harmless there.
        if let prev = previousApp,
           prev.processIdentifier != ProcessInfo.processInfo.processIdentifier {
            prev.activate()
        }
    }

    /// Order the panel out without handing focus back to the previous app —
    /// used when another myclip window (Settings) is taking over.
    func dismissForAppWindow() {
        panel?.orderOut(nil)
        if let m = eventMonitor {
            NSEvent.removeMonitor(m)
            eventMonitor = nil
        }
    }

    private func handle(_ event: NSEvent) -> NSEvent? {
        guard panel?.isVisible == true else { return event }
        // First real mouse movement after a show arms hover-to-select. Pass the
        // event through untouched so the table's tracking areas still see it.
        if event.type == .mouseMoved {
            coordinator.hoverArmed = true
            return event
        }
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
    /// Requires Accessibility permission — if not granted we surface a
    /// helpful alert (with Quit-and-Relaunch) rather than silently failing.
    private static func simulatePaste() {
        // Check without prompting — we'll show our own clearer alert.
        let trusted = AXIsProcessTrustedWithOptions([
            kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false
        ] as CFDictionary)
        guard trusted else {
            showAccessibilityHelp()
            return
        }

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

    /// macOS caches `AXIsProcessTrusted` per-process and ad-hoc-signed builds
    /// produce a different code signature on every release, so an upgraded
    /// app sees a stale "untrusted" state even when System Settings shows the
    /// toggle on. The fix is for the user to remove the entry + relaunch.
    private static func showAccessibilityHelp() {
        let alert = NSAlert()
        alert.messageText = "myclip needs Accessibility access to paste."
        alert.informativeText = """
            Open System Settings → Privacy & Security → Accessibility and \
            turn myclip on, then quit and reopen myclip so the new permission \
            takes effect.

            Already toggled on? After an upgrade, the previous install's grant \
            goes stale. Click the – button next to myclip to remove it from \
            the list, then come back and try again — macOS will re-prompt \
            cleanly.
            """
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open Accessibility Settings")
        alert.addButton(withTitle: "Quit & Relaunch")
        alert.addButton(withTitle: "Later")

        NSApp.activate(ignoringOtherApps: true)
        switch alert.runModal() {
        case .alertFirstButtonReturn:
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(url)
            }
        case .alertSecondButtonReturn:
            quitAndRelaunch()
        default:
            break
        }
    }

    private static func quitAndRelaunch() {
        let bundlePath = Bundle.main.bundleURL.path
        // Wait a second after we quit, then re-open the bundle. The sleep
        // gives our PID time to fully exit so `open` doesn't no-op against
        // a stale instance.
        let task = Process()
        task.launchPath = "/bin/sh"
        task.arguments = ["-c", "/bin/sleep 1 && /usr/bin/open \(bundlePath.shellQuoted)"]
        try? task.run()
        NSApp.terminate(nil)
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
        let vc = ClipPanelViewController(
            store: store,
            coordinator: coordinator,
            onPaste: { [weak self] item in self?.pasteItem(item) },
            onCopy:  { [weak self] item in self?.copyItem(item) }
        )

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 460),
            styleMask: [.titled, .fullSizeContentView, .closable],
            backing: .buffered,
            defer: false
        )
        panel.contentViewController = vc
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.isOpaque = true
        panel.backgroundColor = DSPalette.surfaceWindow
        panel.level = .floating
        panel.hidesOnDeactivate = true
        panel.acceptsMouseMovedEvents = true   // needed for hover-arming
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        // Transient popup: hide the traffic-light buttons (they'd otherwise
        // overlap the search bar under the full-size-content titlebar).
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        return panel
    }
}
