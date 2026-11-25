import SwiftUI

// Each moment of the evening on a phone (phase() in src/modern-ui.js), with the page's words.
struct PhaseView: View {
    let v: Snapshot
    let me: Me
    var body: some View {
        switch v.phase {
        case "lobby": LobbyView(v: v, me: me)
        case "oath": OathView(v: v, me: me)
        case "roles": RoleCard(v: v, me: me)
        case "day": DayView(v: v, me: me)
        case "trial": TrialView(v: v, me: me)
        case "break": BreakView(v: v)
        case "talk": TalkView(v: v, me: me)
        case "vote": VoteView(v: v, me: me)
        case "reveal": RevealView(v: v, me: me)
        case "night": NightView(v: v, me: me)
        case "dawn": DawnView(v: v, me: me)
        case "trust": TrustView(v: v, me: me)
        case "unmask": VStack(alignment: .leading, spacing: 0) { Eyebrow("the unmasking"); H1("Who were they?"); Sub("Every player still in has their role revealed, one at a time."); UnmaskList(v: v) }
        case "honour": HonourView(v: v, me: me)
        case "end": EndView(v: v, me: me)
        default: EmptyView()
        }
    }
}

struct LobbyView: View {
    let v: Snapshot
    let me: Me
    @Environment(Session.self) private var session
    @State private var prize = ""
    @State private var tier1 = ""
    @State private var tier2 = ""
    @State private var loaded = false
    @State private var passing = false
    @FocusState private var focus: String?

    var body: some View {
        let n = v.players.count
        let o = v.opts
        VStack(alignment: .leading, spacing: 0) {
            H2("You’re in")
            // the code, its QR code and Share on every phone, so anyone can bring in a late guest
            if v.practice { Sub("Just you and the bots tonight.") } else { CodeCard(room: session.room) }
            People(list: v.players)
            Small(Words.plural(n, "player") + " joined so far. A game needs 8 to 24 players.").padding(.top, 10)
            if !me.director { WaitHost(v: v) } else {
                LobbyOffer(v: v)
                if v.test || v.practice {
                    Banner(.plain, v.practice ? "This is a practice game. The bots play every part themselves, and the clocks are shorter than usual. Start when you’re ready." : "This is a test game. The bots play themselves, the Trials give random scores, and every countdown lasts ten seconds at most.")
                    if n < (v.practice ? 16 : 24) { Button("Add a bot") { session.act("bots", String(n + 1)) }.btn(.dark, .sm, fit: true).padding(.bottom, 14) }
                }
                Card(.dir) {
                    H2("Before you start", sec: true, first: true)
                    Label2("Sanctuary")
                    two("shield", ("secret", "Secret"), ("public", "Public"), on: o?.shield)
                    Small("Sanctuary is the usual prize for winning a Trial. Whoever holds it can’t be poisoned that night. " + (o?.shield == "public" ? "With Public, everyone is told who has it." : "With Secret, only the winner knows they have it. A Forsworn who wins gets nothing, and their phone tells them so.")).padding(.top, 6)
                    Label2("The prize")
                    Field(placeholder: "", text: $prize, max: 80, submit: sendPrize).focused($focus, equals: "prize")
                    if o?.coins == true { Small("The winners get one chocolate coin for every 100 points they win from the Purse, the prize pot that the Trials fill up.").padding(.top, 6) }
                    More("Better prizes for a fuller Purse", open: !(o?.prizes.isEmpty ?? true)) {
                        Small("This is optional. The Loyal get the better prize if they win with the Purse at least half full, and the best if it’s full. For the Forsworn it works the other way round: at least half empty, or completely empty. Nobody sees these prizes until the end.")
                        Label2("At a half-full Purse")
                        Field(placeholder: "e.g. a big box of chocolates", text: $tier1, max: 80, submit: sendTiers).focused($focus, equals: "tier1")
                        Spacer().frame(height: 8)
                        Label2("At a full Purse")
                        Field(placeholder: "e.g. dinner out", text: $tier2, max: 80, submit: sendTiers).focused($focus, equals: "tier2")
                    }
                    Label2("Twists").padding(.top, 12)
                    two("twists", (true, "On"), (false, "Off"), on: o?.twists)
                    Small(o?.twists == true ? "Twists are special prizes and choices that each happen once in the game: the Casting Vote, the Temptation, the Crown, and the Confessor in the final. Each one is explained when it comes up." : "With twists off, the game is simpler, which is good for a first game.").padding(.top, 6)
                    // a practice game can't be made ad-free: a pass is for a real night
                    if !v.locked.isEmpty && !v.practice {
                        Label2("Trials").padding(.top, 12)
                        Small("A free game plays 8 of the 15 Trials, uses half of the questions, and shows ads. A pass removes the ads for everyone and adds these Trials:").padding(.top, 2)
                        Flow(spacing: 6) { ForEach(v.locked, id: \.self) { LockedTrial(title: $0) } }.padding(.bottom, 10)
                        Button("Make it ad-free with a pass") { passing = true }.btn(.ghost, .sm, fit: true)
                    }
                    Spacer().frame(height: 12)
                    Button(n < 8 ? "Waiting for \(8 - n) more" : "Start with \(n) players") {
                        session.confirm("Start the game? Nobody else can join after this.", yes: "Start") { session.act("start") }
                    }
                    .btn(.fill, .big).disabled(n < 8)
                    if !v.practice {
                        Small(Text("A TV is optional. To use one, AirPlay this phone to it. The TV shows the game for everyone, never your own screen. You can also use an iPad as the TV: tap ") + b("Set up a TV", size: 15) + Text(" on the start screen."), center: true).padding(.top, 12)
                    }
                }
            }
            if !v.practice { ReportLink() }
        }
        .onAppear(perform: load)
        .sheet(isPresented: $passing) { UsePassSheet(use: session.upgrade) }
        .onChange(of: focus) { was, _ in if was == "prize" { sendPrize() } else if was == "tier1" || was == "tier2" { sendTiers() } }
    }

