import AVFoundation
import CoreGraphics
import UIKit

// MARK: - HANDOFF FIX 2025-10-22: Perfect Center Fix - Single Source of Truth

public enum NOAxisRotation {
    case up    // 0°
    case down  // 180°
    case left  // 90° CCW
    case right // 90° CW
}

/// Utilities to normalize orientation using each track's preferredTransform.
/// HANDOFF FIX 2025-10-22: Added perfect centering with transform inversion support
public enum NormalizeOrientation {

    // MARK: - HANDOFF FIX 2025-10-22: Enhanced Rotation Detection System
    
    /// Derive rotation from preferredTransform (tolerance for float noise)
    public static func rotation(from t: CGAffineTransform) -> NOAxisRotation {
        let a = round(t.a * 1000) / 1000
        let b = round(t.b * 1000) / 1000
        let c = round(t.c * 1000) / 1000
        let d = round(t.d * 1000) / 1000
        switch (a, b, c, d) {
        case ( 1,  0,  0,  1): return .up
        case (-1,  0,  0, -1): return .down
        case ( 0,  1, -1,  0): return .right  // 90° CW
        case ( 0, -1,  1,  0): return .left   // 90° CCW
        default:                return .up     // safe default
        }
    }

    /// Upright display size after applying preferredTransform
    public static func uprightSize(natural: CGSize, preferred: CGAffineTransform) -> CGSize {
        switch rotation(from: preferred) {
        case .up, .down:   return natural
        case .left, .right:return CGSize(width: natural.height, height: natural.width)
        }
    }

    /// HANDOFF FIX 2025-10-22: Aspect-fit into renderSize with correct rotation and centering
    public static func aspectFitTransform(naturalSize: CGSize,
                                          preferred: CGAffineTransform,
                                          renderSize: CGSize) -> CGAffineTransform {
        let rot = rotation(from: preferred)
        let upright = uprightSize(natural: naturalSize, preferred: preferred)

        // Scale to fit inside render
        let sx = renderSize.width  / upright.width
        let sy = renderSize.height / upright.height
        let s  = min(sx, sy)

        let scaledW = upright.width  * s
        let scaledH = upright.height * s
        let centerX = (renderSize.width  - scaledW) * 0.5
        let centerY = (renderSize.height - scaledH) * 0.5

        // HANDOFF FIX: Enhanced debug logging for exact values
        print("🔄 NormalizeOrientation HANDOFF FIX:")
        print("   📐 Natural: \(naturalSize), Upright: \(upright), Render: \(renderSize)")
        print("   🧮 sx=\(sx), sy=\(sy), s=\(s)")
        print("   📏 scaledW=\(scaledW), scaledH=\(scaledH)")
        print("   🧭 centerX=\(centerX), centerY=\(centerY)")
        print("   🔄 Rotation: \(rot) (\(rotationDisplayName(rot)))")

        switch rot {
        case .up:
            let transform = CGAffineTransform(a: s,  b: 0,
                                             c: 0,  d: s,
                                             tx: centerX, ty: centerY)
            print("   🧭 .up: tx=\(centerX), ty=\(centerY)")
            return transform

        case .down:
            let tx = scaledW + centerX
            let ty = scaledH + centerY
            let transform = CGAffineTransform(a: -s, b:  0,
                                             c:  0, d: -s,
                                             tx: tx, ty: ty)
            print("   🧭 .down: tx=\(tx), ty=\(ty)")
            return transform

        case .right: // 90° CW; should give tx=1736.25 for the handoff example
            let tx = scaledH + centerX  // HANDOFF FIX: This should match tx=1736.25
            let ty = centerY           // HANDOFF FIX: This should be ty=0 for landscape
            let transform = CGAffineTransform(a: 0,  b: s,
                                             c: -s, d: 0,
                                             tx: tx, ty: ty)
            print("   🧭 .right (90° CW): tx=\(tx), ty=\(ty)")
            
            // HANDOFF FIX: Verify we match expected values
            if abs(tx - 1736.25) < 0.1 && abs(ty) < 0.1 {
                print("   ✅ HANDOFF VERIFICATION: Transform matches expected tx=1736.25, ty=0")
            }
            
            return transform

        case .left:  // 90° CCW
            let tx = centerX
            let ty = scaledW + centerY
            let transform = CGAffineTransform(a: 0,  b: -s,
                                             c: s,  d:  0,
                                             tx: tx, ty: ty)
            print("   🧭 .left (90° CCW): tx=\(tx), ty=\(ty)")
            return transform
        }
    }

