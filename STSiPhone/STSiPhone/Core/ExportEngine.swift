import Foundation
import AVFoundation
import UIKit

// MARK: - Export Actor for Concurrency Safety

/// Dedicated actor for handling export operations without capturing self in @Sendable closures
/// Isolates export logic from the main actor to prevent race conditions
actor ExportActor {
    private var currentExportSession: AVAssetExportSession?
    
    // MARK: - Keyframe Intro Rules
    private func isPortraitVideoTrack(_ track: AVAssetTrack) async -> Bool {
        let natural = (try? await track.load(.naturalSize)) ?? .zero
        let t = (try? await track.load(.preferredTransform)) ?? .identity
        let rect = CGRect(origin: .zero, size: natural).applying(t).standardized
        let w = abs(rect.width)
        let h = abs(rect.height)
        guard w > 0, h > 0 else { return false }
        return h > w
    }

    private func shouldAttachKeyframeIntro(options: ExportOptions, videoTrack: AVAssetTrack) async -> Bool {
        guard options.keyframePhotoURL != nil else { return false }
        switch options.mode {
        case .mergedVideo:
            return true
        case .separateFiles:
            return !(await isPortraitVideoTrack(videoTrack))
        }
    }
    
    // MARK: - Export Operations
    
    func performExport(
        takes: [UnifiedTake],
        options: ExportOptions,
        progressHandler: @Sendable @escaping (Float, String) -> Void
    ) async throws -> [ExportedFile] {
        
        print("📦 ExportActor.performExport – mode=\(options.mode), takes=\(takes.count)")
        
        progressHandler(0.0, "Preparing export...")
        
        let exportedFiles: [ExportedFile]
        
        switch options.mode {
        case .separateFiles:
            print("🎬 ExportActor: Starting separate files export")
            exportedFiles = try await exportSeparateFiles(takes: takes, options: options, progressHandler: progressHandler)
        case .mergedVideo:
            print("🎬 ExportActor: Starting merged video export")
            exportedFiles = try await exportMergedVideo(takes: takes, options: options, progressHandler: progressHandler)
        }
        
        progressHandler(1.0, "Export completed!")
        return exportedFiles
    }
    
    // MARK: - Individual Take Export
    
    private func exportSeparateFiles(
        takes: [UnifiedTake],
        options: ExportOptions,
        progressHandler: @Sendable @escaping (Float, String) -> Void
    ) async throws -> [ExportedFile] {
        
        print("📦 exportSeparateFiles – starting, takes=\(takes.count)")
        progressHandler(0.1, "Processing individual takes...")
        
        var exportedFiles: [ExportedFile] = []
        let totalTakes = takes.count
        var exportSequence = 1
        
        for (index, take) in takes.enumerated() {
            print("📦 exportSeparateFiles – exporting index \(index) / \(totalTakes - 1), file=\(take.fileName)")
            let progress = 0.1 + (0.8 * Float(index) / Float(totalTakes))
            progressHandler(progress, "Exporting \(take.fileName)...")
            
            // Resolve file path using VideoFileManager
            let inputURL = try resolveInputURL(for: take)
            
            guard FileManager.default.fileExists(atPath: inputURL.path) else {
                print("❌ ExportActor: Skipping missing file \(take.fileName) at \(inputURL.path)")
                continue
            }

            let inputAsset = AVURLAsset(url: inputURL)
            
            let outputURL = generateOutputURL(for: take, options: options, sequence: exportSequence)
            
            var composition: AVMutableComposition?
            var videoComposition: AVMutableVideoComposition?
            
            if options.includeVideoMarkers,
               let markers = options.videoMarkers[take.id.uuidString],
               !markers.isEmpty {
                let result = try await createCompositionWithMarkers(
                    inputURL: inputURL,
                    markers: markers,
                    options: options
                )
                composition = result.composition
                videoComposition = result.videoComposition
            }
            
            let outputFile = try await exportSingleTake(
                take: take,
                inputAsset: inputAsset,
                inputURL: inputURL,
                outputURL: outputURL,
                composition: composition,
                videoComposition: videoComposition,
                options: options,
                progressHandler: progressHandler
            )
            
            exportedFiles.append(outputFile)
            print("✅ exportSeparateFiles – finished index \(index), outputURL=\(outputFile.url.path)")
            exportSequence += 1
        }
        
        return exportedFiles
    }
    
    private func exportSingleTake(
        take: UnifiedTake,
        inputAsset: AVAsset,
        inputURL: URL,
        outputURL: URL,
        composition: AVMutableComposition?,
        videoComposition: AVMutableVideoComposition?,
        options: ExportOptions,
        progressHandler: @Sendable @escaping (Float, String) -> Void
    ) async throws -> ExportedFile {
        
        print("🎬 exportSingleTake – starting \(take.fileName), quality=\(options.quality), format=\(options.outputFormat)")
        let profile = VideoExportProfile.profile(for: options.quality, format: options.outputFormat)

        // Create proper composition for separate files to prevent frozen video
        let finalAsset: AVAsset
        let finalVideoComposition: AVMutableVideoComposition?

        var canSkipComposition = composition == nil &&
        videoComposition == nil &&
        options.keyframePhotoURL == nil &&
        !options.includeVideoMarkers

        var forceComposition = false
        var sourcePreferredTransform: CGAffineTransform = .identity
        var sourceNaturalSize: CGSize = .zero

        if let videoTrack = try? await inputAsset.loadTracks(withMediaType: .video).first {
            sourcePreferredTransform = (try? await videoTrack.load(.preferredTransform)) ?? .identity
            sourceNaturalSize = (try? await videoTrack.load(.naturalSize)) ?? .zero
            let sourceRect = CGRect(origin: .zero, size: sourceNaturalSize)
            let transformedRect = sourceRect.applying(sourcePreferredTransform)
            let bbox = transformedRect.standardized
            let offCanvas = bbox.minX < 0 || bbox.minY < 0
#if DEBUG
            print("🔬 [ExportSingle] source bbox=\(bbox) offCanvas=\(offCanvas)")
#endif
            if !sourcePreferredTransform.isIdentity {
                forceComposition = true
            }
            if sourceNaturalSize.height > sourceNaturalSize.width {
                forceComposition = true
            }
        }

        if options.outputFormat.avFileType == .mp4 {
            forceComposition = true
        }

        if forceComposition {
            canSkipComposition = false
        }

#if DEBUG
        print("🎞️ [ExportSingle] \(take.fileName) natural=\(sourceNaturalSize) preferred=\(sourcePreferredTransform) forceComposition=\(forceComposition) outputType=\(options.outputFormat.avFileType.rawValue)")
#endif

        if profile.allowPassthrough && canSkipComposition {
            finalAsset = inputAsset
            finalVideoComposition = nil
            print("✅ ExportActor: Passthrough path enabled for \(take.fileName)")
        } else if let existingComposition = composition {
            finalAsset = existingComposition
            finalVideoComposition = videoComposition
            print("✅ ExportActor: Using existing composition with markers for \(take.fileName)")
        } else {
            print("🔧 ExportActor: Creating composition for separate file \(take.fileName)")
            let (newComposition, newVideoComposition) = try await createSingleTakeComposition(
                inputURL: inputURL,
                take: take,
                options: options
            )
            finalAsset = newComposition
            finalVideoComposition = newVideoComposition
            print("✅ ExportActor: Created new composition for separate file \(take.fileName)")
        }

        // Source instrumentation
        if let sourceMetrics = try? await SourceAnalysis(asset: inputAsset) {
            let targetBitrate = profile.targetBitrate(for: sourceMetrics)
            let targetString = targetBitrate.map { ByteCountFormatter.string(fromByteCount: Int64($0 / 8.0), countStyle: .file) + "/s target" } ?? "passthrough"
            print("📊 ExportActor: Source \(take.fileName) \(Int(sourceMetrics.dimensions.width))x\(Int(sourceMetrics.dimensions.height)) @\(String(format: "%.1f", sourceMetrics.fps))fps ~\(ByteCountFormatter.string(fromByteCount: Int64(sourceMetrics.estimatedBitrate / 8.0), countStyle: .file))/s → \(targetString)")
        }
        
        let presetName = profile.bestPreset(for: finalAsset)
        let analysis = try? await SourceAnalysis(asset: finalAsset)
        let shouldPassthrough = profile.allowPassthrough && canSkipComposition && presetName == AVAssetExportPresetPassthrough

#if DEBUG
        print("🎬 [ExportSingle] \(take.fileName) canSkipComposition=\(canSkipComposition) allowPassthrough=\(profile.allowPassthrough) presetName=\(presetName) shouldPassthrough=\(shouldPassthrough) outputFileType=\(options.outputFormat.avFileType.rawValue)")
#endif
        
        if shouldPassthrough {
            print("🎬 exportSingleTake – using STSExporter pipeline for \(take.fileName)")
            guard let exportSession = STSExport.createSession(
                asset: finalAsset,
                outputURL: outputURL,
                presetName: presetName
            ) else {
                throw ExportEngineError.exportConfigurationFailed
            }
            
            exportSession.outputFileType = options.outputFormat.avFileType
            exportSession.shouldOptimizeForNetworkUse = true
            exportSession.videoComposition = finalVideoComposition
            
            print("🎬 ExportActor: Starting export session for separate file \(take.fileName)")
            print("🎬 ExportActor: Output: \(outputURL.path)")
            
            do {
                let assetDuration = try await finalAsset.load(.duration)
                print("🎬 ExportActor: Asset duration: \(CMTimeGetSeconds(assetDuration))s")
            } catch {
                print("⚠️ ExportActor: Could not load asset duration: \(error)")
            }
            
            currentExportSession = exportSession
            
            do {
                try await STSExport.validateSession(exportSession)
                
                print("🧰 STSExporter.run – starting for \(take.fileName)")
                try await STSExporter.run(
                    session: exportSession,
                    to: outputURL,
                    as: options.outputFormat.avFileType,
                    progress: { progress in
                        progressHandler(Float(progress), "Exporting... \(Int(progress * 100))%")
                    }
                )
                print("🧰 STSExporter.run – completed for \(take.fileName)")
                
                currentExportSession = nil
                
                progressHandler(1.0, "Export completed")
                print("✅ ExportActor: Successfully exported separate file \(take.fileName)")

                if let outputMetrics = try? await SourceAnalysis(asset: AVURLAsset(url: outputURL)) {
                    print("📊 ExportActor: Output \(outputURL.lastPathComponent) \(Int(outputMetrics.dimensions.width))x\(Int(outputMetrics.dimensions.height)) @\(String(format: "%.1f", outputMetrics.fps))fps ~\(ByteCountFormatter.string(fromByteCount: Int64(outputMetrics.estimatedBitrate / 8.0), countStyle: .file))/s")
                }
                return try createExportedFile(
                    at: outputURL,
                    originalTake: take,
                    exportOptions: options
                )
                
            } catch {
                currentExportSession = nil
                
                progressHandler(0.0, "Export failed")
                print("❌ ExportActor: Export failed for \(take.fileName): \(error)")
                throw ExportEngineError.exportFailed(error)
            }
        } else {
            do {
                print("🎬 exportSingleTake – using AVAssetWriter pipeline for \(take.fileName)")
                try await exportWithWriter(
                    asset: finalAsset,
                    videoComposition: finalVideoComposition,
                    outputURL: outputURL,
                    profile: profile,
                    format: options.outputFormat,
                    analysis: analysis,
                    progressHandler: { progress in
                        progressHandler(progress, "Exporting... \(Int(progress * 100))%")
                    }
                )
                if let outputMetrics = try? await SourceAnalysis(asset: AVURLAsset(url: outputURL)) {
                    print("📊 ExportActor: Output \(outputURL.lastPathComponent) \(Int(outputMetrics.dimensions.width))x\(Int(outputMetrics.dimensions.height)) @\(String(format: "%.1f", outputMetrics.fps))fps ~\(ByteCountFormatter.string(fromByteCount: Int64(outputMetrics.estimatedBitrate / 8.0), countStyle: .file))/s")
                }
                return try createExportedFile(
                    at: outputURL,
                    originalTake: take,
                    exportOptions: options
                )
            } catch {
                currentExportSession = nil
                progressHandler(0.0, "Export failed")
                print("❌ ExportActor: Writer export failed for \(take.fileName): \(error)")
                throw ExportEngineError.exportFailed(error)
            }
        }
    }
    
    // MARK: - Merged Export
    
    private func exportMergedVideo(
        takes: [UnifiedTake],
        options: ExportOptions,
        progressHandler: @Sendable @escaping (Float, String) -> Void
    ) async throws -> [ExportedFile] {
        
        progressHandler(0.2, "Creating video composition...")
        print("🎬 ExportActor: Starting merged video export with \(takes.count) takes")
        let profile = VideoExportProfile.profile(for: options.quality, format: options.outputFormat)
        
        // Create composition
        let composition = AVMutableComposition()
        var currentTime = CMTime.zero
        var validTakes: [UnifiedTake] = []
        var skippedTakes: [String] = []
        
        // Add video tracks
        guard let videoTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            throw ExportEngineError.compositionCreationFailed
        }
        
        guard let audioTrack = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            throw ExportEngineError.compositionCreationFailed
        }
        
        progressHandler(0.4, "Processing takes...")
        print("🎬 ExportActor: Created composition tracks, processing takes...")
        
        for (index, take) in takes.enumerated() {
            let progress = 0.4 + (0.3 * Float(index) / Float(takes.count))
            progressHandler(progress, "Adding take \(index + 1)...")
            
            // Resolve input URL
            let inputURL: URL
            do {
                inputURL = try resolveInputURL(for: take)
            } catch {
                skippedTakes.append(take.fileName)
                continue
            }
            
            guard FileManager.default.fileExists(atPath: inputURL.path) else {
                print("❌ ExportActor: File not found: \(take.fileName)")
                skippedTakes.append(take.fileName)
                continue
            }
            
            let asset = AVURLAsset(url: inputURL)
            
            do {
                let videoTracks = try await asset.loadTracks(withMediaType: .video)
                let audioTracks = try await asset.loadTracks(withMediaType: .audio)
                let duration = try await asset.load(.duration)
                
                print("🎬 ExportActor: \(take.fileName) - Video: \(videoTracks.count), Audio: \(audioTracks.count), Duration: \(CMTimeGetSeconds(duration))s")
                
                // Add video track
                if let videoSourceTrack = videoTracks.first {
                    let timeRange = CMTimeRange(start: .zero, duration: duration)
                    try videoTrack.insertTimeRange(timeRange, of: videoSourceTrack, at: currentTime)
                    print("✅ ExportActor: Added video track for \(take.fileName) at time \(CMTimeGetSeconds(currentTime))s")
                }
                
                // Add audio track
                if let audioSourceTrack = audioTracks.first {
                    let timeRange = CMTimeRange(start: .zero, duration: duration)
                    try audioTrack.insertTimeRange(timeRange, of: audioSourceTrack, at: currentTime)
                    print("✅ ExportActor: Added audio track for \(take.fileName) at time \(CMTimeGetSeconds(currentTime))s")
                }
                
                currentTime = CMTimeAdd(currentTime, duration)
                validTakes.append(take)
                
                print("✅ ExportActor: Successfully processed \(take.fileName)")
                
            } catch {
                print("❌ ExportActor: Failed to process \(take.fileName): \(error)")
                skippedTakes.append(take.fileName)
            }
        }
        
        // Validate we have valid takes
        guard !validTakes.isEmpty else {
            let message = skippedTakes.isEmpty ? "No valid video files found" : "All video files are missing: \(skippedTakes.joined(separator: ", "))"
            throw ExportEngineError.processingFailed(message)
        }
        
        // Generate output filename and URL
        let filename = generateMergedFilename(for: validTakes, options: options)
        let outputURL = getOutputURL(filename: filename)
        
        progressHandler(0.7, "Configuring export session...")
        
        progressHandler(0.8, "Exporting merged video...")
        let analysis = try? await SourceAnalysis(asset: composition)
        do {
            try await exportWithWriter(
                asset: composition,
                videoComposition: nil,
                outputURL: outputURL,
                profile: profile,
                format: options.outputFormat,
                analysis: analysis,
                progressHandler: { progress in
                    let adjustedProgress = 0.8 + (0.2 * Float(progress))
                    progressHandler(adjustedProgress, "Exporting... \(Int(progress * 100))%")
                }
            )
            progressHandler(1.0, "Export completed")
            print("✅ ExportActor: Export completed successfully!")
            if let outputMetrics = try? await SourceAnalysis(asset: AVURLAsset(url: outputURL)) {
                print("📊 ExportActor: Output \(outputURL.lastPathComponent) \(Int(outputMetrics.dimensions.width))x\(Int(outputMetrics.dimensions.height)) @\(String(format: "%.1f", outputMetrics.fps))fps ~\(ByteCountFormatter.string(fromByteCount: Int64(outputMetrics.estimatedBitrate / 8.0), countStyle: .file))/s")
            }
            let exportedFile = try createMergedExportedFile(
                at: outputURL,
                originalTakes: validTakes,
                exportOptions: options
            )
            return [exportedFile]
        } catch {
            currentExportSession = nil
            progressHandler(0.0, "Export failed")
            print("❌ ExportActor: Export failed: \(error)")
            throw ExportEngineError.exportFailed(error)
        }
    }
    
    
    // MARK: - Progress Monitoring
    
    // This eliminates iOS 18+ State enum compatibility issues
    
    // MARK: - Cancellation
    
    func cancelCurrentExport() {
        currentExportSession?.cancelExport()
        currentExportSession = nil
    }
    
    // MARK: - Utility Methods
    
    private func resolveInputURL(for take: UnifiedTake) throws -> URL {
        do {
            let inputURL = try VideoFileManager.shared.getVideoURL(for: take.fileName)
            print("✅ ExportActor: VideoFileManager found \(take.fileName) at: \(inputURL.path)")
            return inputURL
        } catch {
            // CRITICAL FIX: If fallback, treat take.filePath as *relative* first
            if !take.filePath.isEmpty && !take.filePath.hasPrefix("/") {
                let resolved = VideoVariantResolver.urlForRelativePath(take.filePath)
                print("⚠️ ExportActor: VideoFileManager failed, resolved as relative: \(resolved.path)")
                return resolved
            }
            let inputURL = URL(fileURLWithPath: take.filePath)
            print("⚠️ ExportActor: VideoFileManager failed, using stored absolute path fallback: \(take.filePath)")
            return inputURL
        }
    }
    
    private func generateOutputURL(for take: UnifiedTake, options: ExportOptions, sequence: Int) -> URL {
        let filename = generateFilename(for: take, options: options, sequence: sequence)
        return getOutputURL(filename: filename)
    }
    
    private func generateFilename(for take: UnifiedTake, options: ExportOptions, sequence: Int) -> String {
        if let customMap = options.customSeparateFilenames,
           let custom = customMap[take.id],
           let sanitizedCustom = sanitizedCustomBaseFilename(custom) {
            return "\(sanitizedCustom).\(options.outputFormat.fileExtension)"
        }
        
        if let customBase = sanitizedCustomBaseFilename(options.customBaseFilename) {
            let suffix = sequence <= 1 ? "" : "\(sequence)"
            return "\(customBase)\(suffix).\(options.outputFormat.fileExtension)"
        }
        
        let timestamp = DateFormatter.filenameFriendly.string(from: take.createdAt)
        let takeInfo = take.isSlate ? "SLATE" : "Take\(take.takeNumber)"
        let rawBase = "\(take.projectID.uuidString.prefix(8))_\(takeInfo)_\(timestamp)"
        let sanitizedBase = ExportFilenameBuilder.sanitizeFilename(rawBase)
        let finalBase = sanitizedBase.isEmpty ? "STS Export" : sanitizedBase
        return "\(finalBase).\(options.outputFormat.fileExtension)"
    }
    
    private func generateMergedFilename(for takes: [UnifiedTake], options: ExportOptions) -> String {
        guard let firstTake = takes.first else {
            return "STS_Export_\(UUID().uuidString.prefix(8)).\(options.outputFormat.fileExtension)"
        }

        if let customBase = sanitizedCustomBaseFilename(options.customBaseFilename) {
            return "\(customBase).\(options.outputFormat.fileExtension)"
        }

        let timestamp = DateFormatter.filenameFriendly.string(from: Date())
        let projectID = firstTake.projectID.uuidString.prefix(8)

        let rawBase = "\(projectID)_Merged_\(takes.count)takes_\(timestamp)"
        let sanitizedBase = ExportFilenameBuilder.sanitizeFilename(rawBase)
        let finalBase = sanitizedBase.isEmpty ? "STS Export" : sanitizedBase

        return "\(finalBase).\(options.outputFormat.fileExtension)"
    }
    
    private func getOutputURL(filename: String) -> URL {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let exportsURL = documentsURL.appendingPathComponent("STS_Exports")
        
        // Create exports directory if it doesn't exist
        try? FileManager.default.createDirectory(at: exportsURL, withIntermediateDirectories: true)
        
        return exportsURL.appendingPathComponent(filename)
    }
    
    private func sanitizedCustomBaseFilename(_ base: String?) -> String? {
        guard var raw = base?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return nil
        }
        raw = (raw as NSString).deletingPathExtension
        if raw.isEmpty { return nil }
        let sanitized = ExportFilenameBuilder.sanitizeFilename(raw)
        if sanitized.isEmpty {
            return "STS Export"
        }
        return sanitized
    }
    
    // MARK: - Composition Creation
    
    private func createSingleTakeComposition(
        inputURL: URL,
        take: UnifiedTake,
        options: ExportOptions
    ) async throws -> (composition: AVMutableComposition, videoComposition: AVMutableVideoComposition?) {
        
        let asset = AVURLAsset(url: inputURL)
        let composition = AVMutableComposition()
        
        print("🔧 ExportActor: Creating single take composition for \(take.fileName)")
        
        // 🚨 MODERNIZED: Use async AVFoundation APIs instead of deprecated synchronous getters
        let videoTracks = try await asset.loadTracks(withMediaType: .video)
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        let duration = try await asset.load(.duration)

        print("🔧 ExportActor: Asset loaded - Video tracks: \(videoTracks.count), Audio tracks: \(audioTracks.count), Duration: \(CMTimeGetSeconds(duration))s")
        
        // Validate duration and tracks before composition
        guard CMTimeGetSeconds(duration) > 0 else {
            throw ExportEngineError.processingFailed("Invalid asset duration")
        }
        
        guard let videoSourceTrack = videoTracks.first else {
            throw ExportEngineError.processingFailed("No video track found in \(take.fileName)")
        }
        let audioSourceTrack = audioTracks.first

        let videoTR: CMTimeRange
        let audioTR: CMTimeRange?
        let nominalFPS: Float
        if #available(iOS 16.0, *) {
            videoTR = try await videoSourceTrack.load(.timeRange)
            nominalFPS = (try? await videoSourceTrack.load(.nominalFrameRate)) ?? 0
            if let audioSourceTrack {
                audioTR = try? await audioSourceTrack.load(.timeRange)
            } else {
                audioTR = nil
            }
        } else {
            videoTR = videoSourceTrack.timeRange
            nominalFPS = videoSourceTrack.nominalFrameRate
            audioTR = audioSourceTrack?.timeRange
        }
        
        let naturalSize = try await videoSourceTrack.load(.naturalSize)
        let preferredTransform = try await videoSourceTrack.load(.preferredTransform)
        let sanitizedNaturalSize = CGSize(
            width: max(1, abs(naturalSize.width)),
            height: max(1, abs(naturalSize.height))
        )
