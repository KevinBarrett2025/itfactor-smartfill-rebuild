import SwiftUI
import AVFoundation
import AVKit
import ImageIO

// MARK: - 60FPS PERFORMANCE: Swift 6 Compliant Image Cache Actor

@globalActor
actor ImageCacheGate {
    static let shared = ImageCacheGate()
    
    private var loadingTasks: [String: Task<UIImage?, Never>] = [:]
    
    func storeTask(_ task: Task<UIImage?, Never>, for key: String) {
        loadingTasks[key] = task
    }
    
    func removeTask(for key: String) {
        loadingTasks.removeValue(forKey: key)
    }
    
    func getTask(for key: String) -> Task<UIImage?, Never>? {
        return loadingTasks[key]
    }
}

// MARK: - 60FPS PERFORMANCE: Optimized Image Cache for Enterprise UI

final class OptimizedImageCache: ObservableObject, @unchecked Sendable {
    static let shared = OptimizedImageCache()
    
    private let cache = NSCache<NSString, UIImage>()
    private let loadingQueue = DispatchQueue(label: "com.sts.imageLoading", qos: .userInteractive)
    
    private init() {
        // Configure cache for 60fps performance
        cache.countLimit = 50 // Limit memory usage
        cache.totalCostLimit = 100 * 1024 * 1024 // 100MB limit
        
        // Listen for memory warnings
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.cache.removeAllObjects()
            print("🧹 Image cache cleared due to memory warning")
        }
    }
    
    func loadImage(for path: String) async -> UIImage? {
        // SWIFT 6 FIX: Convert to String before capture to avoid NSString sendable issues
        let cacheKey = String(path)
        let nsCacheKey = NSString(string: cacheKey)
        
        // Check cache first for 60fps performance
        if let cachedImage = cache.object(forKey: nsCacheKey) {
            return cachedImage
        }
        
        // Swift 6 compliant: Use actor for task coordination instead of NSLock
        let existingTask = await ImageCacheGate.shared.getTask(for: path)
        
        if let existingTask = existingTask {
            return await existingTask.value
        }
        
        // Create loading task
        let task = Task<UIImage?, Never> {
            await loadImageFromDiskWithOrientation(path: path, cacheKey: cacheKey)
        }
        
        // Swift 6 compliant: Store task through actor
        await ImageCacheGate.shared.storeTask(task, for: path)
        
        let result = await task.value
        
        // Swift 6 compliant: Clean up task through actor
        await ImageCacheGate.shared.removeTask(for: path)
        
        return result
    }
    
    // CRITICAL FIX: New method that handles EXIF orientation properly
    // SWIFT 6 FIX: Change cacheKey parameter from NSString to String
    // Simplified image load relying on UIKit EXIF handling
    private func loadImageFromDiskWithOrientation(path: String, cacheKey: String) async -> UIImage? {
        return await withCheckedContinuation { continuation in
            loadingQueue.async {
                let cache = self.cache
                let nsKey = NSString(string: cacheKey)

                var imageURL: URL
                if path.hasPrefix("/") {
                    imageURL = URL(fileURLWithPath: path)
                } else {
                    imageURL = VideoVariantResolver.urlForRelativePath(path)
                }

                if !FileManager.default.fileExists(atPath: imageURL.path) {
                    let fileName = URL(fileURLWithPath: path).lastPathComponent
                    let documentsURL = VideoVariantResolver.documentsURL().appendingPathComponent(fileName)
                    if FileManager.default.fileExists(atPath: documentsURL.path) {
                        imageURL = documentsURL
                    } else {
                        print("❌ OptimizedImageCache: Photo not found at \(imageURL.path)")
                        continuation.resume(returning: nil)
                        return
                    }
                }

                let logName = imageURL.lastPathComponent
                guard let image = UIImage(contentsOfFile: imageURL.path) else {
                    print("❌ Failed to load UIImage from path: \(imageURL.path)")
                    continuation.resume(returning: nil)
                    return
                }

                DispatchQueue.main.async {
                    cache.setObject(image, forKey: nsKey)
                    print("✅ Loaded photo image (system EXIF handling): \(logName)")
                }

                continuation.resume(returning: image)
            }
        }
    }
    
    // NOTE: Currently unused now that we rely on UIImage(contentsOfFile:)
    // for EXIF orientation handling in the photo viewer.
    private func getImageOrientation(from imageSource: CGImageSource) -> CGImagePropertyOrientation {
        guard let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any],
              let orientationValue = properties[kCGImagePropertyOrientation] as? UInt32 else {
            return .up // Default orientation
        }
        
        return CGImagePropertyOrientation(rawValue: orientationValue) ?? .up
    }
    
    // NOTE: Currently unused now that we rely on UIImage(contentsOfFile:)
    // for EXIF orientation handling in the photo viewer.
    private func correctImageOrientation(cgImage: CGImage, orientation: CGImagePropertyOrientation) -> UIImage? {
        // If orientation is already correct, return as-is for performance
        if orientation == .up {
            return UIImage(cgImage: cgImage)
        }
        
        print("📸 Applying EXIF orientation correction: \(orientation.rawValue) (\(orientation.description))")
        
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
            print("⚠️ Unknown orientation: \(orientation.rawValue), using identity")
            transform = .identity
        }
        
        // Create graphics context and apply transform
