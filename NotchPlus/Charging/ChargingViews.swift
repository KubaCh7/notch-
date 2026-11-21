import SwiftUI

enum ChargingLayout {
    static let pillWing: CGFloat = 46
    static let unplugWing: CGFloat = 56

    static func pillSize(notch: CGSize, plugged: Bool) -> CGSize {
        let ears: CGFloat = 16
        if plugged {
            return CGSize(width: notch.width + ears + pillWing * 2, height: notch.height + 6)
        }
        return CGSize(width: notch.width + ears + unplugWing * 2, height: notch.height + 30)
    }

    static func cardSize(notch: CGSize) -> CGSize {
        CGSize(width: max(notch.width + 24 + 130, 330), height: notch.height + 92)
    }
}

/// Charger plugged in / unplugged island content.
struct ChargingIslandView: View {
    let snapshot: PowerSnapshot
    let plugged: Bool
    let phase: IslandPhase
    let notch: CGSize

    private var tint: Color { plugged ? .green : Color(white: 0.62) }

    private var contentTransition: AnyTransition {
        .asymmetric(
            insertion: .opacity.combined(with: .scale(scale: 0.5)).animation(Motion.contentIn),
            removal: .opacity.animation(.easeOut(duration: 0.12))
        )
    }

    var body: some View {
        GeometryReader { geo in
            let wing = max((geo.size.width - notch.width) / 2, 0)

            ZStack(alignment: .top) {
                if phase == .pill {
                    wings(wing: wing)
                        .transition(contentTransition)

                    if !plugged {
                        Text("On Battery")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white.opacity(0.85))
                            .padding(.top, notch.height + 6)
                            .transition(contentTransition)
                    }
                }

                if phase == .expanded && plugged {
                    card
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.92, anchor: .top))
                                .animation(Motion.contentIn),
                            removal: .opacity.animation(.easeOut(duration: 0.15))
                        ))
                }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
        }
    }

    // MARK: Pill

    private func wings(wing: CGFloat) -> some View {
        HStack(spacing: 0) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(tint)
                .symbolEffect(.bounce, value: phase == .pill)
                .padding(.leading, 6)
                .frame(width: wing)

            Spacer(minLength: 0)

            Text("\(snapshot.percent)%")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(plugged ? Color.green : Color.white)
                .padding(.trailing, 6)
                .frame(width: wing)
        }
        .frame(height: notch.height)
    }

    // MARK: Card

    private var card: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: notch.height)

            HStack(spacing: 14) {
                ZStack {
                    BatteryRing(level: Double(snapshot.percent) / 100, color: .green, lineWidth: 5)
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.green)
                }
                .frame(width: 50, height: 50)

                VStack(alignment: .leading, spacing: 0) {
                    Text(title)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.65))
                    AnimatedPercent(target: snapshot.percent,
                                    font: .system(size: 28, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                }

                Spacer(minLength: 8)

                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.55))
                        .multilineTextAlignment(.trailing)
                }
            }
            .padding(.horizontal, 22)
            .frame(maxHeight: .infinity)
        }
    }

    private var title: String {
        if snapshot.isCharged || snapshot.percent >= 100 { return "Fully Charged" }
        if snapshot.isCharging { return "Charging" }
        return "Power Connected"
    }

    private var subtitle: String? {
        guard let minutes = snapshot.minutesToFull, snapshot.percent < 100 else { return nil }
        if minutes >= 60 {
            return "\(minutes / 60)h \(minutes % 60)m\nuntil full"
        }
        return "\(minutes) min\nuntil full"
    }
}

/// Percentage that counts up from 0 in sync with the ring.
struct AnimatedPercent: View {
    let target: Int
    let font: Font

    @State private var value: Double = 0

    var body: some View {
        CountingPercent(value: value, font: font)
            .onAppear {
                withAnimation(Motion.ring) { value = Double(target) }
            }
            .onChange(of: target) { _, newValue in
                withAnimation(Motion.ring) { value = Double(newValue) }
            }
    }
}
