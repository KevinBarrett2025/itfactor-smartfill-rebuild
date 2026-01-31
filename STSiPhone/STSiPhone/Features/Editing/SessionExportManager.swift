import Foundation
import AVFoundation
import UIKit

// AVFoundation export types are manually synchronized on the main actor, so mark them as Sendable.
extension AVAssetExportSession: @retroactive @unchecked Sendable {}
extension AVAssetWriter: @retroactive @unchecked Sendable {}
extension AVAssetWriterInput: @retroactive @unchecked Sendable {}
extension AVAssetWriterInputPixelBufferAdaptor: @retroactive @unchecked Sendable {}

/// SessionExportManager is responsible for building a merged audition export
/// from all takes marked as 'good' in the session. It supports:
/// - Trim & crop per take
/// - Merging multiple takes in order
/// - Inserting a slate/thumbnail photo as the first frames (photo -> short video)
/// - Exporting a final audition video file with multiple quality options
/// UPDATED: Integrated with STS Orientation Forensics System
@MainActor
final class SessionExportManager {

    static let shared = SessionExportManager()

    private let exportActor = SessionExportActor()
    private var currentTask: Task<Void, Never>?
    private var currentCancellation: CancellationToken?

    private init() {}

    // MARK: - Timebase helpers (normalize to 600 to avoid mixed scales in composition)
    private static func t600(_ t: CMTime) -> CMTime {
        CMTimeConvertScale(t, timescale: 600, method: .default)
    }

    private static func r600(_ r: CMTimeRange) -> CMTimeRange {
        CMTimeRange(start: t600(r.start), duration: t600(r.duration))
    }

