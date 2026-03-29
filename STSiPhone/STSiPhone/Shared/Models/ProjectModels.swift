import Foundation
import AVFoundation
import CoreGraphics

// MARK: - Smart Fill Support Types
public enum VideoOrientation: String, Codable, CaseIterable, Sendable {
    case landscape
    case portrait
    
    public var displayName: String {
        switch self {
        case .landscape: return "Landscape"
        case .portrait: return "Portrait"
        }
    }
    
    public var icon: String {
        switch self {
        case .landscape: return "rectangle.landscape.rotate"
        case .portrait: return "rectangle.portrait.rotate"
        }
    }
}

public enum TriState: String, Codable, CaseIterable, Sendable {
    case inherit
    case on
    case off
    
    public var displayName: String {
        switch self {
        case .inherit: return "Inherit"
        case .on: return "On"
        case .off: return "Off"
        }
    }
}

public enum SessionType: String, Codable, CaseIterable, Identifiable, Sendable {
    case selfTape = "Self-Tape"
    case callback = "Callback"
    case chemistryRead = "Chemistry Read"
    case inPerson = "In-Person"
    public var id: String { rawValue }
}

public struct SmartFillSettingsSnapshot: Codable, Equatable, Sendable {
    public var isEnabled: Bool
    public var blurRadius: Double
    public var darkenAmount: Double
    public var backgroundScale: Double
    public var foregroundScale: Double
    public var foregroundOffsetX: Double
    public var foregroundOffsetY: Double
    public var backgroundSourceMode: String?
    public var backgroundAssetPath: String?
    public var backgroundAssetDisplayName: String?
    public var backgroundVideoTakeID: UUID?
    public var renderWidth: Double
    public var renderHeight: Double
    public var processingPriority: String
    public var presetName: String?
    
    public init(
        isEnabled: Bool,
        blurRadius: Double,
        darkenAmount: Double,
        backgroundScale: Double,
        foregroundScale: Double,
        foregroundOffsetX: Double = 0,
        foregroundOffsetY: Double = 0,
        backgroundSourceMode: String? = nil,
        backgroundAssetPath: String? = nil,
        backgroundAssetDisplayName: String? = nil,
        backgroundVideoTakeID: UUID? = nil,
        renderWidth: Double,
        renderHeight: Double,
        processingPriority: String,
        presetName: String?
    ) {
        self.isEnabled = isEnabled
        self.blurRadius = blurRadius
        self.darkenAmount = darkenAmount
        self.backgroundScale = backgroundScale
        self.foregroundScale = foregroundScale
        self.foregroundOffsetX = foregroundOffsetX
        self.foregroundOffsetY = foregroundOffsetY
        self.backgroundSourceMode = backgroundSourceMode
        self.backgroundAssetPath = backgroundAssetPath
        self.backgroundAssetDisplayName = backgroundAssetDisplayName
        self.backgroundVideoTakeID = backgroundVideoTakeID
        self.renderWidth = renderWidth
        self.renderHeight = renderHeight
        self.processingPriority = processingPriority
        self.presetName = presetName
    }

    private enum CodingKeys: String, CodingKey {
        case isEnabled
        case blurRadius
        case darkenAmount
        case backgroundScale
        case foregroundScale
        case foregroundOffsetX
        case foregroundOffsetY
        case backgroundSourceMode
        case backgroundAssetPath
        case backgroundAssetDisplayName
        case backgroundVideoTakeID
        case renderWidth
        case renderHeight
        case processingPriority
        case presetName
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.isEnabled = try container.decode(Bool.self, forKey: .isEnabled)
        self.blurRadius = try container.decode(Double.self, forKey: .blurRadius)
        self.darkenAmount = try container.decode(Double.self, forKey: .darkenAmount)
        self.backgroundScale = try container.decode(Double.self, forKey: .backgroundScale)
        self.foregroundScale = try container.decode(Double.self, forKey: .foregroundScale)
        self.foregroundOffsetX = try container.decodeIfPresent(Double.self, forKey: .foregroundOffsetX) ?? 0
        self.foregroundOffsetY = try container.decodeIfPresent(Double.self, forKey: .foregroundOffsetY) ?? 0
        self.backgroundSourceMode = try container.decodeIfPresent(String.self, forKey: .backgroundSourceMode)
        self.backgroundAssetPath = try container.decodeIfPresent(String.self, forKey: .backgroundAssetPath)
        self.backgroundAssetDisplayName = try container.decodeIfPresent(String.self, forKey: .backgroundAssetDisplayName)
        self.backgroundVideoTakeID = try container.decodeIfPresent(UUID.self, forKey: .backgroundVideoTakeID)
        self.renderWidth = try container.decode(Double.self, forKey: .renderWidth)
        self.renderHeight = try container.decode(Double.self, forKey: .renderHeight)
        self.processingPriority = try container.decode(String.self, forKey: .processingPriority)
        self.presetName = try container.decodeIfPresent(String.self, forKey: .presetName)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(isEnabled, forKey: .isEnabled)
        try container.encode(blurRadius, forKey: .blurRadius)
        try container.encode(darkenAmount, forKey: .darkenAmount)
        try container.encode(backgroundScale, forKey: .backgroundScale)
        try container.encode(foregroundScale, forKey: .foregroundScale)
        try container.encode(foregroundOffsetX, forKey: .foregroundOffsetX)
        try container.encode(foregroundOffsetY, forKey: .foregroundOffsetY)
        try container.encodeIfPresent(backgroundSourceMode, forKey: .backgroundSourceMode)
        try container.encodeIfPresent(backgroundAssetPath, forKey: .backgroundAssetPath)
        try container.encodeIfPresent(backgroundAssetDisplayName, forKey: .backgroundAssetDisplayName)
        try container.encodeIfPresent(backgroundVideoTakeID, forKey: .backgroundVideoTakeID)
        try container.encode(renderWidth, forKey: .renderWidth)
        try container.encode(renderHeight, forKey: .renderHeight)
        try container.encode(processingPriority, forKey: .processingPriority)
        try container.encodeIfPresent(presetName, forKey: .presetName)
    }
}

// MARK: - Take Classification Types
public enum TakeType: String, CaseIterable, Codable, Sendable {
    case regular = "regular"
    case merged = "merged"    // This is a merged video combining multiple takes
    case slate = "slate"      // This is a slate take
    case pipSlate = "pipSlate" // Picture-in-Picture composite slate
    case pipComponent = "pipComponent" // Internal PiP component capture (portrait/close-up clips)
    case exported = "exported" // This is an exported individual file
    
    public var displayName: String {
        switch self {
        case .regular: return "Take"
        case .merged: return "Merged Video"
        case .slate: return "Slate"
        case .pipSlate: return "PiP Slate"
        case .pipComponent: return "PiP Component"
        case .exported: return "Exported Take"
        }
    }
    
    public var icon: String {
        switch self {
        case .regular: return "video.fill"
        case .merged: return "film.stack.fill"
        case .slate: return "person.crop.rectangle.fill"
        case .pipSlate: return "rectangle.on.rectangle"
        case .pipComponent: return "rectangle.on.rectangle"
        case .exported: return "square.and.arrow.up.fill"
        }
    }
    
