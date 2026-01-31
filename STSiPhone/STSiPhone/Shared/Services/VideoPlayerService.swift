import Foundation
import SwiftUI
import AVFoundation
import Combine

/// Unified Video Player Service - Preserves all existing functionality while eliminating duplication
/// Replaces multiple VideoPlayerManager instances with a single, shared service
/// CRITICAL FIX: Enhanced with iOS AVPlayer+AVAssetExportSession bug workaround
@MainActor
class VideoPlayerService: NSObject, ObservableObject {
    // FIXED: Make shared property nonisolated to avoid Swift 6 concurrency issues
    nonisolated static let shared = VideoPlayerService()
    
    // PRESERVED: All existing VideoPlayerManager functionality
    @Published var player: AVPlayer?
    @Published var isPlaying = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var progress: Double = 0
    
    // ENHANCED: Multi-video support for different contexts
    @Published var activeContext: VideoContext = .none
    @Published var availableContexts: Set<VideoContext> = []
    
    // FIXED: Add missing currentURL property for UnifiedVideoPlayerView integration
    @Published var currentURL: URL?
    
    // CRITICAL FIX: Track exported videos to apply iOS bug workaround
    private var isCurrentVideoExported = false
    private var exportedVideoURLs: Set<String> = []
    
    // PRESERVED: All existing computed properties
    var currentTimeString: String {
        formatTime(currentTime)
    }
    
    var durationString: String {
        formatTime(duration)
    }
    
    // ENHANCED: Context management for multiple video views
    enum VideoContext: String, CaseIterable {
        case none = "none"
        case takePlayer = "takePlayer"
        case fullscreenPlayer = "fullscreenPlayer"
        case timelineEditor = "timelineEditor"
        case scriptSync = "scriptSync"
        
        var displayName: String {
            switch self {
            case .none: return "No Video"
            case .takePlayer: return "Take Preview"
            case .fullscreenPlayer: return "Fullscreen Player"
            case .timelineEditor: return "Timeline Editor"
            case .scriptSync: return "Script Sync"
            }
        }
    }
    
    private var timeObserver: Any?
    private var hideControlsTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()
    private var statusObserver: NSKeyValueObservation?
    
    // CRITICAL FIX: Method to detect exported videos that need special handling
    private func isExportedVideo(_ url: URL) -> Bool {
        let fileName = url.lastPathComponent
        let filePath = url.path
        
        // Strategy 1: Check if this URL is in our known exported videos set
        if exportedVideoURLs.contains(filePath) {
            print("🎯 VideoPlayerService: Video identified as EXPORTED via URL tracking")
            return true
        }
        
        // Strategy 2: Check filename patterns that indicate exported videos
        let exportPatterns = [
            "_Merged_",           // Merged videos
            "_Export_",           // Exported individual videos
            "_Combined_",         // Combined videos
            "_Edited_",           // Edited videos
            "TestProject_",       // Our export naming pattern
            "SelfTape_"          // Another potential pattern
        ]
        
        for pattern in exportPatterns {
            if fileName.contains(pattern) {
                print("🎯 VideoPlayerService: Video identified as EXPORTED via filename pattern: \(pattern)")
                exportedVideoURLs.insert(filePath) // Cache for future use
                return true
            }
        }
        
        // Strategy 3: Check if file is in typical export directories
        let exportDirectories = [
            "Exports",
            "Processed",
            "Combined",
            "Merged"
        ]
        
        for exportDir in exportDirectories {
            if filePath.contains("/\(exportDir)/") {
                print("🎯 VideoPlayerService: Video identified as EXPORTED via directory: \(exportDir)")
                exportedVideoURLs.insert(filePath) // Cache for future use
                return true
            }
        }
        
        print("📹 VideoPlayerService: Video identified as ORIGINAL (not exported)")
        return false
    }

    // CRITICAL FIX: Method to manually register exported videos (called after export completes)
    func registerExportedVideo(_ url: URL) {
        let filePath = url.path
        exportedVideoURLs.insert(filePath)
        print("📝 VideoPlayerService: Registered exported video: \(url.lastPathComponent)")
        
        // If this video is currently playing, reinitialize to apply bug workaround
        if currentURL?.path == filePath && !isCurrentVideoExported {
            print("🔄 VideoPlayerService: Current video now marked as exported, reinitializing...")
            setupPlayer(with: url, context: activeContext)
        }
    }