    /// HANDOFF FIX 2025-10-22: Post-transform centering shim (guards against residual dx/dy)
    public static func perfectlyCenteredTransform(naturalSize: CGSize,
                                                  preferred: CGAffineTransform,
                                                  renderSize: CGSize) -> CGAffineTransform {
        let t0 = aspectFitTransform(naturalSize: naturalSize, preferred: preferred, renderSize: renderSize)
        let upright = uprightSize(natural: naturalSize, preferred: preferred)
        let rect = CGRect(origin: .zero, size: upright).applying(t0)
        let dx = (renderSize.width  - rect.width)  * 0.5 - rect.minX
        let dy = (renderSize.height - rect.height) * 0.5 - rect.minY
        
        print("🧪 NormalizeOrientation Perfect Center:")
        print("   🧪 FG Rect pre-shim: \(rect)")
        
        let finalTransform = t0.translatedBy(x: dx, y: dy)
        
        // Verify centering
        let centered = rect.applying(CGAffineTransform(translationX: dx, y: dy))
        print("   🎯 FG Rect post-shim: \(centered) (should be centered inside 0..\(renderSize.width)x0..\(renderSize.height))")
        
        return finalTransform
    }

    // MARK: - Centered Aspect-Fit Transform (shared by export paths)
    
    static func centeredAspectFitTransform(
        for sourceTrack: AVAssetTrack,
        renderSize: CGSize
    ) async -> CGAffineTransform {
        let t = (try? await sourceTrack.load(.preferredTransform)) ?? .identity
        let natural = (try? await sourceTrack.load(.naturalSize)) ?? .zero

        let orientedSize = CGSize(
            width: abs(natural.applying(t).width),
            height: abs(natural.applying(t).height)
        )
        guard orientedSize.width > 0, orientedSize.height > 0 else { return t }

        let scale = min(renderSize.width / orientedSize.width,
                        renderSize.height / orientedSize.height)

        var transform = t.concatenating(CGAffineTransform(scaleX: scale, y: scale))

        let transformedRect = CGRect(origin: .zero, size: natural).applying(transform)

        let dx = (renderSize.width  - transformedRect.width)  / 2.0 - transformedRect.minX
        let dy = (renderSize.height - transformedRect.height) / 2.0 - transformedRect.minY

        transform = transform.concatenating(CGAffineTransform(translationX: dx, y: dy))
        return transform
    }
    
    // MARK: - Helper Functions
    
    private static func rotationDisplayName(_ rotation: NOAxisRotation) -> String {
        switch rotation {
        case .up: return "0°"
        case .down: return "180°"
        case .left: return "90° CCW"
        case .right: return "90° CW"
        }
    }
    
    // MARK: - LEGACY METHODS (Kept for backward compatibility)

    /// Returns the upright extent (size) after applying `preferredTransform`.
    public static func uprightExtent(naturalSize: CGSize, preferred: CGAffineTransform) -> CGSize {
        let rect = CGRect(origin: .zero, size: naturalSize).applying(preferred)
        return CGSize(width: abs(rect.width), height: abs(rect.height))
    }

    /// Builds a transform that rotates to upright (preferred), scales, and centers into `dst`.
    /// HANDOFF FIX #4: Enhanced with debug logging and proper AVMakeRect usage
    public static func finalTransform(naturalSize: CGSize,
                                      preferred: CGAffineTransform,
                                      scale: CGFloat,
                                      dst: CGSize) -> CGAffineTransform {
        let upright = uprightExtent(naturalSize: naturalSize, preferred: preferred)
        let scaledSize = CGSize(width: upright.width * scale, height: upright.height * scale)
        let offset = CGPoint(x: (dst.width - scaledSize.width) * 0.5, y: (dst.height - scaledSize.height) * 0.5)
        
        // HANDOFF FIX #4: Order: translate -> scale -> preferred (for proper composition)
        let transform = CGAffineTransform(translationX: offset.x, y: offset.y)
            .scaledBy(x: scale, y: scale)
            .concatenating(preferred)
            
        print("📐 NormalizeOrientation: HANDOFF FIX #4 - Final transform calculation")
        print("   🎯 Natural: \(naturalSize) -> Upright: \(upright)")
        print("   🎯 Scale: \(scale), Offset: \(offset)")
        print("   🎯 Transform order: translate -> scale -> preferred")
        
        return transform
    }

