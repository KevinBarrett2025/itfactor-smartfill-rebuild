import Foundation
import AVFoundation

enum SessionManagerError: LocalizedError {
    case repositoryUnavailable
    
    var errorDescription: String? {
        switch self {
        case .repositoryUnavailable:
            return "Camera repository is unavailable."
        }
    }
}

struct SessionProgress: Equatable {
    enum MissingCategory: Equatable {
        case scenes([Int])
        case slate
        case keyframe
    }

    let sceneCount: Int
    let scenesWithRegularTakes: Set<Int>
    let hasSlate: Bool
    let hasKeyframePhoto: Bool

    var missingScenes: [Int] {
        guard sceneCount > 0 else { return [] }
        return (1...sceneCount).filter { !scenesWithRegularTakes.contains($0) }
    }

    var missingCategories: [MissingCategory] {
        var categories: [MissingCategory] = []
        let missingScenes = self.missingScenes
        if !missingScenes.isEmpty {
            categories.append(.scenes(missingScenes))
        }
        if !hasSlate {
            categories.append(.slate)
        }
        if !hasKeyframePhoto {
            categories.append(.keyframe)
        }
        return categories
    }

    var allScenesComplete: Bool {
        missingScenes.isEmpty
    }

    var allCategoriesComplete: Bool {
        missingCategories.isEmpty
    }

    static func fromProjectTakes(_ takes: [ProjectTake], sceneCount: Int) -> SessionProgress {
        let normalizedSceneCount = max(1, sceneCount)
        let scenesWithRegularTakes = Set<Int>(takes.compactMap { take in
            guard take.takeType == .regular, take.sceneNumber >= 1 else { return nil }
            return take.sceneNumber
        })
        let hasSlate = takes.contains { $0.takeType.isSlateLike }
        let hasKeyframePhoto = takes.contains { $0.isKeyframePhoto }

        return SessionProgress(
            sceneCount: normalizedSceneCount,
            scenesWithRegularTakes: scenesWithRegularTakes,
            hasSlate: hasSlate,
            hasKeyframePhoto: hasKeyframePhoto
        )
    }

    static func fromUnifiedTakes(_ takes: [UnifiedTake], sceneCount: Int) -> SessionProgress {
        let normalizedSceneCount = max(1, sceneCount)
        let scenesWithRegularTakes = Set<Int>(takes.compactMap { take in
            guard take.sceneNumber >= 1,
                  !take.isSlate,
                  !take.isPhoto,
                  !take.isKeyframePhoto else {
                return nil
            }
            return take.sceneNumber
        })
        let hasSlate = takes.contains { $0.isSlate }
        let hasKeyframePhoto = takes.contains { $0.isKeyframePhoto }

        return SessionProgress(
            sceneCount: normalizedSceneCount,
            scenesWithRegularTakes: scenesWithRegularTakes,
            hasSlate: hasSlate,
            hasKeyframePhoto: hasKeyframePhoto
        )
    }
}

// MARK: - Enhanced Session Manager with UNIFIED MODEL SUPPORT
// Phase 1C: Adding UnifiedTake support alongside existing EnhancedTake system
// PRESERVATION-FIRST: All existing functionality maintained

public class SessionManager: ObservableObject {
    public enum RecordingMode {
        case scenes
        case slates
        case keyframes
    }
    
    public static let shared = SessionManager()
    
    @Published private(set) var currentSession: SessionState?
    
    // EXISTING: Keep original takes for compatibility
    @Published private(set) var activeTakes: [EnhancedTake] = []
    
    // ENHANCED: Add unified takes support alongside existing system
    @Published private(set) var unifiedTakes: [UnifiedTake] = []
    @Published private(set) var useUnifiedModels: Bool = false
    @Published private(set) var ratingOverrides: [UUID: TakeRating] = [:]
    @Published private(set) var sessionProgress: SessionProgress?
#if DEBUG
    private var ratingOverrideUseCount: Int = 0
    private var ratingOverrideClearedCount: Int = 0
    private var ratingOverrideWindowStart = Date()
#endif

    @Published var shouldShowResumeNudge: Bool = false
    @Published private(set) var resumeNudgeRemainingText: String = ""
    private var didShowResumeNudgeThisEntry: Bool = false
    
    @Published var currentScene: Int = 1
    @Published var totalScenes: Int = 1

    var effectiveSessionProgress: SessionProgress {
        if let sessionProgress {
            return sessionProgress
        }
        let unifiedForProgress = useUnifiedModels ? unifiedTakes : activeTakes.map { UnifiedTake(from: $0) }
        return SessionProgress.fromUnifiedTakes(unifiedForProgress, sceneCount: totalScenes)
    }
    
    // REDESIGNED: Slate as separate recording mode, not a modifier
    @Published var isRecordingSlate: Bool = false // NEW: Replace isSlateNext with recording mode
    @Published var hasRecordedSlate: Bool = false
    @Published var slateSkippedForSession: Bool = false
    
    // NEW: Keyframe photo recording mode
    @Published var isRecordingKeyframePhoto: Bool = false
    @Published var hasRecordedKeyframePhoto: Bool = false
    
    // CORE INTEGRATION FIX: Add repository injection
    private var repository: ProjectsRepository?
    private var hasEnabledUnifiedModelsOnRepository = false
    private let autoSmartFillProcessingEnabled = false
    
    // CORE INTEGRATION FIX: Public access to repository for CameraCaptureView
    public var repositoryInstance: ProjectsRepository? {
        return repository
    }
    
    private init() {}

    // MARK: - Archive guard
    private func isArchived(projectID: UUID, sessionID: UUID) -> Bool {
        guard let repository,
              let project = repository.project(by: projectID) else { return false }
        if project.isArchived { return true }
        if let session = project.sessions.first(where: { $0.id == sessionID }),
           session.isArchived {
            return true
        }
        return false
    }

    // MARK: - Thread Safety Helpers
    @inline(__always)
    private func ensureMain(_ work: @escaping () -> Void) {
        if Thread.isMainThread {
            work()
        } else {
            DispatchQueue.main.async {
                work()
            }
        }
    }
    
    // CORE INTEGRATION FIX: Configure repository with enhanced logging
    public func configure(with repository: ProjectsRepository) {
        ensureMain {
            self.repository = repository
            if !self.hasEnabledUnifiedModelsOnRepository {
                repository.enableUnifiedModelSupport()
                self.hasEnabledUnifiedModelsOnRepository = true
                print("📹 SessionManager: Configured repository and enabled unified model support")
            } else {
                print("📹 SessionManager: Repository already has unified model support enabled; skipping re-enable")
            }
        }
    }
    
    // ENHANCED: Enable unified models with seamless migration - ALWAYS ENABLE FOR NEW SESSIONS
    public func enableUnifiedModels() {
        ensureMain {
            if self.useUnifiedModels {
                print("🔄 SessionManager: Unified models already enabled")
                return
            }
            
            print("🔄 SessionManager: Enabling unified models...")
            
            // Convert existing takes to unified format if any exist
            if !self.activeTakes.isEmpty {
                self.unifiedTakes = self.activeTakes.map { UnifiedTake(from: $0) }
                print("✅ Converted \(self.activeTakes.count) existing takes to unified format")
            }
            
            self.useUnifiedModels = true
            print("✅ SessionManager: Unified models enabled with \(self.unifiedTakes.count) takes")
        }
    }
    
    // MARK: - Session Management (PRESERVED) with UNIFIED DEFAULT
    public func startSession(project: Project,
                             session: ProjectSession,
                             preferredScene: Int? = nil,
                             recordingMode: RecordingMode? = nil) {
        ensureMain {
            self.currentSession = SessionState(
                project: project,
                session: session,
                startTime: Date()
            )
#if DEBUG
            print("🧭 SessionManager.currentSession set startSession project=\(project.id) session=\(session.id)")
#endif
            self.activeTakes = []
            self.unifiedTakes = []
            self.sessionProgress = nil
            self.resetResumeNudgeEntryState()
            
            // ENHANCED: Initialize scene management from project
            if let preferredScene = preferredScene {
                self.currentScene = max(1, preferredScene)
            } else {
                self.currentScene = 1
            }
            self.totalScenes = max(1, project.sceneCount) // Ensure at least 1 scene
            
            self.hasRecordedSlate = false
            self.slateSkippedForSession = false
            self.hasRecordedKeyframePhoto = false
            
            switch recordingMode ?? .scenes {
            case .scenes:
                self.isRecordingSlate = false
                self.isRecordingKeyframePhoto = false
            case .slates:
                self.isRecordingSlate = true
                self.isRecordingKeyframePhoto = false
            case .keyframes:
                self.isRecordingSlate = false
                self.isRecordingKeyframePhoto = true
            }
            
            // CRITICAL FIX: Always enable unified models for new sessions
            self.enableUnifiedModels()
            
            print("📹 SessionManager: Started session for \(project.title) with \(self.totalScenes) scenes and unified models enabled")
        }
    }

    /// Ensure SessionManager has a valid review context for playback/rating flows (non-recording).
    public func ensureReviewContext(
        project: Project,
        session: ProjectSession,
        takes: [ProjectTake],
        source: String
    ) {
        ensureMain { [weak self] in
            guard let self else { return }
            let needsSessionUpdate =
                self.currentSession?.project.id != project.id ||
                self.currentSession?.session.id != session.id

            if needsSessionUpdate {
                self.currentSession = SessionState(project: project, session: session, startTime: Date())
#if DEBUG
                print("🧭 SessionManager.currentSession set reviewContext source=\(source) project=\(project.id) session=\(session.id)")
#endif
            }

            if !self.useUnifiedModels {
                self.enableUnifiedModels()
            }

            let updatedUnifiedTakes = takes.enumerated().compactMap { index, take in
                let fileName = URL(fileURLWithPath: take.filePath).lastPathComponent
                return try? UnifiedTake.safeConversion(
                    from: take,
                    projectID: project.id,
                    sessionID: session.id,
                    fileName: fileName,
                    takeNumber: index + 1
                )
            }

            self.unifiedTakes = updatedUnifiedTakes
            self.activeTakes = updatedUnifiedTakes.map { $0.toEnhancedTake() }
            self.objectWillChange.send()
            self.recomputeSessionProgress(project: project, session: session)

#if DEBUG
            if updatedUnifiedTakes.count != takes.count {
                print("🧪 ReviewContext[\(source)] conversionMismatch input=\(takes.count) unified=\(updatedUnifiedTakes.count)")
            }
            let firstID = updatedUnifiedTakes.first?.id.uuidString ?? "nil"
            let lastID = updatedUnifiedTakes.last?.id.uuidString ?? "nil"
            print("🧪 ReviewContext[\(source)] registeredTakes=\(updatedUnifiedTakes.count) first=\(firstID) last=\(lastID)")
#endif
        }
    }
    
    func endSession() {
        guard let session = currentSession else { return }
        print("📹 SessionManager: Ended session for \(session.project.title) with \(effectiveTakeCount) takes")
        
        // CORE INTEGRATION FIX: Persist all takes to repository before clearing
        persistAllTakesToRepository()
        
        ensureMain {
            self.currentSession = nil
#if DEBUG
            print("🧭 SessionManager.currentSession cleared endSession")
#endif
            self.activeTakes = []
            self.unifiedTakes = []
        }
    }
    
    // MARK: - Enhanced Take Management with UNIFIED SUPPORT

