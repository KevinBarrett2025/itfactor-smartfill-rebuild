import UIKit
import AVFoundation
import AVKit
import SwiftUI
import PryntTrimmerView
import TOCropViewController

/// PROFESSIONAL NON-DESTRUCTIVE VIDEO EDITOR with Apple-style UX and Edit Stack Architecture
/// INTEGRATED SYSTEM: Trimmer + Crop + SmartFill working together seamlessly
@MainActor
class LightweightEditorViewController: UIViewController, SmartFillProcessingDelegate, TrimmerViewDelegate, TOCropViewControllerDelegate, EditStackDelegate, UIGestureRecognizerDelegate {
    
    // MARK: - Enterprise Editor
    var enterpriseEditorHost: UIHostingController<EnterpriseEditorView>?
    var enterpriseEditorContext: EnterpriseEditorContext?
    private var hasRemovedLegacySubviewsForEnterprise = false
    
    // MARK: - Core Properties
    var originalAsset: AVAsset
    var onSaveEdits: ((AVAsset, CMTimeRange?, CGRect?, Double?) -> Void)?
    var onCancel: (() -> Void)?
    
    // NEW: Non-destructive edit stack architecture
    internal var editStack: EditStack!
    
    // CRITICAL FIX: Layout counter to prevent infinite layout cycles
    private var layoutCount = 0
    
    // Repository for SmartFill integration
    var repository: ProjectsRepository?
    var currentTake: ProjectTake?
    var currentSession: ProjectSession?
    var currentProject: Project?
    
    // Video playback properties
    internal var player: AVPlayer!
    internal var playerLayer: AVPlayerLayer!
    private var idleTimerToken: IdleTimerController.Token?
    private var idleTimerObservation: NSKeyValueObservation?
#if DEBUG
    private var hasLoggedPlayerMismatch = false
#endif
    
    // CLEAN: Removed complex position tracking - let native trimmer handle this
    // private var isUserScrubbing = false
    // private var isHandleDragging = false
    // private var staticPositionTime: CMTime?
    // private var isPositionBarStatic = false
    
    // UI references
    internal var toolbar: UIToolbar?
    private var buttonUpdateCounter = 0
    private var applyTrimButton: UIBarButtonItem?
    private var cancelTrimButton: UIBarButtonItem?
    private enum ToolbarMode {
        case normal
        case pendingTrim
    }
    private var toolbarMode: ToolbarMode = .normal
    private var playPauseBarButton: UIBarButtonItem?
    
    // Time observer for trim preview
    private var timeObserver: Any?
    private weak var timeObserverOwner: AVPlayer?
    private var timeObserverHeartbeat: Timer?
#if DEBUG
    private var lastPlayheadDebugLogSeconds: Double = -1
#endif

    // MARK: - EditorCore + SeekScheduler
    private var editorCore: EditorCore?
    private var seekScheduler: SeekScheduler?
    private var lastTrimmerSyncTime: CMTime?
    private var lastInteractionMode: EditorCore.InteractionMode = .idle
    private let playheadSyncThreshold: Double = 0.15

    // MARK: - Gestures
    private var playbackTapGesture: UITapGestureRecognizer?
    private var playheadTapGesture: UITapGestureRecognizer?
    private var playheadPanGesture: UIPanGestureRecognizer?
    
    private weak var observedPlayerItem: AVPlayerItem?
    
    // Video orientation and SmartFill state
    private var originalVideoOrientation: VideoOrientation?
    private var isShowingSmartFillVideo = false
    private var originalVideoPath: String?
    private var currentVideoPath: String?
    private var lastHandledSmartFillTakeID: UUID?
    private var orientationDiagnosticsRun: OrientationRun?
    // Crop state tracking
    private var currentCropSourceImageSize: CGSize?
    var latestPreviewComposition: AVMutableComposition?
    var latestPreviewVideoComposition: AVVideoComposition?
    
    // PROFESSIONAL TIMECODE SYSTEM: UI Elements for time display
    private var currentTimeLabel: UILabel!
    private var startTimeLabel: UILabel!
    private var endTimeLabel: UILabel!
    private var durationLabel: UILabel!
    private var scrubTimeLabel: UILabel!
    
    // NON-DESTRUCTIVE: Edit history UI
    private var editHistoryView: UIView!
    private var editHistoryStackView: UIStackView!
    
    // MARK: - Trim State
    internal var hasPendingTrimChanges = false
    private var pendingTrimStartTime: CMTime?
    private var pendingTrimEndTime: CMTime?
    internal var pendingTrimRange: CMTimeRange? = nil
    private var pendingEditMetadata: TakeEditMetadata?
    
    // A lightweight HUD label centered above the trimmer showing duration
    private let trimHud = UILabel()
    // PROFESSIONAL: Native trimmer integration (CLEAN VERSION!)
    internal var trimmerView: SimpleTrimmerView!
    
    init(asset: AVAsset) {
        self.originalAsset = asset
        self.trimmerView = SimpleTrimmerView(frame: .zero)
        super.init(nibName: nil, bundle: nil)
        
        // Initialize non-destructive edit stack
        editStack = EditStack(sourceAsset: asset)
        editStack.delegate = self
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        if let observedItem = observedPlayerItem {
            observedItem.removeObserver(self, forKeyPath: "status")
        }
        if let observer = timeObserver, let owner = timeObserverOwner {
            owner.removeTimeObserver(observer)
            timeObserver = nil
            timeObserverOwner = nil
        }
        timeObserverHeartbeat?.invalidate()
        idleTimerObservation?.invalidate()
        let token = idleTimerToken
        Task { @MainActor in
            token?.release()
        }
        
        // 🚀 LIVE SCRUBBING: Clean up handle seek timer
        handleSeekTimer?.invalidate()
        
        NotificationCenter.default.removeObserver(self)
    }
    
