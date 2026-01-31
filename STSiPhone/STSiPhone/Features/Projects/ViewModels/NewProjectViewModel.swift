import Foundation
import Observation
import Combine

@Observable
public final class NewProjectViewModel {
    public var title: String = ""
    public var roleName: String = ""
    public var castingOffice: String = ""
    public var castingDirector: String = ""
    public var contactEmail: String = ""
    public var contactPhone: String = ""
    public var locationLabel: String = ""
    public var locationAddress: String = ""
    public var slateSelections: SlateSelections = SlateSelections()
    // NEW: Additional fields with audition due date
    public var projectType: String = "Feature"
    public var shootDate: Date = Date()
    public var auditionDueDate: Date = Date().addingTimeInterval(86400 * 3) // Default to 3 days from now
    public var numberOfScenes: Int = 1
    public var projectGenre: String = ""
    
    // CC/BCC tracking
    public var selectedRepID: UUID? = nil
    public var ccRepIDs: Set<UUID> = []
    public var bccRepIDs: Set<UUID> = []
    
    // HANGFIX: Debounced validation to prevent keystroke stalls
    private var cancellables = Set<AnyCancellable>()
    private let validateDebouncer = PassthroughSubject<Void, Never>()
    
    public init() {
        setupDebouncedValidation()
    }

    public static func makeForNewProject(
        calendar: Calendar = .current,
        now: Date = Date()
    ) -> NewProjectViewModel {
        let fresh = NewProjectViewModel()
        let dueBase = calendar.date(byAdding: .day, value: 3, to: now) ?? now
        var dueComponents = calendar.dateComponents([.year, .month, .day], from: dueBase)
        dueComponents.hour = 11
        dueComponents.minute = 0
        if let dueDate = calendar.date(from: dueComponents) {
            fresh.auditionDueDate = dueDate
        }
        if let shootBase = calendar.date(byAdding: .day, value: 14, to: now) {
            fresh.shootDate = shootBase
        }
        return fresh
    }

    public static func makeForEditing(project: Project) -> NewProjectViewModel {
        let configured = NewProjectViewModel()
        configured.apply(project: project)
        return configured
    }
    
    // HANGFIX: Setup debounced validation off keystroke path
    private func setupDebouncedValidation() {
        validateDebouncer
            .debounce(for: .milliseconds(200), scheduler: DispatchQueue.global(qos: .userInitiated))
            .sink { [weak self] in
                Task { @MainActor in
                    self?.validateFieldsBackground()
                }
            }
            .store(in: &cancellables)
    }
    
    // HANGFIX: Debounced validation triggers
    @MainActor
    public func onTitleChanged() {
        validateDebouncer.send()
    }
    
    @MainActor
    public func onRoleChanged() {
        validateDebouncer.send()
    }
    
    // HANGFIX: Heavy validation off main thread
    private func validateFieldsBackground() {
        // Do any expensive validation here off main thread
        // For now, just trigger UI updates if needed
        Task { @MainActor in
            // Force UI update for validation states
            // The @Observable properties will automatically trigger updates
        }
    }
    
    public var canProceedFromStep1: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !roleName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    // ENHANCED: Add validation for Step 2 (scenes selection)
    public var canProceedFromStep2: Bool {
        numberOfScenes >= 1 && numberOfScenes <= 10
    }
    
    // ENHANCED: Comprehensive validation for final step
    public var canProceedToRecording: Bool {
        canProceedFromStep1 && canProceedFromStep2
    }
    
    // ENHANCED: Date validation helpers
    public var isAuditionDueSoon: Bool {
        auditionDueDate.timeIntervalSinceNow < 86400 // Less than 24 hours
    }
    