#if DEBUG
        if size.width <= 0 || size.height <= 0 {
            print("⚠️ SwipeableMediaPlayerView: invalid image context size \(size) for cgImage=\(width)x\(height) orientation=\(orientation.rawValue)")
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
        
        print("✅ Applied EXIF orientation correction: \(orientation.description)")
        return orientedImage
    }
    
    // DEPRECATED: Keep old method for backward compatibility but mark as deprecated
    private func loadImageFromDisk(path: String, cacheKey: String) async -> UIImage? {
        // This method is now deprecated in favor of loadImageFromDiskWithOrientation
        return await loadImageFromDiskWithOrientation(path: path, cacheKey: cacheKey)
    }
    
    func preloadImages(for paths: [String]) {
        Task {
            await withTaskGroup(of: Void.self) { group in
                for path in paths {
                    group.addTask {
                        _ = await self.loadImage(for: path)
                    }
                }
            }
        }
    }
}

// MARK: - EXIF Orientation Extension

extension CGImagePropertyOrientation {
    var description: String {
        switch self {
        case .up: return "Up (normal)"
        case .upMirrored: return "Up Mirrored"
        case .down: return "Down (180°)"
        case .downMirrored: return "Down Mirrored"
        case .left: return "Left (90° CW)"
        case .leftMirrored: return "Left Mirrored"
        case .right: return "Right (90° CCW)"
        case .rightMirrored: return "Right Mirrored"
        @unknown default: return "Unknown (\(rawValue))"
        }
    }
}

// MARK: - 60FPS PERFORMANCE: Optimized Async Image View

struct OptimizedAsyncImageView: View {
    let imagePath: String
    let placeholder: AnyView
    
    @StateObject private var imageCache = OptimizedImageCache.shared
    @State private var loadedImage: UIImage?
    @State private var isLoading = true
    
    init<PlaceholderContent: View>(
        imagePath: String,
        @ViewBuilder placeholder: () -> PlaceholderContent
    ) {
        self.imagePath = imagePath
        self.placeholder = AnyView(placeholder())
    }
    
    var body: some View {
        Group {
            if let loadedImage = loadedImage {
                Image(uiImage: loadedImage)
                    .resizable()
                    .transition(.opacity.animation(.easeInOut(duration: 0.2)))
            } else {
                placeholder
                    .overlay(
                        // 60FPS: Subtle loading indicator
                        isLoading ?
                        ProgressView()
                            .scaleEffect(0.8)
                            .tint(.white.opacity(0.6))
                        : nil
                    )
            }
        }
        .task {
            await loadImageAsync()
        }
        .onChange(of: imagePath, initial: false) { _, _ in
            Task {
                await loadImageAsync()
            }
        }
    }
    
    private func loadImageAsync() async {
        isLoading = true
        let image = await imageCache.loadImage(for: imagePath)
        
        await MainActor.run {
            withAnimation(.easeInOut(duration: 0.2)) {
                loadedImage = image
                isLoading = false
            }
        }
    }
}

// MARK: - Unified Media Display Data

struct MediaPlayerDisplayData {
    let take: ProjectTake
    let unifiedTake: UnifiedTake
    let takeNumber: Int
    let totalTakes: Int
    let isPhoto: Bool
    let displayLabel: String
    let isSmartFillVariant: Bool
    
    init(take: ProjectTake, unifiedTake: UnifiedTake, takeNumber: Int, totalTakes: Int, displayLabel: String, isSmartFillVariant: Bool) {
        self.take = take
        self.unifiedTake = unifiedTake
        self.takeNumber = takeNumber
        self.totalTakes = totalTakes
        self.isPhoto = unifiedTake.isPhoto
        self.displayLabel = displayLabel
        self.isSmartFillVariant = isSmartFillVariant
    }
}

enum RatingsOverlayMode {
    case uikit
    case swiftUIChromeAnchored
}

/// PHASE 3: Unified media player that handles both photos and videos with comprehensive swipe functionality
/// PRESERVED: All swipeable functionality from SwipeableVideoPlayerView
/// ENHANCED: Added photo display support with same gesture system
struct SwipeableMediaPlayerView: View {
    let takes: [ProjectTake]
    let currentSession: ProjectSession
    let currentProject: Project
    let initialIndex: Int
    let onDismiss: () -> Void
    let onTakeAction: (TakeAction, ProjectTake) -> Void
    let ratingsOverlayMode: RatingsOverlayMode
    let manageAudioSession: Bool
    let showsTitleOverlay: Bool
    private let externalIndexBinding: Binding<Int>?
    
    @State private var currentIndex: Int
    @State private var mediaPlayerData: [MediaPlayerDisplayData] = []
    @State private var isLoading = true
    
    // PRESERVED: Video player lifecycle management for videos
    @State private var videoPlayers: [Int: EnhancedAVPlayerViewController] = [:]
    @State private var previousIndex: Int = 0
    
    // PRESERVED: Explicit dismiss control
    @State private var shouldDismiss = false
    
    // PRESERVED: Pull-to-dismiss state with background reveal
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging = false
    @State private var backgroundOpacity: Double = 0
    @State private var isZoomedIn = false
    @State private var interactionEndWorkItem: DispatchWorkItem?
    @State private var pendingSelectionIndex: Int?
    @State private var wasPlayingBeforeDrag = false

