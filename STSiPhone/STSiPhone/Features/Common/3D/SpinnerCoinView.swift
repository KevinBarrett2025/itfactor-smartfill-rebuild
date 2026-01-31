//
//  SpinnerCoinView.swift
//  STSiPhone
//
//  Personalized spinner coin with robust placeholder detection:
//  - Tries node/geometry name "UserPhotoPlaceholder"
//  - Falls back to material name "UserPhotoPlaceholderMat"
//  - Drag-to-spin inertia, tap callback, Reduce Motion safe
//

import SwiftUI
import SceneKit
import UIKit

struct SpinnerCoinPreset: Identifiable, Equatable {
    let id: String
    let name: String
    let description: String
    let rotationAxis: SCNVector3
    let dragRotationMultiplier: CGFloat
    let dragVelocityMultiplier: CGFloat
    let friction: CGFloat
    let maxVelocity: CGFloat
    let settleThreshold: CGFloat
    let unlimitedVelocity: Bool
    let axisJitter: SCNVector3
    let axisJitterSpeed: CGFloat
    let prefersVerticalRest: Bool
    let idleAutoSpinVelocity: CGFloat?

    static let `default` = SpinnerCoinPreset(
        id: "default",
        name: "Default",
        description: "Current production tuning",
        rotationAxis: SCNVector3(0, 1, 0),
        dragRotationMultiplier: 0.01,
        dragVelocityMultiplier: 0.04,
        friction: 0.97,
        maxVelocity: 6.0,
        settleThreshold: 0.18,
        unlimitedVelocity: false,
        axisJitter: SCNVector3(0, 0, 0),
        axisJitterSpeed: 0,
        prefersVerticalRest: true,
        idleAutoSpinVelocity: nil
    )

    static let topSpin = SpinnerCoinPreset(
        id: "top_spin",
        name: "Top Spin",
        description: "Centered wobble with lighter friction",
        rotationAxis: SCNVector3(0.08, 1.0, 0.02),
        dragRotationMultiplier: 0.012,
        dragVelocityMultiplier: 0.05,
        friction: 0.965,
        maxVelocity: 7.5,
        settleThreshold: 0.14,
        unlimitedVelocity: false,
        axisJitter: SCNVector3(0.04, 0.12, 0.02),
        axisJitterSpeed: 0.5,
        prefersVerticalRest: true,
        idleAutoSpinVelocity: nil
    )

    static let freeSpin = SpinnerCoinPreset(
        id: "free_spin",
        name: "Free Spin",
        description: "Low-friction drift with long coast",
        rotationAxis: SCNVector3(0.06, 1.0, 0.08),
        dragRotationMultiplier: 0.015,
        dragVelocityMultiplier: 0.06,
        friction: 0.99,
        maxVelocity: 9.5,
        settleThreshold: 0.1,
        unlimitedVelocity: false,
        axisJitter: SCNVector3(0.08, 0.18, 0.12),
        axisJitterSpeed: 0.9,
        prefersVerticalRest: true,
        idleAutoSpinVelocity: nil
    )

    static let flip = SpinnerCoinPreset(
        id: "flip",
        name: "Flip",
        description: "End-over-end coin flip motion",
        rotationAxis: SCNVector3(1.0, 0.08, 0.04),
        dragRotationMultiplier: 0.016,
        dragVelocityMultiplier: 0.065,
        friction: 0.965,
        maxVelocity: 12.0,
        settleThreshold: 0.14,
        unlimitedVelocity: true,
        axisJitter: SCNVector3(0.22, 0.05, 0.1),
        axisJitterSpeed: 0.7,
        prefersVerticalRest: false,
        idleAutoSpinVelocity: nil
    )

    static let wacky = SpinnerCoinPreset(
        id: "wacky",
        name: "Wacky",
        description: "Chaotic axis drift with playful wobble",
        rotationAxis: SCNVector3(0.35, 0.9, 0.4),
        dragRotationMultiplier: 0.018,
        dragVelocityMultiplier: 0.07,
        friction: 0.982,
        maxVelocity: 10.5,
        settleThreshold: 0.2,
        unlimitedVelocity: false,
        axisJitter: SCNVector3(0.45, 0.4, 0.5),
        axisJitterSpeed: 1.4,
        prefersVerticalRest: false,
        idleAutoSpinVelocity: nil
    )

    static let ludicrous = SpinnerCoinPreset(
        id: "ludicrous",
        name: "Ludicrous",
        description: "No brakes. Swipe forever.",
        rotationAxis: SCNVector3(0.02, 1.0, 0.02),
        dragRotationMultiplier: 0.02,
        dragVelocityMultiplier: 0.09,
        friction: 0.998,
        maxVelocity: 25.0,
        settleThreshold: 0.02,
        unlimitedVelocity: true,
        axisJitter: SCNVector3(0.12, 0.18, 0.12),
        axisJitterSpeed: 1.2,
        prefersVerticalRest: false,
        idleAutoSpinVelocity: nil
    )

    static let turnstile = SpinnerCoinPreset(
        id: "turnstile",
        name: "Turnstile",
        description: "Slow retail showcase spin",
        rotationAxis: SCNVector3(0.0, 1.0, 0.0),
        dragRotationMultiplier: 0.004,
        dragVelocityMultiplier: 0.02,
        friction: 0.995,
        maxVelocity: 2.5,
        settleThreshold: 0.05,
        unlimitedVelocity: false,
        axisJitter: SCNVector3(0.01, 0.02, 0.01),
        axisJitterSpeed: 0.1,
        prefersVerticalRest: true,
        idleAutoSpinVelocity: 0.75
    )