    // MARK: - Debug helpers
    private static func describeAudioFormat(_ track: AVAssetTrack?) async -> String {
        guard let track else { return "audio=nil" }
        // Use modern async load when available; skip legacy introspection to avoid deprecation noise.
        if #available(iOS 16.0, *) {
            do {
                let descs: [CMFormatDescription] = try await track.load(.formatDescriptions)
                guard let fmtDesc = descs.first else { return "audio=unknown" }
                if let asbdPtr = CMAudioFormatDescriptionGetStreamBasicDescription(fmtDesc) {
                    let asbd = asbdPtr.pointee
                    return "sr=\(Int(asbd.mSampleRate))Hz ch=\(asbd.mChannelsPerFrame) fmt=\(asbd.mFormatID)"
                }
                return "audio=cmfmt(no-asbd)"
            } catch {
                return "audio=err(\(error.localizedDescription))"
            }
        }
        return "audio=legacy"
    }

    // MARK: - CMTimeRange helpers
    private static func clamped(_ range: CMTimeRange, to bounds: CMTimeRange) -> CMTimeRange {
        let start = CMTimeMaximum(range.start, bounds.start)
        let end = CMTimeMinimum(range.end, bounds.end)
        let duration = CMTimeMaximum(.zero, end - start)
        return CMTimeRange(start: start, duration: duration)
    }

    // MARK: - Enhanced Configuration Options (CLEAN: SmartFill handled by separate exporters)

    enum ExportQuality: String, CaseIterable, Sendable {
        case low = "Low"
        case medium = "Medium"
        case high = "High"
        case maximum = "Maximum"

        var preset: String {
            switch self {
            case .low:     return AVAssetExportPresetLowQuality
            case .medium:  return AVAssetExportPresetMediumQuality
            case .high:    return AVAssetExportPreset1920x1080
            case .maximum: return AVAssetExportPresetHighestQuality
            }
        }

        var bitrate: Int {
            switch self {
            case .low:     return 1_000_000      // 1 Mbps
            case .medium:  return 3_000_000      // 3 Mbps
            case .high:    return 6_000_000      // 6 Mbps
            case .maximum: return 12_000_000     // 12 Mbps
            }
        }
    }

    private static func buildExportContext(
        takes: [TakeMetadata],
        options: ExportOptions,
        thumbnailMetadata: [AVMetadataItem],
        outputFileName: String,
        pipSlateSession: SlatePIPSession?,
        keyframePhotoURL: URL?
    ) async throws -> ExportContext {
        let finalSelectTakes = takes.filter { $0.isFinalSelect }
        guard !finalSelectTakes.isEmpty else { throw SessionExportError.noFinalSelectTakes }

        let profile = VideoExportProfile.profile(for: options.quality, format: options.format)

        let resolvedRenderSize: CGSize
        if let firstAsset = finalSelectTakes.first?.asset,
           let analysis = try? await SourceAnalysis(asset: firstAsset) {
            resolvedRenderSize = profile.targetRenderSize(sourceSize: analysis.dimensions)
            let targetBitrate = profile.targetBitrate(for: analysis)
            let targetString = targetBitrate.map { ByteCountFormatter.string(fromByteCount: Int64($0 / 8.0), countStyle: .file) + "/s target" } ?? "passthrough"
            print("📊 SessionExport: Source \(Int(analysis.dimensions.width))x\(Int(analysis.dimensions.height)) @\(String(format: "%.1f", analysis.fps))fps ~\(ByteCountFormatter.string(fromByteCount: Int64(analysis.estimatedBitrate / 8.0), countStyle: .file))/s → \(targetString)")
            print("📊 SessionExport: Target render size \(Int(resolvedRenderSize.width))x\(Int(resolvedRenderSize.height)) using profile \(profile.name)")
        } else {
            resolvedRenderSize = profile.targetRenderSize(sourceSize: options.renderSize)
        }

        var keyframeIntroAsset: AVAsset?
        if let photoURL = keyframePhotoURL {
            do {
                keyframeIntroAsset = try await makeKeyframeIntroAsset(
                    photoURL: photoURL,
                    renderSize: resolvedRenderSize
                )
                if let intro = keyframeIntroAsset {
                    let introDuration = try await intro.load(.duration)
                    print("🎞️ SessionExportManager: Prepared keyframe intro clip (\(introDuration.seconds)s) from \(photoURL.lastPathComponent)")
#if DEBUG
                    if let introTrack = try await intro.loadTracks(withMediaType: .video).first {
                        let introSize = (try? await introTrack.load(.naturalSize)) ?? .zero
                        let introTransform = (try? await introTrack.load(.preferredTransform)) ?? .identity
                        print("🔬 [SessionExport] intro clip natural=\(introSize) preferred=\(introTransform) renderSize=\(resolvedRenderSize)")
                    }
#endif
                }
            } catch {
                print("⚠️ SessionExportManager: Failed to build keyframe intro clip: \(error.localizedDescription)")
            }
        }

        var slateAsset: AVAsset?
        var segmentEntries: [(start: CMTime, duration: CMTime, sourceTrack: AVAssetTrack, cropRect: CGRect, rotationDegrees: Double, needsInstruction: Bool)] = []
        var anySegmentNeedsInstruction = false
        let enableFullInstructionCoverage = true
        if let pipSlateURL = try await generatePIPSlateURLIfNeeded(
            from: pipSlateSession,
            includeSlate: options.includeSlate
        ) {
            slateAsset = AVURLAsset(url: pipSlateURL)
        } else if options.includeSlate,
                  let slateImage = takes.first(where: { $0.isSlatePhoto && $0.thumbnailImage != nil })?.thumbnailImage {
            slateAsset = try await convertSlatePhotoToVideoAsync(slateImage, duration: options.slateDuration)
        }

        let composition = AVMutableComposition()
        guard let videoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            throw SessionExportError.compositionFailed
        }
        let compositionAudioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)

        var insertTime = CMTime.zero
        var videoInstructions: [AVMutableVideoCompositionInstruction] = []

        if let introAsset = keyframeIntroAsset,
           let introVideoTrack = try await introAsset.loadTracks(withMediaType: .video).first {
            let introDuration = try await introAsset.load(.duration)
            let timeRange = r600(CMTimeRange(start: .zero, duration: introDuration))
            let insertAt = t600(insertTime)
            try videoTrack.insertTimeRange(timeRange, of: introVideoTrack, at: insertAt)
#if DEBUG
            let introTransform = (try? await introVideoTrack.load(.preferredTransform)) ?? .identity
            let introNeeds = !introTransform.isIdentity
            let introAudio = try? await introAsset.loadTracks(withMediaType: .audio).first
            segmentEntries.append((start: insertTime, duration: timeRange.duration, sourceTrack: introVideoTrack, cropRect: .stsNormalizedFullFrame, rotationDegrees: 0, needsInstruction: introNeeds))
            anySegmentNeedsInstruction = anySegmentNeedsInstruction || introNeeds
            let introAudioTrack = introAudio ?? nil
            let introAudioDur = (try? await introAudioTrack?.load(.timeRange).duration.seconds) ?? 0
            let introAudioFmt = await describeAudioFormat(introAudioTrack)
            let introVideoDur = (try? await introVideoTrack.load(.timeRange).duration.seconds) ?? introDuration.seconds
            print("⏱️ [ExportDur] intro asset=\(introDuration.seconds)s video=\(introVideoDur)s audio=\(introAudioDur)s fmt=\(introAudioFmt)")
            print("⏱️ [ExportInsert] intro insertAt=\(insertTime.seconds)s insertRange=0..\((timeRange.start + timeRange.duration).seconds)s dur=\(timeRange.duration.seconds)s")
#endif
            insertTime = CMTimeAdd(insertTime, timeRange.duration)
        }

        if let slateAsset = slateAsset,
           let slateVideoTrack = try await slateAsset.loadTracks(withMediaType: .video).first {
            let slateDuration = try await slateAsset.load(.duration)
            let timeRange = r600(CMTimeRange(start: .zero, duration: slateDuration))
            let insertAt = t600(insertTime)
            try videoTrack.insertTimeRange(timeRange, of: slateVideoTrack, at: insertAt)
#if DEBUG
            let slateTransform = (try? await slateVideoTrack.load(.preferredTransform)) ?? .identity
            let slateNeeds = !slateTransform.isIdentity
            let slateAudio = try? await slateAsset.loadTracks(withMediaType: .audio).first
            segmentEntries.append((start: insertTime, duration: timeRange.duration, sourceTrack: slateVideoTrack, cropRect: .stsNormalizedFullFrame, rotationDegrees: 0, needsInstruction: slateNeeds))
            anySegmentNeedsInstruction = anySegmentNeedsInstruction || slateNeeds
            let slateAudioTrack = slateAudio ?? nil
            let slateAudioDur = (try? await slateAudioTrack?.load(.timeRange).duration.seconds) ?? 0
            let slateAudioFmt = await describeAudioFormat(slateAudioTrack)
            let slateVideoDur = (try? await slateVideoTrack.load(.timeRange).duration.seconds) ?? slateDuration.seconds
            print("⏱️ [ExportDur] slate asset=\(slateDuration.seconds)s video=\(slateVideoDur)s audio=\(slateAudioDur)s fmt=\(slateAudioFmt)")
            print("⏱️ [ExportInsert] slate insertAt=\(insertTime.seconds)s insertRange=0..\((timeRange.start + timeRange.duration).seconds)s dur=\(timeRange.duration.seconds)s")
#endif
            if options.includeAudio,
               let slateAudioTrack = try await slateAsset.loadTracks(withMediaType: .audio).first,
               let audioTrack = compositionAudioTrack {
                try audioTrack.insertTimeRange(timeRange, of: slateAudioTrack, at: insertTime)
            }
            insertTime = CMTimeAdd(insertTime, timeRange.duration)
        }

        for take in finalSelectTakes {
            let asset = take.asset
            let videoTracks = try await asset.loadTracks(withMediaType: .video)
            let audioTracks = try await asset.loadTracks(withMediaType: .audio)

            var insertedVideoRange600: CMTimeRange? = nil

            if let assetVideoTrack = videoTracks.first {
                let assetDuration = try await asset.load(.duration)
                let srcVideoTR = try await assetVideoTrack.load(.timeRange)
                let baseDur = CMTimeMinimum(assetDuration, srcVideoTR.duration)
                var requestedTR = take.trimRange ?? CMTimeRange(start: srcVideoTR.start, duration: baseDur)
                requestedTR = clamped(requestedTR, to: srcVideoTR)
                let timeRange600 = r600(requestedTR)
                insertedVideoRange600 = timeRange600
#if DEBUG
                let assetAudioTrack = audioTracks.first
                let audioDur = (try? await assetAudioTrack?.load(.timeRange).duration.seconds) ?? 0
                let audioFmt = await describeAudioFormat(assetAudioTrack)
                let videoDur = srcVideoTR.duration.seconds
                let fps: Float
                if #available(iOS 16.0, *) {
                    fps = (try? await assetVideoTrack.load(.nominalFrameRate)) ?? 0
                } else {
                    fps = 0
                }
                print("⏱️ [ExportDur] file=\(take.fileName) asset=\(assetDuration.seconds)s video=\(videoDur)s audio=\(audioDur)s nominalFPS=\(fps) audioFmt=\(audioFmt)")
                print("⏱️ [ExportInsert] file=\(take.fileName) insertAt=\(insertTime.seconds)s insertRange=\(timeRange600.start.seconds)s..\((timeRange600.start + timeRange600.duration).seconds)s dur=\(timeRange600.duration.seconds)s")
#endif
                try videoTrack.insertTimeRange(timeRange600, of: assetVideoTrack, at: t600(insertTime))

                let hasMeaningfulCrop = take.cropRect?.sts_hasMeaningfulCrop ?? false
                let hasRotation = (take.cropRotationDegrees.map { abs($0) > 0.01 } ?? false)
                let naturalSize = (try? await assetVideoTrack.load(.naturalSize)) ?? .zero
                let preferredTransform = (try? await assetVideoTrack.load(.preferredTransform)) ?? .identity
                let needsOrientationNormalization = !preferredTransform.isIdentity

                let shouldCreateInstruction = hasMeaningfulCrop || hasRotation || needsOrientationNormalization
                anySegmentNeedsInstruction = anySegmentNeedsInstruction || shouldCreateInstruction

#if DEBUG
                let createdInstructionPreview = shouldCreateInstruction
                print("🎞️ [SessionExport] seg \(take.fileName) natural=\(naturalSize) preferred=\(preferredTransform) instruction=\(createdInstructionPreview) render=\(resolvedRenderSize)")
                print("🎞️ [SessionExport] insert trackIDs src=\(assetVideoTrack.trackID) comp=\(videoTrack.trackID) timeRange=\(timeRange600) at=\(insertTime)")
#endif

                segmentEntries.append((
                    start: insertTime,
                    duration: timeRange600.duration,
                    sourceTrack: assetVideoTrack,
                    cropRect: take.cropRect ?? .stsNormalizedFullFrame,
                    rotationDegrees: take.cropRotationDegrees ?? 0,
                    needsInstruction: shouldCreateInstruction
                ))
            }

            if options.includeAudio,
               let assetAudioTrack = audioTracks.first,
               let audioTrack = compositionAudioTrack,
               let videoRange600 = insertedVideoRange600 {
                let srcAudioTR = try await assetAudioTrack.load(.timeRange)
                let requestedAudioTR = CMTimeRange(
                    start: CMTimeConvertScale(videoRange600.start, timescale: srcAudioTR.start.timescale, method: .default),
                    duration: CMTimeConvertScale(videoRange600.duration, timescale: srcAudioTR.duration.timescale, method: .default)
                )
                let audioTR = clamped(requestedAudioTR, to: srcAudioTR)
                let timeRange = r600(audioTR)
                if timeRange.duration > .zero {
                    try audioTrack.insertTimeRange(timeRange, of: assetAudioTrack, at: t600(insertTime))
                } else {
                    print("🔇 [ExportAudio] skip insert — requested=\(audioTR.start.seconds)–\((audioTR.start + audioTR.duration).seconds) srcAudio=\(srcAudioTR.start.seconds)–\((srcAudioTR.start + srcAudioTR.duration).seconds)")
                }
            }

            if let videoRange600 = insertedVideoRange600 {
                insertTime = CMTimeAdd(insertTime, videoRange600.duration)
            }
        }

        let videoComposition: AVMutableVideoComposition?
        if enableFullInstructionCoverage && (anySegmentNeedsInstruction || !videoInstructions.isEmpty) {
            videoInstructions = []
            for entry in segmentEntries {
                let timeRange = CMTimeRange(start: entry.start, duration: entry.duration)
                if entry.needsInstruction {
                    let instruction = try await createCropInstruction(
                        compositionTrack: videoTrack,
                        sourceTrack: entry.sourceTrack,
                        cropRect: entry.cropRect,
                        rotationDegrees: entry.rotationDegrees,
                        timeRange: timeRange,
                        renderSize: resolvedRenderSize
                    )
                    videoInstructions.append(instruction)
                } else {
                    let instruction = createIdentityInstruction(
                        compositionTrack: videoTrack,
                        timeRange: timeRange
                    )
                    videoInstructions.append(instruction)
                }
            }
        }

        if videoInstructions.isEmpty {
            videoComposition = nil
        } else {
            let vc = AVMutableVideoComposition()
            vc.instructions = videoInstructions
            vc.frameDuration = CMTime(value: 1, timescale: 30)
            vc.renderSize = resolvedRenderSize
            videoComposition = vc
        }

