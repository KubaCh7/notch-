import CoreAudio
import Foundation

/// Watches the system default output device (read-only). With AirPods
/// automatic switching the Bluetooth link is often already up, so no
/// IOBluetooth "connected" event fires; the audio route change still does.
/// Needs no Bluetooth permission.
final class AudioOutputMonitor {
    /// (device name, Bluetooth address or "") when output moves to a Bluetooth device.
    var onBluetoothOutput: ((String, String) -> Void)?

    private var currentDevice = AudioDeviceID(0)
    private var listener: AudioObjectPropertyListenerBlock?
    private var address = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDefaultOutputDevice,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )

    func start() {
        guard listener == nil else { return }
        currentDevice = Self.defaultOutputDevice()

        let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            self?.outputChanged()
        }
        let status = AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject),
                                                         &address, DispatchQueue.main, block)
        if status == noErr {
            listener = block
        } else {
            NSLog("Notch+: could not watch default output device (\(status))")
        }
    }

    func stop() {
        guard let listener else { return }
        AudioObjectRemovePropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject),
                                               &address, DispatchQueue.main, listener)
        self.listener = nil
    }

    private func outputChanged() {
        let device = Self.defaultOutputDevice()
        guard device != 0, device != currentDevice else { return }
        currentDevice = device

        let transport = Self.uint32(device, kAudioDevicePropertyTransportType) ?? 0
        guard transport == kAudioDeviceTransportTypeBluetooth
                || transport == kAudioDeviceTransportTypeBluetoothLE else { return }

        let name = Self.string(device, kAudioObjectPropertyName) ?? "Headphones"
        onBluetoothOutput?(name, Self.bluetoothAddress(device))
    }

    // MARK: CoreAudio helpers

    private static func defaultOutputDevice() -> AudioDeviceID {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var device = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        let status = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject),
                                                &address, 0, nil, &size, &device)
        return status == noErr ? device : 0
    }

    private static func uint32(_ device: AudioDeviceID, _ selector: AudioObjectPropertySelector) -> UInt32? {
        var address = AudioObjectPropertyAddress(mSelector: selector,
                                                 mScope: kAudioObjectPropertyScopeGlobal,
                                                 mElement: kAudioObjectPropertyElementMain)
        var value = UInt32(0)
        var size = UInt32(MemoryLayout<UInt32>.size)
        let status = AudioObjectGetPropertyData(device, &address, 0, nil, &size, &value)
        return status == noErr ? value : nil
    }

    private static func string(_ device: AudioDeviceID, _ selector: AudioObjectPropertySelector) -> String? {
        var address = AudioObjectPropertyAddress(mSelector: selector,
                                                 mScope: kAudioObjectPropertyScopeGlobal,
                                                 mElement: kAudioObjectPropertyElementMain)
        var value: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        let status = withUnsafeMutablePointer(to: &value) { pointer in
            AudioObjectGetPropertyData(device, &address, 0, nil, &size, pointer)
        }
        guard status == noErr, let value else { return nil }
        return value.takeRetainedValue() as String
    }

    /// Bluetooth audio device UIDs look like "AA-BB-CC-DD-EE-FF:output".
    private static func bluetoothAddress(_ device: AudioDeviceID) -> String {
        guard let uid = string(device, kAudioDevicePropertyDeviceUID) else { return "" }
        let candidate = String(uid.prefix(17)).lowercased()
        let parts = candidate.split(separator: "-")
        guard parts.count == 6, parts.allSatisfy({ $0.count == 2 && $0.allSatisfy(\.isHexDigit) }) else {
            return ""
        }
        return candidate
    }
}
