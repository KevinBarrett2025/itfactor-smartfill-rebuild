import SwiftUI

public enum ActorMustKnowsMode {
    case reference
    case sessionBound
}

public struct ActorMustKnowsView: View {
    private enum Context {
        case standalone
        case bound(projectID: UUID, sessionID: UUID)
    }
    
    fileprivate struct SessionOption: Identifiable, Equatable {
        let projectID: UUID
        let projectTitle: String
        var session: ProjectSession
        
        var id: UUID { session.id }
        var subtitle: String {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            return "\(session.type.rawValue) · \(formatter.string(from: session.date))"
        }
    }
    
    fileprivate struct ChecklistMetadata: Identifiable {
        let id = UUID()
        let item: ChecklistProgress.Item
        let title: String
        let icon: String
        let tip: String
        let reinforcement: String
    }
    
    private let context: Context
    let mode: ActorMustKnowsMode
    private let repository: ProjectsRepository
    private let onComplete: (() -> Void)?
    private let onNavigateToWizard: ((ChecklistProgress.Item) -> Void)?
    private let onCompletionStatus: ((Bool) -> Void)?
    @AppStorage("STSThemeID") private var storedThemeID: String = STSThemeID.studioLobbyV1.rawValue
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var sessionOptions: [SessionOption] = []
    @State private var selectedSession: SessionOption?
    @State private var philosopherMode = false
    @State private var progress: ChecklistProgress
    @State private var showingAchievement = false
    @State private var showingPhilosopherToast = false
    @State private var selectedProjectForWizard: Project?
    @State private var showingProjectPicker = false
    
    // MARK: - Metadata
    private let checklistItems: [ChecklistMetadata] = [
        .init(
            item: .characterBreakdown,
            title: "Character Breakdown",
            icon: "person.text.rectangle",
            tip: "Upload your breakdown or paste it into the project for quick recall.",
            reinforcement: "Access it instantly from Camera Session → Documents between takes."
        ),
        .init(
            item: .slateEssentials,
            title: "Slate Essentials",
            icon: "info.circle",
            tip: "Store name, role, and location in Project → Slate.",
            reinforcement: "Slate Teleprompter auto-populates so you can focus on delivery."
        ),
        .init(
            item: .quietTech,
            title: "Quiet Tech",
            icon: "iphone.slash",
            tip: "Enable Do Not Disturb and silence wearables before you roll.",
            reinforcement: "Keeps your takes clean and avoids notification surprises."
        ),
        .init(
            item: .wardrobeAlignment,
            title: "Wardrobe Alignment",
            icon: "tshirt",
            tip: "Review Actor Resources and IMDb lookbooks for the creative team.",
            reinforcement: "Match the world of the story with intentional wardrobe choices."
        ),
        .init(
            item: .frameAndLight,
            title: "Frame & Light",
            icon: "camera.viewfinder",
            tip: "Check eyelines, headroom, and key light placement.",
            reinforcement: "Need upgrades? Visit Self Tape Gear for mics, backdrops, and LEDs."
        ),
        .init(
            item: .submissionWindow,
            title: "Submission Window",
            icon: "calendar.badge.clock",
            tip: "Set deadline, timezone, and upload notes in Project → Submission.",
            reinforcement: "ItFactor reminders nudge you gently as the clock winds down."
        )
    ]
    
    // MARK: - Initializers
    public init(repository: ProjectsRepository, mode: ActorMustKnowsMode = .sessionBound, onComplete: (() -> Void)? = nil, onNavigateToWizard: ((ChecklistProgress.Item) -> Void)? = nil, onCompletionStatus: ((Bool) -> Void)? = nil) {
        self.context = .standalone
        self.mode = mode
        self.repository = repository
        self.onComplete = onComplete
        self.onNavigateToWizard = onNavigateToWizard
        self.onCompletionStatus = onCompletionStatus
        self._progress = State(initialValue: ChecklistProgress())
    }
    
    public init(project: Project, session: ProjectSession, repository: ProjectsRepository, mode: ActorMustKnowsMode = .sessionBound, onComplete: (() -> Void)? = nil, onNavigateToWizard: ((ChecklistProgress.Item) -> Void)? = nil, onCompletionStatus: ((Bool) -> Void)? = nil) {
        self.context = .bound(projectID: project.id, sessionID: session.id)
        self.mode = mode
        self.repository = repository
        self.onComplete = onComplete
        self.onNavigateToWizard = onNavigateToWizard
        self.onCompletionStatus = onCompletionStatus
        let option = SessionOption(projectID: project.id, projectTitle: project.title, session: session)
        self._selectedSession = State(initialValue: option)
        self._progress = State(initialValue: session.auditionChecklist ?? ChecklistProgress(sessionID: session.id))
    }
    