    // Setup with repository context
    func setupWithRepository(
        _ repository: ProjectsRepository,
        take: ProjectTake,
        session: ProjectSession,
        project: Project
    ) {
        self.repository = repository
        self.currentTake = take
        self.currentSession = session
        self.currentProject = project
        
        let originalURL = VideoVariantResolver.originalURL(for: take)
        let effectiveURL = VideoVariantResolver.effectiveURL(for: take)
        
        self.originalVideoPath = originalURL.path
        self.currentVideoPath = effectiveURL.path
        
        print("🔧 FIXED URL RESOLUTION:")
        print("   📁 Original URL: \(originalURL.path)")
        print("   📁 Effective URL: \(effectiveURL.path)")
        print("   📱 Orientation: \(take.capturedOrientation?.displayName ?? "Unknown")")
        
        self.originalVideoOrientation = take.capturedOrientation
        self.isShowingSmartFillVideo = take.hasSmartFilledVersion
        self.pendingEditMetadata = take.editMetadata
        
        SmartFillProcessingManager.shared.delegate = self
        
        // MODULAR EDITOR TEST: Enable modular editor for testing
        if STS_MODULAR_EDITOR_ENABLED {
            print("🧠 MODULAR EDITOR: Enabled for testing")
            self.enableModularEditor(at: effectiveURL)
        }

        startOrientationDiagnostics(for: effectiveURL, context: "EditorPreview")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        let enterpriseEnabled = STS_ENTERPRISE_EDITOR_ENABLED
        if enterpriseEnabled {
            view.backgroundColor = .black
            view.alpha = 0.0
        }
        
        setupUI()
        setupPlayer()
        startTimeObserverHeartbeat()
        
        if !enterpriseEnabled {
            setupProfessionalTimecodes()
            setupRealTrimmer()
            setupEditHistoryView()
            setupTrimHud()
            
            // CRITICAL FIX: Create toolbar immediately instead of complex deferred creation
            setupToolbarImmediately()
        }
        
        // CRITICAL FIX: Add SmartFill completion notification observer
        setupSmartFillNotifications()
        
        applyPendingEditMetadataIfNeeded()
        
        if enterpriseEnabled {
            print("✅ ENTERPRISE SETUP: Legacy chrome suppressed until SwiftUI surface mounts")
        } else {
            // CLEAN: Remove complex monitoring - let native trimmer handle everything
            print("✅ CLEAN SETUP: Native trimmer handling all interactions")
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Final safety-net: ensure the periodic observer is installed on the current player.
        ensurePeriodicTimeObserverInstalled()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        Task { @MainActor in
            releaseIdleTimer()
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Belt-and-suspenders: make sure the playhead observer is attached whenever the view comes back.
        ensurePeriodicTimeObserverInstalled()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        // CRITICAL FIX: Prevent layout cycle by only logging occasionally
        layoutCount += 1
        if layoutCount % 50 == 1 {
            print("📐 LAYOUT: viewDidLayoutSubviews #\(layoutCount) with bounds: \(view.bounds)")
        }
        
        let safeArea = view.safeAreaInsets
        let availableWidth = view.bounds.width - safeArea.left - safeArea.right
        let availableHeight = view.bounds.height - safeArea.top - safeArea.bottom
        
        let playerHeight: CGFloat = max(200, availableHeight * 0.5)
        let playerFrame = CGRect(
            x: safeArea.left,
            y: safeArea.top,
            width: availableWidth,
            height: playerHeight
        )
        
        if let playerLayer = playerLayer {
            playerLayer.frame = playerFrame
            playerLayer.isHidden = false
            playerLayer.opacity = 1.0
            
            if let sublayers = view.layer.sublayers, sublayers.contains(playerLayer) {
                view.layer.insertSublayer(playerLayer, at: 0)
            }
        }
        
        if STS_ENTERPRISE_EDITOR_ENABLED {
            return
        }
        
        positionTimecodeDisplays()
        positionEditHistoryView()
        
        guard let trimmerView = self.trimmerView, let toolbar = toolbar else {
            return
        }
        
        let trimmerHeight: CGFloat = 60
        let toolbarHeight: CGFloat = 80
        let margin: CGFloat = 20
        
        let trimmerY = view.bounds.height
            - view.safeAreaInsets.bottom
            - toolbarHeight
            - trimmerHeight
            - 16
        
        let newTrimmerFrame = CGRect(
            x: safeArea.left + margin,
            y: trimmerY,
            width: availableWidth - (margin * 2),
            height: trimmerHeight
        )
        
        // 🔧 LAYOUT FIX: Only update frame if it actually changed
        if !trimmerView.frame.equalTo(newTrimmerFrame) {
            print("🔧 LAYOUT: Updating trimmer frame from \(trimmerView.frame) to \(newTrimmerFrame)")
            trimmerView.frame = newTrimmerFrame
        } else if layoutCount % 100 == 1 {
            // Only log occasionally when frame doesn't change
            print("📐 LAYOUT: Trimmer frame unchanged, skipping update")
        }
        
        // Position toolbar properly
        let toolbarFrame = CGRect(
            x: 0,
            y: view.bounds.height - safeArea.bottom - toolbarHeight,
            width: view.bounds.width,
            height: toolbarHeight
        )
        
        // 🔧 LAYOUT FIX: Only update toolbar frame if it actually changed
        if !toolbar.frame.equalTo(toolbarFrame) {
            toolbar.frame = toolbarFrame
            print("🔧 LAYOUT: Updated toolbar frame")
        }
        
        // Ensure toolbar is visible and properly layered
        view.bringSubviewToFront(toolbar)
        view.bringSubviewToFront(trimmerView)
        bringTimecodesToFront()
    }

    // CRITICAL FIX: Immediate toolbar setup instead of complex deferred creation
    private func setupToolbarImmediately() {
        print("🔧 IMMEDIATE TOOLBAR: Creating toolbar immediately in viewDidLoad")
        
        let toolbar = UIToolbar()
        toolbar.backgroundColor = UIColor.black.withAlphaComponent(0.9)
        toolbar.barTintColor = UIColor.black
        toolbar.barStyle = .black
        toolbar.autoresizingMask = [.flexibleWidth, .flexibleTopMargin]
        
        // Create Apply/Cancel buttons immediately
        applyTrimButton = UIBarButtonItem(title: "Apply", style: .done, target: self, action: #selector(applyPendingTrim))
        applyTrimButton?.tintColor = UIColor.systemGreen
        
        cancelTrimButton = UIBarButtonItem(title: "Cancel", style: .plain, target: self, action: #selector(cancelPendingTrim))
        cancelTrimButton?.tintColor = UIColor.systemRed
        
        print("✅ CRITICAL: Apply/Cancel buttons created: apply=\(String(describing: applyTrimButton != nil)), cancel=\(String(describing: cancelTrimButton != nil))")
        
        // Add to view hierarchy immediately
        view.addSubview(toolbar)
        self.toolbar = toolbar
        
        // Set up default toolbar items
        recreateDefaultToolbarItems()
        updatePlayPauseButton()
        
        print("✅ IMMEDIATE TOOLBAR: Toolbar created and added to view successfully")
    }
    
    private func setupUI() {
        view.backgroundColor = .black
        
        let symbolConfig = UIImage.SymbolConfiguration(
            pointSize: 22,
            weight: .semibold,
            scale: .medium
        )
        
        let closeImage = UIImage(
            systemName: "xmark.circle.fill",
            withConfiguration: symbolConfig
        )
        
        let closeButton = UIBarButtonItem(
            image: closeImage,
            style: .plain,
            target: self,
            action: #selector(cancelEdits)
        )
        
        closeButton.tintColor = UIColor.white
        closeButton.setBackgroundImage(
            createCloseButtonBackgroundWithShadow(),
            for: .normal,
            barMetrics: .default
        )
        
        navigationItem.leftBarButtonItem = closeButton
        
        updateNavigationBarForEditStack()
        
        if STS_ENTERPRISE_EDITOR_ENABLED {
            navigationItem.title = nil
        }
    }
    
    private func createCloseButtonBackgroundWithShadow() -> UIImage? {
        let size = CGSize(width: 44, height: 44)
        
        return UIGraphicsImageRenderer(size: size).image { context in
            let rect = CGRect(origin: .zero, size: size)
            let shadowRect = rect.insetBy(dx: 2, dy: 2)
            
            context.cgContext.setShadow(
                offset: CGSize(width: 0, height: 1),
                blur: 2,
                color: UIColor.black.withAlphaComponent(0.3).cgColor
            )
            
            UIColor.black.withAlphaComponent(0.2).setFill()
            context.cgContext.fillEllipse(in: shadowRect)
        }
    }
    
    // PROFESSIONAL TIMECODE SYSTEM: Setup comprehensive time displays
    private func setupProfessionalTimecodes() {
        print("⏱️ PROFESSIONAL TIMECODES: Setting up clean time display system")
        
        currentTimeLabel = createTimecodeLabel(
            text: "00:00",
            fontSize: 18,
            backgroundColor: UIColor.black.withAlphaComponent(0.7),
            textColor: UIColor.white
        )
        view.addSubview(currentTimeLabel)
        
        startTimeLabel = createSimpleTimecodeLabel(text: "00:00", fontSize: 14)
        view.addSubview(startTimeLabel)
        
        endTimeLabel = createSimpleTimecodeLabel(text: "00:00", fontSize: 14)
        view.addSubview(endTimeLabel)
        
        durationLabel = createSimpleTimecodeLabel(text: "00:16", fontSize: 14)
        view.addSubview(durationLabel)
        
        scrubTimeLabel = createTimecodeLabel(text: "00:00", fontSize: 16, backgroundColor: UIColor.systemGreen.withAlphaComponent(0.9), textColor: UIColor.white)
        scrubTimeLabel.isHidden = true
        view.addSubview(scrubTimeLabel)
        
        print("✅ PROFESSIONAL TIMECODES: Clean timecode displays created")
    }
    
    private func createSimpleTimecodeLabel(text: String, fontSize: CGFloat) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = UIFont.monospacedDigitSystemFont(ofSize: fontSize, weight: .medium)
        label.textColor = UIColor.white
        label.backgroundColor = UIColor.clear
        label.textAlignment = .center
        label.sizeToFit()
        
        label.layer.shadowColor = UIColor.black.cgColor
        label.layer.shadowOffset = CGSize(width: 0, height: 1)
        label.layer.shadowRadius = 2
        label.layer.shadowOpacity = 0.8
        
        return label
    }
    
    private func createTimecodeLabel(text: String, fontSize: CGFloat, backgroundColor: UIColor, textColor: UIColor) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = UIFont.monospacedDigitSystemFont(ofSize: fontSize, weight: .semibold)
        label.textColor = textColor
        label.backgroundColor = backgroundColor
        label.textAlignment = .center
        label.layer.cornerRadius = 6
        label.layer.masksToBounds = true
        label.sizeToFit()
        
        label.frame = CGRect(
            x: label.frame.origin.x,
            y: label.frame.origin.y,
            width: label.frame.width + 16,
            height: label.frame.height + 8
        )
        
        return label
    }
    
    // NON-DESTRUCTIVE: Setup edit history view
    private func setupEditHistoryView() {
        print("📝 EDIT HISTORY: Setting up non-destructive edit history view")
        
        editHistoryView = UIView()
        editHistoryView.backgroundColor = UIColor.black.withAlphaComponent(0.8)
        editHistoryView.layer.cornerRadius = 8
        view.addSubview(editHistoryView)
        
        editHistoryStackView = UIStackView()
        editHistoryStackView.axis = .horizontal
        editHistoryStackView.spacing = 12
        editHistoryStackView.alignment = .center
        editHistoryStackView.distribution = .equalSpacing
        editHistoryView.addSubview(editHistoryStackView)
        
        updateEditHistoryView()
    }
    
    // NON-DESTRUCTIVE: Update edit history view with current operations
    private func updateEditHistoryView() {
        if STS_ENTERPRISE_EDITOR_ENABLED { return }
        
        editHistoryStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        if editStack.hasOperations {
            for operation in editStack.operations {
                let operationView = createOperationIndicatorView(for: operation)
                editHistoryStackView.addArrangedSubview(operationView)
            }
            
            let undoButton = createUndoRedoButton(
                systemName: "arrow.uturn.backward",
                action: #selector(undoLastEdit),
                enabled: editStack.canUndo
            )
            editHistoryStackView.addArrangedSubview(undoButton)
            
            let redoButton = createUndoRedoButton(
                systemName: "arrow.uturn.forward",
                action: #selector(redoLastEdit),
                enabled: editStack.canRedo
            )
            editHistoryStackView.addArrangedSubview(redoButton)
            
        } else {
            let noEditsLabel = UILabel()
            noEditsLabel.text = "No edits applied"
            noEditsLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
            noEditsLabel.textColor = UIColor.lightGray
            editHistoryStackView.addArrangedSubview(noEditsLabel)
        }
    }
    
    private func createOperationIndicatorView(for operation: EditOperation) -> UIView {
        let container = UIView()
        container.backgroundColor = UIColor(red: 0.6, green: 0.2, blue: 0.8, alpha: 0.8)
        container.layer.cornerRadius = 16
        container.frame.size = CGSize(width: 32, height: 32)
        
        let imageView = UIImageView()
        imageView.image = UIImage(systemName: operation.iconName)
        imageView.tintColor = UIColor.white
        imageView.contentMode = .scaleAspectFit
        imageView.frame = container.bounds.insetBy(dx: 6, dy: 6)
        container.addSubview(imageView)
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(showOperationDetails))
        tapGesture.accessibilityLabel = operation.id.uuidString
        container.addGestureRecognizer(tapGesture)
        container.isUserInteractionEnabled = true
        
        return container
    }
    
    private func createUndoRedoButton(systemName: String, action: Selector, enabled: Bool) -> UIButton {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: systemName), for: .normal)
        button.tintColor = enabled ? UIColor.white : UIColor.darkGray
        button.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        button.layer.cornerRadius = 16
        button.frame.size = CGSize(width: 32, height: 32)
        button.addTarget(self, action: action, for: .touchUpInside)
        button.isEnabled = enabled
        
