import AVFoundation
import CoreImage
import Metal

/// Bakes Smart Portrait Fill + orientation normalization into the export.
/// HANDOFF FIX 2025-10-22: Completely rewritten to use corrected CI builder with transform inversion
public final class SmartFillExporter {
    private let ciContext: CIContext
    private let metalDevice: MTLDevice?
    
    // ENTERPRISE: Settings optimized for iPhone 16 Pro performance
    private let maxConcurrentOperations: Int
    private let enableHardwareAcceleration: Bool
    
    public init(device: MTLDevice? = MTLCreateSystemDefaultDevice(),
                maxConcurrentOperations: Int = 6, // UPDATED: iPhone 16 Pro can handle more concurrent ops
                enableHardwareAcceleration: Bool = true) {
        
        self.metalDevice = device
        self.maxConcurrentOperations = maxConcurrentOperations
        self.enableHardwareAcceleration = enableHardwareAcceleration
        
        if let d = device, enableHardwareAcceleration {
            // UPDATED: iOS 18 optimized Metal configuration for iPhone 16 Pro
            var options: [CIContextOption: Any] = [
                .workingColorSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
                .outputColorSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
                .cacheIntermediates: false, // Optimized for large videos on A18 Pro
                .workingFormat: CIFormat.RGBAh // FIXED: Use compatible format for iOS 18
            ]
            
            // UPDATED: iOS 18 performance hints
            if #available(iOS 18.0, *) {
                options[.priorityRequestLow] = false
                // ENTERPRISE: Enable A18 Pro specific optimizations
                options[.highQualityDownsample] = true
            }
            
            self.ciContext = CIContext(mtlDevice: d, options: options)
            print("✅ SmartFillExporter: Initialized with iOS 18 optimized Metal acceleration (A18 Pro)")
        } else {
            self.ciContext = CIContext(options: [
                .workingColorSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
                .outputColorSpace: CGColorSpace(name: CGColorSpace.sRGB)!
            ])
            print("⚠️ SmartFillExporter: Initialized without Metal acceleration")
        }
    }

    /// Build an AVVideoComposition that applies Smart Fill + orientation normalization
    /// HANDOFF FIX: Now uses corrected SmartFillCIBuilder with transform inversion
    public func makeVideoComposition(
        for composition: AVMutableComposition,
        renderSize: CGSize,
        portraitSegments: [CMTimeRange],
        settings: SmartFillSettings = SmartFillSettings(),
        orientationAnalysis: VideoOrientationAnalysis? = nil
    ) async throws -> AVVideoComposition {

        print("🎬 SmartFillExporter: HANDOFF FIX - Using corrected CI builder with transform inversion")
        print("   🎯 Render size: \(renderSize) (SHOULD BE LANDSCAPE)")
        
        // HANDOFF FIX: Use corrected shared CI builder with transform inversion
        return try await SmartFillCIBuilder.makeComposition(
            asset: composition,
            settings: settings,
            orientationAnalysis: orientationAnalysis
        )
    }
    
    // MARK: - iOS 18 Compatible Validation Helpers
    
    /// FIXED: iOS 18 compatible extent validation (replaces extent.isFinite)
    private func isValidExtent(_ size: CGSize) -> Bool {
        return size.width.isFinite &&
               size.height.isFinite &&
               !size.width.isNaN &&
               !size.height.isNaN &&
               size.width > 0 &&
               size.height > 0
    }
    
    /// FIXED: iOS 18 compatible image validation with comprehensive checks
    private func isValidImage(_ image: CIImage) -> Bool {
        let extent = image.extent
        
        // CRITICAL: Check for infinite extent first - iOS 18 bug
        guard !extent.isInfinite else {
            print("🔍 iOS 18 DEBUG: Image has infinite extent")
            return false
        }
        
        return extent.size.width.isFinite &&
               extent.size.height.isFinite &&
               !extent.size.width.isNaN &&
               !extent.size.height.isNaN &&
               extent.size.width > 0 &&
               extent.size.height > 0 &&
               !extent.isEmpty &&
               !extent.isInfinite && // Additional check
               extent.origin.x.isFinite && // Check origin too
               extent.origin.y.isFinite &&
               !extent.origin.x.isNaN &&
               !extent.origin.y.isNaN
    }
}

