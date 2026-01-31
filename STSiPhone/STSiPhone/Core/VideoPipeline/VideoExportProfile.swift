import AVFoundation
import CoreGraphics
import Foundation

/// Unified export profile so both ExportEngine and SessionExportManager share the same quality ladder.
struct VideoExportProfile {
    let name: String
    let presetName: String
    let fallbackPresetName: String
    let maxDimension: CGFloat?
    let prefersHEVC: Bool
    let allowPassthrough: Bool
    let bitsPerPixelTarget: Double?

    /// Compute a render size capped by the profile but never upscale above source.
    func targetRenderSize(sourceSize: CGSize?) -> CGSize {
        guard let sourceSize else { return CGSize(width: 1920, height: 1080) }
        guard let maxDimension else { return normalizedSize(sourceSize) }

        let normalized = normalizedSize(sourceSize)
        let largestSide = max(normalized.width, normalized.height)
        if largestSide <= maxDimension {
            return normalized
        }

        let scale = maxDimension / largestSide
        let width = max(2, normalized.width * scale).rounded(.toNearestOrAwayFromZero)
        let height = max(2, normalized.height * scale).rounded(.toNearestOrAwayFromZero)
        return CGSize(width: width, height: height)
    }

    /// Choose the best preset supported for this asset, falling back when passthrough or HEVC are unavailable.
    func bestPreset(for asset: AVAsset) -> String {
        // Use session creation to validate compatibility to avoid deprecated APIs.
        if allowPassthrough,
           AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetPassthrough) != nil {
            return AVAssetExportPresetPassthrough
        }

        if AVAssetExportSession(asset: asset, presetName: presetName) != nil {
            return presetName
        }

        if AVAssetExportSession(asset: asset, presetName: fallbackPresetName) != nil {
            return fallbackPresetName
        }

        // Last resort
        return AVAssetExportPresetHighestQuality
    }

    /// Suggested bitrate based on bits-per-pixel target.
    func targetBitrate(for analysis: SourceAnalysis) -> Double? {
        guard let bitsPerPixelTarget else { return nil }
        let renderSize = targetRenderSize(sourceSize: analysis.dimensions)
        let pixelsPerSecond = Double(renderSize.width * renderSize.height) * max(analysis.fps, 24.0)
        return pixelsPerSecond * bitsPerPixelTarget
    }

    /// Resolve the bitrate we intend to use, capping to the source bitrate to avoid bloat.
    func resolvedBitrate(for analysis: SourceAnalysis) -> Double {
        let sourceBitrate = analysis.estimatedBitrate
        let fallbackBitrate = 5_000_000.0

        guard let target = targetBitrate(for: analysis) else {
            return sourceBitrate > 0 ? sourceBitrate : fallbackBitrate
        }

        // Cap growth to ~10% above source to prevent bloat, but honor profile targets to create tier separation.
        if sourceBitrate > 0 {
            let ceiling = sourceBitrate * 1.1
            return min(target, ceiling)
        }

        return target
    }

    private func normalizedSize(_ size: CGSize) -> CGSize {
        CGSize(width: max(2, abs(size.width)), height: max(2, abs(size.height)))
    }
}

/// Lightweight source analysis used for profile decisions and instrumentation.
struct SourceAnalysis {
    let dimensions: CGSize
    let durationSeconds: Double
    let fps: Double
    let estimatedBitrate: Double

    init(asset: AVAsset) async throws {
        guard let videoTrack = try await asset.loadTracks(withMediaType: .video).first else {
            throw NSError(domain: "VideoExportProfile", code: -1, userInfo: [NSLocalizedDescriptionKey: "No video track"])
        }

        let naturalSize = try await videoTrack.load(.naturalSize)
        let preferredTransform = try await videoTrack.load(.preferredTransform)
        let renderSize = naturalSize.applying(preferredTransform)
        dimensions = CGSize(width: abs(renderSize.width), height: abs(renderSize.height))

        let duration = try await asset.load(.duration)
        durationSeconds = max(duration.seconds, 0.01)

        if let nominalFPS = try? await videoTrack.load(.nominalFrameRate), nominalFPS > 0 {
            fps = Double(nominalFPS)
        } else if let minFrameDuration = try? await videoTrack.load(.minFrameDuration),
                  minFrameDuration.isValid && minFrameDuration.seconds > 0 {
            fps = 1.0 / minFrameDuration.seconds
        } else {
            fps = 30.0
        }

        if let urlAsset = asset as? AVURLAsset,
           let fileSize = try? urlAsset.url.resourceValues(forKeys: [.fileSizeKey]).fileSize,
           fileSize > 0 {
            estimatedBitrate = Double(fileSize) * 8.0 / durationSeconds
        } else {
            estimatedBitrate = 0
        }
    }
}

// MARK: - Profile Factories

extension VideoExportProfile {
    static func profile(for quality: ExportQuality, format: OutputFormat) -> VideoExportProfile {
        switch quality {
        case .maximum:
            return VideoExportProfile(
                name: "Passthrough",
                presetName: AVAssetExportPresetPassthrough,
                fallbackPresetName: AVAssetExportPresetHighestQuality,
                maxDimension: nil,
                prefersHEVC: false,
                allowPassthrough: true,
                bitsPerPixelTarget: nil
            )
        case .high:
            return VideoExportProfile(
                name: "Studio",
                presetName: AVAssetExportPreset3840x2160,
                fallbackPresetName: AVAssetExportPreset1920x1080,
                maxDimension: 3840, // allow 4K, cap above
                prefersHEVC: false,
                allowPassthrough: false,
                bitsPerPixelTarget: 0.12 // bump to improve quality/throughput
            )
        case .medium:
            return VideoExportProfile(
                name: "Balanced",
                presetName: AVAssetExportPreset1920x1080,
                fallbackPresetName: AVAssetExportPreset1280x720,
                maxDimension: 1920,
                prefersHEVC: false,
                allowPassthrough: false,
                bitsPerPixelTarget: 0.07
            )
        case .low:
            return VideoExportProfile(
                name: "Data Saver",
                presetName: AVAssetExportPreset1280x720,
                fallbackPresetName: AVAssetExportPreset960x540,
                maxDimension: 1280,
                prefersHEVC: false,
                allowPassthrough: false,
                bitsPerPixelTarget: 0.04
            )
        }
    }

    static func profile(for quality: SessionExportManager.ExportQuality, format: SessionExportManager.ExportFormat) -> VideoExportProfile {
        let coreFormat: OutputFormat = (format == .mp4) ? .mp4 : .mov
        switch quality {
        case .maximum:
            return profile(for: .maximum, format: coreFormat)
        case .high:
            return profile(for: .high, format: coreFormat)
        case .medium:
            return profile(for: .medium, format: coreFormat)
        case .low:
            return profile(for: .low, format: coreFormat)
        }
    }

    private static func prefersHEVC(for format: OutputFormat) -> Bool {
        // For export, standardize on H.264 for speed/compatibility.
        return false
    }
}
