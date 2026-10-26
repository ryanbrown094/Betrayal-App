import SwiftUI
import UIKit

// A player's phone at a Table (phone() in src/modern-ui.js): joining, setting up, then the game.
struct TableView: View {
    @Bindable var session: Session
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Backdrop()
            if session.isTV { TVView() } else { phone }
        }
        .environment(session)
        // before the game (a name, the host's set-up, a Table not open yet), the system's back button; in it, the top
        // bar's own (TopBar), and on the TV, nothing over the picture
        .toolbar(session.screen == .play || session.isTV ? .hidden : .visible, for: .navigationBar)
        .statusBarHidden(session.isTV)
        .onAppear { session.start(); Feedback.keepAwake(true); AppModel.shared.opened(session) }
        .onDisappear { session.stop(); Feedback.keepAwake(false); AppModel.shared.closed(session) }
        .onChange(of: scenePhase) { _, p in
            session.background = p != .active
            if p == .active { Task { await session.poll() } }
            if !session.demo { Trail.shared.log(session.room, "vis", p == .active ? "foreground" : p == .background ? "background" : "inactive"); if p == .background { Trail.shared.flush(session.room) } }
        }
        .alert(session.ask?.title ?? "", isPresented: Binding(get: { session.ask != nil }, set: { if !$0 { session.ask = nil } }), presenting: session.ask) { a in
            AskButtons(ask: a)
        } message: { a in
            if let m = a.message { Text(m) }
        }
    }

    @ViewBuilder private var phone: some View {
        switch session.screen {
        case .join: ScrollView { JoinCard(back: { dismiss() }) }.scrollDismissesKeyboard(.interactively)
        case .create(let test): ScrollView { CreateCard(test: test) }.scrollDismissesKeyboard(.interactively)
        case .choose: ScrollView { ChooseCard() }
        case .wait: ScrollView { Notice(title: "Asking the host…", text: "The game has started. The host’s phone will ask them to let you back in.") }
        case .nogame:
            ScrollView {
                Notice(title: session.classic ? "Not a Table for the app" : "Not open yet",
                       text: session.classic ? "Table \(session.room) can’t be played in the app. Ask the host to start a new Table in the app." : "Table \(session.room) hasn’t been set up. The host opens it first, then you can join.")
            }
            .task { while session.screen == .nogame && !Task.isCancelled { try? await Task.sleep(nanoseconds: 4_000_000_000); await recheck() } }
        case .play: PlayView().overlay { ShareGuard() }
        case .tv: PlayView()
        }
    }

    // a Table that wasn't set up yet may be by now
    private func recheck() async {
        if await API.mode(of: session.room) == .modern { session.screen = session.token == nil ? .join : .play }
    }
}

// A phone whose screen is being shown somewhere else (mirrored to a TV over AirPlay or a cable, or recorded) while the
// app isn't drawing a TV picture of its own there: the role and the choices on it would show too, so they're covered
// until the sharing stops, or the player says to show them anyway.
private struct ShareGuard: View {
    @State private var captured = false
    @State private var shown = false
    private let model = AppModel.shared
    var body: some View {
        ZStack {
            CaptureWatch(captured: $captured).frame(width: 0, height: 0)
            if captured && !shown && !model.externalConnected {
                ZStack {
                    Backdrop()
                    Column {
                        Brand()
                        VStack(spacing: 0) {
                            H2("Your screen is on show")
                            Sub("This phone’s screen is being shared: mirrored to a TV, or recorded. Your role and your choices would show too, so they’re hidden until it stops.")
                            Small("To stop: Control Centre, then Screen Mirroring (or the record button). For the game on a TV, use an iPad or a spare phone as the TV: Set up a TV, on the start screen.", center: true)
                        }
                        .multilineTextAlignment(.center).frame(maxWidth: .infinity)
                        Button("Show my screen anyway") { shown = true }.btn(.dark, .sm)
                    }
                }
                .transition(.opacity)
            }
        }
        .onChange(of: captured) { _, c in if !c { shown = false } }
    }
}

