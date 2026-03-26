import UIKit
import AVFoundation
import SwiftUI

/// Extension to wire modular editor system into existing LightweightEditorViewController
/// This preserves all existing functionality while adding asset-kind routing
extension LightweightEditorViewController {

    // MARK: - Public Entry Points
    
    func enableModularEditor(at mediaURL: URL) {
        if STS_ENTERPRISE_EDITOR_ENABLED {
            Task { await self.setupEnterpriseEditor(for: mediaURL) }
            return
        }
        Task { @MainActor in
            print("🧠 MODULAR EDITOR: Initializing for \(mediaURL.lastPathComponent)")
            
            // Classify the incoming asset
            let kind = await AssetClassifier.classify(fallbackURL: mediaURL)
            print("📊 ASSET CLASSIFICATION: \(kind)")
            
            // Create coordinator with existing edit stack
            self.coordinator = EditorCoordinator(host: self, editStack: self.editStack, initialKind: kind)
            
            // DISABLED: Don't mount modular player that might conflict with seeking
            // self.coordinator.attachToolsIntoHost()
            print("🚨 MODULAR PLAYER DISABLED: Preventing seek conflicts")
            
            // Configure UI based on asset type
            self.reloadSurface(for: kind)
            self.updateToolbar(for: .playback, kind: kind)
            
            print("✅ MODULAR EDITOR: Initialization complete - no conflicting player systems")
        }
    }
    
    private func setupEnterpriseEditor(for mediaURL: URL) async {
        let kind = await AssetClassifier.classify(fallbackURL: mediaURL)
        print("🧠 ENTERPRISE EDITOR: Asset classification \(kind)")
        
        await MainActor.run {
            switch kind {
            case .video(let url):
                installEnterpriseEditorSurface(at: url)
            case .photo:
                // Preserve existing behavior for photos
                self.reloadSurface(for: kind)
                self.updateToolbar(for: .playback, kind: kind)
            }
        }
    }

    // MARK: - Properties for Coordinator Access
    
    var playerContainerView: UIView {
        // Return the existing player area - we'll use the existing player layer's superview
        if let playerLayer = self.playerLayer {
            return playerLayer.superlayer?.delegate as? UIView ?? view
        }
        return view
    }
    
    var trimmerContainerView: UIView {
        // Return existing trimmer's superview or main view
        return trimmerView?.superview ?? view
    }

    // MARK: - Child View Controller Management
    
    func mountChild(_ child: UIViewController, into container: UIView) {
        addChild(child)
        container.addSubview(child.view)
        child.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            child.view.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            child.view.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            child.view.topAnchor.constraint(equalTo: container.topAnchor),
            child.view.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        child.didMove(toParent: self)
        print("✅ MOUNT CHILD: Mounted \(type(of: child)) into container")
    }

    // MARK: - Tool Installation
    
    func installTrimToolView(_ trimTool: TrimToolController, assetURL: URL) {
        // DISABLED: Don't mount modular trimmer - use original trimmer system
        // The original SimpleTrimmerView is properly sized and positioned
        print("🎛️ INSTALL TRIM: Using original native trimmer system (modular trimmer disabled)")
        
        // Original trimmer is already set up in setupRealTrimmer() and properly sized
        // Just ensure it's visible and configured for the asset
        if let originalTrimmer = self.trimmerView {
            originalTrimmer.isHidden = false
            let asset = AVURLAsset(url: assetURL)
            originalTrimmer.asset = asset
            print("✅ Using native trimmer with direct asset loading")
        }
    }

    func prepareCropTool(_ cropTool: CropToolController) {
        // Crop tool is presented modally, no mounting needed
        print("✂️ PREPARE CROP: Crop tool ready for presentation")
    }
    
    // MARK: - Toolbar Management
    
    func updateToolbar(for mode: EditorMode, kind: AssetKind) {
        print("🔧 UPDATE TOOLBAR: mode=\(mode), kind=\(kind)")
        
        switch kind {
        case .photo:
            showPhotoToolbar()
        case .video:
            showVideoToolbar()
        }
    }

    // MARK: - Surface Management
    