    // MARK: - Body
    public var body: some View {
        NavigationStack {
            ZStack {
                checklistTheme.backgroundGradient
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        header
                        
                        if mode == .sessionBound, case .standalone = context {
                            SessionSelectorView(
                                selectedSession: selectedSession,
                                philosopherMode: philosopherMode,
                                onSelect: selectSession,
                                onPhilosopherMode: activatePhilosopherMode,
                                onShowPicker: { showingProjectPicker = true },
                                sessionOptions: sessionOptions
                            )
                        }
                        
                        if mode == .sessionBound {
                            progressSummary
                        }
                        checklistList
                        if mode == .sessionBound {
                            actionButton
                        }
                    }
                    .padding(24)
                }
                
                if showingAchievement {
                    AchievementCelebrationView {
                        completeAndDismissAfterAchievement()
                    }
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
                }
                
                if showingPhilosopherToast {
                    PhilosopherToast()
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .padding(.bottom, 40)
                        .zIndex(5)
                }
            }
            .navigationTitle("Audition Checklist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundStyle(.white)
                }
            }
            .sheet(isPresented: $showingProjectPicker) {
                ProjectPickerView(
                    projects: repository.fetchProjects(),
                    onSelect: { project in
                        showingProjectPicker = false
                        selectedProjectForWizard = project
                    },
                    onCancel: { showingProjectPicker = false }
                )
            }
            .sheet(item: $selectedProjectForWizard) { project in
                NewSessionWizard(
                    projectID: project.id,
                    repo: repository,
                    presentChecklistOnFinish: false
                ) { newSession in
                    selectedProjectForWizard = nil
                    reloadSessions()
                    if let session = newSession {
                        selectSession(SessionOption(projectID: project.id, projectTitle: project.title, session: session))
                    }
                }
            }
            .onAppear {
                reloadSessions()
                syncProgressWithBindingIfNeeded()
            }
        }
    }
    
    private var checklistTheme: STSTheme {
        let id = STSThemeID(rawValue: storedThemeID) ?? .studioLobbyV1
        return STSThemeLibrary.theme(for: id)
    }

    private var descriptionText: String {
        switch mode {
        case .reference:
            return "A professional preparation guide to help you walk into every audition grounded, confident, and ready."
        case .sessionBound:
            return "Apply this checklist to ensure nothing is missed before recording."
        }
    }
    
    // MARK: - Subviews
    private var header: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(checklistTheme.primaryAccent.opacity(0.35))
                    .frame(width: 96, height: 96)
                    .blur(radius: 22)
                    .offset(y: 4)
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(Color.black)
            }
            
            Text("Audition Checklist")
                .font(Theme.Font.title)
                .foregroundStyle(checklistTheme.textPrimary)

            if mode == .reference {
                Text("REFERENCE GUIDE")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(checklistTheme.primaryAccent.opacity(0.9))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(checklistTheme.primaryAccent.opacity(0.15))
                    )
                    .padding(.top, 4)
            }
            
            Text("“Luck is what happens when preparation meets opportunity.”")
                .font(Theme.Font.caption)
                .foregroundStyle(checklistTheme.textSecondary.opacity(0.75))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Text("— The Roman Philosopher Seneca")
                .font(Theme.Font.caption2)
                .foregroundStyle(checklistTheme.textSecondary.opacity(0.6))
            
            Text(descriptionText)
                .font(Theme.Font.body)
                .foregroundStyle(checklistTheme.textSecondary.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
        }
        .padding(.top, 12)
    }
    
    private var progressSummary: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(progressLabel)
                    .font(Theme.Font.headline)
                    .foregroundStyle(checklistTheme.textPrimary)
                Spacer()
                Text(progressPercentage)
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(checklistTheme.textPrimary)
            }
            
            ProgressView(value: progress.completionFraction)
                .accentColor(progress.isComplete ? .green : checklistTheme.primaryAccent)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.08))
        )
    }
    
    private var checklistList: some View {
        VStack(spacing: 16) {
            ForEach(checklistItems) { metadata in
                let navAction = navigationAction(for: metadata.item)
                ChecklistRow(
                    title: metadata.title,
                    tip: metadata.tip,
                    reinforcement: metadata.reinforcement,
                    icon: metadata.icon,
                    isChecked: progress.checks[metadata.item] ?? false,
                    mode: mode,
                    onToggle: {
                        toggle(metadata.item)
                    },
                    onNavigate: navAction,
                    actionTitle: actionTitle(for: metadata.item),
                    accent: checklistTheme.primaryAccent
                )
            }
        }
    }
    
    private var actionButton: some View {
        VStack(spacing: 14) {
            let isComplete = progress.isComplete
            let accent = checklistTheme.primaryAccent
            let ctaTint = isComplete ? Color.white.opacity(0.9) : accent
            let ctaForeground = isComplete ? checklistTheme.textPrimary : Color.white

            Button(action: handlePrimaryAction) {
                Text(primaryButtonTitle)
                    .font(.headline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
            }
            .buttonStyle(.borderless) // avoid system blue default
            .tint(ctaTint)
            .foregroundStyle(ctaForeground)
            .disabled(!canRunPrimaryAction)
            .overlay {
                if isComplete {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(0.45), lineWidth: 1)
                        .shadow(color: Color.white.opacity(0.3), radius: 12, x: 0, y: 6)
                }
            }

            if case .bound = context, let session = selectedSession?.session, session.unlockedBadges.contains(.romanPhilosopher) {
                Label("Roman Philosopher badge unlocked", systemImage: "laurel.leading")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.8))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.08), in: Capsule())
            }
        }
    }
    
    // MARK: - Actions
    private func toggle(_ item: ChecklistProgress.Item) {
        progress.toggle(item)
        if selectedSession != nil {
            persistProgress()
        } else if philosopherMode {
            progress.sessionID = nil
        }
    }

    private func navigationAction(for item: ChecklistProgress.Item) -> (() -> Void)? {
        // Only specific items support navigation targets.
        let isMappable: Bool = {
            switch item {
            case .characterBreakdown, .slateEssentials, .submissionWindow, .frameAndLight:
                return true
            default:
                return false
            }
        }()
        guard isMappable else { return nil }
        if let handler = onNavigateToWizard {
            return { handler(item) }
        } else {
            // No handler provided (e.g., in TakeReview); still show the pill for consistency.
            return { }
        }
    }
    
    private func actionTitle(for item: ChecklistProgress.Item) -> String {
        switch item {
        case .characterBreakdown: return "Upload or Fill-out"
        case .slateEssentials: return "Set-up Slate"
        case .frameAndLight: return "View Products"
        case .submissionWindow: return "Add Date"
        default: return "Open"
        }
    }
    
    private func handlePrimaryAction() {
        if let _ = selectedSession {
            persistProgress()
            onCompletionStatus?(progress.isComplete)
            if progress.isComplete {
                showingAchievement = true
            } else {
                onComplete?()
            }
        } else {
            showingPhilosopherToast = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.9)) {
                    showingPhilosopherToast = false
                }
            }
        }
    }
    
    private func persistProgress() {
        guard var option = selectedSession else { return }
        var updatedSession = option.session
        var normalized = progress
        normalized.sessionID = updatedSession.id
        if normalized.isComplete {
            normalized.markCompleteIfNeeded()
        }
        updatedSession.auditionChecklist = normalized
        let earnedBadge = normalized.isComplete && !updatedSession.unlockedBadges.contains(.romanPhilosopher)
        if earnedBadge {
            updatedSession.unlockedBadges.append(.romanPhilosopher)
            normalized.achievementUnlocked = true
        }
        repository.updateSession(updatedSession, in: option.projectID)
        option.session = updatedSession
        selectedSession = option
        replaceOption(option)
        progress = normalized
        if earnedBadge {
            showingAchievement = true
        }
    }
    
    private func completeAndDismissAfterAchievement() {
        showingAchievement = false
    }
    
    private func selectSession(_ option: SessionOption?) {
        guard let option else {
            selectedSession = nil
            return
        }
        philosopherMode = false
        selectedSession = option
        progress = option.session.auditionChecklist ?? ChecklistProgress(sessionID: option.session.id)
    }
    
    private func replaceOption(_ option: SessionOption) {
        guard let idx = sessionOptions.firstIndex(where: { $0.id == option.id }) else { return }
        sessionOptions[idx] = option
    }
    
    private func reloadSessions() {
        let projects = repository.fetchProjects()
        sessionOptions = projects.flatMap { project in
            project.sessions
                .filter { !$0.isArchived }
                .map { SessionOption(projectID: project.id, projectTitle: project.title, session: $0) }
        }
        .sorted { $0.session.date > $1.session.date }
    }
    
    private func syncProgressWithBindingIfNeeded() {
        switch context {
        case .standalone:
            break
        case let .bound(projectID, sessionID):
            if let match = sessionOptions.first(where: { $0.projectID == projectID && $0.session.id == sessionID }) {
                selectedSession = match
                progress = match.session.auditionChecklist ?? ChecklistProgress(sessionID: sessionID)
            }
        }
    }
    
    private func activatePhilosopherMode() {
        philosopherMode = true
        selectedSession = nil
        progress = ChecklistProgress()
    }
    
    // MARK: - Computed Helpers
    private var progressLabel: String {
        if let option = selectedSession {
            return "\(option.session.type.rawValue) • \(option.projectTitle)"
        } else if philosopherMode {
            return "Philosopher Mode"
        } else {
            return "Select a session"
        }
    }
    
    private var progressPercentage: String {
        "\(Int(progress.completionFraction * 100))%"
    }
    
    private var primaryButtonTitle: String {
        if selectedSession != nil {
            return progress.isComplete ? "Checklist Complete!" : "Save Progress"
        } else if philosopherMode {
            return "Philosopher Mode Activated"
        } else {
            return "Select a Session"
        }
    }
    
    private var canRunPrimaryAction: Bool {
        selectedSession != nil || philosopherMode
    }
}

