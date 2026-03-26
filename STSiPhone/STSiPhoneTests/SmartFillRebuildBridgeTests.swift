import XCTest
@testable import STSiPhone

final class SmartFillRebuildBridgeTests: XCTestCase {
    private let smartFillDefaultKeys = [
        "smartFillDefaultEnabled",
        "smartFillEnabled",
        "smartFillBlurRadius",
        "smartFillDarkenAmount",
        "smartFillBackgroundScale",
        "smartFillForegroundScale",
        "smartFillPresetName",
        "smartFillRenderWidth",
        "smartFillRenderHeight",
        "smartFillProcessingPriority",
        "smartFillForceUpdateToken"
    ]

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

    func testDefaultWorkspaceSettingsUsePersistedSmartFillDefaultsWhenSnapshotMissing() {
        let persisted = SmartFillSettings(
            isEnabled: false,
            blurRadius: 36,
            darkenAmount: 0.32,
            backgroundScale: 6.5,
            foregroundScale: 1.4,
            presetName: "Custom",
            renderSize: CGSize(width: 1280, height: 720),
            processingPriority: .high
        )

        preservingSmartFillDefaults {
            persisted.saveToUserDefaults()

            let take = ProjectTake(
                filePath: "/tmp/original.mov",
                durationSeconds: 12,
                capturedOrientation: .portrait
            )
            let session = ProjectSession(
                type: .selfTape,
                primaryOrientation: .landscape
            )

            let defaults = SmartFillTakeBridge.defaultWorkspaceSettings(for: take, in: session)

            XCTAssertEqual(defaults.snapshot.blurRadius, Double(persisted.blurRadius))
            XCTAssertEqual(defaults.snapshot.darkenAmount, Double(persisted.darkenAmount))
            XCTAssertEqual(defaults.snapshot.backgroundScale, Double(persisted.backgroundScale))
            XCTAssertEqual(defaults.snapshot.foregroundScale, Double(persisted.foregroundScale))
            XCTAssertEqual(defaults.snapshot.renderWidth, Double(persisted.renderSize.width))
            XCTAssertEqual(defaults.snapshot.renderHeight, Double(persisted.renderSize.height))
            XCTAssertEqual(defaults.snapshot.processingPriority, persisted.processingPriority.rawValue)
            XCTAssertEqual(defaults.snapshot.presetName, persisted.presetName)
            XCTAssertTrue(defaults.snapshot.isEnabled)
        }
    }

    func testEditorLaunchSeedUsesCanonicalOriginalTakeAndVariantSettings() {
        let originalID = UUID()
        let snapshot = SmartFillSettingsSnapshot(
            isEnabled: true,
            blurRadius: 20,
            darkenAmount: 0.18,
            backgroundScale: 5,
            foregroundScale: 1,
            renderWidth: 1920,
            renderHeight: 1080,
            processingPriority: "interactive",
            presetName: "Medium"
        )
        let original = ProjectTake(
            id: originalID,
            filePath: "/tmp/take_1.mov",
            durationSeconds: 12,
            sceneNumber: 2,
            takeNumber: 3,
            capturedOrientation: .portrait
        )
        let smartFillVariant = ProjectTake(
            filePath: "/tmp/take_1_smartfill.mov",
            durationSeconds: 12,
            takeNotes: "[SMARTFILL_ORIGINAL:\(originalID.uuidString)]",
            sceneNumber: 2,
            takeNumber: 3,
            capturedOrientation: .portrait,
            smartFillSettings: snapshot
        )
        let session = ProjectSession(
            type: .selfTape,
            takes: [original, smartFillVariant],
            primaryOrientation: .landscape
        )

        let seed = SmartFillTakeBridge.editorLaunchSeed(for: smartFillVariant, in: session)

        XCTAssertEqual(seed.sourceTakeID, originalID)
        XCTAssertEqual(seed.displayName, "S2T3")
        XCTAssertEqual(seed.infoTitle, "Fine-Tune SmartFill")
        XCTAssertEqual(seed.existingSettings, snapshot)
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

    private func preservingSmartFillDefaults(_ body: () -> Void) {
        let defaults = UserDefaults.standard
        let originalValues = Dictionary(uniqueKeysWithValues: smartFillDefaultKeys.map { ($0, defaults.object(forKey: $0)) })

        defer {
            for (key, value) in originalValues {
                if let value {
                    defaults.set(value, forKey: key)
                } else {
                    defaults.removeObject(forKey: key)
                }
            }
        }

        body()
    }
}
