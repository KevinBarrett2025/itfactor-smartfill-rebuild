import Foundation
import SceneKit
import UIKit

extension Notification.Name {
    static let spinnerCrack = Notification.Name("spinner.crack.screen")
    static let spinnerCelebrate = Notification.Name("spinner.celebrate")
}

public enum SpinnerHapticEvent {
    case lightSpin(CGFloat)
    case hurtSpin(CGFloat)
    case crackHit(CGFloat)
}

public protocol SpinnerHapticsEngine {
    func play(_ event: SpinnerHapticEvent)
}

public struct DefaultSpinnerHapticsEngine: SpinnerHapticsEngine {
    public init() {}

    public func play(_ event: SpinnerHapticEvent) {
        let generator: UIImpactFeedbackGenerator
        let intensity: CGFloat

        switch event {
        case .lightSpin(let value):
            generator = UIImpactFeedbackGenerator(style: .light)
            intensity = value
        case .hurtSpin(let value):
            generator = UIImpactFeedbackGenerator(style: .medium)
            intensity = value
        case .crackHit(let value):
            generator = UIImpactFeedbackGenerator(style: .heavy)
            intensity = value
        }

        generator.prepare()
        generator.impactOccurred(intensity: max(0.05, min(1.0, intensity)))
    }
}

/// Configuration for spinner VFX thresholds and behaviors.
public struct SpinnerEffectsConfig {
    public var glowThreshold: CGFloat
    public var sparkThreshold: CGFloat
    public var hurtThreshold: CGFloat
    public var crackThreshold: CGFloat

    /// Multiplier applied to the base glow "up" intensity.
    public var glowIntensityMultiplier: CGFloat

    /// Master toggles for more intense effects.
    public var hapticsEnabled: Bool
    public var sparksEnabled: Bool
    public var crackingEnabled: Bool
    public var toastsEnabled: Bool
    public var hapticStrength: CGFloat
    public var sparkSpread: CGFloat

    public init(
        glowThreshold: CGFloat = 0.12,
        sparkThreshold: CGFloat = 0.18,
        hurtThreshold: CGFloat = 0.25,
        crackThreshold: CGFloat = 0.32,
        glowIntensityMultiplier: CGFloat = 1.0,
        hapticsEnabled: Bool = true,
        sparksEnabled: Bool = true,
        crackingEnabled: Bool = true,
        toastsEnabled: Bool = true,
        hapticStrength: CGFloat = 1.0,
        sparkSpread: CGFloat = 0.6
    ) {
        self.glowThreshold = glowThreshold
        self.sparkThreshold = sparkThreshold
        self.hurtThreshold = hurtThreshold
        self.crackThreshold = crackThreshold
        self.glowIntensityMultiplier = glowIntensityMultiplier
        self.hapticsEnabled = hapticsEnabled
        self.sparksEnabled = sparksEnabled
        self.crackingEnabled = crackingEnabled
        self.toastsEnabled = toastsEnabled
        self.hapticStrength = hapticStrength
        self.sparkSpread = sparkSpread
    }

    public static let `default` = SpinnerEffectsConfig()
}

/// Encapsulates all gamified reactions (glow, sparks, haptics, overlays) for the spinner coin.
public final class SpinnerEffects {
    private static let sparkSprite: UIImage = {
        let size: CGFloat = 16
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        return renderer.image { ctx in
            let rect = CGRect(origin: .zero, size: CGSize(width: size, height: size))
            ctx.cgContext.setFillColor(UIColor.white.cgColor)
            ctx.cgContext.addEllipse(in: rect)
            ctx.cgContext.fillPath()
        }
    }()

