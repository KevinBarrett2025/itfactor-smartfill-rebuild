import Foundation
import AVFoundation

struct TorchBlinkSpec {
    let blinkCount: Int
    let onDuration: TimeInterval
    let offGap: TimeInterval
    let torchLevel: Float
}

final class TorchCueController {
    private let queue: DispatchQueue

    init(queue: DispatchQueue) {
        self.queue = queue
    }

    func blinkIfAvailable(device: AVCaptureDevice, spec: TorchBlinkSpec) {
        queue.async { [weak self] in
            self?.runBlinkSequence(device: device, spec: spec)
        }
    }

    func forceOff(device: AVCaptureDevice) {
        queue.async { [weak self] in
            self?.setTorchOff(device: device)
        }
    }

    private func runBlinkSequence(device: AVCaptureDevice, spec: TorchBlinkSpec) {
        guard device.hasTorch, device.isTorchModeSupported(.on) else { return }
        let blinkCount = max(0, spec.blinkCount)
        guard blinkCount > 0 else {
            setTorchOff(device: device)
            return
        }

        var delay: TimeInterval = 0
        for _ in 0..<blinkCount {
            schedule(delay: delay) { [weak self] in
                self?.setTorchOn(device: device, level: spec.torchLevel)
            }
            delay += spec.onDuration

            schedule(delay: delay) { [weak self] in
                self?.setTorchOff(device: device)
            }
            delay += spec.offGap
        }

        schedule(delay: delay) { [weak self] in
            self?.setTorchOff(device: device)
        }
    }

    private func schedule(delay: TimeInterval, _ action: @escaping () -> Void) {
        guard delay > 0 else {
            queue.async(execute: action)
            return
        }
        queue.asyncAfter(deadline: .now() + delay, execute: action)
    }

    private func setTorchOn(device: AVCaptureDevice, level: Float) {
        guard device.hasTorch, device.isTorchModeSupported(.on) else { return }
        do {
            try device.lockForConfiguration()
            defer { device.unlockForConfiguration() }
            let clampedLevel = max(0.1, min(level, 1.0))
            try device.setTorchModeOn(level: clampedLevel)
        } catch {
            print("⚠️ TorchCue: Failed to turn torch on: \(error)")
        }
    }

    private func setTorchOff(device: AVCaptureDevice) {
        guard device.hasTorch else { return }
        do {
            try device.lockForConfiguration()
            defer { device.unlockForConfiguration() }
            if device.torchMode != .off {
                device.torchMode = .off
            }
        } catch {
            print("⚠️ TorchCue: Failed to turn torch off: \(error)")
        }
    }
}
