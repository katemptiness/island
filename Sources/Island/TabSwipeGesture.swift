import AppKit

/// Recognizes one horizontal tab step per physical scroll gesture. The direction
/// is locked early so a vertical scroll cannot turn into a tab switch halfway
/// through, and momentum never triggers another step.
struct TabSwipeGesture {
    enum Result: Equatable {
        case passThrough
        case consume
        case switchTab(Int)
    }

    private enum Axis { case undecided, horizontal, vertical }
    private var axis: Axis = .undecided
    private var isTracking = false
    private var didSwitch = false
    private var distanceX: CGFloat = 0
    private var travelX: CGFloat = 0
    private var travelY: CGFloat = 0

    var isTrackingHorizontal: Bool { isTracking && axis == .horizontal }

    mutating func reset() { self = Self() }

    mutating func handle(deltaX: CGFloat, deltaY: CGFloat,
                         phase: NSEvent.Phase, momentumPhase: NSEvent.Phase,
                         isPrecise: Bool, isInverted: Bool, canBegin: Bool) -> Result {
        // Ordinary mouse wheels have no gesture phases and must not change tabs.
        guard isPrecise else { return .passThrough }

        if !momentumPhase.isEmpty {
            // Keep the horizontal tail away from the newly selected tab's list.
            return axis == .horizontal ? .consume : .passThrough
        }

        if phase.contains(.mayBegin) || phase.contains(.began) {
            reset()
            isTracking = phase.contains(.began) && canBegin
        }

        if phase.contains(.ended) || phase.contains(.cancelled) {
            isTracking = false
            // Let a scroll view finish any small scroll it received before we
            // locked the axis, including at an edge where no tab was changed.
            return .passThrough
        }

        guard isTracking, !phase.isEmpty else { return .passThrough }

        // Undo natural-scroll inversion: fingers left always means the next
        // tab, regardless of the user's vertical scrolling preference.
        distanceX += isInverted ? -deltaX : deltaX
        travelX += abs(deltaX)
        travelY += abs(deltaY)

        if axis == .undecided {
            if travelX >= 10 && travelX > travelY * 1.5 {
                axis = .horizontal
            } else if travelY >= 10 {
                axis = .vertical
            }
        }

        guard axis == .horizontal else { return .passThrough }
        if !didSwitch && abs(distanceX) >= 40 {
            didSwitch = true
            return .switchTab(distanceX > 0 ? 1 : -1)
        }
        return .consume
    }
}
