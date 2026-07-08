import SwiftUI

/// One-time first-launch overlay that orients a new user in three taps.
/// The live attractor stays visible and animated behind the dim so the
/// app's core appeal is the first thing they experience.
struct IntroTour: View {
    @Bindable var settings: AttractiveSettings
    @State private var step = 0

    private struct TourStep {
        let icon: String
        let title: String
        let body: String
    }

    private let steps: [TourStep] = [
        TourStep(
            icon: "tornado",
            title: "Chaos, made visible",
            body: "A trajectory obeying a fixed rule that never repeats, never settles, yet never escapes. Lorenz discovered this strange attractor in 1963 — and found that tiny differences grow without bound."
        ),
        TourStep(
            icon: "hand.draw",
            title: "Navigate the phase space",
            body: "Drag to orbit · pinch to zoom. Tap a point on the trail to read its state vector; long-press to relaunch the trajectory from that point."
        ),
        TourStep(
            icon: "circle.grid.cross",
            title: "Explore",
            body: "The bar below switches attractors, bends their equations live, and opens guided lessons on chaos, Lyapunov exponents, and fractal dimension."
        ),
    ]

    private var isLast: Bool { step == steps.count - 1 }
    private var accent: Color { settings.accentColor }
    private var current: TourStep { steps[step] }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.6).ignoresSafeArea()

            VStack(spacing: 0) {
                card
                    .padding(.horizontal, 20)
                navRow
                    .padding(.horizontal, 20)
                    .padding(.top, 14)
                    .padding(.bottom, 30)
            }
        }
    }

    // MARK: - Card

    private var card: some View {
        VStack(alignment: .leading, spacing: 16) {
            Image(systemName: current.icon)
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(accent)

            Text(current.title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)

            Text(current.body)
                .font(.callout)
                .foregroundStyle(.white.opacity(0.75))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 20).fill(Color.black.opacity(0.88)))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(accent.opacity(0.25), lineWidth: 1))
        .id(step)
        .transition(.asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal:   .move(edge: .leading).combined(with: .opacity)))
    }

    // MARK: - Nav row

    private var navRow: some View {
        HStack {
            HStack(spacing: 6) {
                ForEach(steps.indices, id: \.self) { i in
                    Capsule()
                        .fill(i == step ? accent : Color.white.opacity(0.2))
                        .frame(width: i == step ? 22 : 7, height: 7)
                        .animation(.easeInOut(duration: 0.2), value: step)
                }
            }

            Spacer()

            Button {
                if isLast {
                    withAnimation(.easeOut(duration: 0.35)) {
                        settings.hasSeenIntro = true
                    }
                } else {
                    withAnimation(.spring(duration: 0.28)) {
                        step += 1
                    }
                }
            } label: {
                Text(isLast ? "Let's go" : "Next")
                    .font(.callout.weight(.semibold))
                    .padding(.horizontal, 22).padding(.vertical, 10)
                    .background(Capsule().fill(isLast ? accent : Color.white.opacity(0.12)))
                    .foregroundStyle(isLast ? .black : .white)
                    .animation(.easeInOut(duration: 0.2), value: isLast)
            }
        }
    }
}
