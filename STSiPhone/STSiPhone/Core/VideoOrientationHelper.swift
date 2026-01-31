import AVFoundation

/// Centralized logic to determine if a video composition transform is needed to correct orientation.
/// RESEARCH-BASED FIX: AVPlayerViewController handles orientation automatically via video metadata.
/// Video composition should NOT be used for display - it overrides natural orientation handling.
/// UPDATED: Swift 6 actor isolation compliance for AVPlayerItem creation
func shouldForceVideoComposition(naturalSize: CGSize, preferredTransform: CGAffineTransform) -> Bool {
    print("🔍 [VideoOrientationHelper] Analyzing video for DISPLAY context:")
    print("   📏 Natural Size: \(naturalSize)")
    print("   📐 Transform: \(preferredTransform)")
    
    // RESEARCH INSIGHT: AVPlayerViewController handles video orientation automatically
    // based on embedded metadata. Forcing video composition overrides this natural behavior
    // and causes the "one orientation works, other doesn't" problem we've been experiencing.
    
    print("🔍 [VideoOrientationHelper] ✅ Letting AVPlayerViewController handle orientation naturally")
    print("   💡 Research shows: AVPlayerViewController respects video rotation metadata automatically")
    print("   💡 Video composition should only be used for export/processing, not display")
    
    return false
}

// --- PLACEHOLDER FUNCTION (NOT USED FOR DISPLAY) ---
/// This function is kept for potential export use cases but should NOT be called for display
/// RESEARCH FINDING: Video composition for display breaks AVPlayerViewController's natural orientation handling
/// UPDATED: Swift 6 actor isolation compliance - marked @MainActor for AVPlayerItem creation
@MainActor
func createOrientationCorrectedPlayerItem(
    asset: AVAsset,
    videoTrack: AVAssetTrack,
    preferredTransform: CGAffineTransform,
    naturalSize: CGSize
) async throws -> (AVPlayerItem, AVMutableVideoComposition) {
    
    // This function should not be called for display purposes
    print("⚠️ [VideoOrientationHelper] WARNING: Video composition should not be used for display")
    print("   💡 AVPlayerViewController handles orientation automatically")
    
    // UPDATED: Use modern async API for duration - now actor-safe
    let assetDuration = try await asset.load(.duration)
    
    // FIXED: AVPlayerItem creation is now on main actor (Swift 6 compliance)
    let playerItem = AVPlayerItem(asset: asset)
    let videoComposition = AVMutableVideoComposition()
    videoComposition.renderSize = naturalSize
    videoComposition.frameDuration = CMTime(value: 1, timescale: 30)
    
    let instruction = AVMutableVideoCompositionInstruction()
    instruction.timeRange = CMTimeRange(start: .zero, duration: assetDuration)
    let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)
    layerInstruction.setTransform(CGAffineTransform.identity, at: .zero)
    instruction.layerInstructions = [layerInstruction]
    videoComposition.instructions = [instruction]
    playerItem.videoComposition = videoComposition
    
    return (playerItem, videoComposition)
}

// MARK: - Actor-Safe Video Orientation Analysis Utilities

/// Actor-safe utility for analyzing video orientation without creating player items
/// This is the preferred method for orientation detection that doesn't require UI components
func analyzeVideoOrientationMetadata(from asset: AVAsset) async throws -> (naturalSize: CGSize, transform: CGAffineTransform, duration: CMTime) {
    print("🔍 [VideoOrientationHelper] Performing actor-safe orientation analysis")
    
    // Load video tracks and properties safely
    let videoTracks = try await asset.load(.tracks).filter { $0.mediaType == .video }
    
    guard let videoTrack = videoTracks.first else {
        throw NSError(domain: "VideoOrientationHelper", code: -1, 
                     userInfo: [NSLocalizedDescriptionKey: "No video track found"])
    }
    
    // Load track properties asynchronously
    let naturalSize = try await videoTrack.load(.naturalSize)
    let preferredTransform = try await videoTrack.load(.preferredTransform)
    let duration = try await asset.load(.duration)
    
    print("🔍 [VideoOrientationHelper] Analysis complete - Size: \(naturalSize), Transform: \(preferredTransform)")
    
    return (naturalSize: naturalSize, transform: preferredTransform, duration: duration)
}

/// Actor-safe method to determine video orientation from metadata without player item creation
/// This is the recommended approach for orientation detection in Swift 6+
func detectVideoOrientation(from asset: AVAsset) async throws -> VideoOrientationResult {
    let metadata = try await analyzeVideoOrientationMetadata(from: asset)
    
    // Analyze transform to determine orientation
    let transform = metadata.transform
    let naturalSize = metadata.naturalSize
    
    // Calculate effective size after transform
    let transformedSize = naturalSize.applying(transform)
    let effectiveWidth = abs(transformedSize.width)
    let effectiveHeight = abs(transformedSize.height)
    
    let isLandscape = effectiveWidth > effectiveHeight
    
    // Determine rotation angle from transform
    let rotationAngle = atan2(transform.b, transform.a) * 180 / .pi
    
    let result = VideoOrientationResult(
        isLandscape: isLandscape,
        rotationAngle: rotationAngle,
        naturalSize: naturalSize,
        effectiveSize: CGSize(width: effectiveWidth, height: effectiveHeight),
        transform: transform,
        duration: metadata.duration
    )
    
    print("🔍 [VideoOrientationHelper] Detected orientation: \(isLandscape ? "Landscape" : "Portrait"), rotation: \(rotationAngle)°")
    
    return result
}

// MARK: - Supporting Types

/// Result structure for actor-safe video orientation analysis
struct VideoOrientationResult {
    let isLandscape: Bool
    let rotationAngle: Double
    let naturalSize: CGSize
    let effectiveSize: CGSize
    let transform: CGAffineTransform
    let duration: CMTime
    
    var orientationDescription: String {
        return isLandscape ? "Landscape" : "Portrait"
    }
    
    var isRotated: Bool {
        return abs(rotationAngle) > 10 // Consider rotated if more than 10 degrees
    }
}
