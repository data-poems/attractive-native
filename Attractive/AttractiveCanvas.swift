import SwiftUI

/// SwiftUI Canvas + TimelineView host for the live, animated attractor.
/// Owns one engine instance and an animation clock; re-seeds the engine when
/// its size or selected attractor changes. Modeled on `MandazaCanvas`.
struct AttractiveCanvas: View {
    let size: CGSize
    let config: AttractorConfig
    let speed: Double
    let zoom: Double
    let hue: Double
    let lineWidth: Double
    let glow: Bool
    let integrator: IntegratorKind

    @State private var engine = AttractiveEngine()
    @State private var built = false
    @State private var firstTimestamp: Date? = nil
    @State private var lastAdvanceTimestamp: Date? = nil
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isLuminanceReduced) private var luminanceReduced

    var body: some View {
        TimelineView(.animation(paused: luminanceReduced || reduceMotion)) { timeline in
            let elapsedMs = msSince(start: firstTimestamp, now: timeline.date)
            Canvas(opaque: true,
                   colorMode: .extendedLinear,
                   rendersAsynchronously: false) { ctx, canvasSize in
                drawScene(in: &ctx, size: canvasSize, timeMs: elapsedMs)
            }
            .onChange(of: timeline.date) { _, now in
                advance(now: now)
            }
        }
        .background(Color.black)
        .ignoresSafeArea()
        .onAppear { rebuild() }
        .onChange(of: size)       { _, _ in rebuild() }
        .onChange(of: config)     { _, _ in rebuild() }
        .onChange(of: speed)      { _, new in engine.speed = new }
        .onChange(of: zoom)       { _, new in engine.zoom = new }
        .onChange(of: integrator) { _, new in engine.integrator = new }
    }

    private func rebuild() {
        engine.speed = speed
        engine.zoom = zoom
        engine.integrator = integrator
        engine.regenerate(width: Double(size.width),
                          height: Double(size.height),
                          config: config)
        built = size.width > 1 && size.height > 1
        firstTimestamp = nil
        lastAdvanceTimestamp = nil
    }

    private func advance(now: Date) {
        guard built else { return }
        if let last = lastAdvanceTimestamp,
           now.timeIntervalSince(last) < 0.0005 {
            return
        }
        lastAdvanceTimestamp = now
        if firstTimestamp == nil { firstTimestamp = now }
        let t = msSince(start: firstTimestamp, now: now)
        engine.advance(timeMs: t)
    }

    private func msSince(start: Date?, now: Date) -> Double {
        guard let start = start else { return 0 }
        return now.timeIntervalSince(start) * 1000
    }

    private func drawScene(in ctx: inout GraphicsContext, size: CGSize, timeMs: Double) {
        ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.black))
        guard built, engine.points.count > 1 else { return }

        let base = Color(hue: hue, saturation: 0.85, brightness: 1.0)
        let path = Path(engine.trailPath())

        var layer = ctx
        if glow {
            layer.addFilter(.shadow(color: base.opacity(0.7), radius: 8))
        }
        // Fade the older portion of the trail by drawing a dimmer full pass
        // beneath a brighter head segment.
        layer.stroke(path,
                     with: .color(base.opacity(0.55)),
                     style: StrokeStyle(lineWidth: lineWidth,
                                        lineCap: .round,
                                        lineJoin: .round))

        // Bright leading head.
        let headCount = min(engine.points.count, 600)
        if headCount > 1 {
            let headPts = engine.points.suffix(headCount)
            var head = Path()
            head.move(to: headPts.first!)
            for p in headPts.dropFirst() { head.addLine(to: p) }
            var headLayer = ctx
            if glow {
                headLayer.addFilter(.shadow(color: base.opacity(0.85), radius: 12))
            }
            headLayer.stroke(head,
                             with: .color(.white.opacity(0.95)),
                             style: StrokeStyle(lineWidth: lineWidth * 1.1,
                                                lineCap: .round,
                                                lineJoin: .round))
        }
    }
}
