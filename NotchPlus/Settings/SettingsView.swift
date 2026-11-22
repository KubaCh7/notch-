import SwiftUI
import CoreBluetooth

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettings()
                .tabItem { Label("General", systemImage: "gearshape") }
            AnimationSettings()
                .tabItem { Label("Animations", systemImage: "sparkles") }
            UpdateSettings()
                .tabItem { Label("Updates", systemImage: "arrow.down.circle") }
            AboutView()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 480, height: 400)
    }
}

// MARK: - General

private struct GeneralSettings: View {
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        Form {
            Section {
                Toggle("Launch at Login", isOn: Binding(
                    get: { settings.launchAtLogin },
                    set: { settings.setLaunchAtLogin($0) }
                ))
                Toggle("Play Sound", isOn: $settings.playSound)
                LabeledContent("Preview") {
                    HStack {
                        ForEach(SoundPlayer.Effect.allCases, id: \.self) { effect in
                            Button(effect.title) { SoundPlayer.play(effect, force: true) }
                        }
                    }
                }
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

            Section {
                Button("Reset All Settings") { settings.resetToDefaults() }
            }
        }
        .formStyle(.grouped)
        .onAppear { settings.refreshLaunchAtLogin() }
    }

    private var bluetoothStatus: String {
        switch CBManager.authorization {
        case .allowedAlways: return "Allowed"
        case .denied: return "Denied"
        case .restricted: return "Restricted"
        case .notDetermined: return "Not asked yet"
        @unknown default: return "Unknown"
        }
    }
}

// MARK: - Animations

private struct AnimationSettings: View {
    @EnvironmentObject private var settings: AppSettings
    @State private var vorsaintRunning = VorsaintDetector.isRunning

    var body: some View {
        Form {
            Section {
                Toggle("Enable AirPods Animation", isOn: $settings.airPodsEnabled)
                Toggle("Enable Charging Animation", isOn: $settings.chargingEnabled)
                Toggle("Show Unplug Animation", isOn: $settings.showUnplugAnimation)
                    .disabled(!settings.chargingEnabled)
            }

            Section {
                sliderRow("Popup Duration", value: $settings.popupDuration,
                          range: AppSettings.durationRange, step: 0.5)
                sliderRow("Vorsaint Delay", value: $settings.vorsaintDelay,
                          range: AppSettings.vorsaintDelayRange, step: 0.1)
                Text(vorsaintRunning
                     ? "Vorsaint is running. Popups wait this long so its HUD can go first."
                     : "Vorsaint is not running. Popups show immediately.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
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
        .onAppear { vorsaintRunning = VorsaintDetector.isRunning }
    }

    private func sliderRow(_ title: String, value: Binding<Double>,
                           range: ClosedRange<Double>, step: Double) -> some View {
        LabeledContent(title) {
            HStack {
                Slider(value: value, in: range, step: step)
                    .frame(width: 170)
                Text(String(format: "%.1f s", value.wrappedValue))
                    .monospacedDigit()
                    .frame(width: 44, alignment: .trailing)
            }
        }
    }
}

// MARK: - Updates

private struct UpdateSettings: View {
    @EnvironmentObject private var settings: AppSettings
    @ObservedObject private var updater = Updater.shared

    var body: some View {
        Form {
            Section {
                Toggle("Automatically Check for Updates", isOn: $settings.autoCheckUpdates)
                    .onChange(of: settings.autoCheckUpdates) { _, _ in
                        updater.startAutomaticChecks()
                    }
                LabeledContent("Current Version", value: "\(updater.currentVersion) (\(updater.currentBuild))")
                LabeledContent("Status", value: statusText)
            }

            Section {
                HStack {
                    Button("Check Now") {
                        Task { await updater.check(userInitiated: true) }
                    }
                    .disabled(updater.isBusy)

                    if let release = updater.available {
                        Button("Install \(release.version)") {
                            Task { await updater.install(release) }
                        }
                        .disabled(updater.isBusy)
                    }

                    Spacer()

                    if updater.isBusy {
                        ProgressView().controlSize(.small)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    private var statusText: String {
        switch updater.state {
        case .checking: return "Checking…"
        case .downloading: return "Downloading…"
        case .installing: return "Installing…"
        case .failed(let message): return message
        case .upToDate: return "Up to date"
        case .idle:
            if let release = updater.available { return "\(release.version) available" }
            if let date = updater.lastChecked {
                return "Checked \(date.formatted(date: .omitted, time: .shortened))"
            }
            return "Not checked yet"
        }
    }
}

// MARK: - About

private struct AboutView: View {
    @ObservedObject private var updater = Updater.shared

    var body: some View {
        VStack(spacing: 10) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 96, height: 96)
            Text("Notch+")
                .font(.system(size: 22, weight: .semibold))
            Text("Version \(updater.currentVersion) (\(updater.currentBuild))")
                .foregroundStyle(.secondary)
            Text("AirPods and charging animations at the notch.")
                .font(.callout)
                .foregroundStyle(.secondary)
            Link("View on GitHub", destination: Updater.releasesPage)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}