    public var isSlateLike: Bool {
        switch self {
        case .slate, .pipSlate:
            return true
        default:
            return false
        }
    }

    public var isPIPComponent: Bool {
        self == .pipComponent
    }
}

public struct Contact: Codable, Equatable, Sendable {
    public var name: String
    public var email: String?
    public var phone: String?
    public init(name: String, email: String? = nil, phone: String? = nil) {
        self.name = name; self.email = email; self.phone = phone
    }
}

public struct LocationInfo: Codable, Equatable, Sendable {
    public var label: String   // e.g., "Casting Office", "Studio"
    public var address: String?
    public init(label: String, address: String? = nil) {
        self.label = label; self.address = address
    }
}

public struct InPersonAddress: Codable, Equatable, Sendable {
    public var street1: String
    public var street2: String
    public var city: String
    public var state: String
    public var postalCode: String
    public var country: String

    public init(
        street1: String = "",
        street2: String = "",
        city: String = "",
        state: String = "",
        postalCode: String = "",
        country: String = ""
    ) {
        self.street1 = street1
        self.street2 = street2
        self.city = city
        self.state = state
        self.postalCode = postalCode
        self.country = country
    }
}

// ENHANCED: Video marker model for professional annotation system
public struct TakeVideoMarker: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let timestamp: TimeInterval  // Time in seconds
    public let title: String           // e.g., "Great expression", "Remember line"
    public let description: String?    // Optional detailed description
    public let type: MarkerType       // Type of marker for color/icon
    public let createdAt: Date        // When marker was created
    
    public enum MarkerType: String, CaseIterable, Codable, Sendable {
        case good = "good"
        case note = "note"
        case problem = "problem"
        case favorite = "favorite"
        
        public var iconName: String {
            switch self {
            case .good: return "checkmark.circle.fill"
            case .note: return "note.text"
            case .problem: return "exclamationmark.triangle.fill"
            case .favorite: return "star.fill"
            }
        }
        
        public var displayName: String {
            switch self {
            case .good: return "Good"
            case .note: return "Note"
            case .problem: return "Issue"
            case .favorite: return "Star"
            }
        }
    }
    
    public init(timestamp: TimeInterval, title: String, description: String? = nil, type: MarkerType, createdAt: Date = Date()) {
        self.id = UUID() // FIXED: Initialize in constructor instead of default value
        self.timestamp = timestamp
        self.title = title
        self.description = description
        self.type = type
        self.createdAt = createdAt
    }
}

// NEW: Export tracking metadata for post-export flow
public struct ExportMetadata: Codable, Equatable, Sendable {
    public let exportID: UUID
    public let exportDate: Date
    public let exportType: ExportType
    public let originalTakeIDs: [UUID] // Track which individual takes were included
    public let exportOptions: ExportOptionsSnapshot
    
    public enum ExportType: String, CaseIterable, Codable, Sendable {
        case merged = "merged"
        case separate = "separate"
        
        public var displayName: String {
            switch self {
            case .merged: return "Merged Video"
            case .separate: return "Separate Files"
            }
        }
        
        public var icon: String {
            switch self {
            case .merged: return "film.fill"
            case .separate: return "doc.on.doc.fill"
            }
        }
    }
    
    public init(exportID: UUID = UUID(), exportDate: Date = Date(), exportType: ExportType, originalTakeIDs: [UUID], exportOptions: ExportOptionsSnapshot) {
        self.exportID = exportID
        self.exportDate = exportDate
        self.exportType = exportType
        self.originalTakeIDs = originalTakeIDs
        self.exportOptions = exportOptions
    }
}

// NEW: Snapshot of export options for tracking
public struct ExportOptionsSnapshot: Codable, Equatable, Sendable {
    public let quality: String
    public let format: String
    public let includedMarkers: Bool
    public let takeCount: Int
    
    public init(quality: String, format: String, includedMarkers: Bool, takeCount: Int) {
        self.quality = quality
        self.format = format
        self.includedMarkers = includedMarkers
        self.takeCount = takeCount
    }
}

// NEW: Edit tracking metadata for crop/trim operations
public struct TakeEditMetadata: Codable, Equatable, Sendable {
    public let editID: UUID
    public let editedDate: Date
    
    // Trimming data
    public let hasTrimming: Bool
    public let trimStartTime: Double? // In seconds
    public let trimEndTime: Double?   // In seconds
    
    // Cropping data
    public let hasCropping: Bool
    public let cropRect: CGRect?      // Normalized coordinates (0.0 to 1.0)
    public let cropRotationDegrees: Double?
    
    public init(
        editID: UUID = UUID(),
        editedDate: Date = Date(),
        hasTrimming: Bool = false,
        trimStartTime: Double? = nil,
        trimEndTime: Double? = nil,
        hasCropping: Bool = false,
        cropRect: CGRect? = nil,
        cropRotationDegrees: Double? = nil
    ) {
        self.editID = editID
        self.editedDate = editedDate
        self.hasTrimming = hasTrimming
        self.trimStartTime = trimStartTime
        self.trimEndTime = trimEndTime
        self.hasCropping = hasCropping
        self.cropRect = cropRect
        self.cropRotationDegrees = cropRotationDegrees
    }
    
    // Computed properties
    public var hasEdits: Bool {
        return hasTrimming || hasCropping
    }
    
    public var editSummary: String {
        var parts: [String] = []
        if hasTrimming {
            if let start = trimStartTime, let end = trimEndTime {
                parts.append("Trimmed (\(Int(end - start))s)")
            } else {
                parts.append("Trimmed")
            }
        }
        if hasCropping {
            parts.append("Cropped")
            if let rotation = cropRotationDegrees, abs(rotation) > 0.1 {
                parts.append(String(format: "Rotated %.1f°", rotation))
            }
        }
        return parts.isEmpty ? "No edits" : parts.joined(separator: ", ")
    }
}

