import Foundation

/// A configuration a lesson step drives the live view into, so the learner sees
/// the concept being described. Every field is optional — a step changes only
/// what it needs to.
public struct LessonPreset: Sendable {
    public var attractor: AttractorID?
    public var parameters: [ParameterInfo.Slot: Double]?
    public var viewMode: ViewMode?
    public var integrator: IntegratorKind?
    public var sensitiveDependence: Bool?
    public var showLyapunov: Bool?

    public init(attractor: AttractorID? = nil,
                parameters: [ParameterInfo.Slot: Double]? = nil,
                viewMode: ViewMode? = nil,
                integrator: IntegratorKind? = nil,
                sensitiveDependence: Bool? = nil,
                showLyapunov: Bool? = nil) {
        self.attractor = attractor
        self.parameters = parameters
        self.viewMode = viewMode
        self.integrator = integrator
        self.sensitiveDependence = sensitiveDependence
        self.showLyapunov = showLyapunov
    }
}

/// One screen of a lesson: prose, optional equations to render, and the preset
/// that reconfigures the live attractor to match.
public struct LessonStep: Identifiable, Sendable {
    public let id: Int
    public let title: String
    public let body: String
    public let latex: [String]
    public let preset: LessonPreset

    public init(id: Int, title: String, body: String,
                latex: [String] = [], preset: LessonPreset = LessonPreset()) {
        self.id = id
        self.title = title
        self.body = body
        self.latex = latex
        self.preset = preset
    }
}

public struct Lesson: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let subtitle: String
    public let steps: [LessonStep]

    public init(id: String, title: String, subtitle: String, steps: [LessonStep]) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.steps = steps
    }
}

/// The curriculum: a path from "what is a dynamical system" through fixed
/// points, cycles, the route to chaos, sensitive dependence, and the numbers
/// that measure chaos — each concept anchored to a specific attractor.
public enum LessonRegistry {

    public static let all: [Lesson] = [
        dynamicalSystems,
        fixedPoints,
        limitCycles,
        routeToChaos,
        sensitiveDependence,
        measuringChaos,
    ]

    public static func lesson(id: String) -> Lesson? {
        all.first { $0.id == id }
    }

    // MARK: - Lessons

    static let dynamicalSystems = Lesson(
        id: "dynamical-systems",
        title: "What is a dynamical system?",
        subtitle: "State, rules, and trajectories",
        steps: [
            LessonStep(id: 0,
                title: "A point with a rule",
                body: "A dynamical system is just a point moving through space by a fixed rule. The point's position is its state — here three numbers, x, y, and z. The rule says how fast each is changing right now.",
                latex: ["\\dot{x} = f(x, y, z)"],
                preset: LessonPreset(attractor: .lorenz, viewMode: .scene3D, sensitiveDependence: false, showLyapunov: false)),
            LessonStep(id: 1,
                title: "Following the flow",
                body: "Apply the rule over and over and the point traces a path — a trajectory. The curve you see is the history of one point obeying one rule. Drag to rotate it; the structure is genuinely three-dimensional.",
                preset: LessonPreset(attractor: .lorenz, viewMode: .scene3D)),
            LessonStep(id: 2,
                title: "The attractor",
                body: "Start almost anywhere and the trajectory is drawn onto the same shape — the attractor. It is the long-run destiny of the system, and for these equations it is strange: bounded, but never repeating.",
                preset: LessonPreset(attractor: .lorenz, viewMode: .scene3D)),
        ])

    static let fixedPoints = Lesson(
        id: "fixed-points",
        title: "Fixed points & stability",
        subtitle: "Where motion stops — and whether it stays",
        steps: [
            LessonStep(id: 0,
                title: "A point at rest",
                body: "A fixed point is a state where the rule says nothing changes: every derivative is zero. The system can sit there forever. The question is whether it wants to.",
                latex: ["\\dot{x} = \\dot{y} = \\dot{z} = 0"],
                preset: LessonPreset(attractor: .lorenz, viewMode: .scene3D)),
            LessonStep(id: 1,
                title: "Calm convection",
                body: "Turn the Rayleigh number ρ down low. With little heat driving it, the Lorenz system has one stable fixed point at the origin — no convection. Nearby states fall into it and stay. That is stability.",
                preset: LessonPreset(attractor: .lorenz, parameters: [.p2: 0.8], viewMode: .scene3D)),
            LessonStep(id: 2,
                title: "Losing stability",
                body: "Raise ρ past 1 and the origin gives way to two new fixed points — steady convection rolls. Push ρ higher still and those lose stability too. Open the Tune panel and sweep ρ to feel the handoff.",
                preset: LessonPreset(attractor: .lorenz, parameters: [.p2: 14], viewMode: .scene3D)),
        ])

