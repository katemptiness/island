import SwiftUI
import AppKit

/// Files tab: the drag & drop shelf. Drop files onto it to stash them; drag a
/// row out to drop the file elsewhere (it stays on the shelf until you remove
/// it). The island is pinned open while this tab is showing (see IslandModel),
/// so it's a stable drop target even mid-drag, when hover-to-open won't fire.
struct FilesView: View {
    @ObservedObject var model: ShelfModel
    @State private var isTargeted = false

    /// Fixed height for the shelf area; the tab's height is tuned around it.
    private let shelfHeight: CGFloat = 160

    var body: some View {
        VStack(spacing: Theme.Spacing.tight) {
            header
            Group {
                if model.items.isEmpty {
                    dropZone
                } else {
                    list
                }
            }
            .frame(height: shelfHeight)
        }
        .dropDestination(for: URL.self) { urls, _ in
            model.add(urls)
            return true
        } isTargeted: { isTargeted = $0 }
    }

    private var header: some View {
        HStack {
            Text(countText)
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Text.tertiary)
            Spacer()
            if !model.items.isEmpty {
                Button("Clear") { model.clear() }
                    .buttonStyle(.plain)
                    .font(Theme.Font.captionEmphasized)
                    .foregroundStyle(Theme.accent)
            }
        }
    }

    private var countText: String {
        let n = model.items.count
        return n == 0 ? "Shelf" : "\(n) item\(n == 1 ? "" : "s")"
    }

    /// Empty state: a dashed drop target inviting files in.
    private var dropZone: some View {
        VStack(spacing: Theme.Spacing.tight) {
            Image(systemName: "tray.and.arrow.down")
                .font(.system(size: 28))
                .foregroundStyle(Theme.Text.tertiary)
            Text("Drag files here")
                .font(Theme.Font.subhead)
                .foregroundStyle(Theme.Text.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.tile)
                .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [5]))
                .foregroundStyle(isTargeted ? Theme.accent : Theme.Text.faint)
        )
    }

    private var list: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.element) {
                ForEach(model.items) { item in
                    row(item)
                }
            }
        }
        .overlay {
            if isTargeted {
                RoundedRectangle(cornerRadius: Theme.Radius.tile)
                    .strokeBorder(Theme.accent, lineWidth: 1.5)
            }
        }
    }

    private func row(_ item: ShelfItem) -> some View {
        HStack(spacing: Theme.Spacing.tight) {
            Image(nsImage: item.icon)
                .resizable()
                .frame(width: 24, height: 24)
            Text(item.name)
                .font(Theme.Font.subhead)
                .foregroundStyle(item.exists ? Theme.Text.primary : Theme.Text.faint)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: Theme.Spacing.tight)
            Button { model.remove(item) } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(Theme.Text.faint)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 5)
        .padding(.horizontal, Theme.Spacing.tight)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.field).fill(Theme.Fill.subtle))
        .contentShape(Rectangle())
        // Drag the actual file out to Finder, Mail, etc. The shelf keeps it.
        .onDrag { dragProvider(for: item) }
    }

    private func dragProvider(for item: ShelfItem) -> NSItemProvider {
        let provider = NSItemProvider(contentsOf: item.url) ?? NSItemProvider()
        // Preserve the original filename on drop. Without this the receiver
        // falls back to the type's generic name ("PDF document.pdf"). The system
        // appends the extension itself, so we hand it the base name only.
        provider.suggestedName = item.url.deletingPathExtension().lastPathComponent
        return provider
    }
}
