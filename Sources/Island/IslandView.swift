import SwiftUI

/// A rectangle with only its bottom corners rounded, so the top edge stays flush
/// with the screen edge and it reads as an extension of the notch.
struct BottomRoundedRectangle: Shape {
    var radius: CGFloat

    func path(in rect: CGRect) -> Path {
        let r = min(radius, min(rect.width, rect.height) / 2)
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))
        p.addQuadCurve(
            to: CGPoint(x: rect.maxX - r, y: rect.maxY),
            control: CGPoint(x: rect.maxX, y: rect.maxY)
        )
        p.addLine(to: CGPoint(x: rect.minX + r, y: rect.maxY))
        p.addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.maxY - r),
            control: CGPoint(x: rect.minX, y: rect.maxY)
        )
        p.closeSubpath()
        return p
    }
}

/// The island's content. Collapsed: just the black notch shape. Expanded: the
/// feature area below the notch. `topInset` keeps content clear of the physical
/// notch strip at the very top.
struct IslandView: View {
    var isExpanded: Bool
    var topInset: CGFloat

    var body: some View {
        ZStack(alignment: .top) {
            BottomRoundedRectangle(radius: isExpanded ? 22 : 10)
                .fill(Color.black)

            if isExpanded {
                CalendarView()
                    .padding(.top, topInset)
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
