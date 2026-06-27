import SwiftUI

/// The contents of the Settings window: weather refresh interval, which tabs are
/// shown, and the now-playing glow toggle.
struct SettingsView: View {
    @ObservedObject var settings = AppSettings.shared
    @State private var showAbout = false

    var body: some View {
        Form {
            Section("Weather") {
                Picker("Refresh interval", selection: $settings.weatherRefreshMinutes) {
                    ForEach(AppSettings.refreshOptions, id: \.self) { minutes in
                        Text(intervalLabel(minutes)).tag(minutes)
                    }
                }
                Text("Weather refreshes when you open the tab, if the data is older than this.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Tabs") {
                ForEach(IslandTab.allCases) { tab in
                    Toggle(tab.title, isOn: binding(for: tab))
                        .disabled(isLastEnabled(tab))
                }
            }

            Section("Music") {
                Toggle("Now-playing glow", isOn: $settings.musicGlowEnabled)
                Text("A soft glow around the notch while music is playing.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section {
                Button("About Island") { showAbout = true }
                    .popover(isPresented: $showAbout, arrowEdge: .bottom) { aboutCard }
            }
        }
        .formStyle(.grouped)
        .frame(width: 360)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var aboutCard: some View {
        VStack(spacing: 8) {
            Image(systemName: "rectangle.tophalf.inset.filled")
                .font(.system(size: 30))
                .foregroundStyle(.secondary)
            Text("Island")
                .font(.headline)
            Text("Version \(AppInfo.version)")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("A Dynamic Island for the Mac notch — hover to open a hub for your calendar, weather, and music, plus a drag-and-drop file shelf.")
                .font(.callout)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Divider()
            Text("Made by katemptiness & Claude")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(18)
        .frame(width: 260)
    }

    private func intervalLabel(_ minutes: Int) -> String {
        minutes < 60 ? "\(minutes) min" : "1 hour"
    }

    private func binding(for tab: IslandTab) -> Binding<Bool> {
        Binding(
            get: { settings.isTabEnabled(tab) },
            set: { settings.setTab(tab, enabled: $0) }
        )
    }

    /// The single remaining visible tab can't be turned off.
    private func isLastEnabled(_ tab: IslandTab) -> Bool {
        settings.isTabEnabled(tab) && settings.visibleTabs.count == 1
    }
}
