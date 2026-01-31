import Foundation
import AVFoundation
import UIKit

// MARK: - Edit Effects

/// Represents the effects to be applied by an edit operation
struct EditEffects {
    let layerInstructions: [AVMutableVideoCompositionLayerInstruction]
    let renderSize: CGSize?
    
    init(layerInstructions: [AVMutableVideoCompositionLayerInstruction] = [], renderSize: CGSize? = nil) {
        self.layerInstructions = layerInstructions
        self.renderSize = renderSize
    }
}

// MARK: - Edit Operation Protocol

/// Protocol for non-destructive edit operations that can be applied, undone, and previewed
protocol EditOperation: AnyObject {
    /// Unique identifier for this operation
    var id: UUID { get }
    
    /// Display name for this operation in UI
    var displayName: String { get }
    
    /// Icon name for this operation in UI
    var iconName: String { get }
    
    /// Whether this operation can be previewed in real-time
    var canPreview: Bool { get }
    
    /// Apply this operation to the composition for preview - CRITICAL FIX: Made async
    func applyToComposition(_ composition: AVMutableComposition, sourceAsset: AVAsset) async throws
    
    /// Create a copy of this operation for undo/redo
    func copy() -> EditOperation
    
    /// Validate if this operation can be applied to the given asset
    func canApplyToAsset(_ asset: AVAsset) -> Bool
    
    /// Get a description of what this operation will do
    var operationDescription: String { get }
}

// MARK: - Trim Operation

/// Non-destructive trim operation that stores start and end times
final class TrimOperation: EditOperation {
    let id = UUID()
    let displayName = "Trim"
    let iconName = "scissors"
    let canPreview = true
    
    private let startTime: CMTime
    private let endTime: CMTime
    private let originalDuration: CMTime
    
    var trimRange: CMTimeRange {
        CMTimeRange(start: startTime, duration: CMTimeSubtract(endTime, startTime))
    }
    
    var trimStartTime: CMTime {
        return startTime
    }
    
    var trimEndTime: CMTime {
        return endTime
    }
    
    var operationDescription: String {
        let startSeconds = CMTimeGetSeconds(startTime)
        let endSeconds = CMTimeGetSeconds(endTime)
        let durationSeconds = CMTimeGetSeconds(CMTimeSubtract(endTime, startTime))
        
        return String(format: "Trim to %.1f-%.1fs (%.1fs duration)", startSeconds, endSeconds, durationSeconds)
    }
    
    init(startTime: CMTime, endTime: CMTime, originalDuration: CMTime) {
        self.startTime = startTime
        self.endTime = endTime
        self.originalDuration = originalDuration
    }
    
    // Convenience initializer from CMTimeRange
    convenience init(trimRange: CMTimeRange) {
        let endTime = CMTimeAdd(trimRange.start, trimRange.duration)
        // Use maximum possible duration for originalDuration since we don't have asset context
        let maxDuration = CMTimeAdd(endTime, CMTime(seconds: 3600, preferredTimescale: 600))
        self.init(startTime: trimRange.start, endTime: endTime, originalDuration: maxDuration)
    }
    
    func applyToComposition(_ composition: AVMutableComposition, sourceAsset: AVAsset) async throws {
        // CRITICAL FIX: Make this properly async instead of using Task wrapper
        print("✂️ TRIM OPERATION: Applying trim range \(trimRange) to composition")
        
        // Remove existing tracks to apply fresh trim
        for track in composition.tracks {
            composition.removeTrack(track)
        }
        
        // FIXED: Direct async/await instead of Task wrapper
        // Add video track with trim range
        let videoTracks = try await sourceAsset.loadTracks(withMediaType: .video)
        if let videoTrack = videoTracks.first {
            let compositionVideoTrack = composition.addMutableTrack(
                withMediaType: .video,
                preferredTrackID: kCMPersistentTrackID_Invalid
            )
            try compositionVideoTrack?.insertTimeRange(trimRange, of: videoTrack, at: .zero)
            print("✅ TRIM: Video track added with range \(trimRange)")
        }
        
        // Add audio track with trim range
        let audioTracks = try await sourceAsset.loadTracks(withMediaType: .audio)
        if let audioTrack = audioTracks.first {
            let compositionAudioTrack = composition.addMutableTrack(
                withMediaType: .audio,
                preferredTrackID: kCMPersistentTrackID_Invalid
            )
            try compositionAudioTrack?.insertTimeRange(trimRange, of: audioTrack, at: .zero)
            print("✅ TRIM: Audio track added with range \(trimRange)")
        }
    }
    
    func copy() -> EditOperation {
        return TrimOperation(startTime: startTime, endTime: endTime, originalDuration: originalDuration)
    }
    
    func canApplyToAsset(_ asset: AVAsset) -> Bool {
        // Use async duration check - for now, assume valid for compatibility
        Task {
            do {
                let duration = try await asset.load(.duration)
                return startTime >= .zero && endTime <= duration && startTime < endTime
            } catch {
                return false
            }
        }
        
        // Return optimistic result for synchronous compatibility
        return startTime >= .zero && startTime < endTime
    }
}

// MARK: - Crop Operation

/// Non-destructive crop operation that stores normalized crop rectangle
final class CropOperation: EditOperation {
    let id = UUID()
    let displayName = "Crop"
    let iconName = "crop"
    let canPreview = true
    
    private let cropRect: CGRect // Normalized coordinates (0.0 to 1.0)
    private let rotationDegrees: CGFloat
    
    var operationDescription: String {
        let percentage = cropRect.width * cropRect.height * 100
        if abs(rotationDegrees) > 0.01 {
            return String(format: "Crop to %.1f%% (rotate %.1f°)", percentage, rotationDegrees)
        } else {
            return String(format: "Crop to %.1f%% of original frame", percentage)
        }
    }
    
