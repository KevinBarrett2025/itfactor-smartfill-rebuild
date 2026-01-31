import SwiftUI
import UIKit

public struct HomeScreenView: View {
    let repo: ProjectsRepository
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var vm: ProjectsViewModel
    @State private var showingNewProjectWizard = false
    @State private var profileManager = ActorProfileManager()
    @State private var showingActorKit = false
    @State private var showingSettings = false
    @State private var showingFullScreenCoin = false
    @AppStorage("SpinnerCoinPresetID") private var savedSpinnerPresetID = SpinnerCoinPreset.turnstile.id
    @AppStorage("SpinnerCoinAcceleration") private var savedSpinnerAcceleration: Double = 1.0
    @AppStorage("SpinnerCoinGlow") private var savedSpinnerGlow: Double = 0.35
    @AppStorage("SpinnerCoinHaptics") private var savedSpinnerHaptics: Double = 0.6
    @AppStorage("SpinnerCoinSparks") private var savedSpinnerSparks: Double = 0.5
    @AppStorage("SpinnerCoinSparkSpread") private var savedSpinnerSparkSpread: Double = 0.6
    @AppStorage("SpinnerCoinGlowEnabled") private var savedSpinnerGlowEnabled: Bool = true
    @AppStorage("SpinnerCoinHapticsEnabled") private var savedSpinnerHapticsEnabled: Bool = true
    @AppStorage("SpinnerCoinSparksEnabled") private var savedSpinnerSparksEnabled: Bool = true
    @AppStorage("SpinnerCoinYoYoEnabled") private var savedSpinnerYoYoEnabled: Bool = SpinnerYoYoConfig.default.isEnabled
    @AppStorage("SpinnerCoinYoYoDepth") private var savedSpinnerYoYoDepth: Double = 0.18
    @AppStorage("SpinnerCoinYoYoLift") private var savedSpinnerYoYoLift: Double = 0.22
    @AppStorage("SpinnerCoinYoYoFrequency") private var savedSpinnerYoYoFrequency: Double = 3.5
    @AppStorage("SpinnerCoinYoYoDamping") private var savedSpinnerYoYoDamping: Double = 0.65
    @AppStorage("SpinnerCoinYoYoThreshold") private var savedSpinnerYoYoThreshold: Double = 600
    @AppStorage("ActorKit.disableBadgeAnimation") private var disableBadgeAnimation = false
    @AppStorage("ActorKit.badgeSpeedMultiplier") private var badgeSpeedMultiplier: Double = 1.0
    @AppStorage("ActorKit.badgeStopFace") private var badgeStopFaceRaw: String = ActorKitBadgeStopFace.logo.rawValue
    @State private var didAppear = false

    private var theme: STSTheme { themeManager.current }
    private var badgeStopFace: ActorKitBadgeStopFace {
        ActorKitBadgeStopFace(rawValue: badgeStopFaceRaw) ?? .logo
    }
    private var spinnerPreset: SpinnerCoinPreset {
        SpinnerCoinPreset.preset(for: savedSpinnerPresetID)
    }
    
    public init(repo: ProjectsRepository) {
        self.repo = repo
        _vm = State(initialValue: ProjectsViewModel(repo: repo))
    }

    private var spinnerTuning: SpinnerCoinTuning {
        SpinnerCoinTuning(
            acceleration: CGFloat(savedSpinnerAcceleration),
            glow: CGFloat(savedSpinnerGlow),
            haptics: CGFloat(savedSpinnerHaptics),
            sparks: CGFloat(savedSpinnerSparks),
            sparkSpread: CGFloat(savedSpinnerSparkSpread),
            glowEnabled: savedSpinnerGlowEnabled,
            hapticsEnabled: savedSpinnerHapticsEnabled,
            sparksEnabled: savedSpinnerSparksEnabled
        )
    }

    private var spinnerYoYoConfig: SpinnerYoYoConfig {
        SpinnerYoYoConfig(
            isEnabled: savedSpinnerYoYoEnabled,
            maxDepthOffset: CGFloat(savedSpinnerYoYoDepth),
            maxVerticalOffset: CGFloat(savedSpinnerYoYoLift),
            flingVelocityThreshold: CGFloat(savedSpinnerYoYoThreshold),
            springFrequency: CGFloat(savedSpinnerYoYoFrequency),
            springDampingRatio: CGFloat(savedSpinnerYoYoDamping)
        )
    }

