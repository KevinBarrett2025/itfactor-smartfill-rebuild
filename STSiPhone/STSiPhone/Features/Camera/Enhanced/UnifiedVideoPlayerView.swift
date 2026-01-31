import SwiftUI
import Foundation
import AVFoundation
import AVKit
import CoreGraphics
import UIKit

// ENHANCED: Video player context for different use cases
public enum VideoPlayerContext {
    case fullscreenPlayer
    case takePreview
    case sessionReview
    case export
}

// CRITICAL FIX: Enhanced AVPlayerViewController with Orientation Management - MADE PUBLIC
public class EnhancedAVPlayerViewController: AVPlayerViewController {
    var coordinator: CustomAVPlayerViewController.Coordinator?
    var videoData: VideoPlayerDisplayData?
    private var timeControlObserver: NSKeyValueObservation?
    private var chromeTapRecognizer: UITapGestureRecognizer?
    private var chromeRevealObserver: NSObjectProtocol?
    
    // ORIENTATION FIX: Add orientation management
    private var orientationManager: VideoOrientationManager?
    
    // CRITICAL FIX: Add video lifecycle management - FIXED: Default to true for normal playback
    public var isCurrentlyVisible: Bool = true {
        didSet {
            handleVisibilityChange()
        }
    }
    
    private var lastLoggedOrientation: UIDeviceOrientation = .unknown
    private var lastPlayerLayerFrame: CGRect = .zero
    
    // CRITICAL FIX: Flag to track if this is part of swipeable video collection
    public var isPartOfSwipeableCollection: Bool = false
    
    // NEW: Track control visibility with timer-based approach
    private var controlVisibilityTimer: Timer?
    private var lastControlsVisible: Bool = true
    public var onControlVisibilityChanged: ((Bool) -> Void)?
    private var hasLoggedTransportHierarchy = false
#if DEBUG
    private var lastLayoutDebugSignature: String?
#endif
    private var playbackInsetsForChrome = EdgeInsets()
    private var lastAppliedChromeTopInset: CGFloat = -1
    private var externalSafeAreaInsets: UIEdgeInsets = .zero
    private var lastAppliedCombinedInsets: UIEdgeInsets = UIEdgeInsets(top: -1, left: -1, bottom: -1, right: -1)
    private let landscapeChromeTopInset: CGFloat = 18
    private let landscapeTopThreshold: CGFloat = 12
    @available(iOS 17.0, *)
    private var traitChangeRegistration: UITraitChangeRegistration?

    // CRITICAL FIX: Handle visibility changes to manage playback - REFINED logic
    private func handleVisibilityChange() {
        // CRITICAL FIX: Only apply visibility logic if part of a swipeable collection
        guard isPartOfSwipeableCollection else { return }
        
        guard let player = self.player else { return }
        
        if isCurrentlyVisible {
            // Don't auto-play when becoming visible - let user control playback
            print("📱 Video now visible - waiting for user to play")
        } else {
            // Pause playback when no longer visible (only if playing)
            if player.rate > 0 {
                print("⏸️ Pausing video playback - no longer visible")
                player.pause()
            }
        }
    }
    
    // CRITICAL FIX: Add method to force pause (for immediate stopping)
    public func pauseVideo() {
        player?.pause()
        print("⏹️ Force paused video")
    }
    
    // CRITICAL FIX: Add method to resume video
    public func resumeVideo() {
        guard let player = player, player.currentItem != nil else { return }
        player.play()
        print("▶️ Resumed video playback")
    }
    
    // NEW: Setup control visibility monitoring with timer-based detection
    public func setupControlVisibilityMonitoring() {
        // Start timer to periodically check control visibility
        controlVisibilityTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.checkControlVisibility()
        }
        