    func reloadSurface(for kind: AssetKind) {
        print("🔄 RELOAD SURFACE: \(kind)")
        
        switch kind {
        case .photo(let url):
            showPhotoSurface(withURL: url)
            trimmerView?.isHidden = true
        case .video(let url):
            showVideoSurface(withURL: url, gravity: .resizeAspect)
            trimmerView?.isHidden = false
            let asset = AVURLAsset(url: url)
            trimmerView?.asset = asset
        }
    }

    func replacePlayerAsset(withURL url: URL) {
        print("🔄 REPLACE PLAYER: \(url.lastPathComponent)")
        if let coordinator = coordinator,
           coordinator.playerSurfaceVC.viewIfLoaded?.superview != nil {
            coordinator.playerSurfaceVC.replace(with: url, gravity: .resizeAspect)
        }
        latestPreviewComposition = nil
        latestPreviewVideoComposition = nil
        
        // CRITICAL: Also update the original player layer to maintain compatibility
        if let playerLayer = self.playerLayer {
            let newAsset = AVURLAsset(url: url)
            let newItem = AVPlayerItem(asset: newAsset)
            let targetPlayer = resolveActivePlayer("replacePlayerAsset") ?? AVPlayer(playerItem: newItem)
            if resolveActivePlayer("replacePlayerAssetExisting") == nil {
                setActivePlayer(targetPlayer, reason: "replacePlayerAsset")
            }
            let oldItemID = targetPlayer.currentItem.map { ObjectIdentifier($0) }
            targetPlayer.replaceCurrentItem(with: newItem)
            playerLayer.player = targetPlayer
#if DEBUG
            let playerID = ObjectIdentifier(targetPlayer)
            let newItemID = ObjectIdentifier(newItem)
            print("🔁 ActivePlayer replaceCurrentItem: player=\(playerID) oldItem=\(String(describing: oldItemID)) newItem=\(newItemID)")
#endif
            ensurePeriodicTimeObserverInstalled()
            
            // Update edit stack with new asset
            self.editStack = EditStack(sourceAsset: newAsset)
            self.editStack.delegate = self
        }
        
        // CLEAN: Direct asset assignment to native trimmer
        trimmerView?.isHidden = false
        let asset = AVURLAsset(url: url)
        trimmerView?.asset = asset
        
        print("✅ CLEAN UPDATE: Direct asset loading into native trimmer")
    }

    // MARK: - Trim State Management
    
    var currentPendingTrimRange: CMTimeRange? {
        return pendingTrimRange
    }
    
    func showTrimApplyCancel(range: CMTimeRange) {
        pendingTrimRange = range
        hasPendingTrimChanges = true
        updateToolbarForPendingTrim(true)
        print("✂️ SHOW TRIM UI: Apply/Cancel buttons shown")
    }
    
    func endPendingTrimUI() {
        pendingTrimRange = nil
        hasPendingTrimChanges = false
        updateToolbarForPendingTrim(false)
        print("✅ END TRIM UI: Returned to normal toolbar")
    }

    // MARK: - Crop Presentation
    
    func presentCrop(_ cropTool: CropToolController, frame: UIImage, at time: CMTime) {
        cropTool.present(from: self, frameImage: frame, at: time)
    }

    func presentPhotoCrop(_ cropTool: CropToolController, frame: UIImage, at time: CMTime) {
        cropTool.presentPhoto(from: self, frameImage: frame, at: time)
    }
    
    func presentVideoCrop(_ cropTool: CropToolController, asset: AVAsset) {
        cropTool.presentVideo(from: self, asset: asset)
    }
    
    // MARK: - Enterprise Surface
    
