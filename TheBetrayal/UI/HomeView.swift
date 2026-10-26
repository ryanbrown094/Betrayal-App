import SwiftUI

// What the start screen opens: a Table, and how (as a player, as the host setting it up, or as the TV)
struct Target: Hashable {
    enum Start: Hashable { case play, create, bots, tv }
    let room: String
    var start: Start = .play
    var pass: String? = nil
}

// The start screen: join a Table with its code (typed, scanned or from a link), open your own with a booking code, or
// book one. The same calls as the website's home page (site/index.html: open, go, subChoice); booking is the App
// Store's (Model/Shop.swift).
struct HomeView: View {
    @State private var path: [Target] = []
    @State private var scanning = false
    @State private var page: Page?
    private var shop: Shop { Shop.shared }
    private let model = AppModel.shared
    @State private var tableCode = ""
    @State private var bookingCode = ""
    @State private var busy = false
    @State private var problem: String?
    @State private var question: Question?
    @State private var recent = Recent.room

    enum Question {
        case regular(room: String, pass: String) // a pass whose last game is still open
        case test(room: String, pass: String)    // the master code's test Table
        case usePass(pass: String, host: Bool)   // starting a game with a pass on the phone
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
            case .usePass(_, let host): return host ? "Your Host Pass makes this game ad-free, with every Trial." : "Your Night Pass makes tonight ad-free, with every Trial. Its 24 hours start now."
            }
        }
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollViewReader { proxy in
                ScrollView {
                    Column {
                        header
                        if let recent { tonight(recent) }
                        join
                        host.id("host")
                        BookCard(open: openCode, show: { page = $0 }).id("book")
                        footer
                    }
                }
                .onAppear {
                    #if DEBUG
                    if let a = Demo.scroll { DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { proxy.scrollTo(a, anchor: .top) } }
                    #endif
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Backdrop())
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Target.self) { t in TableView(session: AppModel.shared.session(for: t)) }
        }
        .onChange(of: path) { _, now in if now.isEmpty { recent = Recent.room } }
        .onAppear { shop.start(); follow(model.link); Task { await shop.refresh() } }
        .onChange(of: model.link) { _, room in follow(room) }
        .sheet(isPresented: $scanning) { ScanSheet { room in tableCode = room; joinTable() } }
        .sheet(item: $page) { p in PageView(page: p) { page = nil } }
        .sheet(item: Binding(get: { shop.bought }, set: { shop.bought = $0 })) { b in BoughtSheet(bought: b, open: openCode) }
        .alert("Booking", isPresented: Binding(get: { shop.problem != nil }, set: { if !$0 { shop.problem = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(shop.problem ?? "") }
        .confirmationDialog(question?.title ?? "", isPresented: Binding(get: { question != nil }, set: { if !$0 { question = nil } }), titleVisibility: .visible, presenting: question) { q in
            switch q {
            case .regular(let room, let pass):
                Button("Carry on") { Task { await go(room: room, pass: pass, test: false) } }
                Button("Start a new game", role: .destructive) { Task { await open(pass: pass, fresh: true) } }
            case .usePass(let pass, let host):
                Button(host ? "Use my Host Pass" : "Use my Night Pass") { Task { await open(pass: pass, fresh: false) } }
                Button("Start a free game instead") { Task { await open(pass: nil, fresh: false) } }
            case .test(let room, let pass):
                Button("Play Modern") { path.append(Target(room: room, start: .create, pass: pass)) }
                Button("Play against bots") { path.append(Target(room: room, start: .bots, pass: pass)) }
            }
        } message: { q in Text(q.message) }
        .alert("That didn’t work", isPresented: Binding(get: { problem != nil }, set: { if !$0 { problem = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(problem ?? "") }
    }

    private var header: some View {
        VStack(spacing: 10) {
            Crest().frame(width: 96, height: 112).foregroundStyle(Theme.brass2)
            Text("The Betrayal").font(Theme.disp(52)).foregroundStyle(Theme.brass2)
            Text("Everyone swore an oath. Not everyone meant it.").font(Theme.bookItalic(21)).foregroundStyle(Theme.tallow).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 30).padding(.bottom, 26)
    }

    private func tonight(_ room: String) -> some View {
        Card {
            Eyebrow("tonight")
            H2("Table \(room)")
            Sub("Your last Table is still open.")
            Button("Back to the game") { path.append(Target(room: room)) }.btn(.fill)
        }
    }

    private var join: some View {
        Card {
            Eyebrow("play")
            H2("Join a game")
            Sub("Type the Table code from the host’s phone or the TV, or scan the TV’s code.")
            VStack(spacing: 10) {
                Field(placeholder: "ABC123", text: $tableCode, code: true, submit: joinTable)
                Button("Join", action: joinTable).btn(.fill).disabled(!Codes.isRoom(tableCode))
                Button("Scan the TV’s code") { scanning = true }.btn(.ghost)
                Button("Use this screen as the TV") { if Codes.isRoom(tableCode) { path.append(Target(room: tableCode, start: .tv)) } }
                    .btn(.ghost, .sm).disabled(!Codes.isRoom(tableCode))
            }
        }
    }

    private var host: some View {
        Card {
            Eyebrow("host")
            H2("Host a game")
            Sub("Start a Table, free, and everyone joins on their own phone with its code. It stays open for 48 hours.")
            Button(busy ? "Opening…" : "Start a free game", action: startGame).btn(.fill).disabled(busy)
            Small("Free games show an ad between rounds, never while you play, and use the base set of Trials. A pass makes the night ad-free, with every Trial.").padding(.top, 10)
            YourCodes(open: openCode)
            VStack(spacing: 10) {
                Label2("Have a pass? Type its code")
                BookingField(text: $bookingCode, submit: hostTable)
                Button(busy ? "Opening…" : "Start an ad-free game", action: hostTable).btn(.ghost).disabled(busy || bookingCode.count < 4)
            }
        }
    }

    private var footer: some View {
        VStack(spacing: 12) {
            Small("Everyone plays on their own phone, the host included. Best with 8 to 16 players.", center: true)
            Flow(spacing: 8, center: true) {
                Button("How to play") { page = .rules }.btn(.dark, .sm, fit: true)
                Button("Terms") { page = .terms }.btn(.dark, .sm, fit: true)
                Button("Privacy") { page = .privacy }.btn(.dark, .sm, fit: true)
                Link("Contact us", destination: URL(string: "mailto:" + Page.contact)!).btn(.dark, .sm, fit: true)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }

    // a Table from a link (thebetrayal://join/CODE: the TV's QR code, read by the phone's own camera)
    private func follow(_ room: String?) {
        guard let room else { return }
        model.link = nil
        path = []
        tableCode = room
        joinTable()
    }

    private func openCode(_ pass: String) {
        bookingCode = pass
        hostTable()
    }

    private func joinTable() {
        guard Codes.isRoom(tableCode) else { return }
        let room = tableCode
        Task {
            if await API.mode(of: room) == .classic { problem = "This Table plays Classic, which the app doesn’t play."; return }
            path.append(Target(room: room))
        }
    }

    private func hostTable() {
        let pass = bookingCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard pass.count >= 4, !busy else { return }
        Task { await open(pass: pass, fresh: false) }
    }

    // with a pass on the phone, the host is asked whether to use it tonight
    private func startGame() {
        if let p = shop.usable.first { question = .usePass(pass: p.pass, host: p.sub == true) }
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
        case .modern: path.append(Target(room: room))
        case .classic: problem = "This Table is set up for Classic, which the app doesn’t play. Only a new Table can be played in the app."
        case .unset: if test, let pass { question = .test(room: room, pass: pass) } else { path.append(Target(room: room, start: .create, pass: pass)) }
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