        return button
    }
    
    private func positionEditHistoryView() {
        guard let editHistoryView = editHistoryView else { return }
        
        let safeArea = view.safeAreaInsets
        let playerHeight: CGFloat = max(200, (view.bounds.height - safeArea.top - safeArea.bottom) * 0.5)
        let editHistoryHeight: CGFloat = 60
        let margin: CGFloat = 20
        
        let editHistoryY = safeArea.top + playerHeight + 20
        
        editHistoryView.frame = CGRect(
            x: safeArea.left + margin,
            y: editHistoryY,
            width: view.bounds.width - safeArea.left - safeArea.right - (margin * 2),
            height: editHistoryHeight
        )
        
        editHistoryStackView.frame = editHistoryView.bounds.insetBy(dx: 16, dy: 12)
    }
    
    private func positionTimecodeDisplays() {
        guard let currentTimeLabel = currentTimeLabel,
              let startTimeLabel = startTimeLabel,
              let endTimeLabel = endTimeLabel,
              let durationLabel = durationLabel,
              let scrubTimeLabel = scrubTimeLabel else { return }
        
        let safeArea = view.safeAreaInsets
        let margin: CGFloat = 16
        
        currentTimeLabel.frame.origin = CGPoint(x: safeArea.left + margin, y: safeArea.top + margin)
        
        if let trimmerView = self.trimmerView {
            let trimmerFrame = trimmerView.frame
            
            startTimeLabel.sizeToFit()
            startTimeLabel.frame.origin = CGPoint(
                x: trimmerFrame.origin.x + 8,
                y: trimmerFrame.origin.y - startTimeLabel.frame.height - 4
            )
            
            endTimeLabel.sizeToFit()
            endTimeLabel.frame.origin = CGPoint(
                x: trimmerFrame.origin.x + trimmerFrame.width - endTimeLabel.frame.width - 8,
                y: trimmerFrame.origin.y - endTimeLabel.frame.height - 4
            )
            
            durationLabel.sizeToFit()
            durationLabel.frame.origin = CGPoint(
                x: trimmerFrame.origin.x + (trimmerFrame.width - durationLabel.frame.width) / 2,
                y: trimmerFrame.origin.y + (trimmerFrame.height - durationLabel.frame.height) / 2
            )
            
            trimHud.sizeToFit()
            trimHud.frame = CGRect(
                x: trimmerFrame.origin.x + (trimmerFrame.width - max(trimHud.frame.width, 88)) / 2,
                y: trimmerFrame.origin.y - trimHud.frame.height - 16,
                width: max(trimHud.frame.width + 16, 88),
                height: 32
            )
            
            scrubTimeLabel.sizeToFit()
            scrubTimeLabel.frame = CGRect(
                x: trimmerFrame.origin.x + (trimmerFrame.width - scrubTimeLabel.frame.width - 16) / 2,
                y: trimmerFrame.origin.y - scrubTimeLabel.frame.height - 30,
                width: scrubTimeLabel.frame.width + 16,
                height: scrubTimeLabel.frame.height + 8
            )
        }
        
        print("✅ CLEAN TIMECODE POSITIONING: All timecode labels positioned cleanly")
    }
    
    private func bringTimecodesToFront() {
        view.bringSubviewToFront(currentTimeLabel)
        
        if let trimmerView = self.trimmerView {
            view.bringSubviewToFront(durationLabel)
            view.bringSubviewToFront(trimmerView)
        }
        
        view.bringSubviewToFront(startTimeLabel)
        view.bringSubviewToFront(endTimeLabel)
        view.bringSubviewToFront(scrubTimeLabel)
    }
    
    private func formatTime(_ time: CMTime) -> String {
        guard !time.isIndefinite && time.isValid else { return "00:00" }
        let totalSeconds = Int(CMTimeGetSeconds(time))
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    @MainActor
    func updateTimecodeDisplays() {
        if STS_ENTERPRISE_EDITOR_ENABLED { return }
        
        if STS_EDITORCORE_SSOT_ENABLED, let core = editorCore {
            currentTimeLabel.text = formatTime(core.playhead)
            startTimeLabel.text = formatTime(core.trimRange.start)
            let endTime = CMTimeAdd(core.trimRange.start, core.trimRange.duration)
            endTimeLabel.text = formatTime(endTime)
            durationLabel.text = formatTime(core.trimRange.duration)
            trimHud.text = "Duration: \(formatTime(core.trimRange.duration))"
            scrubTimeLabel.isHidden = true
            return
        }

        if let player = resolveActivePlayer("updateTimecodeDisplays") {
            let currentTime = player.currentTime()
            currentTimeLabel.text = formatTime(currentTime)
        }
        
        if let trimmerView = self.trimmerView,
           let startTime = trimmerView.startTime,
           let endTime = trimmerView.endTime {
            
            startTimeLabel.text = formatTime(startTime)
            endTimeLabel.text = formatTime(endTime)
            
            let duration = CMTimeSubtract(endTime, startTime)
            durationLabel.text = formatTime(duration)
            trimHud.text = "Duration: \(formatTime(duration))"
        } else {
            Task {
                do {
                    let originalDuration = try await originalAsset.load(.duration)
                    await MainActor.run {
                        self.startTimeLabel.text = "00:00"
                        self.endTimeLabel.text = self.formatTime(originalDuration)
                        self.durationLabel.text = self.formatTime(originalDuration)
                    }
                } catch {
                    print("❌ Failed to load duration for timecode display: \(error)")
                }
            }
        }
        
        // CLEAN: Removed complex scrub time label logic - just hide it
        scrubTimeLabel.isHidden = true
    }
    
    func updateNavigationBarForEditStack() {
        // Show only the SmartFill badge when applicable; otherwise keep the right side empty.
        if let take = currentTake,
           (take.smartFilledFilePath != nil || take.isSmartFillVariant || take.hasSmartFilledVersion) {
            let smartFillItem = UIBarButtonItem(
                image: UIImage(systemName: "person.and.background.dotted"),
                style: .plain,
                target: self,
                action: #selector(modularSmartFillTapped)
            )
            smartFillItem.tintColor = UIColor.systemCyan
            navigationItem.rightBarButtonItems = [smartFillItem]
        } else {
            navigationItem.rightBarButtonItems = nil
        }
    }
    
    @MainActor
    private func setupPlayer() {
        print("🎬 PLAYER SETUP: Starting with enhanced video display")
        
        let initialAsset = originalAsset
        
        let playerItem = AVPlayerItem(asset: initialAsset)
        if let existingPlayer = player {
            let oldItemID = existingPlayer.currentItem.map { ObjectIdentifier($0) }
            existingPlayer.replaceCurrentItem(with: playerItem)
            player = existingPlayer
#if DEBUG
            let playerID = ObjectIdentifier(existingPlayer)
            let newItemID = ObjectIdentifier(playerItem)
            print("🔁 ActivePlayer replaceCurrentItem: player=\(playerID) oldItem=\(String(describing: oldItemID)) newItem=\(newItemID)")
#endif
        } else {
            player = AVPlayer(playerItem: playerItem)
        }
        playerLayer = AVPlayerLayer(player: player)
        
        playerLayer.backgroundColor = UIColor.black.cgColor
        playerLayer.videoGravity = .resizeAspect
        
        if let originalOrientation = originalVideoOrientation {
            playerLayer.videoGravity = originalOrientation == .portrait ? .resizeAspectFill : .resizeAspect
        } else {
            playerLayer.videoGravity = .resizeAspect
        }
        
        let safeArea = view.safeAreaInsets
        let initialHeight = max(200, view.bounds.height * 0.4)
        playerLayer.frame = CGRect(
            x: safeArea.left,
            y: safeArea.top + 44,
            width: view.bounds.width - safeArea.left - safeArea.right,
            height: initialHeight
        )
        
        view.layer.addSublayer(playerLayer)
        if STS_ENTERPRISE_EDITOR_ENABLED {
            playerLayer.isHidden = true
        }

        setActivePlayer(player, reason: "setupPlayer")
        
        playerItem.addObserver(self, forKeyPath: "status", options: [.new], context: nil)
        observedPlayerItem = playerItem
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(itemDidFinishPlaying(_:)),
            name: .AVPlayerItemDidPlayToEndTime,
            object: playerItem
        )
        
        if !STS_ENTERPRISE_EDITOR_ENABLED {
            let tapGesture = UITapGestureRecognizer(target: self, action: #selector(togglePlayback))
            tapGesture.cancelsTouchesInView = false
            tapGesture.delegate = self
            playbackTapGesture = tapGesture
            view.addGestureRecognizer(tapGesture)
        }
        
        Task {
            let result = await editStack.getPreviewComposition()
            if let previewComposition = result.composition {
                await MainActor.run {
                    self.updatePlayerWithComposition(previewComposition, videoComposition: result.videoComposition)
                }
            }
        }
        
        ensurePeriodicTimeObserverInstalled()
        configureEditorCoreIfNeeded(with: initialAsset)
        if STS_SEEKSCHEDULER_ENABLED {
            if let existingScheduler = seekScheduler {
                existingScheduler.updatePlayer(player)
            } else {
                seekScheduler = SeekScheduler(player: player)
            }
        }
        print("✅ PLAYER SETUP: Complete - starting in paused state")
    }

    @MainActor
    private func configureEditorCoreIfNeeded(with asset: AVAsset) {
        guard STS_EDITORCORE_SSOT_ENABLED, editorCore == nil else { return }
        Task { @MainActor [weak self] in
            guard let self else { return }
            let duration = (try? await asset.load(.duration)) ?? CMTime(seconds: 1, preferredTimescale: 600)
            let initialTrim = self.editStack.currentTrimRange ?? CMTimeRange(start: .zero, duration: duration)
            let core = EditorCore(duration: duration, trimRange: initialTrim)
            self.bindEditorCore(core)
        }
    }

    @MainActor
    private func bindEditorCore(_ core: EditorCore) {
        editorCore = core
        core.onSeekRequested = { [weak self] time, policy in
            self?.requestSeek(time, policy: policy, completion: nil)
        }
        core.onStateChange = { [weak self] _ in
            guard let self else { return }
            if !STS_ENTERPRISE_EDITOR_ENABLED {
                self.updateTimecodeDisplays()
            }
        }
    }

    @MainActor
    func requestSeek(_ time: CMTime, policy: SeekScheduler.Policy, completion: (() -> Void)?) {
        if STS_SEEKSCHEDULER_ENABLED, let scheduler = seekScheduler {
            scheduler.request(.init(time: time, policy: policy, completion: completion))
            return
        }
        let tolerance = policy == .scrub ? CMTime(seconds: 0.05, preferredTimescale: 600) : .zero
        resolveActivePlayer("requestSeek")?.seek(to: time, toleranceBefore: tolerance, toleranceAfter: tolerance, completionHandler: { _ in
            completion?()
        })
    }

    private func installIdleTimerObservation(on player: AVPlayer) {
        idleTimerObservation?.invalidate()
        idleTimerObservation = player.observe(\.timeControlStatus, options: [.initial, .new]) { [weak self] player, _ in
            let isPlaying = player.timeControlStatus == .playing
            Task { @MainActor [weak self] in
                self?.updateIdleTimer(isPlaying)
            }
        }
    }

    @MainActor
    private func updateIdleTimer(_ isPlaying: Bool) {
        if isPlaying {
            if idleTimerToken == nil {
                idleTimerToken = IdleTimerController.shared.acquire(reason: "LightweightEditor")
            }
        } else {
            releaseIdleTimer()
        }
    }

    @MainActor
    private func releaseIdleTimer() {
        idleTimerToken?.release()
        idleTimerToken = nil
    }
    
    private func setupRealTrimmer() {
        print("🎛️ CLEAN NATIVE TRIMMER: Using simple PryntTrimmerView implementation")
        
        // CLEAN: Create simple native trimmer
        trimmerView = SimpleTrimmerView(frame: .zero)
        
        // Set delegate immediately - no complex timing needed
        trimmerView.delegate = self
        
        // Basic configuration
        trimmerView.minDuration = 1.0 // Allow short clips
        
        // Simple frame setup
        let initialFrame = CGRect(x: 20, y: 100, width: max(200, view.bounds.width - 40), height: 60)
        trimmerView.frame = initialFrame
        
        view.addSubview(trimmerView)
        
        // Set asset directly - no pendingURL or deferred loading
        if let originalVideoPath = originalVideoPath {
            let asset = AVURLAsset(url: URL(fileURLWithPath: originalVideoPath))
            trimmerView.asset = asset
            print("✅ CLEAN ASSET: Loaded directly into native trimmer")
        } else if let currentVideoPath = currentVideoPath {
            let asset = AVURLAsset(url: URL(fileURLWithPath: currentVideoPath))
            trimmerView.asset = asset
        }
        
        // No complex timing, no deferred delegate assignment
        view.bringSubviewToFront(trimmerView)
        if STS_EDITORCORE_SSOT_ENABLED {
            installPlayheadGesturesIfNeeded()
        }
        
        print("✅ CLEAN NATIVE TRIMMER: Setup complete with direct asset loading")
    }
    
    // MARK: - Edit Stack Delegate Methods
    
    nonisolated func editStackDidChange(_ editStack: EditStack) {
        print("📝 EDIT STACK CHANGED: \(editStack.operationCount) operations")
        print("🚨 DEBUG CRITICAL: EditStack changed - this should update 'No edits applied' text")
        
        Task { @MainActor [weak self] in
            guard let self else { return }
            if let context = self.enterpriseEditorContext {
                context.syncWithEditStack(
                    trimRange: editStack.currentTrimRange,
                    cropRect: editStack.currentCropRect,
                    cropRotation: editStack.currentCropRotationDegrees.map { Double($0) }
                )
            }
            if STS_EDITORCORE_SSOT_ENABLED, let core = self.editorCore {
                if let range = editStack.currentTrimRange {
                    core.setTrimRange(range, clampPlayhead: true)
                } else {
                    let fullRange = CMTimeRange(start: .zero, duration: core.duration)
                    core.setTrimRange(fullRange, clampPlayhead: true)
                }
            }
            
            if STS_ENTERPRISE_EDITOR_ENABLED {
                return
            }
            
            self.updateEditHistoryView()
            self.updateNavigationBarForEditStack()
            self.refreshToolbarButtons()
            self.updateTimecodeDisplays()
        }
    }
    
    nonisolated func editStackPreviewDidUpdate(_ editStack: EditStack, composition: AVMutableComposition?, videoComposition: AVVideoComposition?) {
        print("🔄 PREVIEW UPDATE: Composition available (with video composition: \(videoComposition != nil))")
        
        Task { @MainActor [weak self] in
            guard let self else { return }
            if let newComposition = composition {
                self.updatePlayerWithComposition(newComposition, videoComposition: videoComposition)
            } else {
                self.latestPreviewComposition = nil
                self.latestPreviewVideoComposition = nil
            }
        }
    }
    
    // NON-DESTRUCTIVE: Update player with new composition and video composition for visual effects
    private func updatePlayerWithComposition(_ composition: AVMutableComposition, videoComposition: AVVideoComposition? = nil) {
        let activePlayer = resolveActivePlayer("updatePlayerWithComposition")
        let currentTime = activePlayer?.currentTime() ?? .zero
        activePlayer?.pause()
        
        if let observedItem = observedPlayerItem {
            observedItem.removeObserver(self, forKeyPath: "status")
            observedPlayerItem = nil
        }
        
        removePeriodicTimeObserverIfNeeded()
        
        let newPlayerItem = AVPlayerItem(asset: composition)
        
        // CRITICAL FIX: Apply video composition for crop operations
        if let videoComposition = videoComposition {
            newPlayerItem.videoComposition = videoComposition
            print("✅ CROP FIX: Applied video composition to player item - crop should now be visible")
        }
        
        latestPreviewComposition = composition
        latestPreviewVideoComposition = videoComposition
        
        let targetPlayer = activePlayer ?? AVPlayer(playerItem: newPlayerItem)
        if activePlayer == nil {
            setActivePlayer(targetPlayer, reason: "updatePlayerWithComposition")
        }
        let oldItemID = targetPlayer.currentItem.map { ObjectIdentifier($0) }
        targetPlayer.replaceCurrentItem(with: newPlayerItem)
        self.playerLayer?.player = targetPlayer
#if DEBUG
        let playerID = ObjectIdentifier(targetPlayer)
        let newItemID = ObjectIdentifier(newPlayerItem)
        print("🔁 ActivePlayer replaceCurrentItem: player=\(playerID) oldItem=\(String(describing: oldItemID)) newItem=\(newItemID)")
#endif
        
        if let coordinator = self.coordinator,
           coordinator.playerSurfaceVC.viewIfLoaded?.superview != nil {
            let gravity = self.playerLayer?.videoGravity ?? .resizeAspect
            coordinator.playerSurfaceVC.attach(
                asset: composition,
                gravity: gravity,
                videoComposition: videoComposition
            )
        }
        
        newPlayerItem.addObserver(self, forKeyPath: "status", options: [.new], context: nil)
        observedPlayerItem = newPlayerItem
        
        installPeriodicTimeObserver(on: targetPlayer)
        updatePlayPauseButton()
        
        Task { @MainActor in
            if let duration = try? await composition.load(.duration) {
                let safeTime = CMTimeMinimum(currentTime, duration)
                self.requestSeek(safeTime, policy: .settle, completion: nil)
            }
        }
    }
    
    // MARK: - Apple-Style UX Methods
    
    @objc private func handlePositionBarDrag(_ gesture: UIPanGestureRecognizer) {
        // Keeping the method in place in case future logic references it, but it does nothing now.
    }

    private func installPlayheadGesturesIfNeeded() {
        guard playheadTapGesture == nil, let trimmerView = trimmerView else { return }
        let tap = UITapGestureRecognizer(target: self, action: #selector(handlePlayheadTap))
        tap.cancelsTouchesInView = false
        tap.delegate = self
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePlayheadPan))
        pan.cancelsTouchesInView = false
        pan.delegate = self
        trimmerView.addGestureRecognizer(tap)
        trimmerView.addGestureRecognizer(pan)
        playheadTapGesture = tap
        playheadPanGesture = pan
        if let playbackTapGesture = playbackTapGesture {
            playbackTapGesture.require(toFail: tap)
        }
    }

    @objc private func handlePlayheadTap(_ gesture: UITapGestureRecognizer) {
        guard STS_EDITORCORE_SSOT_ENABLED, let trimmerView = trimmerView else { return }
        let location = gesture.location(in: trimmerView)
        guard let time = trimmerView.time(for: location) else { return }
        pausePlaybackForInteractionIfNeeded()
        trimmerView.seek(to: time)
        lastTrimmerSyncTime = time
        editorCore?.beginInteraction(.draggingPlayhead)
        editorCore?.endInteraction(finalPlayhead: time)
    }

    @objc private func handlePlayheadPan(_ gesture: UIPanGestureRecognizer) {
        guard STS_EDITORCORE_SSOT_ENABLED, let trimmerView = trimmerView else { return }
        let location = gesture.location(in: trimmerView)
        guard let time = trimmerView.time(for: location) else { return }
        switch gesture.state {
        case .began:
            pausePlaybackForInteractionIfNeeded()
            editorCore?.beginInteraction(.draggingPlayhead)
            editorCore?.setPlayhead(time, policy: .scrub)
            trimmerView.seek(to: time)
            lastTrimmerSyncTime = time
        case .changed:
            editorCore?.setPlayhead(time, policy: .scrub)
            trimmerView.seek(to: time)
            lastTrimmerSyncTime = time
        case .ended, .cancelled, .failed:
            trimmerView.seek(to: time)
            lastTrimmerSyncTime = time
            editorCore?.endInteraction(finalPlayhead: time)
        default:
            break
        }
    }

    @MainActor
    private func pausePlaybackForInteractionIfNeeded() {
        guard let player = resolveActivePlayer("pausePlaybackForInteractionIfNeeded") else { return }
        if player.timeControlStatus == .playing || player.timeControlStatus == .waitingToPlayAtSpecifiedRate {
            player.pause()
            editorCore?.setPlaying(false)
            updatePlayPauseButton()
            enterpriseEditorContext?.updatePlaybackStateFromPlayer()
        }
    }
    
    // MARK: - TrimmerViewDelegate Methods (COMPLETE IMPLEMENTATION)
    private var lastTrimStartTime: CMTime?
    private var lastTrimEndTime: CMTime?
    
    private var handleSeekTimer: Timer?
    private var isLiveScrubbing = false
    
    @MainActor
    private func handleTrimmerPositionDidChange(_ playerTime: CMTime) {
        print("🎯 CLEAN DELEGATE: didChangePositionBar fired with time \(playerTime.seconds)s")
        guard let trimmerView = trimmerView,
              let currentStartTime = trimmerView.startTime,
              let currentEndTime = trimmerView.endTime else {
            return
        }

        if STS_EDITORCORE_SSOT_ENABLED {
            let startTimeChanged = lastTrimStartTime == nil ||
                abs(currentStartTime.seconds - (lastTrimStartTime?.seconds ?? 0)) > 0.01
            let endTimeChanged = lastTrimEndTime == nil ||
                abs(currentEndTime.seconds - (lastTrimEndTime?.seconds ?? 0)) > 0.01
            let interaction = classifyTrimmerInteraction(start: currentStartTime, end: currentEndTime)
            if interaction != lastInteractionMode {
                pausePlaybackForInteractionIfNeeded()
            }
            lastInteractionMode = interaction
            switch interaction {
            case .scrollingTimeline:
                editorCore?.beginInteraction(.scrollingTimeline)
                editorCore?.setPlayhead(playerTime, policy: .scrub)
                if startTimeChanged || endTimeChanged {
                    editorCore?.updateTrimRange(start: currentStartTime, end: currentEndTime, isFinal: false)
                    let range = CMTimeRange(start: currentStartTime, duration: CMTimeSubtract(currentEndTime, currentStartTime))
                    hasPendingTrimChanges = true
                    pendingTrimRange = range
                    updateToolbarForPendingTrim(true)
                }
            case .draggingTrimStart, .draggingTrimEnd:
                editorCore?.beginInteraction(interaction)
                editorCore?.updateTrimRange(start: currentStartTime, end: currentEndTime, isFinal: false)
                let range = CMTimeRange(start: currentStartTime, duration: CMTimeSubtract(currentEndTime, currentStartTime))
                hasPendingTrimChanges = true
                pendingTrimRange = range
                updateToolbarForPendingTrim(true)
            case .draggingPlayhead, .idle:
                break
            }
            lastTrimStartTime = currentStartTime
            lastTrimEndTime = currentEndTime
            updateTimecodeDisplays()
            return
        }

        let startTimeChanged = lastTrimStartTime == nil ||
                             abs(currentStartTime.seconds - (lastTrimStartTime?.seconds ?? 0)) > 0.01
        let endTimeChanged = lastTrimEndTime == nil ||
                           abs(currentEndTime.seconds - (lastTrimEndTime?.seconds ?? 0)) > 0.01
        
        if startTimeChanged || endTimeChanged {
            print("✂️ CLEAN TRIM CHANGE: Handle moved - start=\(currentStartTime.seconds)s, end=\(currentEndTime.seconds)s")
            performLiveScrubbing(startTime: currentStartTime, endTime: currentEndTime, playerTime: playerTime)
            
            let range = CMTimeRange(start: currentStartTime, duration: CMTimeSubtract(currentEndTime, currentStartTime))
            hasPendingTrimChanges = true
            pendingTrimRange = range
            updateToolbarForPendingTrim(true)
            
            lastTrimStartTime = currentStartTime
            lastTrimEndTime = currentEndTime
            
            print("✅ LIVE SCRUBBING: Added real-time seeking with native trimmer coordination")
        }
        
        updateTimecodeDisplays()
    }
    
    nonisolated func didChangePositionBar(_ playerTime: CMTime) {
        Task { @MainActor [weak self] in
            self?.handleTrimmerPositionDidChange(playerTime)
            self?.ensurePeriodicTimeObserverInstalled()
        }
    }
    
    private func performLiveScrubbing(startTime: CMTime, endTime: CMTime, playerTime: CMTime) {
        let seekToTime = determineOptimalSeekTime(startTime: startTime, endTime: endTime, currentPlayerTime: playerTime)
        
        updateTrimHudForLiveScrubbing(seekToTime, range: CMTimeRange(start: startTime, duration: CMTimeSubtract(endTime, startTime)))
        
        handleSeekTimer?.invalidate()
        handleSeekTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.requestSeek(seekToTime, policy: .scrub, completion: nil)
                print("🎯 LIVE SEEK: Sought to \(seekToTime.seconds)s during handle movement")
            }
        }
    }
    
    private func determineOptimalSeekTime(startTime: CMTime, endTime: CMTime, currentPlayerTime: CMTime) -> CMTime {
        let distanceToStart = abs(currentPlayerTime.seconds - startTime.seconds)
        let distanceToEnd = abs(currentPlayerTime.seconds - endTime.seconds)
        
        return distanceToStart <= distanceToEnd ? startTime : endTime
    }

    private func classifyTrimmerInteraction(start: CMTime, end: CMTime) -> EditorCore.InteractionMode {
        guard let lastStart = lastTrimStartTime, let lastEnd = lastTrimEndTime else {
            return .scrollingTimeline
        }
        let deltaStart = start.seconds - lastStart.seconds
        let deltaEnd = end.seconds - lastEnd.seconds
        let epsilon = 0.005
        if abs(deltaStart) < epsilon && abs(deltaEnd) < epsilon {
            return .scrollingTimeline
        }
        if abs(deltaStart - deltaEnd) < epsilon {
            return .scrollingTimeline
        }
        if abs(deltaStart) >= abs(deltaEnd) {
            return .draggingTrimStart
        }
        return .draggingTrimEnd
    }
    
    private func updateTrimHudForLiveScrubbing(_ seekTime: CMTime, range: CMTimeRange) {
        isLiveScrubbing = true
        
        let timeString = formatTime(seekTime)
        let durationString = formatTime(range.duration)
        
        trimHud.text = "🎯 \(timeString) | Duration: \(durationString)"
        trimHud.backgroundColor = UIColor.systemOrange.withAlphaComponent(0.95)
        
        if trimHud.isHidden {
            trimHud.alpha = 0
            trimHud.isHidden = false
            UIView.animate(withDuration: 0.15) { self.trimHud.alpha = 1 }
        }
    }
    
    @MainActor
    private func handleTrimmerPositionStopped(_ playerTime: CMTime) {
        print("🎯 CLEAN DELEGATE: positionBarStoppedMoving fired")
        if STS_EDITORCORE_SSOT_ENABLED {
            if let trimmerView = trimmerView,
               let startTime = trimmerView.startTime,
               let endTime = trimmerView.endTime {
                editorCore?.updateTrimRange(start: startTime, end: endTime, isFinal: true)
            }
            switch lastInteractionMode {
            case .scrollingTimeline:
                editorCore?.endInteraction(finalPlayhead: playerTime)
            case .draggingTrimStart, .draggingTrimEnd:
                editorCore?.endInteraction(finalPlayhead: nil)
            default:
                break
            }
            lastInteractionMode = .idle
            updateTimecodeDisplays()
            return
        }

        if isLiveScrubbing {
            isLiveScrubbing = false
            handleSeekTimer?.invalidate()
            
            if let trimmerView = self.trimmerView,
               let startTime = trimmerView.startTime,
               let endTime = trimmerView.endTime {
                let duration = CMTimeSubtract(endTime, startTime)
                trimHud.text = "Duration: \(formatTime(duration))"
                trimHud.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.92)
            }
            
            print("✅ LIVE SCRUBBING: Stopped - HUD reset to normal state")
        }
        
        updateTimecodeDisplays()
    }
    
    nonisolated func positionBarStoppedMoving(_ playerTime: CMTime) {
        Task { @MainActor [weak self] in
            self?.handleTrimmerPositionStopped(playerTime)
        }
    }
    
    // MARK: - Playback Monitoring

    @MainActor
    func resolveActivePlayer(_ reason: String) -> AVPlayer? {
        if let enterprisePlayer = enterpriseEditorContext?.player {
            if player !== enterprisePlayer {
#if DEBUG
                if !hasLoggedPlayerMismatch {
                    hasLoggedPlayerMismatch = true
                    print("🚨 Editor has multiple AVPlayers; playhead may desync. reason=\(reason)")
                    let stack = Thread.callStackSymbols.joined(separator: "\n")
                    print("🧵 ActivePlayer mismatch stack:\n\(stack)")
                }
#endif
                setActivePlayer(enterprisePlayer, reason: reason)
            }
            return enterprisePlayer
        }
        return player
    }

    @MainActor
    func setActivePlayer(_ newPlayer: AVPlayer, reason: String) {
        let wasDifferent = player !== newPlayer
        player = newPlayer
        if playerLayer?.player !== newPlayer {
            playerLayer?.player = newPlayer
        }
        installIdleTimerObservation(on: newPlayer)
        if STS_SEEKSCHEDULER_ENABLED {
            if let existingScheduler = seekScheduler {
                existingScheduler.updatePlayer(newPlayer)
            } else {
                seekScheduler = SeekScheduler(player: newPlayer)
            }
        }
#if DEBUG
        if wasDifferent {
            let playerID = ObjectIdentifier(newPlayer)
            let itemID = newPlayer.currentItem.map { ObjectIdentifier($0) }
            print("🎯 ActivePlayer set: player=\(playerID) item=\(String(describing: itemID)) reason=\(reason)")
        }
#endif
    }

