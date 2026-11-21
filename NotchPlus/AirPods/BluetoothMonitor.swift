import Foundation
import IOBluetooth

/// Listens for Bluetooth headphone connections. Read-only: never connects,
/// disconnects or reroutes audio.
final class BluetoothMonitor: NSObject {
    /// (name, address) of a headphone device that just connected.
    var onConnect: ((String, String) -> Void)?
    /// Address of a device that disconnected.
    var onDisconnect: ((String) -> Void)?

    private var connectNotification: IOBluetoothUserNotification?
    private var disconnectNotifications: [String: IOBluetoothUserNotification] = [:]
    private var lastConnect: [String: Date] = [:]
    private var startDate = Date()

    /// IOBluetooth reports every already-connected device right after registering.
    private let startupGrace: TimeInterval = 2.0
    /// AirPods sometimes reconnect twice in a row when taken out of the case.
    private let reconnectDebounce: TimeInterval = 4.0

    func start() {
        guard connectNotification == nil else { return }
        startDate = Date()
        connectNotification = IOBluetoothDevice.register(
            forConnectNotifications: self,
            selector: #selector(deviceConnected(_:device:))
        )
    }

    func stop() {
        connectNotification?.unregister()
        connectNotification = nil
        disconnectNotifications.values.forEach { $0.unregister() }
        disconnectNotifications.removeAll()
    }

    static func isHeadphones(_ device: IOBluetoothDevice) -> Bool {
        let name = (device.name ?? "").lowercased()
        if name.contains("airpods") || name.contains("beats") { return true }
        // Major device class 0x04 = Audio/Video (kBluetoothDeviceClassMajorAudio).
        return device.deviceClassMajor == 0x04
    }

    static func connectedHeadphones() -> [IOBluetoothDevice] {
        let paired = (IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice]) ?? []
        return paired.filter { $0.isConnected() && isHeadphones($0) }
    }

    @objc private func deviceConnected(_ notification: IOBluetoothUserNotification,
                                       device: IOBluetoothDevice) {
        let address = device.addressString ?? ""

        if disconnectNotifications[address] == nil {
            disconnectNotifications[address] = device.register(
                forDisconnectNotification: self,
                selector: #selector(deviceDisconnected(_:device:))
            )
        }

        guard Date().timeIntervalSince(startDate) > startupGrace else { return }
        guard Self.isHeadphones(device) else { return }

        let now = Date()
        if let last = lastConnect[address], now.timeIntervalSince(last) < reconnectDebounce { return }
        lastConnect[address] = now

        onConnect?(device.name ?? "Headphones", address)
    }

    @objc private func deviceDisconnected(_ notification: IOBluetoothUserNotification,
                                          device: IOBluetoothDevice) {
        let address = device.addressString ?? ""
        notification.unregister()
        disconnectNotifications[address] = nil
        onDisconnect?(address)
    }
}
