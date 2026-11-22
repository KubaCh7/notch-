import AppKit

/// Short glass-bell chimes bundled with the app (NotchPlus/Sounds).
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
    }

    private static var cache: [Effect: NSSound] = [:]

    /// Plays `effect` if "Play Sound" is on (or always when `force` is true, for previews).
    static func play(_ effect: Effect, force: Bool = false) {
        guard force || AppSettings.shared.playSound else { return }
        guard let sound = sound(for: effect) else { return }
        sound.stop()
        sound.play()
    }

    private static func sound(for effect: Effect) -> NSSound? {
        if let cached = cache[effect] { return cached }
        guard let url = Bundle.main.url(forResource: effect.rawValue, withExtension: "wav"),
              let sound = NSSound(contentsOf: url, byReference: true) else { return nil }
        sound.volume = 0.8
        cache[effect] = sound
        return sound
    }
}
