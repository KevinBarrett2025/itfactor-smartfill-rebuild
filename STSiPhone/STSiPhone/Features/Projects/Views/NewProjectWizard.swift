import SwiftUI
import UIKit
import PhotosUI
import UniformTypeIdentifiers
#if DEBUG
private func STSLogProjectMerge(_ message: @autoclosure () -> String) {
    print("🧩 [ProjectMerge] \(message())")
}
#endif

enum PayDealTag: String, CaseIterable, Codable, Identifiable {
    case noPayTFP
    case lowBudget
    case scale
    case scalePlus
    case dayPlayer
    case weekly
    case deferred
    case backendPoints
    case buyout
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .noPayTFP:      return "TFP / No Pay"
        case .lowBudget:     return "Low / Ultra Low"
        case .scale:         return "Scale"
        case .scalePlus:     return "Scale +"
        case .dayPlayer:     return "Day Rate"
        case .weekly:        return "Weekly"
        case .deferred:      return "Deferred"
        case .backendPoints: return "Backend Points"
        case .buyout:        return "Buyout"
        }
    }
}

private func kindTitle(_ kind: MaterialKind?) -> String {
    switch kind {
    case .breakdown: return "Breakdown"
    case .sides: return "Sides"
    case .none: return "Materials"
    }
}

extension PayDealTag {
    static func available(for projectType: String) -> [PayDealTag] {
        switch projectType {
        case "Commercial":
            return [.scale, .scalePlus, .dayPlayer, .buyout, .lowBudget, .noPayTFP, .deferred, .backendPoints]
        case "Television", "Web Series":
            return [.scale, .scalePlus, .dayPlayer, .weekly, .deferred, .backendPoints, .lowBudget]
        case "Feature", "Short Film":
            return [.scale, .scalePlus, .weekly, .deferred, .backendPoints, .lowBudget, .noPayTFP]
        case "Theatre":
            return [.weekly, .lowBudget, .noPayTFP, .deferred]
        default:
            return Array(self.allCases)
        }
    }
}

enum UnionStatus: String, CaseIterable, Codable, Identifiable {
    case sagAftra
    case sagAftraEligible
    case nonUnion
    case equity
    case actraOrOther
    case notSpecified
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .sagAftra:
            return "SAG-AFTRA"
        case .sagAftraEligible:
            return "SAG-AFTRA Eligible"
        case .nonUnion:
            return "Non-Union"
        case .equity:
            return "Equity / Theatre Union"
        case .actraOrOther:
            return "ACTRA / Other Union"
        case .notSpecified:
            return "Not Specified"
        }
    }
}

enum RoleType: String, CaseIterable, Codable, Identifiable {
    case seriesRegular
    case recurring
    case recurringGuestStar
    case guestStar
    case coStar
    
    case filmLead
    case filmSupporting
    case filmFeatured
    
    case commercialPrincipal
    case commercialFeatured
    case commercialExtra
    
    case theatreLead
    case theatreSupporting
    case theatreEnsemble
    case theatreUnderstudy
    
    case voiceoverLead
    case voiceoverSupporting
    case background
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .seriesRegular:        return "Series Regular"
        case .recurring:            return "Recurring"
        case .recurringGuestStar:   return "Recurring Guest Star"
        case .guestStar:            return "Guest Star"
        case .coStar:               return "Co-Star"
            
        case .filmLead:             return "Lead"
        case .filmSupporting:       return "Supporting"
        case .filmFeatured:         return "Featured"
            
        case .commercialPrincipal:  return "Principal"
        case .commercialFeatured:   return "Featured"
        case .commercialExtra:      return "Extra / Background"
            
        case .theatreLead:          return "Lead"
        case .theatreSupporting:    return "Supporting"
        case .theatreEnsemble:      return "Ensemble"
        case .theatreUnderstudy:    return "Understudy"
            
        case .voiceoverLead:        return "Lead VO"
        case .voiceoverSupporting:  return "Supporting VO"
        case .background:           return "Background"
        }
    }
    
    static func available(for projectType: String) -> [RoleType] {
        switch projectType {
        case "Television", "Web Series":
            return [.seriesRegular, .recurring, .recurringGuestStar, .guestStar, .coStar]
        case "Feature", "Short Film":
            return [.filmLead, .filmSupporting, .filmFeatured]
        case "Commercial":
            return [.commercialPrincipal, .commercialFeatured, .commercialExtra]
        case "Theatre":
            return [.theatreLead, .theatreSupporting, .theatreEnsemble, .theatreUnderstudy]
        default:
            return [.filmLead, .filmSupporting, .filmFeatured, .guestStar, .coStar]
        }
    }
}

struct PayDeal: Codable {
    var selectedTags: Set<PayDealTag> = []
    var rateText: String = ""
    var craftVsMoney: Double = 0.5
    var unionStatus: UnionStatus? = nil
    var roleType: RoleType? = nil
}

private enum SlateFramingOption: String, CaseIterable, Identifiable {
    case closeUp
    case fullBody
    case pip
    
    var id: String { rawValue }
    
    var label: String {
        switch self {
        case .closeUp: return "Close-Up"
        case .fullBody: return "Full Body"
        case .pip: return "Close-Up & Full Body"
        }
    }
    
    var hint: String {
        switch self {
        case .closeUp: return ""
        case .fullBody: return ""
        case .pip: return ""
        }
    }

    var selection: SlateFramingSelection {
        switch self {
        case .closeUp: return .closeUp
        case .fullBody: return .fullBody
        case .pip: return .both
        }
    }

    init(selection: SlateFramingSelection) {
        switch selection {
        case .closeUp: self = .closeUp
        case .fullBody: self = .fullBody
        case .both: self = .pip
        }
    }
}

private enum MaterialKind: Identifiable {
    case breakdown
    case sides
    
    var id: Int {
        switch self {
        case .breakdown: return 0
        case .sides: return 1
        }
    }
    
    var title: String {
        switch self {
        case .breakdown: return "Breakdown"
        case .sides: return "Sides"
        }
    }
}

public struct NewProjectWizard: View {
    public enum InitialScrollTarget: Equatable {
        case uploadsBottom
    }
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    @State private var vm: NewProjectViewModel
    @State private var repsVM = RepsViewModel()
    @State private var actorProfileManager: ActorProfileManager
    @State private var currentStep: Int = 1

    /// Called when camera capture finishes for a wizard-created session so the host can present TakeReview.
    let onRecordingComplete: ((UUID, UUID) -> Void)?

    private let totalSteps = 4
    private let existingProject: Project?
    private let autoSaveEnabled: Bool
    private let usePosterMode = true
    private let showsSaveInsteadOfCancel: Bool

    // Additional fields from handoff
    @State private var shootDate = Date()
    
    // === NEW: Genre support (local state shim so we don't require VM changes) ===
    @State private var selectedGenre: String
    @State private var storedSlatePrompt: String?
    @State private var actorHeightInput: String
    @State private var baseLocationInput: String
    @State private var localHireInput: String
    @State private var isEditingSlatePreview: Bool = false
    @State private var customSlatePreviewText: String = ""
    @State private var suppressSlatePreviewAutoSave = false
    @State private var showActorProfileWizard = false
    @State private var wizardProjectID: UUID
    @State private var wizardSessionID: UUID
    @State private var checklistContext: ChecklistContext?
    @State private var didCommitProject = false
    @State private var autoCreatedProjectID: UUID?
    @State private var payDeal = PayDeal()
    @State private var submittedHeadshotID: UUID?
    @State private var autoSaveWorkItem: DispatchWorkItem?
    @State private var submittedHeadshotThumbnail: UIImage?
    @State private var isPresentingHeadshotPicker = false
    @State private var slateFraming: SlateFramingOption = .pip
    @State private var initialAuditionDueDate: Date
    @State private var didEditSubmissionWindow: Bool = false
    @State private var didEditSlateDetails: Bool = false
    @State private var didTouchBreakdownNotes: Bool = false

    private var theme: STSTheme { themeManager.current }
    private var palette: WizardPalette { WizardPalette(theme: theme) }
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
    
    // Mapping of genres by project type (expand/adjust freely)
    private let genreOptionsByType: [String: [String]] = [
        "Feature": [
            "Drama","Comedy","Thriller","Action","Romance","Horror","Sci-Fi","Fantasy","Crime","Family","Animation","Documentary"
        ],
        "Short Film": [
            "Drama","Comedy","Thriller","Horror","Experimental","Romance","Sci-Fi","Fantasy","Documentary"
        ],
        "Television": [
            "Drama","Comedy","Procedural","Sitcom","Limited Series","Reality","Docu-series","Talk Show","Game Show"
        ],
        "Commercial": [
            "Lifestyle","Comedy","Testimonial","Product","Fashion","Automotive","Food & Beverage","Tech","Pharma"
        ],
        "Web Series": [
            "Comedy","Drama","Docu-series","Sketch","How-To","Lifestyle","Actual Play"
        ],
        "Theatre": [
            "Drama","Comedy","Musical","Classical","Experimental","Improv"
        ]
    ]
    
    // Fallback list used if a type has no mapping
    private var allGenres: [String] {
        Array(Set(genreOptionsByType.values.flatMap { $0 })).sorted()
    }

    private var selectedRepInfo: RepInfo? {
        guard let repID = vm.selectedRepID else { return nil }
        return repsVM.reps.first(where: { $0.id == repID })
    }
    
    private var selectedRepMenuTitle: String {
        if let rep = selectedRepInfo {
            return rep.name
        }
        return "Select from Actor Kit"
    }
    
    private var selectedRepMenuSubtitle: String {
        if let rep = selectedRepInfo {
            if let category = rep.category.slateTrimmedNonEmpty {
                return category
            }
            return "Tap to edit representation line"
        }
        if let manual = vm.slateSelections.representation?.slateTrimmedNonEmpty, !manual.isEmpty {
            return manual
        }
        return "Tap to pull in your representation"
    }
    
    private func representationSummary(for rep: RepInfo) -> String {
        var components: [String] = []
        let trimmedName = rep.name.slateTrimmedNonEmpty ?? rep.name
        components.append(trimmedName)
        if let company = rep.companyName?.slateTrimmedNonEmpty, !company.isEmpty {
            components.append(company)
        }
        return components.joined(separator: ", ")
    }
    
    private func handleRepresentationSelectionChange(_ newValue: UUID?) {
        guard let repID = newValue,
              let rep = repsVM.reps.first(where: { $0.id == repID }) else {
            if newValue == nil {
                vm.slateSelections.representation = nil
            }
            return
        }
        vm.applySelectedRep(rep)
        vm.slateSelections.representation = representationSummary(for: rep)
    }
    
    private var paySummaryText: String? {
        var parts: [String] = []
        if let role = payDeal.roleType {
            parts.append(role.displayName)
        }
        if let union = payDeal.unionStatus {
            parts.append(union.displayName)
        }
        if !payDeal.selectedTags.isEmpty {
            let tags = payDeal.selectedTags.map { $0.displayName }.sorted().joined(separator: " • ")
            parts.append(tags)
        }
        let rate = payDeal.rateText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !rate.isEmpty {
            parts.append(rate)
        }
        return parts.isEmpty ? nil : parts.joined(separator: " • ")
    }
    
    private var materialsSummaryText: String {
        var pieces: [String] = []
        if let sidesFileName, !sidesFileName.isEmpty {
            pieces.append("Sides: \(sidesFileName)")
        }
        if let breakdownFileName, !breakdownFileName.isEmpty {
            pieces.append("Breakdown: \(breakdownFileName)")
        }
        if pieces.isEmpty {
            return "No files attached"
        }
        return pieces.joined(separator: " • ")
    }
    
