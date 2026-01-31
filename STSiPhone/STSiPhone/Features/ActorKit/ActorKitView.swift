import SwiftUI
import UIKit
import PhotosUI
import UniformTypeIdentifiers

struct ActorKitView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var themeManager: ThemeManager
    
    let projectsRepository: ProjectsRepository
    
    @State private var profileManager: ActorProfileManager
    @State private var repsViewModel: RepsViewModel
    
    @State private var showingFramingGuide = false
    @State private var showingMustKnows = false
    @State private var showingChecklist = false
    @State private var showingRepsManager = false
    @State private var showingProfileWizard = false
    @State private var selectedHeadshot: HeadshotAsset?
    @State private var showingHeadshotSource = false
    @State private var headshotPhotoItem: PhotosPickerItem?
    @State private var showingHeadshotPhotoPicker = false
    @State private var showingHeadshotFileImporter = false
    @State private var headshotImportError: String?
    @State private var isImportingHeadshot = false
    @State private var overlayDeleteHeadshot: HeadshotAsset?
    @State private var activeOverlay: ActorKitOverlay?
    @State private var showingSizeCardSheet = false
    @State private var sizeCardDraft: SizeCardConfig
    @State private var profileHeadshotDraft: HeadshotTransform
    @State private var sizeCardCropArmed = false
    @State private var profileCropArmed = false
    @State private var reopenSizeCardAfterWizard = false
    @State private var showingHeadshotPreview = false
    @State private var identityControlsExpanded = true
    @State private var sizesControlsExpanded = true
    @State private var representationControlsExpanded = true
    @State private var socialControlsExpanded = false
    @State private var brandingControlsExpanded = false
    @State private var showingLayoutDesigner = false
    @State private var showingSizeCardPreviewFullScreen = false
    @State private var showingResumeImporter = false
    @State private var resumeImportError: String?
    @State private var resumePreviewItem: ResumePreviewItem?
    @State private var shareSheetItem: ShareURLItem?
    @State private var showingEquipmentGuide = false
    @State private var showResumeCreatorToast = false
    @State private var showingGlobeTheatre = false
    @AppStorage("ActorKitResumeCreatorHintCount") private var resumeCreatorHintCount = 0
    @AppStorage("PreferredMapsApp") private var preferredMapsAppRaw: String = MapsAppPreference.google.rawValue
    @AppStorage("ActorKit.disableBadgeAnimation") private var disableBadgeAnimation = false
    @AppStorage("ActorKit.badgeSpeedMultiplier") private var badgeSpeedMultiplier: Double = 1.0
    @AppStorage("ActorKit.badgeStopFace") private var badgeStopFaceRaw: String = ActorKitBadgeStopFace.logo.rawValue
    @State private var repContactSelection: RepInfo?
    @State private var showingRepContactDialog = false
    @Namespace private var headshotNamespace
    
    private var theme: STSTheme { themeManager.current }
    private var badgeStopFace: ActorKitBadgeStopFace {
        ActorKitBadgeStopFace(rawValue: badgeStopFaceRaw) ?? .logo
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
    
    init(
        profileManager: ActorProfileManager = ActorProfileManager(),
        repsViewModel: RepsViewModel = RepsViewModel(),
        projectsRepository: ProjectsRepository
    ) {
        _profileManager = State(initialValue: profileManager)
        _repsViewModel = State(initialValue: repsViewModel)
        let enforcedConfig = ActorKitView.enforcedSizeCardDefaults(for: profileManager.profile.sizeCardConfig)
        _sizeCardDraft = State(initialValue: enforcedConfig)
        _profileHeadshotDraft = State(initialValue: profileManager.profile.profileHeadshotTransform)
        self.projectsRepository = projectsRepository
    }
    
    var body: some View {
        applyGlobalModifiers(to: navigationShell)
    }
    
    private var navigationShell: some View {
        NavigationStack {
            ZStack {
                theme.backgroundGradient
                    .ignoresSafeArea()
                accentGlow
                
                mainScrollContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                overlayLayer
                headshotPreviewOverlay
                if showResumeCreatorToast {
                    ResumeCreatorToast()
                        .allowsHitTesting(false)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .zIndex(30)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundStyle(.white)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingProfileWizard = true
                    } label: {
                        Image(systemName: "pencil.circle.fill")
                            .font(.title2)
                    }
                    .foregroundStyle(.white)
                    .accessibilityLabel("Edit Actor Profile")
                }
            }
        }
    }

    private func applyGlobalModifiers<Content: View>(to base: Content) -> some View {
        let withSheets = applySheetModals(to: base)
        let withLifecycle = applyLifecycleHandlers(to: withSheets)
        let withMedia = applyMediaHandlers(to: withLifecycle)
        return applyAlertsAndDialogs(to: withMedia)
    }

    private func applySheetModals<Content: View>(to base: Content) -> some View {
        AnyView(
            base
                .sheet(isPresented: $showingFramingGuide) { FramingGuideReferenceView() }
                .sheet(isPresented: $showingMustKnows) {
                    ActorMustKnowsView(repository: projectsRepository, mode: .reference) { showingMustKnows = false }
                }
                .sheet(isPresented: $showingChecklist) { InPersonChecklistView() }
                .sheet(isPresented: $showingRepsManager, onDismiss: reloadReps) { RepsFormView() }
                .sheet(isPresented: $showingProfileWizard) {
                    ActorProfileWizard(
                        startingProfile: profileManager.profile,
                        profileManager: profileManager,
                        onComplete: {
                            showingProfileWizard = false
                            profileManager = ActorProfileManager()
                        }
                    )
                }
                .sheet(item: $resumePreviewItem) { item in
                    DocumentPreviewView(documentURL: item.url, documentTitle: item.fileName)
                        .onDisappear { resumePreviewItem = nil }
                }
                .sheet(item: $shareSheetItem) { item in
                    ShareSheetController(activityItems: [item.url])
                        .onDisappear { shareSheetItem = nil }
                }
                .sheet(isPresented: $showingEquipmentGuide) { EquipmentGuideView() }
                .fullScreenCover(isPresented: $showingGlobeTheatre) {
                    SpinnerCoinTheatreView(
                        headshot: spinnerHeadshotUIImage,
                        headshotTransform: profileManager.profile.profileHeadshotTransform,
                        onClose: { showingGlobeTheatre = false }
                    )
                }
        )
    }

    private func applyLifecycleHandlers<V: View>(to base: V) -> some View {
        AnyView(
            base
                .onAppear {
                    reloadProfile()
                    reloadReps()
                    sizeCardDraft = ActorKitView.enforcedSizeCardDefaults(for: profileManager.profile.sizeCardConfig)
                    profileHeadshotDraft = profileManager.profile.profileHeadshotTransform
                }
                .onReceive(NotificationCenter.default.publisher(for: .actorProfileDidUpdate)) { _ in
                    reloadProfile()
                    reloadReps()
                    sizeCardDraft = ActorKitView.enforcedSizeCardDefaults(for: profileManager.profile.sizeCardConfig)
                    profileHeadshotDraft = profileManager.profile.profileHeadshotTransform
                }
                .onChange(of: showingSizeCardSheet, initial: false) { _, isPresented in
                    if isPresented {
                        sizeCardDraft = ActorKitView.enforcedSizeCardDefaults(for: profileManager.profile.sizeCardConfig)
                        sizeCardCropArmed = false
                    }
                }
                .onChange(of: repsViewModel.reps, initial: false) { _, newValue in
                    cleanupHiddenRepVisibilities(using: newValue)
                }
                .onChange(of: showingProfileWizard, initial: false) { _, isPresented in
                    if !isPresented, reopenSizeCardAfterWizard {
                        reopenSizeCardAfterWizard = false
                        sizeCardDraft = ActorKitView.enforcedSizeCardDefaults(for: profileManager.profile.sizeCardConfig)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                            showingSizeCardSheet = true
                        }
                    }
                }
                .onChange(of: activeOverlay, initial: false) { _, newValue in
                    if newValue == .headshotAdjust {
                        profileHeadshotDraft = profileManager.profile.profileHeadshotTransform
                        profileCropArmed = false
                    }
                }
        )
    }

    private func applyMediaHandlers<V: View>(to base: V) -> some View {
        AnyView(
            base
                .sheet(item: $selectedHeadshot) { asset in
                    HeadshotPreviewSheet(
                        assets: profileManager.profile.headshots,
                        initialAsset: asset,
                        onSetPreferred: { chosen in
                            setPreferredHeadshotAndBeginAdjustment(with: chosen)
                        },
                        onRename: { asset, newLabel in
                            profileManager.updateHeadshotDisplayName(id: asset.id, newName: newLabel)
                            profileManager = ActorProfileManager()
                        },
                        onShare: { asset in
                            shareHeadshot(asset)
                        },
                        onDelete: { asset in
                            deleteHeadshot(asset)
                        }
                    )
                    .onDisappear { selectedHeadshot = nil }
                }
                .fullScreenCover(isPresented: $showingSizeCardSheet) { sizeCardFullScreenSheet }
                .fullScreenCover(isPresented: $showingSizeCardPreviewFullScreen) {
                    SizeCardPreviewFullscreen(
                        profile: profileManager.profile,
                        reps: repsViewModel.reps,
                        config: sizeCardDraft
                    ) {
                        showingSizeCardPreviewFullScreen = false
                    }
                }
                .photosPicker(isPresented: $showingHeadshotPhotoPicker, selection: $headshotPhotoItem, matching: .images)
                .onChange(of: headshotPhotoItem, initial: false) { _, newItem in
                    guard let item = newItem else { return }
                    Task { await handleHeadshotPhotoSelection(item: item) }
                }
                .fileImporter(
                    isPresented: $showingHeadshotFileImporter,
                    allowedContentTypes: [.image],
                    allowsMultipleSelection: true
                ) { result in
                    handleHeadshotFileImport(result: result)
                }
                .fileImporter(
                    isPresented: $showingResumeImporter,
                    allowedContentTypes: [.pdf],
                    allowsMultipleSelection: true
                ) { result in
                    handleResumeImport(result: result)
                }
        )
    }

    private func applyAlertsAndDialogs<V: View>(to base: V) -> some View {
        let headshotChoice = base
            .confirmationDialog(
                "Add Headshot",
                isPresented: $showingHeadshotSource,
                titleVisibility: .visible
            ) {
                Button("Choose from Photos") { showingHeadshotPhotoPicker = true }
                    .disabled(isImportingHeadshot)
                Button("Import from Files") { showingHeadshotFileImporter = true }
                    .disabled(isImportingHeadshot)
                Button("Cancel", role: .cancel) {}
            }
        
        let headshotError = headshotChoice
            .alert(
                "Unable to Import Headshot",
                isPresented: Binding(
                    get: { headshotImportError != nil },
                    set: { if !$0 { headshotImportError = nil } }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(headshotImportError ?? "")
            }
        
        let repDialog = headshotError
            .confirmationDialog(
                repContactSelection?.name ?? "Contact Representative",
                isPresented: $showingRepContactDialog,
                titleVisibility: .visible
            ) {
                if let rep = repContactSelection {
                    if let phone = rep.phone, let callURL = dialURL(for: phone) {
                        Button("Call \(shortPhoneDisplay(phone))") {
                            openURL(callURL)
                            repContactSelection = nil
                        }
                    }
                    if let phone = rep.phone, let smsURL = textURL(for: phone) {
                        Button("Text \(shortPhoneDisplay(phone))") {
                            openURL(smsURL)
                            repContactSelection = nil
                        }
                    }
                    if let email = rep.email, let emailURL = emailURL(for: email) {
                        Button("Email \(email)") {
                            openURL(emailURL)
                            repContactSelection = nil
                        }
                    }
                    if let address = sanitizedAddress(rep.companyAddress),
                       let directionsURL = directionsURL(for: address) {
                        let destinationLabel = rep.companyName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                        let directionsTitle = destinationLabel.isEmpty ? "Directions" : "Directions to \(destinationLabel)"
                        Button(directionsTitle) {
                            openURL(directionsURL)
                            repContactSelection = nil
                        }
                    }
                }
                Button("Cancel", role: .cancel) {
                    repContactSelection = nil
                }
            } message: {
                Text(repContactSelection.map { "Choose how you’d like to reach \($0.name)." } ?? "")
            }
        
        let actionFailed = repDialog
            .alert(
                "Action Failed",
                isPresented: Binding(
                    get: { resumeImportError != nil },
                    set: { if !$0 { resumeImportError = nil } }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(resumeImportError ?? "")
            }
        
        let deleteHeadshot = actionFailed
            .alert(
                "Delete this headshot?",
                isPresented: Binding(
                    get: { overlayDeleteHeadshot != nil },
                    set: { if !$0 { overlayDeleteHeadshot = nil } }
                )
            ) {
                Button("Delete", role: .destructive) {
                    if let asset = overlayDeleteHeadshot {
                        self.deleteHeadshot(asset)
                    }
                    overlayDeleteHeadshot = nil
                }
                Button("Cancel", role: .cancel) {
                    overlayDeleteHeadshot = nil
                }
            } message: {
                Text("This will remove “\(overlayDeleteHeadshot?.title ?? "this headshot")” from your profile.")
            }
        
        return AnyView(deleteHeadshot)
    }
    
    
    // MARK: - Feature flags (disable unfinished sections)
    private var isDocumentsCardEnabled: Bool { false }
    private var isGlobeTheatreEnabled: Bool { true }

    private var actorKitContentInset: CGFloat { 24 }
    private var actorKitHeaderMinHeight: CGFloat { 170 }
    private var actorKitHeaderOverlapDepth: CGFloat { actorKitHeaderMinHeight * 0.13 }
    private var actorKitContentTopPadding: CGFloat { 12 }
    private var headshotPreviewAnimation: Animation {
        .interactiveSpring(response: 0.5, dampingFraction: 0.82, blendDuration: 0.2)
    }
    private var mainScrollContent: some View {
        StickyHeaderScroll(
            behavior: .scrollsWithContent,
            header: {
                BrandHeaderImage(
                    imageName: "ActorKitHero",
                    cardInset: actorKitContentInset,
                    overlapDepth: actorKitHeaderOverlapDepth,
                    minVisualHeight: actorKitHeaderMinHeight
                )
            },
            content: {
                VStack(spacing: 20) {
                    heroCard
                    quickActionsSection
                    resourcesSection
                    if isDocumentsCardEnabled {
                        documentsSection
                    }
                    if isGlobeTheatreEnabled {
                        globeTheatreSection
                    }
                }
                .padding(.horizontal, actorKitContentInset)
                .padding(.top, actorKitContentTopPadding - actorKitHeaderMinHeight * 0.3)
                .padding(.bottom, 28)
            }
        )
    }
    
    private var heroCard: some View {
        ActorKitCard(title: "", icon: "") {
            VStack(spacing: 16) {
                Color.clear.frame(height: 12)
                ZStack(alignment: .bottomTrailing) {
                    ActorKitHeadshotView(
                        headshotName: profileManager.profile.preferredHeadshot?.fileName,
                        transform: profileManager.profile.profileHeadshotTransform
                    )
                    .frame(width: 140, height: 140)
                    .padding(.top, 8)
                    .matchedGeometryEffect(id: "profileHeadshot", in: headshotNamespace, isSource: !showingHeadshotPreview)
                    .onTapGesture {
                        guard profileManager.profile.preferredHeadshot != nil else { return }
                        withAnimation(headshotPreviewAnimation) {
                            showingHeadshotPreview = true
                        }
                    }
                    .accessibilityAddTraits(.isButton)
                    .accessibilityLabel(profileManager.profile.preferredHeadshot == nil ? "Add headshot" : "Preview headshot")
                    .contextMenu {
                        if profileManager.profile.preferredHeadshot != nil {
                            Button("Adjust Photo") {
                                prepareProfileHeadshotAdjust()
                            }
                        }
                    }
                    .opacity(showingHeadshotPreview ? 0 : 1)
                    
                    if profileManager.profile.preferredHeadshot != nil {
                        Button {
                            prepareProfileHeadshotAdjust()
                        } label: {
                            Image(systemName: "pencil")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(10)
                                .background(.ultraThinMaterial, in: Circle())
                                .overlay(
                                    Circle()
                                        .stroke(Color.white.opacity(0.35), lineWidth: 1)
                                )
                                .shadow(color: .black.opacity(0.35), radius: 6, x: 0, y: 4)
                        }
                        .buttonStyle(.plain)
                        .offset(x: 4, y: 4)
                        .accessibilityLabel("Edit headshot")
                    }
                }
                
                VStack(spacing: 4) {
                    Text(profileManager.profile.displayName)
                        .font(Theme.Font.title)
                        .foregroundStyle(.white)
                    
                    unionInfoView
                }
                
                LazyVGrid(columns: statColumns, spacing: 12) {
                    if !profileManager.profile.height.isEmpty {
                        ActorKitStatPill(label: "Height", value: profileManager.profile.height, showsBackground: false)
                    }
                    if !profileManager.profile.ageRange.isEmpty {
                        ActorKitStatPill(label: "Age Range", value: profileManager.profile.ageRange, showsBackground: false)
                    }
                    statButton(label: "Headshots", value: headshotValue) {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                            activeOverlay = .headshots
                        }
                    }
                    statButton(label: "Representation", value: representationValue) {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                            activeOverlay = .representation
                        }
                    }
                    statButton(label: "Size Card", value: "Creator") {
                        sizeCardDraft = profileManager.profile.sizeCardConfig
                        showingSizeCardSheet = true
                    }
                    statButton(label: "Resume", value: resumeValue) {
                        handleResumeButtonTap()
                    }
                }
                .padding(.bottom, 4)
            }
        }
    }
    
    private var quickActionsSection: some View {
        ActorKitCard(title: "Talent Pre-Production", icon: "sparkles") {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                ActorKitQuickAction(
                    title: "Framing Guide",
                    subtitle: "Professional reference visuals",
                    icon: "camera.viewfinder",
                    tint: .blue.opacity(0.8)
                ) { showingFramingGuide = true }
                
                ActorKitQuickAction(
                    title: "Audition Checklist",
                    subtitle: "Pre-session ritual & focus reset",
                    icon: "checkmark.circle",
                    tint: .green.opacity(0.8)
                ) { showingMustKnows = true }
                
                ActorKitQuickAction(
                    title: "In-Person Prep",
                    subtitle: "Audition readiness list",
                    icon: "building.2",
                    tint: .orange.opacity(0.8)
                ) { showingChecklist = true }
                
                ActorKitQuickAction(
                    title: "Self Tape Gear",
                    subtitle: "Curated mics, lights & backdrops",
                    icon: "bolt.fill",
                    tint: .purple.opacity(0.85)
                ) {
                    showingEquipmentGuide = true
                }
            }
            .padding(.horizontal, 4)
        }
    }
    
    private var statColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12)
        ]
    }
    
    private func statButton(label: String, value: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ActorKitStatPill(label: label, value: value)
        }
        .buttonStyle(.plain)
    }
    
    private var headshotValue: String {
        let count = profileManager.profile.headshots.count
        return count == 0 ? "Add" : "\(count)"
    }
    
    private var representationValue: String {
        let count = repsViewModel.reps.count
        return count == 0 ? "Add" : "\(count)"
    }
    
    private var unionInfoView: some View {
        let statusText: String = {
            switch profileManager.profile.sagStatus {
            case .member:
                return "SAG-AFTRA Member"
            case .eligible:
                return "SAG-AFTRA Eligible"
            case .nonUnion:
                return "Non-Union"
            }
        }()
        return VStack(spacing: 2) {
            Text(statusText)
                .font(Theme.Font.body)
                .foregroundStyle(.white.opacity(0.85))
            if !profileManager.profile.sagNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text("#\(profileManager.profile.sagNumber.trimmingCharacters(in: .whitespacesAndNewlines))")
                    .font(Theme.Font.caption)
                    .foregroundStyle(.white.opacity(0.65))
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    private var resumeValue: String {
        let count = profileManager.profile.resumes.count
        return count == 0 ? "" : "\(count)"
    }

    private var spinnerHeadshotUIImage: UIImage? {
        guard let preferred = profileManager.profile.preferredHeadshot,
              let url = resolveHeadshotURL(named: preferred.fileName),
              let image = UIImage(contentsOfFile: url.path) else {
            return nil
        }
        return image
    }
    
    private var resourcesSection: some View {
        let links = ActorKitResourceLink.sampleLinks
        
        return ActorKitCard(title: "Industry Resources", icon: "link") {
            VStack(spacing: 12) {
                ForEach(links) { link in
                    Button {
                        if let url = link.url {
                            openURL(url)
                        }
                    } label: {
                        ActorKitRow(
                            title: link.title,
                            subtitle: link.subtitle,
                            trailing: nil,
                            icon: "arrow.up.right"
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
    
    private var documentsSection: some View {
        ActorKitCard(title: "Documents", icon: "doc.richtext") {
            if profileManager.profile.sizeCards.isEmpty &&
                profileManager.profile.resumes.isEmpty {
                VStack(spacing: 12) {
                    Text("Upload resumes and size cards to keep everything in one place.")
                        .font(Theme.Font.caption)
                        .foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 4)
                    
                    BrandedSecondaryButton(label: "Upload Resume") {
                        showingResumeImporter = true
                    }
                }
            } else {
                VStack(spacing: 12) {
                    if profileManager.profile.sizeCards.isEmpty == false {
                        ActorKitRow(
                            title: "Size Cards",
                            subtitle: "\(profileManager.profile.sizeCards.count) uploaded",
                            trailing: nil,
                            icon: "ruler"
                        )
                    }
                    
                    if profileManager.profile.resumes.isEmpty == false {
                        ActorKitRow(
                            title: "Resumes",
                            subtitle: "\(profileManager.profile.resumes.count) uploaded",
                            trailing: nil,
                            icon: "doc.text.fill",
                            applyCardBackground: false,
                            onTap: {
                                handleResumeButtonTap()
                            }
                        )
                    }
                }
            }
            
            ActorKitRow(
                title: "Coming Soon — Resume Creator!",
                subtitle: "Design polished resumes directly inside ActorKit.",
                trailing: nil,
                icon: "sparkles",
                applyCardBackground: true
            )
            .padding(.top, 8)
        }
    }

    private var globeTheatreSection: some View {
        ActorKitCard(title: "ActorKit Globe Theatre", icon: "sparkles.square.filled.on.square") {
            VStack(spacing: 16) {
                SpinnerCoinView(
                    headshot: spinnerHeadshotUIImage,
                    transform: profileManager.profile.profileHeadshotTransform,
                    height: 220,
                    animationDisabled: disableBadgeAnimation,
                    restAngleDegrees: badgeStopFace.restAngleDegrees,
                    preset: SpinnerCoinPreset.turnstile,
                    tuning: SpinnerCoinTuning.default,
                    yoYoConfig: SpinnerYoYoConfig.disabled,
                    speedMultiplier: CGFloat(badgeSpeedMultiplier)
                )
                .overlay(SpinnerOverlay())
                .padding(18)
                .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .accessibilityLabel("ActorKit Globe Theatre spinner preview")
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Color.white.opacity(0.05))
                )

                Text("Preview the tri-axis coin and dial in motion settings. (Globe Theatre stage coming soon.)")
                    .font(Theme.Font.caption)
                    .foregroundStyle(.white.opacity(0.75))
                    .multilineTextAlignment(.center)

                ActorKitBadgeControlsPanel()
            }
        }
    }
    
    private func reloadProfile() {
        profileManager = ActorProfileManager()
        sizeCardDraft = ActorKitView.enforcedSizeCardDefaults(for: profileManager.profile.sizeCardConfig)
    }
    
    private func reloadReps() {
        repsViewModel = RepsViewModel()
        cleanupHiddenRepVisibilities(using: repsViewModel.reps)
    }

    private func handleResumeButtonTap() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
            activeOverlay = .resume
        }
    }
    
    private func prepareProfileHeadshotAdjust() {
        guard profileManager.profile.preferredHeadshot != nil else { return }
        profileHeadshotDraft = profileManager.profile.profileHeadshotTransform
        profileCropArmed = false
        withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
            activeOverlay = .headshotAdjust
        }
    }
    
    private func handleHeadshotFileImport(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard !urls.isEmpty else { return }
            Task {
                await importHeadshots(from: urls)
            }
        case .failure(let error):
            headshotImportError = error.localizedDescription
        }
    }
    
    private func handleResumeImport(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            var importedNames: [String] = []
            for url in urls {
                do {
                    let importResult = try SafeDocumentStore.importFromPicker(
                        url: url,
                        preferredName: url.lastPathComponent,
                        subfolder: "ActorProfile"
                    )
                    importedNames.append(importResult.fileName)
                } catch {
                    resumeImportError = error.localizedDescription
                    return
                }
            }
            guard !importedNames.isEmpty else { return }
            profileManager.addResumes(importedNames)
            profileManager = ActorProfileManager()
            maybeShowResumeCreatorHint()
        case .failure(let error):
            resumeImportError = error.localizedDescription
        }
    }
    
    private func importHeadshots(from urls: [URL]) async {
        await MainActor.run { isImportingHeadshot = true }
        defer {
            Task { @MainActor in
                isImportingHeadshot = false
            }
        }
        var importedFileNames: [String] = []
        for url in urls {
            do {
                let result = try SafeDocumentStore.importFromPicker(
                    url: url,
                    preferredName: url.lastPathComponent,
                    subfolder: "ActorProfile"
                )
                importedFileNames.append(result.fileName)
            } catch {
                await MainActor.run {
                    headshotImportError = "Couldn’t import \(url.lastPathComponent): \(error.localizedDescription)"
                }
            }
        }
        guard !importedFileNames.isEmpty else { return }
        await MainActor.run {
            profileManager.addHeadshots(fileNames: importedFileNames)
            reloadProfile()
        }
    }
    
    private func handleHeadshotPhotoSelection(item: PhotosPickerItem) async {
        await MainActor.run { isImportingHeadshot = true }
        defer {
            Task { @MainActor in
                isImportingHeadshot = false
            }
        }
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                throw NSError(domain: "ActorKit.Headshot", code: -1, userInfo: [NSLocalizedDescriptionKey: "Selected image could not be loaded."])
            }
            let ext = item.supportedContentTypes.first?.preferredFilenameExtension ?? "jpg"
            let fileName = "Headshot-\(UUID().uuidString.prefix(8)).\(ext)"
            let result = try SafeDocumentStore.save(
                data: data,
                preferredFileName: fileName,
                subfolder: "ActorProfile"
            )
            await MainActor.run {
                profileManager.addHeadshot(fileName: result.fileName)
                reloadProfile()
            }
        } catch {
            await MainActor.run {
                headshotImportError = error.localizedDescription
            }
        }
        await MainActor.run {
            headshotPhotoItem = nil
        }
    }
}

