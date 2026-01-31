import Foundation
import AVFoundation

/// VideoVariantResolver: Single source of truth for video file resolution
/// Handles original vs SmartFill variant selection with proper path resolution
public struct VideoVariantResolver {
    
    // HANDOFF FIX: Add cache to prevent redundant file system checks
    private static var smartFillCache: [UUID: (isValid: Bool, timestamp: Date)] = [:]
    private static let cacheTimeout: TimeInterval = 5.0 // Cache results for 5 seconds
    
    // MARK: - Variant Preferences
    
    public enum VariantPreference {
        case originalFirst
        case smartFillIfAvailable
        case explicit(ProjectTake.Variant)
    }
    
    // MARK: - Cache Management
    
    public static func invalidateSmartFillCache(for takeID: UUID) {
        smartFillCache.removeValue(forKey: takeID)
        print("🔄 SmartFill cache invalidated for take: \(takeID)")
    }
    
    public static func clearSmartFillCache() {
        smartFillCache.removeAll()
        print("🧹 SmartFill cache cleared")
    }
    
    // MARK: - File Resolution Methods
    
    /// Get Documents directory URL (current container)
    public static func documentsURL() -> URL {
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }
    
    /// Convert absolute path to relative path from Documents directory
    public static func relativePath(from url: URL) -> String {
        let docsURL = documentsURL()
        let prefix = docsURL.path.hasSuffix("/") ? docsURL.path : docsURL.path + "/"
        let path = url.path
        
        if path.hasPrefix(prefix) {
            return String(path.dropFirst(prefix.count))
        }
        
        // If not in Documents, return just the filename (fallback)
        return url.lastPathComponent
    }
    
    /// Convert relative path to absolute URL in current Documents directory
    public static func urlForRelativePath(_ relative: String) -> URL {
        return documentsURL().appendingPathComponent(relative, isDirectory: false)
    }
    
    /// Get original video URL for a take
    public static func originalURL(for take: ProjectTake) -> URL {
        // 🔥 CRITICAL PATH VOLATILITY FIX: Handle both relative and absolute paths
        if take.filePath.hasPrefix("/") {
            // Absolute path (legacy data) - use as-is but warn
            print("⚠️ VideoVariantResolver: Using legacy absolute path: \(take.filePath)")
            return URL(fileURLWithPath: take.filePath)
        } else {
            // Relative path (new system) - resolve to current Documents directory
            let resolvedURL = urlForRelativePath(take.filePath)
            print("✅ VideoVariantResolver: Resolved relative path '\(take.filePath)' to '\(resolvedURL.path)'")
            return resolvedURL
        }
    }
    
    /// Get SmartFill video URL for a take (returns nil if doesn't exist)
    public static func smartFillURL(for take: ProjectTake) -> URL? {
        guard let relativePath = take.smartFilledFilePath else {
            print("🔍 VideoVariantResolver: No smartFilledFilePath for take \(take.id)")
            return nil
        }

        print("🔍 VideoVariantResolver: PHASE 1 FIX - Enhanced SmartFill file resolution")
        print("   📁 SmartFill field contains: \(relativePath)")

        // 🚨 PHASE 1 FIX: Enhanced file resolution with robust validation

        // STRATEGY 1: Try as relative path from current Documents directory
        let relativeURL = urlForRelativePath(relativePath)
        if isValidSmartFillFile(at: relativeURL.path) {
            print("✅ VideoVariantResolver: Found VALID SmartFill via relative path strategy")
            print("   📂 Resolved to: \(relativeURL.path)")
            return relativeURL
        }

        // STRATEGY 2: Try as absolute path (backward compatibility)
        if isValidSmartFillFile(at: relativePath) {
            print("✅ VideoVariantResolver: Found VALID SmartFill via absolute path strategy")
            print("   📂 Using: \(relativePath)")
            return URL(fileURLWithPath: relativePath)
        }

        // STRATEGY 3: Container path migration
        if let migratedURL = attemptContainerPathMigration(originalPath: relativePath) {
            if isValidSmartFillFile(at: migratedURL.path) {
                print("✅ VideoVariantResolver: Found VALID SmartFill via container migration")
                print("   📂 Migrated to: \(migratedURL.path)")
                return migratedURL
            }
        }

        // STRATEGY 4: SmartFill directory search by filename pattern
        if let smartFillURL = searchSmartFillDirectory(for: take) {
            if isValidSmartFillFile(at: smartFillURL.path) {
                print("✅ VideoVariantResolver: Found VALID SmartFill via directory search")
                print("   📂 Located: \(smartFillURL.path)")
                return smartFillURL
            }
        }

        // STRATEGY 5: Generate expected SmartFill path and check
        if let expectedURL = generateExpectedSmartFillPath(for: take) {
            if isValidSmartFillFile(at: expectedURL.path) {
                print("✅ VideoVariantResolver: Found VALID SmartFill via expected path generation")
                print("   📂 Generated: \(expectedURL.path)")
                return expectedURL
            }
        }

        print("❌ VideoVariantResolver: VALID SmartFill file NOT FOUND after all strategies")
        print("   🔍 Searched path: \(relativePath)")
        print("   📁 Current Documents: \(documentsURL().path)")
        print("   💡 SmartFill processing may have failed or file was deleted")

        return nil
    }
    
