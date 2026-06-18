import SwiftUI
import simd

/// Observable model the SceneKit coordinator writes to (throttled, on the main
/// actor) and the HUD reads. Kept separate from `AttractiveSettings` because it
/// is live telemetry, not persisted preference.
@MainActor
@Observable
final class PhaseHUDModel {
    /// Separation between the reference and companion trajectories (model space).
    var separation: Double?
    /// Rolling log10 separation samples for the sparkline (oldest→newest).
    var separationLog: [Double] = []
    /// Live largest-Lyapunov estimate and whether it has converged enough to trust.
    var lyapunov: Double?
    var lyapunovWarm: Bool = false
    /// A point the user tapped to inspect (Phase 8).
    var inspected: SIMD3<Double>?

    private let maxSamples = 120

    func pushSeparation(_ d: Double) {
        separation = d
        if d > 0 {
            separationLog.append(log10(d))
            if separationLog.count > maxSamples {
                separationLog.removeFirst(separationLog.count - maxSamples)
            }
        }
    }

    func reset() {
        separation = nil
        separationLog.removeAll(keepingCapacity: true)
        lyapunov = nil
        lyapunovWarm = false
        inspected = nil
    }
}

/// Heads-up overlay for the 3D phase space: the live separation readout with a
/// log-scale sparkline (exponential divergence reads as a straight ramp), the
/// Lyapunov estimate colour-coded by sign, and the tapped state vector.
struct PhaseHUD: View {
    var model: PhaseHUDModel
    var metadata: AttractorMetadata
    var showSeparation: Bool
    var showLyapunov: Bool
    var accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if showSeparation, let d = model.separation {
                separationCard(d)
            }
            if showLyapunov {
                lyapunovCard()
            }
            if let p = model.inspected {
                inspectCard(p)
            }
        }
        .padding(12)
        .frame(maxWidth: 230, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.black.opacity(0.55)))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.08), lineWidth: 1))
    }

    // MARK: - Cards

    private func separationCard(_ d: Double) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            label("Separation δ")
            Text(scientific(d))
                .font(.title3.monospacedDigit().weight(.semibold))
                .foregroundStyle(.white)
            Sparkline(values: model.separationLog, color: accent)
                .frame(height: 34)
            Text("two trajectories, started 10⁻⁵ apart")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.5))
        }
    }

    private func lyapunovCard() -> some View {
        VStack(alignment: .leading, spacing: 4) {
            label("Largest Lyapunov λ₁")
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(model.lyapunov.map { String(format: "%+.3f", $0) } ?? "…")
                    .font(.title3.monospacedDigit().weight(.semibold))
                    .foregroundStyle(lyapunovColor)
                if let ref = metadata.lyapunovEstimate {
                    Text("ref \(String(format: "%.2f", ref))")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.white.opacity(0.4))
                }
            }
            Text(lyapunovVerdict)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.55))
        }
    }

    private func inspectCard(_ p: SIMD3<Double>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            label("Inspected state")
            Text(String(format: "x %.2f\ny %.2f\nz %.2f", p.x, p.y, p.z))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.white.opacity(0.85))
        }
    }

    // MARK: - Bits

    private func label(_ t: String) -> some View {
        Text(t.uppercased())
            .font(.caption2.weight(.semibold))
            .foregroundStyle(accent.opacity(0.8))
            .tracking(0.6)
    }

    private var lyapunovColor: Color {
        guard let l = model.lyapunov, model.lyapunovWarm else { return .white.opacity(0.6) }
        if l > 0.02 { return .orange }
        if l < -0.02 { return .green }
        return .yellow
    }

    private var lyapunovVerdict: String {
        guard let l = model.lyapunov else { return "estimating…" }
        if !model.lyapunovWarm { return "converging…" }
        if l > 0.02 { return "positive ⇒ chaotic, sensitive to start" }
        if l < -0.02 { return "negative ⇒ trajectories converge" }
        return "≈ 0 ⇒ marginal / quasiperiodic"
    }

    private func scientific(_ d: Double) -> String {
        if d == 0 { return "0" }
        let exp = Int(floor(log10(abs(d))))
        let mant = d / pow(10, Double(exp))
        return String(format: "%.2f×10%@", mant, superscript(exp))
    }

    private func superscript(_ n: Int) -> String {
        let map: [Character: Character] = ["0":"⁰","1":"¹","2":"²","3":"³","4":"⁴",
                                           "5":"⁵","6":"⁶","7":"⁷","8":"⁸","9":"⁹","-":"⁻"]
        return String(String(n).map { map[$0] ?? $0 })
    }
}

/// Minimal log-scale sparkline.
private struct Sparkline: View {
    let values: [Double]
    let color: Color

    var body: some View {
        GeometryReader { geo in
            if values.count > 1 {
                let lo = values.min() ?? 0
                let hi = values.max() ?? 1
                let span = max(hi - lo, 1e-9)
                Path { p in
                    for (i, v) in values.enumerated() {
                        let x = geo.size.width * CGFloat(i) / CGFloat(values.count - 1)
                        let y = geo.size.height * (1 - CGFloat((v - lo) / span))
                        if i == 0 { p.move(to: CGPoint(x: x, y: y)) }
                        else { p.addLine(to: CGPoint(x: x, y: y)) }
                    }
                }
                .stroke(color, style: StrokeStyle(lineWidth: 1.5, lineJoin: .round))
            }
        }
        .accessibilityHidden(true)   // the separation value is announced as text
    }
}
