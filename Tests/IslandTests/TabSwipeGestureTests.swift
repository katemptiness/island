import AppKit
import Testing
@testable import Island

struct TabSwipeGestureTests {
    // These samples stand in for AppKit scroll events; no input is posted to
    // the desktop and no accessibility permissions are needed to run the tests.
    private func scroll(_ gesture: inout TabSwipeGesture,
                        x: CGFloat = 0, y: CGFloat = 0,
                        phase: NSEvent.Phase = .changed,
                        momentum: NSEvent.Phase = [],
                        precise: Bool = true, inverted: Bool = false,
                        inside: Bool = true) -> TabSwipeGesture.Result {
        gesture.handle(deltaX: x, deltaY: y, phase: phase, momentumPhase: momentum,
                       isPrecise: precise, isInverted: inverted, canBegin: inside)
    }

    @Test func oneTabPerGestureIncludingMomentum() {
        var gesture = TabSwipeGesture()
        #expect(scroll(&gesture, phase: .began) == .passThrough)
        #expect(scroll(&gesture, x: 24, y: 1) == .consume)
        #expect(scroll(&gesture, x: 24, y: 1) == .switchTab(1))
        #expect(scroll(&gesture, x: 200) == .consume)
        #expect(scroll(&gesture, x: -300) == .consume)
        #expect(scroll(&gesture, phase: .ended) == .passThrough)
        #expect(!gesture.isTrackingHorizontal)
        #expect(scroll(&gesture, x: 200, phase: [], momentum: .began) == .consume)
        #expect(scroll(&gesture, x: 100, phase: [], momentum: .changed) == .consume)
        #expect(scroll(&gesture, phase: [], momentum: .ended) == .consume)
        #expect(scroll(&gesture, x: -50, phase: .began) == .switchTab(-1))
    }

    @Test func verticalScrollStaysVerticalEvenIfTheHandDrifts() {
        var gesture = TabSwipeGesture()
        #expect(scroll(&gesture, x: 1, y: 4, phase: .began) == .passThrough)
        #expect(scroll(&gesture, x: 3, y: 20) == .passThrough)
        #expect(scroll(&gesture, x: 100, y: 5) == .passThrough)
        #expect(scroll(&gesture, phase: .ended) == .passThrough)
        #expect(scroll(&gesture, x: 80, phase: [], momentum: .began) == .passThrough)
    }

    @Test func diagonalScrollDoesNotSwitchTabs() {
        var gesture = TabSwipeGesture()
        #expect(scroll(&gesture, x: 25, y: 25, phase: .began) == .passThrough)
        #expect(scroll(&gesture, x: 50, y: 50) == .passThrough)
    }

    @Test func shortGestureCannotSwitchThroughMomentum() {
        var gesture = TabSwipeGesture()
        #expect(scroll(&gesture, x: 15, phase: .began) == .consume)
        #expect(scroll(&gesture, phase: .ended) == .passThrough)
        #expect(scroll(&gesture, x: 100, phase: [], momentum: .began) == .consume)
    }

    @Test func directionDoesNotDependOnNaturalScrolling() {
        var normal = TabSwipeGesture()
        var inverted = TabSwipeGesture()
        #expect(scroll(&normal, x: 50, phase: .began) == .switchTab(1))
        #expect(scroll(&inverted, x: -50, phase: .began, inverted: true) == .switchTab(1))
        #expect(scroll(&normal, x: -50, phase: .began) == .switchTab(-1))
        #expect(scroll(&inverted, x: 50, phase: .began, inverted: true) == .switchTab(-1))
    }

    @Test func gestureMustStartInsideTheIsland() {
        var gesture = TabSwipeGesture()
        #expect(scroll(&gesture, x: 50, phase: .began, inside: false) == .passThrough)
        #expect(scroll(&gesture, x: 100, inside: true) == .passThrough)
        #expect(scroll(&gesture, x: 50, phase: .began, inside: true) == .switchTab(1))
        // A shorter destination tab must not restart the same gesture.
        #expect(scroll(&gesture, x: 100, inside: false) == .consume)
    }

    @Test func cancellationAndCollapseDiscardAnUnfinishedGesture() {
        var gesture = TabSwipeGesture()
        #expect(scroll(&gesture, x: 20, phase: .began) == .consume)
        #expect(scroll(&gesture, x: 100, phase: .cancelled) == .passThrough)
        #expect(scroll(&gesture, x: 100) == .passThrough)
        #expect(scroll(&gesture, x: 20, phase: .began) == .consume)
        gesture.reset()
        #expect(scroll(&gesture, x: 100) == .passThrough)
        #expect(scroll(&gesture, x: 100, phase: [], momentum: .began) == .passThrough)
        #expect(scroll(&gesture, x: 50, phase: .began) == .switchTab(1))
    }

    @Test func mouseWheelsAndOrphanedEventsDoNotSwitchTabs() {
        var gesture = TabSwipeGesture()
        #expect(scroll(&gesture, x: 100, phase: [], precise: false) == .passThrough)
        #expect(scroll(&gesture, x: 100, phase: .began, precise: false) == .passThrough)
        #expect(scroll(&gesture, x: 100, phase: []) == .passThrough)
        #expect(scroll(&gesture, x: 100) == .passThrough)
        #expect(scroll(&gesture, phase: .mayBegin) == .passThrough)
        #expect(scroll(&gesture, phase: .cancelled) == .passThrough)
        #expect(scroll(&gesture, x: 100) == .passThrough)
    }

    @Test func navigationSkipsHiddenTabsAndStopsAtEdges() {
        let visible: [IslandTab] = [.calendar, .files]
        #expect(IslandTab.calendar.adjacent(by: 1, in: visible) == .files)
        #expect(IslandTab.files.adjacent(by: -1, in: visible) == .calendar)
        #expect(IslandTab.calendar.adjacent(by: -1, in: visible) == nil)
        #expect(IslandTab.files.adjacent(by: 1, in: visible) == nil)
        #expect(IslandTab.music.adjacent(by: 1, in: visible) == nil)
        #expect(IslandTab.calendar.adjacent(by: 1, in: [.calendar]) == nil)
        #expect(IslandTab.calendar.adjacent(by: -1, in: [.calendar]) == nil)
    }
}
