import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var notch: NotchController?
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()

        notch = NotchController()
        notch?.show()

        // Re-place the island if displays change (resolution, plugging a
        // monitor, waking from sleep, etc.).
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screensChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    @objc private func screensChanged() {
        notch?.reposition()
    }

    // MARK: - Menu-bar control

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(
            systemSymbolName: "rectangle.tophalf.inset.filled",
            accessibilityDescription: "Island"
        )

        let menu = NSMenu()

        let title = NSMenuItem(title: "Island v0.1", action: nil, keyEquivalent: "")
        title.isEnabled = false
        menu.addItem(title)

        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        item.menu = menu
        statusItem = item
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}
