import SwiftUI
import AVFoundation

struct PIPSlateLivePreview: View {
    enum LiveMode {
        case portrait
        case landscape
    }

    @Binding var session: SlatePIPSession
    var liveSession: AVCaptureSession? = nil
    var activeLiveMode: LiveMode? = nil
    var usesPassiveLivePreview: Bool = false
    var isModeSelectionEnabled: Bool = true
    var onSelectMode: ((LiveMode) -> Void)? = nil
    var showsAudioControls: Bool = true

    var body: some View {
        GeometryReader { proxy in
            let layout = PiPLayout(canvas: proxy.size)

            ZStack(alignment: .topLeading) {
                landscapeLayer(layout: layout)
                    .frame(width: layout.closeUpSize.width,
                           height: layout.closeUpSize.height,
                           alignment: .topLeading)
                    .clipped()

                portraitLayer(layout: layout)
                    .frame(width: layout.fullBodySize.width,
                           height: layout.fullBodySize.height,
                           alignment: .top)
                    .frame(maxWidth: .infinity,
                           maxHeight: .infinity,
                           alignment: .topTrailing)
                    .overlay(alignment: .leading) {
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color.black.opacity(0.65),
                                        Color.black.opacity(0.0)
                                    ]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: 2)
                    }
            }
            .frame(width: layout.canvas.width, height: layout.canvas.height)
            .background(Color.black)
            .overlay(alignment: .bottomLeading) {
                if showsAudioControls {
                    audioToggle(for: .landscape)
                        .padding()
                }
            }
            .overlay(alignment: .bottomTrailing) {
                if showsAudioControls {
                    audioToggle(for: .portrait)
                        .padding()
                }
            }
        }
        .aspectRatio(16/9, contentMode: .fit)
        .clipped()
    }

    // MARK: - Layers

    @ViewBuilder
    private func landscapeLayer(layout: PiPLayout) -> some View {
        content(for: .landscape, layout: layout)
    }

    @ViewBuilder
    private func portraitLayer(layout: PiPLayout) -> some View {
        content(for: .portrait, layout: layout)
    }

    @ViewBuilder
    private func content(for orientation: VideoOrientation, layout: PiPLayout) -> some View {
        ZStack {
            if let liveSession, shouldShowLive(for: orientation) {
                liveCameraView(for: liveSession, orientation: orientation)
                    .transition(.opacity.combined(with: .scale))
            } else {
                recordedLayer(for: orientation)
                    .transition(.opacity)
            }

            modeOverlay(for: orientation)
        }
    }

    @ViewBuilder
    private func recordedLayer(for orientation: VideoOrientation) -> some View {
        if let take = take(for: orientation),
           FileManager.default.fileExists(atPath: take.fileURL.path) {
            let muted = orientation == .portrait ? session.portraitAudioMuted : session.landscapeAudioMuted
            LoopingVideoView(url: take.fileURL, videoGravity: .resizeAspectFill, isMuted: muted)
        } else {
            placeholder(for: orientation)
        }
    }

    private func take(for orientation: VideoOrientation) -> PIPSlateTake? {
        switch orientation {
        case .landscape: return session.selectedLandscapeTake
        case .portrait: return session.selectedPortraitTake
        }
    }

    private func shouldShowLive(for orientation: VideoOrientation) -> Bool {
        guard liveSession != nil, let activeLiveMode else { return false }
        switch (orientation, activeLiveMode) {
        case (.landscape, .landscape), (.portrait, .portrait):
            return true
        default:
            return false
        }
    }

    // MARK: - Placeholder & Mode Overlay

    @ViewBuilder
    private func placeholder(for orientation: VideoOrientation) -> some View {
        let title = orientation == .landscape ? "CLOSE-UP" : "FULL BODY"

        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.black.opacity(0.28))
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.35), lineWidth: 1)

            VStack(spacing: 6) {
                Image(systemName: orientation == .landscape ? "video" : "person.crop.rectangle")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
                Text(title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.9))
            }
            .padding(8)
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    @ViewBuilder
    private func modeOverlay(for orientation: VideoOrientation) -> some View {
        if isModeSelectionEnabled,
           liveSession != nil,
           activeLiveMode != nil,
           !isActiveOrientation(orientation) {
            let title = orientation == .landscape ? "Close-Up" : "Full Body"
            let icon = orientation == .landscape ? "video.fill" : "person.fill"
            let mode = liveMode(for: orientation)

            VStack {
                Spacer()
                HStack {
                    if orientation == .landscape {
                        modeButton(title: title, systemImage: icon, mode: mode)
                        Spacer()
                    } else {
                        Spacer()
                        modeButton(title: title, systemImage: icon, mode: mode)
                        Spacer()
                    }
                }
            }
            .padding(8)
        }
    }

    private func modeButton(title: String, systemImage: String, mode: LiveMode) -> some View {
        Button {
            onSelectMode?(mode)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.caption2)
                Text(title)
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(Color.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color.black.opacity(0.55))
            )
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.7), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .shadow(color: .black.opacity(0.6), radius: 8, x: 0, y: 4)
    }

    private func isActiveOrientation(_ orientation: VideoOrientation) -> Bool {
        guard let activeLiveMode else { return false }
        switch (orientation, activeLiveMode) {
        case (.landscape, .landscape), (.portrait, .portrait):
            return true
        default:
            return false
        }
    }

    private func liveMode(for orientation: VideoOrientation) -> LiveMode {
        orientation == .portrait ? .portrait : .landscape
    }
    
    @ViewBuilder
    private func audioToggle(for orientation: VideoOrientation) -> some View {
        let isMuted = orientation == .portrait ? session.portraitAudioMuted : session.landscapeAudioMuted
        let hasTake = orientation == .portrait ? (session.selectedPortraitTake != nil) : (session.selectedLandscapeTake != nil)
        let icon = isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill"
        let tint: Color = .black.opacity(0.65)
        
        Button {
            guard hasTake else { return }
            if orientation == .portrait {
                session.portraitAudioMuted.toggle()
            } else {
                session.landscapeAudioMuted.toggle()
            }
        } label: {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .padding(10)
                .background(
                    Circle()
                        .fill(isMuted ? Color.black.opacity(0.35) : tint)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.25), lineWidth: 1)
                        )
                )
                .shadow(color: .black.opacity(0.4), radius: 3, x: 0, y: 2)
                .opacity(hasTake ? 1 : 0.3)
        }
        .buttonStyle(.plain)
        .disabled(!hasTake)
    }

    // MARK: - Live Camera View

    @ViewBuilder
    private func liveCameraView(for session: AVCaptureSession,
                                orientation: VideoOrientation) -> some View {
        let aspect: CGFloat = orientation == .portrait ? (9.0 / 16.0) : (16.0 / 9.0)

        Group {
            if usesPassiveLivePreview {
                PassiveCameraPreviewView(session: session)
            } else {
                CameraPreviewView(session: session, previewLayerOut: .constant(nil))
            }
        }
        .aspectRatio(aspect, contentMode: .fill)
        .clipped()
    }

    // MARK: - Layout helper

    private struct PiPLayout {
        let canvas: CGSize

        var closeUpSize: CGSize {
            canvas
        }

        var fullBodySize: CGSize {
            let height = canvas.height
            let width = height * 9.0 / 16.0
            return CGSize(width: width, height: height)
        }
    }
}