public struct ProjectTake: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let filePath: String
    public let durationSeconds: Double
    public let thumbnailPath: String?
    public var takeNotes: String?  // Make mutable for repository updates
    public let createdAt: Date
    public var videoMarkers: [TakeVideoMarker]  // Make mutable for repository updates
    
    // UNIFIED: Replace ALL legacy boolean flags with single TakeRating
    public var rating: TakeRating = .unrated
    
    // NEW: Scene organization fields (Phase 2: Data Architecture)
    public var sceneNumber: Int = 1           // Which scene this take belongs to
    public var takeNumber: Int = 1            // Take number within the scene
    public var slateNumber: String? = nil     // Optional slate identifier (e.g., "1A", "2B")
    public var slateID: String? = nil         // Alternative slate identifier for complex projects
    
    // NEW: Video orientation for Smart Fill system
    public var capturedOrientation: VideoOrientation? = nil  // Portrait/Landscape when recorded
    public var overrideSmartFill: TriState? = nil            // Override Smart Fill policy
    
    // NEW: SmartFill file management - THE CRITICAL FIX FOR PHASE 2-3
    public var smartFilledFilePath: String? = nil            // Path to _smartfill.mov version
    public var editedFilePath: String? = nil    // 🚨 NEW: Path to _edited.mov version
    
    // NEW: Export tracking for post-export flow
    public var exportMetadata: ExportMetadata?  // Present for merged/exported videos
    public var exportedFromTakeIDs: [UUID] = []  // Track export status on individual takes
    public var lastExportDate: Date?  // When this take was last exported
    
    // NEW: When this deliverable was submitted (if ever)
    public var submittedAt: Date? = nil

    // NEW: Take type classification
    public var takeType: TakeType = .regular
    
    // 🚨 NEW: Edit metadata for crop/trim operations
    public var editMetadata: TakeEditMetadata? = nil
    
    // NEW: Persist SmartFill settings used to create this take
    public var smartFillSettings: SmartFillSettingsSnapshot? = nil
    
    // NEW: Persist PiP composite metadata (audio + sources)
    public var pipSlateMetadata: PIPSlateCompositeMetadata? = nil
    
    // CUSTOM DECODER: Provide default values for new fields to fix migration
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(UUID.self, forKey: .id)
        filePath = try container.decode(String.self, forKey: .filePath)
        durationSeconds = try container.decode(Double.self, forKey: .durationSeconds)
        thumbnailPath = try container.decodeIfPresent(String.self, forKey: .thumbnailPath)
        takeNotes = try container.decodeIfPresent(String.self, forKey: .takeNotes)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        videoMarkers = try container.decodeIfPresent([TakeVideoMarker].self, forKey: .videoMarkers) ?? []
        rating = try container.decodeIfPresent(TakeRating.self, forKey: .rating) ?? .unrated
        
        // NEW SCENE ORGANIZATION FIELDS: Provide smart defaults for backward compatibility
        sceneNumber = try container.decodeIfPresent(Int.self, forKey: .sceneNumber) ?? 1
        takeNumber = try container.decodeIfPresent(Int.self, forKey: .takeNumber) ?? 1
        slateNumber = try container.decodeIfPresent(String.self, forKey: .slateNumber)
        slateID = try container.decodeIfPresent(String.self, forKey: .slateID)
        
        // NEW: Smart Fill orientation fields with backward compatibility
        capturedOrientation = try container.decodeIfPresent(VideoOrientation.self, forKey: .capturedOrientation)
        overrideSmartFill = try container.decodeIfPresent(TriState.self, forKey: .overrideSmartFill)
        
        // NEW: SmartFill file path with backward compatibility
        smartFilledFilePath = try container.decodeIfPresent(String.self, forKey: .smartFilledFilePath)
        editedFilePath = try container.decodeIfPresent(String.self, forKey: .editedFilePath)
        
        // NEW FIELDS: Provide default values for backward compatibility
        exportMetadata = try container.decodeIfPresent(ExportMetadata.self, forKey: .exportMetadata)
        exportedFromTakeIDs = try container.decodeIfPresent([UUID].self, forKey: .exportedFromTakeIDs) ?? []
        lastExportDate = try container.decodeIfPresent(Date.self, forKey: .lastExportDate)
        takeType = try container.decodeIfPresent(TakeType.self, forKey: .takeType) ?? .regular
        
        // NEW: Submitted flag for deliverables
        submittedAt = try container.decodeIfPresent(Date.self, forKey: .submittedAt)
        
        // 🚨 NEW: Edit metadata with backward compatibility
        editMetadata = try container.decodeIfPresent(TakeEditMetadata.self, forKey: .editMetadata)
        smartFillSettings = try container.decodeIfPresent(SmartFillSettingsSnapshot.self, forKey: .smartFillSettings)
        pipSlateMetadata = try container.decodeIfPresent(PIPSlateCompositeMetadata.self, forKey: .pipSlateMetadata)
    }
    
    private enum CodingKeys: String, CodingKey {
        case id, filePath, durationSeconds, thumbnailPath, takeNotes, createdAt, videoMarkers, rating
        case sceneNumber, takeNumber, slateNumber, slateID  // Scene organization fields
        case capturedOrientation, overrideSmartFill          // NEW: Smart Fill fields
        case smartFilledFilePath                             // NEW: SmartFill file path
        case editedFilePath                                  // 🚨 NEW: Edited file path
        case exportMetadata, exportedFromTakeIDs, lastExportDate, takeType
        case editMetadata                                    // 🚨 NEW: Edit metadata
        case smartFillSettings                               // NEW: SmartFill settings snapshot
        case pipSlateMetadata                                // NEW: PiP composite metadata
        // NEW: Deliverable submission tracking
        case submittedAt
    }
    
    public init(
        id: UUID = UUID(),
        filePath: String,
        durationSeconds: Double,
        thumbnailPath: String? = nil,
        takeNotes: String? = nil,
        createdAt: Date = Date(),
        videoMarkers: [TakeVideoMarker] = [],
        rating: TakeRating = .unrated,
        sceneNumber: Int = 1,           // Scene organization
        takeNumber: Int = 1,            // Scene organization
        slateNumber: String? = nil,     // Scene organization
        slateID: String? = nil,         // Scene organization
        capturedOrientation: VideoOrientation? = nil,  // NEW: Smart Fill orientation
        overrideSmartFill: TriState? = nil,           // NEW: Smart Fill override
        smartFilledFilePath: String? = nil,           // NEW: SmartFill file path
        editedFilePath: String? = nil,                // 🚨 NEW: Edited file path
        exportMetadata: ExportMetadata? = nil,
        exportedFromTakeIDs: [UUID] = [],
        lastExportDate: Date? = nil,
        submittedAt: Date? = nil,
        takeType: TakeType = .regular,
        editMetadata: TakeEditMetadata? = nil,         // 🚨 NEW: Edit metadata
        smartFillSettings: SmartFillSettingsSnapshot? = nil,
        pipSlateMetadata: PIPSlateCompositeMetadata? = nil
    ) {
        self.id = id
        self.filePath = filePath
        self.durationSeconds = durationSeconds
        self.thumbnailPath = thumbnailPath
        self.takeNotes = takeNotes
        self.createdAt = createdAt
        self.videoMarkers = videoMarkers
        self.rating = rating
        self.sceneNumber = sceneNumber
        self.takeNumber = takeNumber
        self.slateNumber = slateNumber
        self.slateID = slateID
        self.capturedOrientation = capturedOrientation  // NEW: Smart Fill orientation
        self.overrideSmartFill = overrideSmartFill     // NEW: Smart Fill override
        self.smartFilledFilePath = smartFilledFilePath // NEW: SmartFill file path
        self.editedFilePath = editedFilePath           // 🚨 NEW: Edited file path
        self.exportMetadata = exportMetadata
        self.exportedFromTakeIDs = exportedFromTakeIDs
        self.lastExportDate = lastExportDate
        self.submittedAt = submittedAt
        self.takeType = takeType
        self.editMetadata = editMetadata               // 🚨 NEW: Edit metadata
        self.smartFillSettings = smartFillSettings
        self.pipSlateMetadata = pipSlateMetadata
    }
    
    // COMPUTED: Convenience properties for UI compatibility (read-only)
    public var isFavorite: Bool { rating == .option }
    public var isBest: Bool { rating == .finalSelect }
    public var isRejected: Bool { rating == .rejected }
    
    // NEW: Export status computed properties
    public var isMergedVideo: Bool { takeType == .merged }
    public var isExported: Bool { takeType == .exported || lastExportDate != nil || !exportedFromTakeIDs.isEmpty }
    public var wasUsedInExport: Bool { !exportedFromTakeIDs.isEmpty }
    public var isPiPComposite: Bool { takeType == .pipSlate }
    public var isSlateLike: Bool { takeType.isSlateLike }
    public var pipAudioSummary: String? { pipSlateMetadata?.enabledAudioDescription }
    
    // NEW: Scene organization computed properties
    public var sceneDisplayName: String {
        if let slateNumber = slateNumber {
            return "Scene \(sceneNumber) (\(slateNumber))"
        } else {
            return "Scene \(sceneNumber)"
        }
    }
    
    public var takeDisplayName: String {
        return "Take \(takeNumber)"
    }
    
    public var fullDisplayName: String {
        return "\(sceneDisplayName), \(takeDisplayName)"
    }
    
    // NEW: Formatted display strings for export info
    public var exportStatusDisplay: String {
        if isMergedVideo, let metadata = exportMetadata {
            return "\(metadata.exportType.displayName) • \(metadata.originalTakeIDs.count) takes"
        } else if isExported {
            return "Exported"
        } else {
            return ""
        }
    }
    
    // MARK: - Effective Edit State
    
    public var hasAppliedTrim: Bool {
        guard let metadata = editMetadata,
              metadata.hasTrimming,
              let start = metadata.trimStartTime,
              let end = metadata.trimEndTime else {
            return false
        }
        return end > start
    }
    
    public var hasAppliedCrop: Bool {
        guard let metadata = editMetadata,
              metadata.hasCropping,
              metadata.cropRect != nil else {
            return false
        }
        return true
    }
    
    public var effectiveDurationSeconds: Double {
        guard hasAppliedTrim,
              let start = editMetadata?.trimStartTime,
              let end = editMetadata?.trimEndTime,
              end > start else {
            return durationSeconds
        }
        return end - start
    }
    
    public var trimTimeRangeSeconds: (start: Double, end: Double)? {
        guard hasAppliedTrim,
              let start = editMetadata?.trimStartTime,
              let end = editMetadata?.trimEndTime,
              end > start else {
            return nil
        }
        return (start, end)
    }
    
    public var trimTimeRange: CMTimeRange? {
        guard let range = trimTimeRangeSeconds else { return nil }
        let startTime = CMTime(seconds: range.start, preferredTimescale: 600)
        let duration = CMTime(seconds: range.end - range.start, preferredTimescale: 600)
        return CMTimeRange(start: startTime, duration: duration)
    }

    // NEW: Smart Fill computed properties
    public var needsSmartFillInLandscapeSession: Bool {
        return capturedOrientation == .portrait
    }
    
    public var orientationDisplayName: String {
        return capturedOrientation?.displayName ?? "Unknown"
    }

    // NEW: SmartFill computed properties for UI integration with performance optimization
    private static var smartFillCache: [UUID: (isValid: Bool, timestamp: Date)] = [:]
    private static let cacheTimeout: TimeInterval = 5.0 // Cache results for 5 seconds
    
    // MARK: - Static Cache Management
    public static func invalidateSmartFillCache(for takeID: UUID) {
        smartFillCache.removeValue(forKey: takeID)
        print("🔄 SmartFill cache invalidated for take: \(takeID)")
    }
    
    public static func clearSmartFillCache() {
        smartFillCache.removeAll()
        print("🧹 SmartFill cache cleared")
    }
    
    // 🚨 PHASE 1 FIX: Enhanced SmartFill detection using corrected VideoVariantResolver
    public var hasSmartFilledVersion: Bool {
        // PERFORMANCE FIX: Cache results to prevent redundant file system checks per UI refresh
        if let cached = Self.smartFillCache[id],
           Date().timeIntervalSince(cached.timestamp) < Self.cacheTimeout {
            return cached.isValid
        }
        
        let fileName = URL(fileURLWithPath: filePath).lastPathComponent
        print("🔍 PHASE 1 FIX - ProjectTake.hasSmartFilledVersion for \(fileName)")
        print("   📁 Original file: \(filePath)")
        print("   🆔 Take ID: \(id)")
        print("   📱 Orientation: \(capturedOrientation?.displayName ?? "nil")")
        print("   📂 SmartFill field: \(smartFilledFilePath ?? "NONE")")
        
        // PHASE 1 FIX: Use corrected VideoVariantResolver for consistent file resolution
        let hasSmartFill = VideoVariantResolver.hasSmartFilledVersion(for: self)
        
        // Cache the result
        Self.smartFillCache[id] = (isValid: hasSmartFill, timestamp: Date())
        
        if hasSmartFill {
            print("   🎉 PHASE 1: SmartFill file VALIDATED - UI will show parent/child for \(fileName)")
        } else {
            print("   😞 PHASE 1: No valid SmartFill - UI will show original only for \(fileName)")
        }
        
        return hasSmartFill
    }
    
    // 🚨 CRITICAL FIX: Improved effectiveFilePath that prefers edited version
    public var effectiveFilePath: String {
        let originalFileName = URL(fileURLWithPath: filePath).lastPathComponent
        print("🔍 PATH VOLATILITY FIX - ProjectTake.effectiveFilePath for: \(originalFileName)")
        print("   📁 Take filePath: \(filePath) (relative: \(!filePath.hasPrefix("/")))")
        
        // 🚨 EXPORTED VIDEO FIX: Exported videos should never use edited versions - they ARE the final version
        print("🚨 EXPORTED VIDEO DEBUG: filePath=\(filePath), takeType=\(takeType), originalFileName=\(originalFileName)")
        if filePath.contains("/STS_Exports/") || originalFileName.hasPrefix("STS_") {
            let exportURL = VideoVariantResolver.urlForRelativePath(filePath)
            print("✅ EXPORTED VIDEO FIX: Using original export file: \(exportURL.lastPathComponent)")
            return exportURL.path
        }
        
        // CRITICAL FIX: Check for edited version first (for non-exported videos)
        if let editedPath = editedFilePath {
            let editedURL = VideoVariantResolver.urlForRelativePath(editedPath)
            if FileManager.default.fileExists(atPath: editedURL.path) {
                print("✅ PATH VOLATILITY FIX: effectiveFilePath using EDITED version: \(editedURL.lastPathComponent)")
                return editedURL.path
            } else {
                print("⚠️ PATH VOLATILITY FIX: Edited file missing: \(editedPath)")
            }
        }
        
        // PHASE 1 FIX: Use VideoVariantResolver with enhanced debugging
        let effectiveURL = VideoVariantResolver.effectiveURL(for: self)
        
        let isUsingSmartFill = VideoVariantResolver.smartFillURL(for: self)?.path == effectiveURL.path
        
        if isUsingSmartFill {
            print("✅ PATH VOLATILITY FIX: effectiveFilePath using VALIDATED SmartFill: \(effectiveURL.lastPathComponent)")
        } else {
            print("ℹ️ PATH VOLATILITY FIX: effectiveFilePath using original: \(effectiveURL.lastPathComponent)")
        }
        
        return effectiveURL.path
    }
    
    // 🔥 NEW: Get resolved absolute URL for this take (handles both relative and absolute paths)
    public var resolvedURL: URL {
        return VideoVariantResolver.originalURL(for: self)
    }
    
    // 🔥 NEW: Check if file actually exists on disk
    public var fileExists: Bool {
        return FileManager.default.fileExists(atPath: resolvedURL.path)
    }
    
    // 🔥 NEW: Get file size from disk (returns 0 if file doesn't exist)
    public var actualFileSize: Int64 {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: resolvedURL.path)
            return attributes[.size] as? Int64 ?? 0
        } catch {
            return 0
        }
    }
    
    // 🔥 NEW: Path type indicator for debugging
    public var pathType: String {
        return filePath.hasPrefix("/") ? "absolute" : "relative"
    }
    
    // 🚨 ENHANCED: Robust video file validation with container path support
    // private func isValidVideoFile(at path: String) -> Bool {
    // ... (remove this method as validation is now in VideoVariantResolver)
    
    public var smartFillStatusText: String {
        if hasSmartFilledVersion {
            return "Smart Fill Applied"
        } else if capturedOrientation == .portrait {
            return "Portrait (No Smart Fill)"
        } else {
            return "Landscape"
        }
    }
    
    public var smartFillStatusIcon: String {
        if hasSmartFilledVersion {
            return "rectangle.fill.badge.checkmark"
        } else if capturedOrientation == .portrait {
            return "rectangle.portrait.fill"
        } else {
            return "rectangle.fill"
        }
    }

    // NEW: Edit status computed properties
    public var hasEdits: Bool {
        return editMetadata?.hasEdits ?? false
    }
    
    public var editSummary: String {
        return editMetadata?.editSummary ?? "No edits"
    }
    
    public var isCropped: Bool {
        return editMetadata?.hasCropping ?? false
    }
    
    public var isTrimmed: Bool {
        return editMetadata?.hasTrimming ?? false
    }
}

