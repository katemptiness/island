import SwiftUI

/// The features the island can show, one per tab.
enum IslandTab: String, CaseIterable, Identifiable {
    case calendar
    case weather

    var id: String { rawValue }

    /// SF Symbol shown in the tab bar.
    var icon: String {
        switch self {
        case .calendar: return "calendar"
        case .weather: return "cloud.sun.fill"
        }
    }

    var title: String {
        switch self {
        case .calendar: return "Calendar"
        case .weather: return "Weather"
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

    /// Height of the physical notch strip; content is kept below it.
    var topInset: CGFloat = 32
}
