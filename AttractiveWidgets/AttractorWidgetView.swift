import SwiftUI
import WidgetKit

/// Renders a static frame of a strange attractor for the widget. Reuses the
/// app's pure render path — an `AttractiveEngine` integrated forward to fill its
/// trail, then the projected `trailPath()` stroked the same way `AttractiveCanvas`
/// draws the live 2D view (dim full trail + bright leading head). A widget entry
/// is a single still, so we run the integration up front instead of animating.
struct AttractorWidgetView: View {
    let entry: AttractorEntry

    var body: some View {
        Canvas(opaque: true, colorMode: .extendedLinear) { ctx, size in
            draw(in: &ctx, size: size)
        }
    }

    private func draw(in ctx: inout GraphicsContext, size: CGSize) {
        ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.black))
        guard size.width > 1, size.height > 1 else { return }

        // Build a full trail off the shared engine (compiled into this target).
        let engine = AttractiveEngine(config: AttractorRegistry.defaultConfig(for: entry.attractor))
        engine.integrator = .rk4
        engine.maxPoints = 7000
        engine.regenerate(width: Double(size.width), height: Double(size.height))
        let target = min(engine.maxPoints - 200, 6000)
        var t = 0.0
        while engine.points.count < target {
            t += 16.0
            engine.advance(timeMs: t)
            if t > 120_000 { break }   // safety: never spin forever
        }
        guard engine.points.count > 2 else { return }

        let base = Color(hue: AttractorPalette.hue(for: entry.attractor),
                         saturation: 0.85, brightness: 1.0)
        let glowR = size.width * 0.02
        let lw = max(1.0, size.width * 0.006)

        // Dim full trail.
        var trail = ctx
        trail.addFilter(.shadow(color: base.opacity(0.7), radius: glowR))
        trail.stroke(Path(engine.trailPath()),
                     with: .color(base.opacity(0.6)),
                     style: StrokeStyle(lineWidth: lw, lineCap: .round, lineJoin: .round))

        // Bright leading head.
        let headCount = min(engine.points.count, 600)
        if headCount > 1 {
            let pts = engine.points.suffix(headCount)
            var head = Path()
            head.move(to: pts.first!)
            for p in pts.dropFirst() { head.addLine(to: p) }
            var hl = ctx
            hl.addFilter(.shadow(color: base.opacity(0.9), radius: size.width * 0.03))
            hl.stroke(head,
                      with: .color(.white.opacity(0.95)),
                      style: StrokeStyle(lineWidth: lw * 1.2, lineCap: .round, lineJoin: .round))
        }
    }
}

/// A distinct hue per attractor so a gallery of widgets reads as different
/// systems at a glance (the app defaults to a single user-chosen hue).
enum AttractorPalette {
    static func hue(for id: AttractorID) -> Double {
        switch id {
        case .lorenz:    return 0.55   // cyan
        case .rossler:   return 0.78   // violet
        case .aizawa:    return 0.42   // green
        case .thomas:    return 0.12   // amber
        case .halvorsen: return 0.92   // magenta
        case .chen:      return 0.62   // blue
        }
    }
}
