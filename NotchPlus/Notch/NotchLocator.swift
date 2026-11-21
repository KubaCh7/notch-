import AppKit

struct NotchMetrics {
    /// Frame of the screen the island is drawn on (global coordinates).
    var screenFrame: NSRect
    /// Size of the physical notch (or a virtual one on screens without a notch).
    var notchSize: CGSize
    var hasNotch: Bool

    var centerX: CGFloat { screenFrame.midX }
}

enum NotchLocator {
    /// Fallback size for displays without a notch: the island drops from the top edge.
    static let virtualNotch = CGSize(width: 180, height: 24)

    static func locate() -> NotchMetrics {
        let screens = NSScreen.screens
        // Prefer the built-in display with a notch, wherever it is in the arrangement.
        if let screen = screens.first(where: { $0.safeAreaInsets.top > 0 }) {
            let height = screen.safeAreaInsets.top
            var width: CGFloat = 185
            if let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea {
                width = screen.frame.width - left.width - right.width
            }
            return NotchMetrics(screenFrame: screen.frame,
                                notchSize: CGSize(width: width, height: height),
                                hasNotch: true)
        }

        let screen = NSScreen.main ?? screens.first
        let frame = screen?.frame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let menuBar = screen.map { $0.frame.maxY - $0.visibleFrame.maxY } ?? virtualNotch.height
        return NotchMetrics(screenFrame: frame,
                            notchSize: CGSize(width: virtualNotch.width,
                                              height: max(menuBar, virtualNotch.height)),
                            hasNotch: false)
    }
}
