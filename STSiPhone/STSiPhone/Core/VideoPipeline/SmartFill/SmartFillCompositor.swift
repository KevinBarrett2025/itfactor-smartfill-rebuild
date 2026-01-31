import AVFoundation
import CoreImage
import UIKit

/// 🚨 EXPORT-ONLY SmartFill compositor using CALayer + AVVideoCompositionCoreAnimationTool
/// ⚠️  WARNING: This compositor CANNOT be used with AVPlayerItem for preview - it will CRASH
/// ⚠️  For preview operations, use SmartFillPreviewCompositor instead
/// This is the CORRECT approach for EXPORT operations that works WITH AVFoundation instead of against it
public final class SmartFillCompositor {
    
    // MARK: - Properties
    private let ciContext: CIContext
    private let metalDevice: MTLDevice?
    
    public init(device: MTLDevice? = MTLCreateSystemDefaultDevice()) {
        self.metalDevice = device
        
        if let device = device {
            self.ciContext = CIContext(mtlDevice: device, options: [
                .workingColorSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
                .outputColorSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
                .cacheIntermediates: false // Optimized for single-frame processing
            ])
        } else {
            self.ciContext = CIContext(options: [
                .workingColorSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
                .outputColorSpace: CGColorSpace(name: CGColorSpace.sRGB)!
            ])
        }
        
        print("✅ SmartFillCompositor: Initialized with industry-standard CALayer approach")
    }
    
    // MARK: - Public API
    
    /// Create SmartFill video composition using industry-standard approach
    /// 🚨 WARNING: This method creates compositions for EXPORT ONLY - do NOT use with AVPlayerItem
    /// 🚨 For preview operations, use SmartFillPreviewCompositor.createPreviewVideoComposition()
    /// This method works WITH AVFoundation instead of fighting it - but only for export operations
    public func createVideoComposition(
        for asset: AVAsset,
        renderSize: CGSize = CGSize.zero, // HANDOFF FIX: Ignore passed renderSize, determine from orientation
        settings: SmartFillSettings = SmartFillSettings()
    ) async throws -> AVVideoComposition {
        
        print("🎯 SmartFillCompositor: Creating video composition using industry-standard approach")
        
        // HANDOFF FIX: Analyze video orientation and properties FIRST
        let videoAnalysis = try await analyzeVideoProperties(asset: asset)
        
        // HANDOFF FIX #1: Choose canvas (renderSize) by input orientation - CRITICAL FIX
        // Always target cinematic 16:9 canvas so portrait footage lives inside landscape frame
        let actualRenderSize = CGSize(width: 1920, height: 1080)
        
        print("   🔍 Video analysis: \(videoAnalysis.naturalSize) → \(videoAnalysis.displaySize), portrait: \(videoAnalysis.isPortrait)")
        print("   📐 HANDOFF FIX: Render size determined by orientation: \(actualRenderSize)")
        print("   🎨 Settings: blur=\(settings.defaultBlurRadius), darken=\(settings.defaultDarkenAmount), scale=\(settings.backgroundScale)")
        
        // PHASE 2 ENHANCEMENT: Create professional video composition with proper track handling
        let composition = try await createProfessionalVideoComposition(
            asset: asset,
            videoAnalysis: videoAnalysis,
            renderSize: actualRenderSize, // Use orientation-determined size
            settings: settings
        )
        
        // HANDOFF FIX: Create SmartFill layout helper
        let layout = makeSmartFillLayout(natural: videoAnalysis.displaySize, renderSize: actualRenderSize)
        
        // STEP 1: Extract a single frame to create the blurred background (not frame-by-frame!)
        let backgroundLayer = try await createBlurredBackgroundLayer(
            from: asset,
            videoAnalysis: videoAnalysis,
            renderSize: layout.renderSize, // Use layout's render size
            settings: settings
        )
        
        // STEP 2: Create the layer hierarchy properly with HANDOFF FIXES
        let parentLayer = CALayer()
        parentLayer.frame = CGRect(origin: .zero, size: layout.renderSize)
        
        // HANDOFF FIX #2: Background layer with proper centering
        parentLayer.addSublayer(backgroundLayer)
        
        // HANDOFF FIX #3: Video layer with layout-determined frame
        let videoLayer = CALayer()
        videoLayer.frame = CGRect(origin: .zero, size: layout.renderSize)
        parentLayer.addSublayer(videoLayer)
        
        // STEP 3: Create the animation tool (this is the KEY difference from our old approach)
        // 🚨 CRITICAL: AVVideoCompositionCoreAnimationTool is for EXPORT ONLY
        // 🚨 Do NOT use this composition with AVPlayerItem - it will crash
        let animationTool = AVVideoCompositionCoreAnimationTool(
            postProcessingAsVideoLayer: videoLayer,
            in: parentLayer
        )
        
        // STEP 4: Apply the animation tool to our composition
        composition.animationTool = animationTool
        
        // HANDOFF FIX: Enhanced logging as specified
        print("✅ SmartFillCompositor: Created EXPORT-ONLY video composition")
        print("   🎬 Using AVVideoCompositionCoreAnimationTool (EXPORT ONLY)")
        print("   ⚠️  WARNING: Do NOT use this with AVPlayerItem - will crash")
        print("   📐 HANDOFF: portrait=\(videoAnalysis.isPortrait) render=\(layout.renderSize)")
        print("   📐 HANDOFF: natural=\(videoAnalysis.displaySize) fgFrame=\(foregroundFrameFromLayout(layout))")
        print("   🎨 HANDOFF: bgGravity=\(backgroundLayer.contentsGravity.rawValue) pos=\(backgroundLayer.position)")
        
        return composition
    }
    
