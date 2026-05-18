import SwiftUI
import AppKit
import HotKey

/// A "record-the-keys-I-press" shortcut field, modelled after the recorder
/// in System Settings → Keyboard → Shortcuts. Click to arm; press the desired
/// combo (must include at least one modifier); Esc cancels.
struct ShortcutRecorder: View {
    @ObservedObject var model: SettingsModel
    @StateObject private var recorder = ShortcutRecorderModel()
    @State private var hovering = false

    var body: some View {
        Button(action: recorder.toggle) {
            HStack(spacing: 8) {
                Text(recorder.isRecording
                     ? "Press shortcut · Esc to cancel"
                     : model.current.description)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(recorder.isRecording ? Color.accentColor : Color.primary)
                Spacer()
                Image(systemName: recorder.isRecording ? "record.circle.fill" : "pencil")
                    .foregroundStyle(recorder.isRecording ? .red : .secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(background)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(border, lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .onAppear { recorder.attach(model) }
        .onDisappear { recorder.stop() }
    }

    private var background: Color {
        if recorder.isRecording { return Color.accentColor.opacity(0.12) }
        if hovering              { return Color.secondary.opacity(0.10) }
        return Color.clear
    }

    private var border: Color {
        recorder.isRecording ? Color.accentColor : Color.secondary.opacity(0.35)
    }
}

@MainActor
final class ShortcutRecorderModel: ObservableObject {
    @Published private(set) var isRecording = false

    private var monitor: Any?
    private weak var settingsModel: SettingsModel?

    func attach(_ model: SettingsModel) { settingsModel = model }

    func toggle() { isRecording ? stop() : start() }

    func start() {
        guard monitor == nil else { return }
        isRecording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handle(event)
        }
    }

    func stop() {
        isRecording = false
        if let m = monitor {
            NSEvent.removeMonitor(m)
            monitor = nil
        }
    }

    private func handle(_ event: NSEvent) -> NSEvent? {
        // Esc → cancel without changing anything.
        if event.keyCode == 53 { stop(); return nil }

        let mods = event.modifierFlags.intersection([.command, .control, .option, .shift])
        guard !mods.isEmpty else {
            // A bare key isn't a usable global shortcut; let user keep trying.
            NSSound.beep()
            return nil
        }

        guard let key = Self.key(from: event) else {
            NSSound.beep()
            return nil
        }

        settingsModel?.set(HotKeySpec(key: key, modifiers: mods))
        stop()
        return nil
    }

    /// Map an NSEvent to a HotKey `Key` — first try `charactersIgnoringModifiers`
    /// for letters/digits/symbols, then fall back to keyCode for special keys.
    private static func key(from event: NSEvent) -> Key? {
        if let chars = event.charactersIgnoringModifiers?.lowercased(),
           let first = chars.first,
           let key = Key(string: String(first)) {
            return key
        }
        switch event.keyCode {
        case 49:  return .space
        case 36:  return .return
        case 48:  return .tab
        case 51:  return .delete
        case 117: return .forwardDelete
        case 122: return .f1
        case 120: return .f2
        case 99:  return .f3
        case 118: return .f4
        case 96:  return .f5
        case 97:  return .f6
        case 98:  return .f7
        case 100: return .f8
        case 101: return .f9
        case 109: return .f10
        case 103: return .f11
        case 111: return .f12
        case 126: return .upArrow
        case 125: return .downArrow
        case 123: return .leftArrow
        case 124: return .rightArrow
        default:  return nil
        }
    }
}
