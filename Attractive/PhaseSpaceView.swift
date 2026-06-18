import SwiftUI
import SceneKit

/// SwiftUI host for the 3D phase space. Mirrors `AttractiveCanvas`'s prop list
/// so `ContentView` can swap between them. The render loop lives in the
/// coordinator (SceneKit's own display link); no `TimelineView` here.
struct PhaseSpaceView: UIViewRepresentable {
    let config: AttractorConfig
    let speed: Double
    let zoom: Double
    let hue: Double
    let glow: Bool
    let integrator: IntegratorKind
    let sensitive: Bool
    let lyapunov: Bool
    var hud: PhaseHUDModel? = nil
    var onInspect: ((SIMD3<Double>) -> Void)? = nil

    func makeCoordinator() -> PhaseSpaceCoordinator {
        PhaseSpaceCoordinator()
    }

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        let coord = context.coordinator
        view.scene = coord.scene
        view.delegate = coord
        view.pointOfView = coord.pointOfView
        view.backgroundColor = .black
        view.isPlaying = true
        view.rendersContinuously = true
        view.preferredFramesPerSecond = 0   // let SceneKit pick (120 on ProMotion)
        view.antialiasingMode = .multisampling4X
        coord.onInspect = onInspect
        coord.hud = hud

        let pan = UIPanGestureRecognizer(target: coord, action: #selector(PhaseSpaceCoordinator.handlePan(_:)))
        let pinch = UIPinchGestureRecognizer(target: coord, action: #selector(PhaseSpaceCoordinator.handlePinch(_:)))
        let tap = UITapGestureRecognizer(target: coord, action: #selector(PhaseSpaceCoordinator.handleTap(_:)))
        let longPress = UILongPressGestureRecognizer(target: coord, action: #selector(PhaseSpaceCoordinator.handleLongPress(_:)))
        longPress.minimumPressDuration = 0.45
        for g in [pan, pinch, tap, longPress] { g.delegate = coord }
        // A tap should only fire if it wasn't the start of a long-press.
        tap.require(toFail: longPress)
        view.addGestureRecognizer(pan)
        view.addGestureRecognizer(pinch)
        view.addGestureRecognizer(tap)
        view.addGestureRecognizer(longPress)

        coord.apply(config: config, speed: speed, zoom: zoom, hue: hue,
                    glow: glow, integrator: integrator, sensitive: sensitive,
                    lyapunov: lyapunov)
        return view
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        context.coordinator.onInspect = onInspect
        context.coordinator.apply(config: config, speed: speed, zoom: zoom,
                                  hue: hue, glow: glow, integrator: integrator,
                                  sensitive: sensitive, lyapunov: lyapunov)
    }
}
