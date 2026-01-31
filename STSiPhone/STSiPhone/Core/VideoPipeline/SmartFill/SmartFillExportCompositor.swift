import AVFoundation
import CoreImage
import UIKit

/// 🚨 EXPORT-OPTIMIZED SmartFill compositor using frame-by-frame CIFilter processing
/// This compositor uses custom video compositor class optimized for AVAssetExportSession
/// Unlike CALayer approach, this processes each frame individually with blur effects
/// 🎯 ARCHITECTURE: Frame-by-frame processing instead of static background layers
public final class SmartFillExportCompositor {
    
    // MARK: - Properties
    private let ciContext: CIContext
    private let metalDevice: MTLDevice?
    
    public init(device: MTLDevice? = MTLCreateSystemDefaultDevice()) {
        self.metalDevice = device
        
        if let device = device {
            self.ciContext = CIContext(mtlDevice: device, options: [
                .workingColorSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
                .outputColorSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
                .cacheIntermediates: false
            ])
        } else {
            self.ciContext = CIContext(options: [
                .workingColorSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
                .outputColorSpace: CGColorSpace(name: CGColorSpace.sRGB)!
            ])
        }
        
        print("✅ SmartFillExportCompositor: Initialized with frame-by-frame CIFilter approach")
        print("   🎯 Optimized for AVAssetExportSession export operations")
        print("   🚫 No CALayer dependencies - reliable export rendering")
    }
    
    // MARK: - Public API
    
    /// Create export-optimized video composition using frame-by-frame processing
    /// This approach processes each frame individually instead of using static CALayer background
    public func createExportVideoComposition(
        for asset: AVAsset,
        renderSize: CGSize = CGSize.zero,
        settings: SmartFillSettings = SmartFillSettings()
    ) async throws -> AVVideoComposition {
        
        print("🚀 SmartFillExportCompositor: Creating frame-by-frame export composition")
        
        // 🚨 SETTINGS DEBUG: Log all incoming settings to verify they're correct
        print("🔍 SmartFillExportCompositor: SETTINGS DEBUG")
        print("   📐 backgroundScale: \(settings.backgroundScale)")
        print("   🌀 defaultBlurRadius: \(settings.defaultBlurRadius)")
        print("   🌙 defaultDarkenAmount: \(settings.defaultDarkenAmount)")
        print("   📺 defaultRenderSize: \(settings.defaultRenderSize)")
        print("   ✅ defaultEnabled: \(settings.defaultEnabled)")
        
        // Analyze video properties
        let videoAnalysis = try await analyzeVideoProperties(asset: asset)
        
        // 🚨 FIX #1: Use passed renderSize parameter instead of auto-determining by orientation
        // This matches how SmartFillPreviewCompositor receives renderSize from caller
        let actualRenderSize = renderSize.width > 0 ? renderSize : CGSize(width: 1920, height: 1080)
        
        print("   🔍 Video analysis: \(videoAnalysis.naturalSize) → \(videoAnalysis.displaySize), portrait: \(videoAnalysis.isPortrait)")
        print("   📐 FIXED: Using passed render size: \(actualRenderSize)")
        print("   🎨 Settings: blur=\(settings.defaultBlurRadius), darken=\(settings.defaultDarkenAmount), scale=\(settings.backgroundScale)")
        
        // Create video composition with custom compositor
        let composition = try await createFrameBasedVideoComposition(
            asset: asset,
            videoAnalysis: videoAnalysis,
            renderSize: actualRenderSize, // Use passed size, not orientation-determined
            settings: settings
        )
        
        print("✅ SmartFillExportCompositor: Created export composition with frame-by-frame processing")
        print("   🎬 Uses custom video compositor class for reliable export")
        print("   🔧 Each frame processed individually with blur background")
        print("   📱 Compatible with AVAssetExportSession")
        
        return composition
    }
    
    // MARK: - Video Analysis
    
