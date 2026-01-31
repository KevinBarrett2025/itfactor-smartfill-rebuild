import UIKit
import AVFoundation

/// Scroll-view based crop canvas mirroring professional editors:
/// the crop frame remains fixed while the video content pans/zooms underneath.
final class CropCanvasView: UIView {
    
    // MARK: - Public API
    
    var videoSize: CGSize = .zero {
        didSet { updateGeometry() }
    }
    
    var player: AVPlayer? {
        didSet { playerView.playerLayer.player = player }
    }
    
    var allowsTranslation: Bool = true {
        didSet { updateInteractionModes() }
    }
    
    var allowsScaling: Bool = true {
        didSet { updateInteractionModes() }
    }
    
    var allowsRotation: Bool = false {
        didSet { rotationGesture.isEnabled = allowsRotation }
    }
    
    var rotationDegrees: CGFloat = 0 {
        didSet { applyRotationTransform() }
    }
    
    var cropDidChange: ((CGRect) -> Void)?
    var rotationDidChange: ((CGFloat) -> Void)?
    var interactionBegan: (() -> Void)?
    var interactionEnded: (() -> Void)?
    
    func currentNormalizedCropRect() -> CGRect {
        guard scrollView.zoomScale > 0,
              videoSize.width > 0,
              videoSize.height > 0 else { return .zero }
        
        let scale = scrollView.zoomScale
        let visibleWidth = bounds.width / scale
        let visibleHeight = bounds.height / scale
        let originX = scrollView.contentOffset.x / scale
        let originY = scrollView.contentOffset.y / scale
        
        var rect = CGRect(
            x: originX / videoSize.width,
            y: originY / videoSize.height,
            width: visibleWidth / videoSize.width,
            height: visibleHeight / videoSize.height
        ).standardized
        
        rect.origin.x = max(0, min(1, rect.origin.x))
        rect.origin.y = max(0, min(1, rect.origin.y))
        rect.size.width = max(0, min(1 - rect.origin.x, rect.size.width))
        rect.size.height = max(0, min(1 - rect.origin.y, rect.size.height))
        return rect
    }
    
    func apply(normalizedCropRect rect: CGRect, animated: Bool) {
        guard videoSize.width > 0, videoSize.height > 0 else { return }
        let targetWidth = rect.width * videoSize.width
        let targetHeight = rect.height * videoSize.height
        guard targetWidth > 0, targetHeight > 0 else { return }
        
        let scaleX = bounds.width / targetWidth
        let scaleY = bounds.height / targetHeight
        let targetZoom = min(scrollView.maximumZoomScale, max(scrollView.minimumZoomScale, min(scaleX, scaleY)))
        
        let scaledWidth = videoSize.width * targetZoom
        let scaledHeight = videoSize.height * targetZoom
        
        let targetOffsetX = rect.origin.x * videoSize.width * targetZoom
        let targetOffsetY = rect.origin.y * videoSize.height * targetZoom
        
        let centeredOffset = CGPoint(
            x: targetOffsetX - (bounds.width - rect.width * videoSize.width * targetZoom) / 2,
            y: targetOffsetY - (bounds.height - rect.height * videoSize.height * targetZoom) / 2
        )
        let clampedOffset = clampContentOffset(centeredOffset, zoomScale: targetZoom, contentWidth: scaledWidth, contentHeight: scaledHeight)
        
        scrollView.setZoomScale(targetZoom, animated: animated)
        let applyOffset = {
            self.scrollView.contentOffset = clampedOffset
        }
        if animated {
            UIView.animate(withDuration: 0.25, animations: applyOffset)
        } else {
            applyOffset()
        }
    }
    
    func reset(animated: Bool) {
        guard scrollView.minimumZoomScale > 0 else { return }
        scrollView.setZoomScale(scrollView.minimumZoomScale, animated: animated)
        centerContent(animated: animated)
    }
    
    func setRotationDegrees(_ degrees: CGFloat, animated: Bool) {
        rotationDegrees = degrees
        if animated {
            UIView.animate(withDuration: 0.2) {
                self.applyRotationTransform()
            }
        } else {
            applyRotationTransform()
        }
    }
    
