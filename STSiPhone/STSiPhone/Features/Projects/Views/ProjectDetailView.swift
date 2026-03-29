import SwiftUI
import UIKit
import AVFoundation  // PHASE 1: NEW - Import AVFoundation for editor integration
import UniformTypeIdentifiers

public enum ProjectDetailMode: Equatable {
    case active
    case archived
}

// CRITICAL FIX: Add missing VideoPlayerData struct
struct VideoPlayerData: Identifiable {
    let id = UUID()
    let take: ProjectTake
    let session: ProjectSession
}

// CRITICAL FIX: Add missing ActorMustKnowsData struct to fix empty sheet bug
struct ActorMustKnowsData: Identifiable {
    let id = UUID()
    let project: Project
    let session: ProjectSession
}

// STEP 1: Add ExportManagerData struct to fix sheet presentation bug
struct ExportManagerData: Identifiable {
    let id = UUID()
    let project: Project
    let session: ProjectSession
    let takes: [EnhancedTake]  // STEP 2B: Add takes to avoid recreating them
    let repository: ProjectsRepository  // CRITICAL FIX: Add repository parameter
}

// CRITICAL FIX: Add project-level archive data struct
struct ProjectArchiveData: Identifiable {
    let id = UUID()
    let project: Project
}

// CRITICAL FIX: Add TakeReviewData struct to fix blank sheet bug - ENHANCED: Scene state preservation
struct TakeReviewData: Identifiable {
    let id = UUID()
    let session: ProjectSession
    let project: Project
    let selectedViewType: TakeReviewPage.ViewType? // NEW: Preserve view type
    let selectedSceneNumber: Int? // NEW: Preserve scene number
    let isReadOnly: Bool
}

// NEW: Swipeable Video Player Data for centralized modal management - ENHANCED: Context preservation
struct SwipeableVideoPlayerData: Identifiable {
    let id = UUID()
    let takes: [ProjectTake]
    let initialIndex: Int
    let session: ProjectSession
    let project: Project
    let contextViewType: TakeReviewPage.ViewType // NEW: Remember which context we came from
    let contextSceneNumber: Int? // NEW: Remember which scene we came from (if applicable)
    let savedResultTakeID: UUID?
    let savedResultContext: SmartFillReopenDestinationContext?
}

// NEW: Centralized modal management to fix iOS sheet stacking issue
enum ProjectModalType {
    case none
    case actorMustKnows(ActorMustKnowsData)
    case exportManager(ExportManagerData)
    case projectArchive(ProjectArchiveData)
    case smartFillSettings(SmartFillSettingsContext)
}

struct SmartFillSettingsContext: Identifiable {
    let id = UUID()
    let take: ProjectTake
    let session: ProjectSession
    let project: Project
    let launchSource: SmartFillLaunchSource
    let returnTarget: SmartFillReturnTarget
    let autoLaunchEditor: Bool
    let displayName: String
    let infoTitle: String?
    let infoMessage: String?
    let existingSettings: SmartFillSettings?
    let onUpdatePIPSession: ((SlatePIPSession?) -> Void)?
    
    var previewURL: URL {
        VideoVariantResolver.originalURL(for: take)
    }
    
    var pipSlateSession: SlatePIPSession? {
        session.pipSlateSession
    }

    func updating(
        launchSource: SmartFillLaunchSource,
        returnTarget: SmartFillReturnTarget
    ) -> SmartFillSettingsContext {
        SmartFillSettingsContext(
            take: take,
            session: session,
            project: project,
            launchSource: launchSource,
            returnTarget: returnTarget,
            autoLaunchEditor: autoLaunchEditor,
            displayName: displayName,
            infoTitle: infoTitle,
            infoMessage: infoMessage,
            existingSettings: existingSettings,
            onUpdatePIPSession: onUpdatePIPSession
        )
    }
}

struct SmartFillInFlight: Identifiable {
    let id = UUID()
    let originalTakeID: UUID
    let sessionID: UUID
    let projectID: UUID
    let autoLaunchEditor: Bool
    let displayName: String
}

private struct PendingSmartFillOpenRequest {
    let result: SmartFillResultBridgeRecord
    let context: SmartFillSettingsContext
}

struct SmartFillErrorMessage: Identifiable {
    let id = UUID()
    let message: String
}

struct KeyframePhotoReplaceContext: Identifiable {
    let id = UUID()
    let target: ProjectTake
    let existing: ProjectTake
    let session: ProjectSession
}

// MARK: - Shared ActivityViewController with iPad Fix
struct ActivityViewController: UIViewControllerRepresentable {
    let activityItems: [Any]

    private static func prepareActivityItems(_ items: [Any]) -> [Any] {
        items.map { item in
            guard let url = item as? URL, url.isFileURL else { return item }
            let ext = url.pathExtension.lowercased()
            let type = UTType(filenameExtension: ext) ?? inferredType(for: ext)
            guard let resolvedType = type,
                  resolvedType.conforms(to: .movie) || resolvedType.conforms(to: .image) else {
                return item
            }
            return makeFileProvider(url: url, type: resolvedType)
        }
    }

    private static func inferredType(for fileExtension: String) -> UTType? {
        switch fileExtension {
        case "mov", "mp4", "m4v":
            return .movie
        case "jpg", "jpeg", "png", "heic", "heif":
            return .image
        default:
            return nil
        }
    }

    private static func makeFileProvider(url: URL, type: UTType) -> NSItemProvider {
        let provider = NSItemProvider()
        provider.suggestedName = url.lastPathComponent
        provider.registerFileRepresentation(forTypeIdentifier: type.identifier, fileOptions: [], visibility: .all) { completion in
            completion(url, false, nil)
            return nil
        }
        return provider
    }

#if DEBUG
    private static func logShareItems(_ items: [Any], label: String) {
        items.forEach { debugShareItem($0, label: label) }
    }

    private static func debugShareItem(_ item: Any, label: String) {
        if let url = item as? URL {
            let ext = url.pathExtension.lowercased()
            let type = UTType(filenameExtension: ext)
            let exists = FileManager.default.fileExists(atPath: url.path)
            let readable = FileManager.default.isReadableFile(atPath: url.path)
            let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size]) as? NSNumber
            let sizeValue = size?.int64Value ?? 0
            print("ShareDebug[\(label)]: url=\(url.path) file=\(url.isFileURL) ext=\(ext) exists=\(exists) readable=\(readable) size=\(sizeValue) uti=\(type?.identifier ?? "nil")")
        } else if let data = item as? Data {
            print("ShareDebug[\(label)]: data bytes=\(data.count)")
        } else if let provider = item as? NSItemProvider {
            print("ShareDebug[\(label)]: provider types=\(provider.registeredTypeIdentifiers)")
        } else {
            print("ShareDebug[\(label)]: item type=\(type(of: item))")
        }
    }
#endif
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let preparedItems = ActivityViewController.prepareActivityItems(activityItems)
#if DEBUG
        ActivityViewController.logShareItems(activityItems, label: "raw")
        ActivityViewController.logShareItems(preparedItems, label: "prepared")
#endif
        let controller = UIActivityViewController(
            activityItems: preparedItems,
            applicationActivities: nil
        )
        
        // Exclude some activities that don't make sense for video files
        controller.excludedActivityTypes = [
            .assignToContact,
            .addToReadingList,
            .postToVimeo
        ]
        
        // CRITICAL FIX: Configure popover for iPad to prevent blank share sheet
        if let popover = controller.popoverPresentationController {
            // Set source to center of screen since we don't have access to the specific button
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first {
                popover.sourceView = window.rootViewController?.view
                popover.sourceRect = CGRect(
                    x: window.bounds.midX,
                    y: window.bounds.midY,
                    width: 0,
                    height: 0
                )
                popover.permittedArrowDirections = [] // No arrow when centered
            }
        }
        
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

public struct ProjectDetailView: View {
    @State private var vm: ProjectDetailViewModel
    @State private var mode: ProjectDetailMode
    @State private var showNewSessionWizard = false
    @State private var showingBookedAlert = false
    @State private var fabScale: CGFloat = 1.0
    @State private var expandedSessions: Set<UUID> = []
    @State private var showDeleteProjectConfirmation = false
    @State private var showEditProjectWizard = false
    @State private var pendingSmartFillSettingsContext: SmartFillSettingsContext?
    @State private var isSmartFillPresentationScheduled = false
    @State private var suppressTakeReviewReturn = false
    @State private var pendingTakeReviewAfterSmartFill: TakeReviewData?
    @State private var pendingSmartFillOpenRequest: PendingSmartFillOpenRequest?
    @State private var activePlayerData: SwipeableVideoPlayerData?
    @State private var smartFillInFlight: SmartFillInFlight?
    @State private var smartFillError: SmartFillErrorMessage?
    @State private var editorReturnReviewData: TakeReviewData?
    
    // CRITICAL FIX: Centralized modal state management to prevent iOS sheet stacking conflicts
    @State private var activeModal: ProjectModalType = .none
    @State private var takeReviewState: TakeReviewData?
    
    @State private var sessionToDelete: ProjectSession?
    
    // NEW: State for native iOS sharing
    struct ShareSheetPayload: Identifiable {
        let id = UUID()
        let items: [Any]
    }
    @State private var shareSheetPayload: ShareSheetPayload?

    // NEW: Submitted deliverable alerts / info
    @State private var submittedInfoAlertMessage: String = ""
    @State private var submittedInfoAlertTake: ProjectTake?
    @State private var showingSubmittedInfoAlert = false

    @State private var pendingSubmittedToggleTake: ProjectTake?
    @State private var pendingSubmittedToggleTargetState: Bool = false
    @State private var showingSubmittedToggleAlert = false

    @State private var pendingKeyframePhotoReplace: KeyframePhotoReplaceContext?

    @State private var showRestoreConfirm = false

    @State private var profileManager = ActorProfileManager()
    @State private var showingActorKit = false

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var navCtx: NavigationContextManager
    @EnvironmentObject private var themeManager: ThemeManager
    
    private var theme: STSTheme { themeManager.current }
    
    private var accentGlow: some View {
        RadialGradient(
            gradient: Gradient(colors: [
                theme.primaryAccent.opacity(theme.id == .studioLobbyV1 ? 0.18 : 0.24),
                Color.clear
            ]),
            center: .center,
            startRadius: 0,
            endRadius: 480
        )
        .blendMode(.screen)
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private var readOnlyActionHint: some View {
        HStack(spacing: 8) {
            Image(systemName: "lock.fill")
            Text("Restore to edit or record")
                .fontWeight(.semibold)
        }
        .font(.subheadline)
    }

    private var readOnlyHelperText: some View {
        HStack(spacing: 8) {
            Image(systemName: "archivebox.fill")
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text("Archived Project")
                    .font(.headline)
                Text("Read-only mode. Restore to make changes.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 6)
        .padding(.horizontal)
    }

    private var isReadOnly: Bool { mode == .archived }

    public init(projectID: UUID, repo: ProjectsRepository, mode: ProjectDetailMode = .active) {
        _vm = State(initialValue: ProjectDetailViewModel(projectID: projectID, repo: repo))
        _mode = State(initialValue: mode)
    }

    public var body: some View {
        applyTopLevelModifiers(to: basePageContent)
    }

    private var basePageContent: some View {
        ZStack {
            theme.backgroundGradient
                .ignoresSafeArea()
            accentGlow
            
            if let project = vm.project {
                projectContent(project)
            } else {
                EmptyStateView(title: "Not Found", message: "This project could not be loaded.")
            }
            
            smartFillProcessingBanner
            overlayCreateSessionButton
        }
    }

    private var isModalPresented: Bool {
        if case .none = activeModal {
            return false
        }
        return true
    }

    private func applyTopLevelModifiers(to base: some View) -> some View {
        var view: AnyView = AnyView(base)
        
        view = AnyView(view
            .navigationTitle(vm.project?.title ?? "Project")
            .navigationBarTitleDisplayMode(.inline))
        
        view = AnyView(view.toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                ActorKitAvatarButton(image: profileAvatarImage) {
                    showingActorKit = true
                }
            }
        })
        
        view = AnyView(view.toolbar(.hidden, for: .bottomBar))
        view = AnyView(view.tint(theme.primaryAccent))
        
        view = AnyView(view.onAppear {
            vm.reload()
            if let project = vm.project {
                expandedSessions = Set(project.sessions.map { $0.id })
            }
            profileManager = ActorProfileManager()
        })
        
        view = AnyView(view.onReceive(NotificationCenter.default.publisher(for: .actorProfileDidUpdate)) { _ in
            profileManager = ActorProfileManager()
        })

        view = AnyView(view.alert("Restore project?", isPresented: $showRestoreConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Restore") {
                Task { await restoreProject() }
            }
        } message: {
            Text("This moves the project back to Active Projects and re-enables recording and editing.")
        })

        view = AnyView(view.stsSupportedOrientations(.all, label: "ProjectDetailView"))
        
        view = AnyView(view.fullScreenCover(
            isPresented: Binding(
                get: { isModalPresented },
                set: { if !$0 { activeModal = .none } }
            )
        ) {
            modalContent
        })
        
        view = AnyView(view.sheet(isPresented: $showNewSessionWizard) {
            NewSessionWizard(projectID: vm.projectID, repo: vm.repo) { _ in
                vm.reload()
            }
        })
        
        view = AnyView(view.sheet(isPresented: $showEditProjectWizard) {
            if let project = vm.project {
                NavigationStack {
                    NewProjectWizard(
                        existingProject: project,
                        repo: vm.repo,
                        startStep: nil,
                        onSave: { editedProject in
                            applyProjectEdits(original: project, edited: editedProject)
                        },
                        onRecordingComplete: nil,
                        showsSaveInsteadOfCancel: true
                    )
                }
                .interactiveDismissDisabled(true)
            }
        })
        
        view = AnyView(view.sheet(item: $shareSheetPayload) { payload in
            ActivityViewController(activityItems: payload.items)
        })
        
        view = AnyView(view.alert(item: $smartFillError) { error in
            Alert(
                title: Text("SmartFill Unavailable"),
                message: Text(error.message),
                dismissButton: .default(Text("OK"))
            )
        })
        
        view = AnyView(view.fullScreenCover(isPresented: $showingActorKit) {
            ActorKitView(profileManager: profileManager, projectsRepository: vm.repo)
                .onDisappear {
                    profileManager = ActorProfileManager()
                }
        })
        
        view = AnyView(view.alert("Delete Project?", isPresented: $showDeleteProjectConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete Forever", role: .destructive) {
                if let project = vm.project {
                    vm.repo.delete(project: project)
                    NotificationCenter.default.post(name: Notification.Name("STSProjectsListShouldReload"), object: nil)
                    dismiss()
                }
            }
        } message: {
            if let project = vm.project {
                Text("This will permanently delete \"\(project.title)\" and all \(project.sessions.count) session\(project.sessions.count == 1 ? "" : "s"). This action cannot be undone.")
            }
        })
        