    private var cinematicBackground: some View {
        ZStack {
            theme.backgroundGradient
                .ignoresSafeArea()

            RadialGradient(
                gradient: Gradient(colors: [
                    theme.primaryAccent.opacity(theme.id == .studioLobbyV1 ? 0.18 : 0.24),
                    Color.clear
                ]),
                center: .center,
                startRadius: 0,
                endRadius: 450
            )
            .blendMode(.screen)
            .ignoresSafeArea()
        }
    }

    private var actorTitle: some View {
        VStack(spacing: 4) {
            Text(profileManager.profile.displayName)
                .font(.system(.largeTitle, design: .default).weight(.semibold))
                .foregroundColor(theme.textPrimary)
                .multilineTextAlignment(.center)

            Text("Welcome to your studio lobby")
                .font(.callout)
                .foregroundColor(theme.textSecondary)
        }
        .padding(.horizontal, 24)
    }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                cinematicBackground
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        topChrome
                            .padding(.horizontal, 12)
                            .padding(.top, 8)

                        actorTitle
                            .opacity(didAppear ? 1 : 0)
                            .offset(y: didAppear ? 0 : 8)
                            .animation(.easeOut(duration: 0.4), value: didAppear)

                        spinnerHero
                            .padding(.top, 6)

                        projectsCinematicSection
                            .padding(.bottom, 40)
                    }
                }
                .scrollDisabled(true)
                .padding(.top, 4)
                .onAppear {
                    didAppear = true
                    if savedSpinnerPresetID != SpinnerCoinPreset.turnstile.id {
                        savedSpinnerPresetID = SpinnerCoinPreset.turnstile.id
                    }
                }

                if showingFullScreenCoin {
                    SpinnerCoinTheatreView(
                        headshot: profileAvatarUIImage,
                        headshotTransform: profileManager.profile.profileHeadshotTransform,
                        onClose: { showingFullScreenCoin = false }
                    )
                    .transition(.opacity)
                    .zIndex(1)
                }
            }
            .navigationBarHidden(true)
            .navigationDestination(for: UUID.self) { id in
                ProjectDetailView(projectID: id, repo: repo)
            }
        }
        // Always present NewProjectWizard sheet regardless of gating.
        .sheet(isPresented: $showingNewProjectWizard) {
            NavigationStack {
                NewProjectWizard(
                    repo: repo,
                    onSave: { newProject in
                        if repo.project(by: newProject.id) != nil {
                            repo.updateProject(newProject)
                        } else {
                            repo.insert(project: newProject)
                        }
                        vm.reload()
                    },
                    onRecordingComplete: { projectID, sessionID in
                        print("🎯 HomeScreen: onRecordingComplete project=\(projectID) session=\(sessionID)")
                        guard let project = repo.project(by: projectID),
                              let session = project.sessions.first(where: { $0.id == sessionID }) else {
                            print("⚠️ HomeScreen: unable to resolve project/session for TakeReview handoff")
                            return
                        }
                        showingNewProjectWizard = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                            presentTakeReview(for: project, session: session)
                        }
                    }
                )
            }
            .interactiveDismissDisabled(true)
        }
        .fullScreenCover(isPresented: $showingActorKit) {
            ActorKitView(profileManager: profileManager, projectsRepository: repo)
                .onDisappear {
                    profileManager = ActorProfileManager()
                }
        }
        .fullScreenCover(isPresented: takeReviewHandoffBinding) {
            takeReviewHandoff
        }
        .sheet(isPresented: $showingSettings, onDismiss: {
            NotificationCenter.default.post(name: .spinnerCloseSettings, object: nil)
        }) {
            NavigationStack {
                SettingsView()
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") {
                                showingSettings = false
                            }
                        }
                    }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .spinnerOpenSettings)) { _ in
            showingSettings = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .actorProfileDidUpdate)) { _ in
            profileManager = ActorProfileManager()
        }
        .onAppear {
            vm.reload()
            profileManager = ActorProfileManager()
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("STSProjectsListShouldReload"))) { _ in
            // 🚨 ENHANCED: Prevent main thread blocking during reload
            Task { @MainActor in
                vm.reload()
                profileManager = ActorProfileManager()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("STSTakeRatingUpdated"))) { _ in
            Task { @MainActor in
                vm.reload()
                profileManager = ActorProfileManager()
            }
        }
        .stsPortraitOnly(label: "HomeScreenView")
    }

    private var chromeFill: Color {
        theme.id == .studioLobbyV1 ? Color.white.opacity(0.11) : theme.cardBackground
    }

    private var chromeStroke: Color {
        theme.id == .studioLobbyV1 ? Color.clear : theme.cardStroke
    }

    private var spinnerBackgroundGradient: LinearGradient {
        if theme.id == .studioLobbyV1 {
            return LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.07, blue: 0.12),
                    Color(red: 0.03, green: 0.03, blue: 0.05)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        return LinearGradient(
            colors: [
                theme.cardBackground,
                theme.cardBackground.opacity(0.7)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var spinnerStrokeColor: Color {
        theme.id == .studioLobbyV1 ? Color.white.opacity(0.08) : theme.cardStroke
    }

    // MARK: - TakeReview handoff
    @State private var handoffSession: ProjectSession?
    @State private var handoffProject: Project?
    @State private var playerRequest: PlayerRequest?

    private var takeReviewHandoffBinding: Binding<Bool> {
        Binding(
            get: { handoffProject != nil && handoffSession != nil },
            set: { isPresented in
                if !isPresented {
                    handoffSession = nil
                    handoffProject = nil
                }
            }
        )
    }

    @ViewBuilder
    private var takeReviewHandoff: some View {
        if let project = handoffProject, let session = handoffSession {
            NavigationStack {
                takeReviewHandoffContent(project: project, session: session)
            }
            .sheet(item: $playerRequest) { request in
                if request.prefersMediaPlayer {
                    SwipeableMediaPlayerView(
                        takes: request.takes,
                        session: request.session,
                        project: request.project,
                        initialIndex: request.initialIndex,
                        onDismiss: {
                            playerRequest = nil
                        },
                        onTakeAction: { action, take in
                            handleTakeActionFromHome(action, take: take, session: request.session, project: request.project)
                        }
                    )
                } else {
                    SwipeableVideoPlayerView(
                        takes: request.takes,
                        session: request.session,
                        project: request.project,
                        initialIndex: request.initialIndex,
                        onDismiss: {
                            playerRequest = nil
                        },
                        onTakeAction: { action, take in
                            handleTakeActionFromHome(action, take: take, session: request.session, project: request.project)
                        },
                        repository: repo
                    )
                }
            }
        } else {
            EmptyView()
        }
    }

    @ViewBuilder
    private func takeReviewHandoffContent(project: Project, session: ProjectSession) -> some View {
        TakeReviewPage(
            session: session,
            project: project,
            repository: repo,
            initialViewType: .scenes,
            initialSceneNumber: session.sceneNumber(for: session.id),
            onSessionAction: { _ in
                vm.reload()
            },
            onTakeAction: { action, take in
                handleTakeActionFromHome(action, take: take, session: session, project: project)
            },
            onVideoPlayerRequest: { takes, initialIndex, viewType, sceneNumber, prefersMediaPlayer in
                playerRequest = PlayerRequest(
                    takes: takes,
                    session: session,
                    project: project,
                    initialIndex: initialIndex,
                    viewType: viewType,
                    sceneNumber: sceneNumber,
                    prefersMediaPlayer: prefersMediaPlayer
                )
            },
            onClose: {
                handoffSession = nil
                handoffProject = nil
                vm.reload()
            },
            onExitProcessingReady: nil,
            isReadOnly: project.isArchived
        )
    }

    private func presentTakeReview(for project: Project, session: ProjectSession) {
        print("🎯 HomeScreen: presenting TakeReview for project=\(project.id) session=\(session.id)")
        handoffProject = project
        handoffSession = session
    }
    
    private func handleTakeActionFromHome(_ action: TakeAction,
                                          take: ProjectTake,
                                          session: ProjectSession,
                                          project: Project) {
        switch action {
        case .markBest:
            let newRating: TakeRating = take.rating == .finalSelect ? .unrated : .finalSelect
            repo.setUnifiedTakeRating(
                takeID: take.id,
                sessionID: session.id,
                projectID: project.id,
                rating: newRating
            )
        case .favorite:
            repo.toggleTakeFavorite(takeID: take.id, in: session.id, of: project.id)
        case .setRating(let rating):
            repo.setUnifiedTakeRating(
                takeID: take.id,
                sessionID: session.id,
                projectID: project.id,
                rating: rating
            )
        case .delete:
            repo.deleteTake(takeID: take.id, from: session.id, in: project.id)
        case .export:
            repo.exportTake(takeID: take.id, from: session.id, in: project.id)
        case .addNote, .editSmartFill:
            print("ℹ️ HomeScreen: action \(action.debugName) not implemented in lobby flow")
        default:
            break
        }
        vm.reload()
    }
    
    private struct PlayerRequest: Identifiable {
        let id = UUID()
        let takes: [ProjectTake]
        let session: ProjectSession
        let project: Project
        let initialIndex: Int
        let viewType: TakeReviewPage.ViewType
        let sceneNumber: Int?
        let prefersMediaPlayer: Bool
    }

    private var topChrome: some View {
        HStack {
            NavigationLink(destination: ArchivesView(repo: repo)) {
                ZStack {
                    Circle()
                        .fill(chromeFill)
                        .overlay(Circle().stroke(chromeStroke, lineWidth: 1))
                        .frame(width: 44, height: 44)
                        .shadow(radius: 2)
                    Image(systemName: "rectangle.stack")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 22, height: 22)
                        .foregroundColor(theme.textPrimary)

                    if vm.archivedProjects.count > 0 {
                        Text("\(vm.archivedProjects.count)")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(theme.primaryButtonForeground)
                            .frame(width: 18, height: 18)
                            .background(Circle().fill(theme.primaryAccent))
                            .offset(x: 12, y: -12)
                    }
                }
                .accessibilityLabel("View Archives")
            }

            Spacer()

            Button {
                showingSettings = true
            } label: {
                ZStack {
                    Circle()
                        .fill(chromeFill)
                        .overlay(Circle().stroke(chromeStroke, lineWidth: 1))
                        .frame(width: 44, height: 44)
                        .shadow(radius: 2)
                    Image(systemName: "gear")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 24, height: 24)
                        .foregroundColor(theme.textPrimary)
                }
            }
            .accessibilityLabel("Open Settings")
        }
        .padding(.horizontal, 12)
        .padding(.top, 16)
    }

    private var spinnerHero: some View {
        VStack(spacing: 12) {
            SpinnerCoinView(
                headshot: profileAvatarUIImage,
                transform: profileManager.profile.profileHeadshotTransform,
                height: 240,
                animationDisabled: disableBadgeAnimation,
                restAngleDegrees: badgeStopFace.restAngleDegrees,
                preset: spinnerPreset,
                tuning: spinnerTuning,
                yoYoConfig: spinnerYoYoConfig,
                speedMultiplier: CGFloat(badgeSpeedMultiplier)
            ) {
                showingActorKit = true
            }
            .overlay(SpinnerOverlay())
            .padding(18)
            .background(
                ZStack {
                    Image("STS_LensBackground")
                        .resizable()
                        .scaledToFill()
                        .frame(width: 260, height: 260)
                        .clipShape(Circle())
                        .shadow(color: Color.black.opacity(0.5), radius: 30, x: 0, y: 18)
                        .overlay(
                            Circle()
                                .stroke(Color.black.opacity(0.35), lineWidth: 3)
                        )
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.06), lineWidth: 1)
                                .blur(radius: 10)
                        )
                        .overlay(
                            Circle()
                                .fill(
                                    RadialGradient(
                                        colors: [
                                            Color.white.opacity(0.12),
                                            Color.clear
                                        ],
                                        center: .center,
                                        startRadius: 0,
                                        endRadius: 120
                                    )
                                )
                                .blendMode(.plusLighter)
                                .opacity(0.55)
                        )
                        .mask(Circle())

                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.20),
                                    Color.black.opacity(0.40)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 2
                        )
                        .frame(width: 252, height: 252)
                }
            )
            .shadow(color: Color.black.opacity(0.3), radius: 20, x: 0, y: 10)
        }
        .padding(.vertical, 10)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Open Actor Kit")
        .accessibilityHint("Tap the spinner coin to open ActorKit and update your profile.")
    }

    private var projectsCinematicSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .lastTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Active Projects")
                        .font(.title3.weight(.semibold))
                        .foregroundColor(theme.textPrimary)

                    if !vm.projects.isEmpty {
                        Text("Swipe through your latest sessions and submissions")
                            .font(.footnote)
                            .foregroundColor(theme.textSecondary)
                    }
                }

                Spacer()

                if !vm.projects.isEmpty {
                    Text("\(vm.projects.count) live")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(theme.primaryAccent.opacity(0.18), in: Capsule())
                        .foregroundColor(theme.primaryAccent)
                }
            }
            .padding(.horizontal, 16)

            let cardWidth: CGFloat = 320
            let cardHeight: CGFloat = 210

            if vm.projects.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 22) {
                        EmptyProjectsCarouselCard(theme: theme) {
                            showingNewProjectWizard = true
                        }
                        .frame(width: cardWidth, height: cardHeight)
                        .padding(.vertical, 4)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 6)
                    .padding(.bottom, 10)
                }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 22) {
                        ForEach(vm.projects, id: \.id) { project in
                            NavigationLink {
                                ProjectDetailView(projectID: project.id, repo: repo)
                            } label: {
                                ProjectCarouselCard(
                                    project: project,
                                    sessionsCount: project.sessions.filter { !$0.isArchived }.count,
                                    theme: theme
                                )
                                .frame(width: cardWidth, height: cardHeight)
                                .padding(.vertical, 4)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 6)
                    .padding(.bottom, 10)
                }

                HStack {
                    Spacer()
                    Button(action: { showingNewProjectWizard = true }) {
                        HStack(spacing: 8) {
                            Image(systemName: "plus")
                                .font(.body.weight(.semibold))
                            Text("Start New Session")
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
                    Spacer()
                }
                .padding(.top, 4)
                .padding(.horizontal, 32)
                .padding(.bottom, 24)
            }
        }
    }
}

