import SwiftUI
import AVFoundation
import AVKit
import ImageIO

// MARK: - Unified Take Player View - Uses UnifiedTake for Better Performance & Reliability
struct UnifiedTakePlayerView<AdditionalOverlay: View>: View {
    let unifiedTake: UnifiedTake
    let additionalOverlay: () -> AdditionalOverlay
    @Environment(\.dismiss) private var dismiss
    
    // UNIFIED: Direct VideoPlayerService integration without conversion overhead
    @StateObject private var videoPlayerService = VideoPlayerService.shared
    
    @State private var videoFile: VideoFile?
    @State private var isLoading = true
    @State private var loadingError: String?
    @State private var unifiedVideoMarkers: [UnifiedVideoMarker] = []
    @State private var showMarkerCreation = false
    @State private var markerCreationTimestamp: TimeInterval = 0
    
    // Professional timeline editor integration
    @State private var showTimelineEditor = false

    @State private var idleTimerToken: IdleTimerController.Token?
    @Environment(\.playbackOverlayTopComfort) private var overlayTopComfort
    
    // UNIFIED: Repository integration through SessionManager
    private let repository = SessionManager.shared.repositoryInstance
    
    init(
        unifiedTake: UnifiedTake,
        @ViewBuilder additionalOverlay: @escaping () -> AdditionalOverlay = { EmptyView() }
    ) {
        self.unifiedTake = unifiedTake
        self.additionalOverlay = additionalOverlay
    }

    var body: some View {
        ZStack {
            PlaybackSurface(
                background: {
                    Color.black
                },
                video: {
                    if isLoading || loadingError != nil || videoFile == nil {
                        Color.black
                    } else if let videoFile {
                        if unifiedTake.isPhoto {
                            // PHOTO: Display photo content with zoom and rating capabilities
                            UnifiedPhotoContentView(
                                unifiedTake: unifiedTake,
                                videoFile: videoFile,
                                onRatingChange: { newRating in
                                    updateUnifiedTakeRating(newRating)
                                },
                                onDismiss: {
                                    dismiss()
                                }
                            )
                        } else {
                            // VIDEO: Use existing video player for video content
                            // FIXED: Pass the actual video URL to ensure video displays correctly
                            UnifiedVideoPlayerView(url: videoFile.url)
                        }
                    }
                },
                overlay: {
                    if isLoading {
                        loadingView
                    } else if let error = loadingError {
                        errorView(error)
                    } else if videoFile != nil {
                        ZStack {
                            if !unifiedTake.isPhoto {
                                // UNIFIED: Enhanced video overlay with UnifiedVideoMarker support
                                UnifiedVideoOverlay(
                                    videoPlayerService: videoPlayerService,
                                    videoTitle: unifiedTake.formattedFileName,
                                    videoSubtitle: "Take \(unifiedTake.takeNumber) • Scene \(unifiedTake.sceneNumber)",
                                    takeNumber: unifiedTake.takeNumber,
                                    currentRating: unifiedTake.rating,
                                    markers: convertUnifiedMarkersToVideoMarkers(), // Convert for display
                                    onDismiss: {
                                        dismiss()
                                    },
                                    onRatingChange: { newRating in
                                        updateUnifiedTakeRating(newRating)
                                    }
                                )
                            }

                            // UNIFIED: Professional editing controls - only for video content
                            if !unifiedTake.isPhoto {
                                VStack {
                                    Spacer()
                                    HStack {
                                        // Add Marker Button
                                        Button(action: {
                                            markerCreationTimestamp = videoPlayerService.currentTime
                                            showMarkerCreation = true
                                        }) {
                                            Image(systemName: "plus.circle.fill")
                                                .font(.title2)
                                                .foregroundColor(.white)
                                                .background(Color.orange, in: Circle())
                                                .shadow(radius: 4)
                                        }
                                        
                                        Spacer()
                                        
                                        // Professional Timeline Editor button
                                        Button(action: {
                                            showTimelineEditor = true
                                        }) {
                                            HStack(spacing: 8) {
                                                Image(systemName: "timeline.selection")
                                                    .font(.title2)
                                                
                                                Text("Edit")
                                                    .font(.headline)
                                            }
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 8)
                                            .background(Color.blue, in: Capsule())
                                            .shadow(radius: 4)
                                        }
                                    }
                                    .padding(.horizontal, 20)
                                    .padding(.bottom, 120)
                                }
                            }

                            if !unifiedTake.isPhoto {
                                additionalOverlay()
                            }
                        }
                    }
                }
            )
            
            // Marker Creation Modal
            if showMarkerCreation {
                unifiedMarkerCreationModal
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            setupUnifiedVideoPlayer()
            loadUnifiedMarkersFromRepository()
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
            cleanupUnifiedVideoPlayer()
            Task { @MainActor in
                releaseIdleTimer()
            }
        }
        .fullScreenCover(isPresented: $showTimelineEditor) {
            if let videoFile = videoFile {
                // FIXED: Remove NavigationView wrapper - LightweightEditorView already creates UINavigationController
                LightweightEditorView(
                    asset: AVURLAsset(url: videoFile.url),
                    repository: repository,
                    take: findProjectTakeForUnifiedTake(),
                    session: findProjectSessionForUnifiedTake(),
                    project: findProjectForUnifiedTake(),
                    onSave: { asset, trimRange, cropRect, rotationDegrees in
                        // Convert editor results to EditedVideoResult format
                        let hasMeaningfulCrop = cropRect?.sts_hasMeaningfulCrop ?? false
                        let hasRotationChange = (rotationDegrees.map { abs($0) > 0.01 } ?? false)
                        let hasCropChange = hasMeaningfulCrop || hasRotationChange
                        let editResult = EditedVideoResult(
                            originalVideoFile: videoFile,
                            trimRange: trimRange,
                            cropRect: cropRect ?? .zero,
                            cropRotationDegrees: rotationDegrees ?? 0,
                            markers: [], // No markers from this editor flow
                            brightness: 0.0,
                            contrast: 1.0,
                            saturation: 1.0,
                            hasEdits: (trimRange != nil) || hasCropChange
                        )
                        handleEditedVideo(editResult)
                        showTimelineEditor = false
                    },
                    onCancel: {
                        showTimelineEditor = false
                    }
                )
            }
        }
    }

