import AppKit

/// Wires system monitors to the notch controller.
@MainActor
final class AppCoordinator {
    static let shared = AppCoordinator()

    private let notch = NotchController.shared
    private let settings = AppSettings.shared
    private let power = PowerMonitor()

    func start() {
        power.onPlug = { snapshot in
            Task { @MainActor in AppCoordinator.shared.handlePlug(snapshot) }
        }
        power.onUnplug = { snapshot in
            Task { @MainActor in AppCoordinator.shared.handleUnplug(snapshot) }
        }
        power.start()
    }

    func stop() {
        power.stop()
    }

    // MARK: Charging

    private func handlePlug(_ snapshot: PowerSnapshot) {
        guard settings.chargingEnabled else { return }
        SoundPlayer.play(.plug)
        notch.present(.charging(snapshot), delay: VorsaintDetector.popupDelay)
    }

    private func handleUnplug(_ snapshot: PowerSnapshot) {
        guard settings.chargingEnabled else { return }
        SoundPlayer.play(.unplug)
        notch.present(.unplugged(snapshot), delay: VorsaintDetector.popupDelay)
    }

    // MARK: Tests (menu / settings)

    func testAirPods() {
    }

    func testCharging() {
        var snapshot = PowerMonitor.read() ?? Self.sampleSnapshot
        if !snapshot.hasBattery { snapshot = Self.sampleSnapshot }
        snapshot.onAC = true
        SoundPlayer.play(.plug)
        notch.present(.charging(snapshot))
    }

    func testUnplug() {
        var snapshot = PowerMonitor.read() ?? Self.sampleSnapshot
        if !snapshot.hasBattery { snapshot = Self.sampleSnapshot }
        snapshot.onAC = false
        snapshot.isCharging = false
        SoundPlayer.play(.unplug)
        notch.present(.unplugged(snapshot))
    }

    private static let sampleSnapshot = PowerSnapshot(onAC: true,
                                                      isCharging: true,
                                                      isCharged: false,
                                                      percent: 76,
                                                      minutesToFull: 48,
                                                      hasBattery: true)
}
