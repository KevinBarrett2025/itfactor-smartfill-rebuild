import Foundation
import Photos
import AVFoundation
import os

enum ImportEvent: Sendable {
    case jobUpdated(ImportJob)
    case jobCompleted(ImportJob, ProjectTake)
    case jobRemoved(UUID)
}

actor ImportQueue {
    static let shared = ImportQueue()
    
    private let logger = Logger(subsystem: "com.selftapestudio.app", category: "ImportQueue")
    private let store = ImportJobStore()
    private let maxConcurrentCopies = 2
    
    private var jobs: [UUID: ImportJob] = [:]
    private var runningTasks: [UUID: Task<Void, Never>] = [:]
    private var observers: [UUID: AsyncStream<ImportEvent>.Continuation] = [:]
    private var lastProgressEmit: [UUID: Date] = [:]
    
    private init() {
        Task { await restoreJobs() }
    }
    
    func subscribe() -> AsyncStream<ImportEvent> {
        AsyncStream { continuation in
            let id = UUID()
            observers[id] = continuation
            continuation.onTermination = { _ in
                Task { await self.removeObserver(id: id) }
            }
            for job in jobs.values {
                continuation.yield(.jobUpdated(job))
            }
        }
    }
    
    func enqueue(_ job: ImportJob) {
        jobs[job.id] = job
        persist()
        ImportLog.queue.info(
            "enqueue job=\(job.id.uuidString, privacy: .public) source=\(self.sourceLabel(job.source), privacy: .public) file=\(job.identifiers.fileName, privacy: .public)"
        )
        notify(.jobUpdated(job))
        startNextJobs()
    }
    
    func cancel(jobID: UUID) {
        if let task = runningTasks[jobID] {
            task.cancel()
        }
        guard var job = jobs[jobID] else { return }
        job.phase = .canceled
        job.progress = nil
        job.failure = ImportFailure(code: .canceled, message: "Canceled by user.")
        job.updatedAt = Date()
        jobs[jobID] = job
        persist()
        notify(.jobUpdated(job))
    }

    func remove(jobID: UUID, deleteTempFiles: Bool = true) {
        if let task = runningTasks[jobID] {
            task.cancel()
            runningTasks.removeValue(forKey: jobID)
        }
        jobs.removeValue(forKey: jobID)
        persist()
        notify(.jobRemoved(jobID))
        if deleteTempFiles {
            cleanupTempDirectory(jobID: jobID, tempPath: nil)
        }
    }

    func removeJobs(
        matching predicate: @Sendable (ImportJob) -> Bool,
        deleteTempFiles: Bool = true
    ) {
        let jobIDs = jobs.values
            .filter { predicate($0) }
            .map { $0.id }
        for jobID in jobIDs {
            remove(jobID: jobID, deleteTempFiles: deleteTempFiles)
        }
    }
    
    func retry(jobID: UUID) {
        guard var job = jobs[jobID] else { return }
        job.phase = .queued
        job.progress = nil
        job.failure = nil
        job.updatedAt = Date()
        jobs[jobID] = job
        persist()
        notify(.jobUpdated(job))
        startNextJobs()
    }
    
    func jobsSnapshot() -> [ImportJob] {
        Array(jobs.values)
    }
    
    // MARK: - Private
    
    private func removeObserver(id: UUID) {
        observers.removeValue(forKey: id)
    }
    
    private func notify(_ event: ImportEvent) {
        for continuation in observers.values {
            continuation.yield(event)
        }
    }
    
    private func persist() {
        store.save(Array(jobs.values))
    }
    
    private func restoreJobs() async {
        var restored = store.load()
        if !restored.isEmpty {
            restored = restored.map { job in
                var updated = job
                if updated.phase.isActive {
                    updated.phase = .queued
                    updated.progress = nil
                    updated.failure = nil
                    updated.updatedAt = Date()
                }
                return updated
            }
        }
        jobs = Dictionary(uniqueKeysWithValues: restored.map { ($0.id, $0) })
        persist()
        for job in jobs.values {
            notify(.jobUpdated(job))
        }
        startNextJobs()
    }
    
    private func startNextJobs() {
        let activeCount = runningTasks.count
        guard activeCount < maxConcurrentCopies else { return }
        let availableSlots = maxConcurrentCopies - activeCount
        let queuedJobs = jobs.values
            .filter { $0.phase == .queued }
            .sorted { $0.createdAt < $1.createdAt }
            .prefix(availableSlots)
        
        for job in queuedJobs {
            startJob(jobID: job.id)
        }
    }
    
    private func startJob(jobID: UUID) {
        guard runningTasks[jobID] == nil else { return }
        ImportLog.queue.info("start job=\(jobID.uuidString, privacy: .public)")
        runningTasks[jobID] = Task { [weak self] in
            guard let self else { return }
            await self.runJob(jobID: jobID)
        }
    }
    
    private func runJob(jobID: UUID) async {
        defer {
            runningTasks.removeValue(forKey: jobID)
            startNextJobs()
        }
        
        guard var job = jobs[jobID] else { return }
        ImportLog.queue.info(
            "run job=\(jobID.uuidString, privacy: .public) source=\(self.sourceLabel(job.source), privacy: .public) phase=\(job.phase.rawValue, privacy: .public)"
        )
        let stagedSourceURL: URL? = {
            if case .localFile(let url, _) = job.source {
                return url
            }
            return nil
        }()
        defer {
            cleanupTempDirectory(jobID: jobID, tempPath: job.tempPath)
            if let stagedSourceURL {
                FilePickerCopy.cleanupStagedFileIfNeeded(stagedSourceURL)
            }
        }
        
        do {
            if let updated = update(jobID: jobID, phase: .preparing, progress: nil, failure: nil) {
                job = updated
            }
            let tempURL = try prepareTempURL(for: job)
            job.tempPath = tempURL.path
            job.updatedAt = Date()
            jobs[jobID] = job
            persist()
            notify(.jobUpdated(job))
            
            if Task.isCancelled { throw CancellationError() }
            
            switch job.source {
            case .photos(let localIdentifier, _):
                if let updated = update(jobID: jobID, phase: .downloading, progress: 0, failure: nil) {
                    job = updated
                }
                try await PhotosImportResolver.writeVideoResource(
                    localIdentifier: localIdentifier,
                    to: tempURL,
                    progressHandler: { [weak self] progress in
                        Task { await self?.updateProgress(jobID: jobID, progress: progress) }
                    }
                )
                if let updated = update(jobID: jobID, phase: .copying, progress: 1.0, failure: nil) {
                    job = updated
                }
                
            case .files(let bookmark, _):
                if let updated = update(jobID: jobID, phase: .copying, progress: 0, failure: nil) {
                    job = updated
                }
                let access = try SecurityScopedAccess(bookmark: bookmark)
                defer { access.stop() }
                try await ImportFileIO.copyFile(
                    from: access.url,
                    to: tempURL,
                    progressHandler: { [weak self] progress in
                        Task { await self?.updateProgress(jobID: jobID, progress: progress) }
                    }
                )
                if let updated = update(jobID: jobID, phase: .copying, progress: 1.0, failure: nil) {
                    job = updated
                }
                
            case .localFile(let url, _):
                if let updated = update(jobID: jobID, phase: .copying, progress: 0, failure: nil) {
                    job = updated
                }
                try await ImportFileIO.copyFile(
                    from: url,
                    to: tempURL,
                    progressHandler: { [weak self] progress in
                        Task { await self?.updateProgress(jobID: jobID, progress: progress) }
                    }
                )
                if let updated = update(jobID: jobID, phase: .copying, progress: 1.0, failure: nil) {
                    job = updated
                }
            }
            
            if Task.isCancelled { throw CancellationError() }
            
            if let updated = update(jobID: jobID, phase: .verifying, progress: nil, failure: nil) {
                job = updated
            }
            if job.identifiers.isKeyframePhoto {
                try await ImportVerifier.verifyPhoto(at: tempURL)
            } else {
                try await ImportVerifier.verifyVideo(at: tempURL)
            }
            
            if Task.isCancelled { throw CancellationError() }
            if jobs[jobID] == nil { throw CancellationError() }
            
            if let updated = update(jobID: jobID, phase: .saving, progress: nil, failure: nil) {
                job = updated
            }
            let importedTake: ProjectTake
            if job.identifiers.isKeyframePhoto {
                importedTake = try await PhotoImportIO.buildImportedTake(
                    tempURL: tempURL,
                    identifiers: job.identifiers,
                    contextData: job.contextData
                )
            } else {
                importedTake = try await VideoImportIO.buildImportedTake(
                    tempURL: tempURL,
                    identifiers: job.identifiers,
                    contextData: job.contextData
                )
            }
            
            if let updated = update(jobID: jobID, phase: .ready, progress: 1.0, failure: nil) {
                job = updated
            }
            notify(.jobCompleted(job, importedTake))
            ImportLog.queue.info(
                "complete job=\(jobID.uuidString, privacy: .public) file=\(importedTake.filePath, privacy: .public)"
            )
        } catch is CancellationError {
            ImportLog.queue.info("canceled job=\(jobID.uuidString, privacy: .public)")
            _ = update(jobID: jobID, phase: .canceled, progress: nil, failure: ImportFailure(code: .canceled, message: "Canceled by user."))
        } catch {
            let failure = ImportQueue.mapFailure(error)
            _ = update(jobID: jobID, phase: .failed, progress: nil, failure: failure)
            logger.error("import_failed job=\(jobID.uuidString, privacy: .public) error=\(failure.message, privacy: .public)")
            ImportLog.queue.error(
                "failed job=\(jobID.uuidString, privacy: .public) error=\(failure.message, privacy: .public)"
            )
        }
    }
    
    private func updateProgress(jobID: UUID, progress: Double) async {
        guard let last = lastProgressEmit[jobID] else {
            lastProgressEmit[jobID] = Date()
            _ = update(jobID: jobID, phase: nil, progress: progress, failure: nil)
            return
        }
        let now = Date()
        guard now.timeIntervalSince(last) > 0.12 || progress >= 0.98 else { return }
        lastProgressEmit[jobID] = now
        _ = update(jobID: jobID, phase: nil, progress: progress, failure: nil)
    }
    
    private func update(jobID: UUID, phase: ImportPhase?, progress: Double?, failure: ImportFailure?) -> ImportJob? {
        guard var job = jobs[jobID] else { return nil }
        
        if let phase {
            job.phase = phase
            if progress == nil {
                job.progress = nil
            }
        }
        if let progress { job.progress = progress }
        if let failure { job.failure = failure }
        if phase == .ready { job.progress = 1.0 }
        job.updatedAt = Date()
        jobs[jobID] = job
        persist()
        notify(.jobUpdated(job))
        return job
    }

    private func cleanupTempDirectory(jobID: UUID, tempPath: String?) {
        let directoryURL: URL
        if let tempPath {
            directoryURL = URL(fileURLWithPath: tempPath).deletingLastPathComponent()
        } else {
            directoryURL = ImportPaths.tempDirectory(for: jobID)
        }
        if FileManager.default.fileExists(atPath: directoryURL.path) {
            try? FileManager.default.removeItem(at: directoryURL)
        }
    }
    
    private func prepareTempURL(for job: ImportJob) throws -> URL {
        let tempDir = ImportPaths.tempDirectory(for: job.id)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let destination = tempDir.appendingPathComponent(job.identifiers.fileName)
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        return destination
    }

    private func sourceLabel(_ source: ImportSource) -> String {
        switch source {
        case .photos:
            return "photos"
        case .files:
            return "files"
        case .localFile:
            return "localFile"
        }
    }
    
    private static func mapFailure(_ error: Error) -> ImportFailure {
        if let failure = error as? ImportFailure {
            return failure
        }
        let nsError = error as NSError
        let message = nsError.localizedDescription
        switch nsError.domain {
        case NSCocoaErrorDomain:
            return ImportFailure(code: .copyFailed, message: message)
        case PHPhotosErrorDomain:
            return ImportFailure(code: .downloadFailed, message: message)
        default:
            return ImportFailure(code: .unknown, message: message)
        }
    }
}

