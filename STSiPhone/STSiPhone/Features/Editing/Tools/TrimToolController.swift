import UIKit
import AVFoundation
import PryntTrimmerView

@MainActor
protocol TrimToolHandling: AnyObject {
    var onEvent: ((CoordinatorEvent) -> Void)? { get set }
    func mount(into container: UIView, assetURL: URL)
    func unmount()
}

@MainActor
final class TrimToolController: NSObject, TrimToolHandling {
    var onEvent: ((CoordinatorEvent) -> Void)?
    private var trimmerView: STSResilientTrimmerView? {
        didSet {
            trimmerView?.delegate = delegateProxy
        }
    }
    
    // Track previous trim range to detect handle movements (BREAKTHROUGH PATTERN)
    private var lastTrimStartTime: CMTime?
    private var lastTrimEndTime: CMTime?
    private lazy var delegateProxy = TrimmerDelegateProxy(owner: self)

    func mount(into container: UIView, assetURL: URL) {
        // DISABLED: Don't create duplicate trimmer
        // The original STSResilientTrimmerView in LightweightEditorViewController is working perfectly
        print("🎛️ TRIM TOOL: Skipping modular trimmer mount - using original system")
        
        // The original trimmer already has:
        // - Proper 60pt height constraint
        // - Correct positioning above toolbar
        // - Working Apply/Cancel delegate pattern
        // - Proper STSResilientTrimmerView wrapper
    }

    func unmount() {
        // Nothing to unmount since we're not creating duplicate trimmers
        print("🗑️ TRIM TOOL: No modular trimmer to unmount")
    }
}

// MARK: - Trim Handling

@MainActor
private extension TrimToolController {
    func handlePositionChange(at playerTime: CMTime) {
        print("🎯 TRIM TOOL: didChangePositionBar fired with time \(playerTime.seconds)s")
        
        guard let trimmer = trimmerView,
              let currentStartTime = trimmer.startTime,
              let currentEndTime = trimmer.endTime else { return }
        
        let startTimeChanged = lastTrimStartTime == nil ||
            abs(currentStartTime.seconds - (lastTrimStartTime?.seconds ?? 0)) > 0.01
        let endTimeChanged = lastTrimEndTime == nil ||
            abs(currentEndTime.seconds - (lastTrimEndTime?.seconds ?? 0)) > 0.01
        
        if startTimeChanged || endTimeChanged {
            print("🚨 TRIM TOOL: Handle movement detected!")
            print("✂️ TRIM CHANGE: start=\(currentStartTime.seconds)s, end=\(currentEndTime.seconds)s")
            
            let duration = CMTimeSubtract(currentEndTime, currentStartTime)
            let range = CMTimeRange(start: currentStartTime, duration: duration)
            onEvent?(.pendingTrim(range))
            
            lastTrimStartTime = currentStartTime
            lastTrimEndTime = currentEndTime
        }
    }
    
    func handlePositionStopped(at playerTime: CMTime) {
        print("🎯 TRIM TOOL: positionBarStoppedMoving fired")
    }
    
}

// MARK: - Delegate Proxy

private final class TrimmerDelegateProxy: NSObject, TrimmerViewDelegate {
    weak var owner: TrimToolController?
    
    init(owner: TrimToolController) {
        self.owner = owner
    }
    
    func didChangePositionBar(_ playerTime: CMTime) {
        Task { @MainActor [weak owner] in
            owner?.handlePositionChange(at: playerTime)
        }
    }
    
    func positionBarStoppedMoving(_ playerTime: CMTime) {
        Task { @MainActor [weak owner] in
            owner?.handlePositionStopped(at: playerTime)
        }
    }
}
