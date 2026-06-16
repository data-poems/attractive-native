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
    }

    // MARK: - Derived

    public var attractor: AttractorID {
        get { AttractorID(rawValue: attractorRaw) ?? .lorenz }
        set { attractorRaw = newValue.rawValue }
    }

    /// Build a fresh `AttractorConfig` from defaults for the current selection.
    public func currentConfig() -> AttractorConfig {
        AttractorRegistry.defaultConfig(for: attractor)
    }

    // MARK: - Storage primitives

    private enum Key: String, CaseIterable {
        case attractorRaw, speed, zoom, hue, lineWidth, glow
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