#if DEBUG
        let totalDuration = composition.duration
        print("🎞️ [SessionExport] build summary instructions=\(videoInstructions.count) renderSize=\(resolvedRenderSize) frameDuration=\(videoComposition?.frameDuration ?? .invalid) totalDuration=\(totalDuration)")
        for (idx, instr) in videoInstructions.enumerated() {
            let start = instr.timeRange.start.seconds
            let end = (instr.timeRange.start + instr.timeRange.duration).seconds
            print("🎞️ [SessionExport] instruction[\(idx)] range=\(start)..\(end) dur=\(instr.timeRange.duration.seconds) layers=\(instr.layerInstructions.count)")
        }
#endif

        let outputURL = createOutputURL(fileName: outputFileName, format: options.format)

        var metadata = thumbnailMetadata
        metadata.append(makeExportVersionMetadata())

        var presetName = profile.bestPreset(for: composition)
#if DEBUG
        let debugForcedPreset: String? = nil // e.g., AVAssetExportPresetHighestQuality for experiments
        if let forced = debugForcedPreset {
            presetName = forced
            print("🔬 [SessionExport] DEBUG forcing presetName=\(forced)")
        } else {
            print("🔬 [SessionExport] presetName=\(presetName)")
        }
#endif

        let plan = ExportPlan(
            asset: composition,
            videoComposition: videoComposition,
            audioMix: nil,
            outputURL: outputURL,
            presetName: presetName,
            outputFileType: options.format.fileType,
            timeRange: nil,
            metadata: metadata
        )

        let diagnosticRun = OrientationPolicy.createRun(context: "Export", smartfillMode: "none")
        OrientationDiag.logRunStart(diagnosticRun)

        return ExportContext(plan: plan, diagnosticRun: diagnosticRun)
    }

    private static func convertSlatePhotoToVideoAsync(_ image: UIImage, duration: TimeInterval) async throws -> AVAsset {
        try await withCheckedThrowingContinuation { continuation in
            convertSlatePhotoToVideo(image, duration: duration) { result in
                continuation.resume(with: result)
            }
        }
    }

    private static func generatePIPSlateURLIfNeeded(
        from pipSlateSession: SlatePIPSession?,
        includeSlate: Bool
    ) async throws -> URL? {
        guard includeSlate,
              let pipSlateSession,
              let portrait = pipSlateSession.selectedPortraitTake,
              let landscape = pipSlateSession.selectedLandscapeTake else {
            return nil
        }

        let portraitURL = portrait.fileURL
        let landscapeURL = landscape.fileURL
        guard FileManager.default.fileExists(atPath: portraitURL.path),
              FileManager.default.fileExists(atPath: landscapeURL.path) else {
            return nil
        }

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("pip_slate_\(UUID().uuidString).mp4")

        return try await withCheckedThrowingContinuation { continuation in
            PIPSlateExporter.exportPIPSlate(
                pipSession: pipSlateSession,
                portraitURL: portraitURL,
                landscapeURL: landscapeURL,
                outputURL: outputURL
            ) { result in
                continuation.resume(with: result.mapError { error in
                    SessionExportError.pipSlateGenerationFailed(error.localizedDescription)
                })
            }
        }
    }

    private static func makeKeyframeIntroAsset(
        photoURL: URL,
        renderSize: CGSize
    ) async throws -> AVURLAsset? {
        guard FileManager.default.fileExists(atPath: photoURL.path) else {
            return nil
        }

        let clipURL = try await KeyframeIntroClipBuilder.buildIntroClip(
            from: photoURL,
            renderSize: renderSize,
            duration: 0.01
        )
        return AVURLAsset(url: clipURL)
    }

    private static func makeExportVersionMetadata(version: Int = 2) -> AVMetadataItem {
        let metadataItem = AVMutableMetadataItem()
        metadataItem.keySpace = .common
        metadataItem.key = AVMetadataKey.commonKeyDescription as (NSCopying & NSSecureCoding & NSObjectProtocol)
        metadataItem.value = "STSExportVersion=\(version) Generated=\(Date().timeIntervalSince1970)" as (NSCopying & NSSecureCoding & NSObjectProtocol)
        return metadataItem
    }

    private static func createCropInstruction(
        compositionTrack: AVCompositionTrack,
        sourceTrack: AVAssetTrack,
        cropRect: CGRect,
        rotationDegrees: Double,
        timeRange: CMTimeRange,
        renderSize: CGSize
    ) async throws -> AVMutableVideoCompositionInstruction {
        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = timeRange

        let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: compositionTrack)

        let naturalSize = try await sourceTrack.load(.naturalSize)
        _ = try await sourceTrack.load(.preferredTransform)