    static let allPresets: [SpinnerCoinPreset] = [.default, .topSpin, .freeSpin, .turnstile, .flip, .wacky, .ludicrous]

    static func preset(for id: String) -> SpinnerCoinPreset {
        allPresets.first(where: { $0.id == id }) ?? .default
    }

    static func == (lhs: SpinnerCoinPreset, rhs: SpinnerCoinPreset) -> Bool {
        lhs.id == rhs.id
    }

    var normalizedAxis: SCNVector3 {
        rotationAxis.normalized()
    }
}

struct SpinnerCoinTuning: Equatable {
    var acceleration: CGFloat
    var glow: CGFloat
    var haptics: CGFloat
    var sparks: CGFloat
    var sparkSpread: CGFloat
    var glowEnabled: Bool
    var hapticsEnabled: Bool
    var sparksEnabled: Bool

    static let `default` = SpinnerCoinTuning(acceleration: 1.0,
                                             glow: 0.35,
                                             haptics: 0.5,
                                             sparks: 0.5,
                                             sparkSpread: 0.6,
                                             glowEnabled: true,
                                             hapticsEnabled: true,
                                             sparksEnabled: true)

    func clamped() -> SpinnerCoinTuning {
        SpinnerCoinTuning(
            acceleration: max(0.5, min(1.7, acceleration)),
            glow: max(0, min(1, glow)),
            haptics: max(0, min(1, haptics)),
            sparks: max(0, min(1, sparks)),
            sparkSpread: max(0, min(1, sparkSpread)),
            glowEnabled: glowEnabled,
            hapticsEnabled: hapticsEnabled,
            sparksEnabled: sparksEnabled
        )
    }
}

struct SpinnerCoinView: View {
    var headshot: UIImage?
    var headshotTransform: HeadshotTransform?
    var height: CGFloat = 320
    var animationDisabled: Bool = false
    var restAngleDegrees: CGFloat?
    var speedMultiplier: CGFloat = 1.0
    var onTap: (() -> Void)?
    var preset: SpinnerCoinPreset = .default
    var tuning: SpinnerCoinTuning = .default
    var yoYoConfig: SpinnerYoYoConfig = .disabled

    init(headshot: UIImage?,
         transform: HeadshotTransform? = nil,
         height: CGFloat = 320,
         animationDisabled: Bool = false,
         restAngleDegrees: CGFloat? = nil,
         preset: SpinnerCoinPreset = .default,
         tuning: SpinnerCoinTuning = .default,
         yoYoConfig: SpinnerYoYoConfig = .disabled,
         speedMultiplier: CGFloat = 1.0,
         onTap: (() -> Void)? = nil) {
        self.headshot = headshot
        self.headshotTransform = transform
        self.height = height
        self.animationDisabled = animationDisabled
        self.restAngleDegrees = restAngleDegrees
        self.speedMultiplier = speedMultiplier
        self.preset = preset
        self.tuning = tuning
        self.yoYoConfig = yoYoConfig
        self.onTap = onTap
    }

    public var body: some View {
        SpinnerCoinSceneView(headshot: headshot,
                             transform: headshotTransform,
                             animationDisabled: animationDisabled,
                             restAngleDegrees: restAngleDegrees,
                             preset: preset,
                             tuning: tuning,
                             yoYoConfig: yoYoConfig,
                             speedMultiplier: speedMultiplier,
                             onTap: onTap)
        .frame(width: height, height: height)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Your It Factor coin")
        .accessibilityAddTraits(.startsMediaSession)
    }
}

private struct SpinnerCoinSceneView: UIViewRepresentable {
    var headshot: UIImage?
    var transform: HeadshotTransform?
    var animationDisabled: Bool
    var restAngleDegrees: CGFloat?
    var preset: SpinnerCoinPreset
    var tuning: SpinnerCoinTuning
    var yoYoConfig: SpinnerYoYoConfig
    var speedMultiplier: CGFloat
    var onTap: (() -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(
            preset: preset,
            tuning: tuning,
            yoYoConfig: yoYoConfig,
            speedMultiplier: speedMultiplier,
            onTap: onTap,
            animationDisabled: animationDisabled,
            restAngleDegrees: restAngleDegrees
        )
    }

