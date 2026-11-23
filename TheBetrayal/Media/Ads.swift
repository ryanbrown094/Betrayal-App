import SwiftUI
import UIKit
import GoogleMobileAds
import UserMessagingPlatform
import AppTrackingTransparency

// Ads in the app's free games (the server's tiers.js: the limits come with every poll, as Tier.ads). Nothing here runs at
// a game with a pass, nor on the TV: the SDK isn't started until a phone is at a free game. Google's consent form comes
// first (UK GDPR), then Apple's tracking question; either way the ads show, personalised or not. An ad that hasn't
// loaded by its moment is skipped: nothing here holds up the game.
@MainActor @Observable
final class Ads {
    static let shared = Ads()
    // AdMob's units are in Info.plist (BTAdBanner, BTAdInterstitial); a Debug build (run from Xcode) always shows Google's
    // test ads, as AdMob's rules require while developing, and so does a Release build without its own unit yet
    static let bannerUnit = unit("BTAdBanner", test: "ca-app-pub-3940256099942544/2435281174")
    static let interstitialUnit = unit("BTAdInterstitial", test: "ca-app-pub-3940256099942544/4411468910")
    private static func unit(_ key: String, test: String) -> String {
        #if DEBUG
        return test
        #else
        return Bundle.main.object(forInfoDictionaryKey: key) as? String ?? test
        #endif
    }

    private(set) var ready = false // asked for consent, and the SDK started: ads may load
    private(set) var choicesNeeded = false // the law asks for a way to change ad choices here (the start screen's Ad choices)
    @ObservationIgnored private var starting = false
    @ObservationIgnored private var interstitial: InterstitialAd?
    @ObservationIgnored private var loading = false
    @ObservationIgnored private var lastShown: Date?
    @ObservationIgnored private var shown: [String: Int] = [:] // interstitials shown at each Table
    private let watcher = Watcher()

    func prepare() {
        guard !ready, !starting else { return }
        starting = true
        Task {
            defer { starting = false }
            let consent = ConsentInformation.shared
            try? await consent.requestConsentInfoUpdate(with: RequestParameters())
            if let vc = Ads.top() { try? await ConsentForm.loadAndPresentIfRequired(from: vc) }
            #if DEBUG
            let ask = !ProcessInfo.processInfo.arguments.contains("-noatt") // the CI's simulator can't answer Apple's question
            #else
            let ask = true
            #endif
            if ask, ATTrackingManager.trackingAuthorizationStatus == .notDetermined { _ = await ATTrackingManager.requestTrackingAuthorization() }
            choicesNeeded = consent.privacyOptionsRequirementStatus == .required
            let asked = ["unknown", "required", "not required", "obtained"], tracked = ["not asked", "restricted", "denied", "allowed"]
            let c = consent.consentStatus.rawValue, t = Int(ATTrackingManager.trackingAuthorizationStatus.rawValue)
            Trail.shared.here("ad", "consent " + (asked.indices.contains(c) ? asked[c] : "\(c)") + " · tracking " + (tracked.indices.contains(t) ? tracked[t] : "\(t)") + " · " + (consent.canRequestAds ? "ads may load" : "no ads"))
            guard consent.canRequestAds else { return }
            _ = await MobileAds.shared.start()
            ready = true
        }
    }

    // loaded ahead of its moment, so showing one never waits, and only while nobody is tapping (Session.adMoment): a load
    // keeps the phone busy for a few seconds. Whether a load started (none while one's loaded, loading or ads aren't on)
    @discardableResult func preload() -> Bool {
        guard ready, interstitial == nil, !loading else { return false }
        loading = true
        Task {
            defer { loading = false }
            interstitial = try? await InterstitialAd.load(with: Ads.interstitialUnit, request: Request())
            interstitial?.fullScreenContentDelegate = watcher
        }
        return true
    }

    // a phone at a natural break (placement P2 as a Reckoning's debate starts, P7 at night once its choice is in, P3 the
    // results): shown if the limits allow and one is loaded
    func interstitial(room: String, limits: AdsConfig, placement: String) {
        guard limits.enabled else { return }
        let n = shown[room] ?? 0
        if n >= limits.maxPerRoom { return }
        if let last = lastShown, Date().timeIntervalSince(last) < limits.minGap { return }
        Events.send("ad_requested", placement: placement)
        guard let ad = interstitial, let vc = Ads.top() else { Events.send("ad_failed", placement: placement, product: "notloaded"); return }
        interstitial = nil
        shown[room] = n + 1
        lastShown = Date()
        ad.present(from: vc)
        Events.send("ad_shown", placement: placement)
        #if DEBUG
        // the CI's QA run can't tap the ad's close button: it closes itself, so the game's screens can be photographed
        if ProcessInfo.processInfo.arguments.contains("-adclose") {
            Task { try? await Task.sleep(nanoseconds: 3_000_000_000); vc.presentedViewController?.dismiss(animated: false) } // Google's delegate then calls closed()
        }
        #endif
    }

