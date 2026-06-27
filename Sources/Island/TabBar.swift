import SwiftUI

/// The feature switcher shown at the top of the expanded island.
///
/// There's a single highlight capsule; `matchedGeometryEffect` makes it glide
/// from the old tab to the new one (rather than cross-fading in place) whenever
/// the selection changes, echoing the island's own spring morph.
struct TabBar: View {
    @Binding var selection: IslandTab
    @Namespace private var highlight

    var body: some View {
        HStack(spacing: Theme.Spacing.element) {
            ForEach(IslandTab.allCases) { tab in
                tabButton(tab)
            }
        }
    }

    private func tabButton(_ tab: IslandTab) -> some View {
        let isSelected = tab == selection
        return Button {
            withAnimation(.spring(duration: 0.32, bounce: 0.28)) { selection = tab }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: tab.icon)
                    .font(Theme.Font.footnoteEmphasized)
                Text(tab.title)
                    .font(Theme.Font.footnoteEmphasized)
            }
            .foregroundStyle(isSelected ? Theme.Text.primary : Theme.Text.tertiary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background {
                if isSelected {
                    Capsule()
                        .fill(Theme.Fill.selected)
                        .matchedGeometryEffect(id: "tabHighlight", in: highlight)
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