#if DEBUG
    private func logPlaybackState(_ label: String, player: AVPlayer?) {
        guard let player else {
            print("🎬 \(label): player=nil observerOwner=\(String(describing: timeObserverOwner)) observer=\(timeObserver != nil)")
            return
        }
        let playerID = ObjectIdentifier(player)
        let itemID = player.currentItem.map { ObjectIdentifier($0) }
        let ownerID = timeObserverOwner.map { ObjectIdentifier($0) }
        let timeSeconds = player.currentTime().seconds
        print(String(
            format: "🎬 %@: player=%@ item=%@ owner=%@ rate=%.3f status=%d time=%.3f observer=%@",
            label,
            String(describing: playerID),
            String(describing: itemID),
            String(describing: ownerID),
            player.rate,
            player.timeControlStatus.rawValue,
            timeSeconds,
            (timeObserver != nil).description
        ))
    }
#endif
    
    /// Ensure observer is attached to the current player. Safe and idempotent.
    func ensurePeriodicTimeObserverInstalled() {
        guard let player = resolveActivePlayer("ensurePeriodicTimeObserverInstalled") else {
            print("⏱️ ensurePeriodicTimeObserverInstalled: No player found")
            return
        }
        
        if let existingOwner = timeObserverOwner,
           existingOwner === player,
           timeObserver != nil {
            return
        }
        
        installPeriodicTimeObserver(on: player)
    }
    
    /// Install a new periodic time observer on the given player.
    private func installPeriodicTimeObserver(on player: AVPlayer) {
        print("⏱️ Installing periodic observer on player:", Unmanaged.passUnretained(player).toOpaque())
#if DEBUG
        logPlaybackState("Install observer", player: player)
#endif
        
        removePeriodicTimeObserverIfNeeded()
        
        let interval = CMTime(seconds: 0.1, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        let observedPlayer = player
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            Task { @MainActor in
                guard let self else { return }
                if let activePlayer = self.resolveActivePlayer("periodicTick"),
                   activePlayer !== observedPlayer {
#if DEBUG
                    let observedID = ObjectIdentifier(observedPlayer)
                    let activeID = ObjectIdentifier(activePlayer)
                    print("⚠️ Playhead tick from non-active player observed=\(observedID) active=\(activeID)")
#endif
                    return
                }
                self.handlePeriodicTimeUpdate(time)
            }
        }
        
        timeObserverOwner = player
#if DEBUG
        let playerID = ObjectIdentifier(player)
        let itemID = player.currentItem.map { ObjectIdentifier($0) }
        print("⏱️ Observer installed on ActivePlayer: player=\(playerID) item=\(String(describing: itemID))")
#endif
    }
    
    private func removePeriodicTimeObserverIfNeeded() {
        if let observer = timeObserver, let owner = timeObserverOwner {
            owner.removeTimeObserver(observer)
            timeObserver = nil
            timeObserverOwner = nil
            print("⏱️ TIME OBSERVER: Removed safely from owning player")
        }
    }
    
    @MainActor
    private func handlePeriodicTimeUpdate(_ time: CMTime) {
        #if DEBUG
        print("[Playhead] tick", time.seconds)
        #endif
        currentTimeLabel?.text = formatTime(time)

        let activePlayer = resolveActivePlayer("handlePeriodicTimeUpdate")
        let playerRate = activePlayer?.rate ?? 0
        let timeControlStatus = activePlayer?.timeControlStatus
        let isPlaying = playerRate > 0.01
            || timeControlStatus == .playing
            || timeControlStatus == .waitingToPlayAtSpecifiedRate

#if DEBUG
        let seconds = time.seconds
        if seconds == 0 || seconds - lastPlayheadDebugLogSeconds >= 1.0 {
            lastPlayheadDebugLogSeconds = seconds
            logPlaybackState("Tick from ActivePlayer", player: activePlayer)
        }
#endif
        var playheadTimeForUI: CMTime?
        if STS_EDITORCORE_SSOT_ENABLED {
            if let core = editorCore {
                core.setPlaying(isPlaying)
                playheadTimeForUI = core.ingestPlayerTime(time)
            } else if isPlaying {
                playheadTimeForUI = time
            }
        } else if isPlaying {
            playheadTimeForUI = time
        }

        if let playheadTimeForUI {
            syncPlayheadUI(to: playheadTimeForUI)
        }

        updateTimecodeDisplays()

        if let context = enterpriseEditorContext {
            context.updatePlaybackStateFromPlayer()
        }
    }

    @MainActor
    private func syncPlayheadUI(to time: CMTime) {
        if let simpleTrimmer = trimmerView,
           shouldSyncTrimmer(for: time) {
            simpleTrimmer.updatePlayheadUI(to: time)
            lastTrimmerSyncTime = time
            #if DEBUG
            print("[Playhead] trimmer UI updated", time.seconds)
            #endif
        }

        if let context = enterpriseEditorContext {
            context.updatePlayhead(with: time)
            #if DEBUG
            print("[Playhead] waveform updated", time.seconds)
            #endif
        }
    }

    private func shouldSyncTrimmer(for time: CMTime) -> Bool {
        guard STS_EDITORCORE_SSOT_ENABLED else { return true }
        if let interaction = editorCore?.interaction, interaction != .idle {
            return false
        }
        guard let last = lastTrimmerSyncTime else { return true }
        return abs(time.seconds - last.seconds) >= playheadSyncThreshold
    }
    
    /// Keep the periodic time observer attached in case it was lost after edits.
    private func startTimeObserverHeartbeat() {
        timeObserverHeartbeat?.invalidate()
        timeObserverHeartbeat = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.ensurePeriodicTimeObserverInstalled()
            }
        }
    }
    
    @objc private func itemDidFinishPlaying(_ notification: Notification) {
        print("🎬 PLAYBACK: Video finished playing")
        
        // 🎬 ONLY control the player - let native trimmer sync itself
        resolveActivePlayer("itemDidFinishPlaying")?.pause()
        requestSeek(.zero, policy: .settle, completion: nil)
        editorCore?.setPlaying(false)
        
        // 🚫 REMOVED: Manual trimmer sync - let native handle this
        // Old code: trimmerView.seek(to: .zero)
        
        // IMPORTANT: Update button when video finishes
        updatePlayPauseButton()
        updateTimecodeDisplays()
        if let context = enterpriseEditorContext {
            context.updatePlaybackStateFromPlayer()
            context.setPlayhead(to: context.trimRange.lowerBound)
        }
        
        print("✅ NATIVE SYNC: Player reset to beginning - native trimmer will sync automatically")
    }
    
    // MARK: - Toolbar Setup
    
    internal func updateToolbarForPendingTrim(_ showApplyCancel: Bool) {
        print("🔄 DEBUG updateToolbarForPendingTrim: showApplyCancel=\(showApplyCancel)")
        
        guard let toolbar = toolbar else {
            print("🚨 CRITICAL ERROR: Toolbar should exist by now!")
            return
        }
        
        if showApplyCancel {
            guard let applyButton = applyTrimButton,
                  let cancelButton = cancelTrimButton else {
                print("🚨 CRITICAL ERROR: Apply/Cancel buttons not initialized!")
                return
            }
            
            let flexibleSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
            let fixedSpace = UIBarButtonItem(barButtonSystemItem: .fixedSpace, target: nil, action: nil)
            fixedSpace.width = 20
            
            toolbar.items = [
                flexibleSpace,
                cancelButton,
                fixedSpace,
                applyButton,
                flexibleSpace
            ]
            toolbarMode = .pendingTrim
            view.bringSubviewToFront(toolbar)
            
            print("✅ TOOLBAR SUCCESS: Showing Apply/Cancel buttons for pending trim")
        } else {
            recreateDefaultToolbarItems()
            updatePlayPauseButton()
            toolbarMode = .normal
            view.bringSubviewToFront(toolbar)
            
            print("✅ TOOLBAR: Restored to normal mode")
        }
    }
    
    internal func recreateDefaultToolbarItems() {
        if STS_ENTERPRISE_EDITOR_ENABLED { return }
        guard let toolbar = toolbar else { return }
        
        print("🔧 TOOLBAR DEBUG: Recreating default toolbar items")
        
        let playPauseButton = UIBarButtonItem(
            image: UIImage(systemName: resolveActivePlayer("recreateDefaultToolbarItems")?.timeControlStatus == .playing ? "pause.circle.fill" : "play.circle.fill"),
            style: .plain,
            target: self,
            action: #selector(togglePlayback)
        )
        playPauseButton.tintColor = UIColor(red: 0.6, green: 0.2, blue: 0.8, alpha: 1.0)
        self.playPauseBarButton = playPauseButton
        
        print("🔧 TOOLBAR DEBUG: Created new playPauseButton: \(playPauseButton)")
        
        let jumpBackButton = UIBarButtonItem(
            image: UIImage(systemName: "gobackward.5"),
            style: .plain,
            target: self,
            action: #selector(jumpBack5Seconds)
        )
        jumpBackButton.tintColor = UIColor(red: 0.8, green: 0.3, blue: 0.7, alpha: 0.8)
        
        let jumpForwardButton = UIBarButtonItem(
            image: UIImage(systemName: "goforward.5"),
            style: .plain,
            target: self,
            action: #selector(jumpForward5Seconds)
        )
        jumpForwardButton.tintColor = UIColor(red: 0.8, green: 0.3, blue: 0.7, alpha: 0.8)
        
        let cropButton = UIBarButtonItem(
            image: UIImage(systemName: "crop"),
            style: .plain,
            target: self,
            action: #selector(cropButtonTapped)
        )
        cropButton.tintColor = UIColor(red: 0.6, green: 0.2, blue: 0.8, alpha: 1.0) // Match theme color
        
        let clearButton = UIBarButtonItem(
            title: editStack.hasOperations ? "Clear All" : "No Edits",
            style: .plain,
            target: self,
            action: editStack.hasOperations ? #selector(clearAllEdits) : nil
        )
        clearButton.tintColor = editStack.hasOperations ? UIColor.systemRed : UIColor.darkGray
        clearButton.isEnabled = editStack.hasOperations
        
        let flexibleSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let smallSpace = UIBarButtonItem(barButtonSystemItem: .fixedSpace, target: nil, action: nil)
        smallSpace.width = 16
        
        toolbar.items = [
            playPauseButton,
            smallSpace,
            jumpBackButton,
            jumpForwardButton,
            flexibleSpace,
            cropButton,
            flexibleSpace,
            clearButton
        ]
    }
    
    internal func updatePlayPauseButton() {
        // Only update play/pause when in normal mode
        guard toolbarMode == .normal else {
            print("❌ BUTTON DEBUG: Not in normal mode, toolbarMode=\(toolbarMode)")
            return
        }
        guard let playPauseButton = self.playPauseBarButton else {
            print("❌ BUTTON DEBUG: playPauseBarButton is nil!")
            return
        }
        
        // FIX: Handle both playing AND waitingToPlayAtSpecifiedRate as "playing"
        let timeControlStatus = resolveActivePlayer("updatePlayPauseButton")?.timeControlStatus ?? .paused
        let isPlaying = timeControlStatus == .playing || timeControlStatus == .waitingToPlayAtSpecifiedRate
        let iconName = isPlaying ? "pause.circle.fill" : "play.circle.fill"
        
        print("🔄 BUTTON DEBUG: status=\(timeControlStatus.rawValue), isPlaying=\(isPlaying), icon=\(iconName)")
        
        playPauseButton.image = UIImage(systemName: iconName)
        playPauseButton.tintColor = UIColor(red: 0.6, green: 0.2, blue: 0.8, alpha: 1.0)
        
        print("✅ BUTTON DEBUG: Button updated successfully")
    }
    
    internal func refreshToolbarButtons() {
        if STS_ENTERPRISE_EDITOR_ENABLED { return }
        guard let toolbar = self.toolbar, let items = toolbar.items, let last = items.last else { return }
        last.title = editStack.hasOperations ? "Clear All" : "No Edits"
        last.isEnabled = editStack.hasOperations
        last.tintColor = editStack.hasOperations ? UIColor.systemRed : UIColor.darkGray
    }
    
    // MARK: - CROP FUNCTIONALITY (IMPLEMENTED)
    
    @objc internal func cropButtonTapped() {
        print("✂️ CROP: Starting crop functionality with asset classification")
        
        guard let player = resolveActivePlayer("cropButtonTapped") else {
            print("❌ CROP: No player available")
            showAlert(title: "Crop Error", message: "Video player not available for cropping")
            return
        }
        
        // BREAKTHROUGH FIX: Use modular editor if enabled, otherwise use legacy system
        if STS_MODULAR_EDITOR_ENABLED, let coordinator = self.coordinator {
            print("🧠 CROP: Using modular editor with proper asset classification")
            
            // Get current time for frame extraction
            let currentTime = player.currentTime()
            
            // Use coordinator to handle crop with proper asset type detection
            coordinator.handle(.openCrop(frame: UIImage(), time: currentTime))
            return
        }
        
        // LEGACY SYSTEM: Extract frame and use photo crop (will be deprecated)
        print("⚠️ CROP: Using legacy photo crop system")
        
        let currentTime = player.currentTime()
        
        // Extract video frame at current time
        extractVideoFrame(at: currentTime) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let image):
                    self?.presentCropViewController(with: image, at: currentTime)
                case .failure(let error):
                    print("❌ CROP: Failed to extract video frame: \(error)")
                    self?.showAlert(title: "Crop Error", message: "Failed to extract video frame for cropping")
                }
            }
        }
    }
    
    // MARK: - Video Frame Extraction
    
    private func extractVideoFrame(at time: CMTime, completion: @escaping (Result<UIImage, Error>) -> Void) {
        print("🎬 CROP: Extracting video frame at \(time.seconds)s")
        
        Task {
            // Use the current composition if available, otherwise use original asset
            let asset: AVAsset
            let result = await editStack.getPreviewComposition()
            if let composition = result.composition {
                asset = composition
            } else {
                asset = originalAsset
            }
            
            let imageGenerator = AVAssetImageGenerator(asset: asset)
            imageGenerator.appliesPreferredTrackTransform = true
            imageGenerator.requestedTimeToleranceBefore = .zero
            imageGenerator.requestedTimeToleranceAfter = .zero
            
            // Set maximum size to maintain quality while keeping reasonable memory usage
            imageGenerator.maximumSize = CGSize(width: 1920, height: 1920)
            
            do {
                let cgImage = try await imageGenerator.image(at: time).image
                let uiImage = UIImage(cgImage: cgImage)
                completion(.success(uiImage))
                print("✅ CROP: Successfully extracted video frame")
            } catch {
                print("❌ CROP: Frame extraction failed: \(error)")
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - Crop View Controller
    
    private func presentCropViewController(with image: UIImage, at time: CMTime) {
        print("✂️ CROP: Presenting crop view controller")
        
        let cropViewController = TOCropViewController(image: image)
        cropViewController.delegate = self
        
        // Configure crop controller
        cropViewController.modalPresentationStyle = .fullScreen
        cropViewController.aspectRatioPreset = .presetOriginal
        cropViewController.aspectRatioLockEnabled = false
        cropViewController.resetAspectRatioEnabled = true
        cropViewController.rotateButtonsHidden = false
        cropViewController.rotateClockwiseButtonHidden = false
        cropViewController.aspectRatioPickerButtonHidden = false
        
        // Store the time when this crop was initiated for later use
        cropViewController.view.accessibilityLabel = "crop_time_\(time.seconds)"
        currentCropSourceImageSize = image.size
        
        // Pause playback during cropping
        resolveActivePlayer("presentCropViewController")?.pause()
        updatePlayPauseButton()
        
        present(cropViewController, animated: true) {
            print("✅ CROP: Crop view controller presented")
        }
    }
    

    // MARK: - SmartFill Notification Setup
    
    private func setupSmartFillNotifications() {
        print("🔔 SMARTFILL NOTIFICATIONS: Setting up completion observers")
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSmartFillCompletionNotification(_:)),
            name: Notification.Name("STSSmartFillCompleted"),
            object: nil
        )
        
        print("✅ SMARTFILL NOTIFICATIONS: Observer registered for completion")
    }
    // MARK: - Required Selectors / Actions
    
    @objc internal func clearAllEdits() {
        print("🧹 Clearing all edits.")
        editStack.clearAll()
        
        if !STS_ENTERPRISE_EDITOR_ENABLED {
            recreateDefaultToolbarItems()
            updateNavigationBarForEditStack()
            updateTimecodeDisplays()
            refreshToolbarButtons()
        }
    }
    
    @objc internal func applyPendingTrim() {
        let range: CMTimeRange
        if let pending = pendingTrimRange {
            range = pending
        } else if let start = self.trimmerView.startTime, let end = self.trimmerView.endTime {
            range = CMTimeRange(start: start, duration: CMTimeSubtract(end, start))
        } else {
            print("⚠️ APPLY TRIM: No pending trim changes to apply")
            return
        }
        
        print("✅ APPLYING TRIM: \(formatTime(range.start)) - \(formatTime(CMTimeAdd(range.start, range.duration)))")
        
        // Persist trim into the non-destructive stack
        editStack.replaceTrim(with: range)
        editStack.regeneratePreview()
        if STS_EDITORCORE_SSOT_ENABLED {
            editorCore?.setTrimRange(range, clampPlayhead: true)
        }
        
        // Clear pending state
        hasPendingTrimChanges = false
        pendingTrimStartTime = nil
        pendingTrimEndTime = nil
        pendingTrimRange = nil
        
        // Hide HUD
        if !trimHud.isHidden {
            UIView.animate(withDuration: 0.15, animations: { self.trimHud.alpha = 0 }) { _ in
                self.trimHud.isHidden = true
                self.trimHud.alpha = 1
            }
        }
        
        // Back to default controls
        updateToolbarForPendingTrim(false)
        toolbarMode = .normal
        
        // Light feedback
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
    
    @objc internal func cancelPendingTrim() {
        guard hasPendingTrimChanges else {
            print("⚠️ CANCEL TRIM: No pending trim changes to cancel")
            return
        }
        print("❌ CANCELING TRIM: Reverting pending changes")
        hasPendingTrimChanges = false
        pendingTrimStartTime = nil
        pendingTrimEndTime = nil
        pendingTrimRange = nil
        if STS_EDITORCORE_SSOT_ENABLED, let core = editorCore {
            let restoredRange = editStack.currentTrimRange ?? CMTimeRange(start: .zero, duration: core.duration)
            core.setTrimRange(restoredRange, clampPlayhead: true)
        }
        if !trimHud.isHidden {
            UIView.animate(withDuration: 0.15, animations: { self.trimHud.alpha = 0 }) { _ in
                self.trimHud.isHidden = true
                self.trimHud.alpha = 1
            }
        }
        updateToolbarForPendingTrim(false)
        toolbarMode = .normal
        updateTimecodeDisplays()
    }
    
    @objc internal func cancelEdits() {
        dismissEditor(reason: .cancelled)
    }

    @MainActor
    internal func dismissEditor(reason: EnterpriseEditorCloseReason) {
        switch reason {
        case .saved:
            print("✅ EDITOR: Saved and dismissed")
        case .discarded:
            print("⚠️ EDITOR: Discarded edits and dismissed")
        case .cancelled:
            print("❌ EDITOR: Cancelled edits and dismissed")
        }
        resolveActivePlayer("dismissEditor")?.pause()
        removePeriodicTimeObserverIfNeeded()
        if let observedItem = observedPlayerItem {
            observedItem.removeObserver(self, forKeyPath: "status")
            observedPlayerItem = nil
        }
        if let navigationController = navigationController {
            navigationController.dismiss(animated: true) { [weak self] in
                self?.onCancel?()
            }
        } else {
            onCancel?()
        }
    }
    
    @objc internal func togglePlayback() {
        if let context = enterpriseEditorContext {
            print("🎮 PLAY pressed")
            ensurePeriodicTimeObserverInstalled()
            context.performTogglePlayback()
            enterpriseEditorContext?.updatePlaybackStateFromPlayer()
#if DEBUG
            logPlaybackState("Enterprise toggle", player: resolveActivePlayer("enterpriseToggle"))
            Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: 100_000_000)
                self?.logPlaybackState("Enterprise toggle (post)", player: self?.resolveActivePlayer("enterpriseTogglePost"))
            }
#endif
            return
        }

        guard let player = resolveActivePlayer("togglePlayback") else { return }
        ensurePeriodicTimeObserverInstalled()
        
        print("🎮 PLAY pressed")
        print("🎬 TOGGLE DEBUG: Current status before toggle: \(player.timeControlStatus.rawValue)")
#if DEBUG
        logPlaybackState("Play pressed (pre)", player: player)
#endif
        
        if player.timeControlStatus == .playing {
            player.pause()
            editorCore?.setPlaying(false)
            print("⏸️ TOGGLE DEBUG: Called pause(), new status: \(player.timeControlStatus.rawValue)")
        } else {
            // SMART RESTART: If we're at the very end, restart from beginning
            let currentTime = player.currentTime()
            let duration = player.currentItem?.duration ?? .zero
            
            // Check if we're within 0.1 seconds of the end (to account for floating point precision)
            let isAtEnd = abs(currentTime.seconds - duration.seconds) < 0.1
            
            if isAtEnd && duration.seconds > 0 {
                print("🔄 TOGGLE DEBUG: Smart restart - seeking to zero then playing")
                
                // Restart from beginning with proper button updates
                requestSeek(.zero, policy: .settle) { [weak self] in
                    // 🚫 REMOVED: Manual trimmer sync - let native handle this
                    // Old code: self?.trimmerView.seek(to: .zero)
                    
                    self?.resolveActivePlayer("togglePlaybackRestart")?.play()
                    self?.editorCore?.setPlaying(true)
                    print("▶️ TOGGLE DEBUG: Restarted play - native trimmer will sync")
                    self?.updateTimecodeDisplays()
                    
                    // Update button after play starts
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        self?.updatePlayPauseButton()
                    }
                }
            } else {
                // Normal play from current position
                print("▶️ TOGGLE DEBUG: Normal play from \(currentTime.seconds)s")
                player.play()
                editorCore?.setPlaying(true)
                print("▶️ TOGGLE DEBUG: Called play(), new status: \(player.timeControlStatus.rawValue)")
            }
        }
        
        // Update button immediately for immediate visual feedback
        print("🔄 TOGGLE DEBUG: Calling updatePlayPauseButton immediately")
        updatePlayPauseButton()
        enterpriseEditorContext?.updatePlaybackStateFromPlayer()

