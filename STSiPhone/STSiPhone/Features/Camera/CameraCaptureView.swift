import SwiftUI
import Combine
import AVFoundation
import AVFAudio
import Foundation
import PDFKit // For PDF viewing

private enum TeleprompterUIConstants {
    static let panelWidth: CGFloat = 420
    static let portraitControlsBottomInset: CGFloat = 120
}

enum PIPSlatePhase: Equatable {
    case none
    case landscape
    case portrait
}

enum LevelVisibilityMode: String {
    case auto
    case alwaysOn
}

struct CameraCaptureView: View {
    let project: Project
    let session: ProjectSession
    let slateConfiguration: SlateConfiguration?
    let onBeginExitProcessing: (() -> Void)?
    let onComplete: () -> Void

    // Optional document sources (preferred: URLs, fallback: file names from wizard)
    let sidesURL: URL?
    let breakdownURL: URL?
    let sidesFileName: String?
    let breakdownFileName: String?
    let autoPresentSlatePrompt: Bool

    private let telemetryEnabled = true

    // Debugging: unique identifier to trace view lifecycle logs
    private let debugID = UUID().uuidString
    @State private var lastExitRequestTime: CFAbsoluteTime?

    // Builds a clean list of available documents
    @State private var documentViewerItems: [DocumentItem] = []
    @State private var documentViewerSelection: DocumentItem?

    private var availableDocuments: [DocumentItem] {
        var items: [DocumentItem] = []
        print("📋 CameraCaptureView availableDocuments - sidesFileName: \(sidesFileName ?? "nil"), breakdownFileName: \(breakdownFileName ?? "nil")")
        
        if let url = resolvedURL(primary: sidesURL, fallbackFileName: sidesFileName) {
            items.append(DocumentItem(title: "Sides", url: url, notes: nil))
        }
        if let url = resolvedURL(primary: breakdownURL, fallbackFileName: breakdownFileName) {
            items.append(DocumentItem(title: "Breakdown", url: url, notes: nil))
        }
        if let notes = breakdownNotesText {
            items.append(DocumentItem(title: "Breakdown Notes", url: nil, notes: notes))
        }
        return items
    }

    private var hasSidesDocument: Bool {
        availableDocuments.contains(where: { $0.title == "Sides" })
    }

    private var hasBreakdownDocument: Bool {
        availableDocuments.contains(where: { $0.title == "Breakdown" })
    }

    private var breakdownNotesText: String? {
        let raw = session.breakdownNotes?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let raw, !raw.isEmpty { return raw }
        let projectNotes = project.breakdownNotes?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let projectNotes, !projectNotes.isEmpty { return projectNotes }
        return nil
    }

    // Resolve URL from either direct URL or filename sitting in app Documents dir
    private func resolvedURL(primary: URL?, fallbackFileName: String?) -> URL? {
        if let primary = primary { return primary }
        if let name = fallbackFileName, !name.isEmpty {
            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            print("🔍 Resolving document path: \(docs.path)/\(name)")
            print("📦 Using app container documents: (docs.path)")            // Debug: List all files in Documents directory
            if let documentFiles = try? FileManager.default.contentsOfDirectory(atPath: docs.path) {
                print("📁 Files in Documents directory: \(documentFiles)")
            } else {
                print("❌ Could not read Documents directory contents")
            }
            return docs.appendingPathComponent(name)
        }
        return nil
    }

    // Document presentation state
    @State private var showDocumentViewer = false
    @State private var selectedDocument: DocumentItem?

    @State private var actorProfileManager = ActorProfileManager()

    @State private var showTakesModal = false
    @State private var hasRequestedExit = false
    @StateObject private var engine = CameraEngine()
    @State private var savedTakes: [String] = []
    @State private var isRecording = false
    @State private var takeNumber = 1
    @State private var errorMessage: String?
    @State private var recordingStartDate: Date?
    @State private var recordingDuration: TimeInterval = 0
    @State private var recordingTimer: Timer?

    // Camera mode tracking
    private var currentCameraMode: CameraEngine.CameraMode {
        return sessionManager.isRecordingKeyframePhoto ? .photo : .video
    }

    // Device orientation tracking for UI layout
    @State private var deviceOrientation = UIDevice.current.orientation
    @State private var isLandscape = false
    
    // UI controls state
@State private var showAudioControls = false
@State private var showManualControls = false
@State private var showAudioMeter = true
@State private var showLevelIndicator = true
@State private var recordBlinkTorchEnabled = CameraSettings.recordBlinkTorchEnabled
@State private var levelVisibilityMode: LevelVisibilityMode = .auto
@State private var isLevelIndicatorVisible = false
    @State private var showCameraInfoPopover = false
    @State private var showAudioInfoPopover = false
    @State private var watchBridgeConfigured = false

    // Session manager state
    @State private var showSessionManager = false
    @ObservedObject private var sessionManager = SessionManager.shared
    @AppStorage("WatchRemote.showHUDMaster") private var showWatchHUDMaster = true
    @AppStorage("WatchRemote.showHUD") private var showWatchHUD = true
    @AppStorage("hasSeenKeyframePrompt") private var hasSeenKeyframePrompt: Bool = false
    @State private var showKeyframePrompt = false
    @State private var showWatchRemoteInfoAlert = false
    @Environment(\.scenePhase) private var scenePhase
    // Gestures / focus
    @GestureState private var zoomGestureScale: CGFloat = 1.0
    @State private var currentZoom: CGFloat = 1.0
    @State private var showFocusIndicator = false
    @State private var focusLocation: CGPoint = .zero
    @State private var showAEAFLockHUD = false
    @State private var aeafLockLocation: CGPoint = .zero
    @State private var isInteractingWithAEAFSlider: Bool = false
    @State private var aeafHaptic = UIImpactFeedbackGenerator(style: .medium)
    @State private var hasPreparedAEAFHaptic = false
    @State private var aeafHapticTrigger: Int = 0
    @State private var aeafGestureHapticFired: Bool = false
    @State private var isExitProcessingVisible: Bool = false
    @State private var exitProcessingMessage: String = "Compiling your recording…"
    @State private var exitProcessingDetails: String = "Finishing camera work and preparing Take Review"
    @State private var latestPreviewTouchLocation: CGPoint = .zero

    // Initialization
    @State private var isCameraReady = false
    @State private var isInitializing = true
    @State private var initializationPhase: InitializationPhase = .starting
    @State private var pipSlateSession = SlatePIPSession()
    @State private var pipSlatePhase: PIPSlatePhase = .none
    @State private var pipRequiresPortraitShot = false
    @State private var pipRequiresLandscapeShot = false
    @State private var showSlatePromptSheet = false
    @State private var showTeleprompterScriptEditor = false
    @State private var slatePromptPreview: String = ""
    @State private var slatePromptInputsHash: String = ""
    @State private var slateCaptureStyle: SlateCaptureStyle = .smartFill
    @State private var isSlateOverlayVisible = false
    @State private var pendingSlatePromptPresentation = false
    @State private var activeSlatePrompt: String = ""
    @State private var showSettingsPopover = false
    @State private var showDocumentsPopover = false
    @State private var showBreakdownNotes = false
    @State private var showTeleprompterControls = false
    @State private var restoreTeleprompterControlsAfterRecording = false
    @State private var teleprompterFontSize: CGFloat = 28
    @State private var teleprompterLineHeight: CGFloat = 1.0
    @State private var teleprompterBackgroundOpacity: Double = 0.65
    @State private var teleprompterHeightFraction: CGFloat = 0.85
    @State private var teleprompterScrollSpeed: Double = 1.2
    @State private var teleprompterIsPreviewing = false
    @State private var teleprompterScrollOffset: CGFloat = 0
    @State private var teleprompterContentHeight: CGFloat = 0
    @State private var teleprompterPanelHeight: CGFloat = 0
    @State private var teleprompterAutoScrollDuringRecording = false
    @State private var teleprompterIsBeingDragged = false
    @State private var teleprompterDragStartOffset: CGFloat = 0
    @State private var teleprompterEditorMode: SlatePromptMode = .auto
    @State private var teleprompterEditorDraft: String = ""
    @State private var teleprompterEditorAutoPrompt: String = ""
    @State private var teleprompterEditorShouldClearCustomDraft = false
    @State private var teleprompterAutoSaveWorkItem: DispatchWorkItem?
    // MARK: - Teleprompter Slider Popup
    enum TeleprompterControlType {
        case fontSize
        case lineHeight
        case scrollSpeed
        case opacity
    }

    @State private var activeTeleSlider: TeleprompterControlType? = nil
    private let teleprompterTimer = Timer.publish(every: 1.0 / 60.0, on: .main, in: .common).autoconnect()

    // MARK: - Teleprompter Focus Mode
    private var isTeleprompterFocused: Bool {
        isSlateOverlayVisible || showTeleprompterControls || showTeleprompterScriptEditor
    }
    private let useExperimentalAEAFSlider = false
    private let aeafExposureRange: ClosedRange<Double> = -2.0...2.0
    private let aeafReticleSize: CGFloat = 90
    @State private var previewLayerOut: AVCaptureVideoPreviewLayer?
    @State private var lastPIPDeviceOrientation: UIDeviceOrientation = .unknown
    @State private var pipDismissConfirmationStage: PIPSlatePhase?
    @State private var showPIPToolsMenu = false
    @State private var pipInstructionHidden = false
    @State private var showLevelIndicatorPopover = false
    @EnvironmentObject private var navCtx: NavigationContextManager
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var isExiting = false
    private var sheetTheme: STSTheme { themeManager.current }
    private var aeafExposureBinding: Binding<Double> {
        Binding<Double>(
            get: { Double(engine.exposureValue) },
            set: { engine.setExposure(compensation: Float($0)) }
        )
    }

    enum InitializationPhase {
        case starting
        case requestingPermissions
        case configuringCamera
        case ready
        case failed(String)

        var isFailed: Bool {
            if case .failed = self { return true }
            return false
        }
    }

    private var initializationPhaseMessage: String {
        switch initializationPhase {
        case .starting: return "Starting Camera..."
        case .requestingPermissions: return "Requesting Permissions"
        case .configuringCamera: return "Setting Up Camera"
        case .ready: return "Ready!"
        case .failed(_): return "Setup Failed"
        }
    }

    private var initializationPhaseDetails: String {
        switch initializationPhase {
        case .starting: return "Preparing camera system"
        case .requestingPermissions: return "Please allow camera and microphone access when prompted"
        case .configuringCamera: return "Configuring camera settings and session"
        case .ready: return "Camera is ready to use"
        case .failed(let error): return error
        }
    }

    // Initializer
    init(
        project: Project,
        session: ProjectSession,
        slateConfiguration: SlateConfiguration? = nil,
        autoPresentSlatePrompt: Bool = false,
        sidesURL: URL? = nil,
        breakdownURL: URL? = nil,
        sidesFileName: String? = nil,
        breakdownFileName: String? = nil,
        onBeginExitProcessing: (() -> Void)? = nil,
        onComplete: @escaping () -> Void
    ) {
        self.project = project
        self.session = session
        self.slateConfiguration = slateConfiguration
        self.sidesURL = sidesURL
        self.breakdownURL = breakdownURL
        self.sidesFileName = sidesFileName
        self.breakdownFileName = breakdownFileName
        self.autoPresentSlatePrompt = autoPresentSlatePrompt
        self.onBeginExitProcessing = onBeginExitProcessing
        self.onComplete = onComplete
        _pendingSlatePromptPresentation = State(initialValue: autoPresentSlatePrompt)

        print("📷 CameraCaptureView init – debugID = \(debugID)")
    }