    private func load() {
        guard !loaded, let o = v.opts else { return }
        loaded = true; prize = o.prize ?? ""; tier1 = o.tier(0.5); tier2 = o.tier(1)
    }
    private func sendPrize() { if prize != (v.opts?.prize ?? "") { session.send(["a": "opts", "opts": ["prize": prize]]) } }
    private func sendTiers() {
        var list: [[String: Any]] = []
        let a = tier1.trimmingCharacters(in: .whitespaces), c = tier2.trimmingCharacters(in: .whitespaces)
        if !a.isEmpty { list.append(["at": 0.5, "what": a]) }
        if !c.isEmpty { list.append(["at": 1, "what": c]) }
        session.send(["a": "opts", "opts": ["prizes": list]])
    }
    private func two<T: Equatable>(_ k: String, _ a: (T, String), _ c: (T, String), on: T?) -> some View {
        HStack(spacing: 10) {
            Button(a.1) { session.send(["a": "opts", "opts": [k: a.0]]) }.btn(on == a.0 ? .on : .dark, .sm)
            Button(c.1) { session.send(["a": "opts", "opts": [k: c.0]]) }.btn(on == c.0 ? .on : .dark, .sm)
        }
    }
}

// the Table's code, large, and its QR code, for the room to show each other (there may be no TV to show it), and Share
struct CodeCard: View {
    let room: String
    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Eyebrow("the table code")
                Text(room).font(Theme.ui(40, .bold)).tracking(4).foregroundStyle(Theme.brass2).lineLimit(1).minimumScaleFactor(0.5)
                    .accessibilityLabel(room.map(String.init).joined(separator: " "))
                Text("To join, friends open The Betrayal app, tap Join a game, and type this code or scan the QR code.").font(Theme.ui(15)).foregroundStyle(Theme.tallow2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            QRBox(text: Server.joinLink(room)).frame(width: 118, height: 118).accessibilityHidden(true)
        }
        .padding(14)
        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Theme.brass, lineWidth: 1))
        .padding(.top, 2).padding(.bottom, 10)
        // for anyone still on their way
        ShareLink(item: "Join our game of The Betrayal! Open The Betrayal app, tap Join a game and type " + room + ". Or open this link: " + Server.joinLink(room)) {
            Text("Share the code")
        }
        .btn(.dark, .sm, fit: true)
        .padding(.bottom, 14)
    }
}

struct OathView: View {
    let v: Snapshot
    let me: Me
    @Environment(Session.self) private var session
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if me.optIn != nil {
                H2("Sworn")
                Sub("Your answer is in, and nobody else can see it. Waiting for everyone else to answer.")
                People(list: v.players, mark: { $0.optedIn })
                Tally(n: v.players.filter(\.optedIn).count, of: v.players.count, word: "sworn")
                if me.director { Small("If someone is stuck, open Tools to give out the roles without waiting.") }
            } else {
                Eyebrow("the oath")
                H2("Would you like to be Forsworn?")
                Sub("The Forsworn are the secret traitors. They lie all evening, secretly choose someone to poison each night, and try to win the prize for themselves. Nobody sees your answer. The game uses it when it chooses the roles, but it can’t always give everyone what they asked for.")
                VStack(spacing: 10) {
                    Button("Yes, make me Forsworn") { session.act("optin", "yes") }.btn(.fill)
                    Button("I’d rather be Loyal") { session.act("optin", "no") }.btn(.dark)
                    Button("Either way") { session.act("optin", "any") }.btn(.dark)
                }
            }
        }
    }
}

