import UIKit
import AVKit
import ObjectiveC

final class ZoomableAVPlayerHostViewController: UIViewController, UIScrollViewDelegate {

    let scrollView = UIScrollView()
    let contentContainer = UIView()
    let overlayContainer = PassthroughOverlayView()
    var explicitSafeAreaInsets: UIEdgeInsets?
    
    private lazy var doubleTapRecognizer: UITapGestureRecognizer = {
        let recognizer = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        recognizer.numberOfTapsRequired = 2
        recognizer.cancelsTouchesInView = true
        return recognizer
    }()

    let chromeContainer: ChromeInsetContainerViewController
    var playerViewController: AVPlayerViewController { chromeContainer.playerViewController }

    init(chromeContainer: ChromeInsetContainerViewController) {
        self.chromeContainer = chromeContainer
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .black
        view.clipsToBounds = false

        scrollView.delegate = self
        scrollView.minimumZoomScale = 1.0
        scrollView.maximumZoomScale = 4.0
        scrollView.zoomScale = 1.0
        scrollView.clipsToBounds = false
        scrollView.bouncesZoom = true
        scrollView.bounces = true
        scrollView.alwaysBounceVertical = false
        scrollView.alwaysBounceHorizontal = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.decelerationRate = .fast
        scrollView.backgroundColor = .black
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.panGestureRecognizer.minimumNumberOfTouches = 2
        scrollView.delaysContentTouches = false
        scrollView.canCancelContentTouches = true

        view.addSubview(scrollView)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        scrollView.addSubview(contentContainer)
        contentContainer.clipsToBounds = false
        contentContainer.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            contentContainer.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentContainer.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentContainer.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentContainer.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentContainer.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
            contentContainer.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor)
        ])

        addChild(chromeContainer)
        contentContainer.addSubview(chromeContainer.view)
        chromeContainer.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            chromeContainer.view.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
            chromeContainer.view.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
            chromeContainer.view.topAnchor.constraint(equalTo: contentContainer.topAnchor),
            chromeContainer.view.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor)
        ])
        chromeContainer.didMove(toParent: self)

        overlayContainer.backgroundColor = .clear
        overlayContainer.isUserInteractionEnabled = false
        overlayContainer.alpha = 0
        view.addSubview(overlayContainer)
        overlayContainer.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            overlayContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            overlayContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            overlayContainer.topAnchor.constraint(equalTo: view.topAnchor),
            overlayContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        overlayContainer.addGestureRecognizer(doubleTapRecognizer)
        print("✅ ZoomableAVPlayerHostViewController active (min=\(scrollView.minimumZoomScale) max=\(scrollView.maximumZoomScale))")
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Forward parent safe-area to embedded player so native controls (AirPlay/speaker/fullscreen)
        // are positioned correctly in portrait/landscape even inside the scroll view.
        let parentInsets = explicitSafeAreaInsets ?? view.safeAreaInsets
        if let overlay = playerViewController.contentOverlayView {
            overlay.layoutMargins = UIEdgeInsets(top: parentInsets.top, left: parentInsets.left, bottom: parentInsets.bottom, right: parentInsets.right)
            overlay.insetsLayoutMarginsFromSafeArea = false
        }
#if DEBUG
        debugLogHostLayout(context: "viewDidLayoutSubviews")
#endif
    }

    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
#if DEBUG
        debugLogHostLayout(context: "viewSafeAreaInsetsDidChange")
#endif
    }

#if DEBUG
    private var lastLayoutDebugSignature: String? {
        get { objc_getAssociatedObject(self, &AssociatedKeys.layoutSignatureKey) as? String }
        set { objc_setAssociatedObject(self, &AssociatedKeys.layoutSignatureKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    private func debugLogHostLayout(context: String) {
        let hostSafe = view.safeAreaInsets
        let playerSafe = playerViewController.view.safeAreaInsets
        let additional = chromeContainer.additionalSafeAreaInsets
        let signature = "\(context)-\(Int(view.bounds.width))x\(Int(view.bounds.height))-\(Int(hostSafe.top))\(Int(hostSafe.left))\(Int(hostSafe.bottom))\(Int(hostSafe.right))-\(Int(playerSafe.top))\(Int(playerSafe.left))\(Int(playerSafe.bottom))\(Int(playerSafe.right))-\(Int(additional.top))\(Int(additional.left))\(Int(additional.bottom))\(Int(additional.right))"
        guard signature != lastLayoutDebugSignature else { return }
        lastLayoutDebugSignature = signature

        print("🧭 AVKitHost[\(context)] host bounds=\(view.bounds) safe=\(hostSafe)")
        print("🧭 AVKitHost[\(context)] scroll bounds=\(scrollView.bounds) safe=\(scrollView.safeAreaInsets) clips=\(scrollView.clipsToBounds)")
        print("🧭 AVKitHost[\(context)] content bounds=\(contentContainer.bounds) safe=\(contentContainer.safeAreaInsets) clips=\(contentContainer.clipsToBounds)")
        print("🧭 AVKitHost[\(context)] player frame=\(playerViewController.view.frame) bounds=\(playerViewController.view.bounds)")
        print("🧭 AVKitHost[\(context)] player safe=\(playerSafe) containerAdditional=\(additional) clips=\(playerViewController.view.clipsToBounds) masks=\(playerViewController.view.layer.masksToBounds)")
    }

    private struct AssociatedKeys {
        static var layoutSignatureKey: UInt8 = 0
    }
#endif

    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        contentContainer
    }

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        let scale = scrollView.zoomScale
        print("🔍 ZoomableVideo: zoomScale=\(scale)")
        NotificationCenter.default.post(
            name: Notification.Name("STSZoomScaleChanged"),
            object: nil,
            userInfo: ["scale": scale]
        )
    }
    
    @objc private func handleDoubleTap(_ recognizer: UITapGestureRecognizer) {
        let current = scrollView.zoomScale
        let next = min(scrollView.maximumZoomScale, max(scrollView.minimumZoomScale, current * 1.10))
        let target = (abs(current - scrollView.maximumZoomScale) < 0.01) ? 1.0 : next
        let tapPoint = recognizer.location(in: contentContainer)
        zoom(to: tapPoint, scale: target, animated: true)
    }
    
    private func zoom(to point: CGPoint, scale: CGFloat, animated: Bool) {
        let clampedScale = min(max(scale, scrollView.minimumZoomScale), scrollView.maximumZoomScale)
        
        let size = scrollView.bounds.size
        let width = size.width / clampedScale
        let height = size.height / clampedScale
        
        let originX = point.x - (width / 2.0)
        let originY = point.y - (height / 2.0)
        
        let rect = CGRect(x: originX, y: originY, width: width, height: height)
        scrollView.zoom(to: rect, animated: animated)
    }

    func resetZoom(animated: Bool = true) {
        let block = { self.scrollView.setZoomScale(1.0, animated: animated) }
        if Thread.isMainThread {
            block()
        } else {
            DispatchQueue.main.async { block() }
        }
    }

}
