import SwiftUI

/// State for the Music feature. It only starts querying Music once the user has
/// opened the tab (`activate()`), so the Automation permission prompt appears in
/// context rather than out of nowhere. Live updates come from the
/// `com.apple.Music.playerInfo` distributed notification — no polling.
final class MusicModel: ObservableObject {
    @Published var snapshot: MusicSnapshot = .notRunning

    private let controller = MusicController()
    private var active = false

    init() {
        observe()
    }

    /// Called when the Music tab first appears.
    func activate() {
        active = true
        refresh()
    }

    func refresh() {
        controller.snapshot { [weak self] snap in
            self?.snapshot = snap
        }
    }

    func playPause() { send("playpause") }
    func next() { send("next track") }
    func previous() { send("previous track") }

    // MARK: - Private

    private func send(_ command: String) {
        controller.command(command)
        // playerInfo usually fires, but refresh shortly after as a fallback.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.refresh()
        }
    }

    private func observe() {
        DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("com.apple.Music.playerInfo"),
            object: nil, queue: .main
        ) { [weak self] _ in
            guard let self, self.active else { return }
            self.refresh()
        }

        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didLaunchApplicationNotification,
                     NSWorkspace.didTerminateApplicationNotification] {
            center.addObserver(forName: name, object: nil, queue: .main) { [weak self] note in
                guard let self, self.active else { return }
                let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
                if app?.bundleIdentifier == "com.apple.Music" { self.refresh() }
            }
        }
    }
}
