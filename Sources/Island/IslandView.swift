import SwiftUI

/// The morphing black island. It fills a fixed area (the whole window) and draws
/// the island rectangle itself, sized and rounded from a single `progress` value
/// (0 = collapsed/notch, 1 = expanded). Driving everything from one animatable
/// value guarantees size and corner radius stay in sync — animating a shape's
/// radius separately from its frame does not.
struct IslandShape: Shape {
    var progress: CGFloat
    var collapsedSize: CGSize
    var expandedSize: CGSize
    var maxRadius: CGFloat = 26

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        // Lower-clamp only: allow the spring to overshoot past 1 so the bounce is
        // visible (the window has transparent margins for it to grow into).
        let p = max(0, progress)
        let w = collapsedSize.width + (expandedSize.width - collapsedSize.width) * p
        let h = collapsedSize.height + (expandedSize.height - collapsedSize.height) * p
        let r = min(maxRadius, h * 0.32, w / 2)

        let box = CGRect(x: rect.midX - w / 2, y: rect.minY, width: w, height: h)

        var path = Path()
        path.move(to: CGPoint(x: box.minX, y: box.minY))
        path.addLine(to: CGPoint(x: box.maxX, y: box.minY))
        path.addLine(to: CGPoint(x: box.maxX, y: box.maxY - r))
        path.addQuadCurve(to: CGPoint(x: box.maxX - r, y: box.maxY),
                          control: CGPoint(x: box.maxX, y: box.maxY))
        path.addLine(to: CGPoint(x: box.minX + r, y: box.maxY))
        path.addQuadCurve(to: CGPoint(x: box.minX, y: box.maxY - r),
                          control: CGPoint(x: box.minX, y: box.maxY))
        path.closeSubpath()
        return path
    }
}

/// The island's root view: the morphing shape plus the feature content that fades
/// in when expanded.
struct IslandRootView: View {
    @ObservedObject var model: IslandModel

    var body: some View {
        ZStack(alignment: .top) {
            IslandShape(progress: model.isExpanded ? 1 : 0,
                        collapsedSize: model.collapsedSize,
                        expandedSize: model.expandedSize)
                .fill(Color.black)

            if model.isExpanded {
                VStack(spacing: Theme.Spacing.afterTabs) {
                    TabBar(selection: $model.selectedTab)
                        .padding(.top, model.topInset + Theme.Spacing.belowNotch)
                    content
                        .padding(.horizontal, Theme.Spacing.edge)
                        .padding(.bottom, Theme.Spacing.edge)
                    Spacer(minLength: 0)
                }
                .frame(width: model.expandedSize.width, height: model.expandedSize.height, alignment: .top)
                .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    @ViewBuilder
    private var content: some View {
        switch model.selectedTab {
        case .calendar:
            CalendarView()
        case .weather:
            WeatherView(model: model.weather, isPinned: $model.isPinned)
        case .music:
            MusicView(model: model.music)
        }
    }
}
