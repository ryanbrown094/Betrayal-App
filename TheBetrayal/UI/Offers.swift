import SwiftUI

// Offers to the host of a free game to make the night ad-free, all decided here so their limits live in one place:
//   U1  the host's lobby, once three have joined, until waved away (it takes the lobby banner's place)
//   U2  a strip on the host's phone at the start of two rounds, never consecutive (the second and the fourth)
//   U3  the same two rounds, in a corner of the TV, with nothing to tap: buying is only ever on the host's phone
//   U4  the host's results: the Host Pass, for next time, until waved away
// Players are never offered anything; they can't buy. Nor is anyone at a practice game, where only bots would see ads.
@MainActor
enum Offers {
    static func lobbyDue(_ v: Snapshot, _ s: Session) -> Bool {
        adsOn(s.tier) && !v.practice && v.phase == "lobby" && v.players.count >= 3 && !waved(s.room, "U1")
    }
    static func breakDue(_ v: Snapshot, _ tier: Tier) -> Bool {
        guard adsOn(tier), !v.practice, let a = tier.ads, v.phase == "day", !v.final else { return false }
        return v.round == a.afterRound + 1 || v.round == a.afterRound + 3
    }
    static func resultsDue(_ v: Snapshot, _ s: Session) -> Bool { s.tier.tier == "free" && !v.practice && v.phase == "end" && !waved(s.room, "U4") }

    private static func adsOn(_ t: Tier) -> Bool { t.tier == "free" && t.ads?.enabled == true }
    static func waved(_ room: String, _ spot: String) -> Bool { UserDefaults.standard.bool(forKey: "bt-offer-" + room + "-" + spot) }
    static func wave(_ room: String, _ spot: String) { UserDefaults.standard.set(true, forKey: "bt-offer-" + room + "-" + spot) }

    // "Night Pass, £4.99", or just the name while the App Store hasn't answered
    static func price(_ plan: Shop.Plan?) -> String { plan.map { " (" + $0.price + ($0.period.map { " " + $0 } ?? "") + ")" } ?? "" }
}

// what the server counts (POST /api/app/event): which ads and offers were seen and tapped, nothing about who
enum Events {
    static func send(_ e: String, placement: String? = nil, product: String? = nil) {
        var body: [String: Any] = ["e": e]
        if let placement { body["placement"] = placement }
        if let product { body["product"] = product }
        Task { _ = try? await API.call("/api/app/event", body: body) }
    }
    @MainActor private static var sent: Set<String> = []
    // once a Table for each spot (and round, where it shows at two)
    @MainActor static func once(_ e: String, _ key: String, placement: String) {
        guard sent.insert(e + "|" + key).inserted else { return }
        send(e, placement: placement)
    }
}

// U1
struct LobbyOffer: View {
    let v: Snapshot
    @Environment(Session.self) private var session
    @State private var gone = false
    @State private var open = false
    var body: some View {
        if !gone && Offers.lobbyDue(v, session) {
            Card(.hot) {
                Text("\(v.players.count) players are about to see ads.").font(Theme.book(23)).foregroundStyle(Theme.tallow).padding(.bottom, 6)
                Sub("Make tonight ad-free with a Night Pass\(Offers.price(Shop.shared.night)), or every night you host with the Host Pass\(Offers.price(Shop.shared.host)). Either adds every Trial too.")
                HStack(spacing: 10) {
                    Button("Make it ad-free") { Events.send("upsell_clicked", placement: "U1"); open = true }.btn(.fill, .sm, fit: true)
                    Button("Not tonight") { Offers.wave(session.room, "U1"); gone = true }.btn(.dark, .sm, fit: true)
                }
                .padding(.bottom, 8)
            }
            .onAppear { Events.once("upsell_shown", session.room + "U1", placement: "U1") }
            .sheet(isPresented: $open) { UsePassSheet(use: session.upgrade) }
        }
    }
}