    fileprivate func closed() { Trail.shared.here("ad", "ad_closed") }

    // at launch, whether the law asks for a way to change ad choices, so the start screen offers it before any game
    // (Google's consent information only: the ads themselves still wait for a free game)
    func checkChoices() {
        Task {
            try? await ConsentInformation.shared.requestConsentInfoUpdate(with: RequestParameters())
            choicesNeeded = ConsentInformation.shared.privacyOptionsRequirementStatus == .required
        }
    }

    // Google's form for changing ad choices later, where the law asks for one (the start screen's Ad choices)
    func showChoices() {
        guard let vc = Ads.top() else { return }
        Task { try? await ConsentForm.presentPrivacyOptionsForm(from: vc) }
    }

    static func top() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            .first { $0.session.role == .windowApplication && $0.activationState == .foregroundActive }
        var vc = scene?.keyWindow?.rootViewController
        while let p = vc?.presentedViewController { vc = p }
        return vc
    }
}

private final class Watcher: NSObject, FullScreenContentDelegate {
    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) { Task { @MainActor in Ads.shared.closed() } }
    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) { Task { @MainActor in Ads.shared.closed() } }
}

// a free game's banner at the foot of the screen (P1 a player's lobby, P4 the host's; P5 a player's game, P6 the host's):
// anchored, as wide as the phone's column, and the smaller size once the game starts, so the screens above keep their room
struct AdBanner: View {
    let placement: String
    var large = true
    @State private var width: CGFloat = 0
    // as wide as the space it's given (not the window's: the iPhone Duo folded keeps a narrower screen), and a new one
    // when that changes. Read with a GeometryReader, which takes the width it's offered whatever is in it, so the banner
    // can't widen what it's in: read from itself, a width taken before the iPhone Duo's sidebar came (520) held the
    // column beside it at 520 when it had 419, and the lobby spilled off both sides
    var body: some View {
        let w = min(width, 520), size = w > 0 ? (large ? largeAnchoredAdaptiveBanner(width: w) : currentOrientationAnchoredAdaptiveBanner(width: w)) : nil
        GeometryReader { g in
            ZStack {
                Color.clear.onAppear { width = g.size.width }.onChange(of: g.size.width) { _, x in width = x }
                if let size {
                    BannerBox(size: size).frame(width: size.size.width, height: size.size.height)
                        .id("\(Int(size.size.width))x\(Int(size.size.height))")
                        .onAppear { Events.send("ad_requested", placement: placement) } // each new banner
                }
            }
            .frame(width: g.size.width, height: g.size.height)
        }
        .frame(height: size?.size.height ?? 1)
    }
}

private struct BannerBox: UIViewRepresentable {
    let size: AdSize
    func makeUIView(context: Context) -> BannerView {
        let b = BannerView(adSize: size)
        b.adUnitID = Ads.bannerUnit
        b.rootViewController = Ads.top()
        b.load(Request())
        return b
    }
    func updateUIView(_ b: BannerView, context: Context) {}
}

// a free game's foot: the banner, all game, the lobby's included; and between Trials, on a player's phone, who can end
// the ads (words only: a player can't buy anything)
struct AdStrip: View {
    let v: Snapshot
    let me: Me
    @Environment(Session.self) private var session
    var body: some View {
        if session.tier.tier == "free", let ads = session.tier.ads, ads.enabled {
            let lobby = v.phase == "lobby"
            VStack(spacing: 0) {
                if !lobby && !me.director && ["day", "talk", "break", "end"].contains(v.phase) && v.round > ads.afterRound {
                    Text("The host can remove ads for everyone tonight.")
                        .font(Theme.ui(14)).foregroundStyle(Theme.tallow2)
                        .frame(maxWidth: .infinity).padding(.vertical, 8)
                        .background(Theme.soot.opacity(0.85))
                }
                // one banner from the lobby on (the host's gives way to the offer in the lobby while it's showing, Offers U1)
                if ads.banner && Ads.shared.ready && !(lobby && me.director && Offers.lobbyDue(v, session)) {
                    AdBanner(placement: lobby ? (me.director ? "P4" : "P1") : (me.director ? "P6" : "P5"), large: lobby)
                }
            }
        }
    }
}