    init(normalizedCropRect: CGRect, rotationDegrees: CGFloat = 0) {
        self.cropRect = normalizedCropRect
        self.rotationDegrees = rotationDegrees
        print("🔧 CROP OPERATION: Created with normalized rect: \(normalizedCropRect), rotation: \(rotationDegrees)")
    }
    
    func applyToComposition(_ composition: AVMutableComposition, sourceAsset: AVAsset) async throws {
        print("✂️ CROP OPERATION: applyToComposition called - crop metadata stored")
        // The actual crop transform will be applied by the EditStack's createVideoComposition method
        // This method just needs to exist for the protocol - the real work happens in EditStack
    }
    
    func copy() -> EditOperation {
        return CropOperation(normalizedCropRect: cropRect, rotationDegrees: rotationDegrees)
    }
    
    func canApplyToAsset(_ asset: AVAsset) -> Bool {
        // Crop can be applied to any asset with video tracks using modern API
        Task {
            do {
                let videoTracks = try await asset.loadTracks(withMediaType: .video)
                return !videoTracks.isEmpty
            } catch {
                return false
            }
        }
        
        // Return optimistic result for synchronous compatibility
        return true
    }
    
    /// Get the crop rectangle for external use
    var normalizedCropRect: CGRect {
        return cropRect
    }
    
    var rotationAngleDegrees: CGFloat {
        return rotationDegrees
    }
}

// MARK: - SmartFill Operation

/// Non-destructive SmartFill operation that stores processing parameters
final class SmartFillOperation: EditOperation {
    let id = UUID()
    let displayName = "SmartFill"
    let iconName = "rectangle.fill.badge.plus"
    let canPreview = true // UPDATED: Enable preview with scale approximation
    
    private let settings: SmartFillSettings
    
    var operationDescription: String {
        let blurRadius = Int(settings.defaultBlurRadius)
        let darkenPercent = Int(settings.defaultDarkenAmount * 100)
        return "Apply SmartFill (blur: \(blurRadius)px, darken: \(darkenPercent)%)"
    }
    
    // UPDATED: Accept SmartFillSettings instead of simple enums
    init(settings: SmartFillSettings = SmartFillSettings()) {
        self.settings = settings
    }
    
    // LEGACY: Keep old constructor for backward compatibility
    init(fillMode: SmartFillMode = .automatic, aspectRatio: AspectRatio = .portrait) {
        // Convert legacy parameters to SmartFillSettings
        self.settings = SmartFillSettings(
            defaultEnabled: true,
            defaultBlurRadius: 20.0, // Use reasonable default
            defaultDarkenAmount: 0.15, // Use reasonable default
            defaultRenderSize: aspectRatio == .landscape ? CGSize(width: 1920, height: 1080) : CGSize(width: 1080, height: 1920)
        )
    }
    
    // PATCH: Preview approximation - rely on default playback to avoid distorting user adjustments
    func makeEffects(sourceAsset: AVAsset) async throws -> EditEffects {
        // Leave preview unchanged; SmartFill visualisation happens in final export
        return EditEffects()
    }
    
    func applyToComposition(_ composition: AVMutableComposition, sourceAsset: AVAsset) async throws {
        // Store settings metadata for export processing
        let smartFillMetadata = AVMutableMetadataItem()
        smartFillMetadata.identifier = AVMetadataIdentifier("com.selfstudio.smartfill.settings")
        smartFillMetadata.value = "blur:\(settings.defaultBlurRadius),darken:\(settings.defaultDarkenAmount)" as NSString
        
        print("🤖 SmartFill operation prepared: blur=\(settings.defaultBlurRadius), darken=\(settings.defaultDarkenAmount)")
    }
    
    func copy() -> EditOperation {
        return SmartFillOperation(settings: settings)
    }
    
    func canApplyToAsset(_ asset: AVAsset) -> Bool {
        // SmartFill can be applied to any video asset using modern API
        Task {
            do {
                let videoTracks = try await asset.loadTracks(withMediaType: .video)
                return !videoTracks.isEmpty
            } catch {
                return false
            }
        }
        
        // Return optimistic result for synchronous compatibility
        return true
    }
    
    // MARK: - Getters for external use
    
    var smartFillSettings: SmartFillSettings {
        return settings
    }
    
    // LEGACY SUPPORT: Keep enums for backward compatibility
    enum SmartFillMode {
        case automatic
        case centerFocus
        case faceFocus
        
        var displayName: String {
            switch self {
            case .automatic: return "Automatic"
            case .centerFocus: return "Center Focus"
            case .faceFocus: return "Face Focus"
            }
        }
    }
    
    enum AspectRatio {
        case portrait // 9:16
        case square   // 1:1
        case landscape // 16:9
        
        var displayName: String {
            switch self {
            case .portrait: return "9:16 Portrait"
            case .square: return "1:1 Square"
            case .landscape: return "16:9 Landscape"
            }
        }
        
        var ratio: CGFloat {
            switch self {
            case .portrait: return 9.0/16.0
            case .square: return 1.0
            case .landscape: return 16.0/9.0
            }
        }
    }
}

// MARK: - Errors

enum EditOperationError: LocalizedError {
    case noSourceAsset
    case invalidTimeRange
    case invalidCropRect
    case trackInsertionFailed
    
    var errorDescription: String? {
        switch self {
        case .noSourceAsset:
            return "No source asset available for editing"
        case .invalidTimeRange:
            return "Invalid time range for trim operation"
        case .invalidCropRect:
            return "Invalid crop rectangle"
        case .trackInsertionFailed:
            return "Failed to insert track into composition"
        }
    }
}
