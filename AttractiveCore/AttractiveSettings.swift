import Foundation
import Observation

/// Single source of truth for user-editable visualizer state, written through
/// to `UserDefaults`. Modeled on `MandazaSettings`: plain `var` properties with
/// `didSet` write-through so the `@Observable` macro tracks every read site.
@MainActor
@Observable
public final class AttractiveSettings {

    public static let shared = AttractiveSettings()

    @ObservationIgnored
    private let defaults: UserDefaults

    // MARK: - Selection

    /// Raw value of the selected `AttractorID`.
    public var attractorRaw: String { didSet { write(attractorRaw, .attractorRaw) } }

    // MARK: - Motion / look

    /// Animation speed coefficient (0.2…3, 1 = recommended).
    public var speed: Double      { didSet { write(speed, .speed) } }
    /// Extra zoom on top of the attractor's recommended zoom.
    public var zoom: Double       { didSet { write(zoom, .zoom) } }
    /// Hue (0…1) for the trail stroke.
    public var hue: Double        { didSet { write(hue, .hue) } }
    /// Stroke line width.
    public var lineWidth: Double  { didSet { write(lineWidth, .lineWidth) } }
    /// Glow bloom on the trail stroke.
    public var glow: Bool         { didSet { write(glow, .glow) } }

    // MARK: - Numerics / tuning

    /// Numerical integration scheme. Surfaced to the learner so Euler↔RK4 is a
    /// visible choice, not a hidden default.
    public var integratorRaw: String { didSet { write(integratorRaw, .integratorRaw) } }

    /// Whether the trajectory is shown as the flat 2D Canvas or the 3D phase space.
    public var viewModeRaw: String { didSet { write(viewModeRaw, .viewModeRaw) } }

    /// When on, a second trajectory starting a hair away is drawn alongside the
    /// first to reveal sensitive dependence (the butterfly effect). 3D only.
    public var sensitiveDependence: Bool { didSet { write(sensitiveDependence, .sensitiveDependence) } }

    /// When on, the largest Lyapunov exponent is estimated live and shown on the HUD.
    public var showLyapunov: Bool { didSet { write(showLyapunov, .showLyapunov) } }

    /// Per-attractor parameter overrides (p1, p2, p3), keyed by `AttractorID`
    /// raw value. Absent keys fall back to registry defaults, so the slider UI
    /// only persists what the user has actually tuned. Serialized as JSON.
    @ObservationIgnored
    private var paramOverrides: [String: [Double]] {
        didSet { writeParamOverrides() }
    }
    /// Bump-on-write token so `@Observable` re-evaluates `currentConfig()` reads
    /// when a parameter changes (the dictionary itself is observation-ignored to
    /// keep the JSON write off the hot path).
    public private(set) var paramRevision: Int

    /// Completed lesson ids, persisted as a JSON string array.
    @ObservationIgnored
    private var completedLessons: Set<String> { didSet { writeCompletedLessons() } }
    public private(set) var lessonRevision: Int

    // MARK: - Init

    private init() {
        let suite = UserDefaults.standard
        self.defaults = suite

        self.attractorRaw = suite.string(forKey: Key.attractorRaw.rawValue) ?? AttractorID.lorenz.rawValue
        self.speed     = Self.readDouble(suite, .speed, default: 1.0)
        self.zoom      = Self.readDouble(suite, .zoom, default: 1.0)
        self.hue       = Self.readDouble(suite, .hue, default: 0.55)
        self.lineWidth = Self.readDouble(suite, .lineWidth, default: 1.2)
        self.glow      = Self.readBool(suite, .glow, default: true)
        self.integratorRaw = suite.string(forKey: Key.integratorRaw.rawValue) ?? IntegratorKind.rk4.rawValue
        self.viewModeRaw = suite.string(forKey: Key.viewModeRaw.rawValue) ?? ViewMode.scene3D.rawValue
        self.sensitiveDependence = Self.readBool(suite, .sensitiveDependence, default: false)
        self.showLyapunov = Self.readBool(suite, .showLyapunov, default: false)
        if let data = suite.data(forKey: Key.paramOverrides.rawValue),
           let decoded = try? JSONDecoder().decode([String: [Double]].self, from: data) {
            self.paramOverrides = decoded
        } else {
            self.paramOverrides = [:]
        }
        self.paramRevision = 0
        if let data = suite.data(forKey: Key.completedLessons.rawValue),
           let decoded = try? JSONDecoder().decode([String].self, from: data) {
            self.completedLessons = Set(decoded)
        } else {
            self.completedLessons = []
        }
        self.lessonRevision = 0

        // One-time migration: 3D is now the default view. Installs that saved a
        // 2D preference before this change are flipped to 3D exactly once so
        // everyone lands in the richer phase space. A later manual switch to 2D
        // still persists — we never re-flip. (Property `didSet` write-through
        // doesn't fire during `init`, so the values are written explicitly.)
        if !suite.bool(forKey: Key.didMigrateViewModeTo3D.rawValue) {
            self.viewModeRaw = ViewMode.scene3D.rawValue
            suite.set(ViewMode.scene3D.rawValue, forKey: Key.viewModeRaw.rawValue)
            suite.set(true, forKey: Key.didMigrateViewModeTo3D.rawValue)
        }
    }

