import AppKit

struct MusicNowPlaying {
    let title: String
    let artist: String
    let album: String
    let isPlaying: Bool
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

    // MARK: - Private

    private func readSnapshot() -> MusicSnapshot {
        let source = """
        tell application "Music"
            set ps to player state as text
            if ps is "stopped" then return "stopped"
            set t to ""
            set a to ""
            set al to ""
            try
                set t to name of current track
                set a to artist of current track
                set al to album of current track
            end try
            return ps & "\\n" & t & "\\n" & a & "\\n" & al
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
        return .playing(MusicNowPlaying(
            title: parts.count > 1 ? parts[1] : "",
            artist: parts.count > 2 ? parts[2] : "",
            album: parts.count > 3 ? parts[3] : "",
            isPlaying: state == "playing"
        ))
    }
}
