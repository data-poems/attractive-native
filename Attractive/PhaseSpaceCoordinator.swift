import SceneKit
import UIKit
import simd

/// Drives the 3D phase space: owns the engine, the SceneKit scene graph, the
/// arcball camera (custom, so it never fights the inspection gestures), and the
/// per-frame render loop. SwiftUI feeds it props through `apply(...)`.
final class PhaseSpaceCoordinator: NSObject, SCNSceneRendererDelegate, UIGestureRecognizerDelegate {

    let scene = SCNScene()
    private let engine = AttractiveEngine()
    /// Serializes all access to `engine`, which is mutated from the main thread
    /// (apply / gesture handlers) and advanced+read on SceneKit's render thread.
    private let engineLock = NSLock()

    @inline(__always)
    private func locked<T>(_ body: () -> T) -> T {
        engineLock.lock(); defer { engineLock.unlock() }
        return body()
    }

    /// Bloom strength when glow is on — cranked for a hot, neon phase space.
    static let bloomLevel: CGFloat = 3.6

    // Camera rig: orbit node at the attractor centre, camera pulled back along z.
    private let cameraOrbit = SCNNode()
    private let cameraNode = SCNNode()
    private var orbitRadius: CGFloat = 60
    private var baseRadius: CGFloat = 60

    // Trails.
    private let trail = TrailGeometry(capacity: 9000)
    private let companionTrail = TrailGeometry(capacity: 9000)
    private let headNode = SCNNode()
    private let markerNode = SCNNode()

    // Current props (compared to detect changes).
    private var config: AttractorConfig?
    private var hue: Double = 0.55
    private var glow: Bool = true
    private var sensitive: Bool = false
    private var lyapunov: Bool = false

    // Clock.
    private var firstTime: TimeInterval = 0
    private var started = false

    // HUD telemetry (written throttled, on the main actor).
    var hud: PhaseHUDModel?
    private var lastHUDTime: TimeInterval = 0

    // Inspection callback (Phase 8) — set by the view.
    var onInspect: ((SIMD3<Double>) -> Void)?

    override init() {
        super.init()
        buildScene()
    }

    // MARK: - Scene construction

    private func buildScene() {
        scene.background.contents = UIColor.black

        let cam = SCNCamera()
        cam.usesOrthographicProjection = false
        cam.fieldOfView = 45
        cam.zNear = 0.1
        cam.zFar = 10_000
        cam.bloomIntensity = Self.bloomLevel
        cam.bloomBlurRadius = 22
        cam.bloomThreshold = 0.0          // every lit pixel contributes to the glow
        cam.bloomIterationCount = 3       // wider, softer halo
        cam.wantsHDR = true
        cameraNode.camera = cam
        cameraNode.position = SCNVector3(0, 0, orbitRadius)
        cameraOrbit.addChildNode(cameraNode)
        scene.rootNode.addChildNode(cameraOrbit)

        let head = SCNSphere(radius: 0.9)
        let hm = SCNMaterial()
        hm.lightingModel = .constant
        hm.diffuse.contents = UIColor.white
        hm.emission.contents = UIColor.white
        head.materials = [hm]
        headNode.geometry = head

        let marker = SCNSphere(radius: 1.0)
        let mm = SCNMaterial()
        mm.lightingModel = .constant
        mm.diffuse.contents = UIColor.systemYellow
        mm.emission.contents = UIColor.systemYellow
        marker.materials = [mm]
        markerNode.geometry = marker
        markerNode.isHidden = true

        scene.rootNode.addChildNode(trail.node)
        scene.rootNode.addChildNode(companionTrail.node)
        scene.rootNode.addChildNode(headNode)
        scene.rootNode.addChildNode(markerNode)
    }

    var pointOfView: SCNNode { cameraNode }

    // MARK: - Props from SwiftUI

