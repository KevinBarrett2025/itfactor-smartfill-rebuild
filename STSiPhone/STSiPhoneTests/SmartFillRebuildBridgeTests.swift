import XCTest
@testable import STSiPhone

final class SmartFillRebuildBridgeTests: XCTestCase {
    func testShouldOfferSmartFillForPortraitTakeInLandscapeSession() {
        let take = ProjectTake(
            filePath: "/tmp/original.mov",
            durationSeconds: 12,
            capturedOrientation: .portrait
        )
        let session = ProjectSession(
            type: .selfTape,
            primaryOrientation: .landscape
        )

        XCTAssertTrue(SmartFillTakeBridge.shouldOfferSmartFill(for: take, in: session))
    }

    func testShouldNotOfferSmartFillForSlateLikeTake() {
        let take = ProjectTake(
            filePath: "/tmp/slate.mov",
            durationSeconds: 3,
            capturedOrientation: .portrait,
            takeType: .slate
        )
        let session = ProjectSession(
            type: .selfTape,
            primaryOrientation: .landscape
        )

        XCTAssertFalse(SmartFillTakeBridge.shouldOfferSmartFill(for: take, in: session))
    }

    func testDefaultWorkspaceSettingsPreferTakeSnapshotWhenAvailable() {
        let snapshot = SmartFillSettingsSnapshot(
            isEnabled: true,
            blurRadius: 18,
            darkenAmount: 0.2,
            backgroundScale: 8,
            foregroundScale: 1,
            renderWidth: 1280,
            renderHeight: 720,
            processingPriority: "interactive",
            presetName: "Custom"
        )
        let take = ProjectTake(
            filePath: "/tmp/original.mov",
            durationSeconds: 12,
            capturedOrientation: .portrait,
            smartFillSettings: snapshot
        )
        let session = ProjectSession(
            type: .selfTape,
            primaryOrientation: .landscape,
            smartFillEnabled: false
        )

        let defaults = SmartFillTakeBridge.defaultWorkspaceSettings(for: take, in: session)

        XCTAssertEqual(defaults.snapshot, snapshot)
        XCTAssertTrue(defaults.usesSessionOverride)
        XCTAssertTrue(defaults.shouldOfferSmartFill)
    }

    func testResultBridgeCreatesVariantForOriginalTake() {
        let take = ProjectTake(
            filePath: "/tmp/original.mov",
            durationSeconds: 12,
            takeType: .regular
        )

        let result = SmartFillResultBridge.makeAdoptionRecord(
            outputURL: URL(fileURLWithPath: "/tmp/output_smartfill.mov"),
            duration: 12,
            settingsSnapshot: nil,
            take: take
        )

        XCTAssertEqual(result.adoptionMode, .createStandaloneVariantTake)
    }
}