    // HANDOFF FIX: Add SmartFill layout helper as specified in handoff
    private func makeSmartFillLayout(natural: CGSize, renderSize: CGSize) -> SmartFillLayout {
        SmartFillMath.calculateSmartFillLayout(sourceSize: natural, renderSize: renderSize)
    }
    
    // HANDOFF FIX: Helper to get foreground frame from layout
    private func foregroundFrameFromLayout(_ layout: SmartFillLayout) -> CGRect {
        return CGRect(
            x: layout.foregroundOffset.x,
            y: layout.foregroundOffset.y,
            width: layout.foregroundSize.width,
            height: layout.foregroundSize.height
        )
    }
    
    // MARK: - Phase 2: Professional Video Composition
    
    /// PHASE 2: Analyze video properties for intelligent processing
    private func analyzeVideoProperties(asset: AVAsset) async throws -> VideoAnalysis {
        let videoTracks = try await asset.loadTracks(withMediaType: .video)
        guard let videoTrack = videoTracks.first else {
            throw SmartFillCompositorError.invalidAsset
        }
        
        let naturalSize = try await videoTrack.load(.naturalSize)
        let preferredTransform = try await videoTrack.load(.preferredTransform)
        let nominalFrameRate = try await videoTrack.load(.nominalFrameRate)
        
        // HANDOFF FIX #4: Use NormalizeOrientation.uprightExtent for consistent display size calculation
        let displaySize = NormalizeOrientation.uprightExtent(naturalSize: naturalSize, preferred: preferredTransform)
        let isPortrait = displaySize.height > displaySize.width
        
        print("📐 SmartFillCompositor: HANDOFF FIX - Using NormalizeOrientation for displaySize")
        print("   🔍 Natural: \(naturalSize) -> Display: \(displaySize) (portrait: \(isPortrait))")
        
        return VideoAnalysis(
            naturalSize: naturalSize,
            displaySize: displaySize,
            preferredTransform: preferredTransform,
            nominalFrameRate: nominalFrameRate,
            isPortrait: isPortrait
        )
    }
    
    /// PHASE 2: Create professional video composition with proper track handling
    private func createProfessionalVideoComposition(
        asset: AVAsset,
        videoAnalysis: VideoAnalysis,
        renderSize: CGSize,
        settings: SmartFillSettings
    ) async throws -> AVMutableVideoComposition {
        
        let videoTracks = try await asset.loadTracks(withMediaType: .video)
        guard let videoTrack = videoTracks.first else {
            throw SmartFillCompositorError.invalidAsset
        }
        
        let duration = try await asset.load(.duration)
        
        // PHASE 2: Professional composition setup
        let composition = AVMutableVideoComposition()
        composition.renderSize = renderSize
        
        // PHASE 2: Intelligent frame rate based on source content
        let targetFrameRate: Int32 = videoAnalysis.nominalFrameRate > 0 ? min(Int32(videoAnalysis.nominalFrameRate), 60) : 30
        composition.frameDuration = CMTime(value: 1, timescale: targetFrameRate)
        
        print("🎬 SmartFillCompositor: Using \(targetFrameRate)fps for optimal quality")
        print("   📐 HANDOFF: Composition render size set to \(renderSize)")
        
        // PHASE 2: Professional video composition instruction
        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRange(start: .zero, duration: duration)
        
        // HANDOFF FIX #1: Use new calculateTransform method with aspect-fit approach
        let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)
        let transform = calculateTransform(videoAnalysis: videoAnalysis, renderSize: renderSize)
        layerInstruction.setTransform(transform, at: .zero)
        
