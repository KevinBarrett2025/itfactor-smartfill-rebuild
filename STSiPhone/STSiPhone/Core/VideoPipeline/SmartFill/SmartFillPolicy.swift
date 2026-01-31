import Foundation
import UIKit

// MARK: - Session Extensions for Smart Fill
public extension ProjectSession {
    var inferredPrimaryOrientation: VideoOrientation {
        // INTEGRATION: Determine session orientation from majority of takes
        let landscapeCount = takes.filter { take in
            // Check if we have stored orientation, otherwise infer from filename/metadata
            return inferVideoOrientation(for: take) == .landscape
        }.count
        
        let portraitCount = takes.count - landscapeCount
        
        return portraitCount > landscapeCount ? .portrait : .landscape
    }
    
    var effectiveSmartFillEnabled: Bool {
        // Use stored setting or default to true
        return smartFillEnabled ?? true
    }
    
    private func inferVideoOrientation(for take: ProjectTake) -> VideoOrientation {
        // Use stored orientation if available
        if let stored = take.capturedOrientation {
            return stored
        }
        
        // INTEGRATION: Try to infer orientation from existing take data
        // This is temporary until we add proper orientation capture
        
        // Check if filename suggests orientation
        let fileName = take.filePath.lowercased()
        if fileName.contains("portrait") || fileName.contains("vertical") {
            return .portrait
        }
        if fileName.contains("landscape") || fileName.contains("horizontal") {
            return .landscape
        }
        
        // Default to landscape for backward compatibility
        return .landscape
    }
}

// MARK: - ProjectTake Extensions for Smart Fill
public extension ProjectTake {
    var effectiveCapturedOrientation: VideoOrientation {
        // Use stored orientation or infer from metadata
        return capturedOrientation ?? inferOrientationFromMetadata()
    }
    
    var effectiveSmartFillOverride: TriState {
        // Use stored override or default to inherit
        return overrideSmartFill ?? .inherit
    }
    
    private func inferOrientationFromMetadata() -> VideoOrientation {
        // INTEGRATION: Temporary inference logic
        // Check duration vs typical orientation patterns
        if durationSeconds < 30 && filePath.contains("slate") {
            return .portrait // Slates are often portrait
        }
        
        // Default to landscape for existing takes
        return .landscape
    }
}

// MARK: - Smart Fill Policy Engine
public enum SmartFillPolicy {
    public static func resolve(_ override: TriState?, base: Bool) -> Bool {
        switch override {
        case .some(.on):  return true
        case .some(.off): return false
        default:          return base
        }
    }

    public static func shouldApply(session: ProjectSession, take: ProjectTake, settings: SmartFillSettings) -> Bool {
        let base = session.effectiveSmartFillEnabled
        let wants = resolve(take.effectiveSmartFillOverride, base: base)
        return wants && (session.inferredPrimaryOrientation == .landscape) && (take.effectiveCapturedOrientation == .portrait)
    }
    
    // INTEGRATION: Convenience method for our existing architecture
    public static func shouldApply(for take: ProjectTake, in session: ProjectSession) -> Bool {
        let settings = SmartFillSettings() // Use defaults for now
        return shouldApply(session: session, take: take, settings: settings)
    }
    
    // INTEGRATION: Batch processing for session
    public static func getPortraitTakesNeedingSmartFill(in session: ProjectSession) -> [ProjectTake] {
        return session.takes.filter { take in
            shouldApply(for: take, in: session)
        }
    }
}
