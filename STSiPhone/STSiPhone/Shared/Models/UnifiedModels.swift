import Foundation
import SwiftUI

/// Unified Take Model - Combines EnhancedTake and ProjectTake while preserving all fields
/// This eliminates the need for conversion between different take models
/// ENHANCED: Now supports both video and photo captures with scene organization and Smart Fill orientation
public struct UnifiedTake: Identifiable, Codable, Equatable {
    public let id: UUID // CRITICAL FIX: Remove automatic UUID generation to preserve original IDs
    
    // PRESERVED: All EnhancedTake fields
    public let fileName: String
    public let projectID: UUID
    public let sessionID: UUID
    public let filePath: String
    public let duration: TimeInterval // Will be 0 for photos
    public let fileSize: Int64
    public let cameraPosition: String
    public let sceneNumber: Int
    public let takeNumber: Int
    public let isSlate: Bool
    
    // NEW: Scene organization fields from ProjectTake
    public let slateNumber: String? // e.g., "1.1", "2.1"
    public let slateID: String?     // e.g., "S1-SL1", "S2-SL1"
    
    // NEW: Photo support
    public let isPhoto: Bool // Indicates if this is a photo take
    public let isKeyframePhoto: Bool // Indicates if this is specifically a keyframe photo
    
    // NEW: Smart Fill orientation support
    public var capturedOrientation: VideoOrientation? // Portrait/Landscape when recorded
    public var overrideSmartFill: TriState? // Override Smart Fill policy for this take
    
    // NEW: SmartFill file management - THE CRITICAL FIX FOR PHASE 2-3
    public var smartFilledFilePath: String? // Path to _smartfill.mov version
    
    public var rating: TakeRating
    public var isBest: Bool
    public let notes: String?
    public let createdAt: Date
    
    // PRESERVED: All ProjectTake fields (now unified)
    public var thumbnailPath: String?
    public var isRejected: Bool {
        rating == .rejected
    }
    public var isFavorite: Bool {
        rating == .option
    }
    
    // ENHANCED: Unified video markers (no more conversion needed)
    public var videoMarkers: [UnifiedVideoMarker] = []
    
    // ENHANCED: Photo-specific computed properties
    public var isVideoTake: Bool {
        return !isPhoto
    }
    
    public var fileExtension: String {
        return URL(fileURLWithPath: filePath).pathExtension.lowercased()
    }
    
    public var mediaType: String {
        return isPhoto ? "Photo" : "Video"
    }
    
    /// Uploaded vs in-app captured take classification for UI badges.
    /// Uses filename and notes set by VideoUploadIO + TakeReviewPage.
    public var isUploaded: Bool {
        let lowerName = fileName.lowercased()
        let lowerNotes = notes?.lowercased() ?? ""
        
        // Our upload pipeline stamps filenames with `_U` and notes with
        // "Uploaded via Take Review". Check both for robustness.
        if lowerNotes.contains("uploaded via take review") {
            return true
        }
        
        if lowerName.contains("_u") {
            return true
        }
        
        return false
    }
    
    /// Lightweight classification to recognize merged/exported deliverables.
    public var isExportDeliverable: Bool {
        let lowerName = fileName.lowercased()
        return lowerName.contains("merged") || lowerName.contains("export")
    }
    
    // NEW: SmartFill computed properties for UI integration
    public var hasSmartFilledVersion: Bool {
        // CRITICAL FIX: Use VideoVariantResolver for consistent path resolution instead of direct FileManager check
        guard let smartFilledPath = smartFilledFilePath else { return false }
        
        // Use VideoVariantResolver to properly resolve relative paths to absolute paths
        if smartFilledPath.hasPrefix("/") {
            // Already absolute path - check directly
            let exists = FileManager.default.fileExists(atPath: smartFilledPath)
            if !exists {
                print("⚠️ UnifiedTake: Absolute SmartFill path exists in model but file missing: \(smartFilledPath)")
            }
            return exists
        } else {
            // Relative path - resolve via VideoVariantResolver
            let resolvedURL = VideoVariantResolver.urlForRelativePath(smartFilledPath)
            let exists = FileManager.default.fileExists(atPath: resolvedURL.path)
            if !exists {
                print("⚠️ UnifiedTake: Relative SmartFill path exists in model but file missing: \(smartFilledPath)")
                print("   🔍 Resolved to: \(resolvedURL.path)")
            }
            return exists
        }
    }
    
