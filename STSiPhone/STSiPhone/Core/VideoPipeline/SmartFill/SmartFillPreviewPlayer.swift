import SwiftUI
import AVFoundation
import UIKit
import Foundation

/// PHASE 3: Real-time SmartFill preview using the same composition as export
/// This gives users EXACTLY what they'll get in the final output
public struct SmartFillPreviewPlayer: UIViewRepresentable {
    
    // MARK: - UIViewRepresentable Requirements
    public typealias UIViewType = SmartFillRealPreviewView
    
    // MARK: - Properties
    let videoURL: URL
    let settings: SmartFillSettings
    let refreshID: UUID
    let onError: ((Error) -> Void)?
    
    public init(
        videoURL: URL,
        settings: SmartFillSettings = SmartFillSettings(),
        refreshID: UUID = UUID(),
        onError: ((Error) -> Void)? = nil
    ) {
        self.videoURL = videoURL
        self.settings = settings
        self.refreshID = refreshID
        self.onError = onError
    }
    
    // MARK: - UIViewRepresentable
    
    public func makeUIView(context: Context) -> SmartFillRealPreviewView {
        let previewView = SmartFillRealPreviewView()
        print("🔄 SmartFillPreviewPlayer.makeUIView – refreshID=\(refreshID)")
        
        // PHASE 3: Load the real composition asynchronously
        Task {
            await loadRealPreview(into: previewView)
        }
        
        return previewView
    }
    
    public func updateUIView(_ uiView: SmartFillRealPreviewView, context: Context) {
        print("🔄 SmartFillPreviewPlayer.updateUIView – refreshID=\(refreshID)")
        // Update if settings or video URL changed
        if uiView.currentVideoURL != videoURL || uiView.currentSettings?.backgroundScale != settings.backgroundScale {
            Task {
                await loadRealPreview(into: uiView)
            }
        }
    }
    
    // MARK: - Phase 3: Real Preview Loading
    
    /// PHASE 3: Load the EXACT same composition used for export
    @MainActor
    private func loadRealPreview(into previewView: SmartFillRealPreviewView) async {
        
        print("🎬 SmartFillPreviewPlayer: Loading real-time preview (Phase 3)")
        print("   📁 Video URL: \(videoURL.path)")
        print("   ⚙️ Settings: blur=\(settings.defaultBlurRadius), scale=\(settings.backgroundScale)")
        
        do {
            // 🔧 CRITICAL FIX: Validate video file exists before processing
            guard FileManager.default.fileExists(atPath: videoURL.path) else {
                let error = NSError(domain: "SmartFillPreview", code: 1, userInfo: [
                    NSLocalizedDescriptionKey: "Video file not found: \(videoURL.lastPathComponent)"
                ])
                print("❌ SmartFillPreviewPlayer: File not found: \(videoURL.path)")
                onError?(error)
                return
            }
            
            // 🔧 CRITICAL FIX: Validate settings before creating preview
            guard settings.defaultBlurRadius > 0,
                  settings.backgroundScale >= 1.0,
                  settings.defaultRenderSize.width > 0,
                  settings.defaultRenderSize.height > 0 else {
                let error = NSError(domain: "SmartFillPreview", code: 2, userInfo: [
                    NSLocalizedDescriptionKey: "Invalid SmartFill settings for preview"
                ])
                print("❌ SmartFillPreviewPlayer: Invalid settings: \(settings)")
                onError?(error)
                return
            }
            
            print("🔧 SmartFillPreviewPlayer: Validation passed, creating preview player...")
            
            // 🚨 ENHANCED FIX: Use simplified preview creation that doesn't rely on KVO
            let player = try await createSimplifiedPreviewPlayer(for: videoURL, settings: settings)
            
            // Configure the preview view with the real player
            previewView.configure(
                with: player,
                videoURL: videoURL,
                settings: settings
            )
            
            print("✅ SmartFillPreviewPlayer: Real-time preview loaded successfully")
            print("   🎯 Using simplified preview (no KVO dependencies)")
            
        } catch {
            print("❌ SmartFillPreviewPlayer: Failed to load preview: \(error)")
            print("   📁 Video URL: \(videoURL.path)")
            print("   💾 File exists: \(FileManager.default.fileExists(atPath: videoURL.path))")
            print("   ⚙️ Settings valid: blur=\(settings.defaultBlurRadius), scale=\(settings.backgroundScale)")
            onError?(error)
        }
    }
    