        view = AnyView(view.alert("Delete Session?", isPresented: Binding(get: { sessionToDelete != nil }, set: { _ in sessionToDelete = nil })) {
            Button("Cancel", role: .cancel) {}
            Button("Delete Session", role: .destructive) {
                if let session = sessionToDelete {
                    vm.deleteSession(session)
                    sessionToDelete = nil
                }
            }
        } message: {
            if let session = sessionToDelete {
                Text("This will permanently delete this \(session.type.rawValue) session and all \(session.takes.count) take\(session.takes.count == 1 ? "" : "s").")
            }
        })

        // NEW: Submitted toggle confirmation from Project Lobby
        view = AnyView(view.alert(
            pendingSubmittedToggleTargetState ? "Mark as Submitted" : "Mark as Not Submitted",
            isPresented: $showingSubmittedToggleAlert,
            presenting: pendingSubmittedToggleTake
        ) { take in
            Button(pendingSubmittedToggleTargetState ? "Submit Tape" : "Mark Not Submitted", role: .destructive) {
                handleSubmittedToggleConfirmed(take: take, isSubmitted: pendingSubmittedToggleTargetState)
                pendingSubmittedToggleTake = nil
            }
            Button("Cancel", role: .cancel) {
                pendingSubmittedToggleTake = nil
            }
        } message: { _ in
            if pendingSubmittedToggleTargetState {
                Text("Did you send the Self-Tape to your Reps or Casting? Mark this final tape as submitted to keep it pinned on this project and stop audition reminders for this session.")
            } else {
                Text("Mark this tape as not submitted if you want to change your final tape or keep working on this audition.")
            }
        })

        // NEW: Submitted tape info alert
        view = AnyView(view.alert("Video Info", isPresented: $showingSubmittedInfoAlert) {
            Button("OK", role: .cancel) {
                submittedInfoAlertTake = nil
                submittedInfoAlertMessage = ""
            }
        } message: {
            Text(submittedInfoAlertMessage)
        })

        view = AnyView(view.alert(
            "Replace Final Keyframe?",
            isPresented: Binding(
                get: { pendingKeyframePhotoReplace != nil },
                set: { if !$0 { pendingKeyframePhotoReplace = nil } }
            ),
            presenting: pendingKeyframePhotoReplace
        ) { context in
            Button("Cancel", role: .cancel) {
                handleKeyframePhotoReplaceCancelled(context)
                pendingKeyframePhotoReplace = nil
            }
            Button("Replace") {
                applyKeyframePhotoReplacement(context)
                pendingKeyframePhotoReplace = nil
            }
        } message: { _ in
            Text("Only one keyframe photo can be used for your export thumbnail. Replace your current ⭐ photo with this one?")
        })
        
        view = AnyView(view.onReceive(NotificationCenter.default.publisher(for: Notification.Name("STSTakeRatingUpdated"))) { notification in
            if let projectIDFromNotification = notification.userInfo?["projectID"] as? UUID,
               projectIDFromNotification == vm.projectID {
                DispatchQueue.main.async {
                    vm.reload()
                }
                print("🔄 ProjectDetailView: Force reloaded due to rating update")
            }
        })
        
        view = AnyView(view.onReceive(NotificationCenter.default.publisher(for: Notification.Name("STSProjectsListShouldReload"))) { _ in
            DispatchQueue.main.async {
                vm.reload()
            }
        })
        
        view = AnyView(view.onReceive(NotificationCenter.default.publisher(for: .smartFillDidComplete)) { notification in
            handleSmartFillCompletionNotification(notification)
        })
        
        view = AnyView(view.onReceive(NotificationCenter.default.publisher(for: .smartFillDidFail)) { notification in
            handleSmartFillFailureNotification(notification)
        })
        
        view = AnyView(view.onChange(of: activeModalKey, initial: false) {
            presentPendingSmartFillSheetIfPossible()
        })
        
        view = AnyView(view.frame(maxWidth: .infinity, alignment: .leading))
        
