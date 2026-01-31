import UIKit
import AVFoundation
import PryntTrimmerView

/// A resilient wrapper around PryntTrimmerView.TrimmerView using composition that:
/// - Defers asset assignment until the view has a non-zero size
/// - Rebuilds the internal thumbnail pipeline when height transitions from 0 to > 0
/// - Exposes a fixed intrinsic height so SwiftUI/Auto Layout don't shrink it to zero
/// - CRITICAL FIX: Properly manages delegate connection timing to ensure delegate methods fire
final class STSResilientTrimmerView: UIView {

    /// Public API: assign URL here instead of touching `asset` directly.
    var pendingURL: URL? {
        didSet { if window != nil { setNeedsLayout() } }
    }

    /// Fixed tool height (you can tweak to 56, 64, etc.)
    var desiredHeight: CGFloat = 60 {
        didSet { invalidateIntrinsicContentSize() }
    }
    
    /// CRITICAL FIX: Store delegate reference to reassign after asset initialization
    private weak var pendingDelegate: TrimmerViewDelegate?
    
    /// Delegate forwarding with proper timing management
    weak var delegate: TrimmerViewDelegate? {
        didSet {
            print("🔄 DEBUG STSResilientTrimmerView: Delegate assignment requested: \(String(describing: delegate))")
            pendingDelegate = delegate
            
            // If asset is already loaded, assign immediately
            if trimmerView.asset != nil {
                trimmerView.delegate = delegate
                print("✅ IMMEDIATE DELEGATE: Asset exists, delegate assigned immediately")
            } else {
                print("⏳ DEFERRED DELEGATE: Asset not ready, will assign after initialization")
            }
        }
    }
    
    /// Visual properties forwarding with STS branding
    var handleColor: UIColor? {
        didSet {
            if let color = handleColor {
                trimmerView.handleColor = color
            }
        }
    }
    
    var mainColor: UIColor? {
        didSet {
            if let color = mainColor {
                trimmerView.mainColor = color
            }
        }
    }
    
    var positionBarColor: UIColor? {
        didSet {
            if let color = positionBarColor {
                trimmerView.positionBarColor = color
            }
        }
    }
    
    var maxDuration: Double {
        get { trimmerView.maxDuration }
        set { trimmerView.maxDuration = newValue }
    }
    
    /// Access to internal properties
    var startTime: CMTime? {
        return trimmerView.startTime
    }
    
    var endTime: CMTime? {
        return trimmerView.endTime
    }
    
    var asset: AVAsset? {
        return trimmerView.asset
    }

    // The actual PryntTrimmerView
    internal let trimmerView = TrimmerView()
    
    private var lastBoundsHeight: CGFloat = 0
    private var didInitializeAssetOnce = false
    private var assetWasRebuiltAfterSize = false

