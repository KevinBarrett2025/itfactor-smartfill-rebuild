import Foundation
import UIKit

@MainActor
protocol SmartFillHandling: AnyObject {
    var onEvent: ((CoordinatorEvent) -> Void)? { get set }
    func start(for take: ProjectTake, sessionID: UUID, projectID: UUID, repository: ProjectsRepository)
}

@MainActor
final class SmartFillController: NSObject, SmartFillProcessingDelegate, SmartFillHandling {
    var onEvent: ((CoordinatorEvent) -> Void)?

    func start(for take: ProjectTake, sessionID: UUID, projectID: UUID, repository: ProjectsRepository) {
        print("🎭 SMARTFILL TOOL: Starting SmartFill processing for take \(take.id)")
        
        // Get the correct paths
        let originalURL = VideoVariantResolver.originalURL(for: take)
        let fileName = originalURL.lastPathComponent
        let outputURL = SmartFillManager.shared.getSmartFillURL(for: originalURL)
        
        // Use the existing enqueueJob method
        Task { [weak self] in
            guard let self = self else { return }
            let queued = await SmartFillProcessingManager.shared.enqueueJob(
                originalPath: originalURL.path,
                outputPath: outputURL.path,
                fileName: fileName,
                takeID: take.id,
                sessionID: sessionID,
                projectID: projectID,
                capturedOrientation: take.capturedOrientation,
                settings: SmartFillSettings()
            )
            
            await MainActor.run {
                if queued {
                    SmartFillProcessingManager.shared.delegate = self
                    print("✅ SMARTFILL TOOL: Job enqueued (output: \(outputURL.lastPathComponent))")
                } else {
                    print("ℹ️ SMARTFILL TOOL: Job not enqueued (orientation check failed)")
                    NotificationCenter.default.post(
                        name: .smartFillProcessingFailed,
                        object: nil,
                        userInfo: ["error": "SmartFill not required for this clip"]
                    )
                }
            }
        }
    }

    // MARK: - SmartFillProcessingDelegate
    func smartFillDidFinish(takeID: UUID, outputURL: URL) {
        print("✅ SMARTFILL TOOL: SmartFill completed - output: \(outputURL.lastPathComponent)")
        onEvent?(.smartFillFinished(outputURL: outputURL))
    }

    func smartFillDidFail(takeID: UUID, error: Error) {
        print("❌ SMARTFILL TOOL: SmartFill failed: \(error.localizedDescription)")
        // Could emit error event here if coordinator needs to handle failures
    }
}