#if DEBUG
        print("🎬 [SessionExport] layerInstruction target type=\(type(of: compositionTrack)) trackID=\(compositionTrack.trackID) sourceTrackID=\(sourceTrack.trackID) timeRange=\(timeRange)")
#endif
        let baseTransform = await NormalizeOrientation.centeredAspectFitTransform(
            for: sourceTrack,
            renderSize: renderSize
        )

        var finalTransform = baseTransform

        let rotationRadians = rotationDegrees * (.pi / 180)
        if abs(rotationRadians) > 0.0001 {
            let center = CGPoint(x: renderSize.width / 2, y: renderSize.height / 2)
            let rotationTransform = CGAffineTransform(translationX: center.x, y: center.y)
                .rotated(by: rotationRadians)
                .translatedBy(x: -center.x, y: -center.y)
            finalTransform = finalTransform.concatenating(rotationTransform)
        }

        if cropRect.width > 0, cropRect.height > 0 {
            let cropScaleX = 1.0 / cropRect.width
            let cropScaleY = 1.0 / cropRect.height
            let cropTranslateX = -cropRect.origin.x * cropScaleX
            let cropTranslateY = -cropRect.origin.y * cropScaleY

            let cropTransform = CGAffineTransform(scaleX: cropScaleX, y: cropScaleY)
                .translatedBy(x: cropTranslateX, y: cropTranslateY)

            finalTransform = finalTransform.concatenating(cropTransform)
        }

        layerInstruction.setTransform(finalTransform, at: timeRange.start)
        instruction.layerInstructions = [layerInstruction]