    public var effectiveFilePath: String {
        // CRITICAL FIX: Use VideoVariantResolver for consistent path resolution
        guard let smartFilledPath = smartFilledFilePath else {
            return filePath
        }
        
        // Use proper path resolution
        let smartFillURL: URL
        if smartFilledPath.hasPrefix("/") {
            // Already absolute path
            smartFillURL = URL(fileURLWithPath: smartFilledPath)
        } else {
            // Relative path - resolve it
            smartFillURL = VideoVariantResolver.urlForRelativePath(smartFilledPath)
        }
        
        if FileManager.default.fileExists(atPath: smartFillURL.path) {
            return smartFillURL.path
        }
        
        return filePath
    }
    
    public var smartFillStatusText: String {
        // HANDOFF FIX #3: More accurate status based on filesystem check
        if hasSmartFilledVersion {
            return "Smart Fill Applied"
        } else if capturedOrientation == .portrait {
            return "Portrait (Processing...)"
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
    
    // NEW: Scene organization computed properties
    public var sceneDisplayName: String {
        if let slateNumber = slateNumber {
            return "Scene \(sceneNumber) (\(slateNumber))"
        } else {
            return "Scene \(sceneNumber)"
        }
    }
    
    public var takeDisplayName: String {
        if isSlate, let slateID = slateID {
            return "Slate \(slateID)"
        } else {
            return "Take \(takeNumber)"
        }
    }
    
    public var fullDisplayName: String {
        if isSlate {
            return "Slate for \(sceneDisplayName)"
        } else {
            return "\(sceneDisplayName), \(takeDisplayName)"
        }
    }
    
    // ENHANCED: Formatted filename for display - UPDATED with proper scene organization
    public var formattedFileName: String {
        if isSlate, let slateID = slateID {
            return "Slate \(slateID)"
        } else if sceneNumber > 1 {
            return "S\(sceneNumber)T\(takeNumber)"
        } else {
            return "Take \(takeNumber)"
        }
    }
    
    // PRESERVED: All computed properties from both models
    public var formattedFileSize: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }
    
    public var formattedDuration: String {
        if isPhoto {
            return "Photo"
        }
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    public var durationSeconds: TimeInterval {
        duration // For backward compatibility with ProjectTake
    }
    
    public var takeNotes: String? {
        notes // For backward compatibility with ProjectTake
    }
    
    // ENHANCED: Easy conversion methods for migration period - UPDATED: Photo support
    public func toEnhancedTake() -> EnhancedTake {
        return EnhancedTake(
            fileName: fileName,
            projectID: projectID,
            sessionID: sessionID,
            filePath: filePath,
            duration: duration,
            fileSize: fileSize,
            cameraPosition: cameraPosition,
            sceneNumber: sceneNumber,
            takeNumber: takeNumber,
            isSlate: isSlate,
            rating: rating,
            isBest: isBest,
            notes: notes,
            createdAt: createdAt
        )
    }
    
    public func toProjectTake() -> ProjectTake {
        return ProjectTake(
            id: id, // CRITICAL FIX: Preserve the UUID
            filePath: filePath,
            durationSeconds: duration,
            thumbnailPath: thumbnailPath,
            takeNotes: notes,
            createdAt: createdAt,
            videoMarkers: videoMarkers.map { $0.toTakeVideoMarker() },
            rating: rating,
            sceneNumber: sceneNumber,    // CRITICAL FIX: Preserve scene organization
            takeNumber: takeNumber,      // CRITICAL FIX: Preserve take number
            slateNumber: slateNumber,    // CRITICAL FIX: Preserve slate number
            slateID: slateID,           // CRITICAL FIX: Preserve slate ID
            takeType: isSlate ? .slate : (isPhoto ? .exported : .regular)  // CRITICAL FIX: Set proper take type
        )
    }
    
    // ENHANCED: Create from existing models with PRESERVED UUIDs - UPDATED: Smart Fill support
    public init(from enhancedTake: EnhancedTake) {
        self.id = enhancedTake.id // PRESERVE original ID
        self.fileName = enhancedTake.fileName
        self.projectID = enhancedTake.projectID
        self.sessionID = enhancedTake.sessionID
        self.filePath = enhancedTake.filePath
        self.duration = enhancedTake.duration
        self.fileSize = enhancedTake.fileSize
        self.cameraPosition = enhancedTake.cameraPosition
        self.sceneNumber = enhancedTake.sceneNumber
        self.takeNumber = enhancedTake.takeNumber
        self.isSlate = enhancedTake.isSlate
        self.slateNumber = nil       // EnhancedTake doesn't have slate organization
        self.slateID = nil          // EnhancedTake doesn't have slate organization
        self.isPhoto = false // Default to video for existing takes
        self.isKeyframePhoto = false // Default to non-keyframe
        self.capturedOrientation = nil  // NEW: Will need to be analyzed later
        self.overrideSmartFill = nil   // NEW: Default to inherit
        self.rating = enhancedTake.rating
        self.isBest = enhancedTake.isBest
        self.notes = enhancedTake.notes
        self.createdAt = enhancedTake.createdAt
        self.thumbnailPath = nil
        self.videoMarkers = []
    }
    
    // ENHANCED: Improved ProjectTake conversion with Smart Fill support
    public init(from projectTake: ProjectTake, projectID: UUID, sessionID: UUID, fileName: String, takeNumber: Int = 1) {
        self.id = projectTake.id // CRITICAL FIX: Preserve ProjectTake ID
        self.fileName = fileName
        self.projectID = projectID
        self.sessionID = sessionID
        
        // CRITICAL FIX: Use effective file path (SmartFill version if available)
        self.filePath = projectTake.effectiveFilePath
        
        self.duration = projectTake.durationSeconds
        self.fileSize = 0 // Will need to be calculated from file
        self.cameraPosition = "back" // Default
        
        // CRITICAL FIX: Use ProjectTake's scene organization instead of extracting
        self.sceneNumber = projectTake.sceneNumber
        self.takeNumber = projectTake.takeNumber
        self.slateNumber = projectTake.slateNumber    // PRESERVE slate organization
        self.slateID = projectTake.slateID           // PRESERVE slate ID
        
        // ENHANCED: Smart slate detection - check both filename and ProjectTake takeType
        self.isSlate = (projectTake.takeType.isSlateLike) || Self.isSlateFile(fileName: fileName, filePath: projectTake.filePath)
        
        
        // CRITICAL FIX: Enhanced photo detection matching TakeReviewPage logic
        let lowerPath = projectTake.filePath.lowercased()
        let notesLower = projectTake.takeNotes?.lowercased()
        let isImageExtension = lowerPath.hasSuffix(".jpg") || lowerPath.hasSuffix(".jpeg") || lowerPath.hasSuffix(".png") || lowerPath.hasSuffix(".heic")
        let isVideoExtension = lowerPath.hasSuffix(".mov") || lowerPath.hasSuffix(".mp4")
        let hasPhotoKeyword = lowerPath.contains("photo") || lowerPath.contains("keyframe") || notesLower?.contains("photo") == true || notesLower?.contains("keyframe") == true
        
        self.isPhoto = projectTake.durationSeconds == 0.0 &&
            !projectTake.takeType.isSlateLike &&
            (hasPhotoKeyword || isImageExtension || !isVideoExtension)
        
        // CRITICAL FIX: Enhanced keyframe photo detection
        self.isKeyframePhoto = self.isPhoto && (
            projectTake.isKeyframePhoto ||
            lowerPath.contains("keyframe") ||
            notesLower?.contains("keyframe") == true
        )
        
        // NEW: Smart Fill orientation and file path support from ProjectTake
        self.capturedOrientation = projectTake.capturedOrientation
        self.overrideSmartFill = projectTake.overrideSmartFill
        self.smartFilledFilePath = projectTake.smartFilledFilePath
        
        // CLEANED: Direct rating assignment - no more boolean flag conversion!
        self.rating = projectTake.rating
        self.isBest = (projectTake.rating == .finalSelect)
        self.notes = projectTake.takeNotes
        self.createdAt = projectTake.createdAt
        self.thumbnailPath = projectTake.thumbnailPath
        self.videoMarkers = projectTake.videoMarkers.map { UnifiedVideoMarker(from: $0) }
    }
    
    // PRESERVED: Standard initializer with all the amazing fields - ENHANCED: Smart Fill support
    public init(
        id: UUID = UUID(), // CRITICAL FIX: Allow ID to be passed in, default to new UUID
        fileName: String,
        projectID: UUID,
        sessionID: UUID,
        filePath: String,
        duration: TimeInterval,
        fileSize: Int64,
        cameraPosition: String,
        sceneNumber: Int,
        takeNumber: Int,
        slateNumber: String? = nil,        // NEW: Slate organization
        slateID: String? = nil,           // NEW: Slate ID
        isSlate: Bool = false,
        isPhoto: Bool = false, // NEW: Photo support
        isKeyframePhoto: Bool = false, // NEW: Keyframe photo support
        capturedOrientation: VideoOrientation? = nil,  // NEW: Smart Fill orientation
        overrideSmartFill: TriState? = nil,           // NEW: Smart Fill override
        smartFilledFilePath: String? = nil,           // NEW: SmartFill file path
        rating: TakeRating = .unrated,
        isBest: Bool = false,
        notes: String? = nil,
        createdAt: Date = Date(),
        thumbnailPath: String? = nil,
        videoMarkers: [UnifiedVideoMarker] = []
    ) {
        self.id = id // CRITICAL FIX: Use passed ID instead of generating new one
        self.fileName = fileName
        self.projectID = projectID
        self.sessionID = sessionID
        self.filePath = filePath
        self.duration = duration
        self.fileSize = fileSize
        self.cameraPosition = cameraPosition
        self.sceneNumber = sceneNumber
        self.takeNumber = takeNumber
        self.slateNumber = slateNumber    // NEW: Store slate number
        self.slateID = slateID           // NEW: Store slate ID
        self.isSlate = isSlate
        self.isPhoto = isPhoto // NEW: Photo support
        self.isKeyframePhoto = isKeyframePhoto // NEW: Keyframe photo support
        self.capturedOrientation = capturedOrientation  // NEW: Smart Fill orientation
        self.overrideSmartFill = overrideSmartFill     // NEW: Smart Fill override
        self.smartFilledFilePath = smartFilledFilePath // NEW: SmartFill file path
        self.rating = rating
        self.isBest = isBest
        self.notes = notes
        self.createdAt = createdAt
        self.thumbnailPath = thumbnailPath
        self.videoMarkers = videoMarkers
    }
    
    // MARK: - Smart Detection Methods with Enterprise Error Handling
    
    /// Extract scene number from filename using multiple strategies
    /// - Parameter fileName: The video filename to analyze
    /// - Parameter fallback: The fallback scene number if extraction fails
    /// - Returns: The detected scene number, or fallback if detection fails
    private static func extractSceneNumber(from fileName: String, fallback: Int) -> Int {
        do {
            // Strategy 1: Look for "Scene#" pattern (e.g., "Scene2_Take1.mov")
            if let sceneMatch = fileName.range(of: #"Scene(\d+)"#, options: .regularExpression) {
                let sceneString = String(fileName[sceneMatch]).replacingOccurrences(of: "Scene", with: "")
                if let sceneNumber = Int(sceneString), sceneNumber > 0 {
                    print("✅ UnifiedTake: Extracted scene number \(sceneNumber) from filename: \(fileName)")
                    return sceneNumber
                }
            }
            
            // Strategy 2: Look for "S#" pattern (e.g., "S2_T1.mov")
            if let sMatch = fileName.range(of: #"S(\d+)"#, options: .regularExpression) {
                let sString = String(fileName[sMatch]).replacingOccurrences(of: "S", with: "")
                if let sceneNumber = Int(sString), sceneNumber > 0 {
                    print("✅ UnifiedTake: Extracted scene number \(sceneNumber) from S-pattern in: \(fileName)")
                    return sceneNumber
                }
            }
            
            // Strategy 3: Look for numeric patterns that might indicate scene (conservative approach)
            let regex = try NSRegularExpression(pattern: #"\d+"#)
            let range = NSRange(location: 0, length: fileName.utf16.count)
            let matches = regex.matches(in: fileName, range: range)
            
            let numbers = matches.compactMap { match in
                let matchRange = Range(match.range, in: fileName)
                return matchRange.map { Int(String(fileName[$0])) }
            }.compactMap { $0 }.filter { $0 > 0 && $0 <= 20 } // Reasonable scene number range
            
            if let firstNumber = numbers.first, numbers.count <= 3 {
                print("⚠️ UnifiedTake: Using first number \(firstNumber) as scene number from: \(fileName)")
                return firstNumber
            }
            
            print("⚠️ UnifiedTake: No scene number detected in filename: \(fileName), using fallback: \(fallback)")
            return fallback
            
        } catch {
            print("❌ UnifiedTake: Scene extraction failed for \(fileName): \(error), using fallback: \(fallback)")
            return fallback
        }
    }
    
    /// Determine if a file is a slate based on filename and path patterns
    /// - Parameters:
    ///   - fileName: The filename to analyze
    ///   - filePath: The full file path for additional context
    /// - Returns: true if this appears to be a slate file
    private static func isSlateFile(fileName: String, filePath: String) -> Bool {
        let lowerFileName = fileName.lowercased()
        let lowerFilePath = filePath.lowercased()
        
        // Look for slate indicators in filename
        let slateKeywords = ["slate", "intro", "identification", "name_card"]
        
        for keyword in slateKeywords {
            if lowerFileName.contains(keyword) || lowerFilePath.contains(keyword) {
                print("✅ UnifiedTake: Detected slate file by keyword '\(keyword)' in: \(fileName)")
                return true
            }
        }
        
        // Look for slate patterns (e.g., files starting with "Slate", or containing "S0")
        if lowerFileName.hasPrefix("slate") || lowerFileName.contains("s0_") {
            print("✅ UnifiedTake: Detected slate file by pattern in: \(fileName)")
            return true
        }
        
        return false
    }
}

// ENHANCED: Safer conversion methods with error handling
extension UnifiedTake {
    /// Safe conversion from ProjectTake with detailed error handling
    /// - Parameters:
    ///   - projectTake: The ProjectTake to convert
    ///   - projectID: Project UUID
    ///   - sessionID: Session UUID
    ///   - fileName: Filename for the take
    ///   - takeNumber: Take number (optional, defaults to 1)
    /// - Returns: UnifiedTake instance or throws ConversionError
    public static func safeConversion(
        from projectTake: ProjectTake,
        projectID: UUID,
        sessionID: UUID,
        fileName: String,
        takeNumber: Int = 1
    ) throws -> UnifiedTake {
        
        // Validate required data
        guard !projectTake.filePath.isEmpty else {
            throw ConversionError.invalidFilePath("Empty file path in ProjectTake")
        }
        
        guard !fileName.isEmpty else {
            throw ConversionError.invalidFileName("Empty filename provided")
        }
        
        guard projectTake.durationSeconds >= 0 else {
            throw ConversionError.invalidDuration("Negative duration: \(projectTake.durationSeconds)")
        }
        
        // Create with enhanced validation
        let unifiedTake = UnifiedTake(
            from: projectTake,
            projectID: projectID,
            sessionID: sessionID,
            fileName: fileName,
            takeNumber: takeNumber
        )
        
        print("✅ UnifiedTake: Safe conversion completed - Scene: \(unifiedTake.sceneNumber), Slate: \(unifiedTake.isSlate), File: \(fileName)")
        return unifiedTake
    }
    
    /// Conversion errors for enterprise error handling
    public enum ConversionError: LocalizedError {
        case invalidFilePath(String)
        case invalidFileName(String)
        case invalidDuration(String)
        case fileSystemError(String)
        
        public var errorDescription: String? {
            switch self {
            case .invalidFilePath(let message):
                return "Invalid file path: \(message)"
            case .invalidFileName(let message):
                return "Invalid filename: \(message)"
            case .invalidDuration(let message):
                return "Invalid duration: \(message)"
            case .fileSystemError(let message):
                return "File system error: \(message)"
            }
        }
    }
}

/// Unified Video Marker Model - Combines VideoMarker and TakeVideoMarker
/// Eliminates the need for constant conversion between UI and storage models
public struct UnifiedVideoMarker: Identifiable, Codable, Equatable {
    public let id: UUID // CRITICAL FIX: Remove automatic generation to preserve original IDs
    public let timestamp: TimeInterval
    public let title: String
    public let description: String?
    public let type: MarkerType
    public let createdAt: Date
    
    // PRESERVED: All marker types from both models
    public enum MarkerType: String, CaseIterable, Codable {
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
        
        public var color: Color {
            switch self {
            case .good: return .green
            case .note: return .blue
            case .problem: return .red
            case .favorite: return .yellow
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
    
    // ENHANCED: Easy conversion methods for migration period
    public func toVideoMarker() -> VideoMarker {
        return VideoMarker(
            timestamp: timestamp,
            title: title,
            description: description,
            type: VideoMarker.MarkerType(rawValue: type.rawValue) ?? .note
        )
    }
    
    public func toTakeVideoMarker() -> TakeVideoMarker {
        return TakeVideoMarker(
            timestamp: timestamp,
            title: title,
            description: description,
            type: TakeVideoMarker.MarkerType(rawValue: type.rawValue) ?? .note
        )
    }
    
    // ENHANCED: Create from existing models with PRESERVED IDs
    public init(from videoMarker: VideoMarker) {
        self.id = videoMarker.id // PRESERVE original ID
        self.timestamp = videoMarker.timestamp
        self.title = videoMarker.title
        self.description = videoMarker.description
        self.type = MarkerType(rawValue: videoMarker.type.rawValue) ?? .note
        self.createdAt = Date()
    }
    
    public init(from takeVideoMarker: TakeVideoMarker) {
        self.id = takeVideoMarker.id // PRESERVE original ID
        self.timestamp = takeVideoMarker.timestamp
        self.title = takeVideoMarker.title
        self.description = takeVideoMarker.description
        self.type = MarkerType(rawValue: takeVideoMarker.type.rawValue) ?? .note
        self.createdAt = takeVideoMarker.createdAt
    }
    
    // PRESERVED: Standard initializer
    public init(
        id: UUID = UUID(), // CRITICAL FIX: Allow ID to be passed in
        timestamp: TimeInterval,
        title: String,
        description: String? = nil,
        type: MarkerType,
        createdAt: Date = Date()
    ) {
        self.id = id // Use passed ID
        self.timestamp = timestamp
        self.title = title
        self.description = description
        self.type = type
        self.createdAt = createdAt
    }
}

// MARK: - Migration Helpers

extension UnifiedTake {
    /// Helper to migrate existing SessionManager takes
    public static func migrateFromSessionManager(_ sessionManager: SessionManager) -> [UnifiedTake] {
        return sessionManager.takes.map { UnifiedTake(from: $0) }
    }
    
    /// ENHANCED: Helper to migrate existing ProjectRepository takes with better error handling
    public static func migrateFromRepository(_ repository: ProjectsRepository, project: Project) -> [UnifiedTake] {
        var unifiedTakes: [UnifiedTake] = []
        var conversionErrors: [String] = []
        
        for session in project.sessions {
            for (index, projectTake) in session.takes.enumerated() {
                let fileName = URL(fileURLWithPath: projectTake.filePath).lastPathComponent
                
                do {
                    let unifiedTake = try UnifiedTake.safeConversion(
                        from: projectTake,
                        projectID: project.id,
                        sessionID: session.id,
                        fileName: fileName,
                        takeNumber: index + 1
                    )
                    unifiedTakes.append(unifiedTake)
                } catch {
                    let errorMessage = "Failed to convert take \(fileName): \(error.localizedDescription)"
                    conversionErrors.append(errorMessage)
                    print("❌ UnifiedTake migration error: \(errorMessage)")
                    
                    // Fallback: Create basic UnifiedTake with minimal data
                    let fallbackTake = UnifiedTake(
                        id: projectTake.id,
                        fileName: fileName,
                        projectID: project.id,
                        sessionID: session.id,
                        filePath: projectTake.filePath,
                        duration: max(0, projectTake.durationSeconds), // Ensure non-negative
                        fileSize: 0,
                        cameraPosition: "back",
                        sceneNumber: 1, // Safe fallback
                        takeNumber: index + 1,
                        isSlate: false,
                        rating: projectTake.rating,
                        notes: projectTake.takeNotes,
                        createdAt: projectTake.createdAt,
                        thumbnailPath: projectTake.thumbnailPath
                    )
                    unifiedTakes.append(fallbackTake)
                    print("🔄 Created fallback UnifiedTake for: \(fileName)")
                }
            }
        }
        
        if !conversionErrors.isEmpty {
            print("⚠️ UnifiedTake migration completed with \(conversionErrors.count) errors out of \(unifiedTakes.count) total takes")
        } else {
            print("✅ UnifiedTake migration completed successfully: \(unifiedTakes.count) takes converted")
        }
        
        return unifiedTakes
    }
}

// MARK: - Backward Compatibility Extensions

extension UnifiedVideoMarker.MarkerType {
    public init(from videoMarkerType: VideoMarker.MarkerType) {
        self = UnifiedVideoMarker.MarkerType(rawValue: videoMarkerType.rawValue) ?? .note
    }
    
    public init(from takeVideoMarkerType: TakeVideoMarker.MarkerType) {
        self = UnifiedVideoMarker.MarkerType(rawValue: takeVideoMarkerType.rawValue) ?? .note
    }
}

extension Color {
    // Ensure Color is available for marker types
}
