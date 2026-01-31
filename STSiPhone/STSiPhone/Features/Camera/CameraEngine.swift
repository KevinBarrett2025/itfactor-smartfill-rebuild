import AVFoundation
import UIKit
import ImageIO
import CoreMedia
import Combine

final class CameraEngine: NSObject, ObservableObject {
    enum EngineState {
        case idle, configuring, running, recording, capturing // Added capturing for photo mode
    }
    
    enum CameraPosition {
        case front, back
    }
    
    // NEW: Camera capture mode
    enum CameraMode {
        case video, photo
    }

    // NEW: Audio device types for external mic support
    enum AudioDeviceType {
        case builtin, wired, bluetooth, external
        
        var displayName: String {
            switch self {
            case .builtin: return "Built-in"
            case .wired: return "Wired"
            case .bluetooth: return "Bluetooth"
            case .external: return "External"
            }
        }
        
        var icon: String {
            switch self {
            case .builtin: return "iphone"
            case .wired: return "headphones"
            case .bluetooth: return "headphones.circle"
            case .external: return "mic.fill"
            }
        }
    }
    // CORE STATE - from proven working 744bbb3
    @Published private(set) var state: EngineState = .idle
    @Published private(set) var lastError: Error?
    
    // NEW: Current capture mode
    @Published private(set) var currentMode: CameraMode = .video

    // ENHANCED PROPERTIES - restored for professional controls
    @Published private(set) var currentZoomFactor: CGFloat = 1.0
    @Published private(set) var isFocusLocked: Bool = false
    @Published private(set) var isExposureLocked: Bool = false
    @Published private(set) var isWhiteBalanceLocked: Bool = false
    @Published private(set) var isAEAFLocked: Bool = false
    @Published private(set) var isAutoMode: Bool = true
    @Published private(set) var exposureValue: Float = 0.0
    @Published private(set) var temperatureValue: Float = 5000.0
    @Published private(set) var tintValue: Float = 0.0
    @Published private(set) var currentCameraPosition: CameraPosition = .back
    @Published private(set) var audioSource: String = "Built-in Microphone"
    @Published private(set) var audioLevel: Float = -60.0
    @Published private(set) var availableAudioDevices: [AVCaptureDevice] = []
    @Published private(set) var selectedAudioDevice: AVCaptureDevice?
    @Published private(set) var isExternalMicConnected: Bool = false
    @Published private(set) var audioDeviceType: AudioDeviceType = .builtin
    @Published private(set) var audioRouteNotice: String?
    @Published private(set) var recordingQuality: RecordingQuality = .standard1080
    @Published private(set) var isTorchAvailable: Bool = false
    private let enforcedFrameRate: Int32 = 30

    // NEW: Smart Fill orientation support
    @Published private(set) var currentOrientation: VideoOrientation = .landscape
    @Published private(set) var deviceOrientation: UIDeviceOrientation = .portrait

    // CORE AVFoundation - from proven working 744bbb3
    let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "sts.camera.session")
    private let sessionQueueKey = DispatchSpecificKey<Void>()
    private let torchCueController: TorchCueController

    private func runOnSessionQueue(_ work: @escaping () -> Void) {
        if DispatchQueue.getSpecific(key: sessionQueueKey) != nil {
            work()
        } else {
            sessionQueue.async {
                work()
            }
        }
    }
    
    @inline(__always)
    private func publishOnMain<T>(_ keyPath: ReferenceWritableKeyPath<CameraEngine, T>, _ value: T) {
        if Thread.isMainThread {
            self[keyPath: keyPath] = value
        } else {
            DispatchQueue.main.async { [weak self] in
                self?[keyPath: keyPath] = value
            }
        }
    }

    private func setState(_ newValue: EngineState) {
        publishOnMain(\.state, newValue)
    }

    private var idleTimerToken: IdleTimerController.Token?

    @MainActor
    private func setIdleTimerDisabled(_ disabled: Bool) {
        updateIdleTimerDisabled(disabled)
    }

    @MainActor
    private func updateIdleTimerDisabled(_ disabled: Bool) {
        if disabled {
            if idleTimerToken == nil {
                idleTimerToken = IdleTimerController.shared.acquire(reason: "CameraEngineRecording")
            }
        } else {
            idleTimerToken?.release()
            idleTimerToken = nil
        }
    }

    private func setLastError(_ error: Error?) {
        publishOnMain(\.lastError, error)
    }
    
    // MARK: - Quality Configuration
    func setRecordingQuality(_ quality: RecordingQuality) {
        // Update observable state on main
        publishOnMain(\.recordingQuality, quality)
        CameraSettings.recordingQuality = quality

        // Apply to capture session on the sessionQueue
        runOnSessionQueue { [weak self] in
            guard let self else { return }
            guard self.state == .idle || self.state == .running else {
                // Avoid changing preset mid-export or in invalid states
                return
            }

            self.session.beginConfiguration()

            let preset = quality.sessionPreset
            if self.session.canSetSessionPreset(preset) {
                self.session.sessionPreset = preset
            } else {
                // Graceful fallback if 4K isn't supported, etc.
                if self.session.canSetSessionPreset(.high) {
                    self.session.sessionPreset = .high
                }
            }

            self.session.commitConfiguration()
            self.enforceFrameRateLockIfPossible()
        }
    }
    
    // NEW: Writer-based pipeline (video + audio data outputs)
    private let writerQueue = DispatchQueue(label: "com.sts.camera.writer")
    private var videoDataOutput: AVCaptureVideoDataOutput?
    private var audioDataOutput: AVCaptureAudioDataOutput?
    private var assetWriter: AVAssetWriter?
    private var videoWriterInput: AVAssetWriterInput?
    private var audioWriterInput: AVAssetWriterInput?
    private var recordingStartTime: CMTime?
    @Published private(set) var isTrueStereoCapture: Bool = false
    private var loggedAudioFormat = false
    private var loggedVideoOrientationAttachment = false
    private var didTriggerTorchCue = false
    private let torchBlinkSpec = TorchBlinkSpec(blinkCount: 2, onDuration: 0.12, offGap: 0.10, torchLevel: 1.0)
    
    // NEW: Photo capture output

    // Audio monitoring observation
    private var monitorObservation: NSKeyValueObservation?
    private let photoOutput = AVCapturePhotoOutput()
    
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
    
    // PROFESSIONAL CONTROLS - Audio monitoring
    private var audioRouteObserver: NSObjectProtocol?
    
    // Orientation debounce
    private var orientationWorkItem: DispatchWorkItem?
    private let orientationDebounce: TimeInterval = 0.12
    
    // UPDATED: iOS 17+ rotation coordinator for modern orientation handling
    private var rotationCoordinator: AVCaptureDevice.RotationCoordinator?
    private var orientationObserver: NSObjectProtocol?
    private var settingsObserver: NSObjectProtocol?
    private let previewThumbnailer = PreviewThumbnailer()
    private var pendingAudioRewire = false
    private var pendingAudioRewireSignature: String?
    private var pendingAudioRefreshWorkItem: DispatchWorkItem?
    private var pendingAudioRefreshShouldNotify = false
    private var pendingAudioRefreshReason: String?
    private var isRewiringAudioInput = false
    private var lastAppliedAudioRouteSignature: String?
    private var lastAppliedActiveInputSignature: String?
    private var suppressAudioRouteNoticeUntil: CFAbsoluteTime = 0
    private let audioRefreshDebounce: TimeInterval = 0.35
#if DEBUG
    private var audioRefreshBurstStart: CFAbsoluteTime = 0
    private var audioRefreshBurstCount = 0
