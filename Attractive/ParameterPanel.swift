import SwiftUI

/// Live-tuning panel for the selected attractor's parameters. Each slider is
/// bound to a local draft and commits to `AttractiveSettings` only when the drag
/// ends — one engine re-integration per gesture, not per pixel. Bifurcation
/// thresholds from the metadata are drawn on the track and are tappable.
struct ParameterPanel: View {
    @Bindable var settings: AttractiveSettings

    private var metadata: AttractorMetadata {
        AttractorMetadataRegistry.metadata(for: settings.attractor)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header

                    ForEach(metadata.parameters) { info in
                        ParameterSliderRow(settings: settings, info: info)
                    }
                }
                .padding(20)
            }
            .scrollContentBackground(.hidden)
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Tune \(settings.attractor.displayName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.black, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Reset") { settings.resetParameters() }
                        .disabled(!settings.hasParameterOverrides)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        Text(metadata.character)
            .font(.callout)
            .foregroundStyle(.white.opacity(0.7))
            .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - One parameter row

private struct ParameterSliderRow: View {
    @Bindable var settings: AttractiveSettings
    let info: ParameterInfo

    @State private var draft: Double = 0
    @State private var selectedBifurcation: ParameterInfo.Bifurcation?

    private var accent: Color {
        settings.accentColor
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header: symbol + name + meaning + live value.
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(info.symbol)
                    .font(.title3.monospaced().weight(.semibold))
                    .foregroundStyle(accent)
                    .frame(minWidth: 28, alignment: .leading)
                VStack(alignment: .leading, spacing: 2) {
                    Text(info.name)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white)
                    Text(info.meaning)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.55))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Text(format(draft))
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.white)
            }

            // Slider with bifurcation markers overlaid on the track.
            ZStack(alignment: .leading) {
                Slider(value: $draft, in: info.range, step: info.step) { editing in
                    if !editing { commit() }
                }
                .tint(accent)

                if !info.bifurcations.isEmpty {
                    BifurcationTrack(info: info,
                                     accent: accent,
                                     onTap: jump(to:))
                }
            }

            if let b = selectedBifurcation {
                BifurcationCallout(bifurcation: b, accent: accent)
                    .transition(.opacity)
            }
        }
        .onAppear { draft = settings.parameter(info.slot) }
        .onChange(of: settings.paramRevision) { _, _ in draft = settings.parameter(info.slot) }
        .onChange(of: settings.attractor)     { _, _ in draft = settings.parameter(info.slot) }
    }

    private func commit() {
        // Magnetic snap to a nearby bifurcation threshold.
        if let near = info.bifurcations.first(where: { abs(draft - $0.value) < info.step * 2 }) {
            draft = near.value
        }
        settings.setParameter(info.slot, draft)
    }

    private func jump(to b: ParameterInfo.Bifurcation) {
        draft = b.value
        settings.setParameter(info.slot, b.value)
        withAnimation { selectedBifurcation = (selectedBifurcation == b) ? nil : b }
    }

    private func format(_ v: Double) -> String {
        // Use the slider step to decide decimal places.
        let decimals = info.step < 0.01 ? 4 : (info.step < 0.1 ? 3 : (info.step < 1 ? 2 : 1))
        return String(format: "%.\(decimals)f", v)
    }
}

// MARK: - Bifurcation markers on the track

private struct BifurcationTrack: View {
    let info: ParameterInfo
    let accent: Color
    let onTap: (ParameterInfo.Bifurcation) -> Void

    /// Approximate half-width of the slider thumb; the thumb centre only travels
    /// between these insets, so markers must respect the same band.
    private let thumbInset: CGFloat = 11

    var body: some View {
        GeometryReader { geo in
            let usable = max(1, geo.size.width - thumbInset * 2)
            ForEach(info.bifurcations) { b in
                let f = fraction(for: b.value)
                Capsule()
                    .fill(accent.opacity(0.9))
                    .frame(width: 2, height: 18)
                    .overlay {
                        // Wider invisible hit target.
                        Color.clear
                            .frame(width: 30, height: 36)
                            .contentShape(Rectangle())
                            .onTapGesture { onTap(b) }
                    }
                    .position(x: thumbInset + usable * f, y: geo.size.height / 2)
                    .accessibilityElement()
                    .accessibilityLabel("\(b.label), \(info.symbol) equals \(String(format: "%g", b.value))")
                    .accessibilityHint(b.detail)
                    .accessibilityAddTraits(.isButton)
                    .accessibilityAction { onTap(b) }
            }
        }
        .frame(height: 28)
    }

    private func fraction(for value: Double) -> CGFloat {
        let lo = info.range.lowerBound, hi = info.range.upperBound
        guard hi > lo else { return 0 }
        return CGFloat((min(max(value, lo), hi) - lo) / (hi - lo))
    }
}

// MARK: - Callout

private struct BifurcationCallout: View {
    let bifurcation: ParameterInfo.Bifurcation
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: "arrow.triangle.branch")
                    .font(.caption2)
                    .foregroundStyle(accent)
                Text("\(bifurcation.label) — \(format(bifurcation.value))")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
            }
            Text(bifurcation.detail)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.65))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.06)))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(accent.opacity(0.3), lineWidth: 1))
    }

    private func format(_ v: Double) -> String {
        v == v.rounded() ? String(format: "%.0f", v) : String(format: "%.3f", v)
    }
}
