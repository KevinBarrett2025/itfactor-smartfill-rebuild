import Foundation
import UIKit
import BackgroundTasks
import AVFoundation
import CoreVideo
import CoreMedia
import CoreImage
import os

// MARK: - SmartFill Processing Delegate

/// Delegate protocol for SmartFill processing completion callbacks
@MainActor
public protocol SmartFillProcessingDelegate: AnyObject {
    func smartFillDidFinish(takeID: UUID, outputURL: URL)
    func smartFillDidFail(takeID: UUID, error: Error)
}

/// SmartFill Background Processing Manager
/// Handles queued, throttled background processing of portrait videos with proper resource management
/// 🔥 ARCHITECTURAL UPDATE: Now routes through SmartFillUnifiedInterface for intelligent compositor selection
@MainActor
public final class SmartFillProcessingManager: ObservableObject {
    public static let shared = SmartFillProcessingManager()
    
    // MARK: - Delegate Support
    public weak var delegate: SmartFillProcessingDelegate?
    
    // MARK: - Job Management
    
    public struct SmartFillJob: Identifiable {
        public let id = UUID()
        public let originalPath: String
        public let outputPath: String
        public let fileName: String
        public let takeID: UUID
        public let sessionID: UUID
        public let projectID: UUID
        public let capturedOrientation: VideoOrientation?
        public let settings: SmartFillSettings
        public let createdAt: Date
        public var retryCount: Int = 0
        public var status: JobStatus = .pending
        public var lastError: Error?
        public var progress: Double = 0.0
        
        // KEVIN'S FIX: Store output duration for standalone video creation
        public var outputDurationSeconds: Double = 0.0
        public let settingsSnapshot: SmartFillSettingsSnapshot
        
        public enum JobStatus: String, CaseIterable, Sendable {
            case pending = "pending"
            case processing = "processing"
            case completed = "completed"
            case failed = "failed"
            case paused = "paused"       // For battery/thermal throttling
            case cancelled = "cancelled"
            
            public var displayName: String {
                switch self {
                case .pending: return "Pending"
                case .processing: return "Processing"
                case .completed: return "Completed"
                case .failed: return "Failed"
                case .paused: return "Paused"
                case .cancelled: return "Cancelled"
                }
            }
            
            public var isActive: Bool {
                return self == .processing || self == .pending
            }
            
            public var isCompleted: Bool {
                return self == .completed || self == .failed || self == .cancelled
            }
        }
    }
    
    // MARK: - State Management
    
    @Published public private(set) var jobs: [SmartFillJob] = []
    @Published public private(set) var isProcessing: Bool = false
    @Published public private(set) var currentJob: SmartFillJob?
    @Published public private(set) var processingPaused: Bool = false
    
    // Resource monitoring
    @Published public private(set) var batteryLevel: Float = 1.0
    @Published public private(set) var thermalState: ProcessInfo.ThermalState = .nominal
    @Published public private(set) var isLowPowerModeEnabled: Bool = false
    
    // Configuration
    private let maxConcurrentJobs: Int = 1  // Serial processing to prevent resource conflicts
    private let maxRetryAttempts: Int = 3
    private let minBatteryLevel: Float = 0.20  // Don't process below 20% battery
    private let exportVersion = 2

    // Processing queue
    private nonisolated let worker = SmartFillWorker()
    private let logger = Logger(subsystem: "com.selftapestudio.app", category: "SmartFill")
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    
    // Notifications
    public static let jobStatusDidChange = Notification.Name("SmartFillJobStatusDidChange")
    public static let processingDidComplete = Notification.Name("SmartFillProcessingDidComplete")
    public static let processingWasPaused = Notification.Name("SmartFillProcessingWasPaused")
    public static let processingWasResumed = Notification.Name("SmartFillProcessingWasResumed")
    
    private init() {
        setupResourceMonitoring()
        setupBackgroundProcessing()
        
        self.logger.info("smartfill_manager_init")
    }
    
    // MARK: - Public API
    
