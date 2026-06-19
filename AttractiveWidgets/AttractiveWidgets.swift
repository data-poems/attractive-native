import WidgetKit
import SwiftUI

/// Timeline entry: which attractor to draw. Attractors are static art, so one
/// entry per configuration is enough; we just refresh occasionally.
struct AttractorEntry: TimelineEntry {
    let date: Date
    let attractor: AttractorID
}

struct AttractorProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> AttractorEntry {
        AttractorEntry(date: Date(), attractor: .lorenz)
    }

    func snapshot(for configuration: AttractorWidgetIntent, in context: Context) async -> AttractorEntry {
        AttractorEntry(date: Date(), attractor: configuration.attractor.attractorID)
    }

    func timeline(for configuration: AttractorWidgetIntent, in context: Context) async -> Timeline<AttractorEntry> {
        let entry = AttractorEntry(date: Date(), attractor: configuration.attractor.attractorID)
        // Static image; refresh in a day so WidgetKit keeps it warm without churn.
        return Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(86_400)))
    }
}

struct AttractorWidget: Widget {
    let kind = "AttractorWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind,
                               intent: AttractorWidgetIntent.self,
                               provider: AttractorProvider()) { entry in
            AttractorWidgetView(entry: entry)
                .containerBackground(.black, for: .widget)
        }
        .configurationDisplayName("Strange Attractor")
        .description("A chaotic attractor, rendered on your Home Screen.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .systemExtraLarge])
        .contentMarginsDisabled()
    }
}

@main
struct AttractiveWidgetBundle: WidgetBundle {
    var body: some Widget {
        AttractorWidget()
    }
}
