import Foundation
import SwiftUI
import AVFoundation
import Combine

// MARK: - Timeline Editor View Model
// Manages video editing state and operations

@MainActor
class TimelineEditorViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var player: AVPlayer?
    @Published var currentTime: Double = 0.0
    @Published var videoDuration: Double = 0.0
    @Published var videoSize: CGSize = .zero
    @Published var isPlaying: Bool = false
    
    // Editing properties
    @Published var editingMode: EditingMode = .trim
    @Published var trimRange: CMTimeRange?
    @Published var cropRect: CGRect = .zero
    @Published var cropRotationDegrees: Double = 0
    @Published var markers: [VideoMarker] = []
    
    // Timeline properties
    @Published var timelineZoom: Double = 1.0
    
    // Filter properties
    @Published var brightness: Float = 0.0
    @Published var contrast: Float = 1.0
    @Published var saturation: Float = 1.0
    
    // CRITICAL FIX: Add property to store orientation transform for PlayerView
    @Published var videoOrientationTransform: CGAffineTransform = .identity
    
    // MARK: - Private Properties
    
    private var videoFile: VideoFile?
    private var timeObserver: Any?
    private var cancellables = Set<AnyCancellable>()
    private var playerItem: AVPlayerItem?
    
    // MARK: - Computed Properties
    
    var hasEdits: Bool {
        trimRange != nil ||
        cropRect != .zero ||
        abs(cropRotationDegrees) > 0.01 ||
        !markers.isEmpty ||
        brightness != 0.0 ||
        contrast != 1.0 ||
        saturation != 1.0
    }
    
    // MARK: - Initialization
    
    init() {
        setupObservers()
    }
    
    deinit {
        // FIXED: Use Task to handle MainActor cleanup in deinit
        let cleanup = self.cleanup
        Task.detached {
            await cleanup()
        }
        print("✅ TimelineEditorViewModel: Cleanup scheduled on deinit")
    }
    
    // MARK: - Public Methods
    
    func loadVideo(_ videoFile: VideoFile) {
        self.videoFile = videoFile
        
        let url = URL(fileURLWithPath: videoFile.filePath)
        let asset = AVURLAsset(url: url)
        
        // Create player item
        let playerItem = AVPlayerItem(asset: asset)
        self.playerItem = playerItem
        
        // Create player
        let player = AVPlayer(playerItem: playerItem)
        self.player = player
        
        // CRITICAL FIX: Apply orientation corrections like SwipeableVideoPlayerView
        setupVideoOrientation(with: asset)
        
        // Load video properties
        Task {
            do {
                let duration = try await asset.load(.duration)
                self.videoDuration = CMTimeGetSeconds(duration)
                
                if let track = try await asset.loadTracks(withMediaType: .video).first {
                    let naturalSize = try await track.load(.naturalSize)
                    let transform = try await track.load(.preferredTransform)
                    
                    // FIXED: Comprehensive NaN protection for video dimension calculations
                    
                    // First validate natural size
                    guard !naturalSize.width.isNaN && !naturalSize.width.isInfinite && naturalSize.width > 0 &&
                          !naturalSize.height.isNaN && !naturalSize.height.isInfinite && naturalSize.height > 0 else {
                        print("⚠️ TimelineEditorViewModel: Invalid natural size: \(naturalSize), using fallback")
                        self.videoSize = CGSize(width: 1920, height: 1080) // Default fallback
                        return
                    }
                    
                    // Validate transform matrix components to prevent NaN in transform.applying()
                    let transformValues = [transform.a, transform.b, transform.c, transform.d, transform.tx, transform.ty]
                    let hasInvalidTransform = transformValues.contains { value in
                        value.isNaN || value.isInfinite
                    }
                    
                    var finalSize: CGSize
                    
                    if hasInvalidTransform {
                        print("⚠️ TimelineEditorViewModel: Invalid transform matrix detected, using natural size")
                        finalSize = naturalSize
                    } else {
                        // Apply transform safely
                        let transformedSize = naturalSize.applying(transform)
                        
                        // Validate transformed result
                        let width = abs(transformedSize.width)
                        let height = abs(transformedSize.height)
                        
                        if !width.isNaN && !width.isInfinite && width > 0 &&
                           !height.isNaN && !height.isInfinite && height > 0 {
                            finalSize = CGSize(width: width, height: height)
                        } else {
                            print("⚠️ TimelineEditorViewModel: Transform produced invalid dimensions: \(transformedSize), using natural size")
                            finalSize = naturalSize
                        }
                    }
                    
                    // Final validation before assignment
                    guard finalSize.width > 0 && finalSize.height > 0 &&
                          finalSize.width.isFinite && finalSize.height.isFinite else {
                        print("⚠️ TimelineEditorViewModel: Final size validation failed: \(finalSize), using fallback")
                        self.videoSize = CGSize(width: 1920, height: 1080)
                        return
                    }
                    
                    self.videoSize = finalSize
                    print("✅ TimelineEditorViewModel: Video size calculated safely: \(self.videoSize)")
                }
                
                print("✅ Video loaded: \(videoFile.fileName), Duration: \(self.videoDuration)s")
            } catch {
                print("❌ Failed to load video properties: \(error)")
            }
        }
        
        // Setup time observer
        setupTimeObserver()
        
        // Load existing markers from repository
        loadMarkersFromRepository()
    }
    
    func togglePlayback() {
        guard let player = player else { return }
        
        if isPlaying {
            player.pause()
        } else {
            player.play()
        }
    }
    
    func seek(to time: Double) {
        guard let player = player else { return }
        
        let cmTime = CMTime(seconds: time, preferredTimescale: 600)
        player.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero)
        currentTime = time
    }
    
    func addMarker(at time: Double) {
        let marker = VideoMarker(
            timestamp: time,
            title: "Marker \(markers.count + 1)",
            description: nil,
            type: .note
        )
        
        markers.append(marker)
        markers.sort { $0.timestamp < $1.timestamp }
        
        print("📍 Added marker at \(formatTime(time))")
    }
    
    func removeMarker(_ marker: VideoMarker) {
        markers.removeAll { $0.id == marker.id }
    }
    
    // MARK: - Trim Operations
    
    func setTrimStart() {
        if trimRange == nil {
            // Create new trim range from current time to end
            let startTime = CMTime(seconds: currentTime, preferredTimescale: 600)
            let duration = CMTime(seconds: videoDuration - currentTime, preferredTimescale: 600)
            trimRange = CMTimeRange(start: startTime, duration: duration)
        } else {
            // Update start time of existing range
            let newStartTime = CMTime(seconds: currentTime, preferredTimescale: 600)
            let currentEnd = CMTimeAdd(trimRange!.start, trimRange!.duration)
            let newDuration = CMTimeSubtract(currentEnd, newStartTime)
            
            if CMTimeGetSeconds(newDuration) > 0 {
                trimRange = CMTimeRange(start: newStartTime, duration: newDuration)
            }
        }
    }
    
    func setTrimEnd() {
        if trimRange == nil {
            // Create new trim range from start to current time
            let duration = CMTime(seconds: currentTime, preferredTimescale: 600)
            trimRange = CMTimeRange(start: .zero, duration: duration)
        } else {
            // Update end time of existing range
            let newEndTime = CMTime(seconds: currentTime, preferredTimescale: 600)
            let newDuration = CMTimeSubtract(newEndTime, trimRange!.start)
            
            if CMTimeGetSeconds(newDuration) > 0 {
                trimRange = CMTimeRange(start: trimRange!.start, duration: newDuration)
            }
        }
    }
    
    func resetTrim() {
        trimRange = nil
    }
    
    // MARK: - Crop Operations
    
    func applyCropPreset(_ preset: CropPreset) {
        let aspectRatio = preset.aspectRatio
        
        // Calculate crop rect to maintain aspect ratio and center the crop
        if aspectRatio >= 1.0 {
            // Landscape or square
            let height = 1.0 / aspectRatio
            cropRect = CGRect(
                x: 0,
                y: (1.0 - height) / 2.0,
                width: 1.0,
                height: height
            )
        } else {
            // Portrait
            let width = aspectRatio
            cropRect = CGRect(
                x: (1.0 - width) / 2.0,
                y: 0,
                width: width,
                height: 1.0
            )
        }
        
        print("🎬 Applied crop preset: \(preset.displayName)")
    }
    
    func resetCrop() {
        cropRect = .zero
        cropRotationDegrees = 0
    }
    
    // MARK: - Filter Operations
    
    func resetFilters() {
        brightness = 0.0
        contrast = 1.0
        saturation = 1.0
    }
    
    // MARK: - Export
    
    func generateEditResult() -> EditedVideoResult {
        guard let videoFile = videoFile else {
            fatalError("No video file loaded")
        }
        
        return EditedVideoResult(
            originalVideoFile: videoFile,
            trimRange: trimRange,
            cropRect: cropRect,
            cropRotationDegrees: cropRotationDegrees,
            markers: markers,
            brightness: brightness,
            contrast: contrast,
            saturation: saturation,
            hasEdits: hasEdits
        )
    }
    
    // MARK: - Private Methods
    
    private func setupObservers() {
        // Observe player status
        NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime)
            .sink { [weak self] _ in
                self?.isPlaying = false
            }
            .store(in: &cancellables)
    }
    
    private func setupTimeObserver() {
        guard let player = player else { return }
        
        // Remove existing observer
        if let timeObserver = timeObserver {
            player.removeTimeObserver(timeObserver)
        }
        
        // Add new observer
        let interval = CMTime(seconds: 0.1, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            // FIXED: Use Task to ensure main actor context for property mutations
            Task { @MainActor [weak self] in
                self?.currentTime = CMTimeGetSeconds(time)
                
                // Update playing status
                self?.isPlaying = player.timeControlStatus == .playing
            }
        }
    }
    
    private func loadMarkersFromRepository() {
        guard let videoFile = videoFile,
              let repository = SessionManager.shared.repositoryInstance,
              let currentSession = SessionManager.shared.currentSession else {
            return
        }
        
        // Find corresponding ProjectTake in repository
        if let project = repository.project(by: currentSession.project.id),
           let session = project.sessions.first(where: { $0.id == currentSession.session.id }),
           let projectTake = session.takes.first(where: { projectTake in
               projectTake.filePath == videoFile.filePath ||
               projectTake.filePath.hasSuffix(videoFile.fileName) ||
               URL(fileURLWithPath: projectTake.filePath).lastPathComponent == videoFile.fileName
           }) {
            
            // Convert TakeVideoMarkers to VideoMarkers
            self.markers = projectTake.videoMarkers.map { takeMarker in
                VideoMarker(
                    timestamp: takeMarker.timestamp,
                    title: takeMarker.title,
                    description: takeMarker.description,
                    type: VideoMarker.MarkerType(rawValue: takeMarker.type.rawValue) ?? .note
                )
            }
            
            print("📍 Loaded \(markers.count) existing markers from repository")
        }
    }
    
    private func cleanup() {
        // FIXED: Enhanced cleanup to prevent memory leaks
        
        // Remove time observer FIRST
        if let player = player, let timeObserver = timeObserver {
            player.removeTimeObserver(timeObserver)
            self.timeObserver = nil
        }
        
        // Cancel all publishers and clear set
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()
        
        // Stop and clear player
        player?.pause()
        player?.replaceCurrentItem(with: nil)
        player = nil
        playerItem = nil
        
        // Clear video file reference
        videoFile = nil
        
        // Reset all published properties to break any potential retain cycles
        currentTime = 0.0
        videoDuration = 0.0
        videoSize = .zero
        isPlaying = false
        trimRange = nil
        cropRect = .zero
        markers.removeAll()
        
        print("🧹 TimelineEditorViewModel: Complete cleanup performed")
    }
    
    private func formatTime(_ seconds: Double) -> String {
        // FIXED: Enhanced NaN protection for time formatting
        guard seconds.isFinite && seconds >= 0 else { 
            print("⚠️ TimelineEditorViewModel: Invalid time value for formatting: \(seconds)")
            return "0:00" 
        }
        
        let clampedSeconds = max(0, seconds)
        let minutes = Int(clampedSeconds) / 60
        let remainingSeconds = Int(clampedSeconds) % 60
        
        // Additional validation for calculation results
        guard minutes >= 0 && remainingSeconds >= 0 && remainingSeconds < 60 else {
            print("⚠️ TimelineEditorViewModel: Invalid time calculation: \(minutes):\(remainingSeconds)")
            return "0:00"
        }
        
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
    
    // CRITICAL FIX: Add comprehensive orientation handling from SwipeableVideoPlayerView
    private func setupVideoOrientation(with asset: AVURLAsset) {
        // Apply orientation transform when player is ready
        Task {
            do {
                let videoTracks = try await asset.loadTracks(withMediaType: .video)
                
                guard let videoTrack = videoTracks.first else {
                    print("⚠️ TimelineEditor: No video track found")
                    return
                }
                
                let preferredTransform = try await videoTrack.load(.preferredTransform)
                let naturalSize = try await videoTrack.load(.naturalSize)
                
                await MainActor.run {
                    // Store the transform for PlayerView to apply
                    self.videoOrientationTransform = getCorrectTransform(for: preferredTransform)
                    
                    print("🔄 TimelineEditor Orientation Setup:")
                    print("   📐 Preferred Transform: \(preferredTransform)")
                    print("   📏 Natural Size: \(naturalSize)")
                    print("   🔧 Applied Transform: \(analyzeTransform(self.videoOrientationTransform))")
                }
                
            } catch {
                print("❌ Failed to setup TimelineEditor video orientation: \(error)")
            }
        }
    }
    
    // CRITICAL FIX: Add transform calculation methods from SwipeableVideoPlayerView
    private func getCorrectTransform(for preferredTransform: CGAffineTransform) -> CGAffineTransform {
        let t = preferredTransform
        
        // CRITICAL FIX: Skip orientation fixes for exported and merged videos - they're already correctly oriented
        if let videoFile = self.videoFile {
            // Check if this is an exported/processed video (common patterns)
            let fileName = videoFile.fileName.lowercased()
            if fileName.contains("export") || fileName.contains("merged") || fileName.contains("processed") {
                print("🎬 Skipping TimelineEditor orientation transform for processed video - already correctly oriented")
                return .identity
            }
        }
        
        if t.isIdentity {
            // SURGICAL FIX: Add 180° rotation to fix upside-down display (ONLY for regular takes)
            return CGAffineTransform(rotationAngle: CGFloat.pi)
        } else if t.a == 0 && t.b == 1 && t.c == -1 && t.d == 0 {
            // Portrait (90° clockwise) + 180° fix = 270° total
            return CGAffineTransform(rotationAngle: CGFloat.pi + CGFloat.pi / 2)
            
        } else if t.a == -1 && t.b == 0 && t.c == 0 && t.d == -1 {
            // Landscape Left (180° rotation) + 180° fix = 360° = 0°
            return .identity
            
        } else if t.a == 0 && t.b == -1 && t.c == 1 && t.d == 0 {
            // Portrait Upside Down (-90°) + 180° fix = 90° total
            return CGAffineTransform(rotationAngle: CGFloat.pi + (-CGFloat.pi / 2))
            
        } else {
            // Custom transform - invert and add 180°
            return preferredTransform.inverted().concatenating(CGAffineTransform(rotationAngle: CGFloat.pi))
        }
    }
    
    private func analyzeTransform(_ transform: CGAffineTransform) -> String {
        if transform.isIdentity {
            return "Identity (no rotation)"
        } else if transform.a == 0 && transform.b == 1 && transform.c == -1 && transform.d == 0 {
            return "90° clockwise rotation"
        } else if transform.a == -1 && transform.b == 0 && transform.c == 0 && transform.d == -1 {
            return "180° rotation"
        } else if transform.a == 0 && transform.b == -1 && transform.c == 1 && transform.d == 0 {
            return "90° counter-clockwise rotation"
        } else {
            return "Custom transform: a=\(transform.a), b=\(transform.b), c=\(transform.c), d=\(transform.d)"
        }
    }
}

