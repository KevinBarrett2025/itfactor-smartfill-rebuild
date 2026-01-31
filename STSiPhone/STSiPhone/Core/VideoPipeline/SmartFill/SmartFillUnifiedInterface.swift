import AVFoundation
import UIKit

/// 🚨 SIMPLIFIED FIX: Unified SmartFill interface using fixed SmartFillCIBuilder
/// BACK TO BASICS: Uses the working infinite extent protection approach
public final class SmartFillUnifiedInterface {
    
    // MARK: - Singleton Support (for backward compatibility)
    public static let shared = SmartFillUnifiedInterface()
    
    private init() {}
    
    // MARK: - Preview Creation (Simple Fallback)
    
    /// Creates preview player with fallback approach
    /// Simple and reliable - no complex compositor
    public static func createPreviewPlayer(
        for url: URL,
        settings: SmartFillSettings,
        modalFriendly: Bool = false
    ) async throws -> AVPlayer {
        
        print("🎬 SmartFillUnifiedInterface: Creating simple preview player")
        print("   📁 URL: \(url.lastPathComponent)")
        
        let asset = AVURLAsset(url: url)
        let comp  = try await SmartFillCIBuilder.makeComposition(asset: asset, settings: settings)
        let item = AVPlayerItem(asset: asset)
        item.videoComposition = comp
        let player = AVPlayer(playerItem: item)
        player.automaticallyWaitsToMinimizeStalling = false
        print("✅ SmartFillUnifiedInterface: Preview matches export CI composition")
        return player
    }
    
    /// Instance method for backward compatibility
    public func createPreviewPlayer(
        for url: URL,
        settings: SmartFillSettings,
        modalFriendly: Bool = false
    ) async throws -> AVPlayer {
        return try await Self.createPreviewPlayer(for: url, settings: settings, modalFriendly: modalFriendly)
    }
    
    // MARK: - Export Processing (Using Fixed SmartFillCIBuilder)

    /// Plan B: Private low-level API (async throws -> Void)
    private static func exportRawVideo(
        inputURL: URL,
        outputURL: URL,
        settings: SmartFillSettings,
        progressCallback: ((Float) -> Void)? = nil
    ) async throws {
        print("🎬 SmartFillUnifiedInterface: Processing with fixed SmartFillCIBuilder")
        print("   📁 Input: \(inputURL.lastPathComponent)")
        print("   📁 Output: \(outputURL.lastPathComponent)")
        
        let asset = AVURLAsset(url: inputURL)
        
        // Create video composition using fixed SmartFillCIBuilder
        let videoComposition = try await SmartFillCIBuilder.makeComposition(
            asset: asset,
            settings: settings
        )
        
        guard let session = AVAssetExportSession(
            asset: asset,
            presetName: AVAssetExportPresetHighestQuality
        ) else {
            throw SmartFillUnifiedInterfaceError.exportSessionCreationFailed
        }
        
        session.outputURL = outputURL
        session.outputFileType = .mov
        session.videoComposition = videoComposition
        session.shouldOptimizeForNetworkUse = false
        
        progressCallback?(0.0)
        
        if #available(iOS 18.0, *) {
            let progressTask = Task {
                for await state in session.states(updateInterval: 0.2) {
                    if case .exporting(let progressInfo) = state {
                        progressCallback?(Float(progressInfo.fractionCompleted))
                    }
                }
            }
            
            do {
                try await session.export(to: outputURL, as: .mov)
                progressTask.cancel()
                progressCallback?(1.0)
                print("✅ SmartFillUnifiedInterface: Export completed successfully")
            } catch {
                progressTask.cancel()
                throw SmartFillUnifiedInterfaceError.exportFailed(error.localizedDescription)
            }
        } else {
            let pollingTask = Task {
                while !Task.isCancelled {
                    progressCallback?(session.progress)
                    try await Task.sleep(nanoseconds: 200_000_000)
                }
            }
            
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
                session.exportAsynchronously { [weak session] in
                    pollingTask.cancel()
                    guard let session else {
                        continuation.resume(throwing: SmartFillUnifiedInterfaceError.exportCancelled)
                        return
                    }
                    
                    let statusRaw = session.value(forKey: "status") as? Int
                    let status = AVAssetExportSession.Status(rawValue: statusRaw ?? AVAssetExportSession.Status.unknown.rawValue)
                    let underlyingError = session.value(forKey: "error") as? Error
                    switch status {
                    case .completed:
                        progressCallback?(1.0)
                        print("✅ SmartFillUnifiedInterface: Export completed successfully")
                        continuation.resume()
                    case .cancelled:
                        continuation.resume(throwing: SmartFillUnifiedInterfaceError.exportCancelled)
                    case .failed:
                        let error = underlyingError ?? SmartFillUnifiedInterfaceError.exportFailed("Unknown error")
                        continuation.resume(throwing: error)
                    default:
                        if let error = underlyingError {
                            continuation.resume(throwing: error)
                        } else {
                            continuation.resume(throwing: SmartFillUnifiedInterfaceError.exportFailed("Unexpected status: \(String(describing: status))"))
                        }
                    }
                }
            }
        }
    }

    /// Public Plan B result-typed export API (returns SmartFillJobResult)
    public static func processVideo(
        inputURL: URL,
        outputURL: URL,
        settings: SmartFillSettings,
        progressCallback: ((Float) -> Void)? = nil
    ) async throws -> SmartFillJobResult {
        let t0 = CFAbsoluteTimeGetCurrent()

        // Use only the private, unambiguous implementation
        try await exportRawVideo(
            inputURL: inputURL,
            outputURL: outputURL,
            settings: settings,
            progressCallback: progressCallback
        )

        // Final file size if available
        var bytes: Int64? = nil
        if let values = try? outputURL.resourceValues(forKeys: [.fileSizeKey]),
           let sz = values.fileSize {
            bytes = Int64(sz)
        }

        let elapsed = CFAbsoluteTimeGetCurrent() - t0
        let outOk = FileManager.default.fileExists(atPath: outputURL.path)
        return SmartFillJobResult(
            success: outOk,
            compositorUsed: "SmartFillPreviewCompositor",
            processingTime: elapsed,
            inputURL: inputURL,
            outputURL: outOk ? outputURL : nil,
            bytesWritten: bytes,
            notes: outOk ? nil : "File was not created"
        )
    }
    
    /// Instance style for compat
    public func processVideo(
        inputURL: URL,
        outputURL: URL,
        settings: SmartFillSettings,
        progressCallback: ((Float) -> Void)? = nil
    ) async throws -> SmartFillJobResult {
        try await Self.processVideo(
            inputURL: inputURL,
            outputURL: outputURL,
            settings: settings,
            progressCallback: progressCallback
        )
    }
}

// MARK: - Error Handling

public enum SmartFillUnifiedInterfaceError: LocalizedError {
    case invalidAsset(String)
    case compositionCreationFailed(String)
    case exportSessionCreationFailed
    case exportFailed(String)
    case exportCancelled
    
    public var errorDescription: String? {
        switch self {
        case .invalidAsset(let details):
            return "Invalid asset: \(details)"
        case .compositionCreationFailed(let details):
            return "Failed to create composition: \(details)"
        case .exportSessionCreationFailed:
            return "Failed to create export session"
        case .exportFailed(let details):
            return "Export failed: \(details)"
        case .exportCancelled:
            return "Export was cancelled"
        }
    }
}
