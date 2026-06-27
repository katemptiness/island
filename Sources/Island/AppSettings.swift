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

    /// Which feature tabs the user has hidden. Stored as the *hidden* set (not
    /// the enabled one) so tabs added in future versions show by default instead
    /// of being absent from an older saved list.
    @Published private(set) var hiddenTabs: Set<IslandTab> {
        didSet { defaults.set(hiddenTabs.map(\.rawValue), forKey: Keys.hiddenTabs) }
    }

    /// Whether the breathing now-playing glow shows around the notch.
    @Published var musicGlowEnabled: Bool {
        didSet { defaults.set(musicGlowEnabled, forKey: Keys.musicGlowEnabled) }
    }

    /// Preset refresh intervals offered in the UI (minutes).
    static let refreshOptions = [5, 10, 15, 30, 60]

    /// The visible tabs in their canonical order.
    var visibleTabs: [IslandTab] { IslandTab.allCases.filter { !hiddenTabs.contains($0) } }

    func isTabEnabled(_ tab: IslandTab) -> Bool { !hiddenTabs.contains(tab) }

    /// Toggle a tab, refusing to hide the last remaining one (an empty island
    /// would be useless).
    func setTab(_ tab: IslandTab, enabled: Bool) {
        var next = hiddenTabs
        if enabled { next.remove(tab) } else { next.insert(tab) }
        guard next.count < IslandTab.allCases.count else { return } // keep ≥1 visible
        hiddenTabs = next
    }

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let weatherRefreshMinutes = "island.settings.weatherRefreshMinutes"
        static let hiddenTabs = "island.settings.hiddenTabs"
        static let musicGlowEnabled = "island.settings.musicGlowEnabled"
    }

    private init() {
        let d = UserDefaults.standard
        weatherRefreshMinutes = (d.object(forKey: Keys.weatherRefreshMinutes) as? Int) ?? 10
        if let raw = d.array(forKey: Keys.hiddenTabs) as? [String] {
            hiddenTabs = Set(raw.compactMap(IslandTab.init(rawValue:)))
        } else {
            hiddenTabs = []
        }
        musicGlowEnabled = (d.object(forKey: Keys.musicGlowEnabled) as? Bool) ?? true
    }
}
