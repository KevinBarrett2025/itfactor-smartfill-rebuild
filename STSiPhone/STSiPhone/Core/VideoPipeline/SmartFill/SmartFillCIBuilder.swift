import AVFoundation
import CoreImage

/// CRITICAL FIX 2025-10-22: SmartFill CI Builder with Infinite Extent Protection
/// FIXED: Properly handle infinite source images and validate before processing
public final class SmartFillCIBuilder {
    
    /// CRITICAL FIX 2025-10-22: Create unified CI video composition with infinite extent protection
    public static func makeComposition(
        asset: AVAsset,
        settings: SmartFillSettings,
        orientationAnalysis: VideoOrientationAnalysis? = nil
    ) async throws -> AVVideoComposition {
        
        print("🎯 SmartFillCIBuilder: Creating CI composition with infinite extent protection")
        
        // Load track properties for portrait detection
        let tracks = try await asset.load(.tracks)
        guard let vtrack = tracks.first(where: { $0.mediaType == .video }) else {
            throw SmartFillCIBuilderError.invalidVideoTrack
        }

        let naturalSize = try await vtrack.load(.naturalSize)
        let preferred   = try await vtrack.load(.preferredTransform)
        let renderSize  = settings.defaultRenderSize // 1920x1080 landscape

        print("🔍 SmartFillCIBuilder: Track analysis")
        print("   📐 Track natural: \(naturalSize), preferred: \(preferred)")
        print("   🎯 Render size: \(renderSize) (LANDSCAPE FORCED)")

        // Simple portrait detection (same as working preview)
        let displaySize = naturalSize.applying(preferred)
        let displayWidth = abs(displaySize.width)
        let displayHeight = abs(displaySize.height)
        let isPortrait = displayHeight > displayWidth
        
        print("🧠 SmartFillCIBuilder: Simple portrait detection")
        print("   📐 Display size after transform: \(displayWidth) x \(displayHeight)")
        print("   📱 Is Portrait: \(isPortrait)")

        // Add safe finite check helpers
        @inline(__always) @Sendable func isFinite(_ value: CGFloat) -> Bool {
            value.isFinite && !value.isNaN
        }
        @inline(__always) @Sendable func isSizeFinite(_ s: CGSize) -> Bool {
            isFinite(s.width) && isFinite(s.height) && s.width > 0 && s.height > 0
        }
        @inline(__always) @Sendable func isRectFinite(_ r: CGRect) -> Bool {
            isFinite(r.origin.x) && isFinite(r.origin.y) && isFinite(r.size.width) && isFinite(r.size.height) &&
            r.width > 0 && r.height > 0
        }
        
        // Precompute sizes
        _ = NormalizeOrientation.uprightSize(natural: naturalSize, preferred: preferred)
        let renderRect = CGRect(origin: .zero, size: renderSize)

        let filterHandler: @Sendable (AVAsynchronousCIImageFilteringRequest) -> Void = { request in
            @inline(__always) func blackFrame() -> CIImage { CIImage(color: .black).cropped(to: renderRect) }
            @inline(__always) func finishSafely(_ image: CIImage) { request.finish(with: image.cropped(to: renderRect), context: nil) }

            // Treat the source image as already oriented correctly by AVFoundation.
            let src = request.sourceImage

            // Ensure we have a finite, non-empty extent
            if !isRectFinite(src.extent) || src.extent.isEmpty {
                print("⚠️ SmartFillCIBuilder: sourceImage extent invalid, returning black frame")
                finishSafely(blackFrame())
                return
            }

            let srcExtent = src.extent
            print("🧪 SmartFillCIBuilder: srcExtent =", srcExtent, " renderRect =", renderRect)

            // FOREGROUND: aspect-fit into renderRect
            let fgScale = min(renderSize.width / srcExtent.width,
                              renderSize.height / srcExtent.height)
            let fgScaled = src.transformed(by: CGAffineTransform(scaleX: fgScale, y: fgScale))
            let fgRect = fgScaled.extent
            let fgDx = (renderSize.width  - fgRect.width)  * 0.5 - fgRect.minX
            let fgDy = (renderSize.height - fgRect.height) * 0.5 - fgRect.minY
            let fgCentered = fgScaled
                .transformed(by: CGAffineTransform(translationX: fgDx, y: fgDy))
                .cropped(to: renderRect)

            // BACKGROUND: aspect-fill + blur + darken
            let bgScale = max(renderSize.width / srcExtent.width,
                              renderSize.height / srcExtent.height) * settings.backgroundScale
            let bgScaled = src.transformed(by: CGAffineTransform(scaleX: bgScale, y: bgScale))
            let bgRect = bgScaled.extent
            let bgDx = (renderSize.width  - bgRect.width)  * 0.5 - bgRect.minX
            let bgDy = (renderSize.height - bgRect.height) * 0.5 - bgRect.minY
            let bgCentered = bgScaled.transformed(by: CGAffineTransform(translationX: bgDx, y: bgDy))

            let blurred = bgCentered
                .clampedToExtent()
                .applyingFilter("CIGaussianBlur", parameters: ["inputRadius": settings.defaultBlurRadius])
                .cropped(to: renderRect)
                .applyingFilter("CIColorControls", parameters: ["inputBrightness": -settings.defaultDarkenAmount])

            print("🎯 SmartFillCIBuilder: fgRect =", fgRect, " bgRect =", bgRect, " final =", renderRect)

            finishSafely(fgCentered.composited(over: blurred))
        }

        let comp: AVVideoComposition
        if #available(iOS 18.0, *) {
            comp = try await AVVideoComposition.videoComposition(with: asset, applyingCIFiltersWithHandler: filterHandler)
        } else {
            comp = AVVideoComposition(asset: asset, applyingCIFiltersWithHandler: filterHandler)
        }

        // Set composition properties
        let mutableComp = comp.mutableCopy() as! AVMutableVideoComposition
        mutableComp.renderSize = renderSize
        mutableComp.frameDuration = CMTime(value: 1, timescale: 30)
        
        print("✅ SmartFillCIBuilder: Created CI composition with infinite extent protection")
        
        return mutableComp
    }
}

// MARK: - Error Handling

public enum SmartFillCIBuilderError: LocalizedError {
    case invalidVideoTrack
    case filterCreationFailed(String)
    case filterProcessingFailed(String)
    
    public var errorDescription: String? {
        switch self {
        case .invalidVideoTrack:
            return "Invalid video track for SmartFill CI composition"
        case .filterCreationFailed(let filterName):
            return "Failed to create SmartFill CI filter: \(filterName)"
        case .filterProcessingFailed(let operation):
            return "SmartFill CI filter processing failed: \(operation)"
        }
    }
}
