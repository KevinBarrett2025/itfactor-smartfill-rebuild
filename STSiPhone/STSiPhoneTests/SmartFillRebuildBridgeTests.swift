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

    func testNotificationBackedResultBridgeBuildsStandaloneRecord() {
        let projectID = UUID()
        let sessionID = UUID()
        let takeID = UUID()
        let adoptedTakeID = UUID()
        let context = SmartFillSessionContext(
            projectID: projectID,
            sessionID: sessionID,
            takeID: takeID,
            launchSource: .takeReview,
            returnTarget: .takeReview
        )

        let notification = Notification(
            name: .smartFillDidComplete,
            object: nil,
            userInfo: [
                "originalTakeID": takeID,
                "lineageOriginalTakeID": takeID,
                "smartFillTakeID": adoptedTakeID,
                "sessionID": sessionID,
                "projectID": projectID,
                "smartFillPath": "/tmp/output_smartfill.mov",
                "approach": "standalone"
            ]
        )

        let record = SmartFillResultBridge.makeAdoptionRecord(
            from: notification,
            matching: context,
            settingsSnapshot: nil
        )

        XCTAssertEqual(record?.adoptionMode, .createStandaloneVariantTake)
        XCTAssertEqual(record?.adoptedTakeID, adoptedTakeID)
        XCTAssertEqual(record?.originalTakeID, takeID)
        XCTAssertEqual(record?.projectID, projectID)
        XCTAssertEqual(record?.sessionID, sessionID)
    }

    func testNotificationBackedResultBridgeBuildsInlineRecord() {
        let projectID = UUID()
        let sessionID = UUID()
        let takeID = UUID()
        let context = SmartFillSessionContext(
            projectID: projectID,
            sessionID: sessionID,
            takeID: takeID,
            launchSource: .takeReview,
            returnTarget: .takeReview
        )

        let notification = Notification(
            name: .smartFillDidComplete,
            object: nil,
            userInfo: [
                "originalTakeID": takeID,
                "smartFillTakeID": takeID,
                "sessionID": sessionID,
                "projectID": projectID,
                "smartFillPath": "/tmp/output_smartfill.mov",
                "approach": "inline"
            ]
        )

        let record = SmartFillResultBridge.makeAdoptionRecord(
            from: notification,
            matching: context,
            settingsSnapshot: nil
        )

        XCTAssertEqual(record?.adoptionMode, .updateExistingTakePath)
        XCTAssertEqual(record?.adoptedTakeID, takeID)
        XCTAssertEqual(record?.originalTakeID, takeID)
    }

    func testSettingsRoundTripPreservesSnapshotValues() {
        let settings = SmartFillSettings(
            isEnabled: true,
            blurRadius: 28,
            darkenAmount: 0.18,
            backgroundScale: 4.5,
            foregroundScale: 1.2,
            presetName: "Medium",
            renderSize: CGSize(width: 1280, height: 720),
            processingPriority: .high
        )

        let snapshot = SmartFillTakeBridge.snapshot(from: settings)
        let restored = SmartFillTakeBridge.settings(from: snapshot)

        XCTAssertEqual(snapshot.isEnabled, true)
        XCTAssertEqual(snapshot.renderWidth, 1280)
        XCTAssertEqual(snapshot.processingPriority, SmartFillSettings.ProcessingPriority.high.rawValue)
        XCTAssertEqual(restored.isEnabled, settings.isEnabled)
        XCTAssertEqual(restored.blurRadius, settings.blurRadius)
        XCTAssertEqual(restored.darkenAmount, settings.darkenAmount)
        XCTAssertEqual(restored.backgroundScale, settings.backgroundScale)
        XCTAssertEqual(restored.renderSize.width, settings.renderSize.width)
        XCTAssertEqual(restored.renderSize.height, settings.renderSize.height)
        XCTAssertEqual(restored.processingPriority, settings.processingPriority)
    }

    @MainActor
    func testCoordinatorBeginsInConfigureAndCompletesWithResultRecord() {
        let coordinator = SmartFillWorkspaceCoordinator()
        let context = SmartFillSessionContext(
            projectID: UUID(),
            sessionID: UUID(),
            takeID: UUID(),
            launchSource: .takeReview,
            returnTarget: .takeReview
        )
        let defaults = SmartFillWorkspaceDefaults(
            snapshot: SmartFillSettingsSnapshot(
                isEnabled: true,
                blurRadius: 24,
                darkenAmount: 0.12,
                backgroundScale: 3,
                foregroundScale: 1,
                renderWidth: 1920,
                renderHeight: 1080,
                processingPriority: "interactive",
                presetName: "Medium"
            ),
            usesSessionOverride: true,
            shouldOfferSmartFill: true
        )

        coordinator.begin(context: context, defaults: defaults)
        XCTAssertEqual(coordinator.stage, .configure)
        XCTAssertEqual(coordinator.activeContext, context)

        let result = SmartFillResultBridgeRecord(
            projectID: context.projectID,
            sessionID: context.sessionID,
            originalTakeID: context.takeID,
            adoptedTakeID: context.takeID,
            outputURL: URL(fileURLWithPath: "/tmp/output_smartfill.mov"),
            duration: 5,
            settingsSnapshot: defaults.snapshot,
            adoptionMode: .updateExistingTakePath,
            destinationSummary: "Refresh the existing SmartFill variant in session review."
        )
        coordinator.recordResult(result)

        XCTAssertEqual(coordinator.stage, .completed)
        XCTAssertEqual(coordinator.lastResult?.outputURL.path, "/tmp/output_smartfill.mov")
    }
}
