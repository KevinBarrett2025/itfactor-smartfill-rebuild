import Foundation
import AVFoundation
import CoreMedia

/// Background actor responsible for performing SmartFill exports off the main actor.
actor SmartFillWorker {
    struct JobContext: Sendable {
        let jobID: UUID
        let originalPath: String
        let outputPath: String
        let fileName: String
        let settings: SmartFillSettings
        let capturedOrientation: VideoOrientation?
        let minInputSizeBytes: Int64
        let maxInputSizeBytes: Int64
        let maxDurationSeconds: Double
        let minOutputSizeBytes: Int64
    }
    
    struct Output: Sendable {
        let jobID: UUID
        let result: SmartFillJobResult
        let durationSeconds: Double
        let fileSize: Int64
        let validation: SmartFillValidationResult
    }
    
    private let fileManager: FileManager = .default
    
    func process(
        context: JobContext,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws -> Output {
        guard fileManager.fileExists(atPath: context.originalPath) else {
            throw SmartFillProcessingError.inputFileNotFound
        }
        
        let inputURL = URL(fileURLWithPath: context.originalPath)
        let outputURL = URL(fileURLWithPath: context.outputPath)

        guard inputURL != outputURL else {
            throw SmartFillProcessingError.processingFailed("Output path cannot be the same as input path.")
        }
        
        let attributes = try fileManager.attributesOfItem(atPath: context.originalPath)
        if let inputSize = attributes[.size] as? Int64 {
            guard inputSize >= context.minInputSizeBytes else {
                throw SmartFillProcessingError.processingFailed("Input file too small (\(inputSize) bytes)")
            }
            guard inputSize <= context.maxInputSizeBytes else {
                let sizeGB = Double(inputSize) / 1024 / 1024 / 1024
                throw SmartFillProcessingError.processingFailed(
                    "Input file too large for processing (\(String(format: "%.1f", sizeGB)) GB)"
                )
            }
        }
        
        let asset = AVURLAsset(url: inputURL)
        let videoTracks = try await asset.loadTracks(withMediaType: .video)
        guard !videoTracks.isEmpty else {
            throw SmartFillProcessingError.processingFailed("No video track found in input file")
        }
        
        let duration = try await asset.load(.duration)
        let durationSeconds = CMTimeGetSeconds(duration)
        guard durationSeconds.isFinite && durationSeconds > 0 else {
            throw SmartFillProcessingError.processingFailed("Invalid video duration: \(durationSeconds)")
        }
        
        guard durationSeconds <= context.maxDurationSeconds else {
            throw SmartFillProcessingError.processingFailed(
                "Video too long for SmartFill processing (\(Int(durationSeconds)) seconds)"
            )
        }
        
        var effectiveOrientation = context.capturedOrientation
        if effectiveOrientation == nil {
            if let analysis = try? await NormalizeOrientation.analyzeVideoOrientation(from: asset) {
                effectiveOrientation = analysis.capturedOrientation
            }
        }
        
        if let captured = effectiveOrientation, captured != .portrait {
            throw SmartFillProcessingError.notPortraitVideo
        }
        
        if fileManager.fileExists(atPath: outputURL.path) {
            try? fileManager.removeItem(at: outputURL)
        }
        try fileManager.createDirectory(
            at: outputURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let testFile = outputURL.deletingLastPathComponent().appendingPathComponent("smartfill_write_check.tmp")
        do {
            try "smartfill".write(to: testFile, atomically: true, encoding: .utf8)
            try fileManager.removeItem(at: testFile)
        } catch {
            throw SmartFillProcessingError.processingFailed("Cannot write to output directory: \(error.localizedDescription)")
        }
        
        let result = try await SmartFillUnifiedInterface.shared.processVideo(
            inputURL: inputURL,
            outputURL: outputURL,
            settings: context.settings,
            progressCallback: { value in
                progress(min(max(Double(value), 0.0), 1.0))
            }
        )
        
        guard result.success, let finalURL = result.outputURL else {
            let message = result.notes ?? "SmartFill unified interface reported failure"
            throw SmartFillProcessingError.processingFailed(message)
        }
        
        let outputAttributes = try fileManager.attributesOfItem(atPath: finalURL.path)
        let outputSize = (outputAttributes[.size] as? Int64) ?? 0
        guard outputSize >= context.minOutputSizeBytes else {
            try? fileManager.removeItem(at: finalURL)
            throw SmartFillProcessingError.processingFailed("Output file too small (\(outputSize) bytes)")
        }
        
        let outputAsset = AVURLAsset(url: finalURL)
        let outputValidation = try await SmartFillValidator.validate(inputAsset: asset, outputAsset: outputAsset)
        
        return Output(
            jobID: context.jobID,
            result: result,
            durationSeconds: outputValidation.outputDuration,
            fileSize: outputSize,
            validation: outputValidation
        )
    }
}
