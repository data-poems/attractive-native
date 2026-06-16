import SwiftUI

/// The "Style & numerics" sheet: the ambient look controls (glow, color, speed,
/// line width) plus the integrator choice. Gives the previously tap-only look
/// controls proper continuous sliders and exposes line width, which had no UI.
struct SettingsSheet: View {
    @Bindable var settings: AttractiveSettings
    @Environment(\.dismiss) private var dismiss

    private var accent: Color {
        Color(hue: settings.hue, saturation: 0.85, brightness: 1.0)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    group("Numerics") {
                        IntegratorPicker(settings: settings)
                    }

                    group("Chaos lens (3D)") {
                        Toggle(isOn: $settings.sensitiveDependence) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Sensitive dependence").foregroundStyle(.white)
                                Text("Draw a second trajectory a hair away and watch them diverge")
                                    .font(.caption2).foregroundStyle(.white.opacity(0.55))
                            }
                        }
                        .tint(accent)

                        Toggle(isOn: $settings.showLyapunov) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Lyapunov exponent").foregroundStyle(.white)
                                Text("Estimate λ₁ live — the rate of chaos")
                                    .font(.caption2).foregroundStyle(.white.opacity(0.55))
                            }
                        }
                        .tint(accent)
                    }

                    group("Motion") {
                        labeledSlider("Speed", value: $settings.speed,
                                      range: 0.2...3, step: 0.1,
                                      display: String(format: "%.1f×", settings.speed))
                    }

                    group("Look") {
                        Toggle(isOn: $settings.glow) {
                            Text("Glow").foregroundStyle(.white)
                        }
                        .tint(accent)

                        labeledSlider("Color", value: $settings.hue,
                                      range: 0...1, step: 0.01,
                                      display: hueName(settings.hue))

                        labeledSlider("Line width", value: $settings.lineWidth,
                                      range: 0.5...4, step: 0.1,
                                      display: String(format: "%.1f", settings.lineWidth))
                    }
                }
                .padding(20)
            }
            .scrollContentBackground(.hidden)
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Style & Numerics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.black, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Building blocks

    private func group<Content: View>(_ title: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.caption.weight(.semibold))
                .foregroundStyle(accent.opacity(0.8))
                .tracking(0.8)
            content()
        }
    }

    private func labeledSlider(_ label: String, value: Binding<Double>,
                               range: ClosedRange<Double>, step: Double,
                               display: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label).foregroundStyle(.white)
                Spacer()
                Text(display).font(.callout.monospacedDigit()).foregroundStyle(.white.opacity(0.7))
            }
            Slider(value: value, in: range, step: step).tint(accent)
        }
    }

    private func hueName(_ h: Double) -> String {
        switch h {
        case ..<0.04, 0.96...: return "Red"
        case ..<0.12: return "Orange"
        case ..<0.19: return "Yellow"
        case ..<0.42: return "Green"
        case ..<0.54: return "Teal"
        case ..<0.7:  return "Blue"
        case ..<0.83: return "Purple"
        default:      return "Magenta"
        }
    }
}
