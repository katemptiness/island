import SwiftUI
import AppKit

/// One file sitting on the shelf. We only reference the original on disk (no
/// copy), so the item is just its URL plus a cached type icon.
struct ShelfItem: Identifiable {
    let id = UUID()
    let url: URL
    let icon: NSImage

    var name: String { url.lastPathComponent }
    /// Whether the referenced file still exists (it may be moved/deleted while
    /// it sits on the shelf).
    var exists: Bool { FileManager.default.fileExists(atPath: url.path) }
}

/// The drag & drop file shelf: a temporary, in-memory staging area for files.
/// Contents are session-only (not persisted) and reference the originals rather
/// than copying them.
final class ShelfModel: ObservableObject {
    @Published private(set) var items: [ShelfItem] = []

    /// Add files, skipping any already on the shelf (compared by resolved path).
    func add(_ urls: [URL]) {
        let present = Set(items.map { $0.url.standardizedFileURL })
        for url in urls {
            let std = url.standardizedFileURL
            guard !present.contains(std) else { continue }
            let icon = NSWorkspace.shared.icon(forFile: std.path)
            items.append(ShelfItem(url: std, icon: icon))
        }
    }

    func remove(_ item: ShelfItem) {
        items.removeAll { $0.id == item.id }
    }

    func clear() {
        items.removeAll()
    }
}
