import Foundation
import ServiceManagement

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