        print("🎮 Setup control visibility monitoring with timer approach")
    }
    
    // NEW: Check if controls are currently visible using view hierarchy
    private func checkControlVisibility() {
        let controlsVisible = areControlsVisible()
        
        if controlsVisible != lastControlsVisible {
            lastControlsVisible = controlsVisible
            DispatchQueue.main.async {
                self.onControlVisibilityChanged?(controlsVisible)
            }
        }
    }
    
    // NEW: Detect if controls are visible by examining view hierarchy
    private func areControlsVisible() -> Bool {
        // Look for transport controls view in the view hierarchy
        return findTransportControlsView(in: view) != nil
    }
    
    // NEW: Recursively find transport controls view
    private func findTransportControlsView(in view: UIView) -> UIView? {
        // Check if this view or its subviews contain transport controls
        for subview in view.subviews {
            let className = String(describing: type(of: subview))
            
            // Look for AVKit transport controls
            if className.contains("Transport") ||
               className.contains("Controls") ||
               className.contains("Playback") {
                // Check if it's actually visible (not hidden and has alpha > 0)
                if !subview.isHidden && subview.alpha > 0.1 {
                    logTransportHierarchyOnce(startingAt: subview)
                    return subview
                }
            }
            
            // Recursively search subviews
            if let found = findTransportControlsView(in: subview) {
                return found
            }
        }
        
        return nil
    }

    private func logTransportHierarchyOnce(startingAt view: UIView) {
        guard !hasLoggedTransportHierarchy else { return }
        hasLoggedTransportHierarchy = true
        let fileName: String
        if let take = videoData?.take {
            let path = take.effectiveFilePath
            fileName = URL(fileURLWithPath: path).lastPathComponent
        } else {
            fileName = "unknown"
        }
        print("🎛️ AVPlayer chrome hierarchy for \(fileName)")
        logTransportHierarchy(view, indent: "")
    }
    
    private func logTransportHierarchy(_ view: UIView, indent: String) {
        let className = String(describing: type(of: view))
        let frameDescription = NSCoder.string(for: view.frame)
        let alphaDescription = String(format: "%.2f", view.alpha)
        let visibility = view.isHidden ? "hidden" : "visible"
        print("\(indent)• \(className) frame=\(frameDescription) alpha=\(alphaDescription) \(visibility)")
        
        if let button = view as? UIButton {
            let title = button.currentTitle?.isEmpty == false ? button.currentTitle! : "no-title"
            let imageDesc = button.currentImage != nil ? "hasImage" : "noImage"
            print("\(indent)  ↳ UIButton type=\(button.buttonType.rawValue) title=\(title) \(imageDesc)")
        }
        
        for subview in view.subviews {
            logTransportHierarchy(subview, indent: indent + "  ")
        }
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        if #available(iOS 16.0, *) {
            allowsVideoFrameAnalysis = false
        }
        observePlayerState()
        installChromeTapRecognizer()
        chromeRevealObserver = NotificationCenter.default.addObserver(
            forName: .stsMediaChromeRevealRequested,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.showsPlaybackControls = true
        }
#if DEBUG
        if #available(iOS 17.0, *) {
            traitChangeRegistration = registerForTraitChanges([UITraitHorizontalSizeClass.self, UITraitVerticalSizeClass.self]) { [weak self] (_: EnhancedAVPlayerViewController, _: UITraitCollection) in
                self?.applyChromeInsetsIfNeeded()
                self?.debugLogLayout(context: "traitChange")
            }
        }
#else
        if #available(iOS 17.0, *) {
            traitChangeRegistration = registerForTraitChanges([UITraitHorizontalSizeClass.self, UITraitVerticalSizeClass.self]) { [weak self] (_: EnhancedAVPlayerViewController, _: UITraitCollection) in
                self?.applyChromeInsetsIfNeeded()
            }
        }
#endif
    }
    
    public override var player: AVPlayer? {
        didSet {
            observePlayerState()
        }
    }
    
    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        handleOrientationChange()
        applyChromeInsetsIfNeeded()
        coordinator?.updateRatingsVerticalPlacement(
            isLandscape: view.bounds.width > view.bounds.height,
            reason: "viewDidLayoutSubviews",
            playerView: view,
            overlayView: contentOverlayView
        )
#if DEBUG
        debugLogLayout(context: "viewDidLayoutSubviews")
#endif
    }

    public override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        applyChromeInsetsIfNeeded()
        coordinator?.updateRatingsVerticalPlacement(
            isLandscape: view.bounds.width > view.bounds.height,
            reason: "safeAreaInsetsDidChange",
            playerView: view,
            overlayView: contentOverlayView
        )
#if DEBUG
        debugLogLayout(context: "viewSafeAreaInsetsDidChange")
