import Foundation
import CoreGraphics

/// Integrates a single strange attractor and maintains a rolling trail of
/// recently-visited points, projected to 2D for drawing. Modeled on
/// `MandazaEngine`: a `regenerate(...)` to (re)seed and an `advance(timeMs:)`
/// driven by a SwiftUI `TimelineView`. No SwiftUI/UIKit dependency — testable
/// and safe to use off the main thread.
public final class AttractiveEngine {

    // Inputs
    public var config: AttractorConfig

    // Canvas sizing
    public private(set) var width: Double = 0
    public private(set) var height: Double = 0

    /// Maximum number of trail points retained.
    public var maxPoints: Int = 9000

    /// Integration substeps taken per advance tick — more = smoother curve.
    public var substepsPerTick: Int = 6

    /// Base integration timestep (model time per substep). Scaled by speed.
    public var baseDt: Double = 0.005

    /// Animation speed coefficient (1 = recommended).
    public var speed: Double = 1.0

    /// Numerical integration scheme. RK4 holds the trajectory on the attractor
    /// at step sizes where Euler visibly drifts — the difference is the lesson.
    public var integrator: IntegratorKind = .rk4

    /// Extra view zoom multiplier on top of the attractor's recommended zoom.
    public var zoom: Double = 1.0

    // 3D trajectory state (model space)
    private var x: Double = 0
    private var y: Double = 0
    private var z: Double = 0

    // Trail of projected 2D points (most-recent last).
    public private(set) var points: [CGPoint] = []

    private var prevTimeMs: Double = 0
    private var started = false
    private var rotation: Double = 0.0

    public init(config: AttractorConfig = AttractorRegistry.defaultConfig(for: .lorenz)) {
        self.config = config
    }

    /// (Re)seed the trajectory for the given canvas size. Optionally adopt a
    /// new config. Clears the trail and resets the clock.
    public func regenerate(width: Double, height: Double, config: AttractorConfig? = nil) {
        self.width = width
        self.height = height
        if let config { self.config = config }

        let p = self.config.initPos
        x = p.count > 0 ? p[0] : 0.1
        y = p.count > 1 ? p[1] : 0.0
        z = p.count > 2 ? p[2] : 0.0

        points.removeAll(keepingCapacity: true)
        prevTimeMs = 0
        started = false
        rotation = 0.0
    }

    /// Advance the integration to the supplied elapsed time (ms). Returns true
    /// while the trajectory is actively growing — always true here (an
    /// attractor never "finishes"), but the signature mirrors MandazaEngine so
    /// callers can treat it uniformly.
    @discardableResult
    public func advance(timeMs: Double) -> Bool {
        if !started { started = true; prevTimeMs = timeMs }
        let frameDt = max(0, min(timeMs - prevTimeMs, 64)) // clamp long gaps
        prevTimeMs = timeMs

        // Number of integration steps proportional to elapsed wall time.
        let effSpeed = max(0.05, speed) * max(0.1, config.recommendedSpeed)
        let stepsF = (frameDt / 16.667) * Double(substepsPerTick) * (effSpeed / 3.0)
        let steps = max(1, min(Int(stepsF.rounded()), 240))

        let dt = baseDt
        for _ in 0..<steps {
            (x, y, z) = config.step(x, y, z, dt: dt, integrator: integrator)
            appendProjected()
        }
        rotation += frameDt * 0.00012
        return true
    }

    /// Project the current 3D point to canvas space and append to the trail.
    private func appendProjected() {
        guard width > 1, height > 1 else { return }
        let s = config.scale * config.recommendedZoom * zoom
        // Simple rotation about the vertical axis for a sense of depth, then
        // orthographic projection (x,z used for screen; y modulates a little).
        let cosR = cos(rotation), sinR = sin(rotation)
        let rx = x * cosR - z * sinR
        let rz = x * sinR + z * cosR
        let span = min(width, height)
        let unit = span / 60.0 // model units → points, before scale
        let px = width / 2 + rx * unit * (s / 60.0)
        let py = height / 2 - (y * 0.6 + rz * 0.4) * unit * (s / 60.0)

        points.append(CGPoint(x: px, y: py))
        if points.count > maxPoints {
            points.removeFirst(points.count - maxPoints)
        }
    }

    /// The full trail as a single CGPath polyline.
    public func trailPath() -> CGPath {
        let path = CGMutablePath()
        guard let first = points.first else { return path }
        path.move(to: first)
        for pt in points.dropFirst() {
            path.addLine(to: pt)
        }
        return path
    }
}