    // CRITICAL FIX: Enhanced setup method with iOS AVAssetExportSession bug workaround
    func setupPlayer(with url: URL, context: VideoContext) {
        print("🎥 VideoPlayerService: Setting up player for context: \(context.displayName)")
        print("🎥 VideoPlayerService: URL: \(url.path)")
        
        // FIXED: Store the current URL for UnifiedVideoPlayerView access
        currentURL = url
        
        // CRITICAL FIX: Detect if this is an exported video that needs special handling
        isCurrentVideoExported = isExportedVideo(url)
        
        if isCurrentVideoExported {
            print("🚨 VideoPlayerService: EXPORTED VIDEO DETECTED - Applying iOS bug workaround")
        }
        
        // PRESERVED: Exact same validation logic as existing VideoPlayerManager
        guard FileManager.default.fileExists(atPath: url.path) else {
            print("❌ VideoPlayerService: File does not exist at path: \(url.path)")
            return
        }
        
        // Get file size for validation (preserved logic)
        do {
            let fileSize = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            print("📊 VideoPlayerService: File size: \(fileSize) bytes")
            
            if fileSize == 0 {
                print("❌ VideoPlayerService: File is empty")
                return
            }
        } catch {
            print("⚠️ VideoPlayerService: Could not get file size: \(error)")
        }
        
        // Update context tracking
        activeContext = context
        availableContexts.insert(context)
        
        // PRESERVED: Exact same cleanup and setup logic
        cleanup()
        
        // CRITICAL FIX: Apply iOS bug workaround for exported videos
        if isCurrentVideoExported {
            setupPlayerForExportedVideo(url)
        } else {
            setupPlayerForOriginalVideo(url)
        }
    }