    @MainActor
    private func installEnterpriseEditorSurface(at url: URL) {
        teardownEnterpriseEditorHost()
        
        let asset = AVURLAsset(url: url)
        let player: AVPlayer
        if let existingPlayer = self.player {
            let item = AVPlayerItem(asset: asset)
            let oldItemID = existingPlayer.currentItem.map { ObjectIdentifier($0) }
            existingPlayer.replaceCurrentItem(with: item)
            player = existingPlayer
#if DEBUG
            let playerID = ObjectIdentifier(existingPlayer)
            let newItemID = ObjectIdentifier(item)
            print("🔁 ActivePlayer replaceCurrentItem: player=\(playerID) oldItem=\(String(describing: oldItemID)) newItem=\(newItemID)")
#endif
        } else {
            player = AVPlayer(url: url)
        }
        setActivePlayer(player, reason: "installEnterpriseEditorSurface")

        // Keep the periodic time observer bound to the shared player for SwiftUI playhead sync.
        ensurePeriodicTimeObserverInstalled()
        
        playerLayer?.player = player
        playerLayer?.isHidden = true
        trimmerView?.isHidden = true
        toolbar?.isHidden = true
        navigationItem.rightBarButtonItem = nil
        navigationItem.title = nil
        navigationController?.setToolbarHidden(true, animated: false)
        
        Task { @MainActor [weak self] in
            guard let self else { return }
            let context = await EnterpriseEditorContext(
                asset: asset,
                player: player,
                existingTrimRange: self.editStack.currentTrimRange,
                // Start crop from full frame to avoid misinterpreting legacy pixel-space rects.
                existingCropRect: nil,
                existingCropRotation: 0,
                onApplyTrim: { [weak self] range in
                    self?.applyEnterpriseTrim(range: range)
                },
                onRevertTrim: { [weak self] in
                    self?.editStack.clearTrim()
                    self?.updateNavigationBarForEditStack()
                    self?.updateTimecodeDisplays()
                },
                onApplyCrop: { [weak self] rect, rotation in
                    self?.applyEnterpriseCrop(rect: rect, rotation: rotation)
                },
                onClearCrop: { [weak self] in
                    self?.clearEnterpriseCrop()
                },
                onScrub: { [weak self] time in
                    self?.requestSeek(time, policy: .scrub, completion: nil)
                },
                onSeek: { [weak self] time, policy in
                    self?.requestSeek(time, policy: policy, completion: nil)
                },
                onUndoApplied: { [weak self] in
                    guard let self else { return }
                    _ = self.editStack.undo()
                    self.updateNavigationBarForEditStack()
                    self.updateTimecodeDisplays()
                },
                onSave: { [weak self] in
                    self?.saveEnterpriseEdits()
                },
                onClose: { [weak self] reason in
                    self?.dismissEditor(reason: reason)
                }
            )
            
            context.onPlaybackToggle = { [weak self] in
                self?.togglePlayback()
            }
            
            // Surface SmartFill availability and badge callback into the SwiftUI context
            context.hasSmartFillAvailable = {
                guard let take = self.currentTake else { return false }
                return take.smartFilledFilePath != nil || take.isSmartFillVariant || take.hasSmartFilledVersion
            }()
            context.onSmartFillBadgeTapped = { [weak self] in
                self?.modularSmartFillTapped()
            }
            
            let host = UIHostingController(rootView: EnterpriseEditorView(context: context))
            self.addChild(host)
            host.view.translatesAutoresizingMaskIntoConstraints = false
            self.view.addSubview(host.view)
            NSLayoutConstraint.activate([
                host.view.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
                host.view.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
                host.view.topAnchor.constraint(equalTo: self.view.topAnchor),
                host.view.bottomAnchor.constraint(equalTo: self.view.bottomAnchor)
            ])
            host.didMove(toParent: self)
            
            self.enterpriseEditorHost = host
            self.enterpriseEditorContext = context
            self.finalizeEnterpriseSurfaceVisibility(excluding: host.view)
            
            print("✅ ENTERPRISE EDITOR: Mounted new editor surface")
            
            // Restore toolbar/badge (SmartFill, etc.) after mounting the SwiftUI host
            self.updateNavigationBarForEditStack()
        }
    }
    
    @MainActor
    private func teardownEnterpriseEditorHost() {
        guard let host = enterpriseEditorHost else { return }
        host.willMove(toParent: nil)
        host.view.removeFromSuperview()
        host.removeFromParent()
        enterpriseEditorHost = nil
        enterpriseEditorContext = nil
        
        toolbar?.isHidden = false
        trimmerView?.isHidden = false
        playerLayer?.isHidden = false
    }
    