    // PHASE 1 FIX: Add robust SmartFill file validation
    private static func isValidSmartFillFile(at path: String) -> Bool {
        // Check if file exists
        guard FileManager.default.fileExists(atPath: path) else {
            return false
        }
        
        // Check file size (SmartFill videos should be reasonably sized)
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: path)
            guard let fileSize = attributes[.size] as? Int64 else {
                print("⚠️ VideoVariantResolver: Cannot read file size for: \(path)")
                return false
            }
            
            // SmartFill videos should be at least 100KB (rule out stub files)
            guard fileSize > 100 * 1024 else {
                print("⚠️ VideoVariantResolver: SmartFill file too small (\(fileSize) bytes): \(path)")
                return false
            }
            
            // Check if file has reasonable video extension
            let fileURL = URL(fileURLWithPath: path)
            let fileExtension = fileURL.pathExtension.lowercased()
            guard ["mov", "mp4", "m4v"].contains(fileExtension) else {
                print("⚠️ VideoVariantResolver: SmartFill file has invalid extension (\(fileExtension)): \(path)")
                return false
            }
            
            print("✅ VideoVariantResolver: SmartFill file validation passed - Size: \(ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file))")
            return true
            
        } catch {
            print("❌ VideoVariantResolver: Failed to validate SmartFill file at \(path): \(error)")
            return false
        }
    }
    
    /// HANDOFF FIX: New method for UI gating - decouples preview from smartFilledFilePath
    public static func shouldShowStillPreview(for take: UnifiedTake) -> Bool {
        // HANDOFF FIX: Only require that the source file exists — do not gate on smartFilledFilePath
        return VideoFileManager.shared.fileExists(named: take.fileName)
    }
    
    /// 🔥 CRITICAL PATH VOLATILITY FIX: Enhanced variant detection with relative path support
    public static func hasSmartFilledVersion(for take: ProjectTake) -> Bool {
        // PERFORMANCE FIX: Cache results to prevent redundant file system checks per UI refresh
        if let cached = Self.smartFillCache[take.id],
           Date().timeIntervalSince(cached.timestamp) < Self.cacheTimeout {
            return cached.isValid
        }

        let fileName = URL(fileURLWithPath: take.filePath).lastPathComponent
        print("🔍 PATH VOLATILITY FIX - SMARTFILL UI DEBUG: Checking hasSmartFilledVersion for \(fileName)")
        print("   📁 Original file: \(take.filePath) (relative: \(!take.filePath.hasPrefix("/")))")
        print("   🆔 Take ID: \(take.id)")
        print("   📱 Orientation: \(take.capturedOrientation?.displayName ?? "nil")")

        // PATH VOLATILITY FIX: Use enhanced validation that handles both path types
        let hasSmartFill = smartFillURL(for: take) != nil

        // Cache the result
        Self.smartFillCache[take.id] = (isValid: hasSmartFill, timestamp: Date())

        if hasSmartFill {
            print("   🎉 PARENT/CHILD UI SHOULD BE SHOWING for \(fileName)")
        } else {
            print("   😞 PARENT/CHILD UI WILL NOT SHOW for \(fileName)")
        }

        return hasSmartFill
    }

    /// STRATEGY 4: Search SmartFill directory for matching files
    private static func searchSmartFillDirectory(for take: ProjectTake) -> URL? {
        let smartFillDir = documentsURL().appendingPathComponent("SmartFill")
        let originalFileName = URL(fileURLWithPath: take.filePath).lastPathComponent
        let baseFileName = originalFileName.replacingOccurrences(of: ".mov", with: "").replacingOccurrences(of: ".mp4", with: "")
        
        // Try common SmartFill filename patterns
        let patterns = [
            "\(baseFileName)_smartfill.mov",
            "\(baseFileName)_SmartFill.mov",
            "smartfill_\(take.id.uuidString).mov",
            "\(take.id.uuidString)_smartfill.mov"
        ]
        
        for pattern in patterns {
            let candidateURL = smartFillDir.appendingPathComponent(pattern)
            if FileManager.default.fileExists(atPath: candidateURL.path) {
                return candidateURL
            }
        }
        
        return nil
    }
    
    /// STRATEGY 5: Generate expected SmartFill path based on current conventions
    private static func generateExpectedSmartFillPath(for take: ProjectTake) -> URL? {
        let originalFileName = URL(fileURLWithPath: take.filePath).lastPathComponent
        let baseFileName = originalFileName.replacingOccurrences(of: ".mov", with: "").replacingOccurrences(of: ".mp4", with: "")
        
        let smartFillDir = documentsURL().appendingPathComponent("SmartFill")
        let expectedFileName = "\(baseFileName)_smartfill.mov"
        let expectedURL = smartFillDir.appendingPathComponent(expectedFileName)
        
        return expectedURL
    }
    
    /// Attempt to migrate container paths to current Documents directory
    private static func attemptContainerPathMigration(originalPath: String) -> URL? {
        let originalURL = URL(fileURLWithPath: originalPath)
        let pathComponents = originalURL.pathComponents
        
        // Check if this looks like a container path
        guard pathComponents.contains("Containers"),
              pathComponents.contains("Data"),
              pathComponents.contains("Application") else {
            return nil
        }
        
        // Extract relative path after Documents
        if let documentsIndex = pathComponents.firstIndex(of: "Documents"),
           documentsIndex < pathComponents.count - 1 {
            
            let relativeComponents = Array(pathComponents[(documentsIndex + 1)...])
            let migratedURL = relativeComponents.reduce(documentsURL()) { url, component in
                url.appendingPathComponent(component)
            }
            
            if FileManager.default.fileExists(atPath: migratedURL.path) {
                return migratedURL
            }
        }
        
        // Try looking in SmartFill directory by filename
        let smartFillDir = documentsURL().appendingPathComponent("SmartFill")
        let fileName = originalURL.lastPathComponent
        let alternativeURL = smartFillDir.appendingPathComponent(fileName)
        
        if FileManager.default.fileExists(atPath: alternativeURL.path) {
            return alternativeURL
        }
        
        return nil
    }
    
    // MARK: - Variant Resolution
    
    /// 🔥 CRITICAL PATH VOLATILITY FIX: Get the effective URL with enhanced relative path support
    public static func effectiveURL(for take: ProjectTake, preference: VariantPreference = .smartFillIfAvailable) -> URL {
        // 🚨 CRITICAL VIDEO TRIMMER FIX: Check for edited version FIRST (highest priority)
        if let editedPath = take.editedFilePath {
            let editedURL = urlForRelativePath(editedPath)
            if FileManager.default.fileExists(atPath: editedURL.path) {
                print("✅ VIDEO TRIMMER FIX: Using edited version: \(editedURL.lastPathComponent)")
                return editedURL
            } else {
                print("⚠️ VIDEO TRIMMER FIX: Edited file missing: \(editedPath)")
            }
        }

        let fileName = URL(fileURLWithPath: take.filePath).lastPathComponent
        print("🔍 PATH VOLATILITY FIX - effectiveURL for \(fileName), preference: \(preference)")
        print("   📁 Take filePath: \(take.filePath) (relative: \(!take.filePath.hasPrefix("/")))")
        
        switch preference {
        case .explicit(let variant):
            switch variant {
            case .smartFill:
                let smartFillURL = smartFillURL(for: take)
                let effectiveURL = smartFillURL ?? originalURL(for: take)
                print("   📂 Explicit SmartFill: \(effectiveURL.lastPathComponent)")
                return effectiveURL
            case .original:
                let originalURL = originalURL(for: take)
                print("   📂 Explicit Original: \(originalURL.lastPathComponent)")
                return originalURL
            }
            
        case .smartFillIfAvailable:
            // PATH VOLATILITY FIX: Enhanced SmartFill detection
            if let smartFillURL = smartFillURL(for: take) {
                print("   ✅ Using SmartFill: \(smartFillURL.lastPathComponent)")
                return smartFillURL
            }
            
            let originalURL = originalURL(for: take)
            print("   📁 Using Original (no SmartFill): \(originalURL.lastPathComponent)")
            return originalURL
            
        case .originalFirst:
            let originalURL = originalURL(for: take)
            print("   📁 Original First: \(originalURL.lastPathComponent)")
            return originalURL
        }
    }
    
    /// Get variant info for debugging
    public static func variantInfo(for take: ProjectTake) -> String {
        let hasSmartFill = hasSmartFilledVersion(for: take)
        let effectiveURL = effectiveURL(for: take)
        let smartFillURL = smartFillURL(for: take)
        let isUsingSmartFill = smartFillURL?.path == effectiveURL.path
        
        return """
        📊 PHASE 1 FIX - Variant Info for Take \(take.id):
        - Has SmartFill: \(hasSmartFill)
        - Using SmartFill: \(isUsingSmartFill)
        - Effective URL: \(effectiveURL.lastPathComponent)
        - Original Path: \(take.filePath)
        - SmartFill Path: \(take.smartFilledFilePath ?? "nil")
        - SmartFill URL: \(smartFillURL?.lastPathComponent ?? "nil")
        """
    }
}

// MARK: - ProjectTake Extensions

extension ProjectTake {
    
    /// Effective variant preference for this take
    public enum Variant: String, Codable {
        case original
        case smartFill
    }
    
    /// PHASE 1 FIX: Remove circular reference in effectiveVariant
    public var effectiveVariant: Variant {
        get {
            // PHASE 1 FIX: Simple logic - if SmartFill file exists, prefer it
            return (smartFilledFilePath != nil && VideoVariantResolver.smartFillURL(for: self) != nil) ? .smartFill : .original
        }
    }
}
