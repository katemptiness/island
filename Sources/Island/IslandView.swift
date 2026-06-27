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

/// The island's root view. Collapsed: just the black notch shape. Expanded: the
/// tab bar plus the active feature, kept below the physical notch strip.
struct IslandRootView: View {
    @ObservedObject var model: IslandModel

    var body: some View {
        ZStack(alignment: .top) {
            BottomRoundedRectangle(radius: model.isExpanded ? 22 : 10)
                .fill(Color.black)

            if model.isExpanded {
                VStack(spacing: 10) {
                    TabBar(selection: $model.selectedTab)
                        .padding(.top, model.topInset + 6)
                    content
                    Spacer(minLength: 0)
                }
                .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var content: some View {
        switch model.selectedTab {
        case .calendar:
            CalendarView()
        case .weather:
            WeatherView(model: model.weather, isPinned: $model.isPinned)
        }
    }
}
