import SwiftUI
import Combine

/// The features the island can show, one per tab.
enum IslandTab: String, CaseIterable, Identifiable {
    case calendar
    case weather
    case music
    case files

    var id: String { rawValue }

    /// SF Symbol shown in the tab bar.
    var icon: String {
        switch self {
        case .calendar: return "calendar"
        case .weather: return "cloud.sun.fill"
        case .music: return "music.note"
        case .files: return "tray.full"
        }
    }

    var title: String {
        switch self {
        case .calendar: return "Calendar"
        case .weather: return "Weather"
        case .music: return "Music"
        case .files: return "Files"
        }
    }

    /// Open height for this tab, tuned to hug its content so the island doesn't
    /// leave empty space below. A few px of slack avoids clipping; tighten here
    /// if the layout changes. Width stays fixed across tabs.
    var expandedHeight: CGFloat {
        switch self {
        case .calendar: return 324
        case .weather: return 280
        case .music: return 228
        case .files: return 300
        }
    }
}

/// Shared, persistent state for the island. It's created once and handed to the
/// SwiftUI root, so tab selection and feature data survive the collapse/expand
/// cycle instead of resetting every time the panel closes.
final class IslandModel: ObservableObject {
    @Published var isExpanded = false
    @Published var selectedTab: IslandTab = .calendar

    /// When true, the island stays open regardless of hover — e.g. while the
    /// user is typing a city name. The controller checks this before collapsing.
    @Published var isPinned = false

    /// Per-feature state that must outlive the collapse/expand cycle.
    let weather = WeatherModel()
    let music = MusicModel()
    let shelf = ShelfModel()

    private var cancellables = Set<AnyCancellable>()

    init() {
        // weather/music are separate observable objects; surface their changes
        // here so the island's tint (derived from them) refreshes too.
        for child in [weather.objectWillChange, music.objectWillChange] {
            child.sink { [weak self] _ in self?.objectWillChange.send() }
                .store(in: &cancellables)
        }

        // Keep the selection valid as tabs are shown/hidden in Settings: if the
        // current tab gets hidden, fall back to the first visible one. (Fires
        // immediately with the current set, so it also fixes the launch state.)
        AppSettings.shared.$hiddenTabs
            .sink { [weak self] hidden in
                guard let self else { return }
                let visible = IslandTab.allCases.filter { !hidden.contains($0) }
                if !visible.contains(self.selectedTab), let first = visible.first {
                    self.selectedTab = first
                }
            }
            .store(in: &cancellables)

        // Single source of truth for the pin: keep the island open while the
        // Files tab is showing (a stable drop target) or while editing a city.
        // Both inputs are observed so neither view has to write `isPinned` (which
        // raced on tab switches). The publishers deliver the *new* value, so pass
        // it in rather than reading the not-yet-updated stored property.
        $selectedTab
            .sink { [weak self] tab in self?.refreshPin(tab: tab) }
            .store(in: &cancellables)
        weather.$isEditing
            .sink { [weak self] editing in self?.refreshPin(editing: editing) }
            .store(in: &cancellables)
    }

    private func refreshPin(tab: IslandTab? = nil, editing: Bool? = nil) {
        let t = tab ?? selectedTab
        let e = editing ?? weather.isEditing
        isPinned = (t == .files) || (t == .weather && e)
    }

    /// Height of the physical notch strip; content is kept below it.
    var topInset: CGFloat = 32

    /// Inner island dimensions. The window itself stays at the expanded size;
    /// SwiftUI animates the black shape between collapsed and expanded. The
    /// expanded *width* is fixed; the *height* is per-tab (see below).
    var collapsedSize = CGSize(width: 200, height: 32)
    var expandedSize = CGSize(width: 380, height: 380)

    /// Full panel height (island + transparent margins). Used to map the tint
    /// gradient — which fills the whole panel — onto the island's own height.
    var windowHeight: CGFloat = 430

    /// The open height for whichever tab is selected. Driving the shape from
    /// this makes the island resize (with a spring) as you switch tabs.
    var currentExpandedHeight: CGFloat { selectedTab.expandedHeight }

    /// Bottom color of the island's gradient for the current tab; nil keeps it
    /// pure black (calendar, or when no data/artwork is available).
    var currentTint: Color? {
        switch selectedTab {
        case .calendar: return nil
        case .weather: return weather.tint
        case .music: return music.tint
        case .files: return nil
        }
    }
}
