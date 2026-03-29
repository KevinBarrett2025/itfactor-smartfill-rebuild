import Foundation

public struct SmartFillWorkspaceDefaults: Equatable, Sendable {
    public let snapshot: SmartFillSettingsSnapshot
    public let usesSessionOverride: Bool
    public let shouldOfferSmartFill: Bool

    public init(
        snapshot: SmartFillSettingsSnapshot,
        usesSessionOverride: Bool,
        shouldOfferSmartFill: Bool
    ) {
        self.snapshot = snapshot
        self.usesSessionOverride = usesSessionOverride
        self.shouldOfferSmartFill = shouldOfferSmartFill
    }
}

public struct SmartFillEditorLaunchSeed: Equatable, Sendable {
    public let sourceTakeID: UUID
    public let displayName: String
    public let infoTitle: String
    public let infoMessage: String
    public let existingSettings: SmartFillSettingsSnapshot?

    public init(
        sourceTakeID: UUID,
        displayName: String,
        infoTitle: String,
        infoMessage: String,
        existingSettings: SmartFillSettingsSnapshot?
    ) {
        self.sourceTakeID = sourceTakeID
        self.displayName = displayName
        self.infoTitle = infoTitle
        self.infoMessage = infoMessage
        self.existingSettings = existingSettings
    }
}

enum SmartFillTakeBridge {
    static func settings(from snapshot: SmartFillSettingsSnapshot) -> SmartFillSettings {
        SmartFillSettings(
            isEnabled: snapshot.isEnabled,
            blurRadius: CGFloat(snapshot.blurRadius),
            darkenAmount: CGFloat(snapshot.darkenAmount),
            backgroundScale: CGFloat(snapshot.backgroundScale),
            foregroundScale: CGFloat(snapshot.foregroundScale),
            backgroundSourceMode: SmartFillSettings.BackgroundSourceMode(
                rawValue: snapshot.backgroundSourceMode ?? SmartFillSettings.BackgroundSourceMode.sourceDerived.rawValue
            ) ?? .sourceDerived,
            backgroundAssetPath: snapshot.backgroundAssetPath,
            backgroundAssetDisplayName: snapshot.backgroundAssetDisplayName,
            backgroundVideoTakeID: snapshot.backgroundVideoTakeID,
            presetName: snapshot.presetName,
            renderSize: CGSize(width: snapshot.renderWidth, height: snapshot.renderHeight),
            processingPriority: SmartFillSettings.ProcessingPriority(rawValue: snapshot.processingPriority) ?? .userInitiated
        )
    }

    static func snapshot(from settings: SmartFillSettings) -> SmartFillSettingsSnapshot {
        SmartFillSettingsSnapshot(
            isEnabled: settings.isEnabled,
            blurRadius: Double(settings.blurRadius),
            darkenAmount: Double(settings.darkenAmount),
            backgroundScale: Double(settings.backgroundScale),
            foregroundScale: Double(settings.foregroundScale),
            backgroundSourceMode: settings.backgroundSourceMode.rawValue,
            backgroundAssetPath: settings.backgroundAssetPath,
            backgroundAssetDisplayName: settings.backgroundAssetDisplayName,
            backgroundVideoTakeID: settings.backgroundVideoTakeID,
            renderWidth: Double(settings.renderSize.width),
            renderHeight: Double(settings.renderSize.height),
            processingPriority: settings.processingPriority.rawValue,
            presetName: settings.presetName
        )
    }

    static func makeContext(
        project: Project,
        session: ProjectSession,
        take: ProjectTake,
        launchSource: SmartFillLaunchSource,
        returnTarget: SmartFillReturnTarget
    ) -> SmartFillSessionContext {
        SmartFillSessionContext(
            projectID: project.id,
            sessionID: session.id,
            takeID: take.id,
            launchSource: launchSource,
            returnTarget: returnTarget
        )
    }

    static func defaultWorkspaceSettings(
        for take: ProjectTake,
        in session: ProjectSession
    ) -> SmartFillWorkspaceDefaults {
        let inheritedEnabled = session.smartFillEnabled ?? true
        let override = take.overrideSmartFill ?? .inherit
        let finalEnabled: Bool

        switch override {
        case .inherit:
            finalEnabled = inheritedEnabled
        case .on:
            finalEnabled = true
        case .off:
            finalEnabled = false
        }

        let persistedDefaults = SmartFillSettings()
        let snapshot = take.smartFillSettings ?? SmartFillSettingsSnapshot(
            isEnabled: finalEnabled,
            blurRadius: Double(persistedDefaults.blurRadius),
            darkenAmount: Double(persistedDefaults.darkenAmount),
            backgroundScale: Double(persistedDefaults.backgroundScale),
            foregroundScale: Double(persistedDefaults.foregroundScale),
            backgroundSourceMode: persistedDefaults.backgroundSourceMode.rawValue,
            backgroundAssetPath: persistedDefaults.backgroundAssetPath,
            backgroundAssetDisplayName: persistedDefaults.backgroundAssetDisplayName,
            backgroundVideoTakeID: persistedDefaults.backgroundVideoTakeID,
            renderWidth: Double(persistedDefaults.renderSize.width),
            renderHeight: Double(persistedDefaults.renderSize.height),
            processingPriority: persistedDefaults.processingPriority.rawValue,
            presetName: persistedDefaults.presetName
        )

        return SmartFillWorkspaceDefaults(
            snapshot: snapshot,
            usesSessionOverride: override == .inherit,
            shouldOfferSmartFill: shouldOfferSmartFill(for: take, in: session)
        )
    }

    static func editorLaunchSeed(
        for take: ProjectTake,
        in session: ProjectSession
    ) -> SmartFillEditorLaunchSeed {
        let sourceTake = TakeDisplayFormatter.canonicalTake(for: take, in: session)
        let displayName = TakeDisplayFormatter.label(for: sourceTake, in: session)
        let existingSettings = take.smartFillSettings ?? sourceTake.smartFillSettings
        let isRefiningExistingSmartFill = take.isSmartFillVariant || take.hasSmartFilledVersion || existingSettings != nil

        let infoTitle = isRefiningExistingSmartFill ? "Fine-Tune SmartFill" : "SmartFill Editor"
        let infoMessage: String
        if isRefiningExistingSmartFill {
            infoMessage = "Adjust the SmartFill look for “\(displayName)”, then return to the editor with the updated landscape result."
        } else {
            infoMessage = "Create the first SmartFill version for “\(displayName)”, then return to the editor with the landscape result ready to review."
        }

        return SmartFillEditorLaunchSeed(
            sourceTakeID: sourceTake.id,
            displayName: displayName,
            infoTitle: infoTitle,
            infoMessage: infoMessage,
            existingSettings: existingSettings
        )
    }

    static func shouldOfferSmartFill(
        for take: ProjectTake,
        in session: ProjectSession
    ) -> Bool {
        if take.isSmartFillVariant {
            return true
        }

        if take.takeType.isSlateLike || take.takeType == .pipComponent {
            return false
        }

        if let orientation = take.capturedOrientation {
            if orientation == .portrait {
                if let sessionOrientation = session.primaryOrientation {
                    return sessionOrientation == .landscape
                }
                return true
            }

            return false
        }

        return session.primaryOrientation == .landscape || session.primaryOrientation == nil
    }
}