#if DEBUG
        let rect = CGRect(origin: .zero, size: naturalSize).applying(finalTransform)
        print("🔬 [SessionExport] fitted rect=\(rect) renderSize=\(renderSize)")
#endif
        return instruction
    }

    private static func createIdentityInstruction(
        compositionTrack: AVCompositionTrack,
        timeRange: CMTimeRange
    ) -> AVMutableVideoCompositionInstruction {
        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = timeRange
        let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: compositionTrack)
        layerInstruction.setTransform(.identity, at: timeRange.start)
        instruction.layerInstructions = [layerInstruction]
        return instruction
    }

    private static func createOutputURL(fileName: String, format: ExportFormat) -> URL {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let exportsDirectory = documentsURL.appendingPathComponent("STS_Exports")
        try? FileManager.default.createDirectory(at: exportsDirectory, withIntermediateDirectories: true)

        let sanitizedName = (fileName as NSString).deletingPathExtension
        let finalName = "\(sanitizedName).\(format.fileExtension)"
        let outputURL = exportsDirectory.appendingPathComponent(finalName)

        try? FileManager.default.removeItem(at: outputURL)
        return outputURL
    }

    enum ExportFormat: String, CaseIterable, Sendable {
        case mov = "MOV"
        case mp4 = "MP4"

        var fileType: AVFileType {
            switch self {
            case .mov: return .mov
            case .mp4: return .mp4
            }
        }

        var fileExtension: String {
            rawValue.lowercased()
        }
    }

    // ENHANCED: Clean export options without SmartFill contamination
    struct ExportOptions: Sendable {
        let quality: ExportQuality
        let format: ExportFormat
        let includeSlate: Bool
        let slateDuration: TimeInterval
        let includeAudio: Bool
        let renderSize: CGSize

        static let defaultOptions = ExportOptions(
            quality: .high,
            format: .mov,
            includeSlate: true,
            slateDuration: 2.0,
            includeAudio: true,
            renderSize: CGSize(width: 1920, height: 1080)
        )

        init(quality: ExportQuality = .high,
             format: ExportFormat = .mov,
             includeSlate: Bool = true,
             slateDuration: TimeInterval = 2.0,
             includeAudio: Bool = true,
             renderSize: CGSize = CGSize(width: 1920, height: 1080)) {
            self.quality = quality
            self.format = format
            self.includeSlate = includeSlate
            self.slateDuration = slateDuration
            self.includeAudio = includeAudio
            self.renderSize = renderSize
        }
    }

    private struct ExportContext {
        let plan: ExportPlan
        let diagnosticRun: OrientationRun
    }