    private var slateChipColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 140), spacing: 10)]
    }
    
    private var slateTagColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 120, maximum: 240), spacing: 6)]
    }
    
    // File import state
    @State private var showFileImporter = false
    @State private var importType: ImportType = .breakdown
    @State private var importStatus: ImportStatus = .idle
    @State private var sidesURL: URL? = nil
    @State private var breakdownURL: URL? = nil
    @State private var sidesFileName: String? = nil
    @State private var breakdownFileName: String? = nil
    @State private var minimumSceneCount: Int = 1
    @State private var showPhotoPicker = false
    @State private var photoPickerType: ImportType = .sides
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var breakdownTextInput: String
    
    // Replace confirmation for sides / breakdown re-imports
    private enum ImportSource {
        case files
        case photos
    }
    
    @State private var pendingImportType: ImportType? = nil
    @State private var pendingImportSource: ImportSource? = nil
    @State private var showReplaceConfirmation: Bool = false
    
    //
    @FocusState private var focusedField: FocusableField?
    
    // FIXED: Use shared ProjectSessionData instead of separate @State variables to eliminate capture bug
            
    private let projectsRepository: ProjectsRepository
    private let initialScrollTarget: InitialScrollTarget?
    
    // HANGFIX: Track width for toolbar gating
    @State private var hasWidth: Bool = false
    @State private var activeMaterialOverlay: MaterialKind? = nil
    @State private var showFramingGuide = false
    @State private var showSelfTapeGear = false
    @State private var checklistComplete = false
    @State private var didConsumeInitialScrollTarget = false
    
    var onSave: (Project) -> Void
    
    public init(
        existingProject: Project? = nil,
        repo: ProjectsRepository,
        startStep: Int? = nil,
        initialScrollTarget: InitialScrollTarget? = nil,
        onSave: @escaping (Project) -> Void,
        onRecordingComplete: ((UUID, UUID) -> Void)? = nil,
        showsSaveInsteadOfCancel: Bool = false
    ) {
        self.onSave = onSave
        self.onRecordingComplete = onRecordingComplete
        self.existingProject = existingProject
        self.autoSaveEnabled = existingProject != nil
        self.projectsRepository = repo
        self.showsSaveInsteadOfCancel = showsSaveInsteadOfCancel
        self.initialScrollTarget = initialScrollTarget
        
        let initialViewModel: NewProjectViewModel = {
            guard let project = existingProject else {
                return NewProjectViewModel.makeForNewProject()
            }
            return NewProjectViewModel.makeForEditing(project: project)
        }()
        
        let profileManager = ActorProfileManager()
        let initialHeight = profileManager.profile.height
        let projectLocation = initialViewModel.locationLabel
        let profileLocation = profileManager.profile.primaryLocation
        let initialLocation: String = {
            let trimmedProject = projectLocation.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedProject.isEmpty { return trimmedProject }
            let trimmedProfile = profileLocation.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedProfile.isEmpty { return trimmedProfile }
            return ""
        }()
        let initialProjectPrompt = resolveStoredSlatePrompt(
            from: existingProject,
            actorProfileUpdatedAt: profileManager.profile.updatedAt
        )
        // ----------------------------------------------------
        // ✅ NEW: Seed existing values when editing a project
        // ----------------------------------------------------

        // Seed sides filename
        let initialSidesFileName =
            existingProject?.sidesFileName
            ?? existingProject?.sessions.first?.sidesFileName

        // Seed breakdown filename
        let initialBreakdownFileName =
            existingProject?.breakdownFileName
            ?? existingProject?.sessions.first?.breakdownFileName

        // Seed submitted headshot ID
        let initialSubmittedHeadshotID = existingProject?.submittedHeadshotID

        // Seed submitted headshot thumbnail
        let initialSubmittedHeadshotThumbnail =
            Self.makeThumbnail(
                for: initialSubmittedHeadshotID,
                profileManager: profileManager
            )
        // ----------------------------------------------
        // ✅ NEW: Preserve minimum scenes from the original project
        // ----------------------------------------------
        let minScenes = max(1, existingProject?.sceneCount ?? 1)
        
        _actorProfileManager = State(initialValue: profileManager)
        _vm = State(initialValue: initialViewModel)
        _initialAuditionDueDate = State(initialValue: initialViewModel.auditionDueDate)
        _selectedGenre = State(initialValue: existingProject?.genre ?? "")
        _storedSlatePrompt = State(initialValue: initialProjectPrompt)
        let hasInitialCustomSlate = initialProjectPrompt?.slateTrimmedNonEmpty != nil
        _isEditingSlatePreview = State(initialValue: hasInitialCustomSlate)
        _customSlatePreviewText = State(initialValue: initialProjectPrompt ?? "")
        _actorHeightInput = State(initialValue: initialHeight)
        _baseLocationInput = State(initialValue: initialLocation)
        let projectLocalHire = initialViewModel.slateSelections.localHireMarket ?? ""
        let profileLocalHire = profileManager.profile.localHireMarket
        let initialLocalHire: String = {
            let trimmedProject = projectLocalHire.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedProject.isEmpty { return trimmedProject }
            let trimmedProfile = profileLocalHire.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedProfile.isEmpty { return trimmedProfile }
            return ""
        }()
        _localHireInput = State(initialValue: initialLocalHire)
        let seededBreakdownNotes: String = {
            if let existingProject {
                return existingProject.sessions.first?.breakdownNotes
                ?? existingProject.breakdownNotes
                ?? ""
            } else {
                return ""
            }
        }()
        _breakdownTextInput = State(initialValue: seededBreakdownNotes)
        _sidesFileName = State(initialValue: initialSidesFileName)
        _breakdownFileName = State(initialValue: initialBreakdownFileName)
        let initialFraming = SlateFramingOption(selection: initialViewModel.slateSelections.framingSelection)
        _slateFraming = State(initialValue: initialFraming)
        let baseProjectID = existingProject?.id ?? UUID()
        let baseSessionID = existingProject?.sessions.first?.id ?? UUID()
        _wizardProjectID = State(initialValue: baseProjectID)
        _wizardSessionID = State(initialValue: baseSessionID)
        _minimumSceneCount = State(initialValue: minScenes)
        let initialPayDeal = existingProject.map { project in
            var deal = PayDeal()
            if let raw = project.payDealTagsRaw {
                let tags = raw.split(separator: ",").compactMap { PayDealTag(rawValue: String($0)) }
                deal.selectedTags = Set(tags)
            }
            if let rate = project.payRateText {
                deal.rateText = rate
            }
            if let craft = project.payCraftVsMoney {
                deal.craftVsMoney = craft
            }
            if let unionRaw = project.payUnionStatusRaw,
               let union = UnionStatus(rawValue: unionRaw) {
                deal.unionStatus = union
            }
            if let roleRaw = project.payRoleTypeRaw,
               let role = RoleType(rawValue: roleRaw) {
                deal.roleType = role
            }
            return deal
        } ?? PayDeal()
        _payDeal = State(initialValue: initialPayDeal)
        _submittedHeadshotID = State(initialValue: initialSubmittedHeadshotID)
        _submittedHeadshotThumbnail = State(initialValue: initialSubmittedHeadshotThumbnail)
        let existingChecklistComplete = existingProject?.sessions.first?.auditionChecklist?.isComplete ?? false
        _checklistComplete = State(initialValue: existingChecklistComplete)
        let start = startStep ?? 1
        _currentStep = State(initialValue: max(1, min(totalSteps, start)))
    }
    
    private enum ImportType {
        case sides
        case breakdown
    }
    
    private enum ImportStatus {
        case idle
        case importing
        case success(String)
        case error(String)
    }
    
    // CRITICAL FIX: Enhanced FocusableField enum for proper keyboard focus management
    private enum FocusableField: String, CaseIterable {
        case title = "title"
        case roleName = "role_name"
        case castingOffice = "casting_office"
        case castingDirector = "casting_director"
        case slateNotes = "slate_notes"
        case slateLocalHire = "slate_local_hire"
        case slateRepresentation = "slate_representation"
        case slateContact = "slate_contact"
        case slateUnion = "slate_union"
        case breakdownNotes = "breakdown_notes"
        case slatePreview = "slate_preview"
    }
    
    public var body: some View {
        attachGlobalHandlers(
            ZStack {
                NavigationStack {
                    wizardContent
                }
                
                materialsOverlayLayer
            }
        )
        .stsPortraitOnly(label: "NewProjectWizard")
    }

    @ViewBuilder
    private var wizardContent: some View {
        ZStack {
            theme.backgroundGradient
                .ignoresSafeArea()
            accentGlow

            VStack(spacing: 0) {
                progressIndicator

                TabView(selection: $currentStep) {
                    ForEach(1...totalSteps, id: \.self) { step in
                        wizardStepPage(for: step)
                            .tag(step)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .onChange(of: currentStep, initial: false) { _, _ in
                    // Hook available for analytics / step timing if needed
                }

                navigationButton
            }

            materialsOverlayLayer
        }
        .background(
            GeometryReader { proxy in
                Color.clear
                    .onAppear {
                        let w = clampFinite(proxy.size.width, min: 0.5, fallback: 1.0)
                        hasWidth = w > 0.5
                    }
                    .onChange(of: proxy.size, initial: false) { _, newSize in
                        let w = clampFinite(newSize.width, min: 0.5, fallback: 1.0)
                        hasWidth = w > 0.5
                    }
            }
        )
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                if currentStep > 1 && hasWidth {
                    Button {
                        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                        impactFeedback.impactOccurred()

                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentStep -= 1
                        }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.title2)
                            .foregroundStyle(Theme.textPrimary)
                    }
                }
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                if hasWidth {
                    Button(showsSaveInsteadOfCancel ? "Save Changes" : "Cancel") {
                        if focusedField == .breakdownNotes {
                            didTouchBreakdownNotes = true
                        }
                        focusedField = nil
                        dismissKeyboard()
                        DispatchQueue.main.async {
                            dismiss()
                        }
                    }
                    .foregroundStyle(Theme.textPrimary)
                }
            }

            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button {
                    if focusedField == .breakdownNotes {
                        focusedField = nil
                        didTouchBreakdownNotes = true
                    } else if focusedField == .slatePreview {
                        focusedField = nil
                    } else {
                        focusedField = nil
                    }
                    dismissKeyboard()
                } label: {
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(palette.primaryAccent)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(palette.cardBackground.opacity(0.85))
                        )
                        .overlay(
                            Capsule()
                                .stroke(palette.cardStroke.opacity(0.5), lineWidth: 1)
                        )
                }
                .accessibilityLabel("Dismiss Keyboard")
            }
        }
        .navigationTitle("New Project")
        .navigationBarTitleDisplayMode(.inline)
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }

    @ViewBuilder
    private var materialsOverlayLayer: some View {
        if let overlay = activeMaterialOverlay {
            ZStack {
                Color.black.opacity(0.45)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
                            activeMaterialOverlay = nil
                        }
                    }

                MaterialOverlayPanel(
                    kind: overlay,
                    currentFileName: overlay == .breakdown ? breakdownFileName : sidesFileName,
                    notes: overlay == .breakdown ? $breakdownTextInput : .constant(""),
                    showsNotes: overlay == .breakdown,
                    onImportFromFiles: {
                        let type: ImportType = overlay == .breakdown ? .breakdown : .sides
                        requestImport(for: type, source: .files)
                    },
                    onImportFromPhotos: {
                        let type: ImportType = overlay == .breakdown ? .breakdown : .sides
                        requestImport(for: type, source: .photos)
                    },
                    onClear: {
                        switch overlay {
                        case .breakdown:
                            breakdownURL = nil
                            breakdownFileName = nil
                            breakdownTextInput = ""
                        case .sides:
                            sidesURL = nil
                            sidesFileName = nil
                        }
                    },
                    onDismiss: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
                            activeMaterialOverlay = nil
                        }
                    }
                )
                .frame(maxWidth: 520)
                .padding(.horizontal, 24)
                .transition(.scale.combined(with: .opacity))
            }
            .transition(.opacity)
            .zIndex(5)
        }
    }

    private func attachGlobalHandlers<Content: View>(_ base: Content) -> some View {
        var wrapped: AnyView = AnyView(base)

        wrapped = AnyView(
            wrapped.sheet(isPresented: $showActorProfileWizard) {
                ActorProfileWizard(
                    startingProfile: actorProfileManager.profile,
                    profileManager: actorProfileManager,
                    repsViewModel: repsVM
                ) {
                    showActorProfileWizard = false
                    actorHeightInput = actorProfileManager.profile.height
                }
            }
        )
        
        wrapped = AnyView(
            wrapped.sheet(isPresented: $isPresentingHeadshotPicker) {
                SubmittedHeadshotPickerSheet(
                    headshots: actorProfileManager.profile.headshots,
                    onSelect: { asset, image in
                        submittedHeadshotID = asset.id
                        submittedHeadshotThumbnail = image ?? Self.makeThumbnail(for: asset.id, profileManager: actorProfileManager)
                        isPresentingHeadshotPicker = false
                    },
                    onCancel: {
                        isPresentingHeadshotPicker = false
                    }
                )
            }
        )

        wrapped = AnyView(
            wrapped.sheet(item: $checklistContext, onDismiss: {
                checklistContext = nil
            }) { context in
                ActorMustKnowsView(
                    project: context.project,
                    session: context.session,
                    repository: projectsRepository,
                    onComplete: {
                        checklistContext = nil
                    },
                    onNavigateToWizard: { item in
                        checklistContext = nil
                        switch item {
                        case .characterBreakdown:
                            currentStep = 2
                        case .slateEssentials:
                            currentStep = 3
                        case .submissionWindow:
                            currentStep = 1
                        case .frameAndLight:
                            showSelfTapeGear = true
                        default:
                            break
                        }
                    },
                    onCompletionStatus: { isComplete in
                        checklistComplete = isComplete
                        checklistContext = nil
                    }
                )
            }
        )

        // keep picker registration minimal here
        wrapped = AnyView(
            wrapped.photosPicker(isPresented: $showPhotoPicker,
                                 selection: $selectedPhotoItem,
                                 matching: .images)
        )

        wrapped = AnyView(
            wrapped.sheet(isPresented: $showFramingGuide) {
                FramingGuideReferenceView()
            }
        )

        wrapped = AnyView(
            wrapped.sheet(isPresented: $showSelfTapeGear) {
                EquipmentGuideView()
            }
        )

        wrapped = AnyView(
            wrapped.onAppear {
                syncGenreWithType()
                handleRepresentationSelectionChange(vm.selectedRepID)
            }
        )

        wrapped = AnyView(
            wrapped.onChange(of: vm.projectType, initial: false) { _, _ in
                syncGenreWithType()
            }
        )

        wrapped = AnyView(
            wrapped.onChange(of: isEditingSlatePreview, initial: false) { _, newValue in
                if newValue {
                    if customSlatePreviewText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        suppressSlatePreviewAutoSave = true
                        customSlatePreviewText = storedSlatePrompt ?? deterministicSlatePreviewText
                    }
                }
            }
        )

        wrapped = AnyView(
            wrapped.onChange(of: customSlatePreviewText, initial: false) { _, newValue in
                guard isEditingSlatePreview else { return }
                if suppressSlatePreviewAutoSave {
                    suppressSlatePreviewAutoSave = false
                    return
                }
                didEditSlateDetails = true
                storedSlatePrompt = newValue.slateTrimmedNonEmpty
            }
        )

        wrapped = AnyView(
            wrapped.onChange(of: vm.selectedRepID, initial: false) { _, newValue in
                handleRepresentationSelectionChange(newValue)
            }
        )

        wrapped = AnyView(
            wrapped.onReceive(NotificationCenter.default.publisher(for: .actorProfileDidUpdate)) { _ in
                handleProfileRefresh()
            }
        )

        return wrapped
            
            .fileImporter(
                isPresented: $showFileImporter,
                allowedContentTypes: [.pdf, .plainText, .image, .jpeg, .png],
                allowsMultipleSelection: false
            ) { result in
                handleFileImport(result: result)
            }
            .confirmationDialog(
                "Replace existing file?",
                isPresented: $showReplaceConfirmation,
                titleVisibility: .visible
            ) {
                Button("Replace file", role: .destructive) {
                    guard let type = pendingImportType,
                          let source = pendingImportSource else {
                        pendingImportType = nil
                        pendingImportSource = nil
                        return
                    }
                    startImport(for: type, source: source)
                    pendingImportType = nil
                    pendingImportSource = nil
                }
                
                Button("Cancel", role: .cancel) {
                    pendingImportType = nil
                    pendingImportSource = nil
                }
            } message: {
                let name: String = {
                    switch pendingImportType {
                    case .sides:
                        return sidesFileName ?? "the existing sides file"
                    case .breakdown:
                        return breakdownFileName ?? "the existing breakdown file"
                    case .none:
                        return "the existing file"
                    }
                }()
                Text("You already imported \(name). Do you want to replace it?")
            }
            .onChange(of: selectedPhotoItem, initial: false) { _, newItem in
                guard let item = newItem else { return }
                Task { await handlePhotoPickerSelection(item: item) }
            }
            .onChange(of: autoSaveSignature, initial: false) { _, _ in
                scheduleAutoSave(reason: "field change")
            }
            .onDisappear {
                DispatchQueue.main.async {
                    autoSaveWorkItem?.cancel()
                    autoSaveWorkItem = nil
                    autoSaveProject(reason: "wizard dismissed")
                    cleanupAutoCreatedProjectIfNeeded()
                }
            }
    }
    
    private var progressIndicator: some View {
        HStack(spacing: clampFinite(8, fallback: 8)) {
            ForEach(1...totalSteps, id: \.self) { stepNumber in
                SafeCircle()
                    .fill(stepNumber <= currentStep ? palette.primaryAccent : palette.cardBackground.opacity(clampFinite(0.6, fallback: 0.6)))
                    .frame(
                        width: clampFinite(12, min: 12, fallback: 12),
                        height: clampFinite(12, min: 12, fallback: 12)
                    )
            }
        }
        .padding(.vertical, clampFinite(16, fallback: 16))
    }
    
    @ViewBuilder
    private func wizardStepPage(for step: Int) -> some View {
        if usePosterMode {
            switch step {
            case 1:
                WizardStepScrollContainer {
                    projectCanvasStep
                }
            case 2:
                WizardStepScrollContainer {
                    castingAndMaterialsStep
                }
            case 3:
                posterSlateStep
            case 4:
                WizardStepScrollContainer {
                    posterReviewStep
                }
            default:
                EmptyView()
            }
        } else {
            switch step {
            case 1:
                WizardStepScrollContainer {
                    projectDetailsStep
                }
            case 2:
                WizardStepScrollContainer {
                    representationAndScenesStep
                }
            case 3:
                slateDetailsStep
            case 4:
                WizardStepScrollContainer {
                    reviewProjectStep
                }
            default:
                EmptyView()
            }
        }
    }
    
    // MARK: - Poster Mode Steps
    private var projectCanvasStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 14) {
            Text("PROJECT DETAILS")
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundStyle(palette.primaryAccent)
                .tracking(1)
                    
                    titleAndRoleSection
                    projectTypeAndGenreColumn
                    
                    if let paySummaryText {
                        Text(paySummaryText)
                            .font(.footnote)
                            .foregroundStyle(palette.secondaryText)
                    }
                }
            }
            
            PayDealCard(payDeal: $payDeal, palette: palette, projectType: vm.projectType)
                .posterCard(background: palette.cardBackground, stroke: palette.cardStroke)
            
            HStack(alignment: .top, spacing: 12) {
                scheduleSection
                    .posterCard(background: palette.cardBackground, stroke: palette.cardStroke)
                shootDatePickerCard
                    .posterCard(background: palette.cardBackground, stroke: palette.cardStroke)
            }
        }
    }
    
    private var castingAndMaterialsStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("CASTING & MATERIALS")
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundStyle(.orange)
                .tracking(1)
            
            HStack(alignment: .top, spacing: 12) {
                representationCardPoster
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                VStack(spacing: 10) {
                    SubmittedHeadshotThumbnail(
                        image: submittedHeadshotThumbnail,
                        title: submittedHeadshotID == nil ? "Submitted headshot" : "Submitted Headshot",
                        onTap: { isPresentingHeadshotPicker = true },
                        textColor: palette.secondaryText
                    )
                    .frame(width: 140, height: 170, alignment: .top)
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
            castingCardPoster
            scenesSection
                .posterCard(background: palette.cardBackground, stroke: palette.cardStroke)
            materialsCard
            importStatusSection
        }
    }
    
    private var materialsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Materials")
                .font(.headline)
            
            MaterialRow(
                title: "Breakdown",
                status: breakdownStatusLabel,
                hasNotes: breakdownTextInput.slateTrimmedNonEmpty != nil,
                onTap: {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                        activeMaterialOverlay = .breakdown
                    }
                },
                palette: palette
            )
            
            MaterialRow(
                title: "Sides",
                status: sidesStatusLabel,
                hasNotes: false,
                onTap: {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                        activeMaterialOverlay = .sides
                    }
                },
                palette: palette
            )
        }
        .posterCard(background: palette.cardBackground, stroke: palette.cardStroke)
    }
    
    private var posterSlateStep: some View {
        SlateStepScrollContainer {
            slateComposerSection
            slatePreviewCard
            if focusedField == .breakdownNotes || focusedField == .slatePreview {
                Color.clear.frame(height: 300)
            }
        }
    }
    
    private var posterReviewStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(vm.title.isEmpty ? "UNTITLED PROJECT" : vm.title.uppercased())
                        .font(.system(size: 26, weight: .black))
                        .foregroundStyle(palette.primaryText)
                        .multilineTextAlignment(.leading)
                        .tracking(1.2)
                    
                    if !vm.roleName.isEmpty {
                        Text(vm.roleName)
                            .font(.headline)
                            .foregroundStyle(palette.primaryText)
                    }
                    
                    if !vm.projectType.isEmpty {
                        posterChip(title: vm.projectType.uppercased(), icon: "film")
                    }
                    if !selectedGenre.isEmpty {
                        Text("Genre: \(selectedGenre)")
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(palette.secondaryText)
                    }
                    
                    if let paySummaryText {
                        Text(paySummaryText)
                            .font(.footnote)
                            .foregroundStyle(palette.secondaryText)
                    }
                }
                
                SubmittedHeadshotThumbnail(
                    image: submittedHeadshotThumbnail,
                    title: submittedHeadshotID == nil ? "Submitted headshot" : "Submitted Headshot",
                    onTap: { isPresentingHeadshotPicker = true },
                    textColor: palette.secondaryText
                )
                .frame(width: 140, height: 170, alignment: .top)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    scheduleSummaryCard
                    shootDateCard
                }
                representationSummaryCard
            }
            
            VStack(alignment: .leading, spacing: 10) {
                scenesSummaryCard
                materialsSummaryCard
            }
            
            if let breakdownNotes = breakdownTextInput.slateTrimmedNonEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Breakdown Notes")
                        .font(.caption)
                        .foregroundStyle(palette.secondaryText)
                    Text(breakdownNotes)
                        .font(.body)
                        .foregroundStyle(palette.primaryText)
                        .multilineTextAlignment(.leading)
                }
                .posterCard(background: palette.cardBackground, stroke: palette.cardStroke)
            }
            
            slatePreviewCard
        }
    }
    
    private var projectTypeAndGenreColumn: some View {
        projectTypeSelector
    }
    
    private var scheduleSummaryCard: some View {
        miniInfoCard(
            title: "Submission Due",
            value: vm.auditionDueDate.formatted(date: .abbreviated, time: .shortened),
            icon: vm.isAuditionDueSoon ? "exclamationmark.triangle.fill" : "calendar.badge.clock",
            tint: vm.isAuditionDueSoon ? .red : .blue
        )
    }
    
    private var shootDateCard: some View {
        miniInfoCard(
            title: "Shoot Date",
            value: vm.shootDate.formatted(date: .abbreviated, time: .omitted),
            icon: "calendar",
            tint: .blue
        )
    }
    
    private var scenesSummaryCard: some View {
        miniInfoCard(
            title: "Scenes",
            value: "\(vm.numberOfScenes)",
            icon: "number",
            tint: .orange
        )
    }
    
    private var representationSummaryCard: some View {
        let repText: String = {
            if let rep = selectedRepInfo {
                return representationSummary(for: rep)
            }
            if let manual = vm.slateSelections.representation?.slateTrimmedNonEmpty {
                return manual
            }
            return "Add rep"
        }()
        
        return miniInfoCard(
            title: "Representation",
            value: repText,
            icon: "person.badge.plus",
            tint: palette.primaryAccent
        )
    }
    
    private var materialsSummaryCard: some View {
        miniInfoCard(
            title: "Materials",
            value: materialsSummaryText,
            icon: "doc.on.doc",
            tint: palette.primaryAccent
        )
    }
    
    private var representationCardPoster: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Representation")
                .font(.headline)
                .foregroundStyle(palette.primaryText)
            representationSection
        }
        .posterCard(background: palette.cardBackground, stroke: palette.cardStroke)
    }
    
    private var castingCardPoster: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Casting")
                .font(.headline)
                .foregroundStyle(palette.primaryText)
            castingDetailsSection
        }
        .posterCard(background: palette.cardBackground, stroke: palette.cardStroke)
    }
    
    private func miniInfoCard(title: String, value: String, icon: String, tint: Color = .accentColor) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(palette.secondaryText)
                Text(value)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(palette.primaryText)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(palette.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(palette.cardStroke, lineWidth: 1)
                )
        )
    }
    
    private func posterChip(title: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
            Text(title)
        }
        .font(.caption.weight(.semibold))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule().fill(Color.white.opacity(0.08))
        )
        .overlay(
            Capsule().stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
    }
    
    // MARK: - Step 1: Project Details - SPLIT INTO SMALLER COMPONENTS
    private var projectDetailsStep: some View {
        VStack(alignment: .leading, spacing: 24) {
            headerSection
            titleAndRoleSection
            typeGenreAndScheduleSection      // ← updated
            breakdownSection
            importStatusSection
        }
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("PRODUCTION DETAILS")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(.orange)
                .tracking(1)
            
            Text("Configure your project information")
                .font(Theme.Font.body)
                .foregroundStyle(.gray)
        }
    }
    
    private var titleAndRoleSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            titleField
            roleField
        }
    }
    
    private var titleField: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("TITLE")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(.orange)
                
                Spacer()
                
                if !vm.title.isEmpty {
                    Text("")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }
            
            TextField("e.g. Silver Lake Pilot", text: $vm.title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .textFieldStyle(PlainTextFieldStyle())
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .background(
                    SafeRoundedRectangle(cornerRadius: 8)
                        .fill(Color.black.opacity(0.4))
                        .overlay(
                            SafeRoundedRectangle(cornerRadius: 8)
                                .stroke(!vm.title.isEmpty ? .green.opacity(0.6) : .white.opacity(0.2), lineWidth: 1)
                        )
                )
                .focused($focusedField, equals: .title)
                .onChange(of: vm.title, initial: false) { oldValue, newValue in
                    vm.onTitleChanged()
                    
                    if !oldValue.isEmpty && newValue.isEmpty {
                    } else if !newValue.isEmpty && oldValue.isEmpty {
                    }
                }
                .onChange(of: focusedField, initial: false) { oldValue, newValue in
                    if newValue == .title && oldValue != .title {
                    }
                }
        }
    }
    
    private var roleField: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("ROLE")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(.orange)
                
                Spacer()
                
                if !vm.roleName.isEmpty {
                    Text("")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }
            
            TextField("Detective Ramos", text: $vm.roleName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .textFieldStyle(PlainTextFieldStyle())
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .background(
                    SafeRoundedRectangle(cornerRadius: 8)
                        .fill(Color.black.opacity(0.4))
                        .overlay(
                            SafeRoundedRectangle(cornerRadius: 8)
                                .stroke(!vm.roleName.isEmpty ? .green.opacity(0.6) : .white.opacity(0.2), lineWidth: 1)
                        )
                )
                .focused($focusedField, equals: .roleName)
                // HANGFIX: Use debounced validation instead of heavy onChange
                .onChange(of: vm.roleName, initial: false) { oldValue, newValue in
                    vm.onRoleChanged() // Debounced validation
                    
                    // Keep lightweight logging only
                    if !oldValue.isEmpty && newValue.isEmpty {
                    } else if !newValue.isEmpty && oldValue.isEmpty {
                    }
                }
                .onChange(of: focusedField, initial: false) { oldValue, newValue in
                    if newValue == .roleName && oldValue != .roleName {
                    }
                }
        }
    }
    
    // MARK: - TYPE + GENRE + SCHEDULE (two-column layout)
    private var typeGenreAndScheduleSection: some View {
        Group {
            HStack(alignment: .top, spacing: 20) {
                projectTypeSelector
                    .frame(maxWidth: .infinity)
                
                VStack(alignment: .leading, spacing: 14) {
                    scheduleSection
                }
                .frame(width: 180) // reduced width to give more space to Type buttons
            }
            .padding(.vertical, 8)
        }
    }
    
    private var projectTypeSelector: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("TYPE")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(.orange)
            
            let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
            
            LazyVGrid(columns: columns, alignment: .center, spacing: 12) {
                ForEach(projectTypes, id: \.type) { projectTypeOption in
                    let genres = genreOptionsByType[projectTypeOption.type] ?? allGenres
                    Menu {
                        ForEach(genres, id: \.self) { genre in
                            let isSelected = (vm.projectType == projectTypeOption.type) && selectedGenre == genre
                            Button {
                                focusedField = nil
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                vm.projectType = projectTypeOption.type
                                selectedGenre = genre
                            } label: {
                                HStack {
                                    Text(genre)
                                    Spacer()
                                    if isSelected {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: projectTypeOption.icon)
                                .font(.system(size: 22, weight: .semibold))
                               .foregroundStyle(vm.projectType == projectTypeOption.type ? palette.primaryText : palette.secondaryText)
                            
                            Text(projectTypeOption.type)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(vm.projectType == projectTypeOption.type ? palette.primaryText : palette.secondaryText)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity)
                            
                            Text(genreLabel(for: projectTypeOption.type))
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(palette.secondaryText)
                                .lineLimit(1)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.vertical, 14)
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                        .background(
                            SafeRoundedRectangle(cornerRadius: 12)
                                .fill(vm.projectType == projectTypeOption.type ? palette.cardBackground.opacity(1.1) : palette.cardBackground)
                                .overlay(
                                    SafeRoundedRectangle(cornerRadius: 12)
                                        .stroke(vm.projectType == projectTypeOption.type ? palette.primaryAccent : palette.cardStroke, lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
    
    // NEW: Genre picker section (menu-style Picker to match your mock)
    // NEW: Enhanced Genre picker with all categories
    private var genreSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("GENRE")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(.orange)
            
            Picker(selection: $selectedGenre) {
                // Add "Select a genre" option
                Text("Select a genre").tag("")
                
                // Add all project types with their genres
                ForEach(["Feature", "Short Film", "Television", "Commercial", "Web Series", "Theatre"], id: \.self) { projectType in
                    Section(header: Text("── \(projectType.uppercased()) ──")) {
                        ForEach(genreOptionsByType[projectType] ?? [], id: \.self) { genre in
                            Text(genre).tag(genre)
                        }
                    }
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "list.bullet.rectangle.portrait")
                        .font(.system(size: 16))
                        .foregroundStyle(.blue)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(selectedGenre.isEmpty ? "Select a genre" : selectedGenre)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(selectedGenre.isEmpty ? .white.opacity(0.7) : .white)
                        Text("Choose from all categories")
                            .font(.system(size: 12))
                            .foregroundStyle(.gray)
                    }
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12))
                        .foregroundStyle(.gray)
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .background(
                    SafeRoundedRectangle(cornerRadius: 8)
                        .fill(Color.black.opacity(0.4))
                        .overlay(
                            SafeRoundedRectangle(cornerRadius: 8)
                                .stroke(.white.opacity(0.2), lineWidth: 1)
                        )
                )
            }
            .pickerStyle(.menu)
            .onChange(of: selectedGenre, initial: false) { _, newValue in
            }
        }
    }
    
    private var scheduleSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("SCHEDULE")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(.orange)
            
            VStack(spacing: 10) {
                // Submission Due Date - Date and Time on separate lines
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("SUBMISSION DUE")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundStyle(vm.isAuditionDueSoon ? .red : .yellow)
                        
                        Spacer()
                        
                        if vm.isAuditionDueSoon {
                            Text("URGENT")
                                .font(.system(size: 6, weight: .bold, design: .monospaced))
                                .foregroundStyle(.red)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(
                                    SafeCapsule()
                                        .fill(Color.red.opacity(0.2))
                                )
                        }
                    }
                    
                    // Date picker - only date
                    DatePicker("", selection: $vm.auditionDueDate, displayedComponents: [.date])
                        .datePickerStyle(.compact)
                        .tint(vm.isAuditionDueSoon ? .red : .yellow)
                        .colorScheme(.dark)
                        .scaleEffect(clampFinite(0.85, min: 0.1, max: 2.0, fallback: 1.0))
                        .onChange(of: vm.auditionDueDate, initial: false) { _, newValue in
                            if newValue != initialAuditionDueDate {
                                didEditSubmissionWindow = true
                            }
                        }
                    
                    // Time picker - separate row under date
                    DatePicker("", selection: $vm.auditionDueDate, displayedComponents: [.hourAndMinute])
                        .datePickerStyle(.compact)
                        .tint(vm.isAuditionDueSoon ? .red : .yellow)
                        .colorScheme(.dark)
                        .scaleEffect(clampFinite(0.85, min: 0.1, max: 2.0, fallback: 1.0))
                        .onChange(of: vm.auditionDueDate, initial: false) { _, newValue in
                            if newValue != initialAuditionDueDate {
                                didEditSubmissionWindow = true
                            }
                        }
                }
                .padding(8)
                .background(
                    SafeRoundedRectangle(cornerRadius: 6)
                        .fill(vm.isAuditionDueSoon ? Color.red.opacity(0.1) : Color.yellow.opacity(0.1))
                        .overlay(
                            SafeRoundedRectangle(cornerRadius: 6)
                                .stroke(vm.isAuditionDueSoon ? .red.opacity(0.4) : .yellow.opacity(0.4), lineWidth: 1)
                        )
                )
            }
        }
    }
    
    private var shootDatePickerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SHOOT DATE")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(.blue)
            
            DatePicker("", selection: $vm.shootDate, displayedComponents: [.date])
                .datePickerStyle(.compact)
                .tint(.blue)
                .colorScheme(.dark)
                .scaleEffect(clampFinite(0.85, min: 0.1, max: 2.0, fallback: 1.0))
        }
        .padding(8)
        .background(
            SafeRoundedRectangle(cornerRadius: 6)
                .fill(Color.blue.opacity(0.1))
                .overlay(
                    SafeRoundedRectangle(cornerRadius: 6)
                        .stroke(.blue.opacity(0.4), lineWidth: 1)
                )
        )
    }
    
    private var breakdownSection: some View {
        VStack(spacing: 16) {
            // Breakdown Upload
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("BREAKDOWN")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(.orange)
                    
                    Spacer()
                    
                    if breakdownFileName != nil {
                        HStack(spacing: 4) {
                            Text("")
                                .font(.caption)
                            Text("ATTACHED")
                                .font(.system(size: 8, weight: .bold, design: .monospaced))
                                .foregroundStyle(.green)
                        }
                    }
                }
                
                Button(action: {
                    didTouchBreakdownNotes = true
                    focusedField = nil
                    requestImport(for: .breakdown, source: .files)
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "doc.badge.plus")
                            .font(.system(size: 16))
                            .foregroundStyle(.blue)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(breakdownFileName ?? "Upload PDF or TXT")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(breakdownFileName != nil ? .white : .gray)
                            
                            Text("Auto-fill project details")
                                .font(.system(size: 12))
                                .foregroundStyle(.gray)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12))
                            .foregroundStyle(.gray)
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)
                    .background(
                        SafeRoundedRectangle(cornerRadius: 8)
                            .fill(Color.black.opacity(0.4))
                            .overlay(
                                SafeRoundedRectangle(cornerRadius: 8)
                                    .stroke(.white.opacity(0.2), lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .contentShape(Rectangle())
                
                Button {
                    focusedField = nil
                    requestImport(for: .breakdown, source: .photos)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 16))
                            .foregroundStyle(.purple)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Import from Photos")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.white)
                            Text("Great for screenshots or camera shots")
                                .font(.system(size: 12))
                                .foregroundStyle(.gray)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12))
                            .foregroundStyle(.gray)
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)
                    .background(
                        SafeRoundedRectangle(cornerRadius: 8)
                            .fill(Color.black.opacity(0.35))
                            .overlay(
                                SafeRoundedRectangle(cornerRadius: 8)
                                    .stroke(.white.opacity(0.15), lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())
            }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("BREAKDOWN NOTES")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(.orange)
                    Spacer()
                    if let count = breakdownTextInput.slateTrimmedNonEmpty?.count, count > 0 {
                        Text("\(count) chars")
                            .font(.caption2)
                            .foregroundStyle(.gray)
                    }
                }
                
                ZStack(alignment: .topLeading) {
                    if breakdownTextInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("Upload a Character Breakdown or copy/paste it here so it’s handy during your camera session.")
                            .font(.caption)
                            .foregroundStyle(.gray)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 14)
                    }
                    
                    TextEditor(text: $breakdownTextInput)
                        .frame(minHeight: 140)
                        .foregroundColor(.white)
                        .tint(.white)
                        .scrollContentBackground(.hidden)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .focused($focusedField, equals: .breakdownNotes)
                        .onChange(of: breakdownTextInput, initial: false) { _, newValue in
                            if !newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                didTouchBreakdownNotes = true
                            }
                        }
                }
                .background(
                    SafeRoundedRectangle(cornerRadius: 10)
                        .fill(Color.black.opacity(0.35))
                        .overlay(
                            SafeRoundedRectangle(cornerRadius: 10)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                )
            }
            
            // Days until due countdown display
            if vm.daysUntilAuditionDue >= 0 {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("SUBMISSION DUE BY")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(.orange)
                        
                        Spacer()
                        
                        if vm.isAuditionDueSoon {
                            Text("URGENT")
                                .font(.system(size: 8, weight: .bold, design: .monospaced))
                                .foregroundStyle(.red)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    SafeCapsule()
                                        .fill(Color.red.opacity(0.2))
                                )
                        }
                    }
                    
                    VStack(spacing: 6) {
                        Text("\(vm.daysUntilAuditionDue)")
                            .font(.system(size: 32, weight: .bold, design: .monospaced))
                            .foregroundStyle(vm.isAuditionDueSoon ? .red : .white)
                        
                        Text(vm.daysUntilAuditionDue == 1 ? "DAY LEFT" : "DAYS LEFT")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(.gray)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        SafeRoundedRectangle(cornerRadius: 8)
                            .fill(Color.black.opacity(0.6))
                            .overlay(
                                SafeRoundedRectangle(cornerRadius: 8)
                                    .stroke(vm.isAuditionDueSoon ? .red.opacity(0.4) : .white.opacity(0.2), lineWidth: 1)
                            )
                    )
                }
            }
        }
    }
    
    private var importStatusSection: some View {
        Group {
            // Import status message
            if case .success(let message) = importStatus {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text(message)
                        .font(.system(size: 12))
                        .foregroundStyle(.green)
                }
                .transition(.opacity.animation(.easeInOut))
            } else if case .error(let message) = importStatus {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                    Text(message)
                        .font(.system(size: 12))
                        .foregroundStyle(.red)
                }
                .transition(.opacity.animation(.easeInOut))
            }
        }
    }
    
    // MARK: - Project Type Options with Fun Icons
    private var projectTypes: [(type: String, icon: String)] {
        [
            ("Feature", "film.fill"),                    // Film camera for feature film
            ("Short Film", "video.fill"),               // Video camera for short film
            ("Television", "tv.fill"),                  // TV for television
            ("Commercial", "megaphone.fill"),           // Megaphone for commercial
            ("Web Series", "globe"),                    // Globe for web series
            ("Theatre", "theatermasks.fill")            // Theater masks for theatre
        ]
    }
    
    // MARK: - Step 2: Representation and Scenes
    private enum ScrollAnchor {
        static let uploadsBottom = "uploadsBottom"
    }

    private var representationAndScenesStep: some View {
        ScrollViewReader { proxy in
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("AUDITION DETAILS")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(.orange)
                        .tracking(1)
                    
                    Text("Configure casting details and audition information")
                        .font(Theme.Font.body)
                        .foregroundStyle(.gray)
                }
                
                // Representation Section
                representationSection
                
                // Casting Details Section
                castingDetailsSection
                
                // Import Sides Section
                importSidesSection
                
                // Anchor after uploads to scroll to
                Color.clear
                    .frame(height: 1)
                    .id(ScrollAnchor.uploadsBottom)
                
                // Scenes Section (moved to bottom)
                scenesSection
                
                // Import status message
                importStatusSection
                
                Spacer()
            }
            .onAppear {
                guard !didConsumeInitialScrollTarget else { return }
                guard currentStep == 2 else { return }
                guard initialScrollTarget == .uploadsBottom else { return }
                didConsumeInitialScrollTarget = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        proxy.scrollTo(ScrollAnchor.uploadsBottom, anchor: .bottom)
                    }
                }
            }
        }
    }
    
    private var slateDetailsStep: some View {
        SlateStepScrollContainer {
            slateDetailsHeader
            slateComposerSection
            slatePreviewCard
            if focusedField == .breakdownNotes || focusedField == .slatePreview {
                Color.clear.frame(height: 300)
            }
        }
    }
    
    private var slateDetailsHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SLATE DETAILS")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(.orange)
                .tracking(1)
            
            Text("Choose what to say on camera before you tape")
                .font(Theme.Font.body)
                .foregroundStyle(.gray)
        }
    }
    
    private func handleProfileRefresh() {
        let refreshedManager = ActorProfileManager()
        actorProfileManager = refreshedManager
        actorHeightInput = refreshedManager.profile.height
        baseLocationInput = refreshedManager.profile.primaryLocation

        let seed = refreshedManager.profile.localHireMarket.slateTrimmedNonEmpty
            ?? refreshedManager.profile.primaryLocation.slateTrimmedNonEmpty
        localHireInput = seed ?? ""
        vm.slateSelections.localHireMarket = seed

        if storedSlatePrompt?.slateTrimmedNonEmpty != nil {
            storedSlatePrompt = nil
            if isEditingSlatePreview {
                suppressSlatePreviewAutoSave = true
                customSlatePreviewText = deterministicSlatePreviewText
            }
        }
    }
    
    // MARK: - Step 2 Sections
    private var representationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("WHO SUBMITTED YOU?")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(.orange)
            
            if repsVM.reps.isEmpty {
                HStack {
                    Image(systemName: "person.slash")
                        .font(.system(size: 16))
                        .foregroundStyle(.gray)
                    Text("No representation available")
                        .font(.system(size: 14))
                        .foregroundStyle(.gray)
                    Spacer()
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .background(
                    SafeRoundedRectangle(cornerRadius: 8)
                        .fill(Color.black.opacity(0.2))
                        .overlay(
                            SafeRoundedRectangle(cornerRadius: 8)
                                .stroke(.white.opacity(0.1), lineWidth: 1)
                        )
                )
            } else {
                Picker(selection: $vm.selectedRepID) {
                    Text("No Rep Selected").tag(UUID?.none)
                    ForEach(repsVM.reps, id: \.id) { rep in
                        Text("\(rep.category): \(rep.name)").tag(UUID?.some(rep.id))
                    }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 14))
                            .foregroundStyle(.blue)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Who got you the audition?")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.white)
                            Text("Select your representation")
                                .font(.system(size: 12))
                                .foregroundStyle(.gray)
                        }
                        Spacer()
                        Image(systemName: "chevron.down")
                            .font(.system(size: 12))
                            .foregroundStyle(.gray)
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)
                    .background(
                        SafeRoundedRectangle(cornerRadius: 8)
                            .fill(Color.black.opacity(0.4))
                            .overlay(
                                SafeRoundedRectangle(cornerRadius: 8)
                                    .stroke(.white.opacity(0.2), lineWidth: 1)
                            )
                    )
                }
                .pickerStyle(.menu)
            }
        }
    }
    private var castingDetailsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            castingOfficeField
            castingDirectorField
        }
    }
    
    private var castingOfficeField: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("CASTING OFFICE")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(.orange)
                
                Spacer()
                
                if !vm.castingOffice.isEmpty {
                    Text("")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }
            
            TextField("e.g. ABC Casting", text: $vm.castingOffice)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .textFieldStyle(PlainTextFieldStyle())
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .background(
                    SafeRoundedRectangle(cornerRadius: 8)
                        .fill(Color.black.opacity(0.4))
                        .overlay(
                            SafeRoundedRectangle(cornerRadius: 8)
                                .stroke(!vm.castingOffice.isEmpty ? .green.opacity(0.6) : .white.opacity(0.2), lineWidth: 1)
                        )
                )
                .focused($focusedField, equals: .castingOffice)
                .onChange(of: vm.castingOffice, initial: false) { oldValue, newValue in
                    if !oldValue.isEmpty && newValue.isEmpty {
                    } else if !newValue.isEmpty && oldValue.isEmpty {
                    }
                }
                .onChange(of: focusedField, initial: false) { oldValue, newValue in
                    if newValue == .castingOffice && oldValue != .castingOffice {
                    }
                }
        }
    }
    
    private var castingDirectorField: some View {
            VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("CASTING DIRECTOR")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(.orange)
                
                Spacer()
                
                if !vm.castingDirector.isEmpty {
                    Text("")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }
            
            TextField("e.g. Jamie Rivera", text: $vm.castingDirector)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .textFieldStyle(PlainTextFieldStyle())
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .background(
                    SafeRoundedRectangle(cornerRadius: 8)
                        .fill(Color.black.opacity(0.4))
                        .overlay(
                            SafeRoundedRectangle(cornerRadius: 8)
                                .stroke(!vm.castingDirector.isEmpty ? .green.opacity(0.6) : .white.opacity(0.2), lineWidth: 1)
                        )
                )
                .focused($focusedField, equals: .castingDirector)
                .onChange(of: vm.castingDirector, initial: false) { oldValue, newValue in
                    if !oldValue.isEmpty && newValue.isEmpty {
                    } else if !newValue.isEmpty && oldValue.isEmpty {
                    }
                }
                .onChange(of: focusedField, initial: false) { oldValue, newValue in
                    if newValue == .castingDirector && oldValue != .castingDirector {
                    }
                }
        }
    }
    

    private var slateComposerSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("SLATE DETAILS")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(.orange)
            
            Text("Check your audition details for what casting wants in your slate. Choose framing for your intro and keep the prompts handy for the teleprompter.")
                .font(.footnote)
                .foregroundStyle(palette.secondaryText)
            
            if shouldShowNameReminder {
                slateProfileReminder
            }
            
            framingSelector
            
            LazyVGrid(columns: slateChipColumns, alignment: .leading, spacing: 10) {
                ForEach(SlateField.allCases, id: \.self) { field in
                    VStack(alignment: .leading, spacing: 6) {
                        slateFieldChip(for: field)
                        if needsInlineEditor(for: field) {
                            inlineEditor(for: field)
                        }
                    }
                }
            }

            passportCitizenshipSection
            
        }
    }

    private var passportCitizenshipSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            slateSelectionChip(
                title: "Passport",
                subtitle: passportSubtitleText,
                isSelected: vm.slateSelections.includePassport,
                needsInfo: passportNeedsInfo
            ) {
                togglePassportSelection()
            }

            if vm.slateSelections.includePassport {
                passportConfiguration
            }

            slateSelectionChip(
                title: "Citizenship",
                subtitle: citizenshipSubtitleText,
                isSelected: vm.slateSelections.includeCitizenship,
                needsInfo: citizenshipNeedsInfo
            ) {
                toggleCitizenshipSelection()
            }

            if vm.slateSelections.includeCitizenship {
                citizenshipConfiguration
            }
        }
    }

    private var passportNeedsInfo: Bool {
        vm.slateSelections.includePassport && vm.slateSelections.hasValidPassport == nil
    }

    private var citizenshipNeedsInfo: Bool {
        guard vm.slateSelections.includeCitizenship else { return false }
        if vm.slateSelections.isLegalCitizen == nil { return true }
        if vm.slateSelections.isLegalCitizen == true {
            return vm.slateSelections.citizenshipCountry?.slateTrimmedNonEmpty == nil
        }
        return false
    }

    private var passportSubtitleText: String? {
        guard vm.slateSelections.includePassport else { return nil }
        if passportNeedsInfo {
            return "Tap Yes/No"
        }
        return vm.slateSelections.hasValidPassport == true ? "Yes" : "No"
    }

    private var citizenshipSubtitleText: String? {
        guard vm.slateSelections.includeCitizenship else { return nil }
        if vm.slateSelections.isLegalCitizen == nil {
            return "Tap Yes/No"
        }
        if vm.slateSelections.isLegalCitizen == true {
            return vm.slateSelections.citizenshipCountry?.slateTrimmedNonEmpty ?? "Add country"
        }
        return "No"
    }

    private func clearPassportSelection() {
        didEditSlateDetails = true
        vm.slateSelections.includePassport = false
        vm.slateSelections.hasValidPassport = nil
    }

    private func clearCitizenshipSelection() {
        didEditSlateDetails = true
        vm.slateSelections.includeCitizenship = false
        vm.slateSelections.isLegalCitizen = nil
        vm.slateSelections.citizenshipCountry = ""
    }

    private func togglePassportSelection() {
        didEditSlateDetails = true
        if vm.slateSelections.includePassport {
            clearPassportSelection()
        } else {
            vm.slateSelections.includePassport = true
            vm.slateSelections.hasValidPassport = nil
        }
    }

    private func toggleCitizenshipSelection() {
        didEditSlateDetails = true
        if vm.slateSelections.includeCitizenship {
            clearCitizenshipSelection()
        } else {
            vm.slateSelections.includeCitizenship = true
            vm.slateSelections.isLegalCitizen = nil
            vm.slateSelections.citizenshipCountry = ""
        }
    }

    private func slateSelectionChip(
        title: String,
        subtitle: String?,
        isSelected: Bool,
        needsInfo: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                    if let subtitle {
                        Text(subtitle)
                            .font(.caption2)
                            .foregroundStyle(needsInfo ? Color.orange.opacity(0.9) : palette.secondaryText)
                    }
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.bold))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(isSelected ? palette.primaryAccent.opacity(0.2) : palette.cardBackground.opacity(0.3))
            )
            .overlay(
                Capsule()
                    .stroke(isSelected ? palette.primaryAccent : palette.cardStroke, lineWidth: 1)
            )
            .foregroundStyle(isSelected ? palette.primaryText : palette.secondaryText)
        }
        .buttonStyle(.plain)
    }

    private var passportConfiguration: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Do you have a valid passport?")
                .font(.caption)
                .foregroundStyle(palette.secondaryText)

            Picker("Passport", selection: Binding(
                get: { vm.slateSelections.hasValidPassport },
                set: { newValue in
                    didEditSlateDetails = true
                    vm.slateSelections.hasValidPassport = newValue
                }
            )) {
                Text("Yes").tag(Optional(true))
                Text("No").tag(Optional(false))
            }
            .pickerStyle(.segmented)
        }
        .padding(12)
        .background(
            SafeRoundedRectangle(cornerRadius: 12)
                .fill(palette.cardBackground.opacity(0.2))
                .overlay(
                    SafeRoundedRectangle(cornerRadius: 12)
                        .stroke(palette.cardStroke.opacity(0.4), lineWidth: 1)
                )
        )
    }

    private var citizenshipConfiguration: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Are you a legal citizen?")
                .font(.caption)
                .foregroundStyle(palette.secondaryText)

            Picker("Citizenship", selection: Binding(
                get: { vm.slateSelections.isLegalCitizen },
                set: { newValue in
                    didEditSlateDetails = true
                    vm.slateSelections.isLegalCitizen = newValue
                    if newValue != true {
                        vm.slateSelections.citizenshipCountry = ""
                    }
                }
            )) {
                Text("Yes").tag(Optional(true))
                Text("No").tag(Optional(false))
            }
            .pickerStyle(.segmented)

            if vm.slateSelections.isLegalCitizen == true {
                slateInlineTextField(
                    icon: "globe",
                    placeholder: "Country of citizenship",
                    text: slateBinding(\.citizenshipCountry).toNonOptional()
                )
                .onChange(of: vm.slateSelections.citizenshipCountry, initial: false) { _, _ in
                    didEditSlateDetails = true
                }
            }
        }
        .padding(12)
        .background(
            SafeRoundedRectangle(cornerRadius: 12)
                .fill(palette.cardBackground.opacity(0.2))
                .overlay(
                    SafeRoundedRectangle(cornerRadius: 12)
                        .stroke(palette.cardStroke.opacity(0.4), lineWidth: 1)
                )
        )
    }
    
    private var shouldShowNameReminder: Bool {
        vm.slateSelections.include.contains(.name) &&
        actorProfileManager.profile.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private var slateProfileReminder: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "person.crop.circle.badge.exclam")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.orange)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Add your name to Actor Profile")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                Text("It appears at the top of your slate.")
                    .font(.system(size: 11))
                    .foregroundStyle(.gray)
            }
            
            Spacer()
            
            Button("Edit Profile") {
                showActorProfileWizard = true
            }
            .font(.caption.bold())
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                SafeCapsule()
                    .fill(Theme.primary.opacity(0.2))
            )
            .overlay(
                SafeCapsule()
                    .stroke(Theme.primary, lineWidth: 1)
            )
        }
        .padding(12)
        .background(
            SafeRoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.03))
                .overlay(
                    SafeRoundedRectangle(cornerRadius: 14)
                        .stroke(Color.orange.opacity(0.35), lineWidth: 1)
                )
        )
    }
    
    private var framingSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("FRAMING")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(palette.secondaryText)
            
            HStack(spacing: 10) {
                ForEach(SlateFramingOption.allCases) { option in
                    let selected = slateFraming == option
                    Button {
                        updateSlateFraming(option)
                    } label: {
                        Text(option.label)
                            .font(.caption.weight(.semibold))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity)
                            .background(
                                SafeRoundedRectangle(cornerRadius: 12)
                                .fill(selected ? palette.primaryAccent.opacity(0.18) : palette.cardBackground.opacity(0.3))
                        )
                        .overlay(
                            SafeRoundedRectangle(cornerRadius: 12)
                                .stroke(selected ? palette.primaryAccent : palette.cardStroke, lineWidth: 1)
                        )
                        .foregroundStyle(selected ? palette.primaryText : palette.secondaryText)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func updateSlateFraming(_ option: SlateFramingOption) {
        guard slateFraming != option else { return }
        slateFraming = option
        vm.slateSelections.framingSelection = option.selection
        didEditSlateDetails = true
    }
    
    private func slateFieldChip(for field: SlateField) -> some View {
        let isSelected = vm.slateSelections.include.contains(field)
        return slateSelectionChip(
            title: slateFieldTitle(field),
            subtitle: slateFieldSubtitle(field),
            isSelected: isSelected,
            needsInfo: false
        ) {
            toggleSlateField(field)
        }
    }
    
private func needsInlineEditor(for field: SlateField) -> Bool {
    guard vm.slateSelections.include.contains(field) else { return false }
    switch field {
    case .location, .localHire:
        return true
    default:
        return false
    }
}
    
    @ViewBuilder
    private func inlineEditor(for field: SlateField) -> some View {
        switch field {
        case .height:
            EmptyView()
        case .location:
            slateInlineTextField(
                icon: "mappin.and.ellipse",
                placeholder: "Where are you based?",
                text: $baseLocationInput
            )
            .onSubmit {
                vm.locationLabel = baseLocationInput
            }
            .onDisappear {
                DispatchQueue.main.async {
                    vm.locationLabel = baseLocationInput
                }
            }
        case .localHire:
            slateInlineTextField(
                icon: "airplane.departure",
                placeholder: "Local hire market (e.g., Atlanta)",
                text: $localHireInput,
                focus: .slateLocalHire
            )
            .onSubmit {
                vm.slateSelections.localHireMarket = localHireInput.isEmpty ? nil : localHireInput
            }
            .onDisappear {
                DispatchQueue.main.async {
                    vm.slateSelections.localHireMarket = localHireInput.isEmpty ? nil : localHireInput
                }
            }
        default:
            EmptyView()
        }
    }
    
private func slateInlineTextField(
    icon: String,
    placeholder: String,
    text: Binding<String>,
    focus: FocusableField? = nil
) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.gray)
            
            if let focus {
                TextField(placeholder, text: text)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.words)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white)
                    .focused($focusedField, equals: focus)
                    .onChange(of: text.wrappedValue, initial: false) { _, _ in
                        didEditSlateDetails = true
                    }
            } else {
                TextField(placeholder, text: text)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.words)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white)
                    .onChange(of: text.wrappedValue, initial: false) { _, _ in
                        didEditSlateDetails = true
                    }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            SafeRoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.35))
                .overlay(
                    SafeRoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
        )
    }
    
    @ViewBuilder
    private var slateDependentFields: some View {
        EmptyView()
    }
    
    private var representationPickerField: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("REPRESENTATION")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(.orange)
            
            if repsVM.reps.isEmpty {
                slateAuxiliaryField(
                    title: "",
                    placeholder: "Add representation details manually",
                    text: slateBinding(\.representation),
                    focus: .slateRepresentation,
                    showTitle: false
                )
                
                Text("Add your reps in Actor Kit to choose from a list.")
                    .font(.caption2)
                    .foregroundStyle(.gray)
            } else {
                Menu {
                    Button("No representation") {
                        vm.selectedRepID = nil
                        vm.slateSelections.representation = nil
                    }
                    
                    ForEach(repsVM.reps) { rep in
                        Button {
                            vm.selectedRepID = rep.id
                            vm.slateSelections.representation = representationSummary(for: rep)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(rep.name)
                                if let category = rep.category.slateTrimmedNonEmpty {
                                    Text(category)
                                        .font(.caption)
                                        .foregroundStyle(.gray)
                                }
                            }
                        }
                    }
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(selectedRepMenuTitle)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white)
                            Text(selectedRepMenuSubtitle)
                                .font(.caption)
                                .foregroundStyle(.gray)
                        }
                        Spacer()
                        Image(systemName: "chevron.down")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.gray)
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 14)
                    .background(
                        SafeRoundedRectangle(cornerRadius: 10)
                            .fill(Color.black.opacity(0.35))
                            .overlay(
                                SafeRoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                    )
                }
                
                slateAuxiliaryField(
                    title: "",
                    placeholder: "Fine-tune your representation line",
                    text: slateBinding(\.representation),
                    focus: .slateRepresentation,
                    showTitle: false
                )
            }
        }
    }

    private func slateAuxiliaryField(
        title: String,
        placeholder: String,
        text: Binding<String?>,
        focus: FocusableField,
        showTitle: Bool = true
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if showTitle {
                Text(title)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.orange)
            }
            
            TextField(placeholder, text: text.toNonOptional())
                .autocorrectionDisabled()
                .textInputAutocapitalization(.sentences)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)
                .padding(.vertical, 10)
                .padding(.horizontal, 14)
                .background(
                    SafeRoundedRectangle(cornerRadius: 10)
                        .fill(Color.black.opacity(0.35))
                        .overlay(
                            SafeRoundedRectangle(cornerRadius: 10)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                )
                .focused($focusedField, equals: focus)
        }
    }

    private func slateBinding(_ keyPath: WritableKeyPath<SlateSelections, String?>) -> Binding<String?> {
        Binding(
            get: { vm.slateSelections[keyPath: keyPath] },
            set: { newValue in
                vm.slateSelections[keyPath: keyPath] = newValue
            }
        )
    }

    private func toggleSlateField(_ field: SlateField) {
        didEditSlateDetails = true
        if vm.slateSelections.include.contains(field) {
            vm.slateSelections.include.remove(field)
        } else {
            vm.slateSelections.include.insert(field)
            seedSlateValue(for: field)
        }
    }

    private func seedSlateValue(for field: SlateField) {
        switch field {
        case .localHire:
            if vm.slateSelections.localHireMarket == nil {
                let profileLocalHire = actorProfileManager.profile.localHireMarket.slateTrimmedNonEmpty
                let seed = vm.slateSelections.localHireMarket
                    ?? profileLocalHire
                    ?? vm.locationLabel.slateTrimmedNonEmpty
                    ?? baseLocationInput.slateTrimmedNonEmpty
                vm.slateSelections.localHireMarket = seed
                localHireInput = seed ?? ""
            }
        case .unionStatus:
            if vm.slateSelections.unionStatus == nil {
                vm.slateSelections.unionStatus = actorProfileManager.profile.sagDisplayStatus.slateTrimmedNonEmpty
            }
        case .representation:
            if vm.slateSelections.representation == nil {
                vm.slateSelections.representation = defaultRepresentationText
            }
        case .contact:
            if vm.slateSelections.contact == nil {
                vm.slateSelections.contact = defaultContactText
            }
        default:
            break
        }
    }

    private func slateFieldTitle(_ field: SlateField) -> String {
        switch field {
        case .name: return "Name"
        case .height: return "Height"
        case .location: return "Location"
        case .localHire: return "Local Hire"
        case .unionStatus: return "Union"
        case .representation: return "Representation"
        case .contact: return "Contact"
        }
    }

    private func slateFieldSubtitle(_ field: SlateField) -> String? {
        switch field {
        case .name:
            return actorProfileManager.profile.name.slateTrimmedNonEmpty
        case .height:
            return actorHeightInput.slateTrimmedNonEmpty ?? actorProfileManager.profile.height.slateTrimmedNonEmpty
        case .location:
            return baseLocationInput.slateTrimmedNonEmpty ?? vm.locationLabel.slateTrimmedNonEmpty
        case .localHire:
            return vm.slateSelections.localHireMarket?.slateTrimmedNonEmpty
        case .unionStatus:
            return (vm.slateSelections.unionStatus ?? actorProfileManager.profile.sagDisplayStatus).slateTrimmedNonEmpty
        case .representation:
            return (vm.slateSelections.representation ?? defaultRepresentationText)?.slateTrimmedNonEmpty
        case .contact:
            return (vm.slateSelections.contact ?? defaultContactText)?.slateTrimmedNonEmpty
        }
    }

    private var slatePromptModeBinding: Binding<SlatePromptMode> {
        Binding(
            get: { isEditingSlatePreview ? .custom : .auto },
            set: { newMode in
                let wantsCustom = newMode == .custom
                if !wantsCustom {
                    storedSlatePrompt = nil
                    if focusedField == .slatePreview {
                        focusedField = nil
                        dismissKeyboard()
                    }
                }
                isEditingSlatePreview = wantsCustom
            }
        )
    }
    
    private var slatePreviewCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("SLATE PREVIEW")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(.orange)
                    .tracking(1)
                Spacer()
            }

            Picker("Slate Script Mode", selection: slatePromptModeBinding) {
                Text("Auto").tag(SlatePromptMode.auto)
                Text("Custom").tag(SlatePromptMode.custom)
            }
            .pickerStyle(.segmented)
            .tint(palette.primaryAccent)
            
            if isEditingSlatePreview {
                Text("Tap the checkmark to dismiss the keyboard.")
                    .font(.caption)
                    .foregroundStyle(Color.white.opacity(0.7))
            }

            ZStack(alignment: .topTrailing) {
                Group {
                    if isEditingSlatePreview {
                        TextEditor(text: $customSlatePreviewText)
                            .frame(minHeight: 140)
                            .foregroundColor(.white)
                            .tint(.white)
                            .scrollContentBackground(.hidden)
                            .padding(12)
                            .focused($focusedField, equals: .slatePreview)
                    } else {
                        Text(activeSlatePreviewText)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.leading)
                            .lineSpacing(4)
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .background(
                    SafeRoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.08))
                        .overlay(
                            SafeRoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(isEditingSlatePreview ? 0.35 : 0.18), lineWidth: 1)
                        )
                )
            }
            .onChange(of: isEditingSlatePreview, initial: false) { _, editing in
                if !editing, focusedField == .slatePreview {
                    focusedField = nil
                    dismissKeyboard()
                }
            }

            if isEditingSlatePreview {
                HStack {
                    Button("Save Slate Script") {
                        handleSaveCustomPreview()
                    }
                    .disabled(customSlatePreviewText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    
                    Spacer()
                    
                    Button("Reset to Suggested") {
                        handleResetCustomPreview()
                    }
                }
                .font(.footnote)
            }
            
            LazyVGrid(columns: slateTagColumns, alignment: .leading, spacing: 8) {
                ForEach(SlateField.allCases, id: \.self) { field in
                    if vm.slateSelections.include.contains(field) {
                        Text(slateFieldTitle(field))
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(Color.white.opacity(0.12))
                            )
                    }
                }
                
                if let notes = vm.slateSelections.notes, !notes.isEmpty {
                    Text("Notes")
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.12))
                        )
                }

                if vm.slateSelections.includePassport,
                   vm.slateSelections.hasValidPassport == true {
                    Text("Passport")
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.12))
                        )
                }

                if vm.slateSelections.includeCitizenship,
                   vm.slateSelections.isLegalCitizen == true,
                   let country = vm.slateSelections.citizenshipCountry?.slateTrimmedNonEmpty,
                   !country.isEmpty {
                    Text("Citizenship")
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.12))
                        )
                }
            }
        }
    }
    
    private var activeSlatePreviewText: String {
        if let trimmed = storedSlatePrompt?.trimmingCharacters(in: .whitespacesAndNewlines),
           !trimmed.isEmpty {
            return trimmed
        }
        return deterministicSlatePreviewText
    }
    
    private var deterministicSlatePreviewText: String {
        slatePromptResolution.prompt
    }
    
    private var slatePromptResolution: SlatePromptResolver.Result {
        SlatePromptResolver.resolve(
            profile: actorProfileManager.profile,
            project: nil,
            session: nil,
            selections: vm.slateSelections,
            fallbackLocation: baseLocationInput,
            heightOverride: actorHeightInput,
            locationOverride: baseLocationInput
        )
    }
    
    private func handleSaveCustomPreview() {
        let trimmed = customSlatePreviewText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        storeSlatePrompt(trimmed)
        suppressSlatePreviewAutoSave = true
        customSlatePreviewText = trimmed
        if focusedField == .slatePreview {
            focusedField = nil
            dismissKeyboard()
        }
    }
    
    private func handleResetCustomPreview() {
        let defaultText = deterministicSlatePreviewText
        suppressSlatePreviewAutoSave = true
        customSlatePreviewText = defaultText
        storeSlatePrompt(nil)
        isEditingSlatePreview = false
        if focusedField == .slatePreview {
            focusedField = nil
            dismissKeyboard()
        }
    }
    
    private func storeSlatePrompt(_ text: String?) {
        let trimmed = text?.slateTrimmedNonEmpty
        storedSlatePrompt = trimmed
    }

    private var defaultContactText: String? {
        let profile = actorProfileManager.profile
        let parts = [profile.email.slateTrimmedNonEmpty, profile.phone.slateTrimmedNonEmpty].compactMap { $0 }
        guard !parts.isEmpty else { return nil }
        return parts.joined(separator: " / ")
    }

    private var defaultRepresentationText: String? {
        if let repID = vm.selectedRepID,
           let rep = repsVM.reps.first(where: { $0.id == repID }) {
            return rep.name
        }
        return nil
    }
    private var importSidesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("IMPORT SIDES")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(.orange)
            
            Button(action: {
                focusedField = nil
                print("🚨 SIDES IMPORT BUTTON CLICKED!")
                importType = .sides
                showFileImporter = true
            }) {
                HStack(spacing: 12) {
                    Image(systemName: "doc.badge.plus")
                        .font(.system(size: 16))
                        .foregroundStyle(.blue)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(sidesFileName ?? "Upload PDF or TXT file")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(sidesFileName != nil ? .white : .gray)
                        
                        Text("Script pages for the audition")
                            .font(.system(size: 12))
                            .foregroundStyle(.gray)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12))
                        .foregroundStyle(.gray)
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .background(
                    SafeRoundedRectangle(cornerRadius: 8)
                        .fill(Color.black.opacity(0.4))
                        .overlay(
                            SafeRoundedRectangle(cornerRadius: 8)
                                .stroke(.white.opacity(0.2), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(PlainButtonStyle())
            .contentShape(Rectangle())
            
            Button {
                focusedField = nil
                requestImport(for: .sides, source: .photos)
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "photo.on.rectangle")
                        .font(.system(size: 16))
                        .foregroundStyle(.purple)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Import from Photos")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white)
                        Text("Use screenshots or camera images")
                            .font(.system(size: 12))
                            .foregroundStyle(.gray)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12))
                        .foregroundStyle(.gray)
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .background(
                    SafeRoundedRectangle(cornerRadius: 8)
                        .fill(Color.black.opacity(0.35))
                        .overlay(
                            SafeRoundedRectangle(cornerRadius: 8)
                                .stroke(.white.opacity(0.15), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
        }
    }
    
    private var scenesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("SCENES REQUIRED")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(.orange)
                Spacer()
            }
            
            Picker(selection: Binding(
                get: { vm.numberOfScenes },
                set: { newValue in
                    // ✅ Never allow reducing below the original scene count
                    vm.numberOfScenes = max(newValue, minimumSceneCount)
                }
            )) {
                ForEach(1...10, id: \.self) { n in
                    let label = n == 1 ? "1 Scene" : "\(n) Scenes"

                    HStack(spacing: 4) {
                        Text(label)
                        if n < minimumSceneCount {
                            // 🔒 Show a small "locked" hint for previously committed scenes
                            Text("locked")
                                .font(.caption2)
                                .italic()
                        }
                    }
                    .tag(n)
                    .foregroundStyle(n < minimumSceneCount ? .gray : .primary)
                }
            } label: {
                HStack {
                    Image(systemName: "number")
                        .font(.system(size: 16))
                        .foregroundStyle(.blue)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Number of Scenes")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white)
                        Text("How many scenes will you be recording?")
                            .font(.system(size: 12))
                            .foregroundStyle(.gray)
                    }
                    
                    Spacer()
                    
                    Text("\(vm.numberOfScenes)")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                    
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12))
                        .foregroundStyle(.gray)
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .background(
                    SafeRoundedRectangle(cornerRadius: 8)
                        .fill(Color.black.opacity(0.4))
                        .overlay(
                            SafeRoundedRectangle(cornerRadius: 8)
                                .stroke(.white.opacity(0.2), lineWidth: 1)
                        )
                )
            }
            .pickerStyle(.menu)
            
            if minimumSceneCount > 1 {
                Text("You already planned \(minimumSceneCount) scenes for this project. You can add more scenes, but you can't remove existing ones without losing recorded takes.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 4)
            } else {
                Text("You can adjust the number of scenes at any time. Once you've recorded takes, your original scene count becomes the minimum.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 4)
            }
        }
    }
    // MARK: - Step 3: Review Project
    private var reviewProjectStep: some View {
        VStack(spacing: 32) {
            // Main Title - Movie Style
            VStack(spacing: 8) {
                Text(vm.title.isEmpty ? "UNTITLED PROJECT" : vm.title.uppercased())
                    .font(.system(size: 28, weight: .black, design: .default))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .tracking(2)
                
                HStack(spacing: 12) {
                    Text(vm.projectType.uppercased())
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(
                            SafeCapsule()
                                .fill(Theme.primary)
                        )
                    
                    if !selectedGenre.isEmpty {
                        Text(selectedGenre.uppercased())
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(
                                SafeCapsule()
                                    .fill(Color.white.opacity(0.2))
                            )
                            .overlay(
                                SafeCapsule()
                                    .stroke(.white.opacity(0.3), lineWidth: 1)
                            )
                    }
                }
            }
            
            if !vm.roleName.isEmpty {
                VStack(spacing: 4) {
                    Text("FEATURING")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(.orange)
                        .tracking(1)
                    
                    Text(vm.roleName.uppercased())
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                        .tracking(1)
                }
            }
            
            Rectangle()
                .frame(height: 1)
                .foregroundStyle(Theme.primary)
                .frame(maxWidth: 200)
            
            if let repID = vm.selectedRepID,
               let rep = repsVM.reps.first(where: { $0.id == repID }) {
                VStack(spacing: 4) {
                    Text("BROUGHT TO YOU BY")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(.orange)
                        .tracking(1)
                    
                    Text(rep.name.uppercased())
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                    
                    Text(rep.category.uppercased())
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(.gray)
                }
            }
            
            VStack(spacing: 16) {
                if !vm.castingOffice.isEmpty || !vm.castingDirector.isEmpty {
                    VStack(spacing: 8) {
                        Text("CASTING")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(.orange)
                            .tracking(1)
                        
                        VStack(spacing: 4) {
                            if !vm.castingDirector.isEmpty {
                                Text(vm.castingDirector.uppercased())
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(.white)
                            }
                            
                            if !vm.castingOffice.isEmpty {
                                Text(vm.castingOffice.uppercased())
                                    .font(.system(size: 12, weight: .regular))
                                    .foregroundStyle(.gray)
                            }
                        }
                    }
                }
                
                VStack(spacing: 12) {
                    VStack(spacing: 4) {
                        Text("AUDITION DUE")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(vm.isAuditionDueSoon ? .red : .orange)
                            .tracking(1)
                        
                        HStack(spacing: 8) {
                            Text(vm.auditionDueDate.formatted(date: .abbreviated, time: .shortened))
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(vm.isAuditionDueSoon ? .red : .white)
                            
                            if vm.isAuditionDueSoon {
                                HStack(spacing: 4) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .font(.system(size: 12))
                                        .foregroundStyle(.red)
                                    Text("URGENT")
                                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                                        .foregroundStyle(.red)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(
                                    SafeCapsule()
                                        .fill(Color.red.opacity(0.2))
                                )
                                .overlay(
                                    SafeCapsule()
                                        .stroke(.red.opacity(0.4), lineWidth: 1)
                                )
                            } else {
                                Text("(\(vm.daysUntilAuditionDue) DAYS)")
                                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                                    .foregroundStyle(.gray)
                            }
                        }
                    }
                    
                    HStack(spacing: 8) {
                        Image(systemName: "film")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.primary)
                        
                        Text("\(vm.numberOfScenes) \(vm.numberOfScenes == 1 ? "SCENE" : "SCENES")")
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundStyle(.white)
                    }
                    
                    if sidesFileName != nil || breakdownFileName != nil {
                        VStack(spacing: 4) {
                            Text("MATERIALS ATTACHED")
                                .font(.system(size: 8, weight: .bold, design: .monospaced))
                                .foregroundStyle(.green)
                                .tracking(1)
                            
                            HStack(spacing: 16) {
                                if sidesFileName != nil {
                                    HStack(spacing: 4) {
                                        Image(systemName: "doc.text")
                                            .font(.system(size: 10))
                                            .foregroundStyle(.blue)
                                        Text("SIDES")
                                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                                            .foregroundStyle(.white)
                                    }
                                }
                                
                                if breakdownFileName != nil {
                                    HStack(spacing: 4) {
                                        Image(systemName: "doc.badge.plus")
                                            .font(.system(size: 10))
                                            .foregroundStyle(.blue)
                                        Text("BREAKDOWN")
                                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                                            .foregroundStyle(.white)
                                    }
                                }
                            }
                        }
                    }
                    
                    if let breakdownNotes = breakdownTextInput.slateTrimmedNonEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("BREAKDOWN NOTES")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(.orange)
                            
                            Text(breakdownNotes)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.white)
                                .multilineTextAlignment(.leading)
                                .lineSpacing(4)
                        }
                        .padding(14)
                        .background(
                            SafeRoundedRectangle(cornerRadius: 10)
                                .fill(Color.black.opacity(0.35))
                                .overlay(
                                    SafeRoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                                )
                        )
                    }
                }
            }
            
            slatePreviewCard
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 40)
    }
    
    // MARK: - Navigation
    private var navigationButton: some View {
        VStack(spacing: 8) {
            // Validation message for required fields
            if currentStep == 1 && !vm.canProceedFromStep1 {
                Text("Project title and role name are required")
                    .font(Theme.Font.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
            
            if currentStep == 2 && !vm.canProceedFromStep2 {
                Text("Please select number of scenes (1-10)")
                    .font(Theme.Font.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
            
            if currentStep == totalSteps && !vm.canProceedToRecording {
                Text("Please complete all required fields")
                    .font(Theme.Font.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
            
            if currentStep < totalSteps {
                let isDisabled = (currentStep == 1 && !vm.canProceedFromStep1) || (currentStep == 2 && !vm.canProceedFromStep2)
                Button(action: {
                    guard !isDisabled else { return }
                    withAnimation(.easeInOut(duration: 0.3)) {
                        currentStep += 1
                    }
                }) {
                    HStack(spacing: 10) {
                        Image(systemName: nextButtonIcon)
                            .font(.body.weight(.semibold))
                        Text(nextButtonTitle)
                            .font(.body.weight(.semibold))
                    }
                    .foregroundColor(theme.primaryButtonForeground)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 24)
                    .background(theme.primaryButtonBackground)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(theme.primaryButtonStroke, lineWidth: 1)
                    )
                    .shadow(color: theme.primaryAccent.opacity(0.4), radius: 10, x: 0, y: 8)
                }
                .buttonStyle(.plain)
                .disabled(isDisabled)
                .opacity(isDisabled ? 0.6 : 1.0)
            } else {
                finalReviewButtons
            }
        }
        .padding(.bottom, 34)
    }
    
    private func startRecordingFlow() {
        guard vm.canProceedToRecording else { return }
        let newProject = buildProject()
        guard let firstSession = newProject.sessions.first else { return }

        persistProjectForRecording(newProject)
        didCommitProject = true

        let persistedProject = projectsRepository.project(by: newProject.id) ?? newProject
        onSave(persistedProject)

        let projectID = persistedProject.id
        let sessionID = firstSession.id
        DispatchQueue.main.async {
            print("🎬 Wizard: signaling host to present TakeReview for project=\(projectID) session=\(sessionID)")
            onRecordingComplete?(projectID, sessionID)
        }

        DispatchQueue.main.async {
            dismiss()
        }
    }

    private func persistProjectForRecording(_ project: Project) {
        if projectsRepository.project(by: project.id) != nil {
            projectsRepository.updateProject(project)
        } else {
            projectsRepository.insert(project: project)
            autoCreatedProjectID = project.id
        }
    }
    
    private func scheduleAutoSave(reason: String) {
        guard autoSaveEnabled else { return }
        autoSaveWorkItem?.cancel()
        let workItem = DispatchWorkItem {
            self.autoSaveProject(reason: reason)
        }
        autoSaveWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: workItem)
    }
    
    private func autoSaveProject(reason: String) {
        guard autoSaveEnabled else { return }
        autoSaveWorkItem?.cancel()
        autoSaveWorkItem = nil
        let updatedProject = buildProject()
        onSave(updatedProject)
        print("💾 Auto-saved project edits (\(reason)) for \(updatedProject.title)")
    }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    private func cleanupAutoCreatedProjectIfNeeded() {
        guard !didCommitProject, let projectID = autoCreatedProjectID,
              let project = projectsRepository.project(by: projectID) else { return }
        projectsRepository.delete(project: project)
        autoCreatedProjectID = nil
    }
    
    private var finalReviewButtons: some View {
        VStack(spacing: 12) {
            PosterMarqueeButton(
                title: "Complete Project Setup",
                subtitle: "Get ready for your stellar performance",
                isEnabled: vm.canProceedToRecording
            ) {
                startRecordingFlow()
            }
            .frame(height: 44)
            .padding(.top, 8)
        }
        .padding(.horizontal, 6)
    }
    
    private var nextButtonTitle: String {
        switch currentStep {
        case 1:
            return "Next: Casting & Materials"
        case 2:
            return "Next: Slate & Profile"
        case 3:
            return "Review Details"
        default:
            return "Continue"
        }
    }
    
    private var nextButtonIcon: String {
        switch currentStep {
        case 1:
            return "doc.badge.plus"
        case 2:
            return "person.text.rectangle"
        case 3:
            return "checkmark.circle.fill"
        default:
            return "chevron.right"
        }
    }
    
    // MARK: - Focus Management Helper Methods
    private func focusPreviousField() {
        guard let currentField = focusedField else { return }
        let fields = FocusableField.allCases
        if let currentIndex = fields.firstIndex(of: currentField),
           currentIndex > 0 {
            focusedField = fields[currentIndex - 1]
        }
    }
    
    private func focusNextField() {
        guard let currentField = focusedField else {
            focusedField = FocusableField.allCases.first
            return
        }
        let fields = FocusableField.allCases
        if let currentIndex = fields.firstIndex(of: currentField),
           currentIndex < fields.count - 1 {
            focusedField = fields[currentIndex + 1]
        }
    }
    
    private func canFocusPrevious() -> Bool {
        guard let currentField = focusedField else { return false }
        return FocusableField.allCases.first != currentField
    }
    
    private func canFocusNext() -> Bool {
        guard let currentField = focusedField else { return true }
        return FocusableField.allCases.last != currentField
    }
    
    // MARK: - Import Helpers
    /// Entry point for all sides / breakdown imports. Prompts if replacing.
    private func requestImport(for type: ImportType, source: ImportSource) {
        let existingName: String?
        switch type {
        case .sides:
            existingName = sidesFileName?.trimmingCharacters(in: .whitespacesAndNewlines)
        case .breakdown:
            existingName = breakdownFileName?.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        if let name = existingName, !name.isEmpty {
            pendingImportType = type
            pendingImportSource = source
            showReplaceConfirmation = true
        } else {
            startImport(for: type, source: source)
        }
    }
    
    /// Actually triggers Files / Photos once confirmed.
    private func startImport(for type: ImportType, source: ImportSource) {
        importType = type
        switch source {
        case .files:
            showFileImporter = true
        case .photos:
            photoPickerType = type
            showPhotoPicker = true
        }
    }
    
    // MARK: - File Import
    // MARK: - File Copy Helper
    private func handleFileImport(result: Result<[URL], Error>) {
        importStatus = .importing
        
        
        DispatchQueue.global(qos: .userInitiated).async {
            switch result {
            case .success(let urls):
                guard let url = urls.first else {
                    DispatchQueue.main.async {
                        self.importStatus = .error("No file selected")
                    }
                    return
                }
                
                let fileName = url.lastPathComponent
                
                do {
                    // Use SafeDocumentStore to securely import the file
                    let result = try SafeDocumentStore.importFromPicker(url: url, preferredName: fileName, subfolder: nil)
                    if self.importType == .sides {
                        self.sidesURL = result.localURL
                        self.sidesFileName = result.fileName
                    } else {
                        self.breakdownURL = result.localURL
                        self.breakdownFileName = result.fileName
                    }
                    
                    DispatchQueue.main.async {
                        switch self.importType {
                        case .sides:
                            self.sidesFileName = result.fileName
                            self.importStatus = .success("Sides imported: \(result.fileName)")
                            
                            
                        case .breakdown:
                            self.breakdownFileName = result.fileName
                            self.importStatus = .success("Breakdown imported: \(result.fileName)")
                            self.didTouchBreakdownNotes = true
                        }
                        
                        print("✅ File imported to: \(result.localURL.path)")
                        
                        // Clear success message after 3 seconds
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                            self.importStatus = .idle
                        }
                    }
                } catch {
                    DispatchQueue.main.async {
                        
                        self.importStatus = .error("Import failed: \(error.localizedDescription)")
                        print("❌ Failed to import file: \(error)")
                        
                        // Clear error message after 5 seconds
                        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                            self.importStatus = .idle
                        }
                    }
                }
                
            case .failure(let error):
                DispatchQueue.main.async {
                    
                    self.importStatus = .error("Import failed: \(error.localizedDescription)")
                    
                    // Clear error message after 5 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                        self.importStatus = .idle
                    }
                }
            }
        }
    }
    
    private func preferredPhotoFileName(for type: ImportType, contentType: UTType?) -> String {
        let base = type == .sides ? "SidesPhoto" : "BreakdownPhoto"
        let ext = contentType?.preferredFilenameExtension ?? "jpg"
        return "\(base)_\(Int(Date().timeIntervalSince1970)).\(ext)"
    }
    
    private func handlePhotoPickerSelection(item: PhotosPickerItem) async {
        defer {
            Task { @MainActor in
                selectedPhotoItem = nil
                showPhotoPicker = false
            }
        }
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                await MainActor.run {
                    importStatus = .error("Unable to read selected photo")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) { importStatus = .idle }
                }
                return
            }
            let filename = preferredPhotoFileName(for: photoPickerType, contentType: item.supportedContentTypes.first)
            let result = try SafeDocumentStore.save(data: data, preferredFileName: filename, subfolder: nil)
            await MainActor.run {
                switch photoPickerType {
                case .sides:
                    sidesURL = result.localURL
                    sidesFileName = result.fileName
                case .breakdown:
                    breakdownURL = result.localURL
                    breakdownFileName = result.fileName
                    didTouchBreakdownNotes = true
                }
                importStatus = .success("\(photoPickerType == .sides ? "Sides" : "Breakdown") photo added: \(result.fileName)")
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    importStatus = .idle
                }
            }
        } catch {
            await MainActor.run {
                importStatus = .error("Photo import failed: \(error.localizedDescription)")
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    importStatus = .idle
                }
            }
        }
    }
    // MARK: - Project Building
    private var autoSaveSignature: String {
        guard autoSaveEnabled else { return "" }
        
        let includeSignature = vm.slateSelections.include.map { $0.rawValue }.sorted().joined(separator: ",")
        let payTagsSignature = payDeal.selectedTags.map { $0.rawValue }.sorted().joined(separator: ",")
        let ccSignature = vm.ccRepIDs.map { $0.uuidString }.sorted().joined(separator: ",")
        let bccSignature = vm.bccRepIDs.map { $0.uuidString }.sorted().joined(separator: ",")
        let headshotSignature = submittedHeadshotID?.uuidString ?? "nil"
        let repSignature = vm.selectedRepID?.uuidString ?? "nil"
        
        var components: [String] = []
        components.reserveCapacity(32)
        
        func append(_ value: String) {
            components.append(value)
        }
        
        append(vm.title)
        append(vm.roleName)
        append(vm.projectType)
        append(vm.projectGenre)
        append("\(vm.numberOfScenes)")
        append(String(vm.auditionDueDate.timeIntervalSinceReferenceDate))
        append(String(vm.shootDate.timeIntervalSinceReferenceDate))
        append(vm.castingOffice)
        append(vm.castingDirector)
        append(vm.contactEmail)
        append(vm.contactPhone)
        append(vm.locationLabel)
        append(vm.locationAddress)
        append(baseLocationInput)
        append(selectedGenre)
        append(breakdownTextInput)
        append(storedSlatePrompt ?? "")
        append(sidesFileName ?? "")
        append(breakdownFileName ?? "")
        append(headshotSignature)
        append(repSignature)
        append(ccSignature)
        append(bccSignature)
        append(includeSignature)
        append(localHireInput)
        append(vm.slateSelections.localHireMarket ?? "")
        append(vm.slateSelections.unionStatus ?? "")
        append(vm.slateSelections.representation ?? "")
        append(vm.slateSelections.contact ?? "")
        append(vm.slateSelections.notes ?? "")
        append(vm.slateSelections.framingSelection.rawValue)
        append(vm.slateSelections.includePassport ? "passport_on" : "passport_off")
        append(vm.slateSelections.hasValidPassport.map { $0 ? "passport_yes" : "passport_no" } ?? "passport_nil")
        append(vm.slateSelections.includeCitizenship ? "citizenship_on" : "citizenship_off")
        append(vm.slateSelections.isLegalCitizen.map { $0 ? "citizen_yes" : "citizen_no" } ?? "citizen_nil")
        append(vm.slateSelections.citizenshipCountry ?? "")
        append(payTagsSignature)
        append(payDeal.rateText)
        append(String(payDeal.craftVsMoney))
        append(payDeal.unionStatus?.rawValue ?? "nil")
        append(payDeal.roleType?.rawValue ?? "nil")
        append(materialsSummaryText)
        
        return components.joined(separator: "|")
    }

    private func syncSlateOverridesToViewModel() {
        let trimmedLocation = baseLocationInput.trimmingCharacters(in: .whitespacesAndNewlines)
        if vm.locationLabel != trimmedLocation {
            vm.locationLabel = trimmedLocation
        }

        let trimmedLocalHire = localHireInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedLocalHire = trimmedLocalHire.isEmpty ? nil : trimmedLocalHire
        if vm.slateSelections.localHireMarket != resolvedLocalHire {
            vm.slateSelections.localHireMarket = resolvedLocalHire
        }
    }
    
    private func buildProject() -> Project {
        syncSlateOverridesToViewModel()
        var project = vm.buildProject()
        project.id = wizardProjectID
        let resolvedSessionLocation = project.sessions.first?.location
        let promptOverride = storedSlatePrompt?.slateTrimmedNonEmpty
        let promptMode: SlatePromptMode = promptOverride == nil ? .auto : .custom
        let promptResolution = slatePromptResolution
        let promptUpdatedAt = Date()
        
        // (Optional future) When Project supports genres, apply it here.
        project.genre = selectedGenre
        project.slateSelections = vm.slateSelections
        if didTouchBreakdownNotes {
            project.breakdownNotes = breakdownTextInput.slateTrimmedNonEmpty
        }
        
        // Apply representation
        if let repID = vm.selectedRepID,
           let rep = repsVM.reps.first(where: { $0.id == repID }) {
            project.representation = Contact(
                name: rep.name,
                email: rep.email,
                phone: rep.phone
            )
        }
        project.submittedHeadshotID = submittedHeadshotID
        
        if !payDeal.selectedTags.isEmpty {
            project.payDealTagsRaw = payDeal.selectedTags.map { $0.rawValue }.joined(separator: ",")
        } else {
            project.payDealTagsRaw = nil
        }
        let rate = payDeal.rateText.trimmingCharacters(in: .whitespacesAndNewlines)
        project.payRateText = rate.isEmpty ? nil : rate
        project.payCraftVsMoney = payDeal.craftVsMoney
        project.payUnionStatusRaw = payDeal.unionStatus?.rawValue
        project.payRoleTypeRaw = payDeal.roleType?.rawValue
        
        project.sidesFileName = sidesFileName
        project.breakdownFileName = breakdownFileName
        
        // ----------------------------------------------------
        // ✅ NEW — Safe session merge to prevent take loss
        // ----------------------------------------------------
        let existingProject = projectsRepository.project(by: project.id)
#if DEBUG
        let existingSessionCount = existingProject?.sessions.count ?? 0
        STSLogProjectMerge("Editing project \(project.id) — existing sessions: \(existingSessionCount), existing sceneCount: \(existingProject?.sceneCount ?? -1), new sceneCount: \(project.sceneCount)")
#endif

        if let existingProject, !existingProject.sessions.isEmpty {
            // Editing an existing project: preserve ALL sessions + ALL takes
#if DEBUG
            STSLogProjectMerge("Merging into EXISTING project. Preserving all sessions & takes.")
#endif
            project.sessions = existingProject.sessions.enumerated().map { index, session in
                var updated = session
                if index == 0 {
                    // Enrich first session only — DO NOT modify ID or takes
                    updated.sidesFileName = sidesFileName
                    updated.breakdownFileName = breakdownFileName
                    if didTouchBreakdownNotes {
                        updated.breakdownNotes = breakdownTextInput.slateTrimmedNonEmpty
                    }
                    updated.slatePrompt = promptMode == .custom ? promptOverride : nil
                    updated.slatePromptMode = promptMode
                    updated.slatePromptOverride = promptOverride
                    updated.slatePromptInputsHash = promptResolution.inputsHash
                    updated.slatePromptUpdatedAt = promptUpdatedAt
                    updated.location = resolvedSessionLocation

                    var checklist = session.auditionChecklist ?? ChecklistProgress(sessionID: session.id)
                    let signals = WizardChecklistSignals(
                        editedSubmissionWindow: didEditSubmissionWindow,
                        editedSlateDetails: didEditSlateDetails,
                        touchedBreakdownNotes: didTouchBreakdownNotes
                    )
                    checklist.applyAutoFlags(from: project, session: updated, signals: signals)
                    updated.auditionChecklist = checklist

                    updated.unlockedBadges = session.unlockedBadges
                }
#if DEBUG
                STSLogProjectMerge("Session[\(index)] id=\(session.id) → preserving id=\(updated.id), sides=\(String(describing: updated.sidesFileName)), breakdown=\(String(describing: updated.breakdownFileName))")
#endif
                return updated
            }
        }
        else if !project.sessions.isEmpty {
            // New project — safe to modify session ID, since no recordings yet
#if DEBUG
            STSLogProjectMerge("Creating NEW project sessions (no existing sessions found). Safe to assign wizardSessionID to first session.")
#endif
            project.sessions = project.sessions.enumerated().map { index, session in
                var updated = session
                if index == 0 {
                    updated.id = wizardSessionID
                    updated.sidesFileName = sidesFileName
                    updated.breakdownFileName = breakdownFileName
                    if didTouchBreakdownNotes {
                        updated.breakdownNotes = breakdownTextInput.slateTrimmedNonEmpty
                    }
                    updated.slatePrompt = promptMode == .custom ? promptOverride : nil
                    updated.slatePromptMode = promptMode
                    updated.slatePromptOverride = promptOverride
                    updated.slatePromptInputsHash = promptResolution.inputsHash
                    updated.slatePromptUpdatedAt = promptUpdatedAt
                    updated.location = resolvedSessionLocation

                    var checklist = ChecklistProgress(sessionID: updated.id)
                    let signals = WizardChecklistSignals(
                        editedSubmissionWindow: didEditSubmissionWindow,
                        editedSlateDetails: didEditSlateDetails,
                        touchedBreakdownNotes: didTouchBreakdownNotes
                    )
                    checklist.applyAutoFlags(from: project, session: updated, signals: signals)
                    updated.auditionChecklist = checklist
                }
#if DEBUG
                STSLogProjectMerge("New-project Session[\(index)] id=\(session.id) → assigned id=\(updated.id), sides=\(String(describing: updated.sidesFileName)), breakdown=\(String(describing: updated.breakdownFileName))")
#endif
                return updated
            }
        }
#if DEBUG
        STSLogProjectMerge("Final project \(project.id) — sceneCount=\(project.sceneCount), sessions=\(project.sessions.count)")
        project.sessions.enumerated().forEach { idx, session in
            STSLogProjectMerge("  -> Session[\(idx)] id=\(session.id), sides=\(String(describing: session.sidesFileName)), breakdown=\(String(describing: session.breakdownFileName))")
        }
#endif
        
        return project
    }
    
    // Keep genre aligned with the current type; select first available if needed
    
    private func syncGenreWithType() {
        let options = genreOptionsByType[vm.projectType] ?? allGenres
        if !selectedGenre.isEmpty && !options.contains(selectedGenre) {
            selectedGenre = ""
        }
    }
    
    private func genreLabel(for type: String) -> String {
        let options = genreOptionsByType[type] ?? allGenres
        if !selectedGenre.isEmpty && vm.projectType == type && options.contains(selectedGenre) {
            return selectedGenre
        }
        return "Select genre"
    }
    
    // Deprecated: was used to clamp time picker
    
    private var breakdownStatusLabel: String {
        if let name = breakdownFileName, !name.isEmpty { return name }
        return "Add"
    }
    
    private var sidesStatusLabel: String {
        if let name = sidesFileName, !name.isEmpty { return name }
        return "Add"
    }
    
    private func thumbnailForHeadshot(id: UUID?) -> UIImage? {
        Self.makeThumbnail(for: id, profileManager: actorProfileManager)
    }

    private static func makeThumbnail(for id: UUID?, profileManager: ActorProfileManager) -> UIImage? {
        guard let id,
              let asset = profileManager.profile.headshots.first(where: { $0.id == id }),
              let url = resolveHeadshotURL(named: asset.fileName) else { return nil }
        return UIImage(contentsOfFile: url.path)
    }
}

