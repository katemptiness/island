import SwiftUI
import Combine

/// User-configurable settings, persisted to `UserDefaults`. A single shared
/// instance so the island, the weather model, and the Settings window all read
/// and write the same state — settings are inherently app-global, so this is
/// simpler than threading one object through the whole model tree.
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    /// How stale weather may get before re-opening the tab refetches (minutes).
    /// There's no background polling — weather is only visible while the tab is
    /// open — so this is a staleness threshold, not a timer.
    @Published var weatherRefreshMinutes: Int {
        didSet { defaults.set(weatherRefreshMinutes, forKey: Keys.weatherRefreshMinutes) }
    }

    /// Which feature tabs are shown. Never empty (see `setTab`).
    @Published private(set) var enabledTabs: Set<IslandTab> {
        didSet { defaults.set(enabledTabs.map(\.rawValue), forKey: Keys.enabledTabs) }
    }

    /// Whether the breathing now-playing glow shows around the notch.
    @Published var musicGlowEnabled: Bool {
        didSet { defaults.set(musicGlowEnabled, forKey: Keys.musicGlowEnabled) }
    }

    /// Preset refresh intervals offered in the UI (minutes).
    static let refreshOptions = [5, 10, 15, 30, 60]

    /// The enabled tabs in their canonical order.
    var visibleTabs: [IslandTab] { IslandTab.allCases.filter { enabledTabs.contains($0) } }

    func isTabEnabled(_ tab: IslandTab) -> Bool { enabledTabs.contains(tab) }

    /// Toggle a tab, refusing to hide the last remaining one (an empty island
    /// would be useless).
    func setTab(_ tab: IslandTab, enabled: Bool) {
        var next = enabledTabs
        if enabled { next.insert(tab) } else { next.remove(tab) }
        guard !next.isEmpty else { return }
        enabledTabs = next
    }

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let weatherRefreshMinutes = "island.settings.weatherRefreshMinutes"
        static let enabledTabs = "island.settings.enabledTabs"
        static let musicGlowEnabled = "island.settings.musicGlowEnabled"
    }

    private init() {
        let d = UserDefaults.standard
        weatherRefreshMinutes = (d.object(forKey: Keys.weatherRefreshMinutes) as? Int) ?? 10
        if let raw = d.array(forKey: Keys.enabledTabs) as? [String] {
            let parsed = Set(raw.compactMap(IslandTab.init(rawValue:)))
            enabledTabs = parsed.isEmpty ? Set(IslandTab.allCases) : parsed
        } else {
            enabledTabs = Set(IslandTab.allCases)
        }
        musicGlowEnabled = (d.object(forKey: Keys.musicGlowEnabled) as? Bool) ?? true
    }
}
