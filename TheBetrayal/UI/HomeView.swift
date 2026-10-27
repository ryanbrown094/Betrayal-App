import SwiftUI

// What the start screen opens: a Table, and how (as a player, as a player joining with the name saved on this phone,
// as the host setting it up, or as the TV)
struct Target: Hashable {
    enum Start: Hashable { case play, named, create, bots, practice, tv }
    let room: String
    var start: Start = .play
    var pass: String? = nil
}

// The start screen's own screens, before a Table
enum Route: Hashable { case join, host, passes, tv, table(Target) }

// The start screen: two choices, join a Table or host one, and the rest underneath (practice, the passes, how to play,
// the questions, setting up a TV). Joining takes a Table's code (typed, scanned or from a link) and a name; hosting opens
// a Table, free or with a pass. The same calls as the website's home page (site/index.html: open, go, subChoice); buying is the App Store's
// (Model/Shop.swift).
struct HomeView: View {
    @State private var path: [Route] = []
    @State private var scanning = false
    @State private var page: Page?
    @State private var intro: Intro?
    @AppStorage("bt-intro") private var introSeen = false
    private var shop: Shop { Shop.shared }
    private let model = AppModel.shared
    @State private var tableCode = ""
    @State private var playerName = UserDefaults.standard.string(forKey: "bt-name") ?? ""
    @State private var bookingCode = ""
    @State private var busy = false
    @State private var problem: String?
    @State private var question: Question?
    @State private var recent = Recent.room
    @Environment(\.openURL) private var openURL

    // the premise, before this phone's first game (then: the Table it was about to open), or from How to play
    struct Intro: Identifiable {
        let id = UUID()
        var then: (() -> Void)? = nil
    }

    enum Question {
        case regular(room: String, pass: String) // a pass whose last game is still open
        case test(room: String, pass: String)    // the master code's test Table
        case usePass(pass: String, host: Bool, until: Date?) // starting a game with a pass on the phone (a Night Pass's end, once begun)
        var title: String {
            switch self {
            case .regular: return "You have a game open"
            case .test: return "A test Table"
            case .usePass: return "Make tonight ad-free?"
            }
        }
        var message: String {
            switch self {
            case .regular: return "Carry on with it, or start a new one? A new game closes the one that’s open."
            case .test: return "Play Modern with real phones, or against bots that play by themselves."
            case .usePass(_, let host, let until):
                if host { return "Your Host Pass makes this game ad-free, with every Trial." }
                if let until { return "Your Night Pass makes this game ad-free, with every Trial. Its 24 hours run until " + until.formatted(date: .omitted, time: .shortened) + "." }
                return "Your Night Pass makes tonight ad-free, with every Trial. Its 24 hours start now."
            }
        }
    }

