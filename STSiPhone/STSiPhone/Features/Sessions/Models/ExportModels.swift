import UIKit
import Foundation
import AVFoundation
import UniformTypeIdentifiers
import CoreTransferable

public enum ExportKind: String, Codable, Sendable {
    case take, slate, photo
}

struct ExportItem: Identifiable, Hashable, Sendable {
    public let id: UUID
    var url: URL
    var kind: ExportKind
    var label: String        // "Take 1", "Slate", etc.
    var duration: CMTime
    var included: Bool

    init(id: UUID = UUID(),
                url: URL,
                kind: ExportKind,
                label: String,
                duration: CMTime,
                included: Bool = true) {
        self.id = id
        self.url = url
        self.kind = kind
        self.label = label
        self.duration = duration
        self.included = included
    }
}

// Transferable conformance for drag & drop
extension ExportItem: Transferable {
    public static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(for: ExportItem.self, contentType: .data)
    }
}

// Custom Codable implementation to handle CMTime
extension ExportItem: Codable {
    enum CodingKeys: CodingKey {
        case id, url, kind, label, durationSeconds, included
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        url = try container.decode(URL.self, forKey: .url)
        kind = try container.decode(ExportKind.self, forKey: .kind)
        label = try container.decode(String.self, forKey: .label)
        let seconds = try container.decode(Double.self, forKey: .durationSeconds)
        duration = CMTime(seconds: seconds, preferredTimescale: 600)
        included = try container.decode(Bool.self, forKey: .included)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(url, forKey: .url)
        try container.encode(kind, forKey: .kind)
        try container.encode(label, forKey: .label)
        try container.encode(duration.seconds, forKey: .durationSeconds)
        try container.encode(included, forKey: .included)
    }
}

struct ExportTimeline: Hashable, Sendable {
    var items: [ExportItem]   // order matters
    init(items: [ExportItem]) { self.items = items }
}

// Convenience
public extension CMTime {
    var asClockString: String {
        let total = Int((CMTimeGetSeconds(self).isFinite ? CMTimeGetSeconds(self) : 0).rounded())
        let m = total / 60
        let s = total % 60
        return String(format: "%d:%02d", m, s)
    }
}

// MARK: - Export Header Data Contracts (Filename + Thumbnail)

/// What the Export sheet needs to render the header
struct ExportHeaderContext {
    /// Ordered takes included in export (comes from drag-strip & green-check filtering)
    var includedTakes: [UnifiedTake]
    /// Selected "best" photo (green-check) for this session, if any
    var selectedPhoto: ProjectTake?
    /// Known labels (if present)
    var actorName: String?
    var projectNameOrId: String?
    var roleName: String?
    /// Slate presence inferred from included takes
    var hasSlate: Bool
    /// Scenes list derived from takes
    var scenesDisplay: String?
    
    init(includedTakes: [UnifiedTake], selectedPhoto: ProjectTake? = nil, actorName: String? = nil, projectNameOrId: String? = nil, roleName: String? = nil, hasSlate: Bool = false, scenesDisplay: String? = nil) {
        self.includedTakes = includedTakes
        self.selectedPhoto = selectedPhoto
        self.actorName = actorName
        self.projectNameOrId = projectNameOrId
        self.roleName = roleName
        self.hasSlate = hasSlate
        self.scenesDisplay = scenesDisplay
    }
}


/// Export sheet's mutable options (adding filename & format to existing structure)
struct ExportHeaderOptions {
    var filenameBase: String
    var format: OutputFormat
    
    init(filenameBase: String, format: OutputFormat = .mp4) {
        self.filenameBase = filenameBase
        self.format = format
    }
    
    var fullFilename: String {
        return "\(filenameBase).\(format.fileExtension)"
    }
}

/// Filename auto-generation logic
struct ExportFilenameBuilder {
    init() {}
    
    public func build(from ctx: ExportHeaderContext) -> String {
        let role = ctx.roleName?.slateTrimmedNonEmpty ?? ctx.projectNameOrId?.slateTrimmedNonEmpty
        let actor = ctx.actorName?.slateTrimmedNonEmpty
        let tokens = makeTakeTokens(ctx.includedTakes)
        return ExportFilenameBuilder.buildBase(actorName: actor, roleName: role, takeTokens: tokens)
    }

