import AppKit

/// A tiny, transparent, always-present window sitting right over the notch.
///
/// Its only job is to notice a *file* being dragged to the notch and tell the
/// controller to open the Files tab. The collapsed island itself is click-through
/// (`ignoresMouseEvents`), so it can't catch drags — hence this dedicated
/// catcher, which must receive mouse events but is kept to the notch gap so it
/// never swallows clicks meant for the menu bar (which lives to either side).
final class NotchDropCatcher {
    /// A file drag entered the notch zone.
    var onEnter: (() -> Void)?
    /// Files were dropped directly on the notch.
    var onDrop: (([URL]) -> Void)?

    private let panel: NSPanel
    private let view: DropView

    init(frame: CGRect) {
        view = DropView()
        panel = NSPanel(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .statusBar
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.isMovable = false
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.ignoresMouseEvents = false // must receive drags
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        panel.contentView = view

        view.onEnter = { [weak self] in self?.onEnter?() }
        view.onDrop = { [weak self] urls in self?.onDrop?(urls) }
    }

    func show() { panel.orderFrontRegardless() }

    func setFrame(_ frame: CGRect) { panel.setFrame(frame, display: true) }
}

/// The view that actually registers for and handles file drags.
private final class DropView: NSView {
    var onEnter: (() -> Void)?
    var onDrop: (([URL]) -> Void)?

    private let fileOptions: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: true]

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes([.fileURL])
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    private func hasFiles(_ sender: NSDraggingInfo) -> Bool {
        sender.draggingPasteboard.canReadObject(forClasses: [NSURL.self], options: fileOptions)
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard hasFiles(sender) else { return [] }
        onEnter?()
        return .copy
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        hasFiles(sender) ? .copy : []
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let urls = sender.draggingPasteboard.readObjects(
            forClasses: [NSURL.self], options: fileOptions) as? [URL], !urls.isEmpty else { return false }
        onDrop?(urls)
        return true
    }
}
