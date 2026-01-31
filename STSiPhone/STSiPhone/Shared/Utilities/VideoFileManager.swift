import Foundation
import AVFoundation
import UIKit

/// Enhanced video file management system for Self Tape Studio
class VideoFileManager {
    static let shared = VideoFileManager()

#if DEBUG
    private static let debugLookupLock = NSLock()
    private static var debugLookupCount = 0
#endif
    
    // MARK: - Directory Structure
    
    /// Base directory for all STS video files
    private var baseDirectory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("STS_Projects")
    }
    
    /// Get project directory for a specific project
    private func projectDirectory(for projectID: UUID) -> URL {
        return baseDirectory.appendingPathComponent(projectID.uuidString)
    }
    
    /// Get session directory for a specific project and session
    private func sessionDirectory(for projectID: UUID, sessionID: UUID) -> URL {
        return projectDirectory(for: projectID).appendingPathComponent(sessionID.uuidString)
    }
    
    // MARK: - File Operations
    
    /// Save a video file with proper organization and metadata
    func saveVideo(
        from tempURL: URL,
        projectID: UUID,
        sessionID: UUID,
        fileName: String,
        metadata: VideoMetadata
    ) throws -> VideoFile {
        
        // Create directory structure if needed
        let sessionDir = sessionDirectory(for: projectID, sessionID: sessionID)
        try FileManager.default.createDirectory(at: sessionDir, withIntermediateDirectories: true, attributes: nil)
        
        // Create final destination
        let destination = sessionDir.appendingPathComponent(fileName)
        
        // Remove existing file if it exists
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        
        // Move file to final location
        try FileManager.default.moveItem(at: tempURL, to: destination)
        
        // Create metadata sidecar file
        let metadataFile = destination.appendingPathExtension("metadata.json")
        try saveMetadata(metadata, to: metadataFile)
        
        // Create VideoFile object
        let videoFile = VideoFile(
            filePath: destination.path,
            fileName: fileName,
            metadata: metadata,
            fileSize: try destination.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0,
            createdAt: Date()
        )
        
        print("✅ Video saved: \(destination.path)")
        return videoFile
    }
    
    /// Load video file with metadata
    func loadVideoFile(at path: String) -> VideoFile? {
        let url = URL(fileURLWithPath: path)
        
        guard FileManager.default.fileExists(atPath: path) else {
            print("❌ Video file not found: \(path)")
            return nil
        }
        
        // Load metadata if available
        let metadataPath = url.appendingPathExtension("metadata.json")
        let metadata = loadMetadata(from: metadataPath) ?? VideoMetadata()
        
        do {
            let resources = try url.resourceValues(forKeys: [.fileSizeKey, .creationDateKey])
            
            return VideoFile(
                filePath: path,
                fileName: url.lastPathComponent,
                metadata: metadata,
                fileSize: resources.fileSize ?? 0,
                createdAt: resources.creationDate ?? Date()
            )
        } catch {
            print("⚠️ Could not load video file resources: \(error)")
            return nil
        }
    }
    
    /// Find video file for a take (searches the directory structure)
    func findVideoFile(for take: Take, projectID: UUID, sessionID: UUID) -> VideoFile? {
        let sessionDir = sessionDirectory(for: projectID, sessionID: sessionID)
        let videoPath = sessionDir.appendingPathComponent(take.fileName)
        
        return loadVideoFile(at: videoPath.path)
    }
    
    /// Delete video file and its metadata
    func deleteVideo(at path: String) throws {
        let url = URL(fileURLWithPath: path)
        
        // Delete video file
        if FileManager.default.fileExists(atPath: path) {
            try FileManager.default.removeItem(at: url)
        }
        
        // Delete metadata file
        let metadataPath = url.appendingPathExtension("metadata.json")
        if FileManager.default.fileExists(atPath: metadataPath.path) {
            try FileManager.default.removeItem(at: metadataPath)
        }
        
        print("🗑️ Deleted video: \(path)")
    }
    
    /// Get video duration using AVAsset
    func getVideoDuration(at path: String) async -> TimeInterval {
        let url = URL(fileURLWithPath: path)
        let asset = AVURLAsset(url: url)
        
        do {
            let duration = try await asset.load(.duration)
            return duration.seconds
        } catch {
            print("⚠️ Could not load video duration: \(error)")
            return 0
        }
    }
    
    /// Get video thumbnail
    func generateThumbnail(for videoPath: String, at time: TimeInterval = 0) async -> Data? {
        let url = URL(fileURLWithPath: videoPath)
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true

#if DEBUG
        if let track = try? await asset.loadTracks(withMediaType: .video).first {
            let naturalSize = (try? await track.load(.naturalSize)) ?? .zero
            let preferredTransform = (try? await track.load(.preferredTransform)) ?? .identity
            let renderSize = NormalizeOrientation.uprightExtent(
                naturalSize: naturalSize,
                preferred: preferredTransform
            )
            print("🧪 VideoFileManager.thumbnail url=\(url.lastPathComponent) natural=\(naturalSize) transform=\(preferredTransform) render=\(renderSize) time=\(time)")
            if renderSize.width <= 0 || renderSize.height <= 0 {
                print("⚠️ VideoFileManager.thumbnail invalid render size \(renderSize) — skipping")
                return nil
            }
        } else {
            print("⚠️ VideoFileManager.thumbnail missing video track for \(url.lastPathComponent)")
        }
#endif
        
        do {
            let cgImage = try await generator.image(at: CMTime(seconds: time, preferredTimescale: 600)).image
            let image = UIImage(cgImage: cgImage)
            return image.jpegData(compressionQuality: 0.8)
        } catch {
            print("⚠️ Could not generate thumbnail: \(error)")
            return nil
        }
    }
    
    // MARK: - Metadata Management
    
    private func saveMetadata(_ metadata: VideoMetadata, to url: URL) throws {
        let data = try JSONEncoder().encode(metadata)
        try data.write(to: url)
    }
    
    private func loadMetadata(from url: URL) -> VideoMetadata? {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }
        
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(VideoMetadata.self, from: data)
        } catch {
            print("⚠️ Could not load metadata: \(error)")
            return nil
        }
    }
    
    // MARK: - Storage Management
    
    /// Get total storage used by STS videos
    func getTotalStorageUsed() -> Int64 {
        guard let enumerator = FileManager.default.enumerator(
            at: baseDirectory,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            return 0
        }
        
        var totalSize: Int64 = 0
        for case let url as URL in enumerator {
            if url.pathExtension == "mov" || url.pathExtension == "mp4" {
                do {
                    let resources = try url.resourceValues(forKeys: [.fileSizeKey])
                    totalSize += Int64(resources.fileSize ?? 0)
                } catch {
                    continue
                }
            }
        }
        
        return totalSize
    }
    
    /// Clean up old or orphaned video files
    func cleanupOldVideos(olderThan days: Int = 30) {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        
        guard let enumerator = FileManager.default.enumerator(
            at: baseDirectory,
            includingPropertiesForKeys: [.creationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return
        }
        
        var deletedCount = 0
        for case let url as URL in enumerator {
            if url.pathExtension == "mov" || url.pathExtension == "mp4" {
                do {
                    let resources = try url.resourceValues(forKeys: [.creationDateKey])
                    if let creationDate = resources.creationDate,
                       creationDate < cutoffDate {
                        try FileManager.default.removeItem(at: url)
                        deletedCount += 1
                    }
                } catch {
                    continue
                }
            }
        }
        
        print("🧹 Cleaned up \(deletedCount) old video files")
    }
    
    // CRITICAL FIX: Add methods needed by UnifiedTakePlayerView
    
    /// Save recorded video with proper file path management for consistent retrieval
    func saveRecordedVideo(from sourceURL: URL, fileName: String) throws -> URL {
        // Use Documents directory for immediate access (as used by CameraCaptureView)
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let destination = documentsPath.appendingPathComponent(fileName)
        
        // Remove existing file if it exists
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        
        // Move file to destination
        try FileManager.default.moveItem(at: sourceURL, to: destination)
        
        print("✅ VideoFileManager: Saved video to \(destination.path)")
        return destination
    }
    
    /// Get video URL for a given filename - searches standard locations with container path migration support
    func getVideoURL(for fileName: String) throws -> URL {
        print("🔍 VideoFileManager: Searching for \(fileName)")

#if DEBUG
        let debugStart = CFAbsoluteTimeGetCurrent()
        let debugCallID: Int = {
            Self.debugLookupLock.lock()
            defer { Self.debugLookupLock.unlock() }
            Self.debugLookupCount += 1
            return Self.debugLookupCount
        }()

        func debugLog(result: String) {
            let elapsed = CFAbsoluteTimeGetCurrent() - debugStart
            print(String(format: "🧪 VideoFileManager.getVideoURL[%d] file=%@ result=%@ %.3f s", debugCallID, fileName, result, elapsed))
        }
#endif
        
        // Strategy 1: Check Documents directory first (most common)
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let documentsURL = documentsPath.appendingPathComponent(fileName)
        
        if FileManager.default.fileExists(atPath: documentsURL.path) {
            print("✅ VideoFileManager: Found \(fileName) in Documents directory")
#if DEBUG
            debugLog(result: "documents")
#endif
            return documentsURL
        }
        
        // Strategy 2: Check STS_Exports directory (for exported files)
        let exportsURL = documentsPath.appendingPathComponent("STS_Exports").appendingPathComponent(fileName)
        if FileManager.default.fileExists(atPath: exportsURL.path) {
            print("✅ VideoFileManager: Found \(fileName) in STS_Exports directory")
#if DEBUG
            debugLog(result: "exports")
#endif
            return exportsURL
        }
        
        // Strategy 3: Search STS project structure
        if let enumerator = FileManager.default.enumerator(
            at: baseDirectory,
            includingPropertiesForKeys: [.nameKey],
            options: [.skipsHiddenFiles]
        ) {
            for case let url as URL in enumerator {
                if url.lastPathComponent == fileName {
                    print("✅ VideoFileManager: Found \(fileName) in STS project structure: \(url.path)")
#if DEBUG
                    debugLog(result: "sts-project-tree")
#endif
                    return url
                }
            }
        }
        
        // Strategy 4: CONTAINER PATH MIGRATION - search for files with old container paths
        // iOS changes container paths on app restart, so we need to find files that moved
        let searchDirectories = [
            FileManager.default.temporaryDirectory,
            FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!,
            // Also search parent directories of Documents in case of container path changes
            documentsPath.deletingLastPathComponent(),
            documentsPath.deletingLastPathComponent().deletingLastPathComponent()
        ].compactMap { $0 }
        
        for basePath in searchDirectories {
            // Search recursively for the filename in these directories
            if let enumerator = FileManager.default.enumerator(
                at: basePath,
                includingPropertiesForKeys: [.nameKey],
                options: [.skipsHiddenFiles]
            ) {
                for case let url as URL in enumerator {
                    if url.lastPathComponent == fileName {
                        print("📦 VideoFileManager: Found \(fileName) via container path migration: \(url.path)")
#if DEBUG
                        debugLog(result: "container-migration")
#endif
                        return url
                    }
                }
            }
        }
        
        // Strategy 5: Last resort - search common video directories
        let commonPaths = [
            FileManager.default.temporaryDirectory,
            FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        ].compactMap { $0 }
        
        for basePath in commonPaths {
            let searchURL = basePath.appendingPathComponent(fileName)
            if FileManager.default.fileExists(atPath: searchURL.path) {
                print("✅ VideoFileManager: Found \(fileName) in common directory: \(basePath.path)")
#if DEBUG
                debugLog(result: "common-path")
#endif
                return searchURL
            }
        }
        
        print("❌ VideoFileManager: Could not find \(fileName) in any location")
#if DEBUG
        debugLog(result: "not-found")
#endif
        throw VideoFileError.fileNotFound(fileName)
    }
    
    // CRITICAL FIX: Add method to migrate exported files to current container paths
    /// Migrate old exported files to current container paths to fix access issues after app restart
    func migrateExportedFiles() {
        print("📦 VideoFileManager: Starting exported files migration...")
        
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let exportsDirectory = documentsPath.appendingPathComponent("STS_Exports")
        
        // Ensure exports directory exists
        try? FileManager.default.createDirectory(at: exportsDirectory, withIntermediateDirectories: true, attributes: nil)
        
        // Search for exported files in various locations that might need migration
        let searchPaths = [
            FileManager.default.temporaryDirectory,
            documentsPath.deletingLastPathComponent(),
            documentsPath.deletingLastPathComponent().deletingLastPathComponent()
        ]
        
        var migratedCount = 0
        
        for searchPath in searchPaths {
            guard let enumerator = FileManager.default.enumerator(
                at: searchPath,
                includingPropertiesForKeys: [.nameKey, .fileSizeKey],
                options: [.skipsHiddenFiles]
            ) else { continue }
            
            for case let url as URL in enumerator {
                // Look for exported video files (usually have _Merged_ or similar naming)
                let fileName = url.lastPathComponent
                if (fileName.contains("_Merged_") || fileName.contains("Merged") || fileName.hasPrefix("Export_"))
                   && (url.pathExtension == "mov" || url.pathExtension == "mp4") {
                    
                    let destinationURL = exportsDirectory.appendingPathComponent(fileName)
                    
                    // Only migrate if file doesn't already exist in exports directory
                    if !FileManager.default.fileExists(atPath: destinationURL.path) {
                        do {
                            try FileManager.default.copyItem(at: url, to: destinationURL)
                            migratedCount += 1
                            print("📦 VideoFileManager: Migrated \(fileName) to STS_Exports")
                        } catch {
                            print("❌ VideoFileManager: Failed to migrate \(fileName): \(error)")
                        }
                    }
                }
            }
        }
        
        print("📦 VideoFileManager: Migration complete - \(migratedCount) files migrated")
    }
    
    // 🔥 CRITICAL FIX: Add methods required by SmartFill handoff document
    /// Get Documents directory URL with error handling
    func documentsURL() throws -> URL {
        guard let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw NSError(domain: "VideoFileManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Documents dir not found"])
        }
        return url
    }
    
    /// Get URL for file in Documents directory
    func urlForDocumentsFile(named fileName: String) throws -> URL {
        try documentsURL().appendingPathComponent(fileName, isDirectory: false)
    }
    
    /// Check if file exists in Documents directory
    func fileExists(named fileName: String) -> Bool {
        (try? urlForDocumentsFile(named: fileName)).map { FileManager.default.fileExists(atPath: $0.path) } ?? false
    }
    
    /// HANDOFF FIX: Enhanced variant resolver support
    func shouldShowStillPreview(for take: UnifiedTake) -> Bool {
        // Only require that the source file exists — do not gate on smartFilledFilePath
        return fileExists(named: take.fileName)
    }
    
    // 🔥 NEW: Enhanced file search for SmartFill integration
    func findVideoFile(named fileName: String) -> String? {
        print("🔍 VideoFileManager: Enhanced search for \(fileName)")
        
        // Search in common directories
        let searchPaths = [
            FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0],
            FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("SmartFill"),
            FileManager.default.temporaryDirectory
        ]
        
        for searchPath in searchPaths {
            let filePath = searchPath.appendingPathComponent(fileName).path
            if FileManager.default.fileExists(atPath: filePath) {
                print("✅ VideoFileManager: Found \(fileName) at \(filePath)")
                return filePath
            }
        }
        
        // Recursive search in Documents directory
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        if let foundPath = recursiveSearch(for: fileName, in: documentsURL) {
            print("✅ VideoFileManager: Found \(fileName) via recursive search at \(foundPath)")
            return foundPath
        }
        
        print("❌ VideoFileManager: Could not find \(fileName) anywhere")
        return nil
    }
    
    private func recursiveSearch(for fileName: String, in directory: URL) -> String? {
        guard let enumerator = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: [.isRegularFileKey]) else {
            return nil
        }
        
        for case let fileURL as URL in enumerator {
            if fileURL.lastPathComponent == fileName {
                return fileURL.path
            }
        }
        
        return nil
    }
}