extension HomeScreenView {
    private var profileAvatarImage: Image? {
        guard let preferred = profileManager.profile.preferredHeadshot,
              let url = resolveHeadshotURL(named: preferred.fileName),
              let uiImage = UIImage(contentsOfFile: url.path) else {
            return nil
        }
        return Image(uiImage: uiImage)
    }
    
    private var profileAvatarUIImage: UIImage? {
        guard let preferred = profileManager.profile.preferredHeadshot,
              let url = resolveHeadshotURL(named: preferred.fileName),
              let uiImage = UIImage(contentsOfFile: url.path) else {
            return nil
        }
        return uiImage
    }
}

private struct ProjectCarouselCard: View {
    let project: Project
    let sessionsCount: Int
    let theme: STSTheme

    @State private var isGlowing = false
    @State private var wobblePhase: Double = 0

    private enum ArtCategory {
        case feature, television, theatre, webSeries, shortFilm, commercial, other
    }

    private var artCategory: ArtCategory {
        let type = project.projectType
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        if type.contains("web")
            || type.contains("digital")
            || type.contains("online")
            || type.contains("stream")
            || type.contains("new media") {
            return .webSeries
        }
        if type.contains("short") {
            return .shortFilm
        }
        if type.contains("feature") || type.contains("film") {
            return .feature
        }
        if type.contains("tv")
            || type.contains("television")
            || (type.contains("series") && !type.contains("web")) {
            return .television
        }
        if type.contains("theatre")
            || type.contains("theater")
            || type.contains("stage") {
            return .theatre
        }
        if type.contains("commercial")
            || type.contains("spot")
            || type.contains("brand") {
            return .commercial
        }
        return .other
    }

