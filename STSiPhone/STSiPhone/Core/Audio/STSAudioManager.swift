import AVFoundation
import Foundation
import Combine

@MainActor
public final class STSAudioManager: NSObject, ObservableObject {
    public static let shared = STSAudioManager()

    // UI state
    @Published public private(set) var availableInputs: [AVAudioSessionPortDescription] = []
    @Published public private(set) var currentRouteSummary: String = "Unknown"
    @Published public private(set) var avgdB: Float = -60
    @Published public private(set) var peakdB: Float = -60
    @Published public private(set) var selectedInputUID: String?

    private let routing = STSAudioSubsystem.shared
    private var cancellables: Set<AnyCancellable> = []

    private override init() {
        super.init()
        routing.$availableInputs
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.availableInputs = $0 }
            .store(in: &cancellables)

        routing.$preferredInputUID
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.selectedInputUID = $0 }
            .store(in: &cancellables)

        routing.$currentRouteSummary
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.currentRouteSummary = $0 }
            .store(in: &cancellables)
    }

    // MARK: - Session setup
    public func configureSessionForCamera() throws {
        routing.configureForVideoCaptureIfNeeded()
        refreshInputs()
    }

    // MARK: - Inputs
    public func refreshInputs() {
        routing.refreshInputs()
    }

    public func selectInput(uid: String?) {
        selectedInputUID = uid
        do {
            try routing.setPreferredInput(uid: uid)
        } catch {
            print("⚠️ STSAudioManager selectInput failed: \(error)")
        }
    }

    // MARK: - Meter consume
    // Called by CameraEngine's audio sampleBuffer callback
    public func consumeAudioBuffer(_ buffer: CMSampleBuffer) {
        guard let block = CMSampleBufferGetDataBuffer(buffer) else { return }

        var length: Int = 0
        var dataPointer: UnsafeMutablePointer<Int8>?
        guard CMBlockBufferGetDataPointer(block, atOffset: 0, lengthAtOffsetOut: nil,
                                          totalLengthOut: &length, dataPointerOut: &dataPointer) == kCMBlockBufferNoErr,
              let ptr = dataPointer, length > 0 else { return }

        // Assume Int16 PCM is most common in capture; handle others gracefully
        let sampleCount = length / MemoryLayout<Int16>.size
        if sampleCount <= 0 { return }

        let rms: Float = ptr.withMemoryRebound(to: Int16.self, capacity: sampleCount) { p in
            var acc: Float = 0
            // Tight loop; good enough for 0.1s windows
            for i in 0..<sampleCount {
                let s = Float(p[i]) / Float(Int16.max)
                acc += s * s
            }
            return sqrt(acc / Float(sampleCount))
        }

        // Convert RMS to dBFS (clip at a sensible floor)
        let minRMS: Float = 1e-7
        let db = 20 * log10(max(rms, minRMS))

        // Simple peak with decay to look responsive
        let newPeak = max(db, peakdB - 0.6)

        DispatchQueue.main.async {
            self.avgdB = db
            self.peakdB = newPeak
        }
    }
}