struct ActorKitBadge: View {
    let profileManager: ActorProfileManager
    let projectsRepository: ProjectsRepository
    
    private var profile: ActorProfile { profileManager.profile }
    private var isProfileComplete: Bool { profileManager.isProfileComplete }
    
    @State private var headshotImage: Image?
    @State private var isLoadingHeadshot = false

    private let badgeSize: CGFloat = 220
    
    private var primaryHeadshotAsset: HeadshotAsset? {
        profile.preferredHeadshot
    }
    
    private var headshotURL: URL? {
        resolveHeadshotURL(named: primaryHeadshotAsset?.fileName)
    }
    
    private var primaryHeadshotIdentifier: String {
        primaryHeadshotAsset?.fileName ?? "__none__"
    }
    
    private var logoAsset: Image {
        if UIImage(named: "AppLogoBadge") != nil {
            return Image("AppLogoBadge")
        }
        if UIImage(named: "AppLogoFilled") != nil {
            return Image("AppLogoFilled")
        }
        return Image("AppLogo")
    }
    
    init(
        profileManager: ActorProfileManager,
        projectsRepository: ProjectsRepository = ProjectsRepositoryFactory.makeAppRepository()
    ) {
        self.profileManager = profileManager
        self.projectsRepository = projectsRepository
    }
    
