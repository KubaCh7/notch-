import AppKit

/// Wires system monitors to the notch controller.
@MainActor
final class AppCoordinator {
    static let shared = AppCoordinator()

    private let notch = NotchController.shared
    private let settings = AppSettings.shared

    func start() {
    }

    func stop() {
    }

    // MARK: Tests (menu / settings)

    func testAirPods() {
    }

    func testCharging() {
    }

    func testUnplug() {
    }
}
