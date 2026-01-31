import SwiftUI

// FIXED: Use unique struct name to avoid naming conflict with ProjectDetailView
struct SessionActorMustKnowsData: Identifiable {
    let id = UUID()
    let project: Project
    let session: ProjectSession
}

public struct SessionDetailView: View {
    @State private var vm: SessionDetailViewModel
    private let project: Project
    private let repository: ProjectsRepository
    
    // FIXED: Use Identifiable struct instead of boolean + optional pattern
    @State private var sessionActorMustKnowsData: SessionActorMustKnowsData?
    @State private var showSessionReview = false

    public init(project: Project, session: ProjectSession, repository: ProjectsRepository) {
        _vm = State(initialValue: SessionDetailViewModel(session: session))
        self.project = project
        self.repository = repository
    }
    
    init(vm: SessionDetailViewModel, project: Project, repository: ProjectsRepository) {
        _vm = State(initialValue: vm)
        self.project = project
        self.repository = repository
    }

    public var body: some View {
        ZStack {
            BrandBackground()
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                // Session Header with Icon
                VStack(spacing: 16) {
                    Image(systemName: sessionTypeIcon(for: vm.session.type))
                        .font(.system(size: 60))
                        .foregroundStyle(Theme.primary)
                    
                    VStack(spacing: 8) {
                        Text(vm.session.type.rawValue)
                            .font(Theme.Font.title)
                            .foregroundStyle(Theme.textPrimary)
                        
                        Text(vm.session.date.formatted(date: .abbreviated, time: .shortened))
                            .font(Theme.Font.body)
                            .foregroundStyle(.gray)
                    }
                }
                
                // Session Details Card
                STSCard {
                    VStack(alignment: .leading, spacing: 16) {
                        sessionDetailsContent
                        
                        // Session Statistics
                        if !vm.session.takes.isEmpty {
                            Divider()
                                .background(Color.white.opacity(0.1))
                            
                            sessionStatsContent
                        }
                    }
                }
                
                AuditionChecklistStatusCard(
                    session: vm.session,
                    contextTitle: "\(project.title) • \(vm.session.type.rawValue)"
                ) {
                    sessionActorMustKnowsData = SessionActorMustKnowsData(project: project, session: vm.session)
                }
                
                Spacer()
                
                // ENHANCED: Action buttons that connect to working components
                VStack(spacing: 16) {
                    if !vm.session.takes.isEmpty {
                        // Primary Action - Watch Takes (connects to UnifiedSessionReview with working video)
                        BrandedPrimaryButton(
                            label: "Watch Takes (\(vm.session.takes.count))",
                            icon: "play.fill"
                        ) {
                            showSessionReview = true
                        }
                        
                        // Secondary Action - Resume Session (if applicable)
                        if vm.canResumeSession {
                            BrandedSecondaryButton(
                                label: "Resume Session"
                            ) {
                                sessionActorMustKnowsData = SessionActorMustKnowsData(project: project, session: vm.session)
                            }
                        }
                    } else {
                        // No takes yet - focus on session actions
                        BrandedPrimaryButton(
                            label: "Start Recording",
                            icon: "plus.circle.fill"
                        ) {
                            sessionActorMustKnowsData = SessionActorMustKnowsData(project: project, session: vm.session)
                        }
                    }
                }
                .padding(.bottom, 34)
            }
            .padding(.horizontal, 24)
        }
        .navigationTitle("Session")
        .navigationBarTitleDisplayMode(.inline)
        // FIXED: Use .sheet(item:) pattern to fix empty sheet bug
        .sheet(item: $sessionActorMustKnowsData, onDismiss: {
            sessionActorMustKnowsData = nil
        }) { data in
            ActorMustKnowsView(
                project: data.project,
                session: data.session,
                repository: repository,
                onComplete: {
                    sessionActorMustKnowsData = nil
                }
            )
        }
        .fullScreenCover(isPresented: $showSessionReview) {
            // FIXED: Use UnifiedSessionReview instead of deleted SessionReview
            UnifiedSessionReview(
                project: project,
                session: vm.session,
                repository: repository
            )
        }
    }
    
    // MARK: - Session Details Content
    
    @ViewBuilder
    private var sessionDetailsContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let roleName = vm.session.roleName {
                detailRow(label: "Role", value: roleName)
            }
            
            if let location = vm.session.location {
                VStack(alignment: .leading, spacing: 4) {
                    detailRow(label: "Location", value: location.label)
                    if let address = location.address {
                        Text(address)
                            .font(Theme.Font.caption)
                            .foregroundStyle(.secondary)
                            .padding(.leading, 60)
                    }
                }
            }
            
            if let contact = vm.session.contact {
                VStack(alignment: .leading, spacing: 4) {
                    detailRow(label: "Contact", value: contact.name)
                    if let phone = contact.phone {
                        Text(phone)
                            .font(Theme.Font.caption)
                            .foregroundStyle(.secondary)
                            .padding(.leading, 60)
                    }
                }
            }
            
            if let notes = vm.session.notes, !notes.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Notes:")
                        .font(Theme.Font.caption)
                        .foregroundStyle(.secondary)
                    Text(notes)
                        .font(Theme.Font.body)
                        .foregroundStyle(Theme.textPrimary)
                }
            }
        }
    }
    
    @ViewBuilder
    private var sessionStatsContent: some View {
        HStack(spacing: 24) {
            statItem(
                icon: "video.fill",
                value: "\(vm.session.takes.count)",
                label: vm.session.takes.count == 1 ? "Take" : "Takes"
            )
            
            statItem(
                icon: "checkmark.circle.fill",
                value: "\(optionTakesCount)",
                label: TakeRating.option.displayName
            )
            
            statItem(
                icon: "star.fill",
                value: "\(finalSelectTakesCount)",
                label: TakeRating.finalSelect.displayName
            )
            
            statItem(
                icon: "clock.fill",
                value: totalDuration,
                label: "Duration"
            )
        }
    }
    
    @ViewBuilder
    private func detailRow(label: String, value: String) -> some View {
        HStack {
            Text("\(label):")
                .font(Theme.Font.caption)
                .foregroundStyle(.secondary)
                .frame(width: 50, alignment: .leading)
            
            Text(value)
                .font(Theme.Font.body)
                .foregroundStyle(Theme.textPrimary)
            
            Spacer()
        }
    }
    
    @ViewBuilder
    private func statItem(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(Theme.primary)
            
            Text(value)
                .font(Theme.Font.body)
                .fontWeight(.semibold)
                .foregroundStyle(Theme.textPrimary)
            
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Computed Properties
    
    private var optionTakesCount: Int {
        // CLEANED: Use unified TakeRating system instead of boolean properties
        vm.session.takes.filter { $0.rating == .option }.count
    }
    
    private var finalSelectTakesCount: Int {
        // CLEANED: Use unified TakeRating system instead of boolean properties  
        vm.session.takes.filter { $0.rating == .finalSelect }.count
    }
    
    private var totalDuration: String {
        let total = vm.session.takes.reduce(0) { $0 + $1.durationSeconds }
        let minutes = Int(total) / 60
        let seconds = Int(total) % 60
        return String(format: "%d:%02d", minutes, seconds)
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

// MARK: - SessionDetailViewModel Extension

extension SessionDetailViewModel {
    var canResumeSession: Bool {
        // Session can be resumed if it's recent and not completed
        let daysSinceSession = Calendar.current.dateComponents([.day], from: session.date, to: Date()).day ?? 0
        return daysSinceSession <= 7 && session.type == .selfTape
    }
}

#Preview {
    // ENTERPRISE: Create clean preview data without persistent sample projects
    let previewSession = ProjectSession(
        type: .selfTape,
        takes: [],
        roleName: "Preview Role"
    )
    let previewProject = Project(title: "Sample Project", sessions: [previewSession])
    
    SessionDetailView(
        vm: SessionDetailViewModel(session: previewSession),
        project: previewProject,
        repository: ProjectsRepositoryFactory.makePreviewRepository()
    )
}
