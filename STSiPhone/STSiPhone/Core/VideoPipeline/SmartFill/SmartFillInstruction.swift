import AVFoundation
import CoreMedia

/// Custom instruction that carries all inputs needed by SmartFillPreviewCompositor
/// for both preview and export rendering
public final class SmartFillInstruction: NSObject, AVVideoCompositionInstructionProtocol {
    
    // MARK: - AVVideoCompositionInstructionProtocol Requirements
    public var timeRange: CMTimeRange
    public var enablePostProcessing: Bool = false
    public var containsTweening: Bool = false
    public var requiredSourceTrackIDs: [NSValue]?
    public var passthroughTrackID: CMPersistentTrackID = kCMPersistentTrackID_Invalid
    
    // MARK: - SmartFill-specific Properties
    public let renderSize: CGSize
    public let settings: SmartFillSettings
    public let naturalSize: CGSize
    public let preferredTransform: CGAffineTransform
    public let videoTrackID: CMPersistentTrackID
    
    // MARK: - Initialization
    public init(
        timeRange: CMTimeRange,
        renderSize: CGSize,
        settings: SmartFillSettings,
        naturalSize: CGSize,
        preferredTransform: CGAffineTransform,
        videoTrackID: CMPersistentTrackID
    ) {
        self.timeRange = timeRange
        self.renderSize = renderSize
        self.settings = settings
        self.naturalSize = naturalSize
        self.preferredTransform = preferredTransform
        self.videoTrackID = videoTrackID
        
        // Set required source track IDs
        self.requiredSourceTrackIDs = [NSNumber(value: videoTrackID)]
        
        super.init()
        
        print("🎬 SmartFillInstruction: Created")
        print("   📐 Natural size: \(naturalSize)")
        print("   🔄 Preferred transform: \(preferredTransform)")
        print("   🎯 Render size: \(renderSize)")
        print("   🎨 Blur radius: \(settings.defaultBlurRadius)px")
        print("   🌙 Darken amount: \(settings.defaultDarkenAmount)")
        print("   📐 Background scale: \(settings.backgroundScale)x")
    }
}