#if DEBUG
        print("⏱️ [ExportDur] file=\(take.fileName) asset=\(duration.seconds)s video=\(videoTR.duration.seconds)s audio=\(audioTR?.duration.seconds ?? 0)s nominalFPS=\(nominalFPS)")
#endif
        
        // Create composition tracks
        guard let compositionVideoTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            throw ExportEngineError.compositionCreationFailed
        }
        
        var introDuration: CMTime = .zero
        if await shouldAttachKeyframeIntro(options: options, videoTrack: videoSourceTrack),
           let keyframePhotoURL = options.keyframePhotoURL {
            do {
                let clipURL = try await KeyframeIntroClipBuilder.buildIntroClip(
                    from: keyframePhotoURL,
                    renderSize: sanitizedNaturalSize,
                    duration: options.keyframeIntroDuration ?? 0.55
                )
                let introAsset = AVURLAsset(url: clipURL)
                let introTracks = try await introAsset.loadTracks(withMediaType: .video)
                if let introTrack = introTracks.first {
                    let introTimeRange = CMTimeRange(
                        start: .zero,
                        duration: try await introAsset.load(.duration)
                    )
                    try compositionVideoTrack.insertTimeRange(introTimeRange, of: introTrack, at: .zero)
                    introDuration = introTimeRange.duration
                    print("🎬 ExportActor: Prepended keyframe intro clip (\(CMTimeGetSeconds(introDuration))s) to \(take.fileName)")
                } else {
                    print("⚠️ ExportActor: Intro clip missing video track for \(take.fileName)")
                }
            } catch {
                print("⚠️ ExportActor: Failed to build keyframe intro clip for \(take.fileName): \(error)")
            }
        }
        
        // Enhanced video track insertion with proper time range validation
        let videoTimeRange = CMTimeRange(start: .zero, duration: CMTimeMinimum(videoTR.duration, duration))
        
        do {
            let effectiveVideoDuration = CMTimeMinimum(videoTR.duration, duration)
            let effectiveVideoRange = CMTimeRange(start: .zero, duration: effectiveVideoDuration)
            print("⏱️ [ExportInsert] file=\(take.fileName) insertAt=\(introDuration.seconds)s insertRange=0..\((effectiveVideoRange.duration + effectiveVideoRange.start).seconds)s dur=\(effectiveVideoRange.duration.seconds)s")
            try compositionVideoTrack.insertTimeRange(effectiveVideoRange, of: videoSourceTrack, at: introDuration)
            print("✅ ExportActor: Successfully inserted video track for \(take.fileName)")
        } catch {
            throw ExportEngineError.processingFailed("Video track insertion failed: \(error.localizedDescription)")
        }
        
        // Handle audio track
        if options.includeAudio, let audioSourceTrack {
            guard let compositionAudioTrack = composition.addMutableTrack(
                withMediaType: .audio,
                preferredTrackID: kCMPersistentTrackID_Invalid
            ) else {
                print("⚠️ ExportActor: Could not create audio track, continuing with video only")
                return (composition: composition, videoComposition: nil)
            }
            
            let audioFallbackDuration: CMTime
            if let audioTR {
                audioFallbackDuration = audioTR.duration
            } else {
                audioFallbackDuration = (try? await audioSourceTrack.load(.timeRange).duration) ?? .zero
            }

            let effectiveAudioDuration = CMTimeMinimum(videoTimeRange.duration, audioFallbackDuration)
            let audioTimeRange = CMTimeRange(start: .zero, duration: effectiveAudioDuration)
            
            do {
                try compositionAudioTrack.insertTimeRange(audioTimeRange, of: audioSourceTrack, at: introDuration)
                print("✅ ExportActor: Successfully inserted audio track for \(take.fileName)")
            } catch {
                print("⚠️ ExportActor: Failed to insert audio track for \(take.fileName): \(error), continuing with video only")
            }
        }
        
        // Validate final composition
        do {
            let finalDuration = try await composition.load(.duration)
            guard CMTimeGetSeconds(finalDuration) > 0 else {
                throw ExportEngineError.processingFailed("Composition has invalid duration after track insertion")
            }
            
            print("✅ ExportActor: Single take composition created successfully for \(take.fileName)")
        } catch {
            throw ExportEngineError.processingFailed("Failed to validate composition: \(error.localizedDescription)")
        }
        
        let isIdentityTransform = preferredTransform.isIdentity
        
        if isIdentityTransform {
            print("✅ ExportActor: Using simple composition without video composition (identity transform)")
            return (composition: composition, videoComposition: nil)
        } else {
            print("🎨 ExportActor: Creating video composition for transform")
            let videoComposition = try await createVideoComposition(
                for: composition,
                sourceVideoTrack: videoSourceTrack
            )
            return (composition: composition, videoComposition: videoComposition)
        }
    }
    
    private func createVideoComposition(
        for composition: AVMutableComposition,
        sourceVideoTrack: AVAssetTrack
    ) async throws -> AVMutableVideoComposition {
        
        // 🚨 MODERNIZED: Load source track properties using async APIs
        let naturalSize = try await sourceVideoTrack.load(.naturalSize)
        let preferredTransform = try await sourceVideoTrack.load(.preferredTransform)
        
        // Create video composition
        let videoComposition = AVMutableVideoComposition()
        
        // Enhanced render size calculation
        let renderSize = calculateRenderSize(naturalSize: naturalSize, transform: preferredTransform)
        
        videoComposition.renderSize = renderSize
        videoComposition.frameDuration = CMTime(value: 1, timescale: 30) // 30 FPS
        
        // 🚨 MODERNIZED: Get composition video tracks using async API
        let compositionVideoTracks = try await composition.loadTracks(withMediaType: .video)
        guard let compositionVideoTrack = compositionVideoTracks.first else {
            throw ExportEngineError.processingFailed("No composition video track found")
        }
        
        // Create instruction
        let instruction = AVMutableVideoCompositionInstruction()
        
        let compositionDuration = try await composition.load(.duration)
        instruction.timeRange = CMTimeRange(start: .zero, duration: compositionDuration)
        
        // Create layer instruction
        let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: compositionVideoTrack)
        let fitTransform = await NormalizeOrientation.centeredAspectFitTransform(
            for: sourceVideoTrack,
            renderSize: renderSize
        )
        layerInstruction.setTransform(fitTransform, at: .zero)
        
        instruction.layerInstructions = [layerInstruction]
        videoComposition.instructions = [instruction]
        