// whether this phone's screen is being captured (UITraitCollection.sceneCaptureState: AirPlay or cable mirroring,
// recording, iPhone Mirroring)
private struct CaptureWatch: UIViewRepresentable {
    @Binding var captured: Bool
    func makeUIView(context: Context) -> Watcher { let w = Watcher(); w.changed = { captured = $0 }; return w }
    func updateUIView(_ w: Watcher, context: Context) { w.changed = { captured = $0 } }

    final class Watcher: UIView {
        var changed: ((Bool) -> Void)?
        override init(frame: CGRect) {
            super.init(frame: frame)
            registerForTraitChanges([UITraitSceneCaptureState.self]) { (w: Watcher, _: UITraitCollection) in w.report() }
        }
        required init?(coder: NSCoder) { fatalError() }
        override func didMoveToWindow() { super.didMoveToWindow(); report() }
        func report() {
            let c = traitCollection.sceneCaptureState == .active
            DispatchQueue.main.async { [weak self] in self?.changed?(c) }
        }
    }
}

private struct AskButtons: View {
    let ask: Session.Ask
    @State private var typed = ""
    var body: some View {
        if ask.typed { TextField("SHOW THE ROLES", text: $typed).textInputAutocapitalization(.characters).autocorrectionDisabled() }
        // after the alert has gone, so a question can follow a question (the roles ask three times)
        Button(ask.yes, role: ask.typed ? .destructive : nil) {
            let a = ask, t = typed
            Task { @MainActor in try? await Task.sleep(nanoseconds: 350_000_000); a.then(t) }
        }
        Button("Cancel", role: .cancel) {}
    }
}

// the brand at the top of the screens before a game (.brand)
struct Brand: View {
    var mark: String? = nil // what kind of game, when it isn't an ordinary one (practice, a test game)
    var body: some View {
        VStack(spacing: 6) {
            Crest().frame(width: 64, height: 76).foregroundStyle(Theme.brass2)
            Text("The Betrayal").font(Theme.disp(40)).foregroundStyle(Theme.brass2)
            if let mark { Text(mark).font(Theme.sc(15)).tracking(1.8).foregroundStyle(Theme.tallow2) }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 18).padding(.bottom, 22)
    }
}

struct Notice: View {
    let title: String
    let text: String
    var body: some View {
        Column {
            Brand()
            VStack(spacing: 0) { H2(title); Sub(text) }.multilineTextAlignment(.center).frame(maxWidth: .infinity)
        }
    }
}

// the phone's column: at most 520 wide, 16 from the edges (#app)
struct Column<Content: View>: View {
    @ViewBuilder let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View {
        VStack(alignment: .leading, spacing: 0) { content }
            .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 24)
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity)
    }
}

// the toast under a form (.msg)
struct Msg: View {
    @Environment(Session.self) private var session
    var body: some View {
        Text(session.toast?.text ?? " ").font(Theme.ui(15)).foregroundStyle(session.toast?.error == true ? Theme.blood2 : Theme.tallow2)
            .frame(maxWidth: .infinity, minHeight: 22, alignment: .leading).padding(.top, 8)
            .accessibilityAddTraits(.updatesFrequently)
    }
}

// ---------------------------------------------------------------------------------------------------------------
// before the game: your name for this Table (joinScreen), the host's set-up (createScreen), player or TV (chooseScreen)
struct JoinCard: View {
    var back: () -> Void = {}
    @Environment(Session.self) private var session
    @State private var name = UserDefaults.standard.string(forKey: "bt-name") ?? ""
    var body: some View {
        Column {
            Brand()
            Card {
                H2("Join a game")
                Sub("Everyone plays on their own phone, and your role never leaves this screen.")
                VStack(alignment: .leading, spacing: 10) {
                    Para(Text("Table ") + b(session.room).font(Theme.ui(18, .bold)))
                    Label2("Your name")
                    Field(placeholder: "As the table knows you", text: $name, max: 14, submit: go)
                    Button("Join", action: go).btn(.fill, .big)
                }
                Msg()
            }
        }
    }
    private func go() {
        UserDefaults.standard.set(name.trimmingCharacters(in: .whitespaces), forKey: "bt-name")
        Task { await session.join(name: name) }
    }
}

