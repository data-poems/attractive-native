import Foundation
import simd

/// Online estimator for the largest Lyapunov exponent via the Benettin method:
/// evolve a companion trajectory a tiny distance `d0` away, measure how that
/// separation grows each step, accumulate the log growth, then renormalize the
/// companion back to `d0` so it never saturates. The running average of the log
/// growth per unit model-time converges to λ₁.
///
/// Pure value type — no UIKit/SceneKit — so it unit-tests against the reference
/// values in `AttractorMetadata`.
public struct LyapunovEstimator {

    /// Current estimate of the largest Lyapunov exponent (per unit model time).
    public private(set) var current: Double = 0
    /// True once enough model time has elapsed for `current` to be meaningful.
    public private(set) var warm: Bool = false

    private var logSum: Double = 0
    private var elapsed: Double = 0
    private let d0: Double
    private let warmupSteps: Int
    private var warmupRemaining: Int
    /// Model time after which the estimate is considered settled.
    private let warmTime: Double

    public init(d0: Double = 1e-8, warmupSteps: Int = 1000, warmTime: Double = 8) {
        self.d0 = d0
        self.warmupSteps = warmupSteps
        self.warmupRemaining = warmupSteps
        self.warmTime = warmTime
    }

    /// One Benettin step. `reference` is the main trajectory's new state;
    /// `companion` is the nearby trajectory's new state (already advanced one
    /// step with the same integrator and `dt`). Returns the companion
    /// renormalized back to distance `d0` along the current separation
    /// direction, to feed into the next step.
    public mutating func step(reference: SIMD3<Double>,
                              companion: SIMD3<Double>,
                              dt: Double) -> SIMD3<Double> {
        let delta = companion - reference
        let d1 = simd_length(delta)
        guard d1 > 0, d1.isFinite else {
            // Degenerate separation — re-seed along x at the base distance.
            return reference + SIMD3<Double>(d0, 0, 0)
        }

        if warmupRemaining > 0 {
            warmupRemaining -= 1
        } else {
            logSum += log(d1 / d0)
            elapsed += dt
            if elapsed > 0 { current = logSum / elapsed }
            if elapsed >= warmTime { warm = true }
        }

        // Renormalize back to d0, preserving direction.
        return reference + delta * (d0 / d1)
    }

    /// Initial companion offset for a given reference state.
    public func seed(from reference: SIMD3<Double>) -> SIMD3<Double> {
        reference + SIMD3<Double>(d0, 0, 0)
    }

    public mutating func reset() {
        current = 0
        warm = false
        logSum = 0
        elapsed = 0
        warmupRemaining = warmupSteps
    }
}
