import UIKit
import AVFoundation
import TOCropViewController
import PryntTrimmerView

@MainActor
protocol CropToolHandling: AnyObject {
    var onEvent: ((CoordinatorEvent) -> Void)? { get set }
    func present(from host: UIViewController, frameImage: UIImage, at time: CMTime)
    func presentPhoto(from host: UIViewController, frameImage: UIImage, at time: CMTime)
    func presentVideo(from host: UIViewController, asset: AVAsset)
}

@MainActor
final class CropToolController: NSObject, CropToolHandling {
    var onEvent: ((CoordinatorEvent) -> Void)?
    
    // Store source sizing details so we can normalize crop coordinates correctly after presentation
    private var currentPhotoSourceSize: CGSize?
    private lazy var delegateProxy = TOCropDelegateProxy(owner: self)
    
    // MARK: - Unified Presentation Interface
    
    func present(from host: UIViewController, frameImage: UIImage, at time: CMTime) {
        // Legacy interface - will be deprecated
        presentPhoto(from: host, frameImage: frameImage, at: time)
    }
    
    // MARK: - Asset-Specific Presentation Methods
    
    func presentPhoto(from host: UIViewController, frameImage: UIImage, at time: CMTime) {
        print("📷 CROP TOOL: Using TOCropViewController for photo asset")
        
        currentPhotoSourceSize = frameImage.size
        
        let cropVC = TOCropViewController(image: frameImage)
        cropVC.delegate = delegateProxy
        cropVC.modalPresentationStyle = .fullScreen
        cropVC.aspectRatioPreset = .presetOriginal
        cropVC.aspectRatioLockEnabled = false
        cropVC.resetAspectRatioEnabled = true
        cropVC.rotateButtonsHidden = false
        
        // Store time for later reference
        cropVC.view.accessibilityLabel = "crop_time_\(time.seconds)"
        
        host.present(cropVC, animated: true) {
            print("✅ PHOTO CROP: Presented TOCropViewController")
        }
    }
    
    func presentVideo(from host: UIViewController, asset: AVAsset) {
        print("🛑 VIDEO CROP (legacy) disabled: use enterprise editor crop instead")
        // Intentionally no-op; all video cropping is handled by the enterprise editor surface.
    }
    
}

// MARK: - Crop Handling

@MainActor
private extension CropToolController {
    func handleDidCrop(_ cropViewController: TOCropViewController,
                       image: UIImage,
                       cropRect: CGRect,
                       angle: Int) {
        print("✅ PHOTO CROP: Crop completed - rect: \(cropRect), angle: \(angle)")
        
        let timeString = cropViewController.view.accessibilityLabel?.replacingOccurrences(of: "crop_time_", with: "") ?? "0"
        _ = CMTime(seconds: Double(timeString) ?? 0, preferredTimescale: 600)
        
        let originalSize: CGSize
        if let storedSize = currentPhotoSourceSize {
            originalSize = storedSize
        } else {
            let controllerSize = cropViewController.image.size
            originalSize = controllerSize
            print("⚠️ PHOTO CROP: Missing stored source size, falling back to controller image size \(controllerSize)")
        }
        
        guard originalSize.width > 0, originalSize.height > 0 else {
            print("❌ PHOTO CROP: Invalid source dimensions \(originalSize) - aborting crop application")
            cropViewController.dismiss(animated: true) { [weak self] in
                self?.currentPhotoSourceSize = nil
            }
            return
        }
        
        var normalizedRect = CGRect(
            x: cropRect.origin.x / originalSize.width,
            y: cropRect.origin.y / originalSize.height,
            width: cropRect.size.width / originalSize.width,
            height: cropRect.size.height / originalSize.height
        )
        
        normalizedRect.origin.x = max(0.0, min(1.0, normalizedRect.origin.x))
        normalizedRect.origin.y = max(0.0, min(1.0, normalizedRect.origin.y))
        normalizedRect.size.width = max(0.0, min(1.0 - normalizedRect.origin.x, normalizedRect.size.width))
        normalizedRect.size.height = max(0.0, min(1.0 - normalizedRect.origin.y, normalizedRect.size.height))
        
        print("📐 PHOTO CROP: Normalized crop rect: \(normalizedRect)")
        
        cropViewController.dismiss(animated: true) { [weak self] in
            guard let self else { return }
            let cropOperation = CropOperation(normalizedCropRect: normalizedRect)
            print("✅ PHOTO CROP: Created crop operation for photo asset")
            onEvent?(.applyCrop(cropOperation))
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            currentPhotoSourceSize = nil
        }
    }
    
