import SwiftUI

/// Music tab: now-playing info from Apple Music plus transport controls.
struct MusicView: View {
    @ObservedObject var model: MusicModel

    var body: some View {
        VStack(spacing: Theme.Spacing.section) {
            switch model.snapshot {
            case .notRunning:
                placeholder(icon: "music.note", text: "Music isn't running")
            case .stopped:
                placeholder(icon: "pause.circle", text: "Nothing playing")
            case .noPermission:
                permissionHint
            case .playing(let info):
                nowPlaying(info)
                if info.duration > 0 { progress(info) }
                controls(info)
            }
        }
        .onAppear { model.activate() }
    }

    // MARK: - States

    private func placeholder(icon: String, text: String) -> some View {
        VStack(spacing: Theme.Spacing.tight) {
            Image(systemName: icon)
                .font(.system(size: 30))
                .foregroundStyle(Theme.Text.tertiary)
            Text(text)
                .font(Theme.Font.subhead)
                .foregroundStyle(Theme.Text.tertiary)
        }
        .frame(maxWidth: .infinity, minHeight: 120)
    }

    private var permissionHint: some View {
        VStack(spacing: Theme.Spacing.tight) {
            Image(systemName: "lock.shield")
                .font(.system(size: 26))
                .foregroundStyle(Theme.warn)
            Text("Allow Island to control Music")
                .font(Theme.Font.subheadEmphasized)
                .foregroundStyle(Theme.Text.primary)
            Text("System Settings → Privacy & Security → Automation")
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Text.tertiary)
                .multilineTextAlignment(.center)
            Button("Retry") { model.refresh() }
                .buttonStyle(.plain)
                .font(Theme.Font.footnote)
                .foregroundStyle(Theme.accent)
        }
        .frame(maxWidth: .infinity, minHeight: 120)
    }

    private func nowPlaying(_ info: MusicNowPlaying) -> some View {
        HStack(spacing: Theme.Spacing.section) {
            artwork
            VStack(alignment: .leading, spacing: 3) {
                Text(info.title.isEmpty ? "—" : info.title)
                    .font(Theme.Font.heading)
                    .foregroundStyle(Theme.Text.primary)
                    .lineLimit(1)
                Text(info.artist)
                    .font(Theme.Font.footnote)
                    .foregroundStyle(Theme.Text.secondary)
                    .lineLimit(1)
            }
            Spacer()
        }
    }

    @ViewBuilder
    private var artwork: some View {
        Group {
            if let image = model.artwork {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Image(systemName: "music.note")
                    .font(.system(size: 24))
                    .foregroundStyle(Theme.Text.secondary)
            }
        }
        .frame(width: 54, height: 54)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.tile).fill(Theme.Fill.subtle))
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.tile))
    }

    private func progress(_ info: MusicNowPlaying) -> some View {
        // Redraw a couple of times a second; extrapolate position from the last
        // sample so the bar moves smoothly without polling AppleScript.
        TimelineView(.periodic(from: .now, by: 0.5)) { context in
            let elapsed = info.isPlaying ? max(0, context.date.timeIntervalSince(info.capturedAt)) : 0
            let current = min(info.position + elapsed, info.duration)
            let fraction = info.duration > 0 ? current / info.duration : 0
            VStack(spacing: 3) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Theme.Fill.track)
                        Capsule().fill(Theme.Fill.bar)
                            .frame(width: geo.size.width * fraction)
                    }
                }
                .frame(height: 3)
                HStack {
                    Text(timeString(current))
                    Spacer()
                    Text(timeString(info.duration))
                }
                .font(Theme.Font.micro)
                .foregroundStyle(Theme.Text.tertiary)
            }
        }
    }

    private func timeString(_ seconds: Double) -> String {
        let total = max(0, Int(seconds.rounded()))
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    private func controls(_ info: MusicNowPlaying) -> some View {
        HStack(spacing: 30) {
            controlButton("backward.fill") { model.previous() }
            controlButton(info.isPlaying ? "pause.fill" : "play.fill", size: 26) { model.playPause() }
            controlButton("forward.fill") { model.next() }
        }
        .frame(maxWidth: .infinity)
    }

    private func controlButton(_ symbol: String, size: CGFloat = 18,
                               action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size, weight: .medium))
                .foregroundStyle(Theme.Text.primary)
                .frame(width: 42, height: 36)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