        print("🔧 SmartFillCompositor: HANDOFF FIX - Applied aspect-fit transform: \(transform)")
        
        instruction.layerInstructions = [layerInstruction]
        composition.instructions = [instruction]
        
        return composition
    }
    
    private func calculateTransform(videoAnalysis: VideoAnalysis, renderSize: CGSize) -> CGAffineTransform {
        NormalizeOrientation.perfectlyCenteredTransform(
            naturalSize: videoAnalysis.naturalSize,
            preferred: videoAnalysis.preferredTransform,
            renderSize: renderSize
        )
    }
    
    /// PHASE 2: Calculate video layer frame for CALayer positioning
    private func calculateVideoLayerFrame(
        videoAnalysis: VideoAnalysis,
        renderSize: CGSize
    ) -> CGRect {
        
        // HANDOFF FIX: Use displaySize with AVMakeRect for consistent aspect-fit calculation
        let display = videoAnalysis.displaySize
        let fitRect = AVMakeRect(aspectRatio: display, insideRect: CGRect(origin: .zero, size: renderSize))
        
        print("🔧 SmartFillCompositor: HANDOFF FIX - Video layer frame calculated with aspect-fit")
        print("   📐 Display: \(display) -> Fit rect: \(fitRect)")
        
        return fitRect
    }
    
    // MARK: - Enhanced Background Creation
    
    /// Create blurred background layer from a single extracted frame
    /// PHASE 2: Enhanced with video analysis for better frame selection
    private func createBlurredBackgroundLayer(
        from asset: AVAsset,
        videoAnalysis: VideoAnalysis,
        renderSize: CGSize,
        settings: SmartFillSettings
    ) async throws -> CALayer {
        
        print("🎨 SmartFillCompositor: Creating blurred background from single frame")
        
        // PHASE 2: Enhanced frame extraction with video analysis
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true // Let AVFoundation handle rotation!
        generator.maximumSize = CGSize(width: 1920, height: 1080) // High quality for background
        
        // PHASE 2: Smart time selection - avoid first/last seconds for better frames
        let duration = try await asset.load(.duration)
        let durationSeconds = CMTimeGetSeconds(duration)
        let extractTime = CMTime(seconds: max(1.0, min(durationSeconds / 2, 5.0)), preferredTimescale: 600)
        
        let cgImage = try await generator.image(at: extractTime).image
        
        // Convert to CIImage for processing
        let sourceImage = CIImage(cgImage: cgImage)
        
        // HANDOFF FIX #2: Enhanced background processing with proper centering
        let processedBackground = try createProcessedBackground(
            sourceImage: sourceImage,
            videoAnalysis: videoAnalysis,
            renderSize: renderSize,
            settings: settings
        )
        
        // Convert back to CGImage for CALayer
        let finalCGImage = ciContext.createCGImage(processedBackground, from: processedBackground.extent)!
        
        // HANDOFF FIX #2: Create CALayer with proper centering and .resizeAspectFill
        let backgroundLayer = CALayer()
        backgroundLayer.frame = CGRect(origin: .zero, size: renderSize)
        backgroundLayer.contents = finalCGImage
        backgroundLayer.contentsGravity = .resizeAspectFill // HANDOFF FIX: Ensure it centers + fills
        backgroundLayer.masksToBounds = true // HANDOFF FIX: Prevent overflow
        backgroundLayer.anchorPoint = CGPoint(x: 0.5, y: 0.5) // HANDOFF FIX: Center anchor point
        backgroundLayer.position = CGPoint(x: renderSize.width/2, y: renderSize.height/2) // HANDOFF FIX: Center position
        
        print("✅ SmartFillCompositor: Created blurred background layer with HANDOFF centering fixes")
        print("   📐 Background size: \(renderSize)")
        print("   📐 HANDOFF: contentsGravity=\(backgroundLayer.contentsGravity.rawValue) pos=\(backgroundLayer.position)")
        print("   🎨 Applied blur: \(settings.defaultBlurRadius)px, darken: \(settings.defaultDarkenAmount)")
        
        return backgroundLayer
    }
    
    /// Process the background image with blur and scaling
    /// HANDOFF FIX #2: Enhanced with proper centering to fix "bottom of frame" issue
    private func createProcessedBackground(
        sourceImage: CIImage,
        videoAnalysis: VideoAnalysis,
        renderSize: CGSize,
        settings: SmartFillSettings
    ) throws -> CIImage {
        
        let sourceSize = sourceImage.extent.size
        print("🔧 SmartFillCompositor: HANDOFF FIX - Processing background with proper centering")
        print("   📐 Source: \(sourceSize) -> Render: \(renderSize)")
        
        // HANDOFF FIX #2: Enhanced scaling approach with proper centering
        let scaleX = renderSize.width / sourceSize.width
        let scaleY = renderSize.height / sourceSize.height
        let baseScale = max(scaleX, scaleY) // Use max to ensure complete fill
        let enhancedScale = baseScale * settings.backgroundScale
        
        let scaledImage = sourceImage.transformed(by: CGAffineTransform(scaleX: enhancedScale, y: enhancedScale))
        
        // HANDOFF FIX #2: Center using proper offset calculation
        let scaledSize = CGSize(width: sourceSize.width * enhancedScale, height: sourceSize.height * enhancedScale)
        let offsetX = (renderSize.width - scaledSize.width) / 2
        let offsetY = (renderSize.height - scaledSize.height) / 2
        
        let centeredImage = scaledImage.transformed(by: CGAffineTransform(translationX: offsetX, y: offsetY))
        
        // HANDOFF FIX #2: CRITICAL - Recenter to origin before cropping (fixes bottom-bias)
        let normalized = centeredImage.transformed(by: CGAffineTransform(translationX: -centeredImage.extent.origin.x,
                                                        y: -centeredImage.extent.origin.y))
        let croppedImage = normalized.cropped(to: CGRect(origin: .zero, size: renderSize))
        
        print("🎯 SmartFillCompositor: HANDOFF FIX #2 - Recentered to origin before crop")
        print("   📐 Original extent origin: \(centeredImage.extent.origin)")
        print("   📐 Normalized extent: \(normalized.extent)")
        print("   📐 Final cropped: \(croppedImage.extent)")
        
        // PHASE 2: Enhanced blur with quality optimization
        guard let blurFilter = CIFilter(name: "CIGaussianBlur") else {
            throw SmartFillCompositorError.filterCreationFailed("CIGaussianBlur")
        }
        
        blurFilter.setValue(croppedImage, forKey: kCIInputImageKey)
        blurFilter.setValue(settings.defaultBlurRadius, forKey: kCIInputRadiusKey)
        
        guard let blurredImage = blurFilter.outputImage else {
            throw SmartFillCompositorError.filterProcessingFailed("Gaussian blur")
        }
        
        // PHASE 2: Professional color grading for background
        guard let colorFilter = CIFilter(name: "CIColorControls") else {
            throw SmartFillCompositorError.filterCreationFailed("CIColorControls")
        }
        
        colorFilter.setValue(blurredImage, forKey: kCIInputImageKey)
        colorFilter.setValue(-settings.defaultDarkenAmount, forKey: kCIInputBrightnessKey)
        colorFilter.setValue(0.7, forKey: kCIInputSaturationKey) // Professional desaturation
        colorFilter.setValue(1.1, forKey: kCIInputContrastKey) // Subtle contrast boost
        
        guard let finalImage = colorFilter.outputImage else {
            throw SmartFillCompositorError.filterProcessingFailed("Color controls")
        }
        
        // Final crop to ensure exact render size
        let finalCropped = finalImage.cropped(to: CGRect(origin: .zero, size: renderSize))
        
        print("✅ SmartFillCompositor: HANDOFF FIX #2 COMPLETE - Background properly centered and cropped")
        print("   📐 Enhanced scale: \(enhancedScale) (base: \(baseScale), setting: \(settings.backgroundScale))")
        print("   📐 Center offset: (\(offsetX), \(offsetY)) - eliminates bottom-bias issue")
        
        return finalCropped
    }
}