    var body: some View {
        ZStack {
            mainContent
            if let notice = engine.audioRouteNotice {
                audioRouteNoticeBanner(message: notice)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(900)
            }
            if showTeleprompterScriptEditor {
                teleprompterScriptEditorOverlay
            }
            exitProcessingOverlay
        }
        .animation(.easeInOut(duration: 0.2), value: engine.audioRouteNotice != nil)
        .stsSupportedOrientations(.all, label: "CameraCaptureView")
        .onAppear {
            print("📷 CameraCaptureView onAppear – debugID = \(debugID)")
            actorProfileManager = ActorProfileManager()
            slatePromptPreview = ""
            slatePromptInputsHash = ""
            if !hasPreparedAEAFHaptic {
                aeafHaptic.prepare()
                hasPreparedAEAFHaptic = true
            }
            pipInstructionHidden = UserDefaults.standard.bool(forKey: pipInstructionPreferenceKey)
            configureWatchBridge()
            setupCameraOnce()
            updateOrientationState()
            pipSlateSession = resolvedCurrentPIPSlateSession()
            pipSlatePhase = .none
            resetPIPCaptureChecklist()
            if pendingSlatePromptPresentation {
                pendingSlatePromptPresentation = false
                SessionManager.shared.switchToSlateMode()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    presentSlatePrompt()
                }
            }
        }
        .onDisappear {
            print("📷 CameraCaptureView onDisappear – debugID = \(debugID)")
            let disappearTime = CFAbsoluteTimeGetCurrent()
            if let lastExit = lastExitRequestTime {
                let delta = disappearTime - lastExit
                print(String(format: "🎬 [Perf] CameraCaptureView onDisappear – %.2f s after exit request", delta))
            } else {
                print("🎬 [Perf] CameraCaptureView onDisappear with no recorded exit request time")
            }
            WatchBridge.shared.stopHeartbeat()
            WatchBridge.shared.notifyCameraReady(false)
            engine.forceTorchOff(reason: "view-disappear")
            cleanupCamera()
            completePIPSlateCapture()
            isSlateOverlayVisible = false
            activeSlatePrompt = ""
            clearAEAFLock()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
            updateOrientationState()
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                if isCameraReady {
                    WatchBridge.shared.startHeartbeat(interval: 2.5)
                }
            case .inactive, .background:
                WatchBridge.shared.stopHeartbeat()
                engine.forceTorchOff(reason: "scenePhase")
            @unknown default:
                break
            }
        }
        .onReceive(engine.$currentOrientation.removeDuplicates()) { newValue in
            handlePIPOrientationChange(engineOrientation: newValue)
        }
        .onReceive(NotificationCenter.default.publisher(for: .actorProfileDidUpdate)) { _ in
            actorProfileManager = ActorProfileManager()
            slatePromptPreview = ""
            slatePromptInputsHash = ""
            if isSlateOverlayVisible {
                activeSlatePrompt = resolvedSlatePrompt()
            }
        }
        .onReceive(
            NotificationCenter.default.publisher(for: .watchBridgeRemoteModeSelected)
                .receive(on: RunLoop.main)
        ) { notification in
            guard let mode = notification.userInfo?["mode"] as? String else { return }
            let index = notification.userInfo?["index"] as? Int
            handleRemoteModeChange(mode: mode, index: index)
        }
        .onReceive(engine.$isAEAFLocked.removeDuplicates()) { locked in
            showAEAFLockHUD = locked
        }
        .onReceive(NotificationCenter.default.publisher(for: .cameraSettingsDidChange)) { notification in
            if let enabled = notification.userInfo?[CameraSettingsNotificationKeys.recordBlinkTorchEnabled] as? Bool {
                recordBlinkTorchEnabled = enabled
            }
        }
        .onChange(of: sessionManager.isRecordingKeyframePhoto, initial: false) { _, _ in
            updateCameraEngineMode()
            notifyCurrentModeChange()
        }
        .onChange(of: sessionManager.isRecordingSlate, initial: false) { _, _ in
            updateCameraEngineMode()
            notifyCurrentModeChange()
        }
        .onChange(of: sessionManager.currentScene, initial: false) { _, _ in
            notifyCurrentModeChange()
        }
        .onChange(of: slateCaptureStyle, initial: false) { _, _ in
            if sessionManager.isRecordingSlate || isPiPActive {
                notifyCurrentModeChange()
            }
        }
        .onReceive(engine.$state) { newState in
            syncRecordingState(for: newState)
        }
        .onChange(of: isCameraReady, initial: false) { _, ready in
            WatchBridge.shared.notifyCameraReady(ready)
            if ready {
                WatchBridge.shared.startHeartbeat(interval: 2.5)
                updateCameraEngineMode()
                notifyCurrentModeChange()
            } else {
                WatchBridge.shared.stopHeartbeat()
            }
        }
        .onReceive(teleprompterTimer) { _ in
            // Scroll during preview or when recording has enabled teleprompter auto-scroll.
            guard (teleprompterIsPreviewing || teleprompterAutoScrollDuringRecording),
                  teleprompterPanelHeight > 0,
                  teleprompterContentHeight > 0 else {
                if telemetryEnabled {
                    // Intentionally silent to reduce log spam while idle.
                }
                return
            }

            // Allow the text to scroll past the viewport so we never bounce early.
            let maxOffset = teleprompterContentHeight + teleprompterPanelHeight
            let increment = CGFloat(teleprompterScrollSpeed) * 0.75
            let next = teleprompterScrollOffset + increment

            if next >= maxOffset {
                teleprompterScrollOffset = maxOffset
                finishTeleprompterScrollAtEnd()
            } else {
                teleprompterScrollOffset = next
            }
        }
        .onChange(of: teleprompterIsPreviewing, initial: false) { _, previewing in
            if previewing {
                ensureSlateTeleprompterVisible()
                teleprompterScrollOffset = 0
                if telemetryEnabled {
                    print("📜 [Teleprompter] Preview started – offset reset, autoScroll=\(teleprompterAutoScrollDuringRecording)")
                }
            } else {
                teleprompterAutoScrollDuringRecording = false
                if telemetryEnabled {
                    print("📜 [Teleprompter] Preview stopped – autoScroll disabled, resetOffset next hide")
                }
            }
        }
        .onChange(of: teleprompterFontSize, initial: false) { _, _ in
            teleprompterScrollOffset = 0
        }
        .onChange(of: teleprompterHeightFraction, initial: false) { _, _ in
            teleprompterScrollOffset = 0
        }
        .onChange(of: activeSlatePrompt, initial: false) { _, _ in
            teleprompterScrollOffset = 0
        }
        .onChange(of: isSlateOverlayVisible, initial: false) { _, visible in
            if telemetryEnabled {
                print("📜 [Teleprompter] Overlay visibility changed -> \(visible)")
            }
            if !visible {
                stopTeleprompterScrolling(resetOffset: true)
            }
        }
        .onChange(of: showTeleprompterControls, initial: false) { _, isVisible in
            if !isVisible, teleprompterIsPreviewing, !isRecording {
                if telemetryEnabled {
                    print("📜 [Teleprompter] Teleprompter controls dismissed – stopping preview scroll")
                }
                stopTeleprompterScrolling(resetOffset: true)
            }
        }
        .onChange(of: showTakesModal, initial: false) { _, isPresented in
            guard isPresented else { return }
            if telemetryEnabled {
                print("🎬 [TakesModal] Presenting – dismissing teleprompter overlay and controls")
            }
            isSlateOverlayVisible = false
            showTeleprompterControls = false
            if teleprompterIsPreviewing {
                stopTeleprompterScrolling(resetOffset: true)
            } else {
                teleprompterScrollOffset = 0
            }
        }
        .alert("Camera Error", isPresented: Binding(get: { errorMessage != nil }, set: { _ in errorMessage = nil })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "Unknown error")
        }
        .alert(
            "Session incomplete",
            isPresented: Binding(
                get: { sessionManager.shouldShowResumeNudge },
                set: { newValue in
                    if !newValue {
                        sessionManager.dismissResumeNudge()
                    } else {
                        sessionManager.shouldShowResumeNudge = true
                    }
                }
            )
        ) {
            Button("Continue", role: .cancel) {
                sessionManager.dismissResumeNudge()
            }
            Button("Review missing") {
                sessionManager.dismissResumeNudge()
                sessionManager.navigateToFirstMissingItem()
            }
            Button("Don't show again") {
                sessionManager.suppressResumeNudgeForCurrentSession()
            }
        } message: {
            Text(resumeNudgeMessage)
        }
        .fullScreenCover(isPresented: $showDocumentViewer) {
            DocumentViewerModal(
                documents: documentViewerItems,
                selectedDocument: $documentViewerSelection
            ) {
                showDocumentViewer = false
            }
        }
        .sheet(isPresented: $showSlatePromptSheet) {
            SlatePromptSheet(
                script: $slatePromptPreview,
                selections: slateSelectionsSnapshot,
                captureStyle: $slateCaptureStyle,
                promptMode: $teleprompterEditorMode,
                customScript: $teleprompterEditorDraft,
                clearCustomDraft: $teleprompterEditorShouldClearCustomDraft,
                autoScript: teleprompterEditorAutoPrompt,
                isOverlayActive: Binding(
                    get: { isSlateOverlayVisible },
                    set: { newValue in
                        isSlateOverlayVisible = newValue

                        if newValue {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                                showTeleprompterControls = true
                            }
                        } else {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showTeleprompterControls = false
                                activeTeleSlider = nil
                            }
                        }

                        DispatchQueue.main.async {
                            activeSlatePrompt = newValue ? slatePromptPreview : ""
                        }
                    }
                ),
                onBegin: {
                    handleSlatePromptBegin()
                },
                onDismiss: {
                    showSlatePromptSheet = false
                    isSlateOverlayVisible = false
                    activeSlatePrompt = ""
                    teleprompterEditorShouldClearCustomDraft = false
                },
                theme: sheetTheme
            )
        }
        .sheet(isPresented: $showKeyframePrompt) {
            KeyframePromptSheet(
                onGotIt: {
                    showKeyframePrompt = false
                },
                onDontShowAgain: {
                    hasSeenKeyframePrompt = true
                    showKeyframePrompt = false
                }
            )
            .presentationDetents([.fraction(0.55), .large])
            .presentationDragIndicator(.visible)
        }
        .alert("Watch Remote", isPresented: $showWatchRemoteInfoAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Best reliability requires Bluetooth + Wi‑Fi ON.\n\nSilence devices with Focus / Do Not Disturb (don’t turn radios off).\n\nIf the watch looks stuck, tap the status dot to reconnect.")
        }
        .onChange(of: slatePromptPreview, initial: false) { _, newValue in
            if isSlateOverlayVisible {
                activeSlatePrompt = newValue
            }
        }
        .statusBarHidden(true)
        .background(Color.black)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .topTrailing) {
            if pipSlatePhase != .none {
                pipUtilityControls
                    .padding(.top, calculateTopBarTopPadding())
                    .padding(.trailing, 16)
                    .zIndex(isTeleprompterFocused ? 4000 : 0)
            }
        }
        .overlay {
            ModeOverlayView()
        }
        .overlay(alignment: .topTrailing) {
            pipToolsFloatingMenu
        }
        .confirmationDialog(
            "Finish PiP Slate?",
            isPresented: Binding(
                get: { pipDismissConfirmationStage != nil },
                set: { if !$0 { pipDismissConfirmationStage = nil } }
            ),
            presenting: pipDismissConfirmationStage
        ) { _ in
            Button("I'm finished") {
                pipDismissConfirmationStage = nil
                completePIPSlateCapture()
            }
            Button("Cancel", role: .cancel) {
                pipDismissConfirmationStage = nil
            }
        } message: { stage in
            Text("Are you finished recording your Picture-in-Picture slate? You can return later to capture more takes.")
        }
    }

    private var resumeNudgeMessage: String {
        let remaining = sessionManager.resumeNudgeRemainingText
        if remaining.isEmpty {
            return "Remaining items in this session."
        }
        return "Remaining: \(remaining)."
    }

    @ViewBuilder
    private var mainContent: some View {
        if isInitializing {
            initializationView
                .interactiveDismissDisabled(!initializationPhase.isFailed)
        } else {
            captureView
        }
    }

    @ViewBuilder
    private var exitProcessingOverlay: some View {
        if isExitProcessingVisible {
            ExitProcessingOverlayView(
                message: exitProcessingMessage,
                details: exitProcessingDetails
            )
            .transition(.opacity)
            .zIndex(9999)
            .allowsHitTesting(true)
        }
    }

    @ViewBuilder
    private func audioRouteNoticeBanner(message: String) -> some View {
        VStack {
            Text(message)
                .font(.caption.weight(.semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(Color.black.opacity(0.7))
                        .overlay(
                            Capsule()
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                )
                .padding(.top, 20)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private var initializationView: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 20) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)

                VStack(spacing: 8) {
                    Text(initializationPhaseMessage)
                        .font(.headline)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)

                    Text(initializationPhaseDetails)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }

                if case .failed(_) = initializationPhase {
                    Button("Retry") {
                        retryInitialization()
                    }
                    .font(.headline)
                    .foregroundColor(.black)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.white)
                    .cornerRadius(8)
                }
            }
        }
    }

    // MARK: - Keyframe prompt handling

    private func handleKeyframeSelection() {
        sessionManager.switchToKeyframePhotoMode()
        if !hasSeenKeyframePrompt {
            showKeyframePrompt = true
        }
    }

    // Orientation state for UI layout
    private func updateOrientationState() {
        let newOrientation = UIDevice.current.orientation
        guard newOrientation.isValidInterfaceOrientation else { return }
        deviceOrientation = newOrientation
        withAnimation(.easeInOut(duration: 0.3)) {
            isLandscape = newOrientation.isLandscape
        }
        print("🔄 Orientation changed: \(newOrientation.rawValue), isLandscape: \(isLandscape)")
        handlePIPOrientationChange(newOrientation)
    }

    private func handlePIPOrientationChange(engineOrientation: VideoOrientation) {
        switch engineOrientation {
        case .portrait:
            handlePIPOrientationChange(.portrait)
        case .landscape:
            handlePIPOrientationChange(.landscapeRight)
        }
    }

    private func handlePIPOrientationChange(_ orientation: UIDeviceOrientation) {
        guard pipSlatePhase != .none else { return }
        guard orientation != .unknown, orientation != .faceDown, orientation != .faceUp else { return }
        if orientation == lastPIPDeviceOrientation { return }

        switch orientation {
        case .portrait, .portraitUpsideDown:
            if pipSlatePhase != .portrait {
                withAnimation(.easeInOut(duration: 0.25)) {
                    pipSlatePhase = .portrait
                }
            }
            lastPIPDeviceOrientation = orientation
        case .landscapeLeft, .landscapeRight:
            if pipSlatePhase != .landscape {
                withAnimation(.easeInOut(duration: 0.25)) {
                    pipSlatePhase = .landscape
                }
            }
            lastPIPDeviceOrientation = orientation
        default:
            break
        }
    }

    // MARK: - UI Components
    @ViewBuilder
    private var cameraUIOverlays: some View {
        ZStack {
            Color.clear
                .ignoresSafeArea()
                .allowsHitTesting(false)

            VStack {
                topBar
                Spacer()
                // Bottom corners, meters, etc. (unchanged)
                HStack {
                    VStack(spacing: 8) {
                        Spacer()
                        if !isRecording && !isPiPActive {
                            Button(action: {
                                withAnimation { showAudioControls.toggle() }
                            }) {
                                Image(systemName: showAudioControls ? "mic.fill" : "mic")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(12)
                                    .background(.ultraThinMaterial, in: Circle())
                                    .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                            }
                            .transition(.scale.combined(with: .opacity))
                        }
                        if !isRecording && !isPiPActive {
                            Button(action: {
                                navCtx.clearContexts(source: .cameraCapture,
                                                     sessionID: session.id,
                                                     projectID: project.id)
                                navCtx.preserveFromCamera(
                                    scene: sessionManager.currentScene,
                                    viewType: inferredNavigationViewType,
                                    sessionID: session.id,
                                    projectID: project.id,
                                    metadata: contextMetadataForCurrentState()
                                )
                                showTakesModal = true
                            }) {
                                ZStack {
                                    if let latestTake = SessionManager.shared.getLatestUnifiedTake() {
                                        ThumbnailPreviewView(unifiedTake: latestTake)
                                            .frame(width: 44, height: 44)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                            .transition(.scale.combined(with: .opacity))
                                    } else {
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color.black.opacity(0.3))
                                            .frame(width: 44, height: 44)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .stroke(Color.white.opacity(0.4), lineWidth: 1)
                                            )
                                            .overlay(
                                                Image(systemName: "photo.stack")
                                                    .font(.system(size: 16, weight: .medium))
                                                    .foregroundColor(.white.opacity(0.6))
                                            )
                                            .transition(.scale.combined(with: .opacity))
                                    }
                                }
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                )
                                .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .contentShape(RoundedRectangle(cornerRadius: 8))
                            .transition(.scale.combined(with: .opacity))
                        }
                        if isRecording && showAudioMeter {
                            ExternalAudioMeter(engine: engine, isVisible: .constant(true))
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .padding(.bottom, 20)
                    .padding(.leading, 20)

                    Spacer()

                    VStack(spacing: 8) {
                        Spacer()
                        if !isRecording && !isPiPActive {
                            Button(action: {
                                withAnimation { showManualControls.toggle() }
                            }) {
                                Image(systemName: "slider.horizontal.3")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(12)
                                    .background(.ultraThinMaterial, in: Circle())
                                    .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                            }
                            .transition(.scale.combined(with: .opacity))
                        }
                        if !isRecording {
                            Button(action: { engine.switchCamera() }) {
                                Image(systemName: "camera.rotate.fill")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(12)
                                    .background(.ultraThinMaterial, in: Circle())
                                    .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                            }
                            .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .padding(.bottom, 20)
                    .padding(.trailing, 20)
                }
            }

            if showLevelIndicator {
                LevelIndicatorView(
                    showInPortrait: true,
                    showInLandscape: true,
                    customBottomPadding: calculateLevelIndicatorBottomPadding(),
                    isAlwaysOn: levelVisibilityMode == .alwaysOn,
                    onVisibilityChanged: { visible in
                        isLevelIndicatorVisible = visible
                        if !visible {
                            showLevelIndicatorPopover = false
                        }
                    }
                )
                // Make the visual level itself non-interactive so it doesn't
                // eat touches across the screen.
                .allowsHitTesting(false)
                // Add a small, centered tap target near the level that behaves
                // like a chip and anchors the popover bubble.
                .overlay(alignment: .bottom) {
                    // Only allow tapping when the level is actually visible.
                    if isLevelIndicatorVisible {
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            withAnimation(.snappy) {
                                showLevelIndicatorPopover.toggle()
                            }
                        } label: {
                            // Invisible tap area roughly centered on the level.
                            // Adjust width/height if you want a larger/smaller target.
                            Color.clear
                                .frame(width: 160, height: 60)
                                .contentShape(Rectangle())
                        }
                        // Position this tap target up from the bottom by the same
                        // padding the LevelIndicator uses, so it sits on/near the level.
                        .padding(.bottom, calculateLevelIndicatorBottomPadding())
                        .buttonStyle(.plain)
                        .popover(
                            isPresented: $showLevelIndicatorPopover,
                            attachmentAnchor: .rect(.bounds),
                            arrowEdge: .top
                        ) {
                            levelIndicatorPopoverContent
                                .presentationCompactAdaptation(.popover)
                        }
                    }
                }
            }


            if showFocusIndicator {
                FocusIndicator()
                    .position(focusLocation)
                    .animation(.easeInOut(duration: 0.3), value: focusLocation)
            }

            if showAEAFLockHUD && !isRecording {
                Group {
                    if useExperimentalAEAFSlider {
                        AEAFHudView(
                            lockLocation: aeafLockLocation,
                            exposureValue: aeafExposureBinding,
                            exposureRange: aeafExposureRange,
                            onSliderInteractionChanged: { isInteractingWithAEAFSlider = $0 }
                        )
                    } else {
                        AEAFHudView(
                            lockLocation: aeafLockLocation,
                            exposureValue: aeafExposureBinding,
                            exposureRange: aeafExposureRange,
                            onSliderInteractionChanged: { isInteractingWithAEAFSlider = $0 }
                        )
                    }
                }
                .transition(.scale(scale: 0.9).combined(with: .opacity))
            }

            if showSessionManager && !sessionManager.takes.isEmpty && !isRecording {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        SwipeableTakeManager()
                            .frame(maxWidth: 200)
                    }
                }
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }

            if showAudioControls && !isRecording {
                VStack {
                    Spacer()
                    HStack {
                        CompactAudioControlsPanel(engine: engine, isVisible: $showAudioControls, showInfoPopover: $showAudioInfoPopover)
                            .padding(.bottom, 120)
                            .padding(.leading, 20)
                        Spacer()
                    }
                }
                .transition(.move(edge: .leading).combined(with: .opacity))
            }

            if isLandscape {
                landscapeControlsLayout
            } else {
                portraitControlsLayout
            }

                    if showManualControls {
                        VStack {
                            Spacer()
                            CompactManualControlsPanel(
                                engine: engine,
                                isVisible: $showManualControls,
                                isLocked: Binding(
                                    get: { engine.isAEAFLocked },
                                    set: { newValue in
                                        if newValue {
                                            lockFromManualControls()
                                        } else {
                                            clearAEAFLock()
                                        }
                                    }
                                ),
                                showInfoPopover: $showCameraInfoPopover
                            )
                        }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }

            if showBreakdownNotes {
                let trimmedNotes = breakdownNotesText?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                let notes = (trimmedNotes?.isEmpty ?? true)
                    ? "No breakdown notes have been added yet."
                    : (trimmedNotes ?? "")
                VStack {
                    Spacer()
                    BreakdownNotesOverlayView(
                        text: notes,
                        isPresented: $showBreakdownNotes
                    )
                    .padding(.horizontal, 24)
                    .padding(.bottom, 30)
                }
                .transition(.opacity.combined(with: .scale))
                .zIndex(2000)
            }

            if showTeleprompterControls {
                let teleControlsBottomInset = isLandscape ? 0 : TeleprompterUIConstants.portraitControlsBottomInset

                ZStack {
                    if activeTeleSlider != nil {
                        Color.black.opacity(0.001)
                            .ignoresSafeArea()
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    activeTeleSlider = nil
                                }
                            }
                    }

                    VStack(spacing: 12) {
                        Spacer()
                            .allowsHitTesting(false)

                        if let control = activeTeleSlider {
                            teleSlider(for: control)
                                .accessibilityIdentifier("teleprompterFloatingSlider")
                                .onTapGesture { }
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 20)
                                .padding(.bottom, 6)
                        }

                        HStack {
                            TeleprompterControlsOverlay(
                                isPreviewing: $teleprompterIsPreviewing,
                                scrollOffset: $teleprompterScrollOffset,
                                theme: sheetTheme,
                                telemetryEnabled: telemetryEnabled,
                                onClose: {
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                                    showTeleprompterControls = false
                                    activeTeleSlider = nil
                                }
                            },
                            onEditScript: {
                                activeTeleSlider = nil
                                presentTeleprompterScriptEditor()
                            },
                            onActivateControl: { control in
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    activeTeleSlider = control
                                }
                            }
                        )
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 26)
                            Spacer()
                                .allowsHitTesting(false)
                        }
                    }
                    .padding(.bottom, teleControlsBottomInset)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(3500)
            }

            if showTakesModal {
                if let repository = sessionManager.repositoryInstance {
                    SessionTakesModalView(
                        isPresented: $showTakesModal,
                        project: project,
                        session: session,
                        repository: repository,
                        onThatSAWrap: {
                            print("🎬 SessionTakesModal onThatSAWrap called inside CameraCaptureView – debugID = \(debugID)")
                        }
                    )
                    .transition(.opacity)
                    .zIndex(1000)
                } else {
                    Text("Repository unavailable")
                        .foregroundStyle(.white)
                        .padding()
                }
            }
        }
    }

    @ViewBuilder
    private var pipCaptureOverlay: some View {
        if pipSlatePhase == .none {
            EmptyView()
                .allowsHitTesting(false)
        } else {
            GeometryReader { geo in
                ZStack {
                    Color.clear.allowsHitTesting(false)

                    switch pipSlatePhase {
                    case .portrait:
                        portraitPIPOverlay(size: geo.size)
                    case .landscape:
                        landscapePIPOverlay(size: geo.size)
                    case .none:
                        EmptyView()
                    }
                }
            }
            .animation(.easeInOut(duration: 0.25), value: pipSlatePhase)
        }
    }

    private func portraitPIPOverlay(size: CGSize) -> some View {
        let inset: CGFloat = PIPLayout.portraitInset
        let availableWidth = max(0, size.width - inset * 2)
        let availableHeight = max(0, size.height - inset * 2)
        var frameWidth = availableWidth
        var frameHeight = frameWidth * 16.0 / 9.0
        if frameHeight > availableHeight {
            frameHeight = availableHeight
            frameWidth = frameHeight * 9.0 / 16.0
        }

        return ZStack {
            pipFrame(
                width: frameWidth,
                height: frameHeight,
                title: "Full Body",
                icon: "figure.wave",
                count: pipPortraitCount,
                style: .active,
                phase: .portrait,
                headerAlignment: .topLeading,
                countAlignment: .bottomLeading
            )
            .overlay { pipInstructionBubble(for: .portrait) }
        }
        .frame(width: size.width, height: size.height, alignment: .center)
        .padding(.horizontal, inset)
        .padding(.vertical, inset)
        .offset(
            x: PIPLayout.portraitHorizontalOffset,
            y: PIPLayout.portraitVerticalOffset
        )
    }

    private func landscapePIPOverlay(size: CGSize) -> some View {
        let padding: CGFloat = 24
        let totalWidth = max(0, size.width - padding * 2)
        let totalHeight = max(0, size.height - padding * 2)

        var portraitWidth = min(totalHeight * 9.0 / 16.0, totalWidth * 0.35)
        var portraitHeight = portraitWidth * 16.0 / 9.0
        if portraitHeight > totalHeight {
            portraitHeight = totalHeight
            portraitWidth = portraitHeight * 9.0 / 16.0
        }

        var closeWidth = max(totalWidth - portraitWidth - padding, portraitWidth * 1.2)
        var closeHeight = closeWidth * 9.0 / 16.0
        if closeHeight > totalHeight {
            closeHeight = totalHeight
            closeWidth = closeHeight * 16.0 / 9.0
        }

        let maxHeight = max(closeHeight, portraitHeight)
        let verticalPadding = max(0, (totalHeight - maxHeight) / 2)

        return ZStack {
            HStack(alignment: .center, spacing: padding) {
                pipFrame(
                    width: closeWidth,
                    height: closeHeight,
                    title: "Close-Up",
                    icon: "person.crop.rectangle",
                    count: pipLandscapeCount,
                    style: .active,
                    phase: .landscape,
                    headerAlignment: .topTrailing,
                    countAlignment: .bottomTrailing
                )
                .overlay { pipInstructionBubble(for: .landscape) }
                pipFrame(
                    width: portraitWidth,
                    height: portraitHeight,
                    title: "Full Body",
                    icon: "figure.wave",
                    count: pipPortraitCount,
                    style: .ghost,
                    phase: .portrait,
                    headerAlignment: .topLeading,
                    countAlignment: .bottomLeading
                )
            }
            .padding(.horizontal, padding)
            .padding(.vertical, verticalPadding)
        }
        .frame(width: size.width, height: size.height, alignment: .center)
    }

    private func pipFrame(
        width: CGFloat,
        height: CGFloat,
        title: String,
        icon: String,
        count: Int,
        style: PIPFrameStyle,
        phase: PIPSlatePhase,
        headerAlignment: Alignment = .topLeading,
        countAlignment: Alignment = .bottomLeading
    ) -> some View {
        let strokeColor = style == .active ? Color.white : Color.white.opacity(0.45)
        let lineWidth: CGFloat = style == .active ? 2 : 1.5

        return RoundedRectangle(cornerRadius: 28, style: .continuous)
            .stroke(style: StrokeStyle(lineWidth: lineWidth, dash: [10, 8]))
            .foregroundColor(strokeColor)
            .frame(width: width, height: height)
            .overlay(alignment: headerAlignment) {
                pipFrameHeader(
                    title: title,
                    icon: icon,
                    isActive: style == .active,
                    phase: phase,
                    alignTrailing: headerAlignment == .topTrailing
                )
                .padding(12)
            }
            .overlay(alignment: countAlignment) {
                pipCountOverlay(count: count, alignTrailing: countAlignment == .bottomTrailing, isActive: style == .active)
                    .padding(12)
            }
    }

    @ViewBuilder
    private func pipInstructionBubble(for stage: PIPStatusDescriptor.Stage) -> some View {
        if isPIPRecording {
            EmptyView()
        } else if let descriptor = currentPIPStatus,
           descriptor.stage == stage,
           !pipInstructionHidden,
           let instruction = descriptor.instruction {
            VStack {
                Spacer()
                VStack(spacing: 12) {
                    HStack {
                        Spacer()
                        Button {
                            pipInstructionHidden = true
                            UserDefaults.standard.set(true, forKey: pipInstructionPreferenceKey)
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 12, weight: .semibold))
                                .padding(6)
                                .background(Color.white.opacity(0.2), in: Circle())
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.white.opacity(0.9))
                    }

                    Text(instruction)
                        .font(.subheadline.weight(.semibold))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white)
                        .padding(.top, 4)
                }
                .padding(16)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(descriptor.color.opacity(0.22))
                        .overlay(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .stroke(descriptor.color.opacity(0.45), lineWidth: 1)
                        )
                )
                .padding(24)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            EmptyView()
        }
    }

    private func pipCountBadge(count: Int, isActive: Bool) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "film")
                .font(.caption2.weight(.bold))
            Text("\(count)")
                .font(.caption2.monospacedDigit())
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color.black.opacity(isActive ? 0.75 : 0.45), in: Capsule())
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(isActive ? 0.45 : 0.2), lineWidth: 1)
        )
    }