struct RoleCard: View {
    let v: Snapshot
    let me: Me
    @Environment(Session.self) private var session
    var body: some View {
        if me.acked {
            VStack(alignment: .leading, spacing: 0) {
                DoneLine("handshake", Text("You’ve seen your role. Waiting for everyone else to see theirs…"))
                Spacer().frame(height: 12)
                People(list: v.players, mark: { $0.acked })
                Tally(n: v.players.filter(\.acked).count, of: v.players.count, word: "ready")
            }
        } else if !session.rolePeek {
            Button { session.rolePeek = true } label: {
                VStack(spacing: 0) {
                    Eyebrow("your role")
                    H2("Hold your phone close")
                    Sub("Tap here when nobody can see your screen.")
                }
                .multilineTextAlignment(.center)
                .padding(20)
                .frame(maxWidth: .infinity, minHeight: 300)
                .background(Stripes())
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Theme.edge2, lineWidth: 1))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        } else {
            let f = me.forsworn
            VStack(spacing: 18) {
            Card(.role, center: true) {
                BigSeal(kind: f ? .forsworn : .loyal, icon: f ? "blade" : "candle").frame(width: 150, height: 150).padding(.bottom, 14)
                H1(f ? "Forsworn" : "Loyal", color: f ? Theme.blood2 : Theme.loyal)
                Sub(f ? "You took the Oath, but you never meant it. You are one of the Forsworn, the secret traitors. Each night, you and any other Forsworn choose someone to poison. By day, pretend to be Loyal and vote with the table. Reach the end without being caught to win the prize. You also win every point the Purse, the prize pot, falls short of its target, so quietly spoil the Trials."
                      : "You are true to the table. Somewhere among you are the Forsworn, the secret traitors. Win Trials to fill the Purse, the prize pot. Find the Forsworn and vote them out at the Reckoning, before they poison you. If the Loyal win, the survivors share the prize. If the Forsworn win, they take whatever the Purse falls short of its target.")
                if f {
                    if let allies = me.allies, !allies.isEmpty { Para(Text("Your fellow Forsworn: ") + b(allies.map(\.name).joined(separator: ", "))) }
                    else { Para("You are the only Forsworn. Trust nobody.") }
                }
            }
            .padding(.horizontal, 18)
            // under the card, as wide as every other button (as on Your role)
            Button("Got it. Hide my role") { session.rolePeek = false; session.act("ack") }.btn(.fill)
            }
        }
    }
}

// the veil over the role card: dark diagonal stripes
struct Stripes: View {
    var body: some View {
        Canvas { ctx, size in
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(hex: 0x140B15)))
            var x: CGFloat = -size.height
            while x < size.width + size.height {
                var p = Path()
                p.move(to: CGPoint(x: x, y: 0)); p.addLine(to: CGPoint(x: x + 14 * 1.414, y: 0))
                p.addLine(to: CGPoint(x: x + 14 * 1.414 - size.height, y: size.height)); p.addLine(to: CGPoint(x: x - size.height, y: size.height))
                p.closeSubpath()
                ctx.fill(p, with: .color(Color(hex: 0x170D18)))
                x += 28 * 1.414
            }
        }
    }
}

struct DayView: View {
    let v: Snapshot
    let me: Me
    @Environment(Session.self) private var session
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !v.final { Eyebrow("round \(v.round)") }
            H1(v.final ? "The final" : v.roundTrials > 0 ? "Back at the table" : "A new day")
            Sub(v.final ? "This is the last round. There’s no Sanctuary and no more nights. Anyone voted out now keeps their role secret until the end. Once everyone left trusts each other, the game ends." : "It’s daytime. Talk among yourselves and watch each other closely. The host starts the next part when everyone is ready.")
            People(list: v.players)
            Small(Text("Next: ") + b(v.next ?? "", size: 15) + Text(v.tiers ? ". How full the Purse is at the end decides the prize." : "")).padding(.top, 12)
            WaitHost(v: v)
            DirCard {
                VStack(spacing: 10) {
                    Button("Begin: " + (v.next ?? "next")) { session.act("next") }.btn(.fill, .big)
                    Button(v.practice ? "A short break first" : "A short break first · 10 min") { session.act("break", "interval") }.btn(.ghost, .sm)
                }
            }
        }
    }
}

struct BreakView: View {
    let v: Snapshot
    @Environment(Session.self) private var session
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Eyebrow("a break")
            H1(v.brk?.name ?? "A break")
            Clock(end: v.brk?.end, size: 56).padding(.bottom, 12)
            Sub("Take a short break. Eat, drink and plot quietly. The game carries on when the clock runs out, or when the host ends the break.")
            DirCard {
                HStack(spacing: 10) {
                    Button("+5 minutes") { session.act("brkMore") }.btn(.dark, .sm)
                    Button("End the break") { session.act("brkEnd") }.btn(.fill, .sm)
                }
            }
        }
    }
}

struct TalkView: View {
    let v: Snapshot
    let me: Me
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if me.director { BreakOffer(v: v) }
            Eyebrow("the reckoning" + (v.vote?.second == true ? " · the second exile" : ""))
            H1("Make your accusations")
            Clock(end: v.vote?.talkEnd, size: 56).padding(.bottom, 12)
            Sub((v.vote?.second == true ? "With so many still playing, a second person is exiled today. " : "This is the Reckoning. ") + "Talk about who you think is Forsworn. When the time is up, everyone votes in secret on their phone, and the person with the most votes is exiled from the game.")
            CrownCard(v: v, me: me)
        }
    }
}