    // MARK: - Unified Setup & Cleanup
    
    private func setupUnifiedVideoPlayer() {
        Task { @MainActor in
            do {
                // UNIFIED: Create video file from UnifiedTake (works for both photos and videos)
                let videoFile = try createVideoFileFromUnifiedTake()
                self.videoFile = videoFile
                
                // CRITICAL FIX: Only setup video player service for actual videos
                if !unifiedTake.isPhoto {
                    videoPlayerService.setupPlayer(with: videoFile.url, context: .takePlayer)
                }
                
                isLoading = false
                print("✅ UnifiedTakePlayerView: Successfully loaded \(unifiedTake.isPhoto ? "photo" : "video") - \(unifiedTake.fileName)")
                print("📍 Media URL: \(videoFile.url.path)")
            } catch {
                loadingError = error.localizedDescription
                isLoading = false
                print("❌ UnifiedTakePlayerView: Failed to load \(unifiedTake.fileName) - \(error)")
            }
        }
    }
    
    private func cleanupUnifiedVideoPlayer() {
        // Only cleanup video player service if we have a video
        if !unifiedTake.isPhoto {
            videoPlayerService.cleanup(context: .takePlayer)
        }
        print("🧹 UnifiedTakePlayerView: Cleaned up \(unifiedTake.isPhoto ? "photo" : "video") player")
    }