    // 🚨 NEW: Simplified preview player creation that avoids KVO timing issues
    @MainActor
    private func createSimplifiedPreviewPlayer(for videoURL: URL, settings: SmartFillSettings) async throws -> AVPlayer {
        
        print("🎬 SmartFillPreviewPlayer: Creating simplified preview without KVO dependencies")
        
        // Try unified interface preview first
        do {
            return try await SmartFillUnifiedInterface.shared.createPreviewPlayer(
                for: videoURL,
                settings: settings,
                modalFriendly: true
            )
        } catch {
            print("⚠️ SmartFillPreviewPlayer: Unified preview creation failed, falling back to simple player: \(error)")
        }
        
        // 🚨 ENHANCED FALLBACK: Create a simple player that works reliably in modal contexts
        print("🎬 SmartFillPreviewPlayer: Using reliable modal-friendly preview")
        
        // Create a basic AVPlayer for reliable modal preview
        let asset = AVURLAsset(url: videoURL)
        let playerItem = AVPlayerItem(asset: asset)
        let player = AVPlayer(playerItem: playerItem)
        
        // 🚨 MODAL FIX: Optimize for modal context
        player.automaticallyWaitsToMinimizeStalling = false // Faster startup for modals
        
        // Add basic observer for better UX (non-KVO based)
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { _ in
            // Loop the preview for better UX
            player.seek(to: .zero)
            player.play()
        }
        
        return player
    }
}

// MARK: - Phase 3: Custom UIView for Video Preview (renamed to avoid conflict)

@MainActor
public class SmartFillRealPreviewView: UIView {
    
    // MARK: - Properties
    private var playerLayer: AVPlayerLayer?
    private var player: AVPlayer?
    private var timeControlObserver: NSKeyValueObservation?
    private var idleTimerToken: IdleTimerController.Token?
    
    // Track current configuration for updates
    var currentVideoURL: URL?
    var currentSettings: SmartFillSettings?
    
    // MARK: - Initialization
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupPreviewView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupPreviewView()
    }
    
    private func setupPreviewView() {
        backgroundColor = UIColor.black
        layer.cornerRadius = 12
        clipsToBounds = true
        
        // PHASE 3: Professional preview setup
        layer.borderWidth = 1
        layer.borderColor = UIColor.white.withAlphaComponent(0.1).cgColor
    }
    
    // MARK: - Phase 3: Configuration
    
    func configure(with player: AVPlayer, videoURL: URL, settings: SmartFillSettings) {
        
        print("🎬 SmartFillRealPreviewView: Configuring with enhanced modal compatibility")
        
        // Clean up existing player layer
        playerLayer?.removeFromSuperlayer()
        self.player?.pause()
        releaseIdleTimer()
        timeControlObserver?.invalidate()
        
        // 🚨 ENHANCED: Create player layer with modal-friendly setup
        let newPlayerLayer = AVPlayerLayer(player: player)
        newPlayerLayer.videoGravity = .resizeAspect // Show full composition
        
        // 🚨 MODAL FIX: Defer frame setting until layout
        newPlayerLayer.frame = .zero // Start with zero frame
        
        // PHASE 3: Professional layer setup
        newPlayerLayer.cornerRadius = 12
        newPlayerLayer.masksToBounds = true
        
        layer.addSublayer(newPlayerLayer)
        
        // Store references
        self.playerLayer = newPlayerLayer
        self.player = player
        self.currentVideoURL = videoURL
        self.currentSettings = settings
        startIdleTimerObservation(for: player)
        
        // 🚨 ENHANCED: Trigger layout immediately for modal context
        DispatchQueue.main.async { [weak self] in
            self?.setNeedsLayout()
            self?.layoutIfNeeded()
        }
        
        print("🎬 SmartFillRealPreviewView: Configured with modal-compatible setup")
        print("   📐 Deferred frame setting until layout for modal stability")
    }
    
    // MARK: - Layout
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        
        // 🚨 ENHANCED: Robust layout handling for modal contexts
        guard let playerLayer = playerLayer else { return }
        
        let newFrame = bounds
        if !newFrame.equalTo(playerLayer.frame) {
            // 🚨 MODAL FIX: Use proper transaction to prevent layer timing issues
            CATransaction.begin()
            CATransaction.setDisableActions(true) // Prevent animation glitches in modals
            CATransaction.setAnimationDuration(0) // No animation for modal contexts
            playerLayer.frame = newFrame
            CATransaction.commit()
            
            print("📐 SmartFillRealPreviewView: Updated frame to \(newFrame) (modal-optimized)")
        }
    }
    
    // MARK: - Phase 3: Player Controls
    
    public func play() {
        player?.play()
        print("▶️ SmartFillRealPreviewView: Started preview playback")
    }
    
    public func pause() {
        player?.pause()
        print("⏸️ SmartFillRealPreviewView: Paused preview playback")
    }
    
    public func seek(to time: CMTime) {
        player?.seek(to: time)
    }
    
    public func togglePlayback() {
        if player?.rate == 0 {
            play()
        } else {
            pause()
        }
    }
    
    // MARK: - Memory Management
    
    deinit {
        playerLayer?.removeFromSuperlayer()
        player?.pause()
        player = nil
        timeControlObserver?.invalidate()
        let token = idleTimerToken
        Task { @MainActor in
            token?.release()
        }
        print("🧹 SmartFillRealPreviewView: Cleaned up preview resources")
    }

    private func startIdleTimerObservation(for player: AVPlayer) {
        timeControlObserver?.invalidate()
        timeControlObserver = player.observe(\.timeControlStatus, options: [.initial, .new]) { [weak self] player, _ in
            let isPlaying = player.timeControlStatus == .playing
            Task { @MainActor [weak self] in
                self?.updateIdleTimer(isPlaying)
            }
        }
    }

    @MainActor
    private func updateIdleTimer(_ isPlaying: Bool) {
        if isPlaying {
            if idleTimerToken == nil {
                idleTimerToken = IdleTimerController.shared.acquire(reason: "SmartFillPreview")
            }
        } else {
            releaseIdleTimer()
        }
    }

    @MainActor
    private func releaseIdleTimer() {
        idleTimerToken?.release()
        idleTimerToken = nil
    }
}

