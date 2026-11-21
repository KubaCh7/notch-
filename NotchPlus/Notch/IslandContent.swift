import SwiftUI

/// How a popup unfolds out of the notch.
enum IslandStyle: Equatable {
    /// notch -> pill -> card -> pill -> notch
    case pillThenCard
    /// notch -> pill -> notch
    case pillOnly
    /// notch -> card -> notch. Interactive cards accept clicks while expanded.
    case card(interactive: Bool)
}

/// What the island is currently showing. Each feature adds its own case.
enum IslandContent {
    case charging(PowerSnapshot)
    case unplugged(PowerSnapshot)
    case headphones(HeadphoneInfo)
}

extension IslandContent {
    var style: IslandStyle {
        switch self {
        case .charging: return .pillThenCard
        case .unplugged: return .pillOnly
        case .headphones: return .card(interactive: true)
        }
    }

    /// Used to coalesce repeated events of the same type in the queue.
    var kind: String {
        switch self {
        case .charging, .unplugged: return "power"
        case .headphones: return "headphones"
        }
    }

    func pillSize(notch: CGSize) -> CGSize {
        switch self {
        case .charging: return ChargingLayout.pillSize(notch: notch, plugged: true)
        case .unplugged: return ChargingLayout.pillSize(notch: notch, plugged: false)
        case .headphones: return HeadphonesLayout.cardSize(notch: notch)
        }
    }

    func cardSize(notch: CGSize) -> CGSize {
        switch self {
        case .charging, .unplugged: return ChargingLayout.cardSize(notch: notch)
        case .headphones: return HeadphonesLayout.cardSize(notch: notch)
        }
    }
}

/// The view drawn inside the island for a given content + phase.
struct IslandContentView: View {
    let content: IslandContent
    let phase: IslandPhase
    let notch: CGSize

    var body: some View {
        switch content {
        case .charging(let snapshot):
            ChargingIslandView(snapshot: snapshot, plugged: true, phase: phase, notch: notch)
        case .unplugged(let snapshot):
            ChargingIslandView(snapshot: snapshot, plugged: false, phase: phase, notch: notch)
        case .headphones(let info):
            HeadphonesCardView(info: info, phase: phase, notch: notch)
        }
    }
}