// MARK: - Helpers

private enum ImportPaths {
    static func tempDirectory(for jobID: UUID) -> URL {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("STS_ImportTemp", isDirectory: true)
            .appendingPathComponent(jobID.uuidString, isDirectory: true)
    }
    
    static func jobsFileURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("STS_ImportJobs", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir.appendingPathComponent("import_jobs.json")
    }
}

private struct ImportJobStore {
    func load() -> [ImportJob] {
        let url = ImportPaths.jobsFileURL()
        guard let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([ImportJob].self, from: data)) ?? []
    }
    
    func save(_ jobs: [ImportJob]) {
        let url = ImportPaths.jobsFileURL()
        guard let data = try? JSONEncoder().encode(jobs) else { return }
        try? data.write(to: url, options: .atomic)
    }
}

private struct SecurityScopedAccess {
    let url: URL
    private let didStart: Bool
    
    init(bookmark: Data) throws {
        var isStale = false
        let resolved = try URL(
            resolvingBookmarkData: bookmark,
            options: [],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )
        if isStale {
            throw ImportFailure(code: .accessDenied, message: "File access expired. Please re-select the file.")
        }
        self.url = resolved
        self.didStart = resolved.startAccessingSecurityScopedResource()
        if !didStart {
            throw ImportFailure(code: .accessDenied, message: "Could not access the selected file.")
        }
    }
    