// MARK: - Supporting Models

/// Enhanced video file representation with full metadata
struct VideoFile: Identifiable, Codable {
    let id: UUID
    let filePath: String
    let fileName: String
    let metadata: VideoMetadata
    let fileSize: Int
    let createdAt: Date
    
    init(filePath: String, fileName: String, metadata: VideoMetadata, fileSize: Int, createdAt: Date) {
        self.id = UUID()
        self.filePath = filePath
        self.fileName = fileName
        self.metadata = metadata
        self.fileSize = fileSize
        self.createdAt = createdAt
    }
    
    var url: URL {
        URL(fileURLWithPath: filePath)
    }
    
    var formattedFileSize: String {
        ByteCountFormatter.string(fromByteCount: Int64(fileSize), countStyle: .file)
    }
}

/// Rich metadata for video files
struct VideoMetadata: Codable {
    let projectTitle: String
    let roleName: String?
    let sceneNumber: Int
    let takeNumber: Int
    let rating: TakeRating
    let duration: TimeInterval
    let resolution: VideoResolution?
    let frameRate: Double?
    let codec: String?
    let recordingDate: Date
    let cameraPosition: String // "front" or "back"
    let audioChannels: Int?
    let notes: String?
    
    init(
        projectTitle: String = "",
        roleName: String? = nil,
        sceneNumber: Int = 1,
        takeNumber: Int = 1,
        rating: TakeRating = .unrated,
        duration: TimeInterval = 0,
        resolution: VideoResolution? = nil,
        frameRate: Double? = nil,
        codec: String? = nil,
        recordingDate: Date = Date(),
        cameraPosition: String = "back",
        audioChannels: Int? = nil,
        notes: String? = nil
    ) {
        self.projectTitle = projectTitle
        self.roleName = roleName
        self.sceneNumber = sceneNumber
        self.takeNumber = takeNumber
        self.rating = rating
        self.duration = duration
        self.resolution = resolution
        self.frameRate = frameRate
        self.codec = codec
        self.recordingDate = recordingDate
        self.cameraPosition = cameraPosition
        self.audioChannels = audioChannels
        self.notes = notes
    }
}

