import SwiftUI

/// The feature switcher shown at the top of the expanded island.
struct TabBar: View {
    @Binding var selection: IslandTab

    var body: some View {
        HStack(spacing: 6) {
            ForEach(IslandTab.allCases) { tab in
                tabButton(tab)
            }
        }
    }

    private func tabButton(_ tab: IslandTab) -> some View {
        let isSelected = tab == selection
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) { selection = tab }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: tab.icon)
                    .font(.system(size: 11, weight: .semibold))
                Text(tab.title)
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundStyle(isSelected ? Color.white : Color.white.opacity(0.5))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Capsule().fill(isSelected ? Color.white.opacity(0.16) : Color.clear))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
