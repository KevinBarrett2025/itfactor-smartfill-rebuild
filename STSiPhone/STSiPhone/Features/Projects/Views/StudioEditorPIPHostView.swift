import SwiftUI

struct StudioEditorPIPContext: Identifiable {
    let id = UUID()
    let take: ProjectTake
    let session: ProjectSession
    let project: Project
    let initialSession: SlatePIPSession?
    let onUpdateSession: ((SlatePIPSession?) -> Void)?

    static func make(
        for take: ProjectTake,
        session: ProjectSession,
        project: Project,
        onUpdateSession: ((SlatePIPSession?) -> Void)? = nil
    ) -> StudioEditorPIPContext? {
        guard take.takeType == .pipSlate || take.takeType.isPIPComponent else {
            return nil
        }

        return StudioEditorPIPContext(
            take: take,
            session: session,
            project: project,
            initialSession: session.pipSlateSession,
            onUpdateSession: onUpdateSession
        )
    }
}

struct StudioEditorPIPHostView: View {
    let context: StudioEditorPIPContext
    let onClose: () -> Void

    @State private var pipSession: SlatePIPSession?
    @State private var lastSyncedSession: SlatePIPSession?

    init(
        context: StudioEditorPIPContext,
        onClose: @escaping () -> Void
    ) {
        self.context = context
        self.onClose = onClose
        _pipSession = State(initialValue: context.initialSession)
        _lastSyncedSession = State(initialValue: context.initialSession)
    }

    var body: some View {
        NavigationStack {
            PIPSlateEditorScreen(
                session: $pipSession,
                project: context.project,
                projectSession: context.session,
                onCompositeSaved: {
                    syncParentIfNeeded(force: true)
                }
            )
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        syncParentIfNeeded(force: true)
                        onClose()
                    }
                }
            }
        }
        .onDisappear {
            syncParentIfNeeded(force: true)
        }
    }

    private func syncParentIfNeeded(force: Bool) {
        guard force || pipSession != lastSyncedSession else {
            return
        }

        lastSyncedSession = pipSession
        context.onUpdateSession?(pipSession)
    }
}
