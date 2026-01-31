import Foundation
import CoreGraphics

public enum OrientationPolicyDecision {
    case uiShouldApplyTransform
    case uiShouldNotApplyTransform
}

public struct SmartFillSidecar: Codable {
    public let exportVersion: Int
    public let updatedAt: Int
    public let settings: SmartFillSettings?
    public let inputWidth: Double?
    public let inputHeight: Double?
    public let outputWidth: Double?
    public let outputHeight: Double?
    public let durationDelta: Double?
}

public struct OrientationPolicySidecar {
    public static func decision(for videoURL: URL) -> OrientationPolicyDecision {
        let sidecarURL = videoURL.deletingPathExtension().appendingPathExtension("smartfill.json")
        guard let data = try? Data(contentsOf: sidecarURL),
              let payload = try? JSONDecoder().decode(SmartFillSidecar.self, from: data) else {
            return .uiShouldApplyTransform
        }
        return payload.exportVersion >= 2 ? .uiShouldNotApplyTransform : .uiShouldApplyTransform
    }
    
    public static func write(
        for videoURL: URL,
        exportVersion: Int,
        settings: SmartFillSettings,
        inputSize: CGSize,
        outputSize: CGSize,
        durationDelta: Double
    ) throws {
        let sidecarURL = videoURL.deletingPathExtension().appendingPathExtension("smartfill.json")
        let payload = SmartFillSidecar(
            exportVersion: exportVersion,
            updatedAt: Int(Date().timeIntervalSince1970),
            settings: settings,
            inputWidth: inputSize.width,
            inputHeight: inputSize.height,
            outputWidth: outputSize.width,
            outputHeight: outputSize.height,
            durationDelta: durationDelta
        )
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(payload)
        try data.write(to: sidecarURL, options: [.atomic])
    }
}