    @Environment(\.playbackInteractionActive) private var playbackInteractionActive
    
    init(takes: [ProjectTake],
         session: ProjectSession,
         project: Project,
         initialIndex: Int = 0,
         currentIndexBinding: Binding<Int>? = nil,
         onDismiss: @escaping () -> Void,
         onTakeAction: @escaping (TakeAction, ProjectTake) -> Void,
         ratingsOverlayMode: RatingsOverlayMode = .uikit,
         manageAudioSession: Bool = true,
         showsTitleOverlay: Bool = true) {
        self.takes = takes
        self.currentSession = session
        self.currentProject = project
        self.initialIndex = initialIndex
        self.onDismiss = onDismiss
        self.onTakeAction = onTakeAction
        self.ratingsOverlayMode = ratingsOverlayMode
        self.manageAudioSession = manageAudioSession
        self.showsTitleOverlay = showsTitleOverlay
        self.externalIndexBinding = currentIndexBinding
        let seedIndex = currentIndexBinding?.wrappedValue ?? initialIndex
        self._currentIndex = State(initialValue: seedIndex)
        self._previousIndex = State(initialValue: seedIndex)
    }
    
    var body: some View {
        GeometryReader { geometry in
            PlaybackSurface(
                background: {
                    // PRESERVED: Background that becomes visible during pull-to-dismiss
                    Color.clear
                        .background(.ultraThinMaterial)
                        .opacity(backgroundOpacity)
                },
                video: {
                    // Main media player content
                    ZStack {
                        Color.black
                        
                        if isLoading {
                            loadingView
                        } else if !mediaPlayerData.isEmpty {
                            TabView(selection: $currentIndex) {
                                ForEach(Array(mediaPlayerData.enumerated()), id: \.offset) { index, mediaData in
                                    // UNIFIED: Media content that handles both photos and videos
                                    UnifiedMediaContentView(
                                        mediaData: mediaData,
                                        index: index,
                                        onDismiss: {
                                            shouldDismiss = true
                                        },
                                        onRatingChange: { newRating in
                                            handleRatingChange(newRating, for: mediaData.take)
                                        },
                                        onShare: {
                                            handleShare(mediaData.take)
                                        },
                                        onVideoPlayerCreated: { playerController in
                                            // PRESERVED: Video player lifecycle management
                                            videoPlayers[index] = playerController
                                            playerController.isCurrentlyVisible = (index == currentIndex)
                                        },
                                        manageAudioSession: manageAudioSession,
                                        showsTitleOverlay: showsTitleOverlay,
                                        ratingsOverlayMode: ratingsOverlayMode
                                    )
                                    .tag(index)
                                }
                            }
                            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                            .simultaneousGesture(
                                DragGesture(minimumDistance: 2)
                                    .onChanged { _ in
                                        beginPlaybackInteraction(source: "tabview-drag")
                                    }
                                    .onEnded { _ in
                                        endPlaybackInteractionDebounced(source: "tabview-drag")
                                    }
                            )
                            .onChange(of: currentIndex, initial: false) { oldValue, newIndex in
                                if playbackInteractionActive.wrappedValue {
                                    pendingSelectionIndex = newIndex
#if DEBUG
                                    print("🧪 PlayerSwap deferred reason=interaction index=\(newIndex)")
#endif
                                } else {
                                    // PRESERVED: Media swipe handling for both photos and videos
                                    handleMediaSwipe(from: oldValue, to: newIndex)
                                    previousIndex = oldValue
                                    prefetchNeighbors(for: newIndex)
                                }
                                externalIndexBinding?.wrappedValue = newIndex
                                print("🔄 SwipeableMediaPlayer: Switched to media \(newIndex + 1) of \(mediaPlayerData.count)")
                            }
                            .onChange(of: externalIndexBinding?.wrappedValue, initial: false) { _, newValue in
                                guard let newValue,
                                      newValue != currentIndex,
                                      !mediaPlayerData.isEmpty else { return }
                                let clamped = min(max(0, newValue), mediaPlayerData.count - 1)
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    currentIndex = clamped
                                }
                            }
                            .onAppear {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    ensureCurrentMediaIsReady()
                                }
                            }
                        } else {
                            errorView
                        }
                    }
                },
                overlay: {
                    EmptyView()
                }
            )
            .simultaneousGesture(
                {
                    let pullGesture = DragGesture(minimumDistance: 50)
                        .onChanged { value in
                            if value.translation.height > 0 && abs(value.translation.height) > abs(value.translation.width) {
                                isDragging = true
                                dragOffset = value.translation.height
                                backgroundOpacity = min(0.8, dragOffset / 300)
                            }
                        }
                        .onEnded { value in
                            isDragging = false
                            
                            if value.translation.height > 120 {
                                withAnimation(.easeOut(duration: 0.35)) {
                                    dragOffset = geometry.size.height
                                    backgroundOpacity = 1.0
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    shouldDismiss = true
                                }
                            } else {
                                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                    dragOffset = 0
                                    backgroundOpacity = 0
                                }
                            }
                        }

                    // When zoomed, use a no-op drag to swallow pulls; when not zoomed, use the real pull-to-dismiss.
                    return isZoomedIn
                    ? AnyGesture(DragGesture(minimumDistance: .infinity))
                    : AnyGesture(pullGesture)
                }()
            )
            .offset(y: dragOffset)
            .scaleEffect(isDragging ? max(0.85, 1 - (dragOffset / 1200)) : 1)
        }
        .onChange(of: shouldDismiss, initial: false) { _, dismiss in
            if dismiss {
                // PRESERVED: Pause all videos before dismissing
                pauseAllVideos()
                onDismiss()
            }
        }
        .onAppear {
            setupMediaPlayerData()
        }
        .onChange(of: takes.map(\.id), initial: false) { _, _ in
            refreshMediaForContextChange()
        }
        .onDisappear {
            // PRESERVED: Cleanup - pause all videos when view disappears
            pauseAllVideos()
            interactionEndWorkItem?.cancel()
            if playbackInteractionActive.wrappedValue {
                playbackInteractionActive.wrappedValue = false
#if DEBUG
                print("🧪 PlaybackInteraction end source=disappear")
#endif
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("STSZoomScaleChanged"))) { note in
            if let scale = note.userInfo?["scale"] as? CGFloat {
                isZoomedIn = scale > 1.01
            }
        }
        .ratingEducationToastHost()
        .stsSupportedOrientations(.all, label: "SwipeableMediaPlayerView")
    }

    private func refreshMediaForContextChange() {
        pauseAllVideos()
        videoPlayers.removeAll()
        let clampedIndex = min(currentIndex, max(0, takes.count - 1))
        currentIndex = clampedIndex
        previousIndex = clampedIndex
        setupMediaPlayerData()
    }
    
    // ENHANCED: Media-aware readiness check
    private func ensureCurrentMediaIsReady() {
        let currentMediaData = mediaPlayerData[currentIndex]
        
        if currentMediaData.isPhoto {
            print("📸 Current photo (\(currentIndex + 1)) ready for display")
        } else if let currentPlayer = videoPlayers[currentIndex] {
            currentPlayer.isCurrentlyVisible = true
            print("🎬 Current video (\(currentIndex + 1)) ready - waiting for user to play")
        }
    }
    
    private func beginPlaybackInteraction(source: String) {
        interactionEndWorkItem?.cancel()
        guard !playbackInteractionActive.wrappedValue else { return }
        if let playerVC = videoPlayers[currentIndex],
           let player = playerVC.player,
           player.timeControlStatus == .playing {
            wasPlayingBeforeDrag = true
            playerVC.pauseVideo()
        } else {
            wasPlayingBeforeDrag = false
        }
        playbackInteractionActive.wrappedValue = true
#if DEBUG
        print("🧪 PlaybackInteraction begin source=\(source)")
#endif
    }

    private func endPlaybackInteractionDebounced(source: String) {
        interactionEndWorkItem?.cancel()
        let workItem = DispatchWorkItem {
            guard playbackInteractionActive.wrappedValue else { return }
            playbackInteractionActive.wrappedValue = false
#if DEBUG
            print("🧪 PlayerSwap commit reason=interactionEnded pending=\(pendingSelectionIndex?.description ?? "nil")")
#endif
            if let pending = pendingSelectionIndex {
                handleMediaSwipe(from: previousIndex, to: pending)
                previousIndex = pending
                prefetchNeighbors(for: pending)
                pendingSelectionIndex = nil
            }
            if wasPlayingBeforeDrag,
               mediaPlayerData.indices.contains(currentIndex),
               !mediaPlayerData[currentIndex].isPhoto,
               let playerVC = videoPlayers[currentIndex] {
                playerVC.resumeVideo()
            }
#if DEBUG
            print("🧪 PlaybackInteraction end source=\(source)")
#endif
        }
        interactionEndWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: workItem)
    }
    
    // ENHANCED: Handle media swipe with support for both photos and videos
    private func handleMediaSwipe(from oldIndex: Int, to newIndex: Int) {
        let oldMediaData = mediaPlayerData[oldIndex]
        let newMediaData = mediaPlayerData[newIndex]
#if DEBUG
        let swipeTime = CFAbsoluteTimeGetCurrent()
        let fileName = newMediaData.unifiedTake.fileName
        print(String(format: "🧪 SwipeSelection index=%d file=%@ t=%.3f", newIndex, fileName, swipeTime))
        SwipeTimingTracker.shared.recordSwipe(takeID: newMediaData.take.id, fileName: fileName, time: swipeTime)
#endif
        
        // Handle previous media cleanup
        if !oldMediaData.isPhoto {
            // Pause the previous video immediately
            if let previousPlayer = videoPlayers[oldIndex] {
                previousPlayer.pauseVideo()
                previousPlayer.isCurrentlyVisible = false
            }
        }
        
        // Pause all videos except the new one (if it's a video)
        if !newMediaData.isPhoto {
            pauseAllVideosExcept(newIndex)
            updatePlayerVisibility(for: newIndex)
        }
        
        // Refresh overlay positioning for videos
        if !newMediaData.isPhoto, let newPlayer = videoPlayers[newIndex] {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                refreshOverlayPositioning(for: newPlayer)
            }
        }
        
        let mediaType = newMediaData.isPhoto ? "photo" : "video"
        let effectiveRating = SessionManager.shared.effectiveRating(for: newMediaData.take) ?? newMediaData.take.rating
        print("🔄 Media swipe: switched to \(mediaType) \(newIndex + 1) of \(mediaPlayerData.count) with rating \(effectiveRating.rawValue)")
    }

    private func prefetchNeighbors(for index: Int) {
        guard mediaPlayerData.indices.contains(index) else { return }
        let neighborIndices = [index - 1, index + 1].filter { mediaPlayerData.indices.contains($0) }
        for neighbor in neighborIndices {
            let neighborData = mediaPlayerData[neighbor]
            guard !neighborData.isPhoto else { continue }
            Task {
                await PlayerItemPrefetchCache.shared.prefetch(take: neighborData.take)
            }
        }
    }
    
    // PRESERVED: Video player management methods
    private func updatePlayerVisibility(for index: Int) {
        for (playerIndex, player) in videoPlayers {
            let shouldBeVisible = (playerIndex == index)
            player.isCurrentlyVisible = shouldBeVisible
        }
        
        print("📱 Updated video visibility: video \(index + 1) is now visible, ready for user control")
    }
    
    private func pauseAllVideosExcept(_ exceptIndex: Int) {
        for (index, player) in videoPlayers {
            if index != exceptIndex {
                player.pauseVideo()
                player.isCurrentlyVisible = false
            }
        }
    }
    
    private func pauseAllVideos() {
        for (_, player) in videoPlayers {
            player.pauseVideo()
            player.isCurrentlyVisible = false
        }
        print("⏹️ Paused all videos in SwipeableMediaPlayer")
    }
    
    private func refreshOverlayPositioning(for playerViewController: EnhancedAVPlayerViewController) {
        guard ratingsOverlayMode == .uikit else { return }
        func apply(retryCount: Int) {
            guard let overlayView = playerViewController.contentOverlayView else { return }

            overlayView.setNeedsLayout()
            if overlayView.bounds.height < 1 || overlayView.safeAreaInsets == .zero {
                if retryCount > 0 {
                    DispatchQueue.main.async {
                        apply(retryCount: retryCount - 1)
                    }
                }
                return
            }

            playerViewController.coordinator?.updateRatingsVerticalPlacement(
                isLandscape: playerViewController.view.bounds.width > playerViewController.view.bounds.height,
                reason: "takeChanged",
                playerView: playerViewController.view,
                overlayView: overlayView
            )

            for subview in overlayView.subviews {
                subview.layer.zPosition = 1000
            }

            print("🔄 Refreshed overlay positioning for stable display")
        }

        DispatchQueue.main.async {
            apply(retryCount: 1)
        }
    }
    
    // MARK: - Setup Methods
    
    private func setupMediaPlayerData() {
        isLoading = true
        
        Task { @MainActor in
            var playerDataArray: [MediaPlayerDisplayData] = []
            
            for take in takes {
                let stableTakeNumber = TakeDisplayFormatter.ordinal(for: take, in: currentSession)
                let unifiedTake = UnifiedTake(
                    from: take,
                    projectID: currentProject.id,
                    sessionID: currentSession.id,
                    fileName: URL(fileURLWithPath: take.filePath).lastPathComponent,
                    takeNumber: stableTakeNumber
                )
                
                let displayData = MediaPlayerDisplayData(
                    take: take,
                    unifiedTake: unifiedTake,
                    takeNumber: stableTakeNumber,
                    totalTakes: takes.count, // Total takes in current context
                    displayLabel: TakeDisplayFormatter.label(for: take, in: currentSession),
                    isSmartFillVariant: take.isSmartFillVariant
                )
                
                playerDataArray.append(displayData)
            }
            
            mediaPlayerData = playerDataArray
            if !playerDataArray.isEmpty {
                let clampedIndex = min(max(0, currentIndex), playerDataArray.count - 1)
                if clampedIndex != currentIndex {
                    currentIndex = clampedIndex
                }
                previousIndex = clampedIndex
                prefetchNeighbors(for: clampedIndex)
            } else {
                currentIndex = 0
                previousIndex = 0
            }
            isLoading = false
            
            let photoCount = playerDataArray.filter { $0.isPhoto }.count
            let videoCount = playerDataArray.count - photoCount
            print("✅ SwipeableMediaPlayer: Loaded \(videoCount) contextual videos and \(photoCount) photos, starting at index \(currentIndex)")
        }
    }
    
    // MARK: - Action Handlers
    
    private func handleRatingChange(_ newRating: TakeRating, for take: ProjectTake) {
        print("⭐ SwipeableMediaPlayer: Rating changed to \(newRating.rawValue) for \(URL(fileURLWithPath: take.filePath).lastPathComponent)")
        onTakeAction(.setRating(newRating), take)
    }
    
    private func handleShare(_ take: ProjectTake) {
        print("📤 SwipeableMediaPlayer: Sharing \(URL(fileURLWithPath: take.filePath).lastPathComponent)")
        onTakeAction(.share, take)
    }
    
    // MARK: - UI Components
    
    @ViewBuilder
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(.white)
            
            Text("Loading media...")
                .font(.headline)
                .foregroundColor(.white)
            
            Text("\(takes.count) item\(takes.count == 1 ? "" : "s")")
                .font(.caption)
                .foregroundColor(.gray)
        }
    }
    
    @ViewBuilder
    private var errorView: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.red)
            
            Text("No media to display")
                .font(.headline)
                .foregroundColor(.white)
            
            Button("Close") {
                shouldDismiss = true
            }
            .font(.headline)
            .foregroundColor(.white)
            .padding()
            .background(Color.blue, in: RoundedRectangle(cornerRadius: 12))
        }
    }
}