// MARK: - Supporting Views
private struct SessionSelectorView: View {
    let selectedSession: ActorMustKnowsView.SessionOption?
    let philosopherMode: Bool
    let onSelect: (ActorMustKnowsView.SessionOption?) -> Void
    let onPhilosopherMode: () -> Void
    let onShowPicker: () -> Void
    let sessionOptions: [ActorMustKnowsView.SessionOption]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Apply Checklist To")
                .font(.headline)
                .foregroundStyle(.white)
            
            Menu {
                if sessionOptions.isEmpty {
                    Text("No sessions available").foregroundStyle(.secondary)
                } else {
                    ForEach(sessionOptions) { option in
                        Button("\(option.projectTitle) — \(option.session.type.rawValue)") {
                            onSelect(option)
                        }
                    }
                }
                Divider()
                Button("+ New Session…") {
                    onShowPicker()
                }
                Button("No session yet — I'm more prepared than Seneca 😎") {
                    onPhilosopherMode()
                }
            } label: {
                HStack {
                    Text(selectedLabel)
                        .foregroundStyle(.white)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .foregroundStyle(.white.opacity(0.7))
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                )
            }
        }
    }
    
    private var selectedLabel: String {
        if let session = selectedSession {
            return "\(session.projectTitle) — \(session.session.type.rawValue)"
        } else if philosopherMode {
            return "Philosopher Mode"
        } else {
            return "Select session"
        }
    }
}