#if DEBUG
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 100_000_000)
            self?.logPlaybackState("Play pressed (post)", player: self?.resolveActivePlayer("playPressedPost"))
        }
#endif
    }
    
    @MainActor
    @objc internal func jumpForward5Seconds() {
        guard let player = resolveActivePlayer("jumpForward5Seconds") else { return }
        let current = player.currentTime()
        let newTime = CMTimeAdd(current, CMTime(seconds: 5, preferredTimescale: 600))
        let maxTime = player.currentItem?.duration ?? .positiveInfinity
        let jumpTo = CMTimeMinimum(newTime, maxTime)
        
        seekPlayer(to: jumpTo, logMessage: jumpLogMessage(direction: "forward", targetTime: jumpTo))
    }
    
    @MainActor
    @objc internal func jumpBack5Seconds() {
        guard let player = resolveActivePlayer("jumpBack5Seconds") else { return }
        let current = player.currentTime()
        let newTime = CMTimeSubtract(current, CMTime(seconds: 5, preferredTimescale: 600))
        let jumpTo = CMTimeMaximum(newTime, .zero)
        
        seekPlayer(to: jumpTo, logMessage: jumpLogMessage(direction: "back", targetTime: jumpTo))
    }

    @MainActor
    private func seekPlayer(to targetTime: CMTime, logMessage: String) {
        requestSeek(targetTime, policy: .settle, completion: nil)
        editorCore?.updatePlayheadFromPlayer(targetTime)
        syncPlayheadUI(to: targetTime)
        updateTimecodeDisplays()
        print(logMessage)
    }

    private func jumpLogMessage(direction: String, targetTime: CMTime) -> String {
        let seconds = String(format: "%.2f", targetTime.seconds)
        return "🎬 JUMP: Jumped \(direction) 5 seconds (target: \(seconds)s) - native trimmer will sync"
    }
    
    @MainActor
    func finalizeEnterpriseSurfaceVisibility(excluding hostView: UIView) {
        guard STS_ENTERPRISE_EDITOR_ENABLED else { return }
        
        if !hasRemovedLegacySubviewsForEnterprise {
            for subview in view.subviews where subview !== hostView {
                subview.removeFromSuperview()
            }
            playerLayer?.removeFromSuperlayer()
            playerLayer = nil
            hasRemovedLegacySubviewsForEnterprise = true
        }
        
        if view.alpha == 0 {
            UIView.animate(withDuration: 0.2) {
                self.view.alpha = 1.0
            }
        }
    }
    
    @objc private func handleSmartFillCompletionNotification(_ notification: Notification) {
        print("🎉 SMARTFILL COMPLETION: Received completion notification!")
        
        guard let userInfo = notification.userInfo else {
            print("❌ SMARTFILL COMPLETION: Missing userInfo payload")
            return
        }
        
        let smartFillTakeID: UUID? = {
            if let id = userInfo["smartFillTakeID"] as? UUID {
                return id
            } else if let idString = userInfo["smartFillTakeID"] as? String {
                return UUID(uuidString: idString)
            }
            return nil
        }()
        
        let sessionID: UUID? = {
            if let id = userInfo["sessionID"] as? UUID {
                return id
            } else if let idString = userInfo["sessionID"] as? String {
                return UUID(uuidString: idString)
            }
            return nil
        }()
        
        let projectID: UUID? = {
            if let id = userInfo["projectID"] as? UUID {
                return id
            } else if let idString = userInfo["projectID"] as? String {
                return UUID(uuidString: idString)
            }
            return nil
        }()
        
        let smartFillPath = userInfo["smartFillPath"] as? String
        let fallbackURL = smartFillPath.map { URL(fileURLWithPath: $0) }
        
        guard let smartFillTakeID else {
            print("❌ SMARTFILL COMPLETION: Missing smartFillTakeID - cannot adopt new take")
            return
        }
        
        print("✅ SMARTFILL COMPLETION: SmartFill completed for takeID: \(smartFillTakeID)")
        if let smartFillPath {
            print("   📁 SmartFill video: \(URL(fileURLWithPath: smartFillPath).lastPathComponent)")
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.adoptSmartFillTake(
                smartFillTakeID,
                sessionID: sessionID,
                projectID: projectID,
                fallbackOutputURL: fallbackURL
            )
        }
    }

    private func adoptSmartFillTake(
        _ smartFillTakeID: UUID,
        sessionID: UUID?,
        projectID: UUID?,
        fallbackOutputURL: URL?
    ) {
        if let lastHandledSmartFillTakeID, lastHandledSmartFillTakeID == smartFillTakeID {
            print("ℹ️ SMARTFILL ADOPTION: Take \(smartFillTakeID) already handled - skipping duplicate update")
            return
        }
        
        guard let repository = repository ?? SessionManager.shared.repositoryInstance else {
            print("❌ SMARTFILL ADOPTION: Repository unavailable - cannot adopt new SmartFill take")
            return
        }
        
        guard let resolvedProjectID = projectID ?? currentProject?.id else {
            print("❌ SMARTFILL ADOPTION: Missing projectID context")
            return
        }
        
        guard let resolvedSessionID = sessionID ?? currentSession?.id else {
            print("❌ SMARTFILL ADOPTION: Missing sessionID context")
            return
        }
        
        guard let updatedProject = repository.project(by: resolvedProjectID) else {
            print("❌ SMARTFILL ADOPTION: Could not locate project \(resolvedProjectID)")
            return
        }
        
        guard let updatedSession = updatedProject.sessions.first(where: { $0.id == resolvedSessionID }) else {
            print("❌ SMARTFILL ADOPTION: Could not locate session \(resolvedSessionID) in project \(resolvedProjectID)")
            return
        }
        
        guard let smartFillTake = updatedSession.takes.first(where: { $0.id == smartFillTakeID }) else {
            print("❌ SMARTFILL ADOPTION: Could not locate SmartFill take \(smartFillTakeID) in session \(resolvedSessionID)")
            return
        }
        
        // Instead of switching into the editor, just refresh the current context and UI; the TakeReview badge will reflect SmartFill availability.
        currentProject = updatedProject
        currentSession = updatedSession
        currentTake = smartFillTake
        editStack = EditStack(sourceAsset: AVURLAsset(url: VideoVariantResolver.originalURL(for: smartFillTake)))
        editStack.delegate = self
        print("✅ SMARTFILL ADOPTION: Staying on TakeReview; SmartFill now available for take \(smartFillTakeID)")
    }
    
    private func switchToSmartFillVideo(
        take: ProjectTake,
        project: Project,
        session: ProjectSession,
        assetURL: URL
    ) {
        // Legacy path retained for reference; SmartFill now keeps the user in TakeReview.
        print("ℹ️ SWITCH TO SMARTFILL: Skipped (we remain in TakeReview; badges indicate SmartFill).")
    }

    private func updatePlayerWithSmartFillAsset(_ asset: AVAsset) {
        print("🎬 UPDATING PLAYER: Switching to SmartFill landscape video")
        
        let activePlayer = resolveActivePlayer("updatePlayerWithSmartFillAsset")
        activePlayer?.pause()
        
        if let observedItem = observedPlayerItem {
            observedItem.removeObserver(self, forKeyPath: "status")
            observedPlayerItem = nil
        }
        
        removePeriodicTimeObserverIfNeeded()
        
        let newPlayerItem = AVPlayerItem(asset: asset)
        let targetPlayer = activePlayer ?? AVPlayer(playerItem: newPlayerItem)
        if activePlayer == nil {
            setActivePlayer(targetPlayer, reason: "updatePlayerWithSmartFillAsset")
        }
        let oldItemID = targetPlayer.currentItem.map { ObjectIdentifier($0) }
        targetPlayer.replaceCurrentItem(with: newPlayerItem)
        self.playerLayer?.player = targetPlayer
        self.playerLayer?.videoGravity = .resizeAspect
#if DEBUG
        let playerID = ObjectIdentifier(targetPlayer)
        let newItemID = ObjectIdentifier(newPlayerItem)
        print("🔁 ActivePlayer replaceCurrentItem: player=\(playerID) oldItem=\(String(describing: oldItemID)) newItem=\(newItemID)")
#endif
        
        newPlayerItem.addObserver(self, forKeyPath: "status", options: [.new], context: nil)
        observedPlayerItem = newPlayerItem
        
        installPeriodicTimeObserver(on: targetPlayer)
        updatePlayPauseButton()
        updateTimecodeDisplays()
        
        print("✅ PLAYER UPDATE: SmartFill landscape video loaded successfully")
    }
    
    @objc internal func undoLastEdit() {
        if editStack.canUndo {
            _ = editStack.undo()
            print("↩️ UNDO: Performed undo")
        }
    }
    
    @objc internal func redoLastEdit() {
        if editStack.canRedo {
            _ = editStack.redo()
            print("↪️ REDO: Performed redo")
        }
    }
    
    @objc internal func showOperationDetails(_ gesture: UITapGestureRecognizer) {
        print("ℹ️ Operation details tapped (stub).")
    }
    
    @objc internal func exportWithCurrentEdits() {
        print("📤 EXPORT: Starting export with current edits")
        
        // Check if we have edits to export
        guard editStack.hasOperations else {
            showAlert(title: "No Edits", message: "There are no edits to export. Make some changes first.")
            return
        }
        
        // Get current video path
        guard let currentVideoPath = currentVideoPath else {
            showAlert(title: "Export Error", message: "Unable to determine video file location.")
            return
        }
        
        // Use EditStack built-in export
        let originalURL = URL(fileURLWithPath: currentVideoPath)
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("(UUID().uuidString)_export.mov")
        
        // Show simple progress alert
        let alert = UIAlertController(title: "Exporting Video", message: "Please wait...", preferredStyle: .alert)
        present(alert, animated: true)
        
        // Use EditStack export
        editStack.exportToURL(tempURL, quality: AVAssetExportPresetHighestQuality) { progress in
            // Update on main thread
            DispatchQueue.main.async {
                alert.message = "Exporting... (Int(progress * 100))%"
            }
                } completion: { result in
            DispatchQueue.main.async {
                alert.dismiss(animated: true) {
                    switch result {
                    case .success(_):
                        // Replace original file with exported version
                        do {
                            let backupURL = originalURL.appendingPathExtension("backup")
                            if FileManager.default.fileExists(atPath: backupURL.path) {
                                try FileManager.default.removeItem(at: backupURL)
                            }
                            // CRITICAL FIX: Create _edited.mov instead of replacing original
                            let fileName = originalURL.deletingPathExtension().lastPathComponent
                            let editedFileName = "\(fileName)_edited.mov"
                            let editedURL = originalURL.deletingLastPathComponent().appendingPathComponent(editedFileName)
                            
                            // Move temp file to _edited.mov location
                            if FileManager.default.fileExists(atPath: editedURL.path) {
                                try FileManager.default.removeItem(at: editedURL)
                            }
                            try FileManager.default.moveItem(at: tempURL, to: editedURL)
                            // CRITICAL FIX: Update repository with edited file path
                            if let takeID = self.currentTake?.id,
                               let sessionID = self.currentSession?.id,
                               let projectID = self.currentProject?.id,
                               let repository = self.repository {
                                
                                let editMetadata = self.extractEditMetadata(from: self.editStack)
                                
                                repository.updateTakeWithEditedVersion(
                                    takeID: takeID,
                                    sessionID: sessionID,
                                    projectID: projectID,
                                    editedFilePath: editedURL.path,
                                    editMetadata: editMetadata
                                )
                                
                                // Send UI refresh notification
                                NotificationCenter.default.post(
                                    name: Notification.Name("STSExportCompleted"),
                                    object: nil,
                                    userInfo: [
                                        "sessionID": sessionID,
                                        "takeID": takeID,
                                        "editedFilePath": editedURL.path
                                    ]
                                )
                            }
                            
                            // Clear edit stack since changes are saved
                            self.editStack.clearAll()
                            self.updateNavigationBarForEditStack()
                            self.refreshToolbarButtons()
                            
                            // Show success
                            let successAlert = UIAlertController(title: "Export Complete", message: "Your edited video has been saved successfully. The original is preserved. Edited version saved as \(editedFileName).", preferredStyle: .alert)
                            successAlert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
                                UINotificationFeedbackGenerator().notificationOccurred(.success)
                            })
                            self.present(successAlert, animated: true)
                            
                        } catch {
                            self.showAlert(title: "Export Error", message: "Export completed but failed to save: \(error.localizedDescription)")
                        }
                    case .failure(let error):
                        self.showAlert(title: "Export Failed", message: "Export failed: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
    
    private func showAlert(title: String, message: String, completion: (() -> Void)? = nil) {
        DispatchQueue.main.async {
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
                completion?()
            })
            self.present(alert, animated: true)
        }
    }
    
    // MARK: - KVO for Player
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "status", let playerItem = object as? AVPlayerItem {
            switch playerItem.status {
            case .readyToPlay:
                print("✅ PLAYER: Ready to play")
                DispatchQueue.main.async {
                    self.updatePlayPauseButton()
                    self.updateTimecodeDisplays()
                }
            case .failed:
                print("❌ PLAYER: Failed to load - \(playerItem.error?.localizedDescription ?? "Unknown error")")
                DispatchQueue.main.async {
                    self.showAlert(title: "Video Error", message: "Failed to load video: \(playerItem.error?.localizedDescription ?? "Unknown error")")
                }
            case .unknown:
                print("⚠️ PLAYER: Unknown status")
            @unknown default:
                break
            }
        }
    }
    
    // CRITICAL FIX: Extract edit metadata from EditStack operations
    private func extractEditMetadata(from editStack: EditStack) -> TakeEditMetadata {
        var hasTrimming = false
        var trimStartTime: Double?
        var trimEndTime: Double?
        var hasCropping = false
        var cropRect: CGRect?
        var cropRotation: Double?
        
        // Extract trim and crop information from edit stack operations
        for operation in editStack.operations {
            switch operation {
            case let trimOp as TrimOperation:
                hasTrimming = true
                trimStartTime = trimOp.trimStartTime.seconds
                trimEndTime = trimOp.trimEndTime.seconds
            case let cropOp as CropOperation:
                hasCropping = true
                cropRect = cropOp.normalizedCropRect
                cropRotation = Double(cropOp.rotationAngleDegrees)
            default:
                print("⚠️ Unknown operation type in edit stack: \(type(of: operation))")
            }
        }
        
        let metadata = TakeEditMetadata(
            hasTrimming: hasTrimming,
            trimStartTime: trimStartTime,
            trimEndTime: trimEndTime,
            hasCropping: hasCropping || (cropRotation != nil && abs(cropRotation ?? 0) > 0.01),
            cropRect: cropRect,
            cropRotationDegrees: cropRotation
        )
        
        print("📝 EDIT METADATA: Extracted - \(metadata.editSummary)")
        return metadata
    }

    // MARK: - Trim HUD
    
    private func setupTrimHud() {
        print("🟢 TRIM HUD: Setting up")
        trimHud.font = UIFont.monospacedDigitSystemFont(ofSize: 16, weight: .semibold)
        trimHud.textColor = .white
        trimHud.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.92)
        trimHud.layer.cornerRadius = 10
        trimHud.clipsToBounds = true
        trimHud.textAlignment = .center
        trimHud.isHidden = true
        trimHud.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(trimHud)
    }
    
    @objc private func handleTrimmerTap(_ gesture: UITapGestureRecognizer) {
        return
    }
    
    // MARK: - TrimmerViewDelegate Methods
    
    private func handlePeriodicSeek(to time: CMTime) {
        requestSeek(time, policy: .settle, completion: nil)
    }
    
    private func applyPendingEditMetadataIfNeeded() {
        guard let metadata = pendingEditMetadata else { return }
        pendingEditMetadata = nil
        
        print("📝 RESTORE EDITS: Applying persisted metadata (trim: \(metadata.hasTrimming), crop: \(metadata.hasCropping))")
        
        Task { @MainActor in
            if metadata.hasTrimming,
               let trimStart = metadata.trimStartTime,
               let trimEnd = metadata.trimEndTime,
               trimEnd > trimStart {
                let startTime = CMTime(seconds: trimStart, preferredTimescale: 600)
                let duration = CMTime(seconds: trimEnd - trimStart, preferredTimescale: 600)
                let range = CMTimeRange(start: startTime, duration: duration)
                editStack.replaceTrim(with: range)
                trimmerView?.seek(to: startTime)
                if STS_EDITORCORE_SSOT_ENABLED {
                    editorCore?.setTrimRange(range, clampPlayhead: true)
                    editorCore?.setPlayhead(startTime, policy: .settle)
                }
                print("   ✂️ Restored trim range \(trimStart)s - \(trimEnd)s")
            }
            
            if metadata.hasCropping, let cropRect = metadata.cropRect {
                let cropOperation = CropOperation(normalizedCropRect: cropRect)
                editStack.apply(operation: cropOperation)
                print("   🔲 Restored crop rect \(cropRect)")
            }
            
            updateNavigationBarForEditStack()
            refreshToolbarButtons()
            updateEditHistoryView()
        }
    }

    // MARK: - Gesture Handling

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        let location = touch.location(in: view)
        if gestureRecognizer == playbackTapGesture {
            if let trimmerView = trimmerView, trimmerView.frame.contains(location) {
                return false
            }
            if let toolbar = toolbar, toolbar.frame.contains(location) {
                return false
            }
        }

        if gestureRecognizer == playheadTapGesture || gestureRecognizer == playheadPanGesture {
            guard STS_EDITORCORE_SSOT_ENABLED, let trimmerView = trimmerView else { return false }
            let locationInTrimmer = touch.location(in: trimmerView)
            if isLocationNearTrimHandles(locationInTrimmer, trimmerView: trimmerView) {
                return false
            }
        }
        return true
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer == playheadPanGesture || otherGestureRecognizer == playheadPanGesture {
            return false
        }
        return true
    }

    private func isLocationNearTrimHandles(_ location: CGPoint, trimmerView: SimpleTrimmerView) -> Bool {
        guard let handles = trimmerView.handlePositions() else { return false }
        let threshold: CGFloat = 24
        return abs(location.x - handles.startX) <= threshold || abs(location.x - handles.endX) <= threshold
    }
}