    // MARK: - Capture Completion Flags (truth-based)
    func recomputeCaptureCompletionFlagsFromUnifiedTakes() {
        ensureMain {
            self.hasRecordedSlate = !self.getSlateTakesAsTakes().isEmpty
            self.hasRecordedKeyframePhoto = !self.getKeyframePhotoTakesAsTakes().isEmpty
            let unifiedForProgress = self.useUnifiedModels ? self.unifiedTakes : self.activeTakes.map { UnifiedTake(from: $0) }
            let progress = SessionProgress.fromUnifiedTakes(unifiedForProgress, sceneCount: self.totalScenes)
            self.sessionProgress = progress
#if DEBUG
            print("🎯 SessionProgress: scenesDone=\(progress.scenesWithRegularTakes.sorted()) missing=\(progress.missingScenes) hasSlate=\(progress.hasSlate) hasKeyframe=\(progress.hasKeyframePhoto)")
#endif
        }
    }

    func recomputeSessionProgress(project: Project? = nil, session: ProjectSession? = nil) {
        let sceneCount = max(1, project?.sceneCount ?? currentSession?.project.sceneCount ?? totalScenes)
        let progress: SessionProgress

        if let session {
            progress = SessionProgress.fromProjectTakes(session.takes, sceneCount: sceneCount)
        } else {
            let unifiedForProgress = useUnifiedModels ? unifiedTakes : activeTakes.map { UnifiedTake(from: $0) }
            progress = SessionProgress.fromUnifiedTakes(unifiedForProgress, sceneCount: sceneCount)
        }

        ensureMain {
            self.sessionProgress = progress
#if DEBUG
            print("🎯 SessionProgress: scenesDone=\(progress.scenesWithRegularTakes.sorted()) missing=\(progress.missingScenes) hasSlate=\(progress.hasSlate) hasKeyframe=\(progress.hasKeyframePhoto)")
#endif
        }
    }

    // ENHANCED: New unified take addition method with Smart Fill orientation capture
    func addUnifiedTakeWithOrientation(
        fileName: String,
        projectID: UUID,
        sessionID: UUID,
        filePath: String? = nil,
        duration: TimeInterval = 0,
        fileSize: Int64 = 0,
        cameraPosition: String = "back",
        capturedOrientation: VideoOrientation? = nil,  // NEW: Smart Fill orientation
        notes: String? = nil,
        videoMarkers: [UnifiedVideoMarker] = []
    ) {
        if !Thread.isMainThread {
            DispatchQueue.main.async { [weak self] in
                self?.addUnifiedTakeWithOrientation(
                    fileName: fileName,
                    projectID: projectID,
                    sessionID: sessionID,
                    filePath: filePath,
                    duration: duration,
                    fileSize: fileSize,
                    cameraPosition: cameraPosition,
                    capturedOrientation: capturedOrientation,
                    notes: notes,
                    videoMarkers: videoMarkers
                )
            }
            return
        }

        // --- CRITICAL FIX: Always store path in relative format ---
        // Only use filename if filePath is empty or absolute path
        let safePath: String
        if let filePath, !filePath.isEmpty {
            // If absolute, extract relative path
            if filePath.hasPrefix("/") {
                safePath = VideoVariantResolver.relativePath(from: URL(fileURLWithPath: filePath))
            } else {
                safePath = filePath
            }
        } else {
            safePath = fileName
        }
        // --------------------------------------------------------

        // CRITICAL FIX: Properly calculate scene numbers and take numbers based on current mode
        let (sceneNum, takeNum, slateNum, slateIDStr) = calculateTakeOrganization()
        
        let unifiedTake = UnifiedTake(
            fileName: fileName,
            projectID: projectID,
            sessionID: sessionID,
            filePath: safePath, // FIXED: Always store relative form
            duration: duration,
            fileSize: fileSize,
            cameraPosition: cameraPosition,
            sceneNumber: sceneNum,          // FIXED: Use calculated scene number
            takeNumber: takeNum,            // FIXED: Use calculated take number
            slateNumber: slateNum,          // FIXED: Add slate number
            slateID: slateIDStr,            // FIXED: Add slate ID
            isSlate: isRecordingSlate,      // REDESIGNED: Use recording mode
            isPhoto: false,                 // Default to video - use addUnifiedPhotoTakeWithOrientation for photos
            isKeyframePhoto: false,
            capturedOrientation: capturedOrientation,  // NEW: Store captured orientation
            rating: .unrated,
            notes: notes,
            videoMarkers: videoMarkers
        )
        
        if useUnifiedModels {
            unifiedTakes.append(unifiedTake)
        } else {
            // Convert to legacy for compatibility
            activeTakes.append(unifiedTake.toEnhancedTake())
        }
        
        let projectToken = projectID.uuidString.prefix(8)
        let sessionToken = sessionID.uuidString.prefix(8)
        print("📼 SessionManager: added unified take \(fileName) [project \(projectToken), session \(sessionToken)] scene \(sceneNum) take \(takeNum) slate:\(isRecordingSlate)")
        
        let orientationStr = capturedOrientation?.displayName ?? "Unknown"
        print("📹 SessionManager: Added unified take with orientation \(fileName) - Scene: \(sceneNum), Take: \(takeNum), Slate: \(slateNum ?? "none"), Orientation: \(orientationStr)")
        print("📍 Stored filePath: \(safePath)")
        
        // Persist to repository
        persistUnifiedTakeToRepository(unifiedTake)
        
        if autoSmartFillProcessingEnabled {
            print("🔍 SMARTFILL TRIGGER: About to check if SmartFill processing should be triggered")
            print("   📱 Captured orientation: \(capturedOrientation?.displayName ?? "nil")")
            print("   🎬 Is recording slate: \(isRecordingSlate)")
            print("   📸 Is photo: false (this is a video)")
            
            // 🚨 DISABLED AUTO-PROCESSING: SmartFill should only be applied manually via editor
            // Users should have full control over which videos get SmartFill processing
            // Task { @MainActor in
            //     triggerSmartFillProcessingIfNeeded(unifiedTake: unifiedTake)
            // }
            
            print("📱 SessionManager: Auto-SmartFill disabled - manual processing only via editor")
        }

        // REDESIGNED: Update slate recorded status
        if isRecordingSlate {
            hasRecordedSlate = true
        }

        recomputeCaptureCompletionFlagsFromUnifiedTakes()
    }
    
    // 🔥 NEW: Auto-trigger SmartFill processing for portrait videos
    @MainActor
    private func triggerSmartFillProcessingIfNeeded(unifiedTake: UnifiedTake) {
        print("🔍 SMARTFILL AUTO-TRIGGER DEBUG: Analyzing take for auto-processing")
        print("   🆔 Take ID: \(unifiedTake.id)")
        print("   📁 Filename: \(unifiedTake.fileName)")
        print("   📱 Captured orientation: \(unifiedTake.capturedOrientation?.displayName ?? "nil")")
        print("   📷 Is photo: \(unifiedTake.isPhoto)")
        print("   🎬 Is slate: \(unifiedTake.isSlate)")
        
        // Only exclude photos - process ALL videos (both scene videos AND slate videos)
        guard let orientation = unifiedTake.capturedOrientation,
              orientation == .portrait,
              !unifiedTake.isPhoto else {
            
            let reason = unifiedTake.isPhoto ? "is photo" :
                        unifiedTake.capturedOrientation == nil ? "no orientation captured" :
                        "orientation is \(unifiedTake.capturedOrientation?.displayName ?? "unknown")"
            print("📱 SessionManager: Skipping SmartFill auto-processing - \(reason)")
            return
        }
        
        // 🔥 ENHANCED: Check if SmartFill is enabled globally
        let settings = SmartFillSettings()
        guard settings.defaultEnabled else {
            print("📱 SessionManager: SmartFill disabled globally, skipping auto-processing")
            return
        }
        
        print("✅ SMARTFILL AUTO-TRIGGER: Portrait video detected, SmartFill enabled - proceeding with auto-processing")
        
        // Generate SmartFill output path
        let inputURL = URL(fileURLWithPath: unifiedTake.filePath)
        let fileName = inputURL.deletingPathExtension().lastPathComponent
        let smartFillFileName = "\(fileName)_smartfill.mov"
        
        // Create SmartFill directory if needed
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let smartFillDir = documentsPath.appendingPathComponent("SmartFill")
        
        do {
            try FileManager.default.createDirectory(at: smartFillDir, withIntermediateDirectories: true)
        } catch {
            print("❌ SessionManager: Could not create SmartFill directory: \(error)")
            return
        }
        
        let outputPath = smartFillDir.appendingPathComponent(smartFillFileName).path
        
        print("🎯 SessionManager: Auto-enqueuing SmartFill job for portrait video")
        print("   📁 Input: \(unifiedTake.filePath)")
        print("   📁 Output: \(outputPath)")
        print("   📱 Orientation: \(orientation.displayName)")
        print("   ⚙️ Settings: Enabled=\(settings.defaultEnabled), Blur=\(settings.defaultBlurRadius), Scale=\(settings.backgroundScale)")
        
        // 🔥 CRITICAL FIX: Validate input file exists before enqueuing
        guard FileManager.default.fileExists(atPath: unifiedTake.filePath) else {
            print("❌ SessionManager: Input file does not exist, cannot enqueue SmartFill job: \(unifiedTake.filePath)")
            return
        }
        
        // 🚨 CRITICAL FIX: REMOVED PRE-SETTING OF SMARTFILL PATH
        // Previously we pre-set the SmartFill path here which caused UI to show files that don't exist
        // Now we ONLY set the path AFTER successful processing and file validation
        
        // if let repository = repositoryInstance {
        Task {
            do {
                let result = try await SmartFillUnifiedInterface.shared.processVideo(
                    inputURL: URL(fileURLWithPath: unifiedTake.filePath),
                    outputURL: URL(fileURLWithPath: outputPath),
                    settings: settings
                )
                
                print("✅ SessionManager: SmartFill processing completed successfully")
                print("   🎬 Compositor used: \(result.compositorUsed)")
                print("   ⏱️ Processing time: \(String(format: "%.2f", result.processingTime))s")
                
                // Update repository with completion
                await MainActor.run {
                    if let repository = repositoryInstance {
                        repository.updateTakeWithSmartFillPath(
                            takeID: unifiedTake.id,
                            smartFilledPath: outputPath,
                            in: unifiedTake.sessionID,
                            in: unifiedTake.projectID
                        )
                    }
                    
                    // Post success notification
                    NotificationCenter.default.post(
                        name: Notification.Name("STSSmartFillCompleted"),
                        object: nil,
                        userInfo: [
                            "takeID": unifiedTake.id,
                            "sessionID": unifiedTake.sessionID,
                            "projectID": unifiedTake.projectID,
                            "smartFillPath": outputPath,
                            "compositor": result.compositorUsed,
                            "processingTime": result.processingTime
                        ]
                    )
                }
                
            } catch {
                print("❌ SessionManager: SmartFill processing failed: \(error)")
                
                await MainActor.run {
                    // Post failure notification
                    NotificationCenter.default.post(
                        name: Notification.Name("STSSmartFillFailed"),
                        object: nil,
                        userInfo: [
                            "takeID": unifiedTake.id,
                            "sessionID": unifiedTake.sessionID,
                            "projectID": unifiedTake.projectID,
                            "error": error.localizedDescription
                        ]
                    )
                }
            }
        }

        print("✅ SessionManager: SmartFill processing initiated via unified interface for \(fileName)")
    }
    
