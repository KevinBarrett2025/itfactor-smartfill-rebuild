import SwiftUI
import AVKit
import AVFoundation

struct UnifiedVideoOverlay: View {
    // MIGRATED: Now uses VideoPlayerService directly instead of VideoPlayerManager
    @ObservedObject var videoPlayerService: VideoPlayerService
    let videoTitle: String
    let videoSubtitle: String?
    let takeNumber: Int?
    let onDismiss: () -> Void
    let onRatingChange: ((TakeRating) -> Void)?
    let markers: [VideoMarker]? // Still accepts legacy markers for compatibility
    
    // UNIFIED RATING SUPPORT: Add context for unified rating calls
    let takeID: UUID?
    let sessionID: UUID?
    let projectID: UUID?
    
    @State private var showControls = true
    @State private var showRatingPicker = false
    @State private var showAirPlayPicker = false
    @State private var showMarkersPanel = false
    @State private var currentRating: TakeRating = .unrated
    @State private var hideControlsTask: Task<Void, Never>?
    @Environment(\.playbackOverlayTopComfort) private var overlayTopComfort
    
    // ENHANCED: Migration-compatible initializer with unified rating support
    init(
        videoPlayerService: VideoPlayerService? = nil,
        videoTitle: String,
        videoSubtitle: String? = nil,
        takeNumber: Int? = nil,
        currentRating: TakeRating = .unrated,
        markers: [VideoMarker]? = nil,
        takeID: UUID? = nil,
        sessionID: UUID? = nil,
        projectID: UUID? = nil,
        onDismiss: @escaping () -> Void,
        onRatingChange: ((TakeRating) -> Void)? = nil
    ) {
        // FIXED: Use provided service or VideoPlayerService.shared (now nonisolated)
        self.videoPlayerService = videoPlayerService ?? VideoPlayerService.shared
        self.videoTitle = videoTitle
        self.videoSubtitle = videoSubtitle
        self.takeNumber = takeNumber
        self.onDismiss = onDismiss
        self.onRatingChange = onRatingChange
        self.markers = markers
        self.takeID = takeID
        self.sessionID = sessionID
        self.projectID = projectID
        self._currentRating = State(initialValue: currentRating)
    }
    
    // BACKWARD COMPATIBILITY: Accept old VideoPlayerManager and adapt
    init(
        playerManager: Any, // Changed from VideoPlayerManager to Any for compatibility
        videoTitle: String,
        videoSubtitle: String? = nil,
        takeNumber: Int? = nil,
        currentRating: TakeRating = .unrated,
        markers: [VideoMarker]? = nil,
        takeID: UUID? = nil,
        sessionID: UUID? = nil,
        projectID: UUID? = nil,
        onDismiss: @escaping () -> Void,
        onRatingChange: ((TakeRating) -> Void)? = nil
    ) {
        // Bridge any legacy player manager to VideoPlayerService.shared
        self.videoPlayerService = VideoPlayerService.shared
        self.videoTitle = videoTitle
        self.videoSubtitle = videoSubtitle
        self.takeNumber = takeNumber
        self.onDismiss = onDismiss
        self.onRatingChange = onRatingChange
        self.markers = markers
        self.takeID = takeID
        self.sessionID = sessionID
        self.projectID = projectID
        self._currentRating = State(initialValue: currentRating)
        
        print("🔄 UnifiedVideoOverlay: Using compatibility bridge from legacy player to VideoPlayerService")
    }
    