// MARK: - Video Player View

struct VideoPlayerView: UIViewRepresentable {
    let player: AVPlayer?
    @Binding var currentTime: Double
    let orientationTransform: CGAffineTransform // CRITICAL FIX: Add orientation transform parameter
    
    func makeUIView(context: Context) -> PlayerView {
        let playerView = PlayerView()
        playerView.player = player
        playerView.orientationTransform = orientationTransform // CRITICAL FIX: Set orientation transform
        return playerView
    }
    
    func updateUIView(_ uiView: PlayerView, context: Context) {
        uiView.player = player
        uiView.orientationTransform = orientationTransform // CRITICAL FIX: Update orientation transform
    }
}

class PlayerView: UIView {
    var player: AVPlayer? {
        didSet {
            playerLayer.player = player
        }
    }
    
    // CRITICAL FIX: Add orientation transform property
    var orientationTransform: CGAffineTransform = .identity {
        didSet {
            applyOrientationTransform()
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
        // CRITICAL FIX: Apply orientation transform after layout changes
        applyOrientationTransform()
    }
    
    // CRITICAL FIX: Apply orientation transform to player layer
    private func applyOrientationTransform() {
        guard !orientationTransform.isIdentity else {
            // Reset to identity if no transform needed
            playerLayer.setAffineTransform(.identity)
            return
        }
        
        // Apply the transform to fix video orientation
        playerLayer.setAffineTransform(orientationTransform)
        
        print("🔄 TimelineEditor PlayerView: Applied orientation transform")
    }
}