private struct ChecklistContext: Identifiable {
    let id = UUID()
    let project: Project
    let session: ProjectSession
}

private func resolveStoredSlatePrompt(from project: Project?, actorProfileUpdatedAt: Date) -> String? {
    guard let project else { return nil }
    return project.sessions
        .sorted(by: { $0.date > $1.date })
        .compactMap { session in
            guard session.slatePromptMode == .custom else { return nil }
            guard let promptUpdatedAt = session.slatePromptUpdatedAt,
                  promptUpdatedAt >= actorProfileUpdatedAt else { return nil }
            return session.slatePromptOverride?.slateTrimmedNonEmpty
                ?? session.slatePrompt?.slateTrimmedNonEmpty
        }
        .first
}

private struct WizardStepScrollContainer<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        ScrollView {
            ZStack {
                Color.clear
                    .frame(minWidth: safe(1, fallback: 1), minHeight: safe(1, fallback: 1))
                VStack(spacing: safe(16, fallback: 16)) {
                    content
                }
                .stableGeometry()
                .padding(.horizontal, safe(24, fallback: 24))
                .padding(.vertical, safe(32, fallback: 32))
            }
        }
        .scrollDismissesKeyboard(.interactively)
    }
}

private struct SlateStepScrollContainer<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                content
            }
            .stableGeometry()
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }
}