    var body: some View {
        CoinPortalCoordinator(
            front: logoAsset,
            back: headshotImage,
            badgeSize: badgeSize * 0.8,
            whooshAssetName: "whoosh.caf",
            useLaunchBackground: false,
            actorKit: {
                ActorKitView(profileManager: profileManager, projectsRepository: projectsRepository)
            },
            captionOverlay: { _ in EmptyView() }
        )
        .frame(height: badgeSize * 1.4)
        .accessibilityLabel("ActorKit Portal")
        .onAppear {
            loadHeadshotImage()
        }
        .onChange(of: primaryHeadshotIdentifier, initial: false) { _, _ in
            headshotImage = nil
            loadHeadshotImage()
        }
        .onReceive(NotificationCenter.default.publisher(for: .actorProfileDidUpdate)) { _ in
            headshotImage = nil
            loadHeadshotImage()
        }
    }
    
    private func loadHeadshotImage() {
        guard !isLoadingHeadshot else { return }
        guard let url = headshotURL else {
            headshotImage = nil
            isLoadingHeadshot = false
            return
        }
        
        isLoadingHeadshot = true
        DispatchQueue.global(qos: .userInitiated).async {
            let image: Image?
            if let uiImage = UIImage(contentsOfFile: url.path) {
                image = Image(uiImage: uiImage)
            } else if let data = try? Data(contentsOf: url), let uiImage = UIImage(data: data) {
                image = Image(uiImage: uiImage)
            } else {
                image = nil
            }
            
            DispatchQueue.main.async {
                headshotImage = image
                isLoadingHeadshot = false
            }
        }
    }
}

// MARK: - Supporting Views

private struct ActorKitCard<Content: View>: View {
    let title: String
    let icon: String
    let content: Content
    
    init(title: String, icon: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if !(title.isEmpty && icon.isEmpty) {
                HStack(spacing: 10) {
                    if !icon.isEmpty {
                        Image(systemName: icon)
                            .font(.title2)
                            .foregroundStyle(Theme.primary)
                    }
                    if !title.isEmpty {
                        Text(title)
                            .font(Theme.Font.headline)
                            .foregroundStyle(.white)
                    }
                }
            }
            content
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.black.opacity(0.35))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
        .shadow(color: Color.black.opacity(0.3), radius: 10, x: 0, y: 6)
    }
}