#endif
    }
    
    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        setupOrientationHandling()
    }
    
    public override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        cleanupOrientationHandling()
        
        // Clean up control visibility timer
        controlVisibilityTimer?.invalidate()
        controlVisibilityTimer = nil
    }

    public func updateChromeInsets(using playbackInsets: EdgeInsets) {
        playbackInsetsForChrome = playbackInsets
        applyChromeInsetsIfNeeded()
    }

    public func updateExternalSafeAreaInsets(_ insets: UIEdgeInsets) {
        guard !insets.isApproximatelyEqual(to: externalSafeAreaInsets) else { return }
        externalSafeAreaInsets = insets
        applyChromeInsetsIfNeeded()
    }

    private func applyChromeInsetsIfNeeded() {
        let topInset = computeChromeTopInset()
        let combined = UIEdgeInsets(
            top: externalSafeAreaInsets.top + topInset,
            left: externalSafeAreaInsets.left,
            bottom: externalSafeAreaInsets.bottom,
            right: externalSafeAreaInsets.right
        )
        guard !combined.isApproximatelyEqual(to: lastAppliedCombinedInsets) else { return }
        lastAppliedCombinedInsets = combined
        lastAppliedChromeTopInset = topInset
        additionalSafeAreaInsets = combined
    }

    private func computeChromeTopInset() -> CGFloat {
        let size = view.bounds.size
        let isLandscape = size.width > size.height
        let hasLandscapeNotch = playbackInsetsForChrome.leading > 0 || playbackInsetsForChrome.trailing > 0
        let topIsZeroish = playbackInsetsForChrome.top <= landscapeTopThreshold
        guard isLandscape, hasLandscapeNotch, topIsZeroish else { return 0 }
        return landscapeChromeTopInset
    }

#if DEBUG
    private func debugLogLayout(context: String) {
        let safeInsets = view.safeAreaInsets
        let additionalInsets = additionalSafeAreaInsets
        let frame = view.frame
        let bounds = view.bounds
        let superBounds = view.superview?.bounds ?? .zero
        let signature = "\(context)-\(Int(frame.width))x\(Int(frame.height))-\(Int(bounds.width))x\(Int(bounds.height))-\(Int(safeInsets.top))\(Int(safeInsets.left))\(Int(safeInsets.bottom))\(Int(safeInsets.right))-\(Int(additionalInsets.top))\(Int(additionalInsets.left))\(Int(additionalInsets.bottom))\(Int(additionalInsets.right))"
        guard signature != lastLayoutDebugSignature else { return }
        lastLayoutDebugSignature = signature

        print("🧭 AVKitLayout[\(context)] frame=\(frame) bounds=\(bounds)")
        print("🧭 AVKitLayout[\(context)] safeArea=\(safeInsets) additional=\(additionalInsets)")
        print("🧭 AVKitLayout[\(context)] superviewBounds=\(superBounds)")

        logSuperviewChain(startingAt: view, context: context)
    }

    private func logSuperviewChain(startingAt view: UIView, context: String) {
        var current: UIView? = view
        var depth = 0
        while let node = current, depth < 12 {
            let className = String(describing: type(of: node))
            let frameDesc = NSCoder.string(for: node.frame)
            let boundsDesc = NSCoder.string(for: node.bounds)
            let safeInsets = node.safeAreaInsets
            let clips = node.clipsToBounds
            let masksToBounds = node.layer.masksToBounds
            let cornerRadius = node.layer.cornerRadius
            let hasMask = node.layer.mask != nil
            print("🧭 AVKitChain[\(context)] \(depth): \(className) frame=\(frameDesc) bounds=\(boundsDesc) safe=\(safeInsets) clips=\(clips) masksToBounds=\(masksToBounds) cornerRadius=\(cornerRadius) mask=\(hasMask)")
            current = node.superview
            depth += 1
        }
    }
