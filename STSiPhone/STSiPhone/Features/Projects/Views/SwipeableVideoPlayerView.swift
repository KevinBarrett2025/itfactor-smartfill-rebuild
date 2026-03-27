import SwiftUI
import AVFoundation
import AVKit
import CoreGraphics
import UIKit

// MARK: - Video Player Display Data

struct VideoPlayerDisplayData {
    let take: ProjectTake
    let unifiedTake: UnifiedTake
    let takeNumber: Int
    let totalTakes: Int
    let displayLabel: String
    let isSmartFillVariant: Bool
    let reopenContext: SmartFillReopenDestinationContext?
}

enum SmartFillPlayerEntryIntent: Equatable, CustomStringConvertible {
    case request(targetTake: ProjectTake)
    case edit(targetTake: ProjectTake)

    var targetTake: ProjectTake {
        switch self {
        case .request(let targetTake), .edit(let targetTake):
            return targetTake
        }
    }

    var description: String {
        switch self {
        case .request:
            return "request"
        case .edit:
            return "edit"
        }
    }
}

enum SmartFillPlayerEntryResolver {
    static func resolve(for take: ProjectTake, in session: ProjectSession) -> SmartFillPlayerEntryIntent? {
        if take.isSmartFillVariant {
            return .edit(targetTake: take)
        }

        if let companion = companion(for: take, in: session) {
            return .edit(targetTake: companion)
        }

        guard shouldRequestSmartFill(for: take) else {
            return nil
        }

        return .request(targetTake: take)
    }

    static func companion(for originalTake: ProjectTake, in session: ProjectSession) -> ProjectTake? {
        session.takes.first { candidate in
            guard candidate.id != originalTake.id else { return false }
            guard candidate.isSmartFillVariant else { return false }
            return candidate.smartFillOriginalID == originalTake.id
        }
    }

    static func shouldRequestSmartFill(for take: ProjectTake) -> Bool {
        guard !take.isSmartFillVariant else { return false }
        guard !isExportDeliverable(take) else { return false }
        if let orientation = take.capturedOrientation {
            return orientation == .portrait
        }
        return true
    }

    static func isExportDeliverable(_ take: ProjectTake) -> Bool {
        take.takeType == .merged || take.takeType == .exported
    }
}

// MARK: - Shared Utilities
extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

#if DEBUG
final class SwipeTimingTracker {
    static let shared = SwipeTimingTracker()
    private let lock = NSLock()
    private var swipeStartsByTake: [UUID: CFAbsoluteTime] = [:]

    func recordSwipe(takeID: UUID, fileName: String, time: CFAbsoluteTime) {
        lock.lock()
        swipeStartsByTake[takeID] = time
        lock.unlock()
        print(String(format: "🧪 SwipeTiming swipe start take=%@ file=%@ t=%.3f", takeID.uuidString, fileName, time))
    }

    func elapsedSinceSwipe(takeID: UUID, now: CFAbsoluteTime) -> Double? {
        lock.lock()
        let start = swipeStartsByTake[takeID]
        lock.unlock()
        guard let start else { return nil }
        return now - start
    }
}
#endif

@MainActor
private enum SwipeableTeardownVariant {
    case replaceThenDetach
    case detachThenReplaceDeferred
}

@MainActor
private let swipeableTeardownVariant: SwipeableTeardownVariant = .replaceThenDetach

@MainActor
private func safeSwipeableTeardown(
    _ player: AVPlayer?,
    host: AVPlayerViewController?,
    context: String,
    hostType: String,
    deferReplace: Bool,
    onTeardownStart: (() -> Void)? = nil,
    onTeardownEnd: (() -> Void)? = nil
) {
    let teardownID = UUID().uuidString
    onTeardownStart?()
    guard let player else {
#if DEBUG
        print("🧪 SwipeableTeardown[\(context)] id=\(teardownID) host=\(hostType) player=nil main=\(Thread.isMainThread)")
#endif
        onTeardownEnd?()
        return
    }

    let playerID = String(describing: ObjectIdentifier(player))
    let itemID = player.currentItem.map { String(describing: ObjectIdentifier($0)) } ?? "nil"
    let itemStatus = player.currentItem?.status.rawValue ?? -1
    let timeStatus = player.timeControlStatus.rawValue

#if DEBUG
    let hostWindowed = host?.view.window != nil
    let hostHidden = host?.view.isHidden ?? false
    let hostVisibleFlag = (host as? EnhancedAVPlayerViewController)?.isCurrentlyVisible
    print("🧪 SwipeableTeardown[\(context)] id=\(teardownID) host=\(hostType) player=\(playerID) item=\(itemID) status=\(itemStatus) time=\(timeStatus) defer=\(deferReplace) variant=\(swipeableTeardownVariant) windowed=\(hostWindowed) hidden=\(hostHidden) visibleFlag=\(hostVisibleFlag?.description ?? "nil") main=\(Thread.isMainThread)")
#endif

    player.pause()
#if DEBUG
    print("🧪 SwipeableTeardown[\(context)] id=\(teardownID) pause player=\(playerID)")
#endif

    switch swipeableTeardownVariant {
    case .replaceThenDetach:
        player.replaceCurrentItem(with: nil)
#if DEBUG
        print("🧪 SwipeableTeardown[\(context)] id=\(teardownID) replaceCurrentItem(nil) player=\(playerID) variant=replaceThenDetach")
#endif
        if let host {
            host.player = nil
#if DEBUG
            print("🧪 SwipeableTeardown[\(context)] id=\(teardownID) host.player=nil host=\(String(describing: type(of: host)))")
#endif
        }
        onTeardownEnd?()
    case .detachThenReplaceDeferred:
        if let host {
            host.player = nil
#if DEBUG
            print("🧪 SwipeableTeardown[\(context)] id=\(teardownID) host.player=nil host=\(String(describing: type(of: host)))")
#endif
        }
        if deferReplace {
            DispatchQueue.main.async {
                player.replaceCurrentItem(with: nil)
#if DEBUG
                print("🧪 SwipeableTeardown[\(context)] id=\(teardownID) deferred replaceCurrentItem(nil) player=\(playerID) variant=detachThenReplaceDeferred")
#endif
                onTeardownEnd?()
            }
        } else {
            player.replaceCurrentItem(with: nil)
#if DEBUG
            print("🧪 SwipeableTeardown[\(context)] id=\(teardownID) replaceCurrentItem(nil) player=\(playerID) variant=detachThenReplaceDeferred")
#endif
            onTeardownEnd?()
        }
    }
}

/// Enhanced video player that allows swiping between multiple takes with pull-to-dismiss
struct SwipeableVideoPlayerView: View {
    let takes: [ProjectTake]
    let currentSession: ProjectSession
    let currentProject: Project
    let initialIndex: Int
    let onDismiss: () -> Void
    let onTakeAction: (TakeAction, ProjectTake) -> Void
    
    // PHASE 1: NEW - Editor request callbacks for SmartFill + trim buttons
    let onEditorRequest: ((ProjectTake) -> Void)?
    let onSmartFillRequest: ((ProjectTake) -> Void)?
    let onSmartFillEditRequest: ((ProjectTake) -> Void)?
    let savedResultTakeID: UUID?
    let savedResultContext: SmartFillReopenDestinationContext?
    
    @State private var currentIndex: Int
    @State private var videoPlayerData: [VideoPlayerDisplayData] = []
    @State private var isLoading = true
    
    // CRITICAL FIX: Track video players for lifecycle management
    @State private var videoPlayers: [Int: EnhancedAVPlayerViewController] = [:]
    @State private var previousIndex: Int = 0
    
    // CRITICAL FIX: Use explicit dismiss control instead of @Environment
    @State private var shouldDismiss = false
    
    // ENHANCED: Pull-to-dismiss state with background reveal
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging = false
    @State private var backgroundOpacity: Double = 0
    
    // 🚨 SMARTFILL DATA REFRESH FIX: Add refresh trigger state
    @State private var refreshTrigger = 0
    @State private var ratingTapCount = 0
#if DEBUG
    @State private var audioDiagnosticsTokens: [NSObjectProtocol] = []
#endif
    
    let repository: ProjectsRepository

    // PHASE 1: UPDATED initializer with editor callback
    init(
        takes: [ProjectTake],
        session: ProjectSession,
        project: Project,
        initialIndex: Int = 0,
        onDismiss: @escaping () -> Void,
        onTakeAction: @escaping (TakeAction, ProjectTake) -> Void,
        repository: ProjectsRepository,
        onEditorRequest: ((ProjectTake) -> Void)? = nil,  // PHASE 1: NEW - Optional editor callback
        onSmartFillRequest: ((ProjectTake) -> Void)? = nil,
        onSmartFillEditRequest: ((ProjectTake) -> Void)? = nil,
        savedResultTakeID: UUID? = nil,
        savedResultContext: SmartFillReopenDestinationContext? = nil
    ) {
        self.takes = takes
        self.currentSession = session
        self.currentProject = project
        self.initialIndex = initialIndex
        self.onDismiss = onDismiss
        self.onTakeAction = onTakeAction
        self.repository = repository
        self.onEditorRequest = onEditorRequest  // PHASE 1: NEW - Store editor callback
        self.onSmartFillRequest = onSmartFillRequest
        self.onSmartFillEditRequest = onSmartFillEditRequest
        self.savedResultTakeID = savedResultTakeID
        self.savedResultContext = savedResultContext
        self._currentIndex = State(initialValue: initialIndex)
        self._previousIndex = State(initialValue: initialIndex)
    }
    
