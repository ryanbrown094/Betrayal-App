import SwiftUI
import UIKit

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

// the top bar's buttons: on glass, as high as the chips beside them (40 points), so the bar reads as one row; brass
// while what it opens is open
struct GlassPill: ButtonStyle {
    var on = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(Theme.ui(14, .bold)).foregroundStyle(on ? Theme.brass2 : Theme.tallow).lineLimit(1)
            .padding(.horizontal, 14).frame(minWidth: 40, minHeight: 40)
            .contentShape(Capsule())
            .glass(in: Capsule())
            .scaleEffect(configuration.isPressed ? 0.96 : 1).opacity(configuration.isPressed ? 0.75 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

// a round button on glass (back), 40 points like the bar's chips
struct GlassCircle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.glass(in: Circle())
            .scaleEffect(configuration.isPressed ? 0.94 : 1).opacity(configuration.isPressed ? 0.75 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

// the window's safe area as UIKit has it (the iPhone Duo closed keeps its status bar down one side): a reader that
// ignores the safe area is told it has none, and one inside it is too, so this asks the window itself
struct SidesReader: ViewModifier {
    @Binding var sides: EdgeInsets
    func body(content: Content) -> some View { content.background(WindowInsets(sides: $sides).frame(width: 0, height: 0)) }
}

private struct WindowInsets: UIViewRepresentable {
    @Binding var sides: EdgeInsets
    func makeUIView(context: Context) -> Probe {
        let v = Probe()
        v.report = { i in DispatchQueue.main.async { if sides != i { sides = i } } }
        return v
    }
    func updateUIView(_ v: Probe, context: Context) { v.send() }

    final class Probe: UIView {
        var report: ((EdgeInsets) -> Void)?
        private var last: UIEdgeInsets?
        override func didMoveToWindow() { super.didMoveToWindow(); send() }
        override func layoutSubviews() { super.layoutSubviews(); send() } // (a fold changes the window, and lays this out again)
        func send() {
            guard let w = window else { return }
            let i = w.safeAreaInsets
            if i == last { return }
            last = i
            let rtl = effectiveUserInterfaceLayoutDirection == .rightToLeft
            report?(EdgeInsets(top: i.top, leading: rtl ? i.right : i.left, bottom: i.bottom, trailing: rtl ? i.left : i.right))
        }
    }
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
