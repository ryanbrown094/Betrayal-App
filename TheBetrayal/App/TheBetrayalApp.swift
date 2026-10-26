import SwiftUI
import UIKit
import MetricKit

@main
struct TheBetrayalApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    init() { Theme.registerFonts() }

    var body: some Scene {
        WindowGroup {
            Root()
                .preferredColorScheme(.dark)
                .tint(Theme.brass2)
                .onOpenURL { url in AppModel.shared.link = Codes.room(in: url.absoluteString) }
        }
    }
}

private struct Root: View {
    var body: some View {
        #if DEBUG
        if let demo = Demo.launch { demo } else { HomeView() }
        #else
        HomeView()
        #endif
    }
}

// The app as a whole: the Table this phone is at, and the TV a second display shows for it
@MainActor @Observable
final class AppModel {
    static let shared = AppModel()

    private(set) var current: Session?   // the phone's own Table, as a player
    private(set) var externalTV: Session? // the same Table as the TV sees it, for a second display
    private(set) var watching: Session?   // the Table this device is the TV of (an iPad or a spare phone): a second display shows it too
    var link: String?                      // a Table to join, from a link the app was opened with
    var externalConnected = false { didSet { sync() } }
    @ObservationIgnored private var sessions: [Target: Session] = [:]

    func session(for t: Target) -> Session {
        if let s = sessions[t] { return s }
        let s: Session
        switch t.start {
        case .play: s = Session(room: t.room)
        case .named: s = Session(room: t.room); s.useSavedName = true
        case .create: s = Session(room: t.room, screen: .create(test: false), pass: t.pass); s.useSavedName = true
        case .bots: s = Session(room: t.room, screen: .create(test: true), pass: t.pass)
        case .practice: s = Session(room: t.room, screen: .create(test: true)); s.practice = true
        case .tv: s = Session(room: t.room, screen: .tv)
        }
        sessions[t] = s
        return s
    }

    func opened(_ s: Session) { if s.isTV { watching = s } else { current = s; sync() } }

    func closed(_ s: Session) {
        if current === s { current = nil; sync() }
        if watching === s { watching = nil }
        sessions = sessions.filter { $0.value !== s }
        Sound.shared.release(s)
    }

    // a second display (a TV over AirPlay or a cable) shows the TV of the Table this phone is at, with its sound
    private func sync() {
        let room = externalConnected ? current?.room : nil
        if externalTV?.room == room { return }
        if let old = externalTV { old.stop(); Sound.shared.release(old) }
        externalTV = room.map { Session(room: $0, screen: .tv) }
        if let tv = externalTV { tv.start(); Sound.shared.enable(for: tv) }
    }
}

// ---------------------------------------------------------------------------------------------------------------
// A second display gets a scene of its own (not a mirror of the phone, which would show the player's role): the TV.
@MainActor
final class AppDelegate: NSObject, UIApplicationDelegate {
    // crashes, reported by iOS on the next launch, go to the log of the Table they happened at (Model/Trail.swift)
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        MXMetricManager.shared.add(Crashes.shared)
        return true
    }

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        if connectingSceneSession.role == .windowExternalDisplayNonInteractive {
            let c = UISceneConfiguration(name: "TV", sessionRole: connectingSceneSession.role)
            c.delegateClass = ExternalDisplay.self
            return c
        }
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }
}

@MainActor
final class ExternalDisplay: NSObject, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let ws = scene as? UIWindowScene else { return }
        let w = UIWindow(windowScene: ws)
        w.rootViewController = UIHostingController(rootView: ExternalTV().preferredColorScheme(.dark))
        w.isHidden = false
        window = w
        AppModel.shared.externalConnected = true
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        window = nil
        AppModel.shared.externalConnected = false
    }
}

private struct ExternalTV: View {
    private let model = AppModel.shared
    var body: some View {
        ZStack {
            if let tv = model.externalTV ?? model.watching { TVView(external: true).environment(tv).id(tv.room) }
            else {
                ZStack {
                    Backdrop(tv: true)
                    VStack(spacing: 18) {
                        Crest().frame(width: 140, height: 164).foregroundStyle(Theme.brass2)
                        Text("The Betrayal").font(Theme.disp(80, fixed: true)).foregroundStyle(Theme.brass2)
                        Text("Join a Table, or set this device up as its TV, and the game appears here.").font(Theme.ui(28, fixed: true)).foregroundStyle(Theme.tallow2)
                    }
                }
            }
        }
        .ignoresSafeArea()
    }
}
