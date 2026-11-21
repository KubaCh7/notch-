import Foundation
import IOBluetooth

struct BatteryReading {
    var battery: HeadphoneBattery
    /// Apple product ID when the source knows it (used to pick icons).
    var productID: Int?
}

/// There is no public API for AirPods battery levels, so every source lives
/// behind this protocol and can be swapped or removed without touching the UI.
@MainActor
protocol BatteryProvider {
    func readBattery(address: String, name: String) async -> BatteryReading?
}

/// Tries each provider in order and returns the first useful reading.
@MainActor
final class CompositeBatteryProvider: BatteryProvider {
    private let providers: [BatteryProvider]

    init(providers: [BatteryProvider]) {
        self.providers = providers
    }

    func readBattery(address: String, name: String) async -> BatteryReading? {
        for provider in providers {
            if let reading = await provider.readBattery(address: address, name: name),
               !reading.battery.isEmpty {
                return reading
            }
        }
        return nil
    }
}

// MARK: - Private IOBluetooth properties

/// Reads the undocumented `batteryPercent*` properties of IOBluetoothDevice.
/// Only touched when the object actually responds to them, so a future macOS
/// that drops them just yields nil instead of crashing.
@MainActor
final class IOBluetoothBatteryProvider: BatteryProvider {
    func readBattery(address: String, name: String) async -> BatteryReading? {
        guard !address.isEmpty, let device = IOBluetoothDevice(addressString: address) else { return nil }

        func percent(_ key: String) -> Int? {
            guard device.responds(to: NSSelectorFromString(key)),
                  let number = device.value(forKey: key) as? NSNumber else { return nil }
            let value = number.intValue
            return (1...100).contains(value) ? value : nil
        }

        let battery = HeadphoneBattery(left: percent("batteryPercentLeft"),
                                       right: percent("batteryPercentRight"),
                                       caseLevel: percent("batteryPercentCase"),
                                       single: percent("batteryPercentSingle"))
        return battery.isEmpty ? nil : BatteryReading(battery: battery, productID: nil)
    }
}

// MARK: - system_profiler

/// Parses `system_profiler SPBluetoothDataType -json`. Slower but stable.
@MainActor
final class SystemProfilerBatteryProvider: BatteryProvider {
    func readBattery(address: String, name: String) async -> BatteryReading? {
        guard let data = await Self.runProfiler() else { return nil }
        return Self.parse(data, address: address, name: name)
    }

    nonisolated private static func runProfiler() async -> Data? {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/sbin/system_profiler")
                process.arguments = ["SPBluetoothDataType", "-json"]
                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = FileHandle.nullDevice
                do {
                    try process.run()
                } catch {
                    continuation.resume(returning: nil)
                    return
                }
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()
                continuation.resume(returning: process.terminationStatus == 0 ? data : nil)
            }
        }
    }

    nonisolated static func parse(_ data: Data, address: String, name: String) -> BatteryReading? {
        guard let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let sections = root["SPBluetoothDataType"] as? [[String: Any]] else { return nil }

        // Flatten connected devices into (name, properties).
        var devices: [(String, [String: Any])] = []
        for section in sections {
            guard let connected = section["device_connected"] as? [[String: Any]] else { continue }
            for entry in connected {
                for (deviceName, value) in entry {
                    if let properties = value as? [String: Any] {
                        devices.append((deviceName, properties))
                    }
                }
            }
        }

        let target = normalize(address)
        let match = devices.first { !target.isEmpty && normalize($0.1["device_address"] as? String ?? "") == target }
            ?? devices.first { $0.0 == name }
        guard let properties = match?.1 else { return nil }

        let battery = HeadphoneBattery(left: percent(properties["device_batteryLevelLeft"]),
                                       right: percent(properties["device_batteryLevelRight"]),
                                       caseLevel: percent(properties["device_batteryLevelCase"]),
                                       single: percent(properties["device_batteryLevelMain"]))
        var productID: Int?
        if let raw = properties["device_productID"] as? String {
            productID = Int(raw.lowercased().replacingOccurrences(of: "0x", with: ""), radix: 16)
        }
        return BatteryReading(battery: battery, productID: productID)
    }

    nonisolated private static func normalize(_ address: String) -> String {
        address.uppercased().replacingOccurrences(of: "-", with: ":")
    }

    nonisolated private static func percent(_ value: Any?) -> Int? {
        if let number = value as? NSNumber { return number.intValue }
        guard let string = value as? String else { return nil }
        let digits = string.filter(\.isNumber)
        guard let result = Int(digits), (0...100).contains(result) else { return nil }
        return result
    }
}