    // MARK: - Init
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        configureViewHierarchy()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureViewHierarchy()
    }
    
    // MARK: - Private properties
    
    private let scrollView: UIScrollView = {
        let scroll = UIScrollView()
        scroll.showsVerticalScrollIndicator = false
        scroll.showsHorizontalScrollIndicator = false
        scroll.bounces = true
        scroll.bouncesZoom = true
        scroll.minimumZoomScale = 1
        scroll.maximumZoomScale = 4
        scroll.clipsToBounds = false
        scroll.decelerationRate = .fast
        scroll.canCancelContentTouches = true
        scroll.scrollsToTop = false
        return scroll
    }()
    
    private let playerView = PlayerHostingView()
    private let overlayView = CropGridOverlayView()
    private lazy var rotationGesture: UIRotationGestureRecognizer = {
        let gesture = UIRotationGestureRecognizer(target: self, action: #selector(handleRotationGesture(_:)))
        gesture.isEnabled = allowsRotation
        return gesture
    }()
    private var rotationStartDegrees: CGFloat = 0
    
    // MARK: - Layout
    
    override func layoutSubviews() {
        super.layoutSubviews()
        scrollView.frame = bounds
        overlayView.frame = bounds
        updateGeometry()
    }
    
    private func configureViewHierarchy() {
        backgroundColor = .black
        scrollView.delegate = self
        addSubview(scrollView)
        scrollView.addSubview(playerView)
        addSubview(overlayView)
        addGestureRecognizer(rotationGesture)
        updateInteractionModes()
    }
    
    private func updateGeometry() {
        guard videoSize.width > 0,
              videoSize.height > 0,
              bounds.width > 0,
              bounds.height > 0 else { return }
        
        playerView.frame = CGRect(origin: .zero, size: videoSize)
        scrollView.contentSize = videoSize
        
        let widthScale = bounds.width / videoSize.width
        let heightScale = bounds.height / videoSize.height
        let minZoom = max(widthScale, heightScale)
        scrollView.minimumZoomScale = minZoom
        scrollView.maximumZoomScale = max(minZoom * 4, minZoom + 0.1)
        if scrollView.zoomScale != minZoom {
            scrollView.zoomScale = minZoom
        }
        centerContent(animated: false)
    }
    
    private func centerContent(animated: Bool) {
        guard scrollView.contentSize.width > 0,
              scrollView.contentSize.height > 0 else { return }
        
        let insetX = max(0, (bounds.width - scrollView.contentSize.width) / 2)
        let insetY = max(0, (bounds.height - scrollView.contentSize.height) / 2)
        scrollView.contentInset = UIEdgeInsets(top: insetY, left: insetX, bottom: insetY, right: insetX)
        let offset = CGPoint(
            x: -scrollView.contentInset.left,
            y: -scrollView.contentInset.top
        )
        if animated {
            UIView.animate(withDuration: 0.2) {
                self.scrollView.contentOffset = offset
            }
        } else {
            scrollView.contentOffset = offset
        }
    }
    
    private func clampContentOffset(_ offset: CGPoint, zoomScale: CGFloat, contentWidth: CGFloat, contentHeight: CGFloat) -> CGPoint {
        let maxOffsetX = max(0, contentWidth - bounds.width)
        let maxOffsetY = max(0, contentHeight - bounds.height)
        var clamped = offset
        clamped.x = min(max(-scrollView.contentInset.left, offset.x), maxOffsetX + scrollView.contentInset.right)
        clamped.y = min(max(-scrollView.contentInset.top, offset.y), maxOffsetY + scrollView.contentInset.bottom)
        return clamped
    }
    
    private func updateInteractionModes() {
        scrollView.isScrollEnabled = allowsTranslation
        scrollView.panGestureRecognizer.isEnabled = allowsTranslation
        scrollView.pinchGestureRecognizer?.isEnabled = allowsScaling
    }
    
    private func applyRotationTransform() {
        let radians = rotationDegrees * .pi / 180
        playerView.transform = CGAffineTransform(rotationAngle: radians)
    }
    
    @objc private func handleRotationGesture(_ gesture: UIRotationGestureRecognizer) {
        guard allowsRotation else { return }
        switch gesture.state {
        case .began:
            rotationStartDegrees = rotationDegrees
            interactionBegan?()
        case .changed:
            let delta = gesture.rotation * 180 / .pi
            rotationDegrees = rotationStartDegrees + delta
            rotationDidChange?(rotationDegrees)
        case .ended, .cancelled, .failed:
            interactionEnded?()
        default:
            break
        }
    }
}

// MARK: - UIScrollViewDelegate

extension CropCanvasView: UIScrollViewDelegate {
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        playerView
}
    
    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        centerContent(animated: false)
        cropDidChange?(currentNormalizedCropRect())
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        cropDidChange?(currentNormalizedCropRect())
    }
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        interactionBegan?()
    }
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate { interactionEnded?() }
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        interactionEnded?()
    }
    
    func scrollViewWillBeginZooming(_ scrollView: UIScrollView, with view: UIView?) {
        interactionBegan?()
    }
    
    func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
        interactionEnded?()
    }
}

// MARK: - Player Hosting View

private final class PlayerHostingView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }
    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
}

// MARK: - Overlay View

private final class CropGridOverlayView: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = .clear
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        isUserInteractionEnabled = false
        backgroundColor = .clear
    }
    
    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        context.setStrokeColor(UIColor.white.withAlphaComponent(0.45).cgColor)
        context.setLineWidth(1)
        context.stroke(bounds)
        
        context.setStrokeColor(UIColor.white.withAlphaComponent(0.25).cgColor)
        context.setLineWidth(0.8)
        
        let divisions = 3
        for index in 1..<divisions {
            let fraction = CGFloat(index) / CGFloat(divisions)
            let x = bounds.minX + bounds.width * fraction
            context.move(to: CGPoint(x: x, y: bounds.minY))
            context.addLine(to: CGPoint(x: x, y: bounds.maxY))
        }
        for index in 1..<divisions {
            let fraction = CGFloat(index) / CGFloat(divisions)
            let y = bounds.minY + bounds.height * fraction
            context.move(to: CGPoint(x: bounds.minX, y: y))
            context.addLine(to: CGPoint(x: bounds.maxX, y: y))
        }
        context.strokePath()
    }
}