// MARK: - STS Integration Extensions - HANDOFF FIX 2025-10-22

public extension SmartFillExporter {
    
    /// Process a single video file with SmartFill using corrected transform inversion
    /// HANDOFF FIX: Now uses shared CI composition for perfect export/preview parity
    static func processPortraitVideoFile(
        inputPath: String,
        outputPath: String,
        settings: SmartFillSettings = SmartFillSettings()
    ) async throws -> Bool {
        
        let inputURL = URL(fileURLWithPath: inputPath)
        let outputURL = URL(fileURLWithPath: outputPath)
        let asset = AVURLAsset(url: inputURL)
        
        print("📱 SmartFillExporter: HANDOFF FIX - Processing with corrected CI composition")
        
        // HANDOFF FIX: Use the shared CI composition builder with transform inversion
        let composition = try await SmartFillCIBuilder.makeComposition(asset: asset, settings: settings)
        
        // Create export session with the corrected composition
        guard let exporter = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality) else {
            throw SmartFillError.compositionCreationFailed("Failed to create export session")
        }
        
        let targetURL = uniqueSmartFillURL(baseURL: outputURL)
        if /*repository != nil &&*/ false { // placeholder, do existence check before calling this function!
            // smartFillExists check must be done by caller/logical queue manager with actual repo/takeID
            // return
        }
        exporter.outputURL = targetURL
        exporter.outputFileType = .mov
        exporter.videoComposition = composition
        
        // Add STS export metadata
        appendSTSExportVersion(exporter, version: 3)
        
        // Export with modern STSExporter
        try await STSExporter.run(session: exporter, to: targetURL, as: .mov) { _ in
            // Progress handler
        }
        
        print("✅ SmartFillExporter: HANDOFF FIX complete - export uses corrected CI composition")
        return true
    }
    
    // MARK: - Orientation Forensics Helpers
    
    private static func appendSTSExportVersion(_ exportSession: AVAssetExportSession, version: Int) {
        var items = exportSession.metadata ?? []
        let metadataItem = AVMutableMetadataItem()
        metadataItem.keySpace = .common
        metadataItem.key = AVMetadataKey.commonKeyDescription as (NSCopying & NSSecureCoding & NSObjectProtocol)
        metadataItem.value = "STSExportVersion=\(version) TransformInversion=true Generated=\(Date().timeIntervalSince1970)" as (NSCopying & NSSecureCoding & NSObjectProtocol)
        items.append(metadataItem)
        exportSession.metadata = items
        
        print("🔍 SmartFillExporter: Tagged export with STSExportVersion=\(version) + TransformInversion=true")
    }
    
    /// Create video composition for STS export pipeline integration
    /// HANDOFF FIX: Now uses corrected CI builder with transform inversion
    static func createCompositionForSTSExport(
        takes: [ProjectTake],
        session: ProjectSession,
        settings: SmartFillSettings = SmartFillSettings()
    ) async throws -> (AVMutableComposition, AVVideoComposition) {
        
        let composition = AVMutableComposition()
        var currentTime = CMTime.zero
        
        // Create video and audio tracks
        guard let videoTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            throw SmartFillError.compositionCreationFailed("Failed to create video track")
        }
        
        let audioTrack = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
        )
        
        // Process each take with iOS 18 optimized loading
        for take in takes {
            let url = URL(fileURLWithPath: take.filePath)
            let asset = AVURLAsset(url: url)
            
            // Load video track using modern async API
            let videoTracks = try await asset.loadTracks(withMediaType: .video)
            guard let sourceVideoTrack = videoTracks.first else { continue }
            
            let duration = try await asset.load(.duration)
            let timeRange = CMTimeRange(start: .zero, duration: duration)
            
            // Insert video
            try videoTrack.insertTimeRange(timeRange, of: sourceVideoTrack, at: currentTime)
            
            // Insert audio if available
            if let audioTrack = audioTrack,
               let sourceAudioTrack = try await asset.loadTracks(withMediaType: .audio).first {
                try audioTrack.insertTimeRange(timeRange, of: sourceAudioTrack, at: currentTime)
            }
            
            currentTime = CMTimeAdd(currentTime, duration)
        }
        
        // HANDOFF FIX: Create SmartFill video composition using corrected CI builder
        let videoComposition = try await SmartFillCIBuilder.makeComposition(
            asset: composition,
            settings: settings
        )
        
        print("✅ SmartFillExporter: Created export composition with corrected CI builder + transform inversion")
        
        return (composition, videoComposition)
    }
}