private func pipPhaseDescription(_ phase: PIPSlatePhase?) -> String {
        switch phase {
        case .portrait:
            return "Full Body"
        case .landscape:
            return "Close-Up"
        default:
            return "PiP"
        }
    }

    private func pipFrameHeader(
        title: String,
        icon: String,
        isActive: Bool,
        phase: PIPSlatePhase,
        alignTrailing: Bool
    ) -> some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                if !icon.isEmpty {
                    Image(systemName: icon)
                }
                Text(title)
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white.opacity(isActive ? 1 : 0.8))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.black.opacity(isActive ? 0.7 : 0.45), in: Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(isActive ? 0.35 : 0.2), lineWidth: 1)
            )
            
            if shouldShowPiPControls(for: phase) {
                if pipCaptureReady && canCompletePIP {
                    Button(action: completePIPTapped) {
                        Label("Done", systemImage: "checkmark")
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.green.opacity(0.9), in: Capsule())
                            .foregroundStyle(Color.white)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Finish PiP Slate")
                } else {
                    Button {
                        pipDismissConfirmationStage = phase
                    } label: {
                        Label("Done", systemImage: "xmark")
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.black.opacity(0.75), in: Capsule())
                            .foregroundStyle(Color.white)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Exit PiP Slate")
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: alignTrailing ? .trailing : .leading)
    }

    private func shouldShowPiPControls(for framePhase: PIPSlatePhase) -> Bool {
        guard pipSlatePhase != .none, framePhase != .none else { return false }
        guard !isPIPRecording else { return false }

        let preferredPhase: PIPSlatePhase = {
            switch pipSlatePhase {
            case .portrait: return .landscape
            case .landscape: return .portrait
            case .none: return .none
            }
        }()

        if framePhase == preferredPhase {
            return true
        }

        // When we're in the single-frame portrait layout there is no landscape frame to host the
        // controls, so fall back to showing them on the available portrait frame.
        if pipSlatePhase == .portrait, framePhase == .portrait {
            return true
        }

        return false
    }

    private func pipCountOverlay(count: Int, alignTrailing: Bool, isActive: Bool) -> some View {
        HStack {
            if alignTrailing { Spacer(minLength: 0) }
            pipCountBadge(count: count, isActive: isActive)
        }
    }

    private enum PIPFrameStyle {
        case active
        case ghost
    }

    @ViewBuilder
    private var slateTeleprompterOverlay: some View {
        if isSlateOverlayVisible, !activeSlatePrompt.isEmpty {
            ZStack(alignment: .topTrailing) {
                GeometryReader { geo in
                    let hostHeight = geo.size.height
                    let panelHeight = teleprompterPanelHeight(for: hostHeight, fraction: teleprompterHeightFraction)
                    let initialPadding = teleprompterInitialTopPadding(for: panelHeight)

                    VStack(spacing: 0) {
                        ZStack(alignment: .top) {
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .fill(Color.black.opacity(teleprompterBackgroundOpacity))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                                        .stroke(Color.white.opacity(0.18), lineWidth: 1)
                                )

                            Text(activeSlatePrompt)
                                .font(.system(size: teleprompterFontSize, weight: .semibold, design: .rounded))
                                .multilineTextAlignment(.center)
                                .foregroundStyle(.white)
                                .lineSpacing(teleprompterFontSize * 0.35 * teleprompterLineHeight)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.horizontal, 20)
                                .padding(.top, initialPadding + 18)
                                .padding(.bottom, 18)
                                .frame(maxWidth: .infinity, alignment: .top)
                                .offset(y: -teleprompterScrollOffset)
                                .background(
                                    GeometryReader { textProxy in
                                        Color.clear
                                            .preference(key: TeleprompterContentHeightKey.self, value: textProxy.size.height)
                                    }
                                )
                        }
                        .frame(height: panelHeight, alignment: .top)
                        .mask(
                            LinearGradient(
                                colors: [
                                    Color.black.opacity(0),
                                    Color.white,
                                    Color.white,
                                    Color.black.opacity(0)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .contentShape(Rectangle())
                        .allowsHitTesting(true)
                        .gesture(
                            DragGesture(minimumDistance: 1)
                                .onChanged { value in
                                    if !teleprompterIsBeingDragged {
                                        teleprompterIsBeingDragged = true
                                        teleprompterDragStartOffset = teleprompterScrollOffset
                                        if teleprompterIsPreviewing {
                                            teleprompterIsPreviewing = false
                                        }
                                        teleprompterAutoScrollDuringRecording = false
                                    }

                                    let dragMultiplier: CGFloat = 1.9
                                    let clampedPanelHeight = max(teleprompterPanelHeight, 1)
                                    let expandedLimit = teleprompterContentHeight + (clampedPanelHeight * 2.5)
                                    let maxOffset = max(expandedLimit, 0)
                                    let proposed = teleprompterDragStartOffset - (value.translation.height * dragMultiplier)
                                    teleprompterScrollOffset = min(max(0, proposed), maxOffset)
                                }
                                .onEnded { _ in
                                    teleprompterIsBeingDragged = false
                                    teleprompterDragStartOffset = teleprompterScrollOffset
                                }
                        )
                        .simultaneousGesture(
                            TapGesture()
                                .onEnded {
                                    presentTeleprompterScriptEditor()
                                }
                        )
                        .padding(.horizontal, 24)
                        .padding(.top, 32)
                    }
                    .frame(
                        maxWidth: .infinity,
                        maxHeight: panelHeight + 64,
                        alignment: .top
                    )
                    .onAppear {
                        teleprompterPanelHeight = panelHeight
                        if telemetryEnabled {
                            print("📐 [Teleprompter] Panel height set on appear: \(panelHeight)")
                        }
                    }
                    .onChange(of: teleprompterHeightFraction, initial: false) { _, newFraction in
                        teleprompterPanelHeight = teleprompterPanelHeight(for: hostHeight, fraction: newFraction)
                        if telemetryEnabled {
                            print("📐 [Teleprompter] Panel height updated for fraction \(newFraction): \(teleprompterPanelHeight)")
                        }
                    }
                    .onChange(of: geo.size.height, initial: false) { _, newHostHeight in
                        teleprompterPanelHeight = teleprompterPanelHeight(for: newHostHeight, fraction: teleprompterHeightFraction)
                        if telemetryEnabled {
                            print("📐 [Teleprompter] Panel height updated for hostHeight \(newHostHeight): \(teleprompterPanelHeight)")
                        }
                    }
                    .onPreferenceChange(TeleprompterContentHeightKey.self) { value in
                        teleprompterContentHeight = value
                        if telemetryEnabled {
                            print("📐 [Teleprompter] Content height updated: \(value)")
                        }
                    }
                }

            }
            .transition(.move(edge: .top).combined(with: .opacity))
            .allowsHitTesting(true)
        } else {
            EmptyView().allowsHitTesting(false)
        }
    }

    @ViewBuilder
    private func framingContextBand(in geo: GeometryProxy) -> some View {
        if shouldShowFramingContextBand {
            VStack(spacing: 6) {
                Text(framingContextLabel)
                    .font(.system(size: 15, weight: .bold, design: .default))
                    .tracking(1.0)
                    .foregroundStyle(Color.white.opacity(0.95))
                    .shadow(color: Color.black.opacity(0.3), radius: 2.5, x: 0, y: 1)

                Divider()
                    .background(Color.white.opacity(0.2))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(red: 0.8, green: 0.3, blue: 0.7).opacity(0.3))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.black.opacity(0.85), lineWidth: 1)
            )
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal, 24)
            .padding(.top, max(8, geo.safeAreaInsets.top + 4))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .allowsHitTesting(false)
            .transition(.opacity)
        }
    }

    private var teleprompterScriptEditorOverlay: some View {
        GeometryReader { geo in
            let horizontalPadding: CGFloat = 24
            let verticalPadding: CGFloat = 24
            let safeWidth = max(0, geo.size.width - geo.safeAreaInsets.leading - geo.safeAreaInsets.trailing)
            let safeHeight = max(0, geo.size.height - geo.safeAreaInsets.top - geo.safeAreaInsets.bottom)
            let availableWidth = max(0, safeWidth - (horizontalPadding * 2))
            let availableHeight = max(0, safeHeight - (verticalPadding * 2))
            let layoutIsLandscape = availableWidth > availableHeight
            let useSideBySide = layoutIsLandscape && availableWidth >= 680
            let maxWidth = min(availableWidth, useSideBySide ? 760 : 360)
            let maxHeight = min(availableHeight, useSideBySide ? 520 : 720)

            ZStack {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture {
                        dismissTeleprompterScriptEditor()
                    }

                TeleprompterScriptEditorSheet(
                    autoScript: teleprompterEditorAutoPrompt,
                    initialMode: teleprompterEditorMode,
                    initialCustomScript: teleprompterEditorDraft,
                    isRecording: isRecording,
                    isLandscape: isLandscape,
                    theme: sheetTheme,
                    onSave: { mode, customDraft, clearCustomDraft in
                        teleprompterAutoSaveWorkItem?.cancel()
                        teleprompterAutoSaveWorkItem = nil
                        applyTeleprompterScriptUpdate(
                            mode: mode,
                            customDraft: customDraft,
                            clearCustomDraft: clearCustomDraft
                        )
                        dismissTeleprompterScriptEditor()
                    },
                    onAutoSave: { mode, customDraft in
                        scheduleTeleprompterAutoSave(mode: mode, customDraft: customDraft)
                    },
                    onCancel: {
                        dismissTeleprompterScriptEditor()
                    }
                )
                .frame(maxWidth: maxWidth, maxHeight: maxHeight)
                .background(
                    .ultraThinMaterial,
                    in: RoundedRectangle(cornerRadius: 20, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.35), radius: 22, x: 0, y: 16)
                .padding(.horizontal, horizontalPadding)
                .padding(.vertical, verticalPadding)
                .accessibilityElement(children: .contain)
                .accessibilityAddTraits(.isModal)
                .transition(.opacity.combined(with: .scale))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .zIndex(6000)
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }

    // MARK: - Top Bar (Scene / Slate selector + Settings & Docs)
    @ViewBuilder
    private var topBar: some View {
        if pipSlatePhase == .none {
            VStack {
                if isLandscape {
                    // LANDSCAPE: Scene selector on the left, Watch HUD in the middle,
                    // and PiP / Settings / Docs chips on the right.
                    HStack(alignment: .top, spacing: 10) {
                        if !isRecording && !isTeleprompterFocused {
                            SceneSelectorView(
                                onComplete: {
                                    print("🎬 [CameraCaptureView] SceneSelectorView.onComplete invoked – debugID = \(debugID)")
                                    isSlateOverlayVisible = false
                                    activeSlatePrompt = ""
                                    exitCameraAndReturnToReview(source: "SceneSelectorView.onComplete")
                                },
                                onSlateAction: { presentSlatePrompt() },
                                onKeyframeAction: { handleKeyframeSelection() },
                                debugCameraID: debugID
                            )
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(.black.opacity(0.4), in: Capsule())
                            .transition(.scale.combined(with: .opacity))
                        }

                        if showWatchHUDMaster && showWatchHUD {
                                HStack(spacing: 6) {
                                    WatchReachabilityHUD()
                                    Button {
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                        showWatchRemoteInfoAlert = true
                                    } label: {
                                        Image(systemName: "info.circle")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundStyle(.white.opacity(0.9))
                                            .padding(8)
                                        .background(.black.opacity(0.35), in: Circle())
                                        .overlay(Circle().stroke(Color.white.opacity(0.25), lineWidth: 1))
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Watch Remote Info")
                            }
                            .padding(.horizontal, 4)
                        }

                        Spacer(minLength: 0)

                        // PiP / Settings / Docs chips
                        pipUtilityControls
                            .frame(maxWidth: 220, alignment: .trailing)
                            .zIndex(isTeleprompterFocused ? 4000 : 0)
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 4)
                } else {
                    // PORTRAIT: separate rows for selector and utility chips
                    VStack(alignment: .leading, spacing: 8) {
                        if !isRecording && !isTeleprompterFocused {
                            HStack {
                                SceneSelectorView(
                                    onComplete: {
                                        print("🎬 [CameraCaptureView] SceneSelectorView.onComplete invoked – debugID = \(debugID)")
                                        isSlateOverlayVisible = false
                                        activeSlatePrompt = ""
                                        exitCameraAndReturnToReview(source: "SceneSelectorView.onComplete")
                                    },
                                    onSlateAction: { presentSlatePrompt() },
                                    onKeyframeAction: { handleKeyframeSelection() },
                                    debugCameraID: debugID
                                )
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(.black.opacity(0.4), in: Capsule())
                                .transition(.scale.combined(with: .opacity))

                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 12)
                            .padding(.top, 4)
                        }

                            HStack {
                                Spacer()

                                if showWatchHUDMaster && showWatchHUD {
                                    HStack(spacing: 6) {
                                        WatchReachabilityHUD()
                                        Button {
                                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                            showWatchRemoteInfoAlert = true
                                        } label: {
                                            Image(systemName: "info.circle")
                                                .font(.system(size: 14, weight: .semibold))
                                                .foregroundStyle(.white.opacity(0.9))
                                                .padding(8)
                                                .background(.black.opacity(0.35), in: Circle())
                                                .overlay(Circle().stroke(Color.white.opacity(0.25), lineWidth: 1))
                                        }
                                        .buttonStyle(.plain)
                                        .accessibilityLabel("Watch Remote Info")
                                    }
                                    .padding(.trailing, 8)
                                }

                                pipUtilityControls
                            }
                        .padding(.horizontal, 12)
                        .zIndex(isTeleprompterFocused ? 4000 : 0)
                    }
                }

                if isRecording {
                    HStack {
                        recordingIndicator
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }

                Spacer()
            }
            .padding(.top, calculateTopBarTopPadding())
        } else if isRecording {
            VStack {
                HStack {
                    recordingIndicator
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                Spacer()
            }
            .padding(.top, calculateTopBarTopPadding())
            .allowsHitTesting(false)
        } else {
            Color.clear.frame(height: 0)
        }
    }

    @ViewBuilder
    private var recordingIndicator: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(Color.red)
                .frame(width: 8, height: 8)
            Text("REC \(timeString(recordingDuration))")
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.red)
        }
    }

    @ViewBuilder
    private var settingsMenu: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.snappy) { showSettingsPopover.toggle() }
        } label: {
            Image(systemName: "gearshape")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .padding(10)
                .background(.ultraThinMaterial, in: Circle())
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showSettingsPopover, attachmentAnchor: .rect(.bounds), arrowEdge: .top) {
            settingsPopoverContent
                .presentationCompactAdaptation(.popover)
        }
    }

    private var recordBlinkTorchBinding: Binding<Bool> {
        Binding(
            get: { recordBlinkTorchEnabled },
            set: { newValue in
                recordBlinkTorchEnabled = newValue
                CameraSettings.recordBlinkTorchEnabled = newValue
            }
        )
    }

    private var torchCueUnavailableReason: String? {
        if engine.currentCameraPosition == .front {
            return "Back camera only"
        }
        if !engine.isTorchAvailable {
            return "Torch not available on this device"
        }
        return nil
    }

    private var isTorchCueAvailable: Bool {
        torchCueUnavailableReason == nil
    }

    // Document badge dropdown with slate teleprompter + controls
    @ViewBuilder
    private var documentMenu: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.snappy) { showDocumentsPopover.toggle() }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "scroll")
                    .font(.system(size: 14, weight: .semibold))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .foregroundColor(.white)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.25), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Documents and Slate Teleprompter")
        .popover(isPresented: $showDocumentsPopover, attachmentAnchor: .rect(.bounds), arrowEdge: .top) {
            documentsPopoverContent
                .presentationCompactAdaptation(.popover)
        }
    }

    private var settingsPopoverContent: some View {
        let maxHeight: CGFloat = {
            let screenHeight = UIScreen.main.bounds.height
            let fraction: CGFloat = isLandscape ? 0.5 : 0.7
            return screenHeight * fraction
        }()

        return ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Camera Settings")
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.9))

                settingsToggleRow(
                    title: "Audio Meter",
                    subtitle: "Show while recording",
                    systemImage: "waveform.path",
                    binding: $showAudioMeter
                )

                settingsToggleRow(
                    title: "Level Indicator",
                    subtitle: "Auto-hides when level",
                    systemImage: "level",
                    binding: $showLevelIndicator
                )

                settingsToggleRow(
                    title: "Record Blink (Back Camera)",
                    subtitle: torchCueUnavailableReason,
                    systemImage: "flashlight.on.fill",
                    binding: recordBlinkTorchBinding
                )
                .disabled(!isTorchCueAvailable)
                .opacity(isTorchCueAvailable ? 1.0 : 0.6)
                
                if showWatchHUDMaster {
                    settingsToggleRow(
                        title: "Watch Remote",
                        subtitle: "Show status",
                        systemImage: "applewatch",
                        binding: $showWatchHUD
                    )
                }

                settingsActionRow(
                    title: "Reset Zoom",
                    systemImage: "1.magnifyingglass",
                    action: resetZoom
                )
            }
            .padding(20)
        }
        .frame(width: 340, alignment: .top)
        .frame(maxHeight: maxHeight, alignment: .top)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.black.opacity(0.85))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        )
    }

    private func settingsToggleRow(title: String, subtitle: String? = nil, systemImage: String, binding: Binding<Bool>) -> some View {
        Toggle(isOn: binding) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 10) {
                    Image(systemName: systemImage)
                        .font(.body)
                    Text(title)
                        .font(.body.weight(.semibold))
                }
                .foregroundStyle(.white)

                if let subtitle {
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
        }
        .toggleStyle(SwitchToggleStyle(tint: Theme.primary))
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.08))
        )
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
    }

    private func openDocument(named title: String) {
        let docs = availableDocuments
        guard let item = docs.first(where: { $0.title == title }) else { return }
        documentViewerItems = docs
        documentViewerSelection = item
        showDocumentsPopover = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            showDocumentViewer = true
        }
    }

    private func openDocument(_ item: DocumentItem) {
        let docs = availableDocuments
        documentViewerItems = docs
        documentViewerSelection = docs.first(where: { $0.id == item.id }) ?? docs.first
        showDocumentsPopover = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            showDocumentViewer = true
        }
    }

    private func documentChip(title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .semibold))
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .foregroundColor(.white)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.25), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func settingsActionRow(title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.body)
                Text(title)
                    .font(.body.weight(.semibold))
                Spacer()
                Image(systemName: "arrow.clockwise.circle")
                    .opacity(0.8)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.08))
            )
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Documents Popover (fixed bubble size + scrolling)
    private var documentsPopoverContent: some View {
        let maxHeight: CGFloat = {
            let screenHeight = UIScreen.main.bounds.height
            let fraction: CGFloat = isLandscape ? 0.6 : 0.8
            return screenHeight * fraction
        }()

        return ScrollView(.vertical, showsIndicators: true) {
            DocumentSelectorView(
                documents: documentSelectorOptions,
                hasBreakdownNotes: !(breakdownNotesText?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .isEmpty ?? true),
                showsBreakdownNotesRow: !isTeleprompterFocused,
                isTeleprompterVisible: isSlateOverlayVisible,
                onDocumentSelected: { option in
                    showDocumentsPopover = false
                    handleDocumentSelection(option: option)
                },
                onShowBreakdownNotes: {
                    showDocumentsPopover = false
                    showTeleprompterControls = false
                    withAnimation(.spring(response: 0.35,
                                          dampingFraction: 0.9)) {
                        showBreakdownNotes = true
                    }
                },
                onToggleTeleprompter: {
                    showDocumentsPopover = false
                    showBreakdownNotes = false

                    let wasVisible = isSlateOverlayVisible
                    toggleSlateTeleprompter()

                    withAnimation(.spring(response: 0.35,
                                          dampingFraction: 0.9)) {
                        showTeleprompterControls = !wasVisible
                    }
                },
                onShowTeleprompterControls: {
                    showDocumentsPopover = false
                    showBreakdownNotes = false

                    if !isSlateOverlayVisible {
                        toggleSlateTeleprompter()
                    }

                    withAnimation(.spring(response: 0.35,
                                          dampingFraction: 0.9)) {
                        showTeleprompterControls = true
                    }
                }
            )
            .padding(.vertical, 8)
            .padding(.horizontal, 4)
        }
        .frame(width: 340, alignment: .top)
        .frame(maxHeight: maxHeight, alignment: .top)
    }

    // MARK: - Record Button and Layouts (unchanged)
    @ViewBuilder
    private var landscapeControlsLayout: some View {
        HStack {
            Spacer()
            VStack {
                Spacer()
                recordControlsBar(isLandscape: true)
                Spacer()
            }
            .padding(.trailing, 30)
        }
    }

    @ViewBuilder
    private var portraitControlsLayout: some View {
        VStack(spacing: 10) {
            recordControlsBar(isLandscape: false)
        }
        .frame(maxHeight: .infinity, alignment: .bottom)
        .padding(.bottom, 34)
    }

    private func recordControlsBar(isLandscape: Bool) -> some View {
        HStack(spacing: 20) {
            if isLandscape {
                recordButton
            } else {
                Spacer()
                recordButton
                Spacer()
            }
        }
        .frame(maxWidth: isLandscape ? nil : .infinity, alignment: isLandscape ? .trailing : .center)
    }

    @ViewBuilder
    private var recordButton: some View {
        Button(action: recordTapped) {
            ZStack {
                Circle()
                    .fill(.white.opacity(0.15))
                    .frame(width: 92, height: 92)

                if currentCameraMode == .photo {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white)
                        .frame(width: 68, height: 68)
                        .overlay(
                            Image(systemName: "camera.fill")
                                .font(.system(size: 24, weight: .medium))
                                .foregroundColor(.black)
                        )
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white, lineWidth: 3))
                } else {
                    Circle()
                        .fill(isRecording ? Color.red : Color.white)
                        .frame(width: 68, height: 68)
                        .overlay(Circle().stroke(Color.white, lineWidth: 3))

                    if isRecording {
                        Circle()
                            .fill(Color.white.opacity(0.14))
                            .frame(width: 120, height: 120)
                            .blur(radius: 1)
                            .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: isRecording)
                    }
                }
            }
        }
        .accessibilityLabel(accessibilityLabelText)
        .disabled(!isCameraReady)
    }

    private var accessibilityLabelText: String {
        if currentCameraMode == .photo { return "Capture Keyframe Photo" }
        else if isRecording { return "Stop Recording" }
        else { return "Start Recording" }
    }

    // MARK: - Camera Controls
    private func handleTapToFocus(at location: CGPoint, in size: CGSize) {
        guard !isInteractingWithAEAFSlider else { return }
        guard let safeLocation = clampedPreviewLocation(from: location, in: size),
              let focusPoint = devicePointOfInterest(for: safeLocation, in: size) else {
            return
        }
        print("🎯 Calling engine.setFocus(at:) with normalized point \(focusPoint)")

        focusLocation = safeLocation
        latestPreviewTouchLocation = safeLocation
        showFocusIndicator = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { showFocusIndicator = false }
        engine.setFocus(at: focusPoint)
    }

    private func handlePreviewTap(at location: CGPoint, in size: CGSize) {
        guard !isInteractingWithAEAFSlider else { return }
        if showAEAFLockHUD || engine.isAEAFLocked {
            if isTapOutsideLockBox(location) {
                clearAEAFLock()
            }
            return
        }
        handleTapToFocus(at: location, in: size)
    }

    private func handleAEAFLockPress(at location: CGPoint, in size: CGSize) {
        guard !isInteractingWithAEAFSlider else { return }
        guard let safeLocation = clampedPreviewLocation(from: location, in: size) else { return }

        if showAEAFLockHUD || engine.isAEAFLocked {
            if isTapOutsideLockBox(safeLocation) {
                clearAEAFLock()
                lockAEAFLock(at: safeLocation, in: size)
            }
            return
        }

        lockAEAFLock(at: safeLocation, in: size)
    }

    private func lockAEAFLock(at location: CGPoint, in size: CGSize) {
        let fallback = CGPoint(x: size.width / 2, y: size.height / 2)
        let targetLocation = (location == .zero) ? fallback : location
        guard isCameraReady,
              let safeLocation = clampedPreviewLocation(from: targetLocation, in: size),
              let focusPoint = devicePointOfInterest(for: safeLocation, in: size) else {
            return
        }

        latestPreviewTouchLocation = safeLocation
        aeafLockLocation = safeLocation
        showAEAFLockHUD = true
        showFocusIndicator = false
        focusLocation = safeLocation
        engine.setExposure(compensation: 0.0)
        aeafHaptic.impactOccurred()
        aeafHaptic.prepare()
        engine.lockAEAFPoint(at: focusPoint)
    }

    private func lockFromManualControls() {
        let fallbackLocation = CGPoint(x: UIScreen.main.bounds.midX, y: UIScreen.main.bounds.midY)
        let candidateLocation = (latestPreviewTouchLocation == .zero) ? fallbackLocation : latestPreviewTouchLocation
        lockAEAFLock(at: candidateLocation, in: UIScreen.main.bounds.size)
    }

    private func clearAEAFLock() {
        guard showAEAFLockHUD || engine.isAEAFLocked else { return }
        showAEAFLockHUD = false
        if engine.isAEAFLocked {
            engine.unlockAEAF()
        }
    }

    private func updateLatestPreviewTouchLocation(_ location: CGPoint, in size: CGSize) {
        guard let safeLocation = clampedPreviewLocation(from: location, in: size) else { return }
        latestPreviewTouchLocation = safeLocation
    }

    private func clampedPreviewLocation(from location: CGPoint, in size: CGSize = UIScreen.main.bounds.size) -> CGPoint? {
        guard location.x.isFinite, location.y.isFinite else {
            print("⚠️ Invalid touch location for AE/AF interaction")
            return nil
        }
        guard size.width > 0 && size.height > 0 &&
                !size.width.isNaN && !size.height.isNaN else {
            print("⚠️ Invalid screen size for AE/AF interaction")
            return nil
        }

        let clampedX = max(0, min(size.width, location.x))
        let clampedY = max(0, min(size.height, location.y))
        guard clampedX.isFinite && clampedY.isFinite else {
            return nil
        }
        return CGPoint(x: clampedX, y: clampedY)
    }

    private func devicePointOfInterest(for location: CGPoint, in size: CGSize) -> CGPoint? {
        guard let layer = previewLayerOut else { return nil }
        let localPoint = CGPoint(
            x: max(0, min(size.width, location.x)),
            y: max(0, min(size.height, location.y))
        )
        return layer.captureDevicePointConverted(fromLayerPoint: localPoint)
    }

    private func isTapOutsideLockBox(_ point: CGPoint) -> Bool {
        let box = CGRect(
            x: aeafLockLocation.x - aeafReticleSize / 2,
            y: aeafLockLocation.y - aeafReticleSize / 2,
            width: aeafReticleSize,
            height: aeafReticleSize
        )
        if box.isEmpty || box.origin == .zero {
            return true
        }
        return !box.contains(point)
    }

    private func resetZoom() {
        currentZoom = 1.0
        engine.setZoom(factor: 1.0)
    }

    private func recordTapped() {
        guard isCameraReady else {
            print("⚠️ Camera not ready for recording")
            return
        }

        if currentCameraMode == .photo {
            capturePhoto()
        } else {
            switch engine.state {
            case .running where !isRecording:
                restoreTeleprompterControlsAfterRecording = showTeleprompterControls
                withAnimation(.easeInOut(duration: 0.3)) {
                    showAudioControls = false
                    showManualControls = false
                    showSessionManager = false
                    showTakesModal = false
                    showTeleprompterControls = false
                }
                engine.startRecording()
            case .recording:
                engine.stopRecording()
            default:
                break
            }
        }
    }


    private func capturePhoto() {
        guard engine.canCapturePhoto else {
            print("⚠️ Camera not ready for photo capture")
            return
        }
        engine.capturePhoto()
        print("📸 Photo capture initiated")
        withAnimation(.easeInOut(duration: 0.2)) {}
    }

    private func makeTakeName() -> String {
        let projectId = project.id.uuidString.prefix(8)
        let sessionId = session.id.uuidString.prefix(8)
        let sceneNumber = sessionManager.currentScene
        let timestamp = Int(Date().timeIntervalSince1970)

        if sessionManager.isRecordingSlate {
            let currentSlateCount = sessionManager.getSlateTakesAsTakes().count + 1
            return "\(projectId)_\(sessionId)_SLATE\(currentSlateCount)_\(timestamp).mov"
        } else {
            let currentSceneTakes = sessionManager.getTakesForScene(sceneNumber).count + 1
            return "\(projectId)_\(sessionId)_S\(sceneNumber)T\(currentSceneTakes)_\(timestamp).mov"
        }
    }

    private func makePhotoName() -> String {
        let projectId = project.id.uuidString.prefix(8)
        let sessionId = session.id.uuidString.prefix(8)
        let timestamp = Int(Date().timeIntervalSince1970)

        if sessionManager.isRecordingKeyframePhoto {
            let keyframePhotoCount = sessionManager.getKeyframePhotoTakesAsTakes().count + 1
            return "\(projectId)_\(sessionId)_PHOTO_KF\(keyframePhotoCount)_\(timestamp).jpg"
        } else {
            let sceneNumber = sessionManager.currentScene
            let scenePhotoCount = sessionManager.getKeyframePhotoTakesAsTakes().filter {
                $0.sceneNumber == sceneNumber
            }.count + 1
            return "\(projectId)_\(sessionId)_PHOTO_S\(sceneNumber)P\(scenePhotoCount)_\(timestamp).jpg"
        }
    }

    // MARK: - Camera Setup
    @State private var processedFiles: Set<String> = []
    @State private var notificationObservers: [NSObjectProtocol] = []

    private func setupCameraOnce() {
        print("🎥 Starting enhanced camera setup...")
        isInitializing = true
        isCameraReady = false
        initializationPhase = .starting

        cleanupNotificationObservers()
        initializationPhase = .requestingPermissions

        requestPermissionsIfNeeded {
            print("🎥 Permissions granted, proceeding to camera configuration...")
            self.initializationPhase = .configuringCamera

            SessionManager.shared.ensureProjectAndSessionInRepository(project: self.project, session: self.session)
            SessionManager.shared.enableUnifiedModels()

            Task { self.engine.attachAudioMonitoring(.shared) }
            self.engine.configureAndStart()
            let initialMode = desiredRecordingMode
            SessionManager.shared.startSession(project: self.project,
                                               session: self.session,
                                               preferredScene: SessionManager.shared.currentScene,
                                               recordingMode: initialMode)
            SessionManager.shared.syncFromRepositoryWithErrorHandling()
            SessionManager.shared.evaluateResumeNudgeOnEntry()

            self.setupNotificationObservers()
            self.validateCameraSetupCompletion()
        }
    }

    private func setupNotificationObservers() {
        cleanupNotificationObservers()

        let videoObserver = NotificationCenter.default.addObserver(forName: .stsDidRecordFile, object: nil, queue: .main) { note in
            guard let url = note.userInfo?["url"] as? URL else {
                print("❌ Recording notification missing URL")
                self.errorMessage = "Recording completed but file URL was missing"
                return
            }

            let fileIdentifier = url.lastPathComponent
            guard !self.processedFiles.contains(fileIdentifier) else {
                print("⚠️ File \(fileIdentifier) already processed, skipping duplicate")
                return
            }
            self.processedFiles.insert(fileIdentifier)

            let isVerified = note.userInfo?["verified"] as? Bool ?? false
            let fileSize = note.userInfo?["fileSize"] as? Int ?? 0

            let capturedOrientation = note.userInfo?["capturedOrientation"] as? VideoOrientation
            _ = note.userInfo?["deviceOrientation"] as? UIDeviceOrientation

            print("📹 Processing recorded file: \(url.lastPathComponent) (Verified: \(isVerified), Size: \(fileSize) bytes)")
            print("📱 Recorded with orientation: \(capturedOrientation?.displayName ?? "Unknown")")

            let fileName = self.makeTakeName()

            self.persistRecordedFile(
                from: url,
                as: fileName,
                originalSize: fileSize,
                capturedOrientation: capturedOrientation
            )

            self.stopRecordingTimer()
            self.isRecording = false
        }

        let photoObserver = NotificationCenter.default.addObserver(forName: .stsDidCapturePhoto, object: nil, queue: .main) { note in
            guard let url = note.userInfo?["url"] as? URL else {
                print("❌ Photo notification missing URL")
                self.errorMessage = "Photo captured but file URL was missing"
                return
            }

            let fileIdentifier = url.lastPathComponent
            guard !self.processedFiles.contains(fileIdentifier) else {
                print("⚠️ Photo \(fileIdentifier) already processed, skipping duplicate")
                return
            }
            self.processedFiles.insert(fileIdentifier)

            let isVerified = note.userInfo?["verified"] as? Bool ?? false
            let fileSize = note.userInfo?["fileSize"] as? Int ?? 0

            let capturedOrientation = note.userInfo?["capturedOrientation"] as? VideoOrientation
            _ = note.userInfo?["deviceOrientation"] as? UIDeviceOrientation

            print("📸 Processing captured photo: \(url.lastPathComponent) (Verified: \(isVerified), Size: \(fileSize) bytes)")
            print("📱 Captured with orientation: \(capturedOrientation?.displayName ?? "Unknown")")

            let fileName = self.makePhotoName()

            self.persistCapturedPhoto(
                from: url,
                as: fileName,
                originalSize: fileSize,
                capturedOrientation: capturedOrientation
            )
        }

        notificationObservers = [videoObserver, photoObserver]
        print("✅ Notification observers setup complete with orientation support")
    }

    private func cleanupNotificationObservers() {
        for observer in notificationObservers {
            NotificationCenter.default.removeObserver(observer)
        }
        notificationObservers.removeAll()
        processedFiles.removeAll()
        print("🧹 Notification observers cleaned up")
    }

    private func cleanupCamera() {
        let stopStart = CFAbsoluteTimeGetCurrent()
        print(String(format: "🛑 [Perf] cleanupCamera invoked at t=%.3f", stopStart))
        let engineReference = engine
        DispatchQueue.global(qos: .userInitiated).async {
            let t0 = CFAbsoluteTimeGetCurrent()
            print(String(format: "🛑 [Perf] stopSession starting (state=%@) at t=%.3f", String(describing: engineReference.state), t0))
            engineReference.stopSession()
            let t1 = CFAbsoluteTimeGetCurrent()
            print(String(format: "🛑 [Perf] stopSession completed in %.3f s", t1 - t0))
        }

        stopRecordingTimer()
        cleanupNotificationObservers()
        print("🧹 Camera cleanup scheduled (engine teardown off main thread)")
    }

    private func validateCameraSetupCompletion() {
        let maxAttempts = 10
        var attempts = 0

        func checkCameraState() {
            attempts += 1
            if engine.state == .running {
                DispatchQueue.main.async {
                    self.initializationPhase = .ready
                    self.isCameraReady = true
                    self.isInitializing = false
                    print("✅ Camera setup complete and validated - ready for use")
                }
            } else if attempts < maxAttempts {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { checkCameraState() }
            } else {
                DispatchQueue.main.async {
                    self.initializationPhase = .failed("Camera failed to start properly. Please try again.")
                    print("❌ Camera setup failed after \(maxAttempts) attempts")
                }
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { checkCameraState() }
    }

    private func retryInitialization() {
        initializationPhase = .starting
        setupCameraOnce()
    }

    // MARK: - Permission Handling
    private func requestPermissionsIfNeeded(granted: @escaping () -> Void) {
        func requestMic(_ cont: @escaping () -> Void) {
            if #available(iOS 17.0, *) {
                AVAudioApplication.requestRecordPermission { ok in
                    DispatchQueue.main.async {
                        ok ? cont() :
                        (self.initializationPhase = .failed("Microphone permission is required to record audio."))
                    }
                }
            } else {
                AVAudioSession.sharedInstance().requestRecordPermission { ok in
                    DispatchQueue.main.async {
                        ok ? cont() :
                        (self.initializationPhase = .failed("Microphone permission is required to record audio."))
                    }
                }
            }
        }

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            requestMic(granted)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { ok in
                DispatchQueue.main.async {
                    ok ? requestMic(granted) :
                    (self.initializationPhase = .failed("Camera permission is required to record video."))
                }
            }
        default:
            initializationPhase = .failed("Camera permission is required. Please enable it in Settings.")
        }
    }

    // MARK: - Timer/Formatting
    private func startRecordingTimer() {
        stopRecordingTimer()
        recordingStartDate = Date()
        recordingDuration = 0
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            if let start = recordingStartDate {
                recordingDuration = Date().timeIntervalSince(start)
            }
        }
    }

    private func stopRecordingTimer() {
        recordingTimer?.invalidate()
        recordingTimer = nil
    }

    private func timeString(_ duration: TimeInterval) -> String {
        guard !duration.isNaN && !duration.isInfinite && duration >= 0 else {
            return "0:00.0"
        }
        let min = Int(duration) / 60
        let sec = Int(duration) % 60
        let ms = Int((duration * 10).truncatingRemainder(dividingBy: 10))
        return String(format: "%d:%02d.%d", min, sec, ms)
    }

    @ViewBuilder
    private var captureView: some View {
        GeometryReader { geo in
            ZStack {
                CameraPreviewView(session: engine.session, previewLayerOut: $previewLayerOut)
                    .ignoresSafeArea()
                    .zIndex(0)

                Color.clear
                    .contentShape(Rectangle())
                    .allowsHitTesting(!isInteractingWithAEAFSlider)
                    .ignoresSafeArea()
                    .zIndex(1)
                    .sensoryFeedback(.impact(weight: .medium), trigger: aeafHapticTrigger)

                    // TAP should always win (and we need location)
                    .highPriorityGesture(
                        SpatialTapGesture()
                            .onEnded { value in
                                let loc = value.location
                                print("✅ SpatialTap tap at:", loc)
                                handlePreviewTap(at: loc, in: geo.size)
                            }
                    )

                    // Pinch zoom (coexists with tap)
                    .simultaneousGesture(
                        MagnificationGesture()
                            .updating($zoomGestureScale) { value, state, _ in
                                guard !value.isNaN && !value.isInfinite else { return }
                                state = value
                                let newZoom = currentZoom * value
                                guard !newZoom.isNaN && !newZoom.isInfinite else { return }
                                engine.setZoom(factor: newZoom)
                            }
                            .onEnded { value in
                                guard !value.isNaN && !value.isInfinite else { return }
                                let newZoom = currentZoom * value
                                guard !newZoom.isNaN && !newZoom.isInfinite else { return }
                                currentZoom = max(1.0, min(newZoom, 5.0))
                                engine.setZoom(factor: currentZoom)
                            }
                    )

                    // Track latest touch point continuously
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 0, coordinateSpace: .local)
                            .onChanged { value in
                                updateLatestPreviewTouchLocation(value.location, in: geo.size)
                            }
                    )

                    // Long-press lock with reliable press location
                    .simultaneousGesture(
                        LongPressGesture(minimumDuration: 0.45, maximumDistance: 30)
                            .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .local))
                            .onChanged { value in
                                if case .first(true) = value {
                                    aeafGestureHapticFired = false
                                }
                                if case .second(true, let drag?) = value {
                                    updateLatestPreviewTouchLocation(drag.location, in: geo.size)
                                    if !aeafGestureHapticFired {
                                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                                        aeafGestureHapticFired = true
                                    }
                                }
                            }
                            .onEnded { value in
                                if case .second(true, let drag?) = value {
                                    print("✅ longpress at:", drag.location)
                                    print("🔥 AEAF haptic trigger")
                                    aeafHapticTrigger &+= 1
                                    let g = UINotificationFeedbackGenerator()
                                    g.prepare()
                                    g.notificationOccurred(.success)
                                    handleAEAFLockPress(at: drag.location, in: geo.size)
                                    aeafGestureHapticFired = false
                                }
                            }
                    )

                if isCameraReady && !isInitializing {
                    pipCaptureOverlay
                        .zIndex(10)
                        .allowsHitTesting(pipSlatePhase != .none)

                    framingContextBand(in: geo)
                        .zIndex(25)

                    slateTeleprompterOverlay
                        .zIndex(20)
                        .allowsHitTesting(isSlateOverlayVisible)

                    cameraUIOverlays
                        .zIndex(30)
                }
            }
        }
    }

    // MARK: - Video Persistence + Metadata
    private func persistRecordedFile(from sourceURL: URL, as fileName: String, originalSize: Int, capturedOrientation: VideoOrientation? = nil) {
        do {
            guard FileManager.default.fileExists(atPath: sourceURL.path) else {
                throw NSError(domain: "STS.FileSystem", code: -1,
                              userInfo: [NSLocalizedDescriptionKey: "Source file no longer exists: \(sourceURL.path)"])
            }

            let sourceSize = (try? FileManager.default.attributesOfItem(atPath: sourceURL.path)[.size] as? Int) ?? 0
            let sourceMB = Double(sourceSize) / 1024.0 / 1024.0
            print("✅ Source file verified: \(sourceURL.path) (\(String(format: "%.2f", sourceMB)) MB)")
            print("📱 Captured orientation: \(capturedOrientation?.displayName ?? "Unknown")")

            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let destination = docs.appendingPathComponent(fileName)

            if FileManager.default.fileExists(atPath: destination.path) {
                print("⚠️ File already exists but using unique timestamp filename: \(fileName)")
                throw NSError(domain: "STS.FileSystem", code: -3,
                              userInfo: [NSLocalizedDescriptionKey: "File already exists despite unique naming: \(fileName)"])
            }

            try FileManager.default.copyItem(at: sourceURL, to: destination)
            print("✅ Video copied to: \(destination.path)")

            guard FileManager.default.fileExists(atPath: destination.path) else {
                throw NSError(domain: "STS.FileSystem", code: -2,
                              userInfo: [NSLocalizedDescriptionKey: "File copy completed but destination file not found"])
            }

            let finalSize = (try? FileManager.default.attributesOfItem(atPath: destination.path)[.size] as? Int) ?? 0
            let finalSizeMB = Double(finalSize) / 1024.0 / 1024.0
            print("✅ Video successfully persisted: \(destination.path)")
            print("📊 File size: \(String(format: "%.2f MB", finalSizeMB)) MB (Source: \(sourceSize) bytes, Final: \(finalSize) bytes)")

            self.extractVideoMetadataAndUpdateSession(
                relativePath: fileName,
                fileName: fileName,
                fileSize: Int64(finalSize),
                capturedOrientation: capturedOrientation
            )
        } catch {
            print("❌ File persistence failed: \(error)")
            errorMessage = "Failed to save recording: \(error.localizedDescription)"
        }
    }

    private func extractVideoMetadataAndUpdateSession(relativePath: String, fileName: String, fileSize: Int64, capturedOrientation: VideoOrientation? = nil) {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let absolutePath = docs.appendingPathComponent(relativePath).path
        let asset = AVURLAsset(url: URL(fileURLWithPath: absolutePath))

        Task {
            do {
                let duration: CMTime = try await withTimeout(seconds: 5.0) { try await asset.load(.duration) }
                let durationSeconds = duration.seconds
                let safeDuration = (!durationSeconds.isNaN && !durationSeconds.isInfinite && durationSeconds > 0) ? durationSeconds : 0.0

                let finalOrientation: VideoOrientation?
                if let capturedOrientation = capturedOrientation {
                    finalOrientation = capturedOrientation
                } else {
                    finalOrientation = try await self.extractOrientationFromVideoMetadata(asset: asset)
                }

                print("✅ Video metadata extracted: Duration: \(safeDuration)s, Orientation: \(finalOrientation?.displayName ?? "Unknown")")

                await MainActor.run {
                    self.updateSessionManagerWithMetadata(
                        fileName: fileName,
                        relativePath: relativePath,
                        duration: safeDuration,
                        fileSize: fileSize,
                        capturedOrientation: finalOrientation
                    )
                    self.storePIPSlateTakeIfNeeded(relativePath: relativePath, duration: safeDuration)
                }
            } catch {
                print("❌ Video metadata extraction failed: \(error)")
                await MainActor.run {
                    self.updateSessionManagerWithMetadata(
                        fileName: fileName,
                        relativePath: relativePath,
                        duration: 0.0,
                        fileSize: fileSize,
                        capturedOrientation: capturedOrientation
                    )
                    self.storePIPSlateTakeIfNeeded(relativePath: relativePath, duration: 0.0)
                }
            }
        }
    }

    private func extractOrientationFromVideoMetadata(asset: AVURLAsset) async throws -> VideoOrientation? {
        let videoTracks = try await asset.loadTracks(withMediaType: .video)
        guard let videoTrack = videoTracks.first else { return nil }

        let naturalSize = try await videoTrack.load(.naturalSize)
        let preferredTransform = try await videoTrack.load(.preferredTransform)
        _ = naturalSize.height > naturalSize.width

        let angle = atan2(preferredTransform.b, preferredTransform.a) * 180 / .pi
        let normalizedAngle = angle < 0 ? angle + 360 : angle

        switch normalizedAngle {
        case 45..<135, 225..<315:
            return .portrait
        default:
            return .landscape
        }
    }

    private func updateSessionManagerWithMetadata(fileName: String, relativePath: String, duration: TimeInterval, fileSize: Int64, capturedOrientation: VideoOrientation? = nil) {
        // PiP component clips are managed via pipSlateSession only; do not persist as regular/slate takes.
        if pipSlatePhase != .none {
            print("ℹ️ Skipping ProjectTake persistence for PiP component clip: \(fileName)")
            return
        }

        SessionManager.shared.addUnifiedTakeWithOrientation(
            fileName: fileName,
            projectID: self.project.id,
            sessionID: self.session.id,
            filePath: relativePath,
            duration: duration,
            fileSize: fileSize,
            cameraPosition: self.engine.currentCameraPosition == .front ? "front" : "back",
            capturedOrientation: capturedOrientation,
            notes: nil
        )

        print("✅ SessionManager updated with unified take - Duration: \(duration)s, Size: \(fileSize) bytes")
        print("📱 Orientation: \(capturedOrientation?.displayName ?? "Unknown")")
        print("📍 File path stored (RELATIVE): \(relativePath)")
        print("🔥 CRITICAL PATH VOLATILITY FIX: Now immune to container UUID changes!")
    }

    // MARK: - Photo persistence
    private func persistCapturedPhoto(from sourceURL: URL, as fileName: String, originalSize: Int, capturedOrientation: VideoOrientation? = nil) {
        do {
            guard FileManager.default.fileExists(atPath: sourceURL.path) else {
                throw NSError(domain: "STS.FileSystem", code: -1,
                              userInfo: [NSLocalizedDescriptionKey: "Source photo no longer exists: \(sourceURL.path)"])
            }

            let sourceSize = (try? FileManager.default.attributesOfItem(atPath: sourceURL.path)[.size] as? Int) ?? 0
            print("📁 Source photo verified: \(sourceURL.path) (Size: \(sourceSize) bytes)")
            print("📱 Photo captured with orientation: \(capturedOrientation?.displayName ?? "Unknown")")

            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let destination = docs.appendingPathComponent(fileName)

            if FileManager.default.fileExists(atPath: destination.path) {
                print("⚠️ Photo already exists but using unique timestamp filename: \(fileName)")
                throw NSError(domain: "STS.FileSystem", code: -3,
                              userInfo: [NSLocalizedDescriptionKey: "Photo already exists despite unique naming: \(fileName)"])
            }

            try FileManager.default.copyItem(at: sourceURL, to: destination)
            print("✅ Photo copied to: \(destination.path)")

            guard FileManager.default.fileExists(atPath: destination.path) else {
                throw NSError(domain: "STS.FileSystem", code: -2,
                              userInfo: [NSLocalizedDescriptionKey: "Photo copy completed but destination file not found"])
            }

            let finalSize = (try? FileManager.default.attributesOfItem(atPath: destination.path)[.size] as? Int) ?? 0
            let finalSizeMB = Double(finalSize) / 1024.0 / 1024.0
            print("✅ Photo successfully persisted: \(destination.path)")
            print("📊 Photo size: \(String(format: "%.2f MB", finalSizeMB)) (Source: \(sourceSize) bytes, Final: \(finalSize) bytes)")

            updateSessionManagerWithPhoto(
                fileName: fileName,
                relativePath: fileName,
                fileSize: Int64(finalSize),
                capturedOrientation: capturedOrientation
            )

        } catch {
            print("❌ Photo persistence failed: \(error)")
            errorMessage = "Failed to save photo: \(error.localizedDescription)"
        }
    }

    private func updateSessionManagerWithPhoto(fileName: String, relativePath: String, fileSize: Int64, capturedOrientation: VideoOrientation? = nil) {
        SessionManager.shared.addUnifiedPhotoTakeWithOrientation(
            fileName: fileName,
            projectID: self.project.id,
            sessionID: self.session.id,
            filePath: relativePath,
            fileSize: fileSize,
            cameraPosition: self.engine.currentCameraPosition == .front ? "front" : "back",
            capturedOrientation: capturedOrientation,
            notes: nil
        )

        print("✅ SessionManager updated with photo take - Size: \(fileSize) bytes")
        print("📱 Photo orientation: \(capturedOrientation?.displayName ?? "Unknown")")
        print("📍 Photo path stored (RELATIVE): \(relativePath)")
        print("🔥 CRITICAL PATH VOLATILITY FIX: Photo paths now immune to container UUID changes!")
    }

    // MARK: - Dynamic Positioning Helpers
    private var safeAreaInsets: (top: CGFloat, bottom: CGFloat) {
        let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene
        let window = windowScene?.windows.first
        let top = window?.safeAreaInsets.top ?? 44
        let bottom = window?.safeAreaInsets.bottom ?? 34
        return (top: top, bottom: bottom)
    }

    private func calculateLayoutMetrics() -> LayoutMetrics {
        let safeArea = safeAreaInsets
        let isPortraitMode = !isLandscape

        let manualControlsHeight: CGFloat = 180
        let audioControlsHeight: CGFloat = 140
        let levelIndicatorHeight: CGFloat = 80
        let topBarHeight: CGFloat = 60

        let screenHeight = UIScreen.main.bounds.height
        let availableHeight = screenHeight - safeArea.top - safeArea.bottom

        if isPortraitMode {
            return calculatePortraitLayout(
                availableHeight: availableHeight,
                safeArea: safeArea,
                manualControlsHeight: manualControlsHeight,
                audioControlsHeight: audioControlsHeight,
                levelIndicatorHeight: levelIndicatorHeight,
                topBarHeight: topBarHeight
            )
        } else {
            return calculateLandscapeLayout(
                availableHeight: availableHeight,
                safeArea: safeArea,
                manualControlsHeight: manualControlsHeight,
                audioControlsHeight: audioControlsHeight,
                levelIndicatorHeight: levelIndicatorHeight,
                topBarHeight: topBarHeight
            )
        }
    }

    private func calculatePortraitLayout(
        availableHeight: CGFloat,
        safeArea: (top: CGFloat, bottom: CGFloat),
        manualControlsHeight: CGFloat,
        audioControlsHeight: CGFloat,
        levelIndicatorHeight: CGFloat,
        topBarHeight: CGFloat
    ) -> LayoutMetrics {
        var metrics = LayoutMetrics()
        metrics.topBarPadding = safeArea.top + 12

        var currentBottomOffset: CGFloat = 20

        if showManualControls {
            metrics.manualControlsBottom = currentBottomOffset
            currentBottomOffset += manualControlsHeight + 20
        }

        if showLevelIndicator {
            if showManualControls {
                metrics.levelIndicatorBottom = currentBottomOffset - 20
                currentBottomOffset = max(currentBottomOffset, metrics.levelIndicatorBottom + levelIndicatorHeight + 20)
            } else {
                metrics.levelIndicatorBottom = 150
                currentBottomOffset = max(currentBottomOffset, metrics.levelIndicatorBottom + levelIndicatorHeight + 20)
            }
        }

        if showAudioControls {
            if showLevelIndicator {
                metrics.audioControlsBottom = currentBottomOffset + 20
                currentBottomOffset = max(currentBottomOffset, metrics.audioControlsBottom + audioControlsHeight + 20)
            } else if showManualControls {
                metrics.audioControlsBottom = currentBottomOffset + 20
                currentBottomOffset = max(currentBottomOffset, metrics.audioControlsBottom + audioControlsHeight + 20)
            } else {
                metrics.audioControlsBottom = 200
                currentBottomOffset = max(currentBottomOffset, metrics.audioControlsBottom + audioControlsHeight + 20)
            }
        }

        let minTopClearance = safeArea.top + topBarHeight + 20
        if currentBottomOffset > availableHeight - minTopClearance {
            let compressionRatio = (availableHeight - minTopClearance) / currentBottomOffset
            metrics.audioControlsBottom *= compressionRatio
            metrics.levelIndicatorBottom *= compressionRatio
            metrics.manualControlsBottom *= compressionRatio
        }

        return metrics
    }

    private func calculateLandscapeLayout(
        availableHeight: CGFloat,
        safeArea: (top: CGFloat, bottom: CGFloat),
        manualControlsHeight: CGFloat,
        audioControlsHeight: CGFloat,
        levelIndicatorHeight: CGFloat,
        topBarHeight: CGFloat
    ) -> LayoutMetrics {
        var metrics = LayoutMetrics()
        metrics.topBarPadding = max(safeArea.top + 4, 8)
        let minBottomSafeArea: CGFloat = max(safeArea.bottom + 4, 8)

        if showManualControls {
            metrics.manualControlsBottom = minBottomSafeArea
        }

        if showLevelIndicator {
            if showManualControls && showAudioControls {
                metrics.levelIndicatorBottom = minBottomSafeArea + manualControlsHeight + 10
            } else if showManualControls {
                metrics.levelIndicatorBottom = minBottomSafeArea + manualControlsHeight + 10
            } else {
                metrics.levelIndicatorBottom = 80
            }
        }

        if showAudioControls {
            if showManualControls && showLevelIndicator {
                let safeMiddlePosition = (availableHeight * 0.4)
                metrics.audioControlsBottom = max(safeMiddlePosition, minBottomSafeArea + 160)
            } else if showManualControls {
                metrics.audioControlsBottom = minBottomSafeArea + 120
            } else if showLevelIndicator {
                metrics.audioControlsBottom = max(metrics.levelIndicatorBottom + 60, minBottomSafeArea + 100)
            } else {
                metrics.audioControlsBottom = minBottomSafeArea + 80
            }
        }

        let maxTopPosition = availableHeight - safeArea.top - 40

        if showAudioControls && (metrics.audioControlsBottom + audioControlsHeight) > maxTopPosition {
            metrics.audioControlsBottom = max(maxTopPosition - audioControlsHeight, minBottomSafeArea + 40)
        }

        if showAudioControls && showLevelIndicator && (metrics.levelIndicatorBottom + levelIndicatorHeight + 20) > metrics.audioControlsBottom {
            metrics.levelIndicatorBottom = max(metrics.audioControlsBottom - levelIndicatorHeight - 10, minBottomSafeArea + 20)
        }

        return metrics
    }

    private func calculateAudioControlsBottomPadding() -> CGFloat {
        let metrics = calculateLayoutMetrics()
        return metrics.audioControlsBottom
    }

    private func calculateTopBarTopPadding() -> CGFloat {
        let metrics = calculateLayoutMetrics()
        return metrics.topBarPadding
    }

    private func calculateLevelIndicatorBottomPadding() -> CGFloat {
        let metrics = calculateLayoutMetrics()
        return metrics.levelIndicatorBottom
    }

    private func calculateManualControlsBottomPadding() -> CGFloat {
        let metrics = calculateLayoutMetrics()
        return metrics.manualControlsBottom
    }

    struct LayoutMetrics {
        var topBarPadding: CGFloat = 0
        var audioControlsBottom: CGFloat = 0
        var levelIndicatorBottom: CGFloat = 0
        var manualControlsBottom: CGFloat = 0
    }
}

