import Foundation

public extension ProjectsRepository {
    /// Convenience helper to create or update the standalone SmartFill take for the given original take.
    @discardableResult
    func upsertSmartFillTake(
        projectID: UUID,
        sessionID: UUID,
        originalTakeID: UUID,
        smartFillPath: String,
        duration: Double,
        settings: SmartFillSettingsSnapshot? = nil
    ) -> UUID? {
        createStandaloneSmartFillTake(
            originalTakeID: originalTakeID,
            smartFillPath: smartFillPath,
            duration: duration,
            settings: settings,
            in: sessionID,
            in: projectID
        )
    }
}
