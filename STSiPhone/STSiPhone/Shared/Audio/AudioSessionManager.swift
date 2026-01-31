import AVFoundation
import OSLog

/// Centralized AVAudioSession configuration for capture and playback paths.
/// Standardizes on 48 kHz stereo when hardware allows, mirroring Apple's camera behavior.
final class AudioSessionManager {
    static let shared = AudioSessionManager()

    private let log = Logger(subsystem: "com.rheirhome.STSiPhone", category: "AudioSession")

    private init() {}

    // MARK: - Capture Configuration (Video Recording)

    func configureForVideoCapture() throws {
        let session = AVAudioSession.sharedInstance()

        // Category & mode tuned for camera capture with Bluetooth support and speaker monitoring.
        do {
            try session.setCategory(.playAndRecord,
                                    mode: .videoRecording,
                                    options: [.defaultToSpeaker])
        } catch {
            // Fallback: category without options if speaker route fails
            try session.setCategory(.playAndRecord, mode: .videoRecording, options: [])
        }

        // Prefer video-standard sample rate.
        let preferredSampleRate: Double = 48_000
        try? session.setPreferredSampleRate(preferredSampleRate)

        // Try to get stereo capture if the hardware supports it.
        let maxChannels = session.maximumInputNumberOfChannels
        if maxChannels >= 2 {
            try? session.setPreferredInputNumberOfChannels(2)
        } else if maxChannels == 1 {
            try? session.setPreferredInputNumberOfChannels(1)
        }

        do {
            try session.setActive(true, options: [.notifyOthersOnDeactivation])
        } catch {
            // Last-resort activation without options
            try session.setActive(true)
        }

        logRouteInfo(prefix: "VideoCapture")
    }

    // MARK: - Playback / Preview

    func configureForPlayback() throws {
        let session = AVAudioSession.sharedInstance()

        try session.setCategory(.playback,
                                mode: .moviePlayback,
                                options: [.defaultToSpeaker])

        if session.maximumOutputNumberOfChannels >= 2 {
            try session.setPreferredOutputNumberOfChannels(2)
        }

        try session.setActive(true, options: [])

        logRouteInfo(prefix: "Playback")
    }

    // MARK: - Helpers

    private func logRouteInfo(prefix: String) {
        let session = AVAudioSession.sharedInstance()
        let route = session.currentRoute
        let inputsDesc = route.inputs
            .map { "\($0.portType.rawValue): \($0.portName)" }
            .joined(separator: ", ")
        let outputsDesc = route.outputs
            .map { "\($0.portType.rawValue): \($0.portName)" }
            .joined(separator: ", ")

        log.info("\(prefix, privacy: .public) audio route inputs=\(inputsDesc, privacy: .public) outputs=\(outputsDesc, privacy: .public)")
        log.info("sampleRate=\(session.sampleRate, privacy: .public) inputChannels=\(session.inputNumberOfChannels) outputChannels=\(session.outputNumberOfChannels)")
    }
}
