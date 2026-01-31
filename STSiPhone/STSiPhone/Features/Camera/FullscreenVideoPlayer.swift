import SwiftUI
import AVFoundation
import AVKit

struct FullscreenVideoPlayer: View {
    let videoFile: VideoFile
    let onDismiss: () -> Void
    
    // MIGRATED: Uses unified VideoPlayerService instead of individual VideoPlayerManager
    @StateObject private var videoPlayerService = VideoPlayerService.shared
    
    @State private var showControls = true
    @State private var showInfo = false
    @State private var showRatingPicker = false
    @State private var currentRating: TakeRating
    @State private var isFullscreen = false
    @State private var idleTimerToken: IdleTimerController.Token?
    @Environment(\.playbackOverlayTopComfort) private var overlayTopComfort
    
    init(videoFile: VideoFile, onDismiss: @escaping () -> Void) {
        self.videoFile = videoFile
        self.onDismiss = onDismiss
        self._currentRating = State(initialValue: videoFile.metadata.rating)
    }
    
    var body: some View {
        ZStack {
            PlaybackSurface(
                background: {
                    Color.black
                },
                video: {
                    // MIGRATED: Video Player with unified service
                    if videoPlayerService.player != nil {
                        UnifiedVideoPlayerView(context: .fullscreenPlayer)
                    } else {
                        Color.black
                    }
                },
                overlay: {
                    if videoPlayerService.player != nil {
                        // Custom overlay when controls are shown
                        if showControls {
                            videoOverlay
                        }
                    } else {
                        loadingView
                    }
                }
            )
            .onTapGesture {
                guard videoPlayerService.player != nil else { return }
                withAnimation(.easeInOut(duration: 0.3)) {
                    showControls.toggle()
                }
                if showControls {
                    videoPlayerService.scheduleControlsHide()
                }
            }
            
            // PRESERVED: Rating Picker Modal
            if showRatingPicker {
                ratingPickerModal
            }
            
            // PRESERVED: Info Modal
            if showInfo {
                infoModal
            }
        }
        .navigationBarHidden(true)
        .statusBarHidden(isFullscreen)
        .onAppear {
            setupUnifiedPlayer()
            Task { @MainActor in
                updateIdleTimerForPlayback(videoPlayerService.isPlaying)
            }
        }
        .onChange(of: videoPlayerService.isPlaying, initial: false) { _, isPlaying in
            Task { @MainActor in
                updateIdleTimerForPlayback(isPlaying)
            }
        }
        .onDisappear {
            cleanupUnifiedPlayer()
            Task { @MainActor in
                releaseIdleTimer()
            }
        }
    }
    
    // MARK: - Video Overlay (PRESERVED with unified service integration)
    
    @ViewBuilder
    private var videoOverlay: some View {
        VStack {
            // Top Bar
            ZStack {
                HStack {
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.title2)
                            .foregroundColor(.white)
                            .padding(12)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    
                    Spacer()
                    
                    // Action Buttons
                    HStack(spacing: 8) {
                        // Info Button
                        Button(action: { showInfo = true }) {
                            Image(systemName: "info.circle")
                                .font(.title3)
                                .foregroundColor(.white)
                                .padding(8)
                                .background(.ultraThinMaterial, in: Circle())
                        }
                        
                        // Rating Button
                        Button(action: { showRatingPicker = true }) {
                            Image(systemName: currentRating.iconName)
                                .font(.title3)
                                .foregroundColor(currentRating.color)
                                .padding(8)
                                .background(.ultraThinMaterial, in: Circle())
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                
                // Video Info
                VStack(alignment: .center, spacing: 4) {
                    Text(videoFile.metadata.projectTitle)
                        .font(.headline)
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    if let role = videoFile.metadata.roleName {
                        Text("Role: \(role)")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    
                    HStack(spacing: 8) {
                        Text("Take \(videoFile.metadata.takeNumber)")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                        
                        if videoFile.metadata.sceneNumber > 1 {
                            Text("Scene \(videoFile.metadata.sceneNumber)")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                }
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.black.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
                .transaction { $0.animation = nil }
            }
            .padding()
            .padding(.top, overlayTopComfort)
            
            Spacer()
            
            // Bottom Controls
            if !isFullscreen {
                bottomControls
            }
        }
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.3), value: showControls)
    }
    
    @ViewBuilder
    private var bottomControls: some View {
        VStack(spacing: 16) {
            // Time Scrubber - MIGRATED to use VideoPlayerService
            VStack(spacing: 8) {
                HStack {
                    Text(videoPlayerService.currentTimeString)
                        .font(.caption)
                        .foregroundColor(.white)
                        .monospacedDigit()
                    
                    Spacer()
                    
                    Text(videoPlayerService.durationString)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                        .monospacedDigit()
                }
                
                // Progress Slider - MIGRATED to use VideoPlayerService
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.white.opacity(0.3))
                            .frame(height: 4)
                            .cornerRadius(2)
                        
                        Rectangle()
                            .fill(Color.white)
                            .frame(width: geometry.size.width * videoPlayerService.progress, height: 4)
                            .cornerRadius(2)
                        
                        // Scrub handle
                        Circle()
                            .fill(Color.white)
                            .frame(width: 12, height: 12)
                            .offset(x: max(0, min(geometry.size.width * videoPlayerService.progress - 6, geometry.size.width - 12)))
                    }
                }
                .frame(height: 12)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let progress = max(0, min(1, value.location.x / UIScreen.main.bounds.width))
                            videoPlayerService.seek(to: progress)
                        }
                )
            }
            