// MARK: - Unified Media Content View

struct UnifiedMediaContentView: View {
    let mediaData: MediaPlayerDisplayData
    let index: Int
    let onDismiss: () -> Void
    let onRatingChange: (TakeRating) -> Void
    let onShare: () -> Void
    let onVideoPlayerCreated: (EnhancedAVPlayerViewController) -> Void
    let manageAudioSession: Bool
    let showsTitleOverlay: Bool
    let ratingsOverlayMode: RatingsOverlayMode
    
    var body: some View {
        ZStack {
            Color.black
            
            if mediaData.isPhoto {
                // ENHANCED: Photo display with zoom and swipe compatibility
                UnifiedPhotoDisplayView(
                    mediaData: mediaData,
                    onRatingChange: onRatingChange,
                    onShare: onShare,
                    showsTitleOverlay: showsTitleOverlay,
                    ratingsOverlayMode: ratingsOverlayMode
                )
            } else {
                // PRESERVED: Video display using existing video player
                CustomAVPlayerViewContent(
                    videoData: VideoPlayerDisplayData(
                        take: mediaData.take,
                        unifiedTake: mediaData.unifiedTake,
                        takeNumber: mediaData.takeNumber,
                        totalTakes: mediaData.totalTakes,
                        displayLabel: mediaData.displayLabel,
                        isSmartFillVariant: mediaData.isSmartFillVariant
                    ),
                    index: index,
                    onDismiss: onDismiss,
                    onRatingChange: onRatingChange,
                    onShare: onShare,
                    onPlayerCreated: onVideoPlayerCreated,
                    manageAudioSession: manageAudioSession,
                    showsTitleOverlay: showsTitleOverlay,
                    ratingsOverlayMode: ratingsOverlayMode,
                    onEditorRequest: nil,  // PHASE 1: Add editor request parameter (no editor for media player currently)
                    onSmartFillTap: nil,
                    refreshTrigger: 0,  // 🚨 SMARTFILL DATA REFRESH FIX: Add missing refreshTrigger parameter (not used for media player)
                    enableVideoZoom: true
                )
            }
        }
    }
}

