import Foundation
import IOKit.ps

struct PowerSnapshot: Equatable {
    var onAC: Bool
    var isCharging: Bool
    var isCharged: Bool
    /// 0...100
    var percent: Int
    /// Minutes until full, nil while macOS is still estimating.
    var minutesToFull: Int?
    var hasBattery: Bool
}

/// Watches power source changes through IOKit. Only reads, never changes anything.
final class PowerMonitor {
    var onPlug: ((PowerSnapshot) -> Void)?
    var onUnplug: ((PowerSnapshot) -> Void)?

    private var source: CFRunLoopSource?
    private var last: PowerSnapshot?
    private var lastEventDate = Date.distantPast
    private let debounce: TimeInterval = 1.0

    func start() {
        guard source == nil else { return }
        last = Self.read()

        let context = Unmanaged.passUnretained(self).toOpaque()
        let callback: IOPowerSourceCallbackType = { context in
            guard let context else { return }
            let monitor = Unmanaged<PowerMonitor>.fromOpaque(context).takeUnretainedValue()
            monitor.powerSourcesChanged()
        }
        guard let runLoopSource = IOPSNotificationCreateRunLoopSource(callback, context)?.takeRetainedValue() else {
            NSLog("Notch+: could not create power source notification")
            return
        }
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .defaultMode)
        source = runLoopSource
    }

    func stop() {
        if let source {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .defaultMode)
        }
        source = nil
    }

    private func powerSourcesChanged() {
        guard let now = Self.read() else { return }
        let previous = last
        last = now

        // IOKit fires for every capacity tick; only AC transitions matter.
        guard let previous, previous.onAC != now.onAC, now.hasBattery else { return }

        // Debounce: flaky connectors and MagSafe re-seats send bursts.
        let date = Date()
        guard date.timeIntervalSince(lastEventDate) >= debounce else { return }
        lastEventDate = date

        if now.onAC {
            onPlug?(now)
        } else {
            onUnplug?(now)
        }
    }

    /// Current power state of the internal battery.
    static func read() -> PowerSnapshot? {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue() else { return nil }

        var providing = ""
        if let type = IOPSGetProvidingPowerSourceType(info)?.takeUnretainedValue() {
            providing = type as String
        }

        var snapshot = PowerSnapshot(onAC: providing == "AC Power",
                                     isCharging: false,
                                     isCharged: false,
                                     percent: 100,
                                     minutesToFull: nil,
                                     hasBattery: false)

        guard let list = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef] else {
            return snapshot
        }

        for powerSource in list {
            guard let description = IOPSGetPowerSourceDescription(info, powerSource)?
                    .takeUnretainedValue() as? [String: Any] else { continue }
            guard (description["Type"] as? String) == "InternalBattery" else { continue }

            snapshot.hasBattery = true
            let current = description["Current Capacity"] as? Int ?? 0
            let max = description["Max Capacity"] as? Int ?? 100
            snapshot.percent = max > 0 ? Int((Double(current) / Double(max) * 100).rounded()) : current
            snapshot.isCharging = description["Is Charging"] as? Bool ?? false
            snapshot.isCharged = description["Is Charged"] as? Bool ?? false
            if let state = description["Power Source State"] as? String {
                snapshot.onAC = (state == "AC Power")
            }
            if let minutes = description["Time to Full Charge"] as? Int, minutes > 0 {
                snapshot.minutesToFull = minutes
            }
            break
        }
        return snapshot
    }
}
