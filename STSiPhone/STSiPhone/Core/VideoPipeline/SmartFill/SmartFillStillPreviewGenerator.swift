import AVFoundation
import CoreImage
import UIKit

/// 🚨 CRITICAL FIX: Still-frame SmartFill preview generator
/// HANDOFF FIX: Enhanced with defensive extent clamping and flexible parameter support
/// SOLVES: Preview crashes by avoiding AVPlayer/AVPlayerItem entirely
/// Shows SmartFill effect using single frame + Core Image - fast and safe
public struct SmartFillStillPreviewGenerator {
    
    private let asset: AVAsset
    private let targetPixelSize: CGSize // HANDOFF FIX: Support configurable target size
    private let blurRadius: CGFloat // HANDOFF FIX: Configurable blur
    private let darkenAmount: CGFloat // HANDOFF FIX: Configurable darken
    private let scaleFactor: CGFloat // HANDOFF FIX: Configurable scale
    private let context: CIContext
    
    // HANDOFF FIX: New initializer with configurable parameters
    public init(asset: AVAsset,
                targetPixelSize: CGSize,
                blurRadius: CGFloat,
                darkenAmount: CGFloat,
                scaleFactor: CGFloat) {
        self.asset = asset
        self.targetPixelSize = targetPixelSize
        self.blurRadius = blurRadius
        self.darkenAmount = darkenAmount
        self.scaleFactor = scaleFactor
        
        // Create optimized CI context for still image processing
        if let metalDevice = MTLCreateSystemDefaultDevice() {
            self.context = CIContext(mtlDevice: metalDevice, options: [
                .workingColorSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
                .outputColorSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
                .cacheIntermediates: false // Don't cache for one-off preview
            ])
        } else {
            self.context = CIContext(options: [
                .workingColorSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
                .outputColorSpace: CGColorSpace(name: CGColorSpace.sRGB)!
            ])
        }
        
        print("🎨 SmartFillStillPreviewGenerator: HANDOFF FIX - Enhanced initialization")
        print("   📐 Target size: \(targetPixelSize)")
        print("   ⚙️ Settings: blur=\(blurRadius), darken=\(darkenAmount), scale=\(scaleFactor)")
    }
    
    // LEGACY: Keep existing initializer for backward compatibility
    public init(asset: AVAsset) {
        self.init(asset: asset,
                  targetPixelSize: CGSize(width: 1920, height: 1080),
                  blurRadius: 30.0,
                  darkenAmount: 0.3,
                  scaleFactor: 1.5)
    }
    
    /// HANDOFF FIX: Simplified interface that uses instance parameters
    public func makePreviewImage() async throws -> UIImage {
        
        print("🖼️ SmartFillStillPreviewGenerator: HANDOFF FIX - Starting preview generation")
        print("   📐 Target size: \(targetPixelSize)")
        print("   ⚙️ Settings: blur=\(blurRadius), darken=\(darkenAmount), scale=\(scaleFactor)")
        print("   🎬 Asset: \(asset)")
        
        do {
            // 1) Grab a frame (use AVAssetImageGenerator with maximumSize for speed)
            print("   🎬 Step 1: Extracting frame...")
            let frame = try await extractFrame()
            print("   ✅ Frame extracted with extent: \(frame.extent)")

            // 2) Build background (blurred and darkened), clamp/crop to finite extent
            print("   🎨 Step 2: Creating blurred background...")
            let bg = createBlurredBackground(from: frame)
            print("   ✅ Background created with extent: \(bg.extent)")

            // 3) Foreground: scale portrait to fit height into 16:9 and center horizontally
            print("   🖼️ Step 3: Creating foreground...")
            let fg = createForeground(from: frame)
            print("   ✅ Foreground created with extent: \(fg.extent)")

            // 4) Composite
            print("   🔄 Step 4: Compositing...")
            guard let composite = CIFilter(name: "CISourceOverCompositing",
                                           parameters: [kCIInputImageKey: fg, kCIInputBackgroundImageKey: bg])?.outputImage
            else {
                throw SmartFillPreviewError.filterProcessingFailed("Compositing failed")
            }
            print("   ✅ Composite created with extent: \(composite.extent)")

            // 5) Render to CGImage of target pixel size
            print("   🎯 Step 5: Rendering to UIImage...")
            let renderRect = CGRect(origin: .zero, size: targetPixelSize)
            guard let cg = context.createCGImage(composite, from: renderRect) else {
                throw SmartFillPreviewError.renderingFailed
            }
            
            let uiImage = UIImage(cgImage: cg, scale: 1.0, orientation: .up)
            print("✅ SmartFillStillPreviewGenerator: HANDOFF FIX - Preview generation completed")
            print("   📊 Final UIImage: \(uiImage.size) scale=\(uiImage.scale)")
            
            return uiImage
            
        } catch {
            print("❌ SmartFillStillPreviewGenerator: Generation failed at some step")
            print("   💥 Error: \(error)")
            print("   📝 Error details: \(error.localizedDescription)")
            throw error
        }
    }