private struct ChecklistRow: View {
    let title: String
    let tip: String
    let reinforcement: String
    let icon: String
    let isChecked: Bool
    let mode: ActorMustKnowsMode
    let onToggle: () -> Void
    let onNavigate: (() -> Void)?
    let actionTitle: String
    let accent: Color
    
    var body: some View {
        STSCard {
            HStack(alignment: .top, spacing: 16) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(Theme.primary)
                    .frame(width: 32)
                    .padding(.top, 6)
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(Theme.Font.body.weight(.semibold))
                        .foregroundStyle(.white)
                    Text(tip)
                        .font(Theme.Font.body)
                        .foregroundStyle(.white.opacity(0.85))
                    Text(reinforcement)
                        .font(Theme.Font.caption)
                        .foregroundStyle(.white.opacity(0.6))
                    
                    if mode == .sessionBound, let onNavigate {
                        Button(action: onNavigate) {
                            Text(actionTitle)
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(accent.opacity(0.14), in: Capsule())
                                .overlay(
                                    Capsule()
                                        .stroke(accent.opacity(0.9), lineWidth: 1)
                                )
                                .foregroundStyle(accent)
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 4)
                    }
                }
                Spacer()
                Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isChecked ? .green : .white.opacity(0.3))
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onToggle()
        }
    }
}

