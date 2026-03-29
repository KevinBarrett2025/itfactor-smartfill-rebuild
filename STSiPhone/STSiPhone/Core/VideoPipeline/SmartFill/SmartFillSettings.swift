import Foundation
import CoreGraphics

/// Canonical SmartFill settings shared across preview and export pipelines.
/// Stored values are bridged to legacy property names so the existing codebase
/// continues to compile while we converge on the unified API.
public struct SmartFillSettings: Codable, Equatable, Sendable {
    public enum BackgroundSourceMode: String, Codable, CaseIterable, Sendable {
        case sourceDerived
        case customImage
        case customVideo

        public var title: String {
            switch self {
            case .sourceDerived:
                return "Source"
            case .customImage:
                return "Still"
            case .customVideo:
                return "Motion"
            }
        }

        public var systemImage: String {
            switch self {
            case .sourceDerived:
                return "sparkles.tv"
            case .customImage:
                return "photo"
            case .customVideo:
                return "film"
            }
        }

        public var summary: String {
            switch self {
            case .sourceDerived:
                return "Use the source clip as the background plate."
            case .customImage:
                return "Use a picked still image as the background plate."
            case .customVideo:
                return "Reserve a motion background seam for the next flagship slice."
            }
        }

        public var isCurrentlySupported: Bool {
            switch self {
            case .sourceDerived, .customImage:
                return true
            case .customVideo:
                return false
            }
        }
    }

    // MARK: - Canonical properties
    public var isEnabled: Bool
    public var blurRadius: CGFloat
    public var darkenAmount: CGFloat
    public var backgroundScale: CGFloat
    public var foregroundScale: CGFloat
    public var backgroundSourceMode: BackgroundSourceMode
    public var backgroundAssetPath: String?
    public var backgroundAssetDisplayName: String?
    public var backgroundVideoTakeID: UUID?
    public var presetName: String?
    public var renderSize: CGSize
    public var processingPriority: ProcessingPriority
    /// Token that can be bumped to force preview rebuilds even when numeric settings stay the same.
    public var forceUpdateToken: UUID = UUID()
    
    public enum ProcessingPriority: String, Codable, CaseIterable, Sendable {
        case background
        case userInitiated
        case high
        
        public var displayName: String {
            switch self {
            case .background:     return "Background"
            case .userInitiated:  return "Normal"
            case .high:           return "High"
            }
        }
    }
    
    // MARK: - Initialisers
    
    /// Loads settings from persisted defaults (legacy behaviour).
    public init() {
        let defaults = UserDefaults.standard
        self.isEnabled = defaults.object(forKey: "smartFillDefaultEnabled") as? Bool
            ?? defaults.object(forKey: "smartFillEnabled") as? Bool
            ?? true
        self.blurRadius = SmartFillSettings.cgFloat(forKey: "smartFillBlurRadius", in: defaults, fallback: 24.0)
        self.darkenAmount = SmartFillSettings.cgFloat(forKey: "smartFillDarkenAmount", in: defaults, fallback: 0.12)
        self.backgroundScale = SmartFillSettings.cgFloat(forKey: "smartFillBackgroundScale", in: defaults, fallback: 10.0)
        self.foregroundScale = SmartFillSettings.cgFloat(forKey: "smartFillForegroundScale", in: defaults, fallback: 1.0)
        let backgroundSourceModeRawValue = defaults.string(forKey: "smartFillBackgroundSourceMode")
            ?? BackgroundSourceMode.sourceDerived.rawValue
        self.backgroundSourceMode = BackgroundSourceMode(rawValue: backgroundSourceModeRawValue) ?? .sourceDerived
        self.backgroundAssetPath = defaults.string(forKey: "smartFillBackgroundAssetPath")
        self.backgroundAssetDisplayName = defaults.string(forKey: "smartFillBackgroundAssetDisplayName")
        if let backgroundVideoTakeID = defaults.string(forKey: "smartFillBackgroundVideoTakeID") {
            self.backgroundVideoTakeID = UUID(uuidString: backgroundVideoTakeID)
        } else {
            self.backgroundVideoTakeID = nil
        }
        self.presetName = defaults.string(forKey: "smartFillPresetName")
        let width = SmartFillSettings.cgFloat(forKey: "smartFillRenderWidth", in: defaults, fallback: 1920)
        let height = SmartFillSettings.cgFloat(forKey: "smartFillRenderHeight", in: defaults, fallback: 1080)
        self.renderSize = CGSize(width: width, height: height)
        let priorityRaw = defaults.string(forKey: "smartFillProcessingPriority") ?? ProcessingPriority.userInitiated.rawValue
        self.processingPriority = ProcessingPriority(rawValue: priorityRaw) ?? .userInitiated
        if let tokenString = defaults.string(forKey: "smartFillForceUpdateToken"),
           let token = UUID(uuidString: tokenString) {
            self.forceUpdateToken = token
        } else {
            self.forceUpdateToken = UUID()
        }
    }
    