private struct ActorKitQuickAction: View {
    let title: String
    let subtitle: String
    let icon: String
    let tint: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(.white)
                    .padding(12)
                    .background(tint.opacity(0.6))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                
                Text(title)
                    .font(Theme.Font.body)
                    .foregroundStyle(.white)
                
                Text(subtitle)
                    .font(Theme.Font.caption)
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(0.08))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

private struct ActorKitRow: View {
    let title: String
    let subtitle: String?
    let trailing: String?
    let icon: String?
    let applyCardBackground: Bool
    let onTap: (() -> Void)?
    
    init(title: String, subtitle: String?, trailing: String? = nil, icon: String? = nil, applyCardBackground: Bool = false, onTap: (() -> Void)? = nil) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing
        self.icon = icon
        self.applyCardBackground = applyCardBackground
        self.onTap = onTap
    }
    
    var body: some View {
        let cornerRadius: CGFloat = applyCardBackground ? 20 : 14
        let padding: CGFloat = applyCardBackground ? 20 : 12
        let backgroundShape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        
        HStack(spacing: 12) {
            if let icon {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(Theme.primary)
                    .frame(width: 26)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(Theme.Font.body)
                    .foregroundStyle(.white)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(Theme.Font.caption)
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            
            Spacer()
            
            if let trailing, !trailing.isEmpty {
                Text(trailing)
                    .font(Theme.Font.caption)
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.trailing)
            }
        }
        .padding(padding)
        .frame(maxWidth: .infinity)
        .background(
            backgroundShape
                .fill(applyCardBackground ? Color.black.opacity(0.35) : Color.white.opacity(0.05))
                .overlay {
                    if applyCardBackground {
                        backgroundShape
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    }
                }
        )
        .contentShape(backgroundShape)
        .modifier(ConditionalTapGestureModifier(onTap: onTap))
    }
}

private struct ConditionalTapGestureModifier: ViewModifier {
    let onTap: (() -> Void)?

    func body(content: Content) -> some View {
        if let onTap {
            content.onTapGesture(perform: onTap)
        } else {
            content
        }
    }
}

private struct ActorKitStatPill: View {
    let label: String
    let value: String
    let showsBackground: Bool
    
    init(label: String, value: String, showsBackground: Bool = true) {
        self.label = label
        self.value = value
        self.showsBackground = showsBackground
    }
    
    var body: some View {
        VStack(spacing: 4) {
            Text(label.uppercased())
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.6))
            Text(value)
                .font(Theme.Font.body)
                .foregroundStyle(.white)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity)
        .background(
            Group {
                if showsBackground {
                    Capsule()
                        .fill(Color.white.opacity(0.12))
                }
            }
        )
    }
}

private struct HeadshotCropperView: View {
    let image: Image
    @Binding var transform: HeadshotTransform
    @Binding var isActive: Bool
    let aspectRatio: CGFloat
    let cornerRadius: CGFloat
    let showsTapHint: Bool
    let useCircularMask: Bool
    let requiresActivation: Bool
    
    @State private var dragOffset: CGSize = .zero
    @State private var magnification: CGFloat = 1.0
    
    init(
        image: Image,
        transform: Binding<HeadshotTransform>,
        isActive: Binding<Bool>,
        aspectRatio: CGFloat,
        cornerRadius: CGFloat,
        showsTapHint: Bool = true,
        useCircularMask: Bool = false,
        requiresActivation: Bool = true
    ) {
        self.image = image
        self._transform = transform
        self._isActive = isActive
        self.aspectRatio = aspectRatio
        self.cornerRadius = cornerRadius
        self.showsTapHint = showsTapHint
        self.useCircularMask = useCircularMask
        self.requiresActivation = requiresActivation
    }
    
    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = width / aspectRatio
            let offsets = transform.offset(width: width, height: height)
            ZStack {
                Color.black
                image
                    .resizable()
                    .scaledToFill()
                    .scaleEffect(transform.scale * magnification)
                    .frame(width: width, height: height)
                    .offset(x: offsets.width + dragOffset.width,
                            y: offsets.height + dragOffset.height)
            }
            .frame(width: width, height: height)
            .clipShape(clippingShape)
            .contentShape(Rectangle())
            .overlay {
                if showsTapHint && requiresActivation && !isActive {
                    clippingShape
                        .fill(Color.black.opacity(0.35))
                        .overlay(
                            Label("Tap to adjust", systemImage: "hand.tap.fill")
                                .font(.callout.bold())
                                .foregroundStyle(.white)
                        )
                }
            }
            .onTapGesture {
                guard requiresActivation else { return }
                if !isActive {
                    withAnimation(.easeInOut) { isActive = true }
                }
            }
            .gesture(requiresActivation ? (isActive ? dragGesture(width: width, height: height) : nil) : dragGesture(width: width, height: height))
            .simultaneousGesture(requiresActivation ? (isActive ? magnificationGesture : nil) : magnificationGesture)
        }
        .aspectRatio(aspectRatio, contentMode: .fit)
    }
    
    private func dragGesture(width: CGFloat, height: CGFloat) -> some Gesture {
        DragGesture()
            .onChanged { value in
                dragOffset = value.translation
            }
            .onEnded { value in
                let widthRef = max(width, 1)
                let heightRef = max(height, 1)
                transform.offsetX += value.translation.width / widthRef
                transform.offsetY += value.translation.height / heightRef
                transform.clampOffsets()
                dragOffset = .zero
                if requiresActivation {
                    isActive = false
                }
            }
    }
    
    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                magnification = value
            }
            .onEnded { value in
                transform.scale = min(max(transform.scale * value, 0.8), 2.5)
                magnification = 1.0
                if requiresActivation {
                    isActive = false
                }
            }
    }
    
    private var clippingShape: AnyShape {
        if useCircularMask {
            return AnyShape(Circle())
        }
        return AnyShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

private struct AnyShape: Shape, @unchecked Sendable {
    private let builder: @Sendable (CGRect) -> Path
    
    init<S: Shape>(_ shape: S) {
        builder = { rect in
            shape.path(in: rect)
        }
    }
    
    func path(in rect: CGRect) -> Path {
        builder(rect)
    }
}

struct ShareSheetController: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

private struct ClearListBackground: ViewModifier {
    func body(content: Content) -> some View {
        Group {
            if #available(iOS 16.0, *) {
                content.scrollContentBackground(.hidden)
            } else {
                content
            }
        }
    }
}

struct ResumeCreatorToast: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.headline)
                .foregroundStyle(.white)
            VStack(alignment: .leading, spacing: 2) {
                Text("Resume Creator coming soon")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Text("We’re building an in-app resume designer with templates.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.black.opacity(0.65))
        )
        .padding(.bottom, 40)
        .padding(.horizontal, 24)
    }
}

struct ResumePreviewItem: Identifiable {
    let id = UUID()
    let fileName: String
    let url: URL
}

struct ShareURLItem: Identifiable {
    let id = UUID()
    let url: URL
}

struct EquipmentGuideView: View {
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

    private struct GearItem: Identifiable {
        let id = UUID()
        let name: String
        let subtitle: String
        let imageName: String
        let affiliateURL: URL
        let badge: String?
    }
    
    private let gearItems: [GearItem] = [
        .init(
            name: "Hollyland Lark M2 (Combo) — Wireless Lavalier",
            subtitle: "Discreet dual-transmitter lav kit with clean 48kHz/24-bit audio and noise cancellation—great for crisp dialogue in self-tapes, especially in untreated rooms.",
            imageName: "gear_wireless_mics",
            affiliateURL: URL(string: "https://amzn.to/4okiA3X")!,
            badge: "Studio Tested"
        ),
        .init(
            name: "RAUBAY Collapsible Gray Backdrop (78.7\" × 82.7\")",
            subtitle: "Wrinkle-resistant neutral gray screen that sets up in seconds and packs down fast—an easy way to keep your background consistent across auditions.",
            imageName: "gear_backdrop",
            affiliateURL: URL(string: "https://amzn.to/3MgilcR")!,
            badge: "Recommended"
        )
    ]

    private struct GearPreviewCard: View {
        let item: GearItem
        let accent: Color

        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                Image(item.imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .frame(height: 170)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                HStack(alignment: .firstTextBaseline) {
                    Text(item.name)
                        .font(Theme.Font.body.weight(.semibold))
                        .foregroundStyle(.white)

                    Spacer()

                    if let badge = item.badge {
                        Text(badge)
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(accent.opacity(0.18), in: Capsule())
                            .foregroundStyle(accent)
                    }
                }

                Text(item.subtitle)
                    .font(Theme.Font.caption)
                    .foregroundStyle(.white.opacity(0.75))

                Link(destination: item.affiliateURL) {
                    Label("View on Amazon", systemImage: "arrow.up.right")
                        .font(.subheadline.weight(.semibold))
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                        .background(accent.opacity(0.15), in: Capsule())
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
            )
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                theme.backgroundGradient
                    .ignoresSafeArea()
                accentGlow

                ScrollView {
                    VStack(spacing: 18) {
                    Text("Gear we personally test for dependable self-tapes. Purchase via the affiliate links below to support future ActorKit R&D.")
                        .font(Theme.Font.caption)
                        .foregroundStyle(.white.opacity(0.75))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    Text("Some links are affiliate links. If you choose to purchase through them, it supports ongoing ActorKit R&D at no extra cost to you.")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.55))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    ForEach(gearItems) { item in
                        GearPreviewCard(item: item, accent: theme.primaryAccent)
                    }
                }
                .padding(24)
            }
            }
            .navigationTitle("Self Tape Gear")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct ScaledSizeCardPreview: View {
    let profile: ActorProfile
    let reps: [RepInfo]
    let config: SizeCardConfig
    let maxWidth: CGFloat
    let maxHeight: CGFloat?
    
    var body: some View {
        let baseSize = config.template.aspect.canvasSize
        let widthScale = maxWidth / baseSize.width
        let heightScale = maxHeight.map { $0 / baseSize.height } ?? widthScale
        let scale = min(widthScale, heightScale)
        let targetWidth = baseSize.width * scale
        let targetHeight = baseSize.height * scale
        
        SizeCardView(profile: profile, reps: reps, config: config)
            .frame(width: baseSize.width, height: baseSize.height)
            .scaleEffect(scale, anchor: .topLeading)
            .frame(width: targetWidth, height: targetHeight, alignment: .topLeading)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
            .shadow(color: .black.opacity(0.35), radius: 30, x: 0, y: 16)
#if DEBUG
            .environment(\.sizeCardPreviewScale, scale)
            .environment(\.sizeCardPreviewIsClipped, true)
            .environment(\.sizeCardPreviewContainerSize, CGSize(width: targetWidth, height: targetHeight))
            .environment(\.sizeCardRenderContext, .preview)
            .overlay {
                GeometryReader { proxy in
                    ZStack(alignment: .topLeading) {
                        Rectangle()
                            .stroke(Color.red.opacity(0.9), lineWidth: 1)
                        Text(
                            String(
                                format: "Preview %.0fx%.0f scale=%.3f clipped=YES",
                                proxy.size.width,
                                proxy.size.height,
                                scale
                            )
                        )
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.red)
                        .padding(4)
                        .background(Color.black.opacity(0.5))
                    }
                    .allowsHitTesting(false)
                }
            }
            .onAppear {
                print(
                    String(
                        format: "🧪 SizeCardPreview container=%.0fx%.0f scale=%.3f clipped=YES",
                        targetWidth,
                        targetHeight,
                        scale
                    )
                )
            }
#endif
    }
}

