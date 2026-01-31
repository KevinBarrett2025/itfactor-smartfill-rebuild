import SwiftUI
import UIKit
import PhotosUI
import UniformTypeIdentifiers
import AVFoundation
import Foundation

@MainActor

// MARK: - TakeReviewPage (Deliverables tab hidden, list stays)
struct TakeReviewPage: View {
    // MARK: - Input/Callbacks
    @State private var currentSession: ProjectSession
    @State private var currentProject: Project
    let isReadOnly: Bool
    let repository: ProjectsRepository
    let onClose: (() -> Void)?
    let onSessionAction: (SessionAction) -> Void
    let onTakeAction: (TakeAction, ProjectTake) -> Void
    let onVideoPlayerRequest: ([ProjectTake], Int, ViewType, Int?, Bool) -> Void
    let onExitProcessingReady: (() -> Void)?

    // MARK: - Local UI State
    @Environment(\.dismiss) private var dismiss
        @EnvironmentObject private var navCtx: NavigationContextManager
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var exportManagerData: ExportManagerData?
    @State private var showingDeleteConfirmation = false
    @State private var takeToDelete: ProjectTake?
    struct ShareSheetPayload: Identifiable {
        let id = UUID()
        let items: [Any]
    }
    @State private var shareSheetPayload: ShareSheetPayload?
    @State private var showUploadSourceSheet = false
    @State private var selectedViewType: ViewType = .scenes
    @State private var selectedSceneNumber: Int = 1
    @State private var selectedSlateFilter: SlateFilter = .standard
    @State private var slateFilterManuallyChosenThisVisit: Bool = false
    @State private var ratingFilterSelections: Set<TakeRatingFilter> = []
    private let hasPreservedState: Bool
    @State private var isExporting = false
    @State private var showingBottomButtons = true
    @State private var isSubmitted = false
    @State private var profileManager = ActorProfileManager()
    @State private var showingActorKit = false
    @State private var showPhotoPicker = false
    @State private var pendingDocumentUpload: DocumentUploadKind? = nil
    @State private var photoPickerItems: [PhotosPickerItem] = []
    @State private var importErrorMessage: String?
    @State private var showImportErrorAlert = false
    @State private var breakdownNotesDraft: String = ""
    @State private var isEditingBreakdownNotes = false
    @State private var documentViewerPayload: DocumentViewerPayload?
    @State private var isBreakdownExpanded = false
    // NEW: Expand/collapse Deliverables inside header card
    @State private var isDeliverablesExpanded = true
    // NEW: Submission + info alerts for deliverables
    @State private var pendingSubmissionTake: ProjectTake?
    @State private var pendingSubmissionTargetState: Bool = false
    @State private var showingSubmissionAlert = false

    @State private var infoAlertTake: ProjectTake?
    @State private var infoAlertMessage: String = ""
    @State private var showingInfoAlert = false
    @State private var pendingVideoUploadContext: VideoUploadContext?
    @State private var showKeyframeUploadSourceSheet = false
    @State private var showKeyframePhotoPicker = false
    @State private var pendingKeyframePhotoUploadContext: KeyframePhotoUploadContext?
    @State private var keyframePhotoPickerItems: [PhotosPickerItem] = []
    @State private var videoImportErrorMessage: String?
    @State private var showVideoImportErrorAlert = false
    @State private var isUploadingVideo = false
    @StateObject private var importStore = ImportStore.shared
    @State private var showFilesImporter = false
    @State private var pendingFileImporter: PendingFileImporter? = nil
    @State private var didLoadDisclosurePrefs = false
    @State private var didLoadRatingFilterPrefs = false
    @State private var showInlinePIPEditor = true
    @State private var pendingPhotoShare: ProjectTake?
    @State private var showingPhotoShareOptions = false
    @State private var shareConversionInProgress = false
    @State private var shareConversionError: String?
    @State private var inlinePIPSaveTrigger = 0
    @State private var showingChecklist = false
    @State private var showingEditWizard = false
    @State private var wizardStartStep: Int = 1
    @State private var wizardInitialScrollTarget: NewProjectWizard.InitialScrollTarget? = nil
    @State private var showingSelfTapeGear = false
    @State private var safeBottomInset: CGFloat = 34
    @State private var reloadDebounceWorkItem: DispatchWorkItem?
    @State private var didSignalExitProcessingReady = false
    @State private var didHideProcessingOverlay = false
    @State private var showArchivedAlert = false
    @State private var showNoDocumentsDialog = false
    private var theme: STSTheme { themeManager.current }
    private var takePrimaryText: Color { theme.id == .takeReviewClassic ? .black : theme.textPrimary }
    private var takeSecondaryText: Color { theme.id == .takeReviewClassic ? Color.black.opacity(0.7) : theme.textSecondary }
    private var takeChipBackground: Color { theme.id == .takeReviewClassic ? Color(white: 0.93) : Color.white.opacity(0.05) }
    private var takeChipStroke: Color { theme.id == .takeReviewClassic ? Color(white: 0.8) : Color.white.opacity(0.08) }
    private var takeOverlayFill: Color { theme.id == .takeReviewClassic ? Color(white: 0.95) : Color.white.opacity(0.08) }
    private var takeOverlayStroke: Color { theme.id == .takeReviewClassic ? Color(white: 0.8) : Color.white.opacity(0.12) }
    private var hasAnySidesOrDocs: Bool {
        hasDocument(for: .sides) || hasDocument(for: .breakdown)
    }
    private let reloadQueue = DispatchQueue(label: "com.selftapestudio.takereview.reload", qos: .userInitiated)
    private final class RepositorySendableBox: @unchecked Sendable {
        let repository: ProjectsRepository
        init(_ repository: ProjectsRepository) {
            self.repository = repository
        }
    }
    
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
    
    // MARK: - Public init (so we can seed @State)
    init(
        session: ProjectSession,
        project: Project,
        repository: ProjectsRepository,
        initialViewType: ViewType? = nil,
        initialSceneNumber: Int? = nil,
        onSessionAction: @escaping (SessionAction) -> Void,
        onTakeAction: @escaping (TakeAction, ProjectTake) -> Void,
        onVideoPlayerRequest: @escaping ([ProjectTake], Int, ViewType, Int?, Bool) -> Void,
        onClose: (() -> Void)? = nil,
        onExitProcessingReady: (() -> Void)? = nil,
        isReadOnly: Bool = false
    ) {
        self._currentSession = State(initialValue: session)
        self._currentProject = State(initialValue: project)
        self.isReadOnly = isReadOnly
        self.repository = repository
        self.onClose = onClose
        self.onExitProcessingReady = onExitProcessingReady
        self.onSessionAction = onSessionAction
        self.onTakeAction = onTakeAction
        self.onVideoPlayerRequest = onVideoPlayerRequest
        let vt = initialViewType ?? .scenes
        let scn = initialSceneNumber ?? 1
        self._selectedViewType = State(initialValue: vt)
        self._selectedSceneNumber = State(initialValue: scn)
        self.hasPreservedState = (initialViewType != nil || initialSceneNumber != nil)
        let initialNotes = session.breakdownNotes ?? project.breakdownNotes ?? ""
        self._breakdownNotesDraft = State(initialValue: initialNotes)
        let hasNotes = (session.breakdownNotes?.slateTrimmedNonEmpty ?? project.breakdownNotes?.slateTrimmedNonEmpty) != nil
        self._isEditingBreakdownNotes = State(initialValue: !hasNotes)
        print("🎬 TakeReviewPage init project=\(project.id) session=\(session.id) type=\(session.type.rawValue) takes=\(session.takes.count)")
    }

    // MARK: - ViewType (deliverables kept for context, hidden from tabs)
    enum ViewType: CaseIterable {
        case scenes, slates, keyframes, deliverables
        
        var displayName: String {
            switch self {
            case .scenes: return "Scenes"
            case .slates: return "Slates"
            case .keyframes: return "Photos"
            case .deliverables: return "Deliverables"
            }
        }
        var icon: String {
            switch self {
            case .scenes: return "video.fill"
            case .slates: return "tv"
            case .keyframes: return "camera"
            case .deliverables: return "doc.badge.plus"
            }
        }
        var debugName: String {
            switch self {
            case .scenes: return "scenes"
            case .slates: return "slates"
            case .keyframes: return "keyframes"
            case .deliverables: return "deliverables"
            }
                }
        static var allCases: [ViewType] { return [.scenes, .slates, .keyframes] }
    }
    
    enum DocumentUploadKind {
        case sides
        case breakdown
    }

    enum VideoUploadContext: Equatable {
        case scene(Int)
        case slate(sceneNumber: Int, slateNumber: String?, slateID: String?)
        
        var sceneNumber: Int {
            switch self {
            case .scene(let number): return number
            case .slate(let scene, _, _): return scene
            }
        }
        
        var slateNumber: String? {
            if case .slate(_, let number, _) = self { return number }
            return nil
        }
        
        var slateID: String? {
            if case .slate(_, _, let slateID) = self { return slateID }
            return nil
        }
        
        var isSlate: Bool {
            if case .slate = self { return true }
            return false
        }
        
        var buttonTitle: String {
            switch self {
            case .scene(let number):
                return "Import Scene \(number) Video"
            case .slate(_, let slateNumber, let slateID):
                if let slateID {
                    return "Import \(slateID) Video"
                } else if let slateNumber {
                    return "Import Slate \(slateNumber) Video"
                } else {
                    return "Import Slate Video"
                }
            }
        }
        
        var subtitle: String {
            switch self {
            case .scene(let number):
                return "Adds to Scene \(number)"
            case .slate(_, let slateNumber, let slateID):
                if let slateID {
                    return slateID
                } else if let slateNumber {
                    return "Slate \(slateNumber)"
                } else {
                    return "New Slate"
                }
            }
        }
        
        var iconName: String {
            isSlate ? "movieclapper" : "film.stack"
        }
    }

    private enum KeyframePhotoUploadContext {
        case scene(Int)

        var sceneNumber: Int {
            switch self {
            case .scene(let number):
                return max(1, number)
            }
        }
    }

    private enum PendingFileImporter: Equatable {
        case filesVideo
        case filesKeyframePhoto
        case document
    }

    enum SlateFilter: String, CaseIterable {
        case pip
        case smartFill
        case standard
    }
    
    struct DocumentViewerPayload: Identifiable {
        let id = UUID()
        let documents: [CombinedDocumentView.DocumentReference]
        let initialIndex: Int
    }
    
    // MARK: - Body
    var body: some View {
        GeometryReader { geo in
            modalWrappedNavigation
                .fileImporter(
                    isPresented: $showFilesImporter,
                    allowedContentTypes: filesImporterAllowedTypes,
                    allowsMultipleSelection: filesImporterAllowsMultiple
                ) { result in
                    handleFilesImporterResult(result)
                }
                .onChange(of: showUploadSourceSheet) { _, isPresented in
                    guard !isPresented, pendingFileImporter == .filesVideo else { return }
                    ImportLog.files.info("Presenting fileImporter after dialog fully dismissed (video)")
                    showFilesImporter = true
                }
                .onChange(of: showKeyframeUploadSourceSheet) { _, isPresented in
                    guard !isPresented, pendingFileImporter == .filesKeyframePhoto else { return }
                    ImportLog.files.info("Presenting fileImporter after dialog fully dismissed (keyframe)")
                    showFilesImporter = true
                }
                .onAppear {
                    DispatchQueue.main.async {
                        safeBottomInset = max(geo.safeAreaInsets.bottom, 0)
                        // Do NOT hide the processing overlay here.
                        // We hide it when TakeReview has actually loaded & applied data.
                    }
                }
                .task(id: disclosurePrefsKey) {
                    loadDisclosurePrefs()
                }
                .task(id: ratingFilterPrefsKey) {
                    loadRatingFilterPrefs()
                }
                .onChange(of: isBreakdownExpanded) { _, isExpanded in
                    guard didLoadDisclosurePrefs else { return }
                    persistDisclosurePrefs(
                        breakdownExpanded: isExpanded,
                        deliverablesExpanded: isDeliverablesExpanded,
                        pipEditorExpanded: showInlinePIPEditor
                    )
                }
                .onChange(of: isDeliverablesExpanded) { _, isExpanded in
                    guard didLoadDisclosurePrefs else { return }
                    persistDisclosurePrefs(
                        breakdownExpanded: isBreakdownExpanded,
                        deliverablesExpanded: isExpanded,
                        pipEditorExpanded: showInlinePIPEditor
                    )
                }
                .onChange(of: showInlinePIPEditor) { _, isExpanded in
                    guard didLoadDisclosurePrefs else { return }
                    persistDisclosurePrefs(
                        breakdownExpanded: isBreakdownExpanded,
                        deliverablesExpanded: isDeliverablesExpanded,
                        pipEditorExpanded: isExpanded
                    )
                }
                .onChange(of: ratingFilterSelections) { _, newValue in
                    guard didLoadRatingFilterPrefs else { return }
                    persistRatingFilterPrefs(newValue)
                }
                .ratingEducationToastHost()
        }
        .stsSupportedOrientations(.all, label: "TakeReviewPage")
    }
    
    private var modalWrappedNavigation: some View {
        attachModals(to: navigationScaffold)
    }
    