struct CrownCard: View {
    let v: Snapshot
    let me: Me
    @Environment(Session.self) private var session
    var body: some View {
        if let immune = v.vote?.immune {
            Banner(.plain, icon: "crown", immune == me.id ? "You laid down the Crown, so nobody can exile you this Reckoning." : v.name(immune) + " laid down the Crown, so nobody can vote them out this time.")
        } else if me.crown {
            Card(.hot) {
                HStack(alignment: .top, spacing: 6) {
                    Icon(name: "crown").frame(width: 18, height: 18).foregroundStyle(Theme.tallow).padding(.top, 3)
                    Para("You hold the Crown. If you lay it down now, nobody can vote you out at this Reckoning. You can only do this once.")
                }
                Button("Lay down the Crown") { session.confirm("Lay down the Crown? Nobody can vote you out at this Reckoning, but you can’t use it again.", yes: "Lay it down") { session.act("crown") } }.btn(.dark)
            }
        }
    }
}

struct VoteView: View {
    let v: Snapshot
    let me: Me
    @Environment(Session.self) private var session
    var body: some View {
        let vote = v.vote
        VStack(alignment: .leading, spacing: 0) {
            Eyebrow("the reckoning" + (vote?.tie == true ? " · a tie: vote again" : ""))
            H1(me.alive ? "Who do you exile?" : "Call it, Ghost")
            Sub(line)
            if let end = vote?.voteEnd {
                HStack(alignment: .firstTextBaseline) { Text("Closes in").font(Theme.ui(15)).foregroundStyle(Theme.tallow2); Spacer(); Clock(end: end) }.padding(.bottom, 12)
            }
            CrownCard(v: v, me: me)
            if let mine = vote?.mine {
                DoneLine("scales", Text(me.alive ? "You voted " : "You called ") + b(v.name(mine)) + Text(".\n") + Text("You can change it until everyone has voted.").font(Theme.ui(15)))
                Spacer().frame(height: 12)
            }
            PickGrid(list: cands, on: { $0.id == vote?.mine }) { p in session.act("ballot", p.id) }
        }
    }
    private var cands: [Player] {
        let vote = v.vote
        return v.alive.filter { (p: Player) -> Bool in
            p.id != me.id && p.id != vote?.immune && (vote?.revote?.contains(p.id) ?? true)
        }.sorted { $0.name < $1.name }
    }
    private var line: String {
        let vote = v.vote
        var s = ""
        if let r = vote?.revote { s = "It’s a tie between " + Words.andList(r.map { v.name($0) }) + ", so vote again between them. " }
        s += me.alive ? "Tap the person you want to exile. Nobody sees who you voted for, only the totals." : "Ghosts don’t vote, but you can tap who you think will be exiled. If you’re right, the table will know."
        return s + " \(vote?.voted ?? 0) of \(vote?.of ?? 0) voted."
    }
}

struct RevealView: View {
    let v: Snapshot
    let me: Me
    @Environment(Session.self) private var session
    @State private var words = ""
    var body: some View {
        if let r = v.reveal {
            VStack(alignment: .leading, spacing: 0) {
                H1(r.name + " is exiled")
                Sub(r.counts.map { v.name($0.id) + " \($0.n)" }.joined(separator: " · "))
                if r.cast { Small("It was a tie, and the Casting Vote decided it.") } else if r.byLot { Small(r.counts.isEmpty ? "Nobody voted, so the game picked someone at random." : "It was a tie, so the game picked one of them at random.") }
                if r.secret { Para("This is the final, so their role stays secret until the end, and there are no last words.") }
                else if r.role == nil { Verdict(role: nil, wait: r.roleAt) }
                else {
                    Verdict(role: r.role, wait: nil)
                    if !r.called.isEmpty { Small("The Ghosts who guessed right: " + Words.andList(r.called), center: true) }
                }
                if let w = r.words { LastWords(name: r.name, words: w) }
                if me.id == r.id {
                    Banner(.ghost, icon: "ghost", "You’ve been voted out, so you’re a Ghost now. Please stay at the table. You can still watch and say who you think should go.")
                    if me.words == "" {
                        Card {
                            Label2("Your last words for the table, if you want to say something")
                            Field(placeholder: "One line for the table", text: $words, max: 140, submit: say)
                            Spacer().frame(height: 10)
                            Button("Say it", action: say).btn(.dark)
                        }
                    }
                }
                if r.role != nil || r.secret { DirCard { Button("Continue") { session.act("cont") }.btn(.fill) } }
            }
        }
    }
    private func say() {
        let t = words.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return session.say("Type something first.", error: true) }
        words = ""
        session.act("words", t)
    }
}