    var body: some View {
        NavigationStack(path: $path) {
            home
                .navigationDestination(for: Route.self) { r in
                    switch r {
                    case .join: screen { joinScreen }
                    case .host: screen { hostScreen }
                    case .passes: screen { passesScreen }
                    case .tv: screen { tvScreen }
                    case .table(let t): TableView(session: AppModel.shared.session(for: t))
                    }
                }
        }
        .onChange(of: path) { _, now in if now.isEmpty { recent = Recent.room } }
        .onAppear {
            shop.start(); follow(model.link); Task { await shop.refresh() }
            Ads.shared.checkChoices()
            #if DEBUG
            if let r = Demo.screen, path.isEmpty { path = [r] }
            #endif
        }
        .onChange(of: model.link) { _, room in follow(room) }
        .sheet(isPresented: $scanning) { ScanSheet { room in tableCode = room; joinTable() } }
        .sheet(item: $page) { p in PageView(page: p) { page = nil } }
        .sheet(item: Binding(get: { shop.bought }, set: { shop.bought = $0 })) { b in BoughtSheet(bought: b, open: openCode) }
        .fullScreenCover(item: $intro) { i in
            IntroView(ready: i.then == nil ? "Done" : "Let’s play") {
                introSeen = true
                intro = nil
                i.then?()
            }
        }
        .alert("Your pass", isPresented: Binding(get: { shop.problem != nil }, set: { if !$0 { shop.problem = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(shop.problem ?? "") }
        .confirmationDialog(question?.title ?? "", isPresented: Binding(get: { question != nil }, set: { if !$0 { question = nil } }), titleVisibility: .visible, presenting: question) { q in
            switch q {
            case .regular(let room, let pass):
                Button("Carry on") { Task { await go(room: room, pass: pass, test: false) } }
                Button("Start a new game", role: .destructive) { Task { await open(pass: pass, fresh: true) } }
            case .usePass(let pass, let host, _):
                Button(host ? "Use my Host Pass" : "Use my Night Pass") { Task { await open(pass: pass, fresh: false) } }
                Button("Start a free game instead") { Task { await open(pass: nil, fresh: false) } }
            case .test(let room, let pass):
                Button("Play Modern") { enter(Target(room: room, start: .create, pass: pass)) }
                Button("Play against bots") { enter(Target(room: room, start: .bots, pass: pass)) }
            }
        } message: { q in Text(q.message) }
        .alert("That didn’t work", isPresented: Binding(get: { problem != nil }, set: { if !$0 { problem = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(problem ?? "") }
    }

    // a phone's height of start screen, or more if the words are large
    private var home: some View {
        GeometryReader { g in
            ScrollView {
                Column {
                    header(crest: g.size.height >= 700)
                    if let recent { tonight(recent) }
                    VStack(spacing: 12) {
                        Button("Join a game") { path.append(.join) }.btn(.fill, .big)
                        Button("Host a game") { path.append(.host) }.btn(.ghost, .big)
                    }
                    .padding(.bottom, 26)
                    menu(short: g.size.height < 700)
                    footer
                }
                .frame(minHeight: g.size.height)
            }
        }
        .background(Backdrop())
        .toolbar(.hidden, for: .navigationBar)
    }

    // joining, hosting and the passes: a page each, with the system's back button
    private func screen<C: View>(@ViewBuilder _ content: @escaping () -> C) -> some View {
        ScrollView { Column { Live(content: content) } }
            .scrollDismissesKeyboard(.interactively)
            .background(Backdrop())
            .toolbar(.visible, for: .navigationBar)
            .navigationBarTitleDisplayMode(.inline)
    }

    // a short phone (an iPhone SE) leaves the crest out, so the choices fit without scrolling
    private func header(crest: Bool) -> some View {
        VStack(spacing: 8) {
            if crest { Crest().frame(width: 76, height: 88).foregroundStyle(Theme.brass2) }
            Text("The Betrayal").font(Theme.disp(48)).foregroundStyle(Theme.brass2)
            Text("Everyone swore an oath. Not everyone meant it.").font(Theme.bookItalic(20)).foregroundStyle(Theme.tallow).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 12).padding(.bottom, 28)
    }

    private func tonight(_ room: String) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 0) {
                Eyebrow("tonight")
                Text("Table \(room)").font(Theme.book(22)).foregroundStyle(Theme.tallow)
            }
            Spacer(minLength: 0)
            Button("Back to the game") { enter(Target(room: room)) }.btn(.on, .sm, fit: true)
        }
        .padding(.vertical, 10).padding(.horizontal, 14)
        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Theme.brass, lineWidth: 1))
        .padding(.bottom, 18)
    }

    // (a short phone's rows are a little lower, so the start screen still fits without scrolling)
    private func menu(short: Bool) -> some View {
        VStack(spacing: 0) {
            row("raven", busy ? "Opening…" : "Practice against bots", short: short) { if !busy { Task { await practise() } } }
            row("key", "Your passes", short: short) { path.append(.passes) }
            row("eye", "Set up a TV", short: short) { path.append(.tv) }
            row("scroll", "How to play", short: short) { intro = Intro() }
            row("candle", "FAQs", short: short) { page = .faq }
        }
        .overlay(alignment: .top) { Rectangle().fill(Theme.rule).frame(height: 1) }
    }

    private func row(_ icon: String, _ title: String, short: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Icon(name: icon).frame(width: 24, height: 24).foregroundStyle(Theme.brass2)
                Text(title).font(Theme.ui(18, .bold)).foregroundStyle(Theme.tallow)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.tallow2)
            }
            .frame(minHeight: short ? 42 : 50)
            .contentShape(Rectangle())
            .overlay(alignment: .bottom) { Rectangle().fill(Theme.rule).frame(height: 1) }
        }
        .buttonStyle(.plain)
    }

    private var footer: some View {
        Flow(spacing: 20, lineSpacing: 0, center: true) {
            link("Terms") { page = .terms }
            link("Privacy") { page = .privacy }
            link("Contact us") { openURL(URL(string: "mailto:" + Page.contact)!) }
            link("Report an ad") { openURL(Page.reportAd) }
            if Ads.shared.choicesNeeded { link("Ad choices") { Ads.shared.showChoices() } }
        }
        .padding(.top, 10)
    }

    private func link(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(Theme.ui(15)).foregroundStyle(Theme.tallow2).padding(.vertical, 12).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // the Table's code and this player's name, together: one screen, then the Table
    private var joinScreen: some View {
        VStack(alignment: .leading, spacing: 0) {
            H1("Join a game")
            Sub("Type the Table code from the host’s phone or the TV, or scan its QR code.")
            VStack(alignment: .leading, spacing: 10) {
                Field(placeholder: "ABC123", text: $tableCode, code: true, submit: joinTable)
                Label2("Your name")
                Field(placeholder: "As the table knows you", text: $playerName, max: 14, submit: joinTable)
                Button("Join", action: joinTable).btn(.fill, .big)
                    .disabled(!Codes.isRoom(tableCode) || playerName.trimmingCharacters(in: .whitespaces).isEmpty)
                Button("Scan a QR code") { scanning = true }.btn(.ghost)
            }
            Button("Setting up a TV instead?") { path.append(.tv) }.btn(.dark, .sm).padding(.top, 24)
        }
    }

    // an iPad or a spare phone as the TV, or the host's phone over AirPlay
    private var tvScreen: some View {
        VStack(alignment: .leading, spacing: 0) {
            H1("Set up a TV")
            Sub("The TV shows the game to the whole room: the Table, the Trials, the votes and the reveals, with music. Never anyone’s role. It’s optional.")
            Label2("This screen as the TV")
            Small("On an iPad or a spare phone: connect it to the TV with a cable or AirPlay, or stand it where everyone can see it. Type the Table code from the host’s phone.")
            VStack(spacing: 10) {
                Field(placeholder: "ABC123", text: $tableCode, code: true, submit: watchTable)
                Button("Use this screen as the TV", action: watchTable).btn(.fill, .big).disabled(!Codes.isRoom(tableCode))
            }
            Label2("Or the host’s phone").padding(.top, 26)
            Small("AirPlay the host’s phone to the TV (Control Centre, then Screen Mirroring). While the game is open, the TV shows the game, not the phone’s screen.")
        }
    }

    private var hostScreen: some View {
        VStack(alignment: .leading, spacing: 0) {
            H1("Host a game")
            Sub("Start a Table on this phone. You play too, and your phone moves the evening on; everyone else joins on their own phone with the Table’s code. It stays open for 48 hours. Best with 8 to 16 players.")
            Label2("Your name")
            Field(placeholder: "As the table knows you", text: $playerName, max: 14, submit: startGame)
            Spacer().frame(height: 10)
            Button(busy ? "Opening…" : shop.usable.isEmpty ? "Start a free game" : "Start a game", action: startGame).btn(.fill, .big)
                .disabled(busy || playerName.trimmingCharacters(in: .whitespaces).isEmpty)
            Small("Free games show a short ad as each Reckoning opens and at the end, never during a Trial or a vote, and use the base set of Trials. A pass makes the night ad-free, with every Trial.").padding(.top, 10)
            YourCodes(open: openCode)
            Button(shop.codes.isEmpty ? "Make it ad-free with a pass" : "Buy or restore a pass") { path.append(.passes) }.btn(.ghost)
        }
    }

    private var passesScreen: some View {
        VStack(alignment: .leading, spacing: 0) {
            H1("Your passes")
            if shop.codes.isEmpty { Sub("None on this phone yet. A pass you buy appears here.") }
            YourCodes(open: openCode)
            BookCard(open: openCode, show: { page = $0 })
        }
    }

    // into a Table: the first time on this phone, the premise first (not for a TV, which plays no part)
    private func enter(_ t: Target) {
        if introSeen || t.start == .tv { path.append(.table(t)) }
        else { intro = Intro(then: { path.append(.table(t)) }) }
    }

    // a Table from a link (thebetrayal://join/CODE: the TV's QR code, read by the phone's own camera)
    private func follow(_ room: String?) {
        guard let room else { return }
        model.link = nil
        path = []
        tableCode = room
        joinTable()
    }

    // one person and the bots (the server's practice games)
    private func practise() async {
        busy = true
        defer { busy = false }
        do {
            let t = try await API.open(pass: nil, fresh: false, practice: true)
            enter(Target(room: t.room, start: .practice))
        } catch { problem = error.localizedDescription }
    }

    private func openCode(_ pass: String) {
        bookingCode = pass
        hostTable()
    }

    // with a name, straight in; without one (a scanned code, a link), the Table asks for it
    private func joinTable() {
        guard Codes.isRoom(tableCode) else { return }
        let room = tableCode, name = playerName.trimmingCharacters(in: .whitespaces)
        if !name.isEmpty { UserDefaults.standard.set(name, forKey: "bt-name") }
        Task {
            if await API.mode(of: room) == .classic { problem = "This Table can’t be played in the app. Ask the host to start a new Table in the app."; return }
            enter(Target(room: room, start: name.isEmpty ? .play : .named))
        }
    }

    private func watchTable() {
        guard Codes.isRoom(tableCode) else { return }
        enter(Target(room: tableCode, start: .tv))
    }

    private func hostTable() {
        let pass = bookingCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard pass.count >= 4, !busy else { return }
        Task { await open(pass: pass, fresh: false) }
    }

    // with a pass on the phone, the host is asked whether to use it tonight
    private func startGame() {
        let name = playerName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty, !busy else { return }
        UserDefaults.standard.set(name, forKey: "bt-name")
        if let p = shop.usable.first {
            let st = shop.status[p.pass]
            question = .usePass(pass: p.pass, host: p.sub == true, until: st?.state == "active" ? st?.until : nil)
        }
        else { Task { await open(pass: nil, fresh: false) } }
    }

    // a pass's code, or none for a free game
    private func open(pass: String?, fresh: Bool) async {
        busy = true
        defer { busy = false }
        do {
            let t = try await API.open(pass: pass, fresh: fresh)
            if let pass {
                if !t.test { shop.remember(pass) }
                if t.again { question = .regular(room: t.room, pass: pass); return }
            }
            await go(room: t.room, pass: pass, test: t.test)
            Task { await shop.refresh() }
        } catch { problem = error.localizedDescription }
    }

    // a Table plays Modern or Classic, chosen once; the app plays Modern, so a new Table is set up as Modern
    private func go(room: String, pass: String?, test: Bool) async {
        switch await API.mode(of: room) {
        case .modern: enter(Target(room: room))
        case .classic: problem = "This Table can’t be played in the app. Ask the host to start a new Table in the app."
        case .unset: if test, let pass { question = .test(room: room, pass: pass) } else { enter(Target(room: room, start: .create, pass: pass)) }
        }
    }
}

