import Foundation
import AVFoundation

enum VideoImportIO {
    static func buildImportedTake(
        tempURL: URL,
        identifiers: ImportIdentifiers,
        contextData: ImportContextData
    ) async throws -> ProjectTake {
        let asset = AVURLAsset(url: tempURL)
        let durationTime = try await asset.load(.duration)
        let durationSeconds = max(durationTime.seconds, 0)
        
        let metadata = VideoMetadata(
            projectTitle: contextData.projectTitle,
            roleName: contextData.roleName,
            sceneNumber: identifiers.sceneNumber,
            takeNumber: identifiers.takeNumber,
            rating: .unrated,
            duration: durationSeconds,
            recordingDate: Date(),
            notes: "Imported via Take Review"
        )
        
        let savedVideo = try VideoFileManager.shared.saveVideo(
            from: tempURL,
            projectID: contextData.projectID,
            sessionID: contextData.sessionID,
            fileName: identifiers.fileName,
            metadata: metadata
        )
        
        let relativePath = VideoVariantResolver.relativePath(from: savedVideo.url)
        let orientation = await inferOrientation(for: asset)
        
        return ProjectTake(
            filePath: relativePath,
            durationSeconds: durationSeconds,
            takeNotes: "Imported via Take Review",
            createdAt: Date(),
            sceneNumber: identifiers.sceneNumber,
            takeNumber: identifiers.takeNumber,
            slateNumber: identifiers.slateNumber,
            slateID: identifiers.slateID,
            capturedOrientation: orientation,
            takeType: identifiers.isSlate ? .slate : .regular
        )
    }
    
    /// Modern async helper to load the transformed video extent without deprecated APIs.
    private static func loadTransformedVideoSize(for asset: AVAsset) async throws -> CGSize {
        let videoTracks = try await asset.loadTracks(withMediaType: .video)
        guard let track = videoTracks.first else { return .zero }
        let naturalSize = try await track.load(.naturalSize)
        let preferredTransform = try await track.load(.preferredTransform)
        return naturalSize.applying(preferredTransform)
    }
    
    private static func inferOrientation(for asset: AVAsset) async -> VideoOrientation? {
        let transformedSize: CGSize
        do {
            transformedSize = try await loadTransformedVideoSize(for: asset)
        } catch {
            print("⚠️ Failed to infer orientation: \(error)")
            return nil
        }
        return abs(transformedSize.width) >= abs(transformedSize.height) ? .landscape : .portrait
    }
}
