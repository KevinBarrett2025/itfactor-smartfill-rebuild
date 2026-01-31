import SwiftUI

private let sessionCreationComingSoon = true

public struct NewSessionWizard: View {
    // Inputs
    let projectID: UUID
    let repo: ProjectsRepository
    let onComplete: (ProjectSession?) -> Void
    let presentChecklistOnFinish: Bool

    // Env
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager

    // State
    @State private var project: Project?
    @State private var currentStep: WizardStep = .type
    @State private var selectedType: SessionType? = .selfTape

    // Overrides
    @State private var dueDateOverrideEnabled = false
    @State private var dueDateOverride = Date()

    @State private var sidesOverrideEnabled = false
    @State private var sidesFileName = ""

    @State private var breakdownOverrideEnabled = false
    @State private var breakdownFileName = ""
    @State private var breakdownNotes = ""

    @State private var roleOverrideEnabled = false
    @State private var roleName = ""

    @State private var headshotOverrideEnabled = false
    @State private var headshotIDText = ""

    @State private var sceneCountOverrideEnabled = false
    @State private var sceneCountOverride = 1

    @State private var slateOverrideEnabled = false
    @State private var slatePrompt = ""
    @State private var slateSelectionsOverride: SlateSelections?

    // Session-specific fields
    @State private var sessionDate: Date = Date()
    @State private var locationLabel: String = ""
    @State private var inPersonStreet1: String = ""
    @State private var inPersonStreet2: String = ""
    @State private var inPersonCity: String = ""
    @State private var inPersonState: String = ""
    @State private var inPersonPostal: String = ""
    @State private var inPersonCountry: String = ""
    @State private var inPersonCastingPhone: String = ""
    @State private var inPersonRepPhone: String = ""
    @State private var inPersonRawPaste: String = ""
    @State private var parkingInfo: String = ""
    @State private var notes: String = ""

    // Callback reflection (session-specific)
    @State private var callbackReflection: String = ""
    @State private var callbackIntent: String = ""

    // Calendar feedback
    @State private var showingCalendarResult = false
    @State private var calendarMessage: String = ""

    // Checklist handoff
    @State private var createdSession: ProjectSession?
    @State private var showingActorMustKnows = false

    @State private var seededDefaults = false

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

    private var availableTypes: [SessionType] {
        SessionType.allCases.filter { $0 != .chemistryRead }
    }

    public init(
        projectID: UUID,
        repo: ProjectsRepository,
        presentChecklistOnFinish: Bool = true,
        onComplete: @escaping (ProjectSession?) -> Void
    ) {
        self.projectID = projectID
        self.repo = repo
        self.presentChecklistOnFinish = presentChecklistOnFinish
        self.onComplete = onComplete
        if let initialProject = repo.project(by: projectID) {
            _project = State(initialValue: initialProject)
            _sceneCountOverride = State(initialValue: max(1, initialProject.sceneCount))
            _dueDateOverride = State(initialValue: initialProject.auditionDueDate ?? Date())
            _slateSelectionsOverride = State(initialValue: initialProject.slateSelections)
        } else {
            _project = State(initialValue: nil)
        }
    }