    func stop() {
        if didStart {
            url.stopAccessingSecurityScopedResource()
        }
    }
}

private enum ImportFileIO {
    static func copyFile(
        from source: URL,
        to destination: URL,
        progressHandler: @escaping (Double) -> Void
    ) async throws {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    var coordinationError: NSError?
                    var blockError: NSError?
                    let coordinator = NSFileCoordinator()
                    coordinator.coordinate(readingItemAt: source, options: [], error: &coordinationError) { readURL in
                        do {
                            let size = (try readURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
                            let total = max(size, 1)
                            FileManager.default.createFile(atPath: destination.path, contents: nil)
                            let input = try FileHandle(forReadingFrom: readURL)
                            let output = try FileHandle(forWritingTo: destination)
                            defer {
                                try? input.close()
                                try? output.close()
                            }
                            let chunkSize = 1_048_576
                            var bytesCopied = 0
                            while true {
                                if Task.isCancelled { throw CancellationError() }
                                let data = try input.read(upToCount: chunkSize) ?? Data()
                                if data.isEmpty { break }
                                try output.write(contentsOf: data)
                                bytesCopied += data.count
                                let fraction = min(Double(bytesCopied) / Double(total), 1.0)
                                progressHandler(fraction)
                            }
                            progressHandler(1.0)
                        } catch {
                            blockError = error as NSError
                        }
                    }
                    if let blockError {
                        coordinationError = blockError
                    }
                    if let coordinationError { throw coordinationError }
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

private enum PhotosImportResolver {
    static func writeVideoResource(
        localIdentifier: String,
        to destination: URL,
        progressHandler: @escaping (Double) -> Void
    ) async throws {
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: [localIdentifier], options: nil)
        guard let asset = assets.firstObject else {
            throw ImportFailure(code: .fileNotFound, message: "Selected photo asset not found.")
        }
        
        let resources = PHAssetResource.assetResources(for: asset)
        let resource = resources.first(where: { $0.type == .video || $0.type == .fullSizeVideo || $0.type == .pairedVideo })
            ?? resources.first
        
        guard let resource else {
            throw ImportFailure(code: .downloadFailed, message: "Unable to access video resource.")
        }
        
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        
        let options = PHAssetResourceRequestOptions()
        options.isNetworkAccessAllowed = true
        options.progressHandler = { progress in
            progressHandler(progress)
        }
        
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            PHAssetResourceManager.default().writeData(
                for: resource,
                toFile: destination,
                options: options
            ) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    progressHandler(1.0)
                    continuation.resume(returning: ())
                }
            }
        }
        if Task.isCancelled {
            throw CancellationError()
        }
    }
}

private enum ImportVerifier {
    static func verifyVideo(at url: URL) async throws {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw ImportFailure(code: .verificationFailed, message: "Imported file is missing.")
        }
        let size = (try url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        guard size > 0 else {
            throw ImportFailure(code: .verificationFailed, message: "Imported file is empty.")
        }
        let asset = AVURLAsset(url: url)
        _ = try await asset.load(.duration)
    }

    static func verifyPhoto(at url: URL) async throws {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw ImportFailure(code: .verificationFailed, message: "Imported file is missing.")
        }
        let size = (try url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        guard size > 0 else {
            throw ImportFailure(code: .verificationFailed, message: "Imported file is empty.")
        }
    }
}