    func makeUIView(context: Context) -> SCNView {
        let scnView = SCNView(frame: .zero)
        scnView.antialiasingMode = .multisampling4X
        scnView.backgroundColor = .clear
        scnView.autoenablesDefaultLighting = true
        scnView.allowsCameraControl = false
        scnView.preferredFramesPerSecond = 120

        // MARK: Scene load
        let scene: SCNScene
        if let url = Bundle.main.url(forResource: "ActorCoin", withExtension: "usdz"),
           let loaded = try? SCNScene(url: url, options: [.checkConsistency: true]) {
            scene = loaded
        } else if let named = SCNScene(named: "ActorCoin.usdz") {
            scene = named
        } else {
            scene = SCNScene()
            let text = SCNText(string: "Missing ActorCoin.usdz", extrusionDepth: 2)
            text.firstMaterial?.diffuse.contents = UIColor.systemPink
            let node = SCNNode(geometry: text)
            node.scale = SCNVector3(0.01, 0.01, 0.01)
            scene.rootNode.addChildNode(node)
            print("[SpinnerCoin] ERROR: Could not load ActorCoin.usdz from bundle.")
        }
        scnView.scene = scene

        // Ensure we have a camera
        let cameraNode = Self.ensureCamera(in: scene)
        cameraNode.camera?.zNear = 0.001
        cameraNode.camera?.zFar = 200
        scnView.pointOfView = cameraNode

        // Build pivot and content containers so orientation is separate from spin physics
        let coinPivot = SCNNode()
        coinPivot.name = "CoinPivot"
        let content = SCNNode()
        content.name = "CoinContent"
        scene.rootNode.addChildNode(coinPivot)
        coinPivot.addChildNode(content)

        // Move existing renderable children under content (leave cameras/lights)
        for child in scene.rootNode.childNodes {
            guard child !== coinPivot, child !== cameraNode, child.light == nil, child.camera == nil else { continue }
            child.removeFromParentNode()
            content.addChildNode(child)
        }

        // Force a consistent upright orientation so the coin faces SceneKit +Z.
        content.eulerAngles = SCNVector3(-Float.pi / 2, 0, 0)
        print("[SpinnerCoin] Forced content upright (-90° about X)")

        // Logo background color baked directly in latest USDZ.

        Self.configureCamera(cameraNode: cameraNode, targetNode: content)

        let applied = Self.applyHeadshot(headshot, transform: transform, in: scene)
        if !applied {
            print("[SpinnerCoin] WARN: Could not find placeholder by node/geometry/material name. See USDCoinInspector for model names.")
        }

        Self.ensureGlowRing(on: content)
        Self.updateGlow(on: content, intensity: tuning.glow)
        context.coordinator.attach(to: scnView, coinRoot: coinPivot)
        return scnView
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        guard let scene = uiView.scene else { return }
        _ = Self.applyHeadshot(headshot, transform: transform, in: scene)
        context.coordinator.reduceMotionEnabled = UIAccessibility.isReduceMotionEnabled
        context.coordinator.updatePreset(preset)
        context.coordinator.updateTuning(tuning)
        context.coordinator.updateYoYoConfig(yoYoConfig)
        context.coordinator.updateSpeedMultiplier(speedMultiplier)
        context.coordinator.updateAnimationState(animationDisabled, restAngleDegrees: restAngleDegrees)
        if let content = scene.rootNode.childNode(withName: "CoinContent", recursively: true) {
            Self.updateGlow(on: content, intensity: tuning.glow)
        }
    }

    // MARK: - Placeholder resolution

    @discardableResult
    private static func applyHeadshot(_ image: UIImage?,
                                      transform: HeadshotTransform?,
                                      in scene: SCNScene) -> Bool {
        let fallback = UIImage(named: "default_headshot")
        let finalImage = image ?? fallback

        // Build flattened list of nodes
        var nodes: [SCNNode] = []
        scene.rootNode.enumerateChildNodes { node, _ in nodes.append(node) }

        // 1) Node (or descendant) named "UserPhotoPlaceholder"
        if let placeholderNode = nodes.first(where: { $0.name == "UserPhotoPlaceholder" }) {
            if let geometry = geometry(from: placeholderNode) {
                apply(image: finalImage,
                      transform: transform,
                      to: geometry)
                print("[SpinnerCoin] Applied headshot to node 'UserPhotoPlaceholder'")
                return true
            } else {
                print("[SpinnerCoin] Found node 'UserPhotoPlaceholder' but no geometry beneath it.")
            }
        }

        // 2) Geometry directly named "UserPhotoPlaceholder"
        if let geometryNode = nodes.first(where: { $0.geometry?.name == "UserPhotoPlaceholder" }),
           let geometry = geometryNode.geometry {
            apply(image: finalImage,
                  transform: transform,
                  to: geometry)
            print("[SpinnerCoin] Applied headshot to geometry 'UserPhotoPlaceholder'")
            return true
        }

        // 3) Material named "UserPhotoPlaceholderMat"
        for node in nodes {
            guard let geometry = node.geometry else { continue }
            if let material = geometry.materials.first(where: { $0.name == "UserPhotoPlaceholderMat" }) {
                prepare(material: material,
                        with: finalImage,
                        transform: transform)
                print("[SpinnerCoin] Applied headshot via material 'UserPhotoPlaceholderMat'")
                return true
            }
        }
        return false
    }

    private static func geometry(from node: SCNNode) -> SCNGeometry? {
        if let geometry = node.geometry {
            return geometry
        }
        for child in node.childNodes {
            if let found = geometry(from: child) {
                return found
            }
        }
        return nil
    }

    private static func apply(image: UIImage?,
                              transform: HeadshotTransform?,
                              to geometry: SCNGeometry?) {
        guard let geometry = geometry else { return }
        let material = geometry.firstMaterial ?? SCNMaterial()
        prepare(material: material,
                with: image,
                transform: transform)
        geometry.firstMaterial = material
        remapTextureCoordinatesIfNeeded(for: geometry)
    }

    private static func prepare(material: SCNMaterial,
                                with image: UIImage?,
                                transform: HeadshotTransform?) {
        let bakedHeadshot = renderedHeadshot(from: image, transform: transform)
        material.diffuse.contents = bakedHeadshot ?? image ?? UIColor.systemGray5
        material.locksAmbientWithDiffuse = true
        material.metalness.contents = 0.15
        material.roughness.contents = 0.35
        material.isDoubleSided = true
        material.diffuse.wrapS = .clamp
        material.diffuse.wrapT = .clamp
        material.diffuse.contentsTransform = SCNMatrix4Identity
    }

    private struct UVBounds {
        let minU: CGFloat
        let maxU: CGFloat
        let minV: CGFloat
        let maxV: CGFloat
    }

    private static var uvBoundsCache: [ObjectIdentifier: UVBounds] = [:]

