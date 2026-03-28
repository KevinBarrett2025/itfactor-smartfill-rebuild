import AVFoundation
import SwiftUI
import Combine
import OSLog

/// Modern Enterprise SmartFill Manager - Single Source of Truth
/// Replaces all legacy systems with clean, modern architecture
@MainActor
public final class SmartFillManager: ObservableObject {
    
    // MARK: - Singleton
    public static let shared = SmartFillManager()
    
    // MARK: - Published State
    @Published public private(set) var isProcessing = false
    @Published public private(set) var processingProgress: Double = 0.0
    @Published public private(set) var lastError: SmartFillManagerError?
    
    // MARK: - Private Properties
    // 🚨 CRITICAL FIX: Remove direct compositor reference - use unified interface instead
    private let logger = Logger(subsystem: "SelfTapeStudio", category: "SmartFill")
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Settings Cache
    private var cachedSettings: SmartFillSettings?
    
    private init() {
        logger.info("🚀 SmartFillManager: Initialized enterprise SmartFill system")
    }
    
    // MARK: - Public API
    
    /// Check if a video needs SmartFill processing
    public func needsSmartFill(videoURL: URL) async -> Bool {
        do {
            let asset = AVURLAsset(url: videoURL)
            let tracks = try await asset.loadTracks(withMediaType: .video)
            
            guard let track = tracks.first else { return false }
            
            let naturalSize = try await track.load(.naturalSize)
            let preferredTransform = try await track.load(.preferredTransform)
            
            // Portrait detection
            let transformedSize = naturalSize.applying(preferredTransform)
            let isPortrait = abs(transformedSize.height) > abs(transformedSize.width)
            
            logger.debug("📐 Video analysis: \(String(describing: naturalSize)) → portrait: \(isPortrait)")
            return isPortrait
            
        } catch {
            logger.error("❌ Error analyzing video: \(error)")
            return false
        }
    }
    
    /// Check if SmartFill version exists
    public func hasSmartFillVersion(for videoURL: URL) -> Bool {
        let smartFillURL = getSmartFillURL(for: videoURL)
        let exists = FileManager.default.fileExists(atPath: smartFillURL.path)
        
        if exists {
            logger.debug("✅ SmartFill version exists: \(smartFillURL.lastPathComponent)")
        } else {
            logger.debug("❌ No SmartFill version: \(smartFillURL.lastPathComponent)")
        }
        
        return exists
    }
    
    /// Get SmartFill URL for a video
    public func getSmartFillURL(for videoURL: URL) -> URL {
        let fileName = videoURL.deletingPathExtension().lastPathComponent
        let smartFillFileName = "\(fileName)_smartfill.mov"
        
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let smartFillDir = documentsURL.appendingPathComponent("SmartFill")
        
        // Ensure directory exists
        try? FileManager.default.createDirectory(at: smartFillDir, withIntermediateDirectories: true)
        
        return smartFillDir.appendingPathComponent(smartFillFileName)
    }
    