#endif
    private var audioRouteNoticeWorkItem: DispatchWorkItem?
    private var audioRoutingCancellables: Set<AnyCancellable> = []

    // Camera device reference for controls - FIXED: Ensure we only get VIDEO devices, not audio
    private var currentDevice: AVCaptureDevice? {
        return session.inputs.compactMap { $0 as? AVCaptureDeviceInput }
            .first(where: { $0.device.hasMediaType(.video) })?.device
    }
    
    // Audio device reference - Separate and specific for audio devices
    private var currentAudioDevice: AVCaptureDevice? {
        return session.inputs.compactMap { $0 as? AVCaptureDeviceInput }
            .first(where: { $0.device.hasMediaType(.audio) })?.device
    }

    // MARK: - Lifecycle - UPDATED: iOS 17+ rotation coordinator
    override init() {
        torchCueController = TorchCueController(queue: sessionQueue)
        super.init()
        print("🎛️ CameraEngine init – instance = \(ObjectIdentifier(self))")
        sessionQueue.setSpecific(key: sessionQueueKey, value: ())
        setupOrientationMonitoring()
        observeCameraSettings()
        observeAudioRouting()
        recordingQuality = CameraSettings.recordingQuality
    }
    
    deinit {
        print("🧹 CameraEngine deinit – instance = \(ObjectIdentifier(self))")
        stopOrientationMonitoring()
        if let observer = settingsObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        let token = idleTimerToken
        idleTimerToken = nil
        Task { @MainActor in
            token?.release()
        }
    }
    
    // UPDATED: iOS 17+ rotation coordinator setup
    private func setupOrientationMonitoring() {
        // Start device orientation notifications (fallback for older APIs)
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        
        orientationObserver = NotificationCenter.default.addObserver(
            forName: UIDevice.orientationDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateOrientation()
        }
        
        // NEW: Setup iOS 17+ rotation coordinator
        if let device = AVCaptureDevice.default(for: .video) {
            rotationCoordinator = AVCaptureDevice.RotationCoordinator(device: device, previewLayer: nil)
            print("✅ iOS 17+ rotation coordinator initialized")
        }
        
        // Initial orientation detection
        updateOrientation()
    }
    
    private func stopOrientationMonitoring() {
        UIDevice.current.endGeneratingDeviceOrientationNotifications()
        if let observer = orientationObserver {
            NotificationCenter.default.removeObserver(observer)
            orientationObserver = nil
        }
        
        // UPDATED: Clean up rotation coordinator
        rotationCoordinator = nil
    }

    private func observeCameraSettings() {
        settingsObserver = NotificationCenter.default.addObserver(
            forName: .cameraSettingsDidChange,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let shouldMirror = notification.userInfo?[CameraSettingsNotificationKeys.mirrorFrontCameraEnabled] as? Bool {
                CameraSettings.mirrorFrontCameraEnabled = shouldMirror
                self?.applyMirroringPreference()
            }
            if let qualityRaw = notification.userInfo?[CameraSettingsNotificationKeys.recordingQuality] as? String,
               let quality = RecordingQuality(rawValue: qualityRaw) {
                self?.setRecordingQuality(quality)
            }
        }
    }
    
    // UPDATED: Modern orientation detection using iOS 17+ APIs
    private func updateOrientation() {
        guard state != .recording else { return }
        let deviceOrientation = UIDevice.current.orientation
        self.deviceOrientation = deviceOrientation
        
        let videoOrientation: VideoOrientation
        switch deviceOrientation {
        case .portrait, .portraitUpsideDown:
            videoOrientation = .portrait
        case .landscapeLeft, .landscapeRight:
            videoOrientation = .landscape
        case .faceUp, .faceDown, .unknown:
            videoOrientation = currentOrientation
        @unknown default:
            videoOrientation = .landscape
        }
        
        guard videoOrientation != currentOrientation else { return }
        orientationWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            guard self.state != .recording else { return }
            self.publishOnMain(\.currentOrientation, videoOrientation)
            print("📱 Orientation changed to: \(videoOrientation.displayName)")
            self.applyCurrentOrientationToConnections()
        }
        orientationWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + orientationDebounce, execute: work)
    }
    
    // UPDATED: Apply orientation using iOS 17+ videoRotationAngle API
    private func applyCurrentOrientationToConnections() {
        let work = { [weak self] in
            guard let self else { return }
            // Do not mutate capture connections while actively recording video.
            guard self.state != .recording else { return }

            // This angle is used only for video diagnostics / writer alignment.
            let rotationAngle = self.rotationAngleFromDeviceOrientation(
                self.deviceOrientation,
                position: self.currentCameraPosition == .front ? .front : .back
            )

            if (self.videoDataOutput?.connection(with: .video)) != nil {
                // IMPORTANT: Do not rotate the data output; the writer transform is the single source of truth.
                if #available(iOS 17.0, *) {
                    print("ℹ️ Skipping rotation on videoDataOutput; writer transform handles video orientation. currentAngle=\(rotationAngle)")
                } else {
                    print("ℹ️ Skipping AVCaptureVideoOrientation on videoDataOutput; orientation handled via writer transform. currentAngle=\(rotationAngle)")
                }
            }

            // PHOTO OUTPUT – use a photo-specific mapping that does NOT apply the front 180° flip.
            if let photoConnection = self.photoOutput.connection(with: .video) {
                if #available(iOS 17.0, *) {
                    let photoAngle = self.photoRotationAngleFromDeviceOrientation(self.deviceOrientation)
                    if photoConnection.isVideoRotationAngleSupported(photoAngle) {
                        photoConnection.videoRotationAngle = photoAngle
                        print("✅ Applied photo rotation angle \(photoAngle)° (no front 180°) to photo output")
                    } else {
                        print("⚠️ photoOutput does NOT support rotation angle \(photoAngle)°")
                    }
                } else {
                    if photoConnection.isVideoOrientationSupported,
                       let orientation = self.avOrientation(from: self.deviceOrientation) {
                        photoConnection.videoOrientation = orientation
                        print("✅ Applied videoOrientation \(orientation.rawValue) to photo output")
                    } else {
                        print("⚠️ Could not map deviceOrientation=\(self.deviceOrientation.rawValue) to AVCaptureVideoOrientation for photo output")
                    }
                }
            }

            // Apply mirror preference after orientation so both are consistent.
            self.applyMirroringPreferenceLocked()
        }

        runOnSessionQueue(work)
    }
    
    private func applyMirroringPreferenceLocked() {
        let shouldMirror = CameraSettings.mirrorFrontCameraEnabled && currentCameraPosition == .front
        
        if let videoConnection = videoDataOutput?.connection(with: .video),
           videoConnection.isVideoMirroringSupported {
            videoConnection.automaticallyAdjustsVideoMirroring = false
            videoConnection.isVideoMirrored = shouldMirror
        }
        
        if let photoConnection = photoOutput.connection(with: .video),
           photoConnection.isVideoMirroringSupported {
            photoConnection.automaticallyAdjustsVideoMirroring = false
            photoConnection.isVideoMirrored = shouldMirror
        }
    }
    
    private func applyMirroringPreference() {
        runOnSessionQueue { [weak self] in
            self?.applyMirroringPreferenceLocked()
        }
    }
    
    // UPDATED: Convert device orientation to rotation angle for iOS 17+
    // Front camera applies a 180° offset so recorded output is upright.
    private func rotationAngleFromDeviceOrientation(_ orientation: UIDeviceOrientation, position: AVCaptureDevice.Position = .back) -> CGFloat {
        let baseAngle: CGFloat
        switch orientation {
        case .portrait:
            baseAngle = 90
        case .portraitUpsideDown:
            baseAngle = 270
        case .landscapeLeft:
            baseAngle = 0
        case .landscapeRight:
            baseAngle = 180
        default:
            baseAngle = 90
        }
        
        if position == .front {
            let adjusted = fmod(baseAngle + 180, 360)
            return adjusted < 0 ? adjusted + 360 : adjusted
        } else {
            return baseAngle
        }
    }

    /// Convert device orientation to a rotation angle specifically for *still photo* capture.
    /// Important:
    /// - This does *not* apply the 180° front-camera offset we use for the video writer.
    /// - Mirroring remains controlled by `applyMirroringPreferenceLocked()` via `isVideoMirrored`.
    private func photoRotationAngleFromDeviceOrientation(_ orientation: UIDeviceOrientation) -> CGFloat {
        switch orientation {
        case .portrait:
            return 90
        case .portraitUpsideDown:
            return 270
        case .landscapeLeft:
            return 0
        case .landscapeRight:
            return 180
        default:
            // Treat unknown / faceUp the same as portrait for stills.
            return 90
        }
    }

    /// Legacy helper for mapping device orientation to `AVCaptureVideoOrientation`.
    /// Deprecated in iOS 17 – retained for pre-iOS-17 configuration paths.
    @available(iOS, introduced: 11.0, deprecated: 17.0, message: "Use AVCaptureDeviceRotationCoordinator for iOS 17+")
    private func avOrientation(from deviceOrientation: UIDeviceOrientation) -> AVCaptureVideoOrientation? {
        switch deviceOrientation {
        case .portrait: return .portrait
        case .portraitUpsideDown: return .portraitUpsideDown
        case .landscapeLeft: return .landscapeRight // device left, home button right
        case .landscapeRight: return .landscapeLeft // device right, home button left
        default: return nil
        }
    }
    
    /// Rotation helper used for AVAssetWriter transform (based on logical video orientation)
    private func writerAngleDegrees(startingOrientation: VideoOrientation, cameraPosition: CameraPosition) -> CGFloat {
        let baseAngle: CGFloat
        switch startingOrientation {
        case .portrait:
            baseAngle = 90
        case .landscape:
            baseAngle = 0
        }
        if cameraPosition == .front {
            let adjusted = fmod(baseAngle + 180, 360)
            return adjusted < 0 ? adjusted + 360 : adjusted
        } else {
            return baseAngle
        }
    }

    // MARK: - iOS 16+ Format Configuration Helper
    
    /// Configure the best video format for modern iOS versions, replacing deprecated sessionPreset
    @available(iOS 16.0, *)
    private func configureBestFormat(for device: AVCaptureDevice) {
        do {
            try device.lockForConfiguration()
            
            // Find best format that supports 1920x1080 or higher at 30fps
            let baseFormats = device.formats
                .filter { format in
                    let dimensions = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
                    let width = Int(dimensions.width)
                    let height = Int(dimensions.height)
                    
                    // Look for formats with at least 1080p resolution
                    return width >= 1920 && height >= 1080
                }
                .filter { format in
                    // Ensure the format supports 30fps
                    format.videoSupportedFrameRateRanges.contains { range in
                        range.minFrameRate <= 30 && range.maxFrameRate >= 30
                    }
                }
                .sorted { lhs, rhs in
                    let lhsDims = CMVideoFormatDescriptionGetDimensions(lhs.formatDescription)
                    let rhsDims = CMVideoFormatDescriptionGetDimensions(rhs.formatDescription)
                    // Prefer larger resolutions, then higher max frame rate
                    if lhsDims.width != rhsDims.width {
                        return lhsDims.width > rhsDims.width
                    }
                    let lhsMax = lhs.videoSupportedFrameRateRanges.map { $0.maxFrameRate }.max() ?? 0
                    let rhsMax = rhs.videoSupportedFrameRateRanges.map { $0.maxFrameRate }.max() ?? 0
                    return lhsMax > rhsMax
                }
            
            let targetAspect: Double = 16.0 / 9.0
            let aspectTolerance: Double = 0.03
            let matchingAspectFormats = baseFormats.filter { format in
                let dims = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
                let ratio = Double(dims.width) / Double(dims.height)
                return abs(ratio - targetAspect) <= aspectTolerance
            }
            
            let prioritizedFormats: [AVCaptureDevice.Format]
            if !matchingAspectFormats.isEmpty {
                prioritizedFormats = matchingAspectFormats
            } else {
                prioritizedFormats = baseFormats
            }
            
            let sortedFormats = prioritizedFormats.sorted { lhs, rhs in
                let lhsDims = CMVideoFormatDescriptionGetDimensions(lhs.formatDescription)
                let rhsDims = CMVideoFormatDescriptionGetDimensions(rhs.formatDescription)
                let lhsRatioDiff = abs(Double(lhsDims.width) / Double(lhsDims.height) - targetAspect)
                let rhsRatioDiff = abs(Double(rhsDims.width) / Double(rhsDims.height) - targetAspect)
                
                if lhsRatioDiff != rhsRatioDiff {
                    return lhsRatioDiff < rhsRatioDiff
                }
                if lhsDims.width != rhsDims.width {
                    return lhsDims.width > rhsDims.width
                }
                if lhsDims.height != rhsDims.height {
                    return lhsDims.height > rhsDims.height
                }
                let lhsMax = lhs.videoSupportedFrameRateRanges.map { $0.maxFrameRate }.max() ?? 0
                let rhsMax = rhs.videoSupportedFrameRateRanges.map { $0.maxFrameRate }.max() ?? 0
                return lhsMax > rhsMax
            }
            
            if let bestFormat = sortedFormats.first {
                device.activeFormat = bestFormat
                
                // Set frame rate to 30fps for consistent recording
                device.activeVideoMinFrameDuration = CMTime(value: 1, timescale: 30)
                device.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: 30)
                
                let dimensions = CMVideoFormatDescriptionGetDimensions(bestFormat.formatDescription)
                let aspectText = String(format: "%.2f", Double(dimensions.width) / Double(dimensions.height))
                print("✅ Configured modern camera format: \(dimensions.width)x\(dimensions.height) @ 30fps (ratio \(aspectText))")
            } else {
                print("⚠️ No suitable 1080p+ format found, using default")
            }
            
            device.unlockForConfiguration()
        } catch {
            print("⚠️ Failed to configure camera format: \(error)")
            // Device will use default format
        }
    }

    func configureAndStart() {
        print("🎛️ configureAndStart called – state = \(state)")
        guard state == .idle else { return }
        setState(.configuring)

        runOnSessionQueue { [weak self] in
            guard let self else { return }
            // Align session preset with stored recording quality
            let preferredQuality = CameraSettings.recordingQuality
            publishOnMain(\.recordingQuality, preferredQuality)
            STSAudioSubsystem.shared.beginCaptureSession()
            self.session.beginConfiguration()

            let desiredPreset = preferredQuality.sessionPreset
            if self.session.canSetSessionPreset(desiredPreset) {
                self.session.sessionPreset = desiredPreset
                print("🎚️ CameraEngine: Using preset \(desiredPreset.rawValue) for quality \(preferredQuality.rawValue)")
            } else if self.session.canSetSessionPreset(.high) {
                self.session.sessionPreset = .high
                print("🎚️ CameraEngine: Falling back to .high for quality \(preferredQuality.rawValue)")
            }
            
            // MODERNIZED: Replace deprecated sessionPreset with format-based configuration for iOS 16+
            if #available(iOS 16.0, *) {
                // Use device format selection instead of session preset for modern iOS versions
                if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) {
                    self.configureBestFormat(for: device)
                    let dims = CMVideoFormatDescriptionGetDimensions(device.activeFormat.formatDescription)
                    print("🎚️ CameraEngine: Active format after configureBestFormat: \(dims.width)x\(dims.height)")
                }
            }

            // Inputs
            do {
                // Camera
                guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
                    throw NSError(domain: "STS.Camera", code: -1, userInfo: [NSLocalizedDescriptionKey: "No back camera"])
                }
                let videoInput = try AVCaptureDeviceInput(device: camera)
                if self.session.canAddInput(videoInput) {
                    self.session.addInput(videoInput)
                }

                // Audio
                if let mic = AVCaptureDevice.default(for: .audio) {
                    let audioInput = try AVCaptureDeviceInput(device: mic)
                    if self.session.canAddInput(audioInput) {
                        self.session.addInput(audioInput)
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.setLastError(error)
                    self.setState(.idle)
                }
                self.session.commitConfiguration()
                return
            }

            // Outputs - Data outputs for writer-based pipeline
            let videoOutput = AVCaptureVideoDataOutput()
            videoOutput.alwaysDiscardsLateVideoFrames = true
            videoOutput.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
            ]
            videoOutput.setSampleBufferDelegate(self, queue: self.writerQueue)
            if self.session.canAddOutput(videoOutput) {
                self.session.addOutput(videoOutput)
                if let connection = videoOutput.connection(with: .video) {
                    connection.preferredVideoStabilizationMode = .standard
                }
                self.videoDataOutput = videoOutput
            }

            STSAudioSubsystem.shared.attachAudioCapture(to: self.session,
                                                        delegate: self,
                                                        queue: self.writerQueue)
            self.audioDataOutput = STSAudioSubsystem.shared.captureAudioOutput
            
            // NEW: Add photo output for keyframe photo capture
            if self.session.canAddOutput(self.photoOutput) {
                self.session.addOutput(self.photoOutput)
                // Configure photo output for high quality - FIXED: Removed deprecated iOS 17 API
                // Modern iOS devices support high resolution capture by default
                if self.photoOutput.isLivePhotoCaptureSupported {
                    self.photoOutput.isLivePhotoCaptureEnabled = false // Disable Live Photos for faster capture
                }
            }

            self.session.commitConfiguration()
            self.enforceFrameRateLockIfPossible()
            self.session.startRunning()
            self.lastAppliedAudioRouteSignature = self.currentAudioRouteSignature()
            self.lastAppliedActiveInputSignature = self.currentActiveInputSignature()
            self.suppressAudioRouteNoticeUntil = CFAbsoluteTimeGetCurrent() + 0.8
            self.pendingAudioRewire = false
            self.pendingAudioRewireSignature = nil
            self.pendingAudioRefreshWorkItem?.cancel()
            self.pendingAudioRefreshWorkItem = nil
            self.pendingAudioRefreshShouldNotify = false
            self.pendingAudioRefreshReason = nil

            DispatchQueue.main.async {
                self.setState(.running)
                // SWIFT 6 FIX: Remove unused property initialization - avoid complex white balance queries
                self.initializeCameraProperties()
                self.syncLockStateFromCurrentDevice()
                self.updateAudioProperties()
                self.startAudioLevelMonitoring()
                
                // NEW: Setup external mic support
                self.setupAudioRouteMonitoring()
                self.discoverAudioDevices()
                
                // UPDATED: Apply initial orientation using iOS 17+ API
                self.updateOrientation()
                self.applyMirroringPreference()
            }
        }
    }

    func stopSession() {
        print("🛑 stopSession called – state = \(state)")
        stopAudioLevelMonitoring()
        cleanupAudioRouteMonitoring()
        forceTorchOff(reason: "stopSession")
        resetTorchCueTrigger(reason: "stopSession")
        STSAudioSubsystem.shared.setSelectionPendingApply(false)
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.pendingAudioRefreshWorkItem?.cancel()
            self.pendingAudioRefreshWorkItem = nil
            self.pendingAudioRefreshShouldNotify = false
            self.pendingAudioRefreshReason = nil
            self.pendingAudioRewire = false
            self.pendingAudioRewireSignature = nil
            self.lastAppliedAudioRouteSignature = nil
            self.lastAppliedActiveInputSignature = nil
            self.isRewiringAudioInput = false
            self.suppressAudioRouteNoticeUntil = 0
            if self.session.isRunning { self.session.stopRunning() }
            DispatchQueue.main.async { self.setState(.idle) }
        }
        STSAudioSubsystem.shared.endCaptureSession()
    }

    // MARK: - Audio Monitoring - Unified
    @MainActor
    func attachAudioMonitoring(_ manager: STSAudioManager? = nil) {
        // manager kept for API compatibility; unified monitor handles levels.
        _ = manager
        STSAudioMonitor.shared.startMonitoring()
    }

    // MARK: - Recording Helpers
    private func currentVideoDimensions() -> CGSize {
        if let format = currentDevice?.activeFormat {
            let dims = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
            let size = CGSize(width: Int(dims.width), height: Int(dims.height))
            print("📐 currentVideoDimensions from activeFormat: \(Int(size.width))x\(Int(size.height))")
            return size
        }

        let presetSize: CGSize
        switch session.sessionPreset {
        case .hd4K3840x2160:
            presetSize = CGSize(width: 3840, height: 2160)
        case .hd1920x1080:
            presetSize = CGSize(width: 1920, height: 1080)
        case .hd1280x720:
            presetSize = CGSize(width: 1280, height: 720)
        default:
            presetSize = CGSize(width: 1920, height: 1080)
        }
        print("📐 currentVideoDimensions from sessionPreset: \(Int(presetSize.width))x\(Int(presetSize.height))")
        return presetSize
    }
    
    private func enforceFrameRateLockIfPossible() {
        let desiredDuration = CMTime(value: 1, timescale: enforcedFrameRate)
        let targetFPS = Double(enforcedFrameRate)
        
        let videoInputs = session.inputs.compactMap { $0 as? AVCaptureDeviceInput }
            .filter { $0.device.hasMediaType(.video) }
        
        for input in videoInputs {
            let device = input.device
            do {
                try device.lockForConfiguration()
                let supportsTargetFPS = device.activeFormat.videoSupportedFrameRateRanges.contains { range in
                    range.minFrameRate <= targetFPS && targetFPS <= range.maxFrameRate
                }
                
                if supportsTargetFPS {
                    if device.activeVideoMinFrameDuration != desiredDuration || device.activeVideoMaxFrameDuration != desiredDuration {
                        device.activeVideoMinFrameDuration = desiredDuration
                        device.activeVideoMaxFrameDuration = desiredDuration
                        print("🎯 FrameLock: \(device.position == .front ? "front" : "back") camera locked to \(targetFPS)fps")
                    }
                } else {
                    if let range = device.activeFormat.videoSupportedFrameRateRanges.first {
                        print("⚠️ FrameLock: \(device.localizedName) does not support \(targetFPS)fps (range \(range.minFrameRate)-\(range.maxFrameRate))")
                    } else {
                        print("⚠️ FrameLock: \(device.localizedName) has no frame rate range information")
                    }
                }
                
                device.unlockForConfiguration()
            } catch {
                print("⚠️ FrameLock: Unable to lock \(device.localizedName) for configuration: \(error)")
            }
        }
        
        if videoDataOutput != nil {
            print("🎯 FrameLock: Video data output aligned with device 30fps lock")
        }
    }

    private func targetBitrate(for dimensions: CGSize) -> Int {
        let fps: Double = 30.0
        let largestSide = max(dimensions.width, dimensions.height)

        let bitsPerPixel: Double
        if largestSide >= 3800 {
            bitsPerPixel = 0.12 // 4K-friendly
        } else if largestSide >= 1900 {
            bitsPerPixel = 0.08 // 1080p default
        } else {
            bitsPerPixel = 0.05 // 720p fallback
        }

        let bitrate = Double(dimensions.width * dimensions.height) * fps * bitsPerPixel
        return Int(max(2_000_000, min(bitrate, 50_000_000)))
    }

    // MARK: - Recording - UPDATED: Modern orientation tracking
    func startRecording() {
        resetTorchCueTrigger(reason: "startRecording")
        guard state == .running, assetWriter == nil else { return }
        let s = AVAudioSession.sharedInstance()
        print("🎙️ CameraEngine startRecording audioSession: category=\(s.category.rawValue) mode=\(s.mode.rawValue) sampleRate=\(s.sampleRate) IOBuffer=\(s.ioBufferDuration) route=\(s.currentRoute)")
#if DEBUG
        let audioInputs = session.inputs.compactMap { $0 as? AVCaptureDeviceInput }
            .filter { $0.device.hasMediaType(.audio) }
            .map { $0.device.localizedName }
            .joined(separator: ", ")
        print("[CameraEngineAudio] capture inputs=[\(audioInputs)]")
#endif
        
        backgroundTaskID = UIApplication.shared.beginBackgroundTask(withName: "STSRecording")
        let url = Self.makeOutputURL()
        let startingOrientation = currentOrientation
        let startingDeviceOrientation = deviceOrientation
        
        loggedVideoOrientationAttachment = false
        writerQueue.async { [weak self] in
            guard let self else { return }
            var didSetupWriter = false
            do {
                let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
                self.assetWriter = writer
                self.recordingStartTime = nil
                self.loggedAudioFormat = false
                self.publishOnMain(\.isTrueStereoCapture, false)
                
                // Video settings derived from current preset
                let dims = self.currentVideoDimensions()
                print("🎥 Writer: target dimensions \(Int(dims.width))x\(Int(dims.height)) at quality \(self.recordingQuality.rawValue)")
                
                let colorProperties: [String: Any] = [
                    AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
                    AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
                    AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2
                ]
                
                let videoSettings: [String: Any] = [
                    AVVideoCodecKey: AVVideoCodecType.h264,
                    AVVideoWidthKey: NSNumber(value: Int(dims.width)),
                    AVVideoHeightKey: NSNumber(value: Int(dims.height)),
                    AVVideoCompressionPropertiesKey: [
                        AVVideoAverageBitRateKey: NSNumber(value: self.targetBitrate(for: dims)),
                        AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel
                    ],
                    AVVideoColorPropertiesKey: colorProperties
                ]
                let vInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
                vInput.expectsMediaDataInRealTime = true
                
                // Apply orientation transform so recordings are encoded upright.
                // Front vs back cameras may need different angles, hence the writer helper.
                let angleDegrees = self.writerAngleDegrees(
                    startingOrientation: startingOrientation,
                    cameraPosition: self.currentCameraPosition
                )
                let angleRadians = angleDegrees * .pi / 180
                vInput.transform = CGAffineTransform(rotationAngle: angleRadians)
                
                print("🎬 Writer transform set.",
                      "captureOrientation=\(startingOrientation.displayName),",
                      "deviceOrientation=\(startingDeviceOrientation.rawValue),",
                      "camera=\(self.currentCameraPosition == .front ? "front" : "back"),",
                      "writerAngleDegrees=\(angleDegrees)")
                
                let audioBitrate = AudioSettings.quality.audioBitrate
                print("🎙️ Writer: audio bitrate \(audioBitrate) (quality: \(AudioSettings.quality.rawValue))")
                let audioSettings: [String: Any] = [
                    AVFormatIDKey: kAudioFormatMPEG4AAC,
                    AVSampleRateKey: 48_000,
                    AVNumberOfChannelsKey: 2, // force stereo
                    AVEncoderBitRateKey: audioBitrate
                ]
                let aInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
                aInput.expectsMediaDataInRealTime = true
                
                if writer.canAdd(vInput) { writer.add(vInput); self.videoWriterInput = vInput }
                if writer.canAdd(aInput) { writer.add(aInput); self.audioWriterInput = aInput }
                didSetupWriter = (self.assetWriter != nil && self.videoWriterInput != nil)
                if !didSetupWriter {
                    print("❌ Failed to attach writer inputs. video=\(self.videoWriterInput != nil) audio=\(self.audioWriterInput != nil)")
                    self.assetWriter = nil
                    self.videoWriterInput = nil
                    self.audioWriterInput = nil
                }
            } catch {
                print("❌ Failed to start writer: \(error)")
                self.assetWriter = nil
            }
            
            Task { @MainActor in
                if didSetupWriter {
                    self.setIdleTimerDisabled(true)
                    self.setState(.recording)
                    print("🎬 Recording started with orientation: \(startingOrientation.displayName) (device: \(startingDeviceOrientation.rawValue))")
                } else {
                    if self.backgroundTaskID != .invalid {
                        UIApplication.shared.endBackgroundTask(self.backgroundTaskID)
                        self.backgroundTaskID = .invalid
                    }
                    self.setIdleTimerDisabled(false)
                    self.setState(.running)
                }
            }
        }
    }

    func stopRecording() {
        Task { @MainActor [weak self] in
            self?.setIdleTimerDisabled(false)
        }
        forceTorchOff(reason: "stopRecording-request")
        resetTorchCueTrigger(reason: "stopRecording-request")
        writerQueue.async { [weak self] in
            guard let self else { return }
            guard let writer = self.assetWriter else { return }

            // Prevent re-entrancy: nil-out writer + inputs so subsequent calls bail.
            let videoInput = self.videoWriterInput
            let audioInput = self.audioWriterInput
            self.assetWriter = nil
            self.videoWriterInput = nil
            self.audioWriterInput = nil

            videoInput?.markAsFinished()
            audioInput?.markAsFinished()
            writer.finishWriting { [weak self] in
                guard let self else { return }
                if self.backgroundTaskID != .invalid {
                    UIApplication.shared.endBackgroundTask(self.backgroundTaskID)
                    self.backgroundTaskID = .invalid
                }
                self.forceTorchOff(reason: "stopRecording-complete")
                self.resetTorchCueTrigger(reason: "stopRecording-complete")
                
                DispatchQueue.main.async {
                    self.setState(.running)
                    self.handleRecordedFile(at: writer.outputURL)
                }
                self.applyPendingAudioRewireIfNeeded(reason: "stopRecording")
            }
        }
        print("🎬 Recording stopped")
    }

    private static func makeOutputURL() -> URL {
        let directory = FileManager.default.temporaryDirectory
        let filename = "STS_\(UUID().uuidString).mp4"
        return directory.appendingPathComponent(filename)
    }
    
    // MARK: - Camera Controls - Full Professional Implementation with Device Capability Checking
    func setFocus(at point: CGPoint) {
        guard let device = currentDevice else { return }
        sessionQueue.async {
            do {
                try device.lockForConfiguration()
                if device.isFocusPointOfInterestSupported {
                    device.focusPointOfInterest = point
                    if device.isFocusModeSupported(.continuousAutoFocus) {
                        device.focusMode = .continuousAutoFocus
                    } else if device.isFocusModeSupported(.autoFocus) {
                        device.focusMode = .autoFocus
                    }
                }
                if device.isExposurePointOfInterestSupported {
                    device.exposurePointOfInterest = point
                    if device.isExposureModeSupported(.continuousAutoExposure) {
                        device.exposureMode = .continuousAutoExposure
                    } else if device.isExposureModeSupported(.autoExpose) {
                        device.exposureMode = .autoExpose
                    }
                }
                device.unlockForConfiguration()
            } catch {
                print("Focus config error: \(error)")
                DispatchQueue.main.async { self.setLastError(error) }
            }
        }
    }

    func lockFocusAndExposure(at point: CGPoint) {
        guard !point.x.isNaN, !point.y.isNaN,
              let device = currentDevice else { return }
        let clampedPoint = CGPoint(
            x: max(0, min(1, point.x)),
            y: max(0, min(1, point.y))
        )

        sessionQueue.async { [weak self] in
            guard let self else { return }
            do {
                try device.lockForConfiguration()

                // Disable subject-area monitoring while locked to prevent auto adjustments.
                if device.isSubjectAreaChangeMonitoringEnabled {
                    device.isSubjectAreaChangeMonitoringEnabled = false
                }

                if device.isFocusPointOfInterestSupported {
                    device.focusPointOfInterest = clampedPoint
                    if device.isFocusModeSupported(.autoFocus) {
                        device.focusMode = .autoFocus
                    } else if device.isFocusModeSupported(.continuousAutoFocus) {
                        device.focusMode = .continuousAutoFocus
                    }
                    if device.isFocusModeSupported(.locked) {
                        device.focusMode = .locked
                    }
                }

                if device.isExposurePointOfInterestSupported {
                    device.exposurePointOfInterest = clampedPoint
                    if device.isExposureModeSupported(.autoExpose) {
                        device.exposureMode = .autoExpose
                    } else if device.isExposureModeSupported(.continuousAutoExposure) {
                        device.exposureMode = .continuousAutoExposure
                    }
                    if device.isExposureModeSupported(.locked) {
                        device.exposureMode = .locked
                    }
                }

                let focusLocked = device.focusMode == .locked
                let exposureLocked = device.exposureMode == .locked
                let lockedBias = device.exposureTargetBias
                device.unlockForConfiguration()

                DispatchQueue.main.async {
                    self.isFocusLocked = focusLocked
                    self.isExposureLocked = exposureLocked
                    self.isAEAFLocked = focusLocked || exposureLocked
                    self.isAutoMode = false
                    if !lockedBias.isNaN && !lockedBias.isInfinite {
                        self.exposureValue = lockedBias
                    }
                }
            } catch {
                print("⚠️ AE/AF lock error: \(error)")
                DispatchQueue.main.async {
                    self.isFocusLocked = false
                    self.isExposureLocked = false
                    self.isAEAFLocked = false
                    self.setLastError(error)
                }
            }
        }
    }

    func lockAEAFPoint(at point: CGPoint) {
        guard !point.x.isNaN, !point.y.isNaN,
              let device = currentDevice else { return }
        let clampedPoint = CGPoint(
            x: max(0, min(1, point.x)),
            y: max(0, min(1, point.y))
        )

        sessionQueue.async { [weak self] in
            guard let self else { return }
            do {
                try device.lockForConfiguration()

                // Disable subject-area change monitoring while user has explicitly set a point.
                device.isSubjectAreaChangeMonitoringEnabled = false

                if device.isFocusPointOfInterestSupported {
                    device.focusPointOfInterest = clampedPoint
                    if device.isFocusModeSupported(.continuousAutoFocus) {
                        device.focusMode = .continuousAutoFocus
                    } else if device.isFocusModeSupported(.autoFocus) {
                        device.focusMode = .autoFocus
                    }
                }

                if device.isExposurePointOfInterestSupported {
                    device.exposurePointOfInterest = clampedPoint
                    if device.isExposureModeSupported(.continuousAutoExposure) {
                        device.exposureMode = .continuousAutoExposure
                    } else if device.isExposureModeSupported(.autoExpose) {
                        device.exposureMode = .autoExpose
                    }
                }

                let currentBias = device.exposureTargetBias
                device.unlockForConfiguration()

                DispatchQueue.main.async {
                    self.isAEAFLocked = true
                    self.isFocusLocked = false
                    self.isExposureLocked = false
                    if !currentBias.isNaN && !currentBias.isInfinite {
                        self.exposureValue = currentBias
                    }
                    self.isAutoMode = abs(self.exposureValue) < 0.0001
                }
            } catch {
                print("⚠️ AE/AF point-lock error: \(error)")
                DispatchQueue.main.async {
                    self.isAEAFLocked = false
                    self.isFocusLocked = false
                    self.isExposureLocked = false
                    self.setLastError(error)
                }
            }
        }
    }

    func unlockAEAF() {
        guard let device = currentDevice else { return }
        sessionQueue.async { [weak self] in
            guard let self else { return }
            do {
                try device.lockForConfiguration()
                device.isSubjectAreaChangeMonitoringEnabled = true
                if device.isFocusModeSupported(.continuousAutoFocus) {
                    device.focusMode = .continuousAutoFocus
                } else if device.isFocusModeSupported(.autoFocus) {
                    device.focusMode = .autoFocus
                }
                if device.isExposureModeSupported(.continuousAutoExposure) {
                    device.exposureMode = .continuousAutoExposure
                } else if device.isExposureModeSupported(.autoExpose) {
                    device.exposureMode = .autoExpose
                }
                device.unlockForConfiguration()
                DispatchQueue.main.async {
                    self.isFocusLocked = false
                    self.isExposureLocked = false
                    self.isAEAFLocked = false
                    self.isAutoMode = abs(self.exposureValue) < 0.0001
                }
            } catch {
                print("⚠️ AE/AF unlock error: \(error)")
                DispatchQueue.main.async {
                    self.isFocusLocked = false
                    self.isExposureLocked = false
                    self.isAEAFLocked = false
                    self.isAutoMode = abs(self.exposureValue) < 0.0001
                }
            }
        }
    }

    func setZoom(factor: CGFloat) {
        guard let device = currentDevice else { return }
        sessionQueue.async {
            do {
                try device.lockForConfiguration()
                let maxZoom = min(device.activeFormat.videoMaxZoomFactor, 5.0)
                let zoom = max(1.0, min(factor, maxZoom))
                device.videoZoomFactor = zoom
                device.unlockForConfiguration()
                
                DispatchQueue.main.async {
                    self.currentZoomFactor = zoom
                }
            } catch {
                print("Zoom config error: \(error)")
            }
        }
    }

    // PROFESSIONAL EXPOSURE CONTROL - FIXED: Attempt direct control with graceful fallback (Apple's recommended approach)
    func setExposure(compensation: Float) {
        guard let device = currentDevice else { return }
        
        // FIXED: Enhanced NaN protection for exposure values
        guard !compensation.isNaN && !compensation.isInfinite else {
            print("⚠️ Invalid exposure compensation value: \(compensation)")
            return
        }
        
        // Modern iPhones support exposure controls on both cameras, so attempt directly
        
        sessionQueue.async {
            do {
                try device.lockForConfiguration()
                let clampedValue = max(device.minExposureTargetBias, min(device.maxExposureTargetBias, compensation))
                
                // FIXED: Additional validation before setting
                guard !clampedValue.isNaN && !clampedValue.isInfinite else {
                    print("⚠️ Clamped exposure value is invalid: \(clampedValue)")
                    device.unlockForConfiguration()
                    return
                }
                
                device.setExposureTargetBias(clampedValue) { _ in }
                device.unlockForConfiguration()
                
                DispatchQueue.main.async {
                    self.exposureValue = clampedValue
                    let autoCandidate = abs(clampedValue) < 0.0001 && self.isAEAFLocked == false && self.isExposureLocked == false
                    self.isAutoMode = autoCandidate
                }
                print("✅ Exposure set successfully on \(self.currentCameraPosition) camera: \(clampedValue)")
            } catch {
                print("⚠️ Exposure config error on \(self.currentCameraPosition) camera: \(error)")
                // Don't treat this as a fatal error - just log and continue
            }
        }
    }
    
    // FIXED: Enhanced white balance - attempt direct control with graceful fallback
    func setWhiteBalance(temperature: Float, tint: Float) {
        guard let device = currentDevice else { return }
        
        // FIXED: Enhanced validation and safe ranges
        let safeTemp = max(3000.0, min(8000.0, temperature)) // Safe temperature range
        let safeTint = max(-150.0, min(150.0, tint)) // Safe tint range
        
        guard !safeTemp.isNaN && !safeTemp.isInfinite &&
              !safeTint.isNaN && !safeTint.isInfinite else {
            print("⚠️ Invalid white balance values - temp: \(temperature), tint: \(tint)")
            return
        }
        
        sessionQueue.async {
            do {
                try device.lockForConfiguration()
                
                // FIXED: Use safe gain calculation method
                let redGain: Float = 2000.0 / safeTemp
                let blueGain: Float = safeTemp / 2000.0
                let greenGain: Float = 1.0 + (safeTint / 100.0)
                
                // Ensure gains are within valid device limits
                let maxGain = device.maxWhiteBalanceGain
                let minGain: Float = 1.0
                
                let normalizedGains = AVCaptureDevice.WhiteBalanceGains(
                    redGain: max(minGain, min(redGain, maxGain)),
                    greenGain: max(minGain, min(greenGain, maxGain)),
                    blueGain: max(minGain, min(blueGain, maxGain))
                )
                
                // Final validation of normalized gains
                guard normalizedGains.redGain >= minGain && normalizedGains.redGain <= maxGain &&
                      normalizedGains.greenGain >= minGain && normalizedGains.greenGain <= maxGain &&
                      normalizedGains.blueGain >= minGain && normalizedGains.blueGain <= maxGain else {
                    print("⚠️ Calculated gains are out of range")
                    device.unlockForConfiguration()
                    return
                }
                
                device.setWhiteBalanceModeLocked(with: normalizedGains) { _ in }
                device.unlockForConfiguration()
                
                DispatchQueue.main.async {
                    self.temperatureValue = safeTemp
                    self.tintValue = safeTint
                    self.isWhiteBalanceLocked = true
                }
                print("✅ White balance set successfully on \(self.currentCameraPosition) camera: temp=\(safeTemp), tint=\(safeTint)")
            } catch {
                print("⚠️ White balance config error on \(self.currentCameraPosition) camera: \(error)")
                // Graceful fallback - reset to auto mode
                do {
                    try device.lockForConfiguration()
                    device.whiteBalanceMode = .continuousAutoWhiteBalance
                    device.unlockForConfiguration()
                    DispatchQueue.main.async {
                        self.isWhiteBalanceLocked = false
                        print("🔄 Fell back to auto white balance on \(self.currentCameraPosition) camera")
                    }
                } catch {
                    print("⚠️ Could not set auto white balance: \(error)")
                }
            }
        }
    }
    
    func toggleExposureLock() {
        guard let device = currentDevice else { return }
        
        sessionQueue.async {
            do {
                try device.lockForConfiguration()
                if device.exposureMode == .locked {
                    device.exposureMode = .continuousAutoExposure
                    device.isSubjectAreaChangeMonitoringEnabled = true
                    DispatchQueue.main.async {
                        self.isExposureLocked = false
                        self.isAEAFLocked = self.isFocusLocked
                        self.isAutoMode = self.isFocusLocked == false && self.exposureValue == 0
                        print("🔓 Exposure unlocked on \(self.currentCameraPosition) camera")
                    }
                } else {
                    device.exposureMode = .locked
                    device.isSubjectAreaChangeMonitoringEnabled = false
                    DispatchQueue.main.async {
                        self.isExposureLocked = true
                        self.isAutoMode = false
                        self.isAEAFLocked = true
                        print("🔒 Exposure locked on \(self.currentCameraPosition) camera")
                    }
                }
                device.unlockForConfiguration()
            } catch {
                print("⚠️ Exposure lock toggle error on \(self.currentCameraPosition) camera: \(error)")
            }
        }
    }
    
    func toggleWhiteBalanceLock() {
        guard let device = currentDevice else { return }
        
        sessionQueue.async {
            do {
                try device.lockForConfiguration()
                if device.whiteBalanceMode == .locked {
                    device.whiteBalanceMode = .continuousAutoWhiteBalance
                    DispatchQueue.main.async {
                        self.isWhiteBalanceLocked = false
                        print("🔓 White balance unlocked on \(self.currentCameraPosition) camera")
                    }
                } else {
                    device.whiteBalanceMode = .locked
                    DispatchQueue.main.async {
                        self.isWhiteBalanceLocked = true
                        print("🔒 White balance locked on \(self.currentCameraPosition) camera")
                    }
                }
                device.unlockForConfiguration()
            } catch {
                print("⚠️ White balance lock toggle error on \(self.currentCameraPosition) camera: \(error)")
            }
        }
    }

    func unlockExposure() {
        runOnSessionQueue { [weak self] in
            guard let self else { return }
            guard let device = self.currentDevice else { return }
            
            do {
                try device.lockForConfiguration()
                device.exposureMode = .continuousAutoExposure
                device.isSubjectAreaChangeMonitoringEnabled = true
                device.unlockForConfiguration()
                DispatchQueue.main.async {
                    self.isExposureLocked = false
                    self.isAEAFLocked = self.isFocusLocked
                    self.isAutoMode = self.isFocusLocked == false && self.exposureValue == 0
                }
                print("✅ Exposure unlocked on \(self.currentCameraPosition) camera")
            } catch {
                print("⚠️ Failed to unlock exposure on \(self.currentCameraPosition) camera: \(error)")
            }
        }
    }

    func unlockWhiteBalance() {
        runOnSessionQueue { [weak self] in
            guard let self else { return }
            guard let device = self.currentDevice else { return }
            
            do {
                try device.lockForConfiguration()
                device.whiteBalanceMode = .continuousAutoWhiteBalance
                device.unlockForConfiguration()
                DispatchQueue.main.async {
                    self.isWhiteBalanceLocked = false
                }
                print("✅ White balance unlocked on \(self.currentCameraPosition) camera")
            } catch {
                print("⚠️ Failed to unlock white balance on \(self.currentCameraPosition) camera: \(error)")
            }
        }
    }
    
    // ENHANCED: Auto-correct method - attempt controls on both cameras
    func autoCorrectCamera() {
        runOnSessionQueue { [weak self] in
            guard let self else { return }
            guard let device = self.currentDevice else { return }
            
            do {
                try device.lockForConfiguration()
                
                // Reset exposure to auto
                device.exposureMode = .continuousAutoExposure
                if device.exposureTargetBias != 0 {
                    device.setExposureTargetBias(0) { _ in
                        print("🎥 Auto-correct: Exposure bias reset to 0 on \(self.currentCameraPosition) camera")
                    }
                }
                
                // Reset white balance to auto
                device.whiteBalanceMode = .continuousAutoWhiteBalance
                device.isSubjectAreaChangeMonitoringEnabled = true
                
                device.unlockForConfiguration()
                
                // Update our stored values to reflect the auto settings
                DispatchQueue.main.async {
                    self.exposureValue = 0.0
                    self.temperatureValue = 5500.0 // Default daylight temperature
                    self.tintValue = 0.0
                    self.isFocusLocked = false
                    self.isExposureLocked = false
                    self.isWhiteBalanceLocked = false
                    self.isAEAFLocked = false
                    self.isAutoMode = true
                }
                
                print("✅ Auto-correct applied successfully on \(self.currentCameraPosition) camera")
                
            } catch {
                print("⚠️ Auto-correct failed on \(self.currentCameraPosition) camera: \(error)")
            }
        }
    }
    
    // ENHANCED: Camera switching functionality - ENHANCED: Better device management and error handling
    func switchCamera() {
        guard state == .running else { return }
        
        let targetPosition: AVCaptureDevice.Position = (currentCameraPosition == .back) ? .front : .back
        let newCameraPosition: CameraPosition = (currentCameraPosition == .back) ? .front : .back
        
        print("🎥 Attempting to switch from \(currentCameraPosition) to \(newCameraPosition) camera")
        
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            self.session.beginConfiguration()
            
            // CRITICAL FIX: Find and remove ONLY the video input, preserve audio input
            let videoInput = self.session.inputs.compactMap { $0 as? AVCaptureDeviceInput }
                .first(where: { $0.device.hasMediaType(.video) })
            
            // SWIFT 6 FIX: Remove unused audioInput variable
            _ = self.session.inputs.compactMap { $0 as? AVCaptureDeviceInput }
                .first(where: { $0.device.hasMediaType(.audio) })
            
            // Remove only the video input, keep audio input
            if let currentVideoInput = videoInput {
                self.session.removeInput(currentVideoInput)
                print("🔄 Removed video input: \(currentVideoInput.device.localizedName)")
            }
            
            // Add new camera input
            do {
                // SWIFT 6 FIX: Use device availability check instead of unused guard let
                guard AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: targetPosition) != nil else {
                    // Fallback: re-add the previous video camera if new camera fails
                    if let previousVideoInput = videoInput {
                        if self.session.canAddInput(previousVideoInput) {
                            self.session.addInput(previousVideoInput)
                            print("🔄 Restored previous video input after failure")
                        }
                    }
                    self.session.commitConfiguration()
                    print("❌ Failed to find camera for position: \(targetPosition)")
                    return
                }
                
                let newCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: targetPosition)!
                let newVideoInput = try AVCaptureDeviceInput(device: newCamera)
                
                if self.session.canAddInput(newVideoInput) {
                    self.session.addInput(newVideoInput)
                    print("✅ Added new video input: \(newCamera.localizedName)")
                    
                    if #available(iOS 16.0, *) {
                        self.configureBestFormat(for: newCamera)
                    }
                    
                    // Update video stabilization for the new connection
                    if let connection = self.videoDataOutput?.connection(with: .video) {
                        connection.preferredVideoStabilizationMode = .standard
                    }
                    
                    self.session.commitConfiguration()
                    self.enforceFrameRateLockIfPossible()
                    
                    // Verify we have the correct device before updating properties
                    let verifyDevice = self.session.inputs.compactMap { $0 as? AVCaptureDeviceInput }
                        .first(where: { $0.device.hasMediaType(.video) })?.device
                    
                    print("🔍 Verification - Current video device: \(verifyDevice?.localizedName ?? "None")")
                    
                    // CRITICAL: Update properties on main thread with enhanced safety
                    DispatchQueue.main.async {
                        self.currentCameraPosition = newCameraPosition
                        // Reset zoom when switching cameras
                        self.currentZoomFactor = 1.0
                        
                        // ENHANCED: Reset to safe defaults before re-initializing
                        self.exposureValue = 0.0
                        self.temperatureValue = 5000.0
                        self.tintValue = 0.0
                        self.isFocusLocked = false
                        self.isExposureLocked = false
                        self.isWhiteBalanceLocked = false
                        self.isAEAFLocked = false
                        self.isAutoMode = true
                        
                        // Re-initialize camera properties for new device with capability checking
                        self.initializeCameraProperties()
                        self.syncLockStateFromCurrentDevice()
                        
                        // UPDATED: Apply current orientation to new camera connections
                        self.applyCurrentOrientationToConnections()
                        self.applyMirroringPreference()
                        
                        // Log capabilities for debugging
                        self.logDeviceCapabilities()
                    }
                    
                    print("✅ Camera switched to: \(newCameraPosition)")
                    
                } else {
                    // Fallback: re-add the previous video camera
                    if let previousVideoInput = videoInput {
                        if self.session.canAddInput(previousVideoInput) {
                            self.session.addInput(previousVideoInput)
                            print("🔄 Restored previous video input - cannot add new input")
                        }
                    }
                    self.session.commitConfiguration()
                    print("❌ Cannot add new camera input")
                }
                
            } catch {
                // Fallback: re-add the previous video camera
                if let previousVideoInput = videoInput {
                    if self.session.canAddInput(previousVideoInput) {
                        self.session.addInput(previousVideoInput)
                        print("🔄 Restored previous video input after error")
                    }
                }
                self.session.commitConfiguration()
                print("❌ Error creating camera input: \(error)")
                DispatchQueue.main.async {
                    self.setLastError(error)
                }
            }
        }
    }
    
    // MARK: - Camera Mode Management - NEW: Professional mode switching
    
    func switchToVideoMode() {
        guard currentMode != .video else { return }
        currentMode = .video
        print("🎥 Switched to video capture mode")
    }
    
    func switchToPhotoMode() {
        guard currentMode != .photo else { return }
        currentMode = .photo
        print("📸 Switched to photo capture mode")
    }
    
    // NEW: Photo capture method - ENHANCED: Orientation capture support
    func capturePhoto() {
        guard currentMode == .photo && state == .running else {
            print("⚠️ Cannot capture photo - wrong mode or state")
            return
        }
        
        guard photoOutput.connection(with: .video) != nil else {
            print("⚠️ No photo output connection available")
            return
        }
        
        // Set state to capturing during photo processing
        setState(.capturing)
        
        // Configure photo settings using modern API - FIXED: Removed deprecated iOS 17 API
        let photoSettings = AVCapturePhotoSettings()
        
        // Modern iOS devices capture high resolution by default
        // No need to explicitly enable - this is now handled automatically
        
        // Disable flash for self-tape consistency
        if photoOutput.supportedFlashModes.contains(.off) {
            photoSettings.flashMode = .off
        }
        
        // Capture the photo
        photoOutput.capturePhoto(with: photoSettings, delegate: self)
        
        print("📸 Photo capture initiated with orientation: \(currentOrientation.displayName)")
    }
    
    // Check if photo capture is available
    var canCapturePhoto: Bool {
        return currentMode == .photo && state == .running && photoOutput.connection(with: .video) != nil
    }
    
    // Check if video recording is available
    var canRecordVideo: Bool {
        return currentMode == .video && state == .running && assetWriter == nil
    }
    
    // MARK: - Device Capability Helpers - FIXED: More realistic capability detection
    
    /// Check if current camera device supports manual exposure controls
    /// Note: Due to iOS bugs, we assume modern devices support exposure controls and handle errors gracefully
    var supportsManualExposure: Bool {
        // SWIFT 6 FIX: Use boolean test instead of unused binding
        guard currentDevice != nil else { return false }
        // Modern iPhones support exposure controls on both cameras, despite what isExposureModeSupported reports
        return true // Assume support and handle errors gracefully in actual usage
    }
    
    /// Check if current camera device supports manual white balance controls
    /// Note: Due to iOS bugs, we assume modern devices support WB controls and handle errors gracefully
    var supportsManualWhiteBalance: Bool {
        // SWIFT 6 FIX: Use boolean test instead of unused binding
        guard currentDevice != nil else { return false }
        // Modern iPhones support white balance controls on both cameras
        return true // Assume support and handle errors gracefully in actual usage
    }
    
    /// Check if current camera device supports focus controls
    var supportsFocusControl: Bool {
        guard let device = currentDevice else { return false }
        return device.isFocusPointOfInterestSupported && device.isFocusModeSupported(.autoFocus)
    }
    
    /// Get a summary of current device capabilities for debugging
    func logDeviceCapabilities() {
        guard let device = currentDevice else {
            print("⚠️ No current device to check capabilities")
            return
        }
        
        print("📱 Device Capabilities for \(currentCameraPosition) camera:")
        print("   - Model: \(device.localizedName)")
        print("   - isExposureModeSupported(.locked): \(device.isExposureModeSupported(.locked))")
        print("   - isExposureModeSupported(.continuousAutoExposure): \(device.isExposureModeSupported(.continuousAutoExposure))")
        print("   - isWhiteBalanceModeSupported(.locked): \(device.isWhiteBalanceModeSupported(.locked))")
        print("   - isWhiteBalanceModeSupported(.continuousAutoWhiteBalance): \(device.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance))")
        print("   - Focus Control: \(supportsFocusControl)")
        print("   - Max Zoom: \(device.activeFormat.videoMaxZoomFactor)")
        print("   - Exposure Range: \(device.minExposureTargetBias) to \(device.maxExposureTargetBias)")
        print("   - Note: We attempt controls regardless of isSupported results due to iOS bugs")
    }

    // MARK: - Audio Device Management - External Mic Support

    private func currentAudioRouteSignature() -> String {
        let session = AVAudioSession.sharedInstance()
        let inputs = session.currentRoute.inputs
            .map { "\($0.uid):\($0.portType.rawValue)" }
            .sorted()
            .joined(separator: "|")
        let preferred = STSAudioSubsystem.shared.preferredInputUID ?? "nil"
        return "inputs=\(inputs)|preferred=\(preferred)"
    }

    private func currentActiveInputSignature() -> String {
        let session = AVAudioSession.sharedInstance()
        return session.currentRoute.inputs
            .map { "\($0.uid):\($0.portType.rawValue)" }
            .sorted()
            .joined(separator: "|")
    }

    private func currentActiveMicName() -> String {
        let session = AVAudioSession.sharedInstance()
        return session.currentRoute.inputs.first?.portName ?? "Microphone"
    }

    private func shouldSuppressAudioRouteNotice() -> Bool {
        CFAbsoluteTimeGetCurrent() < suppressAudioRouteNoticeUntil
    }

