import SwiftUI

/// The morphing black island. It fills a fixed area (the whole window) and draws
/// the island rectangle itself, sized and rounded from a single `progress` value
/// (0 = collapsed/notch, 1 = expanded). Driving everything from one animatable
/// value guarantees size and corner radius stay in sync — animating a shape's
/// radius separately from its frame does not.
struct IslandShape: Shape {
    var progress: CGFloat
    /// Target height when fully expanded. Animatable so the island can resize
    /// between tabs (the width is fixed).
    var expandedHeight: CGFloat
    var collapsedSize: CGSize
    var expandedWidth: CGFloat
    var maxRadius: CGFloat = 26

    // Animate both the open/close progress and the per-tab height together, so a
    // tab switch morphs the island's size smoothly instead of snapping.
    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(progress, expandedHeight) }
        set {
            progress = newValue.first
            expandedHeight = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        // Lower-clamp only: allow the spring to overshoot past 1 so the bounce is
        // visible (the window has transparent margins for it to grow into).
        let p = max(0, progress)
        let w = collapsedSize.width + (expandedWidth - collapsedSize.width) * p
        let h = collapsedSize.height + (expandedHeight - collapsedSize.height) * p
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
            // Ambient "now playing" glow around the notch, only while collapsed
            // (when open, the music content already conveys it and a halo would
            // distract).
            if !model.isExpanded, model.music.isActivelyPlaying, let tint = model.music.tint {
                MusicGlow(collapsedSize: model.collapsedSize,
                          expandedWidth: model.expandedSize.width,
                          color: tint)
                    .transition(.opacity)
            }

            IslandShape(progress: model.isExpanded ? 1 : 0,
                        expandedHeight: model.currentExpandedHeight,
                        collapsedSize: model.collapsedSize,
                        expandedWidth: model.expandedSize.width)
                .fill(tintGradient)

            if model.isExpanded {
                VStack(spacing: Theme.Spacing.afterTabs) {
                    TabBar(selection: $model.selectedTab)
                        .padding(.top, model.topInset + Theme.Spacing.belowNotch)
                    content
                        .padding(.horizontal, Theme.Spacing.edge)
                        .padding(.bottom, Theme.Spacing.edge)
                    Spacer(minLength: 0)
                }
                // Match the shape's height and clip, so when the island resizes
                // between tabs the content is revealed/hidden in lockstep with
                // the black box rather than spilling past it.
                .frame(width: model.expandedSize.width, height: model.currentExpandedHeight, alignment: .top)
                .clipped()
                .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        // Fade the glow in/out when playback starts or stops.
        .animation(.easeInOut(duration: 0.4), value: model.music.isActivelyPlaying)
    }

    /// Black at the notch, easing into the tab's tint toward the island's bottom.
    /// The shape fills the whole panel, so the stops are expressed as fractions
    /// of the panel height and the color is reached exactly at the island's edge.
    /// With no tint (calendar / no data) it's black throughout.
    private var tintGradient: LinearGradient {
        let island = max(model.currentExpandedHeight, 1)
        let panel = max(model.windowHeight, island)
        let bottom = min(island / panel, 1)
        let hold = bottom * 0.30 // keep the top third (notch + tabs) solid black
        let tint = model.currentTint ?? .black
        return LinearGradient(
            stops: [
                .init(color: .black, location: 0),
                .init(color: .black, location: hold),
                .init(color: tint, location: bottom)
            ],
            startPoint: .top, endPoint: .bottom
        )
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

/// A soft, slowly breathing halo hugging the collapsed notch, shown while music
/// is playing and tinted by the current artwork. A blurred stroke of the
/// collapsed island shape whose opacity eases up and down forever — light enough
/// to leave running, subtle enough not to pull focus.
private struct MusicGlow: View {
    let collapsedSize: CGSize
    let expandedWidth: CGFloat
    let color: Color
    @State private var bright = false

    var body: some View {
        IslandShape(progress: 0,
                    expandedHeight: collapsedSize.height,
                    collapsedSize: collapsedSize,
                    expandedWidth: expandedWidth)
            .fill(IslandTint.glow(from: color))
            .scaleEffect(1.09, anchor: .top)   // push the bleed past the black notch
            .blur(radius: 12)
            .opacity(bright ? 0.8 : 0.45)
            .allowsHitTesting(false)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.9).repeatForever(autoreverses: true)) {
                    bright = true
                }
            }
    }
}