    /// LEGACY: Enhanced aspect-fit transform using AVMakeRect (kept for backward compatibility)
    /// NOTE: This method is DEPRECATED - use the main aspectFitTransform method above
    @available(*, deprecated, message: "Use the main aspectFitTransform method with exact rotation handling from handoff fix")
    public static func aspectFitTransformLegacy(
        naturalSize: CGSize,
        preferred: CGAffineTransform,
        renderSize: CGSize
    ) -> CGAffineTransform {
        // Compute upright display size once
        let displaySize = uprightExtent(naturalSize: naturalSize, preferred: preferred)
        
        // Use AVMakeRect for proper aspect-fit calculation
        let fitRect = AVMakeRect(aspectRatio: displaySize, insideRect: CGRect(origin: .zero, size: renderSize))
        let scale = fitRect.width / displaySize.width
        
        // Apply preferred transform -> scale -> translate (handoff specified order)
        var transform = preferred
        transform = transform.scaledBy(x: scale, y: scale)
        
        // Translate by unscaled offsets (as per handoff spec)
        let tx = fitRect.origin.x / scale
        let ty = fitRect.origin.y / scale
        transform = transform.translatedBy(x: tx, y: ty)
        
        print("⚠️ NormalizeOrientation: LEGACY aspectFitTransformLegacy called")
        print("   📐 Display: \(displaySize) -> Fit rect: \(fitRect)")
        print("   🔧 Scale: \(scale), Translation: (\(tx), \(ty))")
        print("   📝 NOTE: Use the main aspectFitTransform method for handoff fixes")
        
        return transform
    }

    /// Computes suggested scales for foreground (fit) and background (fill).
    public static func scalesForFGandBG(naturalSize: CGSize,
                                        preferred: CGAffineTransform,
                                        dst: CGSize) -> (fg: CGFloat, bg: CGFloat) {
        let upright = uprightExtent(naturalSize: naturalSize, preferred: preferred)
        let fg = SmartFillMath.scaleToFit(src: upright, dst: dst)
        let bg = SmartFillMath.scaleToFill(src: upright, dst: dst)
        return (fg, bg)
    }
    
    // MARK: - STS Integration Methods
    
    /// Analyze video orientation from AVAsset for ProjectTake integration
    public static func analyzeVideoOrientation(from asset: AVAsset) async throws -> VideoOrientationAnalysis {
        
        let videoTracks = try await asset.loadTracks(withMediaType: .video)
        guard let videoTrack = videoTracks.first else {
            throw OrientationError.noVideoTrack
        }
        
        let naturalSize = try await videoTrack.load(.naturalSize)
        let preferredTransform = try await videoTrack.load(.preferredTransform)
        let timeRange = try await videoTrack.load(.timeRange)
        
        let uprightSize = uprightExtent(naturalSize: naturalSize, preferred: preferredTransform)
        let orientation = uprightSize.width > uprightSize.height ? VideoOrientation.landscape : VideoOrientation.portrait
        
        let transformType = classifyTransform(preferredTransform)
        
        return VideoOrientationAnalysis(
            capturedOrientation: orientation,
            naturalSize: naturalSize,
            preferredTransform: preferredTransform,
            uprightSize: uprightSize,
            transformType: transformType,
            duration: timeRange.duration.seconds
        )
    }
    
    /// Enhanced transform classification for debugging and optimization
    public static func classifyTransform(_ transform: CGAffineTransform) -> TransformType {
        if transform.isIdentity {
            return .identity
        }
        
        // Check for 90-degree rotations (common in mobile video)
        if abs(transform.a) < 0.1 && abs(transform.d) < 0.1 {
            if transform.b > 0.9 && transform.c < -0.9 {
                return .rotate90Clockwise
            } else if transform.b < -0.9 && transform.c > 0.9 {
                return .rotate90CounterClockwise
            }
        }
        
        // Check for 180-degree rotation
        if abs(transform.a + 1.0) < 0.1 && abs(transform.d + 1.0) < 0.1 &&
           abs(transform.b) < 0.1 && abs(transform.c) < 0.1 {
            return .rotate180
        }
        
        return .custom
    }
    
    /// Create normalized video composition for consistent orientation
    /// UPDATED: Use modern async API for duration
    public static func createNormalizedComposition(
        for asset: AVAsset,
        targetRenderSize: CGSize
    ) async throws -> (AVMutableComposition, AVMutableVideoComposition?) {
        
        let composition = AVMutableComposition()
        
        guard let videoTrack = try await asset.loadTracks(withMediaType: .video).first else {
            throw OrientationError.noVideoTrack
        }
        
        guard let compositionVideoTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            throw OrientationError.compositionCreationFailed
        }
        
        // UPDATED: Use modern async API for duration
        let assetDuration = try await asset.load(.duration)
        let timeRange = CMTimeRange(start: .zero, duration: assetDuration)
        try compositionVideoTrack.insertTimeRange(timeRange, of: videoTrack, at: .zero)
        
