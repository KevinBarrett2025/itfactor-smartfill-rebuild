import SpriteKit
import UIKit

final class SpinnerConfettiScene: SKScene {
    private var hasLaunched = false

    override init(size: CGSize) {
        super.init(size: size)
        scaleMode = .resizeFill
        backgroundColor = .clear
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func didMove(to view: SKView) {
        super.didMove(to: view)
        guard !hasLaunched else { return }
        hasLaunched = true
        launchCelebration()
    }

    private func launchCelebration() {
        emitFallingConfetti()
        emitSolarBurst()

        let cleanup = SKAction.sequence([
            .wait(forDuration: 2.6),
            .run { [weak self] in
                self?.removeAllChildren()
                self?.hasLaunched = false
            }
        ])
        run(cleanup)
    }

    private func emitFallingConfetti() {
        let emitter = SKEmitterNode()
        emitter.particleTexture = SpinnerConfettiScene.confettiTextures.randomElement() ?? SpinnerConfettiScene.confettiTextures.first
        emitter.particleBirthRate = 420
        emitter.numParticlesToEmit = 360
        emitter.particleLifetime = 3.4
        emitter.particleLifetimeRange = 0.6
        emitter.emissionAngle = .pi
        emitter.emissionAngleRange = .pi / 2
        emitter.particleSpeed = 250
        emitter.particleSpeedRange = 120
        emitter.yAcceleration = -220
        emitter.xAcceleration = 8
        emitter.particleAlpha = 0.95
        emitter.particleAlphaRange = 0.1
        emitter.particleAlphaSpeed = -0.25
        emitter.particleScale = 0.55
        emitter.particleScaleRange = 0.25
        emitter.particleScaleSpeed = -0.15
        emitter.particleRotationRange = .pi
        emitter.particleRotationSpeed = 2.5
        emitter.particleColorSequence = SpinnerConfettiScene.colorSequence
        emitter.particleBlendMode = .alpha
        emitter.position = CGPoint(x: size.width / 2, y: size.height + 20)
        emitter.particlePositionRange = CGVector(dx: size.width * 1.4, dy: 0)
        emitter.targetNode = self
        addChild(emitter)
    }

    private func emitSolarBurst() {
        let emitter = SKEmitterNode()
        emitter.particleTexture = SpinnerConfettiScene.sparkTexture
        emitter.particleBirthRate = 120
        emitter.numParticlesToEmit = 80
        emitter.particleLifetime = 0.9
        emitter.particleSpeed = 180
        emitter.particleSpeedRange = 80
        emitter.emissionAngleRange = .pi * 2
        emitter.particleAlpha = 0.9
        emitter.particleAlphaSpeed = -0.9
        emitter.particleScale = 0.8
        emitter.particleScaleRange = 0.3
        emitter.particleScaleSpeed = -0.6
        emitter.particleColorSequence = SKKeyframeSequence(
            keyframeValues: [
                UIColor(displayP3Red: 1, green: 0.55, blue: 0.95, alpha: 0.95),
                UIColor(displayP3Red: 0.6, green: 0.72, blue: 1, alpha: 0.1)
            ],
            times: [0, 1]
        )
        emitter.particleBlendMode = .add
        emitter.position = CGPoint(x: size.width / 2, y: size.height / 2)
        emitter.targetNode = self
        addChild(emitter)
    }

    private static let confettiTextures: [SKTexture] = {
        func texture(size: CGSize, cornerRadius: CGFloat) -> SKTexture {
            let renderer = UIGraphicsImageRenderer(size: size)
            return SKTexture(image: renderer.image { context in
                UIColor.white.setFill()
                let rect = CGRect(origin: .zero, size: size)
                UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius).fill()
            })
        }
        return [
            texture(size: CGSize(width: 12, height: 16), cornerRadius: 3),
            texture(size: CGSize(width: 8, height: 24), cornerRadius: 2),
            texture(size: CGSize(width: 10, height: 10), cornerRadius: 5)
        ]
    }()

    private static let sparkTexture: SKTexture = {
        let size = CGSize(width: 12, height: 12)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: [
                    UIColor.white.cgColor,
                    UIColor(displayP3Red: 1, green: 0.5, blue: 0.9, alpha: 0).cgColor
                ] as CFArray,
                locations: [0, 1]
            )!
            ctx.cgContext.drawRadialGradient(
                gradient,
                startCenter: CGPoint(x: size.width / 2, y: size.height / 2),
                startRadius: 0,
                endCenter: CGPoint(x: size.width / 2, y: size.height / 2),
                endRadius: size.width / 2,
                options: .drawsAfterEndLocation
            )
        }
        return SKTexture(image: image)
    }()

    private static let colorSequence: SKKeyframeSequence = {
        let colors: [UIColor] = [
            UIColor(displayP3Red: 0.98, green: 0.32, blue: 0.76, alpha: 0.95),
            UIColor(displayP3Red: 0.45, green: 0.56, blue: 0.98, alpha: 0.95),
            UIColor(displayP3Red: 0.99, green: 0.81, blue: 0.45, alpha: 0.95),
            UIColor.white
        ]
        let times: [NSNumber] = [0, 0.35, 0.7, 1]
        return SKKeyframeSequence(keyframeValues: colors, times: times)
    }()
}
