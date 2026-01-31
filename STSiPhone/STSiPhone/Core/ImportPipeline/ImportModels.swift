import Foundation

enum ImportPhase: String, Codable, Equatable {
    case queued
    case preparing
    case downloading
    case copying
    case saving
    case processing
    case verifying
    case ready
    case failed
    case canceled
    
    var displayName: String {
        switch self {
        case .queued: return "Queued"
        case .preparing: return "Preparing import"
        case .downloading: return "Downloading from Photos"
        case .copying: return "Copying file"
        case .saving: return "Copying into session"
        case .processing: return "Copying into session"
        case .verifying: return "Finalizing"
        case .ready: return "Ready"
        case .failed: return "Failed"
        case .canceled: return "Canceled"
        }
    }
    
    var isActive: Bool {
        switch self {
        case .ready, .failed, .canceled:
            return false
        case .queued, .preparing, .downloading, .copying, .saving, .processing, .verifying:
            return true
        }
    }
}

enum ImportFailureCode: String, Codable, Equatable {
    case accessDenied
    case fileNotFound
    case downloadFailed
    case copyFailed
    case processingFailed
    case verificationFailed
    case canceled
    case unknown
}

struct ImportFailure: Error, Codable, Equatable {
    let code: ImportFailureCode
    let message: String
}

enum ImportSource: Codable, Equatable {
    case photos(localIdentifier: String, suggestedExtension: String?)
    case files(bookmark: Data, originalFilename: String)
    case localFile(url: URL, originalFilename: String?)
}

struct ImportIdentifiers: Codable, Equatable {
    let fileName: String
    let sceneNumber: Int
    let takeNumber: Int
    let slateNumber: String?
    let slateID: String?
    let isSlate: Bool
    let isKeyframePhoto: Bool

    init(
        fileName: String,
        sceneNumber: Int,
        takeNumber: Int,
        slateNumber: String?,
        slateID: String?,
        isSlate: Bool,
        isKeyframePhoto: Bool = false
    ) {
        self.fileName = fileName
        self.sceneNumber = sceneNumber
        self.takeNumber = takeNumber
        self.slateNumber = slateNumber
        self.slateID = slateID
        self.isSlate = isSlate
        self.isKeyframePhoto = isKeyframePhoto
    }

    private enum CodingKeys: String, CodingKey {
        case fileName
        case sceneNumber
        case takeNumber
        case slateNumber
        case slateID
        case isSlate
        case isKeyframePhoto
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        fileName = try container.decode(String.self, forKey: .fileName)
        sceneNumber = try container.decode(Int.self, forKey: .sceneNumber)
        takeNumber = try container.decode(Int.self, forKey: .takeNumber)
        slateNumber = try container.decodeIfPresent(String.self, forKey: .slateNumber)
        slateID = try container.decodeIfPresent(String.self, forKey: .slateID)
        isSlate = try container.decodeIfPresent(Bool.self, forKey: .isSlate) ?? false
        isKeyframePhoto = try container.decodeIfPresent(Bool.self, forKey: .isKeyframePhoto) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(fileName, forKey: .fileName)
        try container.encode(sceneNumber, forKey: .sceneNumber)
        try container.encode(takeNumber, forKey: .takeNumber)
        try container.encodeIfPresent(slateNumber, forKey: .slateNumber)
        try container.encodeIfPresent(slateID, forKey: .slateID)
        try container.encode(isSlate, forKey: .isSlate)
        try container.encode(isKeyframePhoto, forKey: .isKeyframePhoto)
    }
}

struct ImportContextData: Codable, Equatable {
    let projectID: UUID
    let sessionID: UUID
    let projectTitle: String
    let roleName: String?
}

struct ImportJob: Identifiable, Codable, Equatable {
    let id: UUID
    let identifiers: ImportIdentifiers
    let contextData: ImportContextData
    let source: ImportSource
    var phase: ImportPhase
    var progress: Double?
    var tempPath: String?
    var createdAt: Date
    var updatedAt: Date
    var failure: ImportFailure?
    
    var displayName: String {
        identifiers.fileName
    }
    
    var isActive: Bool { phase.isActive }
    var isFinished: Bool { phase == .ready || phase == .failed || phase == .canceled }
}

struct ImportCompletion: Equatable {
    let jobID: UUID
    let sessionID: UUID
    let projectID: UUID
    let take: ProjectTake
}