#if DEBUG
        let rect = CGRect(origin: .zero, size: naturalSize).applying(fitTransform)
        print("🔬 [ExportSingle] fitted rect=\(rect) renderSize=\(renderSize)")
#endif
        print("✅ ExportActor: Video composition created with transform applied")
        
        return videoComposition
    }
    
    private func calculateRenderSize(naturalSize: CGSize, transform: CGAffineTransform) -> CGSize {
        let renderSize = naturalSize.applying(transform)
        
        let normalizedSize = CGSize(
            width: abs(renderSize.width),
            height: abs(renderSize.height)
        )
        
        let minSize: CGFloat = 64
        let finalSize = CGSize(
            width: max(normalizedSize.width, minSize),
            height: max(normalizedSize.height, minSize)
        )
        
        return finalSize
    }
    
    private func createCompositionWithMarkers(
        inputURL: URL,
        markers: [VideoMarker],
        options: ExportOptions
    ) async throws -> (composition: AVMutableComposition, videoComposition: AVMutableVideoComposition?) {
        
        let asset = AVURLAsset(url: inputURL)
        let composition = AVMutableComposition()
        
        // UPDATED: Use modern async API for reliable track loading
        let videoTracks = try await asset.loadTracks(withMediaType: .video)
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        
        guard let videoTrack = videoTracks.first else {
            throw ExportEngineError.processingFailed("No video track found")
        }
        
        guard let compositionVideoTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            throw ExportEngineError.compositionCreationFailed
        }
        
        let naturalSize = try await videoTrack.load(.naturalSize)
        let sanitizedNaturalSize = CGSize(
            width: max(1, abs(naturalSize.width)),
            height: max(1, abs(naturalSize.height))
        )
        
        var introDuration: CMTime = .zero
        if await shouldAttachKeyframeIntro(options: options, videoTrack: videoTrack),
           let keyframePhotoURL = options.keyframePhotoURL {
            do {
                let clipURL = try await KeyframeIntroClipBuilder.buildIntroClip(
                    from: keyframePhotoURL,
                    renderSize: sanitizedNaturalSize,
                    duration: options.keyframeIntroDuration ?? 0.55
                )
                let introAsset = AVURLAsset(url: clipURL)
                let introTracks = try await introAsset.loadTracks(withMediaType: .video)
                if let introTrack = introTracks.first {
                    let introRange = CMTimeRange(
                        start: .zero,
                        duration: try await introAsset.load(.duration)
                    )
                    try compositionVideoTrack.insertTimeRange(introRange, of: introTrack, at: .zero)
                    introDuration = introRange.duration
                    print("🎬 ExportActor: Added keyframe intro clip before marker composition")
                }
            } catch {
                print("⚠️ ExportActor: Failed to attach keyframe intro clip for marker export: \(error)")
            }
        }
        
        let assetDuration = try await asset.load(.duration)
        
        try compositionVideoTrack.insertTimeRange(
            CMTimeRange(start: .zero, duration: assetDuration),
            of: videoTrack,
            at: introDuration
        )
        
        // Add audio track if present
        if let audioTrack = audioTracks.first,
           options.includeAudio {
            let compositionAudioTrack = composition.addMutableTrack(
                withMediaType: .audio,
                preferredTrackID: kCMPersistentTrackID_Invalid
            )
            
            try compositionAudioTrack?.insertTimeRange(
                CMTimeRange(start: .zero, duration: assetDuration),
                of: audioTrack,
                at: introDuration
            )
        }
        
        // Add markers as metadata or chapters
        switch options.markerExportFormat {
        case .chapters, .both:
            addMarkersAsChapters(to: composition, markers: markers)
        case .metadata:
            addMarkersAsMetadata(to: composition, markers: markers)
        case .subtitles:
            break
        }
        
        return (composition: composition, videoComposition: nil)
    }
    
    private func addMarkersAsChapters(to composition: AVMutableComposition, markers: [VideoMarker]) {
        _ = composition.addMutableTrack(
            withMediaType: .metadata,
            preferredTrackID: kCMPersistentTrackID_Invalid
        )
        
        for marker in markers {
            let time = CMTime(seconds: marker.timestamp, preferredTimescale: 600)
            let metadataItem = AVMutableMetadataItem()
            metadataItem.identifier = .commonIdentifierTitle
            metadataItem.value = marker.title as NSString
            metadataItem.time = time
            
            if let description = marker.description {
                let descItem = AVMutableMetadataItem()
                descItem.identifier = .commonIdentifierDescription
                descItem.value = description as NSString
                descItem.time = time
            }
        }
    }
    
    private func addMarkersAsMetadata(to composition: AVMutableComposition, markers: [VideoMarker]) {
        print("🏷️ ExportActor: Markers will be preserved in filenames and logs")
        print("📍 Markers to preserve: \(markers.map { "\($0.title) at \($0.timestamp)s" }.joined(separator: ", "))")
    }
    
    private func createExportedFile(
        at url: URL,
        originalTake: UnifiedTake,
        exportOptions: ExportOptions
    ) throws -> ExportedFile {
        let fileSize = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        
        return ExportedFile(
            url: url,
            filename: url.lastPathComponent,
            fileSize: Int64(fileSize),
            unifiedTakes: [originalTake],
            exportOptions: exportOptions,
            createdAt: Date()
        )
    }
    
    private func createMergedExportedFile(
        at url: URL,
        originalTakes: [UnifiedTake],
        exportOptions: ExportOptions
    ) throws -> ExportedFile {
        let fileSize = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        
        return ExportedFile(
            url: url,
            filename: url.lastPathComponent,
            fileSize: Int64(fileSize),
            unifiedTakes: originalTakes,
            exportOptions: exportOptions,
            createdAt: Date()
        )
    }

    // MARK: - AVAssetReader/Writer Export Pipeline
    private func exportWithWriter(
        asset: AVAsset,
        videoComposition: AVVideoComposition?,
        outputURL: URL,
        profile: VideoExportProfile,
        format: OutputFormat,
        analysis: SourceAnalysis?,
        progressHandler: @Sendable @escaping (Float) -> Void
    ) async throws {
        print("🧰 exportWithWriter – starting AVAssetExportSession to \(outputURL.lastPathComponent)")
        try? FileManager.default.removeItem(at: outputURL)

        let presetName = profile.bestPreset(for: asset)

        guard let exportSession = AVAssetExportSession(asset: asset, presetName: presetName) else {
            throw ExportEngineError.exportFailed(
                NSError(
                    domain: "STS.Export",
                    code: -1000,
                    userInfo: [NSLocalizedDescriptionKey: "Failed to create AVAssetExportSession"]
                )
            )
        }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = format.avFileType
        exportSession.shouldOptimizeForNetworkUse = true
        exportSession.videoComposition = videoComposition

        currentExportSession = exportSession

        print("🧰 exportWithWriter – preset=\(presetName), fileType=\(format.avFileType.rawValue)")

        try await exportSession.sts_export(
            to: outputURL,
            fileType: format.avFileType
        ) { progress in
            progressHandler(progress)
        }
        print("✅ exportWithWriter – export completed for \(outputURL.lastPathComponent)")
        progressHandler(1.0)
        currentExportSession = nil
    }

    private func pump(output: AVAssetReaderOutput, input: AVAssetWriterInput, updateProgress: @escaping (CMTime) -> Void) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            let outputBox = UncheckedSendableBox(value: output)
            let inputBox = UncheckedSendableBox(value: input)
            input.requestMediaDataWhenReady(on: DispatchQueue(label: "com.sts.export.video")) {
                while inputBox.value.isReadyForMoreMediaData {
                    if let sample = outputBox.value.copyNextSampleBuffer() {
                        inputBox.value.append(sample)
                        updateProgress(CMSampleBufferGetPresentationTimeStamp(sample))
                    } else {
                        inputBox.value.markAsFinished()
                        cont.resume()
                        break
                    }
                }
            }
        }
    }

    private func pumpAudio(reader: AVAssetReader, writer: AVAssetWriter, audioOutput: AVAssetReaderOutput?) async throws {
        guard let audioOutput,
              let audioInput = writer.inputs.first(where: { $0.mediaType == .audio }) else {
            return
        }
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            let outputBox = UncheckedSendableBox(value: audioOutput)
            let inputBox = UncheckedSendableBox(value: audioInput)
            inputBox.value.requestMediaDataWhenReady(on: DispatchQueue(label: "com.sts.export.audio")) {
                while inputBox.value.isReadyForMoreMediaData {
                    if let sample = outputBox.value.copyNextSampleBuffer() {
                        inputBox.value.append(sample)
                    } else {
                        inputBox.value.markAsFinished()
                        cont.resume()
                        break
                    }
                }
            }
        }
    }

    private struct UncheckedSendableBox<T>: @unchecked Sendable {
        let value: T
    }
}