    var body: some View {
        GeometryReader { geometry in
            PlaybackSurface(
                background: {
                    // ENHANCED: Background that becomes visible during pull-to-dismiss
                    Color.clear
                        .background(.ultraThinMaterial)
                        .opacity(backgroundOpacity)
                },
                video: {
                    // Main video player content
                    ZStack {
                        Color.black
                        
                        if isLoading {
                            loadingView
                        } else if !videoPlayerData.isEmpty {
                            TabView(selection: $currentIndex) {
                                ForEach(Array(videoPlayerData.enumerated()), id: \.offset) { index, videoData in
                                    CustomAVPlayerViewContent(
                                        videoData: videoData,
                                        currentSession: currentSession,
                                        index: index,
                                        onDismiss: {
                                            shouldDismiss = true
                                        },
                                        onRatingChange: { newRating in
                                            handleRatingChange(newRating, for: videoData.take)
                                        },
                                        onShare: {
                                            handleShare(videoData.take)
                                        },
                                        onPlayerCreated: { playerController in
                                            // CRITICAL FIX: Track video players for lifecycle management
                                            videoPlayers[index] = playerController
                                            // CRITICAL FIX: Set initial visibility correctly
                                            playerController.isCurrentlyVisible = (index == currentIndex)
                                        },
                                        onEditorRequest: { take in
                                            handleStandardEditTap(for: take)
                                        },
                                        onSmartFillTap: { take in
                                            handleSmartFillButtonTap(for: take)
                                        },
                                        onCompareSourceTake: { sourceTakeID in
                                            handleCompareSourceTake(sourceTakeID)
                                        },
                                        refreshTrigger: refreshTrigger,  // 🚨 SMARTFILL DATA REFRESH FIX: Pass refresh trigger
                                        enableVideoZoom: true
                                    )
                                    .tag(index)
                                }
                            }
                            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                            .onChange(of: currentIndex, initial: false) { oldValue, newIndex in
                                // CRITICAL FIX: Pause previous video and manage playback
                                handleVideoSwipe(from: oldValue, to: newIndex)
                                previousIndex = oldValue
                                print("🔄 SwipeableVideoPlayer: Switched to video \(newIndex + 1) of \(videoPlayerData.count)")
                            }
                            // CRITICAL FIX: Ensure initial video starts playing when TabView appears
                            .onAppear {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    ensureCurrentVideoIsPlaying()
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
                DragGesture(minimumDistance: 50)
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
            )
            .offset(y: dragOffset)
            .scaleEffect(isDragging ? max(0.85, 1 - (dragOffset / 1200)) : 1)
        }
        .onChange(of: shouldDismiss, initial: false) { _, dismiss in
            if dismiss {
                // CRITICAL FIX: Pause all videos before dismissing
                pauseAllVideos()
                onDismiss()
            }
        }
        .onAppear {
#if DEBUG
            print("🧭 SwipeableVideoPlayerView.onAppear project=\(currentProject.id) session=\(currentSession.id) takes=\(takes.count)")
            audioDiagnosticsTokens = AudioSessionDiagnostics.installObservers(
                context: "SwipeableVideoPlayer",
                includeRouteChange: true
            )
            AudioSessionDiagnostics.snapshot("SwipeableVideoPlayer/appear/before")
#endif
            SessionManager.shared.configure(with: repository)
            SessionManager.shared.ensureReviewContext(
                project: currentProject,
                session: currentSession,
                takes: currentSession.takes,
                source: "SwipeableVideoPlayerView.onAppear"
            )
            setupVideoPlayerData()
#if DEBUG
            AudioSessionDiagnostics.snapshot("SwipeableVideoPlayer/appear/after")
#endif
        }
        .onDisappear {
#if DEBUG
            print("🧭 SwipeableVideoPlayerView.onDisappear project=\(currentProject.id) session=\(currentSession.id)")
            let metrics = SessionManager.shared.consumeRatingOverrideMetrics()
            print("🧪 SwipeableRatingSummary taps=\(ratingTapCount) overridesUsed=\(metrics.used) overridesCleared=\(metrics.cleared)")
            AudioSessionDiagnostics.snapshot("SwipeableVideoPlayer/disappear")
            AudioSessionDiagnostics.removeObservers(&audioDiagnosticsTokens)
#endif
            // CRITICAL FIX: Cleanup - pause all videos when view disappears
            pauseAllVideos()
        }
        // 🚨 SMARTFILL DATA REFRESH FIX: Listen for SmartFill completion notifications
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("STSSmartFillCompleted"))) { notification in
            handleSmartFillCompletion(notification)
        }
        .ratingEducationToastHost()
        .stsSupportedOrientations(.all, label: "SwipeableVideoPlayerView")
    }
    
    private func handleSmartFillButtonTap(for take: ProjectTake) {
        guard let intent = resolvedSmartFillButtonIntent(for: take) else {
            print("⚠️ SmartFill button tapped but no actionable target was resolved")
            return
        }

        let smartFillHandler: ((ProjectTake) -> Void)?
        switch intent {
        case .request:
            smartFillHandler = onSmartFillRequest
        case .edit:
            smartFillHandler = onSmartFillEditRequest
        }

        guard let smartFillHandler else {
            print("⚠️ SmartFill button tapped but no handler is wired for intent \(intent)")
            return
        }

        if case .edit(let targetTake) = intent {
            print("✨ SwipeableVideoPlayer: SmartFill edit requested for \(friendlyDisplayName(for: targetTake, in: currentSession))")
        }

        prepareForEditorTransition()
        smartFillHandler(intent.targetTake)
    }
    private func handleStandardEditTap(for take: ProjectTake) {
        handleEditorRequestWithRefresh(take)
    }

    private func handleCompareSourceTake(_ sourceTakeID: UUID) {
        guard let sourceIndex = videoPlayerData.firstIndex(where: { $0.take.id == sourceTakeID }) else {
            print("⚠️ SwipeableVideoPlayer: Could not resolve source take \(sourceTakeID) for compare")
            return
        }
        guard sourceIndex != currentIndex else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            currentIndex = sourceIndex
        }
        print("🔁 SwipeableVideoPlayer: Jumped to source take for compare at index \(sourceIndex + 1)")
    }
    
    private func shouldRequestSmartFill(for take: ProjectTake) -> Bool {
        SmartFillPlayerEntryResolver.shouldRequestSmartFill(for: take)
    }

    private func resolvedSmartFillButtonIntent(for take: ProjectTake) -> SmartFillPlayerEntryIntent? {
        SmartFillPlayerEntryResolver.resolve(for: take, in: currentSession)
    }

    private func existingSmartFillCompanion(for originalTake: ProjectTake) -> ProjectTake? {
        SmartFillPlayerEntryResolver.companion(for: originalTake, in: currentSession)
    }
    
    private func isSmartFillTake(_ take: ProjectTake) -> Bool {
        take.isSmartFillVariant
    }
    
    private func friendlyDisplayName(for take: ProjectTake, in session: ProjectSession) -> String {
        switch take.takeType {
        case .slate, .pipSlate:
            if let number = take.slateNumber, !number.isEmpty {
                let prefix = take.takeType == .pipSlate ? "PiP Slate" : "Slate"
                return "\(prefix) (\(number))"
            }
            return take.takeType == .pipSlate ? "PiP Slate" : "Slate"
        case .pipComponent:
            return "PiP Component"
        case .regular:
            let normalizedScene = take.sceneNumber > 0 ? take.sceneNumber : 1
            let storedOrdinal = take.takeNumber
            if storedOrdinal > 0 {
                if normalizedScene > 1 {
                    return "S\(normalizedScene)T\(storedOrdinal)"
                } else {
                    return "Take \(storedOrdinal)"
                }
            } else {
                let isMultiScene = normalizedScene > 1
                let matchingTakes = session.takes
                    .filter {
                        guard $0.takeType == .regular else { return false }
                        if isMultiScene {
                            return $0.sceneNumber == normalizedScene
                        } else {
                            return $0.sceneNumber <= 1
                        }
                    }
                    .sorted { $0.createdAt < $1.createdAt }
                let index = (matchingTakes.firstIndex(where: { $0.id == take.id }) ?? 0) + 1
                if isMultiScene {
                    return "S\(normalizedScene)T\(index)"
                } else {
                    return "Take \(index)"
                }
            }
        case .merged:
            return "Merged Video"
        case .exported:
            return "Exported Take"
        }
    }
    
    // 🚨 SMARTFILL DATA REFRESH FIX: Handle editor request with automatic refresh
    private func handleEditorRequestWithRefresh(_ take: ProjectTake) {
        print("✨ SwipeableVideoPlayer: Editor requested for \(URL(fileURLWithPath: take.filePath).lastPathComponent)")
        
        // Call the original editor request
        onEditorRequest?(take)
        
        // Note: We'll refresh when we receive the SmartFill completion notification
        print("🔄 SwipeableVideoPlayer: Will refresh data when SmartFill processing completes")
    }
    
    // 🚨 SMARTFILL DATA REFRESH FIX: Handle SmartFill completion notification
    private func handleSmartFillCompletion(_ notification: Notification) {
        // KEVIN'S STANDALONE APPROACH: SmartFill creates new video entries, not variants
        guard let originalTakeID = notification.userInfo?["originalTakeID"] as? UUID,
              let smartFillTakeID = notification.userInfo?["smartFillTakeID"] as? UUID,
              let approach = notification.userInfo?["approach"] as? String,
              approach == "standalone" else {
            print("ℹ️ SwipeableVideoPlayer: SmartFill notification not for standalone approach")
            return
        }
        
        print("🎉 KEVIN'S FIX: SmartFill created standalone video - new video entry added!")
        print("   📱 Original: \(originalTakeID)")
        print("   📺 SmartFill: \(smartFillTakeID)")
        
        // Check if this notification affects our current video set
        let affectsOurVideos = videoPlayerData.contains { $0.take.id == originalTakeID }
        
        guard affectsOurVideos else {
            print("ℹ️ SwipeableVideoPlayer: SmartFill completion for different take set, ignoring")
            return
        }
        
        print("🔄 KEVIN'S FIX: Refreshing video list to show new standalone SmartFill video")
        
        // The parent view (TakeReviewPage, etc.) will refresh and show both videos
        // We don't need complex refresh logic since they're now separate entries
        refreshVideoPlayerData()
    }
    
    // 🚨 SMARTFILL DATA REFRESH FIX: Refresh video player data from repository
    private func refreshVideoPlayerData() {
        Task { @MainActor in
            print("🔄 SwipeableVideoPlayer: Refreshing video data from repository")
            
            // Get fresh data from repository
            guard let updatedProject = repository.project(by: currentProject.id),
                  let updatedSession = updatedProject.sessions.first(where: { $0.id == currentSession.id }) else {
                print("❌ SwipeableVideoPlayer: Could not get updated project/session data")
                return
            }

            SessionManager.shared.ensureReviewContext(
                project: updatedProject,
                session: updatedSession,
                takes: updatedSession.takes,
                source: "SwipeableVideoPlayerView.refresh"
            )
            
            // Get updated takes matching our current take IDs
            let currentTakeIDs = videoPlayerData.map { $0.take.id }
            let updatedTakes = updatedSession.takes.filter { currentTakeIDs.contains($0.id) }
            
            // Rebuild video player data with fresh take data
            var newPlayerDataArray: [VideoPlayerDisplayData] = []
            
            for (index, takeID) in currentTakeIDs.enumerated() {
                guard let updatedTake = updatedTakes.first(where: { $0.id == takeID }) else {
                    print("⚠️ SwipeableVideoPlayer: Could not find updated take for ID \(takeID)")
                    continue
                }
                
                let stableTakeNumber = TakeDisplayFormatter.ordinal(for: updatedTake, in: updatedSession)
                let unifiedTake = UnifiedTake(
                    from: updatedTake,
                    projectID: updatedProject.id,
                    sessionID: updatedSession.id,
                    fileName: URL(fileURLWithPath: updatedTake.filePath).lastPathComponent,
                    takeNumber: stableTakeNumber
                )
                
                let displayData = VideoPlayerDisplayData(
                    take: updatedTake,  // 🚨 KEY FIX: Use fresh take data from repository
                    unifiedTake: unifiedTake,
                    takeNumber: stableTakeNumber,
                    totalTakes: updatedTakes.count,
                    displayLabel: TakeDisplayFormatter.label(for: updatedTake, in: updatedSession),
                    isSmartFillVariant: updatedTake.isSmartFillVariant,
                    reopenContext: updatedTake.id == savedResultTakeID ? savedResultContext : nil
                )
                
                newPlayerDataArray.append(displayData)
                
                // Log SmartFill status change
                let oldTake = videoPlayerData[safe: index]?.take
                let hadSmartFill = oldTake?.hasSmartFilledVersion ?? false
                let nowHasSmartFill = updatedTake.hasSmartFilledVersion
                
                if !hadSmartFill && nowHasSmartFill {
                    print("🎉 SwipeableVideoPlayer: Take \(updatedTake.id) now has SmartFill! 📱➡️📺")
                    print("   📁 SmartFill path: \(updatedTake.smartFilledFilePath ?? "nil")")
                }
            }
            
            // Update the data and trigger UI refresh
            videoPlayerData = newPlayerDataArray
            refreshTrigger += 1  // Trigger child view refresh
            
            // Clear video player cache to force recreation with new data
            videoPlayers.removeAll()
            
            print("✅ SwipeableVideoPlayer: Data refresh completed - \(newPlayerDataArray.count) videos updated")
            print("🎬 SmartFilled videos should now show correctly!")
        }
    }
    
    // CRITICAL FIX: Ensure current video is playing (fallback for initial load) - UPDATED: Don't auto-play
    private func ensureCurrentVideoIsPlaying() {
        if let currentPlayer = videoPlayers[currentIndex] {
            currentPlayer.isCurrentlyVisible = true
            print("🎬 Current video (\(currentIndex + 1)) ready - waiting for user to play")
        }
    }
    
    // CRITICAL FIX: Handle video swipe with proper playback management AND overlay stability
    private func handleVideoSwipe(from oldIndex: Int, to newIndex: Int) {
        // Pause the previous video immediately
        if let previousPlayer = videoPlayers[oldIndex] {
            previousPlayer.pauseVideo()
            previousPlayer.isCurrentlyVisible = false
#if DEBUG
            let oldPlayerID = previousPlayer.player.map { String(describing: ObjectIdentifier($0)) } ?? "nil"
            let oldItemID = previousPlayer.player?.currentItem.map { String(describing: ObjectIdentifier($0)) } ?? "nil"
            let oldStatus = previousPlayer.player?.currentItem?.status.rawValue ?? -1
            print("🧪 SwipeableTransition[swipe] from=\(oldIndex) to=\(newIndex) oldPlayer=\(oldPlayerID) oldItem=\(oldItemID) status=\(oldStatus) main=\(Thread.isMainThread)")
#endif
        }
        
        // Pause all other videos to ensure clean state
        pauseAllVideosExcept(newIndex)
        
        // Update visibility for the new video
        updatePlayerVisibility(for: newIndex)
        
        // CRITICAL FIX: Ensure overlay positioning remains stable after swipe
        if let newPlayer = videoPlayers[newIndex] {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                guard newPlayer.player != nil, newPlayer.player?.currentItem != nil else {
#if DEBUG
                    let playerID = newPlayer.player.map { String(describing: ObjectIdentifier($0)) } ?? "nil"
                    let itemID = newPlayer.player?.currentItem.map { String(describing: ObjectIdentifier($0)) } ?? "nil"
                    print("🧪 SwipeableOverlayRefresh skipped player=\(playerID) item=\(itemID) main=\(Thread.isMainThread)")
#endif
                    return
                }
                // Force layout update to ensure overlays stay in correct position
                if let overlayView = newPlayer.contentOverlayView {
#if DEBUG
                    let newPlayerID = newPlayer.player.map { String(describing: ObjectIdentifier($0)) } ?? "nil"
                    print("🧪 SwipeableOverlayRefresh after swipe newPlayer=\(newPlayerID) main=\(Thread.isMainThread)")
#endif
                    overlayView.setNeedsLayout()
                    overlayView.layoutIfNeeded()
                    
                    // Ensure z-position is maintained
                    for subview in overlayView.subviews {
                        subview.layer.zPosition = 1000
                    }
                    print("🔄 Refreshed overlay positioning after video swipe")
                }
            }
        }
        
        print("🎬 Video swipe: paused video \(oldIndex + 1), now showing video \(newIndex + 1)")
    }
    