    func apply(config: AttractorConfig, speed: Double, zoom: Double,
               hue: Double, glow: Bool, integrator: IntegratorKind,
               sensitive: Bool, lyapunov: Bool) {
        // All state shared with the render thread is read/written under the lock.
        // `framingCenter` is captured here and applied to the camera afterwards,
        // so SceneKit node mutations happen outside the lock in one transaction.
        let result: (mustRegenerate: Bool, framingCenter: SIMD3<Float>?) = locked {
            let changed = (self.config != config) || (self.sensitive != sensitive)
                || (self.lyapunov != lyapunov) || !started
            self.hue = hue
            self.glow = glow
            self.config = config
            self.sensitive = sensitive
            self.lyapunov = lyapunov
            engine.speed = speed
            engine.zoom = zoom
            engine.integrator = integrator

            var framingCenter: SIMD3<Float>? = nil
            if changed {
                engine.tracksCompanion = sensitive
                engine.computesLyapunov = lyapunov
                engine.regenerate(width: 400, height: 400, config: config)
                companionTrail.clear()
                started = false
                let b = engine.modelBounds
                if b.extent.isFinite, b.extent > 0 {
                    baseRadius = CGFloat(max(b.extent, 1)) * 1.2
                    framingCenter = SIMD3(Float(b.center.x), Float(b.center.y), Float(b.center.z))
                }
            }
            return (changed, framingCenter)
        }

        // SceneKit node mutations on the main thread — batch in one transaction.
        SCNTransaction.begin()
        SCNTransaction.disableActions = true
        if let c = result.framingCenter {
            cameraOrbit.position = SCNVector3(c.x, c.y, c.z)
        }
        cameraNode.camera?.bloomIntensity = glow ? Self.bloomLevel : 0
        orbitRadius = baseRadius / max(0.2, CGFloat(zoom))
        cameraNode.position = SCNVector3(0, 0, orbitRadius)
        SCNTransaction.commit()

        if result.mustRegenerate {
            Task { @MainActor [weak self] in self?.hud?.reset() }

            // Refine bounds precisely in the background and reanimate the camera
            // to the correct framing. The rough estimate from regenerate provides
            // immediate placement; this glide corrects it within one display cycle.
            let capturedConfig = config
            let capturedIntegrator = integrator
            let capturedZoom = zoom
            Task { @MainActor [weak self] in
                guard let self else { return }
                let bounds = await Task.detached(priority: .userInitiated) {
                    AttractiveEngine.estimateBounds(config: capturedConfig, integrator: capturedIntegrator)
                }.value
                self.locked { self.engine.applyBounds(bounds) }
                let c = bounds.center
                let extent = bounds.extent
                guard extent.isFinite, extent > 0 else { return }
                SCNTransaction.begin()
                SCNTransaction.animationDuration = 0.25
                self.baseRadius = CGFloat(max(extent, 1)) * 1.2
                self.orbitRadius = self.baseRadius / max(0.2, CGFloat(capturedZoom))
                self.cameraOrbit.position = SCNVector3(Float(c.x), Float(c.y), Float(c.z))
                self.cameraNode.position = SCNVector3(0, 0, self.orbitRadius)
                SCNTransaction.commit()
            }
        }
    }

    // MARK: - Render loop

    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        // Advance and read every piece of shared state under the lock so a
        // concurrent main-thread apply()/reseed() can't tear it.
        let snapshot: (state: SIMD3<Double>, sep: Double?, lyap: Double?,
                       warm: Bool, sensitive: Bool, lyapunov: Bool) = locked {
            if !started { started = true; firstTime = time }
            let elapsedMs = (time - firstTime) * 1000.0
            let sensitive = self.sensitive
            let lyapunov = self.lyapunov
            let rgb = Self.rgb(hue: hue)

            engine.advance(timeMs: elapsedMs)
            trail.update(points: engine.points3D, rgb: rgb)
            if sensitive {
                let companionRgb = Self.rgb(hue: (hue + 0.5).truncatingRemainder(dividingBy: 1))
                companionTrail.update(points: engine.companionPoints3D, rgb: companionRgb)
            }
            return (engine.state,
                    sensitive ? engine.separation : nil,
                    lyapunov ? engine.lyapunov.current : nil,
                    engine.lyapunov.warm, sensitive, lyapunov)
        }

        headNode.position = SCNVector3(Float(snapshot.state.x), Float(snapshot.state.y), Float(snapshot.state.z))