// MARK: - AVAssetExportSession modern wrapper

extension AVAssetExportSession {

    /// Unified async export wrapper that uses the modern APIs on iOS 18+,
    /// and falls back to the legacy exportAsynchronously/status path on earlier OSes.
    func sts_export(
        to outputURL: URL,
        fileType: AVFileType,
        updateProgress: (@Sendable @MainActor (Float) -> Void)? = nil
    ) async throws {
        self.outputURL = outputURL
        self.outputFileType = fileType

        if #available(iOS 18, *) {
            if let updateProgress {
                let states = self.states(updateInterval: 0.2)

                // Detach a lightweight observer without retaining self
                Task.detached { [states] in
                    for await state in states {
                        if case let .exporting(progress) = state {
                            let fraction = Float(progress.fractionCompleted)
                            await updateProgress(fraction)
                        }
                    }
                }
            }

            try await self.export(to: outputURL, as: fileType)

        } else {
            let progressHandler = updateProgress

            if let progressHandler {
                Task.detached { [weak self] in
                    guard let self else { return }
                    while self.status == .exporting {
                        let progress = self.progress
                        await MainActor.run {
                            progressHandler(progress)
                        }
                        try? await Task.sleep(nanoseconds: 200_000_000)
                    }
                }
            }

            await withCheckedContinuation { continuation in
                self.exportAsynchronously {
                    continuation.resume()
                }
            }

            switch self.status {
            case .completed:
                return
            case .failed, .cancelled:
                let nsError = self.error ?? NSError(
                    domain: "AVAssetExportSession",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Export failed with status \(self.status)"]
                )
                throw nsError
            default:
                let nsError = NSError(
                    domain: "AVAssetExportSession",
                    code: -2,
                    userInfo: [NSLocalizedDescriptionKey: "Unexpected export status \(self.status)"]
                )
                throw nsError
            }
        }
    }
}