#if DEBUG
    private func noteAudioRefreshBurstIfNeeded(reason: String) {
        let now = CFAbsoluteTimeGetCurrent()
        if now - audioRefreshBurstStart > 2.0 {
            audioRefreshBurstStart = now
            audioRefreshBurstCount = 0
        }
        audioRefreshBurstCount += 1
        if audioRefreshBurstCount > 3 {
            print("[CameraPreview] audioRefresh burst >3/2s reason=\(reason) count=\(audioRefreshBurstCount)")
        }
    }
#endif

    private func scheduleAudioRefresh(reason: String, allowNotice: Bool) {
        runOnSessionQueue { [weak self] in
            guard let self else { return }
            guard self.state != .idle && self.state != .configuring else { return }

            let signature = self.currentAudioRouteSignature()
            if signature == self.lastAppliedAudioRouteSignature {
#if DEBUG
                print("[CameraPreview] audioRefresh skipped (same signature) reason=\(reason)")
#endif
                return
            }

            self.pendingAudioRefreshWorkItem?.cancel()
            self.pendingAudioRefreshShouldNotify = self.pendingAudioRefreshShouldNotify || allowNotice
            self.pendingAudioRefreshReason = reason
            let workItem = DispatchWorkItem { [weak self] in
                guard let self else { return }
                let shouldNotify = self.pendingAudioRefreshShouldNotify
                let effectiveReason = self.pendingAudioRefreshReason ?? reason
                self.pendingAudioRefreshShouldNotify = false
                self.pendingAudioRefreshReason = nil
                self.pendingAudioRefreshWorkItem = nil
                self.refreshAudioInput(reason: effectiveReason, allowNotice: shouldNotify)
            }
            self.pendingAudioRefreshWorkItem = workItem
            self.sessionQueue.asyncAfter(deadline: .now() + self.audioRefreshDebounce, execute: workItem)
#if DEBUG
            print("[CameraPreview] audioRefresh scheduled reason=\(reason)")
#endif
        }
    }

    private func emitAudioRouteNotice(_ message: String, duration: TimeInterval = 2.0) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.audioRouteNoticeWorkItem?.cancel()
            self.audioRouteNotice = message
            let workItem = DispatchWorkItem { [weak self] in
                self?.audioRouteNotice = nil
            }
            self.audioRouteNoticeWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: workItem)
        }
    }

    private func applyPendingAudioRewireIfNeeded(reason: String) {
        runOnSessionQueue { [weak self] in
            guard let self else { return }
            guard self.pendingAudioRewire else { return }
            self.pendingAudioRewire = false
            self.pendingAudioRewireSignature = nil
            STSAudioSubsystem.shared.setSelectionPendingApply(false)
            self.performAudioRewire(reason: reason, allowNotice: false)
        }
    }

    private func refreshAudioInput(reason: String, allowNotice: Bool) {
        runOnSessionQueue { [weak self] in
            guard let self else { return }
            guard self.state != .idle && self.state != .configuring else { return }

            let signature = self.currentAudioRouteSignature()
            if signature == self.lastAppliedAudioRouteSignature {
#if DEBUG
                print("[CameraPreview] audioRefresh skipped (same signature) reason=\(reason)")
#endif
                return
            }
            let noticeAllowed = allowNotice && (!reason.hasPrefix("routeChange:") || !self.shouldSuppressAudioRouteNotice())
#if DEBUG
            let pending = STSAudioSubsystem.shared.isSelectionPendingApply
            print("[CameraPreview] audioRefresh ready reason=\(reason) state=\(self.state) pending=\(pending) signature=\(signature)")
#endif
            if self.state == .recording {
                if self.pendingAudioRewireSignature != signature {
                    self.pendingAudioRewireSignature = signature
                    self.pendingAudioRewire = true
                    STSAudioSubsystem.shared.setSelectionPendingApply(true)
                    if noticeAllowed {
                        self.emitAudioRouteNotice("Mic changed — applies next take")
                    }
#if DEBUG
                    print("[CameraPreview] audioRefresh deferred (recording) reason=\(reason) signature=\(signature)")
#endif
                }
                return
            }
            self.performAudioRewire(reason: reason, allowNotice: allowNotice)
        }
    }

    private func performAudioRewire(reason: String, allowNotice: Bool) {
        if isRewiringAudioInput {
#if DEBUG
            print("[CameraPreview] audioRefresh skipped (rewire in progress) reason=\(reason)")
#endif
            return
        }
        isRewiringAudioInput = true
        defer { isRewiringAudioInput = false }

        STSAudioSubsystem.shared.configureForVideoCaptureIfNeeded()
        let signatureBefore = currentAudioRouteSignature()
        if signatureBefore == lastAppliedAudioRouteSignature {
#if DEBUG
            print("[CameraPreview] audioRefresh skipped (same signature) reason=\(reason)")
#endif
            return
        }
        session.beginConfiguration()

        let currentAudioInputs = session.inputs.compactMap { $0 as? AVCaptureDeviceInput }
            .filter { $0.device.hasMediaType(.audio) }

        for input in currentAudioInputs {
            session.removeInput(input)
        }

        var didAttach = false
        if let device = AVCaptureDevice.default(for: .audio) {
            do {
                let audioInput = try AVCaptureDeviceInput(device: device)
                if session.canAddInput(audioInput) {
                    session.addInput(audioInput)
                    didAttach = true
                }
            } catch {
#if DEBUG
                print("[CameraEngineAudio] rewire failed reason=\(reason) error=\(error)")
#endif
            }
        }

        session.commitConfiguration()

        let appliedSignature = currentAudioRouteSignature()
        let activeSignature = currentActiveInputSignature()
        let previousActiveSignature = lastAppliedActiveInputSignature
        lastAppliedAudioRouteSignature = appliedSignature
        lastAppliedActiveInputSignature = activeSignature
        let noticeAllowed = allowNotice && (!reason.hasPrefix("routeChange:") || !shouldSuppressAudioRouteNotice())

        if didAttach {
            pendingAudioRewire = false
            pendingAudioRewireSignature = nil
            if noticeAllowed, activeSignature != previousActiveSignature {
                emitAudioRouteNotice("Mic: \(currentActiveMicName())")
            }
        }
        STSAudioSubsystem.shared.setSelectionPendingApply(false)

#if DEBUG
        noteAudioRefreshBurstIfNeeded(reason: reason)
        let inputsDesc = session.inputs.compactMap { $0 as? AVCaptureDeviceInput }
            .filter { $0.device.hasMediaType(.audio) }
            .map { $0.device.localizedName }
            .joined(separator: ", ")
        print("[CameraPreview] audioRefresh APPLY reason=\(reason) signature=\(appliedSignature) inputs=[\(inputsDesc)]")
#endif

        DispatchQueue.main.async { [weak self] in
            self?.updateAudioProperties()
            self?.discoverAudioDevices()
        }
    }
    
    /// Discover and enumerate all available audio input devices
    func discoverAudioDevices() {
        let session = AVAudioSession.sharedInstance()
        
        // Get all available audio inputs
        if let inputs = session.availableInputs {
            // Convert AVAudioSessionPortDescription to AVCaptureDevice equivalents
            var devices: [AVCaptureDevice] = []
            var detectedTypes: Set<AudioDeviceType> = []
            
            for input in inputs {
                if let device = AVCaptureDevice.default(for: .audio) {
                    devices.append(device)
                    
                    // Classify device type based on port description
                    let deviceType = classifyAudioDevice(input)
                    detectedTypes.insert(deviceType)
                    
                    print("📱 Discovered audio device: \(input.portName) (\(deviceType.displayName))")
                }
            }
            
            DispatchQueue.main.async {
                self.availableAudioDevices = devices
                self.isExternalMicConnected = detectedTypes.contains(.wired) || detectedTypes.contains(.bluetooth)
                
                // Update selected device if none is set
                if self.selectedAudioDevice == nil {
                    self.selectedAudioDevice = devices.first
                    if let device = devices.first {
                        self.updateAudioDeviceInfo(device)
                    }
                }
            }
        }
    }
    
    /// Classify audio device type based on port description
    private func classifyAudioDevice(_ port: AVAudioSessionPortDescription) -> AudioDeviceType {
        switch port.portType {
        case .builtInMic:
            return .builtin
        case .headsetMic, .headphones:
            return .wired
        case .bluetoothA2DP, .bluetoothHFP, .bluetoothLE:
            return .bluetooth
        case .usbAudio:
            return .external
        default:
            return .external
        }
    }
    
    /// Switch to a specific audio device
    func switchToAudioDevice(_ device: AVCaptureDevice) {
        guard state == .running else { return }
        
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            self.session.beginConfiguration()
            
            // Remove current audio input
            let currentAudioInput = self.session.inputs.compactMap { $0 as? AVCaptureDeviceInput }
                .first(where: { $0.device.hasMediaType(.audio) })
            
            if let audioInput = currentAudioInput {
                self.session.removeInput(audioInput)
                print("🎤 Removed audio input: \(audioInput.device.localizedName)")
            }
            
            // Add new audio input
            do {
                let newAudioInput = try AVCaptureDeviceInput(device: device)
                if self.session.canAddInput(newAudioInput) {
                    self.session.addInput(newAudioInput)
                    print("✅ Added new audio input: \(device.localizedName)")
                    
                    self.session.commitConfiguration()
                    
                    DispatchQueue.main.async {
                        self.selectedAudioDevice = device
                        self.updateAudioDeviceInfo(device)
                    }
                } else {
                    // Restore previous input if adding new one fails
                    if let previousInput = currentAudioInput, self.session.canAddInput(previousInput) {
                        self.session.addInput(previousInput)
                    }
                    self.session.commitConfiguration()
                    print("❌ Cannot add new audio input")
                }
            } catch {
                // Restore previous input on error
                if let previousInput = currentAudioInput, self.session.canAddInput(previousInput) {
                    self.session.addInput(previousInput)
                }
                self.session.commitConfiguration()
                print("❌ Error switching audio device: \(error)")
            }
        }
    }
    
    /// Update audio device information and type classification
    private func updateAudioDeviceInfo(_ device: AVCaptureDevice) {
        DispatchQueue.main.async {
            self.publishOnMain(\.audioSource, device.localizedName)
            
            // Classify device type based on name patterns (fallback method)
            if device.localizedName.lowercased().contains("bluetooth") {
                self.publishOnMain(\.audioDeviceType, .bluetooth)
            } else if device.localizedName.lowercased().contains("headset") || device.localizedName.lowercased().contains("headphone") {
                self.publishOnMain(\.audioDeviceType, .wired)
            } else if device.localizedName.lowercased().contains("built-in") {
                self.publishOnMain(\.audioDeviceType, .builtin)
            } else {
                self.publishOnMain(\.audioDeviceType, .external)
            }
            
            print("🎤 Audio device updated: \(self.audioSource) (\(self.audioDeviceType.displayName))")
        }
    }
    
    /// Setup audio route change monitoring
    private func setupAudioRouteMonitoring() {
        audioRouteObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleAudioRouteChange(notification)
        }
    }
    
    /// Handle audio route changes (device connect/disconnect)
    private func handleAudioRouteChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }

