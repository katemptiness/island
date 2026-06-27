import AppKit

/// App-wide constants.
enum AppInfo {
    static let version = "0.2"
}

// Entry point. We run as an "accessory" app: no Dock icon, lives in the
// background like a menu-bar agent. (Mirrored by LSUIElement in Info.plist.)
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