struct CreateCard: View {
    let test: Bool
    @Environment(Session.self) private var session
    @State private var name = UserDefaults.standard.string(forKey: "bt-name") ?? ""
    @State private var bots = 10
    var body: some View {
        Column {
            Brand(mark: session.practice ? "practice" : test ? "test game" : nil)
            Card {
                if session.practice {
                    H2("A practice game")
                    Sub("Table \(session.room). You and the bots: they swear, play the Trials, vote, choose at night and trust by themselves, so you can play a whole game on your own. The Trials that need people in the room are left out.")
                } else if test {
                    H2("A test game against bots")
                    Sub("Table \(session.room). You host, and the bots swear, vote, choose at night and trust by themselves. Trials give everyone a random score, and every countdown is ten seconds.")
                } else {
                    H2("You’re the host")
                    Sub("Table \(session.room). Your phone begins each part of the evening when the table is ready, and can call a short break. The rest runs itself, and you never see anyone else’s role.")
                }
                Label2("Your name")
                Field(placeholder: "", text: $name, max: 14, submit: go)
                if test {
                    Spacer().frame(height: 10)
                    Label2("Players, you included")
                    Picker("Players, you included", selection: $bots) { ForEach(8...(session.practice ? 16 : 24), id: \.self) { Text("\($0)").tag($0) } }
                        .pickerStyle(.menu).tint(Theme.tallow)
                        .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading).padding(.horizontal, 6)
                        .background(RoundedRectangle(cornerRadius: 4).fill(Theme.field))
                        .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Theme.edge, lineWidth: 1))
                }
                Spacer().frame(height: 12)
                Button(session.practice ? "Start the practice game" : test ? "Start the test game" : "Open the Table", action: go).btn(.fill, .big)
                Msg()
            }
        }
    }
    private func go() {
        UserDefaults.standard.set(name.trimmingCharacters(in: .whitespaces), forKey: "bt-name")
        Task { await session.create(name: name, bots: test ? bots : nil) }
    }
}

struct ChooseCard: View {
    @Environment(Session.self) private var session
    var body: some View {
        Column {
            Brand()
            Card {
                H2("Table \(session.room)")
                Sub("This Table is playing Modern, so everyone plays on their own phone.")
                VStack(spacing: 10) {
                    Button("Join as a player") { session.screen = session.token != nil ? .play : .join }.btn(.fill, .big)
                    Button("Use this screen as the TV") { session.screen = .tv; session.start() }.btn(.ghost)
                }
            }
        }
    }
}