/// Professional-grade export engine for Self Tape Studio
/// MODERNIZED: Concurrency-safe with dedicated ExportActor to prevent capture issues
@MainActor
class ExportEngine: ObservableObject {
    static let shared = ExportEngine()
    
    @Published var isExporting = false
    @Published var exportProgress: Float = 0.0
    @Published var currentExportOperation: String = ""
    
    // CONCURRENCY FIX: Use dedicated actor instead of capturing self
    private let exportActor = ExportActor()
    
    private init() {}
    
    // MARK: - Main Export Methods
    
    func exportTakes(
        _ takes: [UnifiedTake],
        options: ExportOptions,
        completion: @escaping (Result<[ExportedFile], ExportEngineError>) -> Void
    ) {
        print("🎬 ExportEngine: exportTakes called with \(takes.count) unified takes")
        print("🎬 ExportEngine: Export mode: \(options.mode.displayName)")
        
        // Set exporting state immediately
        isExporting = true
        exportProgress = 0.0
        currentExportOperation = "Initializing export..."
        
        // CONCURRENCY FIX: Use Task without capturing self
        // Instead, capture only the immutable values we need
        Task { @MainActor in
            do {
                // CONCURRENCY FIX: Pass progress handler that doesn't capture self
                let exportedFiles = try await exportActor.performExport(
                    takes: takes,
                    options: options,
                    progressHandler: { [weak self] progress, operation in
                        Task { @MainActor in
                            self?.updateExportProgress(progress, operation: operation)
                        }
                    }
                )
                
                print("✅ ExportEngine: Export completed with \(exportedFiles.count) files")
                
                // Reset exporting state
                self.isExporting = false
                
                completion(.success(exportedFiles))
                
            } catch {
                print("❌ ExportEngine: Export failed with error: \(error)")
                
                // Reset exporting state on error
                self.isExporting = false
                self.exportProgress = 0.0
                self.currentExportOperation = "Export failed"
                
                completion(.failure(ExportEngineError.processingFailed(error.localizedDescription)))
            }
        }
    }
    