// a pushed screen's words, drawn in a body of their own so that what they read from the shop (an @Observable) keeps them
// up to date
private struct Live<Content: View>: View {
    let content: () -> Content
    var body: some View { content() }
}

// The premise in five screens: before this phone's first game, and from How to play
struct IntroView: View {
    let ready: String // the last screen's button
    let done: () -> Void
    @State private var at: Int
    @State private var rules = false

    init(start: Int = 0, ready: String, done: @escaping () -> Void) {
        self.ready = ready
        self.done = done
        _at = State(initialValue: start)
    }

    private struct Step { let seals: [(BigSeal.Kind, String)]; let eyebrow: String; let title: String; let text: String }
    private static let steps = [
        Step(seals: [(.forsworn, "blade"), (.loyal, "candle")], eyebrow: "the oath", title: "Everyone swears an oath. Not everyone means it.",
             text: "A few of you are secretly **Forsworn**, and know each other. Everyone else is **Loyal**, and knows nothing. Your role is on your phone, for your eyes only."),
        Step(seals: [(.loyal, "chalice")], eyebrow: "by day", title: "Play for the Purse",
             text: "Each round opens with a Trial on your phones: a quiz, a guessing game, charades and more. Trials fill a shared Purse, and most give their winner **Sanctuary**, safe from that night’s poison. The Forsworn play along, and quietly sabotage."),
        Step(seals: [(.steel, "scales")], eyebrow: "the reckoning", title: "Argue, accuse, vote",
             text: "A few minutes of open debate, then everyone votes in secret. The player with the most votes is exiled, and the table learns what they were: Forsworn, or Loyal."),
        Step(seals: [(.forsworn, "moon")], eyebrow: "by night", title: "The Forsworn choose",
             text: "Heads down. The Forsworn pick someone to poison, and everyone else taps a name too, so nobody can tell who’s choosing. The exiled and the poisoned stay on as **Ghosts**, watching."),
        Step(seals: [(.loyal, "crown")], eyebrow: "the end", title: "Who takes the Purse?",
             text: "The Loyal win if every Forsworn is gone by the end, and share the Purse they built. If even one Forsworn survives, they take what the Purse fell short. Don’t worry about remembering it all: your phone tells you what to do, when."),
    ]

