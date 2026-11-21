import AppKit

/// Read-only check for the Vorsaint notch app. Notch+ never talks to Vorsaint,
/// never reads its files or prefs; it only looks at the list of running apps.
enum VorsaintDetector {
    static var isRunning: Bool {
        NSWorkspace.shared.runningApplications.contains { app in
            let bundleID = app.bundleIdentifier?.lowercased() ?? ""
            let name = app.localizedName?.lowercased() ?? ""
            return bundleID.contains("vorsaint") || name.contains("vorsaint")
        }
    }

    /// Delay to apply before showing a popup for a real (non-test) event.
    static var popupDelay: TimeInterval {
        isRunning ? AppSettings.shared.vorsaintDelay : 0
    }
}