#if DEBUG
        let session = AVAudioSession.sharedInstance()
        let newRoute = session.currentRoute
        let newInputs = newRoute.inputs.map { "\($0.portType.rawValue):\($0.portName)" }.joined(separator: ",")
        let newOutputs = newRoute.outputs.map { "\($0.portType.rawValue):\($0.portName)" }.joined(separator: ",")
        let availableInputs = (session.availableInputs ?? [])
            .map { "\($0.portType.rawValue):\($0.portName)" }
            .joined(separator: ",")
        let preferredInput = session.preferredInput?.portName ?? "nil"
        let prevRoute = (userInfo[AVAudioSessionRouteChangePreviousRouteKey] as? AVAudioSessionRouteDescription)
        let prevInputs = prevRoute?.inputs.map { "\($0.portType.rawValue):\($0.portName)" }.joined(separator: ",") ?? "nil"
        let prevOutputs = prevRoute?.outputs.map { "\($0.portType.rawValue):\($0.portName)" }.joined(separator: ",") ?? "nil"
        print("[AudioRoute] reason=\(reason.rawValue) prevIn=[\(prevInputs)] prevOut=[\(prevOutputs)] newIn=[\(newInputs)] newOut=[\(newOutputs)] available=[\(availableInputs)] preferred=\(preferredInput)")
