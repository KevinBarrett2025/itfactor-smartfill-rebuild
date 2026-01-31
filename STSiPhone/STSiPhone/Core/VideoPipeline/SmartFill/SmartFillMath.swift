import CoreGraphics
import UIKit

// MARK: - Smart Fill Mathematical Operations
public enum SmartFillMath {
    
    // MARK: - Basic Scaling Operations
    public static func scaleToFill(src: CGSize, dst: CGSize) -> CGFloat {
        return max(dst.width / src.width, dst.height / src.height)
    }
    
    public static func scaleToFit(src: CGSize, dst: CGSize) -> CGFloat {
        return min(dst.width / src.width, dst.height / src.height)
    }
    
    public static func centerOffset(srcAfterScale: CGSize, dst: CGSize) -> CGPoint {
        return CGPoint(x: (dst.width - srcAfterScale.width) * 0.5,
                       y: (dst.height - srcAfterScale.height) * 0.5)
    }
    
    // MARK: - Advanced Layout Operations for STS Integration
    
    /// Calculate optimal render size for a session based on take orientations
    public static func calculateSessionRenderSize(
        takes: [ProjectTake],
        preferredOrientation: VideoOrientation = .landscape
    ) -> CGSize {
        
        // INTEGRATION: Default to 1920x1080 for landscape sessions
        let defaultLandscape = CGSize(width: 1920, height: 1080)
        let defaultPortrait = CGSize(width: 1080, height: 1920)
        
        switch preferredOrientation {
        case .landscape:
            return defaultLandscape
        case .portrait:
            return defaultPortrait
        }
    }
    
    /// Calculate layout parameters for Smart Fill effect
    public static func calculateSmartFillLayout(
        sourceSize: CGSize,
        renderSize: CGSize
    ) -> SmartFillLayout {
        
        let backgroundScale = scaleToFill(src: sourceSize, dst: renderSize)
        let foregroundScale = scaleToFit(src: sourceSize, dst: renderSize)
        
        let backgroundSize = CGSize(
            width: sourceSize.width * backgroundScale,
            height: sourceSize.height * backgroundScale
        )
        
        let foregroundSize = CGSize(
            width: sourceSize.width * foregroundScale,
            height: sourceSize.height * foregroundScale
        )
        
        let backgroundOffset = centerOffset(srcAfterScale: backgroundSize, dst: renderSize)
        let foregroundOffset = centerOffset(srcAfterScale: foregroundSize, dst: renderSize)
        
        return SmartFillLayout(
            backgroundScale: backgroundScale,
            foregroundScale: foregroundScale,
            backgroundSize: backgroundSize,
            foregroundSize: foregroundSize,
            backgroundOffset: backgroundOffset,
            foregroundOffset: foregroundOffset,
            renderSize: renderSize
        )
    }
    
    /// Optimize layout for different aspect ratios commonly seen in self-taping
    public static func optimizeForSelfTapeAspectRatio(
        layout: SmartFillLayout,
        sourceAspectRatio: CGFloat
    ) -> SmartFillLayout {
        
        var optimizedLayout = layout
        
        // INTEGRATION: Common self-tape aspect ratios
        let phonePortrait: CGFloat = 9.0 / 16.0  // iPhone portrait
        let phoneLandscape: CGFloat = 16.0 / 9.0 // iPhone landscape
        
        // Adjust scaling for extreme aspect ratios
        if abs(sourceAspectRatio - phonePortrait) < 0.1 {
            // Very tall portrait video - might want slightly more background scale
            optimizedLayout.backgroundScale *= 1.1
        } else if abs(sourceAspectRatio - phoneLandscape) < 0.1 {
            // Standard landscape - use as-is
        } else if sourceAspectRatio < 0.6 {
            // Extremely tall video - increase background presence
            optimizedLayout.backgroundScale *= 1.15
        }
        
        return optimizedLayout
    }
}

// MARK: - Smart Fill Layout Data Structure
public struct SmartFillLayout {
    public var backgroundScale: CGFloat
    public let foregroundScale: CGFloat
    public let backgroundSize: CGSize
    public let foregroundSize: CGSize
    public let backgroundOffset: CGPoint
    public let foregroundOffset: CGPoint
    public let renderSize: CGSize
    
    // INTEGRATION: FIXED - Safer transforms that avoid invalid extents
    public var backgroundTransform: CGAffineTransform {
        // FIXED: Use translation first, then scaling to avoid invalid extents
        let centerX = renderSize.width / 2
        let centerY = renderSize.height / 2
        
        return CGAffineTransform.identity
            .translatedBy(x: centerX, y: centerY)  // Move to center
            .scaledBy(x: backgroundScale, y: backgroundScale)  // Scale from center
            .translatedBy(x: -centerX, y: -centerY)  // Move back
    }
    
    public var foregroundTransform: CGAffineTransform {
        // FIXED: Simple centering transform that's guaranteed to be valid
        return CGAffineTransform.identity
            .translatedBy(x: foregroundOffset.x, y: foregroundOffset.y)
            .scaledBy(x: foregroundScale, y: foregroundScale)
    }
    
    // INTEGRATION: Debug description for development
    public var debugDescription: String {
        return """
        SmartFillLayout:
        - Render Size: \(renderSize)
        - Background: \(backgroundSize) at \(backgroundOffset) (scale: \(backgroundScale))
        - Foreground: \(foregroundSize) at \(foregroundOffset) (scale: \(foregroundScale))
        """
    }
}

// MARK: - Utilities for Video Processing
public extension SmartFillMath {
    
    /// Calculate safe margins for video processing to avoid edge artifacts
    static func calculateSafeMargins(for size: CGSize, marginPercentage: CGFloat = 0.02) -> UIEdgeInsets {
        let margin = min(size.width, size.height) * marginPercentage
        return UIEdgeInsets(top: margin, left: margin, bottom: margin, right: margin)
    }
    
    /// Validate render size constraints for STS requirements
    static func validateRenderSize(_ size: CGSize) -> Bool {
        // INTEGRATION: STS requirements
        let minSize: CGFloat = 480  // Minimum for quality
        let maxSize: CGFloat = 4096 // Maximum for performance
        
        return size.width >= minSize && size.height >= minSize &&
               size.width <= maxSize && size.height <= maxSize &&
               size.width.truncatingRemainder(dividingBy: 2) == 0 && // Even dimensions for video encoding
               size.height.truncatingRemainder(dividingBy: 2) == 0
    }
}
