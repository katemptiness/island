import AppKit
import SwiftUI
import Combine

/// Owns the panel and the shared `IslandModel`.
///
/// The panel is kept at the *expanded* size and transparent; opening/closing is a
/// pure SwiftUI spring on the inner shape (see `IslandRootView`), not a window
/// resize. While collapsed the panel ignores mouse events so clicks pass through
/// to the menu bar / desktop; it grabs them again when expanded.
///
/// Hover is detected by watching the *global* mouse position against two fixed
/// zones — a small "open" zone on the notch and the large "stay-open" zone.
/// Because the open zone is entirely inside the stay-open zone, the two states
/// can't oscillate. While `model.isPinned` is set, hover is ignored entirely.
final class NotchController {
    private var panel: NotchPanel?
    private var geometry: NotchGeometry?
    private let model = IslandModel()

    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var clickMonitor: Any?
    private var cancellables = Set<AnyCancellable>()

    func show() {
        guard let geo = NotchGeometry.current() else {
            elog("could not find a screen — island not shown")
            return
        }
        geometry = geo
        model.topInset = geo.notchRect.height
        model.collapsedSize = geo.collapsedSize
        model.expandedSize = geo.expandedSize

        elog("screen '\(geo.screen.localizedName)'")
        elog("window=\(geo.windowFrame) expanded=\(geo.expandedFrame) trigger=\(geo.hoverTriggerRect)")

        let panel = NotchPanel(contentRect: geo.windowFrame)

        let container = NSView()
        let host = NSHostingView(rootView: IslandRootView(model: model))
        host.autoresizingMask = [.width, .height]
        container.addSubview(host)
        panel.contentView = container
        host.frame = container.bounds

        self.panel = panel

        panel.setFrame(geo.windowFrame, display: true)
        panel.ignoresMouseEvents = true // collapsed: let clicks through
        panel.orderFrontRegardless()

        startMouseMonitoring()
        observePin()
    }

    /// React to the pinned flag: when pinned (e.g. typing a city) make the panel
    /// key so the text field accepts input; when unpinned, re-check hover so the
    /// island can collapse if the pointer has already left.
    private func observePin() {
        model.$isPinned
            .removeDuplicates()
            .sink { [weak self] pinned in
                guard let self, let panel = self.panel else { return }
                if pinned {
                    panel.makeKeyAndOrderFront(nil)
                } else {
                    self.evaluateHover()
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Hover detection

    private func startMouseMonitoring() {
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved]) { [weak self] _ in
            self?.evaluateHover()
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved]) { [weak self] event in
            self?.evaluateHover()
            return event
        }
        // A click outside our panel while pinned cancels city editing. Global
        // monitors only fire for events delivered to *other* apps, so any hit
        // here is by definition outside the island.
        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            guard let self, self.model.isPinned else { return }
            self.model.weather.cancelEditing()
            self.model.isPinned = false
        }
    }

    private func evaluateHover() {
        guard let geo = geometry, !model.isPinned else { return }
        let p = NSEvent.mouseLocation
        if model.isExpanded {
            if !geo.expandedFrame.containsInclusive(p) { collapse() }
        } else {
            if geo.hoverTriggerRect.containsInclusive(p) { expand() }
        }
    }

    // MARK: - State transitions

    private let openAnimation = Animation.spring(duration: 0.42, bounce: 0.3)

    func expand() {
        guard !model.isExpanded else { return }
        panel?.ignoresMouseEvents = false
        withAnimation(openAnimation) { model.isExpanded = true }
    }

    func collapse() {
        guard model.isExpanded else { return }
        panel?.ignoresMouseEvents = true
        withAnimation(openAnimation) { model.isExpanded = false }
    }

    func reposition() {
        guard let geo = NotchGeometry.current() else { return }
        geometry = geo
        model.topInset = geo.notchRect.height
        model.collapsedSize = geo.collapsedSize
        model.expandedSize = geo.expandedSize
        panel?.setFrame(geo.windowFrame, display: true)
    }
}
