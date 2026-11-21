import SwiftUI
import CoreBluetooth

struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    @State private var vorsaintRunning = VorsaintDetector.isRunning

    private var bluetoothStatus: String {
        switch CBManager.authorization {
        case .allowedAlways: return "Allowed"
        case .denied: return "Denied"
        case .restricted: return "Restricted"
        case .notDetermined: return "Not asked yet"
        @unknown default: return "Unknown"
        }
    }

    var body: some View {
        Form {
            Section("Animations") {
                Toggle("Enable AirPods Animation", isOn: $settings.airPodsEnabled)
                Toggle("Enable Charging Animation", isOn: $settings.chargingEnabled)
                Toggle("Play Sound", isOn: $settings.playSound)
            }

            Section("Timing") {
                LabeledContent("Popup Duration") {
                    HStack {
                        Slider(value: $settings.popupDuration,
                               in: AppSettings.durationRange,
                               step: 0.5)
                            .frame(width: 180)
                        Text(String(format: "%.1f s", settings.popupDuration))
                            .monospacedDigit()
                            .frame(width: 44, alignment: .trailing)
                    }
                }
                LabeledContent("Vorsaint Delay") {
                    HStack {
                        Slider(value: $settings.vorsaintDelay,
                               in: AppSettings.vorsaintDelayRange,
                               step: 0.1)
                            .frame(width: 180)
                        Text(String(format: "%.1f s", settings.vorsaintDelay))
                            .monospacedDigit()
                            .frame(width: 44, alignment: .trailing)
                    }
                }
                Text(vorsaintRunning
                     ? "Vorsaint is running. Popups wait this long so its HUD can go first."
                     : "Vorsaint is not running. Popups show immediately.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Bluetooth") {
                LabeledContent("Bluetooth Access") {
                    Text(bluetoothStatus)
                        .foregroundStyle(CBManager.authorization == .allowedAlways ? Color.secondary : Color.orange)
                }
                if CBManager.authorization == .denied || CBManager.authorization == .restricted {
                    Text("Without Bluetooth access Notch+ only notices headphones when audio switches to them, and can't read battery levels.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Button("Open Privacy Settings…") {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Bluetooth") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                }
            }

            Section("General") {
                Toggle("Launch at Login", isOn: Binding(
                    get: { settings.launchAtLogin },
                    set: { settings.setLaunchAtLogin($0) }
                ))
            }

            Section("Preview") {
                HStack {
                    Button("Test AirPods") { AppCoordinator.shared.testAirPods() }
                    Button("Test Charging") { AppCoordinator.shared.testCharging() }
                    Button("Test Unplug") { AppCoordinator.shared.testUnplug() }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .fixedSize(horizontal: false, vertical: true)
        .onAppear {
            vorsaintRunning = VorsaintDetector.isRunning
            settings.refreshLaunchAtLogin()
        }
    }
}