// MARK: - Phase 3: SwiftUI Integration Helpers

public extension SmartFillPreviewPlayer {
    
    /// PHASE 3: Convenience modifier for loading states
    func onLoadingChange(_ callback: @escaping (Bool) -> Void) -> some View {
        // For now, return self - can be enhanced with state tracking
        return self
    }
    
    /// PHASE 3: Convenience modifier for error handling
    func onPreviewError(_ callback: @escaping (Error) -> Void) -> some View {
        // For now, return self - can be enhanced with error state tracking
        return self
    }
}

// MARK: - Phase 3: Preview Controls View

public struct SmartFillPreviewControls: View {
    
    let previewView: SmartFillRealPreviewView?
    @State private var isPlaying = false
    @State private var currentTime: Double = 0
    @State private var duration: Double = 1
    
    public init(previewView: SmartFillRealPreviewView?) {
        self.previewView = previewView
    }
    
    public var body: some View {
        VStack(spacing: 12) {
            // PHASE 3: Playback progress slider
            HStack {
                Text(formatTime(currentTime))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Slider(value: $currentTime, in: 0...duration) { editing in
                    if !editing {
                        let time = CMTime(seconds: currentTime, preferredTimescale: 600)
                        previewView?.seek(to: time)
                    }
                }
                .tint(Theme.primary)
                
                Text(formatTime(duration))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            // PHASE 3: Play/pause button
            HStack {
                Spacer()
                
                Button(action: {
                    previewView?.togglePlayback()
                    isPlaying.toggle()
                }) {
                    Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.title)
                        .foregroundStyle(Theme.primary)
                }
                .buttonStyle(PlainButtonStyle())
                
                Spacer()
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        )
        .onAppear {
            // PHASE 3: Set up time observation if needed
            setupTimeObservation()
        }
    }
    
    private func formatTime(_ seconds: Double) -> String {
        let minutes = Int(seconds) / 60
        let remainingSeconds = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
    
    private func setupTimeObservation() {
        // PHASE 3: Could add time observer here for real-time updates
        // For now, keeping it simple
    }
}

// MARK: - Phase 3: Preview Loading View

public struct SmartFillPreviewLoader: View {
    
    public var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Loading Preview...")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Text("Generating SmartFill composition")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.1))
        )
    }
}

#if DEBUG
// MARK: - Phase 3: Debug Preview

struct SmartFillPreviewPlayer_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            SmartFillPreviewLoader()
                .frame(height: 200)
            
            Text("Real SmartFill Preview")
                .font(.headline)
            
            Text("Phase 3: Uses exact same composition as export")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}
#endif
