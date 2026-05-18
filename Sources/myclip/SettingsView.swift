import SwiftUI

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

            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(width: 460, height: 280)
    }
}

@MainActor
final class SettingsModel: ObservableObject {
    @Published var current: HotKeySpec

    private let hotkey: HotKeyManager

    init(hotkey: HotKeyManager) {
        self.hotkey = hotkey
        self.current = hotkey.currentSpec()
    }

    func set(_ spec: HotKeySpec) {
        hotkey.update(spec)
        current = spec
    }
}