// U2
struct BreakOffer: View {
    let v: Snapshot
    @Environment(Session.self) private var session
    @State private var open = false
    var body: some View {
        if Offers.breakDue(v, session.tier) {
            HStack(spacing: 10) {
                Text("Players are seeing ads.").font(Theme.ui(16)).foregroundStyle(Theme.gold)
                Spacer(minLength: 0)
                Button("Remove them for tonight") { Events.send("upsell_clicked", placement: "U2"); open = true }.btn(.ghost, .sm, fit: true)
            }
            .padding(.vertical, 8).padding(.horizontal, 12)
            .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Theme.goldRule, lineWidth: 1))
            .padding(.bottom, 14)
            .onAppear { Events.once("upsell_shown", session.room + "U2" + String(v.round), placement: "U2") }
            .sheet(isPresented: $open) { UsePassSheet(use: session.upgrade) }
        }
    }
}

// U3: a corner of the TV
struct TVOffer: View {
    let v: Snapshot
    let u: TVUnits
    @Environment(Session.self) private var session
    var body: some View {
        if Offers.breakDue(v, session.tier) {
            VStack(alignment: .trailing, spacing: u.vh * 0.6) {
                Text("Players are seeing ads").font(Theme.ui(u.vh * 2.6, .bold, fixed: true)).foregroundStyle(Theme.gold)
                Text("The host can make tonight ad-free").font(Theme.ui(u.vh * 2.2, fixed: true)).foregroundStyle(Theme.tallow2)
            }
            .padding(u.vh * 1.6)
            .background(RoundedRectangle(cornerRadius: u.vh).fill(Theme.soot.opacity(0.85)))
            .overlay(RoundedRectangle(cornerRadius: u.vh).strokeBorder(Theme.goldRule, lineWidth: 1))
            .onAppear { Events.once("upsell_shown", session.room + "U3" + String(v.round), placement: "U3") }
        }
    }
}

// U4
struct ResultsOffer: View {
    let v: Snapshot
    @Environment(Session.self) private var session
    @State private var gone = false
    @State private var open = false
    var body: some View {
        if !gone && Offers.resultsDue(v, session) {
            Card(.hot) {
                Text("Hosting again?").font(Theme.book(23)).foregroundStyle(Theme.tallow).padding(.bottom, 6)
                Sub("The Host Pass\(Offers.price(Shop.shared.host)): no ads and every Trial, every time you host.")
                HStack(spacing: 10) {
                    Button("Get the Host Pass") { Events.send("upsell_clicked", placement: "U4", product: "host"); open = true }.btn(.fill, .sm, fit: true)
                    Button("No thanks") { Offers.wave(session.room, "U4"); gone = true }.btn(.dark, .sm, fit: true)
                }
                .padding(.bottom, 8)
            }
            .onAppear { Events.once("upsell_shown", session.room + "U4", placement: "U4") }
            .sheet(isPresented: $open) { HostPassSheet() }
        }
    }
}

// the Host Pass, bought at the end of a free game, for the next one
struct HostPassSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var done: Shop.Bought?
    @State private var problem: String?
    private var shop: Shop { Shop.shared }
    var body: some View {
        ScrollView {
            Column {
                HStack { Spacer(); Button("Close") { dismiss() }.btn(.dark, .sm, fit: true) }
                H1("The Host Pass")
                Sub("Every game you host ad-free, for everyone at the Table, with every Trial and the full question banks.")
                if done != nil {
                    Card(.hot, center: true) {
                        Eyebrow("thank you")
                        Text("Your Host Pass").font(Theme.book(30)).foregroundStyle(Theme.brass2).padding(.vertical, 8)
                        Sub("It’s on this phone, under Your passes. Your next game is ad-free.")
                    }
                } else if let h = shop.host {
                    Button(shop.buying == h.id ? "Waiting for the App Store…" : "Subscribe for \(h.price) \(h.period ?? "a year")") {
                        Task {
                            if let b = await shop.buy(h, announce: false, from: "U4") { done = b }
                            else if let p = shop.problem { problem = p; shop.problem = nil }
                        }
                    }
                    .btn(.fill).disabled(shop.buying != nil || h.product == nil)
                    SubscriptionTerms(plan: h)
                } else {
                    Small("The App Store isn’t answering. Try again from the start screen.")
                }
                if let problem { Text(problem).font(Theme.ui(16)).foregroundStyle(Theme.blood2).padding(.top, 10) }
            }
        }
        .background(Backdrop())
    }
}