public enum SessionBadge: String, Codable, CaseIterable, Sendable {
    case romanPhilosopher
}

public struct ChecklistProgress: Codable, Equatable, Identifiable, Sendable {
    public enum Item: String, CaseIterable, Codable, Sendable {
        case characterBreakdown
        case slateEssentials
        case quietTech
        case wardrobeAlignment
        case frameAndLight
        case submissionWindow
    }
    
    public let id: UUID
    public var sessionID: UUID?
    public var checks: [Item: Bool]
    public var completedAt: Date?
    public var achievementUnlocked: Bool
    
    public init(
        id: UUID = UUID(),
        sessionID: UUID? = nil,
        checks: [Item: Bool]? = nil,
        completedAt: Date? = nil,
        achievementUnlocked: Bool = false
    ) {
        self.id = id
        self.sessionID = sessionID
        self.completedAt = completedAt
        self.achievementUnlocked = achievementUnlocked
        
        var map: [Item: Bool] = [:]
        for item in Item.allCases {
            map[item] = checks?[item] ?? false
        }
        self.checks = map
    }
    
    public mutating func toggle(_ item: Item) {
        let currentValue = checks[item] ?? false
        checks[item] = !currentValue
        if !isComplete {
            completedAt = nil
            achievementUnlocked = false
        }
    }
    