            // Playback Controls - MIGRATED to use VideoPlayerService
            HStack(spacing: 32) {
                // Skip Back 15s
                Button(action: { videoPlayerService.skip(-15) }) {
                    Image(systemName: "gobackward.15")
                        .font(.title2)
                        .foregroundColor(.white)
                }
                
                // Previous Frame (slow motion)
                Button(action: { videoPlayerService.stepBackward() }) {
                    Image(systemName: "backward.frame")
                        .font(.title3)
                        .foregroundColor(.white)
                }
                
                // Play/Pause
                Button(action: { videoPlayerService.togglePlayback() }) {
                    Image(systemName: videoPlayerService.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.white)
                        .frame(width: 60, height: 60)
                        .background(.ultraThinMaterial, in: Circle())
                }
                
                // Next Frame (slow motion)
                Button(action: { videoPlayerService.stepForward() }) {
                    Image(systemName: "forward.frame")
                        .font(.title3)
                        .foregroundColor(.white)
                }
                
                // Skip Forward 15s
                Button(action: { videoPlayerService.skip(15) }) {
                    Image(systemName: "goforward.15")
                        .font(.title2)
                        .foregroundColor(.white)
                }
            }
        }
        .padding()
        .background(.black.opacity(0.5), in: RoundedRectangle(cornerRadius: 16))
        .padding()
    }
    
    // MARK: - Modals
    
    @ViewBuilder
    private var ratingPickerModal: some View {
        ZStack {
            Color.black.opacity(0.8)
                .ignoresSafeArea()
                .onTapGesture {
                    showRatingPicker = false
                }
            
            VStack(spacing: 20) {
                Text("Rate This Take")
                    .font(.headline)
                    .foregroundColor(.white)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                    ForEach(TakeRating.displayOrder, id: \.self) { rating in
                        Button(action: {
                            updateRating(rating)
                            showRatingPicker = false
                        }) {
                            VStack(spacing: 8) {
                                Image(systemName: rating.iconName)
                                    .font(.system(size: 32))
                                    .foregroundColor(rating.color)
                                
                                Text(rating.displayName)
                                    .font(.caption)
                                    .foregroundColor(.white)
                            }
                            .frame(width: 80, height: 80)
                            .background(
                                backgroundForRating(rating),
                                in: RoundedRectangle(cornerRadius: 12)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(
                                        strokeColorForRating(rating),
                                        lineWidth: 1
                                    )
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            .padding(24)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 40)
        }
    }
    
    @ViewBuilder
    private var infoModal: some View {
        ZStack {
            Color.black.opacity(0.8)
                .ignoresSafeArea()
                .onTapGesture {
                    showInfo = false
                }
            
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Video Details")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Button(action: { showInfo = false }) {
                            Image(systemName: "xmark")
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                    
                    Divider()
                        .background(Color.white.opacity(0.3))
                    
                    // Video Information
                    infoRow("Project", videoFile.metadata.projectTitle)
                    
                    if let role = videoFile.metadata.roleName {
                        infoRow("Role", role)
                    }
                    
                    infoRow("Take", "\(videoFile.metadata.takeNumber)")
                    infoRow("Scene", "\(videoFile.metadata.sceneNumber)")
                    infoRow("Duration", formatDuration(videoFile.metadata.duration))
                    infoRow("File Size", videoFile.formattedFileSize)
                    infoRow("Recording Date", formatDate(videoFile.metadata.recordingDate))
                    infoRow("Camera", videoFile.metadata.cameraPosition.capitalized)
                    
                    if let resolution = videoFile.metadata.resolution {
                        infoRow("Resolution", resolution.displayName)
                    }
                    
                    if let frameRate = videoFile.metadata.frameRate {
                        infoRow("Frame Rate", "\(Int(frameRate)) fps")
                    }
                    
                    if let codec = videoFile.metadata.codec {
                        infoRow("Codec", codec)
                    }
                    
                    if let notes = videoFile.metadata.notes, !notes.isEmpty {
                        Text("Notes")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.white.opacity(0.7))
                        
                        Text(notes)
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(8)
                            .background(.ultraThinMaterial.opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
                    }
                }
                .padding(20)
            }
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 30)
            .padding(.vertical, 60)
        }
    }
    
    @ViewBuilder
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(.white)
            
            Text("Loading video...")
                .font(.headline)
                .foregroundColor(.white)
        }
    }
    
    // MARK: - Helper Methods
    
    // MIGRATED: Setup with unified video player service
    private func setupUnifiedPlayer() {
        videoPlayerService.setupPlayer(with: videoFile.url, context: .fullscreenPlayer)
    }
    
    // MIGRATED: Cleanup with context-aware unified service  
    private func cleanupUnifiedPlayer() {
        videoPlayerService.cleanup(context: .fullscreenPlayer)
    }

    @MainActor
    private func updateIdleTimerForPlayback(_ isPlaying: Bool) {
        if isPlaying {
            if idleTimerToken == nil {
                idleTimerToken = IdleTimerController.shared.acquire(reason: "FullscreenVideoPlayer")
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
    
    private func updateRating(_ rating: TakeRating) {
        currentRating = rating
        // TODO: Update the actual take rating in SessionManager
        // SessionManager.shared.updateTakeRating(videoFile.id, rating: rating)
    }
    
    private func toggleFullscreen() {
        withAnimation(.easeInOut(duration: 0.3)) {
            isFullscreen.toggle()
        }
    }
    
    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.white.opacity(0.7))
                .frame(width: 80, alignment: .leading)
            
            Text(value)
                .font(.caption)
                .foregroundColor(.white)
            
            Spacer()
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        let ms = Int((duration * 100).truncatingRemainder(dividingBy: 100))
        return String(format: "%d:%02d.%02d", minutes, seconds, ms)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func backgroundForRating(_ rating: TakeRating) -> Color {
        if currentRating == rating {
            return Color.white.opacity(0.1)
        } else {
            return Color.clear
        }
    }
    
    private func strokeColorForRating(_ rating: TakeRating) -> Color {
        if currentRating == rating {
            return Color.white.opacity(0.5)
        } else {
            return Color.white.opacity(0.1)
        }
    }
}

// MARK: - MIGRATION COMPLETE
// The old VideoPlayerManager class has been completely replaced by VideoPlayerService
// All functionality has been migrated to the unified service architecture

#Preview {
    let sampleVideoFile = VideoFile(
        filePath: "/sample/path/video.mov",
        fileName: "sample_video.mov",
        metadata: VideoMetadata(
            projectTitle: "Sample Project",
            roleName: "Sample Role",
            sceneNumber: 1,
            takeNumber: 1,
            rating: .finalSelect,
            duration: 45.0,
            resolution: nil,
            frameRate: nil,
            codec: nil,
            recordingDate: Date(),
            cameraPosition: "back",
            audioChannels: nil,
            notes: nil
        ),
        fileSize: 1024000,
        createdAt: Date()
    )
    
    FullscreenVideoPlayer(videoFile: sampleVideoFile) {
        print("Dismissed")
    }
}