// ---------------------------------------------------------------------------------------------------------------
// the game on a phone (phone0): the top bar, the host's requests and the player's holdings, then the screen itself
struct PlayView: View {
    @Environment(Session.self) private var session
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismiss) private var dismiss

    @Environment(\.rendering) private var rendering

    var body: some View {
        if let v = session.view, let me = v.me {
            ZStack {
                if rendering { page(v, me) } else { ScrollView { page(v, me) }.scrollDismissesKeyboard(.interactively).safeAreaInset(edge: .bottom) { AdStrip(v: v, me: me) } }
                if !session.online {
                    VStack { Spacer(); Text("Reconnecting…").font(Theme.ui(14)).foregroundStyle(Color(hex: 0xF3B7C4)).padding(.horizontal, 12).padding(.vertical, 6)
                        .background(RoundedRectangle(cornerRadius: 3).fill(Color(hex: 0x2A1316))).overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(Color(hex: 0x6A2733), lineWidth: 1)).padding(.bottom, 14) }
                }
                // the host's tools open over the pause (its Host tools button), and close back to it
                if v.paused != nil && !(session.tools && me.director) { PauseBox(v: v, me: me) }
            }
        } else if session.isTV {
            TVView()
        } else {
            ScrollView {
                Column {
                    Brand()
                    Text("Connecting…").font(Theme.ui(18)).foregroundStyle(Theme.tallow2).frame(maxWidth: .infinity).padding(.bottom, 24)
                    Button("Back to the start") { dismiss() }.btn(.dark, .sm)
                }
            }
        }
    }

    private func page(_ v: Snapshot, _ me: Me) -> some View {
        Column {
            if me.left {
                Brand()
                VStack(spacing: 0) { H2("You’ve left the game"); Sub("The host has taken you out of this one. Thanks for playing, and keep what you know to yourself.") }
                    .multilineTextAlignment(.center).frame(maxWidth: .infinity)
                if !rendering { Button("Back to the start") { dismiss() }.btn(.ghost) }
            } else {
                TopBar(v: v, me: me)
                if let peek = session.peekList { PeekView(list: peek) }
                else if session.tools && me.director { ToolsView(v: v, me: me) }
                else { game(v, me) }
            }
        }
    }

    @ViewBuilder private func game(_ v: Snapshot, _ me: Me) -> some View {
        ForEach(session.rejoin) { r in RejoinCard(r: r) }
        if !me.alive && !["lobby", "oath", "roles", "end", "dawn", "reveal"].contains(v.phase) && v.trial?.key != "statue" {
            Banner(.ghost, icon: "ghost", "You’re a Ghost. You still watch, cheer and call it at the Reckoning, but you don’t vote or play.")
        }
        Holdings(v: v, me: me)
        if let t = session.toast { Banner(.plain, t.text) }
        PhaseView(v: v, me: me)
            .id(session.freshKey)
            .modifier(FadeIn(rise: reduceMotion ? 0 : 6))
    }
}

struct TopBar: View {
    let v: Snapshot
    let me: Me
    @Environment(Session.self) private var session
    @Environment(\.dismiss) private var dismiss
    // on one line if it all fits, then with shorter labels, then on two lines (a small phone, larger text)
    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) { back; who; Spacer(minLength: 8); right(short: false) }
            HStack(spacing: 10) { back; who; Spacer(minLength: 8); right(short: true) }
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 10) { back; who; Spacer(minLength: 0) }
                HStack { Spacer(minLength: 0); right(short: true) }
            }
        }
        .padding(.bottom, 10)
        .overlay(alignment: .bottom) { Rectangle().fill(Color(hex: 0x2A1A2C)).frame(height: 1) }
        .padding(.bottom, 18)
    }

    private var back: some View {
        Button(action: leave) {
            Image(systemName: "chevron.left").font(.system(size: 17, weight: .semibold)).foregroundStyle(Theme.tallow2)
                .frame(width: 28, height: 44).contentShape(Rectangle())
        }
        .buttonStyle(.plain).accessibilityLabel("Back to the start")
        .padding(.leading, -6)
    }

    private var who: some View {
        HStack(spacing: 8) {
            Seal(name: me.name, color: v.player(me.id).color).frame(width: 28, height: 28)
            Text(me.name).font(Theme.ui(16)).foregroundStyle(Theme.tallow).lineLimit(1).truncationMode(.tail)
            if me.director { Text("host").font(Theme.sc(15, bold: true)).foregroundStyle(Theme.brass2).fixedSize() }
        }
    }

    // the Table's code (before the game) or the Purse, and the host's Pause and Tools; short: the code alone, Pause as bars
    private func right(short: Bool) -> some View {
        HStack(spacing: 12) {
            let early = ["lobby", "oath", "roles"].contains(v.phase)
            Text(verbatim: early ? (short ? session.room : "Table \(session.room)") : "Purse \(v.pot)")
                .font(Theme.sc(14)).tracking(0.5).monospacedDigit().foregroundStyle(Theme.brass2).lineLimit(1).fixedSize()
            if me.director && v.paused == nil && !["lobby", "end"].contains(v.phase) {
                Button { session.confirm("Pause the game? Every clock stops until you carry on.", yes: "Pause") { session.act("pause") } } label: {
                    if short { PauseBars() } else { Text("Pause") }
                }
                .buttonStyle(TopButton()).accessibilityLabel("Pause the game")
            }
            if me.director {
                Button(session.tools ? "Close" : "Tools") { session.tools.toggle(); session.peekList = nil }
                    .buttonStyle(TopButton()).accessibilityLabel("Host tools")
            }
        }
        .fixedSize()
    }

    // to the start screen, which offers the way back to this Table; mid-game, asked first
    private func leave() {
        if ["lobby", "end"].contains(v.phase) || (!me.alive && !me.director) { dismiss(); return }
        session.confirm(me.director ? "Leave the game for now? It waits for you to move it on: come back to it from the start screen."
                                    : "Leave the game for now? It carries on, and you can come back to it from the start screen.", yes: "Leave") { dismiss() }
    }
}

