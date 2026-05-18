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

            HStack(spacing: 6) {
                Text("Current:")
                    .foregroundStyle(.secondary)
                Text(model.current.description)
                    .font(.system(.body, design: .monospaced))
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

            VStack(alignment: .leading, spacing: 6) {
                Text("Custom")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    TextField("e.g. command+shift+c", text: $model.draft)
                        .textFieldStyle(.roundedBorder)
                        .frame(minWidth: 240)
                    Button("Apply") { model.applyDraft() }
                        .disabled(HotKeySpec.parse(model.draft) == nil)
                }
                Text("Modifiers: command, shift, option, control · plus one letter, number, or space.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
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
    @Published var draft: String

    private let hotkey: HotKeyManager

    init(hotkey: HotKeyManager) {
        self.hotkey = hotkey
        let initial = hotkey.currentSpec()
        self.current = initial
        self.draft = initial.description
    }

    func set(_ spec: HotKeySpec) {
        hotkey.update(spec)
        current = spec
        draft = spec.description
    }

    func applyDraft() {
        guard let parsed = HotKeySpec.parse(draft) else { return }
        set(parsed)
    }
}