        return view
    }

    @MainActor
    private func restoreProject() async {
        await vm.unarchiveProject()
        vm.reload()
        mode = .active
        NotificationCenter.default.post(name: Notification.Name("STSProjectsListShouldReload"), object: nil)
    }
    
    // CRITICAL FIX: Centralized modal content resolver
    @ViewBuilder
    private var modalContent: some View {
        switch activeModal {
        case .none:
            EmptyView()
            
        case .actorMustKnows(let data):
            ActorMustKnowsView(
                project: data.project,
                session: data.session,
                repository: vm.repo,
                onComplete: {
                    activeModal = .none
                    vm.reload()
                },
                onNavigateToWizard: nil,
                onCompletionStatus: { _ in
                    vm.reload()
                }
            )
            
        case .exportManager(let data):
            ExportManagerView(
                takes: data.takes,
                project: data.project,
                session: data.session,
                repository: data.repository,
                onDismiss: {
                    vm.reload()
                    NotificationCenter.default.post(
                        name: Notification.Name("STSExportCompleted"),
                        object: nil,
                        userInfo: ["sessionID": data.session.id]
                    )
                    activeModal = .none
                }
            )
            .onAppear {
            }
            
        case .projectArchive(let archiveData):
            ProjectArchiveModal(
                project: archiveData.project,
                onDismiss: {
                    activeModal = .none
                },
                onDelete: {
                    activeModal = .none
                    vm.repo.delete(project: archiveData.project)
                    NotificationCenter.default.post(name: Notification.Name("STSProjectsListShouldReload"), object: nil)
                    dismiss()
                },
                onArchive: { request in
                    activeModal = .none
                    Task {
                        await vm.archiveProject(request: request)
                        NotificationCenter.default.post(name: Notification.Name("STSProjectsListShouldReload"), object: nil)
                        dismiss()
                    }
                }
            )
            
        // PHASE 1: NEW - Lightweight Editor modal
        case .smartFillSettings(let context):
            SmartFillWorkspaceView(
                context: context,
                onQueueSmartFill: { settings in
                    enqueueSmartFill(using: settings, context: context)
                },
                onOpenSavedTake: { record in
                    pendingSmartFillOpenRequest = PendingSmartFillOpenRequest(
                        result: record,
                        context: context
                    )
                    activeModal = .none
                },
                onCancel: {
                    activeModal = .none
                }
            )
            .onDisappear {
                presentPendingSmartFillSheetIfPossible()
                if !openPendingSmartFillResultIfPossible() {
                    restoreTakeReviewAfterSmartFill()
                }
            }
        }
    }
    
    @ViewBuilder
    private func projectContent(_ project: Project) -> some View {
        List {
            if isReadOnly {
                ArchivedProjectBanner {
                    showRestoreConfirm = true
                }
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)

                readOnlyHelperText
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }

            projectMissionSection(project)
            sessionsSection(project)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .padding(.bottom, 60)
    }
    
    @ViewBuilder
    private func projectMissionSection(_ project: Project) -> some View {
        Section {
            ProjectMissionBriefView(
                project: project,
                sessionStats: sessionStats(for: project),
                dueInfo: dueInfo(for: project),
                theme: theme,
                submittedHeadshot: submittedHeadshotThumbnail(for: project),
                isReadOnly: isReadOnly,
                onEdit: {
                    guard !isReadOnly else { return }
                    showEditProjectWizard = true
                },
                onArchive: {
                    guard !isReadOnly else { return }
                    activeModal = .projectArchive(ProjectArchiveData(project: project))
                },
                onDelete: {
                    guard !isReadOnly else { return }
                    showDeleteProjectConfirmation = true
                }
            )
        }
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }
    
    @ViewBuilder
    private func sessionsSection(_ project: Project) -> some View {
        let sessions = orderedSessions(for: project)
        Section {
            ForEach(sessions) { session in
                SessionNavigationCard(
                    session: session,
                    ordinalLabel: sessionOrdinalLabel(for: session, in: project),
                    checklistProgress: session.auditionChecklist ?? ChecklistProgress(sessionID: session.id),
                    checklistContext: checklistContextTitle(for: session),
                    roleName: session.roleName ?? project.roles.first?.name,
                    theme: theme,
                    isReadOnly: isReadOnly,
                    onNavigate: {
                        presentTakeReviewFlow(TakeReviewData(
                            session: session,
                            project: project,
                            selectedViewType: nil,
                            selectedSceneNumber: nil,
                            isReadOnly: isReadOnly
                        ))
                    },
                    onDelete: {
                        handleSessionAction(.deleteSession, for: session)
                    },
                    onChecklistTap: {
                        activeModal = .actorMustKnows(ActorMustKnowsData(project: project, session: session))
                    },
                    onSubmittedDeliverableAction: { action, take in
                        if isReadOnly && action == .toggleSubmitted {
                            return
                        }
                        switch action {
                        case .play:
                            presentMediaPlayer(
                                SwipeableVideoPlayerData(
                                    takes: [take],
                                    initialIndex: 0,
                                    session: session,
                                    project: project,
                                    contextViewType: .deliverables,
                                    contextSceneNumber: take.sceneNumber,
                                    savedResultTakeID: nil,
                                    savedResultContext: nil
                                ),
                                transitionFromCurrentFlow: false,
                                returnToTakeReviewOnDismiss: false
                            )
                        case .share:
                            shareTake(take)
                        case .toggleSubmitted:
                            requestSubmittedToggleFromLobby(take: take)
                        case .info:
                            showSubmittedVideoInfoFromLobby(take: take)
                        }
                    }
                )
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }
        }
    }
    
    private func presentTakeReviewFlow(_ data: TakeReviewData, transitionFromCurrentFlow: Bool = false) {
        takeReviewState = data
        let payload = TakeReviewPayload {
            TakeReviewPage(
                session: data.session,
                project: data.project,
                repository: vm.repo,
                initialViewType: data.selectedViewType,
                initialSceneNumber: data.selectedSceneNumber,
                onSessionAction: { action in
                    handleSessionAction(action, for: data.session)
                },
                onTakeAction: { action, take in
                    handleTakeAction(action, for: take, in: data.session, project: data.project)
                },
                onVideoPlayerRequest: { takes, initialIndex, viewType, sceneNumber, prefersMediaPlayer in
                    let playerData = SwipeableVideoPlayerData(
                        takes: takes,
                        initialIndex: initialIndex,
                        session: data.session,
                        project: data.project,
                        contextViewType: viewType,
                        contextSceneNumber: sceneNumber,
                        savedResultTakeID: nil,
                        savedResultContext: nil
                    )
                    if prefersMediaPlayer {
                        presentMediaPlayer(playerData, transitionFromCurrentFlow: true)
                    } else {
                        presentVideoPlayer(playerData, transitionFromCurrentFlow: true)
                    }
                },
                onClose: {
                    dismissTakeReviewFlow()
                },
                onExitProcessingReady: nil,
                isReadOnly: data.isReadOnly
            )
            .environmentObject(navCtx)
        }
        
        if transitionFromCurrentFlow {
            FlowCoordinator.shared.transition(
                to: .takeReview(payload: payload),
                viaProcessingOverlay: false
            )
        } else {
            FlowCoordinator.shared.present(.takeReview(payload: payload))
        }
    }
    
    private func dismissTakeReviewFlow() {
        takeReviewState = nil
        FlowCoordinator.shared.dismiss()
        presentPendingSmartFillSheetIfPossible()
    }
    
    private func checklistContextTitle(for session: ProjectSession) -> String {
        if let role = session.roleName, !role.isEmpty {
            return "\(session.type.rawValue) • \(role)"
        } else if let projectTitle = vm.project?.title {
            return "\(projectTitle) • \(session.type.rawValue)"
        } else {
            return session.type.rawValue
        }
    }
    
    @ViewBuilder
    private var smartFillProcessingBanner: some View {
        if let pending = smartFillInFlight {
            VStack {
                Spacer()
                HStack(spacing: 12) {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(0.9)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Creating widescreen take…")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                        Text(pending.displayName)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    Capsule()
                        .fill(Color.black.opacity(0.65))
                )
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.25), lineWidth: 0.8)
                )
                .shadow(color: Color.black.opacity(0.35), radius: 16, x: 0, y: 12)
                .padding(.bottom, 130)
                .padding(.horizontal, 32)
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .allowsHitTesting(false)
        } else {
            EmptyView()
        }
    }
    
    @ViewBuilder
    private var overlayCreateSessionButton: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                if isReadOnly {
                    readOnlyActionHint
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.black.opacity(0.55), in: Capsule())
                        .overlay(
                            Capsule()
                                .stroke(Color.white.opacity(0.35), lineWidth: 1.2)
                        )
                        .foregroundStyle(.white)
                } else {
                    Button {
                        showNewSessionWizard = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "plus.circle.fill")
                            Text("Create Additional Session")
                                .fontWeight(.semibold)
                        }
                        .padding(.horizontal, 22)
                        .padding(.vertical, 12)
                        .background(Color.black.opacity(0.55), in: Capsule())
                        .overlay(
                            Capsule()
                                .stroke(Color.white.opacity(0.35), lineWidth: 1.2)
                        )
                        .shadow(color: Color.black.opacity(0.35), radius: 18, x: 0, y: 18)
                    }
                    .foregroundStyle(.white)
                }
            }
            .padding(.bottom, 48)
            .padding(.horizontal, 24)
        }
    }
    
    private func toggleSession(_ sessionID: UUID) {
        withAnimation(.easeInOut(duration: 0.3)) {
            if expandedSessions.contains(sessionID) {
                expandedSessions.remove(sessionID)
            } else {
                expandedSessions.insert(sessionID)
            }
        }
    }
    
    private func handleSessionAction(_ action: SessionAction, for session: ProjectSession) {

        if isReadOnly {
            switch action {
            case .export, .exportAndShare:
                break
            default:
                return
            }
        }
        
        switch action {
        case .favorite:
            vm.toggleSessionFavorite(session)
            
        case .duplicate:
            vm.duplicateSession(session)
            
        case .export:
            vm.exportSession(session)
            
        case .delete:
            vm.deleteSession(session)
            
        case .resume:
            let lastScene = getLastSceneWithTakes(for: session)
            
            // CRITICAL FIX: Resume should go to TakeReviewPage (SessionReviewModal) NOT camera
            if let project = vm.project {
                // Restore scene state for when camera IS eventually launched
                let sessionManager = SessionManager.shared
                sessionManager.restoreSceneState(sceneNumber: lastScene)
                
                // Go directly to SessionReviewModal (TakeReviewPage) - restore to last scene
                presentTakeReviewFlow(TakeReviewData(
                    session: session,
                    project: project,
                    selectedViewType: .scenes, // NEW: Start with scenes view
                    selectedSceneNumber: lastScene, // NEW: Start with last active scene
                    isReadOnly: isReadOnly
                ))
                
                
                print("🎬 Resume: Opening SessionReviewModal for session with \(session.takes.count) takes, scene \(lastScene)")
            }
            
        case .exportAndShare:
            
            // STEP 1: Add helper method to convert ProjectSession to EnhancedTakes
            if let project = vm.project {
                let enhancedTakes = convertSessionToEnhancedTakes(session)
                activeModal = .exportManager(ExportManagerData(
                    project: project,
                    session: session,
                    takes: enhancedTakes,
                    repository: vm.repo
                ))
                
                
                print("🚀 Launching ExportManager with \(enhancedTakes.count) takes for session with \(session.takes.count) project takes")
            }
            
        case .deleteSession:
            sessionToDelete = session
        }
    }
    
    private func handleTakeAction(_ action: TakeAction, for take: ProjectTake, in session: ProjectSession, project: Project? = nil) {

        if isReadOnly {
            switch action {
            case .play, .playOriginal, .export, .share:
                break
            default:
                return
            }
        }
        
        switch action {
        case .play:
            // This action is now handled by TakeReviewPage calling onVideoPlayerRequest
            break
            
        case .playOriginal:
            // This action is now handled by TakeReviewPage calling onVideoPlayerRequest with forceOriginal
            break
            
        case .markBest:
            vm.markTakeAsBest(take, in: session)
            
        case .favorite:
            vm.toggleTakeFavorite(take)
            
        case .addNote:
            vm.showTakeNoteEditor(for: take)
            
        case .export:
            vm.exportTake(take)
            
        case .delete:
            vm.deleteTake(take, from: session)
            
        case .setRating(let rating):
            if rating == .finalSelect, isKeyframePhotoCandidate(take) {
                if take.rating != .finalSelect,
                   let existing = session.takes.first(where: { isKeyframePhotoCandidate($0) && $0.rating == .finalSelect && $0.id != take.id }) {
                    pendingKeyframePhotoReplace = KeyframePhotoReplaceContext(
                        target: take,
                        existing: existing,
                        session: session
                    )
                    return
                }
            }
            // UNIFIED: Use the unified rating system through ViewModel
            vm.setUnifiedTakeRating(take, in: session, to: rating)
            
        case .setSubmitted(let updatedTake):
            if let project = project ?? vm.project {
                vm.repo.updateTake(updatedTake, in: session.id, in: project.id)
                vm.reload()
                // TODO: When a deliverable is marked submitted, cancel any pending
                // audition due-date notifications for this project/session.
            } else {
                print("⚠️ ProjectDetailView: Missing project context for setSubmitted")
            }
            
        // NEW: Handle swipe actions
        case .share:
            shareTake(take)
            
        case .deleteTake:
            deleteTakeWithConfirmation(take, from: session)
            
        case .editSmartFill:
            if let project = project ?? vm.project {
                handleSmartFillEdit(take: take, session: session, project: project)
            } else {
                print("⚠️ ProjectDetailView: Missing project context for SmartFill edit action.")
            }
        }
    }

    private func applyKeyframePhotoReplacement(_ context: KeyframePhotoReplaceContext) {
        let otherFinalSelects = context.session.takes.filter {
            isKeyframePhotoCandidate($0) && $0.rating == .finalSelect && $0.id != context.target.id
        }
        for take in otherFinalSelects {
            vm.setUnifiedTakeRating(take, in: context.session, to: .option)
        }
        vm.setUnifiedTakeRating(context.target, in: context.session, to: .finalSelect)
    }

    private func handleKeyframePhotoReplaceCancelled(_ context: KeyframePhotoReplaceContext) {
        postRatingUpdateNotification(for: context.target, sessionID: context.session.id)
    }

    private func postRatingUpdateNotification(for take: ProjectTake, sessionID: UUID) {
        let notificationData: [String: Any] = [
            "takeID": take.id,
            "sessionID": sessionID,
            "projectID": vm.projectID,
            "rating": take.rating.rawValue,
            "timestamp": Date().timeIntervalSince1970,
            "source": "ProjectDetailView"
        ]
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: Notification.Name("STSTakeRatingUpdated"),
                object: nil,
                userInfo: notificationData
            )
        }
    }

    private func isKeyframePhotoCandidate(_ take: ProjectTake) -> Bool {
        guard take.durationSeconds == 0 else { return false }
        if take.takeType.isSlateLike { return false }

        let lowerPath = take.filePath.lowercased()
        if lowerPath.hasSuffix(".jpg") || lowerPath.hasSuffix(".jpeg") || lowerPath.hasSuffix(".png") || lowerPath.hasSuffix(".heic") {
            return true
        }

        if take.isKeyframePhoto { return true }

        if let notes = take.takeNotes?.lowercased(),
           notes.contains("photo") || notes.contains("keyframe") {
            return true
        }

        return !lowerPath.hasSuffix(".mov") && !lowerPath.hasSuffix(".mp4")
    }
    
    // NEW: Share take functionality using native iOS sharing
    private func shareTake(_ take: ProjectTake) {
        let videoURL = resolveEffectiveVideoURL(for: take)
        
        // Verify file exists before sharing
        guard FileManager.default.fileExists(atPath: videoURL.path) else {
            print("❌ ProjectDetailView: Cannot share - video file not found at: \(videoURL.path)")
            // TODO: Show user-friendly error message
            return
        }
        
    DispatchQueue.main.async {
        // Prepare share items via payload to avoid blank sheet
        self.shareSheetPayload = ShareSheetPayload(items: [videoURL])
        print("📤 ProjectDetailView: Sharing \(take.takeType.displayName) - \(videoURL.lastPathComponent)")
    }
}

    private func resolveEffectiveVideoURL(for take: ProjectTake) -> URL {
        if take.filePath.hasPrefix("/") {
            return URL(fileURLWithPath: take.filePath)
        }
        return VideoVariantResolver.urlForRelativePath(take.filePath)
    }
    
    // NEW: Delete take with proper cleanup and refresh
    private func deleteTakeWithConfirmation(_ take: ProjectTake, from session: ProjectSession) {
        // Delete the take using existing ViewModel method
        vm.deleteTake(take, from: session)
        
        // Force refresh to update UI immediately
        vm.reload()
        
        print("🗑️ ProjectDetailView: Deleted \(take.takeType.displayName) - \(URL(fileURLWithPath: take.filePath).lastPathComponent)")
    }

    // MARK: - Submitted deliverable handling (Project Lobby)

    private func requestSubmittedToggleFromLobby(take: ProjectTake) {
        pendingSubmittedToggleTake = take
        let target = take.submittedAt == nil
        pendingSubmittedToggleTargetState = target
        showingSubmittedToggleAlert = true
    }

    private func handleSubmittedToggleConfirmed(take: ProjectTake, isSubmitted: Bool) {
        guard let project = vm.project else { return }

        var updated = take
        updated.submittedAt = isSubmitted ? Date() : nil

        let sessionID = project.sessions.first(where: { session in
            session.takes.contains(where: { $0.id == take.id })
        })?.id

        if let sessionID {
            vm.repo.updateTake(updated, in: sessionID, in: project.id)
        } else {
            print("⚠️ ProjectDetailView: Unable to resolve session for submitted toggle on take \(take.id)")
        }

        vm.reload()
    }

    private func showSubmittedVideoInfoFromLobby(take: ProjectTake) {
        // Remember which take we're working on; do not show the alert yet.
        submittedInfoAlertTake = take

        Task {
            let url = VideoInfoPathResolver.resolveURL(for: take)
            let details = await VideoInfoHelper.buildMessage(
                for: take,
                fileURL: url,
                cameraSettings: nil,
                audioSettings: nil
            )
            await MainActor.run {
                guard submittedInfoAlertTake?.id == take.id else { return }
                let message = details.message.trimmingCharacters(in: .whitespacesAndNewlines)
                submittedInfoAlertMessage = message.isEmpty ? "No video information available." : message

                // Present the alert with the final message only.
                showingSubmittedInfoAlert = true

                print("📹 ProjectDetailView.showSubmittedVideoInfoFromLobby: Presenting alert for take \(take.id)")
            }
        }
    }
    
    private func handleStudioEditorLaunchRequest(_ request: StudioEditorLaunchRequest) {
        let didRoute = StudioEditorHost.route(
            request: request,
            requestSmartFillContext: { take, session, project in
                makeSmartFillRequestContext(
                    for: take,
                    session: session,
                    project: project,
                    autoLaunchEditor: false
                )
            },
            editSmartFillContext: { take, session, project in
                makeSmartFillEditContext(
                    for: take,
                    session: session,
                    project: project,
                    autoLaunchEditor: false
                )
            },
            onStandardEdit: { context in
                presentEditor(for: context.take, session: context.session, project: context.project)
            },
            onSmartFill: { context in
                presentSmartFillSettingsContext(context)
            }
        )

        if didRoute == false, smartFillError == nil {
            smartFillError = SmartFillErrorMessage(
                message: "We couldn't find the original portrait video for this SmartFill. Please record or restore the original take to reprocess it."
            )
        }
    }
    
    private func presentEditor(for take: ProjectTake, session: ProjectSession, project: Project) {
        print("✨ Opening Lightweight Editor for: \(URL(fileURLWithPath: take.filePath).lastPathComponent)")
        captureEditorReturnContext(for: take, session: session, project: project)
        let editorPayload = EditorPayload {
            LightweightEditorView(
                asset: AVURLAsset(url: VideoVariantResolver.effectiveURL(for: take)),
                    repository: vm.repo,
                    take: take,
                    session: session,
                    project: project,
                    onSave: { asset, trimRange, cropRect, rotationDegrees in
                        handleEditorSave(
                            asset: asset,
                            trimRange: trimRange,
                            cropRect: cropRect,
                            cropRotationDegrees: rotationDegrees,
                            originalTake: take,
                            session: session,
                            project: project
                        )
                    },
                onCancel: {
                    handleEditorCancel(
                        take: take,
                        session: session,
                        project: project
                    )
                }
            )
        }
        
        if case .player = FlowCoordinator.shared.activeFlow {
            FlowCoordinator.shared.transition(
                to: .editor(payload: editorPayload),
                viaProcessingOverlay: false
            )
        } else {
            FlowCoordinator.shared.present(.editor(payload: editorPayload))
        }
    }
    
    private func presentVideoPlayer(
        _ data: SwipeableVideoPlayerData,
        transitionFromCurrentFlow: Bool = false,
        returnToTakeReviewOnDismiss: Bool = true
    ) {
        activePlayerData = data
        if transitionFromCurrentFlow {
            takeReviewState = nil
        }
        let payload = PlayerPayload {
            SwipeableVideoPlayerView(
                takes: data.takes,
                session: data.session,
                project: data.project,
                initialIndex: data.initialIndex,
                onDismiss: {
                    activePlayerData = nil
                    if suppressTakeReviewReturn {
                        suppressTakeReviewReturn = false
                        FlowCoordinator.shared.dismiss()
                        presentPendingSmartFillSheetIfPossible()
                    } else if returnToTakeReviewOnDismiss {
                        let reviewData = TakeReviewData(
                            session: data.session,
                            project: data.project,
                            selectedViewType: data.contextViewType,
                            selectedSceneNumber: data.contextSceneNumber,
                            isReadOnly: isReadOnly
                        )
                        presentTakeReviewFlow(reviewData, transitionFromCurrentFlow: true)
                    } else {
                        FlowCoordinator.shared.dismiss()
                    }
                },
                onTakeAction: { action, take in
                    handleTakeAction(action, for: take, in: data.session, project: data.project)
                },
                repository: vm.repo,
                onStudioEditorLaunchRequest: { request in
                    handleStudioEditorLaunchRequest(request)
                },
                savedResultTakeID: data.savedResultTakeID,
                savedResultContext: data.savedResultContext
            )
        }
        
        if transitionFromCurrentFlow {
            FlowCoordinator.shared.transition(
                to: .player(payload: payload),
                viaProcessingOverlay: false
            )
        } else {
            FlowCoordinator.shared.present(.player(payload: payload))
        }
    }
    
    private func presentMediaPlayer(
        _ data: SwipeableVideoPlayerData,
        transitionFromCurrentFlow: Bool = false,
        returnToTakeReviewOnDismiss: Bool = true
    ) {
        activePlayerData = data
        if transitionFromCurrentFlow {
            takeReviewState = nil
        }
        let payload = PlayerPayload {
            SwipeableMediaPlayerView(
                takes: data.takes,
                session: data.session,
                project: data.project,
                initialIndex: data.initialIndex,
                onDismiss: {
                    activePlayerData = nil
                    if suppressTakeReviewReturn {
                        suppressTakeReviewReturn = false
                        FlowCoordinator.shared.dismiss()
                        presentPendingSmartFillSheetIfPossible()
                    } else if returnToTakeReviewOnDismiss {
                        let reviewData = TakeReviewData(
                            session: data.session,
                            project: data.project,
                            selectedViewType: data.contextViewType,
                            selectedSceneNumber: data.contextSceneNumber,
                            isReadOnly: isReadOnly
                        )
                        presentTakeReviewFlow(reviewData, transitionFromCurrentFlow: true)
                    } else {
                        FlowCoordinator.shared.dismiss()
                    }
                },
                onTakeAction: { action, take in
                    handleTakeAction(action, for: take, in: data.session, project: data.project)
                }
            )
        }
        
        if transitionFromCurrentFlow {
            FlowCoordinator.shared.transition(
                to: .player(payload: payload),
                viaProcessingOverlay: false
            )
        } else {
            FlowCoordinator.shared.present(.player(payload: payload))
        }
    }
    
    // PHASE 1: NEW - Handle editor save (placeholder for now)
    private func handleEditorSave(
        asset: AVAsset,
        trimRange: CMTimeRange?,
        cropRect: CGRect?,
        cropRotationDegrees: Double?,
        originalTake: ProjectTake,
        session: ProjectSession,
        project: Project
    ) {
        print("💾 EDITOR SAVE: Processing edits for: \(URL(fileURLWithPath: originalTake.filePath).lastPathComponent)")
        
        if let trimRange = trimRange {
            print("   ✂️ TRIM: \(trimRange.start.seconds) - \(trimRange.end.seconds) (\(trimRange.duration.seconds)s)")
        } else {
            print("   ✂️ TRIM: No trimming applied")
        }
        
        if let cropRect = cropRect {
            print("   🖼️ CROP: \(cropRect) (normalized coordinates)")
            print("   🖼️ CROP: X: \(cropRect.origin.x), Y: \(cropRect.origin.y)")
            print("   🖼️ CROP: Width: \(cropRect.size.width), Height: \(cropRect.size.height)")
        } else {
            print("   🖼️ CROP: No cropping applied")
        }
        
        if let rotation = cropRotationDegrees, abs(rotation) > 0.01 {
            print(String(format: "   🔁 ROTATION: %.2f°", rotation))
        }
        
        let hasMeaningfulCrop = cropRect?.sts_hasMeaningfulCrop ?? false
        let hasRotationChange = (cropRotationDegrees.map { abs($0) > 0.01 } ?? false)
        let hasCropChange = hasMeaningfulCrop || hasRotationChange
        
        // 🚨 CRITICAL FIX: Actually save the edits to the take metadata
        let editMetadata = TakeEditMetadata(
            hasTrimming: trimRange != nil,
            trimStartTime: trimRange?.start.seconds,
            trimEndTime: trimRange?.end.seconds,
            hasCropping: hasCropChange,
            cropRect: cropRect,
            cropRotationDegrees: cropRotationDegrees
        )
        
        var pendingTake = originalTake
        pendingTake.editMetadata = editMetadata.hasEdits ? editMetadata : nil
        
        let projectID = vm.project?.id ?? project.id
        vm.repo.updateTakeEditMetadata(
            takeID: originalTake.id,
            sessionID: session.id,
            projectID: projectID,
            editMetadata: editMetadata
        )
        
        vm.reload()
        
        print("✅ EDITOR SAVE: Persisted edit metadata (hasEdits=\(editMetadata.hasEdits)) to take")
    
        let resolvedSession = resolveSession(withID: session.id) ?? session
        let resolvedProject = vm.project ?? project
        let refreshedTake = resolveTake(withID: originalTake.id, sessionID: session.id) ?? pendingTake
        returnToTakeReview(with: refreshedTake, session: resolvedSession, project: resolvedProject)
    }
    
    // PHASE 1: NEW - Handle editor cancel
    private func handleEditorCancel(take: ProjectTake, session: ProjectSession, project: Project) {
        print("❌ Editor cancelled for: \(URL(fileURLWithPath: take.filePath).lastPathComponent)")
        
        let resolvedSession = resolveSession(withID: session.id) ?? session
        let resolvedProject = vm.project ?? project
        returnToTakeReview(with: take, session: resolvedSession, project: resolvedProject)
    }
    
    private func captureEditorReturnContext(for take: ProjectTake, session: ProjectSession, project: Project) {
        if let review = takeReviewState {
            editorReturnReviewData = review
            return
        }
        if let playerData = activePlayerData {
            editorReturnReviewData = TakeReviewData(
                session: playerData.session,
                project: playerData.project,
                selectedViewType: playerData.contextViewType,
                selectedSceneNumber: playerData.contextSceneNumber,
                isReadOnly: isReadOnly
            )
            return
        }
        let fallbackView: TakeReviewPage.ViewType? = take.takeType.isSlateLike ? .slates : .scenes
        editorReturnReviewData = TakeReviewData(
            session: session,
            project: project,
            selectedViewType: fallbackView,
            selectedSceneNumber: take.sceneNumber,
            isReadOnly: isReadOnly
        )
    }
    
    private func returnToTakeReview(with take: ProjectTake, session: ProjectSession, project: Project) {
        let fallbackView: TakeReviewPage.ViewType? = take.takeType.isSlateLike ? .slates : .scenes
        let fallback = TakeReviewData(
            session: session,
            project: project,
            selectedViewType: fallbackView,
            selectedSceneNumber: take.sceneNumber,
            isReadOnly: isReadOnly
        )
        let data: TakeReviewData
        if let stored = editorReturnReviewData {
            let selectedView = stored.selectedViewType ?? fallbackView
            let selectedScene = stored.selectedSceneNumber ?? take.sceneNumber
            data = TakeReviewData(
                session: session,
                project: project,
                selectedViewType: selectedView,
                selectedSceneNumber: selectedScene,
                isReadOnly: isReadOnly
            )
        } else {
            data = fallback
        }
        editorReturnReviewData = nil
        activePlayerData = nil
        presentTakeReviewFlow(data, transitionFromCurrentFlow: true)
    }
    
    private func resolveSession(withID id: UUID) -> ProjectSession? {
        vm.project?.sessions.first(where: { $0.id == id })
    }
    
    private func resolveTake(withID takeID: UUID, sessionID: UUID) -> ProjectTake? {
        resolveSession(withID: sessionID)?.takes.first(where: { $0.id == takeID })
    }
    
    private func handleSmartFillRequest(take: ProjectTake, session: ProjectSession, project: Project) {
        handleStudioEditorLaunchRequest(
            StudioEditorLaunchRequest(
                sourceTake: take,
                intent: .smartFillRequest(targetTake: take),
                session: session,
                project: project
            )
        )
    }

    private func handleSmartFillEdit(take: ProjectTake, session: ProjectSession, project: Project) {
        handleStudioEditorLaunchRequest(
            StudioEditorLaunchRequest(
                sourceTake: take,
                intent: .smartFillEdit(targetTake: take),
                session: session,
                project: project
            )
        )
    }

    private func makeSmartFillRequestContext(
        for take: ProjectTake,
        session: ProjectSession,
        project: Project,
        autoLaunchEditor: Bool
    ) -> SmartFillSettingsContext? {
        makeSmartFillSettingsContext(
            for: take,
            session: session,
            project: project,
            autoLaunchEditor: autoLaunchEditor,
            allowExistingSmartFill: false
        )
    }

    private func makeSmartFillEditContext(
        for take: ProjectTake,
        session: ProjectSession,
        project: Project,
        autoLaunchEditor: Bool
    ) -> SmartFillSettingsContext? {
        guard let original = resolveOriginalTake(for: take, in: session) else {
            smartFillError = SmartFillErrorMessage(
                message: "We couldn't find the original portrait video for this SmartFill. Please record or restore the original take to reprocess it."
            )
            return nil
        }

        let infoTitle = "Fine-Tune SmartFill"
        let infoMessage = "Adjust the SmartFill look for “\(friendlyTakeDisplayName(for: original, in: session))”."
        let existingSettings = take.smartFillSettings.map { SmartFillTakeBridge.settings(from: $0) }

        return makeSmartFillSettingsContext(
            for: original,
            session: session,
            project: project,
            autoLaunchEditor: autoLaunchEditor,
            allowExistingSmartFill: true,
            infoTitleOverride: infoTitle,
            infoMessageOverride: infoMessage,
            existingSettings: existingSettings
        )
    }

    private func makeSmartFillSettingsContext(
        for take: ProjectTake,
        session: ProjectSession,
        project: Project,
        autoLaunchEditor: Bool,
        allowExistingSmartFill: Bool = false,
        infoTitleOverride: String? = nil,
        infoMessageOverride: String? = nil,
        existingSettings: SmartFillSettings? = nil
    ) -> SmartFillSettingsContext? {
        if smartFillInFlight != nil {
            smartFillError = SmartFillErrorMessage(message: "Please wait for the current SmartFill conversion to finish.")
            return nil
        }
        
        if !allowExistingSmartFill,
           let existing = existingSmartFillTake(for: take, in: session) {
            let message = "“\(friendlyTakeDisplayName(for: take, in: session))” already has a SmartFill version. Use “Edit SmartFill” on \(friendlyTakeDisplayName(for: existing, in: session)) to tweak the background."
            smartFillError = SmartFillErrorMessage(message: message)
            return nil
        }
        
        let displayName = friendlyTakeDisplayName(for: take, in: session)
        let infoTitle = infoTitleOverride ?? "SmartFill Required Before Editing"
        let infoMessage = infoMessageOverride ?? "“\(displayName)” was captured vertically. SmartFill converts it into a cinematic widescreen take that blends seamlessly with your other footage so trimming, cropping, and exports stay precise — and your audition session stands out."
        
        let context = SmartFillSettingsContext(
            take: take,
            session: session,
            project: project,
            launchSource: .projectDetail,
            returnTarget: autoLaunchEditor ? .editor : .projectDetail,
            autoLaunchEditor: autoLaunchEditor,
            displayName: displayName,
            infoTitle: infoTitle,
            infoMessage: infoMessage,
            existingSettings: existingSettings,
            onUpdatePIPSession: { newValue in
                var updatedSession = session
                updatedSession.pipSlateSession = newValue
                vm.repo.updateSession(updatedSession, in: project.id)
                vm.reload()
            }
        )

        return context
    }
    
    private func enqueueSmartFill(
        using settings: SmartFillSettings,
        context: SmartFillSettingsContext
    ) {
        let take = context.take
        let session = context.session
        let project = context.project
        
        let sourceURL = VideoVariantResolver.originalURL(for: take)
        let baseName = sourceURL.deletingPathExtension().lastPathComponent
        let outputURL = sourceURL
            .deletingLastPathComponent()
            .appendingPathComponent("\(baseName)_smartfill.mov")
        
        Task {
            let queued = await SmartFillProcessingManager.shared.enqueueJob(
                originalPath: sourceURL.path,
                outputPath: outputURL.path,
                fileName: sourceURL.lastPathComponent,
                takeID: take.id,
                sessionID: session.id,
                projectID: project.id,
                capturedOrientation: take.capturedOrientation,
                settings: settings
            )
            
            await MainActor.run {
                if queued {
                    smartFillInFlight = SmartFillInFlight(
                        originalTakeID: take.id,
                        sessionID: session.id,
                        projectID: project.id,
                        autoLaunchEditor: context.autoLaunchEditor,
                        displayName: context.displayName
                    )
                    print("📐 SmartFill queued for \(take.id) – waiting for completion notification.")
                } else {
                    NotificationCenter.default.post(
                        name: .smartFillProcessingFailed,
                        object: nil,
                        userInfo: ["error": "SmartFill isn't required for this video."]
                    )
                    smartFillError = SmartFillErrorMessage(
                        message: "This take is already landscape, so SmartFill isn’t needed."
                    )
                }
            }
        }
    }
    
    private func handleSmartFillCompletionNotification(_ notification: Notification) {
        guard
            let pending = smartFillInFlight,
            let originalID = uuid(from: notification.userInfo, key: "originalTakeID"),
            pending.originalTakeID == originalID,
            let newTakeID = uuid(from: notification.userInfo, key: "smartFillTakeID")
        else {
            smartFillInFlight = nil
            return
        }
        defer { smartFillInFlight = nil }
        
        print("✅ SmartFill completed for take \(originalID). Reloading project data.")
        vm.reload()
        
        guard
            let project = vm.project,
            let session = project.sessions.first(where: { $0.id == pending.sessionID }),
            let newTake = session.takes.first(where: { $0.id == newTakeID })
        else {
            print("⚠️ SmartFill completion: Unable to locate new take in repository.")
            return
        }
        
        removeOtherSmartFillTakes(for: originalID, keep: newTakeID, in: session, project: project)
        vm.reload()
        
        if let refreshedProject = vm.project,
           let refreshedSession = refreshedProject.sessions.first(where: { $0.id == pending.sessionID }),
           let refreshedTake = refreshedSession.takes.first(where: { $0.id == newTakeID }) {
            if pending.autoLaunchEditor {
                presentEditor(for: refreshedTake, session: refreshedSession, project: refreshedProject)
            }
        } else if pending.autoLaunchEditor {
            presentEditor(for: newTake, session: session, project: project)
        }
        
    }
    
    private func handleSmartFillFailureNotification(_ notification: Notification) {
        guard
            let pending = smartFillInFlight,
            let originalID = uuid(from: notification.userInfo, key: "takeID"),
            pending.originalTakeID == originalID
        else {
            return
        }
        
        smartFillInFlight = nil
        let errorMessage = (notification.userInfo?["error"] as? String) ?? "Something went wrong while creating the SmartFill video."
        smartFillError = SmartFillErrorMessage(message: errorMessage)
    }
    
    private func uuid(from userInfo: [AnyHashable: Any]?, key: String) -> UUID? {
        guard let userInfo else { return nil }
        if let value = userInfo[key] as? UUID {
            return value
        }
        if let stringValue = userInfo[key] as? String {
            return UUID(uuidString: stringValue)
        }
        return nil
    }
    
    private func friendlyTakeDisplayName(for take: ProjectTake, in session: ProjectSession) -> String {
        TakeDisplayFormatter.label(for: take, in: session)
    }
    
    private var activeModalKey: String {
        switch activeModal {
        case .none: return "none"
        case .actorMustKnows: return "checklist"
        case .exportManager: return "export"
        case .projectArchive: return "archive"
        case .smartFillSettings: return "smartFill"
        }
    }
    
    private func presentSmartFillSettingsContext(_ context: SmartFillSettingsContext) {
        let resolvedContext: SmartFillSettingsContext

        if case .smartFillSettings = activeModal {
            pendingSmartFillSettingsContext = context
            return
        }

        let shouldForceSmartFillSlatesTab = (context.existingSettings == nil)

        if let playerData = activePlayerData {
            resolvedContext = context.updating(
                launchSource: .swipeablePlayer,
                returnTarget: context.autoLaunchEditor ? .editor : .swipeablePlayer
            )
            pendingSmartFillSettingsContext = resolvedContext

            let targetViewType: TakeReviewPage.ViewType =
                shouldForceSmartFillSlatesTab ? .slates : playerData.contextViewType

            pendingTakeReviewAfterSmartFill = TakeReviewData(
                session: playerData.session,
                project: playerData.project,
                selectedViewType: targetViewType,
                selectedSceneNumber: playerData.contextSceneNumber,
                isReadOnly: isReadOnly
            )

            suppressTakeReviewReturn = true
            activePlayerData = nil
            FlowCoordinator.shared.dismiss()

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                self.presentPendingSmartFillSheetIfPossible()
            }
            return

        } else if let reviewData = takeReviewState {
            resolvedContext = context.updating(
                launchSource: .takeReview,
                returnTarget: context.autoLaunchEditor ? .editor : .takeReview
            )
            pendingSmartFillSettingsContext = resolvedContext

            if shouldForceSmartFillSlatesTab {
                pendingTakeReviewAfterSmartFill = TakeReviewData(
                    session: reviewData.session,
                    project: reviewData.project,
                    selectedViewType: .slates,
                    selectedSceneNumber: reviewData.selectedSceneNumber,
                    isReadOnly: reviewData.isReadOnly
                )
            } else {
                pendingTakeReviewAfterSmartFill = reviewData
            }

            dismissTakeReviewFlow()

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                self.presentPendingSmartFillSheetIfPossible()
            }
            return

        } else {
            resolvedContext = context.updating(
                launchSource: .projectDetail,
                returnTarget: context.autoLaunchEditor ? .editor : .projectDetail
            )
            pendingTakeReviewAfterSmartFill = nil
        }

        if case .none = activeModal {
            suppressTakeReviewReturn = false
            activeModal = .smartFillSettings(resolvedContext)
        } else {
            pendingSmartFillSettingsContext = resolvedContext
            suppressTakeReviewReturn = true
            activeModal = .none
        }
    }
    
    private func presentPendingSmartFillSheetIfPossible() {
        guard case .none = activeModal,
              activePlayerData == nil,
              pendingSmartFillSettingsContext != nil,
              isSmartFillPresentationScheduled == false else {
            return
        }
        suppressTakeReviewReturn = false
        isSmartFillPresentationScheduled = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            isSmartFillPresentationScheduled = false
            guard case .none = activeModal,
                  let pending = pendingSmartFillSettingsContext else {
                return
            }
            pendingSmartFillSettingsContext = nil
            activeModal = .smartFillSettings(pending)
        }
    }
    
    private func restoreTakeReviewAfterSmartFill() {
        guard case .none = activeModal,
              activePlayerData == nil,
              let pending = pendingTakeReviewAfterSmartFill else {
            return
        }
        pendingTakeReviewAfterSmartFill = nil
        presentTakeReviewFlow(pending)
    }

    private func openPendingSmartFillResultIfPossible() -> Bool {
        guard case .none = activeModal,
              let pending = pendingSmartFillOpenRequest else {
            return false
        }

        pendingSmartFillOpenRequest = nil

        guard let resolved = resolveSavedSmartFillResult(for: pending.result) else {
            return false
        }

        switch SmartFillWorkspaceFollowUpRoute.resolve(for: pending.context.returnTarget) {
        case .editor:
            pendingTakeReviewAfterSmartFill = nil
            presentEditor(for: resolved.take, session: resolved.session, project: resolved.project)
            return true
        case .player(let returnToTakeReviewOnDismiss):
            let reviewData = pendingTakeReviewAfterSmartFill
            pendingTakeReviewAfterSmartFill = nil
            guard let playerData = makeSmartFillPlayerData(
                for: resolved.take,
                session: resolved.session,
                project: resolved.project,
                preferredReviewData: reviewData,
                savedResultDisplayName: pending.result.adoptedTakeDisplayName,
                originalTakeID: pending.result.originalTakeID
            ) else {
                return false
            }
            presentVideoPlayer(
                playerData,
                transitionFromCurrentFlow: false,
                returnToTakeReviewOnDismiss: returnToTakeReviewOnDismiss
            )
            return true
        case .closeOnly:
            return false
        }
    }

    private func resolveSavedSmartFillResult(
        for record: SmartFillResultBridgeRecord
    ) -> (project: Project, session: ProjectSession, take: ProjectTake)? {
        guard let project = vm.repo.project(by: record.projectID),
              let session = project.sessions.first(where: { $0.id == record.sessionID }),
              let take = session.takes.first(where: { $0.id == record.adoptedTakeID }) else {
            return nil
        }
        return (project, session, take)
    }

    private func makeSmartFillPlayerData(
        for take: ProjectTake,
        session: ProjectSession,
        project: Project,
        preferredReviewData: TakeReviewData?,
        savedResultDisplayName: String? = nil,
        originalTakeID: UUID? = nil
    ) -> SwipeableVideoPlayerData? {
        guard let initialIndex = session.takes.firstIndex(where: { $0.id == take.id }) else {
            return nil
        }

        let fallbackViewType: TakeReviewPage.ViewType = take.takeType.isSlateLike ? .slates : .scenes
        let sourceTake = originalTakeID.flatMap { sourceID in
            session.takes.first(where: { $0.id == sourceID && $0.id != take.id })
        }
        return SwipeableVideoPlayerData(
            takes: session.takes,
            initialIndex: initialIndex,
            session: session,
            project: project,
            contextViewType: preferredReviewData?.selectedViewType ?? fallbackViewType,
            contextSceneNumber: preferredReviewData?.selectedSceneNumber ?? take.sceneNumber,
            savedResultTakeID: take.id,
            savedResultContext: savedResultDisplayName.map {
                SmartFillReopenDestinationContext.player(
                    adoptedTakeDisplayName: $0,
                    sourceTakeID: sourceTake?.id,
                    sourceTakeDisplayName: sourceTake.map { TakeDisplayFormatter.label(for: $0, in: session) }
                )
            }
        )
    }
    
    private func existingSmartFillTake(for original: ProjectTake, in session: ProjectSession, excluding excludedID: UUID? = nil) -> ProjectTake? {
        let tag = smartFillMetadataTag(for: original.id)
        if let tagged = session.takes.first(where: { take in
            if take.id == original.id { return false }
            if let excludedID, take.id == excludedID { return false }
            return take.takeNotes?.contains(tag) == true
        }) {
            return tagged
        }
        
        let base = baseName(from: original)
        return session.takes.first { take in
            if take.id == original.id { return false }
            if let excludedID, take.id == excludedID { return false }
            return isSmartFillFilename(take.filePath) && baseName(fromSmartFill: take) == base
        }
    }
    
    private func removeOtherSmartFillTakes(for originalID: UUID, keep newTakeID: UUID, in session: ProjectSession, project: Project) {
        let tag = smartFillMetadataTag(for: originalID)
        let duplicates = session.takes.filter { take in
            guard take.id != newTakeID, take.id != originalID else { return false }
            return take.takeNotes?.contains(tag) == true
        }
        guard !duplicates.isEmpty else { return }
        duplicates.forEach { dup in
            vm.repo.deleteTake(dup, from: session.id, in: project.id)
        }
        print("🧹 Removed \(duplicates.count) previous SmartFill take(s) for original \(originalID)")
    }
    
    private func existingSmartFillTake(for original: ProjectTake, in session: ProjectSession) -> ProjectTake? {
        existingSmartFillTake(for: original, in: session, excluding: nil)
    }
    
    private func originalTakeID(from smartFillTake: ProjectTake) -> UUID? {
        guard let notes = smartFillTake.takeNotes,
              let range = notes.range(of: "[SMARTFILL_ORIGINAL:") else {
            return nil
        }
        let suffix = notes[range.upperBound...]
        guard let closing = suffix.firstIndex(of: "]") else { return nil }
        let idString = String(suffix[..<closing])
        return UUID(uuidString: idString)
    }
    
    private func smartFillMetadataTag(for takeID: UUID) -> String {
        "[SMARTFILL_ORIGINAL:\(takeID.uuidString)]"
    }
    
    private func resolveOriginalTake(for smartFillTake: ProjectTake, in session: ProjectSession) -> ProjectTake? {
        if let originalID = originalTakeID(from: smartFillTake),
           let original = session.takes.first(where: { $0.id == originalID }) {
            return original
        }
        let smartFillBaseName = baseName(fromSmartFill: smartFillTake)
        let candidates = session.takes.filter { candidate in
            guard candidate.id != smartFillTake.id else { return false }
            guard !isSmartFillFilename(candidate.filePath) else { return false }
            return baseName(from: candidate) == smartFillBaseName
        }
        if let portrait = candidates.first(where: { $0.capturedOrientation == .portrait }) {
            return portrait
        }
        return candidates.first
    }
    
    private func baseName(fromSmartFill take: ProjectTake) -> String {
        let fileName = URL(fileURLWithPath: take.filePath).lastPathComponent
        let sanitized = fileName
            .replacingOccurrences(of: "_smartfill.mov", with: ".mov")
            .replacingOccurrences(of: "_smartfill.mp4", with: ".mp4")
        return URL(fileURLWithPath: sanitized).deletingPathExtension().lastPathComponent
    }
    
    private func baseName(from take: ProjectTake) -> String {
        URL(fileURLWithPath: take.filePath).deletingPathExtension().lastPathComponent
    }
    
    private func isSmartFillFilename(_ path: String) -> Bool {
        URL(fileURLWithPath: path).lastPathComponent.lowercased().contains("_smartfill")
    }
    
    // STEP 1: Add helper method to convert ProjectSession to EnhancedTakes
    private func convertSessionToEnhancedTakes(_ session: ProjectSession) -> [EnhancedTake] {
        return session.takes.enumerated().map { index, take in
            EnhancedTake(
                fileName: URL(fileURLWithPath: take.filePath).lastPathComponent,
                projectID: vm.project?.id ?? UUID(),
                sessionID: session.id,
                filePath: take.filePath,
                duration: take.durationSeconds,
                fileSize: estimateFileSize(for: take.filePath),
                cameraPosition: "back", // Default - could be enhanced later
                sceneNumber: take.sceneNumber,  // Use actual scene number from take
                takeNumber: take.takeNumber,    // Use actual take number from take
                isSlate: take.takeType.isSlateLike,
                rating: take.rating,
                isBest: take.rating == .finalSelect,
                notes: take.takeNotes,
                createdAt: take.createdAt
            )
        }
    }
    
    // STEP 1: Helper to estimate file size
    private func estimateFileSize(for filePath: String) -> Int64 {
        if FileManager.default.fileExists(atPath: filePath) {
            do {
                let attributes = try FileManager.default.attributesOfItem(atPath: filePath)
                return attributes[.size] as? Int64 ?? 0
            } catch {
                print("❌ Could not get file size for \(filePath): \(error)")
            }
        }
        return 0
    }
    
    // NEW: Helper method to get last scene with takes for a specific session
    private func getLastSceneWithTakes(for session: ProjectSession) -> Int {
        let sceneNumbers = Set(session.takes.filter { $0.takeType == .regular && $0.sceneNumber > 0 }.map { $0.sceneNumber })
        return sceneNumbers.max() ?? 1
    }
}