    private static func remapTextureCoordinatesIfNeeded(for geometry: SCNGeometry) {
        guard let material = geometry.firstMaterial,
              let bounds = textureBounds(for: geometry) else { return }

        let rangeU = max(bounds.maxU - bounds.minU, 0.0001)
        let rangeV = max(bounds.maxV - bounds.minV, 0.0001)

        // Map geometry's UV subset back to full [0,1] so the entire headshot is visible.
        var transform = SCNMatrix4MakeScale(Float(1 / rangeU), Float(1 / rangeV), 1)
        transform.m41 = Float(-bounds.minU / rangeU) + 0.05
        transform.m42 = Float(-bounds.minV / rangeV)
        material.diffuse.contentsTransform = transform
    }

    private static func textureBounds(for geometry: SCNGeometry) -> UVBounds? {
        let key = ObjectIdentifier(geometry)
        if let cached = uvBoundsCache[key] { return cached }
        guard let source = geometry.sources(for: .texcoord).first,
              source.componentsPerVector >= 2 else { return nil }

        let stride = source.dataStride != 0 ? source.dataStride : source.bytesPerComponent * source.componentsPerVector
        let offset = source.dataOffset
        let vectorCount = source.vectorCount
        let bytesPerComponent = source.bytesPerComponent
        guard bytesPerComponent == MemoryLayout<Float>.size else { return nil }

        var minU = CGFloat.greatestFiniteMagnitude
        var maxU = -CGFloat.greatestFiniteMagnitude
        var minV = CGFloat.greatestFiniteMagnitude
        var maxV = -CGFloat.greatestFiniteMagnitude

        source.data.withUnsafeBytes { rawBuffer in
            guard let basePointer = rawBuffer.baseAddress else { return }
            for i in 0..<vectorCount {
                let start = basePointer.advanced(by: offset + i * stride)
                let u = start.assumingMemoryBound(to: Float.self).pointee
                let vPtr = start.advanced(by: bytesPerComponent)
                let v = vPtr.assumingMemoryBound(to: Float.self).pointee
                let cu = CGFloat(u)
                let cv = CGFloat(v)
                minU = min(minU, cu)
                maxU = max(maxU, cu)
                minV = min(minV, cv)
                maxV = max(maxV, cv)
            }
        }

        guard minU.isFinite, maxU.isFinite, minV.isFinite, maxV.isFinite else { return nil }
        let bounds = UVBounds(minU: minU, maxU: maxU, minV: minV, maxV: maxV)
        uvBoundsCache[key] = bounds
        return bounds
    }

    private static func ensureGlowRing(on root: SCNNode) {
        if root.childNode(withName: "GlowRing", recursively: false) != nil { return }

        let lightNode = SCNNode()
        lightNode.name = "GlowLight"
        let light = SCNLight()
        light.type = .omni
        light.intensity = 250
        lightNode.light = light
        lightNode.position = SCNVector3(0, 0, 4.0)
        root.addChildNode(lightNode)

        let ring = SCNTorus(ringRadius: 2.1, pipeRadius: 0.02)
        let material = SCNMaterial()
        material.diffuse.contents = UIColor.clear
        material.emission.contents = UIColor.systemPink
        material.blendMode = .add
        material.isDoubleSided = true
        ring.materials = [material]
        let ringNode = SCNNode(geometry: ring)
        ringNode.name = "GlowRing"
        ringNode.opacity = 0.25
        root.addChildNode(ringNode)
    }

    private static func updateGlow(on root: SCNNode, intensity: CGFloat) {
        ensureGlowRing(on: root)
        guard let ringNode = root.childNode(withName: "GlowRing", recursively: false),
              let material = ringNode.geometry?.firstMaterial else { return }
        let clamped = max(0.0, min(1.0, intensity))

        let accentA = UIColor(red: 0.98, green: 0.34, blue: 0.75, alpha: 1)
        let accentB = UIColor(red: 0.47, green: 0.38, blue: 0.98, alpha: 1)
        material.emission.contents = blend(accentA, accentB, amount: clamped)

        let baseOpacity = 0.25 + clamped * 0.5
        ringNode.opacity = baseOpacity

        if let light = root.childNode(withName: "GlowLight", recursively: false)?.light {
            light.intensity = 200 + clamped * 400
            light.temperature = 6500 - clamped * 1200
        }

        let pulseKey = "GlowPulse"
        if clamped > 0.6 {
            if ringNode.action(forKey: pulseKey) == nil {
                let up = SCNAction.fadeOpacity(to: baseOpacity + 0.25, duration: 0.9)
                let down = SCNAction.fadeOpacity(to: baseOpacity, duration: 0.9)
                let sequence = SCNAction.sequence([up, down])
                ringNode.runAction(SCNAction.repeatForever(sequence), forKey: pulseKey)
            }
        } else {
            ringNode.removeAction(forKey: pulseKey)
        }
    }

    final class Coordinator: NSObject {
        private weak var scnView: SCNView?
        private weak var coinRoot: SCNNode?

        private var displayLink: CADisplayLink?
        private var lastTimestamp: CFTimeInterval = 0
        private(set) var angularVelocity: CGFloat = 0
        private var preset: SpinnerCoinPreset
        private var tuning: SpinnerCoinTuning
        private var yoYoConfig: SpinnerYoYoConfig
        private var speedMultiplier: CGFloat
        private let hapticGenerator = UIImpactFeedbackGenerator(style: .rigid)
        private var axisTime: CGFloat = 0
        private var effects = SpinnerEffects()
        private var basePosition = SCNVector3Zero
        private var yoYoOffset = SCNVector3Zero
        private var yoYoVelocity = SCNVector3Zero
        private var lastInteractionTimestamp: CFTimeInterval = 0
        private let autoSpinResumeDelay: CFTimeInterval = 1.1
        private var animationDisabled: Bool
        private var restAngleDegrees: CGFloat?