    @MainActor
    private func applyEnterpriseTrim(range: CMTimeRange) {
        editStack.replaceTrim(with: range)
        updateNavigationBarForEditStack()
        updateTimecodeDisplays()
        print("✂️ ENTERPRISE EDITOR: Applied trim \(range)")
    }
    
    @MainActor
    private func applyEnterpriseCrop(rect: CGRect, rotation: Double) {
        editStack.replaceCrop(with: rect, rotationDegrees: CGFloat(rotation))
        updateNavigationBarForEditStack()
        updateTimecodeDisplays()
        print("🖼️ ENTERPRISE EDITOR: Applied crop \(rect) rotation \(rotation)")
    }
    
    @MainActor
    private func clearEnterpriseCrop() {
        editStack.clearCrop()
        updateNavigationBarForEditStack()
        updateTimecodeDisplays()
        print("🧼 ENTERPRISE EDITOR: Cleared crop")
    }

    @MainActor
    private func saveEnterpriseEdits() {
        let assetForSave = player?.currentItem?.asset ?? originalAsset
        let contextTrim = enterpriseEditorContext?.committedTrimTimeRange
        let trimRange = contextTrim ?? editStack.currentTrimRange
        let contextCropRect = enterpriseEditorContext?.committedCropRectValue
        let cropRect = contextCropRect ?? editStack.currentCropRect
        let contextRotation = enterpriseEditorContext?.committedCropRotationValue
        let cropRotation = contextRotation ?? editStack.currentCropRotationDegrees.map { Double($0) }

        if let onSaveEdits {
            onSaveEdits(assetForSave, trimRange, cropRect, cropRotation)
        } else {
            persistEditMetadataIfPossible(trimRange: trimRange, cropRect: cropRect, rotationDegrees: cropRotation)
        }

        print("💾 ENTERPRISE EDITOR: Saved edits (trim: \(trimRange != nil), crop: \(cropRect != nil))")
    }

    @MainActor
    private func persistEditMetadataIfPossible(trimRange: CMTimeRange?, cropRect: CGRect?, rotationDegrees: Double?) {
        guard
            let repository,
            let takeID = currentTake?.id,
            let sessionID = currentSession?.id,
            let projectID = currentProject?.id
        else {
            print("ℹ️ ENTERPRISE EDITOR: No repository context available for metadata save")
            return
        }

        let hasMeaningfulCrop = cropRect?.sts_hasMeaningfulCrop ?? false
        let hasRotationChange = (rotationDegrees.map { abs($0) > 0.01 } ?? false)
        let hasCropChange = hasMeaningfulCrop || hasRotationChange
        
        let metadata = TakeEditMetadata(
            hasTrimming: trimRange != nil,
            trimStartTime: trimRange.map { CMTimeGetSeconds($0.start) },
            trimEndTime: trimRange.map { CMTimeGetSeconds(CMTimeAdd($0.start, $0.duration)) },
            hasCropping: hasCropChange,
            cropRect: cropRect,
            cropRotationDegrees: rotationDegrees
        )

        repository.updateTakeEditMetadata(
            takeID: takeID,
            sessionID: sessionID,
            projectID: projectID,
            editMetadata: metadata
        )

        if var take = currentTake {
            take.editMetadata = metadata
            currentTake = take
        }

        NotificationCenter.default.post(
            name: Notification.Name("STSEnterpriseEditorDidSaveMetadata"),
            object: nil,
            userInfo: [
                "takeID": takeID,
                "sessionID": sessionID,
                "projectID": projectID
            ]
        )

        print("🗂️ ENTERPRISE EDITOR: Persisted metadata directly to repository")
    }

    // MARK: - Toolbar Implementations
    
