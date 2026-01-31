import AVFoundation
import CoreGraphics

enum PIPSlateExporterError: Error {
    case missingVideoTracks
    case exportFailed(String)
}

enum PIPSlateExporter {

    // Common video-friendly grid (divisible by 30/60) to avoid audio-timescale drift.
    private static let pipVideoTimescale: CMTimeScale = 600
    private static let pipFrameDuration = CMTime(value: Int64(pipVideoTimescale / 30), timescale: pipVideoTimescale) // 1/30s

    private static func toVideoTime(_ t: CMTime) -> CMTime {
        CMTimeConvertScale(t, timescale: pipVideoTimescale, method: .roundTowardZero)
    }

    private static func quantizeDownToFrameGrid(_ t: CMTime) -> CMTime {
        let frames = Int64((t.seconds / pipFrameDuration.seconds).rounded(.down))
        let safeFrames = max(frames, 0)
        return CMTimeMultiply(pipFrameDuration, multiplier: Int32(safeFrames))
    }

    private static func generateCGImage(
        using generator: AVAssetImageGenerator,
        at time: CMTime
    ) async throws -> (CGImage, CMTime) {
        try await withCheckedThrowingContinuation { continuation in
            generator.generateCGImageAsynchronously(for: time) { image, actual, error in
                if let image {
                    continuation.resume(returning: (image, actual))
                } else {
                    let nsError = error ?? NSError(
                        domain: "PIPSlateExporter",
                        code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "generateCGImageAsynchronously returned nil image at \(time.seconds)s"]
                    )
                    continuation.resume(throwing: nsError)
                }
            }
        }
    }

    private static func toVideoRange(start: CMTime = .zero, duration: CMTime) -> CMTimeRange {
        CMTimeRange(start: toVideoTime(start), duration: toVideoTime(duration))
    }

    /// Public entry point used by the app.
    static func exportPIPSlate(
        pipSession: SlatePIPSession,
        portraitURL: URL,
        landscapeURL: URL,
        outputURL: URL,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        Task {
            do {
                let url = try await exportPIPSlateAsync(
                    pipSession: pipSession,
                    portraitURL: portraitURL,
                    landscapeURL: landscapeURL,
                    outputURL: outputURL
                )
                completion(.success(url))
            } catch {
                completion(.failure(error))
            }
        }
    }

    // MARK: - Core Async Export

    private static func exportPIPSlateAsync(
        pipSession: SlatePIPSession,
        portraitURL: URL,
        landscapeURL: URL,
        outputURL: URL
    ) async throws -> URL {

        // Remove any previous file at the output location.
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: outputURL.path) {
            try fileManager.removeItem(at: outputURL)
        }

        let portraitAsset = AVURLAsset(url: portraitURL)
        let landscapeAsset = AVURLAsset(url: landscapeURL)

        let portraitVideoTracks = try await portraitAsset.loadTracks(withMediaType: .video)
        let landscapeVideoTracks = try await landscapeAsset.loadTracks(withMediaType: .video)

        guard let portraitVideoTrack = portraitVideoTracks.first else {
            throw PIPSlateExporterError.missingVideoTracks
        }
        guard let landscapeVideoTrack = landscapeVideoTracks.first else {
            throw PIPSlateExporterError.missingVideoTracks
        }

        let portraitFormats = try await portraitVideoTrack.load(.formatDescriptions)
        let portraitFPS = try await portraitVideoTrack.load(.nominalFrameRate)
        let portraitNaturalSize = try await portraitVideoTrack.load(.naturalSize)
        let portraitMinFrameDuration = try await portraitVideoTrack.load(.minFrameDuration)
        let landscapeFormats = try await landscapeVideoTrack.load(.formatDescriptions)
        let landscapeFPS = try await landscapeVideoTrack.load(.nominalFrameRate)
        let landscapeNaturalSize = try await landscapeVideoTrack.load(.naturalSize)
        let landscapeMinFrameDuration = try await landscapeVideoTrack.load(.minFrameDuration)

        print("🎥 PiP portrait track: formatDescriptions=\(portraitFormats), nominalFPS=\(portraitFPS), naturalSize=\(portraitNaturalSize)")
        print("🎥 PiP landscape track: formatDescriptions=\(landscapeFormats), nominalFPS=\(landscapeFPS), naturalSize=\(landscapeNaturalSize)")
        print("🧪 PIP portrait timing: minFrameDuration=\(portraitMinFrameDuration.seconds)s")
        print("🧪 PIP landscape timing: minFrameDuration=\(landscapeMinFrameDuration.seconds)s")

        let portraitGeometry = try await trackGeometry(for: portraitVideoTrack)
        let landscapeGeometry = try await trackGeometry(for: landscapeVideoTrack)

        print("🎬 PIPSlateExporter: portrait asset=\(portraitURL.lastPathComponent)")
        print("🎬 PIPSlateExporter: landscape asset=\(landscapeURL.lastPathComponent)")
        print("🎬 PIPSlateExporter: portrait naturalSize=\(portraitGeometry.naturalSize) preferredTransform=\(portraitGeometry.preferredTransform)")
        print("🎬 PIPSlateExporter: landscape naturalSize=\(landscapeGeometry.naturalSize) preferredTransform=\(landscapeGeometry.preferredTransform)")

        // Drive durations from the video tracks themselves (avoid audio-driven durations).
        let portraitVideoTimeRange = try await portraitVideoTrack.load(.timeRange)
        let landscapeVideoTimeRange = try await landscapeVideoTrack.load(.timeRange)
        let portraitDurationRaw = portraitVideoTimeRange.duration
        let landscapeDurationRaw = landscapeVideoTimeRange.duration

        // Convert to a video-friendly timebase (avoid 48k audio timescale drift)
        let portraitDuration = quantizeDownToFrameGrid(toVideoTime(portraitDurationRaw))
        let landscapeDuration = quantizeDownToFrameGrid(toVideoTime(landscapeDurationRaw))
        print("🧪 PIP portrait duration raw=\(portraitDurationRaw.seconds)s ts=\(portraitDurationRaw.timescale) quantized=\(portraitDuration.seconds)s ts=\(portraitDuration.timescale)")
        print("🧪 PIP landscape duration raw=\(landscapeDurationRaw.seconds)s ts=\(landscapeDurationRaw.timescale) quantized=\(landscapeDuration.seconds)s ts=\(landscapeDuration.timescale)")

        // ✅ Landscape (close-up) defines the full timeline; portrait plays once and freezes if shorter.
        let targetDuration = landscapeDuration
        let portraitPlayDuration = min(portraitDuration, landscapeDuration)
        print("⏱ PIPSlateExporter: portraitDuration=\(portraitDuration.seconds)s landscapeDuration=\(landscapeDuration.seconds)s compositionDuration=\(targetDuration.seconds)s (driven by landscape)")

        // MARK: Composition

        let composition = AVMutableComposition()

        guard
            let portraitCompTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid),
            let landscapeCompTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
        else {
            throw PIPSlateExporterError.exportFailed("Could not create composition video tracks")
        }

        let timeRange = toVideoRange(duration: targetDuration)
        print("🎬 PiP composition duration=\(targetDuration.seconds), timescale=\(targetDuration.timescale)")

        do {
            // Landscape: single pass defines duration.
            try landscapeCompTrack.insertTimeRange(timeRange, of: landscapeVideoTrack, at: .zero)
            // Portrait: play once (trim if longer).
            let portraitRange = CMTimeRange(start: .zero, duration: portraitPlayDuration)
            try portraitCompTrack.insertTimeRange(portraitRange, of: portraitVideoTrack, at: .zero)
        } catch {
            throw PIPSlateExporterError.exportFailed("Failed inserting video time ranges: \(error)")
        }

        // MARK: Audio mixing (simple but honors mute flags)

        // Landscape audio (close-up)
        if !pipSession.landscapeAudioMuted,
           let landscapeCompAudio = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) {
            do {
                let audioTracks = try await landscapeAsset.loadTracks(withMediaType: .audio)
                if let landscapeAudioTrack = audioTracks.first {
                    try landscapeCompAudio.insertTimeRange(timeRange, of: landscapeAudioTrack, at: .zero)
                    print("🔊 PIPSlateExporter: Included landscape audio (single-pass)")
                } else {
                    composition.removeTrack(landscapeCompAudio)
                }
            } catch {
                composition.removeTrack(landscapeCompAudio)
                print("⚠️ PIPSlateExporter: Failed to insert landscape audio: \(error)")
            }
        }

        // Portrait audio (full body)
        if !pipSession.portraitAudioMuted,
           let portraitCompAudio = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) {
            do {
                let audioTracks = try await portraitAsset.loadTracks(withMediaType: .audio)
                if let portraitAudioTrack = audioTracks.first {
                    let audioRange = CMTimeRange(start: .zero, duration: portraitPlayDuration)
                    try portraitCompAudio.insertTimeRange(audioRange, of: portraitAudioTrack, at: .zero)
                    print("🔊 PIPSlateExporter: Included portrait audio (trimmed to portrait duration)")
                } else {
                    composition.removeTrack(portraitCompAudio)
                }
            } catch {
                composition.removeTrack(portraitCompAudio)
                print("⚠️ PIPSlateExporter: Failed to insert portrait audio: \(error)")
            }
        }

        // MARK: Video Composition (PiP layout)

        // Render size follows oriented landscape track for exact sizing.
        let landscapeRect = orientedRect(for: landscapeGeometry.naturalSize, preferredTransform: landscapeGeometry.preferredTransform)
        let renderSize = CGSize(width: abs(landscapeRect.width), height: abs(landscapeRect.height))

        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = timeRange

        let landscapeLayer = AVMutableVideoCompositionLayerInstruction(assetTrack: landscapeCompTrack)
        let portraitLayer = AVMutableVideoCompositionLayerInstruction(assetTrack: portraitCompTrack)

        let bgTransform = pipTransform(
            preferredTransform: landscapeGeometry.preferredTransform,
            naturalSize: landscapeGeometry.naturalSize,
            renderSize: renderSize,
            placeOnRightSide: false
        )
        let fgTransform = pipTransform(
            preferredTransform: portraitGeometry.preferredTransform,
            naturalSize: portraitGeometry.naturalSize,
            renderSize: renderSize,
            placeOnRightSide: true
        )

        landscapeLayer.setTransform(bgTransform, at: .zero)
        portraitLayer.setTransform(fgTransform, at: .zero)

        landscapeLayer.setOpacity(1.0, at: .zero)
        portraitLayer.setOpacity(1.0, at: .zero)

        // Ensure portrait overlay renders on top of the landscape background.
        instruction.layerInstructions = [portraitLayer, landscapeLayer]

        let videoComposition = AVMutableVideoComposition()
        videoComposition.renderSize = renderSize
        videoComposition.frameDuration = pipFrameDuration
        videoComposition.instructions = [instruction]
        print("🎬 PIPSlateExporter: using single instruction covering 0–\(targetDuration.seconds)s with portrait+landscape layers")

        // If portrait ends before landscape, freeze its last frame as a still overlay until the end.
        if portraitPlayDuration < targetDuration {
            let eps = pipFrameDuration
            let lastFrameTime = max(.zero, portraitPlayDuration - eps)
            let fps = landscapeFPS > 0 ? Double(landscapeFPS) : 30.0
            let generator = AVAssetImageGenerator(asset: portraitAsset)
            generator.appliesPreferredTrackTransform = true
            generator.requestedTimeToleranceBefore = .zero
            generator.requestedTimeToleranceAfter = .zero
            do {
                let (cgImage, actualTime) = try await generateCGImage(using: generator, at: lastFrameTime)

                let parentLayer = CALayer()
                parentLayer.frame = CGRect(origin: .zero, size: renderSize)
                let videoLayer = CALayer()
                videoLayer.frame = parentLayer.frame

                let overlayLayer = CALayer()
                overlayLayer.frame = parentLayer.frame

                let portraitStillLayer = CALayer()
                portraitStillLayer.contents = cgImage
                portraitStillLayer.contentsGravity = .resizeAspectFill

                let panelHeight = renderSize.height
                let panelWidth  = panelHeight * 9.0 / 16.0
                let panelX = renderSize.width - panelWidth
                let panelRect = CGRect(x: panelX, y: 0, width: panelWidth, height: panelHeight)
                portraitStillLayer.frame = panelRect
                portraitStillLayer.opacity = 0

                overlayLayer.addSublayer(portraitStillLayer)
                parentLayer.addSublayer(videoLayer)
                parentLayer.addSublayer(overlayLayer)

                // Step opacity: off until just before portrait ends, then on with no fade.
                let D = targetDuration.seconds
                let t = portraitPlayDuration.seconds
                let epsSeconds = max(pipFrameDuration.seconds, 1.0 / fps)
                let t0 = max(0.0, min(1.0, (t - epsSeconds) / D))
                let t1 = max(0.0, min(1.0, t / D))

                let show = CAKeyframeAnimation(keyPath: "opacity")
                show.duration = D
                show.beginTime = AVCoreAnimationBeginTimeAtZero
                show.values = [0.0, 0.0, 1.0, 1.0]
                show.keyTimes = [0.0, NSNumber(value: t0), NSNumber(value: t1), 1.0]
                show.isRemovedOnCompletion = false
                show.fillMode = .both
                portraitStillLayer.add(show, forKey: "showStill")

                videoComposition.animationTool = AVVideoCompositionCoreAnimationTool(
                    postProcessingAsVideoLayer: videoLayer,
                    in: parentLayer
                )

                print("🧊 PIP: Added frozen portrait frame from requested=\(lastFrameTime.seconds)s actual=\(actualTime.seconds)s to cover until \(targetDuration.seconds)s")
            } catch {
                // Retry slightly earlier; if it still fails, fall back to first frame to avoid disappearing overlay.
                let retryTime = max(.zero, lastFrameTime - pipFrameDuration)
                do {
                    let (cgImage, actualTime) = try await generateCGImage(using: generator, at: retryTime)

                    let parentLayer = CALayer()
                    parentLayer.frame = CGRect(origin: .zero, size: renderSize)
                    let videoLayer = CALayer()
                    videoLayer.frame = parentLayer.frame

                    let overlayLayer = CALayer()
                    overlayLayer.frame = parentLayer.frame

                    let portraitStillLayer = CALayer()
                    portraitStillLayer.contents = cgImage
                    portraitStillLayer.contentsGravity = .resizeAspectFill

                    let panelHeight = renderSize.height
                    let panelWidth  = panelHeight * 9.0 / 16.0
                    let panelX = renderSize.width - panelWidth
                    let panelRect = CGRect(x: panelX, y: 0, width: panelWidth, height: panelHeight)
                    portraitStillLayer.frame = panelRect
                    portraitStillLayer.opacity = 0

                    overlayLayer.addSublayer(portraitStillLayer)
                    parentLayer.addSublayer(videoLayer)
                    parentLayer.addSublayer(overlayLayer)

                    let show = CABasicAnimation(keyPath: "opacity")
                    show.fromValue = 0
                    show.toValue = 1
                    show.beginTime = AVCoreAnimationBeginTimeAtZero + portraitPlayDuration.seconds
                    show.duration = 0
                    show.isRemovedOnCompletion = false
                    show.fillMode = .forwards
                    portraitStillLayer.add(show, forKey: "showStill")

                    videoComposition.animationTool = AVVideoCompositionCoreAnimationTool(
                        postProcessingAsVideoLayer: videoLayer,
                        in: parentLayer
                    )

                    print("🧊 PIP: Retry freeze succeeded requested=\(retryTime.seconds)s actual=\(actualTime.seconds)s")
                } catch {
                    print("⚠️ PIP: Failed to generate frozen portrait frame even after retry: \(error)")
                }
            }
        }

        if !landscapeCompTrack.segments.isEmpty {
            print("🧩 Landscape segments count=\(landscapeCompTrack.segments.count)")
            for (idx, seg) in landscapeCompTrack.segments.enumerated() {
                let src = seg.timeMapping.source
                let tgt = seg.timeMapping.target
                print("🧩 [landscape \(idx)] src=\(src.start.seconds)–\(src.end.seconds) -> tgt=\(tgt.start.seconds)–\(tgt.end.seconds)")
            }
        }

        if !portraitCompTrack.segments.isEmpty {
            print("🧩 Portrait segments count=\(portraitCompTrack.segments.count)")
            for (idx, seg) in portraitCompTrack.segments.enumerated() {
                let src = seg.timeMapping.source
                let tgt = seg.timeMapping.target
                print("🧩 [portrait \(idx)] src=\(src.start.seconds)–\(src.end.seconds) -> tgt=\(tgt.start.seconds)–\(tgt.end.seconds)")
            }
        }

        print("🎬 PIPSlateExporter: Using renderSize=\(renderSize), duration=\(targetDuration.seconds)s")

        // MARK: Export

        guard let exportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
            throw PIPSlateExporterError.exportFailed("Could not create AVAssetExportSession")
        }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.videoComposition = videoComposition
        exportSession.shouldOptimizeForNetworkUse = false
        exportSession.timeRange = timeRange // ✅ Clamp export to landscape duration

        print("🧪 PIP: duration(video)=\(targetDuration.seconds)s ts=\(targetDuration.timescale)")
        print("🧪 PIP: instruction=\(instruction.timeRange.start.seconds)–\(instruction.timeRange.end.seconds) ts=\(instruction.timeRange.duration.timescale)")
        print("🧪 PIP: export=\(exportSession.timeRange.start.seconds)–\(exportSession.timeRange.end.seconds) ts=\(exportSession.timeRange.duration.timescale)")

        do {
            if #available(iOS 18.0, *) {
                try await exportSession.export(to: outputURL, as: .mp4)
            } else {
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                    exportSession.exportAsynchronously {
                        switch exportSession.status {
                        case .completed:
                            continuation.resume()
                        case .failed, .cancelled:
                            let message = exportSession.error?.localizedDescription ?? "Unknown export error"
                            logExportFailure(exportSession.error)
                            continuation.resume(throwing: PIPSlateExporterError.exportFailed(message))
                        default:
                            let message = exportSession.error?.localizedDescription ?? "Unexpected export status"
                            logExportFailure(exportSession.error)
                            continuation.resume(throwing: PIPSlateExporterError.exportFailed(message))
                        }
                    }
                }
            }
        } catch {
            if #available(iOS 18.0, *) {
                logExportFailure(error)
            } else {
                logExportFailure(exportSession.error)
            }
            throw error
        }

        return outputURL
    }

    // MARK: - Layout Helpers

    private struct TrackGeometry {
        let naturalSize: CGSize
        let preferredTransform: CGAffineTransform
    }

    private static func trackGeometry(for track: AVAssetTrack) async throws -> TrackGeometry {
        let naturalSize = try await track.load(.naturalSize)
        let preferredTransform = try await track.load(.preferredTransform)
        return TrackGeometry(naturalSize: naturalSize, preferredTransform: preferredTransform)
    }

    private static func pipTransform(
        preferredTransform: CGAffineTransform,
        naturalSize: CGSize,
        renderSize: CGSize,
        placeOnRightSide: Bool
    ) -> CGAffineTransform {
        let rect = orientedRect(for: naturalSize, preferredTransform: preferredTransform)
        let width = abs(rect.width)
        let height = abs(rect.height)

        guard width > 0, height > 0 else {
            print("⚠️ PIPTransform: invalid oriented rect from natural=\(naturalSize) preferred=\(preferredTransform)")
            return preferredTransform
        }

        if !placeOnRightSide {
            let renderRect = CGRect(origin: .zero, size: renderSize)
            return transform(
                rect: rect,
                targetRect: renderRect,
                preferredTransform: preferredTransform
            )
        } else {
            let panelHeight = renderSize.height
            let panelWidth  = panelHeight * 9.0 / 16.0
            let panelX = renderSize.width - panelWidth
            let panelRect = CGRect(x: panelX, y: 0, width: panelWidth, height: panelHeight)

            return transform(
                rect: rect,
                targetRect: panelRect,
                preferredTransform: preferredTransform
            )
        }
    }

    private static func transform(
        rect: CGRect,
        targetRect: CGRect,
        preferredTransform: CGAffineTransform
    ) -> CGAffineTransform {
        let width = abs(rect.width)
        let height = abs(rect.height)

        let scale = max(targetRect.width / width, targetRect.height / height)
        let scaledRect = CGRect(
            x: rect.minX * scale,
            y: rect.minY * scale,
            width: rect.width * scale,
            height: rect.height * scale
        )

        let dx = targetRect.midX - scaledRect.midX
        let dy = targetRect.midY - scaledRect.midY

        var transform = preferredTransform
        transform = transform.concatenating(CGAffineTransform(scaleX: scale, y: scale))
        transform = transform.concatenating(CGAffineTransform(translationX: dx, y: dy))

        print("🎬 PIPTransform: rect=\(rect) target=\(targetRect) scale=\(scale) offset=(\(dx), \(dy))")
        return transform
    }

    // MARK: - Looping Helper

    /// Inserts enough copies of `track` to cover [0, targetDuration] on a stable video timebase.
    /// Uses a final partial insert (no removeTimeRange) to avoid micro-gaps.
    private static func insertLooping(
        from track: AVAssetTrack,
        originalDuration: CMTime,
        into compositionTrack: AVMutableCompositionTrack,
        targetDuration: CMTime
    ) throws {
        let src = toVideoTime(originalDuration)
        let target = toVideoTime(targetDuration)

        guard src > .zero, target > .zero else { return }

        var current = CMTime.zero

        while current < target {
            let remaining = target - current
            let segmentDuration = min(src, remaining)

            let srcRange = CMTimeRange(start: .zero, duration: segmentDuration)
            try compositionTrack.insertTimeRange(srcRange, of: track, at: current)

            print("🔁 PIPLoop(v600): inserted segment at \(current.seconds)s (duration=\(segmentDuration.seconds)s) remaining=\(remaining.seconds)s")

            current = current + segmentDuration
        }
    }

    private static func orientedRect(for naturalSize: CGSize, preferredTransform: CGAffineTransform) -> CGRect {
        CGRect(origin: .zero, size: naturalSize).applying(preferredTransform)
    }

    private static func logExportFailure(_ error: Error?) {
        guard let error = error as NSError? else {
            print("❌ PIPSlateExporter: export failed with unknown error")
            return
        }
        print("❌ PIPSlateExporter: export failed (domain=\(error.domain), code=\(error.code), info=\(error.userInfo))")
        if let underlying = error.userInfo[NSUnderlyingErrorKey] as? NSError {
            print("   ↪ underlying error: domain=\(underlying.domain), code=\(underlying.code), info=\(underlying.userInfo)")
        }
    }
}