    static func buildBase(actorName: String?, roleName: String?, takeTokens: [String]) -> String {
        let actor = actorName?.slateTrimmedNonEmpty ?? ""
        let role = roleName?.slateTrimmedNonEmpty ?? ""
        let takeList = takeTokens.filter { !$0.isEmpty }.joined(separator: ",")

        let header: String
        if !actor.isEmpty && !role.isEmpty {
            header = "\(actor), \(role)"
        } else if !actor.isEmpty {
            header = actor
        } else if !role.isEmpty {
            header = role
        } else {
            header = ""
        }

        let raw: String
        if takeList.isEmpty {
            raw = header
        } else if header.isEmpty {
            raw = takeList
        } else {
            raw = "\(header) - \(takeList)"
        }

        return sanitizeFilename(raw)
    }

    static func sanitizeFilename(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        let illegal = CharacterSet(charactersIn: "/\\:*?\"<>|")
        let control = CharacterSet.controlCharacters.union(.newlines)

        let mapped = trimmed.unicodeScalars.map { scalar -> Character in
            if illegal.contains(scalar) || control.contains(scalar) {
                return "-"
            }
            return Character(scalar)
        }
        var cleaned = String(mapped)

        cleaned = cleaned.replacingOccurrences(of: "_", with: " ")
        cleaned = cleaned.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: "-{2,}", with: "-", options: .regularExpression)
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        cleaned = cleaned.trimmingCharacters(in: CharacterSet(charactersIn: "-,"))

        return cleaned
    }

    private func makeTakeTokens(_ takes: [UnifiedTake]) -> [String] {
        var perSceneCounters: [Int: Int] = [:]
        var tokens: [String] = []

        for take in takes {
            if take.isSlate { continue }
            let scene = take.sceneNumber > 0 ? take.sceneNumber : 1
            let nextCount = (perSceneCounters[scene] ?? 0) + 1
            perSceneCounters[scene] = nextCount
            tokens.append("S\(scene)T\(nextCount)")
        }

        return tokens
    }
}

/// Thumbnail provider for export preview
struct ExportThumbnailProvider {
    @MainActor
    static func thumbnail(ctx: ExportHeaderContext, size: CGSize, scale: CGFloat = 3.0) async -> UIImage? {
        // 1. Try selected photo first
        if let selectedPhoto = ctx.selectedPhoto,
           selectedPhoto.isFinalSelect,
           selectedPhoto.durationSeconds == 0.0 { // Photos have duration 0
            do {
                let photoURL = try VideoFileManager.shared.getVideoURL(for: URL(fileURLWithPath: selectedPhoto.filePath).lastPathComponent)
                if let image = UIImage(contentsOfFile: photoURL.path) {
                    return image
                }
            } catch {
                print("⚠️ Could not load selected photo: \(error)")
            }
        }
        
        // 2. Try first frame of first included take
        guard let firstTake = ctx.includedTakes.first else { return nil }
        
        do {
            let videoURL = try VideoFileManager.shared.getVideoURL(for: firstTake.fileName)
            let asset = AVURLAsset(url: videoURL)
            let gen = AVAssetImageGenerator(asset: asset)
            gen.appliesPreferredTrackTransform = true
            gen.maximumSize = CGSize(width: size.width * scale, height: size.height * scale)

            // Prefer a very early frame so we capture the keyframe intro (0.01s)
            // when present. Fallback to a later frame if that fails.
            let primaryTime  = CMTime(seconds: 0.005, preferredTimescale: 600)
            let fallbackTime = CMTime(seconds: 0.5,   preferredTimescale: 600)

            if let primaryImage = try? await gen.image(at: primaryTime).image {
                return UIImage(cgImage: primaryImage)
            }

            let cgImage = try await gen.image(at: fallbackTime).image
            return UIImage(cgImage: cgImage)
        } catch {
            print("⚠️ Could not generate thumbnail from first take: \(error)")
            return nil
        }
    }
}