    private var navigationScaffold: some View {
        NavigationStack {
            pageContent
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        VStack(spacing: 0) {
                            Text("\(currentSession.type.rawValue) Session")
                                .font(.headline)
                            Text("Created on \(createdOnToolbarText)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(action: dismissPage) {
                            Image(systemName: "xmark")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(theme.textPrimary)
                        }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        ActorKitAvatarButton(image: profileAvatarImage) {
                            showingActorKit = true
                        }
                    }
                }
        }
        .onAppear {
#if DEBUG
            print("🧭 TakeReviewPage.onAppear project=\(currentProject.id) session=\(currentSession.id) takes=\(currentSession.takes.count)")
#endif
            ensurePIPSlateSessionLoaded()
            if selectedViewType == .slates {
                autoMutePIPPreview()
            }
            if selectedViewType == .keyframes {
                SessionManager.shared.ensureSingleFinalSelectKeyframePhoto(
                    sessionID: currentSession.id,
                    projectID: currentProject.id
                )
            }
        }
        .onDisappear {
#if DEBUG
            print("🧭 TakeReviewPage.onDisappear project=\(currentProject.id) session=\(currentSession.id)")
#endif
        }
        .confirmationDialog(
            "Share Keyframe Photo",
            isPresented: $showingPhotoShareOptions,
            presenting: pendingPhotoShare
        ) { take in
            Button("Share Photo") {
                sharePhotoDirectly(take)
            }
            Button("Share as 1-Second Video") {
                sharePhotoAsVideo(take)
            }
            Button("Cancel", role: .cancel) {
                pendingPhotoShare = nil
            }
        } message: { _ in
            Text("Choose how you'd like to share this keyframe photo.")
        }
        .alert(
            "Conversion Failed",
            isPresented: Binding(
                get: { shareConversionError != nil },
                set: { _ in shareConversionError = nil }
            )
        ) {
            Button("OK", role: .cancel) { shareConversionError = nil }
        } message: {
            Text(shareConversionError ?? "")
        }
    }

    @ViewBuilder
    private var pageContent: some View {
        ZStack {
            theme.backgroundGradient.ignoresSafeArea()
            accentGlow
            VStack(spacing: 0) {
                ScrollView {
                    LazyVStack(spacing: Theme.Layout.cardSpacing) {
                        sessionInfoHeader
                        ImportStatusIndicator(sessionID: currentSession.id)

                        if hasAnyTakes {
                            SmartFillStatusIndicator(sessionID: currentSession.id)
                            horizontalTabs
                            ratingFilterSection
                            
                            if selectedViewType == .scenes {
                                sceneBasedTakeSection
                            } else if selectedViewType == .slates {
                                slateUploadSections
                                
                                if selectedSlateFilter == .pip {
                                    pipSlateEditorEntry
                                }
                            } else if selectedViewType == .keyframes {
                                let pendingImports = pendingKeyframeImportJobs
                                if !keyframeTakes.isEmpty || !pendingImports.isEmpty {
                                    STSCard(elevation: .elevated) {
                                        VStack(alignment: .leading, spacing: Theme.Layout.compactPadding) {
                                            HStack {
                                                Text("Keyframe Photos")
                                                    .font(.headline)
                                                    .foregroundStyle(theme.textPrimary)

                                                Spacer()

                                                Button {
                                                    beginKeyframePhotoUpload(forScene: selectedSceneNumber)
                                                } label: {
                                                    HStack(spacing: 4) {
                                                        Image(systemName: "photo.badge.plus")
                                                            .font(.caption.weight(.semibold))
                                                        Text("Import Photo")
                                                            .font(.caption.weight(.semibold))
                                                    }
                                                    .padding(.horizontal, 10)
                                                    .padding(.vertical, 6)
                                                    .background(
                                                        RoundedRectangle(cornerRadius: 6)
                                                            .fill(Color.orange.opacity(0.15))
                                                    )
                                                    .foregroundStyle(.orange)
                                                }
                                                .buttonStyle(.plain)
                                            }

                                            takeSection(
                                                title: "Keyframe Photos",
                                                takes: keyframeTakes,
                                                icon: "camera",
                                                color: .orange,
                                                pendingImports: pendingImports
                                            )
                                        }
                                    }
                                } else if hasActiveRatingFilter && !unfilteredKeyframeTakes.isEmpty {
                                    filterEmptyStateCard
                                }
                            }
                        } else {
                            emptySessionState
                        }
                        
                        Color.clear.frame(height: calculateBottomContentPadding())
                    }
                    .padding(.horizontal, Theme.Layout.screenPadding)
                    .padding(.top, Theme.Layout.screenPadding)
                    .background(
                        FirstLayoutProbe {
                            hideExitProcessingOverlayIfNeeded(source: "takeReview.firstLayout")
                        }
                    )
                }
                
                if showingBottomButtons {
                    enterpriseBottomActionBar
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .onChange(of: selectedViewType, initial: false) { oldValue, newValue in
            if newValue == .slates && oldValue != .slates {
                slateFilterManuallyChosenThisVisit = false
            }
            if newValue == .slates || oldValue == .slates {
                autoMutePIPPreview()
            }
            if newValue == .keyframes {
                SessionManager.shared.ensureSingleFinalSelectKeyframePhoto(
                    sessionID: currentSession.id,
                    projectID: currentProject.id
                )
            }
        }
        .onChange(of: importStore.lastCompletion) { _, completion in
            guard let completion,
                  completion.sessionID == currentSession.id,
                  completion.projectID == currentProject.id
            else { return }
            if !applyImportCompletion(completion) {
                reloadSessionData()
            }
        }
        .overlay {
            if shareConversionInProgress {
                ZStack {
                    Color.black.opacity(0.35).ignoresSafeArea()
                    ProgressView("Preparing video…")
                        .padding()
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
        }
    }

    // MARK: - Modal / overlay stack
    private func attachModals(to base: some View) -> some View {
        var view: AnyView = AnyView(base)
        
        view = AnyView(view.sheet(item: $exportManagerData, onDismiss: {
            exportManagerData = nil
            reloadSessionData()
        }) { data in
            ExportManagerView(
                takes: data.takes,
                project: data.project,
                session: data.session,
                repository: data.repository,
                onDismiss: {
                    exportManagerData = nil
                    reloadSessionData()
                }
            )
        })
        
        view = AnyView(view.sheet(item: $shareSheetPayload) { payload in
            ActivityViewController(activityItems: payload.items)
        })
        
        view = AnyView(view.sheet(item: $documentViewerPayload, onDismiss: {
            documentViewerPayload = nil
        }) { payload in
            CombinedDocumentView(documents: payload.documents, initialSelectedIndex: payload.initialIndex) { docType in
                handleAddDocumentRequest(fromViewer: docType)
            }
        })

        view = AnyView(view.sheet(isPresented: $showingChecklist) {
            ActorMustKnowsView(
                project: currentProject,
                session: currentSession,
                repository: repository,
                onComplete: {
                    showingChecklist = false
                    reloadSessionData()
                },
                onNavigateToWizard: { item in
                    showingChecklist = false
                    switch item {
                    case .characterBreakdown:
                        wizardStartStep = 2
                    case .slateEssentials:
                        wizardStartStep = 3
                    case .submissionWindow:
                        wizardStartStep = 1
                    case .frameAndLight:
                        showingSelfTapeGear = true
                        return
                    default:
                        wizardStartStep = 1
                    }
                    showingEditWizard = true
                },
                onCompletionStatus: { _ in
                    showingChecklist = false
                    reloadSessionData()
                }
            )
        })
        
        view = AnyView(view.sheet(isPresented: $showingSelfTapeGear) {
            EquipmentGuideView()
        })

        view = AnyView(view.sheet(isPresented: $showingEditWizard) {
            NavigationStack {
                NewProjectWizard(
                    existingProject: currentProject,
                    repo: repository,
                    startStep: wizardStartStep,
                    initialScrollTarget: wizardInitialScrollTarget,
                    onSave: { editedProject in
                        repository.updateProject(editedProject)
                        reloadSessionData()
                    },
                    onRecordingComplete: nil,
                    showsSaveInsteadOfCancel: true
                )
                .onAppear {
                    // One-shot scroll target so repeat opens don't auto-scroll.
                    wizardInitialScrollTarget = nil
                }
            }
            .interactiveDismissDisabled(true)
        })

        view = AnyView(
            view
                .photosPicker(
                    isPresented: $showPhotoPicker,
                    selection: $photoPickerItems,
                    matching: .videos
                )
                .onChange(of: photoPickerItems) { _, newItems in
                    handlePhotoPickerSelection(newItems)
                }
                .confirmationDialog("Import Video", isPresented: $showUploadSourceSheet, titleVisibility: .visible) {
                    Button("Choose from Photos") {
                        showPhotoPicker = true
                    }
                    Button("Choose from Files") {
                        ImportLog.files.info("Choose from Files tapped (video)")
                        pendingFileImporter = .filesVideo
                        showUploadSourceSheet = false
                    }
                    Button("Cancel", role: .cancel) {
                        pendingVideoUploadContext = nil
                    }
                } message: {
                    if selectedViewType == .slates && selectedSlateFilter == .pip {
                        Text("""
Imported videos are added to Original slates.

Import a portrait video, to be used with SmartFill.

*Picture-in-Picture slates must be recorded in the iTFactor camera so the close-up and full-body videos stay perfectly synced.*
""")
                    } else {
                        Text("Choose a video to import into this project.")
                    }
                }
        )

        view = AnyView(
            view
                .photosPicker(
                    isPresented: $showKeyframePhotoPicker,
                    selection: $keyframePhotoPickerItems,
                    matching: .images
                )
                .onChange(of: keyframePhotoPickerItems, initial: false) { _, items in
                    handleKeyframePhotoPickerSelection(items)
                }
        )

        view = AnyView(
            view
                .confirmationDialog(
                    "Import Keyframe Photo",
                    isPresented: $showKeyframeUploadSourceSheet,
                    titleVisibility: .visible
                ) {
                    Button("Choose from Photos") {
                        showKeyframePhotoPicker = true
                    }
                    Button("Choose from Files") {
                        ImportLog.files.info("Choose from Files tapped (keyframe)")
                        pendingFileImporter = .filesKeyframePhoto
                        showKeyframeUploadSourceSheet = false
                    }
                    Button("Cancel", role: .cancel) {
                        pendingKeyframePhotoUploadContext = nil
                    }
                }
        )
        
        view = AnyView(view.alert("Import Failed", isPresented: $showImportErrorAlert) {
            Button("OK", role: .cancel) {
                importErrorMessage = nil
            }
        } message: {
            Text(importErrorMessage ?? "Unable to import the selected document.")
        })
        
        view = AnyView(view.alert("Import Failed", isPresented: $showVideoImportErrorAlert) {
            Button("OK", role: .cancel) {
                videoImportErrorMessage = nil
            }
        } message: {
            Text(videoImportErrorMessage ?? "Unable to import the selected video.")
        })
        
        view = AnyView(view.fullScreenCover(isPresented: $showingActorKit) {
            ActorKitView(profileManager: profileManager, projectsRepository: repository)
                .onDisappear {
                    profileManager = ActorProfileManager()
                }
        })
        
        view = AnyView(view.alert("Delete Take", isPresented: $showingDeleteConfirmation, presenting: takeToDelete) { take in
            Button("Delete", role: .destructive) { handleDeleteConfirmed(take) }
            Button("Cancel", role: .cancel) { takeToDelete = nil }
        } message: { _ in
            Text("Are you sure you want to permanently delete this take? This action cannot be undone.")
        })

        // NEW: Deliverable submission confirmation
        view = AnyView(view.alert(
            pendingSubmissionTargetState ? "Mark as Submitted" : "Mark as Not Submitted",
            isPresented: $showingSubmissionAlert,
            presenting: pendingSubmissionTake
        ) { take in
            Button(pendingSubmissionTargetState ? "Submit Tape" : "Mark Not Submitted", role: .destructive) {
                handleDeliverableSubmissionToggle(for: take, isSubmitted: pendingSubmissionTargetState)
                pendingSubmissionTake = nil
            }
            Button("Cancel", role: .cancel) {
                pendingSubmissionTake = nil
            }
        } message: { _ in
            if pendingSubmissionTargetState {
                Text("Did you send the Self-Tape to your Reps or Casting? Mark this final tape as submitted to pin it in your Project Lobby and stop audition reminders for this session.")
            } else {
                Text("Mark this tape as not submitted if you want to change your final tape or keep working on this audition.")
            }
        })

        // NEW: Lightweight video info alert for deliverables
        view = AnyView(view.alert("Video Info", isPresented: $showingInfoAlert) {
            Button("OK", role: .cancel) {
                infoAlertTake = nil
                infoAlertMessage = ""
            }
        } message: {
            Text(infoAlertMessage)
        })

        view = AnyView(view.alert("Project is archived", isPresented: $showArchivedAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("This project is archived. Restore it to record or edit.")
        })
        
        view = AnyView(view.onReceive(NotificationCenter.default.publisher(for: Notification.Name("STSExportCompleted"))) { n in
            if let sid = n.userInfo?["sessionID"] as? UUID, sid == currentSession.id {
                scheduleSessionReload()
            }
        })
        
        view = AnyView(view.onReceive(NotificationCenter.default.publisher(for: Notification.Name("STSSmartFillCompleted"))) { n in
            if let sid = n.userInfo?["sessionID"] as? UUID, sid == currentSession.id {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    if let takeID = n.userInfo?["takeID"] as? UUID {
                        ProjectTake.invalidateSmartFillCache(for: takeID)
                    }
                    scheduleSessionReload()
                }
            }
        })
        
        view = AnyView(view.onReceive(NotificationCenter.default.publisher(for: Notification.Name("SmartFillProcessingDidComplete"))) { n in
            if let sid = n.userInfo?["sessionID"] as? UUID, sid == currentSession.id {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    if let takeID = n.userInfo?["takeID"] as? UUID {
                        ProjectTake.invalidateSmartFillCache(for: takeID)
                    }
                    scheduleSessionReload()
                }
            }
        })
        
        view = AnyView(view.onReceive(NotificationCenter.default.publisher(for: Notification.Name("STSTakeRatingUpdated"))) { n in
            if let sid = n.userInfo?["sessionID"] as? UUID, sid == currentSession.id {
                scheduleSessionReload()
            }
        })

        view = AnyView(view.onReceive(NotificationCenter.default.publisher(for: .stsSessionRepositoryDidUpdate)) { note in
            guard
                let sid = note.userInfo?["sessionID"] as? UUID,
                let pid = note.userInfo?["projectID"] as? UUID,
                sid == currentSession.id,
                pid == currentProject.id
            else { return }

            scheduleSessionReload()
        })
        
        view = AnyView(view.onReceive(NotificationCenter.default.publisher(for: .actorProfileDidUpdate)) { _ in
            profileManager = ActorProfileManager()
        })

view = AnyView(view.onDisappear {
    reloadDebounceWorkItem?.cancel()
})

view = AnyView(view.onAppear {
    scheduleSessionReload()
    navCtx.clearMismatched(sessionID: currentSession.id, projectID: currentProject.id)
    applyPreferredNavigationContextIfAvailable()
    withAnimation(Theme.Animation.comfortable.delay(0.3)) {
        showingBottomButtons = true
    }
            profileManager = ActorProfileManager()
        })
        
        return view
    }
    
    // MARK: - Bottom padding to avoid covering content
    /// Computes the extra padding beneath the scroll content so it never sits under
    /// the bottom action bar. Uses the cached safe-area inset captured via GeometryReader
    /// to avoid querying UIApplication during layout.
    private func calculateBottomContentPadding() -> CGFloat {
        let actionBarHeight: CGFloat = 140
        return actionBarHeight + safeBottomInset + Theme.Layout.padding
    }
    
    // MARK: - Bottom Action Bar
    @ViewBuilder private var enterpriseBottomActionBar: some View {
        VStack(spacing: 0) {
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.clear,
                    theme.primaryAccent.opacity(0.12),
                    theme.cardBackground.opacity(0.85),
                    theme.cardBackground
                ]),
                startPoint: .top, endPoint: .bottom
            ).frame(height: 20)
            VStack(spacing: Theme.Layout.compactPadding) {
                if currentSession.type == .selfTape {
                    HStack(spacing: Theme.Layout.compactPadding) {
                        EnterpriseActionButton(icon: "video.badge.plus",
                                               label: isReadOnly ? "Restore to Record" : (currentSession.takes.isEmpty ? "Record" : "Resume"),
                                               style: .secondary,
                                               isLoading: false,
                                               theme: theme) {
                            if isReadOnly {
                                showArchivedAlert = true
                            } else {
                                handleResumeSession()
                            }
                        }
                        .disabled(isReadOnly)
                        if !currentSession.takes.isEmpty {
                            EnterpriseActionButton(icon: "square.and.arrow.up.circle.fill",
                                                   label: "Export & Share",
                                                   style: .primary,
                                                   isLoading: isExporting,
                                                   theme: theme) { handleExportAndShare() }
                        }
                    }
                }
            }
            .padding(.horizontal, Theme.Layout.screenPadding)
            .padding(.vertical, Theme.Layout.compactPadding)
            .background(
                RoundedRectangle(cornerRadius: Theme.Layout.cardCornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Layout.cardCornerRadius, style: .continuous)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
            )
            .padding(.horizontal, Theme.Layout.screenPadding)
            .shadow(color: Theme.Shadow.dramatic.color,
                    radius: Theme.Shadow.dramatic.radius,
                    x: Theme.Shadow.dramatic.x,
                    y: Theme.Shadow.dramatic.y)
        }
        .background(
            Rectangle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            theme.cardBackground.opacity(0.75),
                            theme.cardBackground.opacity(0.95)
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .ignoresSafeArea(.container, edges: .bottom)
        )
    }
    
    // MARK: - Data reload
    private func scheduleSessionReload(throttle: TimeInterval = 0.2) {
        reloadDebounceWorkItem?.cancel()
        let workItem = DispatchWorkItem { reloadSessionData() }
        reloadDebounceWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + throttle, execute: workItem)
    }
    
    private func reloadSessionData() {
        let reloadStart = CFAbsoluteTimeGetCurrent()
        let repoBox = RepositorySendableBox(repository)
        let projectID = currentProject.id
        let sessionID = currentSession.id
        print("⏳ TakeReview reloadSessionData starting … project=\(projectID.shortDescription) session=\(sessionID.shortDescription)")
        
        reloadQueue.async {
            let repoLookupStart = CFAbsoluteTimeGetCurrent()
            guard let freshProject = repoBox.repository.project(by: projectID) else {
                let repoLookupDuration = CFAbsoluteTimeGetCurrent() - repoLookupStart
                DispatchQueue.main.async {
                    print(String(format: "⚠️ TakeReview reload: project %@ not found (repoLookup=%.3f s)", projectID.shortDescription, repoLookupDuration))
                }
                return
            }
            let repoLookupDuration = CFAbsoluteTimeGetCurrent() - repoLookupStart
            
            let sessionLookupStart = CFAbsoluteTimeGetCurrent()
            guard let freshSession = freshProject.sessions.first(where: { $0.id == sessionID }) else {
                let sessionLookupDuration = CFAbsoluteTimeGetCurrent() - sessionLookupStart
                DispatchQueue.main.async {
                    print(String(format: "⚠️ TakeReview reload: session %@ not found (sessionLookup=%.3f s)", sessionID.shortDescription, sessionLookupDuration))
                }
                return
            }
            let sessionLookupDuration = CFAbsoluteTimeGetCurrent() - sessionLookupStart
            
            DispatchQueue.main.async {
                let applyStart = CFAbsoluteTimeGetCurrent()
                currentProject = freshProject
                currentSession = freshSession
                if selectedViewType == .slates && !slateFilterManuallyChosenThisVisit {
                    let standard = SessionManager.shared.takes(
                        for: .slate(filter: .standard),
                        filter: TakeFilter(),
                        session: currentSession
                    )
                    let pip = SessionManager.shared.takes(
                        for: .slate(filter: .pip),
                        filter: TakeFilter(),
                        session: currentSession
                    )
                    let smartFill = SessionManager.shared.takes(
                        for: .slate(filter: .smartFill),
                        filter: TakeFilter(),
                        session: currentSession
                    )
                    let preferred = preferredSlateFilter(
                        current: selectedSlateFilter,
                        standard: standard,
                        pip: pip,
                        smartFill: smartFill
                    )
                    if preferred != selectedSlateFilter {
                        selectedSlateFilter = preferred
                    }
                }
                let applyDuration = CFAbsoluteTimeGetCurrent() - applyStart
                print("📥 TakeReview reload: refreshed session \(freshSession.id) with \(freshSession.takes.count) takes")
                let elapsed = CFAbsoluteTimeGetCurrent() - reloadStart
                print(
                    String(
                        format: "⏱️ TakeReview reloadSessionData completed in %.2f s (repo=%.3f s, session=%.3f s, apply=%.3f s)",
                        elapsed,
                        repoLookupDuration,
                        sessionLookupDuration,
                        applyDuration
                    )
                )
                
                let notes = currentSession.breakdownNotes?.slateTrimmedNonEmpty ?? currentProject.breakdownNotes?.slateTrimmedNonEmpty
                breakdownNotesDraft = notes ?? ""
                isEditingBreakdownNotes = notes == nil
                if selectedViewType == .scenes {
                    ensureValidSceneSelection()
                }
#if DEBUG
                debugLogSessionSnapshot(context: "reloadSessionData")
#endif
                if !didSignalExitProcessingReady {
                    didSignalExitProcessingReady = true
                    onExitProcessingReady?()
                    hideExitProcessingOverlayIfNeeded(source: "reloadSessionData.ready")
                }
            }
        }
    }

    private func applyImportCompletion(_ completion: ImportCompletion) -> Bool {
        let newTake = completion.take

        if currentSession.takes.contains(where: { $0.id == newTake.id }) {
            return true
        }

        let newName = URL(fileURLWithPath: newTake.filePath).lastPathComponent.lowercased()
        if currentSession.takes.contains(where: {
            URL(fileURLWithPath: $0.filePath).lastPathComponent.lowercased() == newName
        }) {
            return true
        }

        var updatedSession = currentSession
        updatedSession.takes.append(newTake)
        currentSession = updatedSession

        if let sessionIndex = currentProject.sessions.firstIndex(where: { $0.id == updatedSession.id }) {
            var updatedProject = currentProject
            updatedProject.sessions[sessionIndex] = updatedSession
            currentProject = updatedProject
        }

        if selectedViewType == .scenes {
            ensureValidSceneSelection()
        }

        return true
    }
    
    @MainActor
    private func hideExitProcessingOverlayIfNeeded(source: String) {
        guard !didHideProcessingOverlay else { return }
        didHideProcessingOverlay = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            ExitProcessingCoordinator.shared.hide(source: source)
        }
    }
    
    // MARK: - Delete / Share
    private func handleDeleteConfirmed(_ take: ProjectTake) {
        onTakeAction(.deleteTake, take)
        takeToDelete = nil
        // No share sheet payload state to clean up here
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { reloadSessionData() }
    }
    private func handleShareAction(for take: ProjectTake) {
        if isPhotoTake(take) {
            pendingPhotoShare = take
            showingPhotoShareOptions = true
            return
        }
        do {
            let fileName = URL(fileURLWithPath: take.effectiveFilePath).lastPathComponent
            let videoURL = try VideoFileManager.shared.getVideoURL(for: fileName)
            guard FileManager.default.fileExists(atPath: videoURL.path) else {
                print("❌ TakeReviewPage: Cannot share – video file missing at \(videoURL.path)")
                return
            }

            DispatchQueue.main.async {
                self.shareSheetPayload = ShareSheetPayload(items: [videoURL])
            }
        } catch {
            print("Share failed: \(error)")
        }
    }
    
    private func sharePhotoDirectly(_ take: ProjectTake) {
        guard let url = take.absoluteFileURL, FileManager.default.fileExists(atPath: url.path) else {
            print("⚠️ Share Photo: file not found \(take.filePath)")
            return
        }

        shareSheetPayload = ShareSheetPayload(items: [url])
        pendingPhotoShare = nil
    }
    
    private func sharePhotoAsVideo(_ take: ProjectTake) {
        guard let photoURL = take.absoluteFileURL else {
            print("⚠️ Share Photo Video: missing absolute path for \(take.filePath)")
            return
        }
        shareConversionInProgress = true
        Task {
            do {
                let videoURL = try await KeyframeIntroClipBuilder.buildIntroClip(
                    from: photoURL,
                    renderSize: CGSize(width: 1920, height: 1080)
                )
                await MainActor.run {
                    shareConversionInProgress = false
                    shareSheetPayload = ShareSheetPayload(items: [videoURL])
                    pendingPhotoShare = nil
                }
            } catch {
                await MainActor.run {
                    shareConversionInProgress = false
                    shareConversionError = error.localizedDescription
                    print("❌ Share Photo Video: \(error)")
                }
            }
        }
    }
    
    private func dismissPage() {
        if let onClose {
            onClose()
        } else {
            withAnimation(Theme.Animation.modalDismiss) { dismiss() }
        }
    }

    private func ensurePIPSlateSessionLoaded() {
        guard currentSession.pipSlateSession == nil,
              let storedProject = repository.project(by: currentProject.id),
              let storedSession = storedProject.sessions.first(where: { $0.id == currentSession.id }),
              let pipSession = storedSession.pipSlateSession else { return }
        currentSession.pipSlateSession = pipSession
    }

    private func inlinePIPEditorSessionBinding() -> Binding<SlatePIPSession> {
        Binding(
            get: {
                currentSession.pipSlateSession ?? SlatePIPSession()
            },
            set: { newValue in
                currentSession.pipSlateSession = newValue
                persistPIPSlateSession(newValue)
            }
        )
    }

    private var pipSessionOptionalBinding: Binding<SlatePIPSession?> {
        Binding<SlatePIPSession?>(
            get: { currentSession.pipSlateSession },
            set: { newValue in
                currentSession.pipSlateSession = newValue
                persistPIPSlateSession(newValue)
            }
        )
    }

    private func persistPIPSlateSession(_ session: SlatePIPSession?) {
        SessionManager.shared.savePIPSlateSession(
            session,
            projectID: currentProject.id,
            sessionID: currentSession.id
        )
    }

    private func autoMutePIPPreview() {
        guard var pipSession = currentSession.pipSlateSession else { return }
        let needsMute = pipSession.portraitAudioMuted == false || pipSession.landscapeAudioMuted == false
        guard needsMute else { return }
        pipSession.portraitAudioMuted = true
        pipSession.landscapeAudioMuted = true
        currentSession.pipSlateSession = pipSession
    }
    
    private var pipInfoChipText: String? {
        if let pipSession = currentSession.pipSlateSession {
            let summary = pipSlateSummaryText(for: pipSession)
            return "Picture-in-Picture • \(summary)"
        }
        let pipCompositeCount = currentSession.takes.filter { $0.takeType == .pipSlate }.count
        if pipCompositeCount > 0 {
            let plural = pipCompositeCount == 1 ? "" : "s"
            return "Picture-in-Picture • \(pipCompositeCount) saved slate\(plural)"
        }
        return nil
    }
    
    private var checklistProgress: ChecklistProgress {
        currentSession.auditionChecklist ?? ChecklistProgress(sessionID: currentSession.id)
    }
    
    private var sessionIsInProject: Bool {
        currentProject.sessions.contains(where: { $0.id == currentSession.id })
    }
    
    // MARK: - Header
    /// TEMP: simplified header used during wizard → TakeReview debugging.
    @ViewBuilder private var sessionInfoHeader: some View {
        let dueText = formattedDueDateText
        STSCard(elevation: .elevated) {
            ZStack {
                headerBackground
                // VIRGO AUDIT:
                // Root causes:
                // - Header was a single VStack with a top HStack (title + due/checklist) followed by a left-only stack.
                // - The checklist sat in the top row only, so the right column stopped there, leaving a visual gap above
                //   Edit/Sides rows and making the checklist feel like it owned the row width.
                // - No explicit two-column structure meant spacing was fragile and regressed when checklist content changed.
                // Fix:
                // - Introduce a stable two-column HStack (left metadata/actions, right checklist column).
                // - Constrain checklist column width to avoid greedy expansion.
                // - Keep breakdown/deliverables full-width below.
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .top, spacing: 16) {
                        VStack(alignment: .leading, spacing: 10) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(currentProject.title)
                                    .font(Theme.Font.cardTitle)
                                    .foregroundStyle(theme.textPrimary)
                                roleLine
                            }
                            editProjectButton
                            sidesDocsButton
                        }

                        Spacer(minLength: 0)

                        checklistColumn(dueText: dueText)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    breakdownNotesCard
                    deliverablesCard   // NEW
                }
                .padding(16)
            }
        }
    }

    private var headerBackground: some View {
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
    }

    private func checklistColumn(dueText: String?) -> some View {
        VStack(alignment: .trailing, spacing: 10) {
            dueDateChip(dueText: dueText)
            checklistChip
        }
        .frame(minWidth: 150, idealWidth: 190, maxWidth: 220, alignment: .trailing)
    }

    @ViewBuilder
    private func dueDateChip(dueText: String?) -> some View {
        if let dueText {
            Label {
                Text("Due by \(dueText)")
                    .font(Theme.Font.smallCaption)
                    .foregroundStyle(theme.textPrimary.opacity(0.85))
            } icon: {
                Image(systemName: "calendar.badge.clock")
                    .foregroundStyle(theme.primaryAccent)
            }
        }
    }

    private var roleLine: some View {
        Group {
            if let roleName = getRoleName() {
                Text(roleName)
                    .font(Theme.Font.cardSubtitle)
                    .foregroundStyle(theme.textSecondary)
            }
        }
    }

    private var sidesDocsButton: some View {
        Button {
            if hasAnySidesOrDocs {
                openPrimaryDocument()
            } else {
                showNoDocumentsDialog = true
            }
        } label: {
            HStack(spacing: 6) {
                HStack(spacing: 2) {
                    Image(systemName: "theatermasks")
                    Image(systemName: "doc.text")
                }
                .font(.caption)

                Text("Sides & Docs")
                    .font(.caption.weight(.semibold))

                if !hasAnySidesOrDocs {
                    Image(systemName: "plus.circle.fill")
                        .font(.caption)
                }
            }
            .foregroundStyle(hasAnySidesOrDocs ? takePrimaryText : takePrimaryText.opacity(0.55))
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .frame(minHeight: 44)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.black.opacity(0.18))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.white.opacity(0.10), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open sides and documents")
        .confirmationDialog(
            "No Sides or Documents Uploaded",
            isPresented: $showNoDocumentsDialog,
            titleVisibility: .visible
        ) {
            Button("Open Project Details") {
                wizardStartStep = 2
                wizardInitialScrollTarget = .uploadsBottom
                showingEditWizard = true
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("You don’t have any sides or documents yet. Upload them in Project Details.")
        }
    }

    private var editProjectButton: some View {
        Button {
            wizardStartStep = 1
            wizardInitialScrollTarget = nil
            showingEditWizard = true
        } label: {
            Label("Edit Details", systemImage: "square.and.pencil")
                .font(.caption.weight(.semibold))
                .foregroundStyle(takePrimaryText)
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .frame(minHeight: 44)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.black.opacity(0.18))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Color.white.opacity(0.10), lineWidth: 1)
                        )
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Edit project details")
    }

    private var breakdownNotesCard: some View {
        DisclosureGroup(isExpanded: $isBreakdownExpanded) {
            if let notes = effectiveBreakdownNotes, !isEditingBreakdownNotes {
                Text(notes)
                    .font(.system(size: 13))
                    .foregroundStyle(takePrimaryText)
                    .lineSpacing(3)
                    .padding(.top, 2)

                Button("Edit Notes") {
                    breakdownNotesDraft = notes
                    isEditingBreakdownNotes = true
                }
                .font(.caption)
                .foregroundStyle(theme.primaryAccent)
                .padding(.top, 4)
            } else {
                BreakdownNotesEditorView(
                    draft: $breakdownNotesDraft,
                    theme: theme,
                    primaryColor: takePrimaryText,
                    secondaryColor: takeSecondaryText,
                    hasExistingNotes: effectiveBreakdownNotes != nil,
                    onSave: saveBreakdownNotesDraft,
                    onCancel: {
                        isEditingBreakdownNotes = false
                        breakdownNotesDraft = effectiveBreakdownNotes ?? ""
                    }
                )
            }
        } label: {
            Text("Breakdown Notes")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(takePrimaryText)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.black.opacity(0.2))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }

    @ViewBuilder
    private var deliverablesCard: some View {
        if deliverables.isEmpty {
            EmptyView()
        } else {
            let items = indexedTakes(deliverables)
        DisclosureGroup(isExpanded: $isDeliverablesExpanded) {
            deliverableRows(items)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "doc.badge.plus")
                        .font(.caption.weight(.semibold))
                    Text("Deliverables")
                        .font(Theme.Font.cardSubtitle.weight(.semibold))
                    Spacer()
                    Text("\(deliverables.count)")
                        .font(Theme.Font.smallCaption)
                        .foregroundStyle(theme.textSecondary)
                }

                deliverablesHintLine
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.black.opacity(0.2))
                .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
            )
        }
    }

    private var deliverablesHintLine: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text("Tap")
            Image(systemName: deliverableSubmitIconName)
                .accessibilityHidden(true)
            Text("to mark as submitted and pin this tape in your Project Lobby.")
        }
        .font(Theme.Font.smallCaption)
        .foregroundStyle(theme.textSecondary)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Tap the camera to mark as submitted and pin this tape in your Project Lobby.")
    }

    private var deliverableSubmitIconName: String {
        "video.fill.badge.checkmark"
    }


    private var checklistChip: some View {
        let progress = checklistProgress
        let accent = progress.isComplete ? Color.green : theme.primaryAccent
        let percentage = Int(progress.completionFraction * 100)
        
        return Button {
            showingChecklist = true
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .stroke(takeChipStroke.opacity(0.6), lineWidth: 6)
                    Circle()
                        .trim(from: 0, to: CGFloat(max(min(progress.completionFraction, 1.0), 0)))
                        .stroke(
                            accent,
                            style: StrokeStyle(lineWidth: 6, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                    Text("\(percentage)%")
                        .font(.caption2.bold())
                        .foregroundStyle(takePrimaryText)
                }
                .frame(width: 44, height: 44)
                
                Text("Audition Checklist")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(takePrimaryText)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(takeChipBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(takeChipStroke, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
    
    @ViewBuilder
    private func metricChip(icon: String,
                            text: String,
                            iconColor: Color? = nil) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(iconColor ?? theme.textSecondary)

            Text(text)
                .font(Theme.Font.smallCaption)
                .foregroundStyle(theme.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
    }

    @ViewBuilder
    private func slateFilterChip(_ filter: SlateFilter, label: String) -> some View {
        Button {
            withAnimation(Theme.Animation.selection) {
                selectedSlateFilter = filter
                slateFilterManuallyChosenThisVisit = true
            }
        } label: {
            // BEGIN PATCH: SlateFilterChipTextSingleLine
            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(selectedSlateFilter == filter ? .white : theme.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .fixedSize(horizontal: true, vertical: false)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(selectedSlateFilter == filter ? Color.purple : Color.clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.purple.opacity(0.3), lineWidth: 1)
                        )
                )
            // END PATCH: SlateFilterChipTextSingleLine
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Upload Chip UI Helper
    
    @ViewBuilder
    private func uploadChip(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            // BEGIN PATCH: UploadChipTextSingleLine
            HStack(spacing: 4) {
                Image(systemName: "tray.and.arrow.down")
                    .font(.caption.weight(.semibold))
                Text("Import")
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.blue.opacity(0.15))
            )
            .foregroundStyle(.blue)
            // END PATCH: UploadChipTextSingleLine
        }
        .buttonStyle(.plain)
    }

    // MARK: - Rating Filter UI
    @ViewBuilder
    private var ratingFilterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Layout.tinyPadding) {
                Text("Filter:")
                    .font(.caption2)
                    .foregroundStyle(theme.textSecondary)

                ratingFilterChip(
                    label: "All",
                    systemImage: "line.3.horizontal.decrease.circle",
                    tint: theme.primaryAccent,
                    isSelected: ratingFilterSelections.isEmpty
                ) {
                    clearRatingFilters()
                }

                ratingFilterChip(
                    label: TakeRatingFilter.star.displayName,
                    systemImage: "star.fill",
                    tint: .yellow,
                    isSelected: ratingFilterSelections.contains(.star)
                ) {
                    toggleRatingFilter(.star)
                }

                ratingFilterChip(
                    label: TakeRatingFilter.check.displayName,
                    systemImage: "checkmark.circle.fill",
                    tint: .green,
                    isSelected: ratingFilterSelections.contains(.check)
                ) {
                    toggleRatingFilter(.check)
                }

                ratingFilterChip(
                    label: TakeRatingFilter.x.displayName,
                    systemImage: "xmark.circle.fill",
                    tint: .red,
                    isSelected: ratingFilterSelections.contains(.x)
                ) {
                    toggleRatingFilter(.x)
                }

                ratingFilterChip(
                    label: TakeRatingFilter.unrated.displayName,
                    systemImage: "circle",
                    tint: .gray,
                    isSelected: ratingFilterSelections.contains(.unrated)
                ) {
                    toggleRatingFilter(.unrated)
                }
            }
            .padding(.trailing, Theme.Layout.smallPadding)
        }
    }

    private var ratingFilterSection: some View {
        STSCard(elevation: .subtle) {
            ratingFilterRow
                .padding(.vertical, Theme.Layout.tinyPadding)
        }
    }

    @ViewBuilder
    private func ratingFilterChip(label: String,
                                  systemImage: String,
                                  tint: Color,
                                  isSelected: Bool,
                                  action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(isSelected ? .white : tint)

                Text(label)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(isSelected ? .white : theme.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? tint.opacity(0.9) : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(tint.opacity(isSelected ? 0.9 : 0.35), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private func toggleRatingFilter(_ filter: TakeRatingFilter) {
        withAnimation(Theme.Animation.selection) {
            if ratingFilterSelections.contains(filter) {
                ratingFilterSelections.remove(filter)
            } else {
                ratingFilterSelections.insert(filter)
            }
        }
#if DEBUG
        logRatingFilterChange(source: "toggle \(filter)")
#endif
    }

    private func clearRatingFilters() {
        withAnimation(Theme.Animation.selection) {
            ratingFilterSelections.removeAll()
        }
#if DEBUG
        logRatingFilterChange(source: "clear")
#endif
    }
    
    // MARK: - Tabs
    @ViewBuilder private var horizontalTabs: some View {
        STSCard(elevation: .subtle) {
            VStack(spacing: Theme.Layout.compactPadding) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Theme.Layout.smallPadding) {
                        ForEach(ViewType.allCases, id: \.self) { viewType in
                            Button {
                                handleTabSelection(viewType)
                            } label: {
                                HStack(spacing: Theme.Spacing.xs) {
                                    Image(systemName: viewType.icon).font(.caption)
                                    Text(viewType.displayName).font(.caption).fontWeight(.medium)
                                    let count = getCountForViewType(viewType)
                                    if count > 0 { Text("(\(count))").font(.caption2).foregroundStyle(theme.primaryAccent) }
                                }
                                .foregroundStyle(selectedViewType == viewType ? .white : theme.textSecondary)
                                .padding(.horizontal, Theme.Layout.compactPadding)
                                .padding(.vertical, Theme.Layout.smallPadding)
                                .background(
                                    RoundedRectangle(cornerRadius: Theme.Layout.smallCornerRadius)
                                        .fill(selectedViewType == viewType ? theme.primaryAccent : Color.clear)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, Theme.Layout.smallPadding)
                }
                // Scenes chip row with upload
                if selectedViewType == .scenes {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: Theme.Layout.smallPadding) {

                            Text("Scene:")
                                .font(.caption)
                                .foregroundStyle(theme.textSecondary)

                            let totalScenes = max(getSceneCount(), 1)
                            ForEach(1...totalScenes, id: \.self) { n in
                                Button(action: { selectedSceneNumber = n }) {
                                    Text("\(n)")
                                        .font(.caption.weight(.semibold))
                                        .foregroundColor(selectedSceneNumber == n ? .white : theme.textSecondary)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(
                                            RoundedRectangle(cornerRadius: 6)
                                                .fill(selectedSceneNumber == n ? Color.blue : Color.clear)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 6)
                                                        .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                                                )
                                        )
                                }
                                .buttonStyle(.plain)
                            }

                            uploadChip {
                                requestVideoUpload(for: .scene(selectedSceneNumber))
                            }
                        }
                    }
                } else if selectedViewType == .slates {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: Theme.Layout.smallPadding) {
                            Text("Slate type:")
                                .font(.caption)
                                .foregroundStyle(theme.textSecondary)

                            slateFilterChip(.pip,       label: "PiP")
                            slateFilterChip(.smartFill, label: "SmartFill")
                            slateFilterChip(.standard,  label: "Original")

                            uploadChip {
                                requestVideoUpload(
                                    for: .slate(
                                        sceneNumber: defaultSlateSceneNumber,
                                        slateNumber: nil,
                                        slateID: nil
                                    )
                                )
                            }
                        }
                        .padding(.trailing, Theme.Layout.smallPadding)
                    }
                }

            }
        }
    }

    @ViewBuilder
    private func deliverableRows(_ items: [IndexedTake]) -> some View {
        let batches = deliverableBatches(from: items)
        VStack(alignment: .leading, spacing: 14) {
            ForEach(batches) { batch in
                VStack(alignment: .leading, spacing: 8) {
                    deliverableBatchHeader(date: batch.date)

                    VStack(spacing: Theme.Layout.tinyPadding) {
                        ForEach(batch.items) { item in
                            deliverableRow(item)
                        }
                    }
                }
            }
        }
        .padding(.top, 8)
    }

    @ViewBuilder
    private func deliverableRow(_ item: IndexedTake) -> some View {
        let take = item.take
        let isSubmitted = take.submittedAt != nil
        let durationText = take.durationSeconds > 0 ? formattedDuration(take.effectiveDurationSeconds) : nil
        DeliverableRowView(
            take: take,
            takeNumber: item.displayNumber,
            theme: theme,
            isSubmitted: isSubmitted,
            fileNameText: deliverableFileNameText(for: take),
            fileSizeText: deliverableFileSizeText(for: take),
            durationText: durationText,
            onPlay: {
                handleTakeAction(
                    .play,
                    for: take,
                    isFromDeliverables: true
                )
            },
            onAction: { action in
                handleTakeAction(
                    action,
                    for: take,
                    isFromDeliverables: true
                )
            },
            onToggleSubmitted: {
                requestDeliverableSubmissionToggle(
                    for: take,
                    isSubmitted: !isSubmitted
                )
            },
            onShare: { handleShareAction(for: take) },
            onDelete: {
                takeToDelete = take
                showingDeleteConfirmation = true
            },
            onShowInfo: { showVideoInfo(for: take) }
        )
    }

    private struct DeliverableBatch: Identifiable {
        let id: UUID
        let date: Date
        let items: [IndexedTake]
    }

    private func deliverableBatches(from items: [IndexedTake]) -> [DeliverableBatch] {
        let sorted = items.sorted { lhs, rhs in
            deliverableBatchDate(for: lhs.take) > deliverableBatchDate(for: rhs.take)
        }

        var batches: [DeliverableBatch] = []
        var currentItems: [IndexedTake] = []
        var currentAnchor: Date?

        for item in sorted {
            let date = deliverableBatchDate(for: item.take)
            if let anchor = currentAnchor,
               abs(anchor.timeIntervalSince(date)) <= deliverableBatchClusteringWindow {
                currentItems.append(item)
            } else {
                if let anchor = currentAnchor, !currentItems.isEmpty {
                    batches.append(DeliverableBatch(id: UUID(), date: anchor, items: currentItems))
                }
                currentAnchor = date
                currentItems = [item]
            }
        }

        if let anchor = currentAnchor, !currentItems.isEmpty {
            batches.append(DeliverableBatch(id: UUID(), date: anchor, items: currentItems))
        }

        return batches
    }

    private var deliverableBatchClusteringWindow: TimeInterval { 120 }

    private func deliverableBatchDate(for take: ProjectTake) -> Date {
        if let exportDate = take.exportMetadata?.exportDate {
            return exportDate
        }
        if let lastExportDate = take.lastExportDate {
            return lastExportDate
        }
        return take.createdAt
    }

    private func deliverableBatchHeader(date: Date) -> some View {
        Text(deliverableBatchTitle(for: date))
            .font(Theme.Font.smallCaption.weight(.semibold))
            .foregroundStyle(theme.textSecondary)
            .padding(.horizontal, 4)
    }

    private func deliverableBatchTitle(for date: Date) -> String {
        let calendar = Calendar.current
        let time = Self.deliverableBatchTimeFormatter.string(from: date)
        let day: String
        if calendar.isDateInToday(date) {
            day = "Today"
        } else if calendar.isDateInYesterday(date) {
            day = "Yesterday"
        } else {
            day = Self.deliverableBatchDateFormatter.string(from: date)
        }
        return "Export Batch • \(day) • \(time)"
    }

    private static let deliverableBatchTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()

    private static let deliverableBatchDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
    
    // MARK: - Scene section
    @ViewBuilder private var sceneBasedTakeSection: some View {
        let sceneTakes = sceneRegularTakes.filter { $0.sceneNumber == selectedSceneNumber }
        let pendingImports = pendingSceneImportJobs
        let unfilteredSceneTakes = SessionManager.shared.takes(
            for: .scene(sceneNumber: selectedSceneNumber),
            filter: TakeFilter(),
            session: currentSession
        )
        let showFilterEmptyState = hasActiveRatingFilter
        && sceneTakes.isEmpty
        && pendingImports.isEmpty
        && !unfilteredSceneTakes.isEmpty

        VStack(spacing: Theme.Layout.smallPadding) {
            if showFilterEmptyState {
                filterEmptyStateCard
            } else {
                STSCard(elevation: .elevated) {
                    VStack(alignment: .leading, spacing: Theme.Layout.compactPadding) {
                        if !sceneTakes.isEmpty || !pendingImports.isEmpty {
                            takeSection(title: "Scene \(selectedSceneNumber)",
                                        takes: sceneTakes,
                                        icon: "video.fill",
                                        color: .blue,
                                        pendingImports: pendingImports)
                        } else {
                            VStack(spacing: Theme.Layout.compactPadding) {
                                Image(systemName: "tv.slash").font(.system(size: 32)).foregroundStyle(.gray)
                                Text("No takes for Scene \(selectedSceneNumber)").font(.headline).foregroundStyle(theme.textPrimary)
                                Text("Import an existing video or record using the iTFactor camera.")
                                    .font(.caption)
                                    .foregroundStyle(theme.textSecondary)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.vertical, Theme.Layout.smallPadding)
                        }
                    }
                }
            }
        }
    }
    
    // BEGIN PATCH: SlateUploadSectionsEmptyStates
    @ViewBuilder private var slateUploadSections: some View {
        let slates = filteredSlateTakes
        let pendingImports = pendingSlateImportJobs
        let showFilterEmptyState = hasActiveRatingFilter
        && slates.isEmpty
        && pendingImports.isEmpty
        && !unfilteredSelectedSlateTakes.isEmpty

        if showFilterEmptyState {
            filterEmptyStateCard
        } else if slates.isEmpty && pendingImports.isEmpty {
            switch selectedSlateFilter {
            case .pip:
                pipEmptySlateState

            case .smartFill:
                smartFillEmptySlateState

            case .standard:
                genericSlateEmptyState
            }
        } else {
            STSCard(elevation: .elevated) {
                VStack(alignment: .leading, spacing: Theme.Layout.compactPadding) {
                    takeSection(
                        title: currentSlateFilterTitle,
                        takes: slates,
                        icon: "tv",
                        color: .purple,
                        pendingImports: pendingImports
                    )
                }
            }
        }
    }
    // END PATCH: SlateUploadSectionsEmptyStates

    @ViewBuilder
    private var pipSlateEditorEntry: some View {
        STSCard(elevation: .subtle) {
            DisclosureGroup(isExpanded: $showInlinePIPEditor) {
                NavigationLink {
                    PIPSlateEditorScreen(
                        session: pipSessionOptionalBinding,
                        project: currentProject,
                        projectSession: currentSession,
                        onCompositeSaved: {
                            reloadSessionData()
                            autoRateMostRecentPIPSlateAsGood()
                        }
                    )
                } label: {
                    Label("Open Full Editor", systemImage: "arrow.up.left.and.arrow.down.right")
                        .font(.caption.weight(.semibold))
                        .padding(.bottom, Theme.Layout.tinyPadding)
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, alignment: .leading)
                let binding = inlinePIPEditorSessionBinding()
                PIPSlateEditorCore(
                    session: binding,
                    project: currentProject,
                    projectSession: currentSession,
                    isEmbedded: true,
                    externalSaveTrigger: $inlinePIPSaveTrigger,
                    onCompositeSaved: {
                        reloadSessionData()
                        autoRateMostRecentPIPSlateAsGood()
                    }
                )
                .frame(minHeight: 520)
                .transition(.opacity.combined(with: .move(edge: .top)))
            } label: {
                HStack(spacing: Theme.Layout.smallPadding) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Picture-in-Picture Slate")
                            .font(.headline)
                            .foregroundStyle(theme.textPrimary)
                        Label("Picture-in-Picture", systemImage: "rectangle.on.rectangle")
                            .font(.caption)
                            .foregroundStyle(theme.textSecondary)
                        Text(pipSlateSummaryText(for: currentSession.pipSlateSession))
                            .font(.caption)
                            .foregroundStyle(theme.textSecondary)
                    }
                    Spacer()
                }
                .padding(.vertical, Theme.Layout.compactPadding)
            }
        }
    }

    private func pipSlateSummaryText(for session: SlatePIPSession?) -> String {
        guard let session else { return "No Picture-in-Picture slate yet." }
        let portraitLabel = "Portrait: \(session.portraitTakes.count)"
        let landscapeLabel = "Landscape: \(session.landscapeTakes.count)"
        let readiness = (session.selectedPortraitTake != nil && session.selectedLandscapeTake != nil) ? "Ready" : "Needs Takes"
        return [portraitLabel, landscapeLabel, readiness].joined(separator: " • ")
    }

    private func autoRateMostRecentPIPSlateAsGood() {
        // Auto-rating removed: PIP slates remain unrated until user explicitly selects a rating.
    }
    
    private var canInlinePIPSave: Bool {
        guard let session = currentSession.pipSlateSession else { return false }
        return session.selectedPortraitTake != nil && session.selectedLandscapeTake != nil
    }
    
    private func getCountForViewType(_ viewType: ViewType) -> Int {
        switch viewType {
        case .scenes: return sceneRegularTakes.count
        case .slates: return slateTakes.count
        case .keyframes: return keyframeTakes.count
        case .deliverables: return deliverables.count
        }
    }
    
    private func handleTabSelection(_ viewType: ViewType) {
        let wasSlate = selectedViewType == .slates
        withAnimation(Theme.Animation.selection) {
            selectedViewType = viewType
        }
        if viewType == .slates && !wasSlate {
            slateFilterManuallyChosenThisVisit = false
        }
        if viewType == .scenes {
            ensureValidSceneSelection()
        }
    }
    
    private func ensureValidSceneSelection() {
        let scenes = unfilteredSceneRegularTakes.map { max(1, $0.sceneNumber) }
        guard !scenes.isEmpty else {
            selectedSceneNumber = 1
            return
        }
        if !scenes.contains(selectedSceneNumber) {
            if let lastScene = scenes.sorted().last {
                selectedSceneNumber = lastScene
            } else {
                selectedSceneNumber = 1
            }
        }
#if DEBUG
        debugLogSessionSnapshot(context: "ensureValidSceneSelection")
#endif
    }
