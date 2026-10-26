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
            if ATTrackingManager.trackingAuthorizationStatus == .notDetermined { _ = await ATTrackingManager.requestTrackingAuthorization() }
            guard consent.canRequestAds else { return }
            _ = await MobileAds.shared.start()
            ready = true
            preload()
        }
    }

    // loaded ahead of its moment, so showing one never waits
    private func preload() {
        guard ready, interstitial == nil, !loading else { return }
        loading = true
        Task {
            defer { loading = false }
            interstitial = try? await InterstitialAd.load(with: Ads.interstitialUnit, request: Request())
            interstitial?.fullScreenContentDelegate = watcher
        }
    }

    // a player's phone at a natural break (placement P2 between rounds, P3 the results): shown if the limits allow and
    // one is loaded
    func interstitial(room: String, limits: AdsConfig, placement: String) {
        guard limits.enabled else { return }
        let n = shown[room] ?? 0
        if n >= limits.maxPerRoom { return }
        if let last = lastShown, Date().timeIntervalSince(last) < limits.minGap { return }
        Events.send("ad_requested", placement: placement)
        guard let ad = interstitial, let vc = Ads.top() else { Events.send("ad_failed", placement: placement, product: "notloaded"); preload(); return }
        interstitial = nil
        shown[room] = n + 1
        lastShown = Date()
        ad.present(from: vc)
        Events.send("ad_shown", placement: placement)
    }

    fileprivate func closed() { preload() }

    // Google's form for changing ad choices later, where the law asks for one (the start screen's Ad choices)
    var choicesNeeded: Bool { ready && ConsentInformation.shared.privacyOptionsRequirementStatus == .required }
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

// the lobby's banner (P1 a player's, P4 the host's): anchored, as wide as the phone's column
struct AdBanner: View {
    let placement: String
    var body: some View {
        let size = largeAnchoredAdaptiveBanner(width: min(Ads.top()?.view.bounds.width ?? 390, 520))
        BannerBox(size: size).frame(width: size.size.width, height: size.size.height).frame(maxWidth: .infinity)
            .onAppear { Events.send("ad_requested", placement: placement) }
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

// a free game's foot: the lobby's banner, and after a round, on a player's phone, who can end the ads (words only: a
// player can't buy anything)
struct AdStrip: View {
    let v: Snapshot
    let me: Me
    @Environment(Session.self) private var session
    var body: some View {
        if session.tier.tier == "free", let ads = session.tier.ads, ads.enabled {
            if v.phase == "lobby" {
                // the host's banner gives way to the offer while it's showing (Offers, U1)
                if ads.banner && Ads.shared.ready && !(me.director && Offers.lobbyDue(v, session)) { AdBanner(placement: me.director ? "P4" : "P1") }
            } else if !me.director && ["day", "break", "end"].contains(v.phase) && v.round > ads.afterRound {
                Text("The host can remove ads for everyone tonight.")
                    .font(Theme.ui(14)).foregroundStyle(Theme.tallow2)
                    .frame(maxWidth: .infinity).padding(.vertical, 8)
                    .background(Theme.soot.opacity(0.85))
            }
        }
    }
}