    // CRITICAL FIX: Update player visibility state - UPDATED: Don't auto-play
    private func updatePlayerVisibility(for index: Int) {
        for (playerIndex, player) in videoPlayers {
            let shouldBeVisible = (playerIndex == index)
            player.isCurrentlyVisible = shouldBeVisible
        }
        
        print("📱 Updated visibility: video \(index + 1) is now visible, ready for user control")
    }
    
    // CRITICAL FIX: Pause all videos except the specified index
    private func pauseAllVideosExcept(_ exceptIndex: Int) {
        for (index, player) in videoPlayers {
            if index != exceptIndex {
                player.pauseVideo()
                player.isCurrentlyVisible = false
            }
        }
    }
    
    // CRITICAL FIX: Pause all videos (for cleanup)
    private func pauseAllVideos() {
        for (_, player) in videoPlayers {
            player.pauseVideo()
            player.isCurrentlyVisible = false
        }
        print("⏹️ Paused all videos in SwipeableVideoPlayer")
    }
    
    // 🚨 CRITICAL FIX: Safe cleanup before opening editor to prevent AVPlayerItem reuse
    private func prepareForEditorTransition() {
        print("🧹 SwipeableVideoPlayer: Preparing for editor transition")
        
        // Pause all videos first
        pauseAllVideos()
        
        // Detach all player items to prevent reuse
        for (_, playerVC) in videoPlayers {
            let hostType = String(describing: type(of: playerVC))
            Task { @MainActor in
                safeSwipeableTeardown(
                    playerVC.player,
                    host: playerVC,
                    context: "editor-transition",
                    hostType: hostType,
                    deferReplace: false,
                    onTeardownStart: { playerVC.coordinator?.beginTeardown(reason: "editor-transition", playerVC: playerVC) },
                    onTeardownEnd: { playerVC.coordinator?.endTeardown(reason: "editor-transition") }
                )
            }
        }
        
        print("✅ SwipeableVideoPlayer: All player items safely detached for editor transition")
    }
    
    // MARK: - Setup Methods
    
    private func setupVideoPlayerData() {
        isLoading = true
        
        Task { @MainActor in
            var playerDataArray: [VideoPlayerDisplayData] = []
            
            for take in takes {
                let stableTakeNumber = TakeDisplayFormatter.ordinal(for: take, in: currentSession)
                let unifiedTake = UnifiedTake(
                    from: take,
                    projectID: currentProject.id,
                    sessionID: currentSession.id,
                    fileName: URL(fileURLWithPath: take.filePath).lastPathComponent,
                    takeNumber: stableTakeNumber
                )
                
                let displayData = VideoPlayerDisplayData(
                    take: take,
                    unifiedTake: unifiedTake,
                    takeNumber: stableTakeNumber,
                    totalTakes: takes.count, // Total takes in current context
                    displayLabel: TakeDisplayFormatter.label(for: take, in: currentSession),
                    isSmartFillVariant: take.isSmartFillVariant,
                    reopenContext: take.id == savedResultTakeID ? savedResultContext : nil
                )
                
                playerDataArray.append(displayData)
            }
            
            videoPlayerData = playerDataArray
            isLoading = false
            
            print("✅ SwipeableVideoPlayer: Loaded \(playerDataArray.count) contextual videos, starting at index \(currentIndex)")
        }
    }
    
    // MARK: - Action Handlers
    
    private func handleRatingChange(_ newRating: TakeRating, for take: ProjectTake) {
#if DEBUG
        print("🧪 RatingSource=SwipeableVideoPlayer session=\(currentSession.id) take=\(take.id) rating=\(newRating.rawValue)")
#endif
        print("⭐ SwipeableVideoPlayer: Rating changed to \(newRating.rawValue) for \(URL(fileURLWithPath: take.filePath).lastPathComponent)")
        ratingTapCount += 1
        onTakeAction(.setRating(newRating), take)
    }
    
    private func handleShare(_ take: ProjectTake) {
        print("📤 SwipeableVideoPlayer: Sharing \(URL(fileURLWithPath: take.filePath).lastPathComponent)")
        onTakeAction(.share, take)
    }
    
    // MARK: - UI Components
    
    @ViewBuilder
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(.white)
            
            Text("Loading videos...")
                .font(.headline)
                .foregroundColor(.white)
            
            Text("\(takes.count) take\(takes.count == 1 ? "" : "s")")
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
            
            Text("No videos to display")
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

// MARK: - Custom AVPlayer View Content

struct CustomAVPlayerViewContent: View {
    let videoData: VideoPlayerDisplayData
    let currentSession: ProjectSession
    let index: Int
    let onDismiss: () -> Void
    let onRatingChange: (TakeRating) -> Void
    let onShare: () -> Void
    let onPlayerCreated: (EnhancedAVPlayerViewController) -> Void
    let manageAudioSession: Bool
    let showsTitleOverlay: Bool
    let ratingsOverlayMode: RatingsOverlayMode
    
    // PHASE 1: NEW - Editor request callback
    let onEditorRequest: ((ProjectTake) -> Void)?
    let onSmartFillTap: ((ProjectTake) -> Void)?
    let onCompareSourceTake: ((UUID) -> Void)?
    
    // 🚨 SMARTFILL DATA REFRESH FIX: Add refresh trigger
    let refreshTrigger: Int
    let enableVideoZoom: Bool
    
    init(
        videoData: VideoPlayerDisplayData,
        currentSession: ProjectSession,
        index: Int,
        onDismiss: @escaping () -> Void,
        onRatingChange: @escaping (TakeRating) -> Void,
        onShare: @escaping () -> Void,
        onPlayerCreated: @escaping (EnhancedAVPlayerViewController) -> Void,
        manageAudioSession: Bool = true,
        showsTitleOverlay: Bool = true,
        ratingsOverlayMode: RatingsOverlayMode = .uikit,
        onEditorRequest: ((ProjectTake) -> Void)? = nil,
        onSmartFillTap: ((ProjectTake) -> Void)? = nil,
        onCompareSourceTake: ((UUID) -> Void)? = nil,
        refreshTrigger: Int,
        enableVideoZoom: Bool = false
    ) {
        self.videoData = videoData
        self.currentSession = currentSession
        self.index = index
        self.onDismiss = onDismiss
        self.onRatingChange = onRatingChange
        self.onShare = onShare
        self.onPlayerCreated = onPlayerCreated
        self.manageAudioSession = manageAudioSession
        self.showsTitleOverlay = showsTitleOverlay
        self.ratingsOverlayMode = ratingsOverlayMode
        self.onEditorRequest = onEditorRequest
        self.onSmartFillTap = onSmartFillTap
        self.onCompareSourceTake = onCompareSourceTake
        self.refreshTrigger = refreshTrigger
        self.enableVideoZoom = enableVideoZoom
    }
    