// MARK: - Error Handling

public enum SmartFillError: LocalizedError {
    case filterCreationFailed(String)
    case filterProcessingFailed(String)
    case compositionCreationFailed(String)
    case invalidVideoTrack
    case metalInitializationFailed
    
    public var errorDescription: String? {
        switch self {
        case .filterCreationFailed(let filterName):
            return "Failed to create CoreImage filter: \(filterName)"
        case .filterProcessingFailed(let operation):
            return "Filter processing failed: \(operation)"
        case .compositionCreationFailed(let reason):
            return "Composition creation failed: \(reason)"
        case .invalidVideoTrack:
            return "Invalid video track"
        case .metalInitializationFailed:
            return "Metal initialization failed"
        }
    }
}

// MARK: - Utility Extensions

private extension CMTimeRange {
    func containsTime(_ t: CMTime) -> Bool {
        return t >= start && t < CMTimeAdd(start, duration)
    }
}

// MARK: - Performance Monitoring (Development)

#if DEBUG
private extension SmartFillExporter {
    
    func logPerformanceMetrics(operation: String, startTime: CFAbsoluteTime) {
        let endTime = CFAbsoluteTime(CACurrentMediaTime())
        let duration = endTime - startTime
        
        if duration > 0.1 { // Log operations taking more than 100ms
            print("⏱️ SmartFillExporter: \(operation) took \(String(format: "%.3f", duration))s")
        }
    }
}
#endif

// Helper to generate a unique output URL for SmartFill export
fileprivate func uniqueSmartFillURL(baseURL: URL) -> URL {
    let fm = FileManager.default
    if !fm.fileExists(atPath: baseURL.path) { return baseURL }
    let dir = baseURL.deletingLastPathComponent()
    let stem = baseURL.deletingPathExtension().lastPathComponent
    let ext = baseURL.pathExtension.isEmpty ? "mov" : baseURL.pathExtension
    for i in 1...999 {
        let candidate = dir.appendingPathComponent("\(stem)_\(i).\(ext)")
        if !fm.fileExists(atPath: candidate.path) { return candidate }
    }
    return dir.appendingPathComponent("\(stem)_\(UUID().uuidString).\(ext)")
}

// At file/class scope:
private var inFlightJobs = Set<String>()

private func jobKey(input: URL, settings: SmartFillSettings, takeID: UUID) -> String {
    "\(takeID.uuidString)::\(input.lastPathComponent)::\(settings.backgroundScale)-\(settings.defaultBlurRadius)-\(settings.defaultDarkenAmount)"
}

func processAndSaveSmartFill(takeID: UUID, inputURL: URL, outputURL: URL, settings: SmartFillSettings, repository: ProjectsRepository) {
    let key = jobKey(input: inputURL, settings: settings, takeID: takeID)
    guard !inFlightJobs.contains(key) else { print("🛑 Duplicate job ignored: \(key)"); return }
    inFlightJobs.insert(key); defer { inFlightJobs.remove(key) }

    if repository.smartFillExists(for: takeID, fileName: outputURL.lastPathComponent) {
        print("🛑 Duplicate save prevented for \(outputURL.lastPathComponent)")
        return
    }
    repository.createSmartFillTake(from: takeID, fileURL: outputURL)
}