    // NEW: Add unified photo take method with orientation - ENHANCED for Smart Fill
    func addUnifiedPhotoTakeWithOrientation(
        fileName: String,
        projectID: UUID,
        sessionID: UUID,
        filePath: String? = nil,
        fileSize: Int64 = 0,
        cameraPosition: String = "back",
        capturedOrientation: VideoOrientation? = nil,  // NEW: Smart Fill orientation
        notes: String? = nil
    ) {
        if !Thread.isMainThread {
            DispatchQueue.main.async { [weak self] in
                self?.addUnifiedPhotoTakeWithOrientation(
                    fileName: fileName,
                    projectID: projectID,
                    sessionID: sessionID,
                    filePath: filePath,
                    fileSize: fileSize,
                    cameraPosition: cameraPosition,
                    capturedOrientation: capturedOrientation,
                    notes: notes
                )
            }
            return
        }

        // CRITICAL FIX: Photos have their own organization logic
        let photoSceneNum: Int
        let photoTakeNum: Int
        
        if isRecordingKeyframePhoto {
            // Keyframe photos are session-wide
            photoSceneNum = -1  // Special scene number for keyframe photos
            photoTakeNum = getKeyframePhotoTakesAsTakes().count + 1
        } else {
            // Regular scene photos (if we implement this feature)
            photoSceneNum = currentScene
            photoTakeNum = getKeyframePhotoTakesAsTakes().count + 1
        }
        
        let unifiedTake = UnifiedTake(
            fileName: fileName,
            projectID: projectID,
            sessionID: sessionID,
            filePath: filePath ?? fileName,
            duration: 0, // Photos have 0 duration
            fileSize: fileSize,
            cameraPosition: cameraPosition,
            sceneNumber: photoSceneNum,     // FIXED: Use calculated photo scene number
            takeNumber: photoTakeNum,       // FIXED: Use calculated photo take number
            isSlate: false,                 // Photos are not slate takes
            isPhoto: true,                  // This is a photo
            isKeyframePhoto: isRecordingKeyframePhoto,
            capturedOrientation: capturedOrientation,  // NEW: Store captured orientation
            rating: .unrated,
            notes: notes
        )
        
        if useUnifiedModels {
            unifiedTakes.append(unifiedTake)
        } else {
            // Convert to legacy for compatibility
            activeTakes.append(unifiedTake.toEnhancedTake())
        }
        
        let orientationStr = capturedOrientation?.displayName ?? "Unknown"
        print("📸 SessionManager: Added unified photo take with orientation \(fileName) - Scene: \(photoSceneNum), Take: \(photoTakeNum), Keyframe: \(isRecordingKeyframePhoto), Orientation: \(orientationStr)")
        
        // Persist to repository
        persistUnifiedTakeToRepository(unifiedTake)
        
        // Update keyframe photo recorded status
        if isRecordingKeyframePhoto {
            hasRecordedKeyframePhoto = true
        }

        recomputeCaptureCompletionFlagsFromUnifiedTakes()
    }
    
    // CRITICAL FIX: Add method to calculate proper take organization
    private func calculateTakeOrganization() -> (sceneNumber: Int, takeNumber: Int, slateNumber: String?, slateID: String?) {
        if isRecordingSlate {
            // PHASE 1B FIX: Session-wide slate numbering instead of scene-based
            // BEFORE: Sequential slate numbering within scene (WRONG - creates S1SL1, S2SL1)
            // AFTER: Session-wide slate numbering (CORRECT - creates SLATE1, SLATE2, SLATE3)
            let sessionSlateCount = getSlateTakesAsTakes().count + 1  // All slates in session
            
            // PHASE 1B FIX: Create proper session-wide slate identifiers
            let slateNumberStr = "\(sessionSlateCount)"      // "1", "2", "3"
            let slateID = "SLATE\(sessionSlateCount)"        // "SLATE1", "SLATE2", "SLATE3"
            
            return (
                sceneNumber: -2,                    // PHASE 1B FIX: Special scene number for slates (-2 for session-wide slates)
                takeNumber: sessionSlateCount,      // Sequential slate numbering across entire session
                slateNumber: slateNumberStr,
                slateID: slateID
            )
        } else {
            // CRITICAL FIX: Sequential take numbering within scene - FIXED LOGIC
            let currentSceneTakes = getTakesForScene(currentScene)
            let takeNumber = currentSceneTakes.count + 1
            
            return (
                sceneNumber: currentScene,
                takeNumber: takeNumber,      // Sequential scene take numbering - FIXED
                slateNumber: nil,
                slateID: nil
            )
        }
    }
    
    // ENHANCED: Computed property for effective take count
    private var effectiveTakeCount: Int {
        return useUnifiedModels ? unifiedTakes.count : activeTakes.count
    }
    
    // FIXED: Add method to remove take if it exists (for metadata updates)
    func removeTakeIfExists(fileName: String) {
        if useUnifiedModels {
            if let index = unifiedTakes.firstIndex(where: { $0.fileName == fileName }) {
                unifiedTakes.remove(at: index)
                print("🗑️ SessionManager: Removed existing unified take \(fileName) for metadata update")
            }
        } else {
            if let index = activeTakes.firstIndex(where: { $0.fileName == fileName }) {
                activeTakes.remove(at: index)
                print("🗑️ SessionManager: Removed existing take \(fileName) for metadata update")
            }
        }
    }
    
    // ENHANCED: Unified persistence method - CRITICAL FIX for scene organization and UUID consistency
    private func persistUnifiedTakeToRepository(_ unifiedTake: UnifiedTake) {
        guard let repository = repository else {
            print("⚠️ SessionManager: No repository configured, unified take not persisted!")
            return
        }
        if isArchived(projectID: unifiedTake.projectID, sessionID: unifiedTake.sessionID) {
            print("🚫 SessionManager: Blocked persisting take because project/session is archived (project=\(unifiedTake.projectID) session=\(unifiedTake.sessionID))")
            return
        }
        let persistStart = CFAbsoluteTimeGetCurrent()
        
        // CRITICAL FIX: Convert UnifiedTake to ProjectTake with proper scene organization AND CONSISTENT UUID
        let projectTake = ProjectTake(
            id: unifiedTake.id,                      // CRITICAL FIX: Use the same UUID from UnifiedTake!
            filePath: unifiedTake.filePath,
            durationSeconds: unifiedTake.duration,
            thumbnailPath: nil,
            takeNotes: unifiedTake.notes,
            createdAt: unifiedTake.createdAt,
            videoMarkers: [], // Video markers will be handled later
            rating: unifiedTake.rating,
            sceneNumber: unifiedTake.sceneNumber,    // CRITICAL FIX: Preserve scene number
            takeNumber: unifiedTake.takeNumber,      // CRITICAL FIX: Preserve take number
            slateNumber: unifiedTake.slateNumber,    // CRITICAL FIX: Preserve slate number
            slateID: unifiedTake.slateID,           // CRITICAL FIX: Preserve slate ID
            capturedOrientation: unifiedTake.capturedOrientation,  // CRITICAL FIX: Preserve orientation
            takeType: unifiedTake.isSlate ? .slate : .regular  // CRITICAL FIX: Set take type (must come after capturedOrientation)
        )
        
        repository.addTake(projectTake, to: unifiedTake.sessionID, in: unifiedTake.projectID)
        let repoMutationDuration = CFAbsoluteTimeGetCurrent() - persistStart
        
        print(
            String(
                format: "✅ SessionManager: Persisted unified take %@ (S%dT%d) in %.3f s",
                unifiedTake.fileName,
                unifiedTake.sceneNumber,
                unifiedTake.takeNumber,
                repoMutationDuration
            )
        )
#if DEBUG
        debugLogRepositoryEvent("persistUnifiedTake", sessionID: unifiedTake.sessionID, projectID: unifiedTake.projectID, take: projectTake)
#endif
        postRepositoryUpdate(projectID: unifiedTake.projectID, sessionID: unifiedTake.sessionID)
    }
    
    // EXISTING: Keep original persistence method - CLEANED and FIXED for UUID consistency
    private func persistTakeToRepository(_ enhancedTake: EnhancedTake) {
        guard let repository = repository else {
            print("⚠️ SessionManager: No repository configured, take not persisted!")
            return
        }
        if isArchived(projectID: enhancedTake.projectID, sessionID: enhancedTake.sessionID) {
            print("🚫 SessionManager: Blocked persisting take because project/session is archived (project=\(enhancedTake.projectID) session=\(enhancedTake.sessionID))")
            return
        }
        
        // CRITICAL FIX: Convert EnhancedTake to ProjectTake using SAME UUID and rating directly
        let projectTake = ProjectTake(
            id: enhancedTake.id,                     // CRITICAL FIX: Use the same UUID!
            filePath: enhancedTake.filePath,
            durationSeconds: enhancedTake.duration,
            thumbnailPath: nil,
            takeNotes: enhancedTake.notes,
            rating: enhancedTake.rating             // CLEANED: Direct rating assignment!
        )
        
        let persistStart = CFAbsoluteTimeGetCurrent()
        repository.addTake(projectTake, to: enhancedTake.sessionID, in: enhancedTake.projectID)
        let repoMutationDuration = CFAbsoluteTimeGetCurrent() - persistStart
        
        print(
            String(
                format: "✅ SessionManager: Persisted legacy take %@ in %.3f s",
                enhancedTake.fileName,
                repoMutationDuration
            )
        )
#if DEBUG
        debugLogRepositoryEvent("persistEnhancedTake", sessionID: enhancedTake.sessionID, projectID: enhancedTake.projectID, take: projectTake)
#endif
        postRepositoryUpdate(projectID: enhancedTake.projectID, sessionID: enhancedTake.sessionID)
    }

    private func postRepositoryUpdate(projectID: UUID, sessionID: UUID) {
#if DEBUG
        debugLogRepositoryEvent("postNotification", sessionID: sessionID, projectID: projectID, take: nil)
#endif
        let notifyStart = CFAbsoluteTimeGetCurrent()
        NotificationCenter.default.post(
            name: .stsSessionRepositoryDidUpdate,
            object: nil,
            userInfo: [
                "projectID": projectID,
                "sessionID": sessionID
            ]
        )
        let notifyDuration = CFAbsoluteTimeGetCurrent() - notifyStart
        let projectSnippet = String(projectID.uuidString.prefix(8))
        let sessionSnippet = String(sessionID.uuidString.prefix(8))
        print(
            String(
                format: "📢 SessionManager: Posted repository update proj=%@ sess=%@ in %.4f s",
                projectSnippet,
                sessionSnippet,
                notifyDuration
            )
        )
    }
    
    // ENHANCED: Batch persist with unified support
    private func persistAllTakesToRepository() {
        // SWIFT 6 FIX: Replace unused guard let with nil check
        guard repository != nil else {
            print("⚠️ SessionManager: No repository configured, takes not persisted!")
            return
        }
        let batchStart = CFAbsoluteTimeGetCurrent()
        
        if useUnifiedModels {
            print("📹 SessionManager: Persisting \(unifiedTakes.count) unified takes to repository...")
            for unifiedTake in unifiedTakes {
                persistUnifiedTakeToRepository(unifiedTake)
            }
        } else {
            print("📹 SessionManager: Persisting \(activeTakes.count) takes to repository...")
            for enhancedTake in activeTakes {
                persistTakeToRepository(enhancedTake)
            }
        }
        
        let batchDuration = CFAbsoluteTimeGetCurrent() - batchStart
        print(String(format: "✅ SessionManager: All takes persisted to repository in %.3f s", batchDuration))
    }
    
    // MARK: - Scene and Slate Management - REDESIGNED
    