private struct PosterTicketButton: View {
    let title: String
    let subtitle: String?
    let icon: String
    let gradient: Gradient
    var isEnabled: Bool = true
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: icon)
                    .font(.body.weight(.bold))
                    .frame(width: 26, height: 26)
                    .background(.white.opacity(0.18), in: Circle())
                    .foregroundStyle(.white)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title.uppercased())
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white)
                        .tracking(0.8)
                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.85))
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 14)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        LinearGradient(gradient: gradient, startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                            .blendMode(.screen)
                    )
                    .shadow(color: .black.opacity(0.2), radius: 6, x: 0, y: 5)
            )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.5)
    }
}

private struct PosterMarqueeButton: View {
    let title: String
    let subtitle: String
    var isEnabled: Bool = true
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title.uppercased())
                        .font(.system(size: 16, weight: .black))
                        .foregroundStyle(.white)
                        .tracking(1.2)
                    Text(subtitle)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.8))
                }
                Spacer()
                Image(systemName: "arrowtriangle.forward.fill")
                    .font(.title3)
                    .foregroundStyle(.white)
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 18)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [.gray.opacity(0.7), .blue.opacity(0.5)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: .black.opacity(0.25), radius: 10, x: 0, y: 8)
            )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.6)
    }
}

private struct SubmittedHeadshotThumbnail: View {
    let image: UIImage?
    let title: String
    let onTap: () -> Void
    var textColor: Color = .secondary

