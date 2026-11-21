import SwiftUI

// MARK: - Layout

enum IslandLayout {
    /// Ear radius of the resting (notch-sized) shape.
    static let notchEar: CGFloat = 6

    static func size(content: IslandContent?, phase: IslandPhase, notch: CGSize) -> CGSize {
        switch phase {
        case .hidden, .notch:
            return CGSize(width: notch.width + notchEar * 2, height: notch.height)
        case .pill:
            return content?.pillSize(notch: notch) ?? size(content: nil, phase: .notch, notch: notch)
        case .expanded:
            return content?.cardSize(notch: notch) ?? size(content: nil, phase: .notch, notch: notch)
        }
    }

    static func shape(phase: IslandPhase) -> NotchShape {
        switch phase {
        case .hidden, .notch: return NotchShape(topRadius: notchEar, bottomRadius: 10)
        case .pill:           return NotchShape(topRadius: 8, bottomRadius: 18)
        case .expanded:       return NotchShape(topRadius: 12, bottomRadius: 30)
        }
    }
}

// MARK: - Root

/// Fills the panel; the island hangs from the top center.
struct IslandRootView: View {
    @ObservedObject var controller: NotchController

    var body: some View {
        VStack(spacing: 0) {
            if controller.phase != .hidden {
                IslandView(controller: controller)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .ignoresSafeArea()
        .environment(\.colorScheme, .dark)
    }
}

struct IslandView: View {
    @ObservedObject var controller: NotchController

    var body: some View {
        let notch = controller.notchSize
        let phase = controller.phase
        let size = IslandLayout.size(content: controller.content, phase: phase, notch: notch)
        let shape = IslandLayout.shape(phase: phase)

        ZStack(alignment: .top) {
            IslandBackground(shape: shape, phase: phase, notchHeight: notch.height)

            if let content = controller.content {
                IslandContentView(content: content, phase: phase, notch: notch)
                    .frame(width: size.width, height: size.height, alignment: .top)
                    .clipShape(shape)
            }
        }
        .frame(width: size.width, height: size.height, alignment: .top)
    }
}

// MARK: - Glass background

/// Liquid Glass body with a pure-black top band that blends into the physical notch.
struct IslandBackground: View {
    let shape: NotchShape
    let phase: IslandPhase
    let notchHeight: CGFloat

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Namespace private var glassNamespace

    var body: some View {
        ZStack {
            glass
            notchBlend
        }
        .shadow(color: .black.opacity(phase == .expanded ? 0.45 : (phase == .pill ? 0.25 : 0)),
                radius: phase == .expanded ? 22 : 10,
                y: phase == .expanded ? 10 : 4)
    }

    @ViewBuilder
    private var glass: some View {
        if reduceTransparency {
            ZStack {
                shape.fill(Color(white: 0.09))
                shape.stroke(Color.white.opacity(0.12), lineWidth: 0.5)
            }
        } else {
            #if compiler(>=6.2)
            if #available(macOS 26.0, *) {
                LiquidGlassSurface(shape: shape, phase: phase, namespace: glassNamespace)
            } else {
                LegacyGlassSurface(shape: shape)
            }
            #else
            LegacyGlassSurface(shape: shape)
            #endif
        }
    }

    /// Solid black where the island touches the notch, fading into the glass below.
    private var notchBlend: some View {
        GeometryReader { geo in
            let height = max(geo.size.height, 1)
            let solid = min(notchHeight / height, 1)
            let fade = min((notchHeight + 22) / height, 1)
            shape.fill(
                LinearGradient(stops: [
                    .init(color: .black, location: 0),
                    .init(color: .black, location: solid),
                    .init(color: .black.opacity(0), location: max(fade, solid)),
                ], startPoint: .top, endPoint: .bottom)
            )
        }
    }
}

#if compiler(>=6.2)
/// macOS 26+: real Liquid Glass. The pill and the card are two glass shapes
/// sharing one `glassEffectID`, so the system morphs one into the other.
@available(macOS 26.0, *)
private struct LiquidGlassSurface: View {
    let shape: NotchShape
    let phase: IslandPhase
    let namespace: Namespace.ID

    var body: some View {
        GlassEffectContainer(spacing: 24) {
            if phase == .expanded {
                Color.clear
                    .glassEffect(.regular.tint(.black.opacity(0.32)), in: shape)
                    .glassEffectID("island", in: namespace)
                    .glassEffectTransition(.matchedGeometry)
            } else {
                Color.clear
                    .glassEffect(.regular.tint(.black.opacity(0.32)), in: shape)
                    .glassEffectID("island", in: namespace)
                    .glassEffectTransition(.matchedGeometry)
            }
        }
    }
}
#endif

/// macOS 14-15 fallback: behind-window blur (the AppKit equivalent of
/// .ultraThinMaterial in a transparent panel) + white hairline + top highlight.
private struct LegacyGlassSurface: View {
    let shape: NotchShape

    var body: some View {
        ZStack {
            VisualEffectBackdrop()
                .clipShape(shape)
            shape.fill(Color.black.opacity(0.30))
            shape.fill(
                LinearGradient(colors: [Color.white.opacity(0.10), Color.white.opacity(0)],
                               startPoint: .top, endPoint: .center)
            )
            shape.stroke(Color.white.opacity(0.15), lineWidth: 0.5)
        }
    }
}

/// SwiftUI's Material blends within the window, which shows nothing in a
/// clear panel. NSVisualEffectView with .behindWindow actually blurs the desktop.
struct VisualEffectBackdrop: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        view.appearance = NSAppearance(named: .vibrantDark)
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

// MARK: - Shared pieces

/// Circular battery ring that animates from 0 to `level` when it appears
/// (and to any new value later).
struct BatteryRing: View {
    /// 0...1, nil = unknown.
    let level: Double?
    var color: Color = .green
    var lineWidth: CGFloat = 4

    @State private var shown: Double = 0

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.14), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: shown)
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .onAppear { animate(to: level) }
        .onChange(of: level) { _, newValue in animate(to: newValue) }
    }

    private func animate(to value: Double?) {
        withAnimation(Motion.ring) { shown = min(max(value ?? 0, 0), 1) }
    }
}

/// Number that counts up together with the ring.
struct CountingPercent: View, Animatable {
    var value: Double
    var font: Font

    var animatableData: Double {
        get { value }
        set { value = newValue }
    }

    var body: some View {
        Text("\(Int(value.rounded()))%")
            .font(font)
            .monospacedDigit()
    }
}