// MARK: - Helper Views
private struct ArchivedProjectBanner: View {
    let onRestore: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "archivebox.fill")
                .font(.title3)

            VStack(alignment: .leading, spacing: 4) {
                Text("Archived Project")
                    .font(.headline)
                Text("This project is read-only. Restore it to record or edit.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Restore") {
                onRestore()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.systemGray6))
        )
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(Theme.Font.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(Theme.Font.body)
                .foregroundStyle(.primary)
        }
    }
}

// MARK: - Expandable Session Card
struct ExpandableSessionCard: View {
    let session: ProjectSession
    let isExpanded: Bool
    var isReadOnly: Bool = false
    let onToggle: () -> Void
    let onSessionAction: (SessionAction) -> Void
    let onTakeAction: (TakeAction, ProjectTake) -> Void
    let theme: STSTheme
    
    var body: some View {
        VStack(spacing: 0) {
            sessionHeader
            
            if isExpanded {
                expandedContent
            }
        }
    }
    
    @ViewBuilder
    private var sessionHeader: some View {
        Button(action: onToggle) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Image(systemName: sessionTypeIcon(for: session.type))
                            .font(.headline)
                            .foregroundStyle(theme.primaryAccent)
                        
                        Text(session.type.rawValue)
                            .font(Theme.Font.headline)
                            .foregroundStyle(theme.textPrimary)
                        
                        if session.isFavorite {
                            Image(systemName: "star.fill")
                                .font(.caption)
                            .foregroundStyle(.yellow)
                        }
                    }
                    
