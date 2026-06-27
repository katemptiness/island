import AppKit

/// Figures out where the physical notch lives and the frames we use for the
/// collapsed (resting) and expanded states. All rects are in global screen
/// coordinates (bottom-left origin, like AppKit's `NSWindow.setFrame`).
struct NotchGeometry {
    let screen: NSScreen
    /// The physical notch area at the very top-center of the screen.
    let notchRect: CGRect
    let collapsedSize: CGSize
    let expandedSize: CGSize

    static func current() -> NotchGeometry? {
        // Prefer the screen that actually has a notch (a non-zero top safe-area
        // inset). Fall back to the main screen so we still show *something* on
        // notchless displays (a floating pill at the top-center).
        let screen = NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 })
            ?? NSScreen.main
        guard let screen else { return nil }

        let frame = screen.frame
        let topInset = screen.safeAreaInsets.top

        // Notch width = the gap between the usable areas on either side of it.
        var notchWidth: CGFloat = 200
        if let left = screen.auxiliaryTopLeftArea,
           let right = screen.auxiliaryTopRightArea {
            let gap = right.minX - left.maxX
            if gap > 0 { notchWidth = gap }
        }

        let notchHeight = topInset > 0 ? topInset : 32

        let notchRect = CGRect(
            x: frame.midX - notchWidth / 2,
            y: frame.maxY - notchHeight,
            width: notchWidth,
            height: notchHeight
        )

        let collapsedSize = CGSize(width: notchWidth, height: notchHeight)
        let expandedSize = CGSize(width: 380, height: 380)

        return NotchGeometry(
            screen: screen,
            notchRect: notchRect,
            collapsedSize: collapsedSize,
            expandedSize: expandedSize
        )
    }

    /// Resting frame: exactly over the notch so it blends in.
    var collapsedFrame: CGRect {
        CGRect(
            x: notchRect.midX - collapsedSize.width / 2,
            y: screen.frame.maxY - collapsedSize.height,
            width: collapsedSize.width,
            height: collapsedSize.height
        )
    }

    /// Expanded frame: the island's visible extent when open. Also the hover
    /// "stay-open" zone.
    var expandedFrame: CGRect {
        CGRect(
            x: notchRect.midX - expandedSize.width / 2,
            y: screen.frame.maxY - expandedSize.height,
            width: expandedSize.width,
            height: expandedSize.height
        )
    }

    /// The actual window frame — a bit larger than the island so the spring can
    /// overshoot into transparent margins instead of being clipped.
    var windowFrame: CGRect {
        let marginX: CGFloat = 50
        let marginBottom: CGFloat = 50
        return CGRect(
            x: notchRect.midX - (expandedSize.width / 2 + marginX),
            y: screen.frame.maxY - (expandedSize.height + marginBottom),
            width: expandedSize.width + marginX * 2,
            height: expandedSize.height + marginBottom
        )
    }

    /// The "open" zone: the notch, grown a little (wider + a touch downward) so
    /// it's easy to hit when approaching from the sides or from below. The top
    /// stays flush with the screen edge. This is always fully inside
    /// `expandedFrame`, which guarantees no expand/collapse oscillation.
    var hoverTriggerRect: CGRect {
        let extraX: CGFloat = 6
        let extraDown: CGFloat = 8
        return CGRect(
            x: notchRect.minX - extraX,
            y: notchRect.minY - extraDown,
            width: notchRect.width + extraX * 2,
            height: notchRect.height + extraDown
        )
    }
}

extension CGRect {
    /// Like `contains`, but inclusive on the max edges — so the very top row of
    /// the screen (where the notch sits) still counts as "inside".
    func containsInclusive(_ p: CGPoint) -> Bool {
        p.x >= minX && p.x <= maxX && p.y >= minY && p.y <= maxY
    }
}
