import SwiftUI

/// The features the island can show, one per tab.
enum IslandTab: String, CaseIterable, Identifiable {
    case calendar
    case weather
    case music

    var id: String { rawValue }

    /// SF Symbol shown in the tab bar.
    var icon: String {
        switch self {
        case .calendar: return "calendar"
        case .weather: return "cloud.sun.fill"
        case .music: return "music.note"
        }
    }

    var title: String {
        switch self {
        case .calendar: return "Calendar"
        case .weather: return "Weather"
        case .music: return "Music"
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

    /// Height of the physical notch strip; content is kept below it.
    var topInset: CGFloat = 32

    /// Inner island dimensions. The window itself stays at the expanded size;
    /// SwiftUI animates the black shape between collapsed and expanded. The
    /// expanded *width* is fixed; the *height* is per-tab (see below).
    var collapsedSize = CGSize(width: 200, height: 32)
    var expandedSize = CGSize(width: 380, height: 380)

    /// The open height for whichever tab is selected. Driving the shape from
    /// this makes the island resize (with a spring) as you switch tabs.
    var currentExpandedHeight: CGFloat { selectedTab.expandedHeight }
}