struct VideoResolution: Codable {
    let width: Int
    let height: Int
    
    var displayName: String {
        switch (width, height) {
        case (1920, 1080):
            return "1080p"
        case (1280, 720):
            return "720p"
        case (3840, 2160):
            return "4K"
        default:
            return "\(width)×\(height)"
        }
    }
}

// MARK: - Video Info Helper

struct VideoInfoDetails {
    let message: String
}

struct CameraSettingsSummary {
    let resolutionLabel: String
    let frameRateLabel: String
    let presetName: String?

    var displaySummary: String {
        var parts: [String] = [resolutionLabel, frameRateLabel]
        if let presetName, !presetName.isEmpty {
            parts.append("(\(presetName))")
        }
        return parts.joined(separator: " ")
    }
}

struct AudioSettingsSummary {
    let channelsLabel: String
    let sampleRateLabel: String
    let inputName: String?

    var displaySummary: String {
        var parts: [String] = [channelsLabel, sampleRateLabel]
        if let inputName, !inputName.isEmpty {
            parts.append("– \(inputName)")
        }
        return parts.joined(separator: " ")
    }
}

/// Centralized resolver for video URLs used by the Video Info alert.
/// Mirrors the resolvePhotoURL logic used in TakeReviewPage.
enum VideoInfoPathResolver {
    /// Resolve a usable file URL for a given take.
    /// - Note: Handles both absolute paths and relative paths under Documents.
    static func resolveURL(for take: ProjectTake) -> URL? {
        let rawPath = take.filePath
        let fm = FileManager.default

        // 1) Absolute path case (/var/mobile/Containers/Data/...)
        if rawPath.hasPrefix("/") {
            let url = URL(fileURLWithPath: rawPath)
            if fm.fileExists(atPath: url.path) {
                print("📹 VideoInfoPathResolver: Using absolute path for take \(take.id) -> \(url.path)")
                return url
            } else {
                print("⚠️ VideoInfoPathResolver: Absolute path does not exist for take \(take.id): \(url.path)")
            }
        }

        // 2) Primary relative path resolution via VideoVariantResolver
        let primary = VideoVariantResolver.urlForRelativePath(rawPath)
        if fm.fileExists(atPath: primary.path) {
            print("📹 VideoInfoPathResolver: Resolved via VideoVariantResolver for take \(take.id) -> \(primary.path)")
            return primary
        } else {
            print("⚠️ VideoInfoPathResolver: Variant resolver path missing for take \(take.id): \(primary.path)")
        }

        // 3) Fallback: look directly in Documents by file name
        let documentsURL = VideoVariantResolver.documentsURL()
        let fileName = URL(fileURLWithPath: rawPath).lastPathComponent
        let fallback = documentsURL.appendingPathComponent(fileName)
        if fm.fileExists(atPath: fallback.path) {
            print("📹 VideoInfoPathResolver: Using documents fallback for take \(take.id) -> \(fallback.path)")
            return fallback
        } else {
            print("❌ VideoInfoPathResolver: Could not resolve video URL for take \(take.id). rawPath=\(rawPath)")
            return nil
        }
    }
}