    var body: some View {
        CustomAVPlayerViewController(
            videoData: videoData,
            currentSession: currentSession,
            index: index,
            onRatingChange: onRatingChange,
            onShare: onShare,
            onPlayerCreated: onPlayerCreated,
            manageAudioSession: manageAudioSession,
            showsTitleOverlay: showsTitleOverlay,
            ratingsOverlayMode: ratingsOverlayMode,
            onEditorRequest: onEditorRequest,  // PHASE 1: NEW - Pass editor callback through
            onSmartFillTap: onSmartFillTap,
            onCompareSourceTake: onCompareSourceTake,
            refreshTrigger: refreshTrigger,  // 🚨 SMARTFILL DATA REFRESH FIX: Pass refresh trigger
            enableVideoZoom: enableVideoZoom
        )
    }
}

// MARK: - Custom AVPlayerViewController with Overlay Management

struct CustomAVPlayerViewController: UIViewControllerRepresentable {
    let videoData: VideoPlayerDisplayData
    let currentSession: ProjectSession
    let index: Int
    let onRatingChange: (TakeRating) -> Void
    let onShare: () -> Void
    let onPlayerCreated: (EnhancedAVPlayerViewController) -> Void
    let manageAudioSession: Bool
    let showsTitleOverlay: Bool
    let ratingsOverlayMode: RatingsOverlayMode
    @Environment(\.playbackSafeAreaInsets) private var playbackSafeAreaInsets
    @Environment(\.playbackOverlayTopComfort) private var overlayTopComfort
    @Environment(\.playbackInteractionActive) private var playbackInteractionActive
    
    // PHASE 1: NEW - Editor request callback
    let onEditorRequest: ((ProjectTake) -> Void)?
    let onSmartFillTap: ((ProjectTake) -> Void)?
    let onCompareSourceTake: ((UUID) -> Void)?
    
    // 🚨 SMARTFILL DATA REFRESH FIX: Add refresh trigger
    let refreshTrigger: Int
    let enableVideoZoom: Bool
    
    // MARK: - Coordinator
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject {
        let parent: CustomAVPlayerViewController
        weak var overlayRootView: UIView?
        weak var ratingButtonsView: UIView?
        private var timeControlStatusObservation: NSKeyValueObservation?
        private var didEndObserver: NSObjectProtocol?
        private var externalPlaybackObservation: NSKeyValueObservation?
        private var idleTimerToken: IdleTimerController.Token?
        private var isPlaying = false
        private var isExternalPlaybackActive = false
        private let ratingContainerSize = CGSize(width: 60, height: 280)
        private var ratingsCenterYConstraint: NSLayoutConstraint?
        // Minimal landscape clearance: shift ratings up but clamp to keep the top visible.
        private let landscapeRatingsVerticalOffset: CGFloat = -72
        private let ratingsTopMargin: CGFloat = 12
        
        // 🚨 SMARTFILL DATA REFRESH FIX: Track refresh trigger
        var lastRefreshTrigger: Int = -1
        var playbackObserver: NSKeyValueObservation?
        var areControlsVisible: Bool = true
        var priorCategory: AVAudioSession.Category?
        var priorMode: AVAudioSession.Mode?
        var priorOptions: AVAudioSession.CategoryOptions?
        var didCapturePriorAudioSession = false
        private var titleTopConstraint: NSLayoutConstraint?
        private let titleBaseTop: CGFloat = 20
        private var currentOverlayTopComfort: CGFloat = 0
        private var isTearingDown = false
        var isPlaybackInteracting: Bool = false
#if DEBUG
        private var itemStatusObservation: NSKeyValueObservation?
        private var itemLikelyToKeepUpObservation: NSKeyValueObservation?
        private var itemBufferEmptyObservation: NSKeyValueObservation?
        private var itemBufferFullObservation: NSKeyValueObservation?
        private var itemTimeRangesObservation: NSKeyValueObservation?
        private var lastItemAssignTime: CFAbsoluteTime = 0
        private var lastItemFileName: String = ""
        private var lastItemID: ObjectIdentifier?
        private var didLogReadyToPlay = false
        private var lastOverlaySuppressionLog = Date.distantPast
#else
        private var lastOverlaySuppressionLog = Date.distantPast
#endif
        
        init(_ parent: CustomAVPlayerViewController) {
            self.parent = parent
            super.init()
            // Initialize with current refresh trigger
            self.lastRefreshTrigger = parent.refreshTrigger
        }
        
        deinit {
            playbackObserver?.invalidate()
            timeControlStatusObservation?.invalidate()
            if let didEndObserver {
                NotificationCenter.default.removeObserver(didEndObserver)
            }
            externalPlaybackObservation?.invalidate()
#if DEBUG
            resetItemDiagnostics()
#endif
            Task { @MainActor [weak self] in
                self?.releaseIdleTimer()
            }
        }

#if DEBUG
        private func resetItemDiagnostics() {
            itemStatusObservation?.invalidate()
            itemLikelyToKeepUpObservation?.invalidate()
            itemBufferEmptyObservation?.invalidate()
            itemBufferFullObservation?.invalidate()
            itemTimeRangesObservation?.invalidate()
            itemStatusObservation = nil
            itemLikelyToKeepUpObservation = nil
            itemBufferEmptyObservation = nil
            itemBufferFullObservation = nil
            itemTimeRangesObservation = nil
            didLogReadyToPlay = false
            lastItemID = nil
            lastItemAssignTime = 0
            lastItemFileName = ""
        }

        func bindItemDiagnostics(item: AVPlayerItem, fileName: String, assignTime: CFAbsoluteTime) {
            resetItemDiagnostics()
            lastItemAssignTime = assignTime
            lastItemFileName = fileName
            lastItemID = ObjectIdentifier(item)
            let itemID = String(describing: ObjectIdentifier(item))
            print("🧪 PlayerItem assign file=\(fileName) item=\(itemID)")

            itemStatusObservation = item.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
                guard let self else { return }
                let elapsed = self.lastItemAssignTime > 0 ? CFAbsoluteTimeGetCurrent() - self.lastItemAssignTime : -1
                let status = item.status.rawValue
                print(String(format: "🧪 PlayerItem status file=%@ item=%@ status=%d elapsed=%.3f", self.lastItemFileName, itemID, status, elapsed))
                if item.status == .readyToPlay, !self.didLogReadyToPlay {
                    self.didLogReadyToPlay = true
                    print(String(format: "🧪 PlayerItem ready file=%@ item=%@ elapsed=%.3f", self.lastItemFileName, itemID, elapsed))
                    let now = CFAbsoluteTimeGetCurrent()
                    if let swipeElapsed = SwipeTimingTracker.shared.elapsedSinceSwipe(takeID: self.parent.videoData.take.id, now: now) {
                        print(String(format: "🧪 SwipeToReady take=%@ file=%@ elapsed=%.3f", self.parent.videoData.take.id.uuidString, self.lastItemFileName, swipeElapsed))
                    }
                }
            }

            itemLikelyToKeepUpObservation = item.observe(\.isPlaybackLikelyToKeepUp, options: [.initial, .new]) { [weak self] item, _ in
                guard let self else { return }
                let elapsed = self.lastItemAssignTime > 0 ? CFAbsoluteTimeGetCurrent() - self.lastItemAssignTime : -1
                print(String(format: "🧪 PlayerItem likelyToKeepUp file=%@ item=%@ value=%@ elapsed=%.3f", self.lastItemFileName, itemID, item.isPlaybackLikelyToKeepUp.description, elapsed))
            }

            itemBufferEmptyObservation = item.observe(\.isPlaybackBufferEmpty, options: [.initial, .new]) { [weak self] item, _ in
                guard let self else { return }
                let elapsed = self.lastItemAssignTime > 0 ? CFAbsoluteTimeGetCurrent() - self.lastItemAssignTime : -1
                print(String(format: "🧪 PlayerItem bufferEmpty file=%@ item=%@ value=%@ elapsed=%.3f", self.lastItemFileName, itemID, item.isPlaybackBufferEmpty.description, elapsed))
            }

            itemBufferFullObservation = item.observe(\.isPlaybackBufferFull, options: [.initial, .new]) { [weak self] item, _ in
                guard let self else { return }
                let elapsed = self.lastItemAssignTime > 0 ? CFAbsoluteTimeGetCurrent() - self.lastItemAssignTime : -1
                print(String(format: "🧪 PlayerItem bufferFull file=%@ item=%@ value=%@ elapsed=%.3f", self.lastItemFileName, itemID, item.isPlaybackBufferFull.description, elapsed))
            }

            itemTimeRangesObservation = item.observe(\.loadedTimeRanges, options: [.new]) { [weak self] item, _ in
                guard let self else { return }
                guard let range = item.loadedTimeRanges.first?.timeRangeValue else { return }
                let elapsed = self.lastItemAssignTime > 0 ? CFAbsoluteTimeGetCurrent() - self.lastItemAssignTime : -1
                let seconds = CMTimeGetSeconds(range.duration)
                print(String(format: "🧪 PlayerItem loadedRanges file=%@ item=%@ seconds=%.2f elapsed=%.3f", self.lastItemFileName, itemID, seconds, elapsed))
            }
        }
#endif

        private func shouldSuppressOverlayUpdates(playerVC: AVPlayerViewController?) -> Bool {
            if isTearingDown { return true }
            guard let playerVC else { return true }
            guard let player = playerVC.player else { return true }
            guard player.currentItem != nil else { return true }
            return false
        }

        func beginTeardown(reason: String, playerVC: AVPlayerViewController?) {
            isTearingDown = true
            setCustomOverlaysVisible(false)
#if DEBUG
            let playerID = playerVC?.player.map { String(describing: ObjectIdentifier($0)) } ?? "nil"
            let itemID = playerVC?.player?.currentItem.map { String(describing: ObjectIdentifier($0)) } ?? "nil"
            print("🧪 SwipeableOverlayTeardown begin reason=\(reason) player=\(playerID) item=\(itemID) main=\(Thread.isMainThread)")
#endif
        }

        func endTeardown(reason: String) {
            isTearingDown = false
#if DEBUG
            print("🧪 SwipeableOverlayTeardown end reason=\(reason) main=\(Thread.isMainThread)")
#endif
        }
        
        @objc func smartFillButtonTapped() {
            print("✨ SmartFill button tapped for: \(parent.videoData.unifiedTake.fileName)")
            parent.onSmartFillTap?(parent.videoData.take)
        }
        
        @objc func trimButtonTapped() {
            print("✂️ Trim button tapped for: \(parent.videoData.unifiedTake.fileName)")
            parent.onEditorRequest?(parent.videoData.take)
        }

        @objc func compareSourceButtonTapped() {
            guard let sourceTakeID = parent.videoData.reopenContext?.sourceTakeID else { return }
            parent.onCompareSourceTake?(sourceTakeID)
        }
        func setRatingsCenterYConstraint(_ constraint: NSLayoutConstraint) {
            ratingsCenterYConstraint = constraint
        }