// the exile's seal, stamped (.verdict)
struct Verdict: View {
    let role: String?
    let wait: Double?
    var tv = false
    var vh: CGFloat = 8
    @State private var stamped = false
    @State private var breathe = false
    var body: some View {
        VStack(spacing: 6) {
            if let role {
                let f = role == "f"
                BigSeal(kind: f ? .forsworn : .loyal, icon: f ? "blade" : "candle").frame(width: tv ? 22 * vh : 120, height: tv ? 22 * vh : 120)
                Text(f ? "Forsworn" : "Loyal").font(Theme.disp(tv ? 9 * vh : 42, fixed: tv)).foregroundStyle(f ? Theme.blood2 : Theme.loyal)
                    .shadow(color: tv ? (f ? Color(hex: 0xEA5A8F, alpha: 0.45) : Color(hex: 0x5FA88F, alpha: 0.4)) : .clear, radius: 12)
            } else {
                BigSeal(kind: .steel, icon: "scales").frame(width: tv ? 22 * vh : 120, height: tv ? 22 * vh : 120)
                    .opacity(breathe ? 0.45 : 1).scaleEffect(breathe ? 0.94 : 1)
                    .onAppear { withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) { breathe = true } }
                HStack(spacing: 6) {
                    Text("They were…").font(Theme.book(tv ? 4 * vh : 22, fixed: tv)).foregroundStyle(Theme.tallow2)
                    if let wait, !tv { Clock(end: wait) }
                }
            }
        }
        .scaleEffect(role != nil && !stamped ? 1.35 : 1)
        .opacity(role != nil && !stamped ? 0 : 1)
        .onAppear { if role != nil { withAnimation(.spring(response: 0.5, dampingFraction: 0.55)) { stamped = true } } }
        .onChange(of: role) { _, r in if r != nil { stamped = false; withAnimation(.spring(response: 0.5, dampingFraction: 0.55)) { stamped = true } } }
        .frame(maxWidth: .infinity)
        .padding(.vertical, tv ? 0 : 16)
    }
}

struct NightView: View {
    let v: Snapshot
    let me: Me
    @Environment(Session.self) private var session
    var body: some View {
        let n = v.night
        VStack(alignment: .leading, spacing: 0) {
            Eyebrow("the night")
            H1("Heads down")
            if !me.alive {
                Sub("It’s night, and the Forsworn are secretly choosing who to poison. As a Ghost, just watch quietly.")
            } else {
                Sub("It’s night. The Forsworn are secretly choosing who to poison. Everyone taps a name, so nobody can tell who the Forsworn are. Keep your screen hidden.")
                if me.forsworn { forsworn(n) } else {
                    Para("Tap the person you suspect most. Nothing happens to them. Your tap just helps keep the Forsworn hidden.")
                    if n?.done == true { DoneLine("moon", Text("Done. Keep your head down until dawn, when you’ll find out who was poisoned.")) }
                    else { PickGrid(list: v.alive.filter { $0.id != me.id }) { _ in session.send(["a": "sleep"]) } }
                }
            }
        }
    }

    @ViewBuilder private func forsworn(_ n: Night?) -> some View {
        let kills = n?.kills ?? 1
        let votes = tally
        if me.split { Banner(.plain, "The Forsworn don’t agree yet. The night waits until you all choose the same. If the clock runs out first, whoever was chosen most is poisoned.") }
        Card(.hot) {
            Para(Text(kills > 1 ? "Choose \(kills) people to poison tonight. Every Forsworn must choose the same \(kills)." : "Choose who to poison tonight. Every Forsworn must choose the same person.")
                 + (me.sanct.isEmpty ? Text("") : Text(" ") + b(Words.andList(me.sanct)) + Text(me.sanct.count > 1 ? " hold Sanctuary, so they can’t be poisoned tonight." : " holds Sanctuary, so they can’t be poisoned tonight.")))
            ForEach(me.picks.filter { $0.name != me.name }, id: \.name) { p in
                Small(p.name + ": " + (p.picks.isEmpty ? "not chosen yet" : Words.andList(p.picks)))
            }
            Small("\(me.mine.count) of \(kills) chosen")
        }
        PickGrid(list: me.targets.map { v.player($0) }, on: { me.mine.contains($0.id) }, badge: { p in
            AnyView(HStack(spacing: 6) {
                // how many of the Forsworn chose them, as a small badge
                if let c = votes[p.name] {
                    Text("\(c)").font(Theme.ui(13, .bold, fixed: true)).foregroundStyle(Theme.ink).monospacedDigit()
                        .padding(.horizontal, 7).padding(.vertical, 2).background(Capsule().fill(Color(hex: 0xF3B7C4)))
                        .accessibilityLabel("chosen by \(c)")
                }
                if me.sanct.contains(p.name) { Text("Sanctuary").font(Theme.ui(14, .medium)).foregroundStyle(Theme.loyalSoft) }
            })
        }) { p in session.act("pick", p.id) }
        if me.mine.count >= kills { Small(me.split ? "Change your choice to match theirs, or persuade them to change." : "Chosen. You can change it until the night ends.").padding(.top, 10) }
        if let c = me.chat {
            More("Talk to the Forsworn" + (c.isEmpty ? "" : " · \(c.count)"), open: !c.isEmpty) { ForswornChat(me: me) }
        }
    }
}

extension NightView {
    // how many Forsworn chose each name tonight
    var tally: [String: Int] {
        var c: [String: Int] = [:]
        for p in me.picks { for n in p.picks { c[n, default: 0] += 1 } }
        return c
    }
}

