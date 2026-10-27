import AVFoundation

// The music and sounds (src/audio.js), played from the files tools/sounds.mjs renders from the website's own
// synthesiser. The score follows the scene: each change crossfades over a second or so; a big moment's sound ducks the
// music under it, as the page's duck() does. Sound plays on the TV, or on the host's phone when there's no TV.
@MainActor
final class Sound {
    static let shared = Sound()

    private(set) var enabled = false // the sound was turned on (the TV's button, or the host's tools)
    private(set) var muted = false
    private weak var owner: Session?
    private var current: String?
    private let audio = Audio()

    func follows(_ s: Session) -> Bool { enabled && owner === s }
    func isPlaying(for s: Session) -> Bool { follows(s) && !muted }

    // the page's enableSound(): set the music going, and a chime to say it's on
    func enable(for s: Session) {
        owner = s
        if !enabled { enabled = true; audio.setUp() }
        muted = false
        audio.volume(1, over: 0)
        if let v = s.view { scene(v.scene) } else { scene("lobby") }
        cue(["chime"])
        NotificationCenter.default.post(name: Sound.changed, object: nil)
    }

    func toggleMute() {
        muted.toggle()
        audio.volume(muted ? 0 : 1, over: 0.15)
        NotificationCenter.default.post(name: Sound.changed, object: nil)
    }

    // a session that ends gives up the sound
    func release(_ s: Session) { if owner === s { owner = nil; current = nil; audio.stopMusic() } }

    static let changed = Notification.Name("Sound.changed")

    // ---- the score
    func scene(_ name: String) {
        guard enabled, name != current else { return }
        current = name
        audio.music(name)
    }

    // ---- the moments
    func cue(_ names: [String]) {
        guard enabled, !muted else { return }
        audio.cue(names)
    }
}

// The engine and its players, worked only on a queue of their own: over AirPlay, starting, stopping or switching audio
// can take seconds, and the screens must never wait for it (on the main thread it froze the phone and the TV when a
// Trial's countdown ran out, the chime and the Trial's music together).
private final class Audio: @unchecked Sendable {
    private let q = DispatchQueue(label: "uk.co.thebetrayal.sound", qos: .userInitiated)
    private let engine = AVAudioEngine()
    private let bus = AVAudioMixerNode()          // the music, ducked under the big moments
    private var decks: [(player: AVAudioPlayerNode, mixer: AVAudioMixerNode)] = []
    private var deck = 0
    private var playing: String?                  // the music asked for last
    private var effects: [String: AVAudioPlayer] = [:]
    private var fades: [ObjectIdentifier: Int] = [:] // each mixer's latest fade: a newer one stops an older one
    private var ducking = 0
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)! // as the files are rendered

    // how long each sound holds the music down (duck(sec) in audio.js)
    private let ducks: [String: Double] = ["gold": 1.8, "dawn": 2.5, "poison": 3.4, "reveal": 2.4, "win": 5]
    private static let musicLevel: Float = 1

    func setUp() {
        q.async { [self] in
            try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try? AVAudioSession.sharedInstance().setActive(true)
            engine.attach(bus)
            engine.connect(bus, to: engine.mainMixerNode, format: nil)
            for _ in 0..<2 {
                let p = AVAudioPlayerNode(), m = AVAudioMixerNode()
                engine.attach(p); engine.attach(m)
                engine.connect(p, to: m, format: format)
                engine.connect(m, to: bus, format: format)
                decks.append((p, m))
            }
            bus.outputVolume = Audio.musicLevel
            NotificationCenter.default.addObserver(forName: .AVAudioEngineConfigurationChange, object: engine, queue: nil) { [weak self] _ in
                self?.q.async { self?.restart() }
            }
            try? engine.start()
            for name in ["chime", "drum", "beat", "alarm", "seal", "snuff", "gold", "dawn", "poison", "reveal", "win"] {
                if let url = Bundle.main.url(forResource: "sfx-" + name, withExtension: "m4a"), let p = try? AVAudioPlayer(contentsOf: url) {
                    p.prepareToPlay(); effects[name] = p
                }
            }
        }
    }

    // (on q) the output changed under the engine (AirPlay, headphones): start again, with the music it was playing
    private func restart() {
        try? engine.start()
        if let name = playing { playing = nil; start(name) }
    }

    func music(_ name: String) { q.async { [self] in start(name) } }

    // (on q) the scene's music, crossfaded from the last; the file is read off the queue, so sounds don't wait for it
    private func start(_ name: String) {
        playing = name
        guard let url = Bundle.main.url(forResource: "music-" + name, withExtension: "m4a") else { return }
        DispatchQueue.global(qos: .userInitiated).async { [self] in
            guard let file = try? AVAudioFile(forReading: url),
                  let buf = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length)),
                  (try? file.read(into: buf)) != nil, buf.format.sampleRate == 44100, buf.format.channelCount == 2 else { return }
            q.async { [self] in
                guard playing == name, !decks.isEmpty else { return }
                if !engine.isRunning { try? engine.start() }
                let old = decks[deck]
                deck = 1 - deck
                let new = decks[deck]
                new.player.stop()
                new.mixer.outputVolume = old.player.isPlaying ? 0.35 : 1
                new.player.scheduleBuffer(buf, at: nil, options: .loops)
                new.player.play()
                if old.player.isPlaying {
                    ramp(new.mixer, to: 1, over: 1.1)
                    ramp(old.mixer, to: 0, over: 1.2) { old.player.stop() }
                }
            }
        }
    }

    func stopMusic() {
        q.async { [self] in
            playing = nil
            for d in decks { d.player.stop() }
        }
    }

    func volume(_ v: Float, over seconds: Double) { q.async { [self] in ramp(engine.mainMixerNode, to: v, over: seconds) } }

    func cue(_ names: [String]) {
        q.async { [self] in
            for (i, name) in names.enumerated() {
                guard let p = effects[name] else { continue }
                let play = { [self] in
                    p.currentTime = 0
                    p.play()
                    if let d = ducks[name] { duck(d) }
                }
                if i == 0 { play() } else { q.asyncAfter(deadline: .now() + 1.2, execute: play) } // dawn, then the poison
            }
        }
    }

    // (on q)
    private func duck(_ seconds: Double) {
        ducking += 1
        let mine = ducking
        ramp(bus, to: Audio.musicLevel * 0.28, over: 0.1)
        q.asyncAfter(deadline: .now() + seconds) { [self] in
            guard ducking == mine else { return }
            ramp(bus, to: Audio.musicLevel, over: 1.2)
        }
    }

    // (on q) a mixer's volume, moved smoothly
    private func ramp(_ m: AVAudioMixerNode, to target: Float, over seconds: Double, then done: (() -> Void)? = nil) {
        let id = ObjectIdentifier(m), mine = (fades[id] ?? 0) + 1
        fades[id] = mine
        guard seconds > 0 else { m.outputVolume = target; done?(); return }
        let from = m.outputVolume, steps = max(1, Int(seconds * 30))
        for i in 1...steps {
            q.asyncAfter(deadline: .now() + seconds * Double(i) / Double(steps)) { [self] in
                guard fades[id] == mine else { return }
                m.outputVolume = from + (target - from) * Float(i) / Float(steps)
                if i == steps { done?() }
            }
        }
    }
}