        func updateRatingsVerticalPlacement(
            isLandscape: Bool,
            reason: String,
            playerView: UIView? = nil,
            overlayView: UIView? = nil
        ) {
            guard parent.ratingsOverlayMode == .uikit else { return }
            let overlay = overlayView ?? overlayRootView
            guard let centerConstraint = ratingsCenterYConstraint else {
#if DEBUG
                logRatingsLayout(reason: reason, playerView: playerView, overlayView: overlay, targetConstant: nil, minOffset: nil)
#endif
                return
            }
            var targetConstant: CGFloat = 0
            var minOffset: CGFloat?
            if isLandscape {
                let desired = landscapeRatingsVerticalOffset
                if let overlay {
                    let overlayHeight = overlay.bounds.height
                    let safeInsets = overlay.safeAreaInsets
                    let safeHeight = overlayHeight - safeInsets.top - safeInsets.bottom
                    let usableHeight = safeHeight > 1 ? safeHeight : overlayHeight
                    if usableHeight > 1 {
                        let computedMin = ratingsTopMargin + (ratingContainerSize.height / 2) - (usableHeight / 2)
                        minOffset = computedMin
                        targetConstant = max(desired, computedMin)
                    } else {
                        targetConstant = desired
                    }
                } else {
                    targetConstant = desired
                }
            }

            if abs(centerConstraint.constant - targetConstant) > 0.5 {
                CATransaction.begin()
                CATransaction.setDisableActions(true)
                UIView.performWithoutAnimation {
                    centerConstraint.constant = targetConstant
                    overlay?.setNeedsLayout()
                    overlay?.layoutIfNeeded()
                }
                CATransaction.commit()
            }
#if DEBUG
            logRatingsLayout(
                reason: reason,
                playerView: playerView,
                overlayView: overlay,
                targetConstant: targetConstant,
                minOffset: minOffset
            )
#endif
        }

#if DEBUG
        func logRatingsLayout(
            reason: String,
            playerView: UIView?,
            overlayView: UIView?,
            targetConstant: CGFloat?,
            minOffset: CGFloat?
        ) {
            let playerBounds = playerView?.bounds ?? .zero
            let overlayBounds = overlayView?.bounds ?? .zero
            let overlaySafeInsets = overlayView?.safeAreaInsets ?? .zero
            let overlaySafeFrame = overlayView?.safeAreaLayoutGuide.layoutFrame ?? .zero
            let ratingsFrame = ratingButtonsView?.frame ?? .zero
            let currentConstant = ratingsCenterYConstraint?.constant ?? 0
            let desired = landscapeRatingsVerticalOffset
            let currentString = String(format: "%.1f", currentConstant)
            let targetString = targetConstant.map { String(format: "%.1f", $0) } ?? "nil"
            let minOffsetString = minOffset.map { String(format: "%.1f", $0) } ?? "nil"
            let desiredString = String(format: "%.1f", desired)
            print(
                "🧪 RatingsLayout[\(reason)] player=\(playerBounds) overlay=\(overlayBounds) safeInsets=\(overlaySafeInsets) safeFrame=\(overlaySafeFrame) ratingsFrame=\(ratingsFrame) current=\(currentString) target=\(targetString) minOffset=\(minOffsetString) desired=\(desiredString)"
            )
        }
#endif
        
        // UPDATED: Update overlay visibility based on control visibility instead of playback state
        func updateOverlayVisibility(controlsVisible: Bool, overlayRootView: UIView?, playerVC: AVPlayerViewController?) {
            if shouldSuppressOverlayUpdates(playerVC: playerVC) {
#if DEBUG
                let now = Date()
                if now.timeIntervalSince(lastOverlaySuppressionLog) > 1.0 {
                    lastOverlaySuppressionLog = now
                    let playerID = playerVC?.player.map { String(describing: ObjectIdentifier($0)) } ?? "nil"
                    let itemID = playerVC?.player?.currentItem.map { String(describing: ObjectIdentifier($0)) } ?? "nil"
                    let windowed = playerVC?.view.window != nil
                    let hidden = playerVC?.view.isHidden ?? false
                    let visibleFlag = (playerVC as? EnhancedAVPlayerViewController)?.isCurrentlyVisible
                    print("🧪 SwipeableOverlayVisibility suppressed tearingDown=\(isTearingDown) player=\(playerID) item=\(itemID) windowed=\(windowed) hidden=\(hidden) visibleFlag=\(visibleFlag?.description ?? "nil") main=\(Thread.isMainThread)")
                }
#endif
                return
            }
            guard let overlayView = overlayRootView ?? self.overlayRootView ?? playerVC?.contentOverlayView else { return }
            overlayView.isUserInteractionEnabled = true
            areControlsVisible = controlsVisible
            
            let targetAlpha: CGFloat = controlsVisible ? 1.0 : 0.0
            let animationDuration: TimeInterval = 0.3
            let isPlaying = playerVC?.player?.timeControlStatus == .playing
#if DEBUG
            let playerID = playerVC?.player.map { String(describing: ObjectIdentifier($0)) } ?? "nil"
            let itemID = playerVC?.player?.currentItem.map { String(describing: ObjectIdentifier($0)) } ?? "nil"
            let itemStatus = playerVC?.player?.currentItem?.status.rawValue ?? -1
            print("🧪 SwipeableOverlayVisibility controlsVisible=\(controlsVisible) playing=\(isPlaying == true) player=\(playerID) item=\(itemID) status=\(itemStatus) main=\(Thread.isMainThread)")
#endif
            
            UIView.animate(withDuration: animationDuration, delay: 0, options: .curveEaseInOut) {
                self.applyOverlayVisibility(controlsVisible: controlsVisible, isPlaying: isPlaying, overlayView: overlayView, targetAlpha: targetAlpha)
            }
            
            print("🎮 \(controlsVisible ? "Showing" : "Hiding") overlays with player controls")
        }
        
        @objc func ratingButtonTapped(_ sender: UIButton) {
            let ratings: [TakeRating] = [.finalSelect, .option, .unrated, .rejected]
            guard sender.tag < ratings.count else { return }
            
            let selectedRating = ratings[sender.tag]
            print("🎯 Rating Button Tapped: \(selectedRating.rawValue)")
            
            parent.onRatingChange(selectedRating)
            updateButtonAppearances(selectedRating: selectedRating, sender: sender)
        }
        
        private func updateButtonAppearances(selectedRating: TakeRating, sender: UIButton) {
            guard let containerView = sender.superview else { return }
            
            let colors: [UIColor] = [.systemYellow, .systemGreen, .systemGray, .systemRed]
            let ratings: [TakeRating] = [.finalSelect, .option, .unrated, .rejected]
            
            for (index, subview) in containerView.subviews.enumerated() {
                guard let button = subview as? UIButton, index < colors.count else { continue }
                
                let rating = ratings[index]
                let color = colors[index]
                
                button.tintColor = selectedRating == rating ? color : UIColor.white.withAlphaComponent(0.9)
                button.backgroundColor = selectedRating == rating ? color.withAlphaComponent(0.4) : UIColor.black.withAlphaComponent(0.6)
            }
        }
        
        func bindPlaybackObservation(to player: AVPlayer, playerVC: EnhancedAVPlayerViewController) {
            playbackObserver?.invalidate()
            playbackObserver = player.observe(\.timeControlStatus, options: [.initial, .new]) { [weak self, weak playerVC] player, _ in
                let isPlaying = player.timeControlStatus == .playing
#if DEBUG
                if let self {
                    let elapsed = self.lastItemAssignTime > 0 ? CFAbsoluteTimeGetCurrent() - self.lastItemAssignTime : -1
                    let statusRaw = player.timeControlStatus.rawValue
                    print(String(format: "🧪 Player timeControlStatus=%d playing=%@ elapsed=%.3f", statusRaw, isPlaying.description, elapsed))
                }
#endif
                Task { @MainActor [weak self, weak playerVC] in
                    guard let self else { return }
                    self.isPlaying = isPlaying
                    self.updateIdleTimerState()
                    if let playerVC = playerVC {
                        self.handlePlaybackStateChange(isPlaying: isPlaying, playerVC: playerVC)
                    }
                }
            }
        }
        
        func startPlaybackStateObserving(player: AVPlayer) {
            timeControlStatusObservation?.invalidate()
            timeControlStatusObservation = player.observe(\.timeControlStatus, options: [.initial, .new]) { [weak self] player, _ in
                guard let self else { return }
                DispatchQueue.main.async {
                    if self.isTearingDown || player.currentItem == nil {
                        return
                    }
                    let playing = player.timeControlStatus == .playing
                    self.setCustomOverlaysVisible(!playing)
                }
            }
            
            if let didEndObserver {
                NotificationCenter.default.removeObserver(didEndObserver)
            }
            didEndObserver = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: player.currentItem,
                queue: .main
            ) { [weak self] _ in
                self?.setCustomOverlaysVisible(true)
            }
        }
        
