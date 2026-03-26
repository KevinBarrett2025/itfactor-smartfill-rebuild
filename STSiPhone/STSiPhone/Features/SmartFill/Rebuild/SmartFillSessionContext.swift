import Foundation

public enum SmartFillLaunchSource: String, Codable, Sendable {
    case projectDetail
    case takeReview
    case swipeablePlayer
    case editorBadge
    case settings
    case standaloneImport
}

public enum SmartFillReturnTarget: String, Codable, Sendable {
    case projectDetail
    case takeReview
    case swipeablePlayer
    case editor
    case standaloneWorkspace
}

public struct SmartFillSessionContext: Identifiable, Codable, Hashable, Sendable {
    public let projectID: UUID
    public let sessionID: UUID
    public let takeID: UUID
    public let launchSource: SmartFillLaunchSource
    public let returnTarget: SmartFillReturnTarget
    public let launchedAt: Date

    public init(
        projectID: UUID,
        sessionID: UUID,
        takeID: UUID,
        launchSource: SmartFillLaunchSource,
        returnTarget: SmartFillReturnTarget,
        launchedAt: Date = Date()
    ) {
        self.projectID = projectID
        self.sessionID = sessionID
        self.takeID = takeID
        self.launchSource = launchSource
        self.returnTarget = returnTarget
        self.launchedAt = launchedAt
    }

    public var id: UUID { takeID }
}