// MARK: - Unified Photo Display View - SIMPLIFIED FOR SWIPE-ONLY INTERACTION

struct UnifiedPhotoDisplayView: View {
    let mediaData: MediaPlayerDisplayData
    let onRatingChange: (TakeRating) -> Void
    let onShare: () -> Void
    let showsTitleOverlay: Bool
    let ratingsOverlayMode: RatingsOverlayMode
    
    @State private var showOverlays = true
    
    // CRITICAL FIX: Add local state for immediate visual feedback
    @State private var currentRating: TakeRating
    
    // ORIENTATION FIX: Add orientation detection state
    @State private var currentOrientation = UIDevice.current.orientation
    @State private var isLandscape = UIDevice.current.orientation.isLandscape
    
    // 60FPS PERFORMANCE: Optimized image loading state
    @State private var optimizedImage: UIImage?
    @State private var isImageLoading = true
    @State private var lastZoomScale: CGFloat = 1.0

    // MARK: - Rating UI constants (match video overlay)
    private let ratingButtonSize: CGFloat = 46
    private let ratingIconPointSize: CGFloat = 20
    private let ratingStackSpacing: CGFloat = 14
    
    // CRITICAL FIX: Initialize with current rating for immediate visual updates
    init(
        mediaData: MediaPlayerDisplayData,
        onRatingChange: @escaping (TakeRating) -> Void,
        onShare: @escaping () -> Void,
        showsTitleOverlay: Bool = true,
        ratingsOverlayMode: RatingsOverlayMode
    ) {
        self.mediaData = mediaData
        self.onRatingChange = onRatingChange
        self.onShare = onShare
        self.showsTitleOverlay = showsTitleOverlay
        self.ratingsOverlayMode = ratingsOverlayMode
        self._currentRating = State(initialValue: SessionManager.shared.effectiveRating(for: mediaData.take) ?? mediaData.take.rating)
    }
    