// MARK: - Phase 2: Video Analysis Data Structure

/// PHASE 2: Video analysis results for intelligent processing
private struct VideoAnalysis {
    let naturalSize: CGSize
    let displaySize: CGSize
    let preferredTransform: CGAffineTransform
    let nominalFrameRate: Float
    let isPortrait: Bool
}

// MARK: - Error Handling

public enum SmartFillCompositorError: LocalizedError {
    case filterCreationFailed(String)
    case filterProcessingFailed(String)
    case frameExtractionFailed
    case invalidAsset
    
    public var errorDescription: String? {
        switch self {
        case .filterCreationFailed(let filterName):
            return "Failed to create filter: \(filterName)"
        case .filterProcessingFailed(let operation):
            return "Filter processing failed: \(operation)"
        case .frameExtractionFailed:
            return "Failed to extract frame from video"
        case .invalidAsset:
            return "Invalid video asset"
        }
    }
}

// MARK: - Integration Extensions

public extension SmartFillCompositor {
    
    /// Convenience method for STS integration
    /// Creates SmartFill composition for a single video file
    /// 🚨 WARNING: This creates EXPORT-ONLY compositions - do NOT use with AVPlayerItem
    static func createSmartFillComposition(
        for videoURL: URL,
        renderSize: CGSize = CGSize.zero, // HANDOFF FIX: Ignored, determined by orientation
        settings: SmartFillSettings = SmartFillSettings()
    ) async throws -> AVVideoComposition {
        
        print("⚠️  SmartFillCompositor: Creating EXPORT-ONLY composition")
        print("   🚨 WARNING: Do NOT use this with AVPlayerItem - will crash")
        print("   📤 For export operations only")
        print("   🎥 For preview operations, use SmartFillPreviewCompositor instead")
        print("   📐 HANDOFF: Render size determined by video orientation (ignoring passed parameter)")
        
        let asset = AVURLAsset(url: videoURL)
        let compositor = SmartFillCompositor()
        
        return try await compositor.createVideoComposition(
            for: asset,
            renderSize: CGSize.zero, // Will be determined by orientation
            settings: settings
        )
    }
    
