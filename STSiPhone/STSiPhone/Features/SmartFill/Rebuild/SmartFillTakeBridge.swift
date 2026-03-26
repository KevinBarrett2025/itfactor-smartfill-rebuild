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
