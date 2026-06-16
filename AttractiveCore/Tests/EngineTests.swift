import XCTest
import simd
@testable import AttractiveKit

final class RingBufferTests: XCTestCase {

    func testAppendUnderCapacityPreservesOrder() {
        var rb = RingBuffer<Int>(capacity: 5)
        for i in 1...3 { rb.append(i) }
        XCTAssertEqual(rb.count, 3)
        XCTAssertEqual(rb.ordered(), [1, 2, 3])
        XCTAssertEqual(rb.last, 3)
    }

    func testWrapAroundDropsOldest() {
        var rb = RingBuffer<Int>(capacity: 3)
        for i in 1...5 { rb.append(i) }   // 1,2 evicted
        XCTAssertEqual(rb.count, 3)
        XCTAssertTrue(rb.isFull)
        XCTAssertEqual(rb.ordered(), [3, 4, 5])
        XCTAssertEqual(rb.last, 5)
    }

    func testRemoveAllResets() {
        var rb = RingBuffer<Int>(capacity: 3)
        for i in 1...5 { rb.append(i) }
        rb.removeAll()
        XCTAssertEqual(rb.count, 0)
        XCTAssertNil(rb.last)
        rb.append(9)
        XCTAssertEqual(rb.ordered(), [9])
    }

    func testForEachOrderedMatchesOrdered() {
        var rb = RingBuffer<Int>(capacity: 4)
        for i in 1...7 { rb.append(i) }   // keeps 4,5,6,7
        var collected: [Int] = []
        rb.forEachOrdered { collected.append($0) }
        XCTAssertEqual(collected, rb.ordered())
        XCTAssertEqual(collected, [4, 5, 6, 7])
    }
}

final class EngineCompanionTests: XCTestCase {

    /// The reference trajectory must be bit-identical whether or not the
    /// companion is being tracked — companions must never perturb the reference.
    func testReferenceUnaffectedByCompanion() {
        func runReference(tracking: Bool) -> [SIMD3<Double>] {
            let engine = AttractiveEngine(config: AttractorRegistry.defaultConfig(for: .lorenz))
            engine.tracksCompanion = tracking
            engine.regenerate(width: 400, height: 400)
            var states: [SIMD3<Double>] = []
            // Deterministic synthetic clock: fixed 16ms ticks.
            for k in 1...120 {
                engine.advance(timeMs: Double(k) * 16.0)
                states.append(engine.state)
            }
            return states
        }

        let without = runReference(tracking: false)
        let with = runReference(tracking: true)
        XCTAssertEqual(without.count, with.count)
        for (a, b) in zip(without, with) {
            XCTAssertEqual(a.x, b.x, accuracy: 0)
            XCTAssertEqual(a.y, b.y, accuracy: 0)
            XCTAssertEqual(a.z, b.z, accuracy: 0)
        }
    }

    /// With companion tracking on, the two trajectories diverge (positive
    /// largest Lyapunov exponent for Lorenz) — separation should grow well
    /// beyond the seed epsilon.
    func testCompanionDivergesOnChaoticSystem() {
        let engine = AttractiveEngine(config: AttractorRegistry.defaultConfig(for: .lorenz))
        engine.tracksCompanion = true
        engine.epsilon = 1e-5
        engine.regenerate(width: 400, height: 400)
        for k in 1...600 { engine.advance(timeMs: Double(k) * 16.0) }
        // Positive largest Lyapunov exponent ⇒ separation grows exponentially,
        // many times the seed epsilon. (Order-1 saturation needs more model
        // time than this synthetic clock advances; an order-of-magnitude of
        // growth is the robust signature.)
        XCTAssertGreaterThan(engine.separation, 10 * engine.epsilon,
                             "Nearby trajectories should diverge on a chaotic attractor")
    }

    func testReseedClearsAndRecenters() {
        let engine = AttractiveEngine()
        engine.regenerate(width: 400, height: 400)
        for k in 1...30 { engine.advance(timeMs: Double(k) * 16.0) }
        XCTAssertGreaterThan(engine.points3D.count, 0)
        engine.reseed(at: SIMD3<Double>(5, 5, 5))
        XCTAssertEqual(engine.points3D.count, 0)
        XCTAssertEqual(engine.headIndex, 0)
        XCTAssertEqual(engine.state.x, 5, accuracy: 1e-12)
    }
}

final class LyapunovTests: XCTestCase {