    public mutating func markCompleteIfNeeded() {
        guard isComplete else { return }
        if completedAt == nil {
            completedAt = Date()
        }
    }
    
    public var completionFraction: Double {
        let total = Double(Item.allCases.count)
        let checked = Double(checks.filter { $0.value }.count)
        return total == 0 ? 0 : checked / total
    }
    
    public var isComplete: Bool {
        Item.allCases.allSatisfy { checks[$0] ?? false }
    }
}

public enum SlatePromptMode: String, Codable, Sendable, Hashable {
    case auto
    case custom
}

public struct ProjectSession: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID  // Make mutable for repository operations
    public let type: SessionType
    public var date: Date  // Make mutable for repository operations
    public var location: LocationInfo?
    public let contact: Contact?
    public let notes: String?
    public var takes: [ProjectTake]
    public let roleName: String?
    public let callbackNotes: String?
    public let parkingInfo: String?
    public var isArchived: Bool = false
    
    // UNIFIED: Keep session-level favorite (not related to take ratings)
    public var isFavorite: Bool = false
    
    // NEW: Smart Fill session settings
    public var primaryOrientation: VideoOrientation? = nil  // Session's primary orientation
    public var smartFillEnabled: Bool? = nil                // nil = inherit from global settings
    public var slatePrompt: String? = nil                   // Composed slate string (legacy)
    public var slatePromptMode: SlatePromptMode = .auto
    public var slatePromptOverride: String? = nil
    public var slatePromptInputsHash: String? = nil
    public var slatePromptUpdatedAt: Date? = nil
    public var lastCustomSlatePrompt: String? = nil
    public var auditionChecklist: ChecklistProgress?
    public var unlockedBadges: [SessionBadge] = []
    public var sidesFileName: String? = nil
    public var breakdownFileName: String? = nil
    public var breakdownNotes: String? = nil
    public var pipSlateSession: SlatePIPSession? = nil

    // MARK: - In-Person Logistics (Session-Level)
    public var inPersonAddress: InPersonAddress? = nil
    public var inPersonAddressRawPaste: String? = nil
    public var castingPhone: String? = nil
    public var repPhone: String? = nil

    // MARK: - Session Overrides (inherit-from-project unless overridden)
    // Nullable for backward compatibility.
    public var auditionDueDateOverride: Date? = nil
    public var sceneCountOverride: Int? = nil
    public var submittedHeadshotIDOverride: UUID? = nil
    public var slateSelectionsOverride: SlateSelections? = nil

    // NEW: Computed properties for export functionality
    public var mergedVideoTakes: [ProjectTake] {
        takes.filter { $0.takeType == .merged }
    }
    
    public var regularTakes: [ProjectTake] {
        takes.filter { $0.takeType == .regular }
    }
    
    public var slateTakes: [ProjectTake] {
        takes.filter { $0.takeType.isSlateLike }
    }
    
    public var exportedTakes: [ProjectTake] {
        takes.filter { $0.takeType == .exported }
    }
    
    // NEW: Get takes sorted with merged videos at top
    public var takesSortedForDisplay: [ProjectTake] {
        let merged = mergedVideoTakes.sorted { $0.createdAt > $1.createdAt }
        let exported = exportedTakes.sorted { $0.createdAt > $1.createdAt }
        let regular = regularTakes.sorted { $0.createdAt > $1.createdAt }
        let slates = slateTakes.sorted { $0.createdAt > $1.createdAt }
        
        return merged + exported + regular + slates
    }

    // CUSTOM DECODER: Add Smart Fill fields with backward compatibility
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(UUID.self, forKey: .id)
        type = try container.decode(SessionType.self, forKey: .type)
        date = try container.decode(Date.self, forKey: .date)
        location = try container.decodeIfPresent(LocationInfo.self, forKey: .location)
        contact = try container.decodeIfPresent(Contact.self, forKey: .contact)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        takes = try container.decodeIfPresent([ProjectTake].self, forKey: .takes) ?? []
        roleName = try container.decodeIfPresent(String.self, forKey: .roleName)
        callbackNotes = try container.decodeIfPresent(String.self, forKey: .callbackNotes)
        parkingInfo = try container.decodeIfPresent(String.self, forKey: .parkingInfo)
        isArchived = try container.decodeIfPresent(Bool.self, forKey: .isArchived) ?? false
        isFavorite = try container.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false
        
        // NEW: Smart Fill fields with backward compatibility
        primaryOrientation = try container.decodeIfPresent(VideoOrientation.self, forKey: .primaryOrientation)
        smartFillEnabled = try container.decodeIfPresent(Bool.self, forKey: .smartFillEnabled)
        slatePrompt = try container.decodeIfPresent(String.self, forKey: .slatePrompt)
        slatePromptMode = try container.decodeIfPresent(SlatePromptMode.self, forKey: .slatePromptMode) ?? .auto
        slatePromptOverride = try container.decodeIfPresent(String.self, forKey: .slatePromptOverride)
        slatePromptInputsHash = try container.decodeIfPresent(String.self, forKey: .slatePromptInputsHash)
        slatePromptUpdatedAt = try container.decodeIfPresent(Date.self, forKey: .slatePromptUpdatedAt)
        lastCustomSlatePrompt = try container.decodeIfPresent(String.self, forKey: .lastCustomSlatePrompt)
        auditionChecklist = try container.decodeIfPresent(ChecklistProgress.self, forKey: .auditionChecklist)
        unlockedBadges = try container.decodeIfPresent([SessionBadge].self, forKey: .unlockedBadges) ?? []
        sidesFileName = try container.decodeIfPresent(String.self, forKey: .sidesFileName)
        breakdownFileName = try container.decodeIfPresent(String.self, forKey: .breakdownFileName)
        breakdownNotes = try container.decodeIfPresent(String.self, forKey: .breakdownNotes)
        pipSlateSession = try container.decodeIfPresent(SlatePIPSession.self, forKey: .pipSlateSession)
        auditionDueDateOverride = try container.decodeIfPresent(Date.self, forKey: .auditionDueDateOverride)
        sceneCountOverride = try container.decodeIfPresent(Int.self, forKey: .sceneCountOverride)
        submittedHeadshotIDOverride = try container.decodeIfPresent(UUID.self, forKey: .submittedHeadshotIDOverride)
        slateSelectionsOverride = try container.decodeIfPresent(SlateSelections.self, forKey: .slateSelectionsOverride)
        inPersonAddress = try container.decodeIfPresent(InPersonAddress.self, forKey: .inPersonAddress)
        inPersonAddressRawPaste = try container.decodeIfPresent(String.self, forKey: .inPersonAddressRawPaste)
        castingPhone = try container.decodeIfPresent(String.self, forKey: .castingPhone)
        repPhone = try container.decodeIfPresent(String.self, forKey: .repPhone)
    }
    
    private enum CodingKeys: String, CodingKey {
        case id, type, date, location, contact, notes, takes, roleName, callbackNotes, parkingInfo
        case isArchived, isFavorite
        case primaryOrientation, smartFillEnabled, slatePrompt, slatePromptMode, slatePromptOverride, slatePromptInputsHash, slatePromptUpdatedAt, lastCustomSlatePrompt
        case auditionChecklist, unlockedBadges
        case sidesFileName, breakdownFileName, breakdownNotes
        case pipSlateSession
        case auditionDueDateOverride, sceneCountOverride, submittedHeadshotIDOverride, slateSelectionsOverride
        case inPersonAddress, inPersonAddressRawPaste, castingPhone, repPhone
    }
    
    public init(
        id: UUID = UUID(),
        type: SessionType,
        date: Date = Date(),
        location: LocationInfo? = nil,
        contact: Contact? = nil,
        notes: String? = nil,
        takes: [ProjectTake] = [],
        roleName: String? = nil,
        callbackNotes: String? = nil,
        parkingInfo: String? = nil,
        isFavorite: Bool = false,
        isArchived: Bool = false,
        primaryOrientation: VideoOrientation? = nil,  // NEW: Smart Fill
        smartFillEnabled: Bool? = nil,                 // NEW: Smart Fill
        slatePrompt: String? = nil,
        slatePromptMode: SlatePromptMode = .auto,
        slatePromptOverride: String? = nil,
        slatePromptInputsHash: String? = nil,
        slatePromptUpdatedAt: Date? = nil,
        lastCustomSlatePrompt: String? = nil,
        sidesFileName: String? = nil,
        breakdownFileName: String? = nil,
        breakdownNotes: String? = nil,
        pipSlateSession: SlatePIPSession? = nil,
        auditionDueDateOverride: Date? = nil,
        sceneCountOverride: Int? = nil,
        submittedHeadshotIDOverride: UUID? = nil,
        slateSelectionsOverride: SlateSelections? = nil,
        inPersonAddress: InPersonAddress? = nil,
        inPersonAddressRawPaste: String? = nil,
        castingPhone: String? = nil,
        repPhone: String? = nil
    ) {
        self.id = id
        self.type = type
        self.date = date
        self.location = location
        self.contact = contact
        self.notes = notes
        self.takes = takes
        self.roleName = roleName
        self.callbackNotes = callbackNotes
        self.parkingInfo = parkingInfo
        self.isFavorite = isFavorite
        self.isArchived = isArchived
        self.primaryOrientation = primaryOrientation
        self.smartFillEnabled = smartFillEnabled
        self.slatePrompt = slatePrompt
        self.slatePromptMode = slatePromptMode
        self.slatePromptOverride = slatePromptOverride
        self.slatePromptInputsHash = slatePromptInputsHash
        self.slatePromptUpdatedAt = slatePromptUpdatedAt
        self.lastCustomSlatePrompt = lastCustomSlatePrompt
        self.auditionChecklist = nil
        self.unlockedBadges = []
        self.sidesFileName = sidesFileName
        self.breakdownFileName = breakdownFileName
        self.breakdownNotes = breakdownNotes
        self.pipSlateSession = pipSlateSession
        self.auditionDueDateOverride = auditionDueDateOverride
        self.sceneCountOverride = sceneCountOverride
        self.submittedHeadshotIDOverride = submittedHeadshotIDOverride
        self.slateSelectionsOverride = slateSelectionsOverride
        self.inPersonAddress = inPersonAddress
        self.inPersonAddressRawPaste = inPersonAddressRawPaste
        self.castingPhone = castingPhone
        self.repPhone = repPhone
    }
}

