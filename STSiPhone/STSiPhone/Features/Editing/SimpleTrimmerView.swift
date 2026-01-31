import UIKit
import AVFoundation
import PryntTrimmerView

/// CLEAN NATIVE TRIMMER: Direct use of PryntTrimmerView without complex wrappers
/// This removes all our timing issues, deferred loading, and complex state management
/// Uses the library exactly as intended by its authors
final class SimpleTrimmerView: UIView {
    
    // MARK: - Native TrimmerView (Direct Usage)
    private let nativeTrimmer = TrimmerView()
    
    // MARK: - Rotation Detection
    private var lastKnownWidth: CGFloat = 0
    private var cachedDuration: CMTime?
    
    // MARK: - Simple Delegate Forwarding
    weak var delegate: TrimmerViewDelegate? {
        didSet {
            nativeTrimmer.delegate = delegate
            print("🔗 CLEAN DELEGATE: Assigned directly to native trimmer")
        }
    }
    
    // MARK: - Simple Property Forwarding
    var asset: AVAsset? {
        get { nativeTrimmer.asset }
        set {
            nativeTrimmer.asset = newValue
            cachedDuration = nil
            if let asset = newValue {
                Task { [weak self] in
                    let duration = (try? await asset.load(.duration)) ?? .zero
                    await MainActor.run {
                        self?.cachedDuration = duration
                    }
                }
            }
            // Track width when asset is set, but only if we have a valid size
            if bounds.width > 0 {
                lastKnownWidth = bounds.width
                print("📹 CLEAN ASSET: Assigned directly to native trimmer, width=\(lastKnownWidth)")
            } else {
                print("📹 CLEAN ASSET: Assigned but no width available yet")
            }
        }
    }
    
    var startTime: CMTime? { nativeTrimmer.startTime }
    var endTime: CMTime? { nativeTrimmer.endTime }
    
    var handleColor: UIColor {
        get { nativeTrimmer.handleColor }
        set { nativeTrimmer.handleColor = newValue }
    }
    
    var mainColor: UIColor {
        get { nativeTrimmer.mainColor }
        set { nativeTrimmer.mainColor = newValue }
    }
    
    var positionBarColor: UIColor {
        get { nativeTrimmer.positionBarColor }
        set { nativeTrimmer.positionBarColor = newValue }
    }
    
    var minDuration: Double {
        get { nativeTrimmer.minDuration }
        set { nativeTrimmer.minDuration = newValue }
    }
    
    // MARK: - Simple Initialization
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupNativeTrimmer()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupNativeTrimmer()
    }
    
    private func setupNativeTrimmer() {
        // Add native trimmer directly
        addSubview(nativeTrimmer)
        nativeTrimmer.translatesAutoresizingMaskIntoConstraints = false
        
        // Simple constraints
        NSLayoutConstraint.activate([
            nativeTrimmer.topAnchor.constraint(equalTo: topAnchor),
            nativeTrimmer.leadingAnchor.constraint(equalTo: leadingAnchor),
            nativeTrimmer.trailingAnchor.constraint(equalTo: trailingAnchor),
            nativeTrimmer.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        
        // Apply STS theme colors
        nativeTrimmer.handleColor = UIColor(red: 0.6, green: 0.2, blue: 0.8, alpha: 1.0)
        nativeTrimmer.mainColor = UIColor(red: 0.8, green: 0.3, blue: 0.7, alpha: 0.8)
        nativeTrimmer.positionBarColor = UIColor.systemOrange
        
        print("✅ CLEAN SETUP: Native trimmer configured with STS colors")
    }
    
    // MARK: - Rotation Detection & Thumbnail Regeneration
    override func layoutSubviews() {
        super.layoutSubviews()
        
        // Check if width changed significantly (rotation detection)
        let currentWidth = bounds.width
        let widthChanged = abs(currentWidth - lastKnownWidth) > 50 // 50pt threshold for rotation
        let hasAsset = nativeTrimmer.asset != nil
        
        print("🔍 ROTATION DEBUG: currentWidth=\(currentWidth), lastKnownWidth=\(lastKnownWidth), widthChanged=\(widthChanged), hasAsset=\(hasAsset)")
        
        if widthChanged && currentWidth > 0 && hasAsset {
            print("🔄 ROTATION DETECTED: Width changed from \(lastKnownWidth) to \(currentWidth)")
            print("🎬 REGENERATING THUMBNAILS: Refreshing trimmer for new width")
            
            regenerateThumbnails()
            lastKnownWidth = currentWidth
        } else if lastKnownWidth == 0 {
            // Initialize lastKnownWidth if not set
            lastKnownWidth = currentWidth
            print("📏 WIDTH INITIALIZED: Set lastKnownWidth to \(currentWidth)")
        }
    }
    
    private func regenerateThumbnails() {
        guard nativeTrimmer.asset != nil else { return }
        nativeTrimmer.regenerateThumbnails()
        print("✅ THUMBNAILS REGENERATED: Updated without asset reset")
    }
    
    private func getCurrentPlayheadTime() -> CMTime? {
        // Try to get current time from the delegate (if it's the main editor)
        if let delegate = delegate as? LightweightEditorViewController {
            return delegate.player?.currentTime()
        }
        return nil
    }
    
    // MARK: - Simple Methods
    func seek(to time: CMTime) {
        nativeTrimmer.seek(to: time)
    }

    func updatePlayheadUI(to time: CMTime) {
        nativeTrimmer.seek(to: time)
    }

    func time(for locationInSelf: CGPoint) -> CMTime? {
        guard let scrollView = assetPreviewScrollView(),
              let duration = cachedDuration,
              duration.seconds > 0 else { return nil }
        let locationInScroll = convert(locationInSelf, to: scrollView)
        let contentX = locationInScroll.x + scrollView.contentOffset.x
        let contentWidth = max(scrollView.contentSize.width, 1)
        let ratio = max(0, min(1, contentX / contentWidth))
        let seconds = Double(ratio) * duration.seconds
        return CMTime(seconds: seconds, preferredTimescale: duration.timescale)
    }

    func handlePositions() -> (startX: CGFloat, endX: CGFloat)? {
        guard let scrollView = assetPreviewScrollView(),
              let start = nativeTrimmer.startTime,
              let end = nativeTrimmer.endTime,
              let duration = cachedDuration,
              duration.seconds > 0 else { return nil }
        let contentWidth = max(scrollView.contentSize.width, 1)
        let startRatio = CGFloat(start.seconds / duration.seconds)
        let endRatio = CGFloat(end.seconds / duration.seconds)
        let startContentX = startRatio * contentWidth
        let endContentX = endRatio * contentWidth
        let startVisibleX = startContentX - scrollView.contentOffset.x + scrollView.frame.minX
        let endVisibleX = endContentX - scrollView.contentOffset.x + scrollView.frame.minX
        return (startVisibleX, endVisibleX)
    }

    private func assetPreviewScrollView() -> UIScrollView? {
        findScrollView(in: nativeTrimmer)
    }

    private func findScrollView(in view: UIView) -> UIScrollView? {
        if let scrollView = view as? UIScrollView {
            return scrollView
        }
        for subview in view.subviews {
            if let found = findScrollView(in: subview) {
                return found
            }
        }
        return nil
    }
    
    // MARK: - Fixed Height for Layout
    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: 60)
    }
}
