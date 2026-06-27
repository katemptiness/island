import SwiftUI

/// The island's single source of visual truth. Every view pulls its fonts,
/// colors, paddings and radii from here so the three tabs stay consistent and a
/// future restyle is a one-file change. Truly local micro-spacing (e.g. the gap
/// between an icon and its label inside one control) stays inline on purpose.
enum Theme {
    /// Spacing scale. `edge` is the container inset shared by every tab.
    enum Spacing {
        /// Container inset: horizontal padding and bottom padding of each tab.
        static let edge: CGFloat = 16
        /// Gap between major blocks within a tab (e.g. header → content).
        static let section: CGFloat = 12
        /// Tighter grouping inside a block.
        static let tight: CGFloat = 8
        /// Hairline gap between closely-related lines.
        static let element: CGFloat = 4
        /// Gap between the tab bar and the content below it.
        static let afterTabs: CGFloat = 10
        /// Breathing room between the notch and the tab bar.
        static let belowNotch: CGFloat = 6
    }

    /// Corner radii.
    enum Radius {
        /// Text fields and inline inputs.
        static let field: CGFloat = 8
        /// Tiles such as album artwork.
        static let tile: CGFloat = 10
    }

    /// Foreground (text/icon) colors, by emphasis. All are white at decreasing
    /// opacity so hierarchy reads on the black island.
    enum Text {
        static let primary = Color.white
        static let secondary = Color.white.opacity(0.7)
        static let tertiary = Color.white.opacity(0.5)
        static let faint = Color.white.opacity(0.4)
    }

    /// Background fills painted over the black island.
    enum Fill {
        /// Subtle surface: input backgrounds, artwork placeholder.
        static let subtle = Color.white.opacity(0.10)
        /// The selected-tab capsule.
        static let selected = Color.white.opacity(0.16)
        /// Unfilled portion of a progress track.
        static let track = Color.white.opacity(0.15)
        /// Filled portion of a progress track.
        static let bar = Color.white.opacity(0.85)
    }

    /// Accent used for tappable text (e.g. "Retry").
    static let accent = Color.blue
    /// Warnings and permission prompts.
    static let warn = Color.orange
    /// Weekend day numbers in the calendar.
    static let weekend = Color.red.opacity(0.8)

    /// Type scale. Names map to roles, not pixel sizes, so call sites read as
    /// intent. `emphasized` variants add weight at the same size.
    enum Font {
        /// Large readout, e.g. the current temperature.
        static let display = SwiftUI.Font.system(size: 30, weight: .semibold)
        /// A tab's primary heading (month, city, track title).
        static let heading = SwiftUI.Font.system(size: 14, weight: .semibold)
        /// Default body text.
        static let body = SwiftUI.Font.system(size: 13)
        /// 12pt subheads (search results, list items).
        static let subhead = SwiftUI.Font.system(size: 12)
        static let subheadEmphasized = SwiftUI.Font.system(size: 12, weight: .medium)
        /// 11pt supporting text (conditions, artist, tab labels).
        static let footnote = SwiftUI.Font.system(size: 11)
        static let footnoteEmphasized = SwiftUI.Font.system(size: 11, weight: .medium)
        /// 10pt captions.
        static let caption = SwiftUI.Font.system(size: 10)
        static let captionEmphasized = SwiftUI.Font.system(size: 10, weight: .medium)
        /// 9pt fine print (timestamps, sub-subtitles).
        static let micro = SwiftUI.Font.system(size: 9)
    }
}