// MARK: - Effective Session Resolution Support
// Conformance must live in the same source file as ProjectSession to avoid Swift 6 retroactive conformance warnings.
extension ProjectSession: SessionContextSource {}

public struct Role: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID = .init()
    public var name: String                   // e.g., "Detective Ramos"
    
    public init(id: UUID = UUID(), name: String) {
        self.id = id
        self.name = name
    }
}

public struct Project: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID = .init()
    public var title: String                  // e.g., "Silver Lake Pilot"
    public var roles: [Role] = []
    public var sessions: [ProjectSession] = []
    public var createdAt: Date = .init()
    public var castingOffice: String? = nil
    public var castingDirector: Contact? = nil
    public var representation: Contact? = nil // agent/manager (optional)
    // CC/BCC persistence for export/share workflow
    public var ccContacts: [Contact] = []
    public var bccContacts: [Contact] = []
    // Enhanced project states
    public var isFavorite: Bool = false      // Favorite project
    public var isArchived: Bool = false      // Archived project
    public var isCompleted: Bool = false     // Project completed (booked/finished)
    public var sceneCount: Int = 1          // Number of scenes in the project
    
    // SAFE ADDITION: Date fields from NewProjectWizard with backward compatibility
    public var auditionDueDate: Date? = nil  // Optional audition due date
    public var shootDate: Date? = nil        // Optional shoot date
    public var projectType: String = "Feature" // Project type from wizard
    public var genre: String = "" // Project genre from wizard
    
    public var slateSelections: SlateSelections = SlateSelections()
    public var breakdownNotes: String? = nil
    public var sidesFileName: String? = nil
    public var breakdownFileName: String? = nil
    public var submittedHeadshotID: UUID? = nil
    public var payDealTagsRaw: String? = nil
    public var payRateText: String? = nil
    public var payCraftVsMoney: Double? = nil
    public var payUnionStatusRaw: String? = nil
    public var payRoleTypeRaw: String? = nil
    
    // CUSTOM DECODER: Provide default values for new fields to ensure backward compatibility
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        roles = try container.decodeIfPresent([Role].self, forKey: .roles) ?? []
        sessions = try container.decodeIfPresent([ProjectSession].self, forKey: .sessions) ?? []
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        castingOffice = try container.decodeIfPresent(String.self, forKey: .castingOffice)
        castingDirector = try container.decodeIfPresent(Contact.self, forKey: .castingDirector)
        representation = try container.decodeIfPresent(Contact.self, forKey: .representation)
        ccContacts = try container.decodeIfPresent([Contact].self, forKey: .ccContacts) ?? []
        bccContacts = try container.decodeIfPresent([Contact].self, forKey: .bccContacts) ?? []
        isFavorite = try container.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false
        isArchived = try container.decodeIfPresent(Bool.self, forKey: .isArchived) ?? false
        isCompleted = try container.decodeIfPresent(Bool.self, forKey: .isCompleted) ?? false
        sceneCount = try container.decodeIfPresent(Int.self, forKey: .sceneCount) ?? 1
        
        // SAFE NEW FIELDS: Provide default values for backward compatibility with existing projects
        auditionDueDate = try container.decodeIfPresent(Date.self, forKey: .auditionDueDate)
        shootDate = try container.decodeIfPresent(Date.self, forKey: .shootDate)
        projectType = try container.decodeIfPresent(String.self, forKey: .projectType) ?? "Feature"
        genre = try container.decodeIfPresent(String.self, forKey: .genre) ?? ""
        slateSelections = try container.decodeIfPresent(SlateSelections.self, forKey: .slateSelections) ?? SlateSelections()
        breakdownNotes = try container.decodeIfPresent(String.self, forKey: .breakdownNotes)
        sidesFileName = try container.decodeIfPresent(String.self, forKey: .sidesFileName)
        breakdownFileName = try container.decodeIfPresent(String.self, forKey: .breakdownFileName)
        submittedHeadshotID = try container.decodeIfPresent(UUID.self, forKey: .submittedHeadshotID)
        payDealTagsRaw = try container.decodeIfPresent(String.self, forKey: .payDealTagsRaw)
        payRateText = try container.decodeIfPresent(String.self, forKey: .payRateText)
        payCraftVsMoney = try container.decodeIfPresent(Double.self, forKey: .payCraftVsMoney)
        payUnionStatusRaw = try container.decodeIfPresent(String.self, forKey: .payUnionStatusRaw)
        payRoleTypeRaw = try container.decodeIfPresent(String.self, forKey: .payRoleTypeRaw)
    }
    
    private enum CodingKeys: String, CodingKey {
        case id, title, roles, sessions, createdAt, castingOffice, castingDirector, representation
        case ccContacts, bccContacts, isFavorite, isArchived, isCompleted, sceneCount
        case auditionDueDate, shootDate, projectType, genre, slateSelections, breakdownNotes, sidesFileName, breakdownFileName
        case submittedHeadshotID, payDealTagsRaw, payRateText, payCraftVsMoney, payUnionStatusRaw, payRoleTypeRaw
    }
    
    public init(
        id: UUID = UUID(),
        title: String,
        roles: [Role] = [],
        sessions: [ProjectSession] = [],
        createdAt: Date = Date(),
        castingOffice: String? = nil,
        castingDirector: Contact? = nil,
        representation: Contact? = nil,
        ccContacts: [Contact] = [],
        bccContacts: [Contact] = [],
        isFavorite: Bool = false,
        isArchived: Bool = false,
        isCompleted: Bool = false,
        sceneCount: Int = 1,
        auditionDueDate: Date? = nil,
        shootDate: Date? = nil,
        projectType: String = "Feature",
        genre: String = "",
        slateSelections: SlateSelections = SlateSelections(),
        breakdownNotes: String? = nil,
        sidesFileName: String? = nil,
        breakdownFileName: String? = nil,
        submittedHeadshotID: UUID? = nil,
        payDealTagsRaw: String? = nil,
        payRateText: String? = nil,
        payCraftVsMoney: Double? = nil,
        payUnionStatusRaw: String? = nil,
        payRoleTypeRaw: String? = nil
    ) {
        self.id = id
        self.title = title
        self.roles = roles
        self.sessions = sessions
        self.createdAt = createdAt
        self.castingOffice = castingOffice
        self.castingDirector = castingDirector
        self.representation = representation
        self.ccContacts = ccContacts
        self.bccContacts = bccContacts
        self.isFavorite = isFavorite
        self.isArchived = isArchived
        self.isCompleted = isCompleted
        self.sceneCount = sceneCount
        self.auditionDueDate = auditionDueDate
        self.shootDate = shootDate
        self.projectType = projectType
        self.genre = genre
        self.slateSelections = slateSelections
        self.breakdownNotes = breakdownNotes
        self.sidesFileName = sidesFileName
        self.breakdownFileName = breakdownFileName
        self.submittedHeadshotID = submittedHeadshotID
        self.payDealTagsRaw = payDealTagsRaw
        self.payRateText = payRateText
        self.payCraftVsMoney = payCraftVsMoney
        self.payUnionStatusRaw = payUnionStatusRaw
        self.payRoleTypeRaw = payRoleTypeRaw
    }
    
    // NEW: Get all merged videos across all sessions
    public var allMergedVideos: [ProjectTake] {
        sessions.flatMap { $0.mergedVideoTakes }
    }
    
    // NEW: Computed properties for date display logic
    public var isAuditionDueSoon: Bool {
        guard let dueDate = auditionDueDate else { return false }
        return dueDate.timeIntervalSinceNow < 86400 * 2 // Less than 2 days
    }
    