        private var panStartX: CGFloat = 0
        private var panActive = false

        var reduceMotionEnabled: Bool = UIAccessibility.isReduceMotionEnabled {
            didSet {
                if reduceMotionEnabled || animationDisabled {
                    stopLoop()
                } else {
                    startLoop()
                }
            }
        }

        private let onTap: (() -> Void)?
        init(
            preset: SpinnerCoinPreset,
            tuning: SpinnerCoinTuning,
            yoYoConfig: SpinnerYoYoConfig,
            speedMultiplier: CGFloat,
            onTap: (() -> Void)?,
            animationDisabled: Bool,
            restAngleDegrees: CGFloat?
        ) {
            self.preset = preset
            self.tuning = tuning.clamped()
            self.yoYoConfig = yoYoConfig
            self.speedMultiplier = speedMultiplier
            self.onTap = onTap
            self.animationDisabled = animationDisabled
            self.restAngleDegrees = restAngleDegrees
        }

        func updatePreset(_ preset: SpinnerCoinPreset) {
            self.preset = preset
            resetPoseForPreset()
        }

        func updateTuning(_ tuning: SpinnerCoinTuning) {
            self.tuning = tuning.clamped()
            configureEffects()
        }

        func updateYoYoConfig(_ config: SpinnerYoYoConfig) {
            yoYoConfig = config
            if !config.isEnabled {
                resetYoYoPosition()
            }
        }

        func updateSpeedMultiplier(_ speedMultiplier: CGFloat) {
            let clamped = clamp(speedMultiplier, 0.25, 2.5)
            if clamped != self.speedMultiplier {
                if self.speedMultiplier > 0 {
                    angularVelocity *= clamped / self.speedMultiplier
                }
                self.speedMultiplier = clamped
            }
        }

        func updateAnimationState(_ disabled: Bool, restAngleDegrees: CGFloat?) {
            animationDisabled = disabled
            self.restAngleDegrees = restAngleDegrees
            if disabled {
                stopLoop()
                panActive = false
                angularVelocity = 0
                snapToRestAngle(animated: true)
            } else {
                resetPoseForPreset()
                if !reduceMotionEnabled {
                    startLoop()
                }
            }
        }

        func attach(to scnView: SCNView, coinRoot: SCNNode) {
            self.scnView = scnView
            self.coinRoot = coinRoot
            self.basePosition = coinRoot.position

            let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
            let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
            scnView.addGestureRecognizer(pan)
            scnView.addGestureRecognizer(tap)

            hapticGenerator.prepare()
            resetPoseForPreset()
            configureEffects()
            updateYoYoConfig(yoYoConfig)

            updateAnimationState(animationDisabled, restAngleDegrees: restAngleDegrees)
            if !reduceMotionEnabled, !animationDisabled { startLoop() }
        }

        @objc private func handleTap(_ gr: UITapGestureRecognizer) {
            guard gr.state == .ended else { return }
            noteInteraction()
            triggerTapHaptic()
            onTap?()
        }

        @objc private func handlePan(_ gr: UIPanGestureRecognizer) {
            guard !animationDisabled else { return }
            guard let view = scnView else { return }
            let x = gr.translation(in: view).x

            switch gr.state {
            case .began:
                panActive = true
                panStartX = x
                noteInteraction()

            case .changed:
                let dx = x - panStartX
                panStartX = x
                noteInteraction()

                let rotationMultiplier = effectiveDragRotationMultiplier
                let velocityMultiplier = effectiveDragVelocityMultiplier
                let limit = effectiveMaxVelocity

                rotate(by: dx * rotationMultiplier)
                angularVelocity = clamp(
                    angularVelocity + dx * velocityMultiplier,
                    -limit,
                    limit
                )

            case .ended, .cancelled, .failed:
                panActive = false
                let limit = effectiveMaxVelocity
                angularVelocity = clamp(angularVelocity, -limit, limit)
                triggerSpinHaptic()
                logCoinPose(context: "panEnded")
                if yoYoConfig.isEnabled {
                    let velocity = gr.velocity(in: view)
                    triggerYoYoIfNeeded(velocity: velocity)
                }
                noteInteraction()

            default:
                break
            }
        }