// (Watch Remote Info alert now presented inline; helper view removed)

// MARK: - PIP Layout Constants
private enum PIPLayout {
    static let portraitInset: CGFloat = 20
    static let portraitHorizontalOffset: CGFloat = -16
    static let portraitVerticalOffset: CGFloat = -36
}

// Update camera engine mode immediately when SessionManager changes
extension CameraCaptureView {
    private func configureWatchBridge() {
        guard !watchBridgeConfigured else { return }
        WatchBridge.shared.cameraController = engine
        WatchBridge.shared.modeController = SessionManager.shared
        WatchBridge.shared.start()
        watchBridgeConfigured = true
        notifyCurrentModeChange()
    }

    private func notifyCurrentModeChange() {
        let state = currentRemoteModeState()
        ModeOverlayBus.shared.show(text: state.label)
        WatchBridge.shared.notifyRemoteState(
            label: state.label,
            modeValue: state.modeValue,
            sceneIndex: state.sceneIndex,
            slateStyleIndex: state.slateStyleIndex
        )
    }
    
    private func handleRemoteModeChange(mode: String, index: Int?) {
        if mode == "slate" {
            if let index {
                handleRemoteSlateStyleChange(index: index)
            }
            return
        }
        
        if pipSlatePhase != .none {
            print("🎬 [WatchRemote] Mode change (\(mode)) received while PiP active – completing capture")
            completePIPSlateCapture(shouldRestoreSceneMode: false)
        }
    }
    
