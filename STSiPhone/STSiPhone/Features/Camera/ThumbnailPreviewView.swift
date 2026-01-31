import SwiftUI
import AVFoundation
import Foundation

// MARK: - Thumbnail Cache

/// Lightweight in-memory cache so we don't regenerate thumbnails
/// for the same take on every view re-render / reload.
final class ThumbnailPreviewCache {
    static let shared = ThumbnailPreviewCache()

    private let cache = NSCache<NSString, UIImage>()

    func thumbnail(for key: String) -> UIImage? {
        cache.object(forKey: key as NSString)
    }

    func store(_ image: UIImage, for key: String) {
        cache.setObject(image, forKey: key as NSString)
    }
}

// MARK: - Thumbnail Work Limiter (Stage A)
actor ThumbnailWorkLimiter {
    static let shared = ThumbnailWorkLimiter(maxConcurrent: 3, interactiveMax: 1)

    private let normalMax: Int
    private let interactiveMax: Int
    private var currentMax: Int
    private var available: Int
    private var waiters: [CheckedContinuation<Void, Never>] = []
    private var activeCount: Int = 0
    private var totalStarted: Int = 0
    private var interactionActive: Bool = false

    init(maxConcurrent: Int, interactiveMax: Int) {
        self.normalMax = maxConcurrent
        self.interactiveMax = interactiveMax
        self.currentMax = maxConcurrent
        self.available = maxConcurrent
    }

    func acquire(fileName: String) async {
        if available > 0 {
            available -= 1
        } else {
            await withCheckedContinuation { continuation in
                waiters.append(continuation)
            }
        }
        activeCount += 1
        totalStarted += 1
#if DEBUG
        let mode = interactionActive ? "interactive" : "normal"
        print("🧪 ThumbLimiter acquire file=\(fileName) active=\(activeCount) total=\(totalStarted) mode=\(mode) max=\(currentMax)")
#endif
    }

    func release(fileName: String) {
        activeCount = max(0, activeCount - 1)
        if !waiters.isEmpty {
            let continuation = waiters.removeFirst()
            continuation.resume()
        } else {
            available = min(available + 1, currentMax)
        }
#if DEBUG
        let mode = interactionActive ? "interactive" : "normal"
        print("🧪 ThumbLimiter release file=\(fileName) active=\(activeCount) mode=\(mode) max=\(currentMax)")
#endif
    }

#if DEBUG
    func setInteractionActive(_ active: Bool) {
        guard active != interactionActive else { return }
        interactionActive = active
        currentMax = active ? interactiveMax : normalMax
        available = max(0, currentMax - activeCount)
        while available > 0 && !waiters.isEmpty {
            available -= 1
            let continuation = waiters.removeFirst()
            continuation.resume()
        }
        let mode = interactionActive ? "interactive" : "normal"
        print("🧪 ThumbLimiter mode=\(mode) max=\(currentMax) active=\(activeCount)")
    }
#else
    func setInteractionActive(_ active: Bool) {
        guard active != interactionActive else { return }
        interactionActive = active
        currentMax = active ? interactiveMax : normalMax
        available = max(0, currentMax - activeCount)
        while available > 0 && !waiters.isEmpty {
            available -= 1
            let continuation = waiters.removeFirst()
            continuation.resume()
        }
    }
#endif

#if DEBUG
    func snapshot() -> (active: Int, total: Int) {
        (activeCount, totalStarted)
    }
#endif
}

enum ThumbnailQuality {
    case small   // e.g. list rows (60×36)
    case large   // hero cards (full-width 16:9)
    
    var cacheSuffix: String {
        switch self {
        case .small: return "small"
        case .large: return "large"
        }
    }
}

enum ThumbnailFrameMode {
    case automatic   // existing behavior (isExportDeliverable / 10% rule)
    case intro       // force the intro / first frame of the clip
}

// MARK: - Native Camera-Style Thumbnail Preview
struct ThumbnailPreviewView: View {
    let unifiedTake: UnifiedTake
    let quality: ThumbnailQuality
    let frameMode: ThumbnailFrameMode
    