    @MainActor
    private func updateIdleTimerForPlayback(_ isPlaying: Bool) {
        guard !unifiedTake.isPhoto else {
            releaseIdleTimer()
            return
        }
        if isPlaying {
            if idleTimerToken == nil {
                idleTimerToken = IdleTimerController.shared.acquire(reason: "UnifiedTakePlayer")
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

    // MARK: - Unified Take Rating Management
    
    private func updateUnifiedTakeRating(_ newRating: TakeRating) {
        print("🔧 UnifiedTakePlayerView: Updating rating for \(unifiedTake.fileName) to \(newRating.rawValue)")
        
        // CRITICAL FIX: Use the unified rating API that syncs to repository
        // This ensures the rating persists in ProjectDetailView rows
        SessionManager.shared.setUnifiedTakeRating(
            takeID: unifiedTake.id,
            sessionID: unifiedTake.sessionID,
            projectID: unifiedTake.projectID,
            rating: newRating
        )
        
        print("✅ UnifiedTakePlayerView: Rating updated with repository persistence")
    }
    
    // MARK: - Unified Marker Management
    
    private func loadUnifiedMarkersFromRepository() {
        guard let repository = repository else {
            print("⚠️ UnifiedTakePlayerView: No repository available")
            return
        }
        
        // FIXED: Use proper take ID resolution from SessionManager
        guard let takeID = SessionManager.shared.getTakeID(for: unifiedTake.fileName) else {
            print("⚠️ Repository: Could not find take \(unifiedTake.fileName) for markers retrieval")
            unifiedVideoMarkers = []
            return
        }
        
        // UNIFIED: Load markers using resolved take ID
        unifiedVideoMarkers = repository.getUnifiedVideoMarkers(
            for: takeID,
            in: unifiedTake.sessionID,
            of: unifiedTake.projectID
        )
        
        print("📍 UnifiedTakePlayerView: Loaded \(unifiedVideoMarkers.count) unified markers")
    }
    
    private func saveUnifiedMarkerToRepository(_ marker: UnifiedVideoMarker) {
        guard let repository = repository else {
            print("⚠️ UnifiedTakePlayerView: No repository for marker save")
            return
        }
        
        // FIXED: Use proper take ID resolution
        guard let takeID = SessionManager.shared.getTakeID(for: unifiedTake.fileName) else {
            print("⚠️ UnifiedTakePlayerView: Could not resolve take ID for marker save")
            return
        }
        
        // UNIFIED: Save marker with resolved take ID
        repository.addUnifiedVideoMarker(
            marker,
            to: takeID,
            in: unifiedTake.sessionID,
            of: unifiedTake.projectID
        )
        
        print("✅ UnifiedTakePlayerView: Saved unified marker '\(marker.title)'")
    }
    
    // MARK: - Conversion Helpers (for UI compatibility)
    
    private func convertUnifiedMarkersToVideoMarkers() -> [VideoMarker]? {
        guard !unifiedVideoMarkers.isEmpty else { return nil }
        
        return unifiedVideoMarkers.map { unifiedMarker in
            unifiedMarker.toVideoMarker()
        }
    }
    
    // MARK: - Enhanced Video File Creation
    
    private func createVideoFileFromUnifiedTake() throws -> VideoFile {
        // UNIFIED: Use proper file path resolution strategy for both photos and videos
        let mediaURL = getUnifiedMediaURL() // Renamed to reflect it handles both photos and videos
        
        guard let mediaURL = mediaURL else {
            throw VideoLoadError.fileNotFound(unifiedTake.fileName)
        }
        
        print("📹 UnifiedTakePlayerView: Creating VideoFile from unified take (\(unifiedTake.isPhoto ? "photo" : "video"))")
        print("📍 File path: \(mediaURL.path)")
        print("📊 Expected duration: \(unifiedTake.duration)s")
        print("📊 File size: \(unifiedTake.formattedFileSize)")
        
        // Verify file exists
        guard FileManager.default.fileExists(atPath: mediaURL.path) else {
            throw VideoLoadError.fileNotFound("File does not exist: \(mediaURL.path)")
        }
        
        // UNIFIED: Create enhanced metadata from UnifiedTake
        let metadata = VideoMetadata(
            projectTitle: getCurrentProjectTitle(),
            roleName: getCurrentRoleName(),
            sceneNumber: unifiedTake.sceneNumber,
            takeNumber: unifiedTake.takeNumber,
            rating: unifiedTake.rating,
            duration: unifiedTake.duration,
            resolution: nil,
            frameRate: nil,
            codec: nil,
            recordingDate: unifiedTake.createdAt,
            cameraPosition: unifiedTake.cameraPosition,
            audioChannels: nil,
            notes: unifiedTake.notes
        )
        
        return VideoFile(
            filePath: mediaURL.path,
            fileName: unifiedTake.fileName,
            metadata: metadata,
            fileSize: Int(unifiedTake.fileSize), // UnifiedTake has reliable file size
            createdAt: unifiedTake.createdAt
        )
    }
    
    private func getUnifiedMediaURL() -> URL? {
        print("📍 UnifiedTakePlayerView: Resolving \(unifiedTake.isPhoto ? "photo" : "video") URL for \(unifiedTake.fileName)")
        
        // CRITICAL FIX: Strategy 1 - Use VideoFileManager for consistent file path resolution
        do {
            let mediaURL = try VideoFileManager.shared.getVideoURL(for: unifiedTake.fileName)
            print("✅ Found unified \(unifiedTake.isPhoto ? "photo" : "video") using VideoFileManager: \(mediaURL.path)")
            return mediaURL
        } catch {
            print("⚠️ VideoFileManager couldn't locate file: \(error)")
        }
        
        // FIXED: Strategy 2 - Check Documents directory (where CameraCaptureView saves files)
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let documentsURL = documentsPath.appendingPathComponent(unifiedTake.fileName)
        
        if FileManager.default.fileExists(atPath: documentsURL.path) {
            print("✅ Found unified \(unifiedTake.isPhoto ? "photo" : "video") in Documents: \(documentsURL.path)")
            return documentsURL
        }
        
        // FIXED: Strategy 3 - Try UnifiedTake.filePath if it looks valid and exists
        if !unifiedTake.filePath.isEmpty && unifiedTake.filePath != "/" {
            let unifiedURL = URL(fileURLWithPath: unifiedTake.filePath)
            
            if FileManager.default.fileExists(atPath: unifiedURL.path) {
                print("✅ Found unified \(unifiedTake.isPhoto ? "photo" : "video") at stored path: \(unifiedURL.path)")
                return unifiedURL
            } else {
                print("⚠️ Stored path doesn't exist: \(unifiedURL.path)")
            }
        }
        
        // FIXED: Strategy 4 - Search using project-based naming patterns for photos and videos
        let projectName = getCurrentProjectTitle().replacingOccurrences(of: " ", with: "_")
        let expectedExtensions = unifiedTake.isPhoto ? ["jpg", "jpeg", "png", "heic"] : ["mov", "mp4", "m4v"]
        
        // Look for any files that match expected patterns in Documents directory
        if let documentsContents = try? FileManager.default.contentsOfDirectory(at: documentsPath, includingPropertiesForKeys: nil) {
            for fileURL in documentsContents {
                let fileName = fileURL.lastPathComponent
                let fileExtension = fileURL.pathExtension.lowercased()
                
                // Match either exact filename or project-based patterns with correct extensions
                if (fileName == unifiedTake.fileName || 
                   (fileName.hasPrefix(projectName) && expectedExtensions.contains(fileExtension))) {
                    print("✅ Found potential match: \(fileName)")
                    return fileURL
                }
            }
        }
        
        // ENHANCED: Strategy 5 - Search all common locations for debugging
        let commonPaths = [
            documentsPath,
            FileManager.default.temporaryDirectory,
            FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        ].compactMap { $0 }
        
        print("🔍 Comprehensive search for '\(unifiedTake.fileName)':")
        for basePath in commonPaths {
            let searchURL = basePath.appendingPathComponent(unifiedTake.fileName)
            let exists = FileManager.default.fileExists(atPath: searchURL.path)
            print("   - \(basePath.lastPathComponent): \(exists ? "✅ FOUND" : "❌ Not found") at \(searchURL.path)")
            
            if exists {
                return searchURL
            }
        }
        
        // ENHANCED: Debug information for troubleshooting
        print("❌ UnifiedTakePlayerView: COMPREHENSIVE SEARCH FAILED")
        print("   🎯 Target file: '\(unifiedTake.fileName)'")
        print("   📍 Stored path: '\(unifiedTake.filePath)'")
        print("   📁 Documents dir: '\(documentsPath.path)'")
        print("   📸 Is photo: \(unifiedTake.isPhoto)")
        
        // List all files in Documents for debugging
        if let allFiles = try? FileManager.default.contentsOfDirectory(at: documentsPath, includingPropertiesForKeys: nil) {
            let mediaFiles = allFiles.filter { file in
                let ext = file.pathExtension.lowercased()
                return expectedExtensions.contains(ext)
            }
            print("   📹 Available \(unifiedTake.isPhoto ? "photo" : "video") files in Documents:")
            for file in mediaFiles {
                print("      - \(file.lastPathComponent)")
            }
        }
        
        return nil
    }
    
    private func getCurrentProjectTitle() -> String {
        if let currentSession = SessionManager.shared.currentSession {
            return currentSession.project.title
        }
        return "Self Tape Session"
    }
    
    private func getCurrentRoleName() -> String? {
        if let currentSession = SessionManager.shared.currentSession {
            return currentSession.session.roleName
        }
        return nil
    }
    
    // MARK: - UI Components
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(.white)
            
            VStack(spacing: 8) {
                Text("Loading unified take...")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text(unifiedTake.fileName)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
    }
    
    private func errorView(_ error: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.red)
            
            Text("Could not load unified take")
                .font(.headline)
                .foregroundColor(.white)
            
            Text(error)
                .font(.caption)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
            
            Button("Dismiss") {
                dismiss()
            }
            .font(.headline)
            .foregroundColor(.white)
            .padding()
            .background(Color.blue, in: RoundedRectangle(cornerRadius: 12))
        }
        .padding()
    }
    
    // MARK: - Unified Marker Creation Modal
    
    private var unifiedMarkerCreationModal: some View {
        ZStack {
            Color.black.opacity(0.8)
                .ignoresSafeArea()
                .onTapGesture {
                    showMarkerCreation = false
                }
            
            UnifiedMarkerCreationView(
                timestamp: markerCreationTimestamp,
                onCreateMarker: { unifiedMarker in
                    unifiedVideoMarkers.append(unifiedMarker)
                    unifiedVideoMarkers.sort { $0.timestamp < $1.timestamp }
                    
                    // Save to repository
                    saveUnifiedMarkerToRepository(unifiedMarker)
                    
                    showMarkerCreation = false
                },
                onCancel: {
                    showMarkerCreation = false
                }
            )
        }
    }
    
    // MARK: - Video Editing Integration
    
    private func handleEditedVideo(_ editResult: EditedVideoResult) {
        print("🎬 UnifiedTakePlayerView: Video editing completed")
        
        // Convert any new markers to unified format
        if !editResult.markers.isEmpty {
            let unifiedMarkers = editResult.markers.map { videoMarker in
                UnifiedVideoMarker(from: videoMarker)
            }
            
            // Add to local array
            unifiedVideoMarkers.append(contentsOf: unifiedMarkers)
            unifiedVideoMarkers.sort { $0.timestamp < $1.timestamp }
            
            // Save to repository
            for marker in unifiedMarkers {
                saveUnifiedMarkerToRepository(marker)
            }
            
            print("✅ Converted and saved \(unifiedMarkers.count) unified markers")
        }
    }
    
    // MARK: - Helper Methods for Repository Integration

    private func findProjectTakeForUnifiedTake() -> ProjectTake? {
        guard let repository = repository else { return nil }
        
        guard let project = repository.project(by: unifiedTake.projectID) else { return nil }
        guard let session = project.sessions.first(where: { $0.id == unifiedTake.sessionID }) else { return nil }
        
        // FIXED: ProjectTake doesn't have fileName, need to extract from filePath
        return session.takes.first(where: { take in
            let takeFileName = URL(fileURLWithPath: take.filePath).lastPathComponent
            return takeFileName == unifiedTake.fileName || take.filePath.hasSuffix(unifiedTake.fileName)
        })
    }
    
    private func findProjectSessionForUnifiedTake() -> ProjectSession? {
        guard let repository = repository else { return nil }
        
        guard let project = repository.project(by: unifiedTake.projectID) else { return nil }
        return project.sessions.first(where: { $0.id == unifiedTake.sessionID })
    }
    
    private func findProjectForUnifiedTake() -> Project? {
        guard let repository = repository else { return nil }
        return repository.project(by: unifiedTake.projectID)
    }
}

// MARK: - Unified Marker Creation View

struct UnifiedMarkerCreationView: View {
    let timestamp: TimeInterval
    let onCreateMarker: (UnifiedVideoMarker) -> Void
    let onCancel: () -> Void
    