    private func handleRemoteSlateStyleChange(index: Int) {
        let style: SlateCaptureStyle
        switch index {
        case 2:
            style = .pictureInPicture
        case 1:
            style = .smartFill
        default:
            style = .standard
        }
        applyRemoteSlateStyle(style)
    }
    
    private func currentSlateStyleIndex() -> Int {
        switch slateCaptureStyle {
        case .pictureInPicture:
            return 2
        case .smartFill:
            return 1
        case .standard:
            return 0
        }
    }
    
    private func applyRemoteSlateStyle(_ style: SlateCaptureStyle) {
        slateCaptureStyle = style
        switch style {
        case .pictureInPicture:
            if pipSlatePhase == .none {
                startPIPSlateFlow()
            }
            isSlateOverlayVisible = false
            activeSlatePrompt = ""
        case .smartFill:
            startSmartSlateFlow()
            isSlateOverlayVisible = false
            activeSlatePrompt = ""
        case .standard:
            startSmartSlateFlow()
            isSlateOverlayVisible = false
            activeSlatePrompt = ""
        }
    }
    

    private func currentModeLabel() -> String {
        return currentRemoteModeState().label
    }
    
    private func currentRemoteModeState() -> (label: String, modeValue: String, sceneIndex: Int, slateStyleIndex: Int) {
        let scene = sessionManager.currentScene
        let slateIndex = currentSlateStyleIndex()
        
        if sessionManager.isRecordingKeyframePhoto {
            return ("PHOTO", "photo", scene, slateIndex)
        }
        
        if sessionManager.isRecordingSlate || isPiPActive {
            return ("SLATE", "slate", scene, slateIndex)
        }
        
        return ("SCENE \(scene)", "scene", scene, slateIndex)
    }
    
