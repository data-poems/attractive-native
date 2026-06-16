import Foundation
import CoreGraphics

// MARK: - Attractor identity

/// The set of strange attractors the engine can integrate. Adding a new system
/// is a matter of appending a case here and a `step` branch + a `registry`
/// entry below — the engine and UI need no other changes. Ported from the
/// `attractors` config table in the datavis `main.js`.
public enum AttractorID: String, CaseIterable, Codable, Hashable, Sendable, Identifiable {
    case lorenz
    case rossler
    case aizawa
    case thomas
    case halvorsen
    case chen

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .lorenz:    return "Lorenz"
        case .rossler:   return "Rössler"
        case .aizawa:    return "Aizawa"
        case .thomas:    return "Thomas"
        case .halvorsen: return "Halvorsen"
        case .chen:      return "Chen"
        }
    }
}

// MARK: - Configuration value type

/// One fully-specified attractor "recipe": the system to integrate, its three
/// editable parameters, and the spatial constants used to seed and scale the
/// trajectory. Conforms to the universal-currency conformances so it can diff
/// (`onChange`), serialize, hash, and cross actor boundaries.
public struct AttractorConfig: Equatable, Codable, Hashable, Sendable {
    public var id: AttractorID
    /// Three tunable parameters (p1, p2, p3 in the original `compute` closures).
    public var p1: Double
    public var p2: Double
    public var p3: Double
    /// Multiplier applied to model-space coordinates before projection.
    public var scale: Double
    /// Initial position of the trajectory in model space.
    public var initPos: [Double]
    /// Speed/zoom hints carried over from the web version.
    public var recommendedSpeed: Double
    public var recommendedZoom: Double

    public init(id: AttractorID,
                p1: Double, p2: Double, p3: Double,
                scale: Double,
                initPos: [Double],
                recommendedSpeed: Double = 3.0,
                recommendedZoom: Double = 1.0) {
        self.id = id
        self.p1 = p1
        self.p2 = p2
        self.p3 = p3
        self.scale = scale
        self.initPos = initPos
        self.recommendedSpeed = recommendedSpeed
        self.recommendedZoom = recommendedZoom
    }

    // MARK: - ODE step

    /// One integration step using the requested numerical scheme. Euler is the
    /// faithful port of the original `compute` closures; RK4 is the fourth-order
    /// scheme whose smaller error the learner can observe directly against Euler.
    /// Returns the advanced (x, y, z).
    @inline(__always)
    public func step(_ x: Double, _ y: Double, _ z: Double, dt: Double,
                     integrator: IntegratorKind) -> (Double, Double, Double) {
        switch integrator {
        case .euler:
            let (dx, dy, dz) = derivative(x, y, z)
            return (x + dx * dt, y + dy * dt, z + dz * dt)
        case .rk4:
            let (k1x, k1y, k1z) = derivative(x, y, z)
            let (k2x, k2y, k2z) = derivative(x + k1x * dt/2, y + k1y * dt/2, z + k1z * dt/2)
            let (k3x, k3y, k3z) = derivative(x + k2x * dt/2, y + k2y * dt/2, z + k2z * dt/2)
            let (k4x, k4y, k4z) = derivative(x + k3x * dt,   y + k3y * dt,   z + k3z * dt)
            return (x + dt/6 * (k1x + 2*k2x + 2*k3x + k4x),
                    y + dt/6 * (k1y + 2*k2y + 2*k3y + k4y),
                    z + dt/6 * (k1z + 2*k2z + 2*k3z + k4z))
        }
    }

    /// Explicit-Euler step. Retained for call sites that don't expose the
    /// integrator choice; equivalent to `step(_:_:_:dt:integrator: .euler)`.
    @inline(__always)
    public func step(_ x: Double, _ y: Double, _ z: Double, dt: Double) -> (Double, Double, Double) {
        step(x, y, z, dt: dt, integrator: .euler)
    }