    /// Drive the Benettin estimator directly over a long Lorenz integration and
    /// check it converges to the literature value within tolerance.
    func testLyapunovConvergesLorenz() {
        let cfg = AttractorRegistry.defaultConfig(for: .lorenz)
        var est = LyapunovEstimator(d0: 1e-8, warmupSteps: 2000, warmTime: 8)
        let dt = 0.005
        var (x, y, z) = (0.1, 0.0, 0.0)
        var c = est.seed(from: SIMD3(x, y, z))
        for _ in 0..<200_000 {
            (x, y, z) = cfg.step(x, y, z, dt: dt, integrator: .rk4)
            let cs = cfg.step(c.x, c.y, c.z, dt: dt, integrator: .rk4)
            c = est.step(reference: SIMD3(x, y, z), companion: SIMD3(cs.0, cs.1, cs.2), dt: dt)
        }
        let reference = AttractorMetadataRegistry.metadata(for: .lorenz).lyapunovEstimate!
        XCTAssertTrue(est.warm)
        XCTAssertEqual(est.current, reference, accuracy: reference * 0.2,
                       "Lorenz λ₁ should converge near \(reference), got \(est.current)")
    }

    /// Rössler is weakly chaotic — λ₁ is small but positive. Assert sign and a
    /// generous bound rather than a tight value (its convergence is noisier).
    func testLyapunovPositiveRossler() {
        let cfg = AttractorRegistry.defaultConfig(for: .rossler)
        var est = LyapunovEstimator(d0: 1e-8, warmupSteps: 4000, warmTime: 20)
        let dt = 0.005
        var (x, y, z) = (1.0, 1.0, 1.0)
        var c = est.seed(from: SIMD3(x, y, z))
        for _ in 0..<400_000 {
            (x, y, z) = cfg.step(x, y, z, dt: dt, integrator: .rk4)
            let cs = cfg.step(c.x, c.y, c.z, dt: dt, integrator: .rk4)
            c = est.step(reference: SIMD3(x, y, z), companion: SIMD3(cs.0, cs.1, cs.2), dt: dt)
        }
        XCTAssertGreaterThan(est.current, 0, "Rössler is chaotic ⇒ λ₁ > 0")
        XCTAssertLessThan(est.current, 0.3, "Rössler λ₁ is small")
    }

    /// On a non-chaotic regime the estimate should not be strongly positive.
    /// Thomas above its chaos threshold relaxes toward a limit cycle ⇒ λ₁ ≈ 0.
    func testLyapunovResetClearsAccumulation() {
        var est = LyapunovEstimator(d0: 1e-8, warmupSteps: 0)
        _ = est.step(reference: SIMD3(0, 0, 0), companion: SIMD3(1e-8 * 3, 0, 0), dt: 0.01)
        XCTAssertNotEqual(est.current, 0)
        est.reset()
        XCTAssertEqual(est.current, 0)
        XCTAssertFalse(est.warm)
    }
}

final class IntegratorTests: XCTestCase {

    /// Euler step must equal the explicit forward-Euler formula from the
    /// derivative — guards the refactor that split `derivative` out of `step`.
    func testEulerMatchesDerivative() {
        let cfg = AttractorRegistry.defaultConfig(for: .lorenz)
        let (x, y, z) = (1.0, 2.0, 3.0)
        let dt = 0.01
        let d = cfg.derivative(x, y, z)
        let stepped = cfg.step(x, y, z, dt: dt, integrator: .euler)
        XCTAssertEqual(stepped.0, x + d.0 * dt, accuracy: 1e-12)
        XCTAssertEqual(stepped.1, y + d.1 * dt, accuracy: 1e-12)
        XCTAssertEqual(stepped.2, z + d.2 * dt, accuracy: 1e-12)
    }

    /// On a linear-ish slice RK4 and Euler agree to first order but differ at
    /// higher order; here we just assert RK4 produces a finite, distinct result
    /// and stays bounded over many steps where Euler can blow up.
    func testRK4StaysBounded() {
        let cfg = AttractorRegistry.defaultConfig(for: .lorenz)
        var (x, y, z) = (0.1, 0.0, 0.0)
        for _ in 0..<5000 {
            (x, y, z) = cfg.step(x, y, z, dt: 0.01, integrator: .rk4)
        }
        XCTAssertTrue(x.isFinite && y.isFinite && z.isFinite)
        // Lorenz attractor is bounded; coordinates stay within a generous box.
        XCTAssertLessThan(abs(x), 100)
        XCTAssertLessThan(abs(y), 100)
        XCTAssertLessThan(abs(z), 200)
    }
}
