import AVFoundation
import CoreGraphics

struct SmartFillValidationResult: Sendable {
    let inputDisplaySize: CGSize
    let outputDisplaySize: CGSize
    let inputDuration: Double
    let outputDuration: Double
    let aspectRatio: Double
    let durationDelta: Double
}

enum SmartFillValidationError: LocalizedError {
    case missingVideoTrack(String)
    case outputNotLandscape(CGSize)
    case durationMismatch(expected: Double, actual: Double)
    
    var errorDescription: String? {
        switch self {
        case .missingVideoTrack(let context):
            return "Missing video track during validation: \(context)"
        case .outputNotLandscape(let size):
            return "Validated output is not landscape: \(size.width)x\(size.height)"
        case .durationMismatch(let expected, let actual):
            let expectedStr = String(format: "%.2f", expected)
            let actualStr = String(format: "%.2f", actual)
            return "Validated output duration mismatch. Expected ~\(expectedStr)s, got \(actualStr)s"
        }
    }
}

enum SmartFillValidator {
    static func validate(
        inputAsset: AVAsset,
        outputAsset: AVAsset,
        tolerance: Double = 0.1
    ) async throws -> SmartFillValidationResult {
        guard let inputTrack = try await inputAsset.loadTracks(withMediaType: .video).first else {
            throw SmartFillValidationError.missingVideoTrack("input")
        }
        guard let outputTrack = try await outputAsset.loadTracks(withMediaType: .video).first else {
            throw SmartFillValidationError.missingVideoTrack("output")
        }
        
        let inputSize = try await inputTrack.load(.naturalSize)
        let inputTransform = try await inputTrack.load(.preferredTransform)
        let inputDisplay = absSize(inputSize.applying(inputTransform))
        
        let outputSize = try await outputTrack.load(.naturalSize)
        let outputTransform = try await outputTrack.load(.preferredTransform)
        let outputDisplay = absSize(outputSize.applying(outputTransform))
        
        if outputDisplay.height > outputDisplay.width {
            throw SmartFillValidationError.outputNotLandscape(outputDisplay)
        }
        
        let inputDurationSeconds = CMTimeGetSeconds(try await inputAsset.load(.duration))
        let outputDurationSeconds = CMTimeGetSeconds(try await outputAsset.load(.duration))
        let delta = abs(outputDurationSeconds - inputDurationSeconds) / max(inputDurationSeconds, 0.001)
        if delta > tolerance {
            throw SmartFillValidationError.durationMismatch(expected: inputDurationSeconds, actual: outputDurationSeconds)
        }
        
        let aspect = outputDisplay.width / max(outputDisplay.height, 0.001)
        
        return SmartFillValidationResult(
            inputDisplaySize: inputDisplay,
            outputDisplaySize: outputDisplay,
            inputDuration: inputDurationSeconds,
            outputDuration: outputDurationSeconds,
            aspectRatio: aspect,
            durationDelta: delta
        )
    }
    
    private static func absSize(_ size: CGSize) -> CGSize {
        CGSize(width: abs(size.width), height: abs(size.height))
    }
}