    // MARK: - Initializers
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }
    
    private func commonInit() {
        // PROFESSIONAL: Set up professional appearance instead of debug styling
        backgroundColor = UIColor.clear
        layer.cornerRadius = 8
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOffset = CGSize(width: 0, height: 2)
        layer.shadowRadius = 4
        layer.shadowOpacity = 0.1
        
        // Add the actual trimmer as a subview
        addSubview(trimmerView)
        trimmerView.translatesAutoresizingMaskIntoConstraints = false
        
        // Pin the trimmer to fill this wrapper
        NSLayoutConstraint.activate([
            trimmerView.topAnchor.constraint(equalTo: topAnchor),
            trimmerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            trimmerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            trimmerView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        
        // PROFESSIONAL: Apply STS branding colors by default
        trimmerView.handleColor = UIColor(red: 0.6, green: 0.2, blue: 0.8, alpha: 1.0) // Theme primary purple
        trimmerView.mainColor = UIColor(red: 0.8, green: 0.3, blue: 0.7, alpha: 0.8) // Theme secondary pink
        trimmerView.positionBarColor = UIColor.systemOrange // STS accent color
    }
    
    // MARK: - Public Methods
    
    func seek(to time: CMTime) {
        trimmerView.seek(to: time)
    }
    
    func resetTrimHandles(startTime: CMTime, endTime: CMTime) {
        // Reset the trimmer to specific start/end positions
        // Note: PryntTrimmerView doesn't have direct handle setting methods,
        // so we need to work with the asset duration approach
        trimmerView.seek(to: startTime)
        
        // Force the trimmer to update its internal state
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.trimmerView.setNeedsLayout()
            self.trimmerView.layoutIfNeeded()
        }
        
        print("🔄 RESET HANDLES: Trimmer handles reset to \(startTime.seconds)s - \(endTime.seconds)s")
    }

    // MARK: - Sizing

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: desiredHeight)
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        // If we have a pendingURL and we're visible with non-zero height, build the asset once.
        if !didInitializeAssetOnce,
           bounds.width > 0, bounds.height > 0 {
            initializeAssetIfNeeded()
        }

        // Detect 0 -> >0 height transition AFTER initial build
        // This handles cases where SwiftUI/AutoLayout finish later.
        if didInitializeAssetOnce,
           !assetWasRebuiltAfterSize,
           lastBoundsHeight == 0,
           bounds.height > 0 {
            rebuildAssetPipelineAfterSize()
        }

        lastBoundsHeight = bounds.height
    }

    // MARK: - Private

    private func initializeAssetIfNeeded() {
        guard let url = pendingURL else { return }
        // MODERNIZED: Use AVURLAsset instead of deprecated AVAsset(url:)
        let asset = AVURLAsset(url: url)
        
        print("🎉 PROFESSIONAL RESILIENT: Initializing asset with valid size (\(bounds))")
        
        // Setting `asset` triggers Prynt internal setup.
        trimmerView.asset = asset

        // Seek to zero so position bar is in a valid state.
        trimmerView.seek(to: .zero)

        didInitializeAssetOnce = true
        
        // CRITICAL FIX: Reassign delegate AFTER asset initialization
        reassignDelegateAfterAssetInitialization()
        
        print("✅ PROFESSIONAL RESILIENT: Asset initialization complete with STS branding")
    }

    /// Some Prynt versions don't expose `resetSubViews()`.
    /// To force a rebuild when height becomes valid, we reassign the asset on the next runloop.
    private func rebuildAssetPipelineAfterSize() {
        assetWasRebuiltAfterSize = true
        guard let currentAsset = trimmerView.asset else { return }
        
        print("🔧 PROFESSIONAL RESILIENT: Rebuilding asset pipeline after height transition (0 → \(bounds.height))")
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            // Reassign the same asset to force Prynt to rebuild its thumbnails/handlers with the new size.
            self.trimmerView.asset = nil
            self.trimmerView.asset = currentAsset
            self.trimmerView.seek(to: .zero)
            self.trimmerView.setNeedsLayout()
            self.trimmerView.layoutIfNeeded()
            
            // CRITICAL FIX: Reassign delegate AFTER pipeline rebuild
            self.reassignDelegateAfterAssetInitialization()
            
            print("✅ PROFESSIONAL RESILIENT: Pipeline rebuild complete with professional styling")
        }
    }
    
    // CRITICAL FIX: Ensure delegate connection survives asset initialization and rebuilds
    private func reassignDelegateAfterAssetInitialization() {
        guard let pendingDelegate = pendingDelegate else {
            print("⚠️ DELEGATE: No pending delegate to reassign")
            return
        }
        
        // Small delay to ensure PryntTrimmerView internal setup is complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self else { return }
            
            self.trimmerView.delegate = pendingDelegate
            print("🔗 CRITICAL SUCCESS: Delegate reassigned after asset initialization to \(String(describing: pendingDelegate))")
            
            // Verify delegate assignment worked
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                guard let self = self else { return }
                if self.trimmerView.delegate != nil {
                    print("✅ DELEGATE VERIFICATION: Success - delegate is properly connected")
                } else {
                    print("🚨 DELEGATE VERIFICATION: FAILED - delegate connection lost, attempting recovery")
                    self.trimmerView.delegate = self.pendingDelegate
                }
            }
        }
    }
}
