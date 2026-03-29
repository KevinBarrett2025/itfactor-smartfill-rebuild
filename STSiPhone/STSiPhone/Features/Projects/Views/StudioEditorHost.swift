import Foundation

struct StudioEditorStandardEditContext: Identifiable {
    let id = UUID()
    let take: ProjectTake
    let session: ProjectSession
    let project: Project
}

enum StudioEditorHostDestination: Identifiable {
    case standardEdit(StudioEditorStandardEditContext)
    case pipSlate(StudioEditorPIPContext)
    case smartFill(SmartFillSettingsContext)

    var id: UUID {
        switch self {
        case .standardEdit(let context):
            return context.id
        case .pipSlate(let context):
            return context.id
        case .smartFill(let context):
            return context.id
        }
    }
}

enum StudioEditorHost {
    static func resolveDestination(
        for request: StudioEditorLaunchRequest,
        pipSlateContext: (ProjectTake, ProjectSession, Project) -> StudioEditorPIPContext?,
        requestSmartFillContext: (ProjectTake, ProjectSession, Project) -> SmartFillSettingsContext?,
        editSmartFillContext: (ProjectTake, ProjectSession, Project) -> SmartFillSettingsContext?
    ) -> StudioEditorHostDestination? {
        switch request.intent {
        case .standardEdit(let targetTake):
            if let pipContext = pipSlateContext(
                targetTake,
                request.session,
                request.project
            ) {
                return .pipSlate(pipContext)
            }
            return .standardEdit(
                StudioEditorStandardEditContext(
                    take: targetTake,
                    session: request.session,
                    project: request.project
                )
            )
        case .smartFillRequest(let targetTake):
            guard let context = requestSmartFillContext(
                targetTake,
                request.session,
                request.project
            ) else {
                return nil
            }
            return .smartFill(context)
        case .smartFillEdit(let targetTake):
            guard let context = editSmartFillContext(
                targetTake,
                request.session,
                request.project
            ) else {
                return nil
            }
            return .smartFill(context)
        }
    }

    @discardableResult
    static func route(
        request: StudioEditorLaunchRequest,
        pipSlateContext: (ProjectTake, ProjectSession, Project) -> StudioEditorPIPContext?,
        requestSmartFillContext: (ProjectTake, ProjectSession, Project) -> SmartFillSettingsContext?,
        editSmartFillContext: (ProjectTake, ProjectSession, Project) -> SmartFillSettingsContext?,
        onStandardEdit: (StudioEditorStandardEditContext) -> Void,
        onPIPSlate: (StudioEditorPIPContext) -> Void,
        onSmartFill: (SmartFillSettingsContext) -> Void
    ) -> Bool {
        guard let destination = resolveDestination(
            for: request,
            pipSlateContext: pipSlateContext,
            requestSmartFillContext: requestSmartFillContext,
            editSmartFillContext: editSmartFillContext
        ) else {
            return false
        }

        switch destination {
        case .standardEdit(let context):
            onStandardEdit(context)
        case .pipSlate(let context):
            onPIPSlate(context)
        case .smartFill(let context):
            onSmartFill(context)
        }

        return true
    }
}