enum VideoInfoHelper {
    static func buildMessage(
        for take: ProjectTake,
        fileURL: URL?,
        cameraSettings: CameraSettingsSummary?,
        audioSettings: AudioSettingsSummary?
    ) async -> VideoInfoDetails {
        // Fail fast on missing URL
        guard let fileURL = fileURL else {
            let message = """
            File: \(URL(fileURLWithPath: take.filePath).lastPathComponent)
            Status: Could not resolve video file URL.
            Path: \(take.filePath)
            """
            return VideoInfoDetails(message: message)
        }

        let fm = FileManager.default
        guard fm.fileExists(atPath: fileURL.path) else {
            let message = """
            File: \(fileURL.lastPathComponent)
            Status: Video file not found on disk.
            Path: \(fileURL.path)
            """
            return VideoInfoDetails(message: message)
        }

        var lines: [String] = []

        let fileName = fileURL.lastPathComponent
        lines.append("File: \(fileName)")

        appendSceneTakeInfo(fromFileName: fileName, to: &lines, fallbackTake: take)

        if take.effectiveDurationSeconds > 0 {
            lines.append("Duration: \(formattedDuration(take.effectiveDurationSeconds))")
        }
        if let sizeText = fileSizeText(for: fileURL) {
            lines.append("Size: \(sizeText)")
        }

        // AVAsset details wrapped in do/catch so we always return
        do {
            let asset = AVURLAsset(url: fileURL)
            let details = try await loadVideoDetails(from: asset)
            if let resolution = details.resolutionText { lines.append(resolution) }
            if let fps = details.fpsText { lines.append(fps) }
            if let audio = try await loadAudioDetails(from: asset) {
                if let channels = audio.channelsLabel, let rate = audio.sampleRateLabel {
                    lines.append("Audio: \(channels), \(rate)")
                }
            }
        } catch {
            print("⚠️ Video info: failed to load AVAsset details: \(error)")
        }

        if let cameraSettings {
            lines.append("Video: \(cameraSettings.displaySummary)")
        }
        if let audioSettings {
            lines.append("Audio: \(audioSettings.displaySummary)")
        }

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.timeZone = .current
        lines.append("Created: \(formatter.string(from: take.createdAt))")

        return VideoInfoDetails(message: lines.joined(separator: "\n"))
    }

