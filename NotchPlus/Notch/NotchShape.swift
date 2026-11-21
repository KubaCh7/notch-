import SwiftUI

/// The island outline: a body with continuous rounded bottom corners, plus two
/// concave "ears" at the top that flare into the screen edge exactly like the
/// physical notch does. `width` includes both ears.
struct NotchShape: Shape {
    var topRadius: CGFloat
    var bottomRadius: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(topRadius, bottomRadius) }
        set {
            topRadius = newValue.first
            bottomRadius = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard rect.width > 0, rect.height > 0 else { return path }

        let ear = max(0, min(topRadius, rect.width / 4, rect.height / 2))
        let body = CGRect(x: rect.minX + ear, y: rect.minY,
                          width: rect.width - ear * 2, height: rect.height)
        let corner = max(0, min(bottomRadius, body.width / 2, body.height))

        path.addPath(
            UnevenRoundedRectangle(topLeadingRadius: 0,
                                   bottomLeadingRadius: corner,
                                   bottomTrailingRadius: corner,
                                   topTrailingRadius: 0,
                                   style: .continuous)
                .path(in: body)
        )

        guard ear > 0 else { return path }

        // Left ear
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: body.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: body.minX, y: rect.minY + ear))
        path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.minY),
                          control: CGPoint(x: body.minX, y: rect.minY))
        path.closeSubpath()

        // Right ear
        path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: body.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: body.maxX, y: rect.minY + ear))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY),
                          control: CGPoint(x: body.maxX, y: rect.minY))
        path.closeSubpath()

        return path
    }
}
