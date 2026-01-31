import SwiftUI
import Foundation

/// UI Helper extensions for SmartFill functionality
extension Notification.Name {
    /// Posted when SmartFill processing completes successfully
    static let smartFillDidComplete = Notification.Name("STSSmartFillCompleted")
    
    /// Posted when SmartFill processing fails
    static let smartFillDidFail = Notification.Name("STSSmartFillFailed")
}

/// SmartFill processing helper for UI components
public struct SmartFillUIHelper {
    
    /// Debug information for SmartFill status
    public static func debugSmartFillStatus(for take: ProjectTake) -> String {
        return VideoVariantResolver.variantInfo(for: take)
    }
    
    /// Check if a take should show SmartFill parent/child UI
    public static func shouldShowSmartFillHierarchy(for take: ProjectTake) -> Bool {
        return VideoVariantResolver.hasSmartFilledVersion(for: take) && take.capturedOrientation == .portrait
    }
    
    /// Get display-friendly SmartFill status text
    public static func smartFillStatusText(for take: ProjectTake) -> String {
        if VideoVariantResolver.hasSmartFilledVersion(for: take) {
            return "SmartFill Enhanced"
        } else if take.capturedOrientation == .portrait {
            return "Portrait (Processing Available)"
        } else {
            return "Landscape"
        }
    }
    
    /// Get appropriate icon for SmartFill status
    public static func smartFillStatusIcon(for take: ProjectTake) -> String {
        if VideoVariantResolver.hasSmartFilledVersion(for: take) {
            return "rectangle.fill.badge.checkmark"
        } else if take.capturedOrientation == .portrait {
            return "rectangle.portrait"
        } else {
            return "rectangle"
        }
    }
    
    /// Log SmartFill processing result for debugging
    public static func logSmartFillResult(takeID: UUID, success: Bool, outputPath: String? = nil, error: Error? = nil) {
        if success, let outputPath = outputPath {
            print("✅ SmartFillUIHelper: Processing completed for takeID \(takeID)")
            print("   📁 Output: \(outputPath)")
            print("   💾 File exists: \(FileManager.default.fileExists(atPath: outputPath))")
        } else if let error = error {
            print("❌ SmartFillUIHelper: Processing failed for takeID \(takeID)")
            print("   Error: \(error.localizedDescription)")
        }
    }
}
