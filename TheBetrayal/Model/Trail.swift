import Foundation
import UIKit
import MetricKit

// What happened on this phone (or TV) at a Table, sent to that Table's log on the server (POST /api/g/CODE/events, as
// the website's src/diag.js sends a browser's): what it is (open), whose phone (who), the screens it showed (view), the
// actions it sent (act, never anything typed), ads, offers and purchases, connection trouble (net), going to the
// background (vis), and errors and crashes. /admin shows a Table's log device by device; errors and crashes also reach
// its error log with the Table's code. Each device is a random number at each Table, not linked from one to the next.
@MainActor
final class Trail {
    static let shared = Trail()

    private var queues: [String: [[String: Any]]] = [:] // a Table's events waiting to be sent
    private var timers: [String: Task<Void, Never>] = [:]
    private var roles: [String: String] = [:]           // host, player or tv
    private var opened: Set<String> = []

    static let build: String = {
        let i = Bundle.main.infoDictionary
        return (i?["CFBundleShortVersionString"] as? String ?? "?") + " (" + (i?["CFBundleVersion"] as? String ?? "?") + ")"
    }()
    static let model: String = {
        if let sim = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] { return sim + " (simulator)" }
        var u = utsname(); uname(&u)
        return withUnsafeBytes(of: &u.machine) { String(decoding: $0.prefix(while: { $0 != 0 }), as: UTF8.self) }
    }()

    // this device's number at a Table, kept so reopening the app is the same device
    static func device(_ room: String) -> String {
        let k = "bt-dev-" + room
        if let d = UserDefaults.standard.string(forKey: k) { return d }
        let d = String(UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased().prefix(8))
        UserDefaults.standard.set(d, forKey: k)
        return d
    }

    // a Table this device has started taking part in (once each time the app runs): what the device is
    func open(_ room: String, tv: Bool) {
        roles[room] = roles[room] ?? (tv ? "tv" : "player")
        UserDefaults.standard.set(room, forKey: "bt-trail-room") // where a crash on the next launch is reported
        guard opened.insert(room).inserted else { return }
        let s = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first?.screen.bounds.size ?? .zero, text = UIApplication.shared.preferredContentSizeCategory.rawValue.replacingOccurrences(of: "UICTContentSizeCategory", with: "")
        log(room, "open", "app " + Trail.build + " · " + (tv ? "TV" : "phone") + " · " + Trail.model + " · iOS " + UIDevice.current.systemVersion
            + " · " + "\(Int(s.width))×\(Int(s.height))" + " · text " + text)
    }

    func role(_ room: String, _ r: String) { roles[room] = r }

    func log(_ room: String, _ k: String, _ m: String, stack: String? = nil, src: String? = nil) {
        guard !room.isEmpty else { return }
        var e: [String: Any] = ["t": Date().timeIntervalSince1970 * 1000, "k": k, "m": String(m.prefix(400))]
        if let stack { e["stack"] = String(stack.prefix(1500)) }
        if let src { e["src"] = src }
        var q = queues[room] ?? []
        q.append(e)
        if q.count > 500 { q.removeFirst(q.count - 500) }
        queues[room] = q
        if k == "error" || k == "crash" { flush(room) }
        else if timers[room] == nil { timers[room] = Task { [weak self] in try? await Task.sleep(nanoseconds: 30_000_000_000); self?.flush(room) } }
    }

    // to the Table this phone is at, if it's at one (the ads, offers and purchases, which don't know their Table)
    func here(_ k: String, _ m: String) {
        if let room = AppModel.shared.current?.room { log(room, k, m) }
    }

    func flush(_ room: String) {
        timers[room]?.cancel(); timers[room] = nil
        guard var q = queues[room], !q.isEmpty else { return }
        let batch = Array(q.prefix(80)); q.removeFirst(batch.count); queues[room] = q
        let role = roles[room] ?? "player"
        let body: [String: Any] = ["app": true, "role": role, "host": role == "host", "device": Trail.device(room), "build": Trail.build, "events": batch]
        Task { _ = try? await API.room(room, "events", body: body) } // well under the server's 32 KB a batch
        if !q.isEmpty { timers[room] = Task { [weak self] in try? await Task.sleep(nanoseconds: 1_000_000_000); self?.flush(room) } }
    }

    func flushAll() { for room in queues.keys { flush(room) } }
}

// Crashes, as iOS reports them on the next launch (MetricKit), to the log of the Table the device was last at
final class Crashes: NSObject, MXMetricManagerSubscriber {
    static let shared = Crashes()

    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        guard let room = UserDefaults.standard.string(forKey: "bt-trail-room") else { return }
        for p in payloads {
            for c in p.crashDiagnostics ?? [] {
                let what = ["crash", c.exceptionType.map { "exception \($0)" }, c.signal.map { "signal \($0)" }, c.terminationReason]
                    .compactMap { $0 }.joined(separator: " · ") + " · app " + c.metaData.applicationBuildVersion
                let stack = String(data: c.callStackTree.jsonRepresentation(), encoding: .utf8)
                Task { @MainActor in Trail.shared.log(room, "crash", what, stack: stack) }
            }
        }
    }
}