    // REDESIGNED: Switch to slate recording mode
    func switchToSlateMode() {
        ensureMain {
            self.isRecordingSlate = true
            self.isRecordingKeyframePhoto = false // Ensure only one mode active
        }
        print("📹 SessionManager: Switched to slate recording mode")
    }
    
    // REDESIGNED: Switch to scene recording mode
    func switchToSceneMode() {
        ensureMain {
            self.isRecordingSlate = false
            self.isRecordingKeyframePhoto = false // Ensure only one mode active
        }
        print("📹 SessionManager: Switched to scene recording mode")
    }
    
    // NEW: Switch to keyframe photo mode
    func switchToKeyframePhotoMode() {
        ensureMain {
            self.isRecordingSlate = false
            self.isRecordingKeyframePhoto = true
        }
        print("📸 SessionManager: Switched to keyframe photo mode")
    }

#if DEBUG
    private func debugLogRepositoryEvent(_ label: String, sessionID: UUID, projectID: UUID, take: ProjectTake?) {
        if let take {
            let durationString = String(format: "%.2f", take.durationSeconds)
            print("🧭 SessionManager[\(label)]: proj=\(shortID(projectID)) sess=\(shortID(sessionID)) type=\(take.takeType.rawValue) scene=\(take.sceneNumber) take=\(take.takeNumber) duration=\(durationString)")
        } else {
            print("🧭 SessionManager[\(label)]: proj=\(shortID(projectID)) sess=\(shortID(sessionID))")
        }
    }
    
    private func shortID(_ id: UUID) -> String {
        String(id.uuidString.prefix(8))
    }
#endif

    func saveSlatePrompt(_ prompt: String?, projectID: UUID, sessionID: UUID) {
        let trimmed = prompt?.slateTrimmedNonEmpty
        let mode: SlatePromptMode = trimmed == nil ? .auto : .custom
        saveSlatePromptConfiguration(
            mode: mode,
            override: trimmed,
            inputsHash: nil,
            updatedAt: Date(),
            projectID: projectID,
            sessionID: sessionID
        )
    }

    func saveSlatePromptConfiguration(
        mode: SlatePromptMode,
        override: String?,
        inputsHash: String?,
        updatedAt: Date,
        projectID: UUID,
        sessionID: UUID,
        lastCustomPrompt: String? = nil,
        clearLastCustomPrompt: Bool = false
    ) {
        if let repository {
            if let project = repository.project(by: projectID),
               var session = project.sessions.first(where: { $0.id == sessionID }) {
                session.slatePromptMode = mode
                session.slatePromptOverride = override
                session.slatePromptUpdatedAt = updatedAt
                session.slatePrompt = mode == .custom ? override : nil
                if let inputsHash {
                    session.slatePromptInputsHash = inputsHash
                }
                if clearLastCustomPrompt {
                    session.lastCustomSlatePrompt = nil
                } else if let lastCustomPrompt {
                    session.lastCustomSlatePrompt = lastCustomPrompt
                } else if mode == .custom {
                    session.lastCustomSlatePrompt = override
                }
                repository.updateSession(session, in: projectID)
            } else {
                print("⚠️ saveSlatePromptConfiguration: Session not found for update")
            }
        } else {
            print("⚠️ saveSlatePromptConfiguration: No repository available")
        }

        if var current = currentSession,
           current.project.id == projectID,
           current.session.id == sessionID {
            var session = current.session
            session.slatePromptMode = mode
            session.slatePromptOverride = override
            session.slatePromptUpdatedAt = updatedAt
            session.slatePrompt = mode == .custom ? override : nil
            if let inputsHash {
                session.slatePromptInputsHash = inputsHash
            }
            if clearLastCustomPrompt {
                session.lastCustomSlatePrompt = nil
            } else if let lastCustomPrompt {
                session.lastCustomSlatePrompt = lastCustomPrompt
            } else if mode == .custom {
                session.lastCustomSlatePrompt = override
            }
            current.session = session
#if DEBUG
            print("🧭 SessionManager.currentSession update saveSlatePromptConfiguration project=\(projectID) session=\(sessionID)")
#endif
            ensureMain { self.currentSession = current }
        }
    }

    func savePIPSlateSession(_ pipSession: SlatePIPSession?, projectID: UUID, sessionID: UUID) {
        guard let repository = repository else {
            print("⚠️ savePIPSlateSession: No repository available")
            return
        }

        let portrait = pipSession?.portraitTakes.count ?? 0
        let landscape = pipSession?.landscapeTakes.count ?? 0
        print("💾 savePIPSlateSession: portrait=\(portrait) landscape=\(landscape)")

        if var current = currentSession,
           current.project.id == projectID,
           current.session.id == sessionID {

            var updated = current.session
            updated.pipSlateSession = pipSession
            current.session = updated
            currentSession = current

#if DEBUG
            print("🧭 SessionManager.currentSession update savePIPSlateSession project=\(projectID) session=\(sessionID)")
#endif
            print("   ↪️ Updated currentSession")

        } else if var stored = repository.project(by: projectID)?
            .sessions.first(where: { $0.id == sessionID }) {

            stored.pipSlateSession = pipSession

            print("   ↪️ Updated repository snapshot")
        }

        repository.updatePIPSlateSession(
            projectID: projectID,
            sessionID: sessionID,
            pipSlateSession: pipSession
        )
        print("   ✅ repository.updatePIPSlateSession called")

        if let pipSession {
            let portraitNames = pipSession.portraitTakes.map { $0.fileURL.lastPathComponent }
            let landscapeNames = pipSession.landscapeTakes.map { $0.fileURL.lastPathComponent }
            print("   📁 PIP portrait takes: \(portraitNames)")
            print("   📁 PIP landscape takes: \(landscapeNames)")
            print("   🎯 Selected portrait: \(pipSession.selectedPortraitID?.uuidString ?? "nil")")
            print("   🎯 Selected landscape: \(pipSession.selectedLandscapeID?.uuidString ?? "nil")")
        }
    }
    
    @discardableResult
    func storePIPCompositeTake(
        from exportURL: URL,
        duration: TimeInterval,
        project: Project,
        session: ProjectSession,
        selectedPortrait: PIPSlateTake,
        selectedLandscape: PIPSlateTake,
        pipMetadata: PIPSlateCompositeMetadata? = nil
    ) throws -> ProjectTake {
        guard let repository = repository else { throw SessionManagerError.repositoryUnavailable }
        
        let sanitizedExtension = exportURL.pathExtension.isEmpty ? "mp4" : exportURL.pathExtension
        let nextSlateNumber = max(1, repository.nextSlateNumber(in: session.id, in: project.id))
        let slateNumber = "\(nextSlateNumber)"
        let slateID = "SLATE\(nextSlateNumber)"
        let projectPrefix = String(project.id.uuidString.prefix(8))
        let sessionPrefix = String(session.id.uuidString.prefix(8))
        let timestamp = Int(Date().timeIntervalSince1970)
        let fileName = "\(projectPrefix)_\(sessionPrefix)_\(slateID)_PIP\(timestamp).\(sanitizedExtension)"
        
        let portraitName = URL(fileURLWithPath: selectedPortrait.filePath).lastPathComponent
        let landscapeName = URL(fileURLWithPath: selectedLandscape.filePath).lastPathComponent
        let note = "PiP composite from \(portraitName) + \(landscapeName)"
        
        let metadata = VideoMetadata(
            projectTitle: project.title,
            roleName: session.roleName ?? project.roles.first?.name,
            sceneNumber: -2,
            takeNumber: nextSlateNumber,
            rating: .finalSelect,
            duration: max(0, duration),
            recordingDate: Date(),
            cameraPosition: "back",
            notes: note
        )
        
        let savedVideo = try VideoFileManager.shared.saveVideo(
            from: exportURL,
            projectID: project.id,
            sessionID: session.id,
            fileName: fileName,
            metadata: metadata
        )
        
        let relativePath = VideoVariantResolver.relativePath(from: savedVideo.url)
        var projectTake = ProjectTake(
            filePath: relativePath,
            durationSeconds: metadata.duration,
            takeNotes: metadata.notes,
            createdAt: Date(),
            rating: .finalSelect,
            sceneNumber: -2,
            takeNumber: nextSlateNumber,
            slateNumber: slateNumber,
            slateID: slateID,
            capturedOrientation: .landscape,
            takeType: .pipSlate
        )
        // PiP Save is explicit user intent: mark composite as Final Select by default.
        projectTake.pipSlateMetadata = pipMetadata
        
        repository.addTake(projectTake, to: session.id, in: project.id)
        postRepositoryUpdate(projectID: project.id, sessionID: session.id)
        
        if var current = currentSession,
           current.project.id == project.id,
           current.session.id == session.id {
            var updatedSession = current.session
            updatedSession.takes.append(projectTake)
            current.session = updatedSession
            currentSession = current
#if DEBUG
            print("🧭 SessionManager.currentSession update storePIPCompositeTake project=\(project.id) session=\(session.id)")
#endif
        }
        
        print("🎬 SessionManager: Stored PiP composite slate \(fileName) [\(slateID)]")
        return projectTake
    }

    func storedSlatePrompt(for projectID: UUID, sessionID: UUID) -> String? {
        if let prompt = currentSessionPrompt(projectID: projectID, sessionID: sessionID),
           let trimmed = normalizedPrompt(prompt) {
            return trimmed
        }
        if let prompt = repository?.project(by: projectID)?
            .sessions.first(where: { $0.id == sessionID })?.slatePrompt,
           let trimmed = normalizedPrompt(prompt) {
            return trimmed
        }
        return nil
    }
    
    private func currentSessionPrompt(projectID: UUID, sessionID: UUID) -> String? {
        guard let current = currentSession,
              current.project.id == projectID,
              current.session.id == sessionID else {
            return nil
        }
        return current.session.slatePrompt
    }
    
