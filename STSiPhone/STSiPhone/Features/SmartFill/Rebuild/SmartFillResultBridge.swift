import Foundation

public enum SmartFillResultAdoptionMode: String, Codable, Sendable {
    case updateExistingTakePath
    case createStandaloneVariantTake
}

public struct SmartFillResultBridgeRecord: Identifiable, Codable, Sendable {
    public let outputURL: URL
    public let duration: Double
    public let settingsSnapshot: SmartFillSettingsSnapshot?
    public let adoptionMode: SmartFillResultAdoptionMode
    public let destinationSummary: String

    public init(
        outputURL: URL,
        duration: Double,
        settingsSnapshot: SmartFillSettingsSnapshot?,
        adoptionMode: SmartFillResultAdoptionMode,
        destinationSummary: String
    ) {
        self.outputURL = outputURL
        self.duration = duration
        self.settingsSnapshot = settingsSnapshot
        self.adoptionMode = adoptionMode
        self.destinationSummary = destinationSummary
    }

    public var id: String { outputURL.path }
}

enum SmartFillResultBridge {
    static func makeAdoptionRecord(
        outputURL: URL,
        duration: Double,
        settingsSnapshot: SmartFillSettingsSnapshot?,
        take: ProjectTake
    ) -> SmartFillResultBridgeRecord {
        let adoptionMode: SmartFillResultAdoptionMode = take.isSmartFillVariant ? .updateExistingTakePath : .createStandaloneVariantTake

        return SmartFillResultBridgeRecord(
            outputURL: outputURL,
            duration: duration,
            settingsSnapshot: settingsSnapshot,
            adoptionMode: adoptionMode,
            destinationSummary: adoptionMode == .updateExistingTakePath
            ? "Refresh the existing SmartFill variant in session review."
            : "Create or update a standalone SmartFill variant for the selected take."
        )
    }
}