private struct PauseBars: View {
    var body: some View { HStack(spacing: 4) { RoundedRectangle(cornerRadius: 1).frame(width: 4, height: 14); RoundedRectangle(cornerRadius: 1).frame(width: 4, height: 14) } }
}

// .tbtn: the top bar's small ghost buttons
struct TopButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(Theme.ui(14, .bold)).foregroundStyle(Theme.tallow)
            .padding(.horizontal, 10).padding(.vertical, 4)
            .frame(minWidth: 44, minHeight: 34)
            .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(Theme.edge, lineWidth: 1))
            .opacity(configuration.isPressed ? 0.7 : 1)
            .contentShape(Rectangle())
    }
}

// what this player holds, as small folds (tap for the full wording); left off a Trial's result, which says so itself
struct Holdings: View {
    let v: Snapshot
    let me: Me
    var body: some View {
        let chips = list
        if !chips.isEmpty && !(v.phase == "trial" && v.trial?.stage == "done") {
            VStack(spacing: 0) {
                ForEach(chips) { c in Chip(kind: c.kind, icon: c.icon, title: c.title, why: c.why) }
            }
            .overlay(alignment: .top) { Rectangle().fill(Color(hex: 0x3A3020)).frame(height: 1) }
            .padding(.bottom, 14)
        }
    }
    private struct Info: Identifiable { let kind: Banner.Kind; let icon: String; let title: String; let why: String; var id: String { title } }
    private var list: [Info] {
        var c: [Info] = []
        if me.shield { c.append(Info(kind: .sanct, icon: "shield", title: "Sanctuary tonight", why: "Nobody can take you tonight. Keep it to yourself.")) }
        if me.cast { c.append(Info(kind: .plain, icon: "scales", title: "The Casting Vote", why: "If a Reckoning ties and you voted for one of them, your vote decides it. Once. Nobody knows it’s you.")) }
        if me.crown && !["talk", "vote"].contains(v.phase) { c.append(Info(kind: .plain, icon: "crown", title: "The Crown", why: "Once, at a Reckoning, lay it down to be safe from that exile.")) }
        if let f = me.confess {
            c.append(Info(kind: .ghost, icon: "eye", title: f == "self" ? "The Confessor: nobody else" : "A Forsworn: " + f,
                          why: f == "self" ? "The Confessor’s prize: no other Forsworn is left at the table. It’s just you." : "The Confessor’s prize: " + f + " is Forsworn. Only you know."))
        }
        return c
    }
}