    /// Add a SmartFill job to the processing queue
    @discardableResult
    public func enqueueJob(
        originalPath: String,
        outputPath: String,
        fileName: String,
        takeID: UUID,
        sessionID: UUID,
        projectID: UUID,
        capturedOrientation: VideoOrientation?,
        settings: SmartFillSettings = SmartFillSettings()
    ) async -> Bool {
        // Validate that original file exists
        guard FileManager.default.fileExists(atPath: originalPath) else {
            self.logger.error("smartfill_enqueue_missing_file path=\(originalPath, privacy: .private)")
            return false
        }

        var effectiveOrientation = capturedOrientation
        if effectiveOrientation != .portrait {
            let assetURL = URL(fileURLWithPath: originalPath)
            let asset = AVURLAsset(url: assetURL)
            do {
                let analysis = try await NormalizeOrientation.analyzeVideoOrientation(from: asset)
                effectiveOrientation = analysis.capturedOrientation
                self.logger.debug("smartfill_orientation_analysis file=\(fileName, privacy: .public) orientation=\(analysis.capturedOrientation.displayName, privacy: .public)")
            } catch {
                self.logger.warning("smartfill_orientation_failed file=\(fileName, privacy: .public) error=\(error.localizedDescription, privacy: .public)")
            }
        }

        guard effectiveOrientation == .portrait else {
            self.logger.info("smartfill_skip_orientation file=\(fileName, privacy: .public) orientation=\(effectiveOrientation?.displayName ?? "Unknown", privacy: .public)")
            return false
        }
        
        // Check if we already have a job for this file
        if self.jobs.contains(where: { $0.originalPath == originalPath && $0.status.isActive }) {
            self.logger.info("smartfill_enqueue_duplicate file=\(fileName, privacy: .public)")
            return false
        }
        
        let normalizedSettings = settings.clamped()
        let job = SmartFillJob(
            originalPath: originalPath,
            outputPath: outputPath,
            fileName: fileName,
            takeID: takeID,
            sessionID: sessionID,
            projectID: projectID,
            capturedOrientation: effectiveOrientation,
            settings: normalizedSettings,
            createdAt: Date(),
            settingsSnapshot: SmartFillSettingsSnapshot(settings: normalizedSettings)
        )
        
        self.jobs.append(job)
        
        self.logger.info("smartfill_job_enqueued file=\(fileName, privacy: .public) orientation=\(effectiveOrientation?.displayName ?? "Unknown", privacy: .public) queueSize=\(self.jobs.filter { $0.status.isActive }.count)")
        
        // Start processing if not already running
        if !self.isProcessing {
            startProcessing()
        }
        return true
    }
    
    /// Get active jobs for a specific session
    public func getActiveJobs(for sessionID: UUID) -> [SmartFillJob] {
        return self.jobs.filter { $0.sessionID == sessionID && $0.status.isActive }
    }
    
    /// Get completed jobs for a specific session
    public func getCompletedJobs(for sessionID: UUID) -> [SmartFillJob] {
        return self.jobs.filter { $0.sessionID == sessionID && $0.status.isCompleted }
    }
    
    /// Cancel all pending jobs for a session
    public func cancelJobs(for sessionID: UUID) {
        for index in self.jobs.indices {
            if self.jobs[index].sessionID == sessionID && self.jobs[index].status == .pending {
                self.jobs[index].status = .cancelled
            }
        }
        
        self.logger.info("smartfill_cancel_pending session=\(sessionID.uuidString, privacy: .public)")
    }
    
    /// Pause processing (useful for battery/thermal management)
    public func pauseProcessing() {
        self.processingPaused = true
        self.logger.info("smartfill_paused")
        
        NotificationCenter.default.post(name: Self.processingWasPaused, object: nil)
    }
    
    /// Resume processing
    public func resumeProcessing() {
        self.processingPaused = false
        self.logger.info("smartfill_resumed")
        
        NotificationCenter.default.post(name: Self.processingWasResumed, object: nil)
        
        // Continue processing if we have pending jobs
        if !self.isProcessing && self.hasPendingJobs() {
            self.startProcessing()
        }
    }
    