// MARK: - SmartFillProcessingDelegate
extension LightweightEditorViewController {
    func smartFillDidFinish(takeID: UUID, outputURL: URL) {
        print("✅ SmartFill delegate: completed for take: \(takeID), url: \(outputURL)")
        
        adoptSmartFillTake(
            takeID,
            sessionID: currentSession?.id,
            projectID: currentProject?.id,
            fallbackOutputURL: outputURL
        )
    }
    
    func smartFillDidFail(takeID: UUID, error: Error) {
        print("❌ SmartFill failed for take: \(takeID) - \(error)")
        showAlert(
            title: "SmartFill Failed",
            message: "We couldn't complete SmartFill for this take. Error: \(error.localizedDescription)"
        )
    }

    func revertSmartFillToPortrait() {
        guard let take = currentTake,
              let sessionID = currentSession?.id,
              let projectID = currentProject?.id else {
            print("❌ SMARTFILL REVERT: Missing context")
            return
        }
        guard let repo = repository ?? SessionManager.shared.repositoryInstance else {
            print("❌ SMARTFILL REVERT: Repository unavailable")
            return
        }
        
        repo.clearSmartFill(takeID: take.id, sessionID: sessionID, projectID: projectID)
        
        if let refreshedProject = repo.project(by: projectID),
           let refreshedSession = refreshedProject.sessions.first(where: { $0.id == sessionID }),
           let refreshedTake = refreshedSession.takes.first(where: { $0.id == take.id }) {
            currentProject = refreshedProject
            currentSession = refreshedSession
            currentTake = refreshedTake
            isShowingSmartFillVideo = false
            lastHandledSmartFillTakeID = nil
            
            // Reload the original portrait asset into the player/edit stack
            let originalURL = VideoVariantResolver.originalURL(for: refreshedTake)
            let originalAsset = AVURLAsset(url: originalURL)
            self.originalAsset = originalAsset
            self.originalVideoOrientation = refreshedTake.capturedOrientation ?? .portrait
            self.originalVideoPath = originalURL.path
            self.currentVideoPath = originalURL.path
            self.pendingEditMetadata = refreshedTake.editMetadata
            
            editStack = EditStack(sourceAsset: originalAsset)
            editStack.delegate = self
            if let player = resolveActivePlayer("revertSmartFillToPortrait") {
                let newItem = AVPlayerItem(asset: originalAsset)
                let oldItemID = player.currentItem.map { ObjectIdentifier($0) }
                player.replaceCurrentItem(with: newItem)
#if DEBUG
                let playerID = ObjectIdentifier(player)
                let newItemID = ObjectIdentifier(newItem)
                print("🔁 ActivePlayer replaceCurrentItem: player=\(playerID) oldItem=\(String(describing: oldItemID)) newItem=\(newItemID)")
#endif
            }
            trimmerView?.asset = originalAsset
            
            updateNavigationBarForEditStack()
            updateTimecodeDisplays()
            enterpriseEditorContext?.hasSmartFillAvailable = false
            
            print("✅ SMARTFILL REVERT: Reverted to portrait for take \(take.id)")
            
            // Exit back to TakeReview since portrait flows require SmartFill before editing
            if let onCancel = onCancel {
                onCancel()
            } else {
                dismiss(animated: true)
            }
        } else {
            print("⚠️ SMARTFILL REVERT: Unable to refresh take after clearing SmartFill")
        }
    }
}