    private var artworkImageName: String {
        switch artCategory {
        case .feature:     return "STSProjectCard_FeatureFilm"
        case .television:  return "STSProjectCard_Television"
        case .theatre:     return "STSProjectCard_Theatre"
        case .webSeries:   return "STSProjectCard_WebSeries"
        case .shortFilm:   return "STSProjectCard_ShortFilm"
        case .commercial:  return "STSProjectCard_Commercial"
        case .other:       return "STSProjectCard_Generic"
        }
    }

    // MARK: - Accent color mapping

    /// Base accent color for this project type when the project is not marked urgent.
    private func projectTypeBaseAccent(theme: STSTheme) -> Color {
        switch artCategory {
        case .feature:
            return theme.primaryAccent

        case .television:
            return Color(hue: 0.60, saturation: 0.35, brightness: 0.95)

        case .theatre:
            return Color(hue: 0.78, saturation: 0.40, brightness: 0.95)

        case .webSeries:
            return Color(hue: 0.52, saturation: 0.35, brightness: 0.96)

        case .shortFilm:
            return Color(hue: 0.11, saturation: 0.32, brightness: 0.98)

        case .commercial:
            return Color(hue: 0.07, saturation: 0.40, brightness: 0.98)

        case .other:
            return theme.primaryAccent
        }
    }

