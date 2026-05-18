import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @ObservedObject var model: SettingsModel

    private let presets: [(label: String, spec: HotKeySpec)] = [
        ("⌘⇧C",     HotKeySpec(key: .c,     modifiers: [.command, .shift])),
        ("⌘⇧V",     HotKeySpec(key: .v,     modifiers: [.command, .shift])),
        ("⌘⌥V",     HotKeySpec(key: .v,     modifiers: [.command, .option])),
        ("⌃⇧Space", HotKeySpec(key: .space, modifiers: [.control, .shift]))
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Toggle Shortcut")
                .font(.headline)

            VStack(alignment: .leading, spacing: 6) {
                Text("Recorder")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                ShortcutRecorder(model: model)
                Text("Click the field, then press the combination you want · Esc to cancel.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Presets")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                HStack(spacing: 6) {
                    ForEach(presets, id: \.label) { preset in
                        Button(preset.label) { model.set(preset.spec) }
                            .buttonStyle(.bordered)
                    }
                }
            }

            Divider()

            Toggle("Open at Login", isOn: $model.openAtLogin)
                .toggleStyle(.switch)
            if model.loginStatusNote != nil {
                Text(model.loginStatusNote ?? "")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(width: 460, height: 340)
    }
}

@MainActor
final class SettingsModel: ObservableObject {
    @Published var current: HotKeySpec
    @Published var openAtLogin: Bool {
        didSet { applyLoginToggle(openAtLogin) }
    }
    @Published var loginStatusNote: String?

    private let hotkey: HotKeyManager
    private var suppressLoginToggle = false

    init(hotkey: HotKeyManager) {
        self.hotkey = hotkey
        self.current = hotkey.currentSpec()
        self.openAtLogin = SMAppService.mainApp.status == .enabled
        self.loginStatusNote = Self.note(for: SMAppService.mainApp.status)
    }

    func set(_ spec: HotKeySpec) {
        hotkey.update(spec)
        current = spec
    }

    private func applyLoginToggle(_ enabled: Bool) {
        guard !suppressLoginToggle else { return }
        let svc = SMAppService.mainApp
        do {
            if enabled { try svc.register() } else { try svc.unregister() }
            loginStatusNote = Self.note(for: svc.status)
        } catch {
            loginStatusNote = "Couldn't update Login Items: \(error.localizedDescription)"
            // Revert the toggle without recursing into this didSet.
            suppressLoginToggle = true
            openAtLogin = (svc.status == .enabled)
            suppressLoginToggle = false
        }
    }

    private static func note(for status: SMAppService.Status) -> String? {
        switch status {
        case .enabled:           return nil
        case .notRegistered:     return nil
        case .notFound:          return "Move myclip to /Applications first."
        case .requiresApproval:  return "Approve myclip in System Settings → General → Login Items."
        @unknown default:        return nil
        }
    }
}