enum SessionExportError: LocalizedError {
        case noFinalSelectTakes
        case compositionFailed
        case slateConversionFailed
        case exportFailed(String)
        case assetCreationFailed
        case pipSlateGenerationFailed(String)

        var errorDescription: String? {
            switch self {
            case .noFinalSelectTakes:
                return "No final select takes found to export."
            case .compositionFailed:
                return "Failed to create video composition."
            case .slateConversionFailed:
                return "Failed to convert slate photo to video."
            case .exportFailed(let reason):
                return "Export failed: \(reason)"
            case .assetCreationFailed:
                return "Failed to create video asset."
            case .pipSlateGenerationFailed(let reason):
                return "Failed to build Picture-in-Picture slate: \(reason)"
            }
        }
    }

    // ENHANCED: Clean TakeMetadata without SmartFill properties
    struct TakeMetadata: @unchecked Sendable {
        let asset: AVAsset
        let isFinalSelect: Bool
        let trimRange: CMTimeRange?
        let cropRect: CGRect?
        let cropRotationDegrees: Double?
        let isSlatePhoto: Bool
        let thumbnailImage: UIImage? // for slate/first frame (photo attach)
        let takeNumber: Int
        let fileName: String

        // Optional tie-in to your models (left as-is for your project)
        let projectTake: ProjectTake?

        init(asset: AVAsset,
             isFinalSelect: Bool,
             trimRange: CMTimeRange? = nil,
             cropRect: CGRect? = nil,
             cropRotationDegrees: Double? = nil,
             isSlatePhoto: Bool = false,
             thumbnailImage: UIImage? = nil,
             takeNumber: Int = 1,
             fileName: String = "take.mov",
             projectTake: ProjectTake? = nil) {
            self.asset = asset
            self.isFinalSelect = isFinalSelect
            self.trimRange = trimRange
            self.cropRect = cropRect
            self.cropRotationDegrees = cropRotationDegrees
            self.isSlatePhoto = isSlatePhoto
            self.thumbnailImage = thumbnailImage
            self.takeNumber = takeNumber
            self.fileName = fileName
            self.projectTake = projectTake
        }
    }

    // MARK: - ENHANCED Professional Slate Photo to Video Conversion

    /// Converts a UIImage into a temporary AVAsset representing a still-frame video of given duration.
    /// ENHANCED: H.264 encoding, 30 fps, and robust error handling.
    private static func convertSlatePhotoToVideo(
        _ image: UIImage,
        duration: TimeInterval = 2.0,
        completion: @escaping (Result<AVAsset, SessionExportError>) -> Void
    ) {
        print("📸 Converting slate photo to video (duration: \(duration)s)")

        let size = image.size
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("STS_Slate_\(UUID().uuidString).mov")

        // Clean up any existing temp file
        try? FileManager.default.removeItem(at: outputURL)

        guard let writer = try? AVAssetWriter(outputURL: outputURL, fileType: .mov) else {
            print("❌ Failed to create AVAssetWriter")
            completion(.failure(.slateConversionFailed))
            return
        }

        // ENHANCED: H.264 settings
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: Int(size.width),
            AVVideoHeightKey: Int(size.height),
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: 2_000_000,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel
            ]
        ]

        let writerInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        writerInput.expectsMediaDataInRealTime = false

        let pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: writerInput,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
                kCVPixelBufferWidthKey as String: Int(size.width),
                kCVPixelBufferHeightKey as String: Int(size.height)
            ]
        )

        guard writer.canAdd(writerInput) else {
            print("❌ Cannot add video input to writer")
            completion(.failure(.slateConversionFailed))
            return
        }

        writer.add(writerInput)

        guard writer.startWriting() else {
            print("❌ Failed to start writing")
            completion(.failure(.slateConversionFailed))
            return
        }

        writer.startSession(atSourceTime: .zero)
        let processingQueue = DispatchQueue(label: "slate-conversion", qos: .userInitiated)

        writerInput.requestMediaDataWhenReady(on: processingQueue) { [weak writerInput, weak writer] in
            guard let writerInput = writerInput, let writer = writer else { return }
            guard let cgImage = image.cgImage else {
                print("❌ Failed to get CGImage from UIImage")
                writerInput.markAsFinished()
                writer.finishWriting {
                    completion(.failure(.slateConversionFailed))
                }
                return
            }

            guard let pixelBuffer = createPixelBufferFromCGImage(cgImage, size: size) else {
                print("❌ Failed to create pixel buffer")
                writerInput.markAsFinished()
                writer.finishWriting {
                    completion(.failure(.slateConversionFailed))
                }
                return
            }

            let totalFrames = max(1, Int(duration * 30)) // 30fps
            print("🎬 Generating \(totalFrames) frames at 30fps")

            for frameNumber in 0..<totalFrames {
                let frameTime = CMTime(value: CMTimeValue(frameNumber), timescale: 30)

                while !writerInput.isReadyForMoreMediaData {
                    Thread.sleep(forTimeInterval: 0.005)
                }

                if !pixelBufferAdaptor.append(pixelBuffer, withPresentationTime: frameTime) {
                    print("❌ Failed to append pixel buffer at frame \(frameNumber)")
                    writerInput.markAsFinished()
                    writer.finishWriting {
                        completion(.failure(.slateConversionFailed))
                    }
                    return
                }
            }

            writerInput.markAsFinished()
            writer.finishWriting {
                if writer.status == .completed {
                    let asset = AVURLAsset(url: outputURL)
                    Task {
                        do {
                            _ = try await asset.load(.duration)
                            print("✅ Slate video created at \(outputURL.lastPathComponent)")
                            completion(.success(asset))
                        } catch {
                            print("❌ Failed to load slate video duration: \(error)")
                            completion(.failure(.slateConversionFailed))
                        }
                    }
                } else {
                    print("❌ Writer failed with error: \(writer.error?.localizedDescription ?? "Unknown")")
                    completion(.failure(.slateConversionFailed))
                }
            }
        }
    }

    /// ENHANCED: High-quality pixel buffer creation from CGImage
    nonisolated private static func createPixelBufferFromCGImage(_ cgImage: CGImage, size: CGSize) -> CVPixelBuffer? {
#if DEBUG
        if size.width <= 0 || size.height <= 0 {
            print("🧪 CGContext[SessionExportManager.createPixelBuffer] invalid size=\(size) cgImage=\(cgImage.width)x\(cgImage.height)")
        }
#endif
        let options: [CFString: Any] = [
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true,
            kCVPixelBufferIOSurfacePropertiesKey: [:]
        ]

        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            Int(size.width),
            Int(size.height),
            kCVPixelFormatType_32ARGB,
            options as CFDictionary,
            &pixelBuffer
        )

        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            print("❌ CVPixelBufferCreate failed with status: \(status)")
            return nil
        }

        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }

        guard let context = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer),
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
        ) else {
            print("❌ Failed to create CGContext")
            return nil
        }

        context.draw(cgImage, in: CGRect(origin: .zero, size: size))
        return buffer
    }

    // MARK: - Enhanced Export Methods (CLEAN: SmartFill handled elsewhere)

    /// Export a merged audition video from final select takes and optional slate
    /// ENHANCED: Clean export without SmartFill contamination
    static func cancelCurrentExport() {
        Task { @MainActor in
            shared.cancelCurrentExportInternal()
        }
    }

    static func exportMergedAudition(
        from takes: [TakeMetadata],
        outputFileName: String = "MergedAudition.mov",
        options: ExportOptions = .defaultOptions,
        pipSlateSession: SlatePIPSession? = nil,
        thumbnailMetadata: [AVMetadataItem] = [],
        keyframePhotoURL: URL? = nil,
        progressHandler: ((Float) -> Void)? = nil,
        stageHandler: ((ExportStage) -> Void)? = nil,
        completion: @escaping (Result<URL, SessionExportError>) -> Void
    ) {
        Task { @MainActor in
            await shared.exportMergedAuditionInternal(
                takes: takes,
                outputFileName: outputFileName,
                options: options,
                pipSlateSession: pipSlateSession,
                thumbnailMetadata: thumbnailMetadata,
                keyframePhotoURL: keyframePhotoURL,
                progressHandler: progressHandler,
                stageHandler: stageHandler,
                completion: completion
            )
        }
    }

    private func exportMergedAuditionInternal(
        takes: [TakeMetadata],
        outputFileName: String,
        options: ExportOptions,
        pipSlateSession: SlatePIPSession?,
        thumbnailMetadata: [AVMetadataItem],
        keyframePhotoURL: URL?,
        progressHandler: ((Float) -> Void)?,
        stageHandler: ((ExportStage) -> Void)? = nil,
        completion: @escaping (Result<URL, SessionExportError>) -> Void
    ) async {
        print("🎬 Starting enhanced export")
        print("📋 Export options: \(options.quality.rawValue) quality, \(options.format.rawValue) format")
        stageHandler?(.preparingAssets)
        stageHandler?(.preparingAssets)

        currentTask?.cancel()
        currentCancellation?.cancel()

        let cancellationToken = CancellationToken()
        currentCancellation = cancellationToken

        currentTask = Task.detached { [weak self] in
            guard let self else { return }
            do {

                if options.includeSlate || pipSlateSession != nil {
                    stageHandler?(.renderingSlate)
                }

                let exportContext = try await Self.buildExportContext(
                    takes: takes,
                    options: options,
                    thumbnailMetadata: thumbnailMetadata,
                    outputFileName: outputFileName,
                    pipSlateSession: pipSlateSession,
                    keyframePhotoURL: keyframePhotoURL
                )

                stageHandler?(.buildingTimeline)

                let plan = exportContext.plan
                let diagnosticRun = exportContext.diagnosticRun

                print("🎯 SessionExport: Using preset \(plan.presetName) -> \(plan.outputFileType.rawValue)")
                stageHandler?(.encodingVideo)

                do {
                    let url = try await self.exportActor.export(
                        plan: plan,
                        options: SessionExportActorOptions(progressIntervalMilliseconds: 250),
                        progress: { value in
                            Task { @MainActor in
                                progressHandler?(Float(value))
                            }
                        },
                        cancellationToken: cancellationToken
                    )
                    
                    if let metrics = try? await SourceAnalysis(asset: AVURLAsset(url: url)) {
                        print("📊 SessionExport: Output \(url.lastPathComponent) \(Int(metrics.dimensions.width))x\(Int(metrics.dimensions.height)) @\(String(format: "%.1f", metrics.fps))fps ~\(ByteCountFormatter.string(fromByteCount: Int64(metrics.estimatedBitrate / 8.0), countStyle: .file))/s")
                    }

                    OrientationDiag.logTransform(
                        diagnosticRun,
                        stage: "Compositor",
                        desc: "Session export with video composition",
                        notes: "SessionExportManager using video composition for transforms"
                    )

                   OrientationPolicy.shared.validateSingleTransformRule(
                       run: diagnosticRun,
                       expectedStage: "Compositor"
                   )

                   await MainActor.run {
                       completion(.success(url))
                        self.currentTask = nil
                        self.currentCancellation = nil
                    }
                    
                } catch is CancellationError {
                    await MainActor.run {
                        completion(.failure(.exportFailed("Export cancelled")))
                        self.currentTask = nil
                        self.currentCancellation = nil
                    }
                    
                } catch let actorError as SessionExportActorError {
                    await MainActor.run {
                        let message: String
                        switch actorError {
                        case .cannotCreateSession:
                            message = "Unable to create export session"
                        case .failed(let status):
                            message = "Export failed with status: \(status.rawValue)"
                        }
                        completion(.failure(.exportFailed(message)))
                        self.currentTask = nil
                        self.currentCancellation = nil
                    }
                    
                } catch {
                    print("❌ Export failed: \(error)")
                    await MainActor.run {
                        completion(.failure(.exportFailed(error.localizedDescription)))
                        self.currentTask = nil
                        self.currentCancellation = nil
                    }
                    
                }

            } catch {
                print("❌ Export failed during preparation: \(error)")
                await MainActor.run {
                    if let exportError = error as? SessionExportError {
                        completion(.failure(exportError))
                    } else {
                        completion(.failure(.exportFailed(error.localizedDescription)))
                    }
                    self.currentTask = nil
                    self.currentCancellation = nil
                }
                
            }
        }
    }

    private func cancelCurrentExportInternal() {
        currentTask?.cancel()
        currentCancellation?.cancel()
        currentTask = nil
        currentCancellation = nil
    }

    private static func getFinalSelectTakesCount(from takes: [TakeMetadata]) -> Int {
        takes.filter { $0.isFinalSelect }.count
    }

    private static func getTotalDuration(
        from takes: [TakeMetadata],
        includeSlate: Bool,
        slateDuration: TimeInterval
    ) async -> TimeInterval {
        var total: TimeInterval = 0

        if includeSlate && takes.contains(where: { $0.isSlatePhoto && $0.thumbnailImage != nil }) {
            total += slateDuration
        }

        for take in takes where take.isFinalSelect {
            do {
                let assetDuration = try await take.asset.load(.duration)
                if let trim = take.trimRange {
                    total += trim.duration.seconds
                } else {
                    total += assetDuration.seconds
                }
            } catch {
                print("⚠️ SessionExportManager: Failed to load duration for \(take.fileName): \(error)")
            }
        }

        return total
    }

    /// Preview export information (UPDATED: Async version)
    static func getExportPreview(from takes: [TakeMetadata],
                                 options: ExportOptions = .defaultOptions) async
    -> (finalSelectTakes: Int, totalDuration: TimeInterval, hasSlate: Bool) {
        let finalSelectTakesCount = getFinalSelectTakesCount(from: takes)
        let totalDuration = await getTotalDuration(from: takes,
                                                   includeSlate: options.includeSlate,
                                                   slateDuration: options.slateDuration)
        let hasSlate = takes.contains { $0.isSlatePhoto && $0.thumbnailImage != nil }
        return (finalSelectTakesCount, totalDuration, hasSlate)
    }
}

// MARK: - Export Stages (for UI)
enum ExportStage: Equatable {
    case preparingAssets
    case renderingSlate
    case buildingTimeline
    case encodingVideo
    case finalizingFile

    var displayTitle: String {
        switch self {
        case .preparingAssets:
            return "Preparing your footage…"
        case .renderingSlate:
            return "Building your slate…"
        case .buildingTimeline:
            return "Arranging your best take…"
        case .encodingVideo:
            return "Mastering your video…"
        case .finalizingFile:
            return "Wrapping up your tape…"
        }
    }
}