    private func accentColor(theme: STSTheme, due: HomeProjectDueInfo?) -> Color {
        if let due, due.urgency.isUrgent {
            return due.accent
        } else {
            return projectTypeBaseAccent(theme: theme)
        }
    }

    private struct SessionStats {
        let sessions: Int
        let takes: Int
        let bestTakes: Int
        let lastSessionDate: Date?
    }

    private var sessionStats: SessionStats {
        let activeSessions = project.sessions.filter { !$0.isArchived }
        let takes = activeSessions.flatMap { $0.takes }
        let bestTakes = takes.filter { $0.rating == .finalSelect }.count
        let lastDate = activeSessions.sorted(by: { $0.date > $1.date }).first?.date

        return SessionStats(
            sessions: max(sessionsCount, activeSessions.count),
            takes: takes.count,
            bestTakes: bestTakes,
            lastSessionDate: lastDate
        )
    }

    private struct HomeProjectDueInfo {
        enum Urgency {
            case none
            case normal
            case dueSoon
            case dueToday
            case pastDue

            var isUrgent: Bool {
                switch self {
                case .dueSoon, .dueToday, .pastDue:
                    return true
                default:
                    return false
                }
            }
        }

        let title: String
        let badge: String
        let accent: Color
        let urgency: Urgency
    }

