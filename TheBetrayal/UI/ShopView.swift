import SwiftUI
import StoreKit

// The passes (Model/Shop.swift): a Night Pass and the Host Pass at Apple's prices, what renewing means, and the passes this
// phone holds, with what each can do now.
struct BookCard: View {
    let open: (String) -> Void
    let show: (Page) -> Void
    @State private var managing = false
    @Environment(\.openURL) private var openURL
    private var shop: Shop { Shop.shared }

    var body: some View {
        Card {
            Eyebrow("passes")
            H2("Make it ad-free")
            Sub("A pass takes the ads away for everyone at your Table, and adds every Trial and the full question banks: thousands of questions and prompts.")
            if let n = shop.night {
                plan(n, name: "Night Pass", about: "Tonight, ad-free: every game you start in the 24 hours after you first use it. If none of them gets going, you get the night back.", buy: "Buy for \(n.price)")
            }
            if let h = shop.host {
                plan(h, name: "Host Pass", about: "Every night ad-free, whenever you host, with every Trial and the full question banks. Cancel any time.", buy: "Subscribe for \(h.price) \(h.period ?? "a year")")
            }
            if shop.night == nil && shop.host == nil {
                if shop.loaded {
                    Small("Passes aren’t available right now. Check you’re online, then try again.")
                    Button("Try again") { Task { await shop.load() } }.btn(.ghost, .sm, fit: true).padding(.bottom, 12)
                } else {
                    Small("Asking the App Store for prices…")
                }
            } else {
                Small("Your pass appears under Your passes as soon as you’ve paid, and stays on this phone. Use it when you start a game, or on a free game from its lobby. Prices include VAT where it applies.")
                if let h = shop.host { Small(SubscriptionTerms.words(h)) }
            }
            Flow(spacing: 8) {
                Button("Restore purchases") { Task { await shop.restore() } }.btn(.dark, .sm, fit: true)
                Button("Manage subscription") { managing = true }.btn(.dark, .sm, fit: true)
                Button("Terms of Use (EULA)") { openURL(Page.eula) }.btn(.dark, .sm, fit: true)
                Button("Terms of sale") { show(.terms) }.btn(.dark, .sm, fit: true)
                Button("Privacy Policy") { show(.privacy) }.btn(.dark, .sm, fit: true)
            }
            .padding(.bottom, 8)
        }
        .manageSubscriptionsSheet(isPresented: $managing)
    }

    private func plan(_ p: Shop.Plan, name: String, about: String, buy: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text(name).font(Theme.book(24)).foregroundStyle(Theme.tallow)
                Spacer()
                Text(verbatim: p.price + (p.period.map { " " + $0 } ?? "")).font(Theme.ui(20, .bold)).foregroundStyle(Theme.brass2)
            }
            .padding(.bottom, 4)
            Small(about)
            Button(shop.buying == p.id ? "Waiting for the App Store…" : buy) { Task { await shop.buy(p) } }
                .btn(p.id == Shop.nightID ? .fill : .ghost)
                .disabled(shop.buying != nil || (p.product == nil && !shop.previewing))
        }
        .padding(.bottom, 18)
    }
}

// the passes this phone holds, newest first, by name and what each can do now: their codes stay out of sight (the app
// uses them itself), and one that's used up can be cleared away
struct YourCodes: View {
    let open: (String) -> Void
    private var shop: Shop { Shop.shared }

    var body: some View {
        if !shop.codes.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                Label2("On this phone")
                ForEach(shop.codes) { c in
                    let (name, state, usable) = YourCodes.describe(c, shop.status[c.pass])
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(name).font(Theme.ui(19, .bold)).foregroundStyle(usable ? Theme.tallow : Theme.tallow2)
                            if let state { Text(state).font(Theme.sc(13)).tracking(0.6).foregroundStyle(Theme.tallow2) }
                        }
                        Spacer()
                        if usable { Button("Use") { open(c.pass) }.btn(.ghost, .sm, fit: true) }
                        else { Button("Clear") { shop.forget(c) }.btn(.dark, .sm, fit: true) }
                    }
                    .padding(.vertical, 8)
                    .overlay(alignment: .bottom) { Rectangle().fill(Theme.rule).frame(height: 1) }
                }
            }
            .padding(.vertical, 14)
        }
    }

    // (its name, its state, whether it would make a game ad-free now)
    static func describe(_ c: SavedCodes.Code, _ st: API.CodeStatus?) -> (String, String?, Bool) {
        let name = c.sub == true ? "Host Pass" : "Night Pass"
        guard let st else { return (name, nil, true) }
        switch (st.kind, st.state) {
        case ("night", "ready"): return ("Night Pass", "ready for a night", true)
        case ("night", "active"): return ("Night Pass", "ad-free until " + (st.until.map { $0.formatted(date: .omitted, time: .shortened) } ?? "tonight"), true)
        case ("night", "ended"): return ("Night Pass", "used", false)
        case ("host", "active"): return ("Host Pass", st.until.map { "renews " + $0.formatted(date: .abbreviated, time: .omitted) }, true)
        case ("host", "lapsed"): return ("Host Pass", "lapsed: renew it under Manage subscription", false)
        case (_, "cancelled"): return (name, "cancelled", false)
        default: return (name, nil, true)
        }
    }
}