    private func analyzeVideoProperties(asset: AVAsset) async throws -> VideoAnalysis {
        let videoTracks = try await asset.loadTracks(withMediaType: .video)
        guard let videoTrack = videoTracks.first else {
            throw SmartFillExportCompositorError.invalidAsset
        }
        
        let naturalSize = try await videoTrack.load(.naturalSize)
        let preferredTransform = try await videoTrack.load(.preferredTransform)
        let nominalFrameRate = try await videoTrack.load(.nominalFrameRate)
        
        // 🚨 FIX #2: Use naturalSize.applying(preferredTransform) approach to MATCH preview compositor
        // This ensures identical displaySize calculation as SmartFillPreviewCompositor
        let displaySize = naturalSize.applying(preferredTransform)
        let displayWidth = abs(displaySize.width)
        let displayHeight = abs(displaySize.height)
        
        let isPortrait = displayHeight > displayWidth
        
        print("🔧 SmartFillExportCompositor: FIXED video analysis to match preview compositor")
        print("   📐 Natural: \(naturalSize) -> Display: \(CGSize(width: displayWidth, height: displayHeight))")
        
        return VideoAnalysis(
            naturalSize: naturalSize,
            displaySize: CGSize(width: displayWidth, height: displayHeight),
            preferredTransform: preferredTransform,
            nominalFrameRate: nominalFrameRate,
            isPortrait: isPortrait
        )
    }
    
    // MARK: - Frame-Based Video Composition
    
    private func createFrameBasedVideoComposition(
        asset: AVAsset,
        videoAnalysis: VideoAnalysis,
        renderSize: CGSize,
        settings: SmartFillSettings
    ) async throws -> AVMutableVideoComposition {
        
        let videoTracks = try await asset.loadTracks(withMediaType: .video)
        guard let videoTrack = videoTracks.first else {
            throw SmartFillExportCompositorError.invalidAsset
        }
        
        let duration = try await asset.load(.duration)
        
        // Create composition with custom compositor
        let composition = AVMutableVideoComposition()
        composition.renderSize = renderSize
        
        // Set frame rate
        let targetFrameRate: Int32 = videoAnalysis.nominalFrameRate > 0 ? min(Int32(videoAnalysis.nominalFrameRate), 60) : 30
        composition.frameDuration = CMTime(value: 1, timescale: targetFrameRate)
        
        // 🎯 KEY: Use custom compositor class for frame-by-frame processing
        composition.customVideoCompositorClass = SmartFillExportCustomCompositor.self
        
        print("🎬 SmartFillExportCompositor: Using \(targetFrameRate)fps with custom compositor")
        
        // Create instruction with SmartFill parameters
        let instruction = SmartFillExportInstruction()
        instruction.timeRange = CMTimeRange(start: .zero, duration: duration)
        instruction.renderSize = renderSize
        instruction.settings = settings
        instruction.videoAnalysis = videoAnalysis
        
        // Create layer instruction for the video track
        let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)
        layerInstruction.setTransform(.identity, at: .zero)

        instruction.layerInstructions = [layerInstruction]
        instruction.videoTrackID = videoTrack.trackID
        
        composition.instructions = [instruction]
        
        return composition
    }
    
    // MARK: - Transform Calculations
    
    private func calculateVideoTransform(
        videoAnalysis: VideoAnalysis,
        renderSize: CGSize
    ) -> CGAffineTransform {
        
        let display = videoAnalysis.displaySize
        let fitRect = AVMakeRect(aspectRatio: display, insideRect: CGRect(origin: .zero, size: renderSize))
        let scale = fitRect.width / display.width

        var t = videoAnalysis.preferredTransform
        t = t.scaledBy(x: scale, y: scale)
        let tx = fitRect.origin.x / scale
        let ty = fitRect.origin.y / scale
        t = t.translatedBy(x: tx, y: ty)

        print("📐 SmartFillExportCompositor: DETAILED transform debugging (compare with preview):")
        print("   🎯 Display size: \(display)")
        print("   🎯 Render size: \(renderSize)")
        print("   🎯 Fit rect: \(fitRect)")
        print("   🎯 Scale: \(scale)")
        print("   🎯 Translation: (\(tx), \(ty))")
        print("   🎯 PreferredTransform: \(videoAnalysis.preferredTransform)")
        print("   🎯 Final transform: \(t)")

        return t
    }
}

// MARK: - Custom Video Compositor for Export

/// Custom video compositor that processes each frame with SmartFill blur background
/// This approach is reliable for AVAssetExportSession unlike CALayer approach
private final class SmartFillExportCustomCompositor: NSObject, AVVideoCompositing, @unchecked Sendable {
    
    fileprivate typealias Attrs = [String: any Sendable]
    
    private static let kSourceAttrs: Attrs = [
        kCVPixelBufferPixelFormatTypeKey as String: [
            Int(kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange),
            Int(kCVPixelFormatType_32BGRA)
        ] as [Int]
    ]
    