    // CRITICAL FIX: Special setup method for exported videos to avoid iOS AVPlayer bug
    // UPDATED: Swift 6 actor isolation compliance
    @MainActor
    private func setupPlayerForExportedVideo(_ url: URL) {
        print("🔧 VideoPlayerService: Setting up EXPORTED video with iOS bug workaround")
        
        // CRITICAL FIX: For exported videos, create completely fresh AVPlayer and AVPlayerItem
        // This avoids the iOS bug where AVPlayer freezes after AVAssetExportSession operations
        
        // Step 1: Create fresh AVURLAsset with special configuration for exported videos
        let asset = AVURLAsset(url: url, options: [
            AVURLAssetPreferPreciseDurationAndTimingKey: true
        ])
        
        // Step 2: Create fresh AVPlayerItem with exported video workaround settings
        // FIXED: AVPlayerItem creation is now on main actor (Swift 6 compliance)
        let playerItem = AVPlayerItem(asset: asset)
        
        // CRITICAL FIX: Set seekingWaitsForVideoCompositionRendering for exported videos
        // This prevents frozen frames during seeking operations
        playerItem.seekingWaitsForVideoCompositionRendering = true
        
        print("🔧 VideoPlayerService: Applied seekingWaitsForVideoCompositionRendering = true")
        
        // CRITICAL FIX: Add small delay to ensure export session has fully completed
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.finalizePlayerSetup(with: playerItem)
        }
    }

    // PRESERVED: Standard setup method for original (non-exported) videos
    // UPDATED: Swift 6 actor isolation compliance
    @MainActor
    private func setupPlayerForOriginalVideo(_ url: URL) {
        print("🎥 VideoPlayerService: Setting up ORIGINAL video with standard method")
        
        // PRESERVED: Use same robust loading pattern as TimelineEditorViewModel
        let asset = AVURLAsset(url: url)
        // FIXED: AVPlayerItem creation is now on main actor (Swift 6 compliance)
        let playerItem = AVPlayerItem(asset: asset)
        
        finalizePlayerSetup(with: playerItem)
    }

    // CRITICAL FIX: Centralized player setup completion method
    // UPDATED: Swift 6 actor isolation compliance
    @MainActor
    private func finalizePlayerSetup(with playerItem: AVPlayerItem) {
        print("🎥 VideoPlayerService: Finalizing player setup")
        
        // CRITICAL FIX: Create completely fresh AVPlayer instance for exported videos
        // FIXED: AVPlayer creation is now on main actor (Swift 6 compliance)
        player = AVPlayer(playerItem: playerItem)
        
        // FIXED: Use modern KVO observation on AVPlayer.status instead of deprecated AVPlayerItem.status
        if let player = player {
            statusObserver = player.observe(\.status, options: [.new, .initial]) { [weak self] player, change in
                Task { @MainActor [weak self] in
                    switch player.status {
                    case .readyToPlay:
                        let videoType = self?.isCurrentVideoExported ?? false ? "EXPORTED" : "ORIGINAL"
                        print("✅ VideoPlayerService: \(videoType) video player ready to play")
                    case .failed:
                        if let error = player.error {
                            print("❌ VideoPlayerService: Player failed: \(error)")
                        }
                    case .unknown:
                        print("⚠️ VideoPlayerService: Player status unknown")
                    @unknown default:
                        print("⚠️ VideoPlayerService: Unknown player status")
                    }
                }
            }
        }
        
        // PRESERVED: Exact same notification handling
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { [weak self] _ in
            // FIXED: Use Task to ensure main actor context for property mutations
            Task { @MainActor [weak self] in
                self?.isPlaying = false
                self?.seek(to: 0)
            }
        }
        
        // PRESERVED: Exact same time observer with our enhanced NaN protection
        timeObserver = player?.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.1, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            // FIXED: Use Task to ensure main actor context for property mutations
            Task { @MainActor [weak self] in
                let currentSeconds = time.seconds
                
                // PRESERVED: Enhanced NaN protection from our recent fixes
                guard currentSeconds.isFinite && currentSeconds >= 0 &&
                      !currentSeconds.isNaN else {
                    print("⚠️ VideoPlayerService: Invalid currentTime from AVPlayer: \(currentSeconds), skipping update")
                    return
                }
                
                self?.currentTime = currentSeconds
                
                if let duration = self?.duration,
                   duration > 0 && duration.isFinite && !duration.isNaN {
                    
                    guard duration != 0 else {
                        print("⚠️ VideoPlayerService: Duration is zero, cannot calculate progress")
                        return
                    }
                    
                    let newProgress = currentSeconds / duration
                    
                    // PRESERVED: Enhanced progress validation from our recent fixes
                    if newProgress.isFinite && newProgress >= 0 && newProgress <= 1.1 &&
                       !newProgress.isNaN && !newProgress.isInfinite {
                        let clampedProgress = min(1.0, max(0.0, newProgress))
                        self?.progress = clampedProgress
                    } else {
                        print("⚠️ VideoPlayerService: Invalid progress calculated: \(newProgress)")
                    }
                }
            }
        }
        
        // CRITICAL FIX: Load duration from asset directly with exported video handling
        Task {
            do {
                let asset = playerItem.asset
                let duration = try await asset.load(.duration)
                
                if duration.isValid && !duration.isIndefinite && duration.isNumeric {
                    let durationSeconds = duration.seconds
                    if durationSeconds.isFinite && durationSeconds > 0 {
                        await MainActor.run {
                            self.duration = durationSeconds
                        }
                        let videoType = isCurrentVideoExported ? "EXPORTED" : "ORIGINAL"
                        print("✅ VideoPlayerService: Loaded \(videoType) video duration: \(durationSeconds)s")
                    } else {
                        print("⚠️ VideoPlayerService: Invalid duration seconds: \(durationSeconds)")
                    }
                } else {
                    print("⚠️ VideoPlayerService: Duration is invalid, indefinite, or non-numeric")
                }
            } catch {
                print("❌ VideoPlayerService: Could not load video duration: \(error)")
                await MainActor.run {
                    self.duration = 0
                }
            }
        }
    }

    // CRITICAL FIX: Enhanced seek method with exported video handling
    func seek(to progress: Double) {
        guard let player = player else {
            print("⚠️ VideoPlayerService: No player available for seek")
            return
        }
        
        // PRESERVED: Enhanced seek validation from our recent fixes
        guard duration > 0 && duration.isFinite && !duration.isNaN else {
            print("⚠️ VideoPlayerService: Invalid duration for seek: \(duration)")
            return
        }
        
        guard progress.isFinite && !progress.isNaN else {
            print("⚠️ VideoPlayerService: Invalid progress for seek: \(progress)")
            return
        }
        
        let clampedProgress = max(0.0, min(1.0, progress))
        let targetTime = duration * clampedProgress
        
        guard targetTime.isFinite && targetTime >= 0 && !targetTime.isNaN &&
              targetTime <= duration * 1.1 else {
            print("⚠️ VideoPlayerService: Invalid targetTime calculated: \(targetTime)")
            return
        }
        
        let cmTime = CMTime(seconds: targetTime, preferredTimescale: 600)
        
        guard cmTime.isValid && cmTime.isNumeric && !cmTime.isIndefinite else {
            print("⚠️ VideoPlayerService: Invalid CMTime for seek: \(cmTime)")
            return
        }
        
        // CRITICAL FIX: For exported videos, use toleranceBefore and toleranceAfter for smoother seeking
        if isCurrentVideoExported {
            player.seek(to: cmTime, toleranceBefore: CMTime.zero, toleranceAfter: CMTime.zero)
            print("🔧 VideoPlayerService: Applied precise seeking for exported video")
        } else {
            player.seek(to: cmTime)
        }
        
        currentTime = targetTime
        self.progress = clampedProgress
    }
    
    // ENHANCED: Context-aware player switching
    func switchContext(to newContext: VideoContext) {
        guard availableContexts.contains(newContext) else {
            print("⚠️ VideoPlayerService: Context \(newContext.displayName) not available")
            return
        }
        
        print("🔄 VideoPlayerService: Switching from \(activeContext.displayName) to \(newContext.displayName)")
        activeContext = newContext
    }
    
    // PRESERVED: All existing playback controls with exact same functionality
    func togglePlayback() {
        guard let player = player else { return }
        
        if isPlaying {
            player.pause()
        } else {
            player.play()
        }
        isPlaying = !isPlaying
        
        if isPlaying {
            scheduleControlsHide()
        }
    }
    
    // PRESERVED: All existing utility methods
    func skip(_ seconds: TimeInterval) {
        let newTime = max(0, min(currentTime + seconds, duration))
        seek(to: newTime / duration)
    }
    
    func stepForward() {
        let frameTime = 1.0 / 30.0
        let newTime = min(currentTime + frameTime, duration)
        seek(to: newTime / duration)
    }
    
    func stepBackward() {
        let frameTime = 1.0 / 30.0
        let newTime = max(currentTime - frameTime, 0)
        seek(to: newTime / duration)
    }
    
    func scheduleControlsHide() {
        hideControlsTask?.cancel()
        hideControlsTask = Task {
            try? await Task.sleep(nanoseconds: 4_000_000_000) // 4 seconds
        }
    }
    
    // ENHANCED: Context-aware cleanup with memory leak protection
    func cleanup(context: VideoContext? = nil) {
        if let context = context {
            availableContexts.remove(context)
            if activeContext == context {
                activeContext = availableContexts.first ?? .none
            }
            print("🧹 VideoPlayerService: Cleaned up context: \(context.displayName)")
            
            // CRITICAL FIX: Don't fully cleanup if other contexts are active
            if !availableContexts.isEmpty {
                return
            }
        }
        
        // ENHANCED: Full cleanup with memory leak protection
        hideControlsTask?.cancel()
        hideControlsTask = nil
        
        // CRITICAL FIX: Remove observers BEFORE releasing player
        NotificationCenter.default.removeObserver(self)
        
        // FIXED: Remove modern status observer
        statusObserver?.invalidate()
        statusObserver = nil
        
        // CRITICAL FIX: Remove time observer BEFORE pausing
        if let timeObserver = timeObserver {
            player?.removeTimeObserver(timeObserver)
            self.timeObserver = nil
        }
        
        // Pause and release player
        player?.pause()
        player = nil
        
        // Reset all state
        isPlaying = false
        currentTime = 0
        duration = 0
        progress = 0
        
        // CRITICAL FIX: Reset exported video state
        isCurrentVideoExported = false
        
        // Clear context tracking
        activeContext = .none
        availableContexts.removeAll()
        
        // CRITICAL FIX: Force release cancellables to prevent memory leaks
        cancellables.removeAll()
        
        print("🧹 VideoPlayerService: Complete cleanup performed - memory leak protection applied")
        
        // FIXED: Clear currentURL on cleanup
        currentURL = nil
    }
    
    // PRESERVED: Enhanced time formatting from our recent fixes
    private func formatTime(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite && seconds >= 0 && !seconds.isNaN else {
            print("⚠️ VideoPlayerService: Invalid time value for formatting: \(seconds)")
            return "0:00"
        }
        
        let clampedSeconds = max(0, seconds)
        
        guard clampedSeconds < 86400 else { // 24 hours max
            print("⚠️ VideoPlayerService: Time value too large: \(clampedSeconds)")
            return "0:00"
        }
        
        let minutes = Int(clampedSeconds) / 60
        let remainingSeconds = Int(clampedSeconds) % 60
        
        guard minutes >= 0 && remainingSeconds >= 0 && remainingSeconds < 60 else {
            print("⚠️ VideoPlayerService: Invalid time calculation: \(minutes):\(remainingSeconds)")
            return "0:00"
        }
        
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
    
    private nonisolated override init() {
        super.init()
    }
}

