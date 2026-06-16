import SceneKit
import UIKit
import simd

/// Drives the 3D phase space: owns the engine, the SceneKit scene graph, the
/// arcball camera (custom, so it never fights the inspection gestures), and the
/// per-frame render loop. SwiftUI feeds it props through `apply(...)`.
final class PhaseSpaceCoordinator: NSObject, SCNSceneRendererDelegate {

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

    // Current props (compared to detect changes).
    private var config: AttractorConfig?
    private var hue: Double = 0.55
    private var glow: Bool = true
    private var sensitive: Bool = false

    // Clock.
    private var firstTime: TimeInterval = 0
    private var started = false
    private var framedOnce = false

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

        scene.rootNode.addChildNode(trail.node)
        scene.rootNode.addChildNode(companionTrail.node)
        scene.rootNode.addChildNode(headNode)
    }

    var pointOfView: SCNNode { cameraNode }

    // MARK: - Props from SwiftUI

    func apply(config: AttractorConfig, speed: Double, zoom: Double,
               hue: Double, glow: Bool, integrator: IntegratorKind,
               sensitive: Bool) {
        engine.speed = speed
        engine.zoom = zoom
        engine.integrator = integrator
        self.hue = hue
        self.glow = glow

        let configChanged = (self.config != config)
        let sensitivityChanged = (self.sensitive != sensitive)
        self.config = config
        self.sensitive = sensitive

        cameraNode.camera?.bloomIntensity = glow ? 1.4 : 0

        if configChanged || sensitivityChanged || !started {
            engine.tracksCompanion = sensitive
            engine.regenerate(width: 400, height: 400, config: config)
            companionTrail.clear()
            started = false
            framedOnce = false
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

    // MARK: - Helpers

    static func rgb(hue: Double) -> SIMD3<Float> {
        let c = UIColor(hue: CGFloat(hue), saturation: 0.85, brightness: 1.0, alpha: 1)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        c.getRed(&r, green: &g, blue: &b, alpha: &a)
        return SIMD3<Float>(Float(r), Float(g), Float(b))
    }
}