    /// Shared size for Step 2 and Step 4 usage.
    /// 4:5 portrait ratio feels like a real headshot print.
    private let thumbnailSize = CGSize(width: 128, height: 160)

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                ZStack {
                    if let image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Image(systemName: "person.crop.square")
                            .resizable()
                            .scaledToFit()
                            .padding(20)
                            .opacity(0.6)
                    }
                }
                .frame(width: thumbnailSize.width, height: thumbnailSize.height)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.30), lineWidth: 1)
                )
                .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                Text(title)
                    .font(.caption)
                    .foregroundStyle(textColor)
                    .frame(maxWidth: thumbnailSize.width + 12)
                    .multilineTextAlignment(.center)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct PayDealCard: View {
    @Binding var payDeal: PayDeal
    let palette: WizardPalette
    let projectType: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Pay, Union & Deal")
                    .font(.headline)
                    .foregroundStyle(palette.primaryText)
                Spacer()
            }
            
            // Union status
            VStack(alignment: .leading, spacing: 6) {
                Text("UNION STATUS")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(.orange)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(UnionStatus.allCases) { status in
                            let isSelected = payDeal.unionStatus == status
                            Button {
                                payDeal.unionStatus = isSelected ? nil : status
                            } label: {
                                Text(status.displayName)
                                    .font(.caption)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(
                                        Capsule()
                                            .fill(isSelected ? palette.primaryAccent.opacity(0.2) : .clear)
                                    )
                                    .overlay(
                                        Capsule()
                                            .stroke(isSelected ? palette.primaryAccent : palette.secondaryText.opacity(0.5), lineWidth: 1)
                                    )
                                    .foregroundStyle(isSelected ? palette.primaryAccent : palette.primaryText)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
            
            // Role type
            VStack(alignment: .leading, spacing: 6) {
                Text("ROLE TYPE")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(.orange)
                
            let roleOptions = RoleType.available(for: projectType)
            FlexibleTagGrid(
                tags: roleOptions,
                label: { $0.displayName },
                isSelected: { payDeal.roleType == $0 },
                toggleSelection: { tapped in
                    payDeal.roleType = (payDeal.roleType == tapped) ? nil : tapped
                },
                selectedColor: palette.primaryAccent,
                textColor: palette.primaryText,
                secondaryColor: palette.secondaryText
            )
        }
            
            // Deal structure tags
            DisclosureGroup {
                let dealTags = PayDealTag.available(for: projectType)
                FlexibleTagGrid(
                    tags: dealTags,
                    label: { "• \($0.displayName)" },
                    isSelected: { payDeal.selectedTags.contains($0) },
                    toggleSelection: { tapped in
                        if payDeal.selectedTags.contains(tapped) {
                            payDeal.selectedTags.remove(tapped)
                        } else {
                            payDeal.selectedTags.insert(tapped)
                        }
                    },
                    selectedColor: palette.primaryAccent,
                    textColor: palette.primaryText,
                    secondaryColor: palette.secondaryText
                )
                .padding(.top, 6)
            } label: {
                HStack {
                    Image(systemName: "list.bullet.rectangle")
                        .foregroundStyle(palette.primaryAccent)
                    Text(payDeal.selectedTags.isEmpty ? "Select deal structure" : payDeal.selectedTags.map { $0.displayName }.sorted().joined(separator: " • "))
                        .foregroundStyle(payDeal.selectedTags.isEmpty ? palette.secondaryText : palette.primaryText)
                        .lineLimit(2)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .foregroundStyle(palette.secondaryText)
                        .font(.caption)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(palette.cardBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(palette.cardStroke, lineWidth: 1)
                        )
                )
            }
            
            // Quoted rate
            VStack(alignment: .leading, spacing: 6) {
                Text("Quoted rate (optional)")
                    .font(.caption)
                    .foregroundColor(.orange)
                
                TextField("$100/day", text: $payDeal.rateText)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .submitLabel(.done)
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(palette.cardBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(palette.cardStroke, lineWidth: 1)
                            )
                    )
                    .foregroundColor(palette.primaryText)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(palette.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(palette.cardStroke, lineWidth: 1)
                )
        )
    }
}

