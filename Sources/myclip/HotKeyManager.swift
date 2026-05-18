import Foundation
import AppKit
import HotKey
import Carbon.HIToolbox

/// Persistable description of a global shortcut, encoded as a string like
/// `"command+shift+c"`. Stored under UserDefaults key `kHotkeyDefaultsKey`.
struct HotKeySpec: Equatable {
    var key: Key
    var modifiers: NSEvent.ModifierFlags

    static let `default` = HotKeySpec(key: .c, modifiers: [.command, .shift])

    var description: String {
        var parts: [String] = []
        if modifiers.contains(.control)  { parts.append("control")  }
        if modifiers.contains(.option)   { parts.append("option")   }
        if modifiers.contains(.shift)    { parts.append("shift")    }
        if modifiers.contains(.command)  { parts.append("command")  }
        parts.append(String(describing: key).lowercased())
        return parts.joined(separator: "+")
    }

    static func parse(_ s: String) -> HotKeySpec? {
        let tokens = s.lowercased()
            .split(whereSeparator: { $0 == "+" || $0 == " " })
            .map(String.init)
        var mods: NSEvent.ModifierFlags = []
        var key: Key?
        for t in tokens {
            switch t {
            case "cmd", "command", "⌘": mods.insert(.command)
            case "shift", "⇧":          mods.insert(.shift)
            case "opt", "option", "alt", "⌥": mods.insert(.option)
            case "ctrl", "control", "⌃":      mods.insert(.control)
            default:                     key = Key(string: t)
            }
        }
        guard let key, !mods.isEmpty else { return nil }
        return HotKeySpec(key: key, modifiers: mods)
    }
}

let kHotkeyDefaultsKey = "myclip.toggleHotkey"

@MainActor
final class HotKeyManager {
    private weak var panelController: PanelController?
    private var hotKey: HotKey?

    init(panelController: PanelController) {
        self.panelController = panelController
    }

    func register() {
        apply(currentSpec())
    }

    func update(_ spec: HotKeySpec) {
        UserDefaults.standard.set(spec.description, forKey: kHotkeyDefaultsKey)
        apply(spec)
    }

    func currentSpec() -> HotKeySpec {
        if let raw = UserDefaults.standard.string(forKey: kHotkeyDefaultsKey),
           let parsed = HotKeySpec.parse(raw) {
            return parsed
        }
        return .default
    }

    private func apply(_ spec: HotKeySpec) {
        hotKey = nil  // releases the prior registration
        let hk = HotKey(key: spec.key, modifiers: spec.modifiers)
        hk.keyDownHandler = { [weak self] in
            self?.panelController?.toggle()
        }
        hotKey = hk
    }
}