    public var daysUntilAuditionDue: Int {
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: Date(), to: auditionDueDate).day ?? 0
        return max(0, days)
    }
    
    public func buildProject() -> Project {
        var project = Project(title: title.trimmingCharacters(in: .whitespacesAndNewlines))
        let role = Role(name: roleName.trimmingCharacters(in: .whitespacesAndNewlines))
        project.roles = [role]
        
        // ENHANCED: Set scene count in project with validation
        project.sceneCount = max(1, min(numberOfScenes, 10)) // Ensure valid range
        
        // CRITICAL FIX: Pass audition due date from wizard to project
        project.auditionDueDate = auditionDueDate
        project.projectType = projectType
        project.genre = projectGenre
        
        project.castingOffice = castingOffice.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : castingOffice.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if !castingDirector.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            project.castingDirector = Contact(
                name: castingDirector.trimmingCharacters(in: .whitespacesAndNewlines),
                email: contactEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : contactEmail.trimmingCharacters(in: .whitespacesAndNewlines),
                phone: contactPhone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : contactPhone.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }
        
        // Auto-create initial self-tape session with enhanced notes
        var sessions: [ProjectSession] = []
        
        let daysUntil = daysUntilAuditionDue
        let urgencyNote = daysUntil <= 1 ? " - DUE SOON!" : daysUntil <= 3 ? " - Due in \(daysUntil) days" : ""
        
        let trimmedLocation = locationLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAddress = locationAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        let locationInfo: LocationInfo? = trimmedLocation.isEmpty ? nil : LocationInfo(
            label: trimmedLocation,
            address: trimmedAddress.isEmpty ? nil : trimmedAddress
        )
        
        let initialSession = ProjectSession(
            type: .selfTape,
            location: locationInfo,
            notes: "Initial \(projectType.lowercased()) audition for \(numberOfScenes) scene\(numberOfScenes == 1 ? "" : "s")\(urgencyNote)"
        )
        sessions.append(initialSession)
        
        project.sessions = sessions
        
        return project
    }
    
    public func applySelectedRep(_ repInfo: RepInfo?) {
        guard let rep = repInfo else { return }
        print("🔄 NewProjectViewModel: Applying selected rep: \(rep.name)")
        
        // Representation metadata is informational; never overwrite casting details.
        if contactEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           let email = rep.email, !email.isEmpty {
            contactEmail = email
        }
        
        if contactPhone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           let phone = rep.phone, !phone.isEmpty {
            contactPhone = phone
        }
        
        if slateSelections.representation?.isEmpty ?? true {
            slateSelections.representation = rep.name
        }
    }
    
    // CC/BCC management
    public func toggleCC(repID: UUID) {
        if ccRepIDs.contains(repID) {
            ccRepIDs.remove(repID)
        } else {
            ccRepIDs.insert(repID)
        }
        print("🔄 CC reps: \(ccRepIDs.count)")
    }
    
    public func toggleBCC(repID: UUID) {
        if bccRepIDs.contains(repID) {
            bccRepIDs.remove(repID)
        } else {
            bccRepIDs.insert(repID)
        }
        print("🔄 BCC reps: \(bccRepIDs.count)")
    }
    
    public func isCCSelected(repID: UUID) -> Bool {
        ccRepIDs.contains(repID)
    }
    
    public func isBCCSelected(repID: UUID) -> Bool {
        bccRepIDs.contains(repID)
    }
    
    public func applyBreakdownFields(_ fields: BreakdownFields) {
        print("🔄 NewProjectViewModel: Applying breakdown fields")
        
        // Only apply fields if they're not already filled (don't overwrite user input)
        if let projectTitle = fields.projectTitle, !projectTitle.isEmpty,
           title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            title = projectTitle
            print("📋 Applied project title: \(projectTitle)")
        }
        
        if let roleName = fields.roleName, !roleName.isEmpty,
           self.roleName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            self.roleName = roleName
            print("🎭 Applied role name: \(roleName)")
        }
        
        if let castingOffice = fields.castingOffice, !castingOffice.isEmpty,
           self.castingOffice.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            self.castingOffice = castingOffice
            print("🏢 Applied casting office: \(castingOffice)")
        }
        
        if let castingDirector = fields.castingDirector, !castingDirector.isEmpty,
           self.castingDirector.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            self.castingDirector = castingDirector
            print("🎬 Applied casting director: \(castingDirector)")
        }
        
        if let contactEmail = fields.contactEmail, !contactEmail.isEmpty,
           self.contactEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            self.contactEmail = contactEmail
            print("📧 Applied contact email: \(contactEmail)")
        }
        
        if let contactPhone = fields.contactPhone, !contactPhone.isEmpty,
           self.contactPhone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            self.contactPhone = contactPhone
            print("📞 Applied contact phone: \(contactPhone)")
        }
        
        if let locationLabel = fields.locationLabel, !locationLabel.isEmpty,
           self.locationLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            self.locationLabel = locationLabel
            print("📍 Applied location label: \(locationLabel)")
        }
        
        if let locationAddress = fields.locationAddress, !locationAddress.isEmpty,
           self.locationAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            self.locationAddress = locationAddress
            print("🗺️ Applied location address: \(locationAddress)")
        }
    }

    public func reset() {
        title = ""
        roleName = ""
        castingOffice = ""
        castingDirector = ""
        contactEmail = ""
        contactPhone = ""
        locationLabel = ""
        locationAddress = ""
        slateSelections = SlateSelections()
        projectType = "Feature"
        shootDate = Date()
        auditionDueDate = Date().addingTimeInterval(86400 * 3)
        numberOfScenes = 1
        selectedRepID = nil
        projectGenre = ""
        ccRepIDs.removeAll()
        bccRepIDs.removeAll()
    }
    
    public func apply(project: Project) {
        title = project.title
        roleName = project.roles.first?.name ?? ""
        castingOffice = project.castingOffice ?? ""
        if let director = project.castingDirector {
            castingDirector = director.name
            contactEmail = director.email ?? ""
            contactPhone = director.phone ?? ""
        } else {
            castingDirector = ""
            contactEmail = ""
            contactPhone = ""
        }
        
        if let sessionLocation = project.sessions.compactMap({ $0.location }).first {
            locationLabel = sessionLocation.label
            locationAddress = sessionLocation.address ?? ""
        } else {
            locationLabel = ""
            locationAddress = ""
        }
        
        slateSelections = project.slateSelections
        projectType = project.projectType
        projectGenre = project.genre
        auditionDueDate = project.auditionDueDate ?? Date()
        shootDate = project.shootDate ?? Date()
        numberOfScenes = max(1, project.sceneCount)
    }
    
    // MARK: - Genre Data Structures
    public static func genresForProjectType(_ projectType: String) -> [String] {
        switch projectType {
        case "Feature":
            return ["Drama", "Comedy", "Action", "Horror", "Romance", "Sci-Fi", "Mystery", "Thriller"]
        case "Short Film":
            return ["Drama", "Comedy", "Horror", "Documentary", "Experimental", "Animation", "Romance", "Thriller"]
        case "Television":
            return ["Drama", "Comedy/Sitcom", "Procedural", "Reality", "Documentary", "Crime", "Thriller", "Medical"]
        case "Commercial":
            return ["Comedy", "Testimonial", "Product Demo", "Lifestyle", "Informational", "PSA", "Fashion/Beauty", "Automotive"]
        case "Web Series":
            return ["Drama", "Comedy", "Horror", "Mystery", "Documentary", "Sci-Fi", "Romance", "Action"]
        case "Theatre":
            return ["Musical", "Drama", "Comedy", "Tragedy", "Contemporary", "Classical", "Experimental", "Farce"]
        default:
            return ["Drama", "Comedy", "Action", "Horror", "Romance", "Sci-Fi", "Mystery", "Thriller"]
        }
    }
}
