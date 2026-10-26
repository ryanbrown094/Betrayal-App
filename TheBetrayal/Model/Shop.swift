import Foundation
import StoreKit
import Observation

// Buying a Night Pass, or the Host Pass, with Apple's in-app purchase (the server's tiers.js says what they do). Each
// purchase goes to the server (POST /api/appstore/claim, worker/src/appstore.js), which checks it with Apple and gives back
// its code; only then is the purchase finished, so a code is never lost to a dropped connection (unfinished purchases are
// claimed again when the app next opens). The codes are kept on the phone (SavedCodes), and the server says what each
// can do now (status).
@MainActor @Observable
final class Shop {
    static let shared = Shop()
    static let nightID = "uk.co.thebetrayal.app.night"
    static let hostID = "uk.co.thebetrayal.app.host"

    struct Plan: Identifiable {
        let id: String
        let price: String       // as the App Store shows it, in the buyer's currency
        let period: String?     // "a year" for the Host Pass
        let product: Product?
    }
    struct Bought: Identifiable { let id = UUID(); let pass: String; let sub: Bool }

    private(set) var night: Plan?
    private(set) var host: Plan?
    private(set) var loaded = false
    private(set) var buying: String?
    var problem: String?
    var bought: Bought?
    private(set) var codes: [SavedCodes.Code] = SavedCodes.all
    private(set) var status: [String: API.CodeStatus] = [:]
    @ObservationIgnored private var listening: Task<Void, Never>?

    func start() {
        guard listening == nil else { return }
        // purchases that finish away from the buy button (Ask to Buy, a renewal, another device), and any the server
        // hadn't answered for before
        listening = Task { [weak self] in
            for await r in Transaction.updates { _ = await self?.collect(r, shown: false) }
        }
        Task {
            await load()
            for await r in Transaction.unfinished { await collect(r, shown: false) }
            await refresh()
        }
    }

    func load() async {
        guard !shown else { return }
        guard let ps = try? await Product.products(for: [Shop.nightID, Shop.hostID]) else { loaded = true; return }
        for p in ps {
            let plan = Plan(id: p.id, price: p.displayPrice, period: p.subscription.map { Shop.period($0.subscriptionPeriod) }, product: p)
            if p.id == Shop.nightID { night = plan } else if p.id == Shop.hostID { host = plan }
        }
        loaded = true
    }

    // a Debug build's pictures: the plans as the App Store would price them, without the App Store
    func show(night: Plan, host: Plan) { self.night = night; self.host = host; loaded = true; shown = true }
    func reload() { codes = SavedCodes.all }
    var previewing: Bool { shown } // a Debug build's pictures: the buttons look as they do with the App Store

    // what each code on the phone can do now (a Night Pass ready, or ad-free until a time; a Host Pass active or lapsed)
    func refresh() async {
        guard !shown else { return }
        status = await API.codes(codes.map(\.pass))
    }
    @ObservationIgnored private var shown = false

    // announce: show the pass in its own sheet (the start screen); a game's lobby uses it straight away instead
    @discardableResult
    func buy(_ plan: Plan, announce: Bool = true, from: String = "home") async -> Bought? {
        guard let product = plan.product, buying == nil else { return nil }
        Events.send("purchase_started", placement: from, product: plan.id == Shop.hostID ? "host" : "night")
        buying = plan.id
        defer { buying = nil }
        do {
            switch try await product.purchase() {
            case .success(let r):
                let b = await collect(r, shown: true)
                if announce { bought = b }
                Trail.shared.here("buy", b != nil ? "bought: " + plan.id : "paid, but no pass yet: " + plan.id)
                return b
            case .pending: problem = "Your purchase is waiting to be approved. Your pass will appear here once it is."; Trail.shared.here("buy", "pending: " + plan.id)
            case .userCancelled: Trail.shared.here("buy", "cancelled: " + plan.id)
            @unknown default: break
            }
        } catch {
            problem = "The App Store couldn’t complete the purchase. Nothing was charged. Try again in a moment."
            Trail.shared.here("error", "purchase failed: " + plan.id + " · " + error.localizedDescription)
        }
        return nil
    }

    // the Regular plan on this Apple Account (and anything else the App Store still owes this phone)
    func restore() async {
        try? await AppStore.sync()
        var found = false
        for await r in Transaction.currentEntitlements { found = true; if let b = await collect(r, shown: true) { bought = b } }
        if !found { problem = "There’s no Host Pass on this Apple Account. A Night Pass is in Your passes on the phone that bought it." }
    }