#endif
        
        switch reason {
        case .newDeviceAvailable:
            print("🎤 New audio device connected")
            discoverAudioDevices()
            scheduleAudioRefresh(reason: "routeChange:newDeviceAvailable", allowNotice: true)
        case .oldDeviceUnavailable:
            print("🎤 Audio device disconnected")
            discoverAudioDevices()
            scheduleAudioRefresh(reason: "routeChange:oldDeviceUnavailable", allowNotice: true)
        case .routeConfigurationChange:
            scheduleAudioRefresh(reason: "routeChange:routeConfigurationChange", allowNotice: false)
        default:
            break
        }
    }
    
    /// Cleanup audio route monitoring
    private func cleanupAudioRouteMonitoring() {
        if let observer = audioRouteObserver {
            NotificationCenter.default.removeObserver(observer)
            audioRouteObserver = nil
        }
    }

    // MARK: - Audio Level Monitoring - Unified Monitor
    private func startAudioLevelMonitoring() {
        stopAudioLevelMonitoring()
        monitorObservation = STSAudioMonitor.shared.observe(\.currentLevel, options: [.initial, .new]) { [weak self] monitor, _ in
            let level = monitor.currentLevel
            DispatchQueue.main.async {
                self?.publishOnMain(\.audioLevel, level)
            }
        }
        STSAudioMonitor.shared.startMonitoring()
    }
    
    private func stopAudioLevelMonitoring() {
        monitorObservation?.invalidate()
        monitorObservation = nil
        STSAudioMonitor.shared.stopMonitoring()
    }

    private func observeAudioRouting() {
        STSAudioSubsystem.shared.$preferredInputUID
            .removeDuplicates()
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.scheduleAudioRefresh(reason: "preferredInputChanged", allowNotice: true)
            }
            .store(in: &audioRoutingCancellables)
    }
    
    // MARK: - Property Updates - FIXED: Attempt to read actual device state with graceful fallbacks
    private func initializeCameraProperties() {
        guard let device = currentDevice else { return }
        
        // Always safe to read zoom factor
        currentZoomFactor = device.videoZoomFactor
        
                // Attempt to read exposure/focus properties - these don't throw, so no do-catch needed
                let exposureLocked = device.exposureMode == .locked
                let focusLocked = device.focusMode == .locked
                isExposureLocked = exposureLocked
                isFocusLocked = focusLocked
                isAEAFLocked = exposureLocked || focusLocked
                exposureValue = device.exposureTargetBias
                isAutoMode = !(exposureLocked || focusLocked) && exposureValue == 0
                print("✅ Read exposure properties for \(currentCameraPosition) camera: locked=\(exposureLocked), value=\(exposureValue)")
        
        // Attempt to read white balance properties - these don't throw, so no do-catch needed
        isWhiteBalanceLocked = device.whiteBalanceMode == .locked
        print("✅ Read white balance properties for \(currentCameraPosition) camera: locked=\(isWhiteBalanceLocked)")
        
        // Use safe default values for temperature/tint - these are UI-only values anyway
        temperatureValue = 5000.0 // Standard daylight temperature
        tintValue = 0.0 // Neutral tint
        
        print("✅ Camera properties initialized for \(currentCameraPosition) camera - attempting all controls")
    }
    
    private func updateAudioProperties() {
        DispatchQueue.main.async {
            if let audioDevice = self.currentAudioDevice {
                self.publishOnMain(\.audioSource, audioDevice.localizedName)
            } else {
                self.publishOnMain(\.audioSource, "Built-in Microphone")
            }
        }
    }

    private func syncLockStateFromCurrentDevice() {
        runOnSessionQueue { [weak self] in
            guard let self else { return }
            guard let device = self.currentDevice else {
                DispatchQueue.main.async {
                    self.isTorchAvailable = false
                }
                return
            }
            let focusLocked = device.focusMode == .locked
            let exposureLocked = device.exposureMode == .locked
            let torchAvailable = device.hasTorch && device.isTorchModeSupported(.on)
            DispatchQueue.main.async {
                self.isFocusLocked = focusLocked
                self.isExposureLocked = exposureLocked
                self.isAEAFLocked = focusLocked || exposureLocked
                self.isTorchAvailable = torchAvailable
            }
        }
    }

    private func resetTorchCueTrigger(reason: String) {
        _ = reason
        writerQueue.async { [weak self] in
            self?.didTriggerTorchCue = false
        }
    }

    private func triggerTorchCueIfNeeded() {
        if didTriggerTorchCue { return }
        didTriggerTorchCue = true
        runOnSessionQueue { [weak self] in
            guard let self else { return }
            guard CameraSettings.recordBlinkTorchEnabled else { return }
            guard let device = self.currentDevice else { return }
            guard device.position == .back else { return }
            self.torchCueController.blinkIfAvailable(device: device, spec: self.torchBlinkSpec)
        }
    }

    func forceTorchOff(reason: String) {
        _ = reason
        runOnSessionQueue { [weak self] in
            guard let self else { return }
            guard let device = self.currentDevice else { return }
            self.torchCueController.forceOff(device: device)
        }
    }
}

