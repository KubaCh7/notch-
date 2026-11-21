# Notch+

Dynamic Island-style animations at the MacBook notch, written in Swift + SwiftUI.

- **AirPods / Bluetooth headphones connected**: a Liquid Glass card drops out of the notch with the device name, bud/case icons and green battery rings.
- **Charger plugged in**: a glass pill with a green bolt grows out of the notch and morphs into a card with a battery ring that fills to the current %.
- **Charger unplugged**: a short pill with a gray bolt, "On Battery" and the %.

Menu bar only (no Dock icon). Everything else on screen is untouched: the panel only exists while an animation plays.

## Requirements

- Apple Silicon MacBook with a notch (works on other displays too, the island just drops from the top edge)
- macOS 14 Sonoma or later
- Xcode 16+ to build. Build with **Xcode 26** to get real Liquid Glass (`.glassEffect`) on macOS 26; older SDKs/OSes use a blur + hairline fallback.

## Build & run

1. Open `NotchPlus.xcodeproj`.
2. Select the `NotchPlus` scheme, `My Mac`.
3. Run. The app is ad-hoc signed ("Sign to Run Locally"). Pick your own team under Signing & Capabilities if you want to distribute it.
4. On first AirPods connect macOS asks for Bluetooth permission. Allow it.

For **Launch at Login** to stick, copy the built app to `/Applications` first.

## Menu bar

- Enable AirPods Animation
- Enable Charging Animation
- Test AirPods / Test Charging
- Launch at Login
- Settings… (toggles, popup duration, Vorsaint delay, Play Sound)
- Quit Notch+

## Living next to Vorsaint

Notch+ is built to coexist with the Vorsaint notch app:

- Separate process, separate bundle id (`com.notchplus.NotchPlus`), own UserDefaults. It never reads or writes Vorsaint's files, prefs or processes.
- No media/volume/brightness key taps, no Now Playing, no event taps.
- The popup is a borderless, non-activating `NSPanel` (`.statusBar` level, `canJoinAllSpaces`, `fullScreenAuxiliary`, `stationary`). It never becomes key or main, so it can't steal focus.
- Click-through (`ignoresMouseEvents = true`) at all times, except over the AirPods card while it is expanded (so the close button works).
- The panel is ordered out as soon as an animation finishes.
- Connecting AirPods switches the audio output, which makes Vorsaint show its volume HUD. If Vorsaint is running (detected read-only by bundle id/name containing "Vorsaint"), Notch+ delays its popups by 0.6 s (configurable in Settings).

## How it works

| Feature | API |
| --- | --- |
| Power changes | `IOPSNotificationCreateRunLoopSource` + `IOPSCopyPowerSourcesInfo` (AC state, charging, capacity, time to full). Duplicate events within 1 s are ignored. |
| Headphones | `IOBluetoothDevice.register(forConnectNotifications:selector:)` + per-device disconnect notifications. Only audio-class devices (or AirPods/Beats by name). |
| Headphone battery | No public API. Hidden behind a `BatteryProvider` protocol, see below. |
| Launch at Login | `SMAppService.mainApp` |

### Headphone battery

`BatteryProvider` is a protocol with two implementations, tried in order:

1. `IOBluetoothBatteryProvider`: reads the undocumented `batteryPercentLeft/Right/Case/Single` properties of `IOBluetoothDevice` via KVC, only if the object responds to them. Fast, but private, so it can break in any macOS update.
2. `SystemProfilerBatteryProvider`: parses `system_profiler SPBluetoothDataType -json` (`device_batteryLevelLeft/Right/Case/Main`). Slower (~0.5-1 s), but stable across releases.

AirPods report battery a second or two after connecting, so the card shows empty rings first and fills them when values arrive. Per-bud charging state is not exposed by either source, so the small bolt only shows when a provider reports it.

## Project layout

```
NotchPlus/
  App/        app entry, menu, coordinator, Vorsaint detection, sounds
  Notch/      panel, notch geometry, island shape, glass background, timeline
  Charging/   IOKit power monitor + charging views
  AirPods/    Bluetooth monitor, battery providers, headphone card
  Settings/   preferences + settings window
```

## Accessibility

- **Reduce Motion**: springs become short ease-in-out fades.
- **Reduce Transparency**: glass becomes a solid dark surface.
