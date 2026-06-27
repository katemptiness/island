import AppKit
import SwiftUI

/// Owns the panel, hosts the SwiftUI content, and animates between the collapsed
/// (resting) and expanded states.
///
/// Hover is detected by watching the *global* mouse position against two fixed
/// zones — a small "open" zone on the notch and the large "stay-open" zone —
/// rather than by tracking areas on the resizing window. Because the open zone
/// is entirely inside the stay-open zone, the two states can't oscillate.
final class NotchController {
    private var panel: NotchPanel?
    private var hosting: NSHostingView<AnyView>?
    private var geometry: NotchGeometry?
    private var isExpanded = false

    private var globalMonitor: Any?
    private var localMonitor: Any?

    func show() {
        guard let geo = NotchGeometry.current() else {
            elog("не удалось определить экран — island не показан")
            return
        }
        geometry = geo

        elog("экран '\(geo.screen.localizedName)'")
        elog("notchRect=\(geo.notchRect)")
        elog("collapsed=\(geo.collapsedFrame)")
        elog("expanded=\(geo.expandedFrame)")
        elog("trigger=\(geo.hoverTriggerRect)")

        let panel = NotchPanel(contentRect: geo.collapsedFrame)

        let container = NSView()
        let host = NSHostingView(rootView: AnyView(IslandView(isExpanded: false)))
        host.autoresizingMask = [.width, .height]
        container.addSubview(host)
        panel.contentView = container
        host.frame = container.bounds

        self.panel = panel
        self.hosting = host

        panel.setFrame(geo.collapsedFrame, display: true)
        panel.orderFrontRegardless()

        startMouseMonitoring()
    }

    // MARK: - Hover detection

    private func startMouseMonitoring() {
        // Global: pointer is over other apps (the menu bar, desktop, …).
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved]) { [weak self] _ in
            self?.evaluateHover()
        }
        // Local: pointer is over our own panel once it's expanded.
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved]) { [weak self] event in
            self?.evaluateHover()
            return event
        }
    }

    private func evaluateHover() {
        guard let geo = geometry else { return }
        let p = NSEvent.mouseLocation
        if isExpanded {
            if !geo.expandedFrame.containsInclusive(p) { collapse() }
        } else {
            if geo.hoverTriggerRect.containsInclusive(p) { expand() }
        }
    }

    // MARK: - State transitions

    func expand() {
        guard let panel, let geo = geometry, !isExpanded else { return }
        isExpanded = true
        render()
        animate(panel, to: geo.expandedFrame, curve: .easeOut)
    }

    func collapse() {
        guard let panel, let geo = geometry, isExpanded else { return }
        isExpanded = false
        render()
        animate(panel, to: geo.collapsedFrame, curve: .easeIn)
    }

    func reposition() {
        guard let geo = NotchGeometry.current() else { return }
        geometry = geo
        panel?.setFrame(isExpanded ? geo.expandedFrame : geo.collapsedFrame, display: true)
    }

    // MARK: - Private

    private func render() {
        hosting?.rootView = AnyView(IslandView(isExpanded: isExpanded))
    }

    private func animate(_ panel: NotchPanel, to frame: CGRect,
                         curve: CAMediaTimingFunctionName) {
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.28
            ctx.timingFunction = CAMediaTimingFunction(name: curve)
            panel.animator().setFrame(frame, display: true)
        }
    }
}