    /// Process video with SmartFill
    public func processVideo(
        inputURL: URL,
        settings: SmartFillSettings = SmartFillSettings()
    ) async throws -> URL {
        
        guard !isProcessing else {
            throw SmartFillManagerError.alreadyProcessing
        }

        isProcessing = true
        processingProgress = 0.0
        lastError = nil
        

        defer {
            isProcessing = false
            processingProgress = 0.0
        }

        do {
            let outputURL = getSmartFillURL(for: inputURL)
            
            // 🚨 CRITICAL FIX: Enhanced preprocessing validation and diagnostics
                                                
            // Validate input file
            guard FileManager.default.fileExists(atPath: inputURL.path) else {
                throw SmartFillManagerError.processingFailed("Input video file not found")
            }

            // Analyze input video
            let asset = AVURLAsset(url: inputURL)
            let tracks = try await asset.loadTracks(withMediaType: .video)
            guard let videoTrack = tracks.first else {
                throw SmartFillManagerError.processingFailed("No video track found in input file")
            }

            let naturalSize = try await videoTrack.load(.naturalSize)
            let preferredTransform = try await videoTrack.load(.preferredTransform)
            let transformedSize = naturalSize.applying(preferredTransform)
            let isPortrait = abs(transformedSize.height) > abs(transformedSize.width)


                                                            
            guard isPortrait else {
                // Return input URL since no processing needed
                return inputURL
            }

            // Remove existing output file
            if FileManager.default.fileExists(atPath: outputURL.path) {
                try FileManager.default.removeItem(at: outputURL)
                            }

            // Ensure output directory exists
            try FileManager.default.createDirectory(
                at: outputURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )


            // 🚨 CRITICAL: Use unified interface for processing with enhanced error handling
            let result = try await SmartFillUnifiedInterface.shared.processVideo(
                inputURL: inputURL,
                outputURL: outputURL,
                settings: settings,
                progressCallback: { [weak self] progress in
                    DispatchQueue.main.async {
                        self?.processingProgress = Double(progress)
                    }
                }
            )


            if !result.success {
                throw SmartFillManagerError.processingFailed(result.notes ?? "Unknown exporter failure")
            }

            // 🚨 CRITICAL: Validate output file was created correctly
            guard FileManager.default.fileExists(atPath: outputURL.path) else {
                throw SmartFillManagerError.processingFailed("SmartFill processing completed but output file not found")
            }

            // Validate output file size
            let outputSize = try FileManager.default.attributesOfItem(atPath: outputURL.path)[.size] as? Int64 ?? 0
            guard outputSize > 100000 else { // Must be > 100KB
                throw SmartFillManagerError.processingFailed("SmartFill output file is too small - may be corrupted")
            }


            logger.info("✅ SmartFill processing completed successfully")
            logger.info("   📏 Output size: \(ByteCountFormatter.string(fromByteCount: outputSize, countStyle: .file))")

            return outputURL

        } catch {
            
            logger.error("❌ SmartFill processing failed: \(error)")
            lastError = SmartFillManagerError.processingFailed(error.localizedDescription)
            throw error
        }
    }
    
    /// 🚨 CRITICAL FIX: Create preview player using SAFE compositor
    /// This method now routes to the unified interface which uses SmartFillPreviewCompositor
    public func createPreviewPlayer(
        for videoURL: URL,
        settings: SmartFillSettings = SmartFillSettings()
    ) async throws -> ModernSmartFillPlayer {
        
        
        logger.info("🎬 SF-REBUILD-049: Creating hardened SmartFill preview player via unified interface")

        do {
            // 🚨 CRITICAL: Use unified interface which routes to SmartFillPreviewCompositor
            // This prevents the AVVideoCompositionCoreAnimationTool crash
            let avPlayer = try await SmartFillUnifiedInterface.shared.createPreviewPlayer(
                for: videoURL,
                settings: settings,
                modalFriendly: true // Enable modal-friendly mode for better stability
            )

            guard avPlayer.currentItem != nil else {
                throw SmartFillManagerError.invalidVideo
            }


            logger.info("✅ SF-REBUILD-049: Created hardened preview player without AVPlayerItem handoff")
            return ModernSmartFillPlayer(player: avPlayer)
            
        } catch {
            throw error
        }
    }
    
    // MARK: - Private Methods
    
    private func exportWithComposition(
        asset: AVAsset,
        videoComposition: AVVideoComposition,
        outputURL: URL
    ) async throws {
        
        guard let exportSession = AVAssetExportSession(
            asset: asset,
            presetName: AVAssetExportPresetHighestQuality
        ) else {
            throw SmartFillManagerError.exportFailed("Could not create export session")
        }
        
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mov
        exportSession.videoComposition = videoComposition
        exportSession.shouldOptimizeForNetworkUse = true
        
        // MODERNIZED: Replace deprecated progress timer and exportAsynchronously with STSExporter.run
        try await STSExporter.run(session: exportSession, to: outputURL, as: .mov) { [weak self] progress in
            DispatchQueue.main.async {
                self?.processingProgress = progress
            }
        }
    }
}

// MARK: - Modern Preview Player

@MainActor
public final class ModernSmartFillPlayer: ObservableObject {
    