public var daysUntilAuditionDue: Int {
        guard let dueDate = auditionDueDate else { return -1 }
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: Date(), to: dueDate).day ?? 0
        return max(0, days)
    }
}

// MARK: - SmartFill Helpers
public extension ProjectTake {
    var isSmartFillVariant: Bool {
        URL(fileURLWithPath: filePath).lastPathComponent.lowercased().contains("_smartfill")
    }
    
    var smartFillOriginalID: UUID? {
        guard let notes = takeNotes,
              let range = notes.range(of: "[SMARTFILL_ORIGINAL:") else {
            return nil
        }
        let remainder = notes[range.upperBound...]
        guard let closing = remainder.firstIndex(of: "]") else { return nil }
        let idString = String(remainder[..<closing])
        return UUID(uuidString: idString)
    }
}

public enum TakeDisplayFormatter {
    public static func label(for take: ProjectTake, in session: ProjectSession) -> String {
        let reference = canonicalTake(for: take, in: session)
        
        if reference.takeType.isSlateLike {
            let baseLabel = reference.takeType == .pipSlate ? "PiP Slate" : "Slate"
            if let number = reference.slateNumber, !number.isEmpty {
                return "\(baseLabel) (\(number))"
            }
            return baseLabel
        }
        
        let ordinal = ordinal(for: reference, in: session)
        
        if isPhoto(reference) {
            return "Photo \(ordinal)"
        }
        
        let normalizedScene = max(1, reference.sceneNumber)
        if reference.takeType == .regular && normalizedScene > 1 {
            return "S\(normalizedScene)T\(ordinal)"
        }
        
        return "Take \(ordinal)"
    }
    
