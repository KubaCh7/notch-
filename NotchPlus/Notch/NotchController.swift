import AppKit
import SwiftUI

enum IslandPhase: Equatable {
    case hidden
    case notch
    case pill
    case expanded
}

/// Owns the panel and drives the popup timeline. The panel is only ordered
/// in while a popup plays; otherwise it is fully off screen.
@MainActor
final class NotchController: ObservableObject {
    static let shared = NotchController()

    @Published private(set) var phase: IslandPhase = .hidden
    @Published private(set) var content: IslandContent?
    @Published private(set) var notchSize = CGSize(width: 185, height: 32)
    @Published private(set) var isHovering = false

    /// Big enough for the largest card plus its shadow.
    static let panelSize = CGSize(width: 520, height: 300)

    private struct Request {
        let content: IslandContent
        let delay: TimeInterval
    }

    private var panel: NotchPanel?
    private var queue: [Request] = []
    private var isRunning = false
    private var dismissRequested = false
    private var mouseMonitors: [Any] = []
    private var interactiveRect: NSRect = .zero

    // MARK: Public API

    func present(_ content: IslandContent, delay: TimeInterval = 0) {
        queue.removeAll { $0.content.kind == content.kind }
        queue.append(Request(content: content, delay: delay))

        if isRunning {
            // Something newer arrived: wrap up the current popup early.
            dismissRequested = true
            return
        }
        isRunning = true
        Task { await drain() }
    }

    /// Close the current popup (e.g. the card's close button).
    func dismiss() {
        dismissRequested = true
    }

    /// Drop the current popup if it shows something matching `predicate`.
    func dismiss(where predicate: (IslandContent) -> Bool) {
        if let content, predicate(content) { dismissRequested = true }
        queue.removeAll { predicate($0.content) }
    }

    // MARK: Timeline

    private func drain() async {
        while !queue.isEmpty {
            let request = queue.removeFirst()
            await play(request)
        }
        isRunning = false
    }

    private func play(_ request: Request) async {
        if request.delay > 0 { await sleep(request.delay) }

        dismissRequested = false
        showPanel()
        content = request.content
        phase = .notch
        // One frame at notch size so the spring starts from the notch, not from zero.
        await sleep(0.04)

        let hold = AppSettings.shared.popupDuration

        switch request.content.style {
        case .pillThenCard:
            withAnimation(Motion.grow) { phase = .pill }
            await wait(Motion.pillHold)
            if !dismissRequested {
                withAnimation(Motion.morph) { phase = .expanded }
                await wait(hold)
            }
            withAnimation(Motion.collapse) { phase = .pill }
            await sleep(Motion.collapseStep)

        case .pillOnly:
            withAnimation(Motion.grow) { phase = .pill }
            await wait(min(hold, 1.8))

        case .card(let interactive):
            withAnimation(Motion.morph) { phase = .expanded }
            if interactive {
                let size = request.content.cardSize(notch: notchSize)
                enableInteraction(cardSize: size)
            }
            await wait(hold + (interactive ? 1.0 : 0))
            disableInteraction()
        }

        withAnimation(Motion.collapse) { phase = .notch }
        await sleep(Motion.collapseFinish)

        phase = .hidden
        content = nil
        isHovering = false
        panel?.orderOut(nil)
    }

    private func sleep(_ seconds: TimeInterval) async {
        try? await Task.sleep(nanoseconds: UInt64(max(0, seconds) * 1_000_000_000))
    }

    /// Waits for `seconds`, paused while the pointer hovers the card,
    /// and cut short by `dismiss()`.
    private func wait(_ seconds: TimeInterval) async {
        var remaining = seconds
        let step = 0.05
        while remaining > 0 && !dismissRequested {
            await sleep(step)
            if !isHovering { remaining -= step }
        }
    }

    // MARK: Panel

    private func showPanel() {
        let metrics = NotchLocator.locate()
        notchSize = metrics.notchSize

        let size = Self.panelSize
        let frame = NSRect(x: (metrics.centerX - size.width / 2).rounded(),
                           y: metrics.screenFrame.maxY - size.height,
                           width: size.width,
                           height: size.height)

        if panel == nil {
            let newPanel = NotchPanel(contentRect: frame)
            let host = NotchHostingView(rootView: IslandRootView(controller: self))
            host.frame = NSRect(origin: .zero, size: size)
            host.autoresizingMask = [.width, .height]
            newPanel.contentView = host
            panel = newPanel
        }

        panel?.setFrame(frame, display: false)
        panel?.ignoresMouseEvents = true
        panel?.orderFrontRegardless()
    }

    // MARK: Click-through handling

    /// Only the card's own rectangle takes clicks; the rest of the panel stays
    /// click-through. Mouse-moved monitors need no special permissions.
    private func enableInteraction(cardSize: CGSize) {
        guard let panel else { return }
        let frame = panel.frame
        interactiveRect = NSRect(x: frame.midX - cardSize.width / 2,
                                 y: frame.maxY - cardSize.height,
                                 width: cardSize.width,
                                 height: cardSize.height)

        let mask: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged]
        if let global = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: { [weak self] _ in
            MainActor.assumeIsolated { self?.updatePointer() }
        }) {
            mouseMonitors.append(global)
        }
        if let local = NSEvent.addLocalMonitorForEvents(matching: mask, handler: { [weak self] event in
            MainActor.assumeIsolated { self?.updatePointer() }
            return event
        }) {
            mouseMonitors.append(local)
        }
        updatePointer()
    }

    private func disableInteraction() {
        mouseMonitors.forEach { NSEvent.removeMonitor($0) }
        mouseMonitors.removeAll()
        interactiveRect = .zero
        isHovering = false
        panel?.ignoresMouseEvents = true
    }

    private func updatePointer() {
        let inside = interactiveRect.contains(NSEvent.mouseLocation)
        panel?.ignoresMouseEvents = !inside
        if isHovering != inside { isHovering = inside }
    }
}
