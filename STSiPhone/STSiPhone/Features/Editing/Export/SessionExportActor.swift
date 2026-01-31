import Foundation
import AVFoundation

private struct UncheckedExportSession: @unchecked Sendable {
    let session: AVAssetExportSession
}

private extension AVAssetExportSession {
    /// Project deployment target is iOS 18.5+, so use the modern async API directly.
    func exportCompat(to url: URL, fileType: AVFileType) async throws {
        try await self.export(to: url, as: fileType)
    }
}

public actor SessionExportActor {
    public init() {}

    public func export(plan: ExportPlan,
                       options: SessionExportActorOptions = .init(),
                       progress: @Sendable @escaping (Double) -> Void,
                       cancellationToken: CancellationToken) async throws -> URL {

        try? FileManager.default.removeItem(at: plan.outputURL)

        guard let session = AVAssetExportSession(asset: plan.asset, presetName: plan.presetName) else {
            throw SessionExportActorError.cannotCreateSession
        }

        session.outputURL = plan.outputURL
        session.outputFileType = plan.outputFileType
        session.videoComposition = plan.videoComposition
        session.audioMix = plan.audioMix
        if let range = plan.timeRange {
            session.timeRange = range
        }
        if !plan.metadata.isEmpty {
            session.metadata = plan.metadata
            session.metadataItemFilter = AVMetadataItemFilter.forSharing()
        }

        if #available(iOS 18.0, macOS 15.0, *) {
            let sessionBox = UncheckedExportSession(session: session)
            let interval = options.progressIntervalMilliseconds
            let updateInterval = max(0.05, TimeInterval(interval) / 1_000.0)

            let progressTask = Task.detached(priority: .utility) { [sessionBox, cancellationToken, progress, updateInterval] in
                let states = sessionBox.session.states(updateInterval: updateInterval)
                for await _ in states {
                    if Task.isCancelled { break }
                    if cancellationToken.isCancelled {
                        sessionBox.session.cancelExport()
                    }
                    progress(max(0.0, min(1.0, Double(sessionBox.session.progress))))
                }
            }

            // Supplemental ticker to keep UI moving even if states are sparse
            let ticker = Task.detached(priority: .utility) { [sessionBox, cancellationToken, progress] in
                while !Task.isCancelled {
                    if cancellationToken.isCancelled { break }
                    let p = Double(sessionBox.session.progress)
                    progress(max(0.0, min(1.0, p)))
                    try? await Task.sleep(nanoseconds: 500_000_000)
                }
            }

            do {
                try await session.exportCompat(to: plan.outputURL, fileType: plan.outputFileType)
                progressTask.cancel()
                ticker.cancel()
                if !cancellationToken.isCancelled {
                    progress(1.0)
                }
                return plan.outputURL
            } catch {
                progressTask.cancel()
                ticker.cancel()
                if cancellationToken.isCancelled {
                    session.cancelExport()
                    throw CancellationError()
                }
                let err = error as NSError
                print("❌ ExportSession failed: domain=\(err.domain) code=\(err.code) info=\(err.userInfo) outputURL=\(plan.outputURL) fileType=\(plan.outputFileType.rawValue) preset=\(session.presetName)")
                throw error
            }
        } else {
            let intervalMilliseconds = max(50, options.progressIntervalMilliseconds)
            let pollingInterval = UInt64(intervalMilliseconds) * 1_000_000
            let sessionBox = UncheckedExportSession(session: session)

            let progressTask = Task.detached(priority: .utility) { [sessionBox, cancellationToken, progress, pollingInterval] in
                let session = sessionBox.session
                while !Task.isCancelled {
                    if cancellationToken.isCancelled {
                        session.cancelExport()
                        break
                    }
                    progress(max(0.0, min(1.0, Double(session.progress))))
                    try await Task.sleep(nanoseconds: pollingInterval)
                }
            }

            // Supplemental ticker to keep UI moving
            let ticker = Task.detached(priority: .utility) { [sessionBox, cancellationToken, progress] in
                while !Task.isCancelled {
                    if cancellationToken.isCancelled { break }
                    let p = Double(sessionBox.session.progress)
                    progress(max(0.0, min(1.0, p)))
                    try? await Task.sleep(nanoseconds: 500_000_000)
                }
            }

            do {
                try await session.exportCompat(to: plan.outputURL, fileType: plan.outputFileType)
                progressTask.cancel()
                ticker.cancel()

                if !cancellationToken.isCancelled {
                    progress(1.0)
                }
                return plan.outputURL
            } catch {
                progressTask.cancel()
                ticker.cancel()
                if cancellationToken.isCancelled {
                    session.cancelExport()
                    throw CancellationError()
                }
                throw error
            }
        }
    }
}

public enum SessionExportActorError: Error {
    case cannotCreateSession
    case failed(status: AVAssetExportSession.Status)
}

extension SessionExportActorError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .cannotCreateSession:
            return "Unable to create export session"
        case .failed(let status):
            return "Export failed with status: \(status.rawValue)"
        }
    }
}