        // Throttled HUD telemetry (~10 Hz) — hop to the main actor.
        if (snapshot.sensitive || snapshot.lyapunov), time - lastHUDTime > 0.1 {
            lastHUDTime = time
            let sep = snapshot.sep, lyap = snapshot.lyap, warm = snapshot.warm
            Task { @MainActor [weak self] in
                if let sep { self?.hud?.pushSeparation(sep) }
                if let lyap {
                    self?.hud?.lyapunov = lyap
                    self?.hud?.lyapunovWarm = warm
                }
            }
        }
    }

    // MARK: - Gestures (camera; inspection added in Phase 8)

    private var lastPan: CGPoint = .zero

    @objc func handlePan(_ g: UIPanGestureRecognizer) {
        let t = g.translation(in: g.view)
        if g.state == .began { lastPan = .zero }
        let dx = Float(t.x - lastPan.x)
        let dy = Float(t.y - lastPan.y)
        lastPan = t
        // Yaw about world up, pitch about the camera's right.
        let yaw = -dx * 0.005
        let pitch = -dy * 0.005
        var e = cameraOrbit.eulerAngles
        e.y += yaw
        e.x += pitch
        e.x = max(-Float.pi / 2 + 0.05, min(Float.pi / 2 - 0.05, e.x))
        cameraOrbit.eulerAngles = e
    }

    /// Extra yaw already folded into `cameraOrbit`. Hinge turns are applied as
    /// deltas so they add to drag rotation instead of overwriting it.
    private var appliedExtraYaw: Double = 0

    /// Turn the camera about world up by the change in `yaw` since the last
    /// call (iPhone Duo "fold to turn"; see `DuoSplitLayout`).
    func applyExtraYaw(_ yaw: Double) {
        let delta = yaw - appliedExtraYaw
        guard delta != 0 else { return }
        appliedExtraYaw = yaw
        var e = cameraOrbit.eulerAngles
        e.y += Float(delta)
        cameraOrbit.eulerAngles = e
    }

    @objc func handlePinch(_ g: UIPinchGestureRecognizer) {
        if g.state == .changed {
            orbitRadius = max(2, orbitRadius / CGFloat(g.scale))
            cameraNode.position = SCNVector3(0, 0, orbitRadius)
            g.scale = 1
        }
    }

    /// Tap a point in the phase space to read its (x, y, z) state vector.
    @objc func handleTap(_ g: UITapGestureRecognizer) {
        guard let view = g.view as? SCNView,
              let p = nearestTrailPoint(to: g.location(in: view), in: view) else { return }
        markerNode.position = SCNVector3(p.x, p.y, p.z)
        markerNode.isHidden = false
        let state = SIMD3<Double>(Double(p.x), Double(p.y), Double(p.z))
        Task { @MainActor [weak self] in self?.onInspect?(state) }
    }

    /// Long-press to relaunch the trajectory from the touched point and watch it
    /// get pulled back onto the attractor.
    @objc func handleLongPress(_ g: UILongPressGestureRecognizer) {
        guard g.state == .began,
              let view = g.view as? SCNView,
              let p = nearestTrailPoint(to: g.location(in: view), in: view) else { return }
        locked {
            engine.reseed(at: SIMD3<Double>(Double(p.x), Double(p.y), Double(p.z)))
            started = false   // shared with the render thread; reset under the lock
        }
        markerNode.isHidden = true
        Task { @MainActor [weak self] in self?.hud?.reset() }
    }

    /// The trail point nearest the ray cast through a screen location. Line
    /// geometry is effectively unpickable, so we unproject a ray and find the
    /// closest stored 3D point — exact, and trivial at tap frequency. Points
    /// behind the camera (t < 0 along the ray) are excluded so a tap can't snap
    /// to clipped, invisible geometry.
    private func nearestTrailPoint(to location: CGPoint, in view: SCNView) -> SIMD3<Float>? {
        let near = view.unprojectPoint(SCNVector3(Float(location.x), Float(location.y), 0))
        let far = view.unprojectPoint(SCNVector3(Float(location.x), Float(location.y), 1))
        let origin = SIMD3<Float>(near.x, near.y, near.z)
        let dir = simd_normalize(SIMD3<Float>(far.x - near.x, far.y - near.y, far.z - near.z))

        var best: SIMD3<Float>?
        var bestDist = Float.greatestFiniteMagnitude
        locked {
            engine.points3D.forEachOrdered { p in
                let v = p - origin
                let t = simd_dot(v, dir)
                guard t > 0 else { return }   // skip points behind the camera
                let closest = origin + dir * t
                let d = simd_length(p - closest)
                if d < bestDist { bestDist = d; best = p }
            }
        }
        return best
    }

    // MARK: - Gesture delegate

    /// Let the camera pan and pinch run together; discrete tap/long-press stay
    /// independent.
    func gestureRecognizer(_ g: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
        let cameraSet = [g, other].allSatisfy { $0 is UIPanGestureRecognizer || $0 is UIPinchGestureRecognizer }
        return cameraSet
    }

    // MARK: - Helpers

    static func rgb(hue: Double) -> SIMD3<Float> {
        let c = UIColor(hue: CGFloat(hue), saturation: 0.85, brightness: 1.0, alpha: 1)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        c.getRed(&r, green: &g, blue: &b, alpha: &a)
        return SIMD3<Float>(Float(r), Float(g), Float(b))
    }
}
