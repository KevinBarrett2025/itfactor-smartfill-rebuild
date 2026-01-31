import CoreGraphics
import Foundation
import UIKit
import os

public enum OrientationTarget { 
    case portrait1080x1920, landscape1920x1080 
    
    var size: CGSize {
        switch self {
        case .portrait1080x1920: return CGSize(width: 1080, height: 1920)
        case .landscape1920x1080: return CGSize(width: 1920, height: 1080)
        }
    }
}

/// Single source of truth for orientation policy in STS
/// This replaces ad-hoc UI transforms and centralizes orientation logic
public final class OrientationPolicy {
    public static let shared = OrientationPolicy()
    private let logger = Logger(subsystem: "com.selftapestudio.app", category: "OrientationPolicy")
    
    private init() {}

    /// Determines the transform to apply during export/composition
    /// This is where ALL orientation transforms should happen
    public func transformForExport(assetInfo: OrientationAssetInfo, target: OrientationTarget) -> CGAffineTransform {
        // INTEGRATION NOTE: Replace this stub with your exact SmartFill compositor math
        // This should match the logic currently in SmartFillExportCompositor
        
        let canvas = target.size
        
        // Parse dimensions from asset info
        let dims = assetInfo.originalDimensions.split(separator: "x")
        guard dims.count == 2,
              let width = Double(dims[0]),
              let height = Double(dims[1]) else {
            logger.warning("orientation_policy_parse_failed dimensions=\(assetInfo.originalDimensions, privacy: .public)")
            return .identity
        }
        
        let sourceSize = CGSize(width: width, height: height)
        
        // For SmartFill, we typically want to scale and center
        // Replace with your actual compositor transform logic
        let scaleX = canvas.width / sourceSize.width
        let scaleY = canvas.height / sourceSize.height
        let scale = min(scaleX, scaleY) // Fit scale
        
        let scaledSize = CGSize(width: sourceSize.width * scale, height: sourceSize.height * scale)
        let offsetX = (canvas.width - scaledSize.width) / 2
        let offsetY = (canvas.height - scaledSize.height) / 2
        
        return CGAffineTransform(scaleX: scale, y: scale)
            .concatenating(CGAffineTransform(translationX: offsetX, y: offsetY))
    }

    /// Determines if UI players should apply transforms for legacy content
    /// New exports (version >= 2) should be shown raw since compositor handles orientation
    public func uiShouldApplyTransform(for info: OrientationAssetInfo) -> Bool {
        // Canon: compositor owns transforms for new exports
        switch OrientationPolicySidecar.decision(for: info.url) {
        case .uiShouldNotApplyTransform:
            logger.debug("orientation_policy_ui_skip url=\(info.url.lastPathComponent, privacy: .public) version=\(info.exportVersion)")
            return false
        case .uiShouldApplyTransform:
            logger.debug("orientation_policy_ui_apply url=\(info.url.lastPathComponent, privacy: .public) version=\(info.exportVersion)")
            return true
        }
    }
    
    /// Helper to determine if an asset is considered portrait based on dimensions and transform
    public func isPortraitContent(assetInfo: OrientationAssetInfo) -> Bool {
        return assetInfo.normalizedOrientation.contains("portrait")
    }
    
    /// Get expected stage where transforms should be applied
    public func expectedTransformStage(for assetInfo: OrientationAssetInfo) -> String {
        // New assets: compositor owns all transforms
        if assetInfo.exportVersion >= 2 {
            return "Compositor"
        }
        
        // Legacy assets: may need UI transforms until migrated
        return "UIPlayer"
    }
}

// MARK: - Integration Helpers
extension OrientationPolicy {
    
    /// Create an OrientationRun for the current context
    public static func createRun(context: String, smartfillMode: String = "none") -> OrientationRun {
        return OrientationRun(
            runUUID: UUID().uuidString,
            context: context,
            smartfillMode: smartfillMode,
            device: "\(UIDevice.current.model)",
            osVersion: ProcessInfo.processInfo.operatingSystemVersionString,
            appBuild: appBuildString()
        )
    }
    
    /// Convenience method to log a transform application
    public func applyAndLogTransform(
        _ transform: CGAffineTransform,
        stage: String,
        run: OrientationRun,
        notes: String? = nil
    ) {
        OrientationDiag.logTransform(run, stage: stage, desc: transform.debugDescription, notes: notes)
    }
}

// Rule enforcement
extension OrientationPolicy {
    
    /// Validates that only one transform stage is active for a run
    /// Call this after all operations are complete to audit compliance
    public func validateSingleTransformRule(run: OrientationRun, expectedStage: String) {
        OrientationDiag.audit(run, expectedStage: expectedStage)
    }
}
