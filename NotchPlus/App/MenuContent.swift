import SwiftUI

/// Items of the menu bar extra (rendered as a native NSMenu).
struct MenuContent: View {
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.openSettings) private var openSettings

    var body: some View {
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
