import AVFoundation
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
        "smartFillBackgroundSourceMode",
        "smartFillBackgroundAssetPath",
        "smartFillBackgroundAssetDisplayName",
        "smartFillBackgroundVideoTakeID",
        "smartFillPresetName",
        "smartFillRenderWidth",
        "smartFillRenderHeight",
        "smartFillProcessingPriority",
        "smartFillForceUpdateToken"
    ]

    @MainActor
    func testModernSmartFillPlayerWrapsExistingAVPlayerWithoutReusingItemInSecondPlayer() {
        let item = AVPlayerItem(asset: AVMutableComposition())
        let player = AVPlayer(playerItem: item)

        let wrapped = ModernSmartFillPlayer(player: player)

        XCTAssertTrue(wrapped.player === player)
        XCTAssertTrue(wrapped.player.currentItem === item)
    }

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

    func testPlayerEntryResolverRequestsSmartFillForPortraitTakeWithoutCompanion() {
        let original = ProjectTake(
            id: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!,
            filePath: "/tmp/original.mov",
            durationSeconds: 12,
            capturedOrientation: .portrait
        )
        let session = ProjectSession(
            type: .selfTape,
            takes: [original],
            primaryOrientation: .landscape
        )

        XCTAssertEqual(
            SmartFillPlayerEntryResolver.resolve(for: original, in: session),
            .request(targetTake: original)
        )
    }

    func testPlayerEntryResolverEditsExistingCompanionForOriginalPortraitTake() {
        let originalID = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!
        let original = ProjectTake(
            id: originalID,
            filePath: "/tmp/original.mov",
            durationSeconds: 12,
            capturedOrientation: .portrait
        )
        let companion = ProjectTake(
            id: UUID(uuidString: "66666666-7777-8888-9999-AAAAAAAAAAAA")!,
            filePath: "/tmp/original_smartfill.mov",
            durationSeconds: 12,
            takeNotes: "[SMARTFILL_ORIGINAL:\(originalID.uuidString)]",
            capturedOrientation: .portrait
        )
        let session = ProjectSession(
            type: .selfTape,
            takes: [original, companion],
            primaryOrientation: .landscape
        )

        XCTAssertEqual(
            SmartFillPlayerEntryResolver.resolve(for: original, in: session),
            .edit(targetTake: companion)
        )
    }

    func testPlayerEntryResolverEditsCurrentTakeWhenAlreadyOnSmartFillVariant() {
        let originalID = UUID(uuidString: "BBBBBBBB-CCCC-DDDD-EEEE-FFFFFFFFFFFF")!
        let variant = ProjectTake(
            id: UUID(uuidString: "12345678-1234-1234-1234-1234567890AB")!,
            filePath: "/tmp/original_smartfill.mov",
            durationSeconds: 12,
            takeNotes: "[SMARTFILL_ORIGINAL:\(originalID.uuidString)]",
            capturedOrientation: .portrait
        )
        let session = ProjectSession(
            type: .selfTape,
            takes: [variant],
            primaryOrientation: .landscape
        )

        XCTAssertEqual(
            SmartFillPlayerEntryResolver.resolve(for: variant, in: session),
            .edit(targetTake: variant)
        )
    }

    func testPlayerEntryResolverHidesForExportDeliverableWithoutSmartFillPath() {
        let exported = ProjectTake(
            filePath: "/tmp/exported.mov",
            durationSeconds: 12,
            capturedOrientation: .landscape,
            takeType: .exported
        )
        let session = ProjectSession(
            type: .selfTape,
            takes: [exported],
            primaryOrientation: .landscape
        )

        XCTAssertNil(SmartFillPlayerEntryResolver.resolve(for: exported, in: session))
    }

    func testHomeScreenSmartFillRouteBuildsPlayerRequestContext() {
        let take = ProjectTake(
            filePath: "/tmp/original.mov",
            durationSeconds: 12,
            sceneNumber: 1,
            takeNumber: 2,
            capturedOrientation: .portrait
        )
        let session = ProjectSession(
            type: .selfTape,
            takes: [take],
            primaryOrientation: .landscape
        )
        let project = Project(title: "Project", sessions: [session])

        let context = HomeScreenSmartFillRoute.requestContext(
            for: take,
            session: session,
            project: project
        )

        XCTAssertEqual(context.take.id, take.id)
        XCTAssertEqual(context.launchSource, .swipeablePlayer)
        XCTAssertEqual(context.returnTarget, .swipeablePlayer)
        XCTAssertEqual(context.displayName, "Take 2")
        XCTAssertEqual(context.infoTitle, "SmartFill Required Before Editing")
        XCTAssertNil(context.existingSettings)
    }

    func testHomeScreenSmartFillRouteBuildsEditContextFromVariantTake() {
        let originalID = UUID(uuidString: "ABCDEFAB-CDEF-ABCD-EFAB-CDEFABCDEFAB")!
        let snapshot = SmartFillSettingsSnapshot(
            isEnabled: true,
            blurRadius: 20,
            darkenAmount: 0.18,
            backgroundScale: 5,
            foregroundScale: 1.1,
            renderWidth: 1920,
            renderHeight: 1080,
            processingPriority: "interactive",
            presetName: "Medium"
        )
        let original = ProjectTake(
            id: originalID,
            filePath: "/tmp/original.mov",
            durationSeconds: 12,
            sceneNumber: 2,
            takeNumber: 4,
            capturedOrientation: .portrait
        )
        let variant = ProjectTake(
            filePath: "/tmp/original_smartfill.mov",
            durationSeconds: 12,
            takeNotes: "[SMARTFILL_ORIGINAL:\(originalID.uuidString)]",
            sceneNumber: 2,
            takeNumber: 4,
            capturedOrientation: .portrait,
            smartFillSettings: snapshot
        )
        let session = ProjectSession(
            type: .selfTape,
            takes: [original, variant],
            primaryOrientation: .landscape
        )
        let project = Project(title: "Project", sessions: [session])

        let context = HomeScreenSmartFillRoute.editContext(
            for: variant,
            session: session,
            project: project
        )

        XCTAssertEqual(context?.take.id, original.id)
        XCTAssertEqual(context?.displayName, "S2T4")
        XCTAssertEqual(context?.infoTitle, "Fine-Tune SmartFill")
        XCTAssertEqual(context?.existingSettings?.blurRadius, 20)
        XCTAssertEqual(context?.existingSettings?.renderSize, CGSize(width: 1920, height: 1080))
    }

    func testHomeScreenSmartFillRouteBuildsPlayerReopenContext() {
        let originalID = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!
        let adoptedID = UUID(uuidString: "66666666-7777-8888-9999-AAAAAAAAAAAA")!
        let original = ProjectTake(
            id: originalID,
            filePath: "/tmp/original.mov",
            durationSeconds: 12,
            sceneNumber: 3,
            takeNumber: 1,
            capturedOrientation: .portrait
        )
        let adopted = ProjectTake(
            id: adoptedID,
            filePath: "/tmp/original_smartfill.mov",
            durationSeconds: 12,
            sceneNumber: 3,
            takeNumber: 1,
            capturedOrientation: .portrait
        )
        let session = ProjectSession(
            type: .selfTape,
            takes: [original, adopted],
            primaryOrientation: .landscape
        )
        let record = SmartFillResultBridgeRecord(
            projectID: UUID(),
            sessionID: session.id,
            originalTakeID: originalID,
            adoptedTakeID: adoptedID,
            adoptedTakeDisplayName: "S3T1 SmartFill",
            outputURL: URL(fileURLWithPath: "/tmp/output.mov"),
            duration: 12,
            settingsSnapshot: nil,
            adoptionMode: .createStandaloneVariantTake,
            destinationSummary: "Create or refresh S3T1 SmartFill in this session."
        )

        let context = HomeScreenSmartFillRoute.reopenContext(for: record, in: session)

        XCTAssertEqual(context.title, "S3T1 SmartFill")
        XCTAssertEqual(context.sourceTakeID, originalID)
        XCTAssertEqual(context.sourceTakeDisplayName, "S3T1")
        XCTAssertEqual(context.playerComparisonActionTitle, "Compare with S3T1")
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
        XCTAssertEqual(result.adoptedTakeDisplayName, "Take 1 SmartFill")
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
                "smartFillTakeLabel": "S1T1 SmartFill",
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
        XCTAssertEqual(record?.adoptedTakeDisplayName, "S1T1 SmartFill")
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
                "smartFillTakeLabel": "S1T1 SmartFill",
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
        XCTAssertEqual(record?.adoptedTakeDisplayName, "S1T1 SmartFill")
    }

    func testSettingsRoundTripPreservesSnapshotValues() {
        let settings = SmartFillSettings(
            isEnabled: true,
            blurRadius: 28,
            darkenAmount: 0.18,
            backgroundScale: 4.5,
            foregroundScale: 1.2,
            backgroundSourceMode: .customImage,
            backgroundAssetPath: "/tmp/background.png",
            backgroundAssetDisplayName: "background.png",
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
        XCTAssertEqual(restored.backgroundSourceMode, .customImage)
        XCTAssertEqual(restored.backgroundAssetPath, "/tmp/background.png")
        XCTAssertEqual(restored.backgroundAssetDisplayName, "background.png")
        XCTAssertEqual(restored.renderSize.width, settings.renderSize.width)
        XCTAssertEqual(restored.renderSize.height, settings.renderSize.height)
        XCTAssertEqual(restored.processingPriority, settings.processingPriority)
    }

    func testCustomStillBackgroundDefaultsRoundTripPreservesModeAndSelection() {
        preservingSmartFillDefaults {
            let settings = SmartFillSettings(
                isEnabled: true,
                blurRadius: 22,
                darkenAmount: 0.1,
                backgroundScale: 3.0,
                foregroundScale: 1.0,
                backgroundSourceMode: .customImage,
                backgroundAssetPath: "/tmp/still-background.png",
                backgroundAssetDisplayName: "still-background.png",
                presetName: "Balanced",
                renderSize: CGSize(width: 1920, height: 1080),
                processingPriority: .userInitiated
            )

            settings.saveToUserDefaults()

            let restored = SmartFillSettings()

            XCTAssertEqual(restored.backgroundSourceMode, .customImage)
            XCTAssertEqual(restored.backgroundAssetPath, "/tmp/still-background.png")
            XCTAssertEqual(restored.backgroundAssetDisplayName, "still-background.png")
        }
    }

    func testBackgroundSourcePresentationUsesSelectedStillImageName() {
        let settings = SmartFillSettings(
            backgroundSourceMode: .customImage,
            backgroundAssetDisplayName: "studio-backdrop.png"
        )

        XCTAssertEqual(
            SmartFillWorkspacePresentation.backgroundSourceTitle(for: settings),
            "studio-backdrop.png"
        )
        XCTAssertEqual(
            SmartFillWorkspacePresentation.backgroundStillValue(for: settings),
            "studio-backdrop.png"
        )
        XCTAssertFalse(SmartFillSettings.BackgroundSourceMode.customVideo.isCurrentlySupported)
    }

    func testPreviewReloadsWhenRefreshIDChanges() {
        let url = URL(fileURLWithPath: "/tmp/original.mov")
        let settings = SmartFillSettings()

        XCTAssertTrue(
            SmartFillPreviewPlayer.shouldReloadPreview(
                currentVideoURL: url,
                currentSettings: settings,
                currentRefreshID: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE"),
                newVideoURL: url,
                newSettings: settings,
                newRefreshID: UUID(uuidString: "11111111-2222-3333-4444-555555555555")!
            )
        )
    }

    func testPreviewReloadsWhenSettingsChange() {
        let url = URL(fileURLWithPath: "/tmp/original.mov")
        let current = SmartFillSettings(blurRadius: 24, darkenAmount: 0.12, backgroundScale: 3.0)
        let updated = SmartFillSettings(blurRadius: 36, darkenAmount: 0.18, backgroundScale: 4.5)
        let refreshID = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!

        XCTAssertTrue(
            SmartFillPreviewPlayer.shouldReloadPreview(
                currentVideoURL: url,
                currentSettings: current,
                currentRefreshID: refreshID,
                newVideoURL: url,
                newSettings: updated,
                newRefreshID: refreshID
            )
        )
    }

    func testPreviewDoesNotReloadWhenInputsStayTheSame() {
        let url = URL(fileURLWithPath: "/tmp/original.mov")
        let settings = SmartFillSettings(blurRadius: 24, darkenAmount: 0.12, backgroundScale: 3.0)
        let refreshID = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!

        XCTAssertFalse(
            SmartFillPreviewPlayer.shouldReloadPreview(
                currentVideoURL: url,
                currentSettings: settings,
                currentRefreshID: refreshID,
                newVideoURL: url,
                newSettings: settings,
                newRefreshID: refreshID
            )
        )
    }

    func testPreviewPlaybackStateIgnoresNoiseButTracksMeaningfulChanges() {
        let baseline = SmartFillWorkspacePreviewPlaybackState(currentTime: 4.0, shouldPlay: true)

        XCTAssertFalse(
            baseline.shouldReplace(
                with: SmartFillWorkspacePreviewPlaybackState(currentTime: 4.05, shouldPlay: true)
            )
        )
        XCTAssertTrue(
            baseline.shouldReplace(
                with: SmartFillWorkspacePreviewPlaybackState(currentTime: 4.25, shouldPlay: true)
            )
        )
        XCTAssertTrue(
            baseline.shouldReplace(
                with: SmartFillWorkspacePreviewPlaybackState(currentTime: 4.0, shouldPlay: false)
            )
        )
    }

    func testPreviewPlaybackStateClampsAndRequiresSyncAgainstPlayerSnapshot() {
        let state = SmartFillWorkspacePreviewPlaybackState(currentTime: 12.4, shouldPlay: true)
        let clamped = state.clamped(to: 9.0)

        XCTAssertEqual(clamped.currentTime, 9.0)
        XCTAssertTrue(clamped.shouldPlay)
        XCTAssertFalse(clamped.requiresPlayerSync(currentTime: 9.02, isPlaying: true))
        XCTAssertTrue(clamped.requiresPlayerSync(currentTime: 8.6, isPlaying: true))
        XCTAssertTrue(clamped.requiresPlayerSync(currentTime: 9.0, isPlaying: false))
    }

    func testPreviewPlaybackStateRefreshesFromTransportIntent() {
        let baseline = SmartFillWorkspacePreviewPlaybackState(currentTime: 1.4, shouldPlay: false)

        let refreshed = baseline.refreshed(currentTime: 2.8, shouldPlay: true)
        let sanitized = baseline.refreshed(currentTime: .nan, shouldPlay: false)

        XCTAssertEqual(refreshed.currentTime, 2.8, accuracy: 0.0001)
        XCTAssertTrue(refreshed.shouldPlay)
        XCTAssertEqual(sanitized.currentTime, 0, accuracy: 0.0001)
        XCTAssertFalse(sanitized.shouldPlay)
    }

    func testPreviewPlaybackStateToggleUsesLivePlayerSnapshot() {
        let state = SmartFillWorkspacePreviewPlaybackState(currentTime: 0.5, shouldPlay: false)

        let playIntent = state.toggled(currentTime: 4.2, isPlaying: false)
        let pauseIntent = state.toggled(currentTime: 6.1, isPlaying: true)

        XCTAssertEqual(playIntent.currentTime, 4.2, accuracy: 0.0001)
        XCTAssertTrue(playIntent.shouldPlay)
        XCTAssertEqual(pauseIntent.currentTime, 6.1, accuracy: 0.0001)
        XCTAssertFalse(pauseIntent.shouldPlay)
    }

    func testPreviewPlaybackStateSyncingObservedTimePreservesRequestedPlayIntent() {
        let requested = SmartFillWorkspacePreviewPlaybackState(currentTime: 0.0, shouldPlay: true)

        let synced = requested.syncingObservedTime(0.35, allowPlayback: true)

        XCTAssertEqual(synced.currentTime, 0.35, accuracy: 0.0001)
        XCTAssertTrue(synced.shouldPlay)
    }

    func testPreviewPlaybackStateSyncingObservedTimeClearsPlayIntentWhenPlaybackDisallowed() {
        let requested = SmartFillWorkspacePreviewPlaybackState(currentTime: 2.0, shouldPlay: true)

        let synced = requested.syncingObservedTime(2.4, allowPlayback: false)

        XCTAssertEqual(synced.currentTime, 2.4, accuracy: 0.0001)
        XCTAssertFalse(synced.shouldPlay)
    }

    func testPreviewCompareStateUsesSelectedModeWhenNotHolding() {
        let result = SmartFillWorkspacePreviewCompareState(
            selectedMode: .result,
            isHoldingComparison: false,
            isPinnedWipeMode: false
        )
        let source = SmartFillWorkspacePreviewCompareState(
            selectedMode: .source,
            isHoldingComparison: false,
            isPinnedWipeMode: false
        )

        XCTAssertEqual(result.effectiveMode, .result)
        XCTAssertEqual(source.effectiveMode, .source)
    }

    func testPreviewCompareStateTemporarilyShowsAlternateModeWhileHolding() {
        let result = SmartFillWorkspacePreviewCompareState(
            selectedMode: .result,
            isHoldingComparison: true,
            isPinnedWipeMode: false
        )
        let source = SmartFillWorkspacePreviewCompareState(
            selectedMode: .source,
            isHoldingComparison: true,
            isPinnedWipeMode: false
        )

        XCTAssertEqual(result.effectiveMode, .source)
        XCTAssertEqual(source.effectiveMode, .result)
    }

    func testPreviewCompareStateKeepsDominantSideWhenPinnedWipeIsActive() {
        let result = SmartFillWorkspacePreviewCompareState(
            selectedMode: .result,
            isHoldingComparison: true,
            isPinnedWipeMode: true
        )
        let source = SmartFillWorkspacePreviewCompareState(
            selectedMode: .source,
            isHoldingComparison: true,
            isPinnedWipeMode: true
        )

        XCTAssertEqual(result.effectiveMode, .result)
        XCTAssertEqual(source.effectiveMode, .source)
    }

    func testPreviewFrameStepUsesNominalFrameRateWhenAvailable() {
        XCTAssertEqual(
            SmartFillPreviewFrameStep.seconds(forNominalFrameRate: 60),
            1.0 / 60.0,
            accuracy: 0.0001
        )
    }

    func testPreviewFrameStepFallsBackToThirtyFpsWhenNominalRateMissing() {
        XCTAssertEqual(
            SmartFillPreviewFrameStep.seconds(forNominalFrameRate: nil),
            1.0 / 30.0,
            accuracy: 0.0001
        )
        XCTAssertEqual(
            SmartFillPreviewFrameStep.seconds(forNominalFrameRate: 0),
            1.0 / 30.0,
            accuracy: 0.0001
        )
    }

    func testPreviewFrameStepClampsWithinDuration() {
        XCTAssertEqual(
            SmartFillPreviewFrameStep.steppedTime(
                currentTime: 1.0,
                duration: 5.0,
                frameStepSeconds: 1.0 / 30.0,
                frames: 3
            ),
            1.1,
            accuracy: 0.0001
        )
        XCTAssertEqual(
            SmartFillPreviewFrameStep.steppedTime(
                currentTime: 0.01,
                duration: 5.0,
                frameStepSeconds: 1.0 / 30.0,
                frames: -3
            ),
            0,
            accuracy: 0.0001
        )
        XCTAssertEqual(
            SmartFillPreviewFrameStep.steppedTime(
                currentTime: 4.98,
                duration: 5.0,
                frameStepSeconds: 1.0 / 30.0,
                frames: 3
            ),
            5.0,
            accuracy: 0.0001
        )
    }

    func testPreviewCanvasScrubUsesBoundedPrecisionSeekSpan() {
        XCTAssertEqual(
            SmartFillWorkspacePreviewCanvasScrubState.seekSpan(forDuration: 4.0),
            3.0,
            accuracy: 0.0001
        )
        XCTAssertEqual(
            SmartFillWorkspacePreviewCanvasScrubState.seekSpan(forDuration: 20.0),
            7.0,
            accuracy: 0.0001
        )
        XCTAssertEqual(
            SmartFillWorkspacePreviewCanvasScrubState.seekSpan(forDuration: 80.0),
            12.0,
            accuracy: 0.0001
        )
    }

    func testPreviewCanvasScrubClampsTargetTimeWithinDuration() {
        XCTAssertEqual(
            SmartFillWorkspacePreviewCanvasScrubState.targetTime(
                anchorTime: 10.0,
                translation: 150,
                width: 300,
                duration: 20.0
            ),
            13.5,
            accuracy: 0.0001
        )
        XCTAssertEqual(
            SmartFillWorkspacePreviewCanvasScrubState.targetTime(
                anchorTime: 1.0,
                translation: -400,
                width: 300,
                duration: 20.0
            ),
            0,
            accuracy: 0.0001
        )
        XCTAssertEqual(
            SmartFillWorkspacePreviewCanvasScrubState.targetTime(
                anchorTime: 19.0,
                translation: 400,
                width: 300,
                duration: 20.0
            ),
            20.0,
            accuracy: 0.0001
        )
    }

    func testPreviewCanvasScrubKeepsResumePlaybackIntent() {
        let state = SmartFillWorkspacePreviewCanvasScrubState.begin(
            currentTime: 6.2,
            duration: 18.0,
            wasPlaying: true
        ).updated(
            translation: -90,
            width: 300,
            duration: 18.0
        )

        XCTAssertEqual(state.anchorTime, 6.2, accuracy: 0.0001)
        XCTAssertTrue(state.resumePlayback)
        XCTAssertEqual(state.currentTime, 4.31, accuracy: 0.0001)
        XCTAssertEqual(state.playbackState.currentTime, 4.31, accuracy: 0.0001)
        XCTAssertFalse(state.playbackState.shouldPlay)
    }

    func testWorkspacePresentationUsesContextOverridesWhenAvailable() {
        let context = makeWorkspaceContext(
            take: ProjectTake(filePath: "/tmp/original.mov", durationSeconds: 12),
            infoTitle: "Fine-Tune SmartFill",
            infoMessage: "Use the rebuild workspace to shape the look."
        )

        XCTAssertEqual(SmartFillWorkspacePresentation.headerTitle(for: context), "SmartFill Editor")
        XCTAssertEqual(SmartFillWorkspacePresentation.headerMessage(for: context), "Use the rebuild workspace to shape the look.")
    }

    func testWorkspaceToolFocusKeepsHighestFrequencyBackgroundValuesNearPreview() {
        let settings = SmartFillSettings(
            blurRadius: 24,
            darkenAmount: 0.14,
            backgroundScale: 10,
            presetName: "Medium"
        )

        XCTAssertEqual(SmartFillWorkspaceTool.background.shortTitle, "Background")

        let items = SmartFillWorkspaceTool.background.focusItems(
            settings: settings,
            completionBehavior: .returnAutomatically,
            savedTakeName: nil
        )

        XCTAssertEqual(
            items,
            [
                SmartFillWorkspaceFocusItem(title: "Source", value: "Source", symbolName: "sparkles.tv"),
                SmartFillWorkspaceFocusItem(title: "Finish", value: "Balanced", symbolName: "sparkles"),
                SmartFillWorkspaceFocusItem(title: "Fill", value: "Default", symbolName: "arrow.up.left.and.arrow.down.right")
            ]
        )
    }

    func testWorkspaceToolFocusKeepsEditingToolsInlineAndReservesDrillInForSaveDetails() {
        let settings = SmartFillSettings(
            foregroundScale: 1.1,
            renderSize: CGSize(width: 1920, height: 1080),
            processingPriority: .high
        )

        XCTAssertNil(
            SmartFillWorkspaceTool.subject.drillInDescriptor(
                settings: settings,
                completionBehavior: .returnAutomatically,
                savedTakeName: nil,
                activeLookAdjustment: .blur
            )
        )

        XCTAssertNil(
            SmartFillWorkspaceTool.background.drillInDescriptor(
                settings: settings,
                completionBehavior: .returnAutomatically,
                savedTakeName: nil,
                activeLookAdjustment: .blur
            )
        )

        XCTAssertNil(
            SmartFillWorkspaceTool.output.drillInDescriptor(
                settings: settings,
                completionBehavior: .returnAutomatically,
                savedTakeName: nil,
                activeLookAdjustment: .blur
            )
        )

        XCTAssertEqual(
            SmartFillWorkspaceTool.save.drillInDescriptor(
                settings: settings,
                completionBehavior: .returnAutomatically,
                savedTakeName: "S1T1 SmartFill",
                activeLookAdjustment: .blur
            ),
            SmartFillWorkspaceDrillInDescriptor(
                title: "Details",
                value: "S1T1 SmartFill",
                symbolName: "square.and.arrow.down.on.square",
                sheet: .savePlan
            )
        )
    }

    func testPreviewPosterPolicyShowsPosterOnlyForRestingOpeningFrames() {
        XCTAssertTrue(
            SmartFillWorkspacePreviewPosterPolicy.shouldShowPoster(
                currentTime: 0,
                isPlaying: false,
                frameStepSeconds: 1.0 / 30.0
            )
        )

        XCTAssertTrue(
            SmartFillWorkspacePreviewPosterPolicy.shouldShowPoster(
                currentTime: 0.06,
                isPlaying: false,
                frameStepSeconds: 1.0 / 24.0
            )
        )

        XCTAssertFalse(
            SmartFillWorkspacePreviewPosterPolicy.shouldShowPoster(
                currentTime: 0.5,
                isPlaying: false,
                frameStepSeconds: 1.0 / 30.0
            )
        )

        XCTAssertFalse(
            SmartFillWorkspacePreviewPosterPolicy.shouldShowPoster(
                currentTime: 0,
                isPlaying: true,
                frameStepSeconds: 1.0 / 30.0
            )
        )
    }

    func testWorkspacePresentationUsesVariantSaveCopyForSmartFillTake() {
        let originalID = UUID()
        let take = ProjectTake(
            filePath: "/tmp/original_smartfill.mov",
            durationSeconds: 12,
            takeNotes: "[SMARTFILL_ORIGINAL:\(originalID.uuidString)]"
        )
        let context = makeWorkspaceContext(take: take, existingSettings: SmartFillSettings())

        XCTAssertEqual(SmartFillWorkspacePresentation.actionTitle(for: context), "Update and Return to Review")
        XCTAssertEqual(SmartFillWorkspacePresentation.destinationTitle(for: context), "Update current SmartFill take")
        XCTAssertEqual(
            SmartFillWorkspacePresentation.saveLaneMessage(
                for: context,
                adoptionMode: .updateExistingTakePath,
                completionBehavior: .returnAutomatically
            ),
            "Updating SmartFill keeps the current landscape take in sync, then returns you to session review."
        )
    }

    func testWorkspacePresentationDescribesFramingAndPriority() {
        let relaxedFraming = SmartFillSettings(foregroundScale: 0.9, processingPriority: .background)
        let tightFraming = SmartFillSettings(foregroundScale: 1.18, processingPriority: .high)

        XCTAssertEqual(SmartFillWorkspacePresentation.framingCaption(for: relaxedFraming), "Show more breathing room around the subject.")
        XCTAssertEqual(SmartFillWorkspacePresentation.framingCaption(for: tightFraming), "Push the subject forward for a tighter, more dramatic frame.")
        XCTAssertEqual(SmartFillWorkspacePresentation.processingPriorityTitle(for: .background), "Batch")
        XCTAssertEqual(SmartFillWorkspacePresentation.processingPriorityTitle(for: .high), "Fast")
    }

    func testWorkspacePresentationUsesExplicitReturnTargetForCopy() {
        let context = makeWorkspaceContext(
            take: ProjectTake(filePath: "/tmp/original.mov", durationSeconds: 12),
            autoLaunchEditor: false,
            launchSource: .editorBadge,
            returnTarget: .editor
        )

        XCTAssertEqual(SmartFillWorkspacePresentation.returnTargetTitle(for: context), "Editor")
        XCTAssertEqual(SmartFillWorkspacePresentation.actionTitle(for: context, stage: .configure), "Save and Return to Editor")
        XCTAssertEqual(
            SmartFillWorkspacePresentation.actionTitle(
                for: context,
                stage: .configure,
                completionBehavior: .stayHere
            ),
            "Save and Stay Here"
        )
        XCTAssertEqual(
            SmartFillWorkspacePresentation.processingMessage(for: context),
            "Saving SmartFill for “S1T1” and preparing the return to editor…"
        )
        XCTAssertEqual(
            SmartFillWorkspacePresentation.processingMessage(for: context, progress: 0.42),
            "Saving SmartFill for “S1T1” (42%) before returning to editor…"
        )
        XCTAssertEqual(
            SmartFillWorkspacePresentation.saveLaneMessage(
                for: context,
                adoptionMode: .createStandaloneVariantTake,
                completionBehavior: .stayHere
            ),
            "Saving SmartFill creates or refreshes the landscape take for this source clip and keeps SmartFill open so you can compare the preview before returning to editor."
        )
        XCTAssertEqual(
            SmartFillWorkspacePresentation.saveFootnote(
                for: context,
                completionBehavior: .stayHere
            ),
            "After save, SmartFill stays in the workspace so you can compare the landscape result before returning to editor."
        )
    }

    func testWorkspacePresentationSupportsStageAwareSaveCopyAndBackgroundLookTitles() {
        let settings = SmartFillSettings(presetName: "Subtle", processingPriority: .userInitiated)
        let context = makeWorkspaceContext(
            take: ProjectTake(filePath: "/tmp/original.mov", durationSeconds: 12),
            existingSettings: settings
        )

        XCTAssertEqual(SmartFillWorkspacePresentation.backgroundLookTitle(for: settings), "Natural")
        XCTAssertEqual(SmartFillWorkspacePresentation.actionTitle(for: context, stage: .export), "Saving SmartFill…")
        XCTAssertEqual(SmartFillWorkspacePresentation.actionTitle(for: context, stage: .completed), "Return to Review")
        XCTAssertEqual(
            SmartFillWorkspacePresentation.actionTitle(
                for: context,
                stage: .completed,
                adoptedTakeDisplayName: "S1T1 SmartFill"
            ),
            "Open S1T1 SmartFill"
        )
        XCTAssertEqual(
            SmartFillWorkspacePresentation.completionMessage(
                for: context,
                adoptionMode: .createStandaloneVariantTake,
                adoptedTakeDisplayName: "S1T1 SmartFill"
            ),
            "Saved S1T1 SmartFill. Returning to Session review…"
        )
        XCTAssertEqual(
            SmartFillWorkspacePresentation.completionMessage(for: context, adoptionMode: .createStandaloneVariantTake),
            "Saved the SmartFill take. Returning to Session review…"
        )
    }

    func testWorkspacePresentationExplainsOriginalSourcePreviewBeforeAndAfterSave() {
        let context = makeWorkspaceContext(
            take: ProjectTake(filePath: "/tmp/original.mov", durationSeconds: 12)
        )

        XCTAssertEqual(
            SmartFillWorkspacePresentation.sourcePreviewTitle(for: context),
            "S1T1"
        )
        XCTAssertEqual(
            SmartFillWorkspacePresentation.previewResultTitle(adoptedTakeDisplayName: nil),
            "Live SmartFill"
        )
        XCTAssertEqual(
            SmartFillWorkspacePresentation.sourcePreviewMessage(for: context),
            "Scrub the untouched source clip for “S1T1” here while the main editor keeps showing Live SmartFill."
        )
        XCTAssertEqual(
            SmartFillWorkspacePresentation.compareViewerMessage(for: context),
            "Inspect the untouched source clip for “S1T1” and Live SmartFill in a larger compare viewer at the same playhead."
        )
        XCTAssertEqual(
            SmartFillWorkspacePresentation.previewResultTitle(adoptedTakeDisplayName: "S1T1 SmartFill"),
            "S1T1 SmartFill"
        )
        XCTAssertEqual(
            SmartFillWorkspacePresentation.sourcePreviewMessage(
                for: context,
                adoptedTakeDisplayName: "S1T1 SmartFill"
            ),
            "Scrub the untouched source clip for “S1T1” here while the main editor keeps showing S1T1 SmartFill."
        )
        XCTAssertEqual(
            SmartFillWorkspacePresentation.sourcePreviewMessage(
                for: context,
                adoptedTakeDisplayName: "S1T1 SmartFill",
                previewMode: .source
            ),
            "Open the untouched source clip for “S1T1” in a larger viewer while the main editor stays on the original comparison state."
        )
        XCTAssertEqual(
            SmartFillWorkspacePresentation.compareViewerMessage(
                for: context,
                adoptedTakeDisplayName: "S1T1 SmartFill"
            ),
            "Inspect the untouched source clip for “S1T1” and S1T1 SmartFill in a larger compare viewer at the same playhead."
        )
    }

    func testCompareWipeStateClampsDividerProgressToViewerBounds() {
        XCTAssertEqual(
            SmartFillWorkspaceCompareWipeState.clampedProgress(for: -20, width: 240),
            0
        )
        XCTAssertEqual(
            SmartFillWorkspaceCompareWipeState.clampedProgress(for: 120, width: 240),
            0.5
        )
        XCTAssertEqual(
            SmartFillWorkspaceCompareWipeState.clampedProgress(for: 400, width: 240),
            1
        )
        XCTAssertEqual(
            SmartFillWorkspaceCompareWipeState.begin(width: 0).progress,
            0.5
        )
        XCTAssertEqual(
            SmartFillWorkspaceCompareWipeState.begin(locationX: 60, width: 240).progress,
            0.25
        )
        XCTAssertEqual(
            SmartFillWorkspaceCompareWipeState.begin(width: 240)
                .updated(locationX: 180, width: 240)
                .progress,
            0.75
        )
    }

    func testCompareViewerSelectionStateMapsExplicitToolbarModes() {
        var state = SmartFillWorkspaceCompareViewerSelectionState()

        XCTAssertEqual(state.toolbarMode, .source)

        state.selectToolbarMode(.current)
        XCTAssertEqual(state.selectedMode, .result)
        XCTAssertEqual(state.toolbarMode, .current)
        XCTAssertFalse(state.isPinnedWipeMode)

        state.selectToolbarMode(.source)
        XCTAssertEqual(state.selectedMode, .source)
        XCTAssertEqual(state.toolbarMode, .source)
        XCTAssertFalse(state.isPinnedWipeMode)
    }

    func testCompareViewerSelectionStateKeepsLastDominantSideWhenWipeIsPinned() {
        var state = SmartFillWorkspaceCompareViewerSelectionState(selectedMode: .result)

        state.selectToolbarMode(.wipe)
        XCTAssertEqual(state.selectedMode, .result)
        XCTAssertEqual(state.toolbarMode, .wipe)
        XCTAssertTrue(state.isPinnedWipeMode)

        state.selectToolbarMode(.source)
        XCTAssertEqual(state.selectedMode, .source)
        XCTAssertEqual(state.toolbarMode, .source)
        XCTAssertFalse(state.isPinnedWipeMode)

        state.selectToolbarMode(.wipe)
        XCTAssertEqual(state.selectedMode, .source)
        XCTAssertEqual(state.toolbarMode, .wipe)
        XCTAssertTrue(state.isPinnedWipeMode)
    }

    func testPreviewCompareGroupStateUsesSelectedToolbarMode() {
        let sourceState = SmartFillWorkspacePreviewCompareGroupState(
            toolbarMode: .source,
            viewerControl: SmartFillWorkspacePreviewCompareControl(
                title: "Viewer",
                value: "Source",
                symbolName: "film",
                compareMode: .source
            )
        )
        let currentState = SmartFillWorkspacePreviewCompareGroupState(
            toolbarMode: .current,
            viewerControl: SmartFillWorkspacePreviewCompareControl(
                title: "Viewer",
                value: "Current",
                symbolName: "sparkles.tv",
                compareMode: .current
            )
        )
        let wipeState = SmartFillWorkspacePreviewCompareGroupState(
            toolbarMode: .wipe,
            viewerControl: SmartFillWorkspacePreviewCompareControl(
                title: "Viewer",
                value: "Wipe",
                symbolName: "rectangle.split.2x1",
                compareMode: .wipe
            )
        )

        XCTAssertEqual(sourceState.selectedSegment, .source)
        XCTAssertEqual(currentState.selectedSegment, .current)
        XCTAssertEqual(wipeState.selectedSegment, .wipe)
        XCTAssertEqual(wipeState.viewerControl.symbolName, "rectangle.split.2x1")
    }

    func testWorkspacePresentationUsesReturnActionForEditorCompletion() {
        let context = makeWorkspaceContext(
            take: ProjectTake(filePath: "/tmp/original.mov", durationSeconds: 12),
            autoLaunchEditor: false,
            launchSource: .editorBadge,
            returnTarget: .editor
        )

        XCTAssertEqual(
            SmartFillWorkspacePresentation.actionTitle(
                for: context,
                stage: .completed,
                adoptedTakeDisplayName: "S1T1 SmartFill"
            ),
            "Open S1T1 SmartFill"
        )
        XCTAssertEqual(
            SmartFillWorkspacePresentation.completionMessage(
                for: context,
                adoptionMode: .updateExistingTakePath,
                adoptedTakeDisplayName: "S1T1 SmartFill"
            ),
            "Updated S1T1 SmartFill. Returning to Editor…"
        )
        XCTAssertEqual(
            SmartFillWorkspacePresentation.completionMessage(for: context, adoptionMode: .updateExistingTakePath),
            "Updated SmartFill. Returning to Editor…"
        )
        XCTAssertEqual(
            SmartFillWorkspacePresentation.deferredReturnMessage(
                for: context,
                adoptionMode: .updateExistingTakePath,
                adoptedTakeDisplayName: "S1T1 SmartFill"
            ),
            "S1T1 SmartFill is updated. Open it in Editor when you're ready."
        )
    }

    func testWorkspacePresentationRestoresSaveActionWhenCompletedSettingsBecomeDirty() {
        let context = makeWorkspaceContext(
            take: ProjectTake(filePath: "/tmp/original.mov", durationSeconds: 12)
        )

        XCTAssertEqual(
            SmartFillWorkspacePresentation.actionTitle(for: context, stage: .completed, hasUnsavedChanges: true),
            "Save and Return to Review"
        )
        XCTAssertEqual(
            SmartFillWorkspacePresentation.unsavedChangesMessage(for: context, adoptionMode: .createStandaloneVariantTake),
            "Changes are not saved yet. Save SmartFill again before returning to Session review."
        )
        XCTAssertEqual(
            SmartFillWorkspacePresentation.destinationOutcomeTitle(for: .createStandaloneVariantTake),
            "Created or refreshed SmartFill take"
        )
    }

    func testWorkspacePresentationUsesUpdateCopyForDirtyEditorReturn() {
        let context = makeWorkspaceContext(
            take: ProjectTake(filePath: "/tmp/original.mov", durationSeconds: 12),
            existingSettings: SmartFillSettings(),
            autoLaunchEditor: false,
            launchSource: .editorBadge,
            returnTarget: .editor
        )

        XCTAssertEqual(
            SmartFillWorkspacePresentation.actionTitle(for: context, stage: .completed, hasUnsavedChanges: true),
            "Update and Return to Editor"
        )
        XCTAssertEqual(
            SmartFillWorkspacePresentation.unsavedChangesMessage(for: context, adoptionMode: .updateExistingTakePath),
            "Changes are not saved yet. Save SmartFill again before returning to Editor."
        )
        XCTAssertEqual(
            SmartFillWorkspacePresentation.destinationOutcomeTitle(for: .updateExistingTakePath),
            "Updated current SmartFill take"
        )
    }

    func testWorkspacePresentationExplainsSaveOutcomeBeforeFirstSave() {
        let context = makeWorkspaceContext(
            take: ProjectTake(filePath: "/tmp/original.mov", durationSeconds: 12)
        )

        XCTAssertEqual(SmartFillWorkspacePresentation.sourceClipOutcomeTitle(), "Stays unchanged")
        XCTAssertEqual(
            SmartFillWorkspacePresentation.afterSaveOutcomeTitle(
                for: context,
                stage: .configure,
                completionBehavior: .returnAutomatically,
                hasPendingAutoReturn: false,
                hasUnsavedChanges: false
            ),
            "Return to Review after save"
        )
        XCTAssertEqual(
            SmartFillWorkspacePresentation.saveOutcomeMessage(
                for: context,
                adoptionMode: .createStandaloneVariantTake,
                stage: .configure,
                completionBehavior: .returnAutomatically,
                hasPendingAutoReturn: false,
                hasUnsavedChanges: false
            ),
            "Saving keeps the source clip untouched while the session created or refreshed SmartFill take, then returns you to session review."
        )
    }

    func testWorkspacePresentationExplainsDirtySavedStateAndAutoReturn() {
        let context = makeWorkspaceContext(
            take: ProjectTake(filePath: "/tmp/original.mov", durationSeconds: 12),
            existingSettings: SmartFillSettings(),
            autoLaunchEditor: false,
            launchSource: .editorBadge,
            returnTarget: .editor
        )

        XCTAssertEqual(
            SmartFillWorkspacePresentation.afterSaveOutcomeTitle(
                for: context,
                stage: .completed,
                completionBehavior: .returnAutomatically,
                hasPendingAutoReturn: true,
                hasUnsavedChanges: false,
                adoptedTakeDisplayName: "S1T1 SmartFill"
            ),
            "Auto-returning to S1T1 SmartFill"
        )
        XCTAssertEqual(
            SmartFillWorkspacePresentation.saveOutcomeMessage(
                for: context,
                adoptionMode: .updateExistingTakePath,
                stage: .completed,
                completionBehavior: .returnAutomatically,
                hasPendingAutoReturn: true,
                hasUnsavedChanges: false,
                adoptedTakeDisplayName: "S1T1 SmartFill"
            ),
            "Save finished. S1T1 SmartFill is ready in editor, and SmartFill will return there unless you stay here to compare the preview."
        )
        XCTAssertEqual(
            SmartFillWorkspacePresentation.saveOutcomeMessage(
                for: context,
                adoptionMode: .updateExistingTakePath,
                stage: .completed,
                completionBehavior: .returnAutomatically,
                hasPendingAutoReturn: false,
                hasUnsavedChanges: true
            ),
            "The last saved SmartFill result is still available, but these newer changes are not saved yet. Save again before returning to Editor."
        )
    }

    func testWorkspacePresentationExplainsStayHereCompletionMode() {
        let context = makeWorkspaceContext(
            take: ProjectTake(filePath: "/tmp/original.mov", durationSeconds: 12),
            returnTarget: .takeReview
        )

        XCTAssertEqual(
            SmartFillWorkspacePresentation.afterSaveOutcomeTitle(
                for: context,
                stage: .configure,
                completionBehavior: .stayHere,
                hasPendingAutoReturn: false,
                hasUnsavedChanges: false
            ),
            "Stay here after save"
        )
        XCTAssertEqual(
            SmartFillWorkspacePresentation.saveOutcomeMessage(
                for: context,
                adoptionMode: .createStandaloneVariantTake,
                stage: .configure,
                completionBehavior: .stayHere,
                hasPendingAutoReturn: false,
                hasUnsavedChanges: false
            ),
            "Saving keeps the source clip untouched while the session created or refreshed SmartFill take, and SmartFill will stay here so you can compare the preview before returning to Session review."
        )
        XCTAssertEqual(
            SmartFillWorkspacePresentation.saveOutcomeMessage(
                for: context,
                adoptionMode: .createStandaloneVariantTake,
                stage: .completed,
                completionBehavior: .stayHere,
                hasPendingAutoReturn: false,
                hasUnsavedChanges: false,
                adoptedTakeDisplayName: "S1T1 SmartFill"
            ),
            "Save finished. S1T1 SmartFill is ready in Session review. SmartFill will stay here so you can compare the preview before opening it."
        )
        XCTAssertEqual(
            SmartFillWorkspacePresentation.processingMessage(
                for: context,
                progress: 0.4,
                completionBehavior: .stayHere
            ),
            "Saving SmartFill for “S1T1” (40%) and staying in the workspace for preview review…"
        )
        XCTAssertEqual(
            SmartFillWorkspacePresentation.deferredReturnMessage(
                for: context,
                adoptionMode: .createStandaloneVariantTake,
                completionBehavior: .stayHere,
                adoptedTakeDisplayName: "S1T1 SmartFill"
            ),
            "S1T1 SmartFill is saved. Stay here to compare the preview, then open it in Session review when you're ready."
        )
        XCTAssertEqual(
            SmartFillWorkspacePresentation.stayComparisonMessage(
                for: context,
                adoptionMode: .createStandaloneVariantTake,
                adoptedTakeDisplayName: "S1T1 SmartFill"
            ),
            "S1T1 SmartFill is saved into this session. Compare the preview here, then open it in Session review when you are ready."
        )
        XCTAssertEqual(
            SmartFillWorkspacePresentation.returnControlMessage(
                for: context,
                adoptionMode: .createStandaloneVariantTake,
                adoptedTakeDisplayName: "S1T1 SmartFill"
            ),
            "S1T1 SmartFill is saved into this session. Stay here to compare the preview or use the primary action to open it in Session review."
        )
    }

    func testWorkspaceCompletionBehaviorDefaultsPreferStayInEditor() {
        XCTAssertEqual(
            SmartFillWorkspaceCompletionBehavior.defaultValue(for: .editor),
            .stayHere
        )
        XCTAssertEqual(
            SmartFillWorkspaceCompletionBehavior.defaultValue(for: .takeReview),
            .returnAutomatically
        )
    }

    func testWorkspaceFollowUpRoutePrefersEditorForEditorReturnTarget() {
        XCTAssertEqual(
            SmartFillWorkspaceFollowUpRoute.resolve(for: .editor),
            .editor
        )
    }

    func testWorkspaceFollowUpRouteKeepsReviewTargetsInPlayerFlow() {
        XCTAssertEqual(
            SmartFillWorkspaceFollowUpRoute.resolve(for: .takeReview),
            .player(returnToTakeReviewOnDismiss: true)
        )
        XCTAssertEqual(
            SmartFillWorkspaceFollowUpRoute.resolve(for: .swipeablePlayer),
            .player(returnToTakeReviewOnDismiss: true)
        )
    }

    func testWorkspaceFollowUpRouteUsesProjectDetailPlayerWithoutReviewBounce() {
        XCTAssertEqual(
            SmartFillWorkspaceFollowUpRoute.resolve(for: .projectDetail),
            .player(returnToTakeReviewOnDismiss: false)
        )
    }

    func testWorkspaceFollowUpRouteLeavesStandaloneWorkspaceAsCloseOnly() {
        XCTAssertEqual(
            SmartFillWorkspaceFollowUpRoute.resolve(for: .standaloneWorkspace),
            .closeOnly
        )
    }

    func testReopenDestinationContextNamesSavedTakeForPlayerReview() {
        let context = SmartFillReopenDestinationContext.player(
            adoptedTakeDisplayName: "S1T1 SmartFill"
        )

        XCTAssertEqual(context.badgeTitle, "Saved SmartFill Result")
        XCTAssertEqual(context.title, "S1T1 SmartFill")
        XCTAssertEqual(
            context.message,
            "This is the SmartFill take you just saved. Review it here or open editing again if you want another pass."
        )
    }

    func testReopenDestinationContextOffersPlayerCompareActionWhenSourceTakeKnown() {
        let sourceTakeID = UUID()
        let context = SmartFillReopenDestinationContext.player(
            adoptedTakeDisplayName: "S1T1 SmartFill",
            sourceTakeID: sourceTakeID,
            sourceTakeDisplayName: "S1T1"
        )

        XCTAssertEqual(context.sourceTakeID, sourceTakeID)
        XCTAssertEqual(context.sourceTakeDisplayName, "S1T1")
        XCTAssertEqual(context.playerComparisonActionTitle, "Compare with S1T1")
        XCTAssertEqual(
            context.message,
            "This is the SmartFill take you just saved. Swipe or tap Compare with S1T1 to judge it against the original source take."
        )
    }

    func testReopenDestinationContextNamesSavedTakeForEditor() {
        let context = SmartFillReopenDestinationContext.editor(
            adoptedTakeDisplayName: "S1T1 SmartFill"
        )

        XCTAssertEqual(context.badgeTitle, "Saved SmartFill Result")
        XCTAssertEqual(context.title, "Opened S1T1 SmartFill")
        XCTAssertEqual(
            context.message,
            "You are now editing the saved SmartFill take. Keep trimming, cropping, or exporting from this updated result."
        )
    }

    func testReopenDestinationContextOffersEditorCompareActionWhenSourceTakeKnown() {
        let sourceTakeID = UUID()
        let context = SmartFillReopenDestinationContext.editor(
            adoptedTakeDisplayName: "S1T1 SmartFill",
            sourceTakeID: sourceTakeID,
            sourceTakeDisplayName: "S1T1"
        )

        XCTAssertEqual(context.sourceTakeID, sourceTakeID)
        XCTAssertEqual(context.sourceTakeDisplayName, "S1T1")
        XCTAssertEqual(context.editorComparisonActionTitle, "Open S1T1")
        XCTAssertEqual(
            context.message,
            "You are now editing the saved SmartFill take. Open S1T1 if you want to compare it against the original source take."
        )
    }

    func testWorkspaceCompletionFollowUpPrimaryActionOpensSavedTakeWhenAvailable() {
        XCTAssertEqual(
            SmartFillWorkspaceCompletionFollowUpAction.primaryAction(
                hasSavedResult: true,
                canOpenSavedTake: true
            ),
            .openSavedTake
        )
    }

    func testWorkspaceCompletionFollowUpPrimaryActionFallsBackToCloseWithoutSavedTake() {
        XCTAssertEqual(
            SmartFillWorkspaceCompletionFollowUpAction.primaryAction(
                hasSavedResult: false,
                canOpenSavedTake: true
            ),
            .closeOnly
        )
        XCTAssertEqual(
            SmartFillWorkspaceCompletionFollowUpAction.primaryAction(
                hasSavedResult: true,
                canOpenSavedTake: false
            ),
            .closeOnly
        )
    }

    func testWorkspaceCompletionFollowUpAutoReturnUsesSavedTakeWhenReturnIsEnabled() {
        XCTAssertEqual(
            SmartFillWorkspaceCompletionFollowUpAction.autoReturn(
                completionBehavior: .returnAutomatically,
                hasSavedResult: true,
                canOpenSavedTake: true
            ),
            .openSavedTake
        )
    }

    func testWorkspaceCompletionFollowUpAutoReturnStaysCloseOnlyWhenStayModeOrNoSavedTake() {
        XCTAssertEqual(
            SmartFillWorkspaceCompletionFollowUpAction.autoReturn(
                completionBehavior: .stayHere,
                hasSavedResult: true,
                canOpenSavedTake: true
            ),
            .closeOnly
        )
        XCTAssertEqual(
            SmartFillWorkspaceCompletionFollowUpAction.autoReturn(
                completionBehavior: .returnAutomatically,
                hasSavedResult: false,
                canOpenSavedTake: true
            ),
            .closeOnly
        )
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
            adoptedTakeDisplayName: "S1T1 SmartFill",
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

    private func makeWorkspaceContext(
        take: ProjectTake,
        infoTitle: String? = nil,
        infoMessage: String? = nil,
        existingSettings: SmartFillSettings? = nil,
        autoLaunchEditor: Bool = false,
        launchSource: SmartFillLaunchSource = .takeReview,
        returnTarget: SmartFillReturnTarget = .takeReview
    ) -> SmartFillSettingsContext {
        let session = ProjectSession(type: .selfTape, takes: [take], primaryOrientation: .landscape)
        let project = Project(title: "Project", sessions: [session])

        return SmartFillSettingsContext(
            take: take,
            session: session,
            project: project,
            launchSource: launchSource,
            returnTarget: returnTarget,
            autoLaunchEditor: autoLaunchEditor,
            displayName: "S1T1",
            infoTitle: infoTitle,
            infoMessage: infoMessage,
            existingSettings: existingSettings,
            onUpdatePIPSession: nil
        )
    }
}