    /// Force retry a failed job
    public func retryJob(jobID: UUID) {
        guard let index = self.jobs.firstIndex(where: { $0.id == jobID }),
              self.jobs[index].status == .failed else {
            self.logger.warning("smartfill_retry_missing job=\(jobID.uuidString, privacy: .public)")
            return
        }
        
        self.jobs[index].status = .pending
        self.jobs[index].retryCount = 0
        self.jobs[index].lastError = nil
        self.jobs[index].progress = 0.0
        
        self.logger.info("smartfill_retry file=\(self.jobs[index].fileName, privacy: .public) attempt=\(self.jobs[index].retryCount + 1)")
        
        if !self.isProcessing {
            startProcessing()
        }
    }
    
    /// Get status summary for UI display
    public var statusSummary: (active: Int, pending: Int, processing: Int, failed: Int) {
        let active = self.jobs.filter { $0.status.isActive }.count
        let pending = self.jobs.filter { $0.status == .pending }.count
        let processing = self.jobs.filter { $0.status == .processing }.count
        let failed = self.jobs.filter { $0.status == .failed }.count
        
        return (active: active, pending: pending, processing: processing, failed: failed)
    }
    
    // MARK: - Resource Monitoring
    
    private func setupResourceMonitoring() {
        // Battery monitoring
        UIDevice.current.isBatteryMonitoringEnabled = true
        batteryLevel = UIDevice.current.batteryLevel
        
        NotificationCenter.default.addObserver(
            forName: UIDevice.batteryLevelDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.batteryLevel = UIDevice.current.batteryLevel
                self?.evaluateResourceConstraints()
            }
        }
        
        // Low power mode monitoring
        isLowPowerModeEnabled = ProcessInfo.processInfo.isLowPowerModeEnabled
        