    private var slateProjectSnapshot: Project {
        if let repo = sessionManager.repositoryInstance,
           let refreshed = repo.project(by: project.id) {
            return refreshed
        }
        return project
    }
    
    private var slateSessionSnapshot: ProjectSession {
        let snapshotProject = slateProjectSnapshot
        if let updated = snapshotProject.sessions.first(where: { $0.id == session.id }) {
            return updated
        }
        return session
    }
    
    private var slateSelectionsSnapshot: SlateSelections {
        slateProjectSnapshot.slateSelections
    }

    private var framingContextLabel: String {
        switch slateSelectionsSnapshot.framingSelection {
        case .closeUp:
            return "FRAMING: CLOSE-UP"
        case .fullBody:
            return "FRAMING: FULL BODY"
        case .both:
            return "FRAMING: CLOSE-UP & FULL BODY"
        }
    }

    private var teleprompterIsVisible: Bool {
        isSlateOverlayVisible && !activeSlatePrompt.isEmpty
    }

    private var shouldShowFramingContextBand: Bool {
        teleprompterIsVisible
        && !teleprompterIsPreviewing
        && !isRecording
    }
    

    private func syncRecordingState(for state: CameraEngine.EngineState) {
        if telemetryEnabled {
            print("🎛️ [Teleprompter] syncRecordingState received state=\(state) (isRecording=\(isRecording))")
        }
        switch state {
        case .recording:
            if !isRecording {
                startRecordingTimer()
                isRecording = true
                WatchBridge.shared.notifyRecordingState(true)
                if telemetryEnabled {
                    print("🎛️ [Teleprompter] Transitioning into .recording – invoking handleTeleprompterRecordingStart()")
                }
                handleTeleprompterRecordingStart()
            }
        case .running, .idle:
            if isRecording {
                stopRecordingTimer()
                isRecording = false
                WatchBridge.shared.notifyRecordingState(false)
                if telemetryEnabled {
                    print("🎛️ [Teleprompter] Transitioning out of recording – invoking handleTeleprompterRecordingStop()")
                }
                handleTeleprompterRecordingStop()
            }
        default:
            break
        }
    }

    private func updateCameraEngineMode() {
        guard isCameraReady else { return }
        if currentCameraMode == .photo {
            engine.switchToPhotoMode()
            print("📸 Camera engine switched to photo mode")
        } else {
            engine.switchToVideoMode()
            print("📹 Camera engine switched to video mode")
        }
    }

    private func startPIPSlateFlow() {
        pipSlateSession = resolvedCurrentPIPSlateSession()
        pipSlatePhase = .portrait
        beginPIPCaptureChecklist()
        lastPIPDeviceOrientation = UIDevice.current.orientation
        handlePIPOrientationChange(lastPIPDeviceOrientation)
        closePIPUtilityOverlay()
        sessionManager.switchToSlateMode()
    }

    private func completePIPSlateCapture(shouldRestoreSceneMode: Bool = true) {
        guard pipSlatePhase != .none else { return }
        pipSlatePhase = .none
        resetPIPCaptureChecklist()
        closePIPUtilityOverlay()
        if shouldRestoreSceneMode {
            sessionManager.switchToSceneMode()
        }
        lastPIPDeviceOrientation = .unknown
    }

    private func startSmartSlateFlow() {
        pipSlatePhase = .none
        resetPIPCaptureChecklist()
        closePIPUtilityOverlay()
        sessionManager.switchToSlateMode()
    }
    
