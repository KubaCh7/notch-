import AVFoundation
import AppKit

/// All effects are built from the system "Pop":
/// - plug: one Pop
/// - unplug: one Pop, lower
/// - airpods: two quick Pops going up, so it never sounds like the charger
enum SoundPlayer {
    enum Effect: String, CaseIterable {
        case plug
        case unplug
        case airpods

        var title: String {
            switch self {
            case .plug: return "Plug In"
            case .unplug: return "Unplug"
            case .airpods: return "AirPods"
            }
        }

        /// (varispeed rate, start offset in seconds) for each Pop.
        var hits: [(rate: Float, offset: TimeInterval)] {
            switch self {
            case .plug: return [(1.0, 0)]
            case .unplug: return [(0.82, 0)]
            case .airpods: return [(1.12, 0), (1.4, 0.1)]
            }
        }
    }

    private static let popURL = URL(fileURLWithPath: "/System/Library/Sounds/Pop.aiff")
    private static let voiceCount = 2

    private static var engine: AVAudioEngine?
    private static var voices: [(player: AVAudioPlayerNode, varispeed: AVAudioUnitVarispeed)] = []
    private static var buffer: AVAudioPCMBuffer?
    private static var stopWork: DispatchWorkItem?

    /// Plays `effect` if "Play Sound" is on (or always when `force` is true, for previews).
    static func play(_ effect: Effect, force: Bool = false) {
        guard force || AppSettings.shared.playSound else { return }
        if !playPitched(effect) {
            NSSound(named: NSSound.Name("Pop"))?.play()
        }
    }

    private static func playPitched(_ effect: Effect) -> Bool {
        guard prepare(), let engine, let buffer else { return false }

        // The engine only runs while a sound plays, so it never holds the
        // audio device; restarting per sound also follows output switches
        // (e.g. to AirPods that just connected).
        stopWork?.cancel()
        if !engine.isRunning {
            do { try engine.start() } catch { return false }
        }

        for (index, voice) in voices.enumerated() {
            voice.player.stop()
            guard index < effect.hits.count else { continue }
            let hit = effect.hits[index]
            voice.varispeed.rate = hit.rate
            voice.player.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
            if hit.offset > 0 {
                let player = voice.player
                DispatchQueue.main.asyncAfter(deadline: .now() + hit.offset) { player.play() }
            } else {
                voice.player.play()
            }
        }

        let work = DispatchWorkItem {
            voices.forEach { $0.player.stop() }
            engine.stop()
        }
        stopWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: work)
        return true
    }

    private static func prepare() -> Bool {
        if engine != nil { return true }
        guard let file = try? AVAudioFile(forReading: popURL),
              let pcm = AVAudioPCMBuffer(pcmFormat: file.processingFormat,
                                         frameCapacity: AVAudioFrameCount(file.length)),
              (try? file.read(into: pcm)) != nil else { return false }

        let newEngine = AVAudioEngine()
        var newVoices: [(player: AVAudioPlayerNode, varispeed: AVAudioUnitVarispeed)] = []
        for _ in 0..<voiceCount {
            let player = AVAudioPlayerNode()
            let varispeed = AVAudioUnitVarispeed()
            newEngine.attach(player)
            newEngine.attach(varispeed)
            newEngine.connect(player, to: varispeed, format: pcm.format)
            newEngine.connect(varispeed, to: newEngine.mainMixerNode, format: pcm.format)
            newVoices.append((player, varispeed))
        }

        engine = newEngine
        voices = newVoices
        buffer = pcm
        return true
    }
}
