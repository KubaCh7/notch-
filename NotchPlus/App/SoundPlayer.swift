import AVFoundation
import AppKit

/// All effects use the system "Pop", pitched per effect so they're
/// recognisable but feel like one family.
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

        /// Varispeed rate: below 1 is lower, above 1 is higher.
        var rate: Float {
            switch self {
            case .plug: return 1.0
            case .unplug: return 0.82
            case .airpods: return 1.15
            }
        }
    }

    private static let popURL = URL(fileURLWithPath: "/System/Library/Sounds/Pop.aiff")

    private static var engine: AVAudioEngine?
    private static var player: AVAudioPlayerNode?
    private static var varispeed: AVAudioUnitVarispeed?
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
        guard prepare(), let engine, let player, let varispeed, let buffer else { return false }

        // The engine only runs while a sound plays, so it never holds the
        // audio device; restarting per sound also follows output switches
        // (e.g. to AirPods that just connected).
        stopWork?.cancel()
        if !engine.isRunning {
            do { try engine.start() } catch { return false }
        }
        varispeed.rate = effect.rate
        player.stop()
        player.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
        player.play()

        let work = DispatchWorkItem {
            player.stop()
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
        let newPlayer = AVAudioPlayerNode()
        let newVarispeed = AVAudioUnitVarispeed()
        newEngine.attach(newPlayer)
        newEngine.attach(newVarispeed)
        newEngine.connect(newPlayer, to: newVarispeed, format: pcm.format)
        newEngine.connect(newVarispeed, to: newEngine.mainMixerNode, format: pcm.format)

        engine = newEngine
        player = newPlayer
        varispeed = newVarispeed
        buffer = pcm
        return true
    }
}