    private func toggleSlateTeleprompter() {
        if isSlateOverlayVisible {
            hideSlateTeleprompterOverlay()
            withAnimation(.easeInOut(duration: 0.2)) {
                showTeleprompterControls = false
                activeTeleSlider = nil
            }
        } else {
            ensureSlateTeleprompterVisible()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                showTeleprompterControls = true
            }
        }
    }
    
    private func ensureSlateTeleprompterVisible() {
        let prompt = resolvedSlatePrompt()
        if !isSlateOverlayVisible {
            isSlateOverlayVisible = true
        }
        activeSlatePrompt = prompt
    }
    
    private func hideSlateTeleprompterOverlay() {
        isSlateOverlayVisible = false
        activeSlatePrompt = ""
    }

    private func resolveAutoSlatePrompt() -> SlatePromptResolver.Result {
        let snapshotProject = slateProjectSnapshot
        let snapshotSession = slateSessionSnapshot
        return SlatePromptResolver.resolve(
            profile: actorProfileManager.profile,
            project: snapshotProject,
            session: snapshotSession,
            selections: slateSelectionsSnapshot,
            fallbackLocation: snapshotSession.location?.label ?? session.location?.label
        )
    }

    private func presentTeleprompterScriptEditor() {
        guard !isRecording, !showTeleprompterScriptEditor else { return }
        let autoResult = resolveAutoSlatePrompt()
        teleprompterEditorAutoPrompt = autoResult.prompt
        teleprompterEditorShouldClearCustomDraft = false

        let snapshotSession = slateSessionSnapshot
        let customPrompt = snapshotSession.slatePromptOverride?.slateTrimmedNonEmpty
            ?? snapshotSession.slatePrompt?.slateTrimmedNonEmpty
        let savedCustom = customPrompt ?? snapshotSession.lastCustomSlatePrompt?.slateTrimmedNonEmpty
        if shouldUseCustomSlatePrompt(snapshotSession), let prompt = customPrompt {
            teleprompterEditorMode = .custom
            teleprompterEditorDraft = prompt
        } else {
            teleprompterEditorMode = .auto
            teleprompterEditorDraft = savedCustom ?? autoResult.prompt
        }

        if teleprompterIsPreviewing {
            stopTeleprompterScrolling(resetOffset: false)
        }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
            showTeleprompterScriptEditor = true
        }
    }

    private func dismissTeleprompterScriptEditor() {
        teleprompterEditorShouldClearCustomDraft = false
        withAnimation(.easeInOut(duration: 0.2)) {
            showTeleprompterScriptEditor = false
        }
    }

    private func scheduleTeleprompterAutoSave(mode: SlatePromptMode, customDraft: String) {
        guard !isRecording else { return }
        teleprompterAutoSaveWorkItem?.cancel()
        let workItem = DispatchWorkItem { [mode, customDraft] in
            self.applyTeleprompterScriptUpdate(mode: mode, customDraft: customDraft)
            self.teleprompterAutoSaveWorkItem = nil
        }
        teleprompterAutoSaveWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: workItem)
    }

    private func applyTeleprompterScriptUpdate(
        mode: SlatePromptMode,
        customDraft: String,
        clearCustomDraft: Bool = false
    ) {
        let autoResult = resolveAutoSlatePrompt()
        let customTrimmed = customDraft.slateTrimmedNonEmpty
        let updatedAt = Date()

        let resolvedMode: SlatePromptMode
        let override: String?
        let prompt: String
        if mode == .custom, let customTrimmed {
            resolvedMode = .custom
            override = customTrimmed
            prompt = customTrimmed
        } else {
            resolvedMode = .auto
            override = nil
            prompt = autoResult.prompt
        }

        teleprompterEditorMode = resolvedMode
        teleprompterEditorDraft = customDraft
        teleprompterEditorShouldClearCustomDraft = false

        let shouldClearLastCustomPrompt = clearCustomDraft && resolvedMode == .auto

        SessionManager.shared.saveSlatePromptConfiguration(
            mode: resolvedMode,
            override: override,
            inputsHash: autoResult.inputsHash,
            updatedAt: updatedAt,
            projectID: project.id,
            sessionID: session.id,
            lastCustomPrompt: customTrimmed,
            clearLastCustomPrompt: shouldClearLastCustomPrompt
        )

        slatePromptPreview = prompt
        if isSlateOverlayVisible {
            activeSlatePrompt = prompt
        }
        if slatePromptInputsHash != autoResult.inputsHash {
            slatePromptInputsHash = autoResult.inputsHash
        }
        stopTeleprompterScrolling(resetOffset: true)
    }
    
    private func resolvedSlatePrompt() -> String {
        let prompt = buildSlatePromptPreview()
        if slatePromptPreview != prompt {
            slatePromptPreview = prompt
        }
        return slatePromptPreview
    }

    private func stopTeleprompterScrolling(resetOffset: Bool) {
        teleprompterAutoScrollDuringRecording = false
        teleprompterIsPreviewing = false
        if resetOffset {
            teleprompterScrollOffset = 0
        }
    }

    private func finishTeleprompterScrollAtEnd() {
        stopTeleprompterScrolling(resetOffset: false)
    }

    private func teleprompterInitialTopPadding(for panelHeight: CGFloat) -> CGFloat {
        max(0, (panelHeight * 0.5) - (teleprompterFontSize * 1.2))
    }

    private func handleTeleprompterRecordingStart() {
        guard isSlateOverlayVisible else {
            if telemetryEnabled {
                print("🎬 [Teleprompter] Recording start – teleprompter hidden, skipping auto-scroll")
            }
            restoreTeleprompterControlsAfterRecording = false
            teleprompterAutoScrollDuringRecording = false
            teleprompterIsPreviewing = false
            return
        }

        if showTeleprompterControls {
            restoreTeleprompterControlsAfterRecording = true
            withAnimation(.easeInOut(duration: 0.2)) {
                showTeleprompterControls = false
            }
        }

        ensureSlateTeleprompterVisible()
        teleprompterAutoScrollDuringRecording = true
        teleprompterIsPreviewing = true
        if telemetryEnabled {
            print("🎬 [Teleprompter] Recording start – overlayVisible=\(isSlateOverlayVisible) preview=\(teleprompterIsPreviewing) autoScroll=\(teleprompterAutoScrollDuringRecording)")
        }
    }

    private func handleTeleprompterRecordingStop() {
        let shouldRestorePanel = restoreTeleprompterControlsAfterRecording

        if teleprompterAutoScrollDuringRecording {
            stopTeleprompterScrolling(resetOffset: true)
            if telemetryEnabled {
                print("🛑 [Teleprompter] Recording stop – preview=\(teleprompterIsPreviewing) offset=\(teleprompterScrollOffset)")
            }
        } else if telemetryEnabled {
            print("🛑 [Teleprompter] Recording stop – no auto scroll active")
        }

        teleprompterAutoScrollDuringRecording = false

        if shouldRestorePanel && isSlateOverlayVisible {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                showTeleprompterControls = true
            }
        }

        restoreTeleprompterControlsAfterRecording = false
    }

    private func presentSlatePrompt() {
        let start = CFAbsoluteTimeGetCurrent()
        print(String(format: "🎬 [Perf] presentSlatePrompt starting at t=%.3f", start))
        slateCaptureStyle = .smartFill
        let autoResult = resolveAutoSlatePrompt()
        teleprompterEditorAutoPrompt = autoResult.prompt
        teleprompterEditorShouldClearCustomDraft = false

        let snapshotSession = slateSessionSnapshot
        let customPrompt = snapshotSession.slatePromptOverride?.slateTrimmedNonEmpty
            ?? snapshotSession.slatePrompt?.slateTrimmedNonEmpty
        let savedCustom = customPrompt ?? snapshotSession.lastCustomSlatePrompt?.slateTrimmedNonEmpty
        if shouldUseCustomSlatePrompt(snapshotSession), let prompt = customPrompt {
            teleprompterEditorMode = .custom
            teleprompterEditorDraft = prompt
        } else {
            teleprompterEditorMode = .auto
            teleprompterEditorDraft = savedCustom ?? autoResult.prompt
        }

        slatePromptPreview = teleprompterEditorMode == .custom ? teleprompterEditorDraft : autoResult.prompt
        isSlateOverlayVisible = false
        activeSlatePrompt = ""
        let composeTime = CFAbsoluteTimeGetCurrent()
        print(String(format: "🎬 [Perf] Slate prompt composed in %.3f s: %@", composeTime - start, slatePromptPreview))
        withAnimation {
            showSlatePromptSheet = true
        }
        let total = CFAbsoluteTimeGetCurrent() - start
        print(String(format: "🎬 [Perf] presentSlatePrompt finished in %.3f s", total))
    }

    private func handleSlatePromptBegin() {
        showSlatePromptSheet = false
        let t0 = CFAbsoluteTimeGetCurrent()
        applyTeleprompterScriptUpdate(
            mode: teleprompterEditorMode,
            customDraft: teleprompterEditorDraft,
            clearCustomDraft: teleprompterEditorShouldClearCustomDraft
        )
        teleprompterEditorShouldClearCustomDraft = false
        let t1 = CFAbsoluteTimeGetCurrent()
        print(String(format: "🎬 [Perf] Slate prompt saved in %.3f s", t1 - t0))
        if isSlateOverlayVisible {
            activeSlatePrompt = slatePromptPreview
        } else {
            activeSlatePrompt = ""
        }
        print("🎬 Slate prompt begin with style \(slateCaptureStyle.rawValue)")

        switch slateCaptureStyle {
        case .standard, .smartFill:
            startSmartSlateFlow()
        case .pictureInPicture:
            isSlateOverlayVisible = false
            activeSlatePrompt = ""
            startPIPSlateFlow()
        }
    }

    private func buildSlatePromptPreview() -> String {
        let snapshotSession = slateSessionSnapshot
        if shouldUseCustomSlatePrompt(snapshotSession) {
            if let override = snapshotSession.slatePromptOverride?.slateTrimmedNonEmpty {
                return override
            }
            if let legacy = snapshotSession.slatePrompt?.slateTrimmedNonEmpty {
                return legacy
            }
        }
        let result = resolveAutoSlatePrompt()
        if slatePromptInputsHash != result.inputsHash {
            slatePromptInputsHash = result.inputsHash
        }
        return result.prompt
    }

    private func shouldUseCustomSlatePrompt(_ session: ProjectSession) -> Bool {
        guard session.slatePromptMode == .custom else { return false }
        guard let updatedAt = session.slatePromptUpdatedAt else { return false }
        return updatedAt >= actorProfileManager.profile.updatedAt
    }

    private func exitCameraAndReturnToReview(source: String = "exitCameraAndReturnToReview") {
        guard !isExiting else {
            print("⚠️ [\(Date())] exitCameraAndReturnToReview called again; ignoring duplicate exit – debugID = \(debugID), source = \(source)")
            return
        }
        isExiting = true
        let exitTime = CFAbsoluteTimeGetCurrent()
        lastExitRequestTime = exitTime
        print("🎬 [Perf] Camera exit requested (source=\(source)) at t=\(exitTime) – debugID = \(debugID)")

        navCtx.clearContexts(source: .cameraCapture,
                             sessionID: session.id,
                             projectID: project.id)
        navCtx.preserveFromCamera(
            scene: sessionManager.currentScene,
            viewType: inferredNavigationViewType,
            sessionID: session.id,
            projectID: project.id,
            metadata: contextMetadataForCurrentState()
        )

        DispatchQueue.main.async {
            print("🎬 [\(Date())] dispatching requestExitCameraIfNeeded – debugID = \(self.debugID), source = \(source)")
            self.requestExitCameraIfNeeded(source: source)
        }
    }

    private func requestExitCameraIfNeeded(source: String) {
        if hasRequestedExit {
            print("🎬 [CameraCaptureView] requestExitCameraIfNeeded called again – already exiting – debugID = \(debugID), source = \(source)")
            return
        }

        hasRequestedExit = true
        lastExitRequestTime = CFAbsoluteTimeGetCurrent()
        exitProcessingMessage = "Compiling your recording…"
        exitProcessingDetails = "Saving takes and preparing Take Review"
        withAnimation(.easeInOut(duration: 0.12)) {
            isExitProcessingVisible = true
        }
        ExitProcessingCoordinator.shared.show(source: "CameraCaptureView.requestExitCameraIfNeeded.\(source)")
        print("🟦 [ExitProcessing] overlay visible – debugID=\(debugID), source=\(source)")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            print("🟦 [ExitProcessing] calling onComplete() – debugID=\(debugID), source=\(source)")
            onBeginExitProcessing?()
            onComplete()
        }
    }

    private var inferredNavigationViewType: NavigationContextManager.ViewType {
        if sessionManager.isRecordingKeyframePhoto {
            return .keyframes
        }
        if sessionManager.isRecordingSlate || isPiPActive || hasAnyPIPTake {
            return .slates
        }
        if let latest = SessionManager.shared.getLatestUnifiedTake() {
            if latest.isPhoto || latest.isKeyframePhoto {
                return .keyframes
            }
            if latest.isSlate {
                return .slates
            }
        }
        return .scenes
    }
    
    private var desiredRecordingMode: SessionManager.RecordingMode {
        if sessionManager.isRecordingKeyframePhoto {
            return .keyframes
        }
        if sessionManager.isRecordingSlate || isPiPActive {
            return .slates
        }
        return .scenes
    }
    
    private func contextMetadataForCurrentState() -> [String: String]? {
        var metadata: [String: String] = [:]
        if inferredNavigationViewType == .slates,
           let inferred = inferredSlateFilterForContext() {
            metadata["slateFilter"] = inferred.rawValue
        }
        if inferredNavigationViewType == .keyframes {
            metadata["intent"] = "photos"
        }
        return metadata.isEmpty ? nil : metadata
    }
    
    private func inferredSlateFilterForContext() -> SessionTakesModalView.SlateFilter? {
        switch pipSlatePhase {
        case .landscape:
            return .pipCloseUp
        case .portrait:
            return .pipFullBody
        case .none:
            break
        }
        if pipLandscapeCount > 0 && pipLandscapeCount >= pipPortraitCount {
            return .pipCloseUp
        }
        if pipPortraitCount > 0 {
            return .pipFullBody
        }
        if let latestTake = SessionManager.shared.getLatestUnifiedTake(),
           latestTake.isSlate,
           let orientation = latestTake.capturedOrientation {
            return orientation == .landscape ? .pipCloseUp : .pipFullBody
        }
        return nil
    }

    private func closePIPUtilityOverlay() {
        withAnimation(.easeInOut(duration: 0.2)) {
            showAudioControls = false
            showManualControls = false
            showSessionManager = false
            showTakesModal = false
        }
    }

    private var pipPortraitCount: Int { pipSlateSession.portraitTakes.count }
    private var pipLandscapeCount: Int { pipSlateSession.landscapeTakes.count }
    private var hasAnyPIPTake: Bool { pipPortraitCount + pipLandscapeCount > 0 }
    private var canCompletePIP: Bool { pipPortraitCount > 0 && pipLandscapeCount > 0 }
    private var pipCaptureReady: Bool { !pipRequiresPortraitShot && !pipRequiresLandscapeShot }
    private var isPiPActive: Bool { pipSlatePhase != .none }
    private var isPIPRecording: Bool { isRecording && pipSlatePhase != .none }
    
    private func beginPIPCaptureChecklist() {
        pipRequiresPortraitShot = true
        pipRequiresLandscapeShot = true
    }
    
    private func resetPIPCaptureChecklist() {
        pipRequiresPortraitShot = false
        pipRequiresLandscapeShot = false
    }
    
    private func markStageComplete(_ phase: PIPSlatePhase) {
        switch phase {
        case .portrait:
            pipRequiresPortraitShot = false
        case .landscape:
            pipRequiresLandscapeShot = false
        case .none:
            break
        }
    }
    
    private struct PIPStatusDescriptor {
        enum Stage {
            case portrait
            case landscape
            case ready
        }
        
        let stage: Stage
        let color: Color
        let icon: String
        let chipText: String
        let instruction: String?
    }
    
    private var currentPIPStatus: PIPStatusDescriptor? {
        guard pipSlatePhase != .none else { return nil }
        
        if pipCaptureReady {
            return PIPStatusDescriptor(
                stage: .ready,
                color: Color.green.opacity(0.85),
                icon: "checkmark",
                chipText: "Done",
                instruction: nil
            )
        }
        
        if pipRequiresPortraitShot {
            return PIPStatusDescriptor(
                stage: .portrait,
                color: Color.pink.opacity(0.9),
                icon: "",
                chipText: "Full Body",
                instruction: "Get started by recording one or more full body shots."
            )
        }
        
        if pipRequiresLandscapeShot {
            return PIPStatusDescriptor(
                stage: .landscape,
                color: Color.orange.opacity(0.9),
                icon: "",
                chipText: "Close-Up",
                instruction: "Great! Now capture a close-up pass that matches your framing."
            )
        }
        
        return nil
    }

    private func resolvedCurrentPIPSlateSession() -> SlatePIPSession {
        if let current = sessionManager.currentSession,
           current.project.id == project.id,
           current.session.id == session.id,
           let stored = current.session.pipSlateSession {
            return stored
        }
        if let stored = session.pipSlateSession {
            return stored
        }
        return pipSlateSession
    }
    
    private func storePIPSlateTakeIfNeeded(relativePath: String, duration: TimeInterval) {
        guard pipSlatePhase != .none else { return }

        var updated = pipSlateSession
        let take = PIPSlateTake(filePath: relativePath, duration: duration)
        let activePhase = pipSlatePhase

        switch pipSlatePhase {
        case .portrait:
            updated.portraitTakes.append(take)
            updated.selectedPortraitID = take.id
        case .landscape:
            updated.landscapeTakes.append(take)
            updated.selectedLandscapeID = take.id
        case .none:
            break
        }

        pipSlateSession = updated
        persistPIPSlateSession()
        markStageComplete(activePhase)
    }

    private func persistPIPSlateSession() {
        SessionManager.shared.savePIPSlateSession(
            pipSlateSession,
            projectID: project.id,
            sessionID: session.id
        )
    }

    private func completePIPTapped() {
        guard pipSlatePhase != .none else { return }
        guard hasAnyPIPTake else {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            return
        }

        if pipCaptureReady && canCompletePIP {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            completePIPSlateCapture()
        } else {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }
}

// Focus Indicator View
struct FocusIndicator: View {
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.yellow, lineWidth: 2)
                .frame(width: 60, height: 60)
            Circle()
                .stroke(Color.yellow, lineWidth: 1)
                .frame(width: 40, height: 40)
        }
        .opacity(0.8)
    }
}

private struct AEAFHudView: View {
    let lockLocation: CGPoint
    let exposureValue: Binding<Double>
    let exposureRange: ClosedRange<Double>
    let onSliderInteractionChanged: (Bool) -> Void

    var body: some View {
        GeometryReader { proxy in
            let safePoint = clamp(lockLocation, in: proxy.size)
            let sliderPoint = sliderPosition(for: safePoint, in: proxy.size)
            ZStack {
                Text("AE/AF LOCK")
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.black.opacity(0.7), in: Capsule())
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
                    .foregroundColor(.white)
                    .position(x: safePoint.x, y: max(28, safePoint.y - 60))
                    .allowsHitTesting(false)

                FocusLockReticle()
                    .position(safePoint)
                    .allowsHitTesting(false)

                AEAFExposurePillSlider(
                    value: exposureValue,
                    range: exposureRange,
                    onInteractionChanged: onSliderInteractionChanged
                )
                .position(sliderPoint)
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
        }
    }

    private func clamp(_ point: CGPoint, in size: CGSize) -> CGPoint {
        let margin: CGFloat = 40
        let x = min(max(margin, point.x), size.width - margin)
        let y = min(max(100, point.y), size.height - margin)
        return CGPoint(x: x, y: y)
    }

    private func sliderPosition(for point: CGPoint, in size: CGSize) -> CGPoint {
        let offset: CGFloat = 90
        var proposedX = point.x + offset
        if proposedX > size.width - 40 {
            proposedX = point.x - offset
        }
        proposedX = min(max(40, proposedX), size.width - 40)
        return CGPoint(x: proposedX, y: point.y)
    }
}

private struct FocusLockReticle: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .stroke(Color.yellow, lineWidth: 2)
            .frame(width: 76, height: 76)
            .shadow(color: .black.opacity(0.35), radius: 8, x: 0, y: 4)
    }
}

// Timeout Helper
func withTimeout<T>(seconds: Double, operation: @escaping () async throws -> T) async throws -> T {
    return try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask { try await operation() }
        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            throw TimeoutError.operationTimedOut
        }
        let result = try await group.next()!
        group.cancelAll()
        return result
    }
}

enum TimeoutError: Error, LocalizedError {
    case operationTimedOut
    var errorDescription: String? {
        switch self {
        case .operationTimedOut: return "Operation timed out"
        }
    }
}

private struct BreakdownNotesOverlayView: View {
    let text: String
    @Binding var isPresented: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("Breakdown Notes", systemImage: "note.text")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                Spacer()
                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        isPresented = false
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .padding(8)
                        .background(Color.white.opacity(0.15), in: Circle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white.opacity(0.8))
            }

            ScrollView {
                Text(text)
                    .font(.system(size: 16, weight: .regular, design: .default))
                    .foregroundStyle(.white.opacity(0.95))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
            }
            .frame(maxHeight: 280)
        }
        .padding(24)
        .frame(maxWidth: 420)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(.ultraThinMaterial)
                .background(
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .fill(Color.black.opacity(0.45))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.45), radius: 30, x: 0, y: 20)
    }
}


private struct TeleprompterControlsOverlay: View {
    @Binding var isPreviewing: Bool
    @Binding var scrollOffset: CGFloat

    let theme: STSTheme
    let telemetryEnabled: Bool
    let onClose: () -> Void
    let onEditScript: () -> Void
    let onActivateControl: (CameraCaptureView.TeleprompterControlType) -> Void

