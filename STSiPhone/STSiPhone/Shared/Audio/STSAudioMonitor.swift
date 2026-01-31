import AVFoundation
import OSLog

/// AVAudioEngine-based level monitor. Does not add additional capture outputs.
final class STSAudioMonitor: NSObject {
    static let shared = STSAudioMonitor()

    private let log = Logger(subsystem: "com.rheirhome.STSiPhone", category: "STSAudioMonitor")
    private let engine = AVAudioEngine()
    private var isRunning = false

    /// Smoothed RMS level in approximate dBFS (-80...0)
    @objc dynamic private(set) var currentLevel: Float = -80.0

    private override init() {
        super.init()
    }

    func startMonitoring() {
        guard !isRunning else { return }

        let audioSession = AVAudioSession.sharedInstance()
#if DEBUG
        AudioSessionDiagnostics.snapshot("STSAudioMonitor/start/before")
#endif
        try? audioSession.setActive(true)
#if DEBUG
        AudioSessionDiagnostics.snapshot("STSAudioMonitor/start/after")
#endif

        let input = engine.inputNode
        let format = input.inputFormat(forBus: 0)

        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.process(buffer: buffer)
        }

        do {
            try engine.start()
            isRunning = true
            log.info("🎧 Audio monitor started")
        } catch {
            log.fault("❌ Failed to start audio monitor: \(error.localizedDescription, privacy: .public)")
        }
    }

    func stopMonitoring() {
        guard isRunning else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        isRunning = false
        log.info("🛑 Audio monitor stopped")
    }

    // MARK: - Processing

    private func process(buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }
        let channelCount = Int(buffer.format.channelCount)
        let frameLength = Int(buffer.frameLength)
        guard frameLength > 0, channelCount > 0 else { return }

        var rms: Float = 0.0
        for ch in 0..<channelCount {
            let samples = channelData[ch]
            var sum: Float = 0.0
            for i in 0..<frameLength {
                let s = samples[i]
                sum += s * s
            }
            rms += sum / Float(frameLength)
        }
        rms = sqrt(rms / Float(channelCount))

        var db = 20.0 * log10f(rms)
        if !db.isFinite { db = -80.0 }
        db = max(-80.0, min(0.0, db))

        DispatchQueue.main.async {
            self.currentLevel = db
        }
    }
}
