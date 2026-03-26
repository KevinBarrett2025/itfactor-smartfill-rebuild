import Foundation

public enum SmartFillResultAdoptionMode: String, Codable, Sendable {
    case updateExistingTakePath
    case createStandaloneVariantTake
}

public struct SmartFillResultBridgeRecord: Identifiable, Codable, Sendable {
    public let projectID: UUID
    public let sessionID: UUID
    public let originalTakeID: UUID
    public let adoptedTakeID: UUID
    public let outputURL: URL
    public let duration: Double
    public let settingsSnapshot: SmartFillSettingsSnapshot?
    public let adoptionMode: SmartFillResultAdoptionMode
    public let destinationSummary: String

    public init(
        projectID: UUID,
        sessionID: UUID,
        originalTakeID: UUID,
        adoptedTakeID: UUID,
        outputURL: URL,
        duration: Double,
        settingsSnapshot: SmartFillSettingsSnapshot?,
        adoptionMode: SmartFillResultAdoptionMode,
        destinationSummary: String
    ) {
        self.projectID = projectID
        self.sessionID = sessionID
        self.originalTakeID = originalTakeID
        self.adoptedTakeID = adoptedTakeID
        self.outputURL = outputURL
        self.duration = duration
        self.settingsSnapshot = settingsSnapshot
        self.adoptionMode = adoptionMode
        self.destinationSummary = destinationSummary
    }

    public var id: String { outputURL.path }
}

enum SmartFillResultBridge {
    struct AdoptionPayload {
        let originalTakeID: UUID
        let lineageOriginalTakeID: UUID
        let adoptedTakeID: UUID
        let projectID: UUID
        let sessionID: UUID
        let outputURL: URL
        let duration: Double
        let settingsSnapshot: SmartFillSettingsSnapshot?
        let adoptionMode: SmartFillResultAdoptionMode
        let approach: String

        var notificationUserInfo: [AnyHashable: Any] {
            [
                "takeID": originalTakeID,
                "originalTakeID": originalTakeID,
                "lineageOriginalTakeID": lineageOriginalTakeID,
                "smartFillTakeID": adoptedTakeID,
                "sessionID": sessionID,
                "projectID": projectID,
                "smartFillPath": outputURL.path,
                "approach": approach
            ]
        }
    }

    enum AdoptionError: Error {
        case missingProject(UUID)
        case missingSession(UUID)
        case missingTake(UUID)
    }

    static func makeAdoptionRecord(
        outputURL: URL,
        duration: Double,
        settingsSnapshot: SmartFillSettingsSnapshot?,
        take: ProjectTake
    ) -> SmartFillResultBridgeRecord {
        let adoptionMode: SmartFillResultAdoptionMode = take.isSmartFillVariant ? .updateExistingTakePath : .createStandaloneVariantTake

        return SmartFillResultBridgeRecord(
            projectID: UUID(),
            sessionID: UUID(),
            originalTakeID: take.smartFillOriginalID ?? take.id,
            adoptedTakeID: take.id,
            outputURL: outputURL,
            duration: duration,
            settingsSnapshot: settingsSnapshot,
            adoptionMode: adoptionMode,
            destinationSummary: adoptionMode == .updateExistingTakePath
            ? "Refresh the existing SmartFill variant in session review."
            : "Create or update a standalone SmartFill variant for the selected take."
        )
    }