    // MARK: - Progress Updates
    
    private func updateExportProgress(_ progress: Float, operation: String) {
        exportProgress = progress
        currentExportOperation = operation
    }
    
    // MARK: - Utility Methods
    
    func cancelExport() {
        Task {
            await exportActor.cancelCurrentExport()
        }
        
        isExporting = false
        exportProgress = 0.0
        currentExportOperation = "Export cancelled"
    }
}

// MARK: - Export Options
struct ExportOptions: Equatable {
    var mode: ExportMode = .mergedVideo
    var quality: ExportQuality = .high
    var outputFormat: OutputFormat = .mp4
    var outputURL: URL?
    var includeSlate: Bool = true
    var keyframePhotoURL: URL?
    var keyframeIntroDuration: TimeInterval?
    var customBaseFilename: String?
    var customSeparateFilenames: [UUID: String]?
    
    // Video marker export support
    var includeVideoMarkers: Bool = false
    var markerExportFormat: MarkerExportFormat = .chapters
    var videoMarkers: [String: [VideoMarker]] = [:]  // takeID -> markers
    
    // Advanced options
    var customBitrate: Int?
    var customResolution: CGSize?
    var includeAudio: Bool = true
var audioQuality: ExportAudioQuality = .high
    var customFrameRate: Float?
    var enableHardwareAcceleration: Bool = true
    
