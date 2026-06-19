import AppIntents

/// User-pickable attractor for the configurable widget. Mirrors `AttractorID`
/// (compiled into this target) but as an `AppEnum` so it shows up in the widget
/// edit sheet. `id` maps back to the engine's identifier.
enum AttractorChoice: String, AppEnum {
    case lorenz, rossler, aizawa, thomas, halvorsen, chen

    static var typeDisplayRepresentation: TypeDisplayRepresentation { "Attractor" }

    static var caseDisplayRepresentations: [AttractorChoice: DisplayRepresentation] {
        [
            .lorenz:    "Lorenz",
            .rossler:   "Rössler",
            .aizawa:    "Aizawa",
            .thomas:    "Thomas",
            .halvorsen: "Halvorsen",
            .chen:      "Chen",
        ]
    }

    var attractorID: AttractorID { AttractorID(rawValue: rawValue) ?? .lorenz }
}

/// Configuration for the strange-attractor widget: which system to draw.
struct AttractorWidgetIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "Strange Attractor" }
    static var description: IntentDescription { "Choose which chaotic attractor to display." }

    @Parameter(title: "Attractor", default: .lorenz)
    var attractor: AttractorChoice
}