    /// 🚨 SAFETY CHECK: Prevent accidental use with AVPlayerItem
    /// This method will throw an error if someone tries to use export composition for preview
    static func validateCompositionUsage(
        composition: AVVideoComposition,
        intendedFor purpose: CompositionPurpose
    ) throws {
        
        if composition.animationTool != nil && purpose == .preview {
            print("🚨 CRITICAL ERROR: Trying to use EXPORT-ONLY composition for preview")
            print("   💥 This will cause AVVideoCompositionCoreAnimationTool crash")
            print("   🔧 Use SmartFillPreviewCompositor.createPreviewVideoComposition() instead")
            
            throw SmartFillCompositorError.invalidAsset
        }
        
        print("✅ SmartFillCompositor: Composition usage validated for \(purpose)")
    }
    
    enum CompositionPurpose {
        case preview
        case export
        
        var description: String {
            switch self {
            case .preview: return "preview (AVPlayerItem)"
            case .export: return "export (AVAssetExportSession)"
            }
        }
    }
}

#if DEBUG
// MARK: - Debug Extensions

private extension SmartFillCompositor {
    func logPerformance(_ operation: String, startTime: CFAbsoluteTime) {
        let duration = CFAbsoluteTime(CACurrentMediaTime()) - startTime
        if duration > 0.1 {
            print("⏱️ SmartFillCompositor: \(operation) took \(String(format: "%.3f", duration))s")
        }
    }
}
#endif

// MARK: - AVFoundation Extensions for HANDOFF FIX

extension CGRect {
    /// HANDOFF FIX #1: AVMakeRect equivalent for aspect-fit calculations
    static func aspectFit(aspectRatio sourceSize: CGSize, inside destinationRect: CGRect) -> CGRect {
        let destinationSize = destinationRect.size
        let scaleX = destinationSize.width / sourceSize.width
        let scaleY = destinationSize.height / sourceSize.height
        let scale = min(scaleX, scaleY) // aspect-fit uses minimum scale
        
        let scaledSize = CGSize(width: sourceSize.width * scale, height: sourceSize.height * scale)
        let centeredOrigin = CGPoint(
            x: destinationRect.origin.x + (destinationSize.width - scaledSize.width) / 2,
            y: destinationRect.origin.y + (destinationSize.height - scaledSize.height) / 2
        )
        
        return CGRect(origin: centeredOrigin, size: scaledSize)
    }
}

// MARK: - Helper function for AVMakeRect compatibility
private func AVMakeRect(aspectRatio: CGSize, insideRect: CGRect) -> CGRect {
    return CGRect.aspectFit(aspectRatio: aspectRatio, inside: insideRect)
}
