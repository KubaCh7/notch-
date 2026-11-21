import AppKit

enum SoundPlayer {
    enum Effect: String {
        case connect = "Glass"
        case plug = "Pop"
        case unplug = "Tink"
    }

    static func play(_ effect: Effect) {
        guard AppSettings.shared.playSound else { return }
        NSSound(named: NSSound.Name(effect.rawValue))?.play()
    }
}
