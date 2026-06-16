import SwiftUI

/// Surfaces the Euler ↔ RK4 choice as a segmented control with a live summary,
/// so the integrator is a lesson the learner makes, not a hidden default.
struct IntegratorPicker: View {
    @Bindable var settings: AttractiveSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Integrator", selection: $settings.integrator) {
                ForEach(IntegratorKind.allCases) { kind in
                    Text(kind.displayName).tag(kind)
                }
            }
            .pickerStyle(.segmented)

            Text(settings.integrator.summary)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.6))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
