import Foundation

// The game's server: the same Worker and the same calls as the website (worker/src/index.js). Production unless a
// Debug build is launched with -server URL (the CI's local Worker).
enum Server {
    static let production = URL(string: "https://thebetrayal.co.uk")!
    static var base: URL = {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "-server"), i + 1 < args.count, let u = URL(string: args[i + 1]) { return u }
        #endif
        return production
    }()
    // the TV's QR code: opens the app at that Table (CFBundleURLTypes in Info.plist), so joining needs no website
    static func joinLink(_ room: String) -> String { "thebetrayal://join/" + room }

    static let session: URLSession = {
        let c = URLSessionConfiguration.default
        c.requestCachePolicy = .reloadIgnoringLocalCacheData
        c.urlCache = nil
        c.timeoutIntervalForRequest = 15
        c.httpCookieStorage = .shared // the staging site's password cookie, if one is ever set
        return URLSession(configuration: c)
    }()
}

struct Reply {
    let status: Int
    let json: JSON
    var ok: Bool { (200..<300).contains(status) }
    var error: String? { json["error"].string }
}

struct Offline: Error {}

enum API {
    // POST with a body, GET without. X-Tok says which player this phone is.
    static func call(_ path: String, body: [String: Any]? = nil, token: String? = nil) async throws -> Reply {
        guard let url = URL(string: path, relativeTo: Server.base) else { throw Offline() }
        var req = URLRequest(url: url)
        req.httpMethod = body == nil ? "GET" : "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token { req.setValue(token, forHTTPHeaderField: "X-Tok") }
        if let body { req.httpBody = JSON.encode(body) }
        let result: (Data, URLResponse)
        do { result = try await Server.session.data(for: req) } catch { throw Offline() }
        let (data, resp) = result
        let status = (resp as? HTTPURLResponse)?.statusCode ?? 0
        let json = (try? JSON(data: data)) ?? .object(["error": .string("The server didn’t answer properly.")])
        return Reply(status: status, json: json)
    }

    static func room(_ room: String, _ path: String, body: [String: Any]? = nil, token: String? = nil) async throws -> Reply {
        try await call("/api/g/" + room + "/" + path, body: body, token: token)
    }

    // the home page's calls (site/index.html): a code opens its Table, and a Table says which way it plays. The app's
    // calls say they're the app's (app: true): its codes are a pool of their own, and no code is a free game (the
    // server's tiers.js).
    struct Opened { let room: String; let test: Bool; let sub: Bool; let again: Bool; let kind: String?; let until: Date? }
    enum Mode { case unset, modern, classic }

    static func open(pass: String?, fresh: Bool) async throws -> Opened {
        var body: [String: Any] = ["app": true, "fresh": fresh]
        if let pass { body["pass"] = pass }
        let r: Reply
        do { r = try await call("/api/games", body: body) } catch { throw Failure("Can’t reach the server. Check you’re online.") }
        guard r.ok, let room = r.json["room"].string else { throw Failure(r.error ?? "That didn’t work. Try again.") }
        return Opened(room: room, test: r.json["test"].bool ?? false, sub: r.json["sub"].bool ?? false, again: r.json["again"].bool ?? false,
                      kind: r.json["kind"].string, until: r.json["until"].double.map { Date(timeIntervalSince1970: $0 / 1000) })
    }

    // what each of the app's codes on this phone can do now
    struct CodeStatus { let kind: String; let state: String; let until: Date? }
    static func codes(_ passes: [String]) async -> [String: CodeStatus] {
        guard !passes.isEmpty, let r = try? await call("/api/app/codes", body: ["passes": passes]), r.ok else { return [:] }
        var out: [String: CodeStatus] = [:]
        for c in r.json["codes"].array {
            guard let p = c["pass"].string else { continue }
            out[p] = CodeStatus(kind: c["kind"].string ?? "", state: c["state"].string ?? "", until: c["until"].double.map { Date(timeIntervalSince1970: $0 / 1000) })
        }
        return out
    }

    static func mode(of room: String) async -> Mode {
        guard let r = try? await self.room(room, "m") else { return .unset }
        if r.json["none"].bool == true { return r.json["classic"].bool == true ? .classic : .unset }
        return r.json["view"].isNull ? .unset : .modern
    }
}

// a room's tier (the server's tiers.js): whether it shows ads, and whether every Trial and the full question banks are
// in it. A room the website opened has none, and plays as the website always has.
struct Tier: Equatable {
    let tier: String
    let adFree: Bool
    let content: String
    let ads: AdsConfig? // a free game's: whether ads show, and their limits
    static let full = Tier(tier: "full", adFree: true, content: "all", ads: nil)
    private init(tier: String, adFree: Bool, content: String, ads: AdsConfig?) { self.tier = tier; self.adFree = adFree; self.content = content; self.ads = ads }
    init?(_ j: JSON) {
        guard let t = j["tier"].string else { return nil }
        self.init(tier: t, adFree: j["adFree"].bool ?? true, content: j["content"].string ?? "all", ads: AdsConfig(j["ads"]))
    }
}

// the server's adsConfig (tiers.js), so the limits change without an app update
struct AdsConfig: Equatable {
    let enabled: Bool
    let minGap: Double   // seconds between interstitials on one phone
    let maxPerRoom: Int
    let afterRound: Int  // none before the round after this one
    let banner: Bool
    init?(_ j: JSON) {
        guard !j.isNull else { return nil }
        enabled = j["enabled"].bool ?? false
        minGap = j["interstitialMinGapSec"].double ?? 240
        maxPerRoom = j["interstitialMaxPerRoom"].int ?? 4
        afterRound = j["firstInterstitialAfterRound"].int ?? 1
        banner = j["bannerEnabled"].bool ?? true
    }
}

struct Failure: LocalizedError {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}

enum Codes {
    // six letters and numbers (worker/src/codes.js leaves out 0, O, 1, I and L, but a mistyped code just isn't found)
    static func isRoom(_ s: String) -> Bool { s.count == 6 && s.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber) } }
    static func clean(_ s: String) -> String { String(s.uppercased().filter { $0.isASCII && ($0.isLetter || $0.isNumber) }.prefix(6)) }

    // the Table in a scanned QR code or an opened link: the app's own (thebetrayal://join/ABC123), the website TV's
    // (https://…/m/ABC123, …/t/ABC123, …/join?code=ABC123), or just the code
    static func room(in s: String) -> String? {
        let s = s.trimmingCharacters(in: .whitespacesAndNewlines)
        if isRoom(s) { return s.uppercased() }
        guard let u = URLComponents(string: s) else { return nil }
        if let q = u.queryItems?.first(where: { $0.name == "code" || $0.name == "room" })?.value, isRoom(q) { return q.uppercased() }
        let parts = ((u.host.map { [$0] } ?? []) + u.path.split(separator: "/").map(String.init))
        if let last = parts.last, isRoom(last), parts.count >= 2, ["join", "m", "t", "tv"].contains(parts[parts.count - 2].lowercased()) { return last.uppercased() }
        return nil
    }
}
