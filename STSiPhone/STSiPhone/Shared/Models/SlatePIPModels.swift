import Foundation

/// Visual styling options for the final merged slate.
/// `borderStyle` is editor-only; the initial export uses `.none`.
public enum SlatePIPBorderStyle: String, Codable, CaseIterable, Identifiable, Sendable {
    case none
    case thinLight
    case thinDark

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .none: return "None"
        case .thinLight: return "Thin Light"
        case .thinDark: return "Thin Dark"
        }
    }
}

/// A single recorded slate take (portrait or landscape) used in PIP slates.
///
/// `filePath` stores the relative path inside the app's Documents directory.
public struct PIPSlateTake: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var filePath: String
    public var createdAt: Date
    public var duration: TimeInterval

    public init(filePath: String, duration: TimeInterval, id: UUID = UUID(), createdAt: Date = Date()) {
        self.id = id
        self.filePath = filePath
        self.createdAt = createdAt
        self.duration = duration
    }

    private var resolvedAbsolutePath: String {
        if filePath.hasPrefix("/") {
            return filePath
        }
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent(filePath).path
    }

    public var fileURL: URL { URL(fileURLWithPath: resolvedAbsolutePath) }
}

/// A full Picture-in-Picture slate session containing portrait + landscape takes
/// and the currently-selected pair to merge.
public struct SlatePIPSession: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID

    public var portraitTakes: [PIPSlateTake]
    public var landscapeTakes: [PIPSlateTake]

    public var selectedPortraitID: UUID?
    public var selectedLandscapeID: UUID?

    public var borderStyle: SlatePIPBorderStyle
    public var portraitAudioMuted: Bool
    public var landscapeAudioMuted: Bool

    public init(
        id: UUID = UUID(),
        portraitTakes: [PIPSlateTake] = [],
        landscapeTakes: [PIPSlateTake] = [],
        selectedPortraitID: UUID? = nil,
        selectedLandscapeID: UUID? = nil,
        borderStyle: SlatePIPBorderStyle = .none,
        portraitAudioMuted: Bool = false,
        landscapeAudioMuted: Bool = false
    ) {
        self.id = id
        self.portraitTakes = portraitTakes
        self.landscapeTakes = landscapeTakes
        self.selectedPortraitID = selectedPortraitID
        self.selectedLandscapeID = selectedLandscapeID
        self.borderStyle = borderStyle
        self.portraitAudioMuted = portraitAudioMuted
        self.landscapeAudioMuted = landscapeAudioMuted
    }

    public var selectedPortraitTake: PIPSlateTake? {
        if let id = selectedPortraitID, let found = portraitTakes.first(where: { $0.id == id }) {
            return found
        }
        return portraitTakes.last
    }

    public var selectedLandscapeTake: PIPSlateTake? {
        if let id = selectedLandscapeID, let found = landscapeTakes.first(where: { $0.id == id }) {
            return found
        }
        return landscapeTakes.last
    }
}

/// Metadata captured when a Picture-in-Picture composite take is persisted.
public struct PIPSlateCompositeMetadata: Codable, Equatable, Sendable {
    public var portraitTakeID: UUID?
    public var landscapeTakeID: UUID?
    public var portraitAudioEnabled: Bool
    public var landscapeAudioEnabled: Bool

    public init(
        portraitTakeID: UUID?,
        landscapeTakeID: UUID?,
        portraitAudioEnabled: Bool,
        landscapeAudioEnabled: Bool
    ) {
        self.portraitTakeID = portraitTakeID
        self.landscapeTakeID = landscapeTakeID
        self.portraitAudioEnabled = portraitAudioEnabled
        self.landscapeAudioEnabled = landscapeAudioEnabled
    }

    public var enabledAudioDescription: String? {
        switch (portraitAudioEnabled, landscapeAudioEnabled) {
        case (true, true):
            return "Audio: Both angles"
        case (true, false):
            return "Audio: Full Body"
        case (false, true):
            return "Audio: Close-Up"
        default:
            return nil
        }
    }
}