private struct FlexibleTagGrid<Tag: Identifiable & Hashable>: View {
    let tags: [Tag]
    let label: (Tag) -> String
    let isSelected: (Tag) -> Bool
    let toggleSelection: (Tag) -> Void
    var selectedColor: Color = .accentColor
    var textColor: Color = .primary
    var secondaryColor: Color = .secondary
    
    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: 110), spacing: 8)]
    }
    
    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
            ForEach(tags) { tag in
                let selected = isSelected(tag)
                Button {
                    toggleSelection(tag)
                } label: {
                    Text(label(tag))
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(selected ? selectedColor.opacity(0.18) : Color.clear)
                        )
                        .overlay(
                            Capsule()
                                .strokeBorder(selected ? selectedColor : secondaryColor.opacity(0.5), lineWidth: 1)
                        )
                        .foregroundStyle(selected ? selectedColor : textColor)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct MaterialRow: View {
    let title: String
    let status: String
    let hasNotes: Bool
    let onTap: () -> Void
    let palette: WizardPalette
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                Label(title, systemImage: title == "Breakdown" ? "doc.text.magnifyingglass" : "doc.on.doc")
                    .labelStyle(.titleAndIcon)
                Spacer()
                if hasNotes {
                    Image(systemName: "text.bubble")
                        .foregroundColor(palette.secondaryText)
                }
                Text(status)
                    .font(.caption)
                    .foregroundColor(palette.secondaryText)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(palette.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(palette.cardStroke, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

private struct MaterialOverlayPanel: View {
    let kind: MaterialKind
    let currentFileName: String?
    @Binding var notes: String
    let showsNotes: Bool
    let onImportFromFiles: () -> Void
    let onImportFromPhotos: () -> Void
    let onClear: () -> Void
    let onDismiss: () -> Void
    
    private var title: String {
        switch kind {
        case .breakdown: return "Breakdown"
        case .sides: return "Sides"
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text(title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                
                Spacer()

                Button(action: onDismiss) {
                    Text("Done")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(.white.opacity(0.12), in: Capsule())
                }
                .accessibilityLabel("Done")
            }
            
            Text(kind == .breakdown
                 ? "Attach the original casting breakdown so you can reference character details right inside your session."
                 : "Attach your script sides as a PDF or images. They’ll be ready for teleprompter and script view in Camera.")
            .font(.system(size: 13))
            .foregroundStyle(.white.opacity(0.75))
            .fixedSize(horizontal: false, vertical: true)
            
            VStack(alignment: .leading, spacing: 10) {
                Text("Attached File")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.8))
                
                HStack(spacing: 10) {
                    Image(systemName: currentFileName == nil ? "doc.badge.plus" : "doc.text")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(currentFileName ?? "No file attached")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        
                        Text(currentFileName == nil ? "Choose a document or photo to attach." : "Tap a source below to replace this file.")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.7))
                            .lineLimit(2)
                    }
                    
                    Spacer()
                }
                
                if currentFileName != nil {
                    Button(role: .destructive) {
                        onClear()
                    } label: {
                        Label("Remove Attachment", systemImage: "trash")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .buttonStyle(.bordered)
                    .tint(.red.opacity(0.8))
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.05))
            )
            
            HStack(spacing: 10) {
                Button(action: onImportFromFiles) {
                    Label("Import from Files", systemImage: "folder")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                
                Button(action: onImportFromPhotos) {
                    Label("Import from Photos", systemImage: "photo")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            
            if showsNotes {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Breakdown Notes")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.85))
                    
                    TextEditor(text: $notes)
                        .frame(minHeight: 100, maxHeight: 160)
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.black.opacity(0.4))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                                )
                        )
                        .foregroundColor(.white)
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.35), radius: 40, x: 0, y: 25)
        )
    }
}