        NotificationCenter.default.addObserver(
            forName: .NSProcessInfoPowerStateDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.isLowPowerModeEnabled = ProcessInfo.processInfo.isLowPowerModeEnabled
                self?.evaluateResourceConstraints()
            }
        }
        
        // Thermal state monitoring
        thermalState = ProcessInfo.processInfo.thermalState
        
        NotificationCenter.default.addObserver(
            forName: ProcessInfo.thermalStateDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.thermalState = ProcessInfo.processInfo.thermalState
                self?.evaluateResourceConstraints()
            }
        }
        
        // App lifecycle monitoring
        NotificationCenter.default.addObserver(
            forName: UIApplication.willResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleAppWillResignActive()
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleAppDidBecomeActive()
            }
        }
    }
    
    private func evaluateResourceConstraints() {
        let shouldPause = self.batteryLevel < self.minBatteryLevel ||
                         self.isLowPowerModeEnabled ||
                         self.thermalState == .critical ||
                         self.thermalState == .serious
        
        if shouldPause && !self.processingPaused {
            self.logger.warning("smartfill_auto_pause battery=\(Int(self.batteryLevel * 100)) lowPower=\(self.isLowPowerModeEnabled) thermal=\(self.thermalState.rawValue)")
            self.pauseProcessing()
        } else if !shouldPause && self.processingPaused {
            self.logger.info("smartfill_auto_resume")
            self.resumeProcessing()
        }
    }
    
    // MARK: - Background Processing
    
    private func setupBackgroundProcessing() {
        // Register background task identifier
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: "com.selftapestudio.smartfill",
            using: nil
        ) { [weak self] task in
            guard let self else { return }
            self.handleBackgroundTask(task as! BGProcessingTask)
        }
    }
    
    private func handleBackgroundTask(_ task: BGProcessingTask) {
        self.logger.debug("smartfill_background_task_start")
        
        task.expirationHandler = { [weak self] in
            self?.logger.warning("smartfill_background_task_expired")
            task.setTaskCompleted(success: false)
        }
        
        // Process in background
        Task { [weak self] in
            guard let self else { return }
            await self.processBackgroundJobs()
            task.setTaskCompleted(success: true)
        }
    }
    
    private func handleAppWillResignActive() {
        // Request background processing time
        if self.hasPendingJobs() {
            self.scheduleBackgroundProcessing()
        }
    }
    
    private func handleAppDidBecomeActive() {
        // Resume foreground processing if needed
        if !self.isProcessing && self.hasPendingJobs() && !self.processingPaused {
            self.startProcessing()
        }
    }
    
    private func scheduleBackgroundProcessing() {
        let request = BGProcessingTaskRequest(identifier: "com.selftapestudio.smartfill")
        request.requiresNetworkConnectivity = false
        request.requiresExternalPower = false
        request.earliestBeginDate = Date(timeIntervalSinceNow: 5) // Start after 5 seconds
        
        do {
            try BGTaskScheduler.shared.submit(request)
            self.logger.debug("smartfill_background_processing_scheduled")
        } catch {
            self.logger.error("smartfill_background_processing_schedule_failed error=\(error.localizedDescription, privacy: .public)")
        }
    }
    
    // MARK: - Processing Logic
    
    private func startProcessing() {
        guard !self.isProcessing, !self.processingPaused else { return }
        
        self.isProcessing = true
        
        Task { [weak self] in
            await self?.processJobs()
        }
    }
    
    private func processJobs() async {
        self.logger.debug("smartfill_processing_loop_start")
        
        while let jobIndex = self.getNextJobIndex() {
            guard !self.processingPaused else {
                self.logger.debug("smartfill_processing_loop_pause")
                break
            }
            
            await self.processJob(at: jobIndex)
        }

        await MainActor.run {
            self.isProcessing = false
            self.currentJob = nil
            self.logger.debug("smartfill_processing_loop_complete")
        }
    }
    
    private func processBackgroundJobs() async {
        self.logger.debug("smartfill_processing_background_start")
        
        // Process only the most important jobs in background
        let priorityJobs = self.jobs.enumerated().filter { (_, job) in
            job.status == .pending && job.retryCount == 0 // Only first-time jobs in background
        }.prefix(3) // Limit to 3 jobs in background

        for (index, _) in priorityJobs {
            await self.processJob(at: index)
        }
    }

    private func getNextJobIndex() -> Int? {
        return self.jobs.firstIndex { $0.status == .pending }
    }
    
    private func processJob(at index: Int) async {
        guard self.jobs.indices.contains(index) else { return }
        var job = self.jobs[index]
        job.status = .processing
        job.progress = 0.0
        job.lastError = nil
        self.jobs[index] = job
        self.currentJob = job

        self.logger.info("smartfill_job_start id=\(job.id.uuidString, privacy: .public) file=\(job.fileName, privacy: .public) retry=\(job.retryCount)")

        let context = SmartFillWorker.JobContext(
            jobID: job.id,
            originalPath: job.originalPath,
            outputPath: job.outputPath,
            fileName: job.fileName,
            settings: job.settings,
            capturedOrientation: job.capturedOrientation,
            minInputSizeBytes: 1_048_576,
            maxInputSizeBytes: 10 * 1024 * 1024 * 1024,
            maxDurationSeconds: 600,
            minOutputSizeBytes: 100 * 1024
        )

        let start = CFAbsoluteTimeGetCurrent()

        updateProgress(jobID: job.id, progress: 0.0)

        do {
            let output = try await worker.process(
                context: context,
                progress: { [weak self] fraction in
                    Task { @MainActor in
                        self?.updateProgress(jobID: job.id, progress: fraction)
                    }
                }
            )

            handleJobSuccess(
                jobID: job.id,
                output: output,
                processingTime: CFAbsoluteTimeGetCurrent() - start
            )
        } catch {
            handleJobFailure(jobID: job.id, error: error)
        }
    }

    private func updateProgress(jobID: UUID, progress: Double) {
        guard let index = self.jobs.firstIndex(where: { $0.id == jobID }) else { return }
        self.jobs[index].progress = min(max(progress, 0.0), 1.0)
        if self.currentJob?.id == jobID {
            self.currentJob = self.jobs[index]
        }
        NotificationCenter.default.post(
            name: .smartFillProcessingProgress,
            object: nil,
            userInfo: [
                "jobID": self.jobs[index].id,
                "progress": self.jobs[index].progress,
                "takeID": self.jobs[index].takeID,
                "sessionID": self.jobs[index].sessionID,
                "projectID": self.jobs[index].projectID
            ]
        )
    }

    private func handleJobSuccess(jobID: UUID, output: SmartFillWorker.Output, processingTime: Double) {
        guard let index = self.jobs.firstIndex(where: { $0.id == jobID }) else { return }
        var job = self.jobs[index]
        job.retryCount = 0
        job.lastError = nil
        job.outputDurationSeconds = output.durationSeconds

        do {
            try updateRepositoryWithResult(job: job)
            try OrientationPolicySidecar.write(
                for: URL(fileURLWithPath: job.outputPath),
                exportVersion: exportVersion,
                settings: job.settings,
                inputSize: output.validation.inputDisplaySize,
                outputSize: output.validation.outputDisplaySize,
                durationDelta: output.validation.durationDelta
            )
        } catch {
            handleJobFailure(jobID: job.id, error: error)
            return
        }

        updateProgress(jobID: job.id, progress: 1.0)
        job.status = .completed
        self.jobs[index] = job
        self.currentJob = job

        let sizeMB = Double(output.fileSize) / 1024 / 1024
        self.logger.info("smartfill_job_success id=\(job.id.uuidString, privacy: .public) file=\(job.fileName, privacy: .public) time=\(processingTime, format: .fixed(precision: 2)) sizeMB=\(sizeMB, format: .fixed(precision: 2)) aspect=\(output.validation.aspectRatio, format: .fixed(precision: 3)) durationDelta=\(output.validation.durationDelta, format: .fixed(precision: 3))")

        NotificationCenter.default.post(
            name: Self.jobStatusDidChange,
            object: nil,
            userInfo: [
                "jobID": job.id,
                "status": SmartFillJob.JobStatus.completed.rawValue,
                "takeID": job.takeID,
                "sessionID": job.sessionID,
                "projectID": job.projectID,
                "smartFillPath": job.outputPath,
                "processingTime": processingTime
            ]
        )
    }

    private func handleJobFailure(jobID: UUID, error: Error) {
        guard let index = self.jobs.firstIndex(where: { $0.id == jobID }) else { return }
        let job = self.jobs[index]
        self.logger.error("smartfill_job_failure id=\(job.id.uuidString, privacy: .public) file=\(job.fileName, privacy: .public) error=\(String(describing: error), privacy: .public)")

        if FileManager.default.fileExists(atPath: job.outputPath) {
            do {
                try FileManager.default.removeItem(atPath: job.outputPath)
                self.logger.debug("smartfill_cleanup_removed file=\(job.outputPath, privacy: .private)")
            } catch {
                self.logger.warning("smartfill_cleanup_failed file=\(job.outputPath, privacy: .private) error=\(String(describing: error), privacy: .public)")
            }
        }

        self.jobs[index].lastError = error
        self.jobs[index].progress = 0.0
        self.jobs[index].retryCount += 1

        if self.jobs[index].retryCount >= self.maxRetryAttempts {
            self.jobs[index].status = .failed
            self.logger.error("smartfill_job_exhausted id=\(job.id.uuidString, privacy: .public) attempts=\(self.maxRetryAttempts)")
        } else {
            self.jobs[index].status = .pending
            self.logger.info("smartfill_job_retry id=\(job.id.uuidString, privacy: .public) attempt=\(self.jobs[index].retryCount)")
        }

        self.currentJob = self.jobs[index]
        delegate?.smartFillDidFail(takeID: job.takeID, error: error)

        NotificationCenter.default.post(
            name: Self.jobStatusDidChange,
            object: nil,
            userInfo: [
                "jobID": job.id,
                "status": self.jobs[index].status.rawValue,
                "takeID": job.takeID,
                "sessionID": job.sessionID,
                "projectID": job.projectID,
                "error": error.localizedDescription,
                "retryCount": self.jobs[index].retryCount,
                "maxRetries": maxRetryAttempts
            ]
        )
    }

    // CRITICAL FIX: Modernize video validation with async APIs and proper main-actor compliance
    private func isValidVideoFile(at path: String) async -> Bool {
        // Quick file extension check first
        let url = URL(fileURLWithPath: path)
        let pathExtension = url.pathExtension.lowercased()
        let validExtensions = ["mov", "mp4", "m4v", "avi", "mkv"]
        
        guard validExtensions.contains(pathExtension) else {
            self.logger.error("smartfill_validation_invalid_extension path=\(path, privacy: .private) ext=\(pathExtension, privacy: .public)")
            return false
        }
        
        // Check file size - video files should be reasonably large
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: path),
              let fileSize = attributes[.size] as? Int64,
              fileSize > 10240 else { // At least 10KB for processed videos
            self.logger.error("smartfill_validation_small_file path=\(path, privacy: .private)")
            return false
        }
        
        // Enhanced AVAsset validation to ensure it's actually a playable video
        let asset = AVURLAsset(url: url)
        
        do {
            // MODERNIZED: Use async track loading
            let videoTracks = try await asset.loadTracks(withMediaType: .video)
            guard !videoTracks.isEmpty else {
                self.logger.error("smartfill_validation_missing_tracks file=\(url.lastPathComponent, privacy: .public)")
                return false
            }
            
            // MODERNIZED: Use async duration loading
            let duration = try await asset.load(.duration)
            let durationSeconds = CMTimeGetSeconds(duration)
            
            guard durationSeconds.isFinite && durationSeconds > 0 else {
                self.logger.error("smartfill_validation_invalid_duration file=\(url.lastPathComponent, privacy: .public) duration=\(durationSeconds, format: .fixed(precision: 2))")
                return false
            }
            
            self.logger.debug("smartfill_validation_ok file=\(url.lastPathComponent, privacy: .public) duration=\(durationSeconds, format: .fixed(precision: 2)) sizeMB=\(Double(fileSize) / 1024 / 1024, format: .fixed(precision: 2))")
            return true
            
        } catch {
            self.logger.error("smartfill_validation_failed path=\(path, privacy: .private) error=\(String(describing: error), privacy: .public)")
            return false
        }
    }
    
    private func updateRepositoryWithResult(job: SmartFillJob) throws {
        guard let repository = SessionManager.shared.repositoryInstance else {
            throw SmartFillProcessingError.processingFailed("No repository configured for SmartFill updates")
        }

        let adoption = try SmartFillResultBridge.adopt(job: job, repository: repository)

        self.logger.info(
            "smartfill_take_updated original=\(adoption.originalTakeID.uuidString, privacy: .public) adopted=\(adoption.adoptedTakeID.uuidString, privacy: .public) mode=\(adoption.approach, privacy: .public) path=\(job.outputPath, privacy: .private)"
        )

        delegate?.smartFillDidFinish(takeID: adoption.adoptedTakeID, outputURL: adoption.outputURL)

        NotificationCenter.default.post(
            name: .smartFillDidComplete,
            object: nil,
            userInfo: adoption.notificationUserInfo.merging(
                [AnyHashable("originalPath"): job.originalPath]
            ) { current, _ in current }
        )
        
        NotificationCenter.default.post(
            name: .smartFillProcessingComplete,
            object: nil,
            userInfo: adoption.notificationUserInfo.merging(
                [AnyHashable("outputURL"): adoption.outputURL]
            ) { current, _ in current }
        )
    }
    
    private func hasPendingJobs() -> Bool {
        return self.jobs.contains { $0.status == .pending }
    }
}

