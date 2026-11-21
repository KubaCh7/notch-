import SwiftUI

@main
struct NotchPlusApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @ObservedObject private var settings = AppSettings.shared

    var body: some Scene {
        MenuBarExtra("Notch+", systemImage: "rectangle.topthird.inset.filled") {
            MenuContent()
                .environmentObject(settings)
        }
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsView()
                .environmentObject(settings)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Accessory app: no Dock icon (LSUIElement = YES is also set in Info.plist).
        NSApp.setActivationPolicy(.accessory)
        MainActor.assumeIsolated {
            AppCoordinator.shared.start()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        MainActor.assumeIsolated {
            AppCoordinator.shared.stop()
        }
    }
}