    @State private var title: String = ""
    @State private var description: String = ""
    @State private var selectedType: UnifiedVideoMarker.MarkerType = .note
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "flag.fill")
                        .font(.title2)
                        .foregroundColor(.orange)
                    
                    Text("Add Unified Marker")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Button("Cancel", action: onCancel)
                        .foregroundColor(.gray)
                }
                
                Text("at \(formatTime(timestamp))")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Divider()
                .background(Color.white.opacity(0.3))
            
            // Unified Marker Type Selection
            HStack {
                Text("Type:")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                HStack(spacing: 12) {
                    ForEach(UnifiedVideoMarker.MarkerType.allCases, id: \.self) { type in
                        Button(action: {
                            selectedType = type
                        }) {
                            VStack(spacing: 4) {
                                Image(systemName: type.iconName)
                                    .font(.title3)
                                    .foregroundColor(selectedType == type ? type.color : .gray)
                                
                                Text(type.displayName)
                                    .font(.caption2)
                                    .foregroundColor(.white.opacity(0.7))
                            }
                            .padding(8)
                            .background(
                                selectedType == type
                                    ? Color.white.opacity(0.1)
                                    : Color.clear,
                                in: RoundedRectangle(cornerRadius: 8)
                            )
                        }
                    }
                }
            }
            
            // Title Input
            VStack(alignment: .leading, spacing: 4) {
                Text("Title")
                    .font(.headline)
                    .foregroundColor(.white)
                
                TextField("Unified marker title", text: $title)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .onAppear {
                        title = getDefaultTitleForType(selectedType)
                    }
                    .onChange(of: selectedType, initial: false) { _, newType in
                        if title.isEmpty || isDefaultTitle(title) {
                            title = getDefaultTitleForType(newType)
                        }
                    }
            }
            
            // Description Input
            VStack(alignment: .leading, spacing: 4) {
                Text("Notes (Optional)")
                    .font(.headline)
                    .foregroundColor(.white)
                
                TextField("Additional notes...", text: $description, axis: .vertical)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .lineLimit(2...4)
            }
            
            // Action Buttons
            HStack(spacing: 16) {
                Button("Cancel", action: onCancel)
                    .font(.headline)
                    .foregroundColor(.gray)
                    .padding()
                    .background(Color.gray.opacity(0.2), in: RoundedRectangle(cornerRadius: 12))
                
                Button("Add Unified Marker") {
                    createUnifiedMarker()
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding()
                .background(
                    title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? Color.gray
                        : selectedType.color,
                    in: RoundedRectangle(cornerRadius: 12)
                )
                .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 40)
    }
    
    private func createUnifiedMarker() {
        let marker = UnifiedVideoMarker(
            timestamp: timestamp,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            description: description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? nil
                : description.trimmingCharacters(in: .whitespacesAndNewlines),
            type: selectedType
        )
        onCreateMarker(marker)
    }
    
    private func formatTime(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let remainingSeconds = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
    
    private func getDefaultTitleForType(_ type: UnifiedVideoMarker.MarkerType) -> String {
        switch type {
        case .good:
            return "Great unified moment"
        case .note:
            return "Unified note"
        case .problem:
            return "Issue to review"
        case .favorite:
            return "Star moment"
        }
    }
    
    private func isDefaultTitle(_ title: String) -> Bool {
        let defaultTitles = ["Great unified moment", "Unified note", "Issue to review", "Star moment"]
        return defaultTitles.contains(title)
    }
}

