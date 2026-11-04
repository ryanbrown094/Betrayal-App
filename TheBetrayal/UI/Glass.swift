import SwiftUI

// Liquid Glass (iOS 26) for the controls that float over the game and the start screen: the top bar, the host's bar of
// moves, the sidebars, back and close. Cards and the copper buttons keep the game's own look. Before iOS 26, the same
// shapes in the system's thin material and the game's own buttons; drawn offscreen (-render-all, -render-store), which
// can't draw either, a flat dark fill.
struct GlassSurface<S: Shape>: ViewModifier {
    let shape: S
    @Environment(\.rendering) private var rendering

    @ViewBuilder func body(content: Content) -> some View {
        if rendering {
            content.background(shape.fill(Color(hex: 0x1A1120).opacity(0.94))).overlay(shape.stroke(Theme.edge2, lineWidth: 1))
        } else if #available(iOS 26, *) {
            content.glassEffect(.regular, in: shape)
        } else {
            content.background(.ultraThinMaterial, in: shape).overlay(shape.stroke(Theme.edge2.opacity(0.7), lineWidth: 1))
        }
    }
}

// a button on the glass: the system's glass button (a copper one for the main move); before iOS 26, or drawn
// offscreen, the game's own (small, as wide as its words)
struct GlassButton: ViewModifier {
    var prominent = false
    var top = false // the top bar's: its smaller type, and before iOS 26 its outlined button (.tbtn)
    @Environment(\.rendering) private var rendering

    @ViewBuilder func body(content: Content) -> some View {
        if rendering || !Glassy.on {
            if top && !prominent { content.buttonStyle(TopButton()) } else { content.buttonStyle(Btn(kind: prominent ? .fill : .dark, size: .sm, fit: true)) }
        } else if #available(iOS 26, *) {
            if prominent {
                content.buttonStyle(.glassProminent).tint(Color(hex: 0xC0715A))
                    .font(Theme.ui(top ? 14 : 16, .bold)).foregroundStyle(Theme.ink)
            } else {
                content.buttonStyle(.glass).font(Theme.ui(top ? 14 : 16, .bold)).foregroundStyle(Theme.tallow)
            }
        } else {
            if top && !prominent { content.buttonStyle(TopButton()) } else { content.buttonStyle(Btn(kind: prominent ? .fill : .dark, size: .sm, fit: true)) }
        }
    }
}

enum Glassy {
    static var on: Bool { if #available(iOS 26, *) { return true } else { return false } }
}

extension View {
    func glass<S: Shape>(in shape: S) -> some View { modifier(GlassSurface(shape: shape)) }
    func glassButton(prominent: Bool = false, top: Bool = false) -> some View { modifier(GlassButton(prominent: prominent, top: top)) }
}

// several pieces of glass drawn together, so they morph as they come and go (GlassEffectContainer; at a spacing of
// nothing, so pieces side by side stay apart); before iOS 26, just the pieces
struct GlassGroup<Content: View>: View {
    @ViewBuilder let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View {
        if #available(iOS 26, *) { GlassEffectContainer(spacing: 0) { content } } else { content }
    }
}

struct GlassRow<Content: View>: View {
    var spacing: CGFloat
    @ViewBuilder let content: Content
    init(spacing: CGFloat = 8, @ViewBuilder content: () -> Content) { self.spacing = spacing; self.content = content() }
    var body: some View { GlassGroup { HStack(spacing: spacing) { content } } }
}

// the width this view is given, for the layouts that change with it
struct WidthReader: ViewModifier {
    @Binding var width: CGFloat
    func body(content: Content) -> some View {
        content.background(GeometryReader { g in Color.clear.onAppear { width = g.size.width }.onChange(of: g.size.width) { _, w in width = w } })
    }
}

// an iPad, or the iPhone Duo open (669 points, less any side the status bar takes): wide enough for a sidebar beside
// the phone's column; never a phone, nor the Duo's cover (466 points)
enum Wide {
    static let from: CGFloat = 540
    static func sidebar(_ width: CGFloat) -> CGFloat { min(300, max(250, width * 0.32)) }
}