// MARK: - Plan B: Direct Typed Processing API (SmartFillJobResult)
import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

extension SmartFillProcessingManager {
    /// Plan B: Type-safe direct processing API for batch/one-off jobs
    /// - Returns: SmartFillJobResult (typed result)
    @MainActor
    public func process(
        inputURL: URL,
        settings: SmartFillSettings
    ) async throws -> SmartFillJobResult {
        let t0 = CFAbsoluteTimeGetCurrent()
        let compositorUsed: String
        let outputURL: URL?
        var bytes: Int64? = nil

        // Policy flag
        // Unified compositor is the only path; legacy retained for future expansion.
        compositorUsed = "SmartFillPreviewCompositor"
        outputURL = try? await exportUnified(inputURL: inputURL, settings: settings)

        if let out = outputURL,
           let values = try? out.resourceValues(forKeys: [.fileSizeKey]),
           let sz = values.fileSize {
            bytes = Int64(sz)
        }

        let elapsed = CFAbsoluteTimeGetCurrent() - t0
        return SmartFillJobResult(
            success: outputURL != nil,
            compositorUsed: compositorUsed,
            processingTime: elapsed,
            inputURL: inputURL,
            outputURL: outputURL,
            bytesWritten: bytes,
            notes: outputURL != nil ? nil : "Output not created"
        )
    }

