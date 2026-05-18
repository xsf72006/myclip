import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: SettingsModel

    private let presets: [(label: String, spec: HotKeySpec)] = [
        ("⌘⇧C",  HotKeySpec(key: .c, modifiers: [.command, .shift])),
        ("⌘⇧V",  HotKeySpec(key: .v, modifiers: [.command, .shift])),
        ("⌘⌥V",  HotKeySpec(key: .v, modifiers: [.command, .option])),
        ("⌃⇧Space", HotKeySpec(key: .space, modifiers: [.control, .shift]))
    ]

    var body: some View {
        Form {
            Section("Toggle myclip") {
                Text("Current: \(model.current.description)")
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.secondary)

                HStack {
                    ForEach(presets, id: \.label) { preset in
                        Button(preset.label) { model.set(preset.spec) }
                            .buttonStyle(.bordered)
                    }
                }

                HStack {
                    TextField("Custom (e.g. command+shift+c)", text: $model.draft)
                        .textFieldStyle(.roundedBorder)
                    Button("Apply") { model.applyDraft() }
                        .disabled(HotKeySpec.parse(model.draft) == nil)
                }
                Text("Modifiers: command, shift, option, control · plus one letter / number / space.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .frame(width: 420)
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