        func startExternalPlaybackObservation(for player: AVPlayer) {
            externalPlaybackObservation?.invalidate()
            externalPlaybackObservation = player.observe(\.isExternalPlaybackActive, options: [.initial, .new]) { player, _ in
                print("📺 AirPlay externalPlaybackActive = \(player.isExternalPlaybackActive)")
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.isExternalPlaybackActive = player.isExternalPlaybackActive
                    self.updateIdleTimerState()
                }
            }
        }
        
        private func handlePlaybackStateChange(isPlaying: Bool, playerVC: EnhancedAVPlayerViewController) {
            if shouldSuppressOverlayUpdates(playerVC: playerVC) { return }
            guard let overlayView = overlayRootView ?? playerVC.contentOverlayView else { return }
            let targetAlpha: CGFloat = areControlsVisible ? 1.0 : 0.0
            UIView.animate(withDuration: 0.2) {
                self.applyOverlayVisibility(controlsVisible: self.areControlsVisible, isPlaying: isPlaying, overlayView: overlayView, targetAlpha: targetAlpha)
            }
#if DEBUG
            logRatingsLayout(
                reason: "playbackStateChanged",
                playerView: playerVC.view,
                overlayView: overlayView,
                targetConstant: ratingsCenterYConstraint?.constant,
                minOffset: nil
            )
#endif
        }

        @MainActor
        func releaseIdleTimer() {
            idleTimerToken?.release()
            idleTimerToken = nil
            isPlaying = false
            isExternalPlaybackActive = false
        }

        @MainActor
        private func updateIdleTimerState() {
            let shouldDisable = isPlaying || isExternalPlaybackActive
            if shouldDisable {
                if idleTimerToken == nil {
                    idleTimerToken = IdleTimerController.shared.acquire(reason: "SwipeableVideoPlayer")
                }
            } else {
                idleTimerToken?.release()
                idleTimerToken = nil
            }
        }
        
        private func applyOverlayVisibility(controlsVisible: Bool, isPlaying: Bool, overlayView: UIView, targetAlpha: CGFloat) {
            overlayView.subviews.forEach { subview in
                setAlpha(targetAlpha, for: subview, isPlaying: isPlaying)
            }
        }

        func setOverlayTopComfort(_ value: CGFloat) {
            guard abs(value - currentOverlayTopComfort) > 0.5 else { return }
            currentOverlayTopComfort = value
            applyOverlayTopComfortIfPossible()
        }

        func setTitleTopConstraint(_ constraint: NSLayoutConstraint) {
            titleTopConstraint = constraint
            applyOverlayTopComfortIfPossible()
        }

        private func applyOverlayTopComfortIfPossible() {
            guard let titleTopConstraint else { return }
            titleTopConstraint.constant = titleBaseTop + currentOverlayTopComfort
            overlayRootView?.layoutIfNeeded()
        }
        
        private func setAlpha(_ targetAlpha: CGFloat, for view: UIView, isPlaying: Bool) {
            // Custom overlays are controlled by playback state observer; skip them here.
            if view.tag == OverlayTags.titleView
                || view.tag == OverlayTags.trimButton
                || view.tag == OverlayTags.ratingButtons
                || view.tag == OverlayTags.smartFillButton {
                return
            }
            let shouldHideForPlayback = isPlaying
            view.alpha = shouldHideForPlayback ? 0 : targetAlpha
            view.subviews.forEach { setAlpha(targetAlpha, for: $0, isPlaying: isPlaying) }
        }
        
        private func setCustomOverlaysVisible(_ visible: Bool) {
            if isTearingDown { return }
            guard let root = overlayRootView else { return }
            let targetAlpha: CGFloat = visible ? 1.0 : 0.0
            UIView.animate(withDuration: 0.18) {
                for sub in root.subviews {
                    switch sub.tag {
                    case OverlayTags.titleView,
                         OverlayTags.trimButton,
                         OverlayTags.ratingButtons,
                         OverlayTags.smartFillButton:
                        sub.alpha = targetAlpha
                        sub.isUserInteractionEnabled = visible
                    default:
                        break
                    }
                }
            }
        }
    }
    
    private func debugAirPlay(_ player: AVPlayer, label: String) {
        let item = player.currentItem
        let asset = item?.asset as? AVURLAsset
        let isComposition = item?.asset is AVComposition
        let assetName = asset?.url.lastPathComponent ?? "nil"

        Task {
            var videoTracks = 0
            var audioTracks = 0
            if let asset {
                do {
                    let tracks = try await asset.load(.tracks)
                    videoTracks = tracks.filter { $0.mediaType == .video }.count
                    audioTracks = tracks.filter { $0.mediaType == .audio }.count
                } catch {
                    print("📺 AirPlayDBG[\(label)] failed to load tracks: \(error)")
                }
            }

            print("📺 AirPlayDBG[\(label)] allowsExternalPlayback player=\(player.allowsExternalPlayback) externalActive=\(player.isExternalPlaybackActive)")
            print("📺 AirPlayDBG[\(label)] asset=\(assetName) composition=\(isComposition) tracks video=\(videoTracks) audio=\(audioTracks)")
        }
    }
    
    func makeUIViewController(context: Context) -> UIViewController {
        let playerVC = EnhancedAVPlayerViewController()
        if #available(iOS 16.0, *) {
            playerVC.allowsVideoFrameAnalysis = false
        }
        
        // RESTORED: Proper video configuration with natural aspect ratios
        playerVC.videoGravity = AVLayerVideoGravity.resizeAspect // FIXED: Use full type name
        playerVC.showsPlaybackControls = true
        playerVC.allowsPictureInPicturePlayback = false
        playerVC.modalPresentationStyle = UIModalPresentationStyle.fullScreen // FIXED: Use full type name
        playerVC.entersFullScreenWhenPlaybackBegins = false
        playerVC.exitsFullScreenWhenPlaybackEnds = false
        
        // CRITICAL FIX: Mark as part of swipeable collection to enable lifecycle management
        playerVC.isPartOfSwipeableCollection = true
        
        // NEW: Setup control visibility monitoring for overlay synchronization
        playerVC.onControlVisibilityChanged = { controlsVisible in
            DispatchQueue.main.async {
                context.coordinator.updateOverlayVisibility(
                    controlsVisible: controlsVisible,
                    overlayRootView: playerVC.contentOverlayView,
                    playerVC: playerVC
                )
            }
        }
        
        // Store coordinator and setup video
        playerVC.coordinator = context.coordinator
        context.coordinator.isPlaybackInteracting = playbackInteractionActive.wrappedValue

        // 🔥 CRITICAL PATH VOLATILITY FIX: Use VideoVariantResolver to get correct absolute path
        // CRITICAL FIX: Use take.effectiveFilePath to respect edited versions
        let videoURL = URL(fileURLWithPath: videoData.take.effectiveFilePath)
        let fileName = videoURL.lastPathComponent
        
        print("🎬 CRITICAL FIX: Using take.effectiveFilePath to respect edited versions")
        print("   📁 Original filePath: \(videoData.take.filePath)")
        print("   📂 Effective path (edited if available): \(videoURL.path)")
        print("   📱 Orientation: \(videoData.take.capturedOrientation?.displayName ?? "Unknown")")
        
        guard FileManager.default.fileExists(atPath: videoURL.path) else {
            print("❌ PATH VOLATILITY FIX: Video file doesn't exist at resolved path: \(videoURL.path)")
            return playerVC
        }
        
        let player = AVPlayer()
        // ✅ AirPlay video: explicitly allow external playback to avoid audio-only routing.
        player.allowsExternalPlayback = true
        if #available(iOS 12.0, *) {
            player.usesExternalPlaybackWhileExternalScreenIsActive = true
        }
        playerVC.player = player
        context.coordinator.bindPlaybackObservation(to: player, playerVC: playerVC)
        context.coordinator.startExternalPlaybackObservation(for: player)
        debugAirPlay(player, label: "player-created")
        
        print("⏳ Preparing video asynchronously - \(fileName)")
        
        // Store the video data for reference
        playerVC.videoData = videoData
        
        // NEW: Setup control visibility monitoring
        playerVC.setupControlVisibilityMonitoring()
        
        // CRITICAL FIX: Notify parent about player creation for lifecycle management
        onPlayerCreated(playerVC)
        
        let startItemBuild: () -> Void = {
            let assignStart = CFAbsoluteTimeGetCurrent()
#if DEBUG
            print(String(format: "🧪 PlayerItem build start file=%@ t=%.3f", fileName, assignStart))
#endif
            Task {
                let buildStart = CFAbsoluteTimeGetCurrent()
                let builtItem: AVPlayerItem
                let cacheLabel: String
                if let cachedItem = await PlayerItemPrefetchCache.shared.popItem(for: videoData.take) {
                    builtItem = cachedItem
                    cacheLabel = "hit"
                } else {
                    builtItem = await TakePlaybackBuilder.makePlayerItem(for: videoData.take)
                    cacheLabel = "miss"
                }
                let buildElapsed = CFAbsoluteTimeGetCurrent() - buildStart
                let finalItem: AVPlayerItem
                let isExternalPlaybackActive = player.isExternalPlaybackActive
                if builtItem.asset is AVComposition && isExternalPlaybackActive {
                    print("📺 AirPlayDBG: composition item detected with external playback active — using URL item")
                    finalItem = AVPlayerItem(url: videoURL)
                } else {
                    finalItem = builtItem
                }

                if videoData.take.hasEdits,
                   finalItem.asset is AVURLAsset,
                   finalItem.videoComposition == nil {
                    let reason = isExternalPlaybackActive ? "externalPlayback" : "urlItem"
                    await TakePlaybackDiagnostics.shared.warnIfUneditedPlayback(
                        take: videoData.take,
                        fileName: fileName,
                        reason: reason
                    )
                }

                await MainActor.run {
                    let assignElapsed = CFAbsoluteTimeGetCurrent() - assignStart
                    player.replaceCurrentItem(with: finalItem)
#if DEBUG
                    let assetKind = (builtItem.asset is AVComposition) ? "composition" : "url"
                    print(String(format: "🧪 PlayerItem build done file=%@ build=%.3f assignElapsed=%.3f asset=%@ cache=%@", fileName, buildElapsed, assignElapsed, assetKind, cacheLabel))
                    context.coordinator.bindItemDiagnostics(item: finalItem, fileName: fileName, assignTime: assignStart)
                    let now = CFAbsoluteTimeGetCurrent()
                    if let elapsedFromSwipe = SwipeTimingTracker.shared.elapsedSinceSwipe(takeID: videoData.take.id, now: now) {
                        print(String(format: "🧪 SwipeToItemAssign take=%@ file=%@ elapsed=%.3f", videoData.take.id.uuidString, fileName, elapsedFromSwipe))
                    }
                    context.coordinator.logRatingsLayout(
                        reason: "playerItemChanged",
                        playerView: playerVC.view,
                        overlayView: playerVC.contentOverlayView,
                        targetConstant: nil,
                        minOffset: nil
                    )
#endif
                    debugAirPlay(player, label: "item-replaced")
                    print("✅ CRITICAL FIX: Video loaded successfully - \(fileName) (edited version if available)")
                    print("🎯 BREAKTHROUGH: Video player now immune to container UUID changes!")
                }
            }
        }

        if playbackInteractionActive.wrappedValue {
#if DEBUG
            print("🧪 PlayerSwap deferred reason=interaction file=\(fileName)")
#endif
            let coordinator = context.coordinator
            func tryStartAfterInteraction() {
                if coordinator.isPlaybackInteracting {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        tryStartAfterInteraction()
                    }
                } else {
                    startItemBuild()
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                tryStartAfterInteraction()
            }
        } else {
            startItemBuild()
        }
        
        // Observe playback state to control custom overlay visibility
        context.coordinator.startPlaybackStateObserving(player: player)
        
        if manageAudioSession {
            do {
                let session = AVAudioSession.sharedInstance()
                if !context.coordinator.didCapturePriorAudioSession {
                    context.coordinator.didCapturePriorAudioSession = true
                    context.coordinator.priorCategory = session.category
                    context.coordinator.priorMode = session.mode
                    context.coordinator.priorOptions = session.categoryOptions
                }
#if DEBUG
                AudioSessionDiagnostics.snapshot("SwipeableVideoPlayer/AVPVC/configure/before")
#endif
                try session.setCategory(.playback, mode: .moviePlayback, options: [.allowAirPlay])
                try session.setActive(true, options: [])
                print("✅ AVAudioSession set to playback/moviePlayback + allowAirPlay")
#if DEBUG
                AudioSessionDiagnostics.snapshot("SwipeableVideoPlayer/AVPVC/configure/after")
#endif
            } catch {
                print("❌ AVAudioSession setup failed: \(error)")
            }
        } else {
#if DEBUG
            print("🔇 AVAudioSession setup skipped (managed externally)")
#endif
        }

        // Decide overlay host (zoom vs non-zoom) but always mount overlays on contentOverlayView
        guard let overlayView = playerVC.contentOverlayView else {
            print("❌ No contentOverlayView available for custom overlays")
            let container = ChromeInsetContainerViewController(playerViewController: playerVC)
            container.updatePlaybackInsets(playbackSafeAreaInsets)
            return enableVideoZoom ? ZoomableAVPlayerHostViewController(chromeContainer: container) : container
        }
        
        setupOverlay(forRoot: overlayView, coordinator: context.coordinator)
        context.coordinator.setOverlayTopComfort(overlayTopComfort)
        
        let container = ChromeInsetContainerViewController(playerViewController: playerVC)
        container.updatePlaybackInsets(playbackSafeAreaInsets)

        if enableVideoZoom {
            let host = ZoomableAVPlayerHostViewController(chromeContainer: container)
            host.explicitSafeAreaInsets = uiInsets(from: playbackSafeAreaInsets)
            // Ensure visibility updates reference the unified overlay root
            playerVC.onControlVisibilityChanged = { controlsVisible in
                DispatchQueue.main.async {
                    context.coordinator.updateOverlayVisibility(
                        controlsVisible: controlsVisible,
                        overlayRootView: overlayView,
                        playerVC: playerVC
                    )
                }
            }
            return host
        } else {
            return container
        }
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        // 🚨 SMARTFILL DATA REFRESH FIX: Handle refresh trigger changes
        let coordinator = context.coordinator
        coordinator.isPlaybackInteracting = playbackInteractionActive.wrappedValue
        let resolvedInsets = uiInsets(from: playbackSafeAreaInsets)
        coordinator.setOverlayTopComfort(overlayTopComfort)
        if let container = uiViewController as? ChromeInsetContainerViewController {
            container.updatePlaybackInsets(playbackSafeAreaInsets)
        } else if let host = uiViewController as? ZoomableAVPlayerHostViewController {
            host.chromeContainer.updatePlaybackInsets(playbackSafeAreaInsets)
            host.explicitSafeAreaInsets = resolvedInsets
        }
        if coordinator.lastRefreshTrigger != refreshTrigger {
            print("🔄 CustomAVPlayerViewController: Refresh trigger changed (\(coordinator.lastRefreshTrigger) -> \(refreshTrigger))")
            coordinator.lastRefreshTrigger = refreshTrigger

            if let container = uiViewController as? ChromeInsetContainerViewController {
                (container.playerViewController as? EnhancedAVPlayerViewController)?.videoData = videoData
            } else if let host = uiViewController as? ZoomableAVPlayerHostViewController {
                (host.playerViewController as? EnhancedAVPlayerViewController)?.videoData = videoData
            }

            print("🔄 Video data refresh completed")
        }
    }

    private func uiInsets(from edgeInsets: EdgeInsets) -> UIEdgeInsets {
        UIEdgeInsets(top: edgeInsets.top,
                     left: edgeInsets.leading,
                     bottom: edgeInsets.bottom,
                     right: edgeInsets.trailing)
    }

    static func dismantleUIViewController(_ uiViewController: UIViewController, coordinator: Coordinator) {
        Task { @MainActor in
            let performTeardown: () -> Void = {
                if let container = uiViewController as? ChromeInsetContainerViewController {
                    let hostType = String(describing: type(of: container.playerViewController))
                    safeSwipeableTeardown(
                        container.playerViewController.player,
                        host: container.playerViewController,
                        context: "dismantle-container",
                        hostType: hostType,
                        deferReplace: false,
                        onTeardownStart: { coordinator.beginTeardown(reason: "dismantle-container", playerVC: container.playerViewController) },
                        onTeardownEnd: { coordinator.endTeardown(reason: "dismantle-container") }
                    )
                } else if let host = uiViewController as? ZoomableAVPlayerHostViewController {
                    let hostType = String(describing: type(of: host.playerViewController))
                    safeSwipeableTeardown(
                        host.playerViewController.player,
                        host: host.playerViewController,
                        context: "dismantle-host",
                        hostType: hostType,
                        deferReplace: false,
                        onTeardownStart: { coordinator.beginTeardown(reason: "dismantle-host", playerVC: host.playerViewController) },
                        onTeardownEnd: { coordinator.endTeardown(reason: "dismantle-host") }
                    )
                }
            }

            func scheduleAfterInteraction() {
                if coordinator.isPlaybackInteracting {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        scheduleAfterInteraction()
                    }
                } else {
                    performTeardown()
                }
            }

            if coordinator.isPlaybackInteracting {
#if DEBUG
                print("🧪 PlayerSwap deferred reason=interaction (teardown)")
#endif
                scheduleAfterInteraction()
            } else {
                performTeardown()
            }
            coordinator.releaseIdleTimer()
        }
        if coordinator.parent.manageAudioSession {
            restorePriorAudioSessionIfNeeded(coordinator)
        }
    }

    private static func restorePriorAudioSessionIfNeeded(_ coordinator: Coordinator) {
        guard let category = coordinator.priorCategory,
              let mode = coordinator.priorMode else { return }

        let session = AVAudioSession.sharedInstance()
        let options = coordinator.priorOptions ?? []

        do {
#if DEBUG
            AudioSessionDiagnostics.snapshot("SwipeableVideoPlayer/AVPVC/restore/before")
#endif
            try session.setCategory(category, mode: mode, options: options)
            try session.setActive(true)
            print("🔁 CustomAVPlayerViewController: Restored audio session category=\(category.rawValue) mode=\(mode.rawValue)")
#if DEBUG
            AudioSessionDiagnostics.snapshot("SwipeableVideoPlayer/AVPVC/restore/after")
#endif
        } catch {
            print("⚠️ CustomAVPlayerViewController: Failed restoring audio session: \(error)")
        }
    }

    // CRITICAL FIX: New method to determine if Smart Fill should be applied - ONLY for videos with actual SmartFill versions
    private func shouldApplySmartFill(for take: ProjectTake) -> Bool {
        // FIXED: Never use SmartFillPreview for videos that have been processed - play the actual processed file
        // SmartFillPreview is only for live preview, not for playing processed videos
        return false  // Always play the actual video file (original or processed)
    }
    
    // The effectiveFilePath approach in makeUIViewController handles all SmartFill logic
    
    // 🚨 CRITICAL FIX: Add the missing setupOverlayForPlayerViewController method
    private func setupOverlay(forRoot rootView: UIView?, coordinator: Coordinator) {
        guard let overlayView = rootView else {
            print("❌ Could not access overlay root view")
            return
        }

        coordinator.overlayRootView = overlayView
        // ⚠️ IMPORTANT — DO NOT CHANGE WITHOUT FULL CONTEXT ⚠️
        //
        // All custom video overlays (Take header, ratings, SmartFill, trim/crop)
        // MUST be attached to AVPlayerViewController.contentOverlayView.
        //
        // Even when using ZoomableAVPlayerHostViewController, overlays are NOT added
        // to the host’s overlayContainer.
        //
        // Reason:
        // - Native AVPlayer controls (scrubber timeline, AirPlay, playback chrome)
        //   manage visibility based on playback state.
        // - Splitting overlays across multiple roots causes desync:
        //     • overlays not hiding on play
        //     • overlays not reappearing on pause/end
        //     • inconsistent tap behavior
        //
        // Zoom still works because the entire AVPlayerViewController (including
        // contentOverlayView) is inside the zoomable scroll container.
        //
        // This rule preserves:
        // - stable ratings UX
        // - predictable overlay visibility
        // - native playback behavior
        overlayView.subviews.forEach { $0.removeFromSuperview() }
        overlayView.isUserInteractionEnabled = true
        
        if let editorButtons = createEditorButtonsOverlay(coordinator: coordinator) {
            overlayView.addSubview(editorButtons)
            editorButtons.translatesAutoresizingMaskIntoConstraints = false
            let leadingConstraint = editorButtons.leadingAnchor.constraint(equalTo: overlayView.safeAreaLayoutGuide.leadingAnchor, constant: 20)
            let bottomConstraint = editorButtons.bottomAnchor.constraint(equalTo: overlayView.safeAreaLayoutGuide.bottomAnchor, constant: -60)
            let widthConstraint = editorButtons.widthAnchor.constraint(equalToConstant: 66)
            
            leadingConstraint.priority = UILayoutPriority(999)
            bottomConstraint.priority = UILayoutPriority(999)
            widthConstraint.priority = UILayoutPriority(1000)
            
            NSLayoutConstraint.activate([leadingConstraint, bottomConstraint, widthConstraint])
            editorButtons.layer.zPosition = 1000
        }
        
        // Add rating buttons for regular takes AND slates with SAFE AREA positioning
        if ratingsOverlayMode == .uikit, shouldShowRatings(for: videoData.take) {
            let ratingButtonsView = createRatingButtonsOverlay(coordinator: coordinator)
            overlayView.addSubview(ratingButtonsView)

            ratingButtonsView.translatesAutoresizingMaskIntoConstraints = false
            // CRITICAL FIX: Use safe area but with priority adjustments for stability
            let trailingConstraint = ratingButtonsView.trailingAnchor.constraint(equalTo: overlayView.safeAreaLayoutGuide.trailingAnchor, constant: -20)
            let centerYConstraint = ratingButtonsView.centerYAnchor.constraint(equalTo: overlayView.safeAreaLayoutGuide.centerYAnchor)
            let widthConstraint = ratingButtonsView.widthAnchor.constraint(equalToConstant: 60)
            let heightConstraint = ratingButtonsView.heightAnchor.constraint(equalToConstant: 280)

            // CRITICAL FIX: Set higher priority for these constraints to prevent breaking
            trailingConstraint.priority = UILayoutPriority(999)
            centerYConstraint.priority = UILayoutPriority(999)
            widthConstraint.priority = UILayoutPriority(1000)
            heightConstraint.priority = UILayoutPriority(1000)

            NSLayoutConstraint.activate([trailingConstraint, centerYConstraint, widthConstraint, heightConstraint])
            coordinator.setRatingsCenterYConstraint(centerYConstraint)
            coordinator.ratingButtonsView = ratingButtonsView
            coordinator.updateRatingsVerticalPlacement(
                isLandscape: overlayView.bounds.width > overlayView.bounds.height,
                reason: "setupOverlay",
                overlayView: overlayView
            )

            // CRITICAL FIX: Ensure overlay stays positioned correctly during orientation changes
            ratingButtonsView.layer.zPosition = 1000
        }
        
        if showsTitleOverlay {
            // Add video title with SAFE AREA positioning
            let titleView = createTitleOverlay(coordinator: coordinator)
            overlayView.addSubview(titleView)
            
            titleView.translatesAutoresizingMaskIntoConstraints = false
            // CRITICAL FIX: Use safe area with priority adjustments
            let centerXConstraint = titleView.centerXAnchor.constraint(equalTo: overlayView.safeAreaLayoutGuide.centerXAnchor)
            let topConstraint = titleView.topAnchor.constraint(equalTo: overlayView.layoutMarginsGuide.topAnchor, constant: 20)
            
            // CRITICAL FIX: Set higher priority for these constraints
            centerXConstraint.priority = UILayoutPriority(999)
            topConstraint.priority = UILayoutPriority(999)
            
            NSLayoutConstraint.activate([centerXConstraint, topConstraint])
            coordinator.setTitleTopConstraint(topConstraint)
            
            // CRITICAL FIX: Ensure title stays positioned correctly
            titleView.layer.zPosition = 1000
        }

        print("✅ Added overlay controls with safe area positioning and stability priorities")
    }
    
    // MARK: - Helper Methods for Title and Subtitle Formatting
    
    private func formatVideoTitle() -> String {
        switch videoData.take.takeType {
        case .merged:
            return "Merged Video"
        case .exported:
            return "Exported Take"
        case .slate:
            // ENHANCED: Show slate with session-wide numbering
            if let slateID = videoData.take.slateID {
                return slateID // e.g., "SLATE1", "SLATE2"
            } else {
                return "Slate \(videoData.takeNumber)"
            }
        case .pipSlate:
            if let slateID = videoData.take.slateID {
                return "PiP \(slateID)"
            } else {
                return "PiP Slate \(videoData.takeNumber)"
            }
        case .pipComponent:
            return "PiP Component"
        case .regular:
            var baseTitle = videoData.displayLabel
            
            if videoData.isSmartFillVariant {
                baseTitle += " - SmartFill"
            }
            
            return baseTitle
        }
    }
    
    private func formatVideoSubtitle() -> String {
        let duration = formattedDuration(videoData.take.effectiveDurationSeconds)
        
        // Build base subtitle
            let subtitle = switch videoData.take.takeType {
        case .slate, .pipSlate:
            "\(duration) • \(videoData.takeNumber) of \(videoData.totalTakes) slates"
        case .pipComponent:
            "\(duration)"
        case .regular:
            if videoData.take.sceneNumber > 1 {
                "\(duration) • Take \(videoData.takeNumber) of \(videoData.totalTakes) in Scene \(videoData.take.sceneNumber)"
            } else {
                "\(duration) • \(videoData.takeNumber) of \(videoData.totalTakes)"
            }
        case .merged, .exported:
            "\(duration) • \(videoData.takeNumber) of \(videoData.totalTakes)"
        }
        
        if let notes = videoData.take.takeNotes, notes.contains("SmartFill processed") {
            return "\(subtitle) • Landscape (Processed from Portrait)"
        }
        
        return subtitle
    }
    
    private func formattedDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func shouldShowRatings(for take: ProjectTake) -> Bool {
        guard take.takeType == .regular || take.takeType.isSlateLike else { return false }
        if take.takeType == .pipSlate {
            let noteText = (take.takeNotes ?? "").lowercased()
            let slateText = (take.slateNumber ?? "").lowercased()
            let combined = "\(noteText) \(slateText)"
            let isPIPSource = take.sceneNumber <= -100
                || combined.contains("pip full body")
                || combined.contains("pip close-up")
                || combined.contains("pip close up")
            if isPIPSource { return false }
        }
        return true
    }
    
    // MARK: - Overlay Creation Methods
    
    private enum OverlayTags {
        static let titleView = 9001
        static let trimButton = 9002
        static let ratingButtons = 9003
        static let smartFillButton = 9004
    }
    
    private enum SmartFillButtonState {
        case hidden
        case request(available: Bool)
        case edit
        
        var shouldShow: Bool {
            switch self {
            case .hidden: return false
            default: return true
            }
        }
    }

    private func smartFillButtonState(for take: ProjectTake) -> SmartFillButtonState {
        if isExportDeliverable(take) { return .hidden }
        guard let intent = SmartFillPlayerEntryResolver.resolve(for: take, in: currentSession) else {
            return .hidden
        }
        switch intent {
        case .request:
            return .request(available: true)
        case .edit:
            return .edit
        }
    }
    
    private func createEditorButtonsOverlay(coordinator: Coordinator) -> UIView? {
        let smartFillState = smartFillButtonState(for: videoData.take)
        let showSmartFill = smartFillState.shouldShow && onSmartFillTap != nil
        let showTrim = shouldShowTrimButton(for: videoData.take) && onEditorRequest != nil
        guard showSmartFill || showTrim else { return nil }
        
        let containerView = UIView()
        containerView.tag = OverlayTags.ratingButtons
        containerView.backgroundColor = UIColor.clear
        
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 12
        stackView.alignment = .center
        stackView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: containerView.topAnchor),
            stackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            stackView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor)
        ])
        
        if showSmartFill, let smartFillButton = makeSmartFillOverlayButton(for: smartFillState, coordinator: coordinator) {
            smartFillButton.tag = OverlayTags.smartFillButton
            stackView.addArrangedSubview(smartFillButton)
        }
        
        if showTrim {
            let trimButton = makeOverlayButton(
                symbolName: "scissors",
                tintColor: UIColor.white.withAlphaComponent(0.95),
                backgroundColor: UIColor.black.withAlphaComponent(0.65),
                action: #selector(Coordinator.trimButtonTapped),
                coordinator: coordinator
            )
            trimButton.tag = OverlayTags.trimButton
            stackView.addArrangedSubview(trimButton)
        }
        
        return containerView
    }
    
    private func makeSmartFillOverlayButton(for state: SmartFillButtonState, coordinator: Coordinator) -> UIView? {
        switch state {
        case .hidden:
            return nil
        case .edit:
            return makeOverlayButton(
                symbolName: "person.and.background.dotted",
                tintColor: UIColor.white.withAlphaComponent(0.95),
                backgroundColor: UIColor.systemPurple.withAlphaComponent(0.85),
                action: #selector(Coordinator.smartFillButtonTapped),
                coordinator: coordinator
            )
        case .request(let available):
            let tint = available ? UIColor.white.withAlphaComponent(0.95) : UIColor.white.withAlphaComponent(0.35)
            let background = available ? UIColor.systemPurple.withAlphaComponent(0.65) : UIColor.white.withAlphaComponent(0.12)
            return makeOverlayButton(
                symbolName: "person.and.background.dotted",
                tintColor: tint,
                backgroundColor: background,
                action: #selector(Coordinator.smartFillButtonTapped),
                coordinator: coordinator
            )
        }
    }
    
    private func makeOverlayButton(
        symbolName: String,
        tintColor: UIColor,
        backgroundColor: UIColor,
        action: Selector,
        coordinator: Coordinator
    ) -> UIView {
        let buttonSize: CGFloat = 50
        let button = UIButton(type: .system)
        let configuration = UIImage.SymbolConfiguration(pointSize: 22, weight: .medium)
        button.setImage(UIImage(systemName: symbolName, withConfiguration: configuration), for: .normal)
        button.tintColor = tintColor
        button.backgroundColor = backgroundColor
        button.layer.cornerRadius = buttonSize / 2
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOffset = CGSize(width: 0, height: 2)
        button.layer.shadowRadius = 4
        button.layer.shadowOpacity = 0.7
        button.translatesAutoresizingMaskIntoConstraints = false
        button.widthAnchor.constraint(equalToConstant: buttonSize).isActive = true
        button.heightAnchor.constraint(equalToConstant: buttonSize).isActive = true
        button.addTarget(coordinator, action: action, for: .touchUpInside)
        return button
    }
    
    private func shouldShowTrimButton(for take: ProjectTake) -> Bool {
        if take.takeType == .pipSlate { return true }
        return isSmartFillVariant(take) || !requiresSmartFill(for: take)
    }
    
    private func requiresSmartFill(for take: ProjectTake) -> Bool {
        SmartFillPlayerEntryResolver.shouldRequestSmartFill(for: take)
    }
    
    private func isSmartFillVariant(_ take: ProjectTake) -> Bool {
        take.isSmartFillVariant
    }
    
    private func isExportDeliverable(_ take: ProjectTake) -> Bool {
        SmartFillPlayerEntryResolver.isExportDeliverable(take)
    }
    
    private func createRatingButtonsOverlay(coordinator: Coordinator) -> UIView {
        let containerView = UIView()
        containerView.backgroundColor = UIColor.clear
        containerView.tag = OverlayTags.ratingButtons
        containerView.isUserInteractionEnabled = true
        
        let buttonSize: CGFloat = 50
        let spacing: CGFloat = 16
        
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = spacing
        stackView.alignment = .center
        stackView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor)
        ])
        
        let ratings: [(TakeRating, String, UIColor)] = [
            (.finalSelect, "star.fill", .systemYellow),
            (.option, "checkmark.circle.fill", .systemGreen),
            (.unrated, "circle", .systemGray),
            (.rejected, "xmark.circle.fill", .systemRed)
        ]
        let effectiveRating = SessionManager.shared.effectiveRating(for: videoData.take) ?? videoData.take.rating
        
        for (index, (rating, iconName, color)) in ratings.enumerated() {
            let button = UIButton(type: .system)
            button.translatesAutoresizingMaskIntoConstraints = false
            button.widthAnchor.constraint(equalToConstant: buttonSize).isActive = true
            button.heightAnchor.constraint(equalToConstant: buttonSize).isActive = true
            
            let configuration = UIImage.SymbolConfiguration(pointSize: 22, weight: .medium)
            button.setImage(UIImage(systemName: iconName, withConfiguration: configuration), for: .normal)
            button.tintColor = effectiveRating == rating ? color : UIColor.white.withAlphaComponent(0.9)
            button.backgroundColor = effectiveRating == rating ? color.withAlphaComponent(0.4) : UIColor.black.withAlphaComponent(0.6)
            button.layer.cornerRadius = buttonSize / 2
            
            button.layer.shadowColor = UIColor.black.cgColor
            button.layer.shadowOffset = CGSize(width: 0, height: 2)
            button.layer.shadowRadius = 4
            button.layer.shadowOpacity = 0.7
            
            button.tag = index
            button.isUserInteractionEnabled = true
            button.addTarget(coordinator, action: #selector(Coordinator.ratingButtonTapped(_:)), for: .touchUpInside)
            
            stackView.addArrangedSubview(button)
        }
        
        return containerView
    }
    
    private func createTitleOverlay(coordinator: Coordinator) -> UIView {
        let containerView = UIView()
        containerView.tag = OverlayTags.titleView
        containerView.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        containerView.layer.cornerRadius = 12
        
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.alignment = .center
        stackView.spacing = 4
        
        let titleLabel = UILabel()
        titleLabel.text = videoData.reopenContext?.title ?? formatVideoTitle()
        titleLabel.textColor = .white
        titleLabel.font = UIFont.boldSystemFont(ofSize: 18)
        titleLabel.textAlignment = .center

        if let reopenContext = videoData.reopenContext {
            let badgeLabel = UILabel()
            badgeLabel.text = reopenContext.badgeTitle.uppercased()
            badgeLabel.textColor = UIColor.systemTeal
            badgeLabel.font = UIFont.systemFont(ofSize: 11, weight: .semibold)
            badgeLabel.textAlignment = .center
            stackView.addArrangedSubview(badgeLabel)
        }

        let subtitleLabel = UILabel()
        subtitleLabel.text = formatVideoSubtitle()
        subtitleLabel.textColor = UIColor.white.withAlphaComponent(0.9)
        subtitleLabel.font = UIFont.systemFont(ofSize: 14)
        subtitleLabel.textAlignment = .center

        stackView.addArrangedSubview(titleLabel)
        stackView.addArrangedSubview(subtitleLabel)

        if let reopenContext = videoData.reopenContext {
            let contextLabel = UILabel()
            contextLabel.text = reopenContext.message
            contextLabel.textColor = UIColor.white.withAlphaComponent(0.82)
            contextLabel.font = UIFont.systemFont(ofSize: 12)
            contextLabel.textAlignment = .center
            contextLabel.numberOfLines = 0
            stackView.addArrangedSubview(contextLabel)

            if let compareActionTitle = reopenContext.playerComparisonActionTitle,
               onCompareSourceTake != nil {
                let compareButton = UIButton(type: .system)
                compareButton.setTitle(compareActionTitle, for: .normal)
                compareButton.setTitleColor(.white, for: .normal)
                compareButton.titleLabel?.font = UIFont.systemFont(ofSize: 12, weight: .semibold)
                compareButton.backgroundColor = UIColor.systemTeal.withAlphaComponent(0.22)
                compareButton.layer.cornerRadius = 14
                compareButton.contentEdgeInsets = UIEdgeInsets(top: 7, left: 12, bottom: 7, right: 12)
                compareButton.addTarget(coordinator, action: #selector(Coordinator.compareSourceButtonTapped), for: .touchUpInside)
                stackView.addArrangedSubview(compareButton)
            }
        }
        
        containerView.addSubview(stackView)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            stackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
            stackView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 8),
            stackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -8)
        ])
        
        return containerView
    }
}