#if DEBUG
    private func debugLogSessionSnapshot(context: String) {
        let sceneCounts = Dictionary(grouping: sceneRegularTakes, by: { max(1, $0.sceneNumber) })
            .mapValues { $0.count }
            .sorted { $0.key < $1.key }
            .map { "S\($0.key)=\($0.value)" }
            .joined(separator: ", ")
        let takeTypes = Dictionary(grouping: currentSession.takes, by: { $0.takeType })
            .mapValues { $0.count }
            .map { "\($0.key.rawValue)=\($0.value)" }
            .joined(separator: ", ")
        print("""
🔍 TakeReview[\(context)] project=\(currentProject.id.shortDescription) session=\(currentSession.id.shortDescription) \
view=\(selectedViewType) scene=\(selectedSceneNumber) total=\(currentSession.takes.count) \
regular=\(sceneRegularTakes.count) slates=\(slateTakes.count) photos=\(keyframeTakes.count) deliverables=\(deliverables.count)
    types[\(takeTypes)]
    scenes[\(sceneCounts.isEmpty ? "none" : sceneCounts)]
""")
    }

    private func logRatingFilterChange(source: String) {
        let selection = ratingFilterSelections.isEmpty
        ? "all"
        : ratingFilterSelections.map { "\($0)" }.sorted().joined(separator: ",")
        print("🧪 TakeReviewFilter[\(source)] selections=\(selection) scenes=\(sceneRegularTakes.count) slates=\(slateTakes.count) photos=\(keyframeTakes.count)")
    }