                    Text(session.date.formatted(date: .abbreviated, time: .shortened))
                        .font(Theme.Font.caption)
                        .foregroundStyle(.secondary)
                    
                    if let roleName = session.roleName {
                        Text("Role: \(roleName)")
                            .font(Theme.Font.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    if !session.takes.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "video.fill")
                                    .font(.caption)
                                    .foregroundStyle(theme.primaryAccent)
                                Text("\(session.takes.count) take\(session.takes.count == 1 ? "" : "s")")
                                    .font(.caption)
                                    .foregroundStyle(theme.textSecondary)
                            }
                        }
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .animation(.easeInOut(duration: 0.2), value: isExpanded)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)  // 🚨 FIX: Use RoundedRectangle not RoundedRectangleBorder
                .fill(theme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(theme.cardStroke, lineWidth: 1)
                )
        )
    }
    
    @ViewBuilder
    private var expandedContent: some View {
        VStack(spacing: 12) {
            sessionActions
            takesList
        }
        .padding(.top, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.black.opacity(0.1))
        )
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
    
    @ViewBuilder
    private var sessionActions: some View {
        HStack(spacing: 12) {
            // SIMPLIFIED: Only Resume, Export & Share, and Delete Session
            if session.type == .selfTape {
                if !session.takes.isEmpty {
                    // STEP 1: Update button text from "Review and export" to "Export & Share"
                    SessionActionButton(
                        icon: "square.and.arrow.up.circle.fill",
                        label: "Export & Share",
                        color: .blue
                    ) {
                        onSessionAction(.exportAndShare)
                    }
                }
                
                // Always show Resume button for self-tape sessions
                SessionActionButton(
                    icon: "video.badge.plus",
                    label: "Resume Session",
                    color: .green
                ) {
                    onSessionAction(.resume)
                }
                
                // FIXED: Only Delete Session button (no archive for sessions)
                SessionActionButton(
                    icon: "trash.circle.fill",
                    label: "Delete Session",
                    color: .red
                ) {
                    onSessionAction(.deleteSession)
                }
            }
        }
    }
    
    @ViewBuilder
    private var takesList: some View {
        if !session.takes.isEmpty {
            VStack(spacing: 8) {
                HStack {
                    Text("Takes")
                        .font(Theme.Font.subheadline)
                        .foregroundStyle(theme.textPrimary)
                    Spacer()
                }
                .padding(.horizontal)
                
                // NEW: Use takesSortedForDisplay to show merged videos at top
                ForEach(Array(session.takesSortedForDisplay.enumerated()), id: \.element.id) { index, take in
                    TakeRow(
                        take: take,
                        takeNumber: take.takeType == .merged ? 0 : (index + 1), // Merged videos show as "Merged" not numbered
                        onAction: { action in
                            onTakeAction(action, take)
                        },
                        theme: theme,
                        isReadOnly: isReadOnly
                    )
                }
            }
        } else {
            Text("No takes recorded yet")
                .font(Theme.Font.caption)
                .foregroundStyle(.secondary)
                .padding()
        }
    }
    
    private func sessionTypeIcon(for type: SessionType) -> String {
        switch type {
        case .selfTape:
            return "video.fill"
        case .callback:
            return "arrow.triangle.2.circlepath"
        case .inPerson:
            return "building.2.fill"
        case .chemistryRead:
            return "person.3.fill"
        }
    }
}