private struct Chip: View {
    let kind: Banner.Kind
    let icon: String
    let title: String
    let why: String
    @State private var open = false
    var body: some View {
        let fg = kind == .sanct ? Color(hex: 0xCFE9DE) : kind == .ghost ? Color(hex: 0xC4D2E4) : Theme.gold
        VStack(alignment: .leading, spacing: 0) {
            Button { withAnimation(.easeOut(duration: 0.2)) { open.toggle() } } label: {
                HStack(spacing: 8) { Icon(name: icon).frame(width: 16, height: 16); Text(title).font(Theme.ui(15)); Spacer() }
                    .foregroundStyle(fg).frame(minHeight: 44).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if open { Text(why).font(Theme.ui(15)).foregroundStyle(Theme.tallow2).fixedSize(horizontal: false, vertical: true).padding(.leading, 24).padding(.bottom, 10) }
        }
        .overlay(alignment: .bottom) { Rectangle().fill(Color(hex: 0x3A3020)).frame(height: 1) }
    }
}

struct RejoinCard: View {
    let r: Rejoin
    @Environment(Session.self) private var session
    var body: some View {
        Card(.hot) {
            Para(b(r.name) + Text(" is asking to come back in on a new phone. Only let them in if it’s really them."))
            HStack(spacing: 10) {
                Button("Let them in") { session.letIn(r, true) }.btn(.fill, .sm)
                Button("No") { session.letIn(r, false) }.btn(.ghost, .sm)
            }
        }
    }
}

// the host stopped the clocks: everything waits, and nothing can be answered, until they carry on
struct PauseBox: View {
    let v: Snapshot
    let me: Me?
    var tv = false
    var vh: CGFloat = 8
    @Environment(Session.self) private var session
    var body: some View {
        ZStack {
            Rectangle().fill(.ultraThinMaterial).environment(\.colorScheme, .dark)
            Theme.soot.opacity(0.86)
            VStack(spacing: 0) {
                Text("The game is paused").font(Theme.book(tv ? 9 * vh : 34, fixed: tv)).foregroundStyle(Theme.tallow).padding(.vertical, 6)
                Text(me?.director == true ? "Every clock has stopped. Carry on when the table is ready." : "The clocks have stopped. " + (v.director?.name ?? "The host") + " will carry on in a moment.")
                    .font(Theme.ui(tv ? 3.2 * vh : 18, fixed: tv)).foregroundStyle(Theme.tallow2).padding(.bottom, 12)
                if me?.director == true && !session.demo {
                    Button("Carry on") { session.act("pause", "off") }.btn(.fill, .big)
                    Spacer().frame(height: 10)
                    Button("Host tools") { session.tools = true }.btn(.ghost, .sm, fit: true)
                }
                // requests to come back in: the host's, and, once the host's phone has gone quiet, the host's own request
                // on everyone's (the server sends each phone only those it may answer)
                if !tv && !session.demo { ForEach(session.rejoin) { r in RejoinCard(r: r) }.multilineTextAlignment(.leading).padding(.top, 18) }
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: tv ? vh * 140 : 420)
            .padding(24)
        }
        .ignoresSafeArea()
    }
}

// the host's card: only the host's phone shows it (dirCard)
struct DirCard<Content: View>: View {
    @Environment(Session.self) private var session
    @ViewBuilder let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View {
        if session.view?.me?.director == true { Card(.dir) { content } }
    }
}

// "Waiting for the host", with a line to think about (waitHost)
struct WaitHost: View {
    let v: Snapshot
    private static let lines = ["Watch who talks the most.", "Someone here swore the Oath and didn’t mean it.", "A quiet player is a careful player.", "Nobody here is as calm as they look.", "Who looked away just then?"]
    var body: some View {
        if v.me?.director != true {
            Waiting(who: v.director?.name ?? "the host", line: WaitHost.lines[(v.round + v.phase.count) % WaitHost.lines.count])
        }
    }
}

struct Tally: View {
    let n: Int
    let of: Int
    let word: String
    var body: some View { Small("\(n) of \(of) \(word)").padding(.top, 10) }
}

// drawn to a picture (a Debug build's -render-all): no scrolling, the whole page at once
private struct RenderingKey: EnvironmentKey { static let defaultValue = false }
extension EnvironmentValues {
    var rendering: Bool {
        get { self[RenderingKey.self] }
        set { self[RenderingKey.self] = newValue }
    }
}
