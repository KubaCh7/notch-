import SwiftUI

enum HeadphonesLayout {
    static func cardSize(notch: CGSize) -> CGSize {
        CGSize(width: max(340, notch.width + 24 + 120), height: notch.height + 172)
    }
}

/// Card that drops out of the notch when headphones connect.
struct HeadphonesCardView: View {
    @ObservedObject var info: HeadphoneInfo
    let phase: IslandPhase
    let notch: CGSize

    var body: some View {
        ZStack(alignment: .top) {
            if phase == .expanded {
                card
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.9, anchor: .top))
                            .animation(Motion.contentIn),
                        removal: .opacity.animation(.easeOut(duration: 0.15))
                    ))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var card: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: notch.height)

            HStack(spacing: 8) {
                Image(systemName: info.kind.titleSymbol)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.8))
                Text(info.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 8)
                Button {
                    NotchController.shared.dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white.opacity(0.75))
                        .frame(width: 20, height: 20)
                        .background(Circle().fill(Color.white.opacity(0.12)))
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .help("Close")
            }
            .padding(.top, 10)
            .padding(.horizontal, 22)

            HStack(alignment: .top, spacing: 0) {
                ForEach(components) { component in
                    ComponentColumn(component: component)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.top, 14)
            .padding(.horizontal, 16)

            Spacer(minLength: 0)
        }
    }

    private var components: [HeadphoneComponent] {
        let kind = info.kind
        let battery = info.battery
        if kind.hasBuds {
            return [
                HeadphoneComponent(id: "left", symbol: kind.leftSymbol, label: "Left",
                                   level: battery.left, charging: battery.leftCharging),
                HeadphoneComponent(id: "right", symbol: kind.rightSymbol, label: "Right",
                                   level: battery.right, charging: battery.rightCharging),
                HeadphoneComponent(id: "case", symbol: kind.caseSymbol, label: "Case",
                                   level: battery.caseLevel, charging: battery.caseCharging),
            ]
        }
        let level = battery.single ?? battery.left ?? battery.right
        return [
            HeadphoneComponent(id: "single", symbol: kind.singleSymbol, label: "Battery",
                               level: level, charging: battery.singleCharging),
        ]
    }
}

struct HeadphoneComponent: Identifiable {
    let id: String
    let symbol: String
    let label: String
    let level: Int?
    let charging: Bool
}

private struct ComponentColumn: View {
    let component: HeadphoneComponent

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: component.symbol)
                .font(.system(size: 30, weight: .regular))
                .foregroundStyle(.white)
                .frame(height: 40)

            ZStack {
                BatteryRing(level: component.level.map { Double($0) / 100 },
                            color: .green,
                            lineWidth: 3.5)
                Text(component.level.map { "\($0)%" } ?? "–")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(component.level == nil ? 0.4 : 0.95))
                    .contentTransition(.numericText())
            }
            .frame(width: 40, height: 40)
            .overlay(alignment: .topTrailing) {
                if component.charging {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.green)
                        .padding(3)
                        .background(Circle().fill(Color.black))
                        .offset(x: 5, y: -5)
                }
            }

            Text(component.label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.55))
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.8), value: component.level)
    }
}