    // Equatable conformance
    static func == (lhs: ExportOptions, rhs: ExportOptions) -> Bool {
        lhs.mode == rhs.mode &&
        lhs.quality == rhs.quality &&
        lhs.outputFormat == rhs.outputFormat &&
        lhs.includeSlate == rhs.includeSlate &&
        lhs.includeVideoMarkers == rhs.includeVideoMarkers &&
        lhs.keyframePhotoURL == rhs.keyframePhotoURL &&
        lhs.keyframeIntroDuration == rhs.keyframeIntroDuration &&
        lhs.customBaseFilename == rhs.customBaseFilename &&
        lhs.customSeparateFilenames == rhs.customSeparateFilenames
    }
}

// MARK: - Export Enums

enum MarkerExportFormat: String, CaseIterable {
    case chapters = "chapters"
    case metadata = "metadata"
    case subtitles = "subtitles"
    case both = "both"
    
    var displayName: String {
        switch self {
        case .chapters:
            return "Video Chapters"
        case .metadata:
            return "Metadata Only"
        case .subtitles:
            return "Subtitle Track"
        case .both:
            return "Chapters + Metadata"
        }
    }
}

enum ExportMode: String, CaseIterable {
    case separateFiles = "separate"
    case mergedVideo = "merged"
    
    var displayName: String {
        switch self {
        case .separateFiles:
            return "Separate Files"
        case .mergedVideo:
            return "Merged Video"
        }
    }
    
