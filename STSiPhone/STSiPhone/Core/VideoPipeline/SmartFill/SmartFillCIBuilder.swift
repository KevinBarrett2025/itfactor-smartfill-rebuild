import AVFoundation
import CoreImage
import UIKit

/// CRITICAL FIX 2025-10-22: SmartFill CI Builder with Infinite Extent Protection
/// FIXED: Properly handle infinite source images and validate before processing
public final class SmartFillCIBuilder {
    private struct PreparedBackgroundImage: @unchecked Sendable {
        let image: CIImage
    }
    
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
        let preparedBackgroundImage = loadPreparedBackgroundImage(
            mode: settings.backgroundSourceMode,
            assetPath: settings.backgroundAssetPath
        )

        if settings.backgroundSourceMode == .customVideo {
            print("⚠️ SmartFillCIBuilder: Motion background selection is not wired yet, falling back to source-derived background")
        }

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

            let backgroundBaseImage = preparedBackgroundImage?.image ?? src
            let background = makePreparedBackgroundImage(
                from: backgroundBaseImage,
                fallbackSourceImage: src,
                renderSize: renderSize,
                settings: settings
            )

            print("🎯 SmartFillCIBuilder: fgRect =", fgRect, " bgExtent =", background.extent, " final =", renderRect)

            finishSafely(fgCentered.composited(over: background))
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

    private static func loadPreparedBackgroundImage(
        mode: SmartFillSettings.BackgroundSourceMode,
        assetPath: String?
    ) -> PreparedBackgroundImage? {
        guard mode == .customImage else { return nil }
        guard let assetPath, !assetPath.isEmpty else { return nil }

        let url = URL(fileURLWithPath: assetPath)
        guard FileManager.default.fileExists(atPath: url.path) else {
            print("⚠️ SmartFillCIBuilder: custom still background missing at \(assetPath)")
            return nil
        }

        if let ciImage = CIImage(contentsOf: url, options: [.applyOrientationProperty: true]) {
            return PreparedBackgroundImage(image: ciImage)
        }

        if let uiImage = UIImage(contentsOfFile: url.path) {
            if let cgImage = uiImage.cgImage {
                return PreparedBackgroundImage(image: CIImage(cgImage: cgImage))
            }
            if let ciImage = uiImage.ciImage {
                return PreparedBackgroundImage(image: ciImage)
            }
        }

        print("⚠️ SmartFillCIBuilder: could not load custom still background at \(assetPath)")
        return nil
    }

    private static func makePreparedBackgroundImage(
        from image: CIImage,
        fallbackSourceImage: CIImage,
        renderSize: CGSize,
        settings: SmartFillSettings
    ) -> CIImage {
        let inputImage = validatedBackgroundInput(image, fallback: fallbackSourceImage, renderSize: renderSize)
        let sourceSize = inputImage.extent.size
        let baseScale = max(renderSize.width / sourceSize.width, renderSize.height / sourceSize.height)
        let configuredScale = max(settings.backgroundScale, 1.0)
        let finalScale = min(baseScale * configuredScale, baseScale * 4.0)
        let scaled = inputImage.transformed(by: CGAffineTransform(scaleX: finalScale, y: finalScale))
        let scaledRect = scaled.extent
        let offsetX = (renderSize.width - scaledRect.width) * 0.5 - scaledRect.minX
        let offsetY = (renderSize.height - scaledRect.height) * 0.5 - scaledRect.minY
        let centered = scaled.transformed(by: CGAffineTransform(translationX: offsetX, y: offsetY))

        return centered
            .clampedToExtent()
            .applyingFilter("CIGaussianBlur", parameters: ["inputRadius": settings.defaultBlurRadius])
            .cropped(to: CGRect(origin: .zero, size: renderSize))
            .applyingFilter("CIColorControls", parameters: ["inputBrightness": -settings.defaultDarkenAmount])
    }

    private static func validatedBackgroundInput(
        _ image: CIImage,
        fallback fallbackSourceImage: CIImage,
        renderSize: CGSize
    ) -> CIImage {
        let source = isValidBackgroundExtent(image.extent)
            ? image
            : fallbackSourceImage

        guard isValidBackgroundExtent(source.extent) else {
            return CIImage(color: .black)
                .cropped(to: CGRect(origin: .zero, size: renderSize))
        }

        let rect = source.extent
        return source.transformed(
            by: CGAffineTransform(
                translationX: -rect.origin.x,
                y: -rect.origin.y
            )
        )
    }

    private static func isValidBackgroundExtent(_ rect: CGRect) -> Bool {
        rect.isNull == false &&
        rect.isInfinite == false &&
        rect.isEmpty == false &&
        rect.origin.x.isFinite &&
        rect.origin.y.isFinite &&
        rect.size.width.isFinite &&
        rect.size.height.isFinite &&
        rect.size.width > 0 &&
        rect.size.height > 0
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