private struct ActorKitHeadshotView: View {
    let headshotName: String?
    let transform: HeadshotTransform
    
    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let offsets = transform.offset(width: size.width, height: size.height)
            ZStack {
                Circle().fill(Color.black.opacity(0.4))
                if let url = resolveHeadshotURL(named: headshotName),
                   let uiImage = UIImage(contentsOfFile: url.path) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .scaleEffect(transform.scale)
                        .frame(width: size.width, height: size.height)
                        .offset(x: offsets.width, y: offsets.height)
                        .clipShape(Circle())
                } else {
                    placeholder
                        .frame(width: size.width, height: size.height)
                }
            }
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(0.3), lineWidth: 3)
            )
            .shadow(color: Color.black.opacity(0.45), radius: 16, x: 0, y: 8)
        }
        .aspectRatio(1, contentMode: .fit)
    }
    
    private var placeholder: some View {
        Circle()
            .fill(Color.white.opacity(0.08))
            .overlay(
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 62))
                    .foregroundStyle(.white.opacity(0.6))
            )
    }
}

// MARK: - Overlay helpers
private extension ActorKitView {
    var primaryHeadshotAsset: HeadshotAsset? {
        profileManager.profile.headshots.first(where: { $0.isProfilePhoto }) ?? profileManager.profile.headshots.first
    }
    
    var preferredHeadshotImage: Image? {
        guard
            let fileName = primaryHeadshotAsset?.fileName,
            let url = resolveHeadshotURL(named: fileName),
            let uiImage = UIImage(contentsOfFile: url.path)
        else {
            return nil
        }
        return Image(uiImage: uiImage)
    }
    
    func clampScale(_ rawValue: Double, min: Double = 0.8, max: Double = 2.5) -> CGFloat {
        let clamped = Swift.max(min, Swift.min(max, rawValue))
        return CGFloat(clamped)
    }
    
    func dismissHeadshotPreview() {
        withAnimation(headshotPreviewAnimation) {
            showingHeadshotPreview = false
        }
    }
    