    static func adopt(
        job: SmartFillProcessingManager.SmartFillJob,
        repository: ProjectsRepository
    ) throws -> AdoptionPayload {
        guard let project = repository.project(by: job.projectID) else {
            throw AdoptionError.missingProject(job.projectID)
        }
        guard let session = project.sessions.first(where: { $0.id == job.sessionID }) else {
            throw AdoptionError.missingSession(job.sessionID)
        }
        guard let sourceTake = session.takes.first(where: { $0.id == job.takeID }) else {
            throw AdoptionError.missingTake(job.takeID)
        }

        let resolvedDuration = job.outputDurationSeconds > 0 ? job.outputDurationSeconds : sourceTake.durationSeconds
        let outputURL = URL(fileURLWithPath: job.outputPath)
        let lineageOriginalTakeID = sourceTake.smartFillOriginalID ?? sourceTake.id

        repository.updateTakeWithSmartFillPath(
            takeID: lineageOriginalTakeID,
            smartFilledPath: job.outputPath,
            in: job.sessionID,
            in: job.projectID
        )

        let adoptedTakeID: UUID
        let adoptionMode: SmartFillResultAdoptionMode
        let approach: String

        if sourceTake.isSmartFillVariant {
            adoptedTakeID = repository.upsertSmartFillTake(
                projectID: job.projectID,
                sessionID: job.sessionID,
                originalTakeID: lineageOriginalTakeID,
                smartFillPath: job.outputPath,
                duration: resolvedDuration,
                settings: job.settingsSnapshot
            ) ?? sourceTake.id
            adoptionMode = .updateExistingTakePath
            approach = "standalone"
        } else if let standaloneTakeID = repository.upsertSmartFillTake(
            projectID: job.projectID,
            sessionID: job.sessionID,
            originalTakeID: lineageOriginalTakeID,
            smartFillPath: job.outputPath,
            duration: resolvedDuration,
            settings: job.settingsSnapshot
        ) {
            adoptedTakeID = standaloneTakeID
            adoptionMode = .createStandaloneVariantTake
            approach = "standalone"
        } else {
            adoptedTakeID = sourceTake.id
            adoptionMode = .updateExistingTakePath
            approach = "inline"
        }

        return AdoptionPayload(
            originalTakeID: sourceTake.id,
            lineageOriginalTakeID: lineageOriginalTakeID,
            adoptedTakeID: adoptedTakeID,
            projectID: job.projectID,
            sessionID: job.sessionID,
            outputURL: outputURL,
            duration: resolvedDuration,
            settingsSnapshot: job.settingsSnapshot,
            adoptionMode: adoptionMode,
            approach: approach
        )
    }

    static func makeAdoptionRecord(
        from notification: Notification,
        matching context: SmartFillSessionContext,
        settingsSnapshot: SmartFillSettingsSnapshot?
    ) -> SmartFillResultBridgeRecord? {
        guard
            let originalTakeID = uuid(from: notification.userInfo, key: "originalTakeID"),
            originalTakeID == context.takeID,
            let adoptedTakeID = uuid(from: notification.userInfo, key: "smartFillTakeID"),
            let sessionID = uuid(from: notification.userInfo, key: "sessionID"),
            sessionID == context.sessionID,
            let projectID = uuid(from: notification.userInfo, key: "projectID"),
            projectID == context.projectID
        else {
            return nil
        }

        let outputPath = (notification.userInfo?["smartFillPath"] as? String) ?? ""
        let outputURL = URL(fileURLWithPath: outputPath)
        let approach = (notification.userInfo?["approach"] as? String) ?? "inline"
        let adoptionMode: SmartFillResultAdoptionMode = approach == "standalone" || adoptedTakeID != originalTakeID
        ? .createStandaloneVariantTake
        : .updateExistingTakePath

        return SmartFillResultBridgeRecord(
            projectID: projectID,
            sessionID: sessionID,
            originalTakeID: (uuid(from: notification.userInfo, key: "lineageOriginalTakeID") ?? originalTakeID),
            adoptedTakeID: adoptedTakeID,
            outputURL: outputURL,
            duration: 0,
            settingsSnapshot: settingsSnapshot,
            adoptionMode: adoptionMode,
            destinationSummary: adoptionMode == .updateExistingTakePath
            ? "Refresh the existing SmartFill take in this session."
            : "Create or refresh the SmartFill take in this session."
        )
    }

    private static func uuid(from userInfo: [AnyHashable: Any]?, key: String) -> UUID? {
        guard let userInfo else { return nil }
        if let value = userInfo[key] as? UUID {
            return value
        }
        if let value = userInfo[key] as? String {
            return UUID(uuidString: value)
        }
        return nil
    }
}