#endif
    
    // RESTORE: Orientation handling that was making landscape work
    private func setupOrientationHandling() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(deviceOrientationChanged),
            name: UIDevice.orientationDidChangeNotification,
            object: nil
        )
    }
    
    private func cleanupOrientationHandling() {
        NotificationCenter.default.removeObserver(
            self,
            name: UIDevice.orientationDidChangeNotification,
            object: nil
        )
    }
    
    @objc private func deviceOrientationChanged() {
        DispatchQueue.main.async {
            self.handleOrientationChange()
        }
    }
    
    // RESTORE: Handle orientation changes with proper frame updates
    private func handleOrientationChange() {
        let frameChanged = updateVideoLayerForCurrentOrientation()
        let orientation = UIDevice.current.orientation
        
        if orientation.isValidInterfaceOrientation && orientation != lastLoggedOrientation {
            lastLoggedOrientation = orientation
            print("🔄 Orientation changed to: \(orientationDescription(orientation))")
            coordinator?.updateRatingsVerticalPlacement(
                isLandscape: view.bounds.width > view.bounds.height,
                reason: "rotation",
                playerView: view,
                overlayView: contentOverlayView
            )
        } else if frameChanged {
            print("📐 Updated player layer frame to: \(view.bounds)")
        }
    }
    
    private func orientationDescription(_ orientation: UIDeviceOrientation) -> String {
        switch orientation {
        case .portrait: return "Portrait"
        case .landscapeLeft: return "Landscape Left"
        case .landscapeRight: return "Landscape Right"
        case .portraitUpsideDown: return "Portrait Upside Down"
        case .faceUp: return "Face Up"
        case .faceDown: return "Face Down"
        default: return "Unknown"
        }
    }
    
    // RESTORE: Update video layer frame for current orientation
    @discardableResult
    func updateVideoLayerForCurrentOrientation() -> Bool {
        guard let playerLayer = getPlayerLayer() else { return false }
        
        let targetFrame = view.bounds
        if lastPlayerLayerFrame.equalTo(targetFrame) {
            return false
        }
        lastPlayerLayerFrame = targetFrame
        playerLayer.frame = targetFrame
        return true
    }
    
    // RESTORE: Get player layer for frame updates
    private func getPlayerLayer() -> AVPlayerLayer? {
        return findPlayerLayerInView(view)
    }
    
    private func findPlayerLayerInView(_ view: UIView) -> AVPlayerLayer? {
        if let playerLayer = view.layer as? AVPlayerLayer {
            return playerLayer
        }
        
        if let sublayers = view.layer.sublayers {
            for sublayer in sublayers {
                if let playerLayer = sublayer as? AVPlayerLayer {
                    return playerLayer
                }
            }
        }
        
        for subview in view.subviews {
            if let playerLayer = findPlayerLayerInView(subview) {
                return playerLayer
            }
        }
        
        return nil
    }

    private func observePlayerState() {
        timeControlObserver?.invalidate()
        guard let player = player else { return }
        timeControlObserver = player.observe(\.timeControlStatus, options: [.new]) { [weak self] player, _ in
            guard let self = self else { return }
            let isPlaying = player.timeControlStatus == .playing
            DispatchQueue.main.async {
                self.showsPlaybackControls = !isPlaying
                self.onControlVisibilityChanged?( !isPlaying )
                NotificationCenter.default.post(
                    name: .stsMediaPlaybackStateChanged,
                    object: nil,
                    userInfo: ["isPlaying": isPlaying]
                )
            }
        }
    }

    private func installChromeTapRecognizer() {
        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(handlePlayerTap(_:)))
        tapRecognizer.cancelsTouchesInView = false
        view.addGestureRecognizer(tapRecognizer)
        chromeTapRecognizer = tapRecognizer
    }

    @objc private func handlePlayerTap(_ recognizer: UITapGestureRecognizer) {
        if let player = player {
            if player.timeControlStatus == .playing {
                player.pause()
            }
        }
        NotificationCenter.default.post(name: .stsMediaChromeRevealRequested, object: nil)
        showsPlaybackControls = true
    }
    
    deinit {
        timeControlObserver?.invalidate()
        if let chromeRevealObserver {
            NotificationCenter.default.removeObserver(chromeRevealObserver)
        }
        if let chromeTapRecognizer {
            view.removeGestureRecognizer(chromeTapRecognizer)
        }
    }
}

struct UnifiedVideoPlayerView: UIViewControllerRepresentable {
    let url: URL?
    let context: VideoPlayerContext
    @Environment(\.playbackSafeAreaInsets) private var playbackSafeAreaInsets
    
    // BACKWARD COMPATIBILITY: Support direct URL initialization
    init(url: URL) {
        self.url = url
        self.context = .takePreview
    }
    