    /// The vector field ẋ = f(x, y, z): the instantaneous derivative of each
    /// state variable, with no time-stepping. Ported from each system's
    /// `compute` closure in `main.js`. Note that the Thomas/Halvorsen display
    /// speed multipliers are applied by the engine, not baked in here, so the
    /// field stays a pure derivative that RK4 can sample at intermediate points.
    @inline(__always)
    public func derivative(_ x: Double, _ y: Double, _ z: Double) -> (Double, Double, Double) {
        switch id {
        case .lorenz:
            return (p1 * (y - x),
                    x * (p2 - z) - y,
                    x * y - p3 * z)

        case .rossler:
            return (-y - z,
                    x + p1 * y,
                    p2 + z * (x - p3))

        case .aizawa:
            // Standard Aizawa: d, e, f fixed. p1=a, p2=b, p3=c.
            let a = p1, b = p2, c = p3
            let d = 3.5, e = 0.25, f = 0.1
            return ((z - b) * x - d * y,
                    d * x + (z - b) * y,
                    c + a * z - (z * z * z) / 3 - (x * x + y * y) * (1 + e * z) + f * z * x * x * x)

        case .thomas:
            // p1=b (dissipation), p2=display speed multiplier, p3=frequency.
            // The speed multiplier is a constant rescaling of the whole field,
            // folded in here so the derivative stays exact under Euler and RK4.
            let b = p1, speedMult = p2, k = p3
            return ((sin(y * k) - b * x) * speedMult,
                    (sin(z * k) - b * y) * speedMult,
                    (sin(x * k) - b * z) * speedMult)

        case .halvorsen:
            // p1=alpha; p2=scale and p3=speed are display-time multipliers folded
            // into the field as a single constant factor m.
            let m = p2 * p3
            return ((-p1 * x - 4 * y - 4 * z - y * y) * m,
                    (-p1 * y - 4 * z - 4 * x - z * z) * m,
                    (-p1 * z - 4 * x - 4 * y - x * x) * m)

        case .chen:
            // p1=alpha, p2=beta, p3=gamma.
            return (p1 * (y - x),
                    (p3 - p1) * x - x * z + p3 * y,
                    x * y - p2 * z)
        }
    }
}

// MARK: - Registry

public enum AttractorRegistry {

    /// The six starter attractors with their default parameters, ported from
    /// the `attractors` table in `main.js`.
    public static func defaultConfig(for id: AttractorID) -> AttractorConfig {
        switch id {
        case .lorenz:
            return AttractorConfig(id: .lorenz, p1: 10, p2: 28, p3: 2.667,
                                   scale: 8, initPos: [0.1, 0, 0],
                                   recommendedSpeed: 3.0, recommendedZoom: 1.0)
        case .rossler:
            return AttractorConfig(id: .rossler, p1: 0.2, p2: 0.2, p3: 5.7,
                                   scale: 15, initPos: [1, 1, 1],
                                   recommendedSpeed: 4.0, recommendedZoom: 0.8)
        case .aizawa:
            return AttractorConfig(id: .aizawa, p1: 0.95, p2: 0.7, p3: 0.6,
                                   scale: 200, initPos: [0.1, 0.1, 0.1],
                                   recommendedSpeed: 3.0, recommendedZoom: 1.0)
        case .thomas:
            return AttractorConfig(id: .thomas, p1: 0.208186, p2: 10, p3: 1.0,
                                   scale: 70, initPos: [1.1, 1.1, -0.01],
                                   recommendedSpeed: 3.0, recommendedZoom: 1.0)
        case .halvorsen:
            return AttractorConfig(id: .halvorsen, p1: 1.4, p2: 1, p3: 1,
                                   scale: 18, initPos: [-1.48, -1.51, 2.04],
                                   recommendedSpeed: 3.0, recommendedZoom: 1.0)
        case .chen:
            return AttractorConfig(id: .chen, p1: 35, p2: 3, p3: 28,
                                   scale: 6, initPos: [-0.1, 0.5, -0.6],
                                   recommendedSpeed: 2.5, recommendedZoom: 1.2)
        }
    }

    public static let all: [AttractorConfig] = AttractorID.allCases.map(defaultConfig(for:))
}
