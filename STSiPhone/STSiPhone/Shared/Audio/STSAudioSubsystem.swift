import AVFoundation
import OSLog

/// Unified audio owner for capture: configures AVAudioSession and owns the single capture audio output.
final class STSAudioSubsystem: NSObject, ObservableObject, STSAudioRouting {
    static let shared = STSAudioSubsystem()

    private let log = Logger(subsystem: "com.rheirhome.STSiPhone", category: "STSAudioSubsystem")
    private static let preferredInputUIDKey = "sts.preferredAudioInputUID"

    private(set) var captureAudioOutput: AVCaptureAudioDataOutput?
    private(set) var isConfiguredForCapture = false
    private var activeCaptureClients = 0
    private var isApplyingPreferredInput = false

    @Published private(set) var availableInputs: [AVAudioSessionPortDescription] = []
    @Published private(set) var preferredInputUID: String? = UserDefaults.standard.string(forKey: STSAudioSubsystem.preferredInputUIDKey)
    @Published private(set) var activeInputUID: String?
    @Published private(set) var activeInputName: String = "Unknown"
    @Published private(set) var currentRouteSummary: String = "Unknown"
    @Published private(set) var isSelectionPendingApply: Bool = false

    private override init() {
        super.init()
        observeRouteChanges()
        refreshInputs()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Public API

    func beginCaptureSession() {
        activeCaptureClients += 1
        configureForVideoCaptureIfNeeded()
    }

    func endCaptureSession() {
        guard activeCaptureClients > 0 else { return }
        activeCaptureClients -= 1
        guard activeCaptureClients == 0 else { return }

        do {
#if DEBUG
            AudioSessionDiagnostics.snapshot("STSAudioSubsystem/deactivate/before")
#endif
            try AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
            log.info("🎙️ STSAudioSubsystem deactivated audio session")
#if DEBUG
            AudioSessionDiagnostics.snapshot("STSAudioSubsystem/deactivate/after")
#endif
        } catch {
            log.warning("setActive(false) failed: \(error.localizedDescription, privacy: .public)")
        }

        isConfiguredForCapture = false
        captureAudioOutput = nil
    }

    func configureForVideoCaptureIfNeeded() {
        let session = AVAudioSession.sharedInstance()

        if isConfiguredForCapture, isSessionCaptureReady(session) {
            return
        } else if isConfiguredForCapture {
            print("🎙️ STSAudioSubsystem: Re-applying capture audio session (drift detected). category=\(session.category.rawValue) mode=\(session.mode.rawValue) sampleRate=\(session.sampleRate) route=\(session.currentRoute)")
        }

        do {
#if DEBUG
            AudioSessionDiagnostics.snapshot("STSAudioSubsystem/configure/before")
#endif
            // Preferred category/mode for camera capture.
            do {
                try session.setCategory(.playAndRecord,
                                        mode: .videoRecording,
                                        options: [.defaultToSpeaker, .allowBluetoothHFP])
                log.info("🎙️ AudioSession category=playAndRecord mode=videoRecording options=[defaultToSpeaker, allowBluetoothHFP]")
            } catch {
                log.warning("setCategory with defaultToSpeaker+allowBluetoothHFP failed: \(error.localizedDescription, privacy: .public). Retrying without options.")
                try session.setCategory(.playAndRecord, mode: .videoRecording, options: [])
                log.info("🎙️ AudioSession category=playAndRecord mode=videoRecording options=[] (fallback)")
            }

            // Prefer 48 kHz capture; non-fatal if it fails.
            let preferredSampleRate: Double = 48_000
            do {
                try session.setPreferredSampleRate(preferredSampleRate)
            } catch {
                log.warning("setPreferredSampleRate(48k) failed: \(error.localizedDescription, privacy: .public)")
            }

            // Prefer stereo if available.
            let maxChannels = session.maximumInputNumberOfChannels
            if maxChannels >= 2 {
                try? session.setPreferredInputNumberOfChannels(2)
            } else if maxChannels == 1 {
                try? session.setPreferredInputNumberOfChannels(1)
            }

            do {
                try session.setActive(true, options: [.notifyOthersOnDeactivation])
            } catch {
                log.warning("setActive with notifyOthers failed: \(error.localizedDescription, privacy: .public). Retrying without options.")
                try session.setActive(true)
            }

            updateRouteInfo(session: session)
            isConfiguredForCapture = true
            log.info("🎙️ STSAudioSubsystem configured for video capture (48k, stereo if available)")
#if DEBUG
            AudioSessionDiagnostics.snapshot("STSAudioSubsystem/configure/after")
#endif
        } catch {
            log.fault("❌ Failed to configure AVAudioSession for capture: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Attaches the singleton capture audio output to the given session.
    func attachAudioCapture(to session: AVCaptureSession,
                            delegate: AVCaptureAudioDataOutputSampleBufferDelegate,
                            queue: DispatchQueue) {
        configureForVideoCaptureIfNeeded()

        if let existing = captureAudioOutput {
            session.removeOutput(existing)
            captureAudioOutput = nil
        }

        let audioOutput = AVCaptureAudioDataOutput()
        audioOutput.setSampleBufferDelegate(delegate, queue: queue)

        if session.canAddOutput(audioOutput) {
            session.addOutput(audioOutput)
            captureAudioOutput = audioOutput
            log.info("🎤 Attached unified AVCaptureAudioDataOutput to session")
        } else {
            log.fault("❌ Cannot add unified AVCaptureAudioDataOutput to session")
        }
    }

    // MARK: - Route changes

    private func observeRouteChanges() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleRouteChange(_:)),
                                               name: AVAudioSession.routeChangeNotification,
                                               object: nil)
    }

    @objc private func handleRouteChange(_ notification: Notification) {
        let session = AVAudioSession.sharedInstance()
        updateRouteInfo(session: session)

        if let reasonValue = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
           let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) {
            log.info("🔄 Audio route changed: reason=\(reason.rawValue)")
        }
        NotificationCenter.default.post(name: .stsAudioRouteDidChange, object: nil)
    }