// MARK: - AVCaptureFileOutputRecordingDelegate - UPDATED: iOS 17+ orientation tracking
// MARK: - File Persistence - ENHANCED: Orientation metadata
extension CameraEngine {
    private func handleRecordedFile(at sourceURL: URL) {
        // Verify source file exists before attempting move
        guard FileManager.default.fileExists(atPath: sourceURL.path) else {
            print("❌ Source file doesn't exist: \(sourceURL.path)")
            self.setLastError(NSError(domain: "STS.FileSystem", code: -1,
                                   userInfo: [NSLocalizedDescriptionKey: "Recorded file not found"]))
            return
        }
        
        // Get file size for logging
        let fileSize = (try? FileManager.default.attributesOfItem(atPath: sourceURL.path)[.size] as? Int) ?? 0
        let fileSizeMB = Double(fileSize) / 1024 / 1024
        
        print("✅ Source file verified: \(sourceURL.path) (Size: \(String(format: "%.2f", fileSizeMB)) MB)")
        print("📱 Recorded with orientation: \(currentOrientation.displayName)")
        
        // Post notification with the verified temp file URL and orientation metadata
        NotificationCenter.default.post(
            name: .stsDidRecordFile,
            object: nil,
            userInfo: [
                "url": sourceURL,
                "fileSize": fileSize,
                "verified": true,
                "capturedOrientation": currentOrientation,  // NEW: Orientation metadata
                "deviceOrientation": deviceOrientation
            ]
        )
    }
}