    var icon: String {
        switch self {
        case .separateFiles:
            return "doc.on.doc"
        case .mergedVideo:
            return "film"
        }
    }
}

enum ExportQuality: String, CaseIterable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case maximum = "maximum"
    
    var displayName: String {
        switch self {
        case .low:
            return "Data Saver (720p)"
        case .medium:
            return "Balanced (1080p Cap)"
        case .high:
            return "Studio (HEVC/HQ)"
        case .maximum:
            return "Passthrough (Source)"
        }
    }
    
    var avPreset: String {
        switch self {
        case .low:
            return AVAssetExportPresetLowQuality
        case .medium:
            return AVAssetExportPresetMediumQuality
        case .high:
            return AVAssetExportPresetHighestQuality
        case .maximum:
            return AVAssetExportPresetPassthrough
        }
    }
    
    var estimatedCompressionRatio: Double {
        switch self {
        case .low:
            return 0.3
        case .medium:
            return 0.5
        case .high:
            return 0.7
        case .maximum:
            return 1.0
        }
    }
}

// Export audio quality specific to ExportEngine to avoid clashing with capture AudioQuality.
enum ExportAudioQuality: String, CaseIterable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case lossless = "lossless"
    
    var displayName: String {
        switch self {
        case .low:
            return "Low (64 kbps)"
        case .medium:
            return "Medium (128 kbps)"
        case .high:
            return "High (256 kbps)"
        case .lossless:
            return "Lossless"
        }
    }
    
    var bitrate: Int {
        switch self {
        case .low:
            return 64_000
        case .medium:
            return 128_000
        case .high:
            return 256_000
        case .lossless:
            return 0 // Will use lossless compression
        }
    }
}

enum OutputFormat: String, CaseIterable {
    case mp4 = "mp4"
    case mov = "mov"
    
    var displayName: String {
        switch self {
        case .mp4:
            return "MP4 (Universal)"
        case .mov:
            return "MOV (Apple)"
        }
    }
    
    var fileExtension: String {
        return self.rawValue
    }
    
    var avFileType: AVFileType {
        switch self {
        case .mp4:
            return .mp4
        case .mov:
            return .mov
        }
    }
}

// MARK: - Export Results

struct ExportedFile: Identifiable, Equatable {
    let id = UUID()
    let url: URL
    let filename: String
    let fileSize: Int64
    let unifiedTakes: [UnifiedTake]
    let exportOptions: ExportOptions
    let createdAt: Date
    
    var formattedFileSize: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }
    
    var isMultiTake: Bool {
        unifiedTakes.count > 1
    }
    
    // Equatable conformance
    static func == (lhs: ExportedFile, rhs: ExportedFile) -> Bool {
        lhs.id == rhs.id && lhs.filename == rhs.filename && lhs.fileSize == rhs.fileSize
    }
}

// MARK: - Export Errors

enum ExportEngineError: LocalizedError {
    case noTakesFound
    case fileNotFound(String)
    case exportConfigurationFailed
    case compositionCreationFailed
    case noValidTakes
    case exportFailed(Error)
    case postProcessingFailed(Error)
    case exportCancelled
    case batchExportFailed([Error])
    case unknownError
    case processingFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .noTakesFound:
            return "No takes found to export"
        case .fileNotFound(let path):
            return "Video file not found: \(path)"
        case .exportConfigurationFailed:
            return "Failed to configure export settings"
        case .compositionCreationFailed:
            return "Failed to create video composition"
        case .noValidTakes:
            return "No valid video files found"
        case .exportFailed(let error):
            return "Export failed: \(error.localizedDescription)"
        case .postProcessingFailed(let error):
            return "Post-processing failed: \(error.localizedDescription)"
        case .exportCancelled:
            return "Export was cancelled"
        case .batchExportFailed(let errors):
            return "Batch export failed (\(errors.count) errors)"
        case .unknownError:
            return "An unknown error occurred during export"
        case .processingFailed(let message):
            return "Processing failed: \(message)"
        }
    }
}

// MARK: - Utility Extensions

extension DateFormatter {
    static let filenameFriendly: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter
    }()
    
    static let shortTimestamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMdd_HHmm"
        return formatter
    }()}