// MARK: - Orientation Diagnostics
extension LightweightEditorViewController {
    private func startOrientationDiagnostics(for url: URL, context: String) {
        let mode = isShowingSmartFillVideo ? "smartfill" : "original"
        let run = OrientationPolicy.createRun(context: context, smartfillMode: mode)
        orientationDiagnosticsRun = run
        OrientationDiag.logRunStart(run)

        Task {
            let asset = AVURLAsset(url: url)
            let info = await OrientationAssetInfo(asset: asset, url: url)
            OrientationDiag.logAsset(run, info)

            let uiShouldTransform = OrientationPolicy.shared.uiShouldApplyTransform(for: info)
            let stage = uiShouldTransform ? "UIPlayer" : "Compositor"
            let notes = "preferredTransform=\(info.preferredTransform)"
            OrientationDiag.logTransform(
                run,
                stage: stage,
                desc: uiShouldTransform ? "UI should apply transform" : "UI should not transform",
                notes: notes
            )

            let expected = OrientationPolicy.shared.expectedTransformStage(for: info)
            OrientationPolicy.shared.validateSingleTransformRule(run: run, expectedStage: expected)
        }
    }
}

// MARK: - TOCropViewControllerDelegate Methods
extension LightweightEditorViewController {
    @MainActor
    private func handleCropCompletion(
        _ cropViewController: TOCropViewController,
        image: UIImage,
        cropRect: CGRect,
        angle: Int
    ) {
        print("🚨 ENTERED TOCropViewControllerDelegate didCropToImage!")

        let timeString = cropViewController.view.accessibilityLabel?.replacingOccurrences(of: "crop_time_", with: "") ?? "0"
        let cropTime = CMTime(seconds: Double(timeString) ?? 0, preferredTimescale: 600)
        let sourceImageSize = currentCropSourceImageSize ?? cropViewController.image.size

        guard sourceImageSize.width > 0, sourceImageSize.height > 0 else {
            print("❌ CROP: Invalid source image size, aborting crop normalization")
            cropViewController.dismiss(animated: true) { [weak self] in
                self?.currentCropSourceImageSize = nil
                self?.updatePlayPauseButton()
            }
            return
        }

        var normalizedCropRect = CGRect(
            x: cropRect.origin.x / sourceImageSize.width,
            y: cropRect.origin.y / sourceImageSize.height,
            width: cropRect.size.width / sourceImageSize.width,
            height: cropRect.size.height / sourceImageSize.height
        )

        normalizedCropRect.origin.x = max(0.0, min(1.0, normalizedCropRect.origin.x))
        normalizedCropRect.origin.y = max(0.0, min(1.0, normalizedCropRect.origin.y))
        normalizedCropRect.size.width = max(0.0, min(1.0 - normalizedCropRect.origin.x, normalizedCropRect.size.width))
        normalizedCropRect.size.height = max(0.0, min(1.0 - normalizedCropRect.origin.y, normalizedCropRect.size.height))

        print("📐 CROP: Normalized crop rect: \(normalizedCropRect)")

        let cropOperation = CropOperation(normalizedCropRect: normalizedCropRect)
        editStack.apply(operation: cropOperation)

        print("🎯 CROP DEBUG: Applied crop operation to edit stack")
        print("🎯 CROP DEBUG: Edit stack now has \(editStack.operationCount) operations")
        print("🎯 CROP DEBUG: Edit stack operations: \(editStack.operations.map { $0.displayName })")

        cropViewController.dismiss(animated: true) { [weak self] in
            print("✅ CROP: Crop view controller dismissed")
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            self?.currentCropSourceImageSize = nil
            self?.updateNavigationBarForEditStack()
            self?.refreshToolbarButtons()

            self?.requestSeek(cropTime, policy: .settle, completion: nil)
        }
    }

    nonisolated func cropViewController(
        _ cropViewController: TOCropViewController,
        didCropToImage image: UIImage,
        withRect cropRect: CGRect,
        angle: Int
    ) {
        Task { @MainActor [weak self] in
            self?.handleCropCompletion(cropViewController, image: image, cropRect: cropRect, angle: angle)
        }
    }

    @MainActor
    private func handleCropCancellation(_ cropViewController: TOCropViewController) {
        print("🚨 ENTERED TOCropViewControllerDelegate didFinishCancelled!")

        cropViewController.dismiss(animated: true) { [weak self] in
            print("✅ CROP: Crop view controller dismissed after cancellation")
            self?.currentCropSourceImageSize = nil
            self?.updatePlayPauseButton()
        }
    }

    nonisolated func cropViewController(
        _ cropViewController: TOCropViewController,
        didFinishCancelled cancelled: Bool
    ) {
        Task { @MainActor [weak self] in
            self?.handleCropCancellation(cropViewController)
        }
    }
}
