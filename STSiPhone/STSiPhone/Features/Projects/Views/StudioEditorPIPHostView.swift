import SwiftUI

struct StudioEditorPIPContext: Identifiable {
    let id = UUID()
    let take: ProjectTake
    let session: ProjectSession
    let project: Project
    let initialSession: SlatePIPSession?
    let onUpdateSession: ((SlatePIPSession?) -> Void)?
    let isTakeEdited: ((PIPSlateTake, VideoOrientation) -> Bool)?
    let resolveExportTake: ((PIPSlateTake, VideoOrientation) -> ProjectTake?)?

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
            onUpdateSession: onUpdateSession,
            isTakeEdited: { pipTake, orientation in
                resolveCompositeTake(
                    for: pipTake,
                    orientation: orientation,
                    in: session
                ) != nil
            },
            resolveExportTake: { pipTake, orientation in
                resolveCompositeTake(
                    for: pipTake,
                    orientation: orientation,
                    in: session
                )
            }
        )
    }

    static func resolveCompositeTake(
        for pipTake: PIPSlateTake,
        orientation: VideoOrientation,
        in session: ProjectSession
    ) -> ProjectTake? {
        session.takes
            .sorted { $0.createdAt > $1.createdAt }
            .first { take in
                guard let metadata = take.pipSlateMetadata else {
                    return false
                }

                switch orientation {
                case .portrait:
                    return metadata.portraitTakeID == pipTake.id
                case .landscape:
                    return metadata.landscapeTakeID == pipTake.id
                }
            }
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
                },
                isTakeEdited: context.isTakeEdited,
                resolveExportTake: context.resolveExportTake
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