    var body: some View {
        ZStack {
            // Tap to toggle controls
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    toggleControls()
                }
            
            if showControls {
                VStack {
                    // Top Bar - Unified Header
                    topBar
                    
                    Spacer()
                    
                    // Floating Markers (when available)
                    if let markers = markers, !markers.isEmpty {
                        floatingMarkers
                    }
                    
                    Spacer()

                    airPlayChip
                        .padding(.bottom, 4)
                    
                    // Bottom Controls - Unified Playback Controls
                    bottomControls
                }
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.3), value: showControls)
            }
            
            // Modals
            if showRatingPicker {
                ratingPickerModal
            }
            
            if showAirPlayPicker {
                airPlayPickerModal
            }
            
            if showMarkersPanel {
                markersPanelModal
            }
        }
        .onAppear {
            scheduleControlsHide()
        }
        .onChange(of: videoPlayerService.isPlaying, initial: false) { _, isPlaying in
            if isPlaying {
                scheduleControlsHide()
            }
        }
    }
    
    // MARK: - Top Bar
    
    private var topBar: some View {
        ZStack {
            HStack {
                Spacer()
                actionButtons
            }
            .frame(maxWidth: .infinity)
            
            headerView
                .transaction { $0.animation = nil }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .padding(.top, overlayTopComfort)
    }

    private var headerView: some View {
        VStack(alignment: .center, spacing: 4) {
            Text(videoTitle)
                .font(.headline)
                .foregroundColor(.white)
                .lineLimit(1)
            
            if let subtitle = videoSubtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
            }
            
            if let takeNumber = takeNumber {
                Text("Take \(takeNumber)")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
            }
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.black.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
    }

    private var actionButtons: some View {
        HStack(spacing: 8) {
            // Markers Button (when available)
            if let markers = markers, !markers.isEmpty {
                Button(action: { showMarkersPanel = true }) {
                    ZStack {
                        Image(systemName: "flag.fill")
                            .font(.title3)
                            .foregroundColor(.orange)
                        
                        // Badge showing marker count
                        if markers.count > 0 {
                            Text("\(markers.count)")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .frame(width: 16, height: 16)
                                .background(.red, in: Circle())
                                .offset(x: 8, y: -8)
                        }
                    }
                    .padding(8)
                    .background(.ultraThinMaterial, in: Circle())
                }
            }
            
            // Rating Button
            if onRatingChange != nil {
                Button(action: { showRatingPicker = true }) {
                    Image(systemName: currentRating.iconName)
                        .font(.title3)
                        .foregroundColor(currentRating.color)
                        .padding(8)
                        .background(.ultraThinMaterial, in: Circle())
                }
            }
        }
    }

    private var airPlayChip: some View {
        HStack {
            Button(action: { showAirPlayPicker = true }) {
                HStack(spacing: 6) {
                    Image(systemName: "airplayvideo")
                        .font(.subheadline.weight(.semibold))
                    Text("AirPlay")
                        .font(.caption.weight(.semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            Spacer()
        }
        .padding(.horizontal, 24)
    }
    
    // MARK: - Floating Markers
    
    private var floatingMarkers: some View {
        HStack {
            Spacer()
            
            VStack(alignment: .trailing, spacing: 12) {
                ForEach(markers?.prefix(3) ?? [], id: \.id) { marker in
                    floatingMarkerButton(marker)
                }
                
                if let markers = markers, markers.count > 3 {
                    Button(action: { showMarkersPanel = true }) {
                        HStack(spacing: 4) {
                            Text("+\(markers.count - 3)")
                                .font(.caption2)
                                .fontWeight(.semibold)
                            
                            Image(systemName: "ellipsis")
                                .font(.caption2)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.black.opacity(0.7), in: RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
            .padding(.trailing, 16)
        }
    }
    
    private func floatingMarkerButton(_ marker: VideoMarker) -> some View {
        Button(action: {
            seekToMarker(marker)
        }) {
            HStack(spacing: 6) {
                Image(systemName: marker.type.iconName)
                    .font(.caption2)
                    .foregroundColor(marker.type.color)
                
                Text(marker.title)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text(formatTime(marker.timestamp))
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.7))
                    .monospacedDigit()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.black.opacity(0.7), in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(marker.type.color.opacity(0.5), lineWidth: 1)
            )
        }
    }
    
    // MARK: - Bottom Controls
    
    private var bottomControls: some View {
        VStack(spacing: 16) {
            // Time Scrubber with Markers
            timeScrubberWithMarkers
            
            // Playback Controls
            playbackControls
        }
        .padding()
        .background(.black.opacity(0.5), in: RoundedRectangle(cornerRadius: 16))
        .padding()
    }
    
    private var timeScrubberWithMarkers: some View {
        VStack(spacing: 8) {
            HStack {
                // MIGRATED: Now uses VideoPlayerService properties directly
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
            
            // ENHANCED: Professional timeline scrubber - FIXED: Add comprehensive NaN protection
            GeometryReader { geometry in
                let safeWidth = geometry.size.width.isFinite && geometry.size.width > 0 ? geometry.size.width : 320
                let safeHeight = geometry.size.height.isFinite && geometry.size.height > 0 ? geometry.size.height : 44
                let safeDuration = videoPlayerService.duration.isFinite && videoPlayerService.duration > 0 ? videoPlayerService.duration : 1.0
                let safeProgress = videoPlayerService.progress.isFinite && videoPlayerService.progress >= 0 && videoPlayerService.progress <= 1 ? videoPlayerService.progress : 0.0
                
                HStack(spacing: 0) {
                    // Progress bar background
                    Rectangle()
                        .fill(Color.white.opacity(0.3))
                        .frame(width: max(0, safeWidth - 80), height: max(4, safeHeight * 0.5))
                        .overlay(
                            // Progress bar fill - FIXED: Ensure positive width
                            HStack {
                                Rectangle()
                                    .fill(Theme.primary)
                                    .frame(width: max(0, (safeWidth - 80) * safeProgress), height: max(4, safeHeight * 0.5))
                                
                                Spacer()
                            }
                            .clipped()
                        )
                        .clipShape(Capsule())
                    
                    // Time display - FIXED: Safe duration formatting
                    Text(formatTime(videoPlayerService.currentTime) + " / " + formatTime(safeDuration))
                        .font(.system(size: min(12, max(8, safeHeight * 0.3)), weight: .medium, design: .monospaced))
                        .foregroundColor(.white)
                        .frame(width: 80)
                }
                // FIXED: Safe geometry-based positioning
                .position(
                    x: max(safeWidth * 0.5, 40),
                    y: max(safeHeight * 0.5, 22)
                )
            }
            .frame(height: 44)
            
            // Marker Indicators
            if let markers = markers {
                GeometryReader { geometry in
                    let safeWidth = geometry.size.width.isFinite && geometry.size.width > 0 ? geometry.size.width : 320
                    
                    HStack(spacing: 0) {
                        ForEach(markers, id: \.id) { marker in
                            markerIndicator(marker, width: safeWidth)
                        }
                    }
                }
                .frame(height: 8)
            }
        }
    }
    
    private func markerIndicator(_ marker: VideoMarker, width: CGFloat) -> some View {
        // ENHANCED: Uses VideoPlayerService duration with same NaN protection
        guard width > 0 && width.isFinite && width >= 0 &&
              marker.timestamp >= 0 && marker.timestamp.isFinite &&
              videoPlayerService.duration > 0 && videoPlayerService.duration.isFinite else {
            print("⚠️ UnifiedVideoOverlay: Invalid values for marker indicator - width: \(width), timestamp: \(marker.timestamp), duration: \(videoPlayerService.duration)")
            return AnyView(Rectangle().fill(Color.clear).frame(width: 0, height: 0))
        }
        
        guard videoPlayerService.duration != 0 else {
            print("⚠️ UnifiedVideoOverlay: Duration is zero, cannot calculate marker position")
            return AnyView(Rectangle().fill(Color.clear).frame(width: 0, height: 0))
        }
        
        let position = width * (marker.timestamp / videoPlayerService.duration)
        
        guard position.isFinite && position >= 0 && position <= width &&
              !position.isNaN else {
            print("⚠️ UnifiedVideoOverlay: Invalid marker position calculated: \(position)")
            return AnyView(Rectangle().fill(Color.clear).frame(width: 0, height: 0))
        }
        
        return AnyView(
            Rectangle()
                .fill(marker.type.color)
                .frame(width: 2, height: 8)
                .cornerRadius(1)
                .offset(x: position - 1, y: -2)
        )
    }
    
    private var playbackControls: some View {
        HStack(spacing: 32) {
            // Skip Back 15s - MIGRATED: Uses VideoPlayerService
            Button(action: { videoPlayerService.skip(-15) }) {
                Image(systemName: "gobackward.15")
                    .font(.title2)
                    .foregroundColor(.white)
            }
            
            // Frame Step Backward - MIGRATED: Uses VideoPlayerService
            Button(action: { videoPlayerService.stepBackward() }) {
                Image(systemName: "backward.frame")
                    .font(.title3)
                    .foregroundColor(.white)
            }
            
            // Play/Pause - MIGRATED: Uses VideoPlayerService
            Button(action: { videoPlayerService.togglePlayback() }) {
                Image(systemName: videoPlayerService.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.white)
                    .frame(width: 60, height: 60)
                    .background(.ultraThinMaterial, in: Circle())
            }
            
            // Frame Step Forward - MIGRATED: Uses VideoPlayerService
            Button(action: { videoPlayerService.stepForward() }) {
                Image(systemName: "forward.frame")
                    .font(.title3)
                    .foregroundColor(.white)
            }
            
            // Skip Forward 15s - MIGRATED: Uses VideoPlayerService
            Button(action: { videoPlayerService.skip(15) }) {
                Image(systemName: "goforward.15")
                    .font(.title2)
                    .foregroundColor(.white)
            }
        }
    }
    
    // MARK: - Modals (PRESERVED: Exact same functionality)
    
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
                                currentRating == rating 
                                    ? Color.white.opacity(0.2)
                                    : Color.clear,
                                in: RoundedRectangle(cornerRadius: 12)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(
                                        currentRating == rating 
                                            ? Color.white.opacity(0.5) 
                                            : Color.white.opacity(0.1),
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
    
    private var airPlayPickerModal: some View {
        ZStack {
            Color.black.opacity(0.8)
                .ignoresSafeArea()
                .onTapGesture {
                    showAirPlayPicker = false
                }
            
            VStack(spacing: 20) {
                HStack {
                    Image(systemName: "airplayvideo")
                        .font(.title2)
                        .foregroundColor(.blue)
                    
                    Text("AirPlay")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Button(action: { showAirPlayPicker = false }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                
                Divider()
                    .background(Color.white.opacity(0.3))
                
                // AirPlay Picker Integration
                AirPlayPickerView()
                    .frame(height: 200)
                
                Text("Select a device to stream your video")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }
            .padding(24)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 40)
        }
    }
    
    private var markersPanelModal: some View {
        ZStack {
            Color.black.opacity(0.8)
                .ignoresSafeArea()
                .onTapGesture {
                    showMarkersPanel = false
                }
            
            VStack(spacing: 16) {
                HStack {
                    Image(systemName: "flag.fill")
                        .font(.title2)
                        .foregroundColor(.orange)
                    
                    Text("Video Markers")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Button(action: { showMarkersPanel = false }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                
                Divider()
                    .background(Color.white.opacity(0.3))
                
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(markers ?? [], id: \.id) { marker in
                            markerRow(marker)
                        }
                    }
                    .padding(.horizontal, 4)
                }
                .frame(maxHeight: 300)
            }
            .padding(20)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 40)
            .padding(.vertical, 60)
        }
    }
    
    private func markerRow(_ marker: VideoMarker) -> some View {
        Button(action: {
            seekToMarker(marker)
            showMarkersPanel = false
        }) {
            HStack(spacing: 12) {
                Image(systemName: marker.type.iconName)
                    .font(.title3)
                    .foregroundColor(marker.type.color)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(marker.title)
                        .font(.body)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.leading)
                    
                    if let description = marker.description {
                        Text(description)
                            .font(.caption)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.leading)
                    }
                }
                
                Spacer()
                
                Text(formatTime(marker.timestamp))
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
                    .monospacedDigit()
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(marker.type.color.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Helper Methods
    
    private func toggleControls() {
        withAnimation(.easeInOut(duration: 0.3)) {
            showControls.toggle()
        }
        
        if showControls {
            scheduleControlsHide()
        } else {
            hideControlsTask?.cancel()
        }
    }
    
    private func scheduleControlsHide() {
        hideControlsTask?.cancel()
        hideControlsTask = Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
            
            await MainActor.run {
                if !Task.isCancelled && videoPlayerService.isPlaying {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showControls = false
                    }
                }
            }
        }
    }
    
    private func updateRating(_ rating: TakeRating) {
        currentRating = rating
        
        // UNIFIED: Use SessionManager's unified rating system if context is available
        if let takeID = takeID, let sessionID = sessionID, let projectID = projectID {
            SessionManager.shared.setUnifiedTakeRating(
                takeID: takeID,
                sessionID: sessionID, 
                projectID: projectID,
                rating: rating
            )
            print("✅ UnifiedVideoOverlay: Updated rating via unified system - \(rating.rawValue)")
        }
        
        // Still call the legacy callback for backward compatibility
        onRatingChange?(rating)
    }
    
    private func seekToMarker(_ marker: VideoMarker) {
        // MIGRATED: Uses VideoPlayerService for seeking
        let progress = marker.timestamp / videoPlayerService.duration
        videoPlayerService.seek(to: progress)
    }
    
    private func calculateHandleOffset(width: CGFloat) -> CGFloat {
        // ENHANCED: Uses VideoPlayerService with same NaN protection
        guard width > 0 && width.isFinite && 
              videoPlayerService.progress.isFinite &&
              videoPlayerService.progress >= 0 &&
              videoPlayerService.progress <= 1 &&
              !videoPlayerService.progress.isNaN else {
            print("⚠️ UnifiedVideoOverlay: Invalid values for handle offset - width: \(width), progress: \(videoPlayerService.progress)")
            return 0
        }
        
        let progressWidth = width * videoPlayerService.progress
        let handleRadius: CGFloat = 6
        let maxOffset = width - (handleRadius * 2)
        
        guard progressWidth.isFinite && maxOffset.isFinite && 
              !progressWidth.isNaN && !maxOffset.isNaN else {
            print("⚠️ UnifiedVideoOverlay: Invalid calculation results - progressWidth: \(progressWidth), maxOffset: \(maxOffset)")
            return 0
        }
        
        let offset = max(0, min(maxOffset, progressWidth - handleRadius))
        
        guard offset.isFinite && !offset.isNaN && offset >= 0 else {
            print("⚠️ UnifiedVideoOverlay: Invalid final offset calculated: \(offset)")
            return 0
        }
        
        return offset
    }
    
    // FIXED: Enhanced time formatting with NaN protection
    private func formatTime(_ seconds: TimeInterval) -> String {
        // CRITICAL: Add comprehensive NaN protection
        guard seconds.isFinite && seconds >= 0 && !seconds.isNaN else { 
            print("⚠️ UnifiedVideoOverlay: Invalid time value for formatting: \(seconds)")
            return "0:00" 
        }
        
        let clampedSeconds = max(0, seconds)
        
        // Prevent overflow for extremely large values
        guard clampedSeconds < 86400 else { // 24 hours max
            print("⚠️ UnifiedVideoOverlay: Time value too large: \(clampedSeconds)")
            return "0:00"
        }
        
        let minutes = Int(clampedSeconds) / 60
        let remainingSeconds = Int(clampedSeconds) % 60
        
        // Final validation
        guard minutes >= 0 && remainingSeconds >= 0 && remainingSeconds < 60 else {
            print("⚠️ UnifiedVideoOverlay: Invalid time calculation: \(minutes):\(remainingSeconds)")
            return "0:00"
        }
        
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
}

// MARK: - Backward Compatibility Extensions

extension UnifiedVideoOverlay {
    /// Legacy initializer for backward compatibility with existing VideoPlayerManager usage
    @available(*, deprecated, message: "Use VideoPlayerService-based initializer instead")
    static func withLegacyPlayerManager(
        playerManager: Any, // Changed from VideoPlayerManager to Any
        videoTitle: String,
        videoSubtitle: String? = nil,
        takeNumber: Int? = nil,
        currentRating: TakeRating = .unrated,
        markers: [VideoMarker]? = nil,
        onDismiss: @escaping () -> Void,
        onRatingChange: ((TakeRating) -> Void)? = nil
    ) -> UnifiedVideoOverlay {
        return UnifiedVideoOverlay(
            playerManager: playerManager,
            videoTitle: videoTitle,
            videoSubtitle: videoSubtitle,
            takeNumber: takeNumber,
            currentRating: currentRating,
            markers: markers,
            onDismiss: onDismiss,
            onRatingChange: onRatingChange
        )
    }
}

// MARK: - Video Marker Model

public struct VideoMarker: Identifiable, Codable, Equatable {
    public let id: UUID
    public let timestamp: TimeInterval
    public let title: String
    public let description: String?
    public let type: MarkerType
    
    public enum MarkerType: String, CaseIterable, Codable, Equatable {
        case good = "good"
        case note = "note"
        case problem = "problem"
        case favorite = "favorite"
        
        public var iconName: String {
            switch self {
            case .good: return "checkmark.circle.fill"
            case .note: return "note.text"
            case .problem: return "exclamationmark.triangle.fill"
            case .favorite: return "star.fill"
            }
        }
        
        public var color: Color {
            switch self {
            case .good: return .green
            case .note: return .blue
            case .problem: return .red
            case .favorite: return .yellow
            }
        }
    }
    
    public init(timestamp: TimeInterval, title: String, description: String? = nil, type: MarkerType) {
        self.id = UUID() // FIXED: Initialize in constructor instead of default value
        self.timestamp = timestamp
        self.title = title
        self.description = description
        self.type = type
    }
    
    // Equatable conformance
    public static func == (lhs: VideoMarker, rhs: VideoMarker) -> Bool {
        lhs.id == rhs.id && lhs.timestamp == rhs.timestamp && lhs.title == rhs.title
    }
}

// MARK: - AirPlay Picker Integration

struct AirPlayPickerView: UIViewRepresentable {
    func makeUIView(context: Context) -> AVRoutePickerView {
        let routePickerView = AVRoutePickerView()
        routePickerView.backgroundColor = UIColor.clear
        routePickerView.activeTintColor = UIColor.systemBlue
        routePickerView.tintColor = UIColor.white
        return routePickerView
    }
    
    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {}
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        
        UnifiedVideoOverlay(
            videoPlayerService: VideoPlayerService.shared,
            videoTitle: "Silver Lake Pilot - Scene 1",
            videoSubtitle: "Detective Ramos",
            takeNumber: 3,
            currentRating: .finalSelect,
            markers: [
                VideoMarker(timestamp: 15.5, title: "Great expression", description: nil, type: .good),
                VideoMarker(timestamp: 32.1, title: "Line note", description: "Remember to emphasize 'never'", type: .note),
                VideoMarker(timestamp: 45.8, title: "Favorite moment", description: nil, type: .favorite)
            ],
            onDismiss: {},
            onRatingChange: { _ in }
        )
    }
}