    private let panelWidth: CGFloat = TeleprompterUIConstants.panelWidth
    @State private var isCollapsed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            if !isCollapsed {
                controlsRow
            }
        }
        .padding(18)
        .frame(maxWidth: panelWidth, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Color.black.opacity(0.55))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.18), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.35), radius: 18, x: 0, y: 18)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            Text("Teleprompter Settings")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(Color.white)

            Spacer(minLength: 0)

            Button {
                onEditScript()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "pencil")
                    Text("Edit")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .foregroundStyle(Color.white)
                .background(Color.white.opacity(0.18), in: Capsule())
            }
            .buttonStyle(.plain)

            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                    isCollapsed.toggle()
                }
            } label: {
                Image(systemName: isCollapsed ? "eye" : "eye.slash")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .padding(8)
                    .background(Color.white.opacity(0.18), in: Circle())
            }
            .buttonStyle(.plain)

            if isPreviewing {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isPreviewing = false
                        isCollapsed = false
                    }
                } label: {
                    Text("Stop")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .foregroundStyle(Color.white)
                        .background(Color.red.opacity(0.85), in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .onChange(of: isPreviewing) { _, newValue in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
                isCollapsed = newValue
            }
        }
    }

    private var controlsRow: some View {
        HStack(spacing: 12) {
            teleButton(icon: "textformat.size") {
                onActivateControl(.fontSize)
            }

            teleButton(icon: "rectangle.expand.vertical") {
                onActivateControl(.lineHeight)
            }

            teleButton(icon: "app.translucent") {
                onActivateControl(.opacity)
            }

            teleButton(icon: "speedometer") {
                onActivateControl(.scrollSpeed)
            }

            iconButton(icon: "arrow.up.to.line") {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    scrollOffset = 0
                }
            }

            previewButton

            Spacer(minLength: 0)
        }
    }

    private func teleButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.white)
                .padding(8)
                .background(Color.white.opacity(0.18), in: Circle())
        }
        .buttonStyle(.plain)
    }

    private func iconButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.white)
                .padding(10)
                .background(Color.white.opacity(0.18), in: Circle())
        }
        .buttonStyle(.plain)
    }

    private var previewButton: some View {
        Button {
            let newValue = !isPreviewing
            isPreviewing = newValue
            if telemetryEnabled {
                print("▶️ [Teleprompter] Preview toggled: \(newValue) – offset=\(scrollOffset)")
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: isPreviewing ? "pause.fill" : "play.fill")
                Text(isPreviewing ? "Stop" : "Preview")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .foregroundStyle(theme.primaryButtonForeground)
            .background(theme.primaryButtonBackground, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}






private struct TeleprompterContentHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private extension CameraCaptureView {
    func teleprompterPanelHeight(for hostHeight: CGFloat, fraction: CGFloat) -> CGFloat {
        let maxHeight = hostHeight * 0.85
        return max(150, min(hostHeight * fraction, maxHeight))
    }
}

// MARK: - Document support types & views

private struct DocumentItem: Identifiable, Equatable {
    let id: String
    let title: String
    let url: URL?
    let notes: String?

    init(title: String, url: URL?, notes: String?) {
        self.title = title
        self.url = url
        self.notes = notes
        if let absolute = url?.absoluteString {
            self.id = absolute
        } else {
            self.id = "notes-\(title)"
        }
    }
}

private extension CameraCaptureView {
    var documentSelectorOptions: [DocumentSelectorView.DocumentOption] {
        availableDocuments
            .filter { $0.url != nil }
            .map { item in
                DocumentSelectorView.DocumentOption(
                    id: item.id,
                    title: item.title,
                    subtitle: item.url?.lastPathComponent ?? "",
                    iconName: documentIconName(for: item.title)
                )
            }
    }

    func handleDocumentSelection(option: DocumentSelectorView.DocumentOption) {
        guard let item = availableDocuments.first(where: { $0.id == option.id }) else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        openDocument(item)
    }

    func documentIconName(for title: String) -> String {
        switch title.lowercased() {
        case "sides": return "doc.text"
        case "breakdown": return "text.book.closed"
        case "breakdown notes": return "note.text"
        default: return "doc.richtext"
        }
    }
}

private extension CameraCaptureView {
    var pipInstructionPreferenceKey: String {
        "pipInstructionHidden.\(project.id.uuidString)"
    }

    var levelIndicatorPopoverContent: some View {
        let chipMinWidth: CGFloat = 112
        let controlMinHeight: CGFloat = 44

        return VStack(alignment: .center, spacing: 12) {
            Text("Level")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white.opacity(0.9))
                .frame(maxWidth: .infinity, alignment: .center)
                .multilineTextAlignment(.center)

            HStack(spacing: 12) {
                levelModeChip(
                    title: "Auto",
                    systemImage: "wand.and.stars",
                    isSelected: levelVisibilityMode == .auto
                ) {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    levelVisibilityMode = .auto
                }
                .frame(minWidth: chipMinWidth, minHeight: controlMinHeight)

                levelModeChip(
                    title: "Always On",
                    systemImage: "lock.open.display",
                    isSelected: levelVisibilityMode == .alwaysOn
                ) {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    levelVisibilityMode = .alwaysOn
                }
                .frame(minWidth: chipMinWidth, minHeight: controlMinHeight)
            }
            .frame(maxWidth: .infinity, alignment: .center)

            Divider()
                .background(Color.white.opacity(0.25))

            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                showLevelIndicator = false
                levelVisibilityMode = .auto
                showLevelIndicatorPopover = false
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "level")
                        .font(.system(size: 15, weight: .semibold))
                    Text("Hide Level")
                        .font(.system(size: 13, weight: .semibold))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .foregroundColor(.white.opacity(0.9))
                .background(
                    Capsule()
                        .fill(Color.black.opacity(0.8))
                )
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.25), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .controlSize(.small)
            .frame(minHeight: controlMinHeight)
            .frame(maxWidth: .infinity, alignment: .center)
            .accessibilityLabel("Hide level")
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.black.opacity(0.9))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        )
    }

    private func levelModeChip(
        title: String,
        systemImage: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .semibold))
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .foregroundColor(isSelected ? .black : .white)
            .background(
                Capsule().fill(isSelected ? Color.white : Color.white.opacity(0.12))
            )
            .overlay(
                Capsule()
                    .stroke(
                        Color.white.opacity(isSelected ? 0.6 : 0.25),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Level mode \(title)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}






private struct DocumentViewerModal: View {
    let documents: [DocumentItem]
    @Binding var selectedDocument: DocumentItem?
    let onClose: () -> Void
    @State private var startedAccess = false

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if documents.count > 1 {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(documents) { item in
                                documentTab(item)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                    }
                    .background(Color(.secondarySystemBackground))
                }
                
                Divider()
                
                if let doc = selectedDocument {
                    if let url = doc.url {
                        if isImageDocument(url: url), let image = loadImage(from: url) {
                            DocumentImageView(image: image)
                                .navigationTitle(doc.title)
                                .navigationBarTitleDisplayMode(.inline)
                                .onAppear { beginAccessIfNeeded(url: url) }
                                .onDisappear { endAccessIfNeeded(url: url) }
                        } else {
                            RobustPDFView(url: url)
                                .navigationTitle(doc.title)
                                .navigationBarTitleDisplayMode(.inline)
                                .onAppear { beginAccessIfNeeded(url: url) }
                                .onDisappear { endAccessIfNeeded(url: url) }
                        }
                    } else if let notes = doc.notes {
                        ScrollView {
                            Text(notes)
                                .font(.body)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .navigationTitle(doc.title)
                        .navigationBarTitleDisplayMode(.inline)
                    } else {
                        Text("Document unavailable.")
                            .padding()
                    }
                } else {
                    Text("Select a document to view.")
                        .padding()
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { onClose() }
                        .font(.body.weight(.semibold))
                }
                if let url = selectedDocument?.url {
                    ToolbarItem(placement: .topBarTrailing) {
                        ShareLink(item: url) {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                }
            }
            .onAppear {
                if selectedDocument == nil {
                    selectedDocument = documents.first
                } else if let current = selectedDocument,
                          !documents.contains(current) {
                    selectedDocument = documents.first
                }
            }
        }
    }
    
    private func documentTab(_ item: DocumentItem) -> some View {
        let isSelected = item == selectedDocument
        return Button {
            selectedDocument = item
        } label: {
            Text(item.title)
                .font(.system(size: 13, weight: .semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
                .foregroundColor(isSelected ? .accentColor : .primary)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? Color.accentColor : Color.secondary.opacity(0.4), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }
    
    private func beginAccessIfNeeded(url: URL) {
        if url.startAccessingSecurityScopedResource() {
            startedAccess = true
        }
    }
    
    private func endAccessIfNeeded(url: URL) {
        if startedAccess {
            url.stopAccessingSecurityScopedResource()
            startedAccess = false
        }
    }

    private func isImageDocument(url: URL) -> Bool {
        if let type = try? url.resourceValues(forKeys: [.contentTypeKey]).contentType,
           type.conforms(to: .image) {
            return true
        }
        let ext = url.pathExtension.lowercased()
        return ["png", "jpg", "jpeg", "heic", "heif"].contains(ext)
    }

    private func loadImage(from url: URL) -> UIImage? {
        if let image = UIImage(contentsOfFile: url.path) {
            return image
        }
        if let data = try? Data(contentsOf: url) {
            return UIImage(data: data)
        }
        return nil
    }
}

/// A more defensive PDFKit wrapper:
/// - Verifies the file exists
/// - If iCloud file, triggers a download
/// - Tries both URL and Data loading paths
/// - Shows a human-readable error overlay if load fails
private struct RobustPDFView: UIViewRepresentable {
    let url: URL

    final class Coordinator {
        var lastLoadedURL: URL?
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> PDFView {
        let v = PDFView()
        v.displayMode = .singlePageContinuous
        v.displayDirection = .vertical
        v.backgroundColor = .black
        v.autoScales = true
        return v
    }

    func updateUIView(_ pdfView: PDFView, context: Context) {
        guard context.coordinator.lastLoadedURL != url else { return }

        // 1) Resolve iCloud cases (download if needed)
        var resolvedURL = url
        let fm = FileManager.default
        if fm.isUbiquitousItem(at: url) {
            // Ensure the file is downloaded locally
            try? fm.startDownloadingUbiquitousItem(at: url)
            // Best-effort wait loop (short, non-blocking)
            if let values = try? url.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey]),
               values.ubiquitousItemDownloadingStatus != URLUbiquitousItemDownloadingStatus.current {
                // We will not block here; viewer will update when we set the doc below if present.
                print("☁️ iCloud doc not fully local yet: \(String(describing: values.ubiquitousItemDownloadingStatus))")
            }
            resolvedURL = url
        }

        // 2) Verify existence
        guard fm.fileExists(atPath: resolvedURL.path) else {
            showErrorOverlay(on: pdfView, "File not found:\n\(resolvedURL.lastPathComponent)")
            print("❌ PDF not found at path: \(resolvedURL.path)")
            return
        }

        // 3) Try URL load first
        var doc: PDFDocument? = PDFDocument(url: resolvedURL)

        // 4) Fallback: load via Data (helps with security scope / some providers)
        if doc == nil, let data = try? Data(contentsOf: resolvedURL, options: [.mappedIfSafe]) {
            doc = PDFDocument(data: data)
        }

        guard let pdfDoc = doc else {
            showErrorOverlay(on: pdfView, "Could not open PDF.\nIt might be encrypted or unsupported.")
            // Enhanced debugging for file analysis
            if let _ = try? resolvedURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                print("📄 PDF file has valid size")
            }
            if let _ = try? resolvedURL.resourceValues(forKeys: [.contentTypeKey]).contentType {
                print("📄 PDF file has valid content type")
            }
            // Check if file starts with PDF magic bytes
            if let data = try? Data(contentsOf: resolvedURL, options: [.mappedIfSafe]), data.count >= 4 {
                let _ = data.prefix(4)
                print("📄 File appears to have valid header")
            }
            print("✔️ File magic bytes: ")
            // Check if file starts with PDF magic bytes
            if let data = try? Data(contentsOf: resolvedURL, options: [.mappedIfSafe]), data.count >= 4 {
                let magicBytes = data.prefix(4)
                let magicString = String(data: magicBytes, encoding: .ascii) ?? "unknown"
                print("📄 File magic bytes: \(magicString) (should be %PDF for valid PDF)")
            };            print("❌ PDFDocument failed for URL: \(resolvedURL)")
            return
        }

        // 5) Success
        pdfView.document = pdfDoc
        pdfView.autoScales = true // set again after document assignment for good measure
        clearErrorOverlay(on: pdfView)
        context.coordinator.lastLoadedURL = url

        // Log for sanity
        let pageCount = pdfDoc.pageCount
        print("✅ Loaded PDF (\(pageCount) page(s)): \(resolvedURL.lastPathComponent)")
    }

    // Simple error overlay helpers (adds a UILabel on top of PDFView)
    private func showErrorOverlay(on view: PDFView, _ message: String) {
        clearErrorOverlay(on: view)

        let label = UILabel()
        label.text = message
        label.textColor = .white
        label.numberOfLines = 0
        label.textAlignment = .center
        label.tag = 909_001 // magic tag for removal
        label.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 24),
            label.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -24)
        ])
    }

    private func clearErrorOverlay(on view: PDFView) {
        view.viewWithTag(909_001)?.removeFromSuperview()
    }
}

private struct DocumentImageView: View {
    let image: UIImage
    var body: some View {
        GeometryReader { proxy in
            ScrollView([.horizontal, .vertical]) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: proxy.size.width)
                    .padding()
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }
}
extension CameraCaptureView {
    @ViewBuilder
    private func teleSlider(for control: TeleprompterControlType) -> some View {
        let binding = sliderBinding(for: control)
        let range = sliderRange(for: control)
        let title = sliderTitle(for: control)
        let valueLabel = sliderValueDescription(for: control, value: binding.wrappedValue)

        let step = sliderStep(for: control)

        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.white)
                Spacer()
                Text(valueLabel)
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.9))
            }

            Slider(value: binding, in: range, step: step)
                .tint(.white)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, in: Capsule())
        .shadow(color: Color.black.opacity(0.35), radius: 10, x: 0, y: 6)
        .frame(maxWidth: TeleprompterUIConstants.panelWidth)
    }

    private func sliderBinding(for control: TeleprompterControlType) -> Binding<Double> {
        switch control {
        case .fontSize:
            return Binding<Double>(
                get: { Double(teleprompterFontSize) },
                set: { teleprompterFontSize = CGFloat($0) }
            )
        case .lineHeight:
            return Binding<Double>(
                get: { Double(teleprompterLineHeight) },
                set: { teleprompterLineHeight = CGFloat($0) }
            )
        case .scrollSpeed:
            return $teleprompterScrollSpeed
        case .opacity:
            return $teleprompterBackgroundOpacity
        }
    }

    private func sliderRange(for control: TeleprompterControlType) -> ClosedRange<Double> {
        switch control {
        case .fontSize:
            return 14...70
        case .lineHeight:
            return 0.8...2.0
        case .scrollSpeed:
            return 0...3
        case .opacity:
            return 0.2...1.0
        }
    }

    private func sliderStep(for control: TeleprompterControlType) -> Double {
        switch control {
        case .fontSize:
            return 1
        case .lineHeight:
            return 0.05
        case .scrollSpeed:
            return 0.05
        case .opacity:
            return 0.02
        }
    }

    private func sliderTitle(for control: TeleprompterControlType) -> String {
        switch control {
        case .fontSize:
            return "Font Size"
        case .lineHeight:
            return "Line Height"
        case .scrollSpeed:
            return "Scroll Speed"
        case .opacity:
            return "Background Transparency"
        }
    }

    private func sliderValueDescription(for control: TeleprompterControlType, value: Double) -> String {
        switch control {
        case .fontSize:
            return "\(Int(value)) pt"
        case .lineHeight:
            return String(format: "%.1f×", value)
        case .scrollSpeed:
            return String(format: "%.1fx", value)
        case .opacity:
            return String(format: "%.0f%%", value * 100)
        }
    }

    @ViewBuilder
    private var pipUtilityControls: some View {
        if !isRecording {
            VStack(spacing: 10) {
                if isTeleprompterFocused {
                    documentMenu
                    teleprompterQuickHideChip
                } else {
                    settingsMenu
                    if pipSlatePhase == .none {
                        documentMenu
                    } else {
                        pipToolsButton
                    }
                }
            }
            .padding(.top, 4)
        }
    }

    private var teleprompterQuickHideChip: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            restoreTeleprompterControlsAfterRecording = false
            withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
                showTeleprompterControls = false
            }
            hideSlateTeleprompterOverlay()
        } label: {
            Image(systemName: "xmark.app")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.red)
                .padding(10)
                .background(.ultraThinMaterial, in: Circle())
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.25), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Hide Teleprompter")
    }

    private var pipToolsButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.snappy) { showPIPToolsMenu.toggle() }
        } label: {
            Image(systemName: "film")
                .font(.system(size: 20, weight: .semibold))
                .padding(10)
                .foregroundColor(.white)
                .background(.ultraThinMaterial, in: Circle())
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.25), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private var pipToolsMenuContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !availableDocuments.isEmpty {
                Button {
                    showPIPToolsMenu = false
                    presentDocumentViewer()
                } label: {
                    Label("Documents & Notes", systemImage: "doc.text")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
            }

            Button {
                showPIPToolsMenu = false
                showAudioControls = true
            } label: {
                Label("Audio Panel", systemImage: "waveform")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            Button {
                showPIPToolsMenu = false
                if !isSlateOverlayVisible {
                    toggleSlateTeleprompter()
                }
                withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                    showTeleprompterControls = true
                }
            } label: {
                Label("Slate Teleprompter", systemImage: "text.bubble")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            Button {
                showPIPToolsMenu = false
                showManualControls = true
            } label: {
                Label("Camera Controls", systemImage: "dial.min")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            Button {
                showPIPToolsMenu = false
                showTakesModal = true
            } label: {
                Label("Take Review", systemImage: "photo.on.rectangle")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
        }
    }

    private func presentDocumentViewer() {
        let docs = availableDocuments
        guard !docs.isEmpty else { return }
        documentViewerItems = docs
        documentViewerSelection = docs.first
        showDocumentViewer = true
    }
    @ViewBuilder
    private var pipToolsFloatingMenu: some View {
        Group {
            if showPIPToolsMenu {
                ZStack(alignment: .topTrailing) {
                    Color.black.opacity(0.001)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.snappy) { showPIPToolsMenu = false }
                        }

                    pipToolsMenuContent
                        .padding(16)
                        .frame(maxWidth: 240, alignment: .leading)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(Color.white.opacity(0.15), lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.35), radius: 14, x: 0, y: 8)
                        .padding(.trailing, 20)
                        .padding(.top, calculateTopBarTopPadding() + 48)
#if DEBUG
                        .transition(.opacity)
#else
                        .transition(.move(edge: .top).combined(with: .opacity))
#endif
                }
            }
        }
        .allowsHitTesting(showPIPToolsMenu)
    }
}

private struct ExitProcessingOverlayView: View {
    let message: String
    let details: String

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.4)
                    .tint(.white)

                VStack(spacing: 6) {
                    Text(message)
                        .font(.headline)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)

                    Text(details)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.75))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 28)
                }
            }
        }
        .allowsHitTesting(true)
        .accessibilityAddTraits(.isModal)
    }
}

// Preview
struct CameraCaptureView_Previews: PreviewProvider {
    static var previews: some View {
        CameraCaptureView(
            project: Project(title: "Sample Project", castingOffice: "Sample Casting"),
            session: ProjectSession(type: .selfTape, roleName: "Sample Role"),
            autoPresentSlatePrompt: false,
            // You can drop a PDF into the app’s documents dir and set its file name here to preview the menu:
            sidesFileName: "MySides.pdf",
            breakdownFileName: "MyBreakdown.pdf"
        ) {
            print("Preview completed")
        }
        .environmentObject(NavigationContextManager.shared)
        .environmentObject(ThemeManager())
    }
}
