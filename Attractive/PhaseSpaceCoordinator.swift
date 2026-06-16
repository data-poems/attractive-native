import SceneKit
import UIKit
import simd

/// Drives the 3D phase space: owns the engine, the SceneKit scene graph, the
/// arcball camera (custom, so it never fights the inspection gestures), and the
/// per-frame render loop. SwiftUI feeds it props through `apply(...)`.
final class PhaseSpaceCoordinator: NSObject, SCNSceneRendererDelegate, UIGestureRecognizerDelegate {

    let scene = SCNScene()
    private let engine = AttractiveEngine()

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
    private var framedOnce = false

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
        cam.bloomIntensity = 1.4
        cam.bloomBlurRadius = 12
        cam.bloomThreshold = 0.2
        cameraNode.camera = cam
        cameraNode.position = SCNVector3(0, 0, orbitRadius)
        cameraOrbit.addChildNode(cameraNode)
        scene.rootNode.addChildNode(cameraOrbit)

        let head = SCNSphere(radius: 0.6)
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
        engine.speed = speed
        engine.zoom = zoom
        engine.integrator = integrator
        self.hue = hue
        self.glow = glow

        let configChanged = (self.config != config)
        let sensitivityChanged = (self.sensitive != sensitive)
        let lyapunovChanged = (self.lyapunov != lyapunov)
        self.config = config
        self.sensitive = sensitive
        self.lyapunov = lyapunov

        cameraNode.camera?.bloomIntensity = glow ? 1.4 : 0

        if configChanged || sensitivityChanged || lyapunovChanged || !started {
            engine.tracksCompanion = sensitive
            engine.computesLyapunov = lyapunov
            engine.regenerate(width: 400, height: 400, config: config)
            companionTrail.clear()
            started = false
            framedOnce = false
            Task { @MainActor [weak self] in self?.hud?.reset() }
        }
        // Orbit radius responds to the zoom control.
        orbitRadius = baseRadius / max(0.2, CGFloat(zoom))
        cameraNode.position = SCNVector3(0, 0, orbitRadius)
    }

    // MARK: - Render loop

    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        if !started { started = true; firstTime = time }
        let elapsedMs = (time - firstTime) * 1000.0
        engine.advance(timeMs: elapsedMs)

        let rgb = Self.rgb(hue: hue)
        trail.update(points: engine.points3D, rgb: rgb)
        if sensitive {
            companionTrail.update(points: engine.companionPoints3D, rgb: Self.rgb(hue: (hue + 0.5).truncatingRemainder(dividingBy: 1)))
        }

        let s = engine.state
        headNode.position = SCNVector3(Float(s.x), Float(s.y), Float(s.z))

        // Throttled HUD telemetry (~10 Hz) — hop to the main actor.
        if (sensitive || lyapunov), time - lastHUDTime > 0.1 {
            lastHUDTime = time
            let sep = sensitive ? engine.separation : nil
            let lyap = lyapunov ? engine.lyapunov.current : nil
            let warm = engine.lyapunov.warm
            Task { @MainActor [weak self] in
                if let sep { self?.hud?.pushSeparation(sep) }
                if let lyap {
                    self?.hud?.lyapunov = lyap
                    self?.hud?.lyapunovWarm = warm
                }
            }
        }

        frameCameraIfNeeded()
    }

    /// Centre the orbit on the attractor and choose a pull-back distance from
    /// the trail's bounding box, once enough points exist.
    private func frameCameraIfNeeded() {
        guard !framedOnce, engine.points3D.count > 200 else { return }
        let lo = engine.boundsMin, hi = engine.boundsMax
        guard lo.x.isFinite, hi.x.isFinite else { return }
        let center = (lo + hi) * 0.5
        cameraOrbit.position = SCNVector3(center.x, center.y, center.z)
        let extent = simd_length(hi - lo)
        baseRadius = CGFloat(max(extent, 1)) * 1.4
        orbitRadius = baseRadius
        cameraNode.position = SCNVector3(0, 0, orbitRadius)
        framedOnce = true
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
        engine.reseed(at: SIMD3<Double>(Double(p.x), Double(p.y), Double(p.z)))
        markerNode.isHidden = true
        started = false
        framedOnce = false
        Task { @MainActor [weak self] in self?.hud?.reset() }
    }

    /// The trail point nearest the ray cast through a screen location. Line
    /// geometry is effectively unpickable, so we unproject a ray and find the
    /// closest stored 3D point — exact, and trivial at tap frequency.
    private func nearestTrailPoint(to location: CGPoint, in view: SCNView) -> SIMD3<Float>? {
        let near = view.unprojectPoint(SCNVector3(Float(location.x), Float(location.y), 0))
        let far = view.unprojectPoint(SCNVector3(Float(location.x), Float(location.y), 1))
        let origin = SIMD3<Float>(near.x, near.y, near.z)
        let dir = simd_normalize(SIMD3<Float>(far.x - near.x, far.y - near.y, far.z - near.z))

        var best: SIMD3<Float>?
        var bestDist = Float.greatestFiniteMagnitude
        engine.points3D.forEachOrdered { p in
            let v = p - origin
            let t = simd_dot(v, dir)
            let closest = origin + dir * t
            let d = simd_length(p - closest)
            if d < bestDist { bestDist = d; best = p }
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
