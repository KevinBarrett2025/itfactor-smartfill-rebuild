import SwiftUI
import SceneKit
import simd
import UIKit

// MARK: - In-memory persistence of spinner state
struct Spinner3DViewState: Codable {
    var orientationVector: SIMD4<Float>
    var coinScaleVector: SIMD3<Float>
    var orthoScale: Double

    init(orientation: simd_quatf, coinScale: SCNVector3, orthoScale: Double) {
        self.orientationVector = orientation.vector
        self.coinScaleVector = SIMD3<Float>(coinScale.x, coinScale.y, coinScale.z)
        self.orthoScale = orthoScale
    }

    var orientation: simd_quatf {
        simd_quatf(vector: orientationVector)
    }

    var coinScale: SCNVector3 {
        SCNVector3(coinScaleVector.x, coinScaleVector.y, coinScaleVector.z)
    }
}

final class Spinner3DViewStateStore {
    static let shared = Spinner3DViewStateStore()
    private var store: [String: Spinner3DViewState] = [:]
    private init() {}
    func state(for key: String) -> Spinner3DViewState? { store[key] }
    func set(_ state: Spinner3DViewState, for key: String) { store[key] = state }
    func removeState(for key: String) { store.removeValue(forKey: key) }
}

/// Configuration for optional "yo-yo" positional motion on the spinner coin.
public struct SpinnerYoYoConfig {
    public var isEnabled: Bool
    public var maxDepthOffset: CGFloat
    public var maxVerticalOffset: CGFloat
    public var flingVelocityThreshold: CGFloat
    public var springFrequency: CGFloat
    public var springDampingRatio: CGFloat

    public init(
        isEnabled: Bool = false,
        maxDepthOffset: CGFloat = 0.18,
        maxVerticalOffset: CGFloat = 0.20,
        flingVelocityThreshold: CGFloat = 600,
        springFrequency: CGFloat = 3.5,
        springDampingRatio: CGFloat = 0.65
    ) {
        self.isEnabled = isEnabled
        self.maxDepthOffset = maxDepthOffset
        self.maxVerticalOffset = maxVerticalOffset
        self.flingVelocityThreshold = flingVelocityThreshold
        self.springFrequency = springFrequency
        self.springDampingRatio = springDampingRatio
    }

    public static let disabled = SpinnerYoYoConfig(isEnabled: false)
    public static let `default` = SpinnerYoYoConfig(isEnabled: true)
}

// MARK: - Spinner3DView
public struct Spinner3DView: UIViewRepresentable {

    public enum Face { case logo, settings }
    public enum SpinMode { case free, lockedAxes }
    public enum CameraMode { case perspective, orthographic }
    public enum LightPreset { case studioSoft, classic, custom((SCNScene)->Void) }

    // MARK: Config
    public var modelName: String
    public var expectedRootName: String? = "Coin_Main"
    public var startFace: Face = .logo
    public var idleReturnFace: Face = .logo
    public var mode: SpinMode = .free
    public var cameraMode: CameraMode = .orthographic   // flatter badge by default
    public var spinSensitivity: CGFloat = 0.0055
    public var friction: CGFloat = 0.985
    public var clampPitchRadians: CGFloat = .pi * 0.47 // ~85° (ignored in legacy mode)
    public var idleTimeout: TimeInterval = 3.0
    public var fitPadding: CGFloat = 0.73        // modern fit padding
    public var respectBounds: Bool = true        // clip SceneKit view to SwiftUI frame
    public var maxSpinVelocity: CGFloat = 0.05   // cap for yaw/pitch accumulation
    public var spinPlaneLockBias: CGFloat = 1.35 // legacy bias preserved for compatibility
    public var horizontalSwipeLockRatio: CGFloat = 0.6 // ≥ ratio => treat gesture as horizontal spin
    public var verticalSwipeLockRatio: CGFloat = 0.6   // ≥ ratio => treat gesture as vertical spin
    public var spinPlaneLockDeadzone: CGFloat = 4      // ignore tiny drags when deciding plane
    public var spinPlaneAlignmentStrength: CGFloat = 0.18 // how fast we realign toward locked plane
    public var spinPlaneReleaseVelocity: CGFloat = 0.00035 // drop lock when velocities fall below

    // Legacy mode = original feel that worked best
    public var legacyCenteredMode: Bool = true
    public var legacyStaticFitPadding: CGFloat = 1.06  // one-time fit at load in legacy
    public var legacyZoom: CGFloat = 1.00              // >1 zooms in, <1 zooms out

    // Lighting
    public var lightPreset: LightPreset = .studioSoft
    public var envImageName: String? = nil
    public var flipDefaultFace: Bool = false
    
    /// Visual-effects configuration (glow thresholds, haptics, etc.).
    public var effectsConfig: SpinnerEffectsConfig = .default

    /// Positional yo-yo configuration.
    public var yoYoConfig: SpinnerYoYoConfig = .disabled

    // Persistence
    public var persistKey: String? = nil