struct DawnView: View {
    let v: Snapshot
    let me: Me
    @Environment(Session.self) private var session
    var body: some View {
        if let d = v.dawn {
            if !d.revealed {
                if me.victim {
                    Card(.hot, center: true) { H1("You were poisoned"); Sub("The Forsworn chose you tonight. Say nothing yet. When the host reveals what happened, you’ll get time to say your last words.") }
                    DirCard { Button("Reveal the night") { session.act("cont") }.btn(.fill) }
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        Eyebrow("dawn"); H1("Heads up"); Sub("It’s morning. Who made it through the night? The host will reveal who the Forsworn poisoned.")
                        DirCard { Button("Reveal the night") { session.act("cont") }.btn(.fill) }
                        WaitHost(v: v)
                    }
                }
            } else if d.victims.contains(me.name), let last = d.lastEnd {
                Card(.hot, center: true) {
                    H1("Your last words")
                    Sub("Stand up, tell everyone you were poisoned, and say anything you like before the clock runs out. After that, you’re a Ghost: you stay and watch, but you’re out of the game.")
                    Clock(end: last, size: 56)
                }
                DirCard { Button("On to the next round") { session.act("cont") }.btn(.fill) }
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    Eyebrow("dawn")
                    H1(d.victims.isEmpty ? "Nobody was poisoned" : Words.andList(d.victims.map(Words.nb)) + (d.victims.count > 1 ? " were" : " was") + " poisoned")
                    if d.victims.isEmpty { Sub(d.saved > 0 ? "Sanctuary held. The Forsworn chose " + (d.saved > 1 ? "people who were" : "someone who was") + " protected, so nobody was poisoned." : "The night passed quietly.") }
                    else if let last = d.lastEnd { HStack(spacing: 6) { Sub("Poisoned in the night. Time for last words:"); Clock(end: last).padding(.bottom, 12) } }
                    else { Sub("They were poisoned in the night.") }
                    if d.victims.contains(me.name) { Banner(.ghost, icon: "ghost", "You were poisoned, so you’re a Ghost now. Please stay and watch.") }
                    Epitaphs(d: d)
                    DirCard { Button("On to the next round") { session.act("cont") }.btn(.fill) }
                    WaitHost(v: v)
                }
            }
        }
    }
}

// each victim in turn: what the table once voted them most likely to do
struct Epitaphs: View {
    let d: Dawn
    var tv = false
    var vh: CGFloat = 8
    var body: some View {
        ForEach(d.victims, id: \.self) { n in
            if let q = d.likely.first(where: { $0.name == n })?.q {
                Text("The table voted \(n) " + Epitaphs.lower(q) + ". Now we’ll never find out.")
                    .font(Theme.bookItalic(tv ? 3.4 * vh : 18, fixed: tv)).foregroundStyle(Theme.brass2)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: tv ? 120 * vh : .infinity, alignment: tv ? .center : .leading)
                    .multilineTextAlignment(tv ? .center : .leading)
                    .padding(.vertical, tv ? 0 : 10)
            }
        }
    }
    static func lower(_ q: String) -> String { q.lowercased().hasPrefix("most") ? "most" + q.dropFirst(4) : q }
}

struct TrustView: View {
    let v: Snapshot
    let me: Me
    @Environment(Session.self) private var session
    var body: some View {
        if let t = v.trust {
            VStack(alignment: .leading, spacing: 0) {
                if let r = t.result {
                    H1(r == "trust" ? "The table trusts" : "Doubt")
                    Sub(r == "trust" ? "Everyone chose Trust, so the game ends here. Next, every survivor’s role is revealed." : Words.plural(t.count, "player") + " didn’t choose Trust, so there’s another Reckoning, with another debate and vote.")
                    DirCard { Button("Continue") { session.act("cont") }.btn(.fill) }
                    WaitHost(v: v)
                } else if !me.alive {
                    Eyebrow("trust or doubt"); H1("The survivors decide"); Sub("The players still in are deciding whether every Forsworn is gone. \(t.voted) of \(t.of) have chosen.")
                } else {
                    H1("Do you trust everyone left?")
                    Sub("Choose Trust if you think every Forsworn is gone. Choose Doubt if you think one is still here. The game only ends if everyone chooses Trust. One Doubt means another Reckoning. Not answering in time counts as Doubt.")
                    if let e = t.end { Clock(end: e).padding(.bottom, 12) }
                    if let m = t.mine {
                        DoneLine("handshake", Text("You chose ") + b(m.uppercased()) + Text(".\n") + Text("\(t.voted) of \(t.of) have chosen.").font(Theme.ui(15)))
                    } else {
                        Columns(2) {
                            Button("Trust") { session.act("trust", "trust") }.btn(.verd, .big)
                            Button("Doubt") { session.act("trust", "doubt") }.btn(.blood, .big)
                        }
                    }
                }
            }
        }
    }
}

struct UnmaskList: View {
    let v: Snapshot
    var body: some View {
        if let u = v.unmask {
            VStack(spacing: 0) {
                ForEach(Array(u.order.enumerated()), id: \.offset) { i, id in
                    let p = v.player(id)
                    ScoreRow(player: p) {
                        if i < u.shown { points(p.forsworn ? "Forsworn" : "Loyal", color: p.forsworn ? Theme.blood2 : Theme.loyalSoft) }
                        else { points("…") }
                    }
                }
            }
        }
    }
}