    // ENHANCED: Context-aware initialization
    init(context: VideoPlayerContext, url: URL? = nil) {
        self.context = context
        self.url = url
    }

    func makeUIViewController(context: Context) -> ChromeInsetContainerViewController {
        let avPlayerVC = EnhancedAVPlayerViewController()
        if #available(iOS 16.0, *) {
            avPlayerVC.allowsVideoFrameAnalysis = false
        }
        
        // Use URL if provided directly, otherwise get from VideoPlayerService
        let playerURL = url ?? VideoPlayerService.shared.currentURL
        
        if let validURL = playerURL {
            // RESEARCH-BASED FIX: Let AVPlayerViewController handle orientation naturally
            setupPlayerNaturally(avPlayerVC, videoURL: validURL)
        }
        
        avPlayerVC.showsPlaybackControls = true
        
        // ORIENTATION FIX: Use resizeAspect for natural aspect ratios with proper orientation handling
        avPlayerVC.videoGravity = .resizeAspect
        avPlayerVC.allowsPictureInPicturePlayback = true
        
        // Context-specific configurations
        switch self.context {
        case .fullscreenPlayer:
            avPlayerVC.modalPresentationStyle = .fullScreen
            avPlayerVC.showsPlaybackControls = true
        case .takePreview:
            avPlayerVC.showsPlaybackControls = true
        case .sessionReview:
            avPlayerVC.showsPlaybackControls = true
            avPlayerVC.allowsPictureInPicturePlayback = false
        case .export:
            avPlayerVC.showsPlaybackControls = false
            avPlayerVC.allowsPictureInPicturePlayback = false
        }
        
        print("✅ UnifiedVideoPlayerView: Configured EnhancedAVPlayerViewController with natural orientation handling")
        let container = ChromeInsetContainerViewController(playerViewController: avPlayerVC)
        container.updatePlaybackInsets(playbackSafeAreaInsets)
        return container
    }
    
    func updateUIViewController(_ controller: ChromeInsetContainerViewController, context: Context) {
        controller.updatePlaybackInsets(playbackSafeAreaInsets)
        let playerController = controller.playerViewController as? EnhancedAVPlayerViewController
        // Update player URL if it changes from VideoPlayerService
        if let playerController,
           url == nil,
           let newURL = VideoPlayerService.shared.currentURL,
           playerController.player?.currentItem?.asset != AVURLAsset(url: newURL) {
            
            // RESEARCH-BASED FIX: Use natural setup on updates too
            setupPlayerNaturally(playerController, videoURL: newURL)
            print("🔄 UnifiedVideoPlayerView: Updated player with new URL using natural approach")
        }
        
    }
    
    // RESEARCH-BASED FIX: Natural setup without forcing video composition
    private func setupPlayerNaturally(_ playerViewController: EnhancedAVPlayerViewController, videoURL: URL) {
        // Simply create AVPlayer with URL - let AVPlayerViewController handle orientation
        let player = AVPlayer(url: videoURL)
        playerViewController.player = player
        
        print("✅ UnifiedVideoPlayerView: Set up player naturally - letting AVPlayerViewController handle orientation automatically")
        print("   💡 Research finding: AVPlayerViewController respects video rotation metadata without composition")
    }

    private func uiInsets(from edgeInsets: EdgeInsets) -> UIEdgeInsets {
        UIEdgeInsets(top: edgeInsets.top,
                     left: edgeInsets.leading,
                     bottom: edgeInsets.bottom,
                     right: edgeInsets.trailing)
    }
}

// MARK: - VideoPlayerService Integration
extension VideoPlayerService {
}

private extension UIEdgeInsets {
    func isApproximatelyEqual(to other: UIEdgeInsets, epsilon: CGFloat = 0.5) -> Bool {
        abs(top - other.top) <= epsilon
            && abs(left - other.left) <= epsilon
            && abs(bottom - other.bottom) <= epsilon
            && abs(right - other.right) <= epsilon
    }
}

// MARK: - Preview
#Preview {
    if let sampleURL = Bundle.main.url(forResource: "sample_video", withExtension: "mp4") {
        UnifiedVideoPlayerView(url: sampleURL)
    } else {
        Text("No sample video available")
            .foregroundColor(.gray)
    }
}