    private var dueInfo: HomeProjectDueInfo? {
        guard let dueDate = project.auditionDueDate else { return nil }
        let now = Date()
        let interval = dueDate.timeIntervalSince(now)
        let hours = interval / 3600
        let days = Int(hours / 24)

        if interval <= 0 {
            return HomeProjectDueInfo(
                title: "Past Due",
                badge: "LATE",
                accent: .red,
                urgency: .pastDue
            )
        } else if days < 1 {
            return HomeProjectDueInfo(
                title: "Due Today",
                badge: "TODAY",
                accent: .orange,
                urgency: .dueToday
            )
        } else if days <= 2 {
            return HomeProjectDueInfo(
                title: "Due Soon",
                badge: "48H",
                accent: .yellow,
                urgency: .dueSoon
            )
        } else {
            return HomeProjectDueInfo(
                title: "Due in \(days)d",
                badge: "\(days)d",
                accent: theme.primaryAccent,
                urgency: .normal
            )
        }
    }

    private var primaryRoleName: String? {
        if let sessionRole = project.sessions
            .compactMap({ $0.roleName?.slateTrimmedNonEmpty })
            .first {
            return sessionRole
        }
        if let projectRole = project.roles
            .compactMap({ $0.name.slateTrimmedNonEmpty })
            .first {
            return projectRole
        }
        return nil
    }

    private var metadataSummary: String? {
        var parts: [String] = []

        let trimmedType = project.projectType.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedType.isEmpty {
            parts.append(trimmedType)
        }

        let trimmedGenre = project.genre.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedGenre.isEmpty {
            parts.append(trimmedGenre)
        }

        if let director = project.castingDirector?.name.slateTrimmedNonEmpty {
            parts.append(director)
        }

        guard !parts.isEmpty else { return nil }
        return parts.joined(separator: " • ")
    }

    private var hasUrgency: Bool {
        dueInfo?.urgency.isUrgent ?? false
    }

    var body: some View {
        let stats = sessionStats
        let due = dueInfo
        let accent = accentColor(theme: theme, due: due)

        let clipShape = RoundedRectangle(cornerRadius: 26, style: .continuous)

        ZStack {
            cardBackground(accent: accent)
                .overlay(urgentGlowOverlay(accent: accent))

            content(stats: stats, due: due)
                .padding(16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .scaleEffect(hasUrgency ? (isGlowing ? 1.02 : 1.0) : 1.0)
        .rotationEffect(hasUrgency ? .degrees(wobblePhase) : .degrees(0))
        .animation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true), value: isGlowing)
        .animation(.easeInOut(duration: 0.18), value: wobblePhase)
        .onAppear {
            if hasUrgency {
                startUrgencyAnimations()
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .clipShape(clipShape)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel(stats: stats, due: due))
    }

    @ViewBuilder
    private func content(stats: SessionStats, due: HomeProjectDueInfo?) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(project.title)
                    .font(.title3.weight(.semibold))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)

                if let role = primaryRoleName {
                    Text(role)
                        .font(.headline.weight(.semibold))
                        .foregroundColor(theme.primaryAccent)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }

                if let summary = metadataSummary {
                    Text(summary)
                        .font(.caption)
                        .foregroundColor(theme.textSecondary)
                        .lineLimit(2)
                }