private struct AchievementCelebrationView: View {
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "laurel.leading")
                .font(.system(size: 52))
                .foregroundStyle(.yellow)
            Text("🎖️ Achievement Unlocked")
                .font(.title2.bold())
                .foregroundStyle(.white)
            Text("Roman Philosopher badge added to this session. Luck favors the prepared.")
                .font(.body)
                .foregroundStyle(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Button("Nice!") {
                onDismiss()
            }
            .buttonStyle(.borderedProminent)
            .tint(.yellow)
        }
        .padding(28)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.black.opacity(0.85))
        )
    }
}

private struct PhilosopherToast: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "building.columns.fill")
                .font(.headline)
                .foregroundStyle(.white)
            VStack(alignment: .leading, spacing: 2) {
                Text("Philosopher Mode complete!")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Text("You're officially more prepared than Seneca. No session selected, badge not saved.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.black.opacity(0.75))
        )
    }
}

private struct ProjectPickerView: View {
    let projects: [Project]
    let onSelect: (Project) -> Void
    let onCancel: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Group {
                if projects.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "square.stack.3d.up.slash")
                            .font(.system(size: 48))
                            .foregroundStyle(.white.opacity(0.7))
                        Text("No projects yet")
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text("Create a project from ActorKit Home to attach this checklist to a session.")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(BrandBackground().ignoresSafeArea())
                } else {
                    List(projects) { project in
                        Button(project.title) {
                            onSelect(project)
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle("Choose Project")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        onCancel()
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Shared Status Card
struct AuditionChecklistStatusCard: View {
    let session: ProjectSession
    let contextTitle: String
    let onTap: () -> Void
    
    private var normalizedProgress: ChecklistProgress {
        if let stored = session.auditionChecklist {
            return stored
        }
        return ChecklistProgress(sessionID: session.id)
    }
    
    private var completedCount: Int {
        normalizedProgress.checks.filter { $0.value }.count
    }
    
    private var totalCount: Int {
        ChecklistProgress.Item.allCases.count
    }
    
    private var progressFraction: Double {
        normalizedProgress.completionFraction
    }
    
    private var percentageText: String {
        "\(Int(progressFraction * 100))%"
    }
    
    private var statusLine: String {
        if normalizedProgress.isComplete {
            return "Ritual complete — you're camera ready"
        } else {
            return "\(completedCount) of \(totalCount) rituals locked"
        }
    }
    
    private var ctaTitle: String {
        normalizedProgress.isComplete ? "Enter Studio Mode" : "Continue Prep"
    }
    
    private var highlightColor: Color {
        normalizedProgress.isComplete ? .green : Theme.primary
    }
    
    private var hasBadge: Bool {
        session.unlockedBadges.contains(.romanPhilosopher)
    }
    
    private var badgeText: String {
        "Roman Philosopher unlocked"
    }
    
    private var lastUpdatedText: String? {
        if let completedAt = normalizedProgress.completedAt {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .abbreviated
            return "Completed \(formatter.localizedString(for: completedAt, relativeTo: Date()))"
        }
        return nil
    }
    
    var body: some View {
        STSCard(elevation: .subtle, onTap: onTap) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 14) {
                    ChecklistProgressRing(
                        progress: progressFraction,
                        accent: highlightColor
                    ) {
                        Text(percentageText)
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Audition Checklist")
                            .font(Theme.Font.headline)
                            .foregroundStyle(.white)
                        
                        Text(contextTitle)
                            .font(Theme.Font.caption)
                            .foregroundStyle(.white.opacity(0.7))
                        
                        Text(statusLine)
                            .font(Theme.Font.body)
                            .foregroundStyle(.white.opacity(0.85))
                    }
                    Spacer()
                }
                
                if hasBadge {
                    Label(badgeText, systemImage: "laurel.leading")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.1), in: Capsule())
                        .foregroundStyle(.yellow)
                }
                
                if let lastUpdatedText {
                    Text(lastUpdatedText)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.6))
                }
                
                Text(ctaTitle)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(highlightColor.opacity(0.2))
                    )
                    .foregroundStyle(highlightColor)
            }
        }
    }
}

private struct ChecklistProgressRing<Content: View>: View {
    let progress: Double
    let accent: Color
    @ViewBuilder let label: Content
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.15), lineWidth: 8)
            Circle()
                .trim(from: 0, to: CGFloat(max(min(progress, 1.0), 0)))
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [accent, accent.opacity(0.7), accent]),
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            label
        }
        .frame(width: 68, height: 68)
    }
}

#Preview {
    ActorMustKnowsView(repository: ProjectsRepositoryFactory.makePreviewRepository())
}