    // MARK: - Helpers

    private static func appendSceneTakeInfo(
        fromFileName fileName: String,
        to lines: inout [String],
        fallbackTake: ProjectTake
    ) {
        let pattern = #"S(\d+)T(\d+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            appendFallbackSceneTakeInfo(from: fallbackTake, to: &lines)
            return
        }

        let nsRange = NSRange(fileName.startIndex..., in: fileName)
        let matches = regex.matches(in: fileName, range: nsRange)

        guard !matches.isEmpty else {
            appendFallbackSceneTakeInfo(from: fallbackTake, to: &lines)
            return
        }

        let labels: [String] = matches.compactMap { match in
            guard match.numberOfRanges == 3,
                  let sceneRange = Range(match.range(at: 1), in: fileName),
                  let takeRange = Range(match.range(at: 2), in: fileName) else {
                return nil
            }
            let scene = String(fileName[sceneRange])
            let take = String(fileName[takeRange])
            return "S\(scene)T\(take)"
        }

        if !labels.isEmpty {
            lines.append("Scenes/Takes: \(labels.joined(separator: ", "))")
        } else {
            appendFallbackSceneTakeInfo(from: fallbackTake, to: &lines)
        }
    }

    private static func appendFallbackSceneTakeInfo(
        from take: ProjectTake,
        to lines: inout [String]
    ) {
        if take.sceneNumber > 0 {
            lines.append("Scene: \(take.sceneNumber)")
        }
        if take.takeNumber > 0 {
            lines.append("Take: \(take.takeNumber)")
        }
    }

    private struct AVVideoDetails {
        let resolutionText: String?
        let fpsText: String?
    }

    private struct AVAudioDetails {
        let channelsLabel: String?
        let sampleRateLabel: String?
    }

    private static func loadVideoDetails(from asset: AVAsset) async throws -> AVVideoDetails {
        let videoTracks = try await asset.loadTracks(withMediaType: .video)
        guard let track = videoTracks.first else {
            return AVVideoDetails(resolutionText: nil, fpsText: nil)
        }

        let naturalSize = try await track.load(.naturalSize)
        let preferredTransform = try await track.load(.preferredTransform)
        let transformed = naturalSize.applying(preferredTransform)
        let width = Int(abs(transformed.width))
        let height = Int(abs(transformed.height))
        let resolution: String? = (width > 0 && height > 0) ? "Resolution: \(width)x\(height)" : nil

        var fpsText: String? = nil
        if let frameRate = try? await track.load(.nominalFrameRate), frameRate > 0 {
            fpsText = String(format: "Frame rate: %.2f fps", frameRate)
        }

        return AVVideoDetails(resolutionText: resolution, fpsText: fpsText)
    }

    private static func loadAudioDetails(from asset: AVAsset) async throws -> AVAudioDetails? {
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        guard let track = audioTracks.first else { return nil }

        let formatDescriptions = try await track.load(.formatDescriptions)

        var channelsLabel: String?
        var sampleRateLabel: String?

        for desc in formatDescriptions {
            guard CMFormatDescriptionGetMediaType(desc) == kCMMediaType_Audio,
                  let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(desc)?.pointee else {
                continue
            }
            let channels = Int(asbd.mChannelsPerFrame)
            if channels > 0 {
                channelsLabel = channels == 1 ? "Mono" : "Stereo"
            }
            let sampleRate = Int(asbd.mSampleRate)
            if sampleRate > 0 {
                sampleRateLabel = "\(sampleRate / 1000) kHz"
            }
        }

        return AVAudioDetails(channelsLabel: channelsLabel, sampleRateLabel: sampleRateLabel)
    }

    private static func fileSizeText(for url: URL) -> String? {
        if let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize {
            return ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
        }
        return nil
    }

    private static func formattedDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Error Types

enum VideoFileError: Error, LocalizedError {
    case fileNotFound(String)
    case invalidPath
    case metadataError
    
    var errorDescription: String? {
        switch self {
        case .fileNotFound(let fileName):
            return "Video file not found: \(fileName)"
        case .invalidPath:
            return "Invalid video file path"
        case .metadataError:
            return "Could not read video metadata"
        }
    }
}
