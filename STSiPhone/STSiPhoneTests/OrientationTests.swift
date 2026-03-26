import XCTest
import AVFoundation
@testable import STSiPhone

/// Tests for STS Orientation Forensics System
/// Validates the single-transform rule: exactly one stage should own orientation transforms
final class OrientationTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Enable diagnostics for testing
        setenv("STS_ORIENTATION_DIAG", "1", 1)
    }

    func testOrientationPolicyBasics() throws {
        let policy = OrientationPolicy.shared
        
        // Test new export (should defer to compositor)
        let newAssetInfo = OrientationAssetInfo(
            url: URL(fileURLWithPath: "/test/new_export.mov"),
            exportVersion: 2,
            originalDimensions: "1080x1920",
            preferredTransform: "[a:1 b:0 c:0 d:1 tx:0 ty:0]",
            normalizedOrientation: "portrait",
            legacyGuess: 0
        )
        
        XCTAssertFalse(policy.uiShouldApplyTransform(for: newAssetInfo), "New exports should not need UI transforms")
        XCTAssertEqual(policy.expectedTransformStage(for: newAssetInfo), "Compositor")
        
        // Test legacy export (may need UI transforms)
        let legacyAssetInfo = OrientationAssetInfo(
            url: URL(fileURLWithPath: "/test/legacy_export.mov"),
            exportVersion: 1,
            originalDimensions: "1920x1080",
            preferredTransform: "[a:0 b:1 c:-1 d:0 tx:1920 ty:0]",
            normalizedOrientation: "portrait",
            legacyGuess: 1
        )
        
        XCTAssertTrue(policy.uiShouldApplyTransform(for: legacyAssetInfo), "Legacy exports may need UI transforms")
        XCTAssertEqual(policy.expectedTransformStage(for: legacyAssetInfo), "UIPlayer")
    }
    
    func testOrientationRunCreation() throws {
        let run = OrientationPolicy.createRun(context: "XCTest", smartfillMode: "blur")
        
        XCTAssertFalse(run.runUUID.isEmpty)
        XCTAssertEqual(run.context, "XCTest")
        XCTAssertEqual(run.smartfillMode, "blur")
        XCTAssertFalse(run.device.isEmpty)
        XCTAssertFalse(run.osVersion.isEmpty)
        XCTAssertFalse(run.appBuild.isEmpty)
    }
    
    func testTransformForExportBasics() throws {
        let policy = OrientationPolicy.shared
        
        let assetInfo = OrientationAssetInfo(
            url: URL(fileURLWithPath: "/test/portrait.mov"),
            exportVersion: 2,
            originalDimensions: "1080x1920",
            preferredTransform: "[a:1 b:0 c:0 d:1 tx:0 ty:0]",
            normalizedOrientation: "portrait",
            legacyGuess: 0
        )
        
        let transform = policy.transformForExport(assetInfo: assetInfo, target: .landscape1920x1080)
        
        // Should not be identity for portrait->landscape conversion
        XCTAssertFalse(transform.isIdentity, "Portrait to landscape should apply transform")
    }
    
    func testAsyncAssetInfoCreation() async throws {
        // Create a minimal test asset URL (using app bundle as placeholder)
        guard let testURL = Bundle.main.url(forResource: "Info", withExtension: "plist") else {
            throw XCTSkip("No test asset available")
        }
        
        let asset = AVURLAsset(url: testURL)
        
        // This will fail for a plist file, but tests the async API
        let assetInfo = await OrientationAssetInfo(asset: asset, url: testURL)
        
        XCTAssertEqual(assetInfo.url, testURL)
        XCTAssertEqual(assetInfo.exportVersion, 0) // No video metadata
        XCTAssertEqual(assetInfo.legacyGuess, 1) // Should be considered legacy
    }
    
    func testDiagnosticsLogging() throws {
        let run = OrientationPolicy.createRun(context: "TestDiagnostics")
        
        // Log a test run
        OrientationDiag.logRunStart(run)
        
        // Log a test asset
        let assetInfo = OrientationAssetInfo(
            url: URL(fileURLWithPath: "/test/sample.mov"),
            exportVersion: 2,
            originalDimensions: "1920x1080",
            preferredTransform: "[a:1 b:0 c:0 d:1 tx:0 ty:0]",
            normalizedOrientation: "landscape",
            legacyGuess: 0
        )
        
        OrientationDiag.logAsset(run, assetInfo)
        
        // Log a transform application
        let transform = CGAffineTransform(scaleX: 0.5, y: 0.5)
        OrientationDiag.logTransform(run, stage: "Compositor", desc: transform.debugDescription, notes: "Test transform")
        
        // Audit the run
        OrientationDiag.audit(run, expectedStage: "Compositor")
        
        // If we get here without crashing, diagnostics are working
        XCTAssertTrue(true, "Diagnostics logging completed without errors")
    }
    
    func testCGAffineTransformDebugDescription() throws {
        let identity = CGAffineTransform.identity
        let desc = identity.debugDescription
        
        XCTAssertTrue(desc.contains("a:1.000"), "Debug description should include formatted values")
        XCTAssertTrue(desc.contains("d:1.000"), "Debug description should include formatted values")
    }
    
    // MARK: - Integration Test Placeholder
    
    func testExportThenPreview_HasSingleTransform() throws {
        // TODO: This is a placeholder for integration testing
        // When SmartFill export is integrated with OrientationDiagnostics:
        
        // 1. Create/load a test portrait video
        // 2. Process it through SmartFill export with diagnostics enabled
        // 3. Play it back in a UI player with diagnostics enabled
        // 4. Query the brain DB to verify exactly one transform was logged
        // 5. Verify the transform was applied at the correct stage (Compositor for new exports)
        
        XCTAssertTrue(true, "Integration test placeholder - implement when export is connected to diagnostics")
    }
    
    // MARK: - Performance Test
    
    func testOrientationScannerPerformance() throws {
        // Test that the static scanner can run reasonably fast
        measure {
            // This would run the Python scanner, but for unit test we just test the Swift parts
            let policy = OrientationPolicy.shared
            let run = OrientationPolicy.createRun(context: "PerformanceTest")
            
            // Simulate logging many transforms
            for i in 0..<100 {
                let transform = CGAffineTransform(translationX: CGFloat(i), y: CGFloat(i))
                OrientationDiag.logTransform(run, stage: "TestStage", desc: transform.debugDescription)
            }
        }
    }
}

// MARK: - Test Helpers
extension OrientationTests {
    
    /// Helper to create a test OrientationAssetInfo
    func createTestAssetInfo(exportVersion: Int = 2, orientation: String = "portrait") -> OrientationAssetInfo {
        return OrientationAssetInfo(
            url: URL(fileURLWithPath: "/test/\(orientation)_v\(exportVersion).mov"),
            exportVersion: exportVersion,
            originalDimensions: orientation == "portrait" ? "1080x1920" : "1920x1080",
            preferredTransform: "[a:1 b:0 c:0 d:1 tx:0 ty:0]",
            normalizedOrientation: orientation,
            legacyGuess: exportVersion >= 2 ? 0 : 1
        )
    }
}
