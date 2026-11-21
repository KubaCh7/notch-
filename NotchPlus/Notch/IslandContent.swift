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
}

extension IslandContent {
    var style: IslandStyle {
        switch self {
        }
    }

    /// Used to coalesce repeated events of the same type in the queue.
    var kind: String {
        switch self {
        }
    }

    func pillSize(notch: CGSize) -> CGSize {
        switch self {
        }
    }

    func cardSize(notch: CGSize) -> CGSize {
        switch self {
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
        }
    }
}
