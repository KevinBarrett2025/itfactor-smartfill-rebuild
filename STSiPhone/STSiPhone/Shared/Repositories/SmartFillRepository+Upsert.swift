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
        if let project = project(by: projectID),
           let session = project.sessions.first(where: { $0.id == sessionID }),
           let existingVariant = session.takes.first(where: { candidate in
               candidate.id != originalTakeID &&
               candidate.isSmartFillVariant &&
               candidate.smartFillOriginalID == originalTakeID
           }) {
            deleteTake(takeID: existingVariant.id, from: sessionID, in: projectID)
        }

        return createStandaloneSmartFillTake(
            originalTakeID: originalTakeID,
            smartFillPath: smartFillPath,
            duration: duration,
            settings: settings,
            in: sessionID,
            in: projectID
        )
    }
}
