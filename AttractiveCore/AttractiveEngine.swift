import Foundation
import CoreGraphics
import simd

/// Integrates a single strange attractor and maintains a rolling trail of
/// recently-visited points — both as raw 3D model-space coordinates (for the
/// SceneKit phase space) and projected to 2D (for the Canvas). Modeled on
/// `MandazaEngine`: a `regenerate(...)` to (re)seed and an `advance(timeMs:)`
/// driven by a render clock. No SwiftUI/UIKit dependency — testable and safe to
/// use off the main thread.
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

    /// Trail of raw 3D model-space points (oldest→newest), for the SceneKit
    /// phase space. `Float` halves the per-frame GPU upload versus `Double`.
    public private(set) var points3D: RingBuffer<SIMD3<Float>>

    /// Monotonic count of integration substeps taken since the last
    /// `regenerate`/`reseed` — lets the renderer detect new points cheaply.
    public private(set) var headIndex: Int = 0

    /// Current head state in model space.
    public var state: SIMD3<Double> { SIMD3(x, y, z) }

    /// Running model-space bounding box of the 3D trail, for camera framing.
    public private(set) var boundsMin = SIMD3<Float>(repeating: .greatestFiniteMagnitude)
    public private(set) var boundsMax = SIMD3<Float>(repeating: -.greatestFiniteMagnitude)

    // MARK: Companion trajectory (sensitive dependence)

    /// When true, a second trajectory starting `epsilon` away is integrated in
    /// lockstep with the reference — the basis of the butterfly-effect demo.
    public var tracksCompanion: Bool = false
    /// Initial separation of the companion from the reference.
    public var epsilon: Double = 1e-5
    private var cx: Double = 0, cy: Double = 0, cz: Double = 0
    public private(set) var companionPoints3D: RingBuffer<SIMD3<Float>>
    public var companionState: SIMD3<Double> { SIMD3(cx, cy, cz) }
    /// Euclidean separation between reference and companion in model space.
    public var separation: Double { simd_distance(state, companionState) }

    // MARK: Lyapunov estimation

    /// When true, a separate renormalized companion drives a live estimate of
    /// the largest Lyapunov exponent (never rendered — its job is measurement,
    /// not display, and it must stay near the reference, unlike the visual
    /// companion which is allowed to diverge).
    public var computesLyapunov: Bool = false
    public private(set) var lyapunov = LyapunovEstimator()
    private var lyapState = SIMD3<Double>(repeating: 0)

    private var prevTimeMs: Double = 0
    private var started = false
    private var rotation: Double = 0.0

    public init(config: AttractorConfig = AttractorRegistry.defaultConfig(for: .lorenz)) {
        self.config = config
        self.points3D = RingBuffer<SIMD3<Float>>(capacity: maxPoints)
        self.companionPoints3D = RingBuffer<SIMD3<Float>>(capacity: maxPoints)
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
        resetCompanions()

        points.removeAll(keepingCapacity: true)
        points3D.removeAll()
        companionPoints3D.removeAll()
        boundsMin = SIMD3<Float>(repeating: .greatestFiniteMagnitude)
        boundsMax = SIMD3<Float>(repeating: -.greatestFiniteMagnitude)
        headIndex = 0
        prevTimeMs = 0
        started = false
        rotation = 0.0
    }

    /// Relaunch the trajectory from an arbitrary point in model space (e.g. a
    /// long-pressed location in the 3D view). Clears trails and the clock; the
    /// companions are re-seeded.
    public func reseed(at p: SIMD3<Double>) {
        x = p.x; y = p.y; z = p.z
        resetCompanions()

        points.removeAll(keepingCapacity: true)
        points3D.removeAll()
        companionPoints3D.removeAll()
        boundsMin = SIMD3<Float>(repeating: .greatestFiniteMagnitude)
        boundsMax = SIMD3<Float>(repeating: -.greatestFiniteMagnitude)
        headIndex = 0
        prevTimeMs = 0
        started = false
        rotation = 0.0
    }

    /// Re-seed both companions from the current reference and reset the Lyapunov
    /// accumulation (a time-average that must not carry across a restart).
    private func resetCompanions() {
        cx = x + epsilon; cy = y; cz = z
        lyapunov.reset()
        lyapState = lyapunov.seed(from: state)
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
            append3D()
            appendProjected()
            if tracksCompanion {
                (cx, cy, cz) = config.step(cx, cy, cz, dt: dt, integrator: integrator)
                companionPoints3D.append(SIMD3<Float>(Float(cx), Float(cy), Float(cz)))
            }
            if computesLyapunov {
                let stepped = config.step(lyapState.x, lyapState.y, lyapState.z, dt: dt, integrator: integrator)
                lyapState = lyapunov.step(reference: state,
                                          companion: SIMD3(stepped.0, stepped.1, stepped.2),
                                          dt: dt)
            }
            headIndex += 1
        }
        rotation += frameDt * 0.00012
        return true
    }

    /// Append the current 3D point and grow the bounding box.
    private func append3D() {
        let p = SIMD3<Float>(Float(x), Float(y), Float(z))
        points3D.append(p)
        boundsMin = simd_min(boundsMin, p)
        boundsMax = simd_max(boundsMax, p)
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