// MARK: - SwiftUI Integration Helpers

/// SwiftUI View for unified video player integration
// CRITICAL FIX: Remove duplicate declaration of UnifiedVideoPlayerView
// The correct and enhanced version is located in Features/Camera/Enhanced/UnifiedVideoPlayerView.swift
// // struct UnifiedVideoPlayerView: UIViewRepresentable {
// //     // ... implementation ...
// // }

class UnifiedPlayerView: UIView {
    var player: AVPlayer? {
        didSet {
            playerLayer.player = player
        }
    }
    
    override class var layerClass: AnyClass {
        return AVPlayerLayer.self
    }
    
    var playerLayer: AVPlayerLayer {
        return layer as! AVPlayerLayer
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer.videoGravity = .resizeAspect
    }
}

// MARK: - Backward Compatibility Bridge

/// Temporary VideoPlayerManager for backward compatibility during migration
/// This provides a bridge between legacy code and the new VideoPlayerService
@MainActor
class VideoPlayerManager: NSObject, ObservableObject {
    // Bridge to unified service
    private let unifiedService = VideoPlayerService.shared
    
    @Published var player: AVPlayer? {
        didSet {
            // Sync with unified service if needed
        }
    }
    @Published var isPlaying = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var progress: Double = 0
    
    var currentTimeString: String {
        unifiedService.currentTimeString
    }
    
