import Foundation

// MARK: - Integrator

/// Numerical scheme used to advance the ODE system. Exposed to the learner so
/// they can *see* why method choice matters: explicit Euler accumulates error
/// and can blow up at large step sizes where RK4 stays on the attractor.
public enum IntegratorKind: String, CaseIterable, Codable, Sendable, Identifiable {
    case euler
    case rk4

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .euler: return "Euler"
        case .rk4:   return "Runge–Kutta 4"
        }
    }

    /// One-line description of the method's accuracy/cost tradeoff, shown in the
    /// integrator picker so the choice is a lesson, not a hidden setting.
    public var summary: String {
        switch self {
        case .euler:
            return "First-order. One slope evaluation per step. Cheap, but local error grows as the step size — drifts off the true trajectory and can diverge."
        case .rk4:
            return "Fourth-order. Four slope evaluations per step, weighted. Far smaller error for the same step size — the workhorse of trajectory integration."
        }
    }
}

// MARK: - Parameter descriptor

/// Describes one tunable constant of an attractor: its symbol, what it physically
/// means, its default, the safe slider range, and any known bifurcation points
/// where the qualitative behavior of the system changes. This is what turns a
/// raw `Double` into something a learner can reason about.
public struct ParameterInfo: Equatable, Codable, Hashable, Sendable, Identifiable {
    /// Which slot of `AttractorConfig` this descriptor governs.
    public enum Slot: String, Codable, Hashable, Sendable { case p1, p2, p3 }

    public var slot: Slot
    /// Greek/Latin symbol as shown in the equation, e.g. "σ".
    public var symbol: String
    /// Short human name, e.g. "Prandtl number".
    public var name: String
    /// One sentence on what the constant controls in the system.
    public var meaning: String
    public var defaultValue: Double
    public var range: ClosedRange<Double>
    /// Suggested slider step for smooth, meaningful dragging.
    public var step: Double
    /// Known threshold values where behavior qualitatively changes, each with a
    /// short label the UI can snap to and annotate ("Hopf bifurcation", etc.).
    public var bifurcations: [Bifurcation]

    public var id: String { slot.rawValue }

    public struct Bifurcation: Equatable, Codable, Hashable, Sendable, Identifiable {
        public var value: Double
        public var label: String
        public var detail: String
        public var id: Double { value }
        public init(value: Double, label: String, detail: String) {
            self.value = value
            self.label = label
            self.detail = detail
        }
    }

    public init(slot: Slot, symbol: String, name: String, meaning: String,
                defaultValue: Double, range: ClosedRange<Double>, step: Double,
                bifurcations: [Bifurcation] = []) {
        self.slot = slot
        self.symbol = symbol
        self.name = name
        self.meaning = meaning
        self.defaultValue = defaultValue
        self.range = range
        self.step = step
        self.bifurcations = bifurcations
    }
}

// MARK: - Attractor metadata

/// The full educational dossier for one attractor: the equations (LaTeX), the
/// parameters with their meanings and bifurcations, the historical/physical
/// origin, and notes on the system's dynamical character. Kept separate from
/// `AttractorConfig` so the math layer stays pure numerics and the teaching
/// layer can grow independently.
public struct AttractorMetadata: Equatable, Codable, Hashable, Sendable, Identifiable {
    public var id: AttractorID
    /// LaTeX for the coupled ODE system, one line per state variable. Rendered
    /// with the equation view; written so `\sigma`, `\rho` etc. match `symbol`s.
    public var systemLatex: [String]
    /// The tunable parameters, in display order.
    public var parameters: [ParameterInfo]
    /// Who/when/why — e.g. "Edward Lorenz, 1963, simplified atmospheric convection."
    public var origin: String
    /// 2–4 sentences on the dynamical character: dissipative? what's the route to
    /// chaos? what is the learner looking at?
    public var character: String
    /// Approximate largest Lyapunov exponent at default parameters (positive ⇒
    /// chaotic). Nil where not well-established for this parameterization.
    public var lyapunovEstimate: Double?
    /// Approximate fractal (correlation/Kaplan–Yorke) dimension at defaults.
    public var fractalDimensionEstimate: Double?

    public init(id: AttractorID, systemLatex: [String], parameters: [ParameterInfo],
                origin: String, character: String,
                lyapunovEstimate: Double? = nil, fractalDimensionEstimate: Double? = nil) {
        self.id = id
        self.systemLatex = systemLatex
        self.parameters = parameters
        self.origin = origin
        self.character = character
        self.lyapunovEstimate = lyapunovEstimate
        self.fractalDimensionEstimate = fractalDimensionEstimate
    }
}

// MARK: - Metadata registry

public enum AttractorMetadataRegistry {