        // Add audio track if present
        if let audioTrack = try await asset.loadTracks(withMediaType: .audio).first {
            let compositionAudioTrack = composition.addMutableTrack(
                withMediaType: .audio,
                preferredTrackID: kCMPersistentTrackID_Invalid
            )
            try compositionAudioTrack?.insertTimeRange(timeRange, of: audioTrack, at: .zero)
        }
        
        // Create video composition for orientation normalization
        let naturalSize = try await videoTrack.load(.naturalSize)
        let preferredTransform = try await videoTrack.load(.preferredTransform)
        
        let videoComposition = AVMutableVideoComposition()
        videoComposition.renderSize = targetRenderSize
        videoComposition.frameDuration = CMTime(value: 1, timescale: 30)
        
        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = timeRange
        
        let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: compositionVideoTrack)
        
        // HANDOFF FIX 2025-10-22: Use the new aspectFitTransform method for normalization
        let transform = aspectFitTransform(
            naturalSize: naturalSize,
            preferred: preferredTransform,
            renderSize: targetRenderSize
        )
        
        layerInstruction.setTransform(transform, at: .zero)
        instruction.layerInstructions = [layerInstruction]
        videoComposition.instructions = [instruction]
        
        return (composition, videoComposition)
    }
}

// MARK: - Data Structures for STS Integration

// 🚨 SWIFT 6 SENDABILITY: Made VideoOrientationAnalysis Sendable for safe concurrent access
public struct VideoOrientationAnalysis: Sendable {
    public let capturedOrientation: VideoOrientation
    public let naturalSize: CGSize
    public let preferredTransform: CGAffineTransform
    public let uprightSize: CGSize
    public let transformType: TransformType
    public let duration: TimeInterval
    
    // INTEGRATION: Computed properties for STS UI
    public var aspectRatio: CGFloat {
        return uprightSize.width / uprightSize.height
    }
    
    public var isPortraitVideo: Bool {
        return capturedOrientation == .portrait
    }
    
    public var debugDescription: String {
        return """
        Video Orientation Analysis:
        - Captured: \(capturedOrientation)
        - Natural Size: \(naturalSize)
        - Upright Size: \(uprightSize)
        - Transform: \(transformType)
        - Aspect Ratio: \(String(format: "%.2f", aspectRatio))
        - Duration: \(String(format: "%.1f", duration))s
        """
    }
}

// 🚨 SWIFT 6 SENDABILITY: Made TransformType enum Sendable
public enum TransformType: Sendable {
    case identity
    case rotate90Clockwise
    case rotate90CounterClockwise
    case rotate180
    case custom
    
    public var displayName: String {
        switch self {
        case .identity: return "No Rotation"
        case .rotate90Clockwise: return "90° Clockwise"
        case .rotate90CounterClockwise: return "90° Counter-Clockwise"
        case .rotate180: return "180° Rotation"
        case .custom: return "Custom Transform"
        }
    }
}

// 🚨 SWIFT 6 SENDABILITY: Made OrientationError Sendable for safe error handling
public enum OrientationError: LocalizedError, Sendable {
    case noVideoTrack
    case invalidTransform
    case compositionCreationFailed
    
    public var errorDescription: String? {
        switch self {
        case .noVideoTrack:
            return "No video track found in asset"
        case .invalidTransform:
            return "Invalid preferred transform"
        case .compositionCreationFailed:
            return "Failed to create composition"
        }
    }
}

// MARK: - Integration Extensions for Existing STS Types

extension ProjectTake {
    
    /// Analyze orientation for an existing take (migration helper)
    func analyzeOrientation() async throws -> VideoOrientationAnalysis {
        let url = URL(fileURLWithPath: filePath)
        let asset = AVURLAsset(url: url)
        return try await NormalizeOrientation.analyzeVideoOrientation(from: asset)
    }
}

extension VideoPlayerService {
    
    /// Setup player with orientation analysis for Smart Fill compatibility
    func setupPlayerWithOrientationAnalysis(url: URL, context: VideoContext) async {
        do {
            let asset = AVURLAsset(url: url)
            let analysis = try await NormalizeOrientation.analyzeVideoOrientation(from: asset)
            
            print("📐 VideoPlayerService: Orientation analysis completed")
            print("   \(analysis.debugDescription)")
            
            // Store analysis for potential Smart Fill preview
            // This would integrate with Smart Fill preview logic
            
            await MainActor.run {
                setupPlayer(with: url, context: context)
            }
            
        } catch {
            print("❌ VideoPlayerService: Orientation analysis failed: \(error)")
            // Fallback to standard setup
            await MainActor.run {
                setupPlayer(with: url, context: context)
            }
        }
    }
}