    static let limitCycles = Lesson(
        id: "limit-cycles",
        title: "Limit cycles",
        subtitle: "When the system settles into a loop",
        steps: [
            LessonStep(id: 0,
                title: "A repeating orbit",
                body: "Between rest and chaos lies the limit cycle: the trajectory settles onto a closed loop and repeats forever, like a clock. The Rössler system at a low fold threshold does exactly this.",
                preset: LessonPreset(attractor: .rossler, parameters: [.p3: 3.5], viewMode: .scene3D)),
            LessonStep(id: 1,
                title: "Stretch and reinject",
                body: "Rössler works by spiralling slowly outward in a plane, then a fast pulse lifts the point and folds it back to the centre. At this setting the fold is gentle and the loop is simple — one trip per cycle.",
                latex: ["\\dot{z} = b + z\\,(x - c)"],
                preset: LessonPreset(attractor: .rossler, parameters: [.p3: 3.5], viewMode: .scene3D)),
        ])

    static let routeToChaos = Lesson(
        id: "route-to-chaos",
        title: "The route to chaos",
        subtitle: "Period doubling in Rössler",
        steps: [
            LessonStep(id: 0,
                title: "One loop",
                body: "Start with a single clean loop. We will raise the fold threshold c step by step and watch the orbit complicate.",
                preset: LessonPreset(attractor: .rossler, parameters: [.p3: 4.0], viewMode: .scene3D)),
            LessonStep(id: 1,
                title: "The loop doubles",
                body: "Near c ≈ 4.2 the orbit splits: now it takes two trips to close. This is a period-doubling bifurcation. Keep raising c and it doubles again, and again, faster each time.",
                preset: LessonPreset(attractor: .rossler, parameters: [.p3: 4.3], viewMode: .scene3D)),
            LessonStep(id: 2,
                title: "Into the band",
                body: "By c ≈ 5.7 the doublings have piled up without limit and the orbit never closes — a chaotic band. A cascade of simple doublings has produced genuine chaos. Sweep c in the Tune panel to retrace the path.",
                preset: LessonPreset(attractor: .rossler, parameters: [.p3: 5.7], viewMode: .scene3D)),
        ])

    static let sensitiveDependence = Lesson(
        id: "sensitive-dependence",
        title: "Sensitive dependence",
        subtitle: "The butterfly effect, made visible",
        steps: [
            LessonStep(id: 0,
                title: "Two almost-identical starts",
                body: "Here are two trajectories whose starting points differ by one part in a hundred thousand — closer than any measurement could tell apart. Watch the separation readout.",
                preset: LessonPreset(attractor: .lorenz, viewMode: .scene3D, sensitiveDependence: true, showLyapunov: false)),
            LessonStep(id: 1,
                title: "They part ways",
                body: "For a while the two curves move as one. Then they split, and within seconds they are on opposite wings. The tiny initial difference has been amplified beyond all recognition. This is chaos: deterministic, yet unpredictable.",
                preset: LessonPreset(attractor: .lorenz, viewMode: .scene3D, sensitiveDependence: true)),
            LessonStep(id: 2,
                title: "Why forecasts fail",
                body: "Lorenz found this in a weather model in 1963. Because real measurements always carry small errors, and those errors double on a fixed clock, prediction has a horizon no computer can push past. A butterfly's wing is enough.",
                preset: LessonPreset(attractor: .lorenz, viewMode: .scene3D, sensitiveDependence: true)),
        ])

    static let measuringChaos = Lesson(
        id: "measuring-chaos",
        title: "Measuring chaos",
        subtitle: "Lyapunov exponent & fractal dimension",
        steps: [
            LessonStep(id: 0,
                title: "How fast do they diverge?",
                body: "The rate of separation has a number: the largest Lyapunov exponent, λ₁. Positive means nearby states pull apart exponentially — the signature of chaos. Watch the live estimate climb toward its known value.",
                latex: ["\\delta(t) \\approx \\delta_0\\, e^{\\lambda_1 t}"],
                preset: LessonPreset(attractor: .lorenz, viewMode: .scene3D, sensitiveDependence: false, showLyapunov: true)),
            LessonStep(id: 1,
                title: "A shape between dimensions",
                body: "The Lorenz attractor is not a surface and not a solid — its fractal dimension is about 2.06, wedged between two and three. It is an infinitely-layered sheet, which is why trajectories never cross yet never repeat.",
                preset: LessonPreset(attractor: .lorenz, viewMode: .scene3D, showLyapunov: true)),
            LessonStep(id: 2,
                title: "Compare two attractors",
                body: "Switch to Chen, a close cousin of Lorenz with a larger λ₁ — it diverges faster, a fiercer chaos. Open the Math panel on any attractor to see its exponent and dimension side by side.",
                preset: LessonPreset(attractor: .chen, viewMode: .scene3D, showLyapunov: true)),
        ])
}