    /// Designated initialiser used by UI to pass explicit values.
    public init(
        isEnabled: Bool = true,
        blurRadius: CGFloat = 24.0,
        darkenAmount: CGFloat = 0.12,
        backgroundScale: CGFloat = 10.0,
        foregroundScale: CGFloat = 1.0,
        backgroundSourceMode: BackgroundSourceMode = .sourceDerived,
        backgroundAssetPath: String? = nil,
        backgroundAssetDisplayName: String? = nil,
        backgroundVideoTakeID: UUID? = nil,
        presetName: String? = nil,
        renderSize: CGSize = CGSize(width: 1920, height: 1080),
        processingPriority: ProcessingPriority = .userInitiated,
        forceUpdateToken: UUID = UUID()
    ) {
        self.isEnabled = isEnabled
        self.blurRadius = blurRadius
        self.darkenAmount = darkenAmount
        self.backgroundScale = backgroundScale
        self.foregroundScale = foregroundScale
        self.backgroundSourceMode = backgroundSourceMode
        self.backgroundAssetPath = backgroundAssetPath
        self.backgroundAssetDisplayName = backgroundAssetDisplayName
        self.backgroundVideoTakeID = backgroundVideoTakeID
        self.presetName = presetName
        self.renderSize = renderSize
        self.processingPriority = processingPriority
        self.forceUpdateToken = forceUpdateToken
    }

    /// Legacy initializer signature retained for compatibility with existing call sites.
    public init(
        defaultEnabled: Bool,
        defaultBlurRadius: CGFloat,
        defaultDarkenAmount: CGFloat,
        defaultRenderSize: CGSize,
        backgroundScale: CGFloat = 10.0,
        processingPriority: ProcessingPriority = .userInitiated,
        forceUpdateToken: UUID = UUID()
    ) {
        self.init(
            isEnabled: defaultEnabled,
            blurRadius: defaultBlurRadius,
            darkenAmount: defaultDarkenAmount,
            backgroundScale: backgroundScale,
            foregroundScale: 1.0,
            renderSize: defaultRenderSize,
            processingPriority: processingPriority,
            forceUpdateToken: forceUpdateToken
        )
    }
    
    // MARK: - Helpers
    
    public func clamped() -> SmartFillSettings {
        var copy = self
        copy.blurRadius = max(0, copy.blurRadius)
        copy.darkenAmount = min(max(0, copy.darkenAmount), 1)
        copy.backgroundScale = max(0.1, copy.backgroundScale)
        copy.foregroundScale = max(0.1, copy.foregroundScale)
        copy.renderSize = CGSize(
            width: max(1, copy.renderSize.width),
            height: max(1, copy.renderSize.height)
        )
        return copy
    }
    
    public func saveToUserDefaults() {
        let defaults = UserDefaults.standard
        defaults.set(isEnabled, forKey: "smartFillDefaultEnabled")
        defaults.set(isEnabled, forKey: "smartFillEnabled") // legacy key
        defaults.set(blurRadius, forKey: "smartFillBlurRadius")
        defaults.set(darkenAmount, forKey: "smartFillDarkenAmount")
        defaults.set(backgroundScale, forKey: "smartFillBackgroundScale")
        defaults.set(foregroundScale, forKey: "smartFillForegroundScale")
        defaults.set(backgroundSourceMode.rawValue, forKey: "smartFillBackgroundSourceMode")
        defaults.set(backgroundAssetPath, forKey: "smartFillBackgroundAssetPath")
        defaults.set(backgroundAssetDisplayName, forKey: "smartFillBackgroundAssetDisplayName")
        defaults.set(backgroundVideoTakeID?.uuidString, forKey: "smartFillBackgroundVideoTakeID")
        defaults.set(presetName, forKey: "smartFillPresetName")
        defaults.set(renderSize.width, forKey: "smartFillRenderWidth")
        defaults.set(renderSize.height, forKey: "smartFillRenderHeight")
        defaults.set(processingPriority.rawValue, forKey: "smartFillProcessingPriority")
        defaults.set(forceUpdateToken.uuidString, forKey: "smartFillForceUpdateToken")
    }
}

// MARK: - Legacy bridging
public extension SmartFillSettings {
    var defaultEnabled: Bool {
        get { isEnabled }
        set { isEnabled = newValue }
    }
    
    var defaultBlurRadius: CGFloat {
        get { blurRadius }
        set { blurRadius = newValue }
    }
    
    var defaultDarkenAmount: CGFloat {
        get { darkenAmount }
        set { darkenAmount = newValue }
    }
    
    var defaultRenderSize: CGSize {
        get { renderSize }
        set { renderSize = newValue }
    }
}

// MARK: - Presets (legacy compatibility)
public extension SmartFillSettings {
    enum Preset: String, CaseIterable, Sendable {
        case subtle
        case medium
        case dramatic
        
        public var blurRadius: CGFloat {
            switch self {
            case .subtle:   return 32.0
            case .medium:   return 26.0
            case .dramatic: return 50.0
            }
        }
        
        public var darkenAmount: CGFloat {
            switch self {
            case .subtle:   return 0.04
            case .medium:   return 0.12
            case .dramatic: return 0.20
            }
        }
        
        public var backgroundScale: CGFloat {
            switch self {
            case .subtle:   return 1.5
            case .medium:   return 3.0
            case .dramatic: return 6.0
            }
        }
    }
}

// MARK: - Private helpers
private extension SmartFillSettings {
    static func cgFloat(forKey key: String, in defaults: UserDefaults, fallback: CGFloat) -> CGFloat {
        if let number = defaults.object(forKey: key) as? NSNumber {
            return CGFloat(truncating: number)
        }
        return fallback
    }
}