    private func normalizedPrompt(_ prompt: String?) -> String? {
        guard let prompt else { return nil }
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
    
    // REDESIGNED: Get current recording mode description - ENHANCED: Photo support
    var currentRecordingMode: String {
        if isRecordingKeyframePhoto {
            return "Keyframe Photo"
        } else if isRecordingSlate {
            return "Slate"
        } else {
            return "Scene \(currentScene)"
        }
    }
    
    // EXISTING: Keep for backwards compatibility - CRITICAL FIX
    func enableSlateForNextTake() {
        switchToSlateMode()
        print("⚠️ SessionManager: enableSlateForNextTake() is deprecated, use switchToSlateMode()")
    }
    
    func skipSlateForSession() {
        ensureMain {
            self.slateSkippedForSession = true
            self.isRecordingSlate = false
        }
        print("📹 SessionManager: Slate skipped for this session")
    }
    
    func nextScene() {
        ensureMain {
            self.isRecordingSlate = false // Ensure we're in scene mode
            self.isRecordingKeyframePhoto = false // FIXED: Also ensure we're not in keyframe photo mode
            self.currentScene += 1
            if self.currentScene > self.totalScenes {
                self.totalScenes = self.currentScene
            }
            print("📹 SessionManager: Advanced to scene \(self.currentScene)")
        }
    }
    
    func previousScene() {
        ensureMain {
            self.isRecordingSlate = false // Ensure we're in scene mode
            self.isRecordingKeyframePhoto = false // FIXED: Also ensure we're not in keyframe photo mode
            if self.currentScene > 1 {
                self.currentScene -= 1
            }
            print("📹 SessionManager: Returned to scene \(self.currentScene)")
        }
    }
    
    func switchToScene(_ sceneNumber: Int) {
        ensureMain {
            self.isRecordingSlate = false // Ensure we're in scene mode
            self.isRecordingKeyframePhoto = false // FIXED: Also ensure we're not in keyframe photo mode
            self.currentScene = sceneNumber
            if sceneNumber > self.totalScenes {
                self.totalScenes = sceneNumber
            }
            print("📹 SessionManager: Switched to scene \(sceneNumber)")
        }
    }
    
    // PHASE 1B FIX: Add method to restore scene state when resuming sessions
    public func restoreSceneState(sceneNumber: Int) {
        ensureMain {
            self.isRecordingSlate = false // Ensure we're in scene mode
            self.isRecordingKeyframePhoto = false // Ensure we're not in photo mode
            self.currentScene = sceneNumber
            if sceneNumber > self.totalScenes {
                self.totalScenes = sceneNumber
            }
            print("🎬 SessionManager: Restored scene state to scene \(sceneNumber)")
        }
    }
    
    // MARK: - Backwards Compatibility - CRITICAL SECTION
    
    // DEPRECATED: For backwards compatibility with existing code that checks isSlateNext
    var isSlateNext: Bool {
        return isRecordingSlate
    }
    
    // REDESIGNED: Get takes with slate separation
    func getTakesForCurrentScene() -> [Take] {
        if isRecordingSlate {
            return getSlateTakesAsTakes()
        } else {
            return getTakesForScene(currentScene)
        }
    }
    
    func getTakesForScene(_ sceneNumber: Int) -> [Take] {
        if useUnifiedModels {
            // Convert UnifiedTakes to Takes for UI compatibility - filter out slate takes
            return unifiedTakes.filter { $0.sceneNumber == sceneNumber && !$0.isSlate }.map { unifiedTake in
                Take(
                    segmentId: unifiedTake.sessionID,
                    fileName: unifiedTake.fileName,
                    filePath: unifiedTake.filePath,
                    duration: unifiedTake.duration,
                    takeNumber: unifiedTake.takeNumber,
                    sceneNumber: unifiedTake.sceneNumber,
                    rating: unifiedTake.rating,
                    createdAt: unifiedTake.createdAt
                )
            }
        } else {
            // Convert EnhancedTakes to Takes for compatibility - filter out slate takes
            return activeTakes.filter { $0.sceneNumber == sceneNumber && !$0.isSlate }
                .map { enhancedTake in
                    Take(
                        segmentId: enhancedTake.sessionID,
                        fileName: enhancedTake.fileName,
                        filePath: enhancedTake.filePath,
                        duration: enhancedTake.duration,
                        takeNumber: enhancedTake.takeNumber,
                        sceneNumber: enhancedTake.sceneNumber,
                        rating: enhancedTake.rating,
                        createdAt: enhancedTake.createdAt
                    )
                }
        }
    }
    
    // REDESIGNED: Get slate takes as regular Take objects for UI consistency
    func getSlateTakesAsTakes() -> [Take] {
        if useUnifiedModels {
            return unifiedTakes.filter { $0.isSlate }.map { unifiedTake in
                Take(
                    segmentId: unifiedTake.sessionID,
                    fileName: unifiedTake.fileName,
                    filePath: unifiedTake.filePath,
                    duration: unifiedTake.duration,
                    takeNumber: unifiedTake.takeNumber,
                    sceneNumber: 0, // Slate takes use scene 0
                    rating: unifiedTake.rating,
                    createdAt: unifiedTake.createdAt
                )
            }
        } else {
            return activeTakes.filter { $0.isSlate }.map { enhancedTake in
                Take(
                    segmentId: enhancedTake.sessionID,
                    fileName: enhancedTake.fileName,
                    filePath: enhancedTake.filePath,
                    duration: enhancedTake.duration,
                    takeNumber: enhancedTake.takeNumber,
                    sceneNumber: 0, // Slate takes use scene 0
                    rating: enhancedTake.rating,
                    createdAt: enhancedTake.createdAt
                )
            }
        }
    }
    
    // NEW: Get keyframe photo takes as regular Take objects for UI consistency
    func getKeyframePhotoTakesAsTakes() -> [Take] {
        if useUnifiedModels {
            return unifiedTakes.filter { $0.isKeyframePhoto }.map { unifiedTake in
                Take(
                    segmentId: unifiedTake.sessionID,
                    fileName: unifiedTake.fileName,
                    filePath: unifiedTake.filePath,
                    duration: unifiedTake.duration, // Will be 0 for photos
                    takeNumber: unifiedTake.takeNumber,
                    sceneNumber: -1, // Keyframe photos use scene -1
                    rating: unifiedTake.rating,
                    createdAt: unifiedTake.createdAt
                )
            }
        } else {
            // Legacy support: filter by filename pattern since we don't have isKeyframePhoto in EnhancedTake
            return activeTakes.filter { $0.fileName.contains("_Photo_") }.map { enhancedTake in
                Take(
                    segmentId: enhancedTake.sessionID,
                    fileName: enhancedTake.fileName,
                    filePath: enhancedTake.filePath,
                    duration: enhancedTake.duration,
                    takeNumber: enhancedTake.takeNumber,
                    sceneNumber: -1, // Keyframe photos use scene -1
                    rating: enhancedTake.rating,
                    createdAt: enhancedTake.createdAt
                )
            }
        }
    }
    
    // ENHANCED: Unified take retrieval methods
    func getUnifiedTakesForScene(_ sceneNumber: Int) -> [UnifiedTake] {
        if useUnifiedModels {
            return unifiedTakes.filter { $0.sceneNumber == sceneNumber && !$0.isSlate }
        } else {
            return activeTakes.filter { $0.sceneNumber == sceneNumber && !$0.isSlate }
                .map { UnifiedTake(from: $0) }
        }
    }
    
    // MARK: - Enhanced Take Retrieval
    
    // Get latest unified take for thumbnail preview
    public func getLatestUnifiedTake() -> UnifiedTake? {
        guard useUnifiedModels else {
            // Fallback to convert latest legacy take if needed
            guard let latestTake = activeTakes.last else { return nil }
            return UnifiedTake(from: latestTake)
        }
        
        if let latestUnified = unifiedTakes.last {
            return latestUnified
        }
        
        // Fallback: derive latest take from repository if in-memory is empty
        guard
            let repository,
            let currentSession,
            let updatedProject = repository.project(by: currentSession.project.id),
            let updatedSession = updatedProject.sessions.first(where: { $0.id == currentSession.session.id })
        else {
            return nil
        }

        guard !updatedSession.takes.isEmpty else {
            return nil
        }

        let index = updatedSession.takes.count - 1
        let projectTake = updatedSession.takes[index]
        
        let fileName = URL(fileURLWithPath: projectTake.filePath).lastPathComponent
        return try? UnifiedTake.safeConversion(
            from: projectTake,
            projectID: currentSession.project.id,
            sessionID: currentSession.session.id,
            fileName: fileName,
            takeNumber: index + 1
        )
    }
    
    // MARK: - Export Support with UNIFIED SUPPORT
    var takes: [EnhancedTake] {
        if useUnifiedModels {
            return unifiedTakes.map { $0.toEnhancedTake() }
        } else {
            return activeTakes
        }
    }
    
    // ENHANCED: Export unified takes
    var unifiedTakesForExport: [UnifiedTake] {
        if useUnifiedModels {
            return unifiedTakes
        } else {
            return activeTakes.map { UnifiedTake(from: $0) }
        }
    }
    
    // MARK: - Take Rating Management with UNIFIED SUPPORT
    
    func toggleStar(_ take: Take) {
        if useUnifiedModels {
            if let index = unifiedTakes.firstIndex(where: { $0.fileName == take.fileName }) {
                unifiedTakes[index].rating = (unifiedTakes[index].rating == .finalSelect) ? .unrated : .finalSelect
                syncUnifiedRatingToRepository(unifiedTakes[index])
            }
        } else {
            if let index = activeTakes.firstIndex(where: { $0.fileName == take.fileName }) {
                activeTakes[index].rating = (activeTakes[index].rating == .finalSelect) ? .unrated : .finalSelect
                syncRatingToRepository(activeTakes[index])
            }
        }
        
        print("📹 SessionManager: Toggled star for take \(take.fileName)")
    }
    
    func toggleGood(_ take: Take) {
        if useUnifiedModels {
            if let index = unifiedTakes.firstIndex(where: { $0.fileName == take.fileName }) {
                unifiedTakes[index].rating = (unifiedTakes[index].rating == .option) ? .unrated : .option
                syncUnifiedRatingToRepository(unifiedTakes[index])
            }
        } else {
            if let index = activeTakes.firstIndex(where: { $0.fileName == take.fileName }) {
                activeTakes[index].rating = (activeTakes[index].rating == .option) ? .unrated : .option
                syncRatingToRepository(activeTakes[index])
            }
        }
        
        print("📹 SessionManager: Toggled option for take \(take.fileName)")
    }
    
    func markBad(_ take: Take) {
        if useUnifiedModels {
            if let index = unifiedTakes.firstIndex(where: { $0.fileName == take.fileName }) {
                unifiedTakes[index].rating = .rejected
                syncUnifiedRatingToRepository(unifiedTakes[index])
            }
        } else {
            if let index = activeTakes.firstIndex(where: { $0.fileName == take.fileName }) {
                activeTakes[index].rating = .rejected
                syncRatingToRepository(activeTakes[index])
            }
        }
        
        print("📹 SessionManager: Marked bad for take \(take.fileName)")
    }
    
    func resetRating(_ take: Take) {
        if useUnifiedModels {
            if let index = unifiedTakes.firstIndex(where: { $0.fileName == take.fileName }) {
                unifiedTakes[index].rating = .unrated
                syncUnifiedRatingToRepository(unifiedTakes[index])
            }
        } else {
            if let index = activeTakes.firstIndex(where: { $0.fileName == take.fileName }) {
                activeTakes[index].rating = .unrated
                syncRatingToRepository(activeTakes[index])
            }
        }
        
        print("📹 SessionManager: Reset rating for take \(take.fileName)")
    }
    
    func getSlateTakes() -> [EnhancedTake] {
        if useUnifiedModels {
            return unifiedTakes.filter { $0.isSlate }.map { $0.toEnhancedTake() }
        } else {
            return activeTakes.filter { $0.isSlate }
        }
    }
    
    func getUnifiedSlateTakes() -> [UnifiedTake] {
        if useUnifiedModels {
            return unifiedTakes.filter { $0.isSlate }
        } else {
            return activeTakes.filter { $0.isSlate }.map { UnifiedTake(from: $0) }
        }
    }
    
    func getStarredTakes() -> [EnhancedTake] {
        if useUnifiedModels {
            return unifiedTakes.filter { $0.rating == .finalSelect }.map { $0.toEnhancedTake() }
        } else {
            return activeTakes.filter { $0.rating == .finalSelect }
        }
    }
    
    func getUnifiedStarredTakes() -> [UnifiedTake] {
        if useUnifiedModels {
            return unifiedTakes.filter { $0.rating == .finalSelect }
        } else {
            return activeTakes.filter { $0.rating == .finalSelect }.map { UnifiedTake(from: $0) }
        }
    }
    
    func getGoodTakes() -> [EnhancedTake] {
        if useUnifiedModels {
            return unifiedTakes.filter { $0.rating == .option }.map { $0.toEnhancedTake() }
        } else {
            return activeTakes.filter { $0.rating == .option }
        }
    }
    
    func getBadTakes() -> [EnhancedTake] {
        if useUnifiedModels {
            return unifiedTakes.filter { $0.rating == .rejected }.map { $0.toEnhancedTake() }
        } else {
            return activeTakes.filter { $0.rating == .rejected }
        }
    }
    
    func exportSelectedTakes() -> [EnhancedTake] {
        if useUnifiedModels {
            let selectedTakes = unifiedTakes.filter { $0.isExportSelected }
            print("📹 SessionManager: Exporting \(selectedTakes.count) selected unified takes")
            return selectedTakes.map { $0.toEnhancedTake() }
        } else {
            let selectedTakes = activeTakes.filter { $0.isExportSelected }
            print("📹 SessionManager: Exporting \(selectedTakes.count) selected takes")
            return selectedTakes
        }
    }
    
    func exportSelectedUnifiedTakes() -> [UnifiedTake] {
        if useUnifiedModels {
            let selectedTakes = unifiedTakes.filter { $0.isExportSelected }
            print("📹 SessionManager: Exporting \(selectedTakes.count) selected unified takes")
            return selectedTakes
        } else {
            let selectedTakes = activeTakes.filter { $0.isExportSelected }
            print("📹 SessionManager: Exporting \(selectedTakes.count) selected takes as unified")
            return selectedTakes.map { UnifiedTake(from: $0) }
        }
    }
    
    func exportAllTakes() -> [EnhancedTake] {
        if useUnifiedModels {
            print("📹 SessionManager: Exporting all \(unifiedTakes.count) unified takes")
            return unifiedTakes.map { $0.toEnhancedTake() }
        } else {
            print("📹 SessionManager: Exporting all \(activeTakes.count) takes")
            return activeTakes
        }
    }
    
    func exportAllUnifiedTakes() -> [UnifiedTake] {
        if useUnifiedModels {
            print("📹 SessionManager: Exporting all \(unifiedTakes.count) unified takes")
            return unifiedTakes
        } else {
            print("📹 SessionManager: Exporting all \(activeTakes.count) takes as unified")
            return activeTakes.map { UnifiedTake(from: $0) }
        }
    }
    
    // ENHANCED: Unified rating sync method - CLEANED
    private func syncUnifiedRatingToRepository(_ unifiedTake: UnifiedTake) {
        guard let repository = repository else { return }
        
        // CLEANED: Direct rating update through unified API
        repository.setUnifiedTakeRating(
            takeID: unifiedTake.id,
            sessionID: unifiedTake.sessionID,
            projectID: unifiedTake.projectID,
            rating: unifiedTake.rating
        )
        
        print("✅ SessionManager: Synced unified rating change to repository")
    }
    
    // EXISTING: Keep original rating sync method - CLEANED
    private func syncRatingToRepository(_ enhancedTake: EnhancedTake) {
        guard let repository = repository else { return }
        
        // CLEANED: Direct rating update through unified API
        repository.setUnifiedTakeRating(
            takeID: enhancedTake.id,
            sessionID: enhancedTake.sessionID,
            projectID: enhancedTake.projectID,
            rating: enhancedTake.rating
        )
        
        print("✅ SessionManager: Synced rating change to repository")
    }
    
    // Add delete method that takes Take parameter for UI compatibility
    func delete(_ take: Take) {
        if useUnifiedModels {
            if let index = unifiedTakes.firstIndex(where: { $0.fileName == take.fileName }) {
                let unifiedTake = unifiedTakes[index]
                
                // Delete video file if it exists
                do {
                    try VideoFileManager.shared.deleteVideo(at: unifiedTake.filePath)
                } catch {
                    print("⚠️ Could not delete video file: \(error)")
                }
                
                // Remove from unified takes
                unifiedTakes.remove(at: index)
            }
        } else {
            if let index = activeTakes.firstIndex(where: { $0.fileName == take.fileName }) {
                let enhancedTake = activeTakes[index]
                
                // Delete video file if it exists
                do {
                    try VideoFileManager.shared.deleteVideo(at: enhancedTake.filePath)
                } catch {
                    print("⚠️ Could not delete video file: \(error)")
                }
                
                // Remove from active takes
                activeTakes.remove(at: index)
            }
        }
        
        recomputeCaptureCompletionFlagsFromUnifiedTakes()
        print("📹 SessionManager: Deleted take \(take.fileName)")
    }
    
    // MARK: - Session Validation (PRESERVED)
    func canCompleteSession() -> Bool {
        if slateSkippedForSession || hasRecordedSlate {
            return true
        }
        // Require slate unless explicitly skipped
        return false
    }
    
    // MARK: - Repository Integration Methods
    
    // CORE INTEGRATION FIX: Ensure project and session exist in repository
    public func ensureProjectAndSessionInRepository(project: Project, session: ProjectSession) {
        guard let repository = repository else {
            print("⚠️ SessionManager: No repository configured, cannot ensure project/session exists!")
            return
        }
        
        // Check if project exists, if not add it
        if repository.project(by: project.id) == nil {
            print("📁 SessionManager: Adding project \(project.title) to repository")
            repository.insert(project: project)
        } else {
            print("📁 SessionManager: Project \(project.title) already exists in repository")
        }
        
        // Check if session exists in the project
        if let existingProject = repository.project(by: project.id) {
            let sessionExists = existingProject.sessions.contains { $0.id == session.id }
            if !sessionExists {
                print("📁 SessionManager: Adding session \(session.type.rawValue) to project \(project.title)")
                repository.append(session: session, to: project.id)
            } else {
                print("📁 SessionManager: Session \(session.type.rawValue) already exists in project")
            }
        }
        
        print("✅ SessionManager: Project and session ensured in repository")
    }
    
    // UNIFIED RATING API: The ONLY method that should be used for take ratings - ENHANCED for Step 3C + PHASE 1C-C
    public func setUnifiedTakeRating(
        takeID: UUID,
        sessionID: UUID,
        projectID: UUID,
        rating: TakeRating
    ) {
        print("🔄 SessionManager: Setting unified rating \(rating.rawValue) for take \(takeID)")
        ensureMain {
            self.ratingOverrides[takeID] = rating
        }
        
        // STEP 3C: Enhanced error handling and validation
        guard let repository = repository else {
            print("❌ SessionManager: No repository configured, rating update failed!")
            return
        }
        
        // STEP 3C: Validate IDs before proceeding
        guard takeID != UUID(), sessionID != UUID(), projectID != UUID() else {
            print("❌ SessionManager: Invalid IDs provided for rating update")
            return
        }
        
        let currentSessionID = currentSession?.session.id
        let currentProjectID = currentSession?.project.id
        let hasTakeInState = unifiedTakes.contains(where: { $0.id == takeID })
            || activeTakes.contains(where: { $0.id == takeID })
        let shouldSyncInternalState = currentSessionID == sessionID
            && currentProjectID == projectID
            && hasTakeInState

        // PHASE 1C-C: CRITICAL FIX - Photo Mutual Exclusion Validation
        if rating == .finalSelect, shouldSyncInternalState {
            applyPhotoMutualExclusionIfNeeded(
                targetTakeID: takeID,
                sessionID: sessionID,
                projectID: projectID
            )
        }
        
        // CRITICAL FIX: Update repository first (single source of truth)
        repository.setUnifiedTakeRating(
            takeID: takeID,
            sessionID: sessionID,
            projectID: projectID,
            rating: rating
        )

        RatingEducationGate.triggerIfNeeded(rating: rating)
        
        if shouldSyncInternalState {
            // STEP 3C: Enhanced internal state sync with better error handling
            syncRatingToInternalStateWithValidation(takeID: takeID, rating: rating)
            
            // CRITICAL FIX: Immediately sync ALL data from repository to ensure consistency
            syncFromRepositoryWithErrorHandling()
        } else {
            let currentSessionString = currentSessionID?.uuidString ?? "nil"
            let currentProjectString = currentProjectID?.uuidString ?? "nil"
            print("ℹ️ SessionManager: Skipping internal rating sync (currentSession=\(currentSessionString), currentProject=\(currentProjectString), targetSession=\(sessionID), targetProject=\(projectID), takeInState=\(hasTakeInState))")
        }
        
        // STEP 3C: Send enhanced notification with comprehensive data
        sendRatingUpdateNotification(
            takeID: takeID,
            sessionID: sessionID,
            projectID: projectID,
            rating: rating
        )
        
        print("✅ SessionManager: Bidirectional rating sync completed for take \(takeID)")
    }

    public func effectiveRating(for takeID: UUID, fallback: TakeRating) -> TakeRating {
        if let override = ratingOverrides[takeID] {
            if override == fallback {
                if Thread.isMainThread {
                    ratingOverrides.removeValue(forKey: takeID)
#if DEBUG
                    ratingOverrideClearedCount += 1
#endif
                } else {
                    ensureMain {
                        self.ratingOverrides.removeValue(forKey: takeID)
#if DEBUG
                        self.ratingOverrideClearedCount += 1
#endif
                    }
                }
                return fallback
            }
#if DEBUG
            print("🧪 EffectiveRating take=\(takeID) override=\(override.rawValue) persisted=\(fallback.rawValue) chosen=\(override.rawValue)")
            let now = Date()
            let logBlock = { [weak self] in
                guard let self else { return }
                self.ratingOverrideUseCount += 1
                if now.timeIntervalSince(self.ratingOverrideWindowStart) >= 30 {
                    print("🧪 EffectiveRating override usage: \(self.ratingOverrideUseCount) in last 30s (cleared=\(self.ratingOverrideClearedCount))")
                    self.ratingOverrideUseCount = 0
                    self.ratingOverrideClearedCount = 0
                    self.ratingOverrideWindowStart = now
                }
            }
            if Thread.isMainThread {
                logBlock()
            } else {
                ensureMain {
                    logBlock()
                }
            }
#endif
            return override
        }
        return fallback
    }

    public func effectiveRating(for takeID: UUID) -> TakeRating? {
        if let take = currentSession?.session.takes.first(where: { $0.id == takeID }) {
            return effectiveRating(for: take.id, fallback: take.rating)
        }
        if let unified = unifiedTakes.first(where: { $0.id == takeID }) {
            return effectiveRating(for: takeID, fallback: unified.rating)
        }
        if let legacy = activeTakes.first(where: { $0.id == takeID }) {
            return effectiveRating(for: takeID, fallback: legacy.rating)
        }
        return ratingOverrides[takeID]
    }

    public func effectiveRating(for take: ProjectTake) -> TakeRating? {
        effectiveRating(for: take.id, fallback: take.rating)
    }

    public func setRating(
        _ rating: TakeRating?,
        for takeID: UUID,
        sessionID: UUID? = nil,
        projectID: UUID? = nil,
        source: String? = nil
    ) {
        let resolvedRating = rating ?? .unrated
        let resolvedSessionID = sessionID ?? currentSession?.session.id
        let resolvedProjectID = projectID ?? currentSession?.project.id

        guard let resolvedSessionID, let resolvedProjectID else {
            let sourceLabel = source ?? "unknown"
            print("⚠️ SessionManager.setRating: Missing session/project for take \(takeID) source=\(sourceLabel)")
            return
        }

#if DEBUG
        if let source {
            print("🧪 RatingSource=\(source) session=\(resolvedSessionID) project=\(resolvedProjectID) take=\(takeID)")
        }
#endif

        setUnifiedTakeRating(
            takeID: takeID,
            sessionID: resolvedSessionID,
            projectID: resolvedProjectID,
            rating: resolvedRating
        )
    }

    public func takes(
        for context: TakeQueryContext,
        filter: TakeFilter,
        session: ProjectSession? = nil
    ) -> [ProjectTake] {
        let session = session ?? currentSession?.session
        guard let session else { return [] }

        let base: [ProjectTake]
        switch context {
        case .scenes:
            base = session.takes.filter { $0.takeType == .regular && $0.durationSeconds > 0 }
        case .scene(let sceneNumber):
            base = session.takes.filter {
                $0.takeType == .regular
                && $0.durationSeconds > 0
                && $0.sceneNumber == sceneNumber
            }
        case .slates:
            base = slateTakes(in: session)
        case .slate(let slateFilter):
            let ordered = slateTakes(in: session).sorted { $0.createdAt > $1.createdAt }
            base = ordered.filter { take in
                switch slateFilter {
                case .pip:
                    return take.isPiPComposite
                case .smartFill:
                    return take.isSmartFillVariant || take.smartFilledFilePath != nil
                case .standard:
                    return !take.isPiPComposite && !take.isSmartFillVariant && take.smartFilledFilePath == nil
                }
            }
        case .photosKeyframes:
            base = session.takes.filter { isKeyframePhotoCandidate($0) }
        }

        guard !filter.allowedRatings.isEmpty else { return base }
        return base.filter { take in
            let rating = effectiveRating(for: take)
            let mapped = ratingFilter(for: rating)
            return filter.allowedRatings.contains(mapped)
        }
    }

    private func ratingFilter(for rating: TakeRating?) -> TakeRatingFilter {
        guard let rating else { return .unrated }
        switch rating {
        case .finalSelect:
            return .star
        case .option:
            return .check
        case .rejected:
            return .x
        case .unrated:
            return .unrated
        }
    }

    private func slateTakes(in session: ProjectSession) -> [ProjectTake] {
        session.takes.filter { $0.takeType.isSlateLike && !isPIPComponent($0, in: session) }
    }

    private func isPIPComponent(_ take: ProjectTake, in session: ProjectSession) -> Bool {
        if take.takeType.isPIPComponent { return true }
        guard let pip = session.pipSlateSession else { return false }
        let components = pip.portraitTakes + pip.landscapeTakes
        let basenames = Set(components.map { URL(fileURLWithPath: $0.filePath).lastPathComponent.lowercased() })
        let name = URL(fileURLWithPath: take.filePath).lastPathComponent.lowercased()
        return basenames.contains(name)
    }

#if DEBUG
    @MainActor
    public func consumeRatingOverrideMetrics() -> (used: Int, cleared: Int) {
        let used = ratingOverrideUseCount
        let cleared = ratingOverrideClearedCount
        ratingOverrideUseCount = 0
        ratingOverrideClearedCount = 0
        ratingOverrideWindowStart = Date()
        return (used, cleared)
    }
#endif
    
    // PHASE 1C-C: NEW - Photo Mutual Exclusion Logic
    private func applyPhotoMutualExclusionIfNeeded(
        targetTakeID: UUID,
        sessionID: UUID,
        projectID: UUID
    ) {
        // Find the target take being marked as final select
        var targetTakeIsKeyframePhoto = false
        
        // Check in unified takes
        if let targetTake = unifiedTakes.first(where: { $0.id == targetTakeID }) {
            targetTakeIsKeyframePhoto = isKeyframePhotoCandidate(targetTake)
        } else if let targetTake = activeTakes.first(where: { $0.id == targetTakeID }) {
            targetTakeIsKeyframePhoto = isKeyframePhotoCandidate(targetTake)
        }
        
        // Only apply mutual exclusion for keyframe photos
        guard targetTakeIsKeyframePhoto else {
            print("📋 Photo mutual exclusion: Target take is not a keyframe photo - no exclusion needed")
            return
        }
        
        print("📸 PHASE 1C-C: Applying keyframe photo mutual exclusion for take \(targetTakeID)")
        
        // Auto-downgrade other keyframe photos that are marked as final select
        var downgradeCount = 0
        
        // Handle unified takes
        for (index, take) in unifiedTakes.enumerated() {
            if take.id != targetTakeID &&
               isKeyframePhotoCandidate(take) &&
               take.rating == .finalSelect {
                
                // Downgrade this keyframe photo to option (backup)
                unifiedTakes[index].rating = .option
                unifiedTakes[index].isBest = false
                
                // Update repository
                repository?.setUnifiedTakeRating(
                    takeID: take.id,
                    sessionID: sessionID,
                    projectID: projectID,
                    rating: .option
                )
                
                downgradeCount += 1
                print("📸 Downgraded keyframe photo: \(take.fileName) from final select to option")
            }
        }
        
        // Handle legacy takes
        for (index, take) in activeTakes.enumerated() {
            if take.id != targetTakeID &&
               isKeyframePhotoCandidate(take) &&
               take.rating == .finalSelect {
                
                // Downgrade this keyframe photo to option (backup)
                activeTakes[index].rating = .option
                activeTakes[index].isBest = false
                
                // Update repository
                repository?.setUnifiedTakeRating(
                    takeID: take.id,
                    sessionID: sessionID,
                    projectID: projectID,
                    rating: .option
                )
                
                downgradeCount += 1
                print("📸 Downgraded legacy keyframe photo: \(take.fileName) from final select to option")
            }
        }
        
        if downgradeCount > 0 {
            print("✅ PHASE 1C-C: Photo mutual exclusion completed - downgraded \(downgradeCount) other keyframe photo(s)")
            
            // Notify UI of the batch changes
            DispatchQueue.main.async { [weak self] in
                self?.objectWillChange.send()
            }
        } else {
            print("📋 Photo mutual exclusion: No other final select keyframe photos found - no downgrades needed")
        }
    }

    // MARK: - Keyframe Photo Single Final Select (Auto-Heal)
    public func ensureSingleFinalSelectKeyframePhoto(sessionID: UUID, projectID: UUID) {
        guard let repository = repository else { return }
        guard let project = repository.project(by: projectID),
              let session = project.sessions.first(where: { $0.id == sessionID }) else {
            return
        }

        let keyframeCandidates = session.takes.filter { isKeyframePhotoCandidate($0) }
        let finalSelectPhotos = keyframeCandidates.filter { $0.rating == .finalSelect }

        guard finalSelectPhotos.count > 1 else { return }

        let keep = finalSelectPhotos.max(by: { $0.createdAt < $1.createdAt })
        let keepID = keep?.id

        print("📸 Ensuring single final select photo (found \(finalSelectPhotos.count)); keeping \(keepID?.uuidString ?? "nil")")

        for take in finalSelectPhotos where take.id != keepID {
            setUnifiedTakeRating(
                takeID: take.id,
                sessionID: sessionID,
                projectID: projectID,
                rating: .option
            )
        }
    }

    private func isKeyframePhotoCandidate(_ take: ProjectTake) -> Bool {
        guard take.durationSeconds == 0 else { return false }
        if take.takeType.isSlateLike { return false }

        let lowerPath = take.filePath.lowercased()
        if lowerPath.hasSuffix(".jpg") || lowerPath.hasSuffix(".jpeg") || lowerPath.hasSuffix(".png") || lowerPath.hasSuffix(".heic") {
            return true
        }

        if take.isKeyframePhoto { return true }

        if let notes = take.takeNotes?.lowercased(),
           notes.contains("photo") || notes.contains("keyframe") {
            return true
        }

        return !lowerPath.hasSuffix(".mov") && !lowerPath.hasSuffix(".mp4")
    }

    private func isKeyframePhotoCandidate(_ take: UnifiedTake) -> Bool {
        guard take.duration == 0 else { return false }
        if take.isSlate { return false }

        let lowerPath = take.filePath.lowercased()
        if lowerPath.hasSuffix(".jpg") || lowerPath.hasSuffix(".jpeg") || lowerPath.hasSuffix(".png") || lowerPath.hasSuffix(".heic") {
            return true
        }

        if take.isKeyframePhoto { return true }

        if let notes = take.notes?.lowercased(),
           notes.contains("photo") || notes.contains("keyframe") {
            return true
        }

        return !lowerPath.hasSuffix(".mov") && !lowerPath.hasSuffix(".mp4")
    }

    private func isKeyframePhotoCandidate(_ take: EnhancedTake) -> Bool {
        guard take.duration == 0 else { return false }
        if take.isSlate { return false }

        let lowerPath = take.filePath.lowercased()
        if lowerPath.hasSuffix(".jpg") || lowerPath.hasSuffix(".jpeg") || lowerPath.hasSuffix(".png") || lowerPath.hasSuffix(".heic") {
            return true
        }

        if let notes = take.notes?.lowercased(),
           notes.contains("photo") || notes.contains("keyframe") {
            return true
        }

        return !lowerPath.hasSuffix(".mov") && !lowerPath.hasSuffix(".mp4")
    }
    
    // STEP 3C: Enhanced internal state sync with validation
    private func syncRatingToInternalStateWithValidation(takeID: UUID, rating: TakeRating) {
        var stateUpdated = false
        
        // Update unified takes array with validation
        if let index = unifiedTakes.firstIndex(where: { $0.id == takeID }) {
            // STEP 3C: Atomic update to prevent race conditions
            unifiedTakes[index].rating = rating
            
            // Also update isBest flag for UI consistency
            switch rating {
            case .finalSelect:
                unifiedTakes[index].isBest = true
            case .rejected, .unrated, .option:
                unifiedTakes[index].isBest = false
            }
            
            stateUpdated = true
            print("✅ Updated unified take internal state: \(rating.rawValue)")
        }
        
        // Update legacy takes array for compatibility with validation
        if let index = activeTakes.firstIndex(where: { $0.id == takeID }) {
            // STEP 3C: Atomic update to prevent race conditions
            activeTakes[index].rating = rating
            
            switch rating {
            case .finalSelect:
                activeTakes[index].isBest = true
            case .rejected, .unrated, .option:
                activeTakes[index].isBest = false
            }
            
            stateUpdated = true
            print("✅ Updated legacy take internal state: \(rating.rawValue)")
        }
        
        // STEP 3C: Ensure UI updates only if state actually changed
        if stateUpdated {
            // CRITICAL FIX: Force UI update immediately with 60fps optimization
            DispatchQueue.main.async { [weak self] in
                self?.objectWillChange.send()
            }
        } else {
            print("⚠️ SessionManager: Take \(takeID) not found in internal state")
        }
    }
    
    // STEP 3C: Enhanced repository sync with error handling
    public func syncFromRepositoryWithErrorHandling() {
        guard let repository = repository else {
            print("⚠️ SessionManager: No repository for sync")
            return
        }
        
        // Reload current session data from repository with error handling
        guard let currentSession = currentSession else {
            print("⚠️ SessionManager: No current session for sync")
            return
        }
        
        // SWIFT 6 FIX: Remove unreachable do/catch - no throwing operations inside
        guard let updatedProject = repository.project(by: currentSession.project.id) else {
            print("⚠️ SessionManager: Project not found during sync: \(currentSession.project.id)")
            return
        }
        
        guard let updatedSession = updatedProject.sessions.first(where: { $0.id == currentSession.session.id }) else {
            print("⚠️ SessionManager: Session not found during sync: \(currentSession.session.id)")
            return
        }
        
        // STEP 3C: Convert updated repository takes to unified format with error handling
        let updatedUnifiedTakes = updatedSession.takes.enumerated().compactMap { (index, projectTake) in
            let fileName = URL(fileURLWithPath: projectTake.filePath).lastPathComponent
            return try? UnifiedTake.safeConversion(
                from: projectTake,
                projectID: currentSession.project.id,
                sessionID: currentSession.session.id,
                fileName: fileName,
                takeNumber: index + 1
            )
        }
        
        // STEP 3C: Update internal state with batch optimization for 60fps
        ensureMain { [weak self] in
            guard let self = self else { return }
            
            self.unifiedTakes = updatedUnifiedTakes
            self.activeTakes = updatedUnifiedTakes.map { $0.toEnhancedTake() }
            self.totalScenes = max(1, updatedProject.sceneCount)
            self.hasRecordedSlate = updatedSession.takes.contains { $0.takeType.isSlateLike }
            self.hasRecordedKeyframePhoto = updatedSession.takes.contains { $0.isKeyframePhoto }
            let progress = SessionProgress.fromProjectTakes(updatedSession.takes, sceneCount: self.totalScenes)
            self.sessionProgress = progress
#if DEBUG
            print("🎯 SessionProgress: scenesDone=\(progress.scenesWithRegularTakes.sorted()) missing=\(progress.missingScenes) hasSlate=\(progress.hasSlate) hasKeyframe=\(progress.hasKeyframePhoto)")
#endif
            
            // Single UI update for better performance
            self.objectWillChange.send()
        }
        
        print("🔄 SessionManager: Enhanced sync completed - \(updatedUnifiedTakes.count) takes")
    }

    // MARK: - Resume Nudge (Phase 2)
    func resetResumeNudgeEntryState() {
        shouldShowResumeNudge = false
        resumeNudgeRemainingText = ""
        didShowResumeNudgeThisEntry = false
    }

    func evaluateResumeNudgeOnEntry() {
        ensureMain { [weak self] in
            guard let self else { return }
            guard !self.didShowResumeNudgeThisEntry else { return }
            guard let currentSession = self.currentSession else { return }
            guard let progress = self.sessionProgress else { return }
            guard self.effectiveTakeCount > 0 else { return }
            guard !progress.allCategoriesComplete else { return }
            guard !self.isResumeNudgeSuppressed(
                projectID: currentSession.project.id,
                sessionID: currentSession.session.id
            ) else { return }

            let remaining = self.formattedRemainingList(from: progress)
            guard !remaining.isEmpty else { return }

            self.resumeNudgeRemainingText = remaining
            self.shouldShowResumeNudge = true
            self.didShowResumeNudgeThisEntry = true
        }
    }

    func dismissResumeNudge() {
        ensureMain {
            self.shouldShowResumeNudge = false
        }
    }

    func suppressResumeNudgeForCurrentSession() {
        guard let currentSession else { return }
        let key = resumeNudgeSuppressionKey(
            projectID: currentSession.project.id,
            sessionID: currentSession.session.id
        )
        UserDefaults.standard.set(true, forKey: key)
        dismissResumeNudge()
    }

    func navigateToFirstMissingItem() {
        ensureMain { [weak self] in
            guard let self, let progress = self.sessionProgress else { return }
            if !progress.hasSlate {
                self.switchToSlateMode()
                return
            }
            if !progress.hasKeyframePhoto {
                self.switchToKeyframePhotoMode()
                return
            }
            if let firstMissing = progress.missingScenes.first {
                self.switchToSceneMode()
                self.currentScene = max(1, firstMissing)
            }
        }
    }

    private func formattedRemainingList(from progress: SessionProgress) -> String {
        var parts: [String] = []

        if !progress.hasSlate {
            parts.append("Slate")
        }

        let missingScenes = progress.missingScenes
        if !missingScenes.isEmpty {
            if missingScenes.count == 1, let scene = missingScenes.first {
                parts.append("Scene \(scene)")
            } else {
                let sceneList = missingScenes.map(String.init).joined(separator: ", ")
                parts.append("Scenes \(sceneList)")
            }
        }

        if !progress.hasKeyframePhoto {
            parts.append("Keyframe Photo")
        }

        return parts.joined(separator: ", ")
    }

    private func resumeNudgeSuppressionKey(projectID: UUID, sessionID: UUID) -> String {
        "resumeNudgeSuppressed_\(projectID.uuidString)_\(sessionID.uuidString)"
    }

    private func isResumeNudgeSuppressed(projectID: UUID, sessionID: UUID) -> Bool {
        UserDefaults.standard.bool(forKey: resumeNudgeSuppressionKey(projectID: projectID, sessionID: sessionID))
    }
    
    // STEP 3C: Enhanced notification system with comprehensive data
    private func sendRatingUpdateNotification(
        takeID: UUID,
        sessionID: UUID,
        projectID: UUID,
        rating: TakeRating
    ) {
        // STEP 3C: Create comprehensive notification payload
        let notificationData: [String: Any] = [
            "takeID": takeID,
            "sessionID": sessionID,
            "projectID": projectID,
            "rating": rating.rawValue,
            "timestamp": Date().timeIntervalSince1970,
            "source": "SessionManager"
        ]
        
        // STEP 3C: Send on main queue for immediate UI updates
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: Notification.Name("STSTakeRatingUpdated"),
                object: nil,
                userInfo: notificationData
            )
        }
        