struct HonourView: View {
    let v: Snapshot
    let me: Me
    @Environment(Session.self) private var session
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Eyebrow("the last betrayal")
            if !me.forsworn || !me.alive {
                H1("The Forsworn decide")
                Sub("More than one Forsworn made it to the end. Now each of them secretly chooses Honour, to share the prize, or Betray, to try to take all of it.")
            } else {
                H1("Honour or betray?")
                Sub("If every Forsworn chooses Honour, you share the prize. If exactly one chooses Betray, they take it all. If two or more betray, nobody gets anything. If you don’t choose in time, you choose Honour.")
                if let e = v.honour?.end { Clock(end: e).padding(.bottom, 12) }
                if let m = v.honour?.mine { DoneLine("blade", Text("You chose ") + b(m.uppercased()) + Text(".")) }
                else {
                    Columns(2) {
                        Button("Honour") { session.act("honour", "honour") }.btn(.verd, .big)
                        Button("Betray") { session.act("honour", "betray") }.btn(.blood, .big)
                    }
                }
            }
        }
    }
}

struct EndView: View {
    let v: Snapshot
    let me: Me
    @Environment(Session.self) private var session
    var body: some View {
        if let r = v.result {
            let fw = r.forsworn
            VStack(alignment: .leading, spacing: 0) {
                H1(fw ? "The Forsworn win" : "The Loyal win", disp: true)
                if r.early { Small("The host ended the game early, so it was scored as it stood at that moment.") }
                Sub(EndView.how(r))
                if me.director { ResultsOffer(v: v) }
                VStack(spacing: 0) {
                    Eyebrow(EndView.prizeHead(r))
                    Answer(Words.prize(r), center: true)
                    Small(EndView.purse(r), center: true)
                }
                .padding(.top, 18).padding(.bottom, 8)
                .overlay(alignment: .top) { DoubleRule() }
                .overlay(alignment: .bottom) { DoubleRule() }
                .padding(.bottom, 14)
                if me.won { Banner(.sanct, icon: "crown", "You won.") }
                if !r.peeked.isEmpty { Small("The host looked at everyone’s role in " + (r.peeked.count > 1 ? "rounds " : "round ") + r.peeked.map { "\($0)" }.joined(separator: ", ") + ", using a tool meant for when something goes wrong.") }
                H2("Who was who", sec: true)
                VStack(spacing: 0) {
                    ForEach(v.players.sorted { ($0.forsworn ? 0 : 1) < ($1.forsworn ? 0 : 1) }) { p in
                        HStack(spacing: 10) {
                            Seal(p).frame(width: 30, height: 30)
                            (Text(p.name).foregroundColor(p.forsworn ? Color(hex: 0xF3C5D3) : Theme.tallow) + Text(p.alive ? "" : " out").font(Theme.ui(14)).foregroundColor(Theme.mist))
                                .font(Theme.ui(18)).frame(maxWidth: .infinity, alignment: .leading)
                            Text(p.forsworn ? "Forsworn" : "Loyal").font(Theme.sc(15)).tracking(0.45).foregroundStyle(p.forsworn ? Theme.blood2 : Theme.loyalSoft)
                        }
                        .padding(.vertical, 7)
                        .overlay(alignment: .bottom) { Rectangle().fill(Theme.rule2).frame(height: 1) }
                    }
                }
                .overlay(alignment: .top) { Rectangle().fill(Theme.rule2).frame(height: 1) }
                .padding(.top, 6)
                if !r.awards.isEmpty {
                    H2("The awards", sec: true)
                    VStack(spacing: 0) {
                        ForEach(r.awards, id: \.title) { a in
                            HStack(spacing: 10) {
                                Seal(v.player(a.id)).frame(width: 30, height: 30)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(a.title).font(Theme.ui(18, .bold)).foregroundStyle(Theme.tallow)
                                    Text(a.name + " " + a.why).font(Theme.ui(15)).foregroundStyle(Theme.tallow2)
                                }
                                Spacer()
                            }
                            .padding(.vertical, 8)
                            .overlay(alignment: .bottom) { Rectangle().fill(Theme.rule2).frame(height: 1) }
                        }
                    }
                }
                RateCard(me: me)
                DirCard { Button("Play again with the same people") { session.confirm("Start a new game with the same players?", yes: "Play again") { session.act("again") } }.btn(.dark) }
                ReportLink()
            }
        }
    }
}

// one tap: how the game was (the server keeps it in the game's log, for /admin)
struct RateCard: View {
    let me: Me
    @Environment(Session.self) private var session
    var body: some View {
        if me.rated > 0 {
            Small("Thanks for rating it \(me.rated) out of 5.", center: true).padding(.top, 14)
        } else {
            Card {
                Para("How was the game? One tap helps us make it better.")
                HStack(spacing: 8) {
                    ForEach(1...5, id: \.self) { n in Button(String(n)) { session.act("rate", n) }.btn(.dark) }
                }
                Small("1 is poor, 5 is brilliant.").padding(.top, 8)
            }
            .padding(.top, 14)
        }
    }
}