    // a purchase, exchanged for its pass
    @discardableResult
    private func collect(_ r: VerificationResult<Transaction>, shown: Bool) async -> Bought? {
        guard case .verified(let t) = r else {
            if shown { problem = "The App Store couldn’t confirm that purchase, so it wasn’t used." }
            return nil
        }
        guard t.productID == Shop.nightID || t.productID == Shop.hostID else { await t.finish(); return nil }
        let reply: Reply
        do { reply = try await API.call("/api/appstore/claim", body: ["jws": r.jwsRepresentation]) } catch {
            if shown { problem = "Paid, but the server can’t be reached to give you your pass. It will appear here as soon as the app can reach it." }
            return nil
        }
        if let pass = reply.json["pass"].string {
            let sub = reply.json["sub"].bool ?? false
            SavedCodes.add(pass, sub: sub)
            codes = SavedCodes.all
            await t.finish()
            await refresh()
            return Bought(pass: pass, sub: sub)
        } else if reply.status == 410 || reply.status == 403 {
            // refunded, or Xcode's StoreKit testing on a real server: asking again won't change the answer. (Anything else
            // stays unfinished, so a paid purchase is claimed once the server can give its code.)
            await t.finish()
            if shown { problem = (reply.error ?? "That purchase can’t be used.") + (reply.status == 403 ? " Nothing was charged." : "") }
        } else if shown {
            problem = (reply.error ?? "The server couldn’t give you your pass.") + " Your purchase is safe: the app will try again."
        }
        return nil
    }

    // the passes that would make a game ad-free now: a Host Pass that's paid up (first: using it costs nothing), then a
    // Night Pass that's ready or in its 24 hours; one the server hasn't been asked about yet counts
    var usable: [SavedCodes.Code] {
        let ok = codes.filter { c in
            guard let st = status[c.pass] else { return true }
            return st.kind == "night" ? st.state == "ready" || st.state == "active" : st.kind == "host" && st.state == "active"
        }
        return ok.filter { $0.sub == true } + ok.filter { $0.sub != true }
    }

    func forget(_ c: SavedCodes.Code) { SavedCodes.remove(c.pass); codes = SavedCodes.all }
    // a code typed in that opened a Table (not the master passcode, which isn't a booking code's shape)
    func remember(_ typed: String) {
        guard let pass = SavedCodes.shown(typed) else { return }
        SavedCodes.add(pass, sub: nil)
        codes = SavedCodes.all
    }

    static func period(_ p: Product.SubscriptionPeriod) -> String {
        let n = p.value
        switch p.unit {
        case .day: return n == 1 ? "a day" : "every \(n) days"
        case .week: return n == 1 ? "a week" : "every \(n) weeks"
        case .month: return n == 1 ? "a month" : "every \(n) months"
        case .year: return n == 1 ? "a year" : "every \(n) years"
        @unknown default: return ""
        }
    }
}

// The passes this phone has bought or used, newest first: a code bought in the app lives here, so it's never only in a
// screenshot. sub: a Host Pass (true) or a Night Pass (false).
enum SavedCodes {
    struct Code: Identifiable, Codable, Hashable {
        let pass: String
        var sub: Bool?
        let at: Date
        var id: String { pass }
    }
    private static let key = "bt-codes"

    static var all: [Code] {
        guard let d = UserDefaults.standard.data(forKey: key), let list = try? JSONDecoder().decode([Code].self, from: d) else { return [] }
        return list.sorted { $0.at > $1.at }
    }
    static func add(_ pass: String, sub: Bool?) {
        var list = all
        if let i = list.firstIndex(where: { $0.pass == pass }) { if let sub { list[i].sub = sub } }
        else { list.append(Code(pass: pass, sub: sub, at: Date())) }
        save(list)
    }
    static func remove(_ pass: String) { save(all.filter { $0.pass != pass }) }
    // as worker/src/codes.js shows a code (shownPass): OATH-XXXX-XXXX, whichever prefix it was typed with
    static func shown(_ typed: String) -> String? {
        var s = typed.uppercased().filter { $0.isASCII && ($0.isLetter || $0.isNumber) }
        if s.hasPrefix("OATH") || s.hasPrefix("CNDL") { s = String(s.dropFirst(4)) }
        guard s.count == 8 else { return nil }
        return "OATH-" + s.prefix(4) + "-" + s.suffix(4)
    }
    private static func save(_ list: [Code]) { if let d = try? JSONEncoder().encode(list) { UserDefaults.standard.set(d, forKey: key) } }
}