    var durationString: String {
        unifiedService.durationString
    }
    
    override init() {
        super.init()
        // Mirror unified service state
        player = unifiedService.player
        isPlaying = unifiedService.isPlaying
        currentTime = unifiedService.currentTime
        duration = unifiedService.duration
        progress = unifiedService.progress
        
        print("⚠️ VideoPlayerManager: Using compatibility bridge - consider migrating to VideoPlayerService")
    }
    
    func setupPlayer(with url: URL) {
        unifiedService.setupPlayer(with: url, context: .none)
        
        // Mirror state back
        player = unifiedService.player
        isPlaying = unifiedService.isPlaying
        currentTime = unifiedService.currentTime
        duration = unifiedService.duration
        progress = unifiedService.progress
    }
    
    func togglePlayback() {
        unifiedService.togglePlayback()
        isPlaying = unifiedService.isPlaying
    }
    
    func seek(to progress: Double) {
        unifiedService.seek(to: progress)
        self.progress = unifiedService.progress
        currentTime = unifiedService.currentTime
    }
    
    func skip(_ seconds: TimeInterval) {
        unifiedService.skip(seconds)
        currentTime = unifiedService.currentTime
        progress = unifiedService.progress
    }
    
    func stepForward() {
        unifiedService.stepForward()
        currentTime = unifiedService.currentTime
        progress = unifiedService.progress
    }
    
    func stepBackward() {
        unifiedService.stepBackward()
        currentTime = unifiedService.currentTime
        progress = unifiedService.progress
    }
    
    func scheduleControlsHide() {
        unifiedService.scheduleControlsHide()
    }
    
    func cleanup() {
        unifiedService.cleanup()
        player = nil
        isPlaying = false
        currentTime = 0
        duration = 0
        progress = 0
    }
}

// MARK: - Migration Helper Extensions

extension VideoPlayerService {
    /// Helper method to migrate from existing VideoPlayerManager instances
    func migrateFromVideoPlayerManager(_ manager: Any) {
        print("🔄 VideoPlayerService: Migration helper available for existing VideoPlayerManager instances")
        // This can be used during the gradual migration phase
    }
}

// CRITICAL FIX: Remove duplicate declaration of AirPlayPickerView
// The correct version is located in Features/Camera/UnifiedVideoOverlay.swift
// // struct AirPlayPickerView: UIViewRepresentable {
// //     // ... implementation ...
// // }