private struct SubmittedHeadshotPickerSheet: View {
    let headshots: [HeadshotAsset]
    let onSelect: (HeadshotAsset, UIImage?) -> Void
    let onCancel: () -> Void
    var customActions: AnyView? = nil
    
    var body: some View {
        NavigationStack {
            List {
                if let customActions { customActions }
                
                if headshots.isEmpty {
                    Text("No headshots available in Actor Kit.")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(headshots) { asset in
                        Button {
                            onSelect(asset, Self.loadThumbnail(for: asset))
                        } label: {
                            HStack(spacing: 12) {
                                if let image = Self.loadThumbnail(for: asset) {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 54, height: 54)
                                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                } else {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(Color.gray.opacity(0.2))
                                        .frame(width: 54, height: 54)
                                        .overlay(
                                            Image(systemName: "person.crop.square")
                                                .foregroundColor(.secondary)
                                        )
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(asset.title)
                                        .foregroundColor(.primary)
                                    if asset.isProfilePhoto {
                                        Text("Profile photo")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                Spacer()
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle("Submitted Headshot")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { onCancel() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
    
    private static func loadThumbnail(for asset: HeadshotAsset) -> UIImage? {
        guard let url = resolveHeadshotURL(named: asset.fileName) else { return nil }
        return UIImage(contentsOfFile: url.path)
    }
}

#Preview {
    NewProjectWizard(repo: ProjectsRepositoryFactory.makePreviewRepository()) { project in
        print("Created project: \(project)")
    }
    .environmentObject(ThemeManager())
}

private extension Binding where Value == String? {
    func toNonOptional() -> Binding<String> {
        Binding<String>(
            get: { self.wrappedValue ?? "" },
            set: { newValue in
                self.wrappedValue = newValue.isEmpty ? nil : newValue
            }
        )
    }
}

private extension View {
    func posterCard(background: Color, stroke: Color? = nil) -> some View {
        self
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(background)
                    .overlay(
                        Group {
                            if let stroke {
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(stroke, lineWidth: 1)
                            }
                        }
                    )
            )
    }
}

private struct WizardPalette {
    let cardBackground: Color
    let cardStroke: Color
    let primaryText: Color
    let secondaryText: Color
    let primaryAccent: Color
    
    init(theme: STSTheme) {
        self.cardBackground = theme.cardBackground
        self.cardStroke = theme.cardStroke
        self.primaryText = theme.textPrimary
        self.secondaryText = theme.textSecondary
        self.primaryAccent = theme.primaryAccent
    }
}