        private func startLoop() {
            stopLoop()
            let link = CADisplayLink(target: self, selector: #selector(step(_:)))
            link.add(to: .main, forMode: .common)
            displayLink = link
            lastTimestamp = 0
        }

        private func stopLoop() {
            displayLink?.invalidate()
            displayLink = nil
        }

        @objc private func step(_ link: CADisplayLink) {
            guard !animationDisabled else { return }
            guard let coin = coinRoot else { return }
            if lastTimestamp == 0 { lastTimestamp = link.timestamp; return }
            let dt = CGFloat(link.timestamp - lastTimestamp)
            lastTimestamp = link.timestamp
            let speedScale = clampedSpeedMultiplier
            axisTime += dt * max(0.1, preset.axisJitterSpeed) * speedScale

            var ranAutoSpin = false
            if let target = preset.idleAutoSpinVelocity {
                let scaledTarget = target * speedScale
                if shouldRunAutoSpin(targetVelocity: scaledTarget) {
                    angularVelocity = scaledTarget
                    rotate(by: angularVelocity * dt)
                    ranAutoSpin = true
                }
            }
            if !ranAutoSpin, abs(angularVelocity) > 0.0001 {
                rotate(by: angularVelocity * dt)
                angularVelocity *= pow(preset.friction, max(1, 60 * dt))
                angularVelocity = clamp(angularVelocity, -effectiveMaxVelocity, effectiveMaxVelocity)
            } else if !panActive && !ranAutoSpin {
                settleIfNeeded(node: coin)
            }

            if yoYoConfig.isEnabled {
                updateYoYoPosition(dt: dt)
            } else {
                resetYoYoPosition()
            }
        }

        private var accelerationScale: CGFloat {
            tuning.acceleration
        }

        private var clampedSpeedMultiplier: CGFloat {
            clamp(speedMultiplier, 0.25, 2.5)
        }

        private var effectiveDragRotationMultiplier: CGFloat {
            preset.dragRotationMultiplier * accelerationScale * clampedSpeedMultiplier
        }

        private var effectiveDragVelocityMultiplier: CGFloat {
            preset.dragVelocityMultiplier * accelerationScale * clampedSpeedMultiplier
        }

        private var effectiveMaxVelocity: CGFloat {
            let base: CGFloat
            if preset.unlimitedVelocity {
                base = max(80 * accelerationScale, 40)
            } else {
                base = preset.maxVelocity * (0.7 + accelerationScale * 0.5)
            }
            return base * clampedSpeedMultiplier
        }

        private func triggerSpinHaptic() {
            guard tuning.haptics > 0 else { return }
            let normalized = min(1.0, max(0.05, abs(angularVelocity) / max(effectiveMaxVelocity, 0.1)))
            let intensity = min(1.0, CGFloat(tuning.haptics) * normalized)
            hapticGenerator.impactOccurred(intensity: max(0.05, intensity))
            hapticGenerator.prepare()
        }

        private func triggerTapHaptic() {
            guard tuning.haptics > 0 else { return }
            hapticGenerator.impactOccurred(intensity: max(0.05, CGFloat(tuning.haptics)))
            hapticGenerator.prepare()
        }

        private func currentAxis() -> SCNVector3 {
            let base = preset.normalizedAxis
            let jitter = preset.axisJitter
            if jitter.length() < 0.0001 { return base }
            let t = axisTime
            let perturbation = SCNVector3(
                jitter.x * sin(Float(t * 1.3)),
                jitter.y * cos(Float(t * 0.9)),
                jitter.z * sin(Float(t * 1.6))
            )
            let axis = SCNVector3(base.x + perturbation.x,
                                  base.y + perturbation.y,
                                  base.z + perturbation.z)
            return axis.normalized()
        }

        private func rotate(by delta: CGFloat) {
            guard let coin = coinRoot else { return }

            let currentAngle = CGFloat(coin.rotation.w)
            let newAngle = (currentAngle + delta)
                .truncatingRemainder(dividingBy: (CGFloat.pi * 2))

            let axis = currentAxis()
            coin.rotation = SCNVector4(axis.x, axis.y, axis.z, Float(newAngle))
            evaluateEffects(for: coin)
        }

        private func settleIfNeeded(node: SCNNode) {
            let angle = normalizedAngle(CGFloat(node.rotation.w))
            if abs(angularVelocity) > preset.settleThreshold { return }

            let d0 = shortestDelta(from: angle, to: 0)
            let d1 = shortestDelta(from: angle, to: .pi)
            let target = abs(d0) < abs(d1) ? 0 : .pi

            let delta = shortestDelta(from: angle, to: target)
            if abs(delta) > 0.001 {
                let axis = preset.prefersVerticalRest ? SCNVector3(0, 1, 0) : currentAxis()
                node.rotation = SCNVector4(axis.x, axis.y, axis.z, Float(angle + delta * 0.35))
            } else if preset.prefersVerticalRest {
                node.rotation = SCNVector4(0, 1, 0, Float(target))
            }
            evaluateEffects(for: node)
        }

        private func logCoinPose(context: String) {
            guard let coin = coinRoot else { return }

            let euler = coin.eulerAngles
            let rot = coin.rotation

            print(
                """
                [SpinnerCoin] Pose (\(context)):
                  eulerAngles = (x: \(euler.x), y: \(euler.y), z: \(euler.z))
                  rotation    = axis(\(rot.x), \(rot.y), \(rot.z)), angle: \(rot.w)
                """
            )
        }

        private func normalizedAngle(_ a: CGFloat) -> CGFloat {
            var x = a.truncatingRemainder(dividingBy: (CGFloat.pi * 2))
            if x < 0 { x += (CGFloat.pi * 2) }
            return x
        }

        private func shortestDelta(from a: CGFloat, to b: CGFloat) -> CGFloat {
            var d = (b - a).truncatingRemainder(dividingBy: (CGFloat.pi * 2))
            if d > CGFloat.pi { d -= (CGFloat.pi * 2) }
            if d < -CGFloat.pi { d += (CGFloat.pi * 2) }
            return d
        }

        private func clamp<T: Comparable>(_ v: T, _ lo: T, _ hi: T) -> T { max(lo, min(hi, v)) }

        private func noteInteraction() {
            lastInteractionTimestamp = CACurrentMediaTime()
        }

        private func shouldRunAutoSpin(targetVelocity: CGFloat) -> Bool {
            guard !animationDisabled else { return false }
            guard !reduceMotionEnabled else { return false }
            guard !panActive else { return false }
            let now = CACurrentMediaTime()
            if abs(angularVelocity) > max(0.8, targetVelocity * 1.6) { return false }
            return (now - lastInteractionTimestamp) >= autoSpinResumeDelay
        }

        private func resetYoYoPosition() {
            yoYoOffset = SCNVector3Zero
            yoYoVelocity = SCNVector3Zero
            coinRoot?.position = basePosition
        }

        private func updateYoYoPosition(dt: CGFloat) {
            guard yoYoConfig.isEnabled, let coin = coinRoot else { return }
            let cfg = yoYoConfig
            let frequency = max(0.1, cfg.springFrequency)
            let omega = 2.0 * Double.pi * Double(frequency)
            let damping = Double(cfg.springDampingRatio)
            let stiffness = omega * omega
            let dampingCoeff = 2.0 * damping * omega
            let deltaTime = Double(dt)

            func integrate(_ x: Float, _ v: Float) -> (Float, Float) {
                let position = Double(x)
                let velocity = Double(v)
                let acceleration = -stiffness * position - dampingCoeff * velocity
                let vNext = velocity + acceleration * deltaTime
                let xNext = position + vNext * deltaTime
                return (Float(xNext), Float(vNext))
            }

            var offsetY = yoYoOffset.y
            var velocityY = yoYoVelocity.y
            (offsetY, velocityY) = integrate(offsetY, velocityY)

            var offsetZ = yoYoOffset.z
            var velocityZ = yoYoVelocity.z
            (offsetZ, velocityZ) = integrate(offsetZ, velocityZ)

            let maxY = Float(cfg.maxVerticalOffset)
            let maxZ = Float(cfg.maxDepthOffset)
            offsetY = max(-maxY, min(maxY, offsetY))
            offsetZ = max(-maxZ, min(maxZ, offsetZ))

            yoYoOffset = SCNVector3(0, offsetY, offsetZ)
            yoYoVelocity = SCNVector3(0, velocityY, velocityZ)

            coin.position = SCNVector3(
                basePosition.x,
                basePosition.y + yoYoOffset.y,
                basePosition.z + yoYoOffset.z
            )
        }

        private func triggerYoYoIfNeeded(velocity: CGPoint) {
            let cfg = yoYoConfig
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

        private func configureEffects() {
            var config = effects.config
            let glow = tuning.glow
            let sparks = tuning.sparks
            let thresholdScale = max(0.55, 1.10 - sparks * 0.6)
            config.glowThreshold = 0.18 * thresholdScale
            config.sparkThreshold = 0.28 * thresholdScale
            config.hurtThreshold = 0.38 * thresholdScale
            config.crackThreshold = 0.5 * thresholdScale
            config.glowIntensityMultiplier = tuning.glowEnabled ? max(0.3, 0.6 + glow * 3.6) : 0
            config.sparksEnabled = tuning.sparksEnabled && sparks > 0.05
            config.toastsEnabled = false
            config.crackingEnabled = tuning.sparksEnabled && sparks > 0.2
            config.hapticsEnabled = tuning.hapticsEnabled && tuning.haptics > 0.01
            config.hapticStrength = tuning.hapticsEnabled ? max(0.15, min(1.0, tuning.haptics)) : 0
            config.sparkSpread = max(0.1, min(1.0, tuning.sparkSpread))
            effects.config = config
            if let coin = coinRoot {
                evaluateEffects(for: coin)
            }
        }

        private func evaluateEffects(for node: SCNNode) {
            let normalizedSpin = min(1.0, abs(angularVelocity) * 0.02 * tuning.acceleration)
            effects.evaluateSpinMagnitude(normalizedSpin, on: node)
        }

        private func resetPoseForPreset() {
            angularVelocity = 0
            panActive = false
            axisTime = 0
            guard let coin = coinRoot else { return }
            let axis = preset.prefersVerticalRest ? SCNVector3(0, 1, 0) : preset.normalizedAxis
            coin.rotation = SCNVector4(axis.x, axis.y, axis.z, 0)
            resetYoYoPosition()
            configureEffects()
            evaluateEffects(for: coin)
        }

        private func snapToRestAngle(animated: Bool) {
            guard let coin = coinRoot else { return }
            let angleDegrees = restAngleDegrees ?? 0
            let radians = CGFloat(angleDegrees) * .pi / 180
            let axis = SCNVector3(0, 1, 0)
            let apply = {
                coin.rotation = SCNVector4(axis.x, axis.y, axis.z, Float(radians))
                self.evaluateEffects(for: coin)
            }
            if animated {
                SCNTransaction.begin()
                SCNTransaction.animationDuration = 0.35
                apply()
                SCNTransaction.commit()
            } else {
                apply()
            }
        }
    }

    // MARK: - Camera helpers

    private static func ensureCamera(in scene: SCNScene) -> SCNNode {
        if let node = scene.rootNode.childNodes(passingTest: { node, _ in node.camera != nil }).first {
            return node
        }

        let cameraNode = SCNNode()
        let camera = SCNCamera()
        cameraNode.camera = camera
        scene.rootNode.addChildNode(cameraNode)
        return cameraNode
    }

    private static func configureCamera(cameraNode: SCNNode, targetNode: SCNNode) {
        guard let camera = cameraNode.camera else { return }
        let bounds = targetNode.boundingBox
        let spanX = Double(bounds.max.x - bounds.min.x)
        let spanY = Double(bounds.max.y - bounds.min.y)
        let spanZ = Double(bounds.max.z - bounds.min.z)
        let maxSpan = max(spanX, spanY, spanZ)
        let radius = max(maxSpan * 0.5, 3.0)

        let centerLocal = SCNVector3((bounds.min.x + bounds.max.x) * 0.5,
                                     (bounds.min.y + bounds.max.y) * 0.5,
                                     (bounds.min.z + bounds.max.z) * 0.5)
        let centerWorld = targetNode.convertPosition(centerLocal, to: nil)

        camera.usesOrthographicProjection = false
        camera.fieldOfView = 45
        camera.zNear = 0.01
        camera.zFar = max(300, radius * 30.0)

        let distance = max(maxSpan, 6.0)
        let offsetDistance = Float(distance * 1.8)
        cameraNode.position = SCNVector3(centerWorld.x,
                                         centerWorld.y,
                                         centerWorld.z + offsetDistance)
        cameraNode.look(at: centerWorld, up: SCNVector3(0, 1, 0), localFront: SCNVector3(0, 0, -1))
    }

    // MARK: - Headshot baking

    private static func renderedHeadshot(from image: UIImage?,
                                         transform: HeadshotTransform?) -> UIImage? {
        guard let baseImage = image else { return nil }

        let canvasSize = CGSize(width: 1024, height: 1024)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 2
        format.opaque = false

        let zoom = max(0.2, min(transform?.scale ?? 1.0, 5.0))

        let renderer = UIGraphicsImageRenderer(size: canvasSize, format: format)
        return renderer.image { ctx in
            let cg = ctx.cgContext

            cg.setFillColor(UIColor.clear.cgColor)
            cg.fill(CGRect(origin: .zero, size: canvasSize))

            let imageSize = baseImage.size
            guard imageSize.width > 0, imageSize.height > 0 else {
                baseImage.draw(in: CGRect(origin: .zero, size: canvasSize))
                return
            }

            let aspectFillScale = max(canvasSize.width / imageSize.width,
                                      canvasSize.height / imageSize.height)
            let finalScale = aspectFillScale * zoom

            let scaledSize = CGSize(width: imageSize.width * finalScale,
                                    height: imageSize.height * finalScale)

            let offset = transform?.offset(width: canvasSize.width,
                                           height: canvasSize.height) ?? .zero

            let origin = CGPoint(
                x: (canvasSize.width - scaledSize.width) / 2 + offset.width,
                y: (canvasSize.height - scaledSize.height) / 2 + offset.height
            )

            baseImage.draw(in: CGRect(origin: origin, size: scaledSize))
        }
    }
}

private extension SCNVector3 {
    func length() -> Float {
        sqrt(x * x + y * y + z * z)
    }