        print("📢 SessionManager: Enhanced rating notification sent for take \(takeID)")
    }
    
    // STEP 3C: Wrapper for backward compatibility with enhanced error handling
    public func syncFromRepository() {
        syncFromRepositoryWithErrorHandling()
    }
    
    // MARK: - Take ID Resolution (for UnifiedTakePlayerView integration)
    
    func getTakeID(for fileName: String) -> UUID? {
        if useUnifiedModels {
            return unifiedTakes.first(where: { $0.fileName == fileName })?.id
        } else {
            return activeTakes.first(where: { $0.fileName == fileName })?.id
        }
    }
    
    func getUnifiedTake(by id: UUID) -> UnifiedTake? {
        if useUnifiedModels {
            return unifiedTakes.first(where: { $0.id == id })
        } else {
            return activeTakes.first(where: { $0.id == id }).map { UnifiedTake(from: $0) }
        }
    }
    
    func getUnifiedTake(by fileName: String) -> UnifiedTake? {
        if useUnifiedModels {
            return unifiedTakes.first(where: { $0.fileName == fileName })
        } else {
            return activeTakes.first(where: { $0.fileName == fileName }).map { UnifiedTake(from: $0) }
        }
    }
    
    // MARK: - Storage Information with UNIFIED SUPPORT
    func getTotalStorageUsed() -> Int64 {
        if useUnifiedModels {
            return unifiedTakes.reduce(0) { $0 + $1.fileSize }
        } else {
            return activeTakes.reduce(0) { $0 + $1.fileSize }
        }
    }
    
    func getFormattedStorageUsed() -> String {
        let totalBytes = getTotalStorageUsed()
        return ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file)
    }
    
    // MARK: - Migration Helpers
    
    /// Get current take count regardless of model type
    var currentTakeCount: Int {
        return useUnifiedModels ? unifiedTakes.count : activeTakes.count
    }
    
    /// Check if unified models are available
    var hasUnifiedTakes: Bool {
        return !unifiedTakes.isEmpty
    }
    
    // MARK: - SmartFill Support Methods - NEW for Phase 2-3 Integration
    
    /// Update take with SmartFill processed file path
    public func updateTakeWithSmartFill(takeID: UUID, smartFillPath: String, sessionID: UUID, projectID: UUID) {
        // Update unified takes first
        if let index = unifiedTakes.firstIndex(where: { $0.id == takeID }) {
            unifiedTakes[index].smartFilledFilePath = smartFillPath
            print("✅ SessionManager: Updated unified take with SmartFill path: \(URL(fileURLWithPath: smartFillPath).lastPathComponent)")
        }
        
        // Update repository
        if let repository = repositoryInstance {
            repository.updateTakeWithSmartFillPath(
                takeID: takeID,
                smartFilledPath: smartFillPath,
                in: sessionID,
                in: projectID
            )
            
            print("✅ Repository updated with SmartFill path for takeID: \(takeID)")
            print("📁 SmartFill path: \(smartFillPath)")
            print("💾 File exists: \(FileManager.default.fileExists(atPath: smartFillPath))")
            
            // ENHANCED: Post completion notification for UI updates
            NotificationCenter.default.post(
                name: Notification.Name("STSSmartFillCompleted"),
                object: nil,
                userInfo: [
                    "takeID": takeID,
                    "sessionID": sessionID,
                    "projectID": projectID,
                    "smartFillPath": smartFillPath
                ]
            )
            
            print("📢 Posted STSSmartFillCompleted notification")
        }
        
        print("✅ SessionManager: Updated take with SmartFill path: \(URL(fileURLWithPath: smartFillPath).lastPathComponent)")
    }
    
    /// Get SmartFill status for current session
    public func getSmartFillStatus() -> SmartFillSessionStatus? {
        guard let currentSession = currentSession,
              let repository = repository else { return nil }
        
        return repository.getSmartFillStatus(
            for: currentSession.session.id,
            in: currentSession.project.id
        )
    }
    
    /// Get all unified takes - convenience method for external access
    public func getAllUnifiedTakes() -> [UnifiedTake] {
        if useUnifiedModels {
            return unifiedTakes
        } else {
            return activeTakes.map { UnifiedTake(from: $0) }
        }
    }
    
    /// Find unified take by filename - used by SmartFill processing
    public func findUnifiedTake(byFileName fileName: String) -> UnifiedTake? {
        if useUnifiedModels {
            return unifiedTakes.first(where: { $0.fileName == fileName })
        } else {
            return activeTakes.first(where: { $0.fileName == fileName }).map { UnifiedTake(from: $0) }
        }
    }
}