    var body: some View {
        let last = IntroView.steps.count - 1
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button(ready == "Done" ? "Close" : "Skip", action: done).btn(.dark, .sm, fit: true)
            }
            TabView(selection: $at) {
                ForEach(IntroView.steps.indices, id: \.self) { i in step(IntroView.steps[i]).tag(i) }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            HStack(spacing: 8) {
                ForEach(IntroView.steps.indices, id: \.self) { i in Circle().fill(i == at ? Theme.brass2 : Theme.edge).frame(width: 8, height: 8) }
            }
            .padding(.vertical, 18)
            .accessibilityHidden(true)
            Button(at < last ? "Next" : ready) { if at < last { withAnimation { at += 1 } } else { done() } }.btn(.fill, .big)
            Button("Read the full rules") { rules = true }.btn(.ghost, .sm).padding(.top, 10)
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .frame(maxWidth: 520)
        .frame(maxWidth: .infinity)
        .background(Backdrop())
        .sheet(isPresented: $rules) { PageView(page: .rules) { rules = false } }
    }

    private func step(_ s: Step) -> some View {
        GeometryReader { g in
            ScrollView {
                VStack(spacing: 0) {
                    HStack(spacing: 14) {
                        ForEach(s.seals.indices, id: \.self) { i in BigSeal(kind: s.seals[i].0, icon: s.seals[i].1).frame(width: 128, height: 128) }
                    }
                    .padding(.bottom, 24)
                    Eyebrow(s.eyebrow)
                    Text(s.title).font(Theme.book(32)).foregroundStyle(Theme.tallow)
                        .fixedSize(horizontal: false, vertical: true).padding(.bottom, 14)
                    rich(s.text, size: 19).font(Theme.ui(19)).foregroundStyle(Theme.tallow2).lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: g.size.height)
            }
        }
    }
}

// a pass's code: OATH-XXXX-XXXX, typed any way
struct BookingField: View {
    @Binding var text: String
    let submit: () -> Void
    var body: some View {
        TextField("", text: $text, prompt: Text("OATH-XXXX-XXXX").foregroundColor(Theme.tallow2.opacity(0.45)))
            .font(Theme.ui(24, .bold)).tracking(2).multilineTextAlignment(.center)
            .textInputAutocapitalization(.characters).autocorrectionDisabled().keyboardType(.asciiCapable)
            .submitLabel(.go).onSubmit(submit)
            .foregroundStyle(Theme.tallow).tint(Theme.brass2)
            .padding(.horizontal, 12).frame(minHeight: 58)
            .background(RoundedRectangle(cornerRadius: 4).fill(Theme.field))
            .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Theme.edge, lineWidth: 1))
            .onChange(of: text) { _, v in
                let clean = String(v.uppercased().filter { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-") }.prefix(24))
                if clean != v { text = clean }
            }
    }
}