                if let due {
                    HStack(spacing: 6) {
                        Text(due.badge.uppercased())
                            .font(.system(size: 10, weight: .heavy, design: .monospaced))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(due.accent.opacity(0.22), in: Capsule())
                            .foregroundColor(due.accent)

                        Text(due.title)
                            .font(.caption2.weight(.medium))
                            .foregroundColor(theme.textSecondary)
                    }
                    .padding(.top, 2)
                }
            }

            HStack(spacing: 10) {
                MetricPill(icon: "list.number", title: "Scenes", value: "\(project.sceneCount)")
                MetricPill(icon: "person.2.fill", title: "Sessions", value: "\(stats.sessions)")
                MetricPill(icon: "video.fill", title: "Takes", value: "\(stats.takes)")
            }

            HStack {
                Spacer()
                Text("View Project →")
                    .font(.callout.weight(.semibold))
                    .foregroundColor(theme.primaryAccent)
            }
        }
    }

    @ViewBuilder
    private func cardBackground(accent: Color) -> some View {
        let shape = RoundedRectangle(cornerRadius: 26, style: .continuous)

        ZStack {
            shape
                .fill(
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.80),
                            accent.opacity(0.40)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    shape
                        .stroke(Color.white.opacity(0.18), lineWidth: 1)
                )

            Image(artworkImageName)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
                .scaleEffect(1.12, anchor: .center)
                .offset(x: 34)
                .opacity(0.82)
                .blendMode(.screen)
                .allowsHitTesting(false)
                .clipShape(shape)
        }
        .clipShape(shape)
        .shadow(color: Color.black.opacity(0.35), radius: 12, x: 0, y: 10)
    }

    @ViewBuilder
    private func urgentGlowOverlay(accent: Color) -> some View {
        if hasUrgency {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(accent.opacity(isGlowing ? 0.95 : 0.35), lineWidth: 2.0)
                .blur(radius: isGlowing ? 7 : 2)
                .opacity(0.9)
        }
    }

    private func startUrgencyAnimations() {
        isGlowing = false
        withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
            isGlowing = true
        }

        wobblePhase = -0.8
        withAnimation(
            .easeInOut(duration: 0.18)
                .repeatCount(4, autoreverses: true)
        ) {
            wobblePhase = 0.8
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.72) {
            wobblePhase = 0
        }
    }

    private func accessibilityLabel(stats: SessionStats, due: HomeProjectDueInfo?) -> String {
        var parts: [String] = []
        parts.append(project.title)

        if let role = primaryRoleName {
            parts.append("Role \(role)")
        }

        parts.append("\(stats.sessions) session\(stats.sessions == 1 ? "" : "s")")
        parts.append("\(stats.takes) takes")

        if let due {
            parts.append(due.title)
        }

        return parts.joined(separator: ", ")
    }

    private struct MetricPill: View {
        let icon: String
        let title: String
        let value: String

        var body: some View {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(.white.opacity(0.85))

                VStack(alignment: .leading, spacing: 2) {
                    Text(value)
                        .font(.footnote.weight(.semibold))
                        .foregroundColor(.white)

                    Text(title.uppercased())
                        .font(.system(size: 9.5, weight: .heavy, design: .monospaced))
                        .foregroundColor(.white.opacity(0.65))
                }
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.white.opacity(0.08))
            )
        }
    }
}

private struct EmptyProjectsCarouselCard: View {
    let theme: STSTheme
    let onStartFirstProject: () -> Void

    private var backgroundColor: Color {
        if theme.id == .studioLobbyV1 {
            return Color.white.opacity(0.05)
        }
        return theme.cardBackground
    }

    private var strokeColor: Color {
        theme.id == .studioLobbyV1 ? Color.white.opacity(0.08) : theme.cardStroke
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("No projects yet")
                .font(.headline.weight(.semibold))
                .foregroundColor(theme.textPrimary)

            Text("Start your first project and bring your next role to life.")
                .font(.subheadline)
                .foregroundColor(theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()

            Button(action: onStartFirstProject) {
                Text("Create Your First Project")
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .foregroundColor(theme.primaryButtonForeground)
                    .background(theme.primaryButtonBackground)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(theme.cardStroke, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(backgroundColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(strokeColor, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.35), radius: 12, x: 0, y: 10)
        .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("No projects yet. Create your first project.")
    }
}