    // MARK: - Derived

    public var attractor: AttractorID {
        get { AttractorID(rawValue: attractorRaw) ?? .lorenz }
        set { attractorRaw = newValue.rawValue }
    }

    public var integrator: IntegratorKind {
        get { IntegratorKind(rawValue: integratorRaw) ?? .rk4 }
        set { integratorRaw = newValue.rawValue }
    }

    public var viewMode: ViewMode {
        // Fallback matches the init/default (3D) so a corrupted raw value can't
        // silently drop the user into the 2D canvas.
        get { ViewMode(rawValue: viewModeRaw) ?? .scene3D }
        set { viewModeRaw = newValue.rawValue }
    }

    /// Build the `AttractorConfig` for the current selection, applying any user
    /// parameter overrides on top of the registry defaults.
    public func currentConfig() -> AttractorConfig {
        _ = paramRevision // read so `@Observable` tracks tuning as a dependency
        var config = AttractorRegistry.defaultConfig(for: attractor)
        if let o = paramOverrides[attractor.rawValue], o.count == 3 {
            config.p1 = o[0]; config.p2 = o[1]; config.p3 = o[2]
        }
        return config
    }

    /// Current value of one tunable parameter for the selected attractor,
    /// honoring overrides — the source of truth for slider positions.
    public func parameter(_ slot: ParameterInfo.Slot) -> Double {
        let c = currentConfig()
        switch slot {
        case .p1: return c.p1
        case .p2: return c.p2
        case .p3: return c.p3
        }
    }

    /// Set one tunable parameter for the selected attractor and persist it.
    /// Drives live re-integration via `currentConfig()` reads.
    public func setParameter(_ slot: ParameterInfo.Slot, _ value: Double) {
        let c = currentConfig()
        var trio = [c.p1, c.p2, c.p3]
        switch slot {
        case .p1: trio[0] = value
        case .p2: trio[1] = value
        case .p3: trio[2] = value
        }
        paramOverrides[attractor.rawValue] = trio
        paramRevision &+= 1
    }

    /// Discard tuning for the selected attractor, returning it to canonical
    /// parameters.
    public func resetParameters() {
        paramOverrides[attractor.rawValue] = nil
        paramRevision &+= 1
    }

    /// Whether the selected attractor currently differs from its defaults.
    public var hasParameterOverrides: Bool {
        _ = paramRevision
        return paramOverrides[attractor.rawValue] != nil
    }

    // MARK: - Lessons

    /// Drive the live view into a lesson step's preset. Sets the attractor first
    /// so parameter overrides land on the right system.
    public func apply(_ preset: LessonPreset) {
        if let a = preset.attractor { attractor = a }
        if let vm = preset.viewMode { viewMode = vm }
        if let ig = preset.integrator { integrator = ig }
        if let s = preset.sensitiveDependence { sensitiveDependence = s }
        if let l = preset.showLyapunov { showLyapunov = l }
        if let params = preset.parameters {
            for (slot, value) in params { setParameter(slot, value) }
        }
    }

    public func isLessonComplete(_ id: String) -> Bool {
        _ = lessonRevision
        return completedLessons.contains(id)
    }

    public func markLessonComplete(_ id: String) {
        guard !completedLessons.contains(id) else { return }
        completedLessons.insert(id)
        lessonRevision &+= 1
    }

    // MARK: - Storage primitives

    private enum Key: String {
        case attractorRaw, speed, zoom, hue, lineWidth, glow, integratorRaw, paramOverrides
        case viewModeRaw, sensitiveDependence, showLyapunov, completedLessons
        case didMigrateViewModeTo3D
    }

    private func writeParamOverrides() {
        if let data = try? JSONEncoder().encode(paramOverrides) {
            defaults.set(data, forKey: Key.paramOverrides.rawValue)
        }
    }

    private func writeCompletedLessons() {
        if let data = try? JSONEncoder().encode(Array(completedLessons)) {
            defaults.set(data, forKey: Key.completedLessons.rawValue)
        }
    }

    private func write<T>(_ value: T, _ key: Key) {
        defaults.set(value, forKey: key.rawValue)
    }

    private static func readDouble(_ d: UserDefaults, _ key: Key, default fallback: Double) -> Double {
        d.object(forKey: key.rawValue) != nil ? d.double(forKey: key.rawValue) : fallback
    }
    private static func readBool(_ d: UserDefaults, _ key: Key, default fallback: Bool) -> Bool {
        d.object(forKey: key.rawValue) != nil ? d.bool(forKey: key.rawValue) : fallback
    }
}