    func normalized() -> SCNVector3 {
        let len = max(length(), 0.0001)
        return SCNVector3(x / len, y / len, z / len)
    }

    func dot(_ other: SCNVector3) -> Float {
        x * other.x + y * other.y + z * other.z
    }

    static func *(lhs: SCNVector3, rhs: Float) -> SCNVector3 {
        SCNVector3(lhs.x * rhs, lhs.y * rhs, lhs.z * rhs)
    }

    static func +(lhs: SCNVector3, rhs: SCNVector3) -> SCNVector3 {
        SCNVector3(lhs.x + rhs.x, lhs.y + rhs.y, lhs.z + rhs.z)
    }
}

// MARK: - Math helpers
@inline(__always) private func dot(_ a: SCNVector3, _ b: SCNVector3) -> Float { a.x * b.x + a.y * b.y + a.z * b.z }
@inline(__always) private func cross(_ a: SCNVector3, _ b: SCNVector3) -> SCNVector3 {
    SCNVector3(a.y * b.z - a.z * b.y, a.z * b.x - a.x * b.z, a.x * b.y - a.y * b.x)
}
@inline(__always) private func length(_ v: SCNVector3) -> Float { sqrtf(v.x * v.x + v.y * v.y + v.z * v.z) }
@inline(__always) private func normalize(_ v: SCNVector3) -> SCNVector3 {
    let L = max(length(v), 1e-6)
    return SCNVector3(v.x / L, v.y / L, v.z / L)
}

private func blend(_ a: UIColor, _ b: UIColor, amount t: CGFloat) -> UIColor {
    let clamped = max(0, min(1, t))
    var ar: CGFloat = 0, ag: CGFloat = 0, ab: CGFloat = 0, aa: CGFloat = 0
    var br: CGFloat = 0, bg: CGFloat = 0, bb: CGFloat = 0, ba: CGFloat = 0
    a.getRed(&ar, green: &ag, blue: &ab, alpha: &aa)
    b.getRed(&br, green: &bg, blue: &bb, alpha: &ba)
    return UIColor(red: ar + (br - ar) * clamped,
                   green: ag + (bg - ag) * clamped,
                   blue: ab + (bb - ab) * clamped,
                   alpha: aa + (ba - aa) * clamped)
}

/// Returns an axis-angle rotation aligning v1 to v2. Nil if already aligned.
private func rotationAligning(v1: SCNVector3, v2: SCNVector3) -> SCNVector4? {
    let a = normalize(v1)
    let b = normalize(v2)
    let c = dot(a, b)
    if c > 0.9999 { return nil }
    if c < -0.9999 {
        let axis = normalize(abs(a.x) > 0.9 ? cross(a, SCNVector3(0, 1, 0)) : cross(a, SCNVector3(1, 0, 0)))
        return SCNVector4(axis.x, axis.y, axis.z, .pi)
    }
    let axis = normalize(cross(a, b))
    let angle = acos(max(-1, min(1, c)))
    return SCNVector4(axis.x, axis.y, axis.z, angle)
}