    private static let flareSprite: UIImage = {
        let size: CGFloat = 220
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        return renderer.image { ctx in
            let colors = [UIColor(displayP3Red: 1, green: 0.4, blue: 1, alpha: 0.9).cgColor,
                          UIColor(displayP3Red: 0.2, green: 0.08, blue: 0.6, alpha: 0).cgColor] as CFArray
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0,1])!
            ctx.cgContext.drawRadialGradient(
                gradient,
                startCenter: CGPoint(x: size/2, y: size/2),
                startRadius: 0,
                endCenter: CGPoint(x: size/2, y: size/2),
                endRadius: size/2,
                options: []
            )
        }
    }()

    /// Mutable runtime configuration so SwiftUI can drive thresholds/toggles.
    public var config: SpinnerEffectsConfig
    public var hapticsEngine: SpinnerHapticsEngine

    public init(
        config: SpinnerEffectsConfig = .default,
        hapticsEngine: SpinnerHapticsEngine = DefaultSpinnerHapticsEngine()
    ) {
        self.config = config
        self.hapticsEngine = hapticsEngine
    }

    /// Evaluate the current spin magnitude and trigger appropriate effects.
    public func evaluateSpinMagnitude(_ spin: CGFloat, on node: SCNNode) {
        let cfg = config
        let normalizedSpin = max(0, min(1.0, spin))
        guard normalizedSpin >= cfg.glowThreshold else { return }

        if normalizedSpin >= cfg.crackThreshold {
            if cfg.crackingEnabled {
                crackScreen()
                triggerAuroraRibbon(on: node)
            }
            triggerHaptic({ SpinnerHapticEvent.crackHit($0) }, strength: 1.0)
            NotificationCenter.default.post(name: .spinnerCelebrate, object: nil)
            return
        }

        if normalizedSpin >= cfg.hurtThreshold {
            let boost = max(2.0, normalizedSpin * 4.0) * cfg.glowIntensityMultiplier
            glowPulse(node, color: .systemPink, up: boost, duration: 0.28)
            solarFlarePulse(on: node, intensity: normalizedSpin)
            triggerHaptic({ SpinnerHapticEvent.hurtSpin($0) }, strength: 0.85)
            return
        }

        if normalizedSpin >= cfg.sparkThreshold {
            quickFlash(node)
            if cfg.sparksEnabled {
                spawnSparkBurst(on: node, intensity: normalizedSpin)
            }
            triggerHaptic({ SpinnerHapticEvent.lightSpin($0) }, strength: 0.45)
            return
        }

        if cfg.glowIntensityMultiplier > 0 {
            let chill = max(0.8, normalizedSpin * 2.4) * cfg.glowIntensityMultiplier
            glowPulse(node, color: .systemPurple, up: chill, duration: 0.22)
        }
    }

    // MARK: - Visual helpers

    private func glowPulse(_ node: SCNNode, color: UIColor, up: CGFloat, duration: TimeInterval) {
        let targets = materials(for: node)
        guard !targets.isEmpty else { return }

        SCNTransaction.begin()
        SCNTransaction.animationDuration = duration
        targets.forEach {
            $0.emission.contents = color
            $0.emission.intensity = up
        }
        SCNTransaction.completionBlock = {
            SCNTransaction.begin()
            SCNTransaction.animationDuration = duration
            targets.forEach { $0.emission.intensity = 0 }
            SCNTransaction.commit()
        }
        SCNTransaction.commit()
    }

    private func quickFlash(_ node: SCNNode) {
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.12
        node.opacity = 0.85
        SCNTransaction.completionBlock = {
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.18
            node.opacity = 1.0
            SCNTransaction.commit()
        }
        SCNTransaction.commit()
    }

    private func spawnSparkBurst(on node: SCNNode, intensity: CGFloat) {
        let spread = max(0.1, min(1.0, config.sparkSpread))
        let sparks = SCNParticleSystem()
        sparks.birthRate = 900 * intensity * (0.5 + spread)
        sparks.particleLifeSpan = 0.45
        sparks.particleLifeSpanVariation = 0.18
        sparks.particleVelocity = (4.0 + intensity * 6) * (0.8 + spread)
        sparks.particleVelocityVariation = 2.5
        sparks.spreadingAngle = 25 + (1 - spread) * 45
        sparks.emissionDuration = 0.08
        sparks.emittingDirection = SCNVector3(0, 0, 1)
        sparks.particleSize = 0.045 + (intensity * 0.05 * spread)
        sparks.particleColor = UIColor(displayP3Red: 0.75, green: 0.55, blue: 1.0, alpha: 0.95)
        sparks.particleColorVariation = SCNVector4(0.2, 0.1, 0.2, 0.2)
        sparks.blendMode = .alpha
        sparks.particleImage = SpinnerEffects.sparkSprite
        let radius = 0.55 + spread * 0.55
        let cylinder = SCNCylinder(radius: CGFloat(radius), height: 0.02)
        cylinder.radialSegmentCount = 32
        sparks.emitterShape = cylinder
        node.addParticleSystem(sparks)
    }

    private func materials(for node: SCNNode) -> [SCNMaterial] {
        if let geoMats = node.geometry?.materials, !geoMats.isEmpty {
            return geoMats
        }
        var mats: [SCNMaterial] = []
        node.enumerateChildNodes { child, _ in
            if let childMats = child.geometry?.materials {
                mats.append(contentsOf: childMats)
            }
        }
        return mats
    }

    // MARK: - Overlay + haptics

    private func crackScreen() {
        NotificationCenter.default.post(name: .spinnerCrack, object: nil)
    }

    private func triggerHaptic(_ builder: (CGFloat) -> SpinnerHapticEvent, strength: CGFloat) {
        guard config.hapticsEnabled, config.hapticStrength > 0 else { return }
        let intensity = max(0.05, min(1.0, strength * config.hapticStrength))
        hapticsEngine.play(builder(intensity))
    }

    private func triggerAuroraRibbon(on node: SCNNode) {
        guard config.sparksEnabled else { return }
        let ribbon = SCNParticleSystem()
        ribbon.birthRate = 120
        ribbon.particleLifeSpan = 0.85
        ribbon.particleLifeSpanVariation = 0.25
        ribbon.particleVelocity = 1.5
        ribbon.particleVelocityVariation = 0.6
        ribbon.emittingDirection = SCNVector3(0, 1, 0)
        ribbon.spreadingAngle = 45
        ribbon.particleSize = 0.05
        ribbon.particleColor = UIColor(displayP3Red: 0.8, green: 0.35, blue: 1.0, alpha: 0.9)
        ribbon.particleColorVariation = SCNVector4(0.2, 0.1, 0.2, 0.0)
        ribbon.blendMode = .alpha
        ribbon.particleImage = SpinnerEffects.flareSprite
        ribbon.acceleration = SCNVector3(0, 0.5, 0)
        ribbon.emitterShape = SCNTorus(ringRadius: 1.1, pipeRadius: 0.02)
        node.addParticleSystem(ribbon)
    }

    private func solarFlarePulse(on node: SCNNode, intensity: CGFloat) {
        let plane = SCNPlane(width: 2.4, height: 2.4)
        let material = SCNMaterial()
        material.diffuse.contents = SpinnerEffects.flareSprite
        material.isDoubleSided = true
        material.transparencyMode = .rgbZero
        material.blendMode = .alpha
        plane.firstMaterial = material

        let flareNode = SCNNode(geometry: plane)
        flareNode.constraints = [SCNBillboardConstraint()]
        flareNode.opacity = 0
        let scale = Float(0.9 + intensity * 1.6)
        flareNode.scale = SCNVector3(scale, scale, scale)
        node.addChildNode(flareNode)

        let fadeIn = SCNAction.fadeOpacity(to: 0.85, duration: 0.08)
        let fadeOut = SCNAction.fadeOut(duration: 0.3)
        let sequence = SCNAction.sequence([
            SCNAction.group([fadeIn, SCNAction.scale(by: 1.1, duration: 0.08)]),
            fadeOut,
            .removeFromParentNode()
        ])
        flareNode.runAction(sequence)
    }
}