// straight after paying: the pass, and the way to an ad-free game
struct BoughtSheet: View {
    let bought: Shop.Bought
    let open: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            Column {
                Brand(mark: "ad-free")
                Card(.hot, center: true) {
                    Eyebrow("thank you")
                    Text(bought.sub ? "Your Host Pass" : "Your Night Pass").font(Theme.book(30)).foregroundStyle(Theme.brass2).padding(.vertical, 10)
                    Sub(bought.sub
                        ? "Every game you host is ad-free while it’s active, with every Trial and the full question banks."
                        : "Its 24 hours start when you first use it: start a game with it, or use it on a free game from its lobby.")
                }
                Small(bought.sub ? "It’s on this phone, under Your passes, and Restore purchases brings it to your other devices." : "It’s on this phone, under Your passes, ready when you are.", center: true)
                VStack(spacing: 10) {
                    Button("Start an ad-free game now") { dismiss(); open(bought.pass) }.btn(.fill)
                    Button("Later") { dismiss() }.btn(.dark, .sm)
                }
            }
        }
        .background(Backdrop())
    }
}

// what Apple asks to be beside every way to subscribe: the subscription's name, length, price and what it gives, how it
// renews and is cancelled, and links to the Terms of Use (Apple's standard licence) and the privacy policy
struct SubscriptionTerms: View {
    let plan: Shop.Plan
    @State private var page: Page?
    @Environment(\.openURL) private var openURL
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Small(SubscriptionTerms.words(plan))
            Flow(spacing: 8) {
                Button("Terms of Use (EULA)") { openURL(Page.eula) }.btn(.dark, .sm, fit: true)
                Button("Terms of sale") { page = .terms }.btn(.dark, .sm, fit: true)
                Button("Privacy Policy") { page = .privacy }.btn(.dark, .sm, fit: true)
            }
            .padding(.bottom, 8)
        }
        .padding(.top, 10)
        .sheet(item: $page) { p in PageView(page: p) { page = nil } }
    }
    static func words(_ h: Shop.Plan) -> String {
        "The Host Pass is a yearly subscription at \(h.price) \(h.period ?? "a year"): every game you host is ad-free for everyone at the Table, with every Trial and the full question banks. Payment is taken from your Apple Account when you confirm. It renews automatically at the same price unless you cancel at least 24 hours before the end of the year, in your Apple Account’s subscriptions."
    }
}

// a Trial a free game doesn't play
struct LockedTrial: View {
    let title: String
    var body: some View {
        HStack(spacing: 5) {
            Icon(name: "key").frame(width: 15, height: 15)
            Text(title).font(Theme.ui(15))
        }
        .foregroundStyle(Theme.tallow2)
        .padding(.horizontal, 10).padding(.vertical, 5)
        .overlay(Capsule().strokeBorder(Theme.edge, lineWidth: 1))
    }
}

// the host makes a free game ad-free from its lobby: one of this phone's passes, or a pass's code typed in
struct UsePassSheet: View {
    let use: (String) async -> String?
    @Environment(\.dismiss) private var dismiss
    @State private var busy = false
    @State private var problem: String?
    private var shop: Shop { Shop.shared }
    private var usable: [SavedCodes.Code] { shop.usable }

    var body: some View {
        ScrollView {
            Column {
                HStack { Spacer(); Button("Close") { dismiss() }.btn(.dark, .sm, fit: true) }
                H1("Make tonight ad-free")
                Sub("A pass takes the ads away for everyone at this Table, and adds every Trial and the full question banks from the next Trial on. A Night Pass’s 24 hours start the first time it’s used.")
                if !usable.isEmpty {
                    Label2("Your passes")
                    ForEach(usable) { c in
                        let (name, state, _) = YourCodes.describe(c, shop.status[c.pass])
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(name).font(Theme.ui(19, .bold)).foregroundStyle(Theme.tallow)
                                if let state { Text(state).font(Theme.sc(13)).tracking(0.6).foregroundStyle(Theme.tallow2) }
                            }
                            Spacer()
                            Button("Use") { go(c.pass) }.btn(.fill, .sm, fit: true).disabled(busy)
                        }
                        .padding(.vertical, 8)
                        .overlay(alignment: .bottom) { Rectangle().fill(Theme.rule).frame(height: 1) }
                    }
                    Spacer().frame(height: 18)
                }
                if let problem { Text(problem).font(Theme.ui(16)).foregroundStyle(Theme.blood2).padding(.top, 10) }
                if shop.night != nil || shop.host != nil {
                    Label2(usable.isEmpty ? "Buy one, and use it now" : "Or buy one, and use it now").padding(.top, usable.isEmpty ? 4 : 22)
                    VStack(spacing: 10) {
                        if let n = shop.night {
                            Button(shop.buying == n.id ? "Waiting for the App Store…" : "Night Pass, \(n.price)") { buyAndUse(n) }
                                .btn(.fill).disabled(busy || shop.buying != nil || n.product == nil)
                        }
                        if let h = shop.host {
                            Button(shop.buying == h.id ? "Waiting for the App Store…" : "Host Pass, \(h.price) \(h.period ?? "a year")") { buyAndUse(h) }
                                .btn(.ghost).disabled(busy || shop.buying != nil || h.product == nil)
                            SubscriptionTerms(plan: h)
                        }
                    }
                }
            }
        }
        .background(Backdrop())
        .task { await shop.refresh() }
    }

    private func buyAndUse(_ plan: Shop.Plan) {
        problem = nil
        Task {
            if let b = await shop.buy(plan, announce: false, from: "lobby") { go(b.pass) }
            else if let p = shop.problem { problem = p; shop.problem = nil }
        }
    }

    private func go(_ pass: String) {
        let p = pass.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !busy, p.count >= 4 else { return }
        busy = true
        problem = nil
        Task {
            let e = await use(p)
            busy = false
            if let e { problem = e } else { dismiss() }
        }
    }
}