    var body: some View {
        ZStack {
            // 60FPS PERFORMANCE: Optimized photo display with enterprise caching - SWIPE ONLY
            Group {
                if let image = optimizedImage {
                    ZoomableImageView(
                        image: image,
                        minScale: 1.0,
                        maxScale: 4.0,
                        doubleTapScale: 2.5,
                        onZoomScaleChanged: { scale in
                            lastZoomScale = scale
                            NotificationCenter.default.post(
                                name: Notification.Name("STSZoomScaleChanged"),
                                object: nil,
                                userInfo: ["scale": scale]
                            )
                        }
                    )
                    .ignoresSafeArea()
                    .transition(.opacity.animation(.easeInOut(duration: 0.3)))
                    .onTapGesture {
                        let impact = UIImpactFeedbackGenerator(style: .light)
                        impact.impactOccurred()
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showOverlays.toggle()
                        }
                    }
                } else {
                    // 60FPS PERFORMANCE: Optimized loading placeholder
                    photoLoadingPlaceholder
                        .transition(.opacity.animation(.easeInOut(duration: 0.2)))
                }
            }
            
            // CRITICAL FIX: Simplified overlay structure with proper hit testing
            if showOverlays && !isImageLoading && showsTitleOverlay {
                // Top overlay: centered title/subtitle to mirror video layout
                VStack {
                    VStack(alignment: .center, spacing: 4) {
                        Text(formatPhotoTitle())
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.8), radius: 3, x: 0, y: 1)
                        
                        Text(formatPhotoSubtitle())
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.9))
                            .shadow(color: .black.opacity(0.8), radius: 2, x: 0, y: 1)
                    }
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.black.opacity(0.5))
                    )
                    .padding(.top, 20)
                    Spacer()
                }
                .allowsHitTesting(false) // CRITICAL: Don't intercept touches for title overlay
                .transition(.opacity.animation(.easeInOut(duration: 0.3)))
            }
        }
        .overlay(alignment: .trailing) {
            if showOverlays && !isImageLoading && shouldShowRatingsOverlay {
                ratingButtonsOverlay
                    .padding(.top, 20)
                    .transition(.opacity.animation(.easeInOut(duration: 0.3)))
            }
        }
        // CRITICAL FIX: Listen for external rating changes (from other views)
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("STSTakeRatingUpdated"))) { notification in
            if let takeID = notification.userInfo?["takeID"] as? UUID,
               takeID == mediaData.take.id,
               let ratingRawValue = notification.userInfo?["rating"] as? String,
               let newRating = TakeRating(rawValue: ratingRawValue) {
                
                withAnimation(.easeInOut(duration: 0.2)) {
                    currentRating = newRating
                }
                print("📸 Photo player: External rating update received - \(newRating.rawValue)")
            }
        }
        // ORIENTATION FIX: Listen for orientation changes with 60fps smooth transitions
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
            let newOrientation = UIDevice.current.orientation
            
            // Only update for valid orientations
            guard newOrientation.isValidInterfaceOrientation else { return }
            
            // 60FPS PERFORMANCE: Smooth orientation transition with enterprise-grade curve
            withAnimation(.interactiveSpring(response: 0.35, dampingFraction: 0.85, blendDuration: 0.1)) {
                currentOrientation = newOrientation
                isLandscape = newOrientation.isLandscape
            }
            
            print("🔄 Photo orientation changed to: \(newOrientation.description)")
        }
        .onAppear {
            // Initialize orientation state and load image
            let deviceOrientation = UIDevice.current.orientation
            if deviceOrientation.isValidInterfaceOrientation {
                currentOrientation = deviceOrientation
                isLandscape = deviceOrientation.isLandscape
            }
            
            // CRITICAL FIX: Sync local rating state with media data
            currentRating = SessionManager.shared.effectiveRating(for: mediaData.take) ?? mediaData.take.rating
            
            // 60FPS PERFORMANCE: Async image loading
            Task {
                await loadOptimizedImage()
            }
            
            print("📸 Photo viewer appeared with rating: \(currentRating.rawValue) - SWIPE ONLY")
        }
        .task {
            // 60FPS PERFORMANCE: Preload adjacent images for smoother swiping
            await preloadAdjacentImages()
        }
    }

    private var shouldShowRatingsOverlay: Bool {
        ratingsOverlayMode != .swiftUIChromeAnchored
    }
    
    // CRITICAL FIX: Dedicated rating buttons overlay with localized hit testing only on buttons
    @ViewBuilder
    private var ratingButtonsOverlay: some View {
        VStack(spacing: ratingStackSpacing) {
            enhancedRatingButton(.finalSelect, "star.fill", .yellow)
            enhancedRatingButton(.option, "checkmark.circle.fill", .green)
            enhancedRatingButton(.unrated, "circle", .gray)
            enhancedRatingButton(.rejected, "xmark.circle.fill", .red)
        }
        .frame(width: ratingContainerSize.width)
        .padding(.trailing, 20)
        .padding(.vertical, 20)
        .background(Color.clear)
        .allowsHitTesting(true)
    }

    private var ratingContainerSize: CGSize {
        let contentHeight = (ratingButtonSize * 4) + (ratingStackSpacing * 3)
        let paddedHeight = contentHeight + 40
        return CGSize(width: 60, height: paddedHeight)
    }

    // CRITICAL FIX: Enhanced rating button with guaranteed touch detection AND immediate visual feedback
    @ViewBuilder
    private func enhancedRatingButton(_ rating: TakeRating, _ iconName: String, _ color: Color) -> some View {
        Button(action: {
            // ENHANCED: Add haptic feedback for better user experience
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()
            
            // CRITICAL FIX: Update local state immediately for instant visual feedback
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                currentRating = rating
            }
            
            print("📸 Photo rating button tapped: \(rating.rawValue) - immediate visual update")
            
            // Then call the repository update
            onRatingChange(rating)
        }) {
            ZStack {
                // CRITICAL FIX: Larger hit area for better touch detection
                Circle()
                    .fill(Color.clear)
                    .frame(width: ratingButtonSize + 20, height: ratingButtonSize + 20)
                
                // Visual button - NOW USES LOCAL STATE for immediate updates
                Image(systemName: iconName)
                    .font(.system(size: ratingIconPointSize, weight: .medium))
                    .foregroundColor(currentRating == rating ? color : Color.white.opacity(0.9))
                    .frame(width: ratingButtonSize, height: ratingButtonSize)
                    .background(
                        Circle()
                            .fill(
                                currentRating == rating
                                    ? color.opacity(0.6)
                                    : Color.black.opacity(0.8)
                            )
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.3), lineWidth: 2)
                            )
                    )
                    .shadow(color: .black.opacity(0.9), radius: 8, x: 0, y: 4)
            }
        }
        .buttonStyle(PlainButtonStyle()) // CRITICAL: Use PlainButtonStyle to avoid interference
        .scaleEffect(currentRating == rating ? 1.2 : 1.0) // NOW USES LOCAL STATE
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentRating) // ANIMATE ON LOCAL STATE CHANGES
        .contentShape(Circle()) // CRITICAL: Define explicit content shape for hit testing
        .allowsHitTesting(true) // CRITICAL: Explicitly enable hit testing
    }

    // 60FPS PERFORMANCE: Optimized image loading with enterprise caching
    private func loadOptimizedImage() async {
        await MainActor.run {
            isImageLoading = true
        }
        
        let imagePath = mediaData.take.filePath
        let loadedImage = await OptimizedImageCache.shared.loadImage(for: imagePath)
        
        await MainActor.run {
            withAnimation(.easeInOut(duration: 0.3)) {
                optimizedImage = loadedImage
                isImageLoading = false
            }
        }
    }
    
    // 60FPS PERFORMANCE: Preload adjacent images for smooth swiping
    private func preloadAdjacentImages() async {
        guard mediaData.totalTakes > 1 else { return }
        
        // This would need access to adjacent media data - conceptual implementation
        // In a real implementation, this would be passed from the parent view
        print("📸 Preloading adjacent images for smooth swiping experience")
    }
    
    // 60FPS PERFORMANCE: Optimized loading placeholder with smooth animations
    @ViewBuilder
    private var photoLoadingPlaceholder: some View {
        VStack(spacing: 16) {
            // 60FPS PERFORMANCE: Smooth loading animation
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial.opacity(0.3))
                    .frame(width: 120, height: 80)
                
                Image(systemName: "photo")
                    .font(.system(size: 32))
                    .foregroundColor(.white.opacity(0.6))
                    .scaleEffect(isImageLoading ? 1.0 : 0.8)
                    .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isImageLoading)
            }
            
            Text("Loading photo...")
                .font(.headline)
                .foregroundColor(.white.opacity(0.8))
                .opacity(isImageLoading ? 1.0 : 0.6)
                .animation(.easeInOut(duration: 0.5), value: isImageLoading)
        }
        .padding()
    }
    
    // MARK: - Helper Methods for Photo Rating Display (optimized for 60fps)
    
    private func loadPhotoImage() -> UIImage? {
        // DEPRECATED: This method is replaced by optimized async loading
        // Kept for backward compatibility but not used in optimized path
        return optimizedImage
    }
    
    private func formatPhotoTitle() -> String {
        switch mediaData.take.takeType {
        case .slate:
            if let slateID = mediaData.take.slateID {
                return slateID // e.g., "SLATE1", "SLATE2"
            } else {
                return "Slate \(mediaData.takeNumber)"
            }
        case .pipSlate:
            if let slateID = mediaData.take.slateID {
                return "PiP \(slateID)"
            } else {
                return "PiP Slate \(mediaData.takeNumber)"
            }
        case .pipComponent:
            return "PiP Component"
        case .regular:
            if mediaData.unifiedTake.isKeyframePhoto {
                return "Keyframe Photo \(mediaData.takeNumber)"
            } else if mediaData.take.sceneNumber > 1 {
                return "Scene \(mediaData.take.sceneNumber) Photo \(mediaData.takeNumber)"
            } else {
                return "Photo \(mediaData.takeNumber)"
            }
        case .exported:
            return "Exported Photo"
        case .merged:
            return "Merged Photo"
        }
    }
    
    private func formatPhotoSubtitle() -> String {
        // CRITICAL FIX: Show context-aware subtitle for photos (matches video player format)
        switch mediaData.take.takeType {
        case .slate:
            return "\(mediaData.takeNumber) of \(mediaData.totalTakes) slate photos"
        case .pipSlate:
            return "\(mediaData.takeNumber) of \(mediaData.totalTakes) PiP slate photos"
        case .pipComponent:
            return "PiP Component"
        case .regular:
            if mediaData.unifiedTake.isKeyframePhoto {
                return "Keyframe photo \(mediaData.takeNumber) of \(mediaData.totalTakes)"
            } else if mediaData.take.sceneNumber > 1 {
                return "Photo \(mediaData.takeNumber) of \(mediaData.totalTakes) in Scene \(mediaData.take.sceneNumber)"
            } else {
                return "\(mediaData.takeNumber) of \(mediaData.totalTakes)"
            }
        case .exported, .merged:
            return "\(mediaData.takeNumber) of \(mediaData.totalTakes)"
        }
    }
}