// MARK: - Session Action Button
struct SessionActionButton: View {
    let icon: String
    let label: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(color)
                
                Text(label)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(color.opacity(0.1))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Take Row
struct TakeRow: View {
    let take: ProjectTake
    let takeNumber: Int
    let onAction: (TakeAction) -> Void
    let theme: STSTheme
    let isReadOnly: Bool

    @State private var showDeleteConfirmation = false

    private var effectiveRating: TakeRating {
        SessionManager.shared.effectiveRating(for: take) ?? take.rating
    }
    
    var body: some View {
        mainRowContent
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                // Share action (blue)
                Button {
                    onAction(.share)
                } label: {
                    Label("Share", systemImage: "square.and.arrow.up.fill")
                }
                .tint(.blue)
                
                if !isReadOnly {
                    // Delete action (red, destructive)
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Label("Delete", systemImage: "trash.fill")
                    }
                }
            }
            .alert("Delete Video?", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete Forever", role: .destructive) {
                    onAction(.deleteTake)
                }
            } message: {
                Text(deleteConfirmationMessage)
            }
    }
    
    // FIXED: Clean main row content without custom drag gestures
    @ViewBuilder
    private var mainRowContent: some View {
        HStack(spacing: 12) {
            videoThumbnail
            takeInfo
            Spacer()
            if take.takeType == .merged {
                exportInfo
            } else if take.takeType == .exported {
                exportedTakeInfo
            } else {
                takeActions
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(takeRowBackgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(takeRowBorderColor, lineWidth: take.takeType == .merged ? 2 : 0)
                )
        )
    }

    // NEW: Dynamic delete confirmation message based on take type
    private var deleteConfirmationMessage: String {
        switch take.takeType {
        case .merged:
            return "This will permanently delete the merged video. The original takes will remain available."
        case .exported:
            return "This will permanently delete the exported video file. The original take will remain available."
        case .slate:
            return "This will permanently delete the slate video."
        case .pipSlate:
            return "This will permanently delete the PiP slate video."
        case .pipComponent:
            return "PiP component clips are managed inside the PiP editor. Deleting here will remove this clip."
        case .regular:
            return "This will permanently delete this take. This action cannot be undone."
        }
    }

    // NEW: Dynamic background color based on take type
    private var takeRowBackgroundColor: Color {
        switch take.takeType {
        case .merged:
            return Color.green.opacity(0.15)
        case .exported:
            return Color.blue.opacity(0.12)
        case .slate:
            return Color.blue.opacity(0.08)
        case .pipSlate:
            return Color.pink.opacity(0.1)
        case .pipComponent:
            return Color.clear
        case .regular:
            if take.isExported {
                return Color.yellow.opacity(0.08)
            } else {
                return Color.white.opacity(0.05)
            }
        }
    }
    
    // NEW: Dynamic border color for special take types
    private var takeRowBorderColor: Color {
        switch take.takeType {
        case .merged:
            return Color.green.opacity(0.6)
        case .exported:
            return Color.blue.opacity(0.5)
        case .slate:
            return Color.blue.opacity(0.3)
        case .pipSlate:
            return Color.pink.opacity(0.35)
        case .pipComponent:
            return Color.clear
        case .regular:
            if take.isExported {
                return Color.yellow.opacity(0.4)
            } else {
                return Color.clear
            }
        }
    }
    
    @ViewBuilder
    private var videoThumbnail: some View {
        Button {
            onAction(.play)
        } label: {
            ZStack {
                // CRITICAL FIX: Replace AsyncImage with working ThumbnailPreviewView
                ThumbnailPreviewView(unifiedTake: createUnifiedTakeForThumbnail())
                    .frame(width: 60, height: 36)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                
                // Play overlay for videos only (photos handled by ThumbnailPreviewView)
                if take.takeType != .regular || take.durationSeconds > 0.0 {
                    Image(systemName: "play.fill")
                        .font(.caption)
                        .foregroundStyle(take.takeType == .merged ? .green : theme.primaryAccent)
                        .background(
                            Circle()
                                .fill(.black.opacity(0.6))
                                .frame(width: 24, height: 24)
                        )
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // CRITICAL FIX: Create UnifiedTake for thumbnail generation
    private func createUnifiedTakeForThumbnail() -> UnifiedTake {
        return UnifiedTake(
            id: take.id, // Preserve original ID
            fileName: URL(fileURLWithPath: take.filePath).lastPathComponent,
            projectID: UUID(), // Placeholder - not used by thumbnail generation
            sessionID: UUID(), // Placeholder - not used by thumbnail generation
            filePath: take.filePath,
            duration: take.durationSeconds,
            fileSize: 0, // Not critical for thumbnails
            cameraPosition: "back",
            sceneNumber: take.sceneNumber,
            takeNumber: takeNumber,
            isSlate: take.takeType.isSlateLike,
            rating: take.rating,
            notes: take.takeNotes,
            createdAt: take.createdAt
        )
    }
    
    @ViewBuilder
    private var takeInfo: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 8) {
                // NEW: Display based on take type
                if take.takeType == .merged {
                    HStack(spacing: 6) {
                        Image(systemName: "film.stack.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                        
                        Text(take.takeType.displayName)
                            .font(Theme.Font.body)
                            .fontWeight(.semibold)
                            .foregroundStyle(.green)
                    }
                } else if take.takeType == .exported {
                    HStack(spacing: 6) {
                        Image(systemName: "square.and.arrow.up.fill")
                            .font(.caption)
                            .foregroundStyle(.blue)
                        
                        Text(take.takeType.displayName)
                            .font(Theme.Font.body)
                            .fontWeight(.medium)
                            .foregroundStyle(.blue)
                    }
                } else if take.takeType.isSlateLike {
                    HStack(spacing: 6) {
                        Image(systemName: "person.crop.rectangle.fill")
                            .font(.caption)
                            .foregroundStyle(.blue)
                        
                        Text("Slate")
                            .font(Theme.Font.body)
                            .foregroundStyle(theme.textPrimary)
                    }
                } else {
                    Text("Take \(takeNumber)")
                        .font(Theme.Font.body)
                        .foregroundStyle(theme.textPrimary)
                }
                
                // NEW: Export status indicator for regular takes (not needed for .exported type since it's already marked as exported)
                if take.takeType == .regular && take.isExported {
                    Image(systemName: "square.and.arrow.up.fill")
                        .font(.caption2)
                        .foregroundStyle(.yellow)
                }
                
                // Status indicators - CLEANED: Use TakeRating directly (only for regular takes)
                if take.takeType == .regular {
                    HStack(spacing: 4) {
                        if effectiveRating == .finalSelect {
                            Image(systemName: "star.fill")
                                .font(.caption)
                                .foregroundStyle(.yellow)
                        }
                        
                        if effectiveRating == .option {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.green)
                        }
                        
                        if effectiveRating == .rejected {
                            Image(systemName: "xmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                }
            }
            
            HStack(spacing: 8) {
                Text(formattedDuration(take.effectiveDurationSeconds))
                    .font(Theme.Font.caption)
                    .foregroundStyle(.secondary)
                
                // NEW: Export status display
                if !take.exportStatusDisplay.isEmpty {
                    Text("• \(take.exportStatusDisplay)")
                        .font(.caption)
                        .foregroundStyle(.gray)
                }
            }
        }
    }
    
    // NEW: Export info view for merged videos
    @ViewBuilder
    private var exportInfo: some View {
        VStack(alignment: .trailing, spacing: 4) {
            if let metadata = take.exportMetadata {
                Text("\(metadata.originalTakeIDs.count) takes")
                    .font(Theme.Font.caption)
                    .foregroundStyle(.green)
                    .fontWeight(.medium)
                
                Text(metadata.exportDate.formatted(date: .omitted, time: .shortened))
                    .font(Theme.Font.caption)
                    .foregroundStyle(.gray)
            } else {
                Text("Merged")
                    .font(Theme.Font.caption)
                    .foregroundStyle(.green)
                    .fontWeight(.medium)
            }
        }
    }
    
    // NEW: Export info view for exported individual files
    @ViewBuilder
    private var exportedTakeInfo: some View {
        VStack(alignment: .trailing, spacing: 4) {
            if let metadata = take.exportMetadata {
                Text(metadata.exportType.displayName)
                    .font(Theme.Font.caption)
                    .foregroundStyle(.blue)
                    .fontWeight(.medium)
                
                Text(metadata.exportDate.formatted(date: .omitted, time: .shortened))
                    .font(Theme.Font.caption)
                    .foregroundStyle(.gray)
            } else {
                Text("Exported")
                    .font(Theme.Font.caption)
                    .foregroundStyle(.blue)
                    .fontWeight(.medium)
            }
        }
    }

    @ViewBuilder
    private var takeActions: some View {
        if !isReadOnly {
            HStack(spacing: 8) {
                // CLEANED: Use TakeRating system directly - no more boolean mess!
                // Only show rating controls for regular takes
                if take.takeType == .regular {
                    Button {
                        onAction(.setRating(.finalSelect))
                    } label: {
                        Image(systemName: effectiveRating == .finalSelect ? "star.fill" : "star")
                            .font(.caption)
                            .foregroundStyle(effectiveRating == .finalSelect ? .yellow : .gray)
                    }
                    Button {
                        onAction(.setRating(.option))
                    } label: {
                        Image(systemName: effectiveRating == .option ? "checkmark.circle.fill" : "checkmark.circle")
                            .font(.caption)
                            .foregroundStyle(effectiveRating == .option ? .green : .gray)
                    }
                    Button {
                        onAction(.setRating(.rejected))
                    } label: {
                        Image(systemName: effectiveRating == .rejected ? "xmark.circle.fill" : "xmark.circle")
                            .font(.caption)
                            .foregroundStyle(effectiveRating == .rejected ? .red : .gray)
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    private func formattedDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Action Enums
enum SessionAction {
    case favorite, duplicate, export, delete, resume, exportAndShare, deleteSession
    
    var debugName: String {
        switch self {
        case .favorite: return "session_favorite"
        case .duplicate: return "session_duplicate"
        case .export: return "session_export"
        case .delete: return "session_delete"
        case .resume: return "session_resume"
        case .exportAndShare: return "session_export_and_share"
        case .deleteSession: return "session_delete_confirm"
        }
    }
}

enum TakeAction {
    case play
    case playOriginal  // ENHANCED: Play original version specifically (not SmartFill)
    case markBest
    case favorite
    case addNote
    case export
    case delete
    // NEW (for all-your-rating-unification)
    case setRating(TakeRating)
    // NEW: Swipe actions for all video rows
    case share
    case deleteTake
    case editSmartFill
    case setSubmitted(ProjectTake)
    
    var debugName: String {
        switch self {
        case .play: return "take_play"
        case .playOriginal: return "take_play_original"
        case .markBest: return "take_mark_best"
        case .favorite: return "take_favorite"
        case .addNote: return "take_add_note"
        case .export: return "take_export"
        case .delete: return "take_delete"
        case .setRating(let rating): return "take_set_rating_\(rating.rawValue)"
        case .share: return "take_share"
        case .deleteTake: return "take_delete_swipe"
        case .editSmartFill: return "take_edit_smartfill"
        case .setSubmitted: return "take_set_submitted"
        }
    }
}

enum SubmittedDeliverableAction {
    case play
    case toggleSubmitted
    case share
    case info
}

private func latestSubmittedDeliverable(for session: ProjectSession) -> ProjectTake? {
    session.takes
        .filter { ($0.takeType == .merged || $0.takeType == .exported) && $0.submittedAt != nil }
        .sorted { ($0.submittedAt ?? .distantPast) > ($1.submittedAt ?? .distantPast) }
        .first
}

private func submittedDeliverables(for session: ProjectSession) -> [ProjectTake] {
    session.takes
        .filter { $0.submittedAt != nil && ($0.takeType == .merged || $0.takeType == .exported) }
        .sorted { ($0.submittedAt ?? $0.createdAt) > ($1.submittedAt ?? $1.createdAt) }
}

// MARK: - Session Navigation Card with Swipe-to-Delete
// MARK: - Session Navigation Card - FIXED: Native SwiftUI swipeActions without NavigationLink
struct SessionNavigationCard: View {
    enum SubmittedViewMode {
        case card
        case list
    }

    let session: ProjectSession
    let ordinalLabel: String
    let checklistProgress: ChecklistProgress
    let checklistContext: String
    let roleName: String?
    let theme: STSTheme
    var isReadOnly: Bool = false
    let onNavigate: () -> Void
    let onDelete: () -> Void
    let onChecklistTap: () -> Void
    let onSubmittedDeliverableAction: (SubmittedDeliverableAction, ProjectTake) -> Void

    @State private var submittedViewMode: SubmittedViewMode = .card
    
    var body: some View {
        if isReadOnly {
            sessionCardContent
                .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        } else {
            sessionCardContent
                .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        onDelete()
                    } label: {
                        Label("Delete", systemImage: "trash.fill")
                    }
                }
        }
    }
    
    @ViewBuilder
    private var sessionCardContent: some View {
        let submittedTakes = submittedDeliverables(for: session)

        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    if let roleName, !roleName.isEmpty {
                        Text("Role: \(roleName)")
                            .font(Theme.Font.headline)
                            .foregroundStyle(theme.primaryAccent)
                    }
                    
                    HStack(spacing: 8) {
                        Image(systemName: sessionTypeIcon(for: session.type))
                            .font(.headline)
                            .foregroundStyle(theme.primaryAccent)
                        
                        Text("\(session.type.rawValue) • \(ordinalLabel)")
                            .font(Theme.Font.headline)
                            .foregroundStyle(theme.textPrimary)
                        
                        if session.isFavorite {
                            Image(systemName: "star.fill")
                                .font(.caption)
                                .foregroundStyle(.yellow)
                        }
                    }
                    
                    Text(session.date.formatted(date: .abbreviated, time: .shortened))
                        .font(Theme.Font.caption)
                        .foregroundStyle(theme.textSecondary)
                    
                    if session.unlockedBadges.contains(.romanPhilosopher) {
                        Label("Prepared to Book It!", systemImage: "laurel.leading")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.yellow)
                    }
                }
                
                Spacer()
            }
            .contentShape(Rectangle())
            .onTapGesture {
                onNavigate()
            }
            
            if submittedTakes.isEmpty {
                SubmittedDeliverablePreviewPlaceholder(theme: theme)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Submitted tapes")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(theme.textPrimary)

                        Spacer()

                        if !submittedTakes.isEmpty {
                            Picker("View", selection: $submittedViewMode) {
                                Text("Card").tag(SubmittedViewMode.card)
                                Text("List").tag(SubmittedViewMode.list)
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 140)
                        }
                    }

                    if submittedViewMode == .card {
                        VStack(spacing: 12) {
                            ForEach(submittedTakes, id: \.id) { take in
                                SubmittedDeliverablePreview(
                                    take: take,
                                    sessionID: session.id,
                                    theme: theme,
                                    style: .card,
                                    onTap: {
                                        onSubmittedDeliverableAction(.play, take)
                                    },
                                    onMenuAction: { action in
                                        onSubmittedDeliverableAction(action, take)
                                    }
                                )
                            }
                        }
                    } else {
                        VStack(spacing: 6) {
                            ForEach(submittedTakes, id: \.id) { take in
                                SubmittedDeliverablePreview(
                                    take: take,
                                    sessionID: session.id,
                                    theme: theme,
                                    style: .list,
                                    onTap: {
                                        onSubmittedDeliverableAction(.play, take)
                                    },
                                    onMenuAction: { action in
                                        onSubmittedDeliverableAction(action, take)
                                    }
                                )
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(cardStroke, lineWidth: 1.25)
                )
        )
    }

    private var brandPrimary: Color {
        Color("BrandPrimaryColor")
    }

    private var cardBackground: AnyShapeStyle {
        if session.type == .selfTape {
            let gradient = LinearGradient(
                colors: [
                    brandPrimary.opacity(0.24),
                    brandPrimary.opacity(0.12)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            return AnyShapeStyle(gradient)
        } else {
            return AnyShapeStyle(theme.cardBackground)
        }
    }

    private var cardStroke: Color {
        if session.type == .selfTape {
            return brandPrimary.opacity(0.55)
        } else {
            return theme.cardStroke
        }
    }
    
    private func sessionTypeIcon(for type: SessionType) -> String {
        switch type {
        case .selfTape:
            return "video.fill"
        case .callback:
            return "arrow.triangle.2.circlepath"
        case .inPerson:
            return "building.2.fill"
        case .chemistryRead:
            return "person.3.fill"
        }
    }
}

struct SubmittedDeliverablePreview: View {
    let take: ProjectTake
    let sessionID: UUID?
    let theme: STSTheme

    enum Style {
        case card
        case list
    }

    let style: Style
    let onTap: (() -> Void)?
    let onMenuAction: ((SubmittedDeliverableAction) -> Void)?

    var body: some View {
        Group {
            switch style {
            case .card:
                cardBody
            case .list:
                listBody
            }
        }
    }

    private var listBody: some View {
        HStack(spacing: 10) {
            listThumbnail
            listInfoStack
            Spacer(minLength: 8)
            menuButton
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.black.opacity(0.2))
        )
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .onTapGesture {
            onTap?()
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var cardBody: some View {
        Button(action: { onTap?() }) {
            VStack(alignment: .leading, spacing: 10) {
                ZStack(alignment: .bottomLeading) {
                    ThumbnailPreviewView(unifiedTake: unifiedTake, quality: .large, frameMode: .intro)
                        .frame(maxWidth: .infinity)
                        .aspectRatio(16.0 / 9.0, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.0),
                            Color.black.opacity(0.7)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .allowsHitTesting(false)

                    HStack(spacing: 8) {
                        if take.takeNumber > 0 {
                            Text("\(take.takeNumber)")
                                .font(Theme.Font.smallCaption.bold())
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.ultraThinMaterial)
                                .clipShape(Capsule())
                        }

                        Text(formattedDurationLocal(take.durationSeconds))
                            .font(Theme.Font.smallCaption.bold())
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                    }
                    .padding(10)
                }

                HStack(alignment: .center, spacing: 8) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Submitted tape")
                            .font(Theme.Font.body.bold())
                            .foregroundStyle(theme.textPrimary)

                        Text(submittedTimestampText(for: take))
                            .font(Theme.Font.smallCaption)
                            .foregroundStyle(theme.textSecondary)
                    }

                    Spacer()

                    Menu {
                        Button("Play") { onMenuAction?(.play) }
                        Button(take.submittedAt == nil ? "Mark as\nSubmitted" : "Mark as\nNot Submitted") {
                            onMenuAction?(.toggleSubmitted)
                        }
                        Button("Share") { onMenuAction?(.share) }
                        Button("Video info") { onMenuAction?(.info) }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 16, weight: .semibold))
                            .padding(8)
                            .background(
                                Circle()
                                    .fill(Color.white.opacity(0.08))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(theme.cardBackground)
            )
        }
        .buttonStyle(.plain)
    }

    private var listThumbnail: some View {
        ZStack {
            ThumbnailPreviewView(unifiedTake: unifiedTake, quality: .small, frameMode: .intro)
            .frame(width: 72, height: 44)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            Image(systemName: "play.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.9))
                .background(
                    Circle()
                        .fill(Color.black.opacity(0.55))
                        .frame(width: 26, height: 26)
                )
        }
    }

    private var listInfoStack: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Submitted tape")
                .font(.caption.weight(.semibold))
                .foregroundStyle(theme.textPrimary)

            Text(formattedDurationLocal(take.durationSeconds))
                .font(.caption2)
                .foregroundStyle(theme.textSecondary)

            if let submittedAt = take.submittedAt {
                Text(submittedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(theme.textSecondary)
            }
        }
    }

    private var menuButton: some View {
        Menu {
            Button {
                onMenuAction?(.play)
            } label: {
                Label("Play", systemImage: "play.fill")
            }

            Button {
                onMenuAction?(.toggleSubmitted)
            } label: {
                Label(
                    take.submittedAt == nil ? "Mark as\nSubmitted" : "Mark as\nNot Submitted",
                    systemImage: "video.fill.badge.checkmark"
                )
            }

            Button {
                onMenuAction?(.share)
            } label: {
                Label("Share", systemImage: "square.and.arrow.up")
            }

            Button {
                onMenuAction?(.info)
            } label: {
                Label("View Video Info", systemImage: "info.circle")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.caption)
                .foregroundStyle(theme.primaryAccent)
        }
    }

    private func formattedDurationLocal(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func submittedTimestampText(for take: ProjectTake) -> String {
        if let submittedAt = take.submittedAt {
            return submittedAt.formatted(date: .abbreviated, time: .shortened)
        }
        return "Not submitted"
    }

    private var unifiedTake: UnifiedTake {
        UnifiedTake(
            id: take.id,
            fileName: URL(fileURLWithPath: take.filePath).lastPathComponent,
            projectID: UUID(),
            sessionID: sessionID ?? UUID(),
            filePath: take.filePath,
            duration: take.durationSeconds,
            fileSize: 0,
            cameraPosition: "back",
            sceneNumber: max(1, take.sceneNumber),
            takeNumber: max(1, take.takeNumber),
            isSlate: false,
            smartFilledFilePath: nil,
            rating: take.rating,
            createdAt: take.createdAt
        )
    }
}

private struct SubmittedDeliverablePreviewPlaceholder: View {
    let theme: STSTheme
    
    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.white.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.white.opacity(0.16), lineWidth: 1)
                    )
                
                Image(systemName: "play.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.9))
            }
            .frame(width: 72, height: 44)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Submitted tape preview")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.textPrimary)
                Text("Choose your final deliverable after export to pin it here.")
                    .font(.caption2)
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(2)
            }
            
            Spacer()
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.03))
        )
    }
}

// NEW: Helper method to get last scene with takes for a specific session
private func getLastSceneWithTakes(for session: ProjectSession) -> Int {
    let sceneNumbers = Set(session.takes.filter { $0.takeType == .regular && $0.sceneNumber > 0 }.map { $0.sceneNumber })
    return sceneNumbers.max() ?? 1
}

private extension ProjectDetailView {
    var profileAvatarImage: Image? {
        guard let preferred = profileManager.profile.preferredHeadshot,
              let url = resolveHeadshotURL(named: preferred.fileName),
              let uiImage = UIImage(contentsOfFile: url.path) else {
            return nil
        }
        return Image(uiImage: uiImage)
    }
    
    func submittedHeadshotThumbnail(for project: Project) -> UIImage? {
        guard let headshotID = project.submittedHeadshotID else {
            return nil
        }
        
        guard let asset = profileManager.profile.headshots.first(where: { $0.id == headshotID }),
              let url = resolveHeadshotURL(named: asset.fileName),
              let image = UIImage(contentsOfFile: url.path) else {
            return nil
        }
        
        return image
    }
}

// MARK: - Project Mission Data Helpers
private extension ProjectDetailView {
    struct SessionStats {
        let sessions: Int
        let takes: Int
        let bestTakes: Int
        let lastSessionDate: Date?
    }
    
    struct ProjectDueInfo {
        let title: String
        let detail: String
        let accent: Color
        let badge: String
    }
    
    func sessionStats(for project: Project) -> SessionStats {
        let sessions = project.sessions.filter { !$0.isArchived }
        let takes = sessions.flatMap { $0.takes }
        let bestTakes = takes.filter { $0.rating == .finalSelect }.count
        let lastDate = sessions.sorted { $0.date > $1.date }.first?.date
        return SessionStats(
            sessions: sessions.count,
            takes: takes.count,
            bestTakes: bestTakes,
            lastSessionDate: lastDate
        )
    }
    
    func dueInfo(for project: Project) -> ProjectDueInfo? {
        guard let due = project.auditionDueDate else { return nil }
        let now = Date()
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        
        let detail = formatter.string(from: due)
        let interval = due.timeIntervalSince(now)
        let hours = interval / 3600
        let days = Int(hours / 24)
        
        if interval <= 0 {
            return ProjectDueInfo(title: "Past Due", detail: detail, accent: .red, badge: "Urgent")
        } else if days < 1 {
            return ProjectDueInfo(title: "Due Today", detail: detail, accent: .orange, badge: "Today")
        } else if days <= 2 {
            return ProjectDueInfo(title: "Due Soon", detail: "In \(days) day\(days == 1 ? "" : "s") • \(detail)", accent: .yellow, badge: "48h")
        } else {
            return ProjectDueInfo(title: "Due In \(days)d", detail: detail, accent: theme.primaryAccent, badge: "\(days)d")
        }
    }
    
    func orderedSessions(for project: Project) -> [ProjectSession] {
        project.sessions
            .filter { !$0.isArchived }
            .sorted { $0.date > $1.date }
    }
    
    private func applyProjectEdits(original: Project, edited: Project) {
        var updated = original
        updated.title = edited.title
        updated.roles = edited.roles
        updated.castingOffice = edited.castingOffice
        updated.castingDirector = edited.castingDirector
        updated.representation = edited.representation
        updated.sceneCount = edited.sceneCount
        updated.auditionDueDate = edited.auditionDueDate
        updated.shootDate = edited.shootDate
        updated.projectType = edited.projectType
        updated.genre = edited.genre
        updated.slateSelections = edited.slateSelections
        updated.breakdownNotes = edited.breakdownNotes
        updated.sidesFileName = edited.sidesFileName
        updated.breakdownFileName = edited.breakdownFileName
        // ✅ Persist submitted headshot selection
        updated.submittedHeadshotID = edited.submittedHeadshotID

        if let editedSession = edited.sessions.first,
           let index = updated.sessions.firstIndex(where: { $0.id == editedSession.id }) {
            var mergedSession = updated.sessions[index]
            mergedSession.sidesFileName = editedSession.sidesFileName
            mergedSession.breakdownFileName = editedSession.breakdownFileName
            mergedSession.breakdownNotes = editedSession.breakdownNotes
            mergedSession.location = editedSession.location
            mergedSession.auditionChecklist = editedSession.auditionChecklist
            mergedSession.slatePrompt = editedSession.slatePrompt
            mergedSession.slatePromptMode = editedSession.slatePromptMode
            mergedSession.slatePromptOverride = editedSession.slatePromptOverride
            mergedSession.slatePromptInputsHash = editedSession.slatePromptInputsHash
            mergedSession.slatePromptUpdatedAt = editedSession.slatePromptUpdatedAt
            mergedSession.lastCustomSlatePrompt = editedSession.lastCustomSlatePrompt
            mergedSession.unlockedBadges = editedSession.unlockedBadges
            updated.sessions[index] = mergedSession
        }
        
        vm.repo.updateProject(updated)
        vm.reload()
        NotificationCenter.default.post(name: Notification.Name("STSProjectsListShouldReload"), object: nil)
    }
    
    func sessionOrdinalLabel(for session: ProjectSession, in project: Project) -> String {
        let sessionsOfType = project.sessions
            .filter { $0.type == session.type && !$0.isArchived }
            .sorted { $0.date < $1.date }
        guard let index = sessionsOfType.firstIndex(where: { $0.id == session.id }) else {
            return session.type.rawValue
        }
        let ordinal = ordinalString(index + 1)
        switch session.type {
        case .selfTape:
            return "\(ordinal) Session"
        case .callback:
            return "\(ordinal) Callback"
        case .inPerson:
            return "\(ordinal) In-Person"
        case .chemistryRead:
            return "\(ordinal) Chemistry Read"
        }
    }
    
    func ordinalString(_ number: Int) -> String {
        let suffix: String
        let tens = number % 100
        let ones = number % 10
        if tens - ones == 10 {
            suffix = "th"
        } else {
            switch ones {
            case 1: suffix = "st"
            case 2: suffix = "nd"
            case 3: suffix = "rd"
            default: suffix = "th"
            }
        }
        return "\(number)\(suffix)"
    }
    
}

// MARK: - Project Mission Brief View
private struct ProjectMissionBriefView: View {
    let project: Project
    let sessionStats: ProjectDetailView.SessionStats
    let dueInfo: ProjectDetailView.ProjectDueInfo?
    let theme: STSTheme
    let submittedHeadshot: UIImage?
    let isReadOnly: Bool
    let onEdit: () -> Void
    let onArchive: () -> Void
    let onDelete: () -> Void
    
    @State private var isCardCollapsed = true
    
    var body: some View {
        STSCard {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.black.opacity(0.8),
                                theme.primaryAccent.opacity(0.35)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.white.opacity(0.18), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.35), radius: 12, x: 0, y: 10)
                
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .top, spacing: 16) {
                        VStack(alignment: .leading, spacing: 10) {
                            header
                            infoRows
                        }
                        
                        Spacer(minLength: 0)
                        
                        SubmittedHeadshotPreview(
                            image: submittedHeadshot,
                            theme: theme
                        )
                    }
                    
                    if !isCardCollapsed {
                        datesRow
                            .padding(.top, 4)
                        Divider().background(Color.white.opacity(0.12))
                        metricRow
                        wizardDetails
                    }
                    
                    actionRow
                }
                .padding(16)
            }
        }
    }
    
    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(project.title)
                .font(Theme.Font.title)
                .foregroundStyle(theme.textPrimary)
            
            if let roleName = project.roles.first?.name, !roleName.isEmpty {
                Text(roleName)
                    .font(Theme.Font.headline)
                    .foregroundStyle(theme.primaryAccent)
            }
        }
    }
    
    private var infoRows: some View {
        VStack(alignment: .leading, spacing: 6) {
            MissionInfoRow(
                icon: "film.fill",
                title: "Project Type",
                value: project.projectType,
                accent: theme.primaryAccent
            )
            
            if !project.genre.isEmpty {
                MissionInfoRow(
                    icon: "wand.and.stars",
                    title: "Genre",
                    value: project.genre,
                    accent: .purple
                )
            }
            
            if let representation = heroRepresentationValue {
                MissionInfoRow(
                    icon: "person.badge.shield.checkmark",
                    title: "Representation",
                    value: representation,
                    accent: theme.primaryAccent
                )
            }
        }
    }

    private var heroRepresentationValue: String? {
        var components: [String] = []
        
        func appendIfNeeded(_ raw: String?) {
            guard let raw,
                  let trimmed = raw.slateTrimmedNonEmpty,
                  !components.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) else { return }
            components.append(trimmed)
        }
        
        appendIfNeeded(project.representation?.name)
        
        if let summary = project.slateSelections.representation?.slateTrimmedNonEmpty {
            let commaTokens = summary
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            
            for token in commaTokens {
                if token.isEmpty { continue }
                if let colonIndex = token.firstIndex(of: ":") {
                    let afterColon = token[token.index(after: colonIndex)...].trimmingCharacters(in: .whitespacesAndNewlines)
                    appendIfNeeded(afterColon.isEmpty ? token : afterColon)
                } else {
                    appendIfNeeded(token)
                }
            }
        }
        
        return components.isEmpty ? nil : components.joined(separator: ", ")
    }
    
    private var datesRow: some View {
        HStack(spacing: 12) {
            if let dueInfo {
                DateTile(title: dueInfo.title, subtitle: dueInfo.detail, badge: dueInfo.badge, accent: dueInfo.accent, theme: theme)
            }
            if let shootText = formattedShootDate {
                DateTile(title: "Shoot Date", subtitle: shootText, badge: "On Set", accent: theme.primaryAccent, theme: theme)
            }
            if dueInfo == nil && formattedShootDate == nil {
                DateTile(title: "Scene Plan", subtitle: "\(project.sceneCount) scene\(project.sceneCount == 1 ? "" : "s")", badge: "Wizard", accent: theme.primaryAccent, theme: theme)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var metricRow: some View {
        HStack(spacing: 12) {
            MetricTile(title: "Scenes Planned", value: "\(project.sceneCount)", icon: "list.number")
            MetricTile(title: "Sessions Logged", value: "\(sessionStats.sessions)", icon: "person.2.fill")
            MetricTile(title: "Takes Captured", value: "\(sessionStats.takes)", icon: "video.fill")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var wizardDetails: some View {
        VStack(spacing: 10) {
            DetailRow(icon: "person.text.rectangle", title: "Casting Director", value: project.castingDirector?.name)
            DetailRow(icon: "building.2.crop.circle", title: "Casting Office", value: project.castingOffice)
            DetailRow(icon: "mappin.and.ellipse", title: "Local Hire Market", value: project.slateSelections.localHireMarket)
            DetailRow(icon: "shield.checkerboard", title: "Union Status", value: project.slateSelections.unionStatus)
            DetailRow(icon: "phone.bubble.left", title: "Contact Line", value: project.slateSelections.contact)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var actionRow: some View {
        HStack(spacing: 14) {
            HStack(spacing: 10) {
                missionActionButton(
                    icon: "archivebox.fill",
                    background: Color.blue.opacity(0.18),
                    accessibilityLabel: "Archive Project",
                    action: onArchive
                )
                missionActionButton(
                    icon: "trash.fill",
                    background: Color.red.opacity(0.2),
                    accessibilityLabel: "Delete Project",
                    action: onDelete
                )
            }
            .disabled(isReadOnly)
            
            Spacer()
            
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    isCardCollapsed.toggle()
                }
            } label: {
                Image(systemName: isCardCollapsed ? "chevron.down" : "chevron.up")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(10)
                    .background(
                        Circle()
                            .fill(Color.white.opacity(0.08))
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
                            )
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isCardCollapsed ? "Expand project mission brief" : "Collapse project mission brief")
        }
        .overlay(alignment: .leading) {
            if isReadOnly {
                Text("Restore to edit, archive, or delete.")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.leading, 2)
                    .padding(.top, 4)
            }
        }
    }
    
    private func missionActionButton(
        icon: String,
        background: Color,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(
                    Circle()
                        .fill(background)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
    
    private struct MissionInfoRow: View {
        let icon: String
        let title: String
        let value: String
        let accent: Color
        
        var body: some View {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(accent)
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                .foregroundStyle(accent.opacity(0.9))
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
        }
    }
    
    private struct MetricTile: View {
        let title: String
        let value: String
        let icon: String
        var body: some View {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.8))
                Text(value)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.65))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
            )
        }
    }

private struct SubmittedHeadshotPreview: View {
    let image: UIImage?
    let theme: STSTheme
    
    private let size = CGSize(width: 110, height: 140)
    
    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(0.04))
                
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(systemName: "person.crop.square")
                        .resizable()
                        .scaledToFit()
                        .padding(20)
                        .foregroundStyle(Color.white.opacity(0.7))
                }
            }
            .frame(width: size.width, height: size.height)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            
            Text("Submitted headshot")
                .font(.caption2)
                .foregroundStyle(theme.textSecondary)
        }
    }
}

    private struct DateTile: View {
        let title: String
        let subtitle: String
        let badge: String
        let accent: Color
        let theme: STSTheme
        
        var body: some View {
            VStack(alignment: .leading, spacing: 4) {
                Text(badge.uppercased())
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(accent.opacity(0.2), in: Capsule())
                    .foregroundStyle(accent)
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(theme.textPrimary)
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(theme.textSecondary)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(theme.cardBackground.opacity(0.8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(theme.cardStroke, lineWidth: 1)
                    )
            )
        }
    }
    
    private struct DetailRow: View {
        let icon: String
        let title: String
        let value: String?
        var body: some View {
            if let text = value?.slateTrimmedNonEmpty, !text.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: icon)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.75))
                    Text(title.uppercased())
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.6))
                    Text(text)
                        .font(.system(size: 13))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
    
    private var formattedShootDate: String? {
        guard let shoot = project.shootDate else { return nil }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: shoot)
    }
    
    private var representationText: String? {
        guard let rep = project.representation else {
            return project.slateSelections.representation
        }
        var pieces: [String] = [rep.name]
        if let email = rep.email?.slateTrimmedNonEmpty {
            pieces.append(email)
        }
        if let phone = rep.phone?.slateTrimmedNonEmpty {
            pieces.append(phone)
        }
        return pieces.joined(separator: " • ")
    }
}
