import Foundation
import SwiftUI

/// PHASE 4: SmartFill Diagnostic Utility for identifying file path resolution issues
public struct SmartFillDiagnostics {
    
    /// Comprehensive diagnostic report for a take's SmartFill status
    public static func generateReport(for take: ProjectTake) -> SmartFillDiagnosticReport {
        var report = SmartFillDiagnosticReport(takeID: take.id, originalFileName: URL(fileURLWithPath: take.filePath).lastPathComponent)
        
        print("🔍 PHASE 4 SMARTFILL DIAGNOSTIC REPORT")
        print("=====================================")
        print("Take ID: \(take.id)")
        print("Original File: \(report.originalFileName)")
        print("")
        
        // Step 1: Check take properties
        report.capturedOrientation = take.capturedOrientation?.displayName ?? "nil"
        report.smartFilledFilePathField = take.smartFilledFilePath
        report.hasSmartFilledVersionUI = take.hasSmartFilledVersion
        
        print("📱 TAKE PROPERTIES:")
        print("   Orientation: \(report.capturedOrientation)")
        print("   SmartFill Field: \(report.smartFilledFilePathField ?? "NONE")")
        print("   UI Shows SmartFill: \(report.hasSmartFilledVersionUI)")
        print("")
        
        // Step 2: Check file existence
        report.originalFileExists = FileManager.default.fileExists(atPath: take.filePath)
        report.originalFileSize = getFileSize(path: take.filePath)
        
        print("📂 ORIGINAL FILE:")
        print("   Exists: \(report.originalFileExists)")
        print("   Size: \(report.originalFileSize)")
        print("")
        
        // Step 3: Check effectiveFilePath
        let effectiveFilePath = take.effectiveFilePath
        report.effectiveFilePath = effectiveFilePath
        report.effectiveFileExists = FileManager.default.fileExists(atPath: effectiveFilePath)
        report.effectiveFileSize = getFileSize(path: effectiveFilePath)
        report.effectivePathSameAsOriginal = (effectiveFilePath == take.filePath)
        
        print("🎯 EFFECTIVE FILE PATH:")
        print("   Path: \(effectiveFilePath)")
        print("   Exists: \(report.effectiveFileExists)")
        print("   Size: \(report.effectiveFileSize)")
        print("   Same as original: \(report.effectivePathSameAsOriginal)")
        print("")
        
        // Step 4: Check VideoVariantResolver
        if let smartFillURL = VideoVariantResolver.smartFillURL(for: take) {
            report.resolverFoundSmartFill = true
            report.resolverSmartFillPath = smartFillURL.path
            report.resolverSmartFillExists = FileManager.default.fileExists(atPath: smartFillURL.path)
            report.resolverSmartFillSize = getFileSize(path: smartFillURL.path)
        } else {
            report.resolverFoundSmartFill = false
        }
        
        print("🔧 VIDEO VARIANT RESOLVER:")
        print("   Found SmartFill: \(report.resolverFoundSmartFill)")
        if let path = report.resolverSmartFillPath {
            print("   SmartFill Path: \(path)")
            print("   SmartFill Exists: \(report.resolverSmartFillExists)")
            print("   SmartFill Size: \(report.resolverSmartFillSize)")
        }
        print("")
        
        // Step 5: Search SmartFill directory manually
        let smartFillDir = VideoVariantResolver.documentsURL().appendingPathComponent("SmartFill")
        let baseFileName = report.originalFileName.replacingOccurrences(of: ".mov", with: "").replacingOccurrences(of: ".mp4", with: "")
        
        let searchPatterns = [
            "\(baseFileName)_smartfill.mov",
            "\(baseFileName)_SmartFill.mov",
            "smartfill_\(take.id.uuidString).mov"
        ]
        
        print("🔍 SMARTFILL DIRECTORY SEARCH:")
        print("   Directory: \(smartFillDir.path)")
        for pattern in searchPatterns {
            let candidateURL = smartFillDir.appendingPathComponent(pattern)
            let exists = FileManager.default.fileExists(atPath: candidateURL.path)
            let size = exists ? getFileSize(path: candidateURL.path) : "N/A"
            print("   Pattern: \(pattern) - Exists: \(exists) - Size: \(size)")
            
            if exists && report.directoryFoundSmartFill == nil {
                report.directoryFoundSmartFill = candidateURL.path
                report.directorySmartFillSize = size
            }
        }
        print("")
        
        // Step 6: Analysis and recommendations
        report.analysisResult = analyzeResults(report)
        
        print("🎯 ANALYSIS:")
        print(report.analysisResult)
        print("")
        print("=====================================")
        
        return report
    }
    
