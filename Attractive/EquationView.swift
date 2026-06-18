import SwiftUI

/// The mathematical dossier for the selected attractor: its ODE system rendered
/// as LaTeX, the meaning of each parameter (with live values), the historical
/// origin, the dynamical character, and the invariants that quantify its chaos.
struct EquationView: View {
    @Bindable var settings: AttractiveSettings
    @Environment(\.dismiss) private var dismiss

    private var metadata: AttractorMetadata {
        AttractorMetadataRegistry.metadata(for: settings.attractor)
    }

    private var accent: Color {
        settings.accentColor
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    systemBlock
                    parameterLegend
                    prose("Origin", metadata.origin)
                    prose("Dynamics", metadata.character)
                    invariants
                }
                .padding(20)
            }
            .scrollContentBackground(.hidden)
            .background(Color.black.ignoresSafeArea())
            .navigationTitle(metadata.id.displayName)
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

    // MARK: - Sections

    private var systemBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("System")
            ForEach(Array(metadata.systemLatex.enumerated()), id: \.offset) { _, line in
                LaTeXLine(latex: line, color: .white, fontSize: 22)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var parameterLegend: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Parameters")
            ForEach(metadata.parameters) { info in
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(info.symbol)
                        .font(.headline.monospaced())
                        .foregroundStyle(accent)
                        .frame(minWidth: 28, alignment: .leading)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(info.name)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.white)
                        Text(info.meaning)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.6))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 8)
                    Text(formatted(settings.parameter(info.slot)))
                        .font(.callout.monospacedDigit())
                        .foregroundStyle(.white.opacity(0.9))
                }
            }
        }
    }

    private var invariants: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Invariants at current parameters")
            HStack(spacing: 12) {
                statCard(title: "λ₁",
                         value: metadata.lyapunovEstimate.map { formatted($0) } ?? "—",
                         caption: "Largest Lyapunov exponent\npositive ⇒ chaotic")
                statCard(title: "D",
                         value: metadata.fractalDimensionEstimate.map { formatted($0) } ?? "—",
                         caption: "Fractal dimension\nof the attractor")
            }
        }
    }

    // MARK: - Building blocks

    private func prose(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel(title)
            Text(body)
                .font(.callout)
                .foregroundStyle(.white.opacity(0.8))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func statCard(title: String, value: String, caption: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(title).font(.title3.monospaced().weight(.semibold)).foregroundStyle(accent)
                Text(value).font(.title3.monospacedDigit()).foregroundStyle(.white)
            }
            Text(caption)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.55))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.05)))
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.caption.weight(.semibold))
            .foregroundStyle(accent.opacity(0.8))
            .tracking(0.8)
    }

    private func formatted(_ v: Double) -> String {
        if v == v.rounded() { return String(format: "%.0f", v) }
        return abs(v) < 0.01 ? String(format: "%.4f", v) : String(format: "%.3f", v)
    }
}