extension EndView {
    static func how(_ r: GameResult) -> String {
        if r.how == "betrayed" { return Words.andList(r.to) + " betrayed the other Forsworn at the very end, and takes it all." }
        if r.how == "nobody" { return "More than one Forsworn chose Betray, so nobody gets the prize." }
        return r.to.isEmpty ? "" : "The prize goes to " + Words.andList(r.to) + "."
    }
    static func prizeHead(_ r: GameResult) -> String {
        guard r.tier > 0 else { return "the prize" }
        let full: String = r.forsworn ? (r.pot <= 0 ? "an empty" : "a half-empty") : (r.pot >= r.cap ? "a full" : "a half-full")
        return "the prize · " + full + " Purse"
    }
    static func purse(_ r: GameResult) -> String {
        let s: String
        if r.forsworn { s = r.won > 0 ? "The Loyal filled the Purse to \(r.pot) out of \(r.cap). The Forsworn take the \(r.won) it fell short." : "The Loyal filled the Purse, so there was nothing left for the Forsworn to take." }
        else { s = "The Purse reached \(r.pot) out of \(r.cap)." }
        return s + (r.coins != nil ? " That’s one chocolate coin for every 100 points." : "")
    }
}

// .card.prize's border: 3px double, in brass
struct DoubleRule: View {
    var body: some View { VStack(spacing: 1) { Rectangle().fill(Theme.brass).frame(height: 1); Rectangle().fill(Theme.brass).frame(height: 1) } }
}

// The Forsworn's conversation: what's been said, the set phrases, and a line to type (the night's panel, and Your role)
struct ForswornChat: View {
    let me: Me
    @Environment(Session.self) private var session
    @State private var typed = ""
    var body: some View {
        let c = me.chat ?? []
        VStack(alignment: .leading, spacing: 0) {
            if c.isEmpty { Small("Only the Forsworn who are still in the game can see these messages.") }
            else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(c.suffix(20).enumerated()), id: \.offset) { _, x in
                        (Text(x.name + "  ").font(Theme.ui(16, .bold)).foregroundColor(Theme.blood2) + Text(x.text).font(Theme.ui(16)).foregroundColor(Theme.tallow))
                            .padding(.vertical, 4).frame(maxWidth: .infinity, alignment: .leading)
                            .overlay(alignment: .bottom) { Rectangle().fill(.white.opacity(0.06)).frame(height: 1) }
                    }
                }
                .padding(.top, 8).padding(.bottom, 12)
            }
            Columns(2, spacing: 8) {
                ForEach(Array(me.whisperSay.enumerated()), id: \.offset) { i, m in
                    Button(m) { session.act("whisper", i) }.btn(.dark, .sm)
                }
            }
            HStack(spacing: 8) {
                Field(placeholder: "A message to the Forsworn", text: $typed, max: 140, submit: send)
                Button("Send", action: send).btn(.fill, fit: true) // (as high as the field beside it)
                    .disabled(typed.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.top, 10)
        }
    }
    private func send() {
        let t = typed.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        typed = ""
        session.act("chat", t)
    }
}

// Your role, the same button on every phone: inside, the role, and for the Forsworn their allies and their chat, so a
// glance at a phone gives nothing away
struct RoleView: View {
    let v: Snapshot
    let me: Me
    @Environment(Session.self) private var session
    var body: some View {
        if session.myRole == 1 {
            VStack(spacing: 12) {
                Button { session.myRole = 2 } label: {
                    VStack(spacing: 0) {
                        Eyebrow("your role")
                        H2("Hold your phone close")
                        Sub("Tap here when nobody can see your screen.")
                    }
                    .multilineTextAlignment(.center)
                    .padding(20)
                    .frame(maxWidth: .infinity, minHeight: 300)
                    .background(Stripes())
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Theme.edge2, lineWidth: 1))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                Button("Back to the game") { session.myRole = 0 }.btn(.ghost, .sm)
            }
        } else {
            let f = me.forsworn
            VStack(alignment: .leading, spacing: 0) {
                Card(.role, center: true) {
                    BigSeal(kind: f ? .forsworn : .loyal, icon: f ? "blade" : "candle").frame(width: 120, height: 120).padding(.bottom, 12)
                    H1(f ? "Forsworn" : "Loyal", color: f ? Theme.blood2 : Theme.loyal)
                    if f {
                        Sub("You are one of the secret traitors. Keep pretending to be Loyal.")
                        if let allies = me.allies, !allies.isEmpty { Para(Text("Your fellow Forsworn: ") + b(allies.map { $0.name + ($0.alive ? "" : " (out)") }.joined(separator: ", "))) }
                        else { Para("You are the only Forsworn. Trust nobody.") }
                    } else { Sub("You are true to the table. Find the Forsworn, the secret traitors.") }
                }
                .padding(.horizontal, 18)
                if me.chat != nil {
                    H2("Talk to the Forsworn").padding(.top, 18)
                    ForswornChat(me: me)
                }
                Button("Hide my role") { session.myRole = 0 }.btn(.fill, .big).padding(.top, 18)
            }
        }
    }
}
