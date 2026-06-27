import AppKit
import SwiftUI

/// Owns the Settings window — created lazily, reused, and brought to front.
/// The app is an accessory (no Dock icon), so we activate it when showing the
/// window so it can take keyboard focus and come to the foreground.
final class SettingsWindowController {
    private var window: NSWindow?

    func show() {
        if window == nil {
            let hosting = NSHostingController(rootView: SettingsView())
            let window = NSWindow(contentViewController: hosting)
            window.title = "Island Settings"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.center()
            self.window = window
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
