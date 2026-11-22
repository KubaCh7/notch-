import AppKit
import IOBluetooth

/// Wires system monitors to the notch controller.
@MainActor
final class AppCoordinator {
    static let shared = AppCoordinator()

    private let notch = NotchController.shared
    private let settings = AppSettings.shared
    private let power = PowerMonitor()
    private let bluetooth = BluetoothMonitor()
    private let audioOutput = AudioOutputMonitor()
    /// Both monitors usually fire for one connection; show the card once.
    private var lastHeadphonesShown: [String: Date] = [:]
    private let batteryProvider: BatteryProvider = CompositeBatteryProvider(providers: [
        IOBluetoothBatteryProvider(),
        SystemProfilerBatteryProvider(),
    ])

    func start() {
        power.onPlug = { snapshot in
            Task { @MainActor in AppCoordinator.shared.handlePlug(snapshot) }
        }
        power.onUnplug = { snapshot in
            Task { @MainActor in AppCoordinator.shared.handleUnplug(snapshot) }
        }
        power.start()

        bluetooth.onConnect = { name, address in
            Task { @MainActor in AppCoordinator.shared.handleHeadphonesConnected(name: name, address: address) }
        }
        bluetooth.onDisconnect = { address in
            Task { @MainActor in AppCoordinator.shared.handleHeadphonesDisconnected(address: address) }
        }
        bluetooth.start()

        audioOutput.onBluetoothOutput = { name, address in
            Task { @MainActor in AppCoordinator.shared.handleHeadphonesConnected(name: name, address: address) }
        }
        audioOutput.start()

        Updater.shared.startAutomaticChecks()
    }

    func stop() {
        power.stop()
        bluetooth.stop()
        audioOutput.stop()
    }

    // MARK: Headphones

    private func handleHeadphonesConnected(name: String, address: String) {
        guard settings.airPodsEnabled else { return }

        let key = name.lowercased()
        let now = Date()
        if let last = lastHeadphonesShown[key], now.timeIntervalSince(last) < 8 { return }
        lastHeadphonesShown[key] = now

        showHeadphones(name: name, address: address, delay: VorsaintDetector.popupDelay)
    }

    private func handleHeadphonesDisconnected(address: String) {
        notch.dismiss { content in
            if case .headphones(let info) = content { return info.address == address }
            return false
        }
    }

    private func showHeadphones(name: String, address: String, delay: TimeInterval) {
        let info = HeadphoneInfo(name: name, address: address,
                                 kind: HeadphoneKind.detect(name: name, productID: nil))
        SoundPlayer.play(.airpods)
        notch.present(.headphones(info), delay: delay)
        loadBattery(into: info)
    }

    /// AirPods publish their levels a moment after the link comes up, so poll a few times.
    private func loadBattery(into info: HeadphoneInfo) {
        let provider = batteryProvider
        Task { @MainActor in
            for wait in [0.3, 1.0, 1.5, 2.0] {
                try? await Task.sleep(nanoseconds: UInt64(wait * 1_000_000_000))
                guard let reading = await provider.readBattery(address: info.address, name: info.name) else {
                    continue
                }
                if let productID = reading.productID {
                    info.kind = HeadphoneKind.detect(name: info.name, productID: productID)
                }
                info.battery = reading.battery
                if reading.battery.isComplete(for: info.kind) { return }
            }
        }
    }

    // MARK: Charging

    private func handlePlug(_ snapshot: PowerSnapshot) {
        guard settings.chargingEnabled else { return }
        // No sound here: macOS already plays its own charging chime on plug-in.
        notch.present(.charging(snapshot), delay: VorsaintDetector.popupDelay)
    }

    private func handleUnplug(_ snapshot: PowerSnapshot) {
        guard settings.chargingEnabled, settings.showUnplugAnimation else { return }
        SoundPlayer.play(.unplug)
        notch.present(.unplugged(snapshot), delay: VorsaintDetector.popupDelay)
    }

    // MARK: Tests (menu / settings)

    func testAirPods() {
        if let device = BluetoothMonitor.connectedHeadphones().first {
            showHeadphones(name: device.name ?? "Headphones",
                           address: device.addressString ?? "",
                           delay: 0)
            return
        }

        // Nothing connected: show a sample AirPods Pro card.
        let info = HeadphoneInfo(name: "AirPods Pro", address: "", kind: .airPodsPro)
        SoundPlayer.play(.airpods)
        notch.present(.headphones(info))
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 350_000_000)
            info.battery = HeadphoneBattery(left: 82, right: 79, caseLevel: 56,
                                            caseCharging: true)
        }
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
