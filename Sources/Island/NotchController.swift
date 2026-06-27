import AppKit
import SwiftUI
import Combine

/// Owns the panel and the shared `IslandModel`, and animates between the
/// collapsed and expanded states.
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

        elog("screen '\(geo.screen.localizedName)'")
        elog("collapsed=\(geo.collapsedFrame)")
        elog("expanded=\(geo.expandedFrame)")
        elog("trigger=\(geo.hoverTriggerRect)")

        let panel = NotchPanel(contentRect: geo.collapsedFrame)

        let container = NSView()
        let host = NSHostingView(rootView: IslandRootView(model: model))
        host.autoresizingMask = [.width, .height]
        container.addSubview(host)
        panel.contentView = container
        host.frame = container.bounds

        self.panel = panel

        panel.setFrame(geo.collapsedFrame, display: true)
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

    func expand() {
        guard let panel, let geo = geometry, !model.isExpanded else { return }
        withAnimation(.easeOut(duration: 0.28)) { model.isExpanded = true }
        animateFrame(panel, to: geo.expandedFrame)
    }

    func collapse() {
        guard let panel, let geo = geometry, model.isExpanded else { return }
        withAnimation(.easeIn(duration: 0.22)) { model.isExpanded = false }
        animateFrame(panel, to: geo.collapsedFrame)
    }

    func reposition() {
        guard let geo = NotchGeometry.current() else { return }
        geometry = geo
        model.topInset = geo.notchRect.height
        panel?.setFrame(model.isExpanded ? geo.expandedFrame : geo.collapsedFrame, display: true)
    }

    private func animateFrame(_ panel: NotchPanel, to frame: CGRect) {
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.28
            ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            panel.animator().setFrame(frame, display: true)
        }
    }
}