#endif
    
    // MARK: - Sections
    private struct IndexedTake: Identifiable {
        let id: UUID
        let displayNumber: Int
        let take: ProjectTake
    }

    private func indexedTakes(_ source: [ProjectTake]) -> [IndexedTake] {
        source.map { take in
            let displayNumber = TakeDisplayFormatter.ordinal(for: take, in: currentSession)
            return IndexedTake(id: take.id, displayNumber: displayNumber, take: take)
        }
    }

    @ViewBuilder
    private func takeSection(
        title: String,
        takes: [ProjectTake],
        icon: String,
        color: Color,
        pendingImports: [ImportJob] = []
    ) -> some View {
        STSCard(elevation: .elevated) {
            let items = indexedTakes(takes)
            let totalCount = takes.count + pendingImports.count
            let isDeliverables = (title == "Deliverables")
            VStack(alignment: .leading, spacing: Theme.Layout.compactPadding) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: icon).font(.headline).foregroundStyle(color)
                        Text(title).font(Theme.Font.cardTitle).foregroundStyle(theme.textPrimary)
                        Spacer()
                        Text("\(totalCount)").font(Theme.Font.smallCaption).foregroundStyle(theme.textSecondary)
                    }

                    if isDeliverables {
                        Text("Export your final tape, then mark it as submitted to pin it in your Project Lobby and stop audition reminders.")
                            .font(Theme.Font.smallCaption)
                            .foregroundStyle(theme.textSecondary)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                LazyVStack(spacing: Theme.Layout.tinyPadding) {
                    ForEach(pendingImports) { job in
                        PendingImportRowView(
                            job: job,
                            theme: theme,
                            accent: color,
                            onCancel: { importStore.cancel(jobID: job.id) },
                            onRetry: { importStore.retry(jobID: job.id) }
                        )
                    }
                    ForEach(items) { item in
                        takeRowView(item, isDeliverablesSection: isDeliverables)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func takeRowView(_ item: IndexedTake, isDeliverablesSection: Bool) -> some View {
        let take = item.take
        TakeRowSimplified(
            take: take,
            takeNumber: item.displayNumber,
            session: currentSession,
            theme: theme,
            onAction: { action in
                handleTakeAction(action, for: take, isFromDeliverables: isDeliverablesSection)
            },
            onDelete: { takeToDelete = take; showingDeleteConfirmation = true },
            onShare: { handleShareAction(for: take) },
            onSubmittedToggle: nil // submission handled only in header card
        )
    }
    
    @ViewBuilder
    private func inlineUploadControl(for context: VideoUploadContext) -> some View {
        switch context {
        case .scene:
            let totalScenes = max(getSceneCount(), 1)
            Menu {
                ForEach(1...totalScenes, id: \.self) { scene in
                    Button("Scene \(scene)") {
                        requestVideoUpload(for: .scene(scene))
                    }
                }
            } label: {
                InlineUploadLabel(context: context, theme: theme)
            }
        default:
            Button {
                requestVideoUpload(for: context)
            } label: {
                InlineUploadLabel(context: context, theme: theme)
            }
            .buttonStyle(.plain)
        }
    }
    
private struct InlineUploadLabel: View {
        let context: VideoUploadContext
        let theme: STSTheme
        var body: some View {
            let copy = TakeReviewPage.inlineUploadCopy(for: context)
            HStack(spacing: Theme.Layout.smallPadding) {
                Image(systemName: context.iconName)
                    .font(.caption)
                VStack(alignment: .leading, spacing: 2) {
                    Text(copy.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(theme.textPrimary)
                    Text(copy.subtitle)
                        .font(.caption2)
                        .foregroundStyle(theme.textSecondary)
                }
                Spacer()
                Image(systemName: "square.and.arrow.up")
                    .font(.caption)
            }
            .padding(10)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(theme.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(theme.cardStroke, lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }
    
    private static func inlineUploadCopy(for context: VideoUploadContext) -> (title: String, subtitle: String) {
        switch context {
        case .scene:
            return ("Import Scene Video", "Choose a scene to add footage")
        case .slate:
            return ("Import Slate Video", "Add or replace slate media")
        }
    }

    @ViewBuilder
    private var emptySessionState: some View {
        STSCard(elevation: .elevated) {
            VStack(spacing: Theme.Layout.compactPadding) {
                Image(systemName: "video.badge.plus")
                    .font(.system(size: 32))
                    .foregroundStyle(theme.primaryAccent)
                
                Text("No takes yet")
                    .font(.headline)
                    .foregroundStyle(theme.textPrimary)
                
                Text("Tap \"Record\" below to begin your Self-Tape session.")
                    .font(.caption)
                    .foregroundStyle(theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, Theme.Layout.smallPadding)
        }
    }
    // MARK: - Computed
    private var takeRatingFilter: TakeFilter {
        TakeFilter(allowedRatings: ratingFilterSelections)
    }

    private var hasActiveRatingFilter: Bool {
        !ratingFilterSelections.isEmpty
    }

    private var unfilteredSceneRegularTakes: [ProjectTake] {
        SessionManager.shared.takes(
            for: .scenes,
            filter: TakeFilter(),
            session: currentSession
        )
    }

    private var unfilteredSlateTakes: [ProjectTake] {
        SessionManager.shared.takes(
            for: .slates,
            filter: TakeFilter(),
            session: currentSession
        )
    }

    private var unfilteredKeyframeTakes: [ProjectTake] {
        SessionManager.shared.takes(
            for: .photosKeyframes,
            filter: TakeFilter(),
            session: currentSession
        )
    }

    private var unfilteredSelectedSlateTakes: [ProjectTake] {
        SessionManager.shared.takes(
            for: .slate(filter: takeQuerySlateFilter),
            filter: TakeFilter(),
            session: currentSession
        )
    }

    private var mergedVideos: [ProjectTake] {
        currentSession.takes.filter { $0.takeType == .merged }
    }
    private var sceneRegularTakes: [ProjectTake] {
        SessionManager.shared.takes(
            for: .scenes,
            filter: takeRatingFilter,
            session: currentSession
        )
    }
    private var slateTakes: [ProjectTake] {
        SessionManager.shared.takes(
            for: .slates,
            filter: takeRatingFilter,
            session: currentSession
        )
    }

    private var filteredSlateTakes: [ProjectTake] {
        SessionManager.shared.takes(
            for: .slate(filter: takeQuerySlateFilter),
            filter: takeRatingFilter,
            session: currentSession
        )
    }

    private var pendingSceneImportJobs: [ImportJob] {
        importStore.jobs
            .filter { job in
                job.contextData.sessionID == currentSession.id
                && job.contextData.projectID == currentProject.id
                && !job.identifiers.isSlate
                && !job.identifiers.isKeyframePhoto
                && job.identifiers.sceneNumber == selectedSceneNumber
                && shouldSurfaceImportJob(job)
            }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    private var pendingSlateImportJobs: [ImportJob] {
        importStore.jobs
            .filter { job in
                job.contextData.sessionID == currentSession.id
                && job.contextData.projectID == currentProject.id
                && job.identifiers.isSlate
                && !job.identifiers.isKeyframePhoto
                && shouldSurfaceImportJob(job)
            }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    private var pendingKeyframeImportJobs: [ImportJob] {
        importStore.jobs
            .filter { job in
                job.contextData.sessionID == currentSession.id
                && job.contextData.projectID == currentProject.id
                && job.identifiers.isKeyframePhoto
                && shouldSurfaceImportJob(job)
            }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    private var hasVisibleImportJobs: Bool {
        importStore.jobs.contains { job in
            job.contextData.sessionID == currentSession.id
            && job.contextData.projectID == currentProject.id
            && shouldSurfaceImportJob(job)
        }
    }

    private func shouldSurfaceImportJob(_ job: ImportJob) -> Bool {
        if job.phase.isActive || job.phase == .failed {
            return true
        }
        if job.phase == .ready {
            return !isJobReflectedInSession(job)
        }
        return false
    }

    private func isJobReflectedInSession(_ job: ImportJob) -> Bool {
        let target = job.identifiers.fileName.lowercased()
        return currentSession.takes.contains { take in
            URL(fileURLWithPath: take.filePath).lastPathComponent.lowercased() == target
        }
    }

    private var currentSlateFilterTitle: String {
        switch selectedSlateFilter {
        case .pip:
            return "PiP Slates"
        case .smartFill:
            return "SmartFill Slates"
        case .standard:
            return "Slates"
        }
    }
    private var keyframeTakes: [ProjectTake] {
        SessionManager.shared.takes(
            for: .photosKeyframes,
            filter: takeRatingFilter,
            session: currentSession
        )
    }
    private var exportedTakes: [ProjectTake] {
        currentSession.takes.filter { $0.takeType == .exported }
    }
    private var deliverables: [ProjectTake] {
        let merged = mergedVideos.sorted { $0.createdAt > $1.createdAt }
        let exported = exportedTakes.sorted { $0.createdAt > $1.createdAt }
        return merged + exported
    }

    private func deliverableResolvedURL(for take: ProjectTake) -> URL? {
        guard take.takeType == .merged || take.takeType == .exported else { return nil }
        guard !take.filePath.isEmpty else { return nil }

        let primaryURL = URL(fileURLWithPath: take.filePath)
        if FileManager.default.fileExists(atPath: primaryURL.path) {
            return primaryURL
        }

        return VideoVariantResolver.urlForRelativePath(take.filePath)
    }

    private func deliverableFileNameText(for take: ProjectTake) -> String? {
        guard let resolvedURL = deliverableResolvedURL(for: take) else { return nil }
        let fileName = resolvedURL.lastPathComponent
        return fileName.isEmpty ? nil : fileName
    }

    private func deliverableFileSizeText(for take: ProjectTake) -> String? {
        guard let resolvedURL = deliverableResolvedURL(for: take) else { return nil }
        if let size = try? resolvedURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
            return ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
        }
        return nil
    }

    private func formattedDuration(_ duration: TimeInterval) -> String {
        let m = Int(duration) / 60
        let s = Int(duration) % 60
        return String(format: "%d:%02d", m, s)
    }

    private var pipComponentBasenames: Set<String> {
        guard let pip = currentSession.pipSlateSession else { return [] }
        let components = pip.portraitTakes + pip.landscapeTakes
        return Set(components.map { URL(fileURLWithPath: $0.filePath).lastPathComponent.lowercased() })
    }

    private func isPIPComponent(_ take: ProjectTake) -> Bool {
        if take.takeType.isPIPComponent { return true }
        let name = URL(fileURLWithPath: take.filePath).lastPathComponent.lowercased()
        return pipComponentBasenames.contains(name)
    }

    private var takeQuerySlateFilter: TakeSlateFilter {
        switch selectedSlateFilter {
        case .pip:
            return .pip
        case .smartFill:
            return .smartFill
        case .standard:
            return .standard
        }
    }

    private func preferredSlateFilter(
        current: SlateFilter,
        standard: [ProjectTake],
        pip: [ProjectTake],
        smartFill: [ProjectTake]
    ) -> SlateFilter {
        let currentTakes: [ProjectTake]
        switch current {
        case .standard:
            currentTakes = standard
        case .pip:
            currentTakes = pip
        case .smartFill:
            currentTakes = smartFill
        }
        if !currentTakes.isEmpty {
            return current
        }

        struct Candidate {
            let filter: SlateFilter
            let latest: Date
        }

        var candidates: [Candidate] = []
        if let date = latestSlateDate(in: smartFill) {
            candidates.append(Candidate(filter: .smartFill, latest: date))
        }
        if let date = latestSlateDate(in: pip) {
            candidates.append(Candidate(filter: .pip, latest: date))
        }
        if let date = latestSlateDate(in: standard) {
            candidates.append(Candidate(filter: .standard, latest: date))
        }

        guard let best = candidates.max(by: { lhs, rhs in
            if lhs.latest != rhs.latest {
                return lhs.latest < rhs.latest
            }
            return slateFilterPriority(lhs.filter) < slateFilterPriority(rhs.filter)
        }) else {
            return current
        }
        return best.filter
    }

    private func latestSlateDate(in takes: [ProjectTake]) -> Date? {
        guard !takes.isEmpty else { return nil }
        return takes
            .map { $0.editMetadata?.editedDate ?? $0.createdAt }
            .max()
    }

    private func slateFilterPriority(_ filter: SlateFilter) -> Int {
        switch filter {
        case .smartFill:
            return 3
        case .pip:
            return 2
        case .standard:
            return 1
        }
    }

    private var hasPIPContent: Bool {
        guard let pip = currentSession.pipSlateSession else { return false }
        return !pip.portraitTakes.isEmpty || !pip.landscapeTakes.isEmpty
    }

    private var hasAnyTakes: Bool {
        !currentSession.takes.isEmpty || hasPIPContent || hasVisibleImportJobs
    }
    private var defaultSlateSceneNumber: Int {
        let orderedSlates = unfilteredSlateTakes.sorted { $0.createdAt > $1.createdAt }
        if let firstSlateScene = orderedSlates.first?.sceneNumber {
            return firstSlateScene
        }
        if sceneRegularTakes.contains(where: { $0.sceneNumber == selectedSceneNumber }) {
            return selectedSceneNumber
        }
        return currentSession.takes.first?.sceneNumber ?? 1
    }
    
    private var createdOnToolbarText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd/yy 'at' h:mma"
        return formatter.string(from: currentSession.date).lowercased()
    }
    
    private var formattedDueDateText: String? {
        guard let due = currentProject.auditionDueDate else { return nil }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: due)
    }
    
    private var effectiveSidesFileName: String? {
        currentSession.sidesFileName ?? currentProject.sidesFileName
    }
    
    private var effectiveBreakdownFileName: String? {
        currentSession.breakdownFileName ?? currentProject.breakdownFileName
    }
    
    private var effectiveSidesURL: URL? {
        effectiveSidesFileName.flatMap { resolveDocumentURL(named: $0) }
    }
    
    private var effectiveBreakdownURL: URL? {
        effectiveBreakdownFileName.flatMap { resolveDocumentURL(named: $0) }
    }
    
    private var effectiveBreakdownNotes: String? {
        currentSession.breakdownNotes?.slateTrimmedNonEmpty ?? currentProject.breakdownNotes?.slateTrimmedNonEmpty
    }
    
    private func resolveDocumentURL(named fileName: String) -> URL? {
        guard !fileName.isEmpty,
              let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        let url = documentsDirectory.appendingPathComponent(fileName)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }
    
    private func writeTemporaryDocument(named name: String, contents: String) -> URL? {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("ProjectDocs", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let fileURL = directory.appendingPathComponent(name)
            try contents.data(using: .utf8)?.write(to: fileURL, options: .atomic)
            return fileURL
        } catch {
            print("⚠️ Failed to write temporary document: \(error.localizedDescription)")
            return nil
        }
    }
    
    private func getSceneCount() -> Int {
        let sceneNumbers = Set(
            currentSession.takes
                .filter { $0.takeType == .regular && $0.durationSeconds > 0 && $0.sceneNumber > 0 }
                .map { $0.sceneNumber }
        )
        return sceneNumbers.count
    }

    private func getSlateCount() -> Int {
        let identifiers = Set(
            currentSession.takes
                .filter { $0.takeType.isSlateLike }
                .compactMap { take -> String? in
                    if let slateID = take.slateID?.slateTrimmedNonEmpty {
                        return slateID
                    }
                    if let slateNumber = take.slateNumber?.slateTrimmedNonEmpty {
                        return slateNumber
                    }
                    return nil
                }
        )
        return identifiers.count
    }

    private func getKeyframePhotoCount() -> Int {
        currentSession.takes.filter { take in
            guard take.durationSeconds == 0, !take.takeType.isSlateLike else { return false }
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
        }.count
    }

    private var smartFillCount: Int {
        currentSession.takes.filter { $0.isSmartFillVariant || $0.smartFilledFilePath != nil }.count
    }

    private var pipSlateCount: Int {
        currentSession.takes.filter { $0.takeType == .pipSlate }.count
    }

    private var editedCount: Int {
        currentSession.takes.filter { $0.hasEdits }.count
    }
    
    private func openPrimaryDocument() {
        if hasDocument(for: .sides) {
            openDocument(for: .sides)
        } else {
            openDocument(for: .breakdown)
        }
    }
    
    private func openDocument(for type: DocumentUploadKind) {
        let docs = allDocumentReferences()
        if let targetIndex = docs.firstIndex(where: { doc in
            switch type {
            case .sides:
                return doc.type == .sides
            case .breakdown:
                return doc.type == .breakdown
            }
        }) {
            documentViewerPayload = DocumentViewerPayload(
                documents: docs,
                initialIndex: targetIndex
            )
            return
        }
        
        if type == .breakdown {
            isBreakdownExpanded = true
            isEditingBreakdownNotes = true
            persistDisclosurePrefs(
                breakdownExpanded: true,
                deliverablesExpanded: isDeliverablesExpanded,
                pipEditorExpanded: showInlinePIPEditor
            )
        }
        
        beginDocumentUpload(for: type)
    }
    
    private func beginDocumentUpload(for type: DocumentUploadKind) {
        pendingDocumentUpload = type
        pendingFileImporter = .document
        showFilesImporter = true
    }

    private func handleFilesImporterResult(_ result: Result<[URL], Error>) {
        let importer = pendingFileImporter
        pendingFileImporter = nil
        showFilesImporter = false

        ImportLog.files.info(
            "fileImporter completion pending=\(String(describing: importer), privacy: .public)"
        )

        switch result {
        case .success(let urls):
            ImportLog.files.info("fileImporter success urls=\(urls.count, privacy: .public)")
        case .failure(let error):
            ImportLog.files.error("fileImporter failure error=\(error.localizedDescription, privacy: .public)")
        }

        switch importer {
        case .document:
            handleDocumentImport(result)
        case .filesVideo:
            handleVideoImport(result)
        case .filesKeyframePhoto:
            handleKeyframeFileImport(result)
        case .none:
            break
        }
    }
    
    private func handleAddDocumentRequest(fromViewer type: CombinedDocumentView.DocumentType) {
        switch type {
        case .sides:
            beginDocumentUpload(for: .sides)
        case .breakdown:
            beginDocumentUpload(for: .breakdown)
        default:
            break
        }
    }
    
    private func hasDocument(for type: DocumentUploadKind) -> Bool {
        switch type {
        case .sides:
            return effectiveSidesFileName != nil
        case .breakdown:
            return effectiveBreakdownFileName != nil || effectiveBreakdownNotes != nil
        }
    }
    
    private func handleDocumentImport(_ result: Result<[URL], Error>) {
        guard let pending = pendingDocumentUpload else { return }
        pendingDocumentUpload = nil
        
        switch result {
        case .failure(let error):
            let nsError = error as NSError
            if nsError.domain == NSCocoaErrorDomain && nsError.code == NSUserCancelledError {
                return
            }
            importErrorMessage = error.localizedDescription
            showImportErrorAlert = true
        case .success(let urls):
            guard let url = urls.first else { return }
            do {
                let importResult = try SafeDocumentStore.importFromPicker(
                    url: url,
                    preferredName: url.lastPathComponent,
                    subfolder: nil
                )
                
                switch pending {
                case .sides:
                    currentSession.sidesFileName = importResult.fileName
                case .breakdown:
                    currentSession.breakdownFileName = importResult.fileName
                }
                
                persistSessionChanges()
                
                let docs = allDocumentReferences()
                if let targetIndex = docs.firstIndex(where: { doc in
                    switch pending {
                    case .sides:
                        return doc.type == .sides
                    case .breakdown:
                        return doc.type == .breakdown
                    }
                }) {
                    documentViewerPayload = DocumentViewerPayload(
                        documents: docs,
                        initialIndex: targetIndex
                    )
                }
            } catch {
                importErrorMessage = error.localizedDescription
                showImportErrorAlert = true
            }
        }
    }
    
    private func requestVideoUpload(for context: VideoUploadContext) {
        guard !isUploadingVideo else { return }
        pendingVideoUploadContext = context
        pendingFileImporter = nil
        showUploadSourceSheet = true
    }
    
    private func beginKeyframePhotoUpload(forScene sceneNumber: Int) {
        pendingKeyframePhotoUploadContext = .scene(sceneNumber)
        pendingFileImporter = nil
        showKeyframeUploadSourceSheet = true
    }
    
    private func handleVideoImport(_ result: Result<[URL], Error>) {
        guard let context = pendingVideoUploadContext else {
            print("⚠️ No pending context for video import")
            return
        }

        pendingVideoUploadContext = nil

        switch result {
        case .success(let urls):
            ImportLog.files.info(
                "handleVideoImport urls=\(urls.count) scene=\(context.sceneNumber) isSlate=\(context.isSlate)"
            )
            for url in urls {
                ImportLog.files.info(
                    "file selected name=\(url.lastPathComponent, privacy: .public) ext=\(url.pathExtension, privacy: .public) scheme=\(url.scheme ?? "nil", privacy: .public)"
                )
            }
            isUploadingVideo = true
            let contextData = makeImportContextData()

            Task.detached(priority: .userInitiated) {
                defer {
                    Task { @MainActor in
                        self.isUploadingVideo = false
                    }
                }

                for pickedURL in urls {
                    let ext = pickedURL.pathExtension.isEmpty ? "mov" : pickedURL.pathExtension
                    let identifiers = await MainActor.run {
                        self.prepareImportIdentifiers(for: context, fileExtension: ext)
                    }
                    let jobID = UUID()
                    let createdAt = Date()
                    let stagedURL = FilePickerCopy.stagingURL(jobID: jobID, fileExtension: ext)
                    let placeholderSource = ImportSource.localFile(
                        url: stagedURL,
                        originalFilename: identifiers.fileName
                    )
                    let placeholderJob = ImportJob(
                        id: jobID,
                        identifiers: identifiers,
                        contextData: contextData,
                        source: placeholderSource,
                        phase: .preparing,
                        progress: nil,
                        tempPath: stagedURL.path,
                        createdAt: createdAt,
                        updatedAt: createdAt,
                        failure: nil
                    )
                    await MainActor.run {
                        self.importStore.registerEnqueuedJob(placeholderJob)
                    }

                    do {
                        var copyingJob = placeholderJob
                        copyingJob.phase = .copying
                        copyingJob.updatedAt = Date()
                        let copyingSnapshot = copyingJob
                        await MainActor.run {
                            self.importStore.registerEnqueuedJob(copyingSnapshot)
                        }

                        try FilePickerCopy.copyToTemp(from: pickedURL, to: stagedURL)
                        ImportLog.files.info(
                            "staged video job=\(jobID.uuidString, privacy: .public) dest=\(stagedURL.lastPathComponent, privacy: .public)"
                        )

                        let job = ImportJob(
                            id: jobID,
                            identifiers: identifiers,
                            contextData: contextData,
                            source: placeholderSource,
                            phase: .queued,
                            progress: nil,
                            tempPath: stagedURL.path,
                            createdAt: createdAt,
                            updatedAt: Date(),
                            failure: nil
                        )
                        await MainActor.run {
                            if self.importStore.jobs.first(where: { $0.id == jobID })?.phase != .canceled {
                                self.enqueueImportJob(job)
                            }
                        }
                    } catch {
                        ImportLog.files.error(
                            "video staging failed job=\(jobID.uuidString, privacy: .public) error=\(error.localizedDescription, privacy: .public)"
                        )
                        FilePickerCopy.cleanupStagedFileIfNeeded(stagedURL)
                        let failure = ImportFailure(code: .copyFailed, message: error.localizedDescription)
                        let failedJob = ImportJob(
                            id: jobID,
                            identifiers: identifiers,
                            contextData: contextData,
                            source: placeholderSource,
                            phase: .failed,
                            progress: nil,
                            tempPath: stagedURL.path,
                            createdAt: createdAt,
                            updatedAt: Date(),
                            failure: failure
                        )
                        await MainActor.run {
                            self.importStore.registerEnqueuedJob(failedJob)
                            self.videoImportErrorMessage = error.localizedDescription
                            self.showVideoImportErrorAlert = true
                        }
                    }
                }
            }

        case .failure(let error):
            print("❌ File import failed: \(error)")
            ImportLog.files.error("handleVideoImport failed error=\(error.localizedDescription, privacy: .public)")
            videoImportErrorMessage = error.localizedDescription
            showVideoImportErrorAlert = true
            isUploadingVideo = false
        }
    }
    
    private func handlePhotoPickerSelection(_ items: [PhotosPickerItem]) {
        guard
            !items.isEmpty,
            let context = pendingVideoUploadContext
        else { return }

        isUploadingVideo = true
        let contextData = makeImportContextData()

        Task {
            defer {
                Task { @MainActor in
                    isUploadingVideo = false
                    photoPickerItems = []
                    pendingVideoUploadContext = nil
                }
            }

            for item in items {
                let ext = item.supportedContentTypes.first?.preferredFilenameExtension ?? "mov"
                let identifiers = prepareImportIdentifiers(for: context, fileExtension: ext)
                let jobID = UUID()
                let createdAt = Date()
                let placeholderURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent("\(jobID.uuidString).\(ext)")
                let placeholderSource = ImportSource.localFile(
                    url: placeholderURL,
                    originalFilename: identifiers.fileName
                )
                let placeholderJob = ImportJob(
                    id: jobID,
                    identifiers: identifiers,
                    contextData: contextData,
                    source: placeholderSource,
                    phase: .preparing,
                    progress: nil,
                    tempPath: nil,
                    createdAt: createdAt,
                    updatedAt: createdAt,
                    failure: nil
                )
                await MainActor.run {
                    importStore.registerEnqueuedJob(placeholderJob)
                }
                if item.itemIdentifier == nil {
                    var updatedPlaceholder = placeholderJob
                    updatedPlaceholder.phase = .downloading
                    updatedPlaceholder.updatedAt = Date()
                    await MainActor.run {
                        importStore.registerEnqueuedJob(updatedPlaceholder)
                    }
                }
                do {
                    if let identifier = item.itemIdentifier {
                        let source = ImportSource.photos(
                            localIdentifier: identifier,
                            suggestedExtension: ext
                        )
                        let job = ImportJob(
                            id: jobID,
                            identifiers: identifiers,
                            contextData: contextData,
                            source: source,
                            phase: .queued,
                            progress: nil,
                            tempPath: nil,
                            createdAt: createdAt,
                            updatedAt: Date(),
                            failure: nil
                        )
                        await MainActor.run {
                            if importStore.jobs.first(where: { $0.id == jobID })?.phase != .canceled {
                                enqueueImportJob(job)
                            }
                        }
                    } else if let movie = try await item.loadTransferable(type: MovieImport.self) {
                        let source = ImportSource.localFile(
                            url: movie.url,
                            originalFilename: movie.url.lastPathComponent
                        )
                        let job = ImportJob(
                            id: jobID,
                            identifiers: identifiers,
                            contextData: contextData,
                            source: source,
                            phase: .queued,
                            progress: nil,
                            tempPath: nil,
                            createdAt: createdAt,
                            updatedAt: Date(),
                            failure: nil
                        )
                        await MainActor.run {
                            if importStore.jobs.first(where: { $0.id == jobID })?.phase != .canceled {
                                enqueueImportJob(job)
                            }
                        }
                    } else {
                        throw ImportFailure(code: .downloadFailed, message: "Unable to access the selected video.")
                    }
                } catch {
                    print("❌ PhotosPicker load failed: \(error)")
                    let failure = ImportFailure(code: .downloadFailed, message: error.localizedDescription)
                    let failedJob = ImportJob(
                        id: jobID,
                        identifiers: identifiers,
                        contextData: contextData,
                        source: placeholderSource,
                        phase: .failed,
                        progress: nil,
                        tempPath: nil,
                        createdAt: createdAt,
                        updatedAt: Date(),
                        failure: failure
                    )
                    await MainActor.run {
                        importStore.registerEnqueuedJob(failedJob)
                    }
                }
            }
        }
    }

    private func handleKeyframeFileImport(_ result: Result<[URL], Error>) {
        guard let context = pendingKeyframePhotoUploadContext else {
            print("⚠️ No pending context for keyframe photo import")
            return
        }

        pendingKeyframePhotoUploadContext = nil
        showKeyframeUploadSourceSheet = false

        switch result {
        case .success(let urls):
            ImportLog.files.info(
                "handleKeyframeFileImport urls=\(urls.count) scene=\(context.sceneNumber)"
            )
            for url in urls {
                ImportLog.files.info(
                    "keyframe file selected name=\(url.lastPathComponent, privacy: .public) ext=\(url.pathExtension, privacy: .public) scheme=\(url.scheme ?? "nil", privacy: .public)"
                )
            }
            let contextData = makeImportContextData()
            Task.detached(priority: .userInitiated) {
                for pickedURL in urls {
                    let ext = pickedURL.pathExtension.isEmpty ? "jpg" : pickedURL.pathExtension
                    let identifiers = await MainActor.run {
                        self.prepareKeyframePhotoIdentifiers(
                            sceneNumber: context.sceneNumber,
                            fileExtension: ext
                        )
                    }
                    let jobID = UUID()
                    let createdAt = Date()
                    let stagedURL = FilePickerCopy.stagingURL(jobID: jobID, fileExtension: ext)
                    let placeholderSource = ImportSource.localFile(
                        url: stagedURL,
                        originalFilename: identifiers.fileName
                    )
                    let placeholderJob = ImportJob(
                        id: jobID,
                        identifiers: identifiers,
                        contextData: contextData,
                        source: placeholderSource,
                        phase: .preparing,
                        progress: nil,
                        tempPath: stagedURL.path,
                        createdAt: createdAt,
                        updatedAt: createdAt,
                        failure: nil
                    )
                    await MainActor.run {
                        self.importStore.registerEnqueuedJob(placeholderJob)
                    }

                    do {
                        var copyingJob = placeholderJob
                        copyingJob.phase = .copying
                        copyingJob.updatedAt = Date()
                        let copyingSnapshot = copyingJob
                        await MainActor.run {
                            self.importStore.registerEnqueuedJob(copyingSnapshot)
                        }

                        try FilePickerCopy.copyToTemp(from: pickedURL, to: stagedURL)
                        ImportLog.files.info(
                            "staged keyframe job=\(jobID.uuidString, privacy: .public) dest=\(stagedURL.lastPathComponent, privacy: .public)"
                        )

                        let job = ImportJob(
                            id: jobID,
                            identifiers: identifiers,
                            contextData: contextData,
                            source: placeholderSource,
                            phase: .queued,
                            progress: nil,
                            tempPath: stagedURL.path,
                            createdAt: createdAt,
                            updatedAt: Date(),
                            failure: nil
                        )
                        await MainActor.run {
                            if self.importStore.jobs.first(where: { $0.id == jobID })?.phase != .canceled {
                                self.enqueueImportJob(job)
                            }
                        }
                    } catch {
                        ImportLog.files.error(
                            "keyframe staging failed job=\(jobID.uuidString, privacy: .public) error=\(error.localizedDescription, privacy: .public)"
                        )
                        FilePickerCopy.cleanupStagedFileIfNeeded(stagedURL)
                        let failure = ImportFailure(code: .copyFailed, message: error.localizedDescription)
                        let failedJob = ImportJob(
                            id: jobID,
                            identifiers: identifiers,
                            contextData: contextData,
                            source: placeholderSource,
                            phase: .failed,
                            progress: nil,
                            tempPath: stagedURL.path,
                            createdAt: createdAt,
                            updatedAt: Date(),
                            failure: failure
                        )
                        await MainActor.run {
                            self.importStore.registerEnqueuedJob(failedJob)
                            self.importErrorMessage = error.localizedDescription
                            self.showImportErrorAlert = true
                        }
                    }
                }
            }

        case .failure(let error):
            print("❌ Keyframe photo import file selection failed: \(error)")
            ImportLog.files.error("handleKeyframeFileImport failed error=\(error.localizedDescription, privacy: .public)")
            showKeyframeUploadSourceSheet = false
        }
    }

    private func handleKeyframePhotoPickerSelection(_ items: [PhotosPickerItem]) {
        guard
            !items.isEmpty,
            let context = pendingKeyframePhotoUploadContext
        else {
            return
        }

        Task.detached(priority: .userInitiated) {
            let project = await self.currentProject
            let session = await self.currentSession
            let repository = await self.repository
            let sceneNumber = context.sceneNumber

            do {
                try await KeyframePhotoUploadIO.importKeyframePhotosFromPhotoPickerItems(
                    items,
                    sceneNumber: sceneNumber,
                    project: project,
                    session: session,
                    repository: repository
                )

                await MainActor.run {
                    self.pendingKeyframePhotoUploadContext = nil
                    self.keyframePhotoPickerItems = []
                    self.showKeyframePhotoPicker = false
                    self.showKeyframeUploadSourceSheet = false
                    self.reloadSessionData()
                }
            } catch {
                await MainActor.run {
                    print("❌ Keyframe photo import (Photos) failed: \(error)")
                    self.pendingKeyframePhotoUploadContext = nil
                    self.keyframePhotoPickerItems = []
                    self.showKeyframePhotoPicker = false
                    self.showKeyframeUploadSourceSheet = false
                }
            }
        }
    }
    
    private func enqueueImportJob(source: ImportSource, context: VideoUploadContext, fileExtension: String) {
        let identifiers = prepareImportIdentifiers(for: context, fileExtension: fileExtension)
        let job = ImportJob(
            id: UUID(),
            identifiers: identifiers,
            contextData: makeImportContextData(),
            source: source,
            phase: .queued,
            progress: nil,
            tempPath: nil,
            createdAt: Date(),
            updatedAt: Date(),
            failure: nil
        )
        enqueueImportJob(job)
    }

    private func enqueueImportJob(_ job: ImportJob) {
        importStore.registerEnqueuedJob(job)
        Task { await ImportQueue.shared.enqueue(job) }
    }

    private func makeImportContextData() -> ImportContextData {
        ImportContextData(
            projectID: currentProject.id,
            sessionID: currentSession.id,
            projectTitle: currentProject.title,
            roleName: currentProject.roles.first?.name
        )
    }
    
    private func prepareImportIdentifiers(for context: VideoUploadContext, fileExtension: String) -> ImportIdentifiers {
        let sanitizedExtension = fileExtension.isEmpty ? "mov" : fileExtension.lowercased()
        let sceneNumber = max(1, context.sceneNumber)
        let baseTakeNumber = repository.nextTakeNumber(for: sceneNumber, in: currentSession.id, in: currentProject.id)
        let pendingTakeCount = importStore.jobs.filter {
            $0.contextData.sessionID == currentSession.id
            && $0.identifiers.sceneNumber == sceneNumber
            && !$0.identifiers.isSlate
            && !$0.isFinished
        }.count
        let takeNumber = baseTakeNumber + pendingTakeCount
        
        var slateNumber = context.slateNumber
        var slateID = context.slateID
        if context.isSlate, slateNumber == nil {
            let baseSlate = repository.nextSlateNumber(in: currentSession.id, in: currentProject.id)
            let pendingSlateCount = importStore.jobs.filter {
                $0.contextData.sessionID == currentSession.id
                && $0.identifiers.isSlate
                && !$0.isFinished
            }.count
            let next = baseSlate + pendingSlateCount
            slateNumber = "\(next)"
            slateID = "SLATE\(next)"
        } else if context.isSlate, slateID == nil, let number = slateNumber {
            if number.uppercased().hasPrefix("SLATE") {
                slateID = number.uppercased()
            } else {
                slateID = "SLATE\(number)"
            }
        }
        
        let timestamp = Int(Date().timeIntervalSince1970)
        let projectPrefix = String(currentProject.id.uuidString.prefix(8))
        let sessionPrefix = String(currentSession.id.uuidString.prefix(8))
        let baseName: String
        if context.isSlate {
            let identifier = slateID ?? "SLATE\(slateNumber ?? "\(takeNumber)")"
            baseName = "\(projectPrefix)_\(sessionPrefix)_\(identifier)_U\(timestamp)"
        } else {
            baseName = "\(projectPrefix)_\(sessionPrefix)_S\(sceneNumber)T\(takeNumber)_U\(timestamp)"
        }
        
        let fileName = "\(baseName).\(sanitizedExtension)"
        
        return ImportIdentifiers(
            fileName: fileName,
            sceneNumber: sceneNumber,
            takeNumber: takeNumber,
            slateNumber: slateNumber,
            slateID: slateID,
            isSlate: context.isSlate,
            isKeyframePhoto: false
        )
    }

    private func prepareKeyframePhotoIdentifiers(sceneNumber: Int, fileExtension: String) -> ImportIdentifiers {
        let cleanExt = fileExtension.isEmpty ? "jpg" : fileExtension.lowercased()
        let baseTakeNumber = keyframeTakes.map { $0.takeNumber }.max() ?? 0
        let pendingCount = importStore.jobs.filter {
            $0.contextData.sessionID == currentSession.id
            && $0.contextData.projectID == currentProject.id
            && $0.identifiers.isKeyframePhoto
            && !$0.isFinished
        }.count
        let takeNumber = baseTakeNumber + pendingCount + 1
        let fileName = "KeyframePhoto_scene\(sceneNumber)_\(UUID().uuidString.prefix(8)).\(cleanExt)"

        return ImportIdentifiers(
            fileName: fileName,
            sceneNumber: sceneNumber,
            takeNumber: takeNumber,
            slateNumber: nil,
            slateID: nil,
            isSlate: false,
            isKeyframePhoto: true
        )
    }
    
    private func allDocumentReferences() -> [CombinedDocumentView.DocumentReference] {
        var refs: [CombinedDocumentView.DocumentReference] = []
        if let sides = documentReference(for: .sides) {
            refs.append(sides)
        }
        if let breakdown = documentReference(for: .breakdown) {
            refs.append(breakdown)
        }
        return refs
    }
    
    private func documentReference(for type: DocumentUploadKind) -> CombinedDocumentView.DocumentReference? {
        switch type {
        case .sides:
            guard let fileName = effectiveSidesFileName,
                  let url = resolveDocumentURL(named: fileName) else { return nil }
            return CombinedDocumentView.DocumentReference(
                url: url,
                title: "Sides",
                type: .sides
            )
        case .breakdown:
            if let fileName = effectiveBreakdownFileName,
               let url = resolveDocumentURL(named: fileName) {
                return CombinedDocumentView.DocumentReference(
                    url: url,
                    title: "Breakdown",
                    type: .breakdown
                )
            }
            if let notes = effectiveBreakdownNotes,
               let tempURL = writeTemporaryDocument(named: "Breakdown-\(currentProject.id.uuidString).txt", contents: notes) {
                return CombinedDocumentView.DocumentReference(
                    url: tempURL,
                    title: "Breakdown Notes",
                    type: .breakdown
                )
            }
            return nil
        }
    }
    
    private func saveBreakdownNotesDraft() {
        let trimmed = breakdownNotesDraft.slateTrimmedNonEmpty
        currentSession.breakdownNotes = trimmed
        persistSessionChanges()
        breakdownNotesDraft = trimmed ?? ""
        isEditingBreakdownNotes = trimmed == nil
    }
    
    private func persistSessionChanges() {
        repository.updateSession(currentSession, in: currentProject.id)
        reloadSessionData()
    }

    private var disclosurePrefsKey: String {
        TakeReviewDisclosurePrefs.key(
            projectID: currentProject.id,
            sessionID: currentSession.id
        )
    }

    private var ratingFilterPrefsKey: String {
        TakeReviewRatingFilterPrefs.key(
            projectID: currentProject.id,
            sessionID: currentSession.id
        )
    }

    @MainActor
    private func loadDisclosurePrefs() {
        didLoadDisclosurePrefs = false
        let prefs = TakeReviewDisclosurePrefs.load(
            projectID: currentProject.id,
            sessionID: currentSession.id
        )
        isBreakdownExpanded = prefs.breakdownExpanded
        isDeliverablesExpanded = prefs.deliverablesExpanded
        showInlinePIPEditor = prefs.pipEditorExpanded
        didLoadDisclosurePrefs = true
    }

    private func persistDisclosurePrefs(
        breakdownExpanded: Bool,
        deliverablesExpanded: Bool,
        pipEditorExpanded: Bool
    ) {
        let prefs = TakeReviewDisclosurePrefs(
            breakdownExpanded: breakdownExpanded,
            deliverablesExpanded: deliverablesExpanded,
            pipEditorExpanded: pipEditorExpanded
        )
        TakeReviewDisclosurePrefs.save(
            prefs,
            projectID: currentProject.id,
            sessionID: currentSession.id
        )
    }

    @MainActor
    private func loadRatingFilterPrefs() {
        didLoadRatingFilterPrefs = false
        let prefs = TakeReviewRatingFilterPrefs.load(
            projectID: currentProject.id,
            sessionID: currentSession.id
        )
        let selections = prefs.ratingFilters.compactMap { TakeRatingFilter.fromPersistenceKey($0) }
        ratingFilterSelections = Set(selections)
        didLoadRatingFilterPrefs = true
    }

    private func persistRatingFilterPrefs(_ selections: Set<TakeRatingFilter>) {
        let prefs = TakeReviewRatingFilterPrefs(
            ratingFilters: selections.map { $0.persistenceKey }.sorted()
        )
        TakeReviewRatingFilterPrefs.save(
            prefs,
            projectID: currentProject.id,
            sessionID: currentSession.id
        )
    }
    
    private var documentImportTypes: [UTType] {
        [.pdf, .plainText, .image, .jpeg, .png]
    }
    
    private var videoImportTypes: [UTType] {
        var types: [UTType] = [.movie, .video]
        if #available(iOS 15.0, *) {
            types.append(.mpeg4Movie)
        } else if let mp4 = UTType(filenameExtension: "mp4") {
            types.append(mp4)
        }
        return types
    }
    
    private var keyframeImageImportTypes: [UTType] {
        var types: [UTType] = [.image, .jpeg, .png]
        if #available(iOS 14.0, *) {
            types.append(.heic)
        }
        return types
    }

    private var filesImporterAllowedTypes: [UTType] {
        switch pendingFileImporter {
        case .filesVideo:
            return videoImportTypes
        case .filesKeyframePhoto:
            return keyframeImageImportTypes
        case .document:
            return documentImportTypes
        case .none:
            return [.movie]
        }
    }

    private var filesImporterAllowsMultiple: Bool {
        switch pendingFileImporter {
        case .filesVideo, .filesKeyframePhoto:
            return true
        case .document:
            return false
        case .none:
            return false
        }
    }

    private func toNavViewType(_ viewType: ViewType) -> NavigationContextManager.ViewType {
        switch viewType {
        case .scenes:
            return .scenes
        case .slates:
            return .slates
        case .keyframes:
            return .keyframes
        case .deliverables:
            return .scenes
        }
    }
    
    private func fromNavViewType(_ viewType: NavigationContextManager.ViewType) -> ViewType {
        switch viewType {
        case .scenes:
            return .scenes
        case .slates:
            return .slates
        case .keyframes, .photos:
            return .keyframes
        }
    }

    @discardableResult
    private func applyNavigationContext(_ ctx: NavigationContext) -> Bool {
        selectedViewType = fromNavViewType(ctx.viewType)
        selectedSceneNumber = max(1, ctx.sceneNumber)
        return true
    }
    
    private func applyPreferredNavigationContextIfAvailable() {
        let prioritized: [NavigationContextManager.SourceView] = [.cameraCapture, .sessionTakesModal, .takeReview, .player]
        var applied = false
        while let ctx = navCtx.preferredContext(sessionID: currentSession.id,
                                                projectID: currentProject.id,
                                                prioritizedSources: prioritized) {
            if applyNavigationContext(ctx) {
                navCtx.removeContext(id: ctx.id)
                applied = true
                break
            } else {
                navCtx.removeContext(id: ctx.id)
            }
        }
        if !applied && !hasPreservedState {
            selectedSceneNumber = getLastSceneWithTakes()
        }
    }

    // MARK: - Actions
    private func handleExportAndShare() {
        withAnimation(Theme.Animation.smooth) { isExporting = true }
        let enhancedTakes = convertSessionToEnhancedTakes(currentSession)
        exportManagerData = ExportManagerData(
            project: currentProject,
            session: currentSession,
            takes: enhancedTakes,
            repository: repository
        )
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(Theme.Animation.smooth) { isExporting = false }
        }
    }
    private func handleResumeSession() {
        if isReadOnly {
            showArchivedAlert = true
            return
        }
        navCtx.clearContexts(source: .takeReview,
                             sessionID: currentSession.id,
                             projectID: currentProject.id)
        navCtx.preserveFromTakeReview(
            viewType: toNavViewType(selectedViewType),
            scene: selectedSceneNumber,
            sessionID: currentSession.id,
            projectID: currentProject.id
        )
        let targetScene = max(1, selectedSceneNumber)
        SessionManager.shared.restoreSceneState(sceneNumber: targetScene)
        switch selectedViewType {
        case .keyframes:
            SessionManager.shared.switchToKeyframePhotoMode()
        case .slates:
            SessionManager.shared.switchToSlateMode()
        default:
            SessionManager.shared.switchToSceneMode()
        }
        CameraCapturePresenter.present(
            project: currentProject,
            session: currentSession,
            sidesURL: effectiveSidesURL,
            breakdownURL: effectiveBreakdownURL,
            sidesFileName: effectiveSidesFileName,
            breakdownFileName: effectiveBreakdownFileName,
            navContext: navCtx,
            autoPresentSlatePrompt: selectedViewType == .slates,
            debugSource: "TakeReviewPage.handleResumeSession",
            onComplete: {
                print("📸 Camera session complete, TakeReviewPage will reload now")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    scheduleSessionReload(throttle: 0.0)
                }
            }
        )
    }
    private func getLastSceneWithTakes() -> Int {
        let sceneNumbers = Set(currentSession.takes.filter { $0.takeType == .regular }.map { $0.sceneNumber })
        return sceneNumbers.max() ?? 1
    }
    private func handleTakeAction(_ action: TakeAction, for take: ProjectTake, isFromDeliverables: Bool = false) {
        switch action {
        case .play:
            if take.takeType == .pipSlate {
                launchVideoPlayerViaParent(for: take, forceOriginal: false, isFromDeliverables: isFromDeliverables)
            } else if isPhotoTake(take) {
                // CRITICAL FIX: Launch SwipeableMediaPlayerView for proper photo handling
                launchSwipeablePlayer(for: take, isFromDeliverables: isFromDeliverables)
            } else {
                launchVideoPlayerViaParent(for: take, forceOriginal: false, isFromDeliverables: isFromDeliverables)
            }
        case .playOriginal:
            launchVideoPlayerViaParent(for: take, forceOriginal: true, isFromDeliverables: isFromDeliverables)
        case .share:
            handleShareAction(for: take)
        case .deleteTake:
            takeToDelete = take; showingDeleteConfirmation = true
        case .setRating(_):
#if DEBUG
            print("🧪 RatingSource=TakeReviewList session=\(currentSession.id) take=\(take.id)")
#endif
            onTakeAction(action, take)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { reloadSessionData() }
        default:
            onTakeAction(action, take)
        }
    }
    
    // MARK: - Deliverable submission handling

    /// Opens a confirmation alert before toggling the submitted state of a deliverable.
    private func requestDeliverableSubmissionToggle(for take: ProjectTake, isSubmitted: Bool) {
        pendingSubmissionTake = take
        pendingSubmissionTargetState = isSubmitted
        showingSubmissionAlert = true
    }

    /// Actually applies the submitted/unsubmitted state and persists it.
    private func handleDeliverableSubmissionToggle(for take: ProjectTake, isSubmitted: Bool) {
        var updated = take
        updated.submittedAt = isSubmitted ? Date() : nil
        
        // Update local session takes
        if let idx = currentSession.takes.firstIndex(where: { $0.id == updated.id }) {
            currentSession.takes[idx] = updated
        }
        if let sessionIndex = currentProject.sessions.firstIndex(where: { $0.id == currentSession.id }) {
            currentProject.sessions[sessionIndex].takes = currentSession.takes
        }
        
        // Persist to repository
        repository.updateTake(updated, in: currentSession.id, in: currentProject.id)
        
        // Inform parent listeners
        onTakeAction(.setSubmitted(updated), updated)
    }

    // MARK: - Deliverable video info

    /// Called from the deliverables menu to show a quick info summary.
    private func showVideoInfo(for take: ProjectTake) {
        // Remember which take we're working on; do not show the alert yet.
        infoAlertTake = take

        Task {
            // Centralized URL resolution + logging
            let url = VideoInfoPathResolver.resolveURL(for: take)

            let details = await VideoInfoHelper.buildMessage(
                for: take,
                fileURL: url,
                cameraSettings: nil,
                audioSettings: nil
            )
            await MainActor.run {
                // Only update if we're still looking at the same take
                guard infoAlertTake?.id == take.id else { return }

                // Always replace the text with *something* before presenting
                let message = details.message.trimmingCharacters(in: .whitespacesAndNewlines)
                infoAlertMessage = message.isEmpty ? "No video information available." : message

                // Present the alert after the final message is ready
                showingInfoAlert = true

                print("📹 TakeReviewPage.showVideoInfo: Presenting alert for take \(take.id)")
            }
        }
    }

    private func isPhotoTake(_ take: ProjectTake) -> Bool {
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
    // CRITICAL FIX: Launch SwipeableMediaPlayerView instead of onVideoPlayerRequest for proper photo handling
    private func launchSwipeablePlayer(for selectedTake: ProjectTake, isFromDeliverables: Bool = false) {
        let contextTakes = isFromDeliverables ? deliverables : getContextualSwipeableTakes()
        let initialIndex = contextTakes.firstIndex(where: { $0.id == selectedTake.id }) ?? 0
        
        navCtx.preserveFromTakeReview(
            viewType: toNavViewType(isFromDeliverables ? .deliverables : selectedViewType),
            scene: selectedSceneNumber,
            takeIndex: initialIndex,
            sessionID: currentSession.id,
            projectID: currentProject.id
        )
        
        onVideoPlayerRequest(
            contextTakes,
            initialIndex,
            isFromDeliverables ? .deliverables : selectedViewType,
            selectedViewType == .scenes ? selectedSceneNumber : nil,
            true
        )
        
        print("🎬 TakeReviewPage: Launching SwipeableMediaPlayerView with \(contextTakes.count) contextual takes, starting at index \(initialIndex)")
    }
    
    private func launchVideoPlayerViaParent(for selectedTake: ProjectTake, forceOriginal: Bool = false, isFromDeliverables: Bool = false) {
        let contextTakes = isFromDeliverables ? deliverables : getContextualSwipeableTakes()
        let initialIndex = contextTakes.firstIndex(where: { $0.id == selectedTake.id }) ?? 0
        navCtx.preserveFromTakeReview(
            viewType: toNavViewType(isFromDeliverables ? .deliverables : selectedViewType),
            scene: selectedSceneNumber,
            takeIndex: initialIndex,
            sessionID: currentSession.id,
            projectID: currentProject.id
        )
        onVideoPlayerRequest(
            contextTakes,
            initialIndex,
            isFromDeliverables ? .deliverables : selectedViewType,
            selectedViewType == .scenes ? selectedSceneNumber : nil,
            false
        )
    }
    private func getContextualSwipeableTakes() -> [ProjectTake] {
        switch selectedViewType {
        case .scenes: return sceneRegularTakes.filter { $0.sceneNumber == selectedSceneNumber }
        case .slates: return slateTakes
        case .keyframes: return keyframeTakes
        case .deliverables: return deliverables
        }
    }
    
    private func convertSessionToEnhancedTakes(_ session: ProjectSession) -> [EnhancedTake] {
        return session.takes.enumerated().map { index, take in
            EnhancedTake(
                fileName: URL(fileURLWithPath: take.filePath).lastPathComponent,
                projectID: currentProject.id,
                sessionID: session.id,
                filePath: take.filePath,
                duration: take.durationSeconds,
                fileSize: estimateFileSize(for: take.filePath),
                cameraPosition: "back",
                sceneNumber: 1,
                takeNumber: index + 1,
                isSlate: take.takeType.isSlateLike,
                createdAt: take.createdAt
            )
        }
    }
    private func estimateFileSize(for filePath: String) -> Int64 {
        if FileManager.default.fileExists(atPath: filePath) {
            do { return (try FileManager.default.attributesOfItem(atPath: filePath))[.size] as? Int64 ?? 0 }
            catch { return 0 }
        }
        return 0
    }
    private func getRoleName() -> String? {
        if let n = currentSession.roleName, !n.isEmpty { return n }
        if let first = currentProject.roles.first { return first.name }
        return nil
    }
    
    // MARK: - Nested Views
    private struct PendingImportRowView: View {
        let job: ImportJob
        let theme: STSTheme
        let accent: Color
        let onCancel: () -> Void
        let onRetry: () -> Void

        var body: some View {
            TimelineView(.periodic(from: .now, by: 1.0)) { context in
                let elapsed = max(0, context.date.timeIntervalSince(job.createdAt))
                VStack(alignment: .leading, spacing: Theme.Layout.tinyPadding) {
                    HStack(spacing: Theme.Layout.compactPadding) {
                        Image(systemName: iconName)
                            .font(.caption)
                            .foregroundStyle(accent)
                            .padding(8)
                            .background(
                                Circle()
                                    .fill(accent.opacity(0.15))
                            )

                        VStack(alignment: .leading, spacing: 2) {
                            Text(titleText)
                                .font(Theme.Font.cardSubtitle)
                                .foregroundStyle(theme.textPrimary)
                            Text(statusText)
                                .font(.caption2)
                                .foregroundStyle(theme.textSecondary)
                            if let detail = statusDetail(elapsed: elapsed) {
                                Text(detail)
                                    .font(.caption2)
                                    .foregroundStyle(theme.textSecondary)
                                    .lineLimit(1)
                            }
                        }

                        Spacer(minLength: 8)

                        if job.phase.isActive {
                            Button(action: onCancel) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            }
                            .buttonStyle(.plain)
                        } else if job.phase == .failed {
                            Button(action: onRetry) {
                                Image(systemName: "arrow.clockwise.circle.fill")
                                    .font(.caption)
                                    .foregroundStyle(theme.primaryAccent)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if job.phase.isActive || job.phase == .ready {
                        ImportProgressBar(
                            progress: progressValue,
                            isActive: job.phase.isActive,
                            accent: accent
                        )
                        if let progressLine = progressText(elapsed: elapsed) {
                            Text(progressLine)
                                .font(.caption2)
                                .foregroundStyle(theme.textSecondary)
                        }
                        if shouldShowKeepOpenHint(elapsed: elapsed) {
                            Text("Keep the app open while importing.")
                                .font(.caption2)
                                .foregroundStyle(theme.textSecondary)
                        }
                    }

                    if job.phase == .failed, let failure = job.failure {
                        Text(failure.message)
                            .font(.caption2)
                            .foregroundStyle(.red)
                            .lineLimit(2)
                    }
                }
                .padding(Theme.Layout.compactPadding)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(theme.cardBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(theme.cardStroke, lineWidth: 1)
                )
            }
        }

        private var iconName: String {
            if job.identifiers.isKeyframePhoto { return "camera" }
            return job.identifiers.isSlate ? "tv" : "video.fill"
        }

        private var titleText: String {
            if job.identifiers.isKeyframePhoto {
                let scene = max(1, job.identifiers.sceneNumber)
                return "Keyframe Photo (Scene \(scene))"
            }
            if job.identifiers.isSlate {
                if let slateNumber = job.identifiers.slateNumber?.slateTrimmedNonEmpty {
                    return "Slate \(slateNumber)"
                }
                if let slateID = job.identifiers.slateID?.slateTrimmedNonEmpty {
                    return slateID
                }
                return "Slate Import"
            }

            let scene = max(1, job.identifiers.sceneNumber)
            let take = max(1, job.identifiers.takeNumber)
            return "Scene \(scene) Take \(take)"
        }

        private var statusText: String {
            switch job.phase {
            case .queued:
                return "Queued"
            case .preparing:
                return "Preparing import"
            case .downloading:
                return isPhotosSource ? "Downloading from Photos" : "Downloading"
            case .copying:
                return "Copying file"
            case .saving, .processing:
                return "Copying into session"
            case .verifying:
                return "Finalizing"
            case .ready:
                return "Ready"
            case .failed:
                return "Import failed"
            case .canceled:
                return "Canceled"
            }
        }

        private func statusDetail(elapsed: TimeInterval) -> String? {
            guard job.phase.isActive else { return nil }
            switch job.phase {
            case .preparing:
                return elapsed > 6 ? "Setting up and checking access." : nil
            case .downloading:
                return elapsed > 6 ? "Large iCloud videos can take a few minutes." : nil
            case .saving, .processing:
                return elapsed > 6 ? "Saving video into the session." : nil
            case .verifying:
                return "Verifying file integrity."
            default:
                return nil
            }
        }

        private var progressValue: Double? {
            if job.phase == .ready { return 1.0 }
            return job.progress
        }

        private func progressText(elapsed: TimeInterval) -> String? {
            guard job.phase.isActive else { return nil }
            let elapsedText = formatDuration(elapsed)
            if let progress = job.progress, progress > 0, progress < 1 {
                let percent = Int(progress * 100)
                if let eta = etaText(progress: progress, elapsed: elapsed) {
                    return "\(percent)% · ~\(eta) remaining"
                }
                return "\(percent)% · \(elapsedText) elapsed"
            }
            return "Elapsed \(elapsedText)"
        }

        private func etaText(progress: Double, elapsed: TimeInterval) -> String? {
            guard progress > 0.03, progress < 0.98 else { return nil }
            let remaining = elapsed * (1.0 - progress) / progress
            guard remaining.isFinite, remaining > 0 else { return nil }
            return formatDuration(remaining)
        }

        private func shouldShowKeepOpenHint(elapsed: TimeInterval) -> Bool {
            job.phase.isActive && elapsed > 10
        }

        private func formatDuration(_ seconds: TimeInterval) -> String {
            let totalSeconds = max(Int(seconds.rounded()), 0)
            let minutes = totalSeconds / 60
            let remainingSeconds = totalSeconds % 60
            if minutes > 0 {
                return String(format: "%dm %02ds", minutes, remainingSeconds)
            }
            return "\(remainingSeconds)s"
        }

        private var isPhotosSource: Bool {
            if case .photos = job.source { return true }
            return false
        }
    }

    private struct ImportProgressBar: View {
        let progress: Double?
        let isActive: Bool
        let accent: Color

        var body: some View {
            GeometryReader { proxy in
                let width = proxy.size.width
                let height = proxy.size.height
                let base = Capsule()
                ZStack(alignment: .leading) {
                    base
                        .fill(accent.opacity(0.15))
                    if let progress, progress > 0 {
                        base
                            .fill(accent)
                            .frame(width: width * CGFloat(min(max(progress, 0), 1)))
                    } else if isActive {
                        TimelineView(.animation) { context in
                            let shimmerWidth = max(width * 0.35, 24)
                            let travel = width + shimmerWidth
                            let t = context.date.timeIntervalSinceReferenceDate
                            let progress = (t.truncatingRemainder(dividingBy: 1.6)) / 1.6
                            let x = (progress * travel) - shimmerWidth
                            LinearGradient(
                                colors: [
                                    accent.opacity(0.1),
                                    accent.opacity(0.6),
                                    accent.opacity(0.1)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                            .frame(width: shimmerWidth, height: height)
                            .clipShape(base)
                            .offset(x: x)
                        }
                    }
                }
            }
            .frame(height: 6)
        }
    }

    struct DeliverableRowView: View {
        let take: ProjectTake
        let takeNumber: Int
        let theme: STSTheme
        let isSubmitted: Bool
        let fileNameText: String?
        let fileSizeText: String?
        let durationText: String?
        let onPlay: () -> Void
        let onAction: (TakeAction) -> Void
        let onToggleSubmitted: () -> Void
        let onShare: () -> Void
        let onDelete: () -> Void
        let onShowInfo: () -> Void

        @Environment(\.horizontalSizeClass) private var horizontalSizeClass
        @Environment(\.verticalSizeClass) private var verticalSizeClass

        @State private var attentionScale: CGFloat = 1.0
        @State private var hasAnimatedAttention = false

        private var isSmartFillTake: Bool {
            take.isSmartFillVariant || take.smartFilledFilePath != nil
        }

        private var hasMetadataIcons: Bool {
            isSmartFillTake || take.hasEdits
        }

        private var metaText: String {
            [durationText, fileSizeText].compactMap { $0 }.joined(separator: " • ")
        }

        private var displayFileName: String? {
            guard let fileNameText else { return nil }
            let trimmed = fileNameText.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }

        private var primaryTitleText: String {
            displayFileName ?? deliverableTypeLabel
        }

        private var shouldShowTypeBadge: Bool {
            displayFileName != nil
        }

        private var prefersCompactLayout: Bool {
            horizontalSizeClass == .compact && verticalSizeClass == .regular
        }

        var body: some View {
            ViewThatFits(in: .horizontal) {
                if prefersCompactLayout {
                    compactBody
                    regularBody
                } else {
                    regularBody
                    compactBody
                }
            }
        }

        private var compactBody: some View {
            rowBody(isCompact: true)
        }

        private var regularBody: some View {
            rowBody(isCompact: false)
        }

        private func rowBody(isCompact: Bool) -> some View {
            HStack(spacing: Theme.Layout.compactPadding) {
                videoThumbnail

                VStack(alignment: .leading, spacing: 4) {
                    primaryLabel
                        .layoutPriority(2)

                    secondaryLine(isCompact: isCompact)
                        .layoutPriority(1)
                }
                .layoutPriority(1)

                if !isCompact {
                    Spacer(minLength: 0)
                }

                trailingActions(isCompact: isCompact)
                    .frame(width: actionColumnWidth(isCompact: isCompact), alignment: .trailing)
            }
            .padding(Theme.Layout.compactPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(effectiveRowBackgroundColor)
            )
            .scaleEffect(attentionScale)
            .onAppear {
                maybeAnimateAttentionIfNeeded()
            }
        }

        @ViewBuilder
        private func secondaryLine(isCompact: Bool) -> some View {
            HStack(spacing: 6) {
                if shouldShowTypeBadge {
                    deliverableTypeBadge(isCompact: isCompact)
                }

                if !metaText.isEmpty {
                    Text(metaText)
                        .font(Theme.Font.smallCaption)
                        .foregroundStyle(theme.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }

                if hasMetadataIcons && !isCompact {
                    Spacer(minLength: 0)
                    metadataIcons
                }
            }
        }

        @ViewBuilder private var videoThumbnail: some View {
            Button(action: onPlay) {
                ZStack {
                    ThumbnailPreviewView(
                        unifiedTake: createUnifiedTakeForThumbnail(),
                        quality: .small,
                        frameMode: .intro
                    )
                    .frame(width: 70, height: 42)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Layout.smallCornerRadius))

                    Image(systemName: "play.fill")
                        .font(.caption)
                        .foregroundStyle(.white)
                        .background(
                            Circle()
                                .fill(.black.opacity(0.6))
                                .frame(width: 24, height: 24)
                        )
                }
            }
            .buttonStyle(.plain)
        }

        private func createUnifiedTakeForThumbnail() -> UnifiedTake {
            UnifiedTake(
                id: take.id,
                fileName: URL(fileURLWithPath: take.filePath).lastPathComponent,
                projectID: UUID(),
                sessionID: UUID(),
                filePath: take.filePath,
                duration: take.durationSeconds,
                fileSize: 0,
                cameraPosition: "back",
                sceneNumber: take.sceneNumber == -1 ? 1 : take.sceneNumber,
                takeNumber: takeNumber,
                isSlate: take.isSlateLike,
                smartFilledFilePath: nil,
                rating: take.rating,
                createdAt: take.createdAt
            )
        }

        @ViewBuilder private var primaryLabel: some View {
            HStack(spacing: 6) {
                Text(primaryTitleText)
                    .foregroundStyle(theme.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .accessibilityLabel(Text(primaryTitleText))

                if isSubmitted {
                    submittedBadge
                }
            }
            .font(Theme.Font.cardSubtitle)
            .lineLimit(1)
            .minimumScaleFactor(0.9)
        }

        private var deliverableTypeLabel: String {
            switch take.takeType {
            case .merged:
                return "Merged Reel"
            case .exported:
                return "Single Clip"
            default:
                return "Deliverable"
            }
        }

        private func deliverableTypeLabel(isCompact: Bool) -> String {
            guard isCompact else { return deliverableTypeLabel }
            switch take.takeType {
            case .merged:
                return "Reel"
            case .exported:
                return "Clip"
            default:
                return "Deliverable"
            }
        }

        private var deliverableTypeColor: Color {
            switch take.takeType {
            case .merged:
                return .green
            case .exported:
                return .blue
            default:
                return theme.textSecondary
            }
        }

        private var deliverableTypeIconName: String? {
            switch take.takeType {
            case .merged:
                return "film.stack.fill"
            case .exported:
                return "square.and.arrow.up.fill"
            default:
                return nil
            }
        }

        @ViewBuilder private func deliverableTypeBadge(isCompact: Bool) -> some View {
            HStack(spacing: 4) {
                if let iconName = deliverableTypeIconName {
                    Image(systemName: iconName)
                        .font(.caption2.weight(.semibold))
                }

                Text(deliverableTypeLabel(isCompact: isCompact))
                    .font(Theme.Font.smallCaption.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)
                    .truncationMode(.tail)
                    .accessibilityLabel(Text(deliverableTypeLabel))
            }
            .foregroundStyle(deliverableTypeColor)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                Capsule()
                    .fill(theme.cardBackground)
            )
            .overlay(
                Capsule()
                    .stroke(theme.cardStroke, lineWidth: 1)
            )
        }

        @ViewBuilder private var metadataIcons: some View {
            HStack(spacing: 6) {
                if isSmartFillTake {
                    Image(systemName: "person.and.background.dotted")
                        .font(.caption)
                        .foregroundStyle(Color.cyan)
                }
                if take.hasEdits {
                    Image(systemName: "pencil.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
        }

        private func actionColumnWidth(isCompact: Bool) -> CGFloat {
            isCompact ? 68 : 72
        }

        private func trailingActions(isCompact: Bool) -> some View {
            VStack(alignment: .trailing, spacing: isCompact ? 6 : 10) {
                submitButton
                takeActionsMenu
            }
            .frame(maxHeight: .infinity, alignment: .center)
        }

        private var submitButton: some View {
            Button(action: onToggleSubmitted) {
                Image(systemName: "video.fill.badge.checkmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(isSubmitted ? theme.textPrimary.opacity(0.9) : .white)
                    .frame(width: 44, height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(isSubmitted ? theme.cardBackground : theme.primaryAccent.opacity(0.9))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(isSubmitted ? theme.cardStroke : Color.white.opacity(0.35), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isSubmitted ? "Unmark as submitted" : "Mark as submitted")
            .accessibilityHint("Pins this tape in your Project Lobby")
            .frame(minWidth: 44, minHeight: 44)
        }

        private var takeActionsMenu: some View {
            Menu {
                if isSmartFillTake {
                    Button {
                        onAction(.editSmartFill)
                    } label: {
                        Label("Edit SmartFill", systemImage: "person.and.background.dotted")
                    }
                }

                Button {
                    onShare()
                } label: {
                    Label("Share", systemImage: "square.and.arrow.up.fill")
                }

                Button {
                    onToggleSubmitted()
                } label: {
                    Label(
                        isSubmitted ? "Unmark Submitted" : "Mark as Submitted",
                        systemImage: "video.fill.badge.checkmark"
                    )
                }

                Button {
                    onShowInfo()
                } label: {
                    Label("View Video Info", systemImage: "info.circle")
                }

                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Delete", systemImage: "trash.fill")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(theme.textSecondary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("More actions")
        }

        /// Animates a small “bump” on unsubmitted deliverables the first time they appear.
        private func maybeAnimateAttentionIfNeeded() {
            guard !hasAnimatedAttention, !isSubmitted else { return }

            hasAnimatedAttention = true

            let animation = Animation.easeInOut(duration: 0.14)
                .repeatCount(3, autoreverses: true)

            withAnimation(animation) {
                attentionScale = 1.03
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.14 * 3.0) {
                attentionScale = 1.0
            }
        }

        /// Row background color that respects the submitted state for deliverables.
        private var effectiveRowBackgroundColor: Color {
            if isSubmitted {
                return Color("BrandPrimaryColor").opacity(0.18)
            }
            switch take.takeType {
            case .merged: return Color.green.opacity(0.08)
            case .exported: return Color.blue.opacity(0.08)
            default: return Color.white.opacity(0.03)
            }
        }

        private var submittedBadge: some View {
            HStack(spacing: 4) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.caption2)
                Text("Submitted")
                    .font(.caption2.weight(.semibold))
            }
            .foregroundStyle(theme.textSecondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                Capsule()
                    .fill(theme.cardBackground)
            )
            .overlay(
                Capsule()
                    .stroke(theme.cardStroke, lineWidth: 1)
            )
        }
    }

    struct TakeRowSimplified: View {
        let take: ProjectTake
        let takeNumber: Int
        let session: ProjectSession
        let theme: STSTheme
        let onAction: (TakeAction) -> Void
        let onDelete: () -> Void
        let onShare: () -> Void
        /// Optional callback for marking deliverables as submitted (used only for merged/exported takes).
        let onSubmittedToggle: ((Bool) -> Void)?
        /// Optional callback to show a quick “Video Info” summary for deliverables.
        let onShowInfo: (() -> Void)?

        init(
            take: ProjectTake,
            takeNumber: Int,
            session: ProjectSession,
            theme: STSTheme,
            onAction: @escaping (TakeAction) -> Void,
            onDelete: @escaping () -> Void,
            onShare: @escaping () -> Void,
            onSubmittedToggle: ((Bool) -> Void)? = nil,
            onShowInfo: (() -> Void)? = nil
        ) {
            self.take = take
            self.takeNumber = takeNumber
            self.session = session
            self.theme = theme
            self.onAction = onAction
            self.onDelete = onDelete
            self.onShare = onShare
            self.onSubmittedToggle = onSubmittedToggle
            self.onShowInfo = onShowInfo
        }

        // NEW: Subtle bump animation to draw attention to unsubmitted deliverables.
        @State private var attentionScale: CGFloat = 1.0
        @State private var hasAnimatedAttention = false
        
        private var sessionTakes: [ProjectTake] { session.takes }
        private var isSlateTake: Bool { take.isSlateLike }
        private var isPiPComposite: Bool { take.isPiPComposite }
        private var effectiveRating: TakeRating {
            SessionManager.shared.effectiveRating(for: take) ?? take.rating
        }
        
        var body: some View {
            VStack(spacing: 0) { mainTakeRow }
                .scaleEffect(attentionScale)
                .onAppear {
                    maybeAnimateAttentionIfNeeded()
                }
        }

        /// Animates a small “bump” on unsubmitted deliverables the first time they appear.
        private func maybeAnimateAttentionIfNeeded() {
            guard !hasAnimatedAttention,
                  isDeliverableTake,
                  !isSubmitted else { return }

            hasAnimatedAttention = true

            let animation = Animation.easeInOut(duration: 0.14)
                .repeatCount(3, autoreverses: true)

            withAnimation(animation) {
                attentionScale = 1.03
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.14 * 3.0) {
                attentionScale = 1.0
            }
        }
        
        @ViewBuilder private var mainTakeRow: some View {
            HStack(spacing: Theme.Layout.compactPadding) {
                VStack(alignment: .leading, spacing: 4) {
                    videoThumbnail
                    primaryLabel
                }

                takeInfoSecondary
                Spacer(minLength: 8)
                takeRatingActions
                takeActionsMenu
            }
            .padding(Theme.Layout.compactPadding)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(effectiveRowBackgroundColor)
            )
        }
        
        @ViewBuilder private var videoThumbnail: some View {
            Button { onAction(.play) } label: {
                ZStack {
                    Group {
                        if isPhotoTake {
                            if let url = resolvePhotoURL() {
                                AsyncImage(url: url) { image in
                                    image.resizable().aspectRatio(contentMode: .fill)
                                } placeholder: {
                                    photoPlaceholder
                                }
                            } else {
                                photoPlaceholder
                            }
                        } else {
                            ThumbnailPreviewView(
                                unifiedTake: createUnifiedTakeForThumbnail(),
                                quality: .small,
                                frameMode: thumbnailFrameMode
                            )
                        }
                    }
                    .frame(width: 70, height: 42)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Layout.smallCornerRadius))
                    if !isPhotoTake {
                        Image(systemName: "play.fill")
                            .font(.caption)
                            .foregroundStyle(.white)
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

        private var thumbnailFrameMode: ThumbnailFrameMode {
            switch take.takeType {
            case .merged, .exported:
                return .intro
            default:
                return .automatic
            }
        }
        
        private func createUnifiedTakeForThumbnail() -> UnifiedTake {
            UnifiedTake(
                id: take.id,
                fileName: URL(fileURLWithPath: take.filePath).lastPathComponent,
                projectID: UUID(),
                sessionID: UUID(),
                filePath: take.filePath,
                duration: take.durationSeconds,
                fileSize: 0,
                cameraPosition: "back",
                sceneNumber: take.sceneNumber == -1 ? 1 : take.sceneNumber,
                takeNumber: takeNumber,
                isSlate: isSlateTake,
                smartFilledFilePath: nil,
                rating: effectiveRating,
                createdAt: take.createdAt
            )
        }
        
        @ViewBuilder private var primaryLabel: some View {
            HStack(spacing: 6) {
                switch take.takeType {
                case .merged:
                    Image(systemName: "film.stack.fill").font(.caption)
                    Text("Merged Reel").foregroundStyle(.green)
                case .exported:
                    Image(systemName: "square.and.arrow.up.fill").font(.caption)
                    Text("Single Clip").foregroundStyle(.blue)
                case .pipSlate:
                    Image(systemName: "rectangle.on.rectangle").font(.caption)
                        .foregroundStyle(Color.pink)
                    Text("PiP Slate").foregroundStyle(theme.textPrimary)
                    if let n = take.slateNumber {
                        Text("(\(n))").font(.caption).foregroundStyle(theme.textSecondary)
                    }
                case .slate:
                    Image(systemName: "tv").font(.caption)
                    Text("Slate").foregroundStyle(theme.textPrimary)
                    if let n = take.slateNumber {
                        Text("(\(n))").font(.caption).foregroundStyle(theme.textSecondary)
                    }
                case .pipComponent:
                    EmptyView()
                case .regular:
                    if isPhotoTake {
                        Text("Photo \(takeNumber)").foregroundStyle(theme.textPrimary)
                    } else if take.sceneNumber > 1 {
                        Text("S\(take.sceneNumber)T\(takeNumber)").foregroundStyle(theme.textPrimary)
                    } else {
                        Text("Take \(takeNumber)").foregroundStyle(theme.textPrimary)
                    }
                }

                if isDeliverableTake && isSubmitted {
                    submittedBadge
                }
            }
            .font(Theme.Font.cardSubtitle)
            .lineLimit(1)
            .minimumScaleFactor(0.85)
        }

        @ViewBuilder private var takeInfoSecondary: some View {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    if !isPhotoTake {
                        Text(formattedDuration(take.effectiveDurationSeconds))
                            .font(Theme.Font.smallCaption)
                            .foregroundStyle(theme.textSecondary)
                    }

                    if let sizeText = deliverableFileSizeText {
                        Text(sizeText)
                            .font(Theme.Font.smallCaption)
                            .foregroundStyle(theme.textSecondary)
                    }

                    // Inline Submitted / Mark Submitted chip for deliverables
                    if isDeliverableTake, let onSubmittedToggle {
                        if !isSubmitted {
                            Button {
                                onSubmittedToggle(true)
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "video.fill.badge.checkmark")
                                        .font(.system(size: 11, weight: .semibold))

                                    Text("Submit")
                                        .font(Theme.Font.smallCaption)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(theme.cardBackground)
                                )
                                .overlay(
                                    Capsule()
                                        .stroke(theme.cardStroke, lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Mark as submitted")
                            .accessibilityHint("Pins this tape in your Project Lobby")
                        }
                    }

                    Spacer(minLength: 12)

                    HStack(spacing: 6) {
                        if isSmartFillTake {
                            Image(systemName: "person.and.background.dotted")
                                .font(.caption)
                                .foregroundStyle(Color.cyan)
                        }
                        if take.hasEdits {
                            Image(systemName: "pencil.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    }
                }
            }
        }
        
        private var isSmartFillTake: Bool {
            take.isSmartFillVariant || take.smartFilledFilePath != nil
        }
        
        private func getSmartFillDisplayName() -> String {
            friendlyDisplayName(for: take)
        }
        
        private func friendlyDisplayName(for take: ProjectTake) -> String {
            TakeDisplayFormatter.label(for: take, in: session)
        }
        
        private var isDeliverableTake: Bool {
            take.takeType == .merged || take.takeType == .exported
        }
        
        private var deliverableFileSizeText: String? {
            guard isDeliverableTake else { return nil }
            let primaryURL = URL(fileURLWithPath: take.filePath)
            let resolvedURL: URL
            if FileManager.default.fileExists(atPath: primaryURL.path) {
                resolvedURL = primaryURL
            } else {
                resolvedURL = VideoVariantResolver.urlForRelativePath(take.filePath)
            }
            if let size = try? resolvedURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                return ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
            }
            return nil
        }
        
        private var isSubmitted: Bool {
            take.submittedAt != nil
        }
        
        /// Row background color that respects the submitted state for deliverables.
        private var effectiveRowBackgroundColor: Color {
            if isDeliverableTake && isSubmitted {
                return Color("BrandPrimaryColor").opacity(0.18)
            }
            return takeRowBackgroundColor
        }

        private var submittedBadge: some View {
            HStack(spacing: 4) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.caption2)
                Text("Submitted")
                    .font(.caption2.weight(.semibold))
            }
            .foregroundStyle(theme.textSecondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                Capsule()
                    .fill(theme.cardBackground)
            )
            .overlay(
                Capsule()
                    .stroke(theme.cardStroke, lineWidth: 1)
            )
        }
        
        @ViewBuilder private var takeRatingActions: some View {
            if take.takeType == .regular || take.takeType.isSlateLike || isSmartFillTake {
                HStack(spacing: 8) {
                    Button { onAction(.setRating(effectiveRating == .finalSelect ? .unrated : .finalSelect)) } label: {
                        Image(systemName: effectiveRating == .finalSelect ? "star.fill" : "star")
                            .font(.caption).foregroundStyle(effectiveRating == .finalSelect ? .yellow : .gray).padding(6)
                    }
                    Button { onAction(.setRating(effectiveRating == .option ? .unrated : .option)) } label: {
                        Image(systemName: effectiveRating == .option ? "checkmark.circle.fill" : "checkmark.circle")
                            .font(.caption).foregroundStyle(effectiveRating == .option ? .green : .gray).padding(6)
                    }
                    Button { onAction(.setRating(effectiveRating == .rejected ? .unrated : .rejected)) } label: {
                        Image(systemName: "xmark.circle\(effectiveRating == .rejected ? ".fill" : "")")
                            .font(.caption).foregroundStyle(effectiveRating == .rejected ? .red : .gray).padding(6)
                    }
                }.buttonStyle(PlainButtonStyle())
            }
        }

        @ViewBuilder private var takeActionsMenu: some View {
            Menu {
                if isSmartFillTake {
                    Button {
                        onAction(.editSmartFill)
                    } label: {
                        Label("Edit SmartFill", systemImage: "person.and.background.dotted")
                    }
                }
                
                Button {
                    onShare()
                } label: {
                    Label("Share", systemImage: "square.and.arrow.up.fill")
                }

                if isDeliverableTake, let onSubmittedToggle {
                    Button {
                        onSubmittedToggle(!isSubmitted)
                    } label: {
                        Label(
                            isSubmitted ? "Unmark Submitted" : "Mark as Submitted",
                            systemImage: "video.fill.badge.checkmark"
                        )
                    }
                }

                if isDeliverableTake {
                    Button {
                        onShowInfo?()
                    } label: {
                        Label("View Video Info", systemImage: "info.circle")
                    }
                }
                
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Delete", systemImage: "trash.fill")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.caption)
                    .foregroundStyle(theme.primaryAccent)
                    .padding(6)
            }
            .accessibilityLabel("More actions")
        }        
        private var takeRowBackgroundColor: Color {
            if isSmartFillTake { return Color.cyan.opacity(0.06) }
            switch take.takeType {
            case .merged: return Color.green.opacity(0.08)
            case .exported: return Color.blue.opacity(0.08)
            case .slate: return Color.blue.opacity(0.05)
            case .pipSlate: return Color.pink.opacity(0.08)
            case .pipComponent: return Color.clear
            case .regular: return Color.white.opacity(0.03)
            }
        }
        private var isPhotoTake: Bool {
            guard take.durationSeconds == 0, !take.takeType.isSlateLike else { return false }
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

        private func resolvePhotoURL() -> URL? {
            if take.filePath.hasPrefix("/") {
                let url = URL(fileURLWithPath: take.filePath)
                return FileManager.default.fileExists(atPath: url.path) ? url : nil
            }
            let primary = VideoVariantResolver.urlForRelativePath(take.filePath)
            if FileManager.default.fileExists(atPath: primary.path) {
                return primary
            }
            let fallback = VideoVariantResolver.documentsURL().appendingPathComponent(URL(fileURLWithPath: take.filePath).lastPathComponent)
            if FileManager.default.fileExists(atPath: fallback.path) {
                return fallback
            }
            return nil
        }

        private var photoPlaceholder: some View {
            Rectangle()
                .fill(.gray.opacity(0.25))
                .overlay {
                    Image(systemName: "photo")
                        .font(.caption)
                        .foregroundStyle(.gray)
                }
        }
        private func formattedDuration(_ duration: TimeInterval) -> String {
            let m = Int(duration) / 60, s = Int(duration) % 60
            return String(format: "%d:%02d", m, s)
        }
    }
}



private struct BreakdownNotesEditorView: View {
    @Binding var draft: String
    let theme: STSTheme
    let primaryColor: Color
    let secondaryColor: Color
    let hasExistingNotes: Bool
    let onSave: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Add quick reminders about tone, stakes, wardrobe, or anything that keeps you grounded during shoots.")
                .font(.caption)
                .foregroundStyle(secondaryColor)
                .padding(.top, 4)

            TextEditor(text: $draft)
                .font(.system(size: 13))
                .foregroundStyle(primaryColor)
                .padding(8)
                .frame(minHeight: 120)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(theme.cardBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(theme.cardStroke, lineWidth: 1)
                        )
                )

            HStack {
                Button(action: onSave) {
                    Label("Save Notes", systemImage: "square.and.arrow.down")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.borderedProminent)
                .tint(theme.primaryAccent)
                .disabled(draft.slateTrimmedNonEmpty == nil)

                if hasExistingNotes {
                    Button("Cancel", action: onCancel)
                        .font(.caption)
                        .foregroundStyle(secondaryColor)
                }
            }
            .padding(.top, 4)
        }
    }
}

private extension UUID {
    var shortDescription: String {
        String(uuidString.prefix(8))
    }
}

// MARK: - First layout probe to safely hide processing overlay after UI is ready
private struct FirstLayoutProbe: View {
    let onReady: () -> Void
    @State private var didFire = false

    var body: some View {
        Color.clear
            .onAppear {
                guard !didFire else { return }
                didFire = true
                DispatchQueue.main.async {
                    DispatchQueue.main.async { // two runloop turns
                        onReady()
                    }
                }
            }
    }
}

private extension TakeReviewPage {
    @ViewBuilder
    var filterEmptyStateCard: some View {
        STSCard(elevation: .subtle) {
            VStack(spacing: Theme.Layout.compactPadding) {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .font(.system(size: 28))
                    .foregroundStyle(theme.textSecondary)

                Text("No takes match your filter")
                    .font(.headline)
                    .foregroundStyle(theme.textPrimary)

                Text("Clear filters to see every take.")
                    .font(.caption)
                    .foregroundStyle(theme.textSecondary)
                    .multilineTextAlignment(.center)

                Button {
                    clearRatingFilters()
                } label: {
                    Text("Clear filters")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(theme.primaryAccent.opacity(0.18))
                        )
                        .foregroundStyle(theme.primaryAccent)
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, Theme.Layout.smallPadding)
        }
    }

    var profileAvatarImage: Image? {
        guard let preferred = profileManager.profile.preferredHeadshot,
              let url = resolveHeadshotURL(named: preferred.fileName),
              let uiImage = UIImage(contentsOfFile: url.path) else {
            return nil
        }
        return Image(uiImage: uiImage)
    }
}

@MainActor

// MARK: - Enterprise Action Button
struct EnterpriseActionButton: View {
    let icon: String
    let label: String
    let style: ButtonStyle
    let isLoading: Bool
    let theme: STSTheme
    let action: () -> Void
    
    enum ButtonStyle { case primary, secondary }

    private var brandPrimary: Color {
        Color("BrandPrimaryColor")
    }

    private var isBrandedRecordButton: Bool {
        style == .secondary && icon == "video.badge.plus"
    }

    private var backgroundColor: AnyShapeStyle {
        if isBrandedRecordButton {
            let gradient = LinearGradient(
                colors: [
                    brandPrimary.opacity(0.95),
                    brandPrimary.opacity(0.8)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            return AnyShapeStyle(gradient)
        }
        switch style {
        case .primary: return AnyShapeStyle(theme.primaryButtonBackground)
        case .secondary: return AnyShapeStyle(theme.cardBackground)
        }
    }
    private var foregroundColor: Color {
        if isBrandedRecordButton { return .white }
        switch style {
        case .primary: return theme.primaryButtonForeground
        case .secondary: return theme.textSecondary
        }
    }
    private var borderColor: Color {
        if isBrandedRecordButton {
            return brandPrimary.opacity(0.8)
        }
        return theme.cardStroke
    }
    
    var body: some View {
        Button {
            if !isLoading {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                action()
            }
        } label: {
            HStack(spacing: Theme.Spacing.xs) {
                if isLoading { ProgressView().scaleEffect(0.8).tint(foregroundColor) }
                else { Image(systemName: icon).font(.system(size: 16, weight: .semibold)) }
                Text(isLoading ? "Processing..." : label).font(Theme.Font.buttonLabel).fontWeight(.medium)
            }
            .padding(.vertical, Theme.Layout.compactPadding)
            .padding(.horizontal, Theme.Layout.comfortablePadding)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: Theme.Layout.smallCornerRadius).fill(backgroundColor))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Layout.smallCornerRadius)
                    .stroke(borderColor, lineWidth: 1)
            )
            .foregroundColor(foregroundColor)
            .shadow(color: style == .primary ? Theme.Shadow.elevated.color : Theme.Shadow.subtle.color,
                    radius: Theme.Shadow.elevated.radius, x: 0, y: Theme.Shadow.elevated.y)
            .shadow(color: Theme.Shadow.small.color, radius: Theme.Shadow.small.radius, x: 0, y: Theme.Shadow.small.y)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isLoading)
    }
}
 
private extension TakeReviewPage {
    // BEGIN PATCH: PiPEmptySlateStateHelper
    @ViewBuilder
    var pipEmptySlateState: some View {
        STSCard(elevation: .subtle) {
            VStack(spacing: Theme.Layout.compactPadding) {
                Image(systemName: "rectangle.inset.filled.and.person.filled")
                    .font(.system(size: 32))
                    .foregroundStyle(.gray)

                Text("Create Picture-in-Picture Slate")
                    .font(.headline)
                    .foregroundStyle(theme.textPrimary)

                Text("Use the PiP editor below to combine your recorded clips into a finished slate. If you haven’t recorded PiP footage yet, record a Portrait + Landscape pair in the iTFactor Camera.")
                    .font(.caption)
                    .foregroundStyle(theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)
            }
            .padding(.vertical, Theme.Layout.smallPadding)
        }
    }
    // END PATCH: PiPEmptySlateStateHelper

    // BEGIN PATCH: SmartFillEmptySlateStateHelper
    @ViewBuilder
    var smartFillEmptySlateState: some View {
        STSCard(elevation: .subtle) {
            VStack(spacing: Theme.Layout.compactPadding) {
                Image(systemName: "person.and.background.dotted")
                    .font(.system(size: 32))
                    .foregroundStyle(.gray)

                Text("No SmartFill Slate Yet")
                    .font(.headline)
                    .foregroundStyle(theme.textPrimary)

                Text("SmartFill slates are created from your Original slates. Open an Original slate (recorded in Portrait/Vertical) in preview and tap the SmartFill icon to generate a SmartFill version.")
                    .font(.caption)
                    .foregroundStyle(theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)
            }
            .padding(.vertical, Theme.Layout.smallPadding)
        }
    }
    // END PATCH: SmartFillEmptySlateStateHelper

    // BEGIN PATCH: GenericSlateEmptyStateHelper
    @ViewBuilder
    var genericSlateEmptyState: some View {
        STSCard(elevation: .subtle) {
            VStack(spacing: Theme.Layout.compactPadding) {
                Image(systemName: "movieclapper")
                    .font(.system(size: 32))
                    .foregroundStyle(.gray)

                Text("No Original slates yet")
                    .font(.headline)
                    .foregroundStyle(theme.textPrimary)

                Text("Record one using the iTFactor Camera. Continue to PiP if you've already recorded a Portrait + Landscape pair.")
                    .font(.caption)
                    .foregroundStyle(theme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
        }
    }
    // END PATCH: GenericSlateEmptyStateHelper
}