// MARK: - Video Load Error

enum VideoLoadError: LocalizedError {
    case fileNotFound(String)
    case invalidFile(String)
    case unknownError(String)
    
    var errorDescription: String? {
        switch self {
        case .fileNotFound(let fileName):
            return "Video file '\(fileName)' not found"
        case .invalidFile(let fileName):
            return "Invalid video file: \(fileName)"
        case .unknownError(let message):
            return message
        }
    }
}

// MARK: - Unified Photo Content View

struct UnifiedPhotoContentView: View {
    let unifiedTake: UnifiedTake
    let videoFile: VideoFile
    let onRatingChange: (TakeRating) -> Void
    let onDismiss: () -> Void

    @Environment(\.playbackOverlayTopComfort) private var overlayTopComfort
    
    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var showOverlays = true
    @GestureState private var magnification: CGFloat = 1.0
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Photo display
                if let image = loadPhotoImage() {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .scaleEffect(scale * magnification)
                        .offset(offset)
                        .gesture(
                            SimultaneousGesture(
                                // Zoom gesture
                                MagnificationGesture()
                                    .updating($magnification) { value, state, _ in
                                        state = value
                                    }
                                    .onEnded { value in
                                        scale = max(0.5, min(scale * value, 5.0))
                                    },
                                
                                // Pan gesture for zoomed images
                                DragGesture()
                                    .onChanged { value in
                                        if scale > 1.0 {
                                            offset = CGSize(
                                                width: offset.width + value.translation.width / scale,
                                                height: offset.height + value.translation.height / scale
                                            )
                                        }
                                    }
                            )
                        )
                        .onTapGesture(count: 2) {
                            // Double-tap to zoom
                            withAnimation(.easeInOut(duration: 0.3)) {
                                if scale > 1.0 {
                                    scale = 1.0
                                    offset = .zero
                                } else {
                                    scale = 2.0
                                }
                            }
                        }
                        .onTapGesture {
                            // Single tap to toggle overlays
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showOverlays.toggle()
                            }
                        }
                } else {
                    // Photo loading placeholder
                    VStack(spacing: 16) {
                        Image(systemName: "photo")
                            .font(.system(size: 48))
                            .foregroundColor(.white.opacity(0.6))
                        
                        Text("Photo not available")
                            .font(.headline)
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                
                // Photo overlays with same positioning as video overlays
                if showOverlays {
                    photoOverlays
                }
            }
            .clipped()
        }
    }
    
    @ViewBuilder
    private var photoOverlays: some View {
        VStack {
            // Top overlay - Photo title
            HStack {
                Spacer()
                
                VStack(alignment: .center, spacing: 4) {
                    Text(formatPhotoTitle())
                        .font(.headline)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                    
                    Text(formatPhotoSubtitle())
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.black.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
                
                Spacer()
            }
            .padding()
            .padding(.top, overlayTopComfort)
            
            Spacer()
            
            // ENTERPRISE: Professional rating overlay using UnifiedRatingButtons
            HStack {
                Spacer()
                
                VStack(spacing: 16) {
                    // Close button
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 50, height: 50)
                            .background(
                                Color.black.opacity(0.6),
                                in: Circle()
                            )
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                    }
                    
                    // ENTERPRISE: Use UnifiedRatingButtons for consistent enterprise experience
                    UnifiedRatingButtons(
                        currentRating: unifiedTake.rating,
                        layout: .vertical,
                        size: .large,
                        onRatingChange: { newRating in
                            print("📸 UnifiedTakePlayer: Photo rating changed to \(newRating.rawValue)")
                            onRatingChange(newRating)
                        }
                    )
                    .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                }
                .padding(.trailing, 20)
            }
            .padding(.vertical)
        }
        .transition(.opacity)
    }
    
    // Helper methods for photo rating display
    private func loadPhotoImage() -> UIImage? {
        // CRITICAL FIX: Apply EXIF orientation correction like SwipeableMediaPlayerView
        let photoURL = videoFile.url
        
        if FileManager.default.fileExists(atPath: photoURL.path) {
            return loadImageWithOrientationCorrection(from: photoURL)
        }
        
        // Fallback: Try unifiedTake filePath
        if !unifiedTake.filePath.isEmpty {
            let fallbackURL = URL(fileURLWithPath: unifiedTake.filePath)
            if FileManager.default.fileExists(atPath: fallbackURL.path) {
                return loadImageWithOrientationCorrection(from: fallbackURL)
            }
        }
        
        return nil
    }
    
    // CRITICAL FIX: Add EXIF orientation correction method from SwipeableMediaPlayerView
    private func loadImageWithOrientationCorrection(from url: URL) -> UIImage? {
        // Load image with proper EXIF orientation handling
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
            print("❌ UnifiedTakePlayerView: Failed to create CGImage from \(url.lastPathComponent)")
            return nil
        }
        
        // Read EXIF orientation from image metadata
        let orientation = getImageOrientation(from: imageSource)
        
        // Apply orientation correction
        let correctedImage = correctImageOrientation(cgImage: cgImage, orientation: orientation)
        
        if correctedImage != nil {
            print("✅ UnifiedTakePlayerView: Loaded and orientation-corrected photo: \(url.lastPathComponent)")
        } else {
            print("❌ UnifiedTakePlayerView: Failed to apply orientation correction for: \(url.lastPathComponent)")
        }
        
        return correctedImage
    }
    
    // CRITICAL FIX: Read EXIF orientation from image source
    private func getImageOrientation(from imageSource: CGImageSource) -> CGImagePropertyOrientation {
        guard let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any],
              let orientationValue = properties[kCGImagePropertyOrientation] as? UInt32 else {
            return .up // Default orientation
        }
        
        return CGImagePropertyOrientation(rawValue: orientationValue) ?? .up
    }
    
    // CRITICAL FIX: Apply orientation correction from SwipeableMediaPlayerView
    private func correctImageOrientation(cgImage: CGImage, orientation: CGImagePropertyOrientation) -> UIImage? {
        // If orientation is already correct, return as-is for performance
        if orientation == .up {
            return UIImage(cgImage: cgImage)
        }
        
        print("📸 UnifiedTakePlayerView: Applying EXIF orientation correction: \(orientation.rawValue) (\(orientation.description))")
        
        let width = cgImage.width
        let height = cgImage.height
        
        // Determine the size and transform based on orientation
        var transform = CGAffineTransform.identity
        var size = CGSize(width: width, height: height)
        
        switch orientation {
        case .up:
            transform = .identity
            
        case .upMirrored:
            transform = CGAffineTransform(scaleX: -1, y: 1)
            
        case .down:
            transform = CGAffineTransform(rotationAngle: .pi)
            
        case .downMirrored:
            transform = CGAffineTransform(rotationAngle: .pi).scaledBy(x: -1, y: 1)
            
        case .left:
            transform = CGAffineTransform(rotationAngle: .pi / 2)
            size = CGSize(width: height, height: width)
            
        case .leftMirrored:
            transform = CGAffineTransform(rotationAngle: .pi / 2).scaledBy(x: -1, y: 1)
            size = CGSize(width: height, height: width)
            
        case .right:
            transform = CGAffineTransform(rotationAngle: -.pi / 2)
            size = CGSize(width: height, height: width)
            
        case .rightMirrored:
            transform = CGAffineTransform(rotationAngle: -.pi / 2).scaledBy(x: -1, y: 1)
            size = CGSize(width: height, height: width)
        @unknown default:
            print("⚠️ UnifiedTakePlayerView: Unknown orientation: \(orientation.rawValue), using identity")
            transform = .identity
        }
        
        // Create graphics context and apply transform
#if DEBUG
        if size.width <= 0 || size.height <= 0 {
            print("⚠️ UnifiedTakePlayerView: invalid image context size \(size) for cgImage=\(width)x\(height) orientation=\(orientation.rawValue)")
        }
#endif
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        guard let context = UIGraphicsGetCurrentContext() else {
            UIGraphicsEndImageContext()
            return UIImage(cgImage: cgImage)
        }
        
        // Configure context for the transformation
        context.concatenate(transform)
        
        // Draw the image in the correct coordinate system
        let drawRect: CGRect
        switch orientation {
        case .left, .leftMirrored:
            drawRect = CGRect(x: 0, y: -height, width: width, height: height)
        case .right, .rightMirrored:
            drawRect = CGRect(x: -width, y: 0, width: width, height: height)
        case .down, .downMirrored:
            drawRect = CGRect(x: -width, y: -height, width: width, height: height)
        default:
            drawRect = CGRect(x: 0, y: 0, width: width, height: height)
        }
        
        context.draw(cgImage, in: drawRect)
        let orientedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        print("✅ UnifiedTakePlayerView: Applied EXIF orientation correction: \(orientation.description)")
        return orientedImage
    }
    
    private func formatPhotoTitle() -> String {
        if unifiedTake.isKeyframePhoto {
            return "Keyframe Photo \(unifiedTake.takeNumber)"
        } else if unifiedTake.isSlate {
            return "Slate Photo"
        } else if unifiedTake.sceneNumber > 1 {
            return "Scene \(unifiedTake.sceneNumber) Photo \(unifiedTake.takeNumber)"
        } else {
            return "Photo \(unifiedTake.takeNumber)"
        }
    }
    
    private func formatPhotoSubtitle() -> String {
        // Show creation time for photos
        let timeAgo = formatTimeAgo(from: unifiedTake.createdAt)
        
        if unifiedTake.isKeyframePhoto {
            return "Keyframe photo • \(timeAgo)"
        } else if unifiedTake.isSlate {
            return "Slate photo • \(timeAgo)"
        } else if unifiedTake.sceneNumber > 1 {
            return "Scene \(unifiedTake.sceneNumber) photo • \(timeAgo)"
        } else {
            return "Photo • \(timeAgo)"
        }
    }
    
    private func formatTimeAgo(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 60 { 
            return "now" 
        } else if interval < 3600 { 
            return "\(Int(interval / 60))m ago" 
        } else if interval < 86400 { 
            return "\(Int(interval / 3600))h ago" 
        } else { 
            return "\(Int(interval / 86400))d ago" 
        }
    }
}


// MARK: - Preview

#Preview {
    let sampleUnifiedTake = UnifiedTake(
        fileName: "Ghost_Take2.mov",
        projectID: UUID(),
        sessionID: UUID(),
        filePath: "/sample/path/Ghost_Take2.mov",
        duration: 3.0,
        fileSize: 3060949,
        cameraPosition: "back",
        sceneNumber: 1,
        takeNumber: 2,
        rating: .finalSelect,
        notes: "Great performance"
    )
    
    UnifiedTakePlayerView(unifiedTake: sampleUnifiedTake)
}