    @State private var thumbnail: UIImage?
    @State private var isLoading = false
    @State private var loadError: String?
    @State private var thumbnailTask: Task<Void, Never>?

#if DEBUG
    @MainActor private static var debugAppearCount: Int = 0

    @MainActor static func resetDebugAppearCount() {
        debugAppearCount = 0
    }

    @MainActor static func incrementDebugAppearCount() {
        debugAppearCount += 1
    }

    @MainActor static func currentDebugAppearCount() -> Int {
        debugAppearCount
    }
#endif

    // NEW: Stable cache key per take (uses UnifiedTake.id)
    private var cacheKey: String {
        unifiedTake.id.uuidString + "_\(quality.cacheSuffix)_\(frameModeKey)"
    }
    
    private var frameModeKey: String {
        switch frameMode {
        case .automatic: return "auto"
        case .intro:     return "intro"
        }
    }
    
    init(
        unifiedTake: UnifiedTake,
        quality: ThumbnailQuality = .small,
        frameMode: ThumbnailFrameMode = .automatic
    ) {
        self.unifiedTake = unifiedTake
        self.quality = quality
        self.frameMode = frameMode
    }
    
    var body: some View {
        ZStack {
            // Background
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black.opacity(0.8))
            
            if isLoading {
                // Loading state
                VStack(spacing: 2) {
                    ProgressView()
                        .scaleEffect(0.6)
                        .tint(.white)
                    
                    Text("Loading")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.7))
                }
            } else if let thumbnail = thumbnail {
                // Thumbnail image - Square aspect ratio
                Image(uiImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .clipped()
                    .cornerRadius(8)
                
                // Overlay info - SIMPLIFIED for square format
                VStack {
                    HStack {
                        Spacer()
                        
                        // Rating indicator (top right)
                        if unifiedTake.rating != .unrated {
                            Image(systemName: unifiedTake.rating.iconName)
                                .font(.caption2)
                                .foregroundColor(unifiedTake.rating.color)
                                .padding(2)
                                .background(Color.black.opacity(0.6), in: Circle())
                        }
                        
                        // NEW: SmartFill indicator badge if SmartFill version is being used
                        if unifiedTake.hasSmartFilledVersion {
                            Image(systemName: "rectangle.fill.badge.checkmark")
                                .font(.caption2)
                                .foregroundColor(.green)
                                .padding(2)
                                .background(Color.black.opacity(0.6), in: Circle())
                        }
                    }
                    
                    Spacer()
                    
                    HStack {
                        // Take number indicator
                        Text("\(unifiedTake.takeNumber)")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.black.opacity(0.6), in: Capsule())

                        // Uploaded badge for imported media
                        if unifiedTake.isUploaded {
                            Text("Uploaded")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.black.opacity(0.6), in: Capsule())
                                .fixedSize(horizontal: true, vertical: false)
                        }
                        
                        Spacer()
                    }
                }
                .padding(3)
                
            } else if loadError != nil {
                // Error state
                VStack(spacing: 2) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.caption2)
                        .foregroundColor(.yellow)
                    
                    Text("Error")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.7))
                }
            } else {
                // No thumbnail available
                VStack(spacing: 2) {
                    Image(systemName: unifiedTake.isPhoto ? "photo.slash" : "video.slash")
                        .font(.caption2)
                        .foregroundColor(.gray)
                    
                    Text("No Preview")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            
            // ENHANCED: Content type indicator - play button for video, camera icon for photo
            if thumbnail != nil {
                if unifiedTake.isPhoto {
                    // Photo indicator
                    Circle()
                        .fill(Color.white.opacity(0.8))
                        .frame(width: 16, height: 16)
                        .overlay(
                            Image(systemName: "camera.fill")
                                .font(.system(size: 6))
                                .foregroundColor(.black)
                        )
                        .shadow(color: .black.opacity(0.3), radius: 1)
                } else {
                    // Video play button
                    Circle()
                        .fill(Color.white.opacity(0.8))
                        .frame(width: 16, height: 16)
                        .overlay(
                            Image(systemName: "play.fill")
                                .font(.system(size: 6))
                                .foregroundColor(.black)
                        )
                        .shadow(color: .black.opacity(0.3), radius: 1)
                }
            }
        }
        .onAppear {
#if DEBUG
            ThumbnailPreviewView.incrementDebugAppearCount()
#endif
            loadThumbnail()
        }
        .onChange(of: unifiedTake.id, initial: false) { _, _ in
            cancelThumbnailTask(reason: "id-change")
            thumbnail = nil
            loadError = nil
            isLoading = false
            loadThumbnail()
        }
        .onDisappear {
            cancelThumbnailTask(reason: "disappear")
            isLoading = false
        }
    }
    
    // MARK: - Thumbnail loading with caching
    private func loadThumbnail() {
        // If we're already loading, don't start another task
        if isLoading {
            return
        }

        // If we already have a thumbnail in memory, nothing to do
        if thumbnail != nil, loadError == nil {
            return
        }

        // Reset error state
        loadError = nil

        // Try cache first
        if let cached = ThumbnailPreviewCache.shared.thumbnail(for: cacheKey) {
#if DEBUG
            print("🧪 ThumbCache hit file=\(unifiedTake.fileName) key=\(cacheKey)")
#endif
            thumbnail = cached
            isLoading = false
            return
        }
#if DEBUG
        print("🧪 ThumbCache miss file=\(unifiedTake.fileName) key=\(cacheKey)")
#endif

        // No cached image – start a fresh load
        isLoading = true
        let loadStart = CFAbsoluteTimeGetCurrent()
        let currentTake = unifiedTake
        let cacheKey = self.cacheKey
        let fileName = currentTake.fileName
        let isPhoto = currentTake.isPhoto

        print("⏳ ThumbnailPreviewView starting \(isPhoto ? "photo" : "video") thumbnail for \(fileName)")

        cancelThumbnailTask(reason: "restart")
        thumbnailTask = Task.detached(priority: .utility) {
            let waitStart = CFAbsoluteTimeGetCurrent()
            await ThumbnailWorkLimiter.shared.acquire(fileName: fileName)
            let waitElapsed = CFAbsoluteTimeGetCurrent() - waitStart
#if DEBUG
            if waitElapsed > 0.01 {
                print(String(format: "🧪 ThumbLimiter wait file=%@ %.3f s", fileName, waitElapsed))
            }
#endif
            var released = false
            func releaseIfNeeded() async {
                guard !released else { return }
                released = true
                await ThumbnailWorkLimiter.shared.release(fileName: fileName)
            }

            if Task.isCancelled {
                await releaseIfNeeded()
                return
            }
            do {
                let generatedThumbnail: UIImage

                // Preserve existing photo vs video behavior
                if isPhoto {
                    generatedThumbnail = try await ThumbnailPreviewView.generatePhotoThumbnail(for: currentTake, quality: quality)
                } else {
                    generatedThumbnail = try await ThumbnailPreviewView.generateVideoThumbnail(for: currentTake, quality: quality, frameMode: frameMode)
                }

                if Task.isCancelled {
                    await releaseIfNeeded()
                    return
                }

                // Store in cache immediately so future loads are instant
                ThumbnailPreviewCache.shared.store(generatedThumbnail, for: cacheKey)

                await MainActor.run {
                    self.thumbnail = generatedThumbnail
                    self.isLoading = false
                    self.loadError = nil
                }

                let elapsed = CFAbsoluteTimeGetCurrent() - loadStart
                print(String(
                    format: "✅ ThumbnailPreviewView finished %@ thumbnail in %.2f s (detached)",
                    fileName,
                    elapsed
                ))
                await releaseIfNeeded()
            } catch {
                let elapsed = CFAbsoluteTimeGetCurrent() - loadStart

                await MainActor.run {
                    self.isLoading = false
                    self.loadError = error.localizedDescription
                }

                print(String(
                    format: "❌ ThumbnailPreviewView failed %@ thumbnail in %.2f s (detached) – %@",
                    fileName,
                    elapsed,
                    error.localizedDescription
                ))
                print("❌ ThumbnailPreviewView: Failed to generate thumbnail for \(fileName) - \(error)")
                await releaseIfNeeded()
            }
        }
    }

    private func cancelThumbnailTask(reason: String) {
        guard let task = thumbnailTask else { return }
        task.cancel()
        thumbnailTask = nil
#if DEBUG
        print("🧪 ThumbnailPreviewView cancel reason=\(reason) file=\(unifiedTake.fileName)")
#endif
    }
    // NEW: Photo thumbnail generation
    private static func generatePhotoThumbnail(for take: UnifiedTake, quality: ThumbnailQuality) async throws -> UIImage {
        // Get photo URL
        let photoURL = try getContentURL(for: take)
        
        // Load photo data
        let photoData = try Data(contentsOf: photoURL)
        
        // Create UIImage from data
        guard let fullSizeImage = UIImage(data: photoData) else {
            throw ThumbnailError.thumbnailGenerationFailed("Could not create UIImage from photo data")
        }
        
        // Resize to thumbnail size (square)
        let basePoints: CGFloat
        switch quality {
        case .small:
            basePoints = 100        // existing behavior
        case .large:
            basePoints = 600        // more detail for hero cards
        }
        let thumbnailSize = CGSize(width: basePoints, height: basePoints)
        
        let renderer = UIGraphicsImageRenderer(size: thumbnailSize)
        let thumbnailImage = renderer.image { _ in
            fullSizeImage.draw(in: CGRect(origin: .zero, size: thumbnailSize))
        }
        
        return thumbnailImage
    }

    private static func generateVideoThumbnail(for take: UnifiedTake, quality: ThumbnailQuality, frameMode: ThumbnailFrameMode) async throws -> UIImage {
        let overallStart = CFAbsoluteTimeGetCurrent()
        
        // Get video URL using same strategy as UnifiedTakePlayerView
        let resolveStart = CFAbsoluteTimeGetCurrent()
        let videoURL = try getContentURL(for: take)
        let resolveDuration = CFAbsoluteTimeGetCurrent() - resolveStart
        let resolvedFile = videoURL.lastPathComponent
        print(String(format: "🗂️ ThumbnailPreview: Resolved video URL %@ in %.3f s", resolvedFile, resolveDuration))
        
        let asset = AVURLAsset(url: videoURL)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        
        // Configure for better thumbnail quality - UPDATED for square format
        imageGenerator.appliesPreferredTrackTransform = true
        let scale = UIScreen.main.scale
        let maxSide: CGFloat
        switch quality {
        case .small:
            maxSide = 240 * scale   // good enough for small list rows
        case .large:
            maxSide = 1280 * scale  // high-res for full-width card previews
        }
        imageGenerator.maximumSize = CGSize(width: maxSide, height: maxSide) // Square at 2x for retina

#if DEBUG
        if let track = try? await asset.loadTracks(withMediaType: .video).first {
            let naturalSize = (try? await track.load(.naturalSize)) ?? .zero
            let preferredTransform = (try? await track.load(.preferredTransform)) ?? .identity
            let renderSize = NormalizeOrientation.uprightExtent(
                naturalSize: naturalSize,
                preferred: preferredTransform
            )
            print("🧪 ThumbnailPreview video=\(resolvedFile) natural=\(naturalSize) transform=\(preferredTransform) render=\(renderSize) maxSide=\(maxSide)")
            if renderSize.width <= 0 || renderSize.height <= 0 {
                print("⚠️ ThumbnailPreview invalid render size \(renderSize) — skipping thumbnail")
                throw ThumbnailError.thumbnailGenerationFailed("invalid render size \(renderSize)")
            }
        } else {
            print("⚠️ ThumbnailPreview missing video track for \(resolvedFile)")
        }
#endif
        
        // Generate thumbnail. Choose frame based on frameMode.
        let thumbnailTime: CMTime
        var durationLoad: CFAbsoluteTime = 0

        switch frameMode {
        case .intro:
            thumbnailTime = CMTime(seconds: 0.03, preferredTimescale: 600) // tiny offset into intro frame
        case .automatic:
            if take.isExportDeliverable {
                thumbnailTime = .zero
            } else {
                let durationLoadStart = CFAbsoluteTimeGetCurrent()
                let duration = try await asset.load(.duration)
                durationLoad = CFAbsoluteTimeGetCurrent() - durationLoadStart
                thumbnailTime = CMTime(seconds: duration.seconds * 0.1, preferredTimescale: 600)
            }
        }
        
        imageGenerator.requestedTimeToleranceBefore = .zero
        imageGenerator.requestedTimeToleranceAfter = .zero

        let frameCaptureStart = CFAbsoluteTimeGetCurrent()
        let cgImage = try await imageGenerator.image(at: thumbnailTime).image
        let frameCaptureDuration = CFAbsoluteTimeGetCurrent() - frameCaptureStart
        let totalDuration = CFAbsoluteTimeGetCurrent() - overallStart
        
        print(
            String(
                format: "🎞️ ThumbnailPreview: Captured frame for %@ (durationLoad=%.3f s, frame=%.3f s, total=%.3f s)",
                resolvedFile,
                durationLoad,
                frameCaptureDuration,
                totalDuration
            )
        )
        return UIImage(cgImage: cgImage)
    }
    
    // ENHANCED: Unified content URL resolution for both photos and videos with SmartFill support
    private static func getContentURL(for take: UnifiedTake) throws -> URL {
        // CRITICAL FIX: First try to get SmartFill version if available
        let effectiveFileName: String
        
        // Check if this UnifiedTake has SmartFill version available
        if take.hasSmartFilledVersion {
            effectiveFileName = URL(fileURLWithPath: take.effectiveFilePath).lastPathComponent
            print("🎨 ThumbnailPreview: Using SmartFill version - \(effectiveFileName)")
        } else {
            effectiveFileName = take.fileName
        }
        
        // Strategy 1: Try VideoFileManager with effective filename (works for both videos and photos)
        do {
            let contentURL = try VideoFileManager.shared.getVideoURL(for: effectiveFileName)
            return contentURL
        } catch {
            // Continue to next strategy
        }
        
        // Strategy 2: Check Documents directory with effective filename
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let documentsURL = documentsPath.appendingPathComponent(effectiveFileName)
        
        if FileManager.default.fileExists(atPath: documentsURL.path) {
            return documentsURL
        }
        
        // Strategy 3: Use effective file path directly
        if take.hasSmartFilledVersion,
           let smartFillPath = take.smartFilledFilePath,
           !smartFillPath.isEmpty && smartFillPath != "/" {
            let smartFillURL = URL(fileURLWithPath: smartFillPath)
            if FileManager.default.fileExists(atPath: smartFillURL.path) {
                return smartFillURL
            }
        }
        
        // Strategy 4: Fallback to original file path if SmartFill not available or not found
        if !take.filePath.isEmpty && take.filePath != "/" {
            let originalURL = URL(fileURLWithPath: take.filePath)
            if FileManager.default.fileExists(atPath: originalURL.path) {
                print("🎬 ThumbnailPreview: Falling back to original file - \(originalURL.lastPathComponent)")
                return originalURL
            }
        }
        
        throw ThumbnailError.contentFileNotFound("No file found for \(take.fileName)")
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        guard duration > 0 && duration.isFinite else { return "0:00" }
        
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Thumbnail Error

enum ThumbnailError: LocalizedError {
    case contentFileNotFound(String)
    case thumbnailGenerationFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .contentFileNotFound(let fileName):
            return "Content file not found: \(fileName)"
        case .thumbnailGenerationFailed(let error):
            return "Failed to generate thumbnail: \(error)"
        }
    }
}

#Preview {
    let sampleTake = UnifiedTake(
        fileName: "Sample_Take1.mov",
        projectID: UUID(),
        sessionID: UUID(),
        filePath: "/sample/path/Sample_Take1.mov",
        duration: 45.5,
        fileSize: 1024000,
        cameraPosition: "back",
        sceneNumber: 1,
        takeNumber: 1,
        rating: .finalSelect,
        notes: nil
    )
    
    HStack {
        Button(action: {
            print("Thumbnail tapped in preview")
        }) {
            ThumbnailPreviewView(unifiedTake: sampleTake)
                .frame(width: 60, height: 80)
        }
        
        Spacer()
    }
    .padding()
    .background(.black)
}