// MARK: - Enhanced Session State (PRESERVED)
struct SessionState {
    var project: Project
    var session: ProjectSession
    let startTime: Date
    var endTime: Date?
    
    var duration: TimeInterval {
        (endTime ?? Date()).timeIntervalSince(startTime)
    }
}

// MARK: - Enhanced Take Model for SessionManager (PRESERVED for compatibility)
public struct EnhancedTake: Identifiable, Codable, Equatable {
    public let id: UUID
    public let fileName: String
    public let projectID: UUID
    public let sessionID: UUID
    public let filePath: String
    public let duration: TimeInterval
    public let fileSize: Int64
    public let cameraPosition: String
    public let sceneNumber: Int
    public let takeNumber: Int
    public let isSlate: Bool
    public var rating: TakeRating
    public var isBest: Bool
    public let notes: String?
    public let createdAt: Date
    
    public init(
        fileName: String,
        projectID: UUID,
        sessionID: UUID,
        filePath: String,
        duration: TimeInterval,
        fileSize: Int64,
        cameraPosition: String,
        sceneNumber: Int,
        takeNumber: Int,
        isSlate: Bool = false,
        rating: TakeRating = .unrated,
        isBest: Bool = false,
        notes: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = UUID()
        self.fileName = fileName
        self.projectID = projectID
        self.sessionID = sessionID
        self.filePath = filePath
        self.duration = duration
        self.fileSize = fileSize
        self.cameraPosition = cameraPosition
        self.sceneNumber = sceneNumber
        self.takeNumber = takeNumber
        self.isSlate = isSlate
        self.rating = rating
        self.isBest = isBest
        self.notes = notes
        self.createdAt = createdAt
    }
    
    public var formattedFileSize: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }
    
public var formattedDuration: String {
    let minutes = Int(duration) / 60
    let seconds = Int(duration) % 60
    return String(format: "%d:%02d", minutes, seconds)
}
}

// MARK: - Watch Remote Mode Control
extension SessionManager: ModeControlling {
    public func setMode(_ mode: STSMode) {
        switch mode {
        case .scene(let index):
            switchToScene(index)
        case .slate:
            switchToSlateMode()
        case .photo:
            switchToKeyframePhotoMode()
        }
    }
}