    private static func getFileSize(path: String) -> String {
        guard FileManager.default.fileExists(atPath: path) else {
            return "FILE NOT FOUND"
        }
        
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: path)
            if let fileSize = attributes[.size] as? Int64 {
                return ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
            }
        } catch {
            return "ERROR: \(error)"
        }
        
        return "UNKNOWN"
    }
    
    private static func analyzeResults(_ report: SmartFillDiagnosticReport) -> String {
        var analysis: [String] = []
        
        // UI vs Reality Check
        if report.hasSmartFilledVersionUI && !report.resolverFoundSmartFill {
            analysis.append("🚨 CRITICAL ISSUE: UI shows SmartFill available but VideoVariantResolver cannot find file!")
            
            if let directoryFound = report.directoryFoundSmartFill {
                analysis.append("💡 FOUND ISSUE: SmartFill file exists in directory but resolver logic failed!")
                analysis.append("   File: \(URL(fileURLWithPath: directoryFound).lastPathComponent)")
                analysis.append("   Recommended fix: Update smartFilledFilePath field in repository")
            } else {
                analysis.append("💔 CRITICAL: No SmartFill file found anywhere - processing may have failed")
            }
        }
        
        // effectiveFilePath Analysis
        if report.effectivePathSameAsOriginal && report.hasSmartFilledVersionUI {
            analysis.append("🔍 ISSUE: effectiveFilePath same as original despite UI showing SmartFill")
        }
        
        if !report.effectiveFileExists {
            analysis.append("❌ CRITICAL: effectiveFilePath points to non-existent file!")
        }
        
        // Resolution Inconsistency
        if report.hasSmartFilledVersionUI != report.resolverFoundSmartFill {
            analysis.append("⚖️ INCONSISTENCY: UI state differs from VideoVariantResolver result")
        }
        
        // Success Case
        if report.hasSmartFilledVersionUI && report.resolverFoundSmartFill && report.resolverSmartFillExists {
            analysis.append("✅ SUCCESS: SmartFill system working correctly")
        }
        
        if analysis.isEmpty {
            return "ℹ️ No SmartFill processing expected or detected for this take"
        }
        
        return analysis.joined(separator: "\n")
    }
}

/// PHASE 4: Diagnostic report data structure
public struct SmartFillDiagnosticReport {
    public let takeID: UUID
    public let originalFileName: String
    
    // Take properties
    public var capturedOrientation: String = ""
    public var smartFilledFilePathField: String?
    public var hasSmartFilledVersionUI: Bool = false
    
    // File existence
    public var originalFileExists: Bool = false
    public var originalFileSize: String = ""
    
    // effectiveFilePath analysis
    public var effectiveFilePath: String = ""
    public var effectiveFileExists: Bool = false
    public var effectiveFileSize: String = ""
    public var effectivePathSameAsOriginal: Bool = true
    
    // VideoVariantResolver analysis
    public var resolverFoundSmartFill: Bool = false
    public var resolverSmartFillPath: String?
    public var resolverSmartFillExists: Bool = false
    public var resolverSmartFillSize: String = ""
    
    // Directory search results
    public var directoryFoundSmartFill: String?
    public var directorySmartFillSize: String = ""
    
    // Analysis
    public var analysisResult: String = ""
    
    public init(takeID: UUID, originalFileName: String) {
        self.takeID = takeID
        self.originalFileName = originalFileName
    }
}

/// PHASE 4: SwiftUI view for displaying diagnostic report
public struct SmartFillDiagnosticsView: View {
    let report: SmartFillDiagnosticReport
    
    public var body: some View {
        NavigationView {
            List {
                Section("Take Information") {
                    DiagnosticInfoRow(label: "File Name", value: report.originalFileName)
                    DiagnosticInfoRow(label: "Take ID", value: report.takeID.uuidString)
                    DiagnosticInfoRow(label: "Orientation", value: report.capturedOrientation)
                    DiagnosticInfoRow(label: "UI Shows SmartFill", value: report.hasSmartFilledVersionUI ? "YES" : "NO")
                }
                
                Section("Original File") {
                    DiagnosticInfoRow(label: "Exists", value: report.originalFileExists ? "YES" : "NO")
                    DiagnosticInfoRow(label: "Size", value: report.originalFileSize)
                }
                
                Section("Effective Path") {
                    DiagnosticInfoRow(label: "Same as Original", value: report.effectivePathSameAsOriginal ? "YES" : "NO")
                    DiagnosticInfoRow(label: "Exists", value: report.effectiveFileExists ? "YES" : "NO")
                    DiagnosticInfoRow(label: "Size", value: report.effectiveFileSize)
                }
                
                Section("VideoVariantResolver") {
                    DiagnosticInfoRow(label: "Found SmartFill", value: report.resolverFoundSmartFill ? "YES" : "NO")
                    if let path = report.resolverSmartFillPath {
                        DiagnosticInfoRow(label: "SmartFill Path", value: URL(fileURLWithPath: path).lastPathComponent)
                        DiagnosticInfoRow(label: "SmartFill Exists", value: report.resolverSmartFillExists ? "YES" : "NO")
                        DiagnosticInfoRow(label: "SmartFill Size", value: report.resolverSmartFillSize)
                    }
                }
                
                if let directoryFound = report.directoryFoundSmartFill {
                    Section("Directory Search") {
                        DiagnosticInfoRow(label: "Found File", value: URL(fileURLWithPath: directoryFound).lastPathComponent)
                        DiagnosticInfoRow(label: "Size", value: report.directorySmartFillSize)
                    }
                }
                
                Section("Analysis") {
                    Text(report.analysisResult)
                        .font(.caption)
                        .foregroundColor(report.analysisResult.contains("CRITICAL") ? .red : 
                                        report.analysisResult.contains("SUCCESS") ? .green : .primary)
                }
            }
            .navigationTitle("SmartFill Diagnostics")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct DiagnosticInfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
        }
    }
}