    public init(modelName: String = "SpinnerCoin_v2",
                expectedRootName: String? = "Coin_Main",
                startFace: Face = .logo,
                idleReturnFace: Face = .logo,
                mode: SpinMode = .free,
                cameraMode: CameraMode = .orthographic,
                fitPadding: CGFloat = 0.82,
                respectBounds: Bool = true,
                legacyCenteredMode: Bool = true,
                legacyStaticFitPadding: CGFloat = 1.06,
                legacyZoom: CGFloat = 1.00,
                lightPreset: LightPreset = .studioSoft,
                envImageName: String? = nil,
                flipDefaultFace: Bool = false,
                persistKey: String? = nil,
                maxSpinVelocity: CGFloat = 0.05,
                spinPlaneLockBias: CGFloat = 1.35,
                horizontalSwipeLockRatio: CGFloat = 0.6,
                verticalSwipeLockRatio: CGFloat = 0.6,
                spinPlaneLockDeadzone: CGFloat = 4,
                spinPlaneAlignmentStrength: CGFloat = 0.18,
                spinPlaneReleaseVelocity: CGFloat = 0.00035,
                effectsConfig: SpinnerEffectsConfig = .default,
                yoYoConfig: SpinnerYoYoConfig = .disabled) {
        self.modelName = modelName
        self.expectedRootName = expectedRootName
        self.startFace = startFace
        self.idleReturnFace = idleReturnFace
        self.mode = mode
        self.cameraMode = cameraMode
        self.fitPadding = fitPadding
        self.respectBounds = respectBounds
        self.legacyCenteredMode = legacyCenteredMode
        self.legacyStaticFitPadding = legacyStaticFitPadding
        self.legacyZoom = legacyZoom
        self.lightPreset = lightPreset
        self.envImageName = envImageName
        self.flipDefaultFace = flipDefaultFace
        self.persistKey = persistKey
        self.maxSpinVelocity = maxSpinVelocity
        self.spinPlaneLockBias = spinPlaneLockBias
        self.horizontalSwipeLockRatio = horizontalSwipeLockRatio
        self.verticalSwipeLockRatio = verticalSwipeLockRatio
        self.spinPlaneLockDeadzone = spinPlaneLockDeadzone
        self.spinPlaneAlignmentStrength = spinPlaneAlignmentStrength
        self.spinPlaneReleaseVelocity = spinPlaneReleaseVelocity
        self.effectsConfig = effectsConfig
        self.yoYoConfig = yoYoConfig
    }

