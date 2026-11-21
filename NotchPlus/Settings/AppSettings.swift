import Foundation
import ServiceManagement
import Combine

/// User preferences. Stored in Notch+'s own UserDefaults domain only.
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    private enum Keys {
        static let airPods = "airPodsAnimationEnabled"
        static let charging = "chargingAnimationEnabled"
        static let duration = "popupDuration"
        static let vorsaintDelay = "vorsaintDelay"
        static let playSound = "playSound"
        static let showUnplug = "showUnplugAnimation"
        static let autoCheckUpdates = "autoCheckUpdates"
        static let skippedBuild = "skippedBuild"
        static let all = [airPods, charging, duration, vorsaintDelay, playSound, showUnplug, autoCheckUpdates, skippedBuild]
    }

    static let durationRange: ClosedRange<Double> = 1.5...6.0
    static let vorsaintDelayRange: ClosedRange<Double> = 0.0...2.0

    private let defaults = UserDefaults.standard

    @Published var airPodsEnabled: Bool {
        didSet { defaults.set(airPodsEnabled, forKey: Keys.airPods) }
    }
    @Published var chargingEnabled: Bool {
        didSet { defaults.set(chargingEnabled, forKey: Keys.charging) }
    }
    /// How long an expanded popup stays on screen, in seconds.
    @Published var popupDuration: Double {
        didSet { defaults.set(popupDuration, forKey: Keys.duration) }
    }
    /// Extra delay applied when Vorsaint is running, so its volume HUD can go first.
    @Published var vorsaintDelay: Double {
        didSet { defaults.set(vorsaintDelay, forKey: Keys.vorsaintDelay) }
    }
    @Published var playSound: Bool {
        didSet { defaults.set(playSound, forKey: Keys.playSound) }
    }
    @Published var showUnplugAnimation: Bool {
        didSet { defaults.set(showUnplugAnimation, forKey: Keys.showUnplug) }
    }
    @Published var autoCheckUpdates: Bool {
        didSet { defaults.set(autoCheckUpdates, forKey: Keys.autoCheckUpdates) }
    }
    /// Build number the user chose to skip in the update prompt.
    var skippedBuild: Int {
        get { defaults.integer(forKey: Keys.skippedBuild) }
        set { defaults.set(newValue, forKey: Keys.skippedBuild) }
    }
    @Published private(set) var launchAtLogin: Bool = false

    private init() {
        defaults.register(defaults: [
            Keys.airPods: true,
            Keys.charging: true,
            Keys.duration: 2.5,
            Keys.vorsaintDelay: 0.6,
            Keys.playSound: false,
            Keys.showUnplug: true,
            Keys.autoCheckUpdates: true,
        ])
        airPodsEnabled = defaults.bool(forKey: Keys.airPods)
        chargingEnabled = defaults.bool(forKey: Keys.charging)
        popupDuration = defaults.double(forKey: Keys.duration)
        vorsaintDelay = defaults.double(forKey: Keys.vorsaintDelay)
        playSound = defaults.bool(forKey: Keys.playSound)
        showUnplugAnimation = defaults.bool(forKey: Keys.showUnplug)
        autoCheckUpdates = defaults.bool(forKey: Keys.autoCheckUpdates)
        refreshLaunchAtLogin()
    }

    func resetToDefaults() {
        Keys.all.forEach { defaults.removeObject(forKey: $0) }
        airPodsEnabled = defaults.bool(forKey: Keys.airPods)
        chargingEnabled = defaults.bool(forKey: Keys.charging)
        popupDuration = defaults.double(forKey: Keys.duration)
        vorsaintDelay = defaults.double(forKey: Keys.vorsaintDelay)
        playSound = defaults.bool(forKey: Keys.playSound)
        showUnplugAnimation = defaults.bool(forKey: Keys.showUnplug)
        autoCheckUpdates = defaults.bool(forKey: Keys.autoCheckUpdates)
    }

    func refreshLaunchAtLogin() {
        let status = SMAppService.mainApp.status
        launchAtLogin = (status == .enabled || status == .requiresApproval)
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
                if SMAppService.mainApp.status == .requiresApproval {
                    SMAppService.openSystemSettingsLoginItems()
                }
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("Notch+: launch at login change failed: \(error.localizedDescription)")
        }
        refreshLaunchAtLogin()
    }
}
