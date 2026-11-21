import AppKit
import SwiftUI

/// Central place for the island's timing so every popup moves the same way.
enum Motion {
    static var reduceMotion: Bool {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    static var reduceTransparency: Bool {
        NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency
    }

    /// Notch -> pill.
    static var grow: Animation {
        reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.45, dampingFraction: 0.8)
    }

    /// Pill -> card (and notch -> card).
    static var morph: Animation {
        reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.45, dampingFraction: 0.8)
    }

    /// Card -> pill -> notch. Slightly more damped so it tucks in without bouncing past the notch.
    static var collapse: Animation {
        reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.4, dampingFraction: 0.9)
    }

    /// Content that pops in after the shape has started growing.
    static var contentIn: Animation {
        reduceMotion ? .easeInOut(duration: 0.15) : .spring(response: 0.35, dampingFraction: 0.75).delay(0.08)
    }

    /// Ring fill 0 -> value.
    static var ring: Animation {
        reduceMotion ? .linear(duration: 0.01) : .timingCurve(0.2, 0.8, 0.2, 1, duration: 1.0).delay(0.12)
    }

    // Timeline (seconds)
    static var pillHold: TimeInterval { reduceMotion ? 0.25 : 0.6 }
    static var collapseStep: TimeInterval { reduceMotion ? 0.22 : 0.3 }
    static var collapseFinish: TimeInterval { reduceMotion ? 0.25 : 0.45 }
}
