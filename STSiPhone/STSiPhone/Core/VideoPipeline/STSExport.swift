import AVFoundation
import Foundation

/// Modern export wrapper that provides iOS 18+ async export support with fallback
public enum STSExport {
    
    /// Unified async export with improved error handling and sendability compliance
    public static func run(_ session: AVAssetExportSession) async throws {
        guard let outputURL = session.outputURL, let outputFileType = session.outputFileType else {
            throw STSExportFailure.parametersMissing
        }
        try await STSExporter.run(session: session, to: outputURL, as: outputFileType)
    }
    
    /// Export with progress monitoring
    public static func runWithProgress(
        _ session: AVAssetExportSession,
        progressHandler: @MainActor @escaping (Double) -> Void = { _ in }
    ) async throws {
        guard let outputURL = session.outputURL, let outputFileType = session.outputFileType else {
            throw STSExportFailure.parametersMissing
        }
        try await STSExporter.run(session: session, to: outputURL, as: outputFileType, progress: progressHandler)
    }
    
    /// Helper to create export session with modern settings
    public static func createSession(
        asset: AVAsset,
        outputURL: URL,
        presetName: String = AVAssetExportPresetHighestQuality
    ) -> AVAssetExportSession? {
        let session = AVAssetExportSession(asset: asset, presetName: presetName)
        session?.outputURL = outputURL
        session?.outputFileType = .mov // Default to .mov for compatibility
        return session
    }
    
    /// Helper to validate export session before running
    public static func validateSession(_ session: AVAssetExportSession) async throws {
        guard let outputURL = session.outputURL else {
            throw NSError(
                domain: "STS.Export.Validation",
                code: -100,
                userInfo: [NSLocalizedDescriptionKey: "Export session missing output URL"]
            )
        }
        
        // MODERNIZED: Use async load(.isExportable) instead of deprecated property
        guard try await session.asset.load(.isExportable) else {
            throw NSError(
                domain: "STS.Export.Validation",
                code: -101,
                userInfo: [NSLocalizedDescriptionKey: "Asset is not exportable"]
            )
        }
        
        // Ensure output directory exists
        let outputDir = outputURL.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: outputDir.path) {
            try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
        }
        
        // Remove existing file if present
        if FileManager.default.fileExists(atPath: outputURL.path) {
            try FileManager.default.removeItem(at: outputURL)
        }
    }
}

// MARK: - Export Error Types

public enum STSExportFailure: LocalizedError {
    case parametersMissing
    case cancelled
    case failed(underlying: Error?)
    case unexpectedState
    
    public var errorDescription: String? {
        switch self {
        case .parametersMissing:
            return "Export parameters missing (outputURL or fileType)"
        case .failed(let underlying):
            return "Export failed: \(underlying?.localizedDescription ?? "Unknown error")"
        case .cancelled:
            return "Export was cancelled"
        case .unexpectedState:
            return "Export ended with unexpected status"
        }
    }
}

// MARK: - STSExporter (iOS 18+ modernization)

public struct STSExporter {
    /// Unified export entry point used everywhere in STS.
    /// - Parameters:
    ///   - session: Preconfigured `AVAssetExportSession` (preset, timeRange, etc.).
    ///   - outputURL: Destination URL (required for iOS 18 `export(to:as:)`).
    ///   - fileType: Output type (e.g., `.mov`, `.mp4`).
    ///   - progress: Optional progress callback (0.0…1.0) delivered on MainActor.
    public static func run(
        session: AVAssetExportSession,
        to outputURL: URL,
        as fileType: AVFileType,
        progress: (@MainActor (Double) -> Void)? = nil
    ) async throws {
        
        
        if #available(iOS 18.0, *) {
            // Progress monitoring using async sequence.
            let seq = session.states(updateInterval: 0.2)
            let monitor = Task {
                for await status in seq {
                    // CRITICAL FIX: status is AVAssetExportSession.Status, not State
                    // No progress parameter in .exporting case - must access .progress property
                    if case .exporting = status {
                        // SWIFT 6 FIX: Capture progress locally to avoid non-Sendable capture
                        let currentProgress = session.progress
                        print("📤 STSExporter: progress=\(Int(currentProgress * 100))% preset=\(session.presetName)")
                        await MainActor.run { progress?(Double(currentProgress)) }
                        
                    }
                }
            }
            defer { monitor.cancel() }
            
            do {
                print("📤 STSExporter: export(to:as:) starting -> " + outputURL.lastPathComponent)
                try await session.export(to: outputURL, as: fileType)
                print("✅ STSExporter: export(to:as:) finished")
                
                
            } catch {
                throw error
            }
            
        } else {
            // Legacy path for iOS 17 and earlier
            do {
                // Start export progress polling
                
                print("📤 STSExporter: exportAsynchronously legacy starting -> " + (session.outputURL?.lastPathComponent ?? "<unknown>"))
                try await session.exportAsyncLegacy()
                print("✅ STSExporter: exportAsynchronously legacy finished")
                await MainActor.run { progress?(1.0) }
                
                
            } catch {
                throw error
            }
        }
    }
}

// MARK: - AVAssetExportSession Extensions

@available(iOS, deprecated: 18, message: "Use export(to:as:) instead of exportAsynchronously")
extension AVAssetExportSession {
    /// Legacy async wrapper for iOS < 18 to avoid deprecation noise.
    public func exportAsyncLegacy() async throws {
        try await withCheckedThrowingContinuation { [weak self] cont in
            self?.exportAsynchronously {
                cont.resume()
            }
        }
        
        // Check final status after completion - iOS version guarded
        if #available(iOS 18.0, *) {
            // Use modern error handling - would need states() for real implementation
            return
        } else {
            switch self.status {
            case .completed:
                return
            case .failed:
                throw STSExportFailure.failed(underlying: self.error)
            case .cancelled:
                throw STSExportFailure.cancelled
            default:
                throw STSExportFailure.unexpectedState
            }
        }
    }
    
    /// Unified async export method that replaces deprecated status/error polling
    public func exportAsync() async throws {
        guard let outputURL = self.outputURL, let outputFileType = self.outputFileType else {
            throw STSExportFailure.parametersMissing
        }
        try await STSExporter.run(session: self, to: outputURL, as: outputFileType)
    }
}

// MARK: - Convenience Extensions

public extension AVAssetExportSession {
    
    /// Export using STSExport wrapper with validation
    func exportWithSTS() async throws {
        try await STSExport.validateSession(self)
        try await STSExport.run(self)
    }
    
    /// Export using STSExport wrapper with progress monitoring
    func exportWithSTSProgress(
        progressHandler: @MainActor @escaping (Double) -> Void = { _ in }
    ) async throws {
        try await STSExport.validateSession(self)
        try await STSExport.runWithProgress(self, progressHandler: progressHandler)
    }
}