    func refreshInputs() {
        let session = AVAudioSession.sharedInstance()
        updateRouteInfo(session: session)
    }

    func setPreferredInput(uid: String?) throws {
        configureForVideoCaptureIfNeeded()
        let session = AVAudioSession.sharedInstance()
        let currentPreferredUID = preferredInputUID
        let sessionPreferredUID = session.preferredInput?.uid
        if uid == currentPreferredUID, sessionPreferredUID == uid {
            return
        }
        let inputs = session.availableInputs ?? []
        let resolvedPort = uid.flatMap { target in inputs.first(where: { $0.uid == target }) }

        do {
            if let port = resolvedPort {
                try session.setPreferredInput(port)
            } else {
                try session.setPreferredInput(nil)
            }
        } catch {
            log.warning("setPreferredInput failed: \(error.localizedDescription, privacy: .public)")
            throw error
        }

        let newUID = uid
        UserDefaults.standard.set(newUID, forKey: STSAudioSubsystem.preferredInputUIDKey)
        publishOnMain { [weak self] in
            self?.preferredInputUID = newUID
        }
        NotificationCenter.default.post(name: .stsAudioPreferredInputDidChange, object: nil)
        updateRouteInfo(session: session)
    }

    func setSelectionPendingApply(_ pending: Bool) {
        publishOnMain { [weak self] in
            self?.isSelectionPendingApply = pending
        }
        NotificationCenter.default.post(name: .stsAudioPendingApplyDidChange, object: nil)
    }

    private func updateRouteInfo(session: AVAudioSession) {
        let route = session.currentRoute
        let activePort = route.inputs.first
        let inputsDesc = route.inputs
            .map { "\($0.portType.rawValue): \($0.portName)" }
            .joined(separator: ", ")
        let outputsDesc = route.outputs
            .map { "\($0.portType.rawValue): \($0.portName)" }
            .joined(separator: ", ")

        let inputs = session.availableInputs ?? []
        let availableDesc = inputs
            .map { "\($0.portType.rawValue): \($0.portName)" }
            .joined(separator: ", ")
        let preferredDesc = session.preferredInput?.portName ?? "nil"
        let pending = isSelectionPendingApply
        let preferredUID = preferredInputUID ?? "nil"

        log.info("[AudioRoute] inputs=[\(inputsDesc, privacy: .public)] outputs=[\(outputsDesc, privacy: .public)] available=[\(availableDesc, privacy: .public)] preferred=\(preferredDesc, privacy: .public)")
        log.info("[AudioRoute] sampleRate=\(session.sampleRate, privacy: .public) inputChannels=\(session.inputNumberOfChannels) outputChannels=\(session.outputNumberOfChannels)")
        log.info("[AudioRoute] active=\(activePort?.portName ?? "nil", privacy: .public) activeUID=\(activePort?.uid ?? "nil", privacy: .public) preferredUID=\(preferredUID, privacy: .public) pending=\(pending)")
        let activeName = activePort?.portName ?? "None"
        let activeUID = activePort?.uid
        let summary = "In: \(activeName)  •  Out: \(route.outputs.first?.portName ?? "None")"

        publishOnMain { [weak self] in
            guard let self else { return }
            self.availableInputs = inputs
            self.activeInputName = activeName
            self.activeInputUID = activeUID
            self.currentRouteSummary = summary
        }

        applyPreferredInputIfNeeded(session: session, availableInputs: inputs)
    }

    private func applyPreferredInputIfNeeded(session: AVAudioSession, availableInputs: [AVAudioSessionPortDescription]) {
        guard let preferredUID = preferredInputUID else { return }
        guard !isApplyingPreferredInput else { return }
        if session.preferredInput?.uid == preferredUID { return }
        guard let port = availableInputs.first(where: { $0.uid == preferredUID }) else { return }
        isApplyingPreferredInput = true
        do {
            try session.setPreferredInput(port)
        } catch {
            log.warning("applyPreferredInput failed: \(error.localizedDescription, privacy: .public)")
        }
        isApplyingPreferredInput = false
    }

    private func publishOnMain(_ block: @escaping () -> Void) {
        if Thread.isMainThread {
            block()
        } else {
            DispatchQueue.main.async(execute: block)
        }
    }

    private func isSessionCaptureReady(_ session: AVAudioSession) -> Bool {
        session.category == .playAndRecord && session.mode == .videoRecording
    }
}