// MARK: - AVCapturePhotoCaptureDelegate - ENHANCED: Orientation metadata
extension CameraEngine: AVCapturePhotoCaptureDelegate {
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Handle any capture errors first
            if let error = error {
                print("❌ Photo capture failed: \(error)")
                self.setLastError(error)
                self.setState(.running)
                return
            }
            
            self.setState(.running)
            
            // ENHANCED: Handle captured photo data with orientation
            self.handleCapturedPhoto(photo)
        }
    }
    
    // MARK: - Photo Processing - ENHANCED: Orientation metadata
    private func handleCapturedPhoto(_ photo: AVCapturePhoto) {
        // Extract image data
        guard let imageData = photo.fileDataRepresentation() else {
            print("❌ Could not get photo data representation")
            self.setLastError(NSError(domain: "STS.PhotoCapture", code: -1,
                                   userInfo: [NSLocalizedDescriptionKey: "Could not get photo data"]))
            return
        }
        
        // Verify image data is valid
        guard UIImage(data: imageData) != nil else {
            print("❌ Could not create UIImage from photo data")
            self.setLastError(NSError(domain: "STS.PhotoCapture", code: -2,
                                   userInfo: [NSLocalizedDescriptionKey: "Invalid photo data"]))
            return
        }
        
        // Save photo to temporary location
        let tempURL = Self.makePhotoOutputURL()
        
        do {
            try imageData.write(to: tempURL)
            print("✅ Photo saved to temporary location: \(tempURL.path)")
            print("📱 Captured with orientation: \(currentOrientation.displayName)")
            
            // Get file size for logging
            let fileSize = imageData.count
            let fileSizeMB = Double(fileSize) / 1024 / 1024
            
            print("📊 Photo captured: \(String(format: "%.2f", fileSizeMB)) MB")
            
            // Post notification with the captured photo URL and orientation metadata
            NotificationCenter.default.post(
                name: .stsDidCapturePhoto,
                object: nil,
                userInfo: [
                    "url": tempURL,
                    "fileSize": fileSize,
                    "verified": true,
                    "capturedOrientation": currentOrientation,  // NEW: Orientation metadata
                    "deviceOrientation": deviceOrientation
                ]
            )
            
        } catch {
            print("❌ Failed to save photo: \(error)")
            self.setLastError(error)
        }
    }
    
    private static func makePhotoOutputURL() -> URL {
        let directory = FileManager.default.temporaryDirectory
        let filename = "STS_Photo_\(UUID().uuidString).jpg"
        return directory.appendingPathComponent(filename)
    }
}

