import SwiftUI

/// Items of the menu bar extra (rendered as a native NSMenu).
struct MenuContent: View {
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.openSettings) private var openSettings
    @ObservedObject private var updater = Updater.shared

    var body: some View {
        if let release = updater.available {
            Button("Update to \(release.version)…") {
                Task { await updater.install(release) }
            }
            .disabled(updater.isBusy)
            Divider()
        }

        Toggle("Enable AirPods Animation", isOn: $settings.airPodsEnabled)
        Toggle("Enable Charging Animation", isOn: $settings.chargingEnabled)

        Divider()

        Button("Test AirPods") { AppCoordinator.shared.testAirPods() }
        Button("Test Charging") { AppCoordinator.shared.testCharging() }

        Divider()

        Toggle("Launch at Login", isOn: Binding(
            get: { settings.launchAtLogin },
            set: { settings.setLaunchAtLogin($0) }
        ))

        Button(updater.state == .checking ? "Checking for Updates…" : "Check for Updates…") {
            Task { await updater.check(userInitiated: true) }
        }
        .disabled(updater.isBusy)

        Button("Settings…") {
            // The user explicitly asked for a window, so activating here is fine.
            NSApp.activate()
            openSettings()
        }
        .keyboardShortcut(",")

        Divider()

        Button("Quit Notch+") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}
