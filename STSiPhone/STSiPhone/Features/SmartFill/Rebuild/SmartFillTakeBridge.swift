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

enum SmartFillTakeBridge {
    static func settings(from snapshot: SmartFillSettingsSnapshot) -> SmartFillSettings {
        SmartFillSettings(
            isEnabled: snapshot.isEnabled,
            blurRadius: CGFloat(snapshot.blurRadius),
            darkenAmount: CGFloat(snapshot.darkenAmount),
            backgroundScale: CGFloat(snapshot.backgroundScale),
            foregroundScale: CGFloat(snapshot.foregroundScale),
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

        let snapshot = take.smartFillSettings ?? SmartFillSettingsSnapshot(
            isEnabled: finalEnabled,
            blurRadius: 24.0,
            darkenAmount: 0.12,
            backgroundScale: 10.0,
            foregroundScale: 1.0,
            renderWidth: 1920,
            renderHeight: 1080,
            processingPriority: "interactive",
            presetName: "Medium"
        )

        return SmartFillWorkspaceDefaults(
            snapshot: snapshot,
            usesSessionOverride: override == .inherit,
            shouldOfferSmartFill: shouldOfferSmartFill(for: take, in: session)
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
