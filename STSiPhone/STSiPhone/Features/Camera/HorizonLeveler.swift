import Foundation
import CoreMotion
import Combine
import UIKit

final class HorizonLeveler: ObservableObject {
    private let motion = CMMotionManager()
    private let queue = OperationQueue()

    @Published var roll: Double = 0.0
    @Published var isActive: Bool = false

    init() {
        setupMotion()
    }
    
    private func setupMotion() {
        motion.deviceMotionUpdateInterval = 0.05 // 20Hz updates for smooth animation
        queue.maxConcurrentOperationCount = 1
        queue.name = "HorizonLevelerQueue"
    }

    func start() {
        guard motion.isDeviceMotionAvailable && !motion.isDeviceMotionActive else { return }
        
        motion.startDeviceMotionUpdates(using: .xMagneticNorthZVertical, to: queue) { [weak self] data, error in
            guard let self = self else { return }
            
            if let error = error {
                print("Motion update error: \(error)")
                return
            }
            
            guard let attitude = data?.attitude else { return }
            
            DispatchQueue.main.async {
                // Get current device orientation
                let orientation = UIDevice.current.orientation
                var adjustedRoll: Double
                
                switch orientation {
                case .portrait:
                    adjustedRoll = attitude.roll
                case .portraitUpsideDown:
                    adjustedRoll = attitude.roll + .pi
                case .landscapeLeft:
                    adjustedRoll = attitude.pitch
                case .landscapeRight:
                    adjustedRoll = -attitude.pitch
                default:
                    adjustedRoll = attitude.roll
                }
                
                // Keep the level bar horizontal (negative because we want it to counter-rotate)
                self.roll = -adjustedRoll
                self.isActive = true
            }
        }
    }

    func stop() {
        motion.stopDeviceMotionUpdates()
        DispatchQueue.main.async {
            self.isActive = false
            self.roll = 0.0
        }
    }

    deinit {
        stop()
    }
}
