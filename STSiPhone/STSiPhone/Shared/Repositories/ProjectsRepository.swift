import Foundation

// NEW: SmartFill session status for tracking processing state
public struct SmartFillSessionStatus {
    public let totalPortraitTakes: Int
    public let smartFilledTakes: Int
    public let pendingTakes: Int
    public let allPortraitTakes: [ProjectTake]
    public let needsProcessing: Bool
    
    public init(totalPortraitTakes: Int = 0, smartFilledTakes: Int = 0, pendingTakes: Int = 0, allPortraitTakes: [ProjectTake] = [], needsProcessing: Bool = false) {
        self.totalPortraitTakes = totalPortraitTakes
        self.smartFilledTakes = smartFilledTakes
        self.pendingTakes = pendingTakes
        self.allPortraitTakes = allPortraitTakes
        self.needsProcessing = needsProcessing
    }
    
    public var processingCompletionRate: Double {
        guard totalPortraitTakes > 0 else { return 1.0 }
        return Double(smartFilledTakes) / Double(totalPortraitTakes)
    }
    
    public var statusText: String {
        if totalPortraitTakes == 0 {
            return "No portrait takes found"
        } else if smartFilledTakes == totalPortraitTakes {
            return "All portrait takes processed"
        } else {
            return "\(smartFilledTakes) of \(totalPortraitTakes) portrait takes processed"
        }
    }
}

public protocol ProjectsRepository {
    func fetchProjects() -> [Project]
    func project(by id: UUID) -> Project?
    func updateProject(_ project: Project)
    func insert(project: Project)
    func append(session: ProjectSession, to projectID: UUID)
    func updateSession(_ session: ProjectSession, in projectID: UUID)
    func delete(project: Project)
    func deleteSession(sessionID: UUID, from projectID: UUID)
    func updateSlatePrompt(_ prompt: String?, for sessionID: UUID, in projectID: UUID)
    
    // ENHANCED: Take management with scene organization
    func addTake(_ take: ProjectTake, to sessionID: UUID, in projectID: UUID)
    func updateTake(_ take: ProjectTake, in sessionID: UUID, in projectID: UUID)
    func deleteTake(_ take: ProjectTake, from sessionID: UUID, in projectID: UUID)
    
    // ENHANCED: Scene-based take queries
    func takesForScene(_ sceneNumber: Int, in sessionID: UUID, in projectID: UUID) -> [ProjectTake]
    func takesByScene(in sessionID: UUID, in projectID: UUID) -> [Int: [ProjectTake]]
    func maxSceneNumber(in sessionID: UUID, in projectID: UUID) -> Int
    
    // ENHANCED: Slate management
    func slateTakes(in sessionID: UUID, in projectID: UUID) -> [ProjectTake]
    func keyframePhotoTakes(in sessionID: UUID, in projectID: UUID) -> [ProjectTake]
    
    // ENHANCED: Take numbering and organization
    func nextTakeNumber(for sceneNumber: Int, in sessionID: UUID, in projectID: UUID) -> Int
    func nextSlateNumber(in sessionID: UUID, in projectID: UUID) -> Int
    
    // ENHANCED: Merged video management
    func saveMergedVideo(filePath: String, duration: Double, exportMetadata: ExportMetadata, to sessionID: UUID, in projectID: UUID)
    
    // NEW: SmartFill integration methods
    func updateTakeWithSmartFillPath(takeID: UUID, smartFilledPath: String, in sessionID: UUID, in projectID: UUID)
    func getSmartFillStatus(for sessionID: UUID, in projectID: UUID) -> SmartFillSessionStatus
    func markTakeForBatchSmartFill(takeID: UUID, in sessionID: UUID, in projectID: UUID)
    func clearBatchSmartFillFlag(takeID: UUID, in sessionID: UUID, in projectID: UUID)
    
    // 🚨 KEVIN'S STANDALONE VIDEO APPROACH: Create separate take for SmartFilled videos
    func createStandaloneSmartFillTake(
        originalTakeID: UUID,
        smartFillPath: String,
        duration: Double,
        settings: SmartFillSettingsSnapshot?,
        in sessionID: UUID,
        in projectID: UUID
    ) -> UUID?
    