    // MARK: - Published State
    @Published public private(set) var isPlaying = false
    @Published public private(set) var currentTime: Double = 0
    @Published public private(set) var duration: Double = 0
    @Published public private(set) var isReady = false
    @Published public private(set) var frameStepSeconds: Double = SmartFillPreviewFrameStep.defaultSeconds
    
    // MARK: - Properties
    public let player: AVPlayer
    private var cancellables = Set<AnyCancellable>()
    private let logger = Logger(subsystem: "SelfTapeStudio", category: "SmartFillPreview")
    
    convenience init(playerItem: AVPlayerItem) {
        self.init(player: AVPlayer(playerItem: playerItem))
    }

    init(player: AVPlayer) {
        self.player = player

        setupObservation()
        logger.info("🎬 ModernSmartFillPlayer: Initialized with modern Combine observation")
    }
    
    // MARK: - Public Methods
    
    public func play() {
        player.play()
        logger.debug("▶️ Started playback")
    }
    
    public func pause() {
        player.pause()
        logger.debug("⏸️ Paused playback")
    }
    
    public func seek(to time: CMTime) {
        player.seek(to: time)
        logger.debug("⏭️ Seeked to: \(time.seconds)s")
    }

    public func stepForwardOneFrame() {
        step(byFrames: 1)
    }

    public func stepBackwardOneFrame() {
        step(byFrames: -1)
    }
    
    // MARK: - Modern Combine Observation (No KVO!)
    
    private func setupObservation() {
        
        // Player status observation
        player.publisher(for: \.timeControlStatus)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.isPlaying = (status == .playing)
            }
            .store(in: &cancellables)
        
        // FIXED: Use modern Combine publisher for AVPlayer.status instead of deprecated AVPlayerItem.status
        player.publisher(for: \.status)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                guard let self else { return }
                self.isReady = (status == .readyToPlay)
                
                if status == .readyToPlay {
                    guard let asset = self.player.currentItem?.asset else { return }
                    // FIXED: Use modern async duration loading
                    Task { [weak self] in
                        do {
                            let duration = try await asset.load(.duration)
                            let tracks = try await asset.loadTracks(withMediaType: .video)
                            let nominalFrameRate = try await tracks.first?.load(.nominalFrameRate)
                            await MainActor.run {
                                guard let self else { return }
                                self.duration = duration.seconds
                                self.frameStepSeconds = SmartFillPreviewFrameStep.seconds(forNominalFrameRate: nominalFrameRate)
                                self.logger.info("✅ Player ready, duration: \(self.duration)s frameStep: \(self.frameStepSeconds)s")
                            }
                        } catch {
                            await MainActor.run {
                                self?.logger.error("Failed to load duration/frame rate: \(error)")
                            }
                        }
                    }
                }
            }
            .store(in: &cancellables)
        
        // Time observation
        player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.1, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            Task { @MainActor in
                self?.currentTime = time.seconds
            }
        }
        
        // End time notification
        NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime)
            .filter { [weak self] notification in
                notification.object as? AVPlayerItem === self?.player.currentItem
            }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.logger.debug("🔄 Video ended, seeking to start")
                self?.player.seek(to: .zero)
            }
            .store(in: &cancellables)
    }
    
    deinit {
        cancellables.removeAll()
        logger.info("🧹 ModernSmartFillPlayer: Cleaned up")
    }

    private func step(byFrames frames: Int) {
        guard frames != 0 else { return }
        let targetSeconds = SmartFillPreviewFrameStep.steppedTime(
            currentTime: currentTime,
            duration: duration,
            frameStepSeconds: frameStepSeconds,
            frames: frames
        )

        pause()
        currentTime = targetSeconds
        seek(to: CMTime(seconds: targetSeconds, preferredTimescale: 600))
    }
}

// MARK: - Error Types

public enum SmartFillManagerError: LocalizedError {
    case alreadyProcessing
    case processingFailed(String)
    case exportFailed(String)
    case invalidVideo
    
    public var errorDescription: String? {
        switch self {
        case .alreadyProcessing:
            return "SmartFill is already processing another video"
        case .processingFailed(let message):
            return "SmartFill processing failed: \(message)"
        case .exportFailed(let message):
            return "SmartFill export failed: \(message)"
        case .invalidVideo:
            return "Invalid video file"
        }
    }
}
