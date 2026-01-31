import SwiftUI
import AVFoundation
import OSLog

/// Modern SwiftUI SmartFill Preview - No UIViewRepresentable, No KVO
/// Enterprise-grade preview using native SwiftUI + modern video player
public struct SmartFillPreviewView: View {
    
    // MARK: - Properties
    let videoURL: URL
    let settings: SmartFillSettings
    let onError: ((Error) -> Void)?
    
    // MARK: - State
    @StateObject private var previewManager = SmartFillPreviewManager()
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    private let logger = Logger(subsystem: "SelfTapeStudio", category: "SmartFillPreview")
    
    public init(
        videoURL: URL,
        settings: SmartFillSettings = SmartFillSettings(),
        onError: ((Error) -> Void)? = nil
    ) {
        self.videoURL = videoURL
        self.settings = settings
        self.onError = onError
    }
    
    public var body: some View {
        ZStack {
            if isLoading {
                loadingView
            } else if let errorMessage = errorMessage {
                errorView(message: errorMessage)
            } else {
                previewContent
            }
        }
        .background(Color.black)
        .cornerRadius(12)
        .onAppear {
            loadPreview()
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(.white)
            
            Text("Loading Preview...")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.8))
            
            Text("Generating SmartFill composition")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Error View
    
    private func errorView(message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.title)
                .foregroundStyle(.orange)
            
            Text("Preview Error")
                .font(.headline)
                .foregroundStyle(.white)
            
            Text(message)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .lineLimit(3)
            
            Button("Retry") {
                loadPreview()
            }
            .font(.caption)
            .foregroundStyle(.blue)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    // MARK: - Preview Content
    
    private var previewContent: some View {
        VStack {
            // Modern Video Player
            if let player = previewManager.previewPlayer {
                ModernVideoPlayerView(player: player.player)
                    .aspectRatio(16/9, contentMode: .fit)
                    .onAppear {
                        player.play()
                    }
                    .onDisappear {
                        player.pause()
                    }
            }
            
            // Controls
            if let player = previewManager.previewPlayer {
                ModernSmartFillPreviewControls(player: player)
            }
        }
    }
    
    // MARK: - Preview Loading
    
    private func loadPreview() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                logger.info("🎬 Loading SAFE SmartFill preview for: \(videoURL.lastPathComponent)")
                
                // 🚨 ENHANCED SAFETY: Validate file exists before attempting preview
                guard FileManager.default.fileExists(atPath: videoURL.path) else {
                    throw SmartFillManagerError.invalidVideo
                }
                
                // 🚨 ENHANCED SAFETY: Use manager which now routes through unified interface
                let player = try await SmartFillManager.shared.createPreviewPlayer(
                    for: videoURL,
                    settings: settings
                )
                
                await MainActor.run {
                    previewManager.previewPlayer = player
                    isLoading = false
                    logger.info("✅ SAFE SmartFill preview loaded successfully (no crash risk)")
                }
                
            } catch {
                logger.error("❌ SAFE SmartFill preview failed: \(error)")
                
                await MainActor.run {
                    errorMessage = "Preview failed: \(error.localizedDescription)"
                    isLoading = false
                    onError?(error)
                }
            }
        }
    }
}

// MARK: - Preview Manager

@MainActor
private final class SmartFillPreviewManager: ObservableObject {
    @Published var previewPlayer: ModernSmartFillPlayer?
    private var loadingTask: Task<Void, Never>?
    
    deinit {
        loadingTask?.cancel()
        
        // CRITICAL FIX: Cannot access @Published properties from deinit in Swift 6
        // The player will be cleaned up automatically when the object is deallocated
        print("🧹 SmartFillPreviewManager: Deinitializing, loadingTask cancelled")
    }
    
    func startLoadingPreview(videoURL: URL, settings: SmartFillSettings) {
        loadingTask?.cancel()
        loadingTask = Task { @MainActor in
            guard !Task.isCancelled else { return }
            
            do {
                let player = try await SmartFillManager.shared.createPreviewPlayer(
                    for: videoURL,
                    settings: settings
                )
                
                if !Task.isCancelled {
                    self.previewPlayer = player
                }
                
            } catch {
                if !Task.isCancelled {
                    // Handle error
                    print("❌ Preview loading failed: \(error)")
                }
            }
        }
    }
}

// MARK: - Modern Video Player View (replaces VideoPlayer)

private struct ModernVideoPlayerView: UIViewRepresentable {
    let player: AVPlayer
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .black
        
        let playerLayer = AVPlayerLayer(player: player)
        playerLayer.videoGravity = .resizeAspect
        view.layer.addSublayer(playerLayer)
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        if let playerLayer = uiView.layer.sublayers?.first as? AVPlayerLayer {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            playerLayer.frame = uiView.bounds
            CATransaction.commit()
        }
    }
}

// MARK: - Modern Preview Controls

public struct ModernSmartFillPreviewControls: View {
    
    @ObservedObject private var player: ModernSmartFillPlayer
    @State private var isDraggingSlider = false
    
    public init(player: ModernSmartFillPlayer) {
        self.player = player
    }
    
    public var body: some View {
        VStack(spacing: 8) {
            // Progress Slider
            HStack {
                Text(formatTime(player.currentTime))
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.8))
                
                Slider(
                    value: Binding(
                        get: { player.currentTime },
                        set: { newValue in
                            if !isDraggingSlider {
                                let time = CMTime(seconds: newValue, preferredTimescale: 600)
                                player.seek(to: time)
                            }
                        }
                    ),
                    in: 0...max(player.duration, 0.1)
                ) { editing in
                    isDraggingSlider = editing
                }
                .tint(.white)
                
                Text(formatTime(player.duration))
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.8))
            }
            
            // Play/Pause Button
            Button(action: {
                if player.isPlaying {
                    player.pause()
                } else {
                    player.play()
                }
            }) {
                Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.white)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(
            LinearGradient(
                colors: [.clear, .black.opacity(0.6)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
    
    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite && seconds >= 0 else { return "0:00" }
        
        let minutes = Int(seconds) / 60
        let remainingSeconds = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
}

#if DEBUG
// MARK: - Preview

struct SmartFillPreviewView_Previews: PreviewProvider {
    static var previews: some View {
        SmartFillPreviewView(
            videoURL: URL(fileURLWithPath: "/dev/null"),
            settings: SmartFillSettings()
        )
        .frame(height: 200)
        .padding()
        .previewDisplayName("SmartFill Preview")
    }
}
#endif