    // CRITICAL FIX: Add missing createSmartFillTake method that SmartFillExporter calls
    func createSmartFillTake(from takeID: UUID, fileURL: URL)
    
    // CRITICAL FIX: SmartFill lookup helpers shared by exporter tooling
    func loadSmartFillTakes(for takeID: UUID) -> [ProjectTake]
    func smartFillExists(for takeID: UUID, fileName: String) -> Bool
    
    // LEGACY METHODS: Maintain compatibility with existing ViewModels
    func archiveSession(sessionID: UUID, in projectID: UUID)
    func unarchiveSession(sessionID: UUID, in projectID: UUID)
    func toggleSessionFavorite(sessionID: UUID, in projectID: UUID)
    func duplicateSession(sessionID: UUID, in projectID: UUID)
    func exportSession(sessionID: UUID, from projectID: UUID)
    func setUnifiedTakeRating(takeID: UUID, sessionID: UUID, projectID: UUID, rating: TakeRating)
    func toggleTakeFavorite(takeID: UUID, in sessionID: UUID, of projectID: UUID)
    func exportTake(takeID: UUID, from sessionID: UUID, in projectID: UUID)
    func deleteTake(takeID: UUID, from sessionID: UUID, in projectID: UUID)
    func toggleFavorite(project: Project)
    func toggleArchive(project: Project)
    func toggleComplete(project: Project)
    func exportProject(_ project: Project)

    // Explicit archive APIs
    func archiveProject(projectID: UUID, request: ArchiveRequest) async throws
    func unarchiveProject(projectID: UUID) async throws
    func archiveSession(projectID: UUID, sessionID: UUID, request: ArchiveRequest) async throws
    func unarchiveSession(projectID: UUID, sessionID: UUID) async throws
    func unarchiveAllProjects() async throws
    
    // UNIFIED MODEL SUPPORT
    func getUnifiedVideoMarkers(for takeID: UUID, in sessionID: UUID, of projectID: UUID) -> [UnifiedVideoMarker]
    func addUnifiedVideoMarker(_ marker: UnifiedVideoMarker, to takeID: UUID, in sessionID: UUID, of projectID: UUID)
    
    func addTakeNote(takeID: UUID, in sessionID: UUID, of projectID: UUID, note: String)
    func exportSession(sessionID: UUID, projectID: UUID, takeIDs: [UUID])
    
    // NEW: Export and Edit Management
    func updateTakeEditMetadata(takeID: UUID, sessionID: UUID, projectID: UUID, editMetadata: TakeEditMetadata)
    
    // 🚨 NEW: Update take with edited version (like SmartFill system)
    func updateTakeWithEditedVersion(takeID: UUID, sessionID: UUID, projectID: UUID, editedFilePath: String, editMetadata: TakeEditMetadata)
    
    /// Update take orientation metadata (e.g., after SmartFill processing)
    func updateTakeOrientation(takeID: UUID, sessionID: UUID, projectID: UUID, newOrientation: VideoOrientation)
    func clearSmartFill(takeID: UUID, sessionID: UUID, projectID: UUID)

    /// Update only the PiP slate session payload for a specific session without rewriting the full project.
    func updatePIPSlateSession(projectID: UUID, sessionID: UUID, pipSlateSession: SlatePIPSession?)

    /// Hook for repositories that need explicit unified-model initialization.
    func enableUnifiedModelSupport()
}

public extension ProjectsRepository {
    /// Clears trim/crop metadata for a take, resetting edits to the original clip.
    func clearEditMetadata(
        takeID: UUID,
        sessionID: UUID,
        projectID: UUID
    ) {
        let emptyMetadata = TakeEditMetadata(
            hasTrimming: false,
            trimStartTime: nil,
            trimEndTime: nil,
            hasCropping: false,
            cropRect: nil,
            cropRotationDegrees: nil
        )

        updateTakeEditMetadata(
            takeID: takeID,
            sessionID: sessionID,
            projectID: projectID,
            editMetadata: emptyMetadata
        )
    }
}