    private func showPhotoToolbar() {
        print("📷 PHOTO TOOLBAR: Crop disabled for photos in current editor build")
        
        guard let toolbar = toolbar else { return }
        
        // Disabled crop button with feedback
        let cropButton = UIBarButtonItem(
            title: "Photo Editing Coming Soon",
            style: .plain,
            target: nil,
            action: nil
        )
        cropButton.tintColor = UIColor.systemOrange.withAlphaComponent(0.6)
        cropButton.isEnabled = false
        
        let clearButton = UIBarButtonItem(
            title: editStack.hasOperations ? "Clear All" : "No Edits",
            style: .plain,
            target: self,
            action: editStack.hasOperations ? #selector(clearAllEdits) : nil
        )
        clearButton.tintColor = editStack.hasOperations ? UIColor.systemRed : UIColor.darkGray
        clearButton.isEnabled = editStack.hasOperations
        
        let flexibleSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        
        toolbar.items = [
            flexibleSpace,
            cropButton,
            flexibleSpace,
            clearButton,
            flexibleSpace
        ]
        
        print("🚫 Photo editing disabled: showing placeholder toolbar")
    }
    
    private func showVideoToolbar() {
        print("🎬 VIDEO TOOLBAR: Full toolset available")
        recreateDefaultToolbarItems()
        updatePlayPauseButton()
    }
    
    // MARK: - Surface Implementations
    
    private func showPhotoSurface(withURL url: URL) {
        print("📷 PHOTO SURFACE: Showing photo at \(url.lastPathComponent)")
        
        // Hide video player
        playerLayer?.isHidden = true
        
        // TODO: Implement proper photo surface - for now just hide video
        // You might want to add a UIImageView here
    }
    
    private func showVideoSurface(withURL url: URL, gravity: AVLayerVideoGravity) {
        print("🎬 VIDEO SURFACE: Showing video with gravity \(gravity)")
        
        // Show video player
        playerLayer?.isHidden = false
        playerLayer?.videoGravity = gravity
        
        if let previewComposition = latestPreviewComposition {
            coordinator?.playerSurfaceVC.attach(
                asset: previewComposition,
                gravity: gravity,
                videoComposition: latestPreviewVideoComposition
            )
        } else {
            let asset = AVURLAsset(url: url)
            coordinator?.playerSurfaceVC.attach(asset: asset, gravity: gravity)
        }
    }

    // MARK: - Modular Actions
    