    private static let kRequiredAttrs: Attrs = [
        kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
    ]
    
    nonisolated var sourcePixelBufferAttributes: Attrs? { Self.kSourceAttrs }
    nonisolated var requiredPixelBufferAttributesForRenderContext: Attrs { Self.kRequiredAttrs }
    
    private let renderQueue = DispatchQueue(label: "SmartFillExportRenderQueue", qos: .userInteractive)
    private let ciContext = CIContext(options: [
        .workingColorSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
        .outputColorSpace: CGColorSpace(name: CGColorSpace.sRGB)!
    ])
    
    func renderContextChanged(_ newRenderContext: AVVideoCompositionRenderContext) {
        // No-op
    }
    
    func startRequest(_ asyncVideoCompositionRequest: AVAsynchronousVideoCompositionRequest) {
        renderQueue.async { [weak self] in
            self?.processExportRequest(asyncVideoCompositionRequest)
        }
    }
    
    private func processExportRequest(_ request: AVAsynchronousVideoCompositionRequest) {
        guard let instruction = request.videoCompositionInstruction as? SmartFillExportInstruction else {
            request.finish(with: NSError(domain: "SmartFillExportCompositor", code: -1))
            return
        }
        
        guard let sourceBuffer = request.sourceFrame(byTrackID: instruction.videoTrackID) else {
            request.finish(with: NSError(domain: "SmartFillExportCompositor", code: -2))
            return
        }
        
        guard let outputBuffer = request.renderContext.newPixelBuffer() else {
            request.finish(with: NSError(domain: "SmartFillExportCompositor", code: -2))
            return
        }
        
        do {
            let sourceImage = CIImage(cvPixelBuffer: sourceBuffer)
            let composed = try renderSmartFillFrame(
                sourceImage: sourceImage,
                instruction: instruction
            )
            ciContext.render(composed, to: outputBuffer)
            request.finish(withComposedVideoFrame: outputBuffer)
        } catch {
            request.finish(with: error)
        }
    }
    
    private func renderSmartFillFrame(
        sourceImage inputImage: CIImage,
        instruction: SmartFillExportInstruction
    ) throws -> CIImage {
        // Normalize incoming frame so operations start from origin
        let sourceExtent = inputImage.extent
        let normalizedSource = inputImage.transformed(by: CGAffineTransform(
            translationX: -sourceExtent.origin.x,
            y: -sourceExtent.origin.y
        ))

        // Apply the track's preferred transform to orient the frame upright.
        let oriented = normalizedSource.transformed(by: instruction.videoAnalysis.preferredTransform)
        let orientedExtent = oriented.extent
        let orientedNormalized = oriented.transformed(by: CGAffineTransform(
            translationX: -orientedExtent.origin.x,
            y: -orientedExtent.origin.y
        ))
        
        let renderSize = instruction.renderSize
        let renderRect = CGRect(origin: .zero, size: renderSize)
        
        let foreground = makeForegroundImage(from: orientedNormalized, renderSize: renderSize)
        let background = try makeBackgroundImage(from: orientedNormalized, renderSize: renderSize, settings: instruction.settings)
        
        let composite = foreground.composited(over: background).cropped(to: renderRect)
        print("🎯 SmartFillExportCompositor: Frame composed (extent: \(composite.extent))")
        return composite
    }
    
    private func makeForegroundImage(from image: CIImage, renderSize: CGSize) -> CIImage {
        let sourceSize = image.extent.size
        let scale = min(renderSize.width / sourceSize.width, renderSize.height / sourceSize.height)
        let scaled = image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let rect = scaled.extent
        let offsetX = (renderSize.width  - rect.width)  * 0.5 - rect.minX
        let offsetY = (renderSize.height - rect.height) * 0.5 - rect.minY
        let translated = scaled.transformed(by: CGAffineTransform(translationX: offsetX, y: offsetY))
        print("   🎬 Foreground fit scale=\(scale), offset=(\(offsetX), \(offsetY))")
        return translated
    }
    