    public static func canonicalTake(for take: ProjectTake, in session: ProjectSession) -> ProjectTake {
        guard take.isSmartFillVariant else {
            return take
        }
        
        if let originalID = take.smartFillOriginalID,
           let original = session.takes.first(where: { $0.id == originalID }) {
            return original
        }
        
        let base = normalizedBaseName(for: take)
        if let fallback = session.takes.first(where: { candidate in
            !candidate.isSmartFillVariant && normalizedBaseName(for: candidate) == base
        }) {
            return fallback
        }
        
        return take
    }
    
    public static func ordinal(for take: ProjectTake, in session: ProjectSession) -> Int {
        if take.takeNumber > 0 {
            return take.takeNumber
        }
        
        switch take.takeType {
        case .slate, .pipSlate:
            let slates = session.takes
                .filter { $0.takeType.isSlateLike }
                .sorted { $0.createdAt < $1.createdAt }
            if let idx = slates.firstIndex(where: { $0.id == take.id }) {
                return idx + 1
            }
            return max(1, slates.count)
        case .regular:
            let normalizedScene = max(1, take.sceneNumber)
            let isSceneSpecific = normalizedScene > 1
            let filtered = session.takes
                .filter { candidate in
                    guard candidate.takeType == .regular else { return false }
                    if candidate.isSmartFillVariant { return false }
                    if isSceneSpecific {
                        return candidate.sceneNumber == normalizedScene
                    } else {
                        return candidate.sceneNumber <= 1
                    }
                }
                .sorted { $0.createdAt < $1.createdAt }
            if let idx = filtered.firstIndex(where: { $0.id == take.id }) {
                return idx + 1
            }
            return max(1, filtered.count)
        default:
            let filtered = session.takes
                .filter { $0.takeType == take.takeType }
                .sorted { $0.createdAt < $1.createdAt }
            if let idx = filtered.firstIndex(where: { $0.id == take.id }) {
                return idx + 1
            }
            return max(1, filtered.count)
        }
    }
    
    private static func normalizedBaseName(for take: ProjectTake) -> String {
        let fileName = URL(fileURLWithPath: take.filePath).lastPathComponent.lowercased()
        let sanitized = fileName
            .replacingOccurrences(of: "_smartfill.mov", with: ".mov")
            .replacingOccurrences(of: "_smartfill.mp4", with: ".mp4")
        return URL(fileURLWithPath: sanitized).deletingPathExtension().lastPathComponent
    }
    
private static func isPhoto(_ take: ProjectTake) -> Bool {
        take.durationSeconds == 0.0 && !take.takeType.isSlateLike
    }
}

public extension ProjectTake {
    var isKeyframePhoto: Bool {
        sceneNumber == -1 && durationSeconds == 0
    }
    
    var absoluteFileURL: URL? {
        guard !filePath.isEmpty else { return nil }
        if filePath.hasPrefix("/") {
            return URL(fileURLWithPath: filePath)
        }
        guard let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        return docs.appendingPathComponent(filePath)
    }
}

public extension ProjectSession {
    var keyframeThumbnailPhotoURL: URL? {
        let photoCandidates = takes.filter {
            $0.durationSeconds == 0.0 && !$0.takeType.isSlateLike
        }
        
        guard !photoCandidates.isEmpty else { return nil }
        
        let sorted = photoCandidates.sorted { lhs, rhs in
            // Score each take: (final select first, explicit keyframe first, newest first)
            let lhsScore = (
                lhs.isFinalSelect ? 0 : 1,
                lhs.isKeyframePhoto ? 0 : 1,
                lhs.createdAt
            )
            let rhsScore = (
                rhs.isFinalSelect ? 0 : 1,
                rhs.isKeyframePhoto ? 0 : 1,
                rhs.createdAt
            )
            
            if lhsScore.0 != rhsScore.0 {
                return lhsScore.0 < rhsScore.0
            }
            if lhsScore.1 != rhsScore.1 {
                return lhsScore.1 < rhsScore.1
            }
            return lhsScore.2 > rhsScore.2
        }
        
        return sorted.first?.absoluteFileURL
    }
}

// MARK: - Normalized Geometry Helpers

extension CGRect {
    /// Normalized full-frame rectangle used by trim/crop metadata.
    static let stsNormalizedFullFrame = CGRect(x: 0, y: 0, width: 1, height: 1)
    
    /// Returns true when the rect effectively covers the entire normalized frame.
    func sts_isApproximatelyFullFrame(tolerance: CGFloat = 0.002) -> Bool {
        abs(origin.x) < tolerance &&
        abs(origin.y) < tolerance &&
        abs(size.width - 1.0) < tolerance &&
        abs(size.height - 1.0) < tolerance
    }
    
    /// Flag indicating that the rect represents an actual crop (not the normalized full frame).
    var sts_hasMeaningfulCrop: Bool {
        return !sts_isApproximatelyFullFrame()
    }
}