    func handleDidCancel(_ cropViewController: TOCropViewController) {
        print("❌ PHOTO CROP: Cancelled")
        cropViewController.dismiss(animated: true) { [weak self] in
            self?.currentPhotoSourceSize = nil
        }
    }
}

// MARK: - VideoCropViewController Implementation

class VideoCropViewController: UIViewController {
    
    // MARK: - Properties
    
    weak var delegate: CropToolController?
    var asset: AVAsset? {
        didSet {
            if isViewLoaded {
                setupVideoCropView()
            }
        }
    }
    
    // CRITICAL FIX: Use PryntTrimmerView classes directly
    private var videoCropView: PryntTrimmerView.VideoCropView!
    private var thumbSelector: PryntTrimmerView.ThumbSelectorView!
    private var toolbar: UIToolbar!
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupToolbar()
        
        // Setup views if asset is already set
        if asset != nil {
            setupVideoCropView()
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        layoutViews()
    }
    
    // MARK: - Setup Methods
    
    private func setupUI() {
        view.backgroundColor = .black
        title = "Crop Video"
        
        // Setup navigation bar
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "Cancel",
            style: .plain,
            target: self,
            action: #selector(cancelCrop)
        )
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Apply",
            style: .done,
            target: self,
            action: #selector(applyCrop)
        )
    }
    
    private func setupVideoCropView() {
        guard let asset = asset else {
            print("❌ VIDEO CROP: No asset available for setup")
            return
        }
        
        print("🎬 VIDEO CROP: Setting up VideoCropView with asset")
        
        // Remove existing views if any
        videoCropView?.removeFromSuperview()
        thumbSelector?.removeFromSuperview()
        
        // CRITICAL FIX: Create PryntTrimmerView classes correctly
        videoCropView = PryntTrimmerView.VideoCropView()
        videoCropView.backgroundColor = .black
        view.addSubview(videoCropView)
        
        thumbSelector = PryntTrimmerView.ThumbSelectorView()
        thumbSelector.backgroundColor = .darkGray
        thumbSelector.delegate = self
        view.addSubview(thumbSelector)
        
        // CRITICAL FIX: Set assets AFTER adding to view hierarchy and use proper frame layout
        // PryntTrimmerView components use manual frame layout, not Auto Layout
        videoCropView.translatesAutoresizingMaskIntoConstraints = true
        thumbSelector.translatesAutoresizingMaskIntoConstraints = true
        
        // Set assets to initialize the views
        videoCropView.asset = asset
        thumbSelector.asset = asset
        
        // 🎯 SMART ASPECT RATIO: Default to source video's recorded orientation, then constrain to landscape presets
        setupSmartAspectRatio()
        
        print("✅ VIDEO CROP: VideoCropView setup complete with smart aspect ratio")
    }
    
    // 🎯 SMART ASPECT RATIO SYSTEM: Default to source orientation, constrain for merging workflow
    private func setupSmartAspectRatio() {
        guard let asset = asset, let videoCropView = videoCropView else { return }
        
        Task { @MainActor in
            do {
                guard let videoTrack = try await asset.loadTracks(withMediaType: .video).first else {
                    print("❌ No video track found for aspect ratio detection")
                    return
                }
                
                let naturalSize = try await videoTrack.load(.naturalSize)
                let transform = try await videoTrack.load(.preferredTransform)
                
                // Detect actual recorded orientation
                let isRotated = abs(transform.b) == 1.0 && abs(transform.c) == 1.0
                let displaySize = isRotated ? CGSize(width: naturalSize.height, height: naturalSize.width) : naturalSize
                
                let aspectRatio = displaySize.width / displaySize.height
                
                print("📐 SOURCE VIDEO: \(displaySize.width)x\(displaySize.height), aspect ratio: \(String(format: "%.2f", aspectRatio))")
                
                let targetAspectRatio: CGSize
                
                if aspectRatio >= 2.0 {
                    targetAspectRatio = CGSize(width: 21, height: 9)
                    print("🎬 Cinema landscape source → 21:9 crop")
                } else if aspectRatio >= 1.7 {
                    targetAspectRatio = CGSize(width: 16, height: 9)
                    print("📺 Wide landscape source → 16:9 crop")
                } else {
                    targetAspectRatio = CGSize(width: 16, height: 9)
                    print("📐 Square-ish source → 16:9 crop")
                }
                
                videoCropView.setAspectRatio(targetAspectRatio, animated: false)
                print("✅ Smart aspect ratio applied: \(targetAspectRatio.width):\(targetAspectRatio.height)")
                
            } catch {
                print("❌ Failed to analyze source video aspect ratio: \(error)")
                // Fallback to 16:9 landscape
                videoCropView.setAspectRatio(CGSize(width: 16, height: 9), animated: false)
            }
        }
    }
    
    private func setupToolbar() {
        toolbar = UIToolbar()
        toolbar.backgroundColor = UIColor.black.withAlphaComponent(0.9)
        toolbar.barTintColor = UIColor.black
        toolbar.barStyle = .black
        view.addSubview(toolbar)
        
        // 🎯 CONSTRAINT-SAFE TOOLBAR: Simplified to prevent width conflicts
        let ratio16x9Button = UIBarButtonItem(
            title: "16:9",
            style: .plain,
            target: self,
            action: #selector(setAspectRatio16x9)
        )
        ratio16x9Button.tintColor = .white
        
        let ratio21x9Button = UIBarButtonItem(
            title: "21:9",
            style: .plain,
            target: self,
            action: #selector(setAspectRatio21x9)
        )
        ratio21x9Button.tintColor = .white
        
        let ratioFlexButton = UIBarButtonItem(
            title: "3:2",
            style: .plain,
            target: self,
            action: #selector(setCustomAspectRatio)
        )
        ratioFlexButton.tintColor = .white
        
        // FIXED: Use large flexible spaces to prevent constraint conflicts
        let flexSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        
        // SIMPLIFIED: Three buttons with large spaces to avoid toolbar width=0 conflicts
        toolbar.items = [
            flexSpace,
            ratio16x9Button,
            flexSpace,
            ratio21x9Button,
            flexSpace,
            ratioFlexButton,
            flexSpace
        ]
        
        print("🎛️ Constraint-safe landscape crop presets toolbar configured")
    }
    
    private func layoutViews() {
        guard let videoCropView = videoCropView,
              let thumbSelector = thumbSelector,
              let toolbar = toolbar else { return }
        
        let safeArea = view.safeAreaInsets
        let toolbarHeight: CGFloat = 60
        let thumbHeight: CGFloat = 80
        let margin: CGFloat = 16
        
        // CRITICAL FIX: Manual frame layout for PryntTrimmerView components
        let availableHeight = view.bounds.height - safeArea.top - safeArea.bottom - toolbarHeight - thumbHeight - (margin * 3)
        let availableWidth = view.bounds.width - safeArea.left - safeArea.right - (margin * 2)
        
        let cropFrame = CGRect(
            x: safeArea.left + margin,
            y: safeArea.top + margin,
            width: availableWidth,
            height: availableHeight
        )
        
        // CRITICAL FIX: Set frame directly (PryntTrimmerView uses manual layout)
        videoCropView.frame = cropFrame
        
        // ThumbSelector below the crop view
        thumbSelector.frame = CGRect(
            x: safeArea.left + margin,
            y: cropFrame.maxY + margin,
            width: availableWidth,
            height: thumbHeight
        )
        
        // Toolbar at bottom
        toolbar.frame = CGRect(
            x: 0,
            y: view.bounds.height - safeArea.bottom - toolbarHeight,
            width: view.bounds.width,
            height: toolbarHeight
        )
        
        print("🔧 LAYOUT: VideoCropView frame: \(cropFrame)")
        print("🔧 LAYOUT: ThumbSelector frame: \(thumbSelector.frame)")
    }
    
    // MARK: - Aspect Ratio Actions
    
    @objc private func setAspectRatio16x9() {
        videoCropView?.setAspectRatio(CGSize(width: 16, height: 9), animated: true)
        print("📺 Set 16:9 landscape aspect ratio")
    }
    
    @objc private func setAspectRatio21x9() {
        videoCropView?.setAspectRatio(CGSize(width: 21, height: 9), animated: true)
        print("🎬 Set 21:9 cinema aspect ratio")
    }
    
    @objc private func setCustomAspectRatio() {
        // FIXED: Don't use (0,0) as it causes NaN geometry crash in PryntTrimmerView
        // Instead, use a flexible landscape aspect ratio that allows more freedom
        videoCropView?.setAspectRatio(CGSize(width: 3, height: 2), animated: true) // 3:2 flexible landscape
        print("🎨 Set flexible landscape aspect ratio (3:2)")
    }
    
    // MARK: - Actions
    
    @objc private func cancelCrop() {
        print("❌ VIDEO CROP: User cancelled crop")
        dismiss(animated: true)
    }
    
    @objc private func applyCrop() {
        guard let videoCropView = videoCropView,
              let asset = asset else {
            print("❌ VIDEO CROP: Missing crop view or asset")
            return
        }
        
        print("✅ VIDEO CROP: Applying video crop")
        
        // CRITICAL FIX: Use PryntTrimmerView's getImageCropFrame method
        let cropFrame = videoCropView.getImageCropFrame()
        
        // Get video dimensions for normalization
        Task { @MainActor in
            do {
                guard let videoTrack = try await asset.loadTracks(withMediaType: .video).first else {
                    print("❌ VIDEO CROP: No video track found")
                    return
                }
                
                let naturalSize = try await videoTrack.load(.naturalSize)
                let transform = try await videoTrack.load(.preferredTransform)
                
                // Handle video orientation for proper crop calculation
                let isRotated = abs(transform.b) == 1.0 && abs(transform.c) == 1.0
                let displaySize = isRotated ? CGSize(width: naturalSize.height, height: naturalSize.width) : naturalSize
                
                // CRITICAL FIX: getImageCropFrame already returns coordinates relative to video
                // So we use the cropFrame directly as normalized rect
                let normalizedRect = CGRect(
                    x: cropFrame.origin.x / displaySize.width,
                    y: cropFrame.origin.y / displaySize.height,
                    width: cropFrame.size.width / displaySize.width,
                    height: cropFrame.size.height / displaySize.height
                )
                
                print("🎯 VIDEO CROP: Crop frame from VideoCropView: \(cropFrame)")
                print("📐 VIDEO CROP: Video size: \(displaySize), normalized rect: \(normalizedRect)")
                
                // Create crop operation
                let cropOperation = CropOperation(normalizedCropRect: normalizedRect)
                
                // Dismiss and apply operation via coordinator
                self.dismiss(animated: true) {
                    print("✅ VIDEO CROP: Created crop operation for video asset")
                    
                    // CRITICAL FIX: Send applyCrop event to coordinator (this was missing!)
                    self.delegate?.onEvent?(.applyCrop(cropOperation))
                    
                    // Haptic feedback
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }
                
            } catch {
                print("❌ VIDEO CROP: Failed to get video dimensions: \(error)")
                self.showAlert(title: "Crop Error", message: "Failed to process video crop")
            }
        }
    }
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - ThumbSelectorViewDelegate

extension VideoCropViewController: ThumbSelectorViewDelegate {
    
    func didChangeThumbPosition(_ imageTime: CMTime) {
        // CRITICAL FIX: Sync video player in VideoCropView with selected thumbnail time
        videoCropView?.player?.seek(to: imageTime, toleranceBefore: .zero, toleranceAfter: .zero)
        print("🎯 VIDEO CROP: Synced to frame at \(imageTime.seconds)s")
    }
}

// MARK: - Delegate Proxy

private final class TOCropDelegateProxy: NSObject, TOCropViewControllerDelegate {
    weak var owner: CropToolController?
    
    init(owner: CropToolController) {
        self.owner = owner
    }
    
    func cropViewController(_ cropViewController: TOCropViewController,
                            didCropTo image: UIImage,
                            with cropRect: CGRect,
                            angle: Int) {
        Task { @MainActor [weak owner] in
            owner?.handleDidCrop(cropViewController, image: image, cropRect: cropRect, angle: angle)
        }
    }
    
    func cropViewController(_ cropViewController: TOCropViewController, didFinishCancelled cancelled: Bool) {
        Task { @MainActor [weak owner] in
            owner?.handleDidCancel(cropViewController)
        }
    }
}