    public static func metadata(for id: AttractorID) -> AttractorMetadata {
        switch id {
        case .lorenz:
            return AttractorMetadata(
                id: .lorenz,
                systemLatex: [
                    "\\dot{x} = \\sigma\\,(y - x)",
                    "\\dot{y} = x\\,(\\rho - z) - y",
                    "\\dot{z} = x\\,y - \\beta\\,z",
                ],
                parameters: [
                    ParameterInfo(slot: .p1, symbol: "σ", name: "Prandtl number",
                        meaning: "Ratio of fluid viscosity to thermal diffusivity; sets how fast the convection rolls respond.",
                        defaultValue: 10, range: 0...20, step: 0.1),
                    ParameterInfo(slot: .p2, symbol: "ρ", name: "Rayleigh number",
                        meaning: "Temperature difference driving the convection; the primary knob for the route into chaos.",
                        defaultValue: 28, range: 0...50, step: 0.1,
                        bifurcations: [
                            .init(value: 1, label: "Origin loses stability",
                                  detail: "For ρ < 1 the only fixed point is the origin and it is stable — no convection."),
                            .init(value: 24.74, label: "Onset of chaos",
                                  detail: "Above ρ ≈ 24.74 the two convection fixed points lose stability via a subcritical Hopf bifurcation; the strange attractor appears."),
                        ]),
                    ParameterInfo(slot: .p3, symbol: "β", name: "Geometric factor",
                        meaning: "Aspect ratio of the convection cell. Lorenz used 8/3 ≈ 2.667.",
                        defaultValue: 2.667, range: 0...5, step: 0.01),
                ],
                origin: "Edward Lorenz, 1963 — a three-variable truncation of Rayleigh–Bénard atmospheric convection. The first system in which Lorenz observed sensitive dependence on initial conditions, coining the 'butterfly effect.'",
                character: "Dissipative: phase-space volume contracts everywhere, yet trajectories never settle — they wind forever around two unstable spirals, the wings. The route to chaos is a subcritical Hopf bifurcation. This is the canonical strange attractor.",
                lyapunovEstimate: 0.906,
                fractalDimensionEstimate: 2.06)

        case .rossler:
            return AttractorMetadata(
                id: .rossler,
                systemLatex: [
                    "\\dot{x} = -y - z",
                    "\\dot{y} = x + a\\,y",
                    "\\dot{z} = b + z\\,(x - c)",
                ],
                parameters: [
                    ParameterInfo(slot: .p1, symbol: "a", name: "Spiral gain",
                        meaning: "Controls the slow outward spiral in the x–y plane.",
                        defaultValue: 0.2, range: 0...0.4, step: 0.01),
                    ParameterInfo(slot: .p2, symbol: "b", name: "Reinjection offset",
                        meaning: "Sets the baseline of the fast z reinjection that folds the spiral back.",
                        defaultValue: 0.2, range: 0...2, step: 0.01),
                    ParameterInfo(slot: .p3, symbol: "c", name: "Fold threshold",
                        meaning: "Height at which z fires; drives a period-doubling cascade into chaos.",
                        defaultValue: 5.7, range: 1...18, step: 0.1,
                        bifurcations: [
                            .init(value: 4.2, label: "Period-2", detail: "The single loop first doubles around c ≈ 4.2."),
                            .init(value: 5.7, label: "Chaos", detail: "By c ≈ 5.7 the period-doubling cascade has produced a chaotic band — Rössler's classic value."),
                        ]),
                ],
                origin: "Otto Rössler, 1976 — designed deliberately as the simplest possible continuous chaotic system: a single quadratic nonlinearity producing one folded band.",
                character: "A textbook stretch-and-fold mechanism: trajectories spiral outward in a plane, then a fast z-pulse lifts and folds them back. Reaches chaos through a clean period-doubling cascade, making it the standard teaching example for the route to chaos.",
                lyapunovEstimate: 0.0714,
                fractalDimensionEstimate: 2.01)

        case .aizawa:
            return AttractorMetadata(
                id: .aizawa,
                systemLatex: [
                    "\\dot{x} = (z - b)\\,x - d\\,y",
                    "\\dot{y} = d\\,x + (z - b)\\,y",
                    "\\dot{z} = c + a\\,z - \\tfrac{z^3}{3} - (x^2 + y^2)(1 + e\\,z) + f\\,z\\,x^3",
                ],
                parameters: [
                    ParameterInfo(slot: .p1, symbol: "a", name: "z feedback",
                        meaning: "Linear growth term on z; sustains the vertical drift.",
                        defaultValue: 0.95, range: 0...1.5, step: 0.01),
                    ParameterInfo(slot: .p2, symbol: "b", name: "Radial bias",
                        meaning: "Shifts where the in-plane rotation switches from expanding to contracting.",
                        defaultValue: 0.7, range: 0...1.5, step: 0.01),
                    ParameterInfo(slot: .p3, symbol: "c", name: "Drive",
                        meaning: "Constant forcing on z that pushes the trajectory through the central spike.",
                        defaultValue: 0.6, range: 0...1.5, step: 0.01),
                ],
                origin: "Attributed to Aizawa; popularized through computer-graphics explorations of chaotic flows. Constants d=3.5, e=0.25, f=0.1 are held fixed.",
                character: "Produces a striking sphere-and-spike form: trajectories orbit a near-spherical shell while a cylindrical spike threads its poles. A good example that strange attractors need not look like the Lorenz wings.",
                lyapunovEstimate: 0.07,
                fractalDimensionEstimate: 2.1)

        case .thomas:
            return AttractorMetadata(
                id: .thomas,
                systemLatex: [
                    "\\dot{x} = \\sin(k\\,y) - b\\,x",
                    "\\dot{y} = \\sin(k\\,z) - b\\,y",
                    "\\dot{z} = \\sin(k\\,x) - b\\,z",
                ],
                parameters: [
                    ParameterInfo(slot: .p1, symbol: "b", name: "Dissipation",
                        meaning: "Damping on every axis. As b falls, the system moves from a stable point through limit cycles into chaos.",
                        defaultValue: 0.208186, range: 0...0.5, step: 0.001,
                        bifurcations: [
                            .init(value: 0.32899, label: "Onset of chaos",
                                  detail: "Below b ≈ 0.3290 the symmetric system becomes chaotic; above it relaxes to a limit cycle, then a fixed point."),
                            .init(value: 0, label: "Conservative limit",
                                  detail: "At b = 0 the system is volume-preserving — a deterministic random walk through the sinusoidal lattice."),
                        ]),
                    ParameterInfo(slot: .p2, symbol: "s", name: "Speed multiplier",
                        meaning: "Display-only time scaling; does not change the attractor's shape.",
                        defaultValue: 10, range: 1...20, step: 0.5),
                    ParameterInfo(slot: .p3, symbol: "k", name: "Frequency",
                        meaning: "Scales the argument of the sines — the spacing of the cubic lattice the trajectory weaves through.",
                        defaultValue: 1.0, range: 0.5...2, step: 0.01),
                ],
                origin: "René Thomas, 1999 — a cyclically symmetric system modeling feedback among three variables, each driven by a sinusoid of the next.",
                character: "Three-fold cyclic symmetry: the flow looks the same under x→y→z→x. With weak dissipation it 'walks' through a lattice of unstable points, an unusually clear picture of how a single damping parameter tunes a system from order into chaos.",
                lyapunovEstimate: 0.035,
                fractalDimensionEstimate: 2.0)

        case .halvorsen:
            return AttractorMetadata(
                id: .halvorsen,
                systemLatex: [
                    "\\dot{x} = -a\\,x - 4y - 4z - y^2",
                    "\\dot{y} = -a\\,y - 4z - 4x - z^2",
                    "\\dot{z} = -a\\,z - 4x - 4y - x^2",
                ],
                parameters: [
                    ParameterInfo(slot: .p1, symbol: "a", name: "Damping",
                        meaning: "Linear self-damping shared by all three (cyclically symmetric) axes.",
                        defaultValue: 1.4, range: 0.5...3, step: 0.01),
                    ParameterInfo(slot: .p2, symbol: "s", name: "Scale",
                        meaning: "Display time scaling; folds into the integration step, not the shape.",
                        defaultValue: 1, range: 0.2...3, step: 0.1),
                    ParameterInfo(slot: .p3, symbol: "v", name: "Speed",
                        meaning: "Display time scaling; folds into the integration step, not the shape.",
                        defaultValue: 1, range: 0.2...3, step: 0.1),
                ],
                origin: "Attributed to Arne Halvorsen — another cyclically symmetric system, here with quadratic coupling rather than sinusoidal.",
                character: "Cyclically symmetric like Thomas but with quadratic nonlinearity, giving a tightly wound three-lobed knot. Useful for contrasting how the form of the nonlinearity (sin vs square) reshapes an otherwise similar symmetry.",
                lyapunovEstimate: 0.69,
                fractalDimensionEstimate: 2.1)

        case .chen:
            return AttractorMetadata(
                id: .chen,
                systemLatex: [
                    "\\dot{x} = a\\,(y - x)",
                    "\\dot{y} = (c - a)\\,x - x\\,z + c\\,y",
                    "\\dot{z} = x\\,y - b\\,z",
                ],
                parameters: [
                    ParameterInfo(slot: .p1, symbol: "a", name: "Coupling",
                        meaning: "Plays σ's role from Lorenz — the x–y coupling rate.",
                        defaultValue: 35, range: 20...50, step: 0.5),
                    ParameterInfo(slot: .p2, symbol: "b", name: "Dissipation",
                        meaning: "Damping on z, analogous to Lorenz's β.",
                        defaultValue: 3, range: 1...8, step: 0.1),
                    ParameterInfo(slot: .p3, symbol: "c", name: "Drive",
                        meaning: "Forcing analogous to Lorenz's ρ; tunes the strength of the double-scroll.",
                        defaultValue: 28, range: 20...40, step: 0.1),
                ],
                origin: "Guanrong Chen & Tetsushi Ueta, 1999 — a 'dual' to the Lorenz system, topologically non-equivalent to it despite the similar form.",
                character: "Closely related to Lorenz but not topologically equivalent: a more tightly wound double-scroll. The ideal side-by-side companion to Lorenz for showing that similar equations can host genuinely different attractors.",
                lyapunovEstimate: 2.0,
                fractalDimensionEstimate: 2.13)
        }
    }

    public static let all: [AttractorMetadata] = AttractorID.allCases.map(metadata(for:))
}