    public func makeUIView(context: Context) -> SCNView {
        let view = SCNView(frame: .zero)
        let scene = SCNScene()
        view.scene = scene
        view.backgroundColor = .clear
        view.preferredFramesPerSecond = 120
        view.antialiasingMode = .multisampling4X
        view.allowsCameraControl = false
        view.isUserInteractionEnabled = true
        view.isPlaying = true
        view.clipsToBounds = respectBounds && !legacyCenteredMode // legacy: allow slight bleed if needed
        view.translatesAutoresizingMaskIntoConstraints = false
        view.autoenablesDefaultLighting = false
        view.rendersContinuously = true

        // Camera
        let camNode = SCNNode()
        let camera = SCNCamera()
        camNode.camera = camera

        if legacyCenteredMode {
            camera.usesOrthographicProjection = true
            camera.orthographicScale = 1.0
            camera.zNear = 0.0001
            camera.zFar  = 1000
            camNode.position = SCNVector3(0, 0, 3)   // fixed distance
        } else {
            switch cameraMode {
            case .orthographic:
                camera.usesOrthographicProjection = true
                camera.orthographicScale = 1.0
                camera.zNear = 0.0001
                camera.zFar  = 1000
                camNode.position = SCNVector3(0, 0, 3)
            case .perspective:
                camera.usesOrthographicProjection = false
                camera.fieldOfView = 30
                camera.zNear = 0.01
                camera.zFar  = 1000
                camNode.position = SCNVector3(0, 0, 4.2)
            }
        }

        scene.rootNode.addChildNode(camNode)
        view.pointOfView = camNode

        // Light Rig
        applyLightPreset(lightPreset, to: scene)
        if let env = envImageName, let img = UIImage(named: env) {
            scene.lightingEnvironment.contents = img
            scene.lightingEnvironment.intensity = 0.6
        }

        // Model
        if let node = loadCoin(modelName: modelName, expectedRootName: expectedRootName) {
            forceMaterialStability(node)
            centerPivotAggregated(node)
            // autoOrientFlatObjectToFaceCamera(node) // disabled; alignFaceForward handles facing
            if flipDefaultFace {
                node.eulerAngles.y += .pi
            }

            scene.rootNode.addChildNode(node)
            context.coordinator.coinNode = node
            context.coordinator.basePosition = node.position
            context.coordinator.yoYoOffset = SCNVector3Zero
            context.coordinator.yoYoVelocity = SCNVector3Zero
            context.coordinator.setupAuraIfNeeded(on: node)

            // Initial orientation
            let baseQ = node.simdOrientation
            let startFaceQ = (startFace == .logo)
                ? simd_quatf(angle: 0, axis: SIMD3<Float>(0,1,0))
                : simd_quatf(angle: .pi, axis: SIMD3<Float>(0,1,0))
            context.coordinator.orientation = alignFaceForward(baseQ * startFaceQ)
            node.simdOrientation = context.coordinator.orientation

            // Restore or fit
            if let key = persistKey, let saved = Spinner3DViewStateStore.shared.state(for: key) {
                // ✅ Restore immediately
                node.scale = saved.coinScale
                node.simdOrientation = saved.orientation
                context.coordinator.orientation = saved.orientation
                if let cam = view.pointOfView?.camera, cam.usesOrthographicProjection {
                    cam.orthographicScale = saved.orthoScale
                }
            } else if legacyCenteredMode {
                // ✅ One-time normalize + fit + zoom, then persist
                staticNormalizeAndFit(node, in: view, padding: legacyStaticFitPadding, zoom: legacyZoom)
                persistStateIfNeeded(view: view, node: node)
            } else {
                // modern path: dynamic fit on load + on updates
                DispatchQueue.main.async { [weak view] in
                    guard let view = view else { return }
                    self.fitCoin(node, in: view, padding: self.fitPadding)
                    self.persistStateIfNeeded(view: view, node: node)
                }
            }
        }

        // Gestures
        let pan = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePan(_:)))
        pan.maximumNumberOfTouches = 1
        pan.cancelsTouchesInView = true
        view.addGestureRecognizer(pan)

        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        tap.cancelsTouchesInView = true
        view.addGestureRecognizer(tap)

        // Ticker
        context.coordinator.hostingView = view
        context.coordinator.displayLink = CADisplayLink(target: context.coordinator, selector: #selector(Coordinator.tick))
        context.coordinator.displayLink?.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 120, preferred: 120)
        context.coordinator.displayLink?.add(to: .main, forMode: .common)
        context.coordinator.parent = self

        // Listen for forced face requests (optional)
        NotificationCenter.default.addObserver(forName: .spinnerForceFace, object: nil, queue: .main) { note in
            guard let faceStr = note.userInfo?["face"] as? String, let coin = context.coordinator.coinNode else { return }
            let raw = (faceStr == "logo")
                ? simd_quatf(angle: 0, axis: SIMD3<Float>(0,1,0))
                : simd_quatf(angle: .pi, axis: SIMD3<Float>(0,1,0))
            let aligned = alignFaceForward(raw)
            context.coordinator.orientation = aligned
            coin.simdOrientation = aligned
            persistStateIfNeeded(view: view, node: coin)
        }

        return view
    }

    public func updateUIView(_ uiView: SCNView, context: Context) {
        if legacyCenteredMode { return } // legacy: do not refit/dolly each update
        if let coin = context.coordinator.coinNode {
            fitCoin(coin, in: uiView, padding: fitPadding)
            persistStateIfNeeded(view: uiView, node: coin)
        }
    }

    public static func dismantleUIView(_ uiView: SCNView, coordinator: Coordinator) {
        coordinator.displayLink?.invalidate()
    }

    public func makeCoordinator() -> Coordinator { Coordinator(self) }

    // Helpers
    private func loadCoin(modelName: String, expectedRootName: String? = "Coin_Main") -> SCNNode? {
        if let url = Bundle.main.url(forResource: modelName, withExtension: "usdz") {
            let ref = SCNReferenceNode(url: url); ref?.load()
            guard let loaded = ref else { return nil }
            let rootCandidate = (expectedRootName.flatMap { loaded.childNode(withName: $0, recursively: true) }) ?? loaded
            let container = SCNNode(); container.name = "SpinnerContainer"
            container.addChildNode(rootCandidate)
            return container
        }
        if let scene = SCNScene(named: "\(modelName).usdz") {
            let container = SCNNode()
            for child in scene.rootNode.childNodes { container.addChildNode(child) }
            return container
        }
        return nil
    }

    private func centerPivotAggregated(_ node: SCNNode) {
        var minV = SCNVector3Zero, maxV = SCNVector3Zero
        if node.__getBoundingBoxMin(&minV, max: &maxV) {
            let c = SCNVector3((minV.x+maxV.x)*0.5, (minV.y+maxV.y)*0.5, (minV.z+maxV.z)*0.5)
            node.pivot = SCNMatrix4MakeTranslation(c.x, c.y, c.z)
            node.position = SCNVector3Zero
        }
    }

    private func forceMaterialStability(_ node: SCNNode) {
        if let geo = node.geometry {
            for m in geo.materials {
                m.isDoubleSided = true
                m.readsFromDepthBuffer = true
                m.writesToDepthBuffer = true
                m.blendMode = .alpha
                m.transparencyMode = .aOne
                m.fresnelExponent = 0
                m.cullMode = .back
            }
        }
        for c in node.childNodes { forceMaterialStability(c) }
    }

    private func autoOrientFlatObjectToFaceCamera(_ node: SCNNode) {
        var minV = SCNVector3Zero, maxV = SCNVector3Zero
        guard node.__getBoundingBoxMin(&minV, max: &maxV) else { return }
        let sx = abs(maxV.x - minV.x)
        let sy = abs(maxV.y - minV.y)
        let sz = abs(maxV.z - minV.z)
        if sx <= sy && sx <= sz { node.eulerAngles.y += .pi / 2 }
        else if sy <= sx && sy <= sz { node.eulerAngles.x -= .pi / 2 }
    }

    private func boundingSphere(for node: SCNNode) -> (center: SCNVector3, radius: Float) {
        var minV = SCNVector3Zero, maxV = SCNVector3Zero
        var hasBox = node.__getBoundingBoxMin(&minV, max: &maxV)
        
        if !hasBox {
            var aggMin = SCNVector3(Float.greatestFiniteMagnitude,
                                    Float.greatestFiniteMagnitude,
                                    Float.greatestFiniteMagnitude)
            var aggMax = SCNVector3(-Float.greatestFiniteMagnitude,
                                    -Float.greatestFiniteMagnitude,
                                    -Float.greatestFiniteMagnitude)
            node.enumerateChildNodes { child, _ in
                var cmin = SCNVector3Zero, cmax = SCNVector3Zero
                if child.__getBoundingBoxMin(&cmin, max: &cmax) {
                    aggMin.x = min(aggMin.x, cmin.x); aggMin.y = min(aggMin.y, cmin.y); aggMin.z = min(aggMin.z, cmin.z)
                    aggMax.x = max(aggMax.x, cmax.x); aggMax.y = max(aggMax.y, cmax.y); aggMax.z = max(aggMax.z, cmax.z)
                    hasBox = true
                }
            }
            if hasBox { minV = aggMin; maxV = aggMax } else { return (SCNVector3Zero, 0) }
        }
        
        let center = SCNVector3((minV.x+maxV.x)*0.5, (minV.y+maxV.y)*0.5, (minV.z+maxV.z)*0.5)
        let dx = maxV.x - minV.x
        let dy = maxV.y - minV.y
        let dz = maxV.z - minV.z
        let radius = 0.5 * sqrtf(dx*dx + dy*dy + dz*dz)
        return (center, radius)
    }

    private func alignFaceForward(_ q: simd_quatf) -> simd_quatf {
        let e = spinnerEulerAngles(q)
        return simd_quatf(eulerXYZ: SIMD3<Float>(0, e.y, 0))
    }
    
    private var baseFaceQuaternion: simd_quatf {
        alignFaceForward(simd_quatf(angle: 0, axis: SIMD3<Float>(0,1,0)))
    }
    
    private var baseFaceEulerAngles: SIMD3<Float> {
        spinnerEulerAngles(baseFaceQuaternion)
    }

    private func spinnerEulerAngles(_ q: simd_quatf) -> SIMD3<Float> {
        let m = simd_float3x3(q)
        let sy = -asin(max(-1, min(1, m[2,0])))
        let cy = cos(sy)
        let x = atan2(m[2,1]/cy, m[2,2]/cy)
        let y = sy
        let z = atan2(m[1,0]/cy, m[0,0]/cy)
        return SIMD3<Float>(x,y,z)
    }
    
    private func realign(_ q: simd_quatf, toward plane: Coordinator.SpinPlane, strength: Float) -> simd_quatf {
        guard strength > 0, plane != .free else { return q }
        let base = baseFaceQuaternion
        let baseInv = simd_inverse(base)
        let relative = baseInv * q
        var relativeAngles = spinnerEulerAngles(relative)
        switch plane {
        case .horizontal:
            relativeAngles.x = 0
            relativeAngles.z = 0
        case .vertical:
            relativeAngles.y = 0
            relativeAngles.z = 0
        case .free:
            return q
        }
        let targetRelative = simd_quatf(eulerXYZ: relativeAngles)
        let target = base * targetRelative
        let clampedStrength = max(0, min(1, strength))
        return simd_slerp(q, target, clampedStrength)
    }

    /// Non-legacy sizing helper (legacy mode bypasses this)
    private func fitCoin(_ coin: SCNNode, in view: SCNView, padding: CGFloat? = nil) {
        let pad = padding ?? fitPadding
        let sphere = boundingSphere(for: coin)
        guard sphere.radius.isFinite, sphere.radius > 0 else { return }
        
        coin.position = SCNVector3Zero
        guard let camNode = view.pointOfView, let cam = camNode.camera else { return }
        let targetRadius = CGFloat(sphere.radius) * pad
        
        if cam.usesOrthographicProjection {
            cam.orthographicScale = Double(targetRadius)
            camNode.position = SCNVector3(camNode.position.x, camNode.position.y, max(3, camNode.position.z))
        } else {
            let fovY = CGFloat(cam.fieldOfView) * (.pi / 180)
            let distance = targetRadius / tan(fovY * 0.5)
            camNode.position = SCNVector3(0, 0, Float(max(0.01, distance)))
        }
    }

    /// Legacy one-time normalization: scale coin to unit radius and set ortho scale and zoom
    private func staticNormalizeAndFit(_ coin: SCNNode, in view: SCNView, padding: CGFloat, zoom: CGFloat) {
        let s = boundingSphere(for: coin)
        guard s.radius.isFinite, s.radius > 0 else { return }
        let unit: CGFloat = 1.0
        let scale = unit / CGFloat(s.radius)
        coin.scale = SCNVector3(Float(scale), Float(scale), Float(scale))
        coin.position = SCNVector3Zero

        if let cam = view.pointOfView?.camera, cam.usesOrthographicProjection {
            cam.orthographicScale = Double(unit * padding / max(0.01, zoom))
        }
    }

    private func persistStateIfNeeded(view: SCNView, node: SCNNode) {
        guard let key = persistKey else { return }
        let ortho = view.pointOfView?.camera?.orthographicScale ?? 1.0
        let state = Spinner3DViewState(orientation: node.simdOrientation, coinScale: node.scale, orthoScale: ortho)
        Spinner3DViewStateStore.shared.set(state, for: key)
    }

    private func applyLightPreset(_ preset: LightPreset, to scene: SCNScene) {
        func classic() {
            let key = SCNNode(); key.light = SCNLight(); key.light?.type = .directional; key.light?.intensity = 900; key.eulerAngles = SCNVector3(-0.5, 0.6, 0.0); scene.rootNode.addChildNode(key)
            let fill = SCNNode(); fill.light = SCNLight(); fill.light?.type = .omni; fill.light?.intensity = 520; fill.position = SCNVector3(0.0, 0.3, 2.0); scene.rootNode.addChildNode(fill)
            let amb = SCNNode(); amb.light = SCNLight(); amb.light?.type = .ambient; amb.light?.intensity = 220; scene.rootNode.addChildNode(amb)
        }
        func studioSoft() {
            let key = SCNNode(); key.light = SCNLight(); key.light?.type = .directional; key.light?.intensity = 520; key.light?.castsShadow = false; key.eulerAngles = SCNVector3(-0.45, 0.85, 0.0); scene.rootNode.addChildNode(key)
            let fill = SCNNode(); fill.light = SCNLight(); fill.light?.type = .omni; fill.light?.intensity = 140; fill.position = SCNVector3(-0.6, 0.2, 1.8); scene.rootNode.addChildNode(fill)
            let rim = SCNNode(); rim.light = SCNLight(); rim.light?.type = .directional; rim.light?.intensity = 380; rim.eulerAngles = SCNVector3(0.35, -2.7, 0.0); scene.rootNode.addChildNode(rim)
            let amb = SCNNode(); amb.light = SCNLight(); amb.light?.type = .ambient; amb.light?.intensity = 120; scene.rootNode.addChildNode(amb)
        }
        switch preset {
        case .classic: classic()
        case .studioSoft: studioSoft()
        case .custom(let block): block(scene)
        }
    }

    // MARK: Coordinator
    public final class Coordinator: NSObject {
        var parent: Spinner3DView
        let effects: SpinnerEffects
        init(_ parent: Spinner3DView) {
            self.parent = parent
            self.effects = SpinnerEffects(config: parent.effectsConfig)
        }

        weak var coinNode: SCNNode?
        weak var hostingView: SCNView?
        var displayLink: CADisplayLink?

        enum State { case idle, playing, flippingToSettings, flippingToLogo }
        var state: State = .idle
        enum SpinPlane { case free, horizontal, vertical }
        var spinPlane: SpinPlane = .free

        var orientation = simd_quatf(angle: 0, axis: SIMD3<Float>(0,1,0))
        var yawVelocity: CGFloat = 0
        var pitchVelocity: CGFloat = 0
        var lastInteraction: TimeInterval = CACurrentMediaTime()
        var basePosition: SCNVector3 = SCNVector3Zero
        var yoYoOffset: SCNVector3 = SCNVector3Zero
        var yoYoVelocity: SCNVector3 = SCNVector3Zero
        var lastTickTime: CFTimeInterval?
        var auraSystem: SCNParticleSystem?
        weak var auraNode: SCNNode?

        @objc func handleTap(_ recognizer: UITapGestureRecognizer) {
            guard let _ = coinNode else { return }
            let e = parent.spinnerEulerAngles(orientation)
            let isLogo = abs(normalizeAngle(e.y)) < (.pi/2)
            if isLogo { state = .flippingToSettings; flipTo(face: .settings, thenFly: true) }
            else      { state = .flippingToLogo;     flipTo(face: .logo,     thenFly: false) }
        }

        @objc func handlePan(_ recognizer: UIPanGestureRecognizer) {
            guard let view = recognizer.view as? SCNView, let node = coinNode else { return }
            if recognizer.state == .began {
                lastInteraction = CACurrentMediaTime()
                return
            }
            switch recognizer.state {
            case .ended, .cancelled, .failed:
                if parent.yoYoConfig.isEnabled {
                    let velocity = recognizer.velocity(in: view)
                    triggerYoYoIfNeeded(velocity: velocity)
                }
                return
            default:
                break
            }

            let p = recognizer.translation(in: view)
            recognizer.setTranslation(.zero, in: view)
            lastInteraction = CACurrentMediaTime()

            var rawYaw   = Float(p.x) * Float(parent.spinSensitivity)
            var rawPitch = Float(p.y) * Float(parent.spinSensitivity)

            let absX = abs(p.x)
            let absY = abs(p.y)
            let magnitude = absX + absY
            var lockedThisFrame = false

            if magnitude > parent.spinPlaneLockDeadzone {
                let horizontalRatio = magnitude == 0 ? 0 : absX / magnitude
                let verticalRatio = magnitude == 0 ? 0 : absY / magnitude
                if horizontalRatio >= parent.horizontalSwipeLockRatio {
                    spinPlane = .horizontal
                    rawPitch = 0
                    lockedThisFrame = true
                } else if verticalRatio >= parent.verticalSwipeLockRatio {
                    spinPlane = .vertical
                    rawYaw = 0
                    lockedThisFrame = true
                }
            }

            if !lockedThisFrame {
                let bias = parent.spinPlaneLockBias
                if spinPlane == .horizontal && absY > absX * bias {
                    spinPlane = .vertical
                    rawYaw = 0
                    lockedThisFrame = true
                } else if spinPlane == .vertical && absX > absY * bias {
                    spinPlane = .horizontal
                    rawPitch = 0
                    lockedThisFrame = true
                }
            }

            if !lockedThisFrame {
                switch spinPlane {
                case .horizontal:
                    rawPitch *= 0.15
                case .vertical:
                    rawYaw *= 0.15
                case .free:
                    rawPitch *= 0.45
                    rawYaw *= 0.45
                }
            }

            func accumulate(_ current: inout CGFloat, delta: CGFloat) {
                if current * delta < 0 {
                    current *= 0.55 // braking when user swipes opposite direction
                }
                let newValue = current + delta
                let limit = parent.maxSpinVelocity
                current = max(-limit, min(limit, newValue))
            }

            if parent.legacyCenteredMode {
                // Legacy: unconstrained spin, no clamping
                let qYaw   = simd_quatf(angle: rawYaw,   axis: SIMD3<Float>(0,1,0))
                let qPitch = simd_quatf(angle: rawPitch, axis: SIMD3<Float>(1,0,0))
                orientation = qYaw * orientation * qPitch
                node.simdOrientation = orientation
                accumulate(&yawVelocity, delta: CGFloat(rawYaw))
                accumulate(&pitchVelocity, delta: CGFloat(rawPitch))
            } else if parent.mode == .lockedAxes {
                if abs(p.x) >= abs(p.y) {
                    let qYaw = simd_quatf(angle: rawYaw, axis: SIMD3<Float>(0,1,0))
                    orientation = qYaw * orientation
                    node.simdOrientation = orientation
                    accumulate(&yawVelocity, delta: CGFloat(rawYaw))
                    pitchVelocity = 0
                } else {
                    let qPitch = simd_quatf(angle: rawPitch, axis: SIMD3<Float>(1,0,0))
                    orientation = orientation * qPitch
                    orientation = clampPitch(orientation, limit: Float(parent.clampPitchRadians))
                    node.simdOrientation = orientation
                    yawVelocity = 0
                    accumulate(&pitchVelocity, delta: CGFloat(rawPitch))
                }
            } else {
                let qYaw   = simd_quatf(angle: rawYaw,   axis: SIMD3<Float>(0,1,0))
                let qPitch = simd_quatf(angle: rawPitch, axis: SIMD3<Float>(1,0,0))
                orientation = qYaw * orientation * qPitch
                orientation = clampPitch(orientation, limit: Float(parent.clampPitchRadians))
                node.simdOrientation = orientation
                accumulate(&yawVelocity, delta: CGFloat(rawYaw))
                accumulate(&pitchVelocity, delta: CGFloat(rawPitch))
            }
            state = .playing
        }

        @objc func tick() {
            guard let node = coinNode else { return }
            let now = CACurrentMediaTime()
            let dt: CFTimeInterval
            if let last = lastTickTime {
                dt = max(1.0 / 240.0, min(now - last, 1.0 / 20.0))
            } else {
                dt = 1.0 / 60.0
            }
            lastTickTime = now
            var auraSpinMagnitude: CGFloat = 0

            switch state {
            case .idle:
                node.simdOrientation = orientation

            case .playing:
                var yv = yawVelocity, pv = pitchVelocity
                if abs(yv) > 0.00001 || abs(pv) > 0.00001 {
                    if spinPlane == .horizontal && abs(pv) > abs(yv) * 0.35 {
                        pv *= 0.9
                        pitchVelocity = pv
                    } else if spinPlane == .vertical && abs(yv) > abs(pv) * 0.35 {
                        yv *= 0.9
                        yawVelocity = yv
                    }
                    let qYaw   = simd_quatf(angle: Float(yv), axis: SIMD3<Float>(0,1,0))
                    let qPitch = simd_quatf(angle: Float(pv), axis: SIMD3<Float>(1,0,0))
                    if parent.legacyCenteredMode {
                        orientation = qYaw * orientation * qPitch          // no clamp
                    } else {
                        orientation = qYaw * orientation * qPitch
                        orientation = clampPitch(orientation, limit: Float(parent.clampPitchRadians))
                    }
                    orientation = parent.realign(orientation,
                                                  toward: spinPlane,
                                                  strength: Float(parent.spinPlaneAlignmentStrength))
                    node.simdOrientation = orientation
                    yawVelocity *= parent.friction
                    pitchVelocity *= parent.friction
                    let spinMagnitude = sqrt(yawVelocity * yawVelocity + pitchVelocity * pitchVelocity)
                    effects.evaluateSpinMagnitude(spinMagnitude, on: node)
                    auraSpinMagnitude = spinMagnitude
                    if spinPlane != .free &&
                        abs(yawVelocity) < parent.spinPlaneReleaseVelocity &&
                        abs(pitchVelocity) < parent.spinPlaneReleaseVelocity {
                        spinPlane = .free
                    }
                    if let host = hostingView {
                        parent.persistStateIfNeeded(view: host, node: node)
                    }
                } else if now - lastInteraction > parent.idleTimeout {
                    flipTo(face: parent.idleReturnFace, thenFly: false)
                    state = .idle
                }

            case .flippingToSettings, .flippingToLogo:
                break
            }

            updateAuraIntensity(for: auraSpinMagnitude)

            if parent.yoYoConfig.isEnabled {
                updateYoYoPosition(node: node, dt: dt)
            } else {
                node.position = basePosition
                yoYoOffset = SCNVector3Zero
                yoYoVelocity = SCNVector3Zero
            }
        }

        func updateYoYoPosition(node: SCNNode, dt: CFTimeInterval) {
            let cfg = parent.yoYoConfig
            guard cfg.isEnabled else {
                node.position = basePosition
                return
            }

            let frequency = max(0.1, cfg.springFrequency)
            let omega = 2.0 * Double.pi * Double(frequency)
            let damping = Double(cfg.springDampingRatio)
            let k = omega * omega
            let c = 2.0 * damping * omega

            func integrate(_ x: Float, _ v: Float) -> (Float, Float) {
                let xD = Double(x)
                let vD = Double(v)
                let a = -k * xD - c * vD
                let vNext = vD + a * dt
                let xNext = xD + vNext * dt
                return (Float(xNext), Float(vNext))
            }

            var offsetY = yoYoOffset.y
            var velY = yoYoVelocity.y
            (offsetY, velY) = integrate(offsetY, velY)

            var offsetZ = yoYoOffset.z
            var velZ = yoYoVelocity.z
            (offsetZ, velZ) = integrate(offsetZ, velZ)

            let maxY = Float(cfg.maxVerticalOffset)
            let maxZ = Float(cfg.maxDepthOffset)
            offsetY = max(-maxY, min(maxY, offsetY))
            offsetZ = max(-maxZ, min(maxZ, offsetZ))

            yoYoOffset = SCNVector3(0, offsetY, offsetZ)
            yoYoVelocity = SCNVector3(0, velY, velZ)

            node.position = SCNVector3(
                basePosition.x,
                basePosition.y + yoYoOffset.y,
                basePosition.z + yoYoOffset.z
            )
        }

        func triggerYoYoIfNeeded(velocity: CGPoint) {
            let cfg = parent.yoYoConfig
            guard cfg.isEnabled else { return }

            let speed = hypot(velocity.x, velocity.y)
            guard speed >= cfg.flingVelocityThreshold else { return }

            let absX = abs(velocity.x)
            let absY = abs(velocity.y)
            let maxScale = cfg.flingVelocityThreshold * 2.5
            let normalized = min(1.0, speed / maxScale)

            if absY >= absX {
                let direction: CGFloat = velocity.y < 0 ? -1 : 1
                let impulse = Float(direction * cfg.maxVerticalOffset * 3.0 * normalized)
                yoYoVelocity.y += impulse
            } else {
                let direction: CGFloat = velocity.y < 0 ? -1 : 1
                let impulse = Float(direction * cfg.maxDepthOffset * 3.5 * normalized)
                yoYoVelocity.z += impulse
            }
        }

        func setupAuraIfNeeded(on node: SCNNode) {
            if auraNode === node, auraSystem != nil { return }
            let aura = SCNParticleSystem(named: "SpinnerAura.scnp", inDirectory: nil) ?? makeDefaultAuraSystem()
            auraSystem = aura
            node.addParticleSystem(aura)
            auraNode = node
            updateAuraIntensity(for: 0)
        }

        private static let auraSprite: UIImage = {
            let size = CGSize(width: 18, height: 18)
            let renderer = UIGraphicsImageRenderer(size: size)
            return renderer.image { context in
                let gradientColors: [CGColor] = [
                    UIColor(displayP3Red: 1.0, green: 0.52, blue: 0.94, alpha: 0.95).cgColor,
                    UIColor(displayP3Red: 0.35, green: 0.43, blue: 1.0, alpha: 0.0).cgColor
                ]
                let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                          colors: gradientColors as CFArray,
                                          locations: [0, 1])!
                context.cgContext.drawRadialGradient(
                    gradient,
                    startCenter: CGPoint(x: size.width / 2, y: size.height / 2),
                    startRadius: 0,
                    endCenter: CGPoint(x: size.width / 2, y: size.height / 2),
                    endRadius: size.width / 2,
                    options: .drawsAfterEndLocation
                )
            }
        }()

        private func makeDefaultAuraSystem() -> SCNParticleSystem {
            let aura = SCNParticleSystem()
            aura.birthRate = 140
            aura.particleLifeSpan = 1.4
            aura.particleLifeSpanVariation = 0.4
            aura.loops = true
            aura.particleSize = 0.018
            aura.particleSizeVariation = 0.01
            aura.spreadingAngle = 65
            aura.particleVelocity = 0.5
            aura.particleVelocityVariation = 0.3
            aura.emissionDuration = 0
            aura.emitterShape = SCNTorus(ringRadius: 1.05, pipeRadius: 0.14)
            aura.particleColor = UIColor(displayP3Red: 0.96, green: 0.35, blue: 0.95, alpha: 0.55)
            aura.particleColorVariation = SCNVector4(0.1, 0.2, 0.1, 0.25)
            aura.blendMode = .additive
            aura.particleImage = Self.auraSprite
            return aura
        }

        private func updateAuraIntensity(for spinMagnitude: CGFloat) {
            guard let aura = auraSystem else { return }
            let normalized = min(1.0, max(0.0, spinMagnitude * 18.0))
            let minRate: CGFloat = 45
            let maxRate: CGFloat = 520
            aura.birthRate = minRate + (maxRate - minRate) * normalized
            aura.particleSize = 0.012 + 0.05 * normalized
            aura.particleVelocity = 0.35 + 1.4 * normalized
            aura.particleColor = UIColor(
                displayP3Red: 0.96,
                green: 0.36 + 0.35 * normalized,
                blue: 0.98,
                alpha: 0.3 + 0.5 * normalized
            )
        }

        func flipTo(face: Spinner3DView.Face, thenFly: Bool) {
            guard let node = coinNode else { return }
            let rawTarget = (face == .logo)
                ? simd_quatf(angle: 0, axis: SIMD3<Float>(0,1,0))
                : simd_quatf(angle: .pi, axis: SIMD3<Float>(0,1,0))
            let target = parent.alignFaceForward(rawTarget)

            let start = orientation
            let duration: CFTimeInterval = 0.35
            let startTime = CACurrentMediaTime()

            func step() {
                let t = min(1.0, (CACurrentMediaTime() - startTime)/duration)
                let q = simd_slerp(start, target, Float(t))
                node.simdOrientation = q
                if t < 1.0 { DispatchQueue.main.async { step() } }
                else {
                    orientation = target
                    if thenFly { flyForwardToSettings(node: node) }
                    state = .idle
                }
            }
            step()
        }

        func flyForwardToSettings(node: SCNNode) {
            let scaleUp = SCNAction.scale(to: 1.35, duration: 0.22)
            scaleUp.timingMode = .easeInEaseOut
            let fade = SCNAction.fadeOpacity(to: 0.0, duration: 0.22)
            let group = SCNAction.group([scaleUp, fade])
            node.runAction(group) {
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .spinnerOpenSettings, object: nil)
                    node.opacity = 1.0
                    node.scale = SCNVector3(1,1,1)
                }
            }
        }

        // Utilities
        func clampPitch(_ q: simd_quatf, limit: Float) -> simd_quatf {
            if parent.legacyCenteredMode { return q } // no clamp in legacy
            let e = parent.spinnerEulerAngles(q)
            let clampedX = max(-limit, min(limit, e.x))
            return simd_quatf(eulerXYZ: SIMD3<Float>(clampedX, e.y, 0)) // zero roll
        }
        func normalizeAngle(_ a: Float) -> Float {
            var v = fmod(a + .pi, 2 * .pi)
            if v < 0 { v += 2 * .pi }
            return v - .pi
        }
    }
}

// MARK: - Notifications
extension Notification.Name {
    static let spinnerOpenSettings = Notification.Name("spinner.open.settings")
    static let spinnerCloseSettings = Notification.Name("spinner.close.settings")
    static let spinnerForceFace = Notification.Name("spinner.force.face")
}

// MARK: - Helpers
private extension simd_quatf {
    init(eulerXYZ angles: SIMD3<Float>) {
        let qx = simd_quatf(angle: angles.x, axis: SIMD3<Float>(1, 0, 0))
        let qy = simd_quatf(angle: angles.y, axis: SIMD3<Float>(0, 1, 0))
        let qz = simd_quatf(angle: angles.z, axis: SIMD3<Float>(0, 0, 1))
        self = qx * qy * qz
    }
}