    public var body: some View {
        if sessionCreationComingSoon {
            VStack(spacing: 24) {
                Image(systemName: "hammer")
                    .font(.system(size: 54))
                    .foregroundColor(.yellow)
                Text("Session Creation Coming Soon")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
                Text("We're working to support per-session overrides and additional features. This feature will be available in an upcoming update.")
                    .foregroundStyle(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
                Button {
                    dismiss()
                } label: {
                    Label("OK, got it", systemImage: "checkmark")
                        .font(.headline)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 14)
                        .background(Color.white.opacity(0.12), in: Capsule())
                }
                .buttonStyle(.plain)
                .padding(.top, 10)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black.opacity(0.85).ignoresSafeArea())
        } else {
            NavigationStack {
                ZStack {
                    theme.backgroundGradient.ignoresSafeArea()
                    accentGlow

                    VStack(spacing: 0) {
                        progressIndicator
                        ScrollView {
                            VStack(spacing: 20) {
                                stepContent(for: currentStep)
                            }
                            .padding(.horizontal, 24)
                            .padding(.vertical, 24)
                        }
                        navigationControls
                    }
                }
                .navigationTitle("New Session")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        if currentStep != .type {
                            Button {
                                goBack()
                            } label: {
                                Image(systemName: "chevron.left")
                                    .font(.title2)
                                    .foregroundStyle(Theme.textPrimary)
                            }
                        }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Cancel") { dismiss() }
                            .foregroundStyle(Theme.textPrimary)
                    }
                }
                .onAppear {
                    seedDefaultsIfNeeded()
                }
                .sheet(isPresented: $showingActorMustKnows) {
                    if let session = createdSession, let project {
                        ActorMustKnowsView(
                            project: project,
                            session: session,
                            repository: repo,
                            onComplete: {
                                showingActorMustKnows = false
                                createdSession = nil
                            }
                        )
                    }
                }
            }
        }
    }

    // MARK: - Steps
    private func stepContent(for step: WizardStep) -> some View {
        Group {
            switch step {
            case .type: typeStep
            case .dueDate: dueDateStep
            case .docs: docsStep
            case .role: roleStep
            case .headshot: headshotStep
            case .sceneCount: sceneCountStep
            case .slate: slateStep
            case .conditional: conditionalStep
            case .review: reviewStep
            }
        }
    }

    private var typeStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Session Type")
                .font(Theme.Font.title)
                .foregroundStyle(Theme.textPrimary)
            Text("Pick the session type. Chemistry Read stays hidden from new sessions.")
                .font(Theme.Font.body)
                .foregroundStyle(.secondary)

            ForEach(availableTypes, id: \.self) { type in
                Button {
                    selectedType = type
                } label: {
                    STSCard {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(type.displayTitle)
                                    .font(Theme.Font.headline)
                                    .foregroundStyle(Theme.textPrimary)
                                Text(type.summary)
                                    .font(Theme.Font.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: selectedType == type ? "checkmark.circle.fill" : "circle")
                                .font(.title2)
                                .foregroundStyle(selectedType == type ? theme.primaryAccent : .gray)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var dueDateStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Submission Window")
                .font(Theme.Font.title)
                .foregroundStyle(Theme.textPrimary)
            ToggleOverrideRow(
                title: dueDateOverrideEnabled ? "Using session due date" : "Use project due date",
                subtitle: project?.auditionDueDate.map { "Project: \($0.formatted(date: .abbreviated, time: .omitted))" } ?? "Project: none set",
                isOn: $dueDateOverrideEnabled
            )
            if dueDateOverrideEnabled {
                DatePicker("Due by", selection: $dueDateOverride, displayedComponents: [.date, .hourAndMinute])
                    .datePickerStyle(.graphical)
            }
        }
    }

    private var docsStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Sides & Breakdown")
                .font(Theme.Font.title)
                .foregroundStyle(Theme.textPrimary)

            // Sides
            STSCard {
                VStack(alignment: .leading, spacing: 10) {
                    ToggleOverrideRow(
                        title: "Sides",
                        subtitle: sidesOverrideEnabled ? "Session sides" : "Using project sides",
                        isOn: $sidesOverrideEnabled
                    )
                    if sidesOverrideEnabled {
                        TextField("Sides file name", text: $sidesFileName)
                            .textFieldStyle(.roundedBorder)
                    } else if let projectSides = project?.sidesFileName {
                        Text("Project: \(projectSides)")
                            .font(Theme.Font.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("No project sides set")
                            .font(Theme.Font.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // Breakdown
            STSCard {
                VStack(alignment: .leading, spacing: 10) {
                    ToggleOverrideRow(
                        title: "Breakdown",
                        subtitle: breakdownOverrideEnabled ? "Session breakdown" : "Using project breakdown",
                        isOn: $breakdownOverrideEnabled
                    )
                    if breakdownOverrideEnabled {
                        TextField("Breakdown file name", text: $breakdownFileName)
                            .textFieldStyle(.roundedBorder)
                        TextField("Breakdown notes", text: $breakdownNotes, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(2...4)
                    } else {
                        if let projectBreakdown = project?.breakdownFileName {
                            Text("Project file: \(projectBreakdown)")
                                .font(Theme.Font.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("No project breakdown set")
                                .font(Theme.Font.caption)
                                .foregroundStyle(.secondary)
                        }
                        if let notes = project?.breakdownNotes, !notes.isEmpty {
                            Text("Project notes: \(notes)")
                                .font(Theme.Font.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    private var roleStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Role")
                .font(Theme.Font.title)
                .foregroundStyle(Theme.textPrimary)
            ToggleOverrideRow(
                title: "Role name",
                subtitle: roleOverrideEnabled ? "Session role" : "Using project role",
                isOn: $roleOverrideEnabled
            )
            if roleOverrideEnabled {
                TextField("Role name", text: $roleName)
                    .textFieldStyle(.roundedBorder)
            } else if let projectRole = project?.roles.first?.name, !projectRole.isEmpty {
                Text("Project: \(projectRole)")
                    .font(Theme.Font.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("No project role set")
                    .font(Theme.Font.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var headshotStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Submitted Headshot")
                .font(Theme.Font.title)
                .foregroundStyle(Theme.textPrimary)
            ToggleOverrideRow(
                title: "Headshot",
                subtitle: headshotOverrideEnabled ? "Session headshot" : "Using project headshot",
                isOn: $headshotOverrideEnabled
            )
            if headshotOverrideEnabled {
                TextField("Headshot UUID", text: $headshotIDText)
                    .textFieldStyle(.roundedBorder)
            } else if let projectHeadshot = project?.submittedHeadshotID {
                Text("Project headshot: \(projectHeadshot.uuidString)")
                    .font(Theme.Font.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("No project headshot set")
                    .font(Theme.Font.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var sceneCountStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Scene Count")
                .font(Theme.Font.title)
                .foregroundStyle(Theme.textPrimary)
            ToggleOverrideRow(
                title: "Scene count",
                subtitle: sceneCountOverrideEnabled ? "Session override" : "Using project count",
                isOn: $sceneCountOverrideEnabled
            )
            HStack {
                if sceneCountOverrideEnabled {
                    Stepper(value: $sceneCountOverride, in: 1...30) {
                        Text("\(sceneCountOverride) scene\(sceneCountOverride == 1 ? "" : "s")")
                    }
                } else {
                    let projectCount = project?.sceneCount ?? 1
                    Text("Project: \(projectCount) scene\(projectCount == 1 ? "" : "s")")
                        .font(Theme.Font.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.vertical, 4)
        }
    }

    private var slateStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Slate Details")
                .font(Theme.Font.title)
                .foregroundStyle(Theme.textPrimary)
            ToggleOverrideRow(
                title: "Slate selections",
                subtitle: slateOverrideEnabled ? "Session slate settings" : "Using project slate settings",
                isOn: $slateOverrideEnabled
            )
            if slateOverrideEnabled {
                Text("Using project slate selections as starting point. (Advanced editing to be added.)")
                    .font(Theme.Font.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Project slate will be used.")
                    .font(Theme.Font.caption)
                    .foregroundStyle(.secondary)
            }

            Text("Slate prompt (optional)")
                .font(Theme.Font.headline)
                .foregroundStyle(Theme.textPrimary)
            TextField("e.g., Name, Role, Representation", text: $slatePrompt, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(2...4)
        }
    }

    private var conditionalStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Session Specifics")
                .font(Theme.Font.title)
                .foregroundStyle(Theme.textPrimary)

            switch selectedType ?? .selfTape {
            case .callback:
                STSCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Callback Reflection")
                            .font(Theme.Font.headline)
                        TextField("What landed the callback?", text: $callbackReflection, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(2...4)
                        TextField("Mood/energy to recreate", text: $callbackIntent, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(2...4)
                        TextField("Session notes (optional)", text: $notes, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(2...4)
                    }
                }
            case .inPerson:
                STSCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("In-Person Logistics")
                            .font(Theme.Font.headline)
                        TextField("Venue/Office name", text: $locationLabel)
                            .textFieldStyle(.roundedBorder)
                        Text("Paste a full address into Street to auto-fill the fields.")
                            .font(Theme.Font.caption)
                            .foregroundStyle(.secondary)
                        TextField("Street", text: $inPersonStreet1)
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: inPersonStreet1) { oldValue, newValue in
                                handleStreet1Change(oldValue: oldValue, newValue: newValue)
                            }
                        TextField("Apt / Suite (optional)", text: $inPersonStreet2)
                            .textFieldStyle(.roundedBorder)
                        HStack {
                            TextField("City", text: $inPersonCity)
                                .textFieldStyle(.roundedBorder)
                            TextField("State / Province", text: $inPersonState)
                                .textFieldStyle(.roundedBorder)
                        }
                        HStack {
                            TextField("Postal", text: $inPersonPostal)
                                .textFieldStyle(.roundedBorder)
                            TextField("Country", text: $inPersonCountry)
                                .textFieldStyle(.roundedBorder)
                        }
                        TextField("Casting phone (optional)", text: $inPersonCastingPhone)
                            .textFieldStyle(.roundedBorder)
                            .textContentType(.telephoneNumber)
                            .keyboardType(.phonePad)
                        TextField("Rep phone (optional)", text: $inPersonRepPhone)
                            .textFieldStyle(.roundedBorder)
                            .textContentType(.telephoneNumber)
                            .keyboardType(.phonePad)
                        TextField("Parking notes", text: $parkingInfo, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(2...4)
                        DatePicker("Appointment", selection: $sessionDate, displayedComponents: [.date, .hourAndMinute])
                            .datePickerStyle(.compact)
                        TextField("Session notes (optional)", text: $notes, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(2...4)
                    }
                }
            default:
                STSCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("No extra details needed.")
                            .font(Theme.Font.body)
                            .foregroundStyle(.secondary)
                        TextField("Session notes (optional)", text: $notes, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(2...4)
                    }
                }
            }
        }
    }

    private var reviewStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Review Session")
                .font(Theme.Font.title)
                .foregroundStyle(Theme.textPrimary)
            if let project {
                let session = buildSession(commit: false)
                let ctx = EffectiveSessionContext(project: project, session: session)
                ReviewGrid(context: ctx)
            } else {
                Text("Project not found.")
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Navigation
    private var navigationControls: some View {
        VStack {
            BrandedPrimaryButton(
                label: currentStep == .review ? "Create Session" : "Continue",
                icon: currentStep == .review ? "checkmark.circle.fill" : "chevron.right"
            ) {
                if currentStep == .review {
                    saveSession()
                } else {
                    goForward()
                }
            }
            .disabled(!canProceed)
        }
        .padding(.bottom, 34)
    }

    private var canProceed: Bool {
        switch currentStep {
        case .type:
            return selectedType != nil
        case .conditional:
            if selectedType == .inPerson {
                return hasInPersonAddress
            }
            return true
        default:
            return true
        }
    }

    private func goForward() {
        if let next = WizardStep.next(after: currentStep) {
            currentStep = next
        }
    }

    private func goBack() {
        if let prev = WizardStep.previous(before: currentStep) {
            currentStep = prev
        }
    }

    // MARK: - Build + Save
    private func buildSession(commit: Bool) -> ProjectSession {
        let sessionType = selectedType ?? .selfTape
        let dateForSession = (sessionType == .inPerson) ? sessionDate : Date()

        var location: LocationInfo?
        if sessionType == .inPerson {
            let addressString = formattedInPersonAddress()
            if !locationLabel.isEmpty || !addressString.isEmpty {
                location = LocationInfo(
                    label: locationLabel.isEmpty ? "Location" : locationLabel,
                    address: addressString.isEmpty ? nil : addressString
                )
            }
        }

        var callbackNotesCombined: String?
        if sessionType == .callback {
            var parts: [String] = []
            if !callbackReflection.isEmpty { parts.append("Callback Reflection: \(callbackReflection)") }
            if !callbackIntent.isEmpty { parts.append("Booking Intention: \(callbackIntent)") }
            callbackNotesCombined = parts.joined(separator: "\n")
        }

        let headshotUUID = headshotOverrideEnabled ? UUID(uuidString: headshotIDText) : nil
        let slateOverrideValue = slateOverrideEnabled ? (slateSelectionsOverride ?? project?.slateSelections) : nil
        let trimmedSlatePrompt = slatePrompt.nonEmpty
        let slatePromptMode: SlatePromptMode = trimmedSlatePrompt == nil ? .auto : .custom
        let slatePromptUpdatedAt = trimmedSlatePrompt == nil ? nil : Date()

        var session = ProjectSession(
            type: sessionType,
            date: dateForSession,
            location: location,
            contact: nil,
            notes: notes.isEmpty ? nil : notes,
            takes: [],
            roleName: roleOverrideEnabled ? roleName.nonEmpty : nil,
            callbackNotes: callbackNotesCombined,
            parkingInfo: (sessionType == .inPerson) ? parkingInfo.nonEmpty : nil,
            isFavorite: false,
            isArchived: false,
            primaryOrientation: nil,
            smartFillEnabled: nil,
            slatePrompt: trimmedSlatePrompt,
            slatePromptMode: slatePromptMode,
            slatePromptOverride: trimmedSlatePrompt,
            slatePromptUpdatedAt: slatePromptUpdatedAt,
            sidesFileName: sidesOverrideEnabled ? sidesFileName.nonEmpty : nil,
            breakdownFileName: breakdownOverrideEnabled ? breakdownFileName.nonEmpty : nil,
            breakdownNotes: breakdownOverrideEnabled ? breakdownNotes.nonEmpty : nil,
            pipSlateSession: nil,
            auditionDueDateOverride: dueDateOverrideEnabled ? dueDateOverride : nil,
            sceneCountOverride: sceneCountOverrideEnabled ? max(1, sceneCountOverride) : nil,
            submittedHeadshotIDOverride: headshotUUID,
            slateSelectionsOverride: slateOverrideValue
        )

        if sessionType == .inPerson {
            if hasInPersonAddress {
                session.inPersonAddress = InPersonAddress(
                    street1: inPersonStreet1,
                    street2: inPersonStreet2,
                    city: inPersonCity,
                    state: inPersonState,
                    postalCode: inPersonPostal,
                    country: inPersonCountry
                )
            }
            session.inPersonAddressRawPaste = inPersonRawPaste.nonEmpty
            session.castingPhone = inPersonCastingPhone.nonEmpty
            session.repPhone = inPersonRepPhone.nonEmpty
        }

        return session
    }

    private func saveSession() {
        guard let project else { return }
        let session = buildSession(commit: true)
        repo.append(session: session, to: project.id)

        if session.type == .inPerson {
            addCalendarEvent(for: session, project: project)
        }

        if presentChecklistOnFinish {
            createdSession = session
            showingActorMustKnows = true
        }

        onComplete(session)
        dismiss()
    }

    private func addCalendarEvent(for session: ProjectSession, project: Project) {
        CalendarHelper.addAuditionEvent(
            projectTitle: project.title,
            roleName: session.roleName ?? project.roles.first?.name,
            sessionType: session.type,
            date: session.date,
            location: session.location?.label,
            address: session.location?.address,
            parkingInfo: session.parkingInfo
        ) { success, message in
            calendarMessage = message ?? (success ? "Event added to calendar" : "Failed to add calendar event")
            showingCalendarResult = true
        }
    }

    // MARK: - Helpers
    private var hasInPersonAddress: Bool {
        [
            inPersonStreet1,
            inPersonStreet2,
            inPersonCity,
            inPersonState,
            inPersonPostal,
            inPersonCountry
        ]
        .contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    private func formattedInPersonAddress() -> String {
        let trimmed: (String) -> String = { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        var lines: [String] = []
        if !trimmed(inPersonStreet1).isEmpty { lines.append(trimmed(inPersonStreet1)) }
        if !trimmed(inPersonStreet2).isEmpty { lines.append(trimmed(inPersonStreet2)) }

        var cityLine: [String] = []
        if !trimmed(inPersonCity).isEmpty { cityLine.append(trimmed(inPersonCity)) }
        if !trimmed(inPersonState).isEmpty { cityLine.append(trimmed(inPersonState)) }
        if !trimmed(inPersonPostal).isEmpty { cityLine.append(trimmed(inPersonPostal)) }
        if !cityLine.isEmpty { lines.append(cityLine.joined(separator: ", ")) }

        if !trimmed(inPersonCountry).isEmpty { lines.append(trimmed(inPersonCountry)) }
        return lines.joined(separator: ", ")
    }

    private func handleStreet1Change(oldValue: String, newValue: String) {
        guard inPersonCity.isEmpty, inPersonState.isEmpty, inPersonPostal.isEmpty, inPersonCountry.isEmpty else { return }
        let addedLength = newValue.count - oldValue.count
        if newValue.contains(",") || addedLength >= 10 {
            let parsed = AddressParsingService.parse(newValue)
            applyParsedAddress(parsed, raw: newValue)
        }
    }

    private func applyParsedAddress(_ parsed: InPersonAddress, raw: String) {
        inPersonStreet1 = parsed.street1
        inPersonStreet2 = parsed.street2
        inPersonCity = parsed.city
        inPersonState = parsed.state
        inPersonPostal = parsed.postalCode
        inPersonCountry = parsed.country
        inPersonRawPaste = raw
    }

    private var progressIndicator: some View {
        let total = WizardStep.allCases.count
        let index = WizardStep.allCases.firstIndex(of: currentStep) ?? 0
        return HStack(spacing: 8) {
            ForEach(0..<total, id: \.self) { i in
                Capsule()
                    .fill(i <= index ? theme.primaryAccent : theme.cardStroke)
                    .frame(width: i == index ? 36 : 18, height: 8)
                    .animation(.easeInOut(duration: 0.2), value: index)
            }
        }
        .padding(.vertical, 14)
    }

    private func seedDefaultsIfNeeded() {
        guard !seededDefaults, let project else { return }
        seededDefaults = true
        if let due = project.auditionDueDate {
            dueDateOverride = due
        }
        sceneCountOverride = max(1, project.sceneCount)
        slateSelectionsOverride = project.slateSelections
        slatePrompt = ""
        sidesFileName = project.sidesFileName ?? ""
        breakdownFileName = project.breakdownFileName ?? ""
        breakdownNotes = project.breakdownNotes ?? ""
        roleName = project.roles.first?.name ?? ""
        headshotIDText = project.submittedHeadshotID?.uuidString ?? ""
        if selectedType == nil { selectedType = .selfTape }
    }
}

// MARK: - Wizard Step Enum
private enum WizardStep: Int, CaseIterable {
    case type, dueDate, docs, role, headshot, sceneCount, slate, conditional, review

    static func next(after step: WizardStep) -> WizardStep? {
        guard let idx = allCases.firstIndex(of: step), idx + 1 < allCases.count else { return nil }
        return allCases[idx + 1]
    }

    static func previous(before step: WizardStep) -> WizardStep? {
        guard let idx = allCases.firstIndex(of: step), idx > 0 else { return nil }
        return allCases[idx - 1]
    }
}

// MARK: - Review Grid
private struct ReviewGrid: View {
    let context: EffectiveSessionContext

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            reviewRow("Type", value: context.effective.sessionType.rawValue)
            reviewRow("Due by", value: context.effective.auditionDueDate.value?.formatted(date: .abbreviated, time: .shortened) ?? "Not set", origin: context.effective.auditionDueDate.origin)
            reviewRow("Sides", value: context.effective.sidesFileName.value ?? "Not set", origin: context.effective.sidesFileName.origin)
            reviewRow("Breakdown", value: context.effective.breakdownFileName.value ?? "Not set", origin: context.effective.breakdownFileName.origin)
            reviewRow("Breakdown notes", value: context.effective.breakdownNotes.value ?? "None", origin: context.effective.breakdownNotes.origin)
            reviewRow("Role", value: context.effective.roleName.value ?? "Not set", origin: context.effective.roleName.origin)
            reviewRow("Headshot", value: context.effective.submittedHeadshotID.value?.uuidString ?? "Not set", origin: context.effective.submittedHeadshotID.origin)
            reviewRow("Scene count", value: "\(context.effective.sceneCount.value)", origin: context.effective.sceneCount.origin)
            reviewRow("Slate prompt", value: context.effective.slatePrompt.value ?? "None", origin: context.effective.slatePrompt.origin)
            reviewRow("Slate selections", value: slateSelectionsSummary(context.effective.slateSelections.value), origin: context.effective.slateSelections.origin)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Theme.surface.opacity(0.35), in: RoundedRectangle(cornerRadius: 12))
    }

    private func reviewRow(_ title: String, value: String, origin: ValueOrigin? = nil) -> some View {
        HStack(alignment: .top) {
            Text(title)
                .font(Theme.Font.caption)
                .foregroundStyle(.secondary)
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(value)
                    .font(Theme.Font.body)
                    .foregroundStyle(Theme.textPrimary)
                if let origin {
                    OriginChip(origin: origin)
                }
            }
        }
    }

    private func slateSelectionsSummary(_ selections: SlateSelections) -> String {
        var tokens = selections.include.map { $0.rawValue }
        if selections.includePassport, selections.hasValidPassport == true {
            tokens.append("passport")
        }
        if selections.includeCitizenship,
           selections.isLegalCitizen == true,
           selections.citizenshipCountry?.slateTrimmedNonEmpty != nil {
            tokens.append("citizenship")
        }
        if tokens.isEmpty { return "None" }
        return tokens.joined(separator: ", ")
    }
}

private struct OriginChip: View {
    let origin: ValueOrigin
    var body: some View {
        Text(originLabel)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(chipColor.opacity(0.15))
            .foregroundStyle(chipColor)
            .clipShape(Capsule())
    }
    private var originLabel: String {
        switch origin {
        case .sessionOverride: return "Session override"
        case .sessionValue: return "Session"
        case .projectValue: return "Project"
        case .defaultValue: return "Default"
        }
    }
    private var chipColor: Color {
        switch origin {
        case .sessionOverride: return .orange
        case .sessionValue: return .blue
        case .projectValue: return .green
        case .defaultValue: return .gray
        }
    }
}

// MARK: - Toggle Row
private struct ToggleOverrideRow: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Theme.Font.headline)
                Text(subtitle)
                    .font(Theme.Font.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Toggle("", isOn: $isOn)
                .labelsHidden()
        }
    }
}

private extension SessionType {
    var displayTitle: String {
        switch self {
        case .selfTape: return "Additional Self-Tape"
        case .callback: return "Callback (Congrats!)"
        case .inPerson: return "In-Person Audition"
        case .chemistryRead: return "Chemistry Read"
        }
    }

    var summary: String {
        switch self {
        case .selfTape: return "Create an add-on self-tape session."
        case .callback: return "Recreate what worked and book it."
        case .inPerson: return "Capture appointment details to arrive prepared."
        case .chemistryRead: return "Legacy only (hidden)."
        }
    }
}

private extension String {
    var nonEmpty: String? {
        self.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : self
    }
}