// MARK: - Recorded Looping Preview

@MainActor
private struct LoopingVideoView: UIViewRepresentable {
    let url: URL
    let videoGravity: AVLayerVideoGravity
    let isMuted: Bool

    func makeUIView(context: Context) -> PlayerView {
        let view = PlayerView()
        context.coordinator.configure(with: url, gravity: videoGravity, isMuted: isMuted, playerLayer: view.playerLayer)
        return view
    }

    func updateUIView(_ uiView: PlayerView, context: Context) {
        context.coordinator.configure(with: url, gravity: videoGravity, isMuted: isMuted, playerLayer: uiView.playerLayer)
    }

    static func dismantleUIView(_ uiView: PlayerView, coordinator: Coordinator) {
        coordinator.teardown()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class PlayerView: UIView {
        override class var layerClass: AnyClass { AVPlayerLayer.self }
        var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    }

    @MainActor
    final class Coordinator {
        private let player = AVQueuePlayer()
        private var looper: AVPlayerLooper?
        private var currentURL: URL?
        private var currentMuted: Bool = true
        private var idleTimerToken: IdleTimerController.Token?
        private var timeControlObservation: NSKeyValueObservation?
        private var didTearDown = false
        private var lastIsPlaying = false

        init() {
#if DEBUG
            Self.debugLog("init")
#endif
            timeControlObservation = player.observe(\.timeControlStatus, options: [.initial, .new]) { [weak self] player, _ in
                let isPlaying = player.timeControlStatus == .playing
                Task { @MainActor [weak self] in
                    self?.updateIdleTimer(isPlaying)
                }
            }
        }

        func configure(with url: URL,
                       gravity: AVLayerVideoGravity,
                       isMuted: Bool,
                       playerLayer: AVPlayerLayer) {
            if currentURL == url {
                playerLayer.player = player
                playerLayer.videoGravity = gravity
                player.isMuted = isMuted
                currentMuted = isMuted
                if player.timeControlStatus != .playing { player.play() }
#if DEBUG
                Self.debugLog("configure reuse url=\(url.lastPathComponent)")
#endif
                return
            }

            currentURL = url
            player.pause()
            player.removeAllItems()

            let item = AVPlayerItem(url: url)
            item.preferredPeakBitRate = 3_000_000
            item.preferredMaximumResolution = CGSize(width: 1280, height: 720)
            looper = AVPlayerLooper(player: player, templateItem: item)

            player.isMuted = isMuted
            currentMuted = isMuted
            player.play()

            playerLayer.player = player
            playerLayer.videoGravity = gravity
#if DEBUG
            Self.debugLog("configure new url=\(url.lastPathComponent)")
#endif
        }

        @MainActor
        func teardown() {
            guard !didTearDown else { return }
            didTearDown = true
            let teardownID = UUID().uuidString
#if DEBUG
            let playerID = String(describing: ObjectIdentifier(player))
            let itemStatus = player.currentItem?.status.rawValue ?? -1
            Self.debugLog("teardown id=\(teardownID) isPiP=true player=\(playerID) item=\(itemStatus)", coordinator: self, hasToken: idleTimerToken != nil)
#endif
            releaseIdleTimer()
#if DEBUG
            Self.debugLog("teardown pause id=\(teardownID)", coordinator: self, hasToken: idleTimerToken != nil)
#endif
            player.pause()
#if DEBUG
            Self.debugLog("teardown removeAllItems id=\(teardownID)", coordinator: self, hasToken: idleTimerToken != nil)
#endif
            player.removeAllItems()
            looper = nil
            currentURL = nil
            timeControlObservation?.invalidate()
            timeControlObservation = nil
        }

        @MainActor
        private func updateIdleTimer(_ isPlaying: Bool) {
#if DEBUG
            Self.debugLog("updateIdleTimer isPlaying=\(isPlaying)", coordinator: self, hasToken: idleTimerToken != nil)
#endif
            if isPlaying {
                if !lastIsPlaying {
                    lastIsPlaying = true
                }
                guard idleTimerToken == nil else { return }
#if DEBUG
                Self.debugLog("acquire request isPlaying=\(isPlaying)", coordinator: self, hasToken: false)
#endif
                idleTimerToken = IdleTimerController.shared.acquire(reason: "PiPLivePreview")
#if DEBUG
                Self.debugLog("acquired isPlaying=\(isPlaying)", coordinator: self, hasToken: idleTimerToken != nil)
#endif
            } else {
                if lastIsPlaying {
                    lastIsPlaying = false
                }
                if idleTimerToken != nil {
                    releaseIdleTimer()
                }
            }
        }

        @MainActor
        private func releaseIdleTimer() {
#if DEBUG
            Self.debugLog("releaseIdleTimer lastIsPlaying=\(lastIsPlaying)", coordinator: self, hasToken: idleTimerToken != nil)
#endif
            idleTimerToken?.release()
            idleTimerToken = nil
        }

        deinit {
#if DEBUG
            Self.debugLog("deinit", coordinator: self, hasToken: idleTimerToken != nil)
#endif
            let token = idleTimerToken
            idleTimerToken = nil
            Task { @MainActor in
                token?.release()
            }
            Task { @MainActor [weak self] in
                self?.teardown()
            }
        }

#if DEBUG
        nonisolated private static func debugLog(_ event: String, coordinator: Coordinator? = nil, hasToken: Bool? = nil) {
            let id = coordinator.map { String(describing: ObjectIdentifier($0)) } ?? "nil"
            let tokenState = hasToken.map { $0 ? "token=yes" : "token=no" } ?? "token=?"
            print("LoopingVideoView.Coordinator \(event) id=\(id) \(tokenState) main=\(Thread.isMainThread)")
        }
#endif
    }
}

// MARK: - Passive Preview

struct PassiveCameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PassivePreview {
        let view = PassivePreview()
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        view.backgroundColor = .black
        view.videoPreviewLayer.backgroundColor = UIColor.black.cgColor
        view.updateOrientationOnce()
        return view
    }