    @objc func modularSmartFillTapped() {
        print("🎭 MODULAR SMARTFILL: Opening rebuild workspace")

        guard let context = buildEditorSmartFillContext() else {
            let alert = UIAlertController(
                title: "SmartFill Unavailable",
                message: "We couldn't find the project, session, and take context needed to open SmartFill.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
            return
        }

        let workspace = UIHostingController(
            rootView: SmartFillWorkspaceView(
                context: context,
                onQueueSmartFill: { [weak self] settings in
                    self?.queueSmartFillFromWorkspace(settings, context: context)
                },
                onOpenSavedTake: { [weak self] record in
                    self?.dismiss(animated: true) { [weak self] in
                        self?.openSavedSmartFillTakeFromWorkspace(record)
                    }
                },
                onCancel: {
                    print("🎭 SMARTFILL WORKSPACE: User closed rebuild workspace")
                }
            )
        )

        workspace.modalPresentationStyle = .pageSheet
        workspace.isModalInPresentation = false

        if let sheet = workspace.sheetPresentationController {
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 16
        }

        present(workspace, animated: true)
        print("✅ SMARTFILL WORKSPACE: Presented rebuild workspace from editor")
    }
    
    // MARK: - SmartFill Settings Application
    
    private func buildEditorSmartFillContext() -> SmartFillSettingsContext? {
        guard let take = currentTake,
              let session = currentSession,
              let project = currentProject else {
            return nil
        }

        let launchSeed = SmartFillTakeBridge.editorLaunchSeed(for: take, in: session)
        let sourceTake = session.takes.first(where: { $0.id == launchSeed.sourceTakeID }) ?? take
        let existingSettings = launchSeed.existingSettings.map { SmartFillTakeBridge.settings(from: $0) }

        return SmartFillSettingsContext(
            take: sourceTake,
            session: session,
            project: project,
            launchSource: .editorBadge,
            returnTarget: .editor,
            autoLaunchEditor: false,
            displayName: launchSeed.displayName,
            infoTitle: launchSeed.infoTitle,
            infoMessage: launchSeed.infoMessage,
            existingSettings: existingSettings,
            onUpdatePIPSession: { [weak self] newValue in
                self?.updateEditorPIPSession(newValue, sessionID: session.id, projectID: project.id)
            }
        )
    }

    private func updateEditorPIPSession(_ newValue: SlatePIPSession?, sessionID: UUID, projectID: UUID) {
        guard let repository = repository ?? SessionManager.shared.repositoryInstance,
              var session = currentSession ?? repository.project(by: projectID)?.sessions.first(where: { $0.id == sessionID }) else {
            return
        }

        session.pipSlateSession = newValue
        repository.updateSession(session, in: projectID)

        if let refreshedProject = repository.project(by: projectID),
           let refreshedSession = refreshedProject.sessions.first(where: { $0.id == sessionID }) {
            currentProject = refreshedProject
            currentSession = refreshedSession
            if let takeID = currentTake?.id,
               let refreshedTake = refreshedSession.takes.first(where: { $0.id == takeID }) {
                currentTake = refreshedTake
            }
        }
    }

    private func queueSmartFillFromWorkspace(
        _ settings: SmartFillSettings,
        context: SmartFillSettingsContext
    ) {
        print("🎭 APPLYING SMARTFILL: Rebuild workspace queued processing")
        print("🔍 PROCESSING SETTINGS DEBUG:")
        print("   📐 backgroundScale: \(settings.backgroundScale)")
        print("   🌀 defaultBlurRadius: \(settings.defaultBlurRadius)")
        print("   🌙 defaultDarkenAmount: \(settings.defaultDarkenAmount)")
        print("   📺 defaultRenderSize: \(settings.defaultRenderSize)")
        print("   ✅ defaultEnabled: \(settings.defaultEnabled)")

        guard let repository = repository ?? SessionManager.shared.repositoryInstance else {
            print("❌ SMARTFILL: Missing repository for workspace launch")
            return
        }

        settings.saveToUserDefaults()

        let take = context.take
        let originalURL = VideoVariantResolver.originalURL(for: take)
        let originalFileName = originalURL.lastPathComponent
        let smartFillOutputURL = SmartFillManager.shared.getSmartFillURL(for: originalURL)

        Task { [weak self] in
            guard let self = self else { return }
            let jobQueued = await SmartFillProcessingManager.shared.enqueueJob(
                originalPath: originalURL.path,
                outputPath: smartFillOutputURL.path,
                fileName: originalFileName,
                takeID: take.id,
                sessionID: context.session.id,
                projectID: context.project.id,
                capturedOrientation: take.capturedOrientation,
                settings: settings
            )

            await MainActor.run {
                if jobQueued {
                    SmartFillProcessingManager.shared.delegate = self
                    self.repository = repository
                    print("✅ SMARTFILL: Job enqueued with modal settings (output: \(smartFillOutputURL.lastPathComponent))")
                } else {
                    print("ℹ️ SMARTFILL: Job not queued (orientation check failed)")
                    NotificationCenter.default.post(
                        name: .smartFillProcessingFailed,
                        object: nil,
                        userInfo: ["error": "SmartFill not required for this clip"]
                    )
                }
            }
        }
    }

    private func openSavedSmartFillTakeFromWorkspace(_ record: SmartFillResultBridgeRecord) {
        guard let repository = repository ?? SessionManager.shared.repositoryInstance,
              let project = repository.project(by: record.projectID),
              let session = project.sessions.first(where: { $0.id == record.sessionID }),
              let take = session.takes.first(where: { $0.id == record.adoptedTakeID }) else {
            print("❌ SMARTFILL WORKSPACE: Could not resolve saved take \(record.adoptedTakeID) for reopen")
            return
        }

        setupWithRepository(repository, take: take, session: session, project: project)

        let effectiveURL = VideoVariantResolver.effectiveURL(for: take)
        replacePlayerAsset(withURL: effectiveURL)

        Task { @MainActor in
            let newKind = await AssetClassifier.classify(fallbackURL: effectiveURL)
            self.coordinator?.assetKind = newKind
            self.reloadSurface(for: newKind)
            self.updateToolbar(for: .playback, kind: newKind)
        }

        print("✅ SMARTFILL WORKSPACE: Reopened saved take \(record.adoptedTakeDisplayName) in editor")
    }
    
    private func handleSmartFillComplete(outputURL: URL) {
        // Update the asset to the new SmartFill version
        let newAsset = AVURLAsset(url: outputURL)
        
        // Replace the edit stack with the new asset
        self.editStack = EditStack(sourceAsset: newAsset)
        self.editStack.delegate = self
        
        // Update player with new asset
        let newPlayerItem = AVPlayerItem(asset: newAsset)
        self.player?.replaceCurrentItem(with: newPlayerItem)
        
        // Update the coordinator to landscape mode since SmartFill converts to landscape
        Task { @MainActor in
            let newKind = await AssetClassifier.classify(fallbackURL: outputURL)
            self.coordinator?.assetKind = newKind
            
            // Update UI for new asset type
            self.reloadSurface(for: newKind)
            self.updateToolbar(for: .playback, kind: newKind)
            
            print("🎭 SMARTFILL UI UPDATE: Switched to landscape mode after processing")
        }
    }

    // MARK: - Helper Properties (using associated objects to avoid modifying main class)
    
    private var playerHostView: UIView! {
        get { objc_getAssociatedObject(self, &AssociatedKeys.playerHost) as? UIView }
        set { objc_setAssociatedObject(self, &AssociatedKeys.playerHost, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
    
    var coordinator: EditorCoordinator! {
        get { objc_getAssociatedObject(self, &AssociatedKeys.coordinator) as? EditorCoordinator }
        set { objc_setAssociatedObject(self, &AssociatedKeys.coordinator, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    // MARK: - Associated Object Keys
    
    private struct AssociatedKeys {
        static var coordinator: UInt8 = 0
        static var playerHost: UInt8 = 0
    }
}

// MARK: - SmartFillProcessingDelegate Extension
// Note: Remove the redundant conformance and override keywords since
// LightweightEditorViewController already conforms to SmartFillProcessingDelegate
extension LightweightEditorViewController {
    
    // MARK: - SmartFill Delegate Implementation for Modular System
    
    func handleSmartFillCompletion(takeID: UUID, outputURL: URL) {
        print("✅ SmartFill completed for take: \(takeID), url: \(outputURL)")
        
        DispatchQueue.main.async { [weak self] in
            self?.handleSmartFillComplete(outputURL: outputURL)
            
            // Post notification for modal to handle
            NotificationCenter.default.post(
                name: .smartFillProcessingComplete,
                object: nil,
                userInfo: ["outputURL": outputURL]
            )
        }
    }
    
    func handleSmartFillFailure(takeID: UUID, error: Error) {
        print("❌ SmartFill failed for take: \(takeID) - \(error)")
        
        DispatchQueue.main.async {
            // Post notification for modal to handle
            NotificationCenter.default.post(
                name: .smartFillProcessingFailed,
                object: nil,
                userInfo: ["error": error.localizedDescription]
            )
        }
    }
}

// MARK: - SmartFill Revert (with trim reset)
extension LightweightEditorViewController {
    func handleRevertSmartFillTapped() {
        let hasEdits = (currentTake?.editMetadata?.hasTrimming == true) || (currentTake?.editMetadata?.hasCropping == true)
        let alert = UIAlertController(
            title: "Revert SmartFill?",
            message: hasEdits ? "Reverting SmartFill will reset trim edits as well." : "This will remove SmartFill and restore the original take.",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "Revert", style: .destructive, handler: { [weak self] _ in
            self?.performSmartFillRevert()
        }))

        present(alert, animated: true)
    }

    private func performSmartFillRevert() {
        guard let take = currentTake,
              let session = currentSession,
              let project = currentProject else {
            revertSmartFillToPortrait()
            return
        }

        if let repo = repository ?? SessionManager.shared.repositoryInstance {
            repo.clearEditMetadata(
                takeID: take.id,
                sessionID: session.id,
                projectID: project.id
            )
        }

        revertSmartFillToPortrait()
    }
}
