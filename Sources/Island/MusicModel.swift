import SwiftUI

/// State for the Music feature. It only starts querying Music once the user has
/// opened the tab (`activate()`), so the Automation permission prompt appears in
/// context rather than out of nowhere. Live updates come from the
/// `com.apple.Music.playerInfo` distributed notification — no polling.
final class MusicModel: ObservableObject {
    @Published var snapshot: MusicSnapshot = .notRunning
    @Published var artwork: NSImage?
    /// Background tint derived from the current artwork (nil when none).
    @Published var tint: Color?

    /// True only while a track is actually playing (not paused/stopped). Drives
    /// the ambient now-playing glow around the notch.
    var isActivelyPlaying: Bool {
        if case .playing(let info) = snapshot { return info.isPlaying }
        return false
    }

    private let controller = MusicController()
    private var active = false
    private var artworkKey: String?

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
            guard let self else { return }
            self.snapshot = snap
            self.updateArtwork(for: snap)
        }
    }

    /// Fetch artwork only when the track actually changes; clear it otherwise.
    private func updateArtwork(for snap: MusicSnapshot) {
        guard case .playing(let info) = snap else {
            artworkKey = nil
            artwork = nil
            withAnimation(.easeInOut(duration: 0.4)) { tint = nil }
            return
        }
        let key = info.title + "|" + info.artist
        guard key != artworkKey else { return }
        artworkKey = key
        controller.artwork { [weak self] image in
            guard let self, self.artworkKey == key else { return } // track still current
            self.artwork = image
            guard let image else {
                withAnimation(.easeInOut(duration: 0.4)) { self.tint = nil }
                return
            }
            // Derive the tint off the main thread; cheap, but keep the UI smooth.
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                let tint = IslandTint.artwork(image)
                DispatchQueue.main.async {
                    guard let self, self.artworkKey == key else { return }
                    withAnimation(.easeInOut(duration: 0.5)) { self.tint = tint }
                }
            }
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