// MARK: - Data Output Delegates (Video/Audio Recording + Monitoring)
extension CameraEngine: AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let isVideoOutput = (output === videoDataOutput)
        if isVideoOutput {
            previewThumbnailer.process(sampleBuffer)
        }
        
        // Writer pipeline
        writerQueue.async { [weak self] in
            guard let self else { return }
            guard let writer = self.assetWriter else { return }
            
            let isVideo = output === self.videoDataOutput
            let isAudio = output === self.audioDataOutput
            
            if writer.status == .unknown {
                let ts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
                writer.startWriting()
                writer.startSession(atSourceTime: ts)
                self.recordingStartTime = ts
                self.triggerTorchCueIfNeeded()
            }
            
            if writer.status == .failed {
                let message = writer.error?.localizedDescription ?? "unknown"
                print("❌ Writer failed: \(message)")
                self.forceTorchOff(reason: "writer-failed")
                self.resetTorchCueTrigger(reason: "writer-failed")
                DispatchQueue.main.async {
                    self.setLastError(writer.error)
                    self.setState(.running)
                }
                return
            }
            
            if isVideo, let vInput = self.videoWriterInput, vInput.isReadyForMoreMediaData {
                if !self.loggedVideoOrientationAttachment {
                    self.loggedVideoOrientationAttachment = true
                    var attachmentDescription = "none"
                    if let attachmentsArray = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false) as? [[CFString: Any]],
                       let attachments = attachmentsArray.first,
                       let rawOrientation = attachments[kCGImagePropertyOrientation] {
                        attachmentDescription = "\(rawOrientation)"
                    }
                    let rotationAngle = self.rotationAngleFromDeviceOrientation(
                        self.deviceOrientation,
                        position: self.currentCameraPosition == .front ? .front : .back
                    )
                    let connectionMirror = connection.isVideoMirrored
                    let requestedMirror = CameraSettings.mirrorFrontCameraEnabled && self.currentCameraPosition == .front
                    print("🎞️ Video sample orientationAttachment=\(attachmentDescription) rotationAngle=\(rotationAngle)° camera=\(self.currentCameraPosition) mirrored(connection)=\(connectionMirror) mirrorSetting=\(requestedMirror)")
                }
                vInput.append(sampleBuffer)
            } else if isAudio, let aInput = self.audioWriterInput, aInput.isReadyForMoreMediaData {
                self.inspectAudioFormatIfNeeded(sampleBuffer: sampleBuffer)
                aInput.append(sampleBuffer)
            }
        }
    }
    
    private func inspectAudioFormatIfNeeded(sampleBuffer: CMSampleBuffer) {
        guard !loggedAudioFormat else { return }
        loggedAudioFormat = true
        
        guard let formatDesc = CMSampleBufferGetFormatDescription(sampleBuffer),
              let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(formatDesc)?.pointee else {
            print("⚠️ Failed to read audio format")
            return
        }
        
        let channels = Int(asbd.mChannelsPerFrame)
        let rate = asbd.mSampleRate
        let stereo = channels >= 2
        publishOnMain(\.isTrueStereoCapture, stereo)
        print("🎙️ Audio format: channels=\(channels) sampleRate=\(rate) stereo=\(stereo)")
    }
}

extension Notification.Name {
    static let stsDidRecordFile = Notification.Name("stsDidRecordFile")
    static let stsDidCapturePhoto = Notification.Name("stsDidCapturePhoto") // NEW: Photo capture notification
}

// MARK: - Watch Remote Recording Control
extension CameraEngine: CameraControlling {
    public func capturePhotoViaRemote() {
        DispatchQueue.main.async {
            self.capturePhoto()
        }
    }
}
