import AppKit

/// A borderless, transparent, always-on-top panel that hosts the island.
/// It does NOT activate the app or steal focus from whatever you're doing.
final class NotchPanel: NSPanel {
    /// Return true to consume a horizontal tab gesture before SwiftUI's scroll
    /// views see it. All other events follow the normal window dispatch path.
    var onScroll: ((NSEvent) -> Bool)?

    init(contentRect: CGRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        isFloatingPanel = true
        level = .statusBar               // above the menu bar
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        isMovable = false
        hidesOnDeactivate = false
        isReleasedWhenClosed = false

        // Show on every Space and float over full-screen apps.
        collectionBehavior = [
            .canJoinAllSpaces,
            .stationary,
            .fullScreenAuxiliary,
            .ignoresCycle
        ]
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func sendEvent(_ event: NSEvent) {
        if event.type == .scrollWheel, onScroll?(event) == true { return }
        super.sendEvent(event)
    }
}