    // MARK: - Adapter for legacy (completion-block based) callers
    @MainActor
    public func process(
        inputURL: URL,
        settings: SmartFillSettings,
        completion: @escaping (_ result: SmartFillJobResult) -> Void
    ) {
        Task {
            do {
                completion(try await process(inputURL: inputURL, settings: settings))
            } catch {
                completion(SmartFillJobResult(
                    success: false,
                    compositorUsed: "Error",
                    processingTime: 0,
                    inputURL: inputURL,
                    outputURL: nil,
                    notes: "Error: \(error)"
                ))
            }
        }
    }

    // MARK: - Export helpers (Plan B signatures)
    @MainActor
    private func exportUnified(inputURL: URL, settings: SmartFillSettings) async throws -> URL {
        let outputURL = SmartFillManager.shared.getSmartFillURL(for: inputURL)
        let result = try await SmartFillUnifiedInterface.shared.processVideo(
            inputURL: inputURL,
            outputURL: outputURL,
            settings: settings,
            progressCallback: nil
        )
        
        guard result.success, let finalURL = result.outputURL else {
            let message = result.notes ?? "Unified export failed without error details"
            throw SmartFillProcessingError.processingFailed(message)
        }
        
        return finalURL
    }

    @MainActor
    private func exportLegacy(inputURL: URL, settings: SmartFillSettings) async throws -> URL {
        try await SmartFillManager.shared.processVideo(
            inputURL: inputURL,
            settings: settings
        )
    }
}