    private func makeBackgroundImage(
        from image: CIImage,
        renderSize: CGSize,
        settings: SmartFillSettings
    ) throws -> CIImage {
        guard let blurFilter = CIFilter(name: "CIGaussianBlur") else {
            throw SmartFillExportCompositorError.filterCreationFailed("CIGaussianBlur")
        }
        blurFilter.setValue(image.clampedToExtent(), forKey: kCIInputImageKey)
        blurFilter.setValue(settings.defaultBlurRadius, forKey: kCIInputRadiusKey)
        
        guard let blurred = blurFilter.outputImage else {
            throw SmartFillExportCompositorError.filterProcessingFailed("Gaussian blur")
        }
        
        let sourceSize = image.extent.size
        let baseScale = max(renderSize.width / sourceSize.width, renderSize.height / sourceSize.height)
        let configuredScale = max(settings.backgroundScale, 1.0)
        // Prevent runaway GPU cost – extreme background scaling offers minimal visual benefit
        let finalScale = min(baseScale * configuredScale, baseScale * 4.0)
        let scaled = blurred.transformed(by: CGAffineTransform(scaleX: finalScale, y: finalScale))
        let offsetX = (renderSize.width - scaled.extent.size.width) / 2
        let offsetY = (renderSize.height - scaled.extent.size.height) / 2
        let centered = scaled.transformed(by: CGAffineTransform(translationX: offsetX, y: offsetY))
        
        guard let colorFilter = CIFilter(name: "CIColorControls") else {
            throw SmartFillExportCompositorError.filterCreationFailed("CIColorControls")
        }
        colorFilter.setValue(centered, forKey: kCIInputImageKey)
        colorFilter.setValue(-settings.defaultDarkenAmount, forKey: kCIInputBrightnessKey)
        
        guard let darkened = colorFilter.outputImage else {
            throw SmartFillExportCompositorError.filterProcessingFailed("Color controls")
        }
        
        print("   🎨 Background scale base=\(baseScale), requested=\(configuredScale), applied=\(finalScale/baseScale), offset=(\(offsetX), \(offsetY))")
        return darkened.cropped(to: CGRect(origin: .zero, size: renderSize))
    }
}
// MARK: - Custom Instruction

private class SmartFillExportInstruction: NSObject, AVVideoCompositionInstructionProtocol {
    var timeRange: CMTimeRange = .zero
    var enablePostProcessing: Bool = false
    var containsTweening: Bool = false
    var requiredSourceTrackIDs: [NSValue]?
    var passthroughTrackID: CMPersistentTrackID = kCMPersistentTrackID_Invalid
    var layerInstructions: [AVVideoCompositionLayerInstruction] = []
    
    // Custom properties for SmartFill export
    var renderSize: CGSize = .zero
    var settings: SmartFillSettings = SmartFillSettings()
    var videoAnalysis: VideoAnalysis = VideoAnalysis(
        naturalSize: .zero,
        displaySize: .zero,
        preferredTransform: .identity,
        nominalFrameRate: 30,
        isPortrait: false
    )
    var videoTrackID: CMPersistentTrackID = kCMPersistentTrackID_Invalid
    
    override init() {
        super.init()
    }
}

// MARK: - Supporting Types

private struct VideoAnalysis {
    let naturalSize: CGSize
    let displaySize: CGSize
    let preferredTransform: CGAffineTransform
    let nominalFrameRate: Float
    let isPortrait: Bool
}

// MARK: - Error Handling

public enum SmartFillExportCompositorError: LocalizedError {
    case invalidAsset
    case filterCreationFailed(String)
    case filterProcessingFailed(String)
    
    public var errorDescription: String? {
        switch self {
        case .invalidAsset:
            return "Invalid video asset for export"
        case .filterCreationFailed(let filterName):
            return "Failed to create export filter: \(filterName)"
        case .filterProcessingFailed(let operation):
            return "Export filter processing failed: \(operation)"
        }
    }
}

// MARK: - Helper function for AVMakeRect compatibility
private func AVMakeRect(aspectRatio: CGSize, insideRect: CGRect) -> CGRect {
    let destinationSize = insideRect.size
    let scaleX = destinationSize.width / aspectRatio.width
    let scaleY = destinationSize.height / aspectRatio.height
    let scale = min(scaleX, scaleY)
    
    let scaledSize = CGSize(width: aspectRatio.width * scale, height: aspectRatio.height * scale)
    let centeredOrigin = CGPoint(
        x: insideRect.origin.x + (destinationSize.width - scaledSize.width) / 2,
        y: insideRect.origin.y + (destinationSize.height - scaledSize.height) / 2
    )
    
    return CGRect(origin: centeredOrigin, size: scaledSize)
}