    func dismissHeadshotAdjustOverlay() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
            activeOverlay = nil
        }
    }
    
    func setPreferredHeadshotAndBeginAdjustment(with asset: HeadshotAsset) {
        profileManager.setPreferredHeadshot(named: asset.fileName)
        profileManager = ActorProfileManager()
        DispatchQueue.main.async {
            prepareProfileHeadshotAdjust()
        }
    }
    
    func presentContactOptions(for rep: RepInfo) {
        repContactSelection = rep
        showingRepContactDialog = true
    }
    
    private func dialURL(for phone: String) -> URL? {
        url(for: phone, prefix: "tel://")
    }
    
    private func textURL(for phone: String) -> URL? {
        url(for: phone, prefix: "sms:")
    }
    
    private func url(for phone: String, prefix: String) -> URL? {
        let digits = sanitizedPhoneDigits(from: phone)
        guard !digits.isEmpty else { return nil }
        return URL(string: "\(prefix)\(digits)")
    }
    
    private func emailURL(for email: String) -> URL? {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return nil }
        return URL(string: "mailto:\(encoded)")
    }
    
    private func sanitizedAddress(_ raw: String?) -> String? {
        guard let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }
    
    private var preferredMapsApp: MapsAppPreference {
        MapsAppPreference(rawValue: preferredMapsAppRaw) ?? .google
    }
    
    private func directionsURL(for address: String) -> URL? {
        guard let encoded = address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return nil
        }
        switch preferredMapsApp {
        case .apple:
            return URL(string: "http://maps.apple.com/?q=\(encoded)")
        case .google:
            // Using universal HTTP URL to avoid scheme failures if the app isn't installed
            return URL(string: "https://www.google.com/maps/search/?api=1&query=\(encoded)")
        }
    }
    
    private func sanitizedPhoneDigits(from raw: String) -> String {
        var result = ""
        for character in raw {
            if character == "+" {
                if result.isEmpty {
                    result.append(character)
                }
            } else if character.isNumber {
                result.append(character)
            }
        }
        return result
    }

    private enum MapsAppPreference: String {
        case google
        case apple
    }
    
    private func shortPhoneDisplay(_ phone: String) -> String {
        phone.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func resumeURL(named fileName: String) -> URL? {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let subfolder = docs.appendingPathComponent("ActorProfile", isDirectory: true)
        let candidates = [
            subfolder.appendingPathComponent(fileName),
            docs.appendingPathComponent(fileName)
        ]
        for candidate in candidates where FileManager.default.fileExists(atPath: candidate.path) {
            return candidate
        }
        return nil
    }
    
    private func maybeShowResumeCreatorHint() {
        resumeCreatorHintCount += 1
        let shouldShow = resumeCreatorHintCount % 4 == 0
        guard shouldShow else { return }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.9)) {
            showResumeCreatorToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.9)) {
                showResumeCreatorToast = false
            }
        }
    }
    
    private func openResumePreview(named fileName: String) {
        guard let url = resumeURL(named: fileName) else {
            resumeImportError = "Could not open \(fileName). Try uploading it again."
            return
        }
        resumePreviewItem = ResumePreviewItem(fileName: fileName, url: url)
        maybeShowResumeCreatorHint()
    }
    
    private func shareResume(named fileName: String) {
        guard let url = resumeURL(named: fileName) else {
            resumeImportError = "Could not open \(fileName). Try uploading it again."
            return
        }
        shareSheetItem = ShareURLItem(url: url)
        maybeShowResumeCreatorHint()
    }
    
    private func deleteResume(named fileName: String) {
        profileManager.removeResume(named: fileName)
        profileManager = ActorProfileManager()
    }
    
    private func shareHeadshot(_ asset: HeadshotAsset) {
        guard let url = resolveHeadshotURL(named: asset.fileName) else {
            resumeImportError = "Could not open \(asset.fileName). Try uploading it again."
            return
        }
        shareSheetItem = ShareURLItem(url: url)
    }
    
    private func deleteHeadshot(_ asset: HeadshotAsset) {
        profileManager.removeHeadshot(id: asset.id)
        profileManager = ActorProfileManager()
    }
    
    static func enforcedSizeCardDefaults(for config: SizeCardConfig) -> SizeCardConfig {
        var copy = config
        copy.template.templateID = SizeCardTemplate.compact.rawValue
        copy.template.aspect = .half
        return copy
    }
    enum ActorKitOverlay: Identifiable {
        case headshots
        case representation
        case headshotAdjust
        case resume
        
        var id: Int {
            switch self {
            case .headshots: return 0
            case .representation: return 1
            case .headshotAdjust: return 2
            case .resume: return 3
            }
        }
        
        var title: String {
            switch self {
            case .headshots: return "Headshots"
            case .representation: return "Representation"
            case .headshotAdjust: return "Adjust Headshot"
            case .resume: return "Resume"
            }
        }
    }
    
    private var overlayLayer: some View {
        Group {
            if let overlay = activeOverlay {
                ZStack {
                    Color.black.opacity(0.55)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                activeOverlay = nil
                            }
                        }
                    overlayPanel(for: overlay)
                        .transition(.scale(scale: 0.96).combined(with: .opacity))
                }
                .animation(.easeInOut(duration: 0.25), value: activeOverlay)
            }
        }
    }

    private var headshotPreviewOverlay: some View {
        Group {
            if showingHeadshotPreview, profileManager.profile.preferredHeadshot != nil {
                GeometryReader { proxy in
                    let minSide = min(proxy.size.width, proxy.size.height)
                    let previewSize = max(minSide - 80, 240)
                    
                    ZStack {
                        Color.black.opacity(0.82)
                            .ignoresSafeArea()
                            .transition(.opacity)
                            .animation(headshotPreviewAnimation, value: showingHeadshotPreview)

                        ActorKitHeadshotView(
                            headshotName: profileManager.profile.preferredHeadshot?.fileName,
                            transform: profileManager.profile.profileHeadshotTransform
                        )
                        .matchedGeometryEffect(id: "profileHeadshot", in: headshotNamespace, isSource: false)
                        .frame(width: previewSize, height: previewSize)
                        .shadow(color: .black.opacity(0.55), radius: 45, x: 0, y: 24)
                        .accessibilityLabel("Close headshot preview")
                        .accessibilityAddTraits(.isButton)
                    }
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .contentShape(Rectangle())
                    .onTapGesture { dismissHeadshotPreview() }
                    .zIndex(50)
                    .animation(headshotPreviewAnimation, value: showingHeadshotPreview)
                }
            }
        }
    }
    
    @ViewBuilder
    private func overlayPanel(for overlay: ActorKitOverlay) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text(overlay.title)
                    .font(Theme.Font.headline)
                    .foregroundStyle(.white)
                Spacer()
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                        activeOverlay = nil
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.white.opacity(0.85))
                }
                .accessibilityLabel("Close overlay")
            }
            overlayContent(for: overlay)
        }
        .padding(24)
        .frame(maxWidth: 520)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.35), radius: 40, x: 0, y: 25)
        )
        .padding(.horizontal, 24)
    }
    
    @ViewBuilder
    private func overlayContent(for overlay: ActorKitOverlay) -> some View {
        switch overlay {
        case .headshots:
            headshotsOverlayContent
        case .representation:
            representationOverlayContent
        case .headshotAdjust:
            headshotAdjustOverlayContent
        case .resume:
            resumeOverlayContent
        }
    }
    
    private var headshotsOverlayContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Keep your latest looks ready for every opportunity.")
                .font(Theme.Font.body)
                .foregroundStyle(.white.opacity(0.8))
            SharedHeadshotDeckView(
                headshots: profileManager.profile.headshots,
                preferredID: profileManager.profile.preferredHeadshot?.id,
                isImporting: isImportingHeadshot,
                resolveImage: { asset in headshotImage(for: asset) },
                onSelect: { asset in
                    selectedHeadshot = asset
                },
                onSetPreferred: { asset in
                    setPreferredHeadshotAndBeginAdjustment(with: asset)
                },
                onAdd: {
                    showingHeadshotSource = true
                },
                onDelete: { asset in
                    overlayDeleteHeadshot = asset
                }
            )
        }
    }

    private func headshotImage(for asset: HeadshotAsset) -> Image? {
        guard
            let url = resolveHeadshotURL(named: asset.fileName),
            let uiImage = UIImage(contentsOfFile: url.path)
        else {
            return nil
        }
        return Image(uiImage: uiImage)
    }
    
    private var representationOverlayContent: some View {
        VStack(spacing: 14) {
            if repsViewModel.reps.isEmpty {
                VStack(spacing: 12) {
                    Text("Add your reps to keep contact info handy during sessions.")
                        .font(Theme.Font.caption)
                        .foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                    
                    BrandedSecondaryButton(label: "Add Representation") {
                        activeOverlay = nil
                        showingRepsManager = true
                    }
                }
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(repsViewModel.reps) { rep in
                            let hasContact = !(rep.phone?.isEmpty ?? true) || !(rep.email?.isEmpty ?? true)
                            let hasAddress = !(rep.companyAddress?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
                            let hasAction = hasContact || hasAddress
                            let trailingDetails = [
                                rep.companyName,
                                rep.companyAddress,
                                rep.email,
                                rep.phone
                            ]
                            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
                            .filter { !$0.isEmpty }
                            .joined(separator: " • ")
                            ActorKitRow(
                                title: rep.name,
                                subtitle: rep.category,
                                trailing: trailingDetails,
                                applyCardBackground: true,
                                onTap: hasAction ? { presentContactOptions(for: rep) } : nil
                            )
                        }
                        
                        BrandedSecondaryButton(label: "Manage Reps") {
                            activeOverlay = nil
                            showingRepsManager = true
                        }
                        .padding(.top, 4)
                    }
                    .padding(.top, 4)
                }
                .frame(maxHeight: 260)
            }
        }
    }

    private var headshotAdjustOverlayContent: some View {
        VStack(spacing: 20) {
            if let image = preferredHeadshotImage {
                
                HeadshotCropperView(
                    image: image,
                    transform: $profileHeadshotDraft,
                    isActive: $profileCropArmed,
                    aspectRatio: 1.0,
                    cornerRadius: 160,
                    showsTapHint: false,
                    useCircularMask: true,
                    requiresActivation: false
                )
                .frame(height: 320)
                
                Slider(
                    value: Binding(
                        get: { Double(profileHeadshotDraft.scale) },
                        set: { profileHeadshotDraft.scale = clampScale($0) }
                    ),
                    in: 0.8...2.5
                ) {
                    Text("Zoom")
                }
                .tint(Theme.primary)
                
                HStack {
                    Button("Reset") {
                        profileHeadshotDraft = .identity
                        profileCropArmed = false
                    }
                    .buttonStyle(.bordered)
                    
                    Spacer()
                    
                    Button("Save") {
                        profileManager.updateProfileHeadshotTransform(profileHeadshotDraft)
                        dismissHeadshotAdjustOverlay()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.primary)
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "person.crop.circle.badge.plus")
                        .font(.system(size: 64))
                        .foregroundStyle(.white.opacity(0.7))
                    Text("Add a headshot to unlock framing adjustments.")
                        .font(Theme.Font.body)
                        .foregroundStyle(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                    Button("Add Headshot") {
                        dismissHeadshotAdjustOverlay()
                        showingHeadshotSource = true
                    }
                    .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
    
    private var resumeOverlayContent: some View {
        VStack(spacing: 20) {
            if profileManager.profile.resumes.isEmpty {
                VStack(spacing: 12) {
                    Text("No resume on file yet")
                        .font(Theme.Font.headline)
                        .foregroundStyle(.white)
                    Text("Upload PDF resumes so you can preview and share them instantly from ActorKit.")
                        .font(Theme.Font.body)
                        .foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 12)
                    Button {
                        showingResumeImporter = true
                    } label: {
                        Label("Upload Resume", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.primary)
                    .padding(.top, 6)
                }
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Your resumes")
                        .font(Theme.Font.headline)
                        .foregroundStyle(.white)
                    Text("Tap to preview. Swipe for quick share or delete.")
                        .font(Theme.Font.caption)
                        .foregroundStyle(.white.opacity(0.65))
                }
                List {
                    ForEach(profileManager.profile.resumes, id: \.self) { resumeName in
                        ActorKitRow(
                            title: resumeName,
                            subtitle: "PDF",
                            trailing: "Preview",
                            icon: "doc.text",
                            applyCardBackground: true,
                            onTap: {
                                openResumePreview(named: resumeName)
                            }
                        )
                        .listRowInsets(.init(top: 6, leading: 0, bottom: 6, trailing: 0))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .swipeActions(edge: .leading, allowsFullSwipe: false) {
                            if resumeURL(named: resumeName) != nil {
                                Button {
                                    shareResume(named: resumeName)
                                } label: {
                                    Label("Share", systemImage: "square.and.arrow.up")
                                }
                                .tint(.blue)
                            }
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                deleteResume(named: resumeName)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .modifier(ClearListBackground())
                .frame(maxHeight: 280)
                
                Button {
                    showingResumeImporter = true
                } label: {
                    Label("Upload Another Resume", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            
            Divider().overlay(Color.white.opacity(0.08))
            
            HStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.title3)
                    .foregroundStyle(Theme.primary)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Resume Creator coming soon")
                        .font(Theme.Font.body.weight(.semibold))
                        .foregroundStyle(.white)
                    Text("We’re crafting in-app templates for tailored theatrical, commercial, and VO resumes.")
                        .font(Theme.Font.caption)
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(0.05))
            )
        }
    }
    
    
    private var sizeCardFullScreenSheet: some View {
        NavigationStack {
            GeometryReader { proxy in
                let cardInset: CGFloat = 20
                let heroMinHeight: CGFloat = 150
                let heroOverlapDepth: CGFloat = heroMinHeight * 0.13  // ~13% overlap
                let contentTopPadding: CGFloat = 10
                let bottomSafeArea = proxy.safeAreaInsets.bottom
                
                StickyHeaderScroll(
                    behavior: .scrollsWithContent,
                    header: {
                        BrandHeaderImage(
                            imageName: "SizeCardCreator",
                            cardInset: cardInset,
                            overlapDepth: heroOverlapDepth,
                            minVisualHeight: heroMinHeight
                        )
                    },
                    content: {
                        VStack(spacing: 20) {
                            sizeCardPreviewBlock(maxWidth: proxy.size.width)
                                .padding(.horizontal, cardInset)
                                .padding(.top, contentTopPadding)
                                .zIndex(1)
                            
                            sizeCardControlsBlock
                                .padding(.horizontal, cardInset)
                        }
                        .padding(.bottom, bottomSafeArea + 32)
                        .frame(maxWidth: 900)
                        .frame(maxWidth: .infinity)
                    }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(BrandBackground().ignoresSafeArea())
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        showingSizeCardSheet = false
                    }
                    .foregroundStyle(.white.opacity(0.9))
                }
            }
        }
        .sheet(isPresented: $showingLayoutDesigner) {
            LayoutDesignerView(
                profile: profileManager.profile,
                reps: repsViewModel.reps,
                config: $sizeCardDraft
            ) {
                showingLayoutDesigner = false
            }
        }
    }
    private func sizeCardPreviewBlock(maxWidth: CGFloat) -> some View {
        let clampedWidth = max(min(maxWidth - 48, 780), 320)
        return VStack(spacing: 20) {
            if let image = preferredHeadshotImage {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Adjust Headshot Framing")
                        .font(Theme.Font.headline)
                        .foregroundStyle(.white)
                    HeadshotCropperView(
                        image: image,
                        transform: $sizeCardDraft.headshotTransform,
                        isActive: $sizeCardCropArmed,
                        aspectRatio: 8.0/10.0,
                        cornerRadius: 24
                    )
                    Slider(
                        value: Binding(
                            get: { Double(sizeCardDraft.headshotTransform.scale) },
                            set: { sizeCardDraft.headshotTransform.scale = clampScale($0) }
                        ),
                        in: 0.8...2.5
                    ) {
                        Text("Zoom")
                    }
                    .tint(Theme.primary)
                    Button("Reset Framing") {
                        sizeCardDraft.headshotTransform = .identity
                        sizeCardCropArmed = false
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            }
            
            ScaledSizeCardPreview(
                profile: profileManager.profile,
                reps: repsViewModel.reps,
                config: sizeCardDraft,
                maxWidth: clampedWidth,
                maxHeight: 520
            )
            .contentShape(Rectangle())
            .onTapGesture {
                showingLayoutDesigner = true
            }
            .onLongPressGesture {
                showingSizeCardPreviewFullScreen = true
            }
            .accessibilityLabel("Tap to open Layout Designer. Long-press to zoom preview.")
        }
    }
    
    private var sizeCardControlsBlock: some View {
        VStack(spacing: 20) {
            identityControls
            sizesControls
            representationControls
            socialControls
            brandingControls
            
            Button {
                reopenSizeCardAfterWizard = true
                showingSizeCardSheet = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    showingProfileWizard = true
                }
            } label: {
                Label("Update Sizes", systemImage: "ruler")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            
            VStack(spacing: 12) {
                Button {
                    let normalized = ActorKitView.enforcedSizeCardDefaults(for: sizeCardDraft)
                    SizeCardRenderer.presentShareSheet(
                        profile: profileManager.profile,
                        reps: repsViewModel.reps,
                        config: normalized
                    )
                } label: {
                    Label("Share Size Card", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                
                Button {
                    let normalized = ActorKitView.enforcedSizeCardDefaults(for: sizeCardDraft)
                    profileManager.updateSizeCardConfig(normalized)
                    sizeCardDraft = normalized
                    showingSizeCardSheet = false
                } label: {
                    Label("Save", systemImage: "checkmark.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
    }
    
    private var identityControls: some View {
        controlSection(
            title: "Identity & Contact",
            systemImage: "person.text.rectangle",
            isExpanded: $identityControlsExpanded
        ) {
            Toggle("Union Status", isOn: $sizeCardDraft.visibility.showUnion)
            Toggle("Primary Location", isOn: $sizeCardDraft.visibility.showPrimaryLocation)
            Toggle("Local Hire", isOn: $sizeCardDraft.visibility.showLocalHire)
            if sizeCardDraft.visibility.showLocalHire {
                TextField("Local hire market", text: Binding(
                    get: { sizeCardDraft.localHireOverride },
                    set: { sizeCardDraft.localHireOverride = $0 }
                ))
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.words)
            }
            
            Divider().overlay(Color.white.opacity(0.08))
            
            Toggle("Email", isOn: $sizeCardDraft.visibility.showEmail)
                .disabled(!hasEmailOnFile)
            if !hasEmailOnFile {
                Text("Add an email in your Actor Profile to enable this line.")
                    .font(Theme.Font.caption)
                    .foregroundStyle(.white.opacity(0.6))
            }
            Toggle("Phone", isOn: $sizeCardDraft.visibility.showPhone)
                .disabled(!hasPhoneOnFile)
            if !hasPhoneOnFile {
                Text("Add a phone number in your Actor Profile to enable this line.")
                    .font(Theme.Font.caption)
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
    }
    
    private var sizesControls: some View {
        controlSection(
            title: "Sizes & Measurements",
            systemImage: "ruler",
            isExpanded: $sizesControlsExpanded
        ) {
            Toggle("Wardrobe & Measurements", isOn: $sizeCardDraft.visibility.showWardrobe)
            Text("Need to update values? Tap “Update Sizes” below to jump back into the wizard without losing your card progress.")
                .font(Theme.Font.caption)
                .foregroundStyle(.white.opacity(0.6))
            Text("For field-by-field visibility or placement adjustments, open the Layout Designer from the preview.")
                .font(Theme.Font.caption)
                .foregroundStyle(.white.opacity(0.5))
        }
    }
    
    private var representationControls: some View {
        controlSection(
            title: "Representation",
            systemImage: "person.2.badge.gearshape",
            isExpanded: $representationControlsExpanded
        ) {
            Toggle("Show Representation", isOn: $sizeCardDraft.visibility.showReps)
            if repsViewModel.reps.isEmpty {
                Text("Add agents/managers from the Your Profile card to unlock this row.")
                    .font(Theme.Font.caption)
                    .foregroundStyle(.white.opacity(0.6))
            } else {
                Divider().overlay(Color.white.opacity(0.08))
                ForEach(repsViewModel.reps) { rep in
                    Toggle(rep.category, isOn: bindingForRepVisibility(rep))
                        .disabled(!sizeCardDraft.visibility.showReps)
                }
                Button {
                    showingRepsManager = true
                } label: {
                    Label("Manage Representation", systemImage: "square.and.pencil")
                }
                .buttonStyle(.bordered)
            }
        }
    }
    
    private var socialControls: some View {
        controlSection(
            title: "Social Links",
            systemImage: "link",
            isExpanded: $socialControlsExpanded
        ) {
            Toggle("Show Social Icons", isOn: $sizeCardDraft.visibility.showLinks)
            Divider().overlay(Color.white.opacity(0.08))
            Toggle("Instagram", isOn: $sizeCardDraft.visibility.showInstagram)
                .disabled(!sizeCardDraft.visibility.showLinks || !hasInstagramLink)
            Toggle("Facebook", isOn: $sizeCardDraft.visibility.showFacebook)
                .disabled(!sizeCardDraft.visibility.showLinks || !hasFacebookLink)
            Toggle("TikTok", isOn: $sizeCardDraft.visibility.showTiktok)
                .disabled(!sizeCardDraft.visibility.showLinks || !hasTiktokLink)
            Toggle("IMDb", isOn: $sizeCardDraft.visibility.showImdb)
                .disabled(!sizeCardDraft.visibility.showLinks || !hasImdbLink)
            Text("Only icons with saved links will appear on the card.")
                .font(Theme.Font.caption)
                .foregroundStyle(.white.opacity(0.6))
        }
    }
    
    private var brandingControls: some View {
        controlSection(
            title: "Branding",
            systemImage: "sparkles.rectangle.stack",
            isExpanded: $brandingControlsExpanded
        ) {
            Toggle("Watermark QR code", isOn: $sizeCardDraft.visibility.showWatermarkQR)
            Text("Adds a small iTFactor • Self Tape Studio badge in the lower-right corner with a QR link back to the app.")
                .font(Theme.Font.caption)
                .foregroundStyle(.white.opacity(0.6))
        }
    }
    
    private func controlSection<Content: View>(
        title: String,
        systemImage: String,
        isExpanded: Binding<Bool>,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        DisclosureGroup(isExpanded: isExpanded) {
            VStack(alignment: .leading, spacing: 12) {
                content()
            }
            .padding(.top, 8)
        } label: {
            Label(title, systemImage: systemImage)
                .font(Theme.Font.headline)
                .foregroundStyle(.white)
        }
        .toggleStyle(SwitchToggleStyle(tint: Theme.primary))
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var hasEmailOnFile: Bool {
        !profileManager.profile.email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var hasPhoneOnFile: Bool {
        !profileManager.profile.phone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var hasInstagramLink: Bool {
        !profileManager.profile.socialLinks.instagram.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var hasFacebookLink: Bool {
        !profileManager.profile.socialLinks.facebook.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var hasTiktokLink: Bool {
        !profileManager.profile.socialLinks.tiktok.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var hasImdbLink: Bool {
        !profileManager.profile.socialLinks.imdb.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func bindingForRepVisibility(_ rep: RepInfo) -> Binding<Bool> {
        Binding(
            get: { !sizeCardDraft.hiddenRepIDs.contains(rep.id) },
            set: { isVisible in
                if isVisible {
                    sizeCardDraft.hiddenRepIDs.remove(rep.id)
                } else {
                    sizeCardDraft.hiddenRepIDs.insert(rep.id)
                }
            }
        )
    }

    private func cleanupHiddenRepVisibilities(using reps: [RepInfo]) {
        let validIDs = Set(reps.map(\.id))
        sizeCardDraft.hiddenRepIDs = Set(sizeCardDraft.hiddenRepIDs.filter { validIDs.contains($0) })
    }
}

private struct SizeCardPreviewFullscreen: View {
    let profile: ActorProfile
    let reps: [RepInfo]
    let config: SizeCardConfig
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.92)
                .ignoresSafeArea()
            VStack(spacing: 16) {
                HStack {
                    Spacer()
                    Button {
                        onDismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 30, weight: .bold))
                            .foregroundStyle(.white.opacity(0.85))
                    }
                    .padding(16)
                }
                GeometryReader { proxy in
                    let maxWidth = min(proxy.size.width - 48, 900)
                    let maxHeight = proxy.size.height - 80
                    ScaledSizeCardPreview(
                        profile: profile,
                        reps: reps,
                        config: config,
                        maxWidth: maxWidth,
                        maxHeight: maxHeight
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                }
                .padding(.horizontal)
            }
        }
    }
}

private struct HeadshotDeckView: View {
    let headshots: [HeadshotAsset]
    let preferredID: UUID?
    let isImporting: Bool
    let onSelect: (HeadshotAsset) -> Void
    let onSetPreferred: (HeadshotAsset) -> Void
    let onAdd: () -> Void
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(headshots) { asset in
                    HeadshotDeckCard(
                        asset: asset,
                        isPreferred: asset.id == preferredID,
                        onTap: { onSelect(asset) },
                        onSetPreferred: { onSetPreferred(asset) }
                    )
                }
                
                Button(action: onAdd) {
                    VStack(spacing: 8) {
                        if isImporting {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .tint(.white)
                        } else {
                            Image(systemName: "plus")
                                .font(.title)
                                .foregroundStyle(.white)
                        }
                        Text(isImporting ? "Importing…" : "Add Headshot")
                            .font(Theme.Font.caption)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    .frame(width: 150, height: 210)
                    .background(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.35), style: StrokeStyle(lineWidth: 1.5, dash: [8, 6]))
                    )
                }
                .buttonStyle(.plain)
                .disabled(isImporting)
            }
            .padding(.vertical, 4)
        }
    }
}

private struct HeadshotDeckCard: View {
    let asset: HeadshotAsset
    let isPreferred: Bool
    let onTap: () -> Void
    let onSetPreferred: () -> Void
    
    var body: some View {
        VStack(spacing: 10) {
            headshotThumbnail
                .frame(width: 150, height: 210)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(alignment: .topLeading) {
                    if isPreferred {
                        Label("Profile", systemImage: "star.fill")
                            .font(.caption2)
                            .padding(6)
                            .background(.ultraThinMaterial, in: Capsule())
                            .padding(8)
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
                .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .onTapGesture(perform: onTap)
            
            Button(isPreferred ? "Profile Photo" : "Set as Profile") {
                onSetPreferred()
            }
            .font(.footnote.weight(.semibold))
            .buttonStyle(.borderedProminent)
            .tint(isPreferred ? Color.green.opacity(0.85) : Theme.primary)
            .disabled(isPreferred)
        }
        .frame(width: 160)
    }
    
    @ViewBuilder
    private var headshotThumbnail: some View {
        if let image = resolvedImage {
            image
                .resizable()
                .scaledToFill()
        } else {
            ZStack {
                Color.white.opacity(0.08)
                Image(systemName: "person.crop.rectangle")
                    .font(.largeTitle)
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
    }
    
    private var resolvedImage: Image? {
        guard
            let url = resolveHeadshotURL(named: asset.fileName),
            let uiImage = UIImage(contentsOfFile: url.path)
        else {
            return nil
        }
        return Image(uiImage: uiImage)
    }
}

private struct HeadshotPreviewSheet: View {
    let assets: [HeadshotAsset]
    let initialAsset: HeadshotAsset
    let onSetPreferred: (HeadshotAsset) -> Void
    let onRename: (HeadshotAsset, String) -> Void
    let onShare: (HeadshotAsset) -> Void
    let onDelete: (HeadshotAsset) -> Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var workingAssets: [HeadshotAsset]
    @State private var currentIndex: Int
    @State private var labelText: String
    @State private var isEditingLabel = false
    @State private var pendingDeletion: HeadshotAsset?
    @State private var showingDeleteConfirm = false
    @FocusState private var labelFieldFocused: Bool
    @GestureState private var swipeTranslation: CGFloat = 0
    
    init(
        assets: [HeadshotAsset],
        initialAsset: HeadshotAsset,
        onSetPreferred: @escaping (HeadshotAsset) -> Void,
        onRename: @escaping (HeadshotAsset, String) -> Void,
        onShare: @escaping (HeadshotAsset) -> Void,
        onDelete: @escaping (HeadshotAsset) -> Void
    ) {
        self.assets = assets
        self.initialAsset = initialAsset
        self.onSetPreferred = onSetPreferred
        self.onRename = onRename
        self.onShare = onShare
        self.onDelete = onDelete
        let initialIndex = assets.firstIndex(where: { $0.id == initialAsset.id }) ?? 0
        _workingAssets = State(initialValue: assets)
        _currentIndex = State(initialValue: initialIndex)
        let initialLabel = HeadshotPreviewSheet.labelText(for: assets, index: initialIndex, fallback: initialAsset)
        _labelText = State(initialValue: initialLabel)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.opacity(0.95).ignoresSafeArea()
                VStack(spacing: 24) {
                    ZStack {
                        headshotPreview(for: currentAsset)
                    }
                    .frame(maxHeight: 480)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
                    .overlay(alignment: .topLeading) {
                        if workingAssets.count > 1 {
                            Text("\(currentIndex + 1) / \(workingAssets.count)")
                                .font(.caption.bold())
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(.ultraThinMaterial, in: Capsule())
                                .padding(12)
                        }
                    }
                    .overlay(alignment: .topTrailing) {
                        if let asset = currentAsset {
                            actionButton(systemName: "square.and.arrow.up", tint: Theme.primary) {
                                onShare(asset)
                            }
                            .padding(16)
                        }
                    }
                    .overlay(alignment: .bottomTrailing) {
                        if currentAsset != nil {
                            actionButton(systemName: "trash", tint: .red.opacity(0.85)) {
                                pendingDeletion = currentAsset
                                showingDeleteConfirm = true
                            }
                            .padding([.trailing, .bottom], 16)
                        }
                    }
                    .offset(x: swipeTranslation)
                    .animation(.spring(response: 0.45, dampingFraction: 0.85), value: currentIndex)
                    .gesture(swipeGesture)
                    
                    labelEditor
                   
                    Button {
                        guard let asset = currentAsset else { return }
                        finalizeLabelEditing()
                        onSetPreferred(asset)
                        dismiss()
                    } label: {
                        Label("Use as Profile Photo", systemImage: "star.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.primary)
                    
                    Button(role: .cancel) {
                        finalizeLabelEditing()
                        dismiss()
                    } label: {
                        Text("Close")
                    }
                    .buttonStyle(.bordered)
                    .tint(.white.opacity(0.8))
                }
                .padding(32)
            }
        }
        .onDisappear {
            finalizeLabelEditing()
        }
        .alert("Delete this headshot?", isPresented: $showingDeleteConfirm) {
            Button("Delete", role: .destructive) {
                if let asset = pendingDeletion {
                    performDeletion(asset)
                }
            }
            Button("Cancel", role: .cancel) {
                pendingDeletion = nil
            }
        } message: {
            Text("This will remove “\(pendingDeletion?.title ?? "this headshot")” from your profile.")
        }
    }
    
    private var currentAsset: HeadshotAsset? {
        guard !workingAssets.isEmpty else { return initialAsset }
        if workingAssets.indices.contains(currentIndex) {
            return workingAssets[currentIndex]
        }
        return workingAssets.first ?? initialAsset
    }
    
    private var swipeGesture: some Gesture {
        DragGesture()
            .updating($swipeTranslation) { value, state, _ in
                guard workingAssets.count > 1 else {
                    state = 0
                    return
                }
                state = value.translation.width
            }
            .onEnded { value in
                guard workingAssets.count > 1 else { return }
                let threshold: CGFloat = 80
                if value.translation.width < -threshold {
                    goToIndex(currentIndex + 1)
                } else if value.translation.width > threshold {
                    goToIndex(currentIndex - 1)
                }
            }
    }
    
    private func goToIndex(_ newIndex: Int) {
        guard workingAssets.indices.contains(newIndex) else { return }
        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
            currentIndex = newIndex
            labelText = HeadshotPreviewSheet.labelText(for: workingAssets, index: newIndex, fallback: initialAsset)
            isEditingLabel = false
            labelFieldFocused = false
            pendingDeletion = nil
        }
    }
    
    private func performDeletion(_ asset: HeadshotAsset) {
        pendingDeletion = nil
        onDelete(asset)
        if let idx = workingAssets.firstIndex(where: { $0.id == asset.id }) {
            workingAssets.remove(at: idx)
            if workingAssets.isEmpty {
                dismiss()
                return
            }
            let newIndex = min(idx, workingAssets.count - 1)
            currentIndex = newIndex
            labelText = HeadshotPreviewSheet.labelText(for: workingAssets, index: newIndex, fallback: initialAsset)
            isEditingLabel = false
            labelFieldFocused = false
        }
    }
    
    private func actionButton(systemName: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
                .padding(12)
                .background(tint, in: Circle())
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.4), radius: 6, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }
    
    @ViewBuilder
    private func headshotPreview(for asset: HeadshotAsset?) -> some View {
        if
            let asset,
            let url = resolveHeadshotURL(named: asset.fileName),
            let uiImage = UIImage(contentsOfFile: url.path)
        {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFit()
        } else {
            ZStack {
                Color.white.opacity(0.08)
                Image(systemName: "person.crop.rectangle.badge.exclam")
                    .font(.system(size: 80))
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
    }
    private var labelDirty: Bool {
        guard let asset = currentAsset else { return false }
        let trimmed = labelText.trimmingCharacters(in: .whitespacesAndNewlines)
        let currentStored = asset.displayName ?? ""
        return trimmed != currentStored
    }
    
    private func persistLabelChanges() {
        guard labelDirty, let asset = currentAsset else { return }
        let trimmed = labelText.trimmingCharacters(in: .whitespacesAndNewlines)
        onRename(asset, trimmed)
        if let idx = workingAssets.firstIndex(where: { $0.id == asset.id }) {
            workingAssets[idx].displayName = trimmed.isEmpty ? nil : trimmed
        }
        labelText = trimmed
    }
    
    private func finalizeLabelEditing() {
        persistLabelChanges()
        isEditingLabel = false
        labelFieldFocused = false
    }
    
    private static func labelText(for assets: [HeadshotAsset], index: Int, fallback: HeadshotAsset) -> String {
        guard assets.indices.contains(index) else {
            return fallback.displayName ?? ""
        }
        return assets[index].displayName ?? ""
    }
    
    @ViewBuilder
    private var labelEditor: some View {
        VStack(spacing: 6) {
            if isEditingLabel {
                TextField("Headshot label", text: $labelText)
                    .font(Theme.Font.headline)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .textInputAutocapitalization(.words)
                    .disableAutocorrection(true)
                    .submitLabel(.done)
                    .focused($labelFieldFocused)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .onAppear { labelFieldFocused = true }
                    .onSubmit { finalizeLabelEditing() }
            } else {
                Text(labelDisplayText)
                    .font(Theme.Font.headline)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .onTapGesture {
                        guard currentAsset != nil else { return }
                        isEditingLabel = true
                        labelFieldFocused = true
                    }
            }
        }
        .onChange(of: currentIndex, initial: false) { _, _ in
            isEditingLabel = false
            labelFieldFocused = false
            labelText = HeadshotPreviewSheet.labelText(for: workingAssets, index: currentIndex, fallback: initialAsset)
        }
        .onChange(of: labelFieldFocused, initial: false) { _, focused in
            if !focused && isEditingLabel {
                finalizeLabelEditing()
            }
        }
    }
    
    private var labelDisplayText: String {
        let trimmed = labelText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return currentAsset?.title ?? "Headshot"
        }
        return trimmed
    }
}

private struct ActorKitResourceLink: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let urlString: String?
    
    var url: URL? {
        guard let urlString else { return nil }
        return URL(string: urlString)
    }
    
    static let sampleLinks: [ActorKitResourceLink] = [
        ActorKitResourceLink(
            title: "SAG-AFTRA",
            subtitle: "Union contracts, rates, membership status, and official updates",
            urlString: "https://www.sagaftra.org"
        ),
        ActorKitResourceLink(
            title: "IMDb (Pro Recommended)",
            subtitle: "Industry-standard credits, production research, and casting intel",
            urlString: "https://www.imdb.com"
        ),
        ActorKitResourceLink(
            title: "Deadline",
            subtitle: "Breaking casting news, pilot pickups, and deal announcements",
            urlString: "https://deadline.com"
        ),
        ActorKitResourceLink(
            title: "The Hollywood Reporter",
            subtitle: "In-depth industry reporting and studio movement",
            urlString: "https://www.hollywoodreporter.com"
        ),
        ActorKitResourceLink(
            title: "Casting Networks",
            subtitle: "Commercial & theatrical breakdowns and submissions",
            urlString: "https://www.castingnetworks.com"
        ),
        ActorKitResourceLink(
            title: "Actors Access",
            subtitle: "Theatrical breakdowns, Eco Casts, and union projects",
            urlString: "https://actorsaccess.com"
        ),
        ActorKitResourceLink(
            title: "iTFactor Instagram",
            subtitle: "Self Tape Studio updates, pro tips, and new features",
            urlString: "https://www.instagram.com/itfactor_selftapestudio?igsh=MTg0aDhzcndxMGZoaA=="
        )
    ]
}
