import SwiftUI
import StoreKit

// The passes (Model/Shop.swift): a Night Pass and the Host Pass at Apple's prices, what renewing means, and the passes this
// phone holds, with what each can do now.
struct BookCard: View {
    let open: (String) -> Void
    let show: (Page) -> Void
    @State private var managing = false
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
                if let h = shop.host {
                    Small("Payment is taken from your Apple Account. The Host Pass is \(h.price) \(h.period ?? "a year") and renews automatically until you cancel, which you can do at any time up to 24 hours before the end of the year, in your Apple Account’s subscriptions.")
                }
            }
            Flow(spacing: 8) {
                Button("Restore purchases") { Task { await shop.restore() } }.btn(.dark, .sm, fit: true)
                Button("Manage subscription") { managing = true }.btn(.dark, .sm, fit: true)
                Button("Terms of sale") { show(.terms) }.btn(.dark, .sm, fit: true)
                Button("Privacy") { show(.privacy) }.btn(.dark, .sm, fit: true)
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
                .disabled(shop.buying != nil || p.product == nil)
        }
        .padding(.bottom, 18)
    }
}

// the passes this phone has bought or opened a Table with, newest first, with what each can do now
struct YourCodes: View {
    let open: (String) -> Void
    @State private var copied: String?
    private var shop: Shop { Shop.shared }

    var body: some View {
        if !shop.codes.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                Label2("Your passes")
                ForEach(shop.codes) { c in
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(verbatim: c.pass).font(Theme.ui(20, .bold)).tracking(1.5).foregroundStyle(Theme.tallow).textSelection(.enabled)
                            Text(copied == c.pass ? "Copied" : label(c))
                                .font(Theme.sc(13)).tracking(0.6).foregroundStyle(Theme.tallow2)
                        }
                        Spacer()
                        Button("Open") { open(c.pass) }.btn(.ghost, .sm, fit: true)
                    }
                    .padding(.vertical, 8)
                    .overlay(alignment: .bottom) { Rectangle().fill(Theme.rule).frame(height: 1) }
                    .contextMenu {
                        Button("Copy the code") { UIPasteboard.general.string = c.pass; copied = c.pass }
                        Button("Forget this code", role: .destructive) { shop.forget(c) }
                    }
                }
                Small("Touch and hold a code to copy it or forget it.").padding(.top, 8)
            }
            .padding(.bottom, 14)
        }
    }

    private func label(_ c: SavedCodes.Code) -> String {
        let name = c.sub == true ? "Host Pass" : c.sub == false ? "Night Pass" : "Pass"
        guard let st = shop.status[c.pass] else { return name }
        switch (st.kind, st.state) {
        case ("night", "ready"): return "Night Pass · ready"
        case ("night", "active"): return "Night Pass · ad-free until " + (st.until.map { $0.formatted(date: .omitted, time: .shortened) } ?? "tonight")
        case ("night", "ended"): return "Night Pass · used"
        case ("host", "active"): return "Host Pass"
        case ("host", "lapsed"): return "Host Pass · lapsed"
        case (_, "cancelled"): return name + " · cancelled"
        default: return name
        }
    }
}

// straight after paying: the pass, and the way to an ad-free game
struct BoughtSheet: View {
    let bought: Shop.Bought
    let open: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var copied = false

    var body: some View {
        ScrollView {
            Column {
                Brand(mark: "booked")
                Card(.hot, center: true) {
                    Eyebrow(bought.sub ? "your host pass" : "your night pass")
                    Text(verbatim: bought.pass).font(Theme.ui(30, .bold)).tracking(2).foregroundStyle(Theme.brass2).textSelection(.enabled).padding(.vertical, 10)
                    Sub(bought.sub
                        ? "Every game you host is ad-free while it’s active, with every Trial and the full question banks."
                        : "Its 24 hours start when you first use it: start a game with it, or use it on a free game from its lobby.")
                }
                Small("It’s saved on this phone, under Your passes. Write the code down or take a screenshot too.", center: true)
                VStack(spacing: 10) {
                    Button("Start an ad-free game now") { dismiss(); open(bought.pass) }.btn(.fill)
                    Button(copied ? "Copied" : "Copy the code") { UIPasteboard.general.string = bought.pass; copied = true }.btn(.ghost)
                    Button("Later") { dismiss() }.btn(.dark, .sm)
                }
            }
        }
        .background(Backdrop())
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
    @State private var code = ""
    @State private var busy = false
    @State private var problem: String?
    private var shop: Shop { Shop.shared }
    private var usable: [SavedCodes.Code] { shop.usable }

    var body: some View {
        ScrollView {
            Column {
                HStack { Spacer(); Button("Close") { dismiss() }.btn(.dark, .sm, fit: true) }
                H1("Make tonight ad-free")
                Sub("A pass takes the ads away for everyone at this Table, and adds every Trial and the full question banks from the next Trial on. A Night Pass’s 24 hours start now.")
                if !usable.isEmpty {
                    Label2("Your passes")
                    ForEach(usable) { c in
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(verbatim: c.pass).font(Theme.ui(20, .bold)).tracking(1.5).foregroundStyle(Theme.tallow)
                                Text(c.sub == true ? "Host Pass" : "Night Pass").font(Theme.sc(13)).tracking(0.6).foregroundStyle(Theme.tallow2)
                            }
                            Spacer()
                            Button("Use") { go(c.pass) }.btn(.fill, .sm, fit: true).disabled(busy)
                        }
                        .padding(.vertical, 8)
                        .overlay(alignment: .bottom) { Rectangle().fill(Theme.rule).frame(height: 1) }
                    }
                    Spacer().frame(height: 18)
                }
                Label2(usable.isEmpty ? "Type a pass’s code" : "Or type a pass’s code")
                VStack(spacing: 10) {
                    BookingField(text: $code) { go(code) }
                    Button(busy ? "Using it…" : "Use this pass") { go(code) }.btn(.ghost).disabled(busy || code.count < 4)
                }
                if let problem { Text(problem).font(Theme.ui(16)).foregroundStyle(Theme.blood2).padding(.top, 10) }
                if shop.night != nil || shop.host != nil {
                    Label2("Or buy one, and use it now").padding(.top, 22)
                    VStack(spacing: 10) {
                        if let n = shop.night {
                            Button(shop.buying == n.id ? "Waiting for the App Store…" : "Night Pass, \(n.price)") { buyAndUse(n) }
                                .btn(.fill).disabled(busy || shop.buying != nil || n.product == nil)
                        }
                        if let h = shop.host {
                            Button(shop.buying == h.id ? "Waiting for the App Store…" : "Host Pass, \(h.price) \(h.period ?? "a year")") { buyAndUse(h) }
                                .btn(.ghost).disabled(busy || shop.buying != nil || h.product == nil)
                            Small("Payment is taken from your Apple Account. The Host Pass renews automatically until you cancel, which you can do at any time up to 24 hours before the end of the year, in your Apple Account’s subscriptions.")
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
