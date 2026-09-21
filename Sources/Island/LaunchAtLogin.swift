import ServiceManagement
import SwiftUI

/// Wraps `SMAppService.mainApp` so Settings can offer a "launch at login"
/// toggle. The system owns the truth here — the user can also flip the item in
/// System Settings, and macOS may park it in `.requiresApproval` — so every
/// change is followed by re-reading the status rather than trusting our own.
/// Like `AppSettings`, it is only ever touched from the main thread (menu
/// commands and the Settings window), so it needs no isolation of its own.
final class LaunchAtLogin: ObservableObject {
    static let shared = LaunchAtLogin()

    @Published private(set) var status: SMAppService.Status
    /// Set when the system refuses a change, so Settings can say why.
    @Published private(set) var lastError: String?

    private init() {
        status = SMAppService.mainApp.status
    }

    var isEnabled: Bool { status == .enabled }

    /// macOS knows about the login item but it is switched off in System
    /// Settings; the toggle cannot override that, only the user can.
    var needsApproval: Bool { status == .requiresApproval }

    /// A login item points at a fixed path, so registering the copy that lives
    /// in the build directory would quietly break the next time it is wiped.
    var isInstalled: Bool { Bundle.main.bundlePath.hasPrefix("/Applications/") }

    func refresh() {
        status = SMAppService.mainApp.status
    }

    func setEnabled(_ enabled: Bool) {
        lastError = nil
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            lastError = error.localizedDescription
            elog("login item \(enabled ? "register" : "unregister") failed: \(error)")
        }
        refresh()
    }

    func openLoginItemsSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