private extension SmartFillSettingsSnapshot {
    init(settings: SmartFillSettings) {
        self.init(
            isEnabled: settings.isEnabled,
            blurRadius: Double(settings.blurRadius),
            darkenAmount: Double(settings.darkenAmount),
            backgroundScale: Double(settings.backgroundScale),
            foregroundScale: Double(settings.foregroundScale),
            backgroundSourceMode: settings.backgroundSourceMode.rawValue,
            backgroundAssetPath: settings.backgroundAssetPath,
            backgroundAssetDisplayName: settings.backgroundAssetDisplayName,
            backgroundVideoTakeID: settings.backgroundVideoTakeID,
            renderWidth: Double(settings.renderSize.width),
            renderHeight: Double(settings.renderSize.height),
            processingPriority: settings.processingPriority.rawValue,
            presetName: settings.presetName
        )
    }
}

// MARK: - Sendable Support

// MARK: - Error Types

public enum SmartFillProcessingError: LocalizedError {
    case inputFileNotFound
    case outputFileNotCreated
    case notPortraitVideo
    case processingFailed(String)
    case resourceConstraints(String)
    
    public var errorDescription: String? {
        switch self {
        case .inputFileNotFound:
            return "Input video file not found"
        case .outputFileNotCreated:
            return "SmartFill output file was not created"
        case .notPortraitVideo:
            return "Video is not portrait orientation"
        case .processingFailed(let reason):
            return "SmartFill processing failed: \(reason)"
        case .resourceConstraints(let reason):
            return "Processing paused due to resource constraints: \(reason)"
        }
    }
}