    func updateUIView(_ uiView: PassivePreview, context: Context) {
        if uiView.videoPreviewLayer.session != session {
            uiView.videoPreviewLayer.session = session
        }
    }

    final class PassivePreview: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var videoPreviewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }

        private var lastOrientation: UIDeviceOrientation?
        private var orientationUpdateTimer: Timer?

        override func layoutSubviews() {
            super.layoutSubviews()
            scheduleOrientationUpdate()
        }

        private func scheduleOrientationUpdate() {
            orientationUpdateTimer?.invalidate()
            orientationUpdateTimer = Timer.scheduledTimer(withTimeInterval: 0.1,
                                                          repeats: false) { [weak self] _ in
                self?.updateOrientationIfNeeded()
            }
        }

        private func updateOrientationIfNeeded() {
            let currentOrientation = UIDevice.current.orientation
            guard currentOrientation != lastOrientation else { return }
            lastOrientation = currentOrientation
            updateOrientation()
        }

        func updateOrientationOnce() {
            updateOrientation()
        }

        private func updateOrientation() {
            guard let connection = videoPreviewLayer.connection else { return }

            let deviceOrientation = UIDevice.current.orientation
            let cameraPosition = currentCameraPosition()
            let rotationAngle: CGFloat

            if cameraPosition == .front {
                switch deviceOrientation {
                case .portrait:
                    rotationAngle = 90
                case .portraitUpsideDown:
                    rotationAngle = 90
                case .landscapeLeft:
                    rotationAngle = 180
                case .landscapeRight:
                    rotationAngle = 0
                default:
                    rotationAngle = 90
                }
            } else {
                switch deviceOrientation {
                case .portrait:
                    rotationAngle = 90
                case .portraitUpsideDown:
                    rotationAngle = 270
                case .landscapeLeft:
                    rotationAngle = 0
                case .landscapeRight:
                    rotationAngle = 180
                default:
                    rotationAngle = 90
                }
            }

            if connection.isVideoRotationAngleSupported(rotationAngle) {
                if connection.videoRotationAngle != rotationAngle {
                    connection.videoRotationAngle = rotationAngle
                    videoPreviewLayer.setNeedsLayout()
                }
            } else if #available(iOS 17.0, *) {
                // rotation coordinator handles it; nothing to do
            } else if connection.isVideoOrientationSupported,
                      let fallback = avCaptureOrientation(for: deviceOrientation) {
                if connection.videoOrientation != fallback {
                    connection.videoOrientation = fallback
                }
            }
        }

        private func currentCameraPosition() -> AVCaptureDevice.Position {
            guard let session = videoPreviewLayer.session else { return .back }
            for input in session.inputs {
                if let deviceInput = input as? AVCaptureDeviceInput,
                   deviceInput.device.hasMediaType(.video) {
                    return deviceInput.device.position
                }
            }
            return .back
        }

        @available(iOS, introduced: 11.0, deprecated: 17.0)
        private func avCaptureOrientation(for deviceOrientation: UIDeviceOrientation) -> AVCaptureVideoOrientation? {
            switch deviceOrientation {
            case .portrait: return .portrait
            case .portraitUpsideDown: return .portraitUpsideDown
            case .landscapeLeft: return .landscapeRight
            case .landscapeRight: return .landscapeLeft
            default: return nil
            }
        }

        deinit {
            orientationUpdateTimer?.invalidate()
        }
    }
}
