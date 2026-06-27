import AppKit

struct MusicNowPlaying {
    let title: String
    let artist: String
    let album: String
    let isPlaying: Bool
    let position: Double      // seconds into the track at capture time
    let duration: Double      // track length in seconds
    let capturedAt: Date      // when position was sampled (for local extrapolation)
}

enum MusicSnapshot {
    case notRunning
    case noPermission
    case stopped
    case playing(MusicNowPlaying)
}

/// Talks to Apple Music via Apple Events (AppleScript). Reading state and sending
/// commands both require the one-time "control Music" (Automation) permission.
/// We never launch Music ourselves — if it isn't running we just report that.
final class MusicController {
    private let bundleID = "com.apple.Music"
    private let queue = DispatchQueue(label: "island.music.applescript")

    var isRunning: Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).isEmpty
    }

    func snapshot(_ completion: @escaping (MusicSnapshot) -> Void) {
        guard isRunning else { completion(.notRunning); return }
        queue.async {
            let snap = self.readSnapshot()
            DispatchQueue.main.async { completion(snap) }
        }
    }

    /// `playpause`, `next track`, `previous track`.
    func command(_ command: String) {
        guard isRunning else { return }
        queue.async {
            let source = "tell application \"Music\" to \(command)"
            var error: NSDictionary?
            NSAppleScript(source: source)?.executeAndReturnError(&error)
            if let error { elog("music command '\(command)' error: \(error)") }
        }
    }

    /// Current track artwork, if any. Fiddly (raw image bytes over Apple Events),
    /// so it fails soft to nil.
    func artwork(_ completion: @escaping (NSImage?) -> Void) {
        guard isRunning else { completion(nil); return }
        queue.async {
            let image = self.readArtwork()
            DispatchQueue.main.async { completion(image) }
        }
    }

    private func readArtwork() -> NSImage? {
        let source = """
        tell application "Music"
            if player state is stopped then return missing value
            try
                return data of artwork 1 of current track
            on error
                return missing value
            end try
        end tell
        """
        var error: NSDictionary?
        guard let result = NSAppleScript(source: source)?.executeAndReturnError(&error),
              error == nil else { return nil }
        return NSImage(data: result.data) // empty data (missing value) → nil
    }

    // MARK: - Private

    private func readSnapshot() -> MusicSnapshot {
        let source = """
        tell application "Music"
            set ps to player state as text
            if ps is "stopped" then return "stopped"
            set t to ""
            set a to ""
            set al to ""
            set pos to 0
            set dur to 0
            try
                set t to name of current track
                set a to artist of current track
                set al to album of current track
                set dur to (duration of current track) as integer
                set pos to (player position) as integer
            end try
            return ps & "\\n" & t & "\\n" & a & "\\n" & al & "\\n" & (pos as text) & "\\n" & (dur as text)
        end tell
        """
        var error: NSDictionary?
        guard let result = NSAppleScript(source: source)?.executeAndReturnError(&error) else {
            return .notRunning
        }
        if let error {
            let code = (error["NSAppleScriptErrorNumber"] as? Int) ?? 0
            elog("music snapshot error \(code): \(error)")
            return code == -1743 ? .noPermission : .notRunning // -1743 = not authorized
        }

        let text = result.stringValue ?? ""
        if text == "stopped" { return .stopped }

        let parts = text.components(separatedBy: "\n")
        let state = parts.first ?? ""
        func part(_ i: Int) -> String { parts.count > i ? parts[i] : "" }
        return .playing(MusicNowPlaying(
            title: part(1),
            artist: part(2),
            album: part(3),
            isPlaying: state == "playing",
            position: Double(part(4)) ?? 0,
            duration: Double(part(5)) ?? 0,
            capturedAt: Date()
        ))
    }
}
