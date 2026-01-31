import Foundation
import AVFoundation
import os.log

// MARK: - Diagnostics DB minimal wrapper (Development Only)
enum DiagnosticsDB {
    static let dbPath = "/Users/kevinbarrett/SelfTapeStudio/Development/BRAIN/STS_MasterBrain.sqlite3"
    
    static func exec(_ sql: String, _ bind: (() -> Void)? = nil) {
        // Fallback logging for development - SQLite integration can be enhanced later
        #if DEBUG
        print("🔍 DiagnosticsDB SQL: \(sql)")
        bind?()
        #endif
    }
}

// MARK: - Models
public struct OrientationRun {
    public let runUUID: String
    public let context: String           // "EditorPreview" | "TakeReviewPage" | "Export"
    public let smartfillMode: String     // "blur" | "darken" | "none" | etc.
    public let device: String
    public let osVersion: String
    public let appBuild: String
    
    public init(runUUID: String, context: String, smartfillMode: String, device: String, osVersion: String, appBuild: String) {
        self.runUUID = runUUID
        self.context = context
        self.smartfillMode = smartfillMode
        self.device = device
        self.osVersion = osVersion
        self.appBuild = appBuild
    }
}

public struct OrientationAssetInfo {
    public let url: URL
    public let exportVersion: Int
    public let originalDimensions: String
    public let preferredTransform: String
    public let normalizedOrientation: String
    public let legacyGuess: Int
    
    public init(url: URL, exportVersion: Int, originalDimensions: String, preferredTransform: String, normalizedOrientation: String, legacyGuess: Int) {
        self.url = url
        self.exportVersion = exportVersion
        self.originalDimensions = originalDimensions
        self.preferredTransform = preferredTransform
        self.normalizedOrientation = normalizedOrientation
        self.legacyGuess = legacyGuess
    }
}

public enum OrientationDiag {
    
    #if DEBUG || STS_ORIENTATION_DIAG
    private static let diagnosticsEnabled = true
    #else
    private static let diagnosticsEnabled = ProcessInfo.processInfo.environment["STS_ORIENTATION_DIAG"] == "1"
    #endif
    
    public static func logRunStart(_ run: OrientationRun) {
        guard diagnosticsEnabled else { return }
        
        print("🔍 OrientationDiag: Starting run \(run.runUUID) - \(run.context)")
        
        // Log to console in Debug builds, could integrate with full SQLite later
        DiagnosticsDB.exec("OrientationRuns INSERT: \(run.runUUID), \(run.context), \(run.smartfillMode)")
    }

    public static func logAsset(_ run: OrientationRun, _ info: OrientationAssetInfo) {
        guard diagnosticsEnabled else { return }
        
        print("🔍 OrientationDiag: Asset \(info.url.lastPathComponent) - export v\(info.exportVersion), \(info.normalizedOrientation)")
        
        DiagnosticsDB.exec("OrientationAssets INSERT: \(run.runUUID), \(info.url.lastPathComponent), v\(info.exportVersion)")
    }

    public static func logTransform(_ run: OrientationRun, stage: String, desc: String, notes: String? = nil) {
        guard diagnosticsEnabled else { return }
        
        print("🔍 OrientationDiag: Transform at \(stage): \(desc)")
        if let notes = notes {
            print("   Notes: \(notes)")
        }
        
        DiagnosticsDB.exec("OrientationApplications INSERT: \(run.runUUID), \(stage), \(desc)")
    }

    public static func audit(_ run: OrientationRun, expectedStage: String) {
        guard diagnosticsEnabled else { return }
        
        print("🔍 OrientationDiag: Auditing run \(run.runUUID) - expected stage: \(expectedStage)")
        
        DiagnosticsDB.exec("OrientationPolicyAudits INSERT: \(run.runUUID), \(expectedStage)")
    }
}

// MARK: - Helpers to build OrientationAssetInfo from AVAsset
extension OrientationAssetInfo {
    public init(asset: AVAsset, url: URL) async {
        // Use modern async API for iOS 15+ compatibility
        let videoTracks = try? await asset.loadTracks(withMediaType: .video)
        let track = videoTracks?.first
        
        let natural = (try? await track?.load(.naturalSize)) ?? .zero
        let dims = "\(Int(natural.width))x\(Int(natural.height))"
        
        let pt = (try? await track?.load(.preferredTransform)) ?? .identity
        let ptDesc = "[a:\(pt.a) b:\(pt.b) c:\(pt.c) d:\(pt.d) tx:\(pt.tx) ty:\(pt.ty)]"

        let orientation = OrientationAssetInfo.describeOrientation(transform: pt, size: natural)
        let exportVer = await OrientationAssetInfo.extractExportVersion(from: asset) ?? 0
        let legacy = exportVer >= 2 ? 0 : 1

        self.init(url: url,
                  exportVersion: exportVer,
                  originalDimensions: dims,
                  preferredTransform: ptDesc,
                  normalizedOrientation: orientation,
                  legacyGuess: legacy)
    }
    
    private static func extractExportVersion(from asset: AVAsset) async -> Int? {
        if #available(iOS 16.0, *) {
            if let metadata = try? await asset.load(.commonMetadata) {
                return await extractExportVersion(from: metadata)
            }
        }
        let metadata = legacyCommonMetadata(from: asset)
        return await extractExportVersion(from: metadata)
    }
    
    private static func legacyCommonMetadata(from asset: AVAsset) -> [AVMetadataItem] {
        (asset.value(forKey: "commonMetadata") as? [AVMetadataItem]) ?? []
    }

    private static func extractExportVersion(from metadata: [AVMetadataItem]) async -> Int? {
        for item in metadata {
            if let key = item.commonKey?.rawValue.lowercased(),
               (key.contains("description") || key.contains("title") || key.contains("comment")) {
                var valueString: String?
                if #available(iOS 16.0, *) {
                    valueString = try? await item.load(.stringValue)
                } else {
                    valueString = item.stringValue
                }
                if let value = valueString,
                   let range = value.range(of: "STSExportVersion=") {
                    let suffix = value[range.upperBound...]
                    if let component = suffix.split(separator: " ").first,
                       let version = Int(component) {
                        return version
                    }
                }
            }
        }
        return nil
    }

    private static func describeOrientation(transform t: CGAffineTransform, size: CGSize) -> String {
        // Simple heuristic; refine if needed based on STS orientation logic
        if t.a == 0 && t.b == 1 && t.c == -1 && t.d == 0 { return "portrait" }           // 90°
        if t.a == 0 && t.b == -1 && t.c == 1 && t.d == 0 { return "portraitUpsideDown" } // -90°
        if t.a == -1 && t.d == -1 { return "landscapeRight" }                             // 180°
        if t.a == 1 && t.d == 1 { return size.width >= size.height ? "landscape" : "portrait" }
        return "unknown"
    }
}

// MARK: - Utility Extensions
extension CGAffineTransform {
    public var debugDescription: String { 
        "[a:\(String(format: "%.3f", a)) b:\(String(format: "%.3f", b)) c:\(String(format: "%.3f", c)) d:\(String(format: "%.3f", d)) tx:\(String(format: "%.1f", tx)) ty:\(String(format: "%.1f", ty))]" 
    }
}

// MARK: - Quick Device Info Helper
public func appBuildString() -> String {
    let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
    let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
    return "\(short) (\(v))"
}