    /// Generate SmartFill preview image - LEGACY METHOD for backward compatibility
    public func makePreviewImage(
        targetSize: CGSize = CGSize(width: 1920, height: 1080),
        time: CMTime? = nil,
        settings: SmartFillSettings = SmartFillSettings()
    ) async throws -> UIImage {
        
        print("🖼️ SmartFillStillPreviewGenerator: LEGACY - Using legacy method")
        
        // Create new generator with legacy parameters
        let legacyGenerator = SmartFillStillPreviewGenerator(
            asset: asset,
            targetPixelSize: targetSize,
            blurRadius: settings.defaultBlurRadius,
            darkenAmount: settings.defaultDarkenAmount,
            scaleFactor: settings.backgroundScale
        )
        
        return try await legacyGenerator.makePreviewImage()
    }
    
    // MARK: - Private Implementation

    private func extractFrame() async throws -> CIImage {
        let gen = AVAssetImageGenerator(asset: asset)
        gen.appliesPreferredTrackTransform = true
        // Give the generator a maximum size to keep memory low
        let maxWidth = max(targetPixelSize.width, targetPixelSize.height)
        gen.maximumSize = CGSize(width: maxWidth, height: maxWidth)
        let time = CMTimeMultiplyByFloat64(try await asset.load(.duration), multiplier: 0.25) // quarter mark
        
        // MODERNIZED: Use async image generation instead of deprecated copyCGImage
        return try await withCheckedThrowingContinuation { continuation in
            gen.generateCGImageAsynchronously(for: time) { cgImage, _, error in
                if let cgImage = cgImage {
                    let ciImage = CIImage(cgImage: cgImage)
                    continuation.resume(returning: ciImage)
                } else {
                    let error = error ?? SmartFillPreviewError.frameExtractionFailed
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /// HANDOFF FIX: Defensive extent clamping to prevent Core Image anomalies
    private func clampedExtent(_ image: CIImage) -> CIImage {
        // HANDOFF FIX: Handle infinite extent and empty extent cases
        if image.extent.isInfinite || image.extent.isEmpty {
            let safeRect = CGRect(x: 0, y: 0, width: targetPixelSize.width, height: targetPixelSize.height)
            return image.clampedToExtent().cropped(to: safeRect)
        }
        return image.clampedToExtent().cropped(to: image.extent)
    }
    
    /// COMPREHENSIVE FIX: Thorough background creation with step-by-step validation and fallbacks
    /// This ensures the preview shows background expansion on BOTH SIDES like the actual export
    private func createBlurredBackground(from originalImage: CIImage) -> CIImage {
        print("🎨 SmartFillStillPreviewGenerator: COMPREHENSIVE FIX - Starting background creation")
        print("   📐 Target size: \(targetPixelSize)")
        print("   🎨 Settings: blur=\(blurRadius), darken=\(darkenAmount), scale=\(scaleFactor)")
        print("   📐 Original image extent: \(originalImage.extent)")
        
        // STEP 1: Defensive extent clamping with validation
        let clampedImage = clampedExtent(originalImage)
        print("   ✅ Step 1 - Clamped extent: \(clampedImage.extent)")
        
        guard !clampedImage.extent.isEmpty && clampedImage.extent.size.width > 0 && clampedImage.extent.size.height > 0 else {
            print("   ❌ Invalid clamped image, using fallback")
            return createFallbackBackground(from: originalImage)
        }
        
        // STEP 2: Calculate scaling - match SmartFillExporter logic exactly
        let sourceSize = clampedImage.extent.size
        let scaleX = targetPixelSize.width / sourceSize.width
        let scaleY = targetPixelSize.height / sourceSize.height
        let baseScale = max(scaleX, scaleY)
        
        // CRITICAL: Use the SAME logic as SmartFillExporter - baseScale * settings.backgroundScale
        let finalScale = baseScale * scaleFactor
        
        print("   📏 Step 2 - Scaling calculation:")
        print("      📐 Source size: \(sourceSize)")
        print("      📐 Scale X: \(scaleX), Scale Y: \(scaleY)")
        print("      📐 Base scale: \(baseScale)")
        print("      📐 Background scale factor: \(scaleFactor)")
        print("      📐 Final scale: \(finalScale)")
        
        guard finalScale > 0 && finalScale.isFinite else {
            print("   ❌ Invalid scale values, using fallback")
            return createFallbackBackground(from: originalImage)
        }
        
        // STEP 3: Apply scaling transform
        let scaledImage = clampedImage.transformed(by: CGAffineTransform(scaleX: finalScale, y: finalScale))
        print("   ✅ Step 3 - Scaled image extent: \(scaledImage.extent)")
        
        guard !scaledImage.extent.isEmpty && !scaledImage.extent.isInfinite else {
            print("   ❌ Invalid scaled image, using fallback")
            return createFallbackBackground(from: originalImage)
        }
        
        // STEP 4: Calculate centering - center the scaled image to fill target size
        let scaledSize = CGSize(width: sourceSize.width * finalScale, height: sourceSize.height * finalScale)
        let offsetX = (targetPixelSize.width - scaledSize.width) / 2
        let offsetY = (targetPixelSize.height - scaledSize.height) / 2
        
        print("   📐 Step 4 - Centering calculation:")
        print("      📐 Scaled size: \(scaledSize)")
        print("      📐 Target size: \(targetPixelSize)")
        print("      📐 Offset: (\(offsetX), \(offsetY))")
        
        // STEP 5: Apply centering - position for center crop
        let centeredImage = scaledImage.transformed(by: CGAffineTransform(translationX: offsetX, y: offsetY))
        print("   ✅ Step 5 - Centered image extent: \(centeredImage.extent)")
        
        guard !centeredImage.extent.isEmpty && !centeredImage.extent.isInfinite else {
            print("   ❌ Invalid centered image, using fallback")
            return createFallbackBackground(from: originalImage)
        }
        
        // STEP 6: Crop to target size
        let cropRect = CGRect(origin: .zero, size: targetPixelSize)
        let croppedImage = centeredImage.cropped(to: cropRect)
        print("   ✅ Step 6 - Cropped to target size: \(croppedImage.extent)")
        
        guard !croppedImage.extent.isEmpty else {
            print("   ❌ Invalid cropped image, using fallback")
            return createFallbackBackground(from: originalImage)
        }
        
        // STEP 7: Apply blur filter with validation
        print("   🌊 Step 7 - Applying blur filter (radius: \(blurRadius))...")
        guard let blurFilter = CIFilter(name: "CIGaussianBlur") else {
            print("   ❌ Could not create blur filter, skipping blur")
            return applyColorAdjustments(to: croppedImage)
        }
        
        blurFilter.setValue(croppedImage, forKey: kCIInputImageKey)
        blurFilter.setValue(blurRadius, forKey: kCIInputRadiusKey)
        
        guard let blurredImage = blurFilter.outputImage else {
            print("   ❌ Blur filter failed, skipping blur")
            return applyColorAdjustments(to: croppedImage)
        }
        
        // Crop blur result to exact size (blur can expand extent)
        let blurredCropped = blurredImage.cropped(to: cropRect)
        print("   ✅ Step 7 - Blur applied and cropped: \(blurredCropped.extent)")
        
        // STEP 8: Apply color adjustments
        print("   🎨 Step 8 - Applying color adjustments...")
        let finalBackground = applyColorAdjustments(to: blurredCropped)
        
        print("✅ SmartFillStillPreviewGenerator: COMPREHENSIVE SUCCESS")
        print("   📐 Final background extent: \(finalBackground.extent)")
        print("   🎯 Background properly scaled, centered, and processed")
        
        return finalBackground
    }
    
    /// Apply color adjustments with validation and fallback
    private func applyColorAdjustments(to image: CIImage) -> CIImage {
        guard let colorFilter = CIFilter(name: "CIColorControls") else {
            print("   ⚠️ Could not create color filter, returning image without adjustments")
            return image
        }
        
        colorFilter.setValue(image, forKey: kCIInputImageKey)
        colorFilter.setValue(-darkenAmount, forKey: kCIInputBrightnessKey) // Darken
        colorFilter.setValue(0.7, forKey: kCIInputSaturationKey) // Desaturate
        colorFilter.setValue(1.1, forKey: kCIInputContrastKey) // Contrast boost
        
        guard let adjustedImage = colorFilter.outputImage else {
            print("   ⚠️ Color adjustments failed, returning original image")
            return image
        }
        
        // Ensure final crop to exact target size
        let finalCropped = adjustedImage.cropped(to: CGRect(origin: .zero, size: targetPixelSize))
        print("   ✅ Color adjustments applied, final size: \(finalCropped.extent.size)")
        
        return finalCropped
    }
    
    /// Create fallback background when processing fails
    private func createFallbackBackground(from originalImage: CIImage) -> CIImage {
        print("   🛡️ Creating fallback background")
        
        // Create a simple blurred version without complex transformations
        let clampedImage = clampedExtent(originalImage)
        
        // Simple aspect fill scaling
        let sourceSize = clampedImage.extent.size
        let scaleX = targetPixelSize.width / sourceSize.width
        let scaleY = targetPixelSize.height / sourceSize.height
        let scale = max(scaleX, scaleY) * 1.2 // Slight overfill
        
        let simpleScaled = clampedImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let cropRect = CGRect(origin: .zero, size: targetPixelSize)
        let simpleCropped = simpleScaled.cropped(to: cropRect)
        
        // Apply minimal blur if possible
        if let blurFilter = CIFilter(name: "CIGaussianBlur") {
            blurFilter.setValue(simpleCropped, forKey: kCIInputImageKey)
            blurFilter.setValue(min(blurRadius, 10.0), forKey: kCIInputRadiusKey) // Reduced blur for safety
            
            if let blurred = blurFilter.outputImage {
                let blurredCropped = blurred.cropped(to: cropRect)
                print("   ✅ Fallback background with light blur created")
                return blurredCropped
            }
        }
        
        print("   ✅ Fallback background without blur created")
        return simpleCropped
    }
    
    private func createForeground(from originalImage: CIImage) -> CIImage {
        // Scale portrait to fit height into 16:9 and center horizontally
        let fgWidth = targetPixelSize.height * 9.0 / 16.0
        let x = (targetPixelSize.width - fgWidth) / 2.0
        let fgRect = CGRect(x: max(0, x), y: 0, width: min(targetPixelSize.width, fgWidth), height: targetPixelSize.height)
        
        return originalImage
            .transformed(by: CGAffineTransform(scaleX: fgRect.width / originalImage.extent.width,
                                               y: fgRect.height / originalImage.extent.height))
            .transformed(by: CGAffineTransform(translationX: fgRect.minX, y: fgRect.minY))
    }
}

// MARK: - Core Image Extensions for SmartFill

private extension CIImage {
    
    /// Scale image to fill target size with optional extra scaling
    func smartFillScaled(to target: CGSize, scale: CGFloat = 1.0) -> CIImage {
        let sourceSize = extent.size
        
        // Calculate scale to fill target size
        let sx = target.width / sourceSize.width
        let sy = target.height / sourceSize.height
        let fillScale = max(sx, sy) * scale // Apply extra scale factor
        
        // Apply scaling transform
        let scaledImage = transformed(by: CGAffineTransform(scaleX: fillScale, y: fillScale))
        
        // Center crop to target size
        let scaledSize = CGSize(
            width: sourceSize.width * fillScale,
            height: sourceSize.height * fillScale
        )
        
        let offsetX = (scaledSize.width - target.width) * 0.5
        let offsetY = (scaledSize.height - target.height) * 0.5
        
        let cropRect = CGRect(
            x: scaledImage.extent.origin.x + offsetX,
            y: scaledImage.extent.origin.y + offsetY,
            width: target.width,
            height: target.height
        )
        
        return scaledImage.cropped(to: cropRect)
    }
    
    /// Scale image to fit within target size and center with transparent background
    func smartFillAspectFit(in target: CGSize) -> CIImage {
        let sourceSize = extent.size
        
        // Calculate scale to fit within target
        let sx = target.width / sourceSize.width
        let sy = target.height / sourceSize.height
        let fitScale = min(sx, sy)
        
        // Apply scaling
        let scaledImage = transformed(by: CGAffineTransform(scaleX: fitScale, y: fitScale))
        let scaledSize = CGSize(
            width: sourceSize.width * fitScale,
            height: sourceSize.height * fitScale
        )
        
        // Calculate centering offset
        let offsetX = (target.width - scaledSize.width) * 0.5
        let offsetY = (target.height - scaledSize.height) * 0.5
        
        // Center in target canvas
        return scaledImage.transformed(by: CGAffineTransform(
            translationX: offsetX - scaledImage.extent.origin.x,
            y: offsetY - scaledImage.extent.origin.y
        ))
    }
}

// MARK: - Error Handling

public enum SmartFillPreviewError: LocalizedError {
    case frameExtractionFailed
    case filterCreationFailed(String)
    case filterProcessingFailed(String)
    case renderingFailed
    
    public var errorDescription: String? {
        switch self {
        case .frameExtractionFailed:
            return "Failed to extract frame from video"
        case .filterCreationFailed(let filterName):
            return "Failed to create Core Image filter: \(filterName)"
        case .filterProcessingFailed(let operation):
            return "Core Image filter processing failed: \(operation)"
        case .renderingFailed:
            return "Failed to render final preview image"
        }
    }
}

// MARK: - Convenience Extensions

public extension SmartFillStillPreviewGenerator {
    
    /// Quick preview generation from URL
    static func generatePreview(
        from url: URL,
        targetSize: CGSize = CGSize(width: 1920, height: 1080),
        settings: SmartFillSettings = SmartFillSettings()
    ) async throws -> UIImage {
        
        let asset = AVURLAsset(url: url)
        let generator = SmartFillStillPreviewGenerator(asset: asset)
        return try await generator.makePreviewImage(
            targetSize: targetSize,
            settings: settings
        )
    }
}
