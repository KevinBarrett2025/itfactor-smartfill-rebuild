import Foundation
import Observation

@Observable
public class ProjectDetailViewModel {
    public private(set) var project: Project?
    public let projectID: UUID
    public let repo: ProjectsRepository
    
    public init(projectID: UUID, repo: ProjectsRepository) {
        self.projectID = projectID
        self.repo = repo
        self.project = repo.project(by: projectID)
    }
    
    public func reload() {
        project = repo.project(by: projectID)
    }
    
    // MARK: - Computed Properties
    
    /// Active (non-archived) sessions for main project view
    var groupedSessions: [(SessionType, [ProjectSession])] {
        guard let project = project else { return [] }
        
        let activeSessions = project.sessions.filter { !$0.isArchived }
        let grouped = Dictionary(grouping: activeSessions) { $0.type }
        let sortedKeys = SessionType.allCases.filter { grouped[$0] != nil }
        
        return sortedKeys.map { type in
            let sessions = grouped[type] ?? []
            return (type, sessions.sorted { $0.date > $1.date })
        }
    }
    
    /// Archived sessions for archives view
    var archivedSessions: [ProjectSession] {
        guard let project = project else { return [] }
        return project.sessions.filter { $0.isArchived }.sorted { $0.date > $1.date }
    }
    
    // MARK: - Session Actions
    func archiveSession(_ session: ProjectSession) {
        Task { await archiveSession(session, request: .default) }
    }
    
    func unarchiveSession(_ session: ProjectSession) {
        Task { await unarchiveSession(session) }
    }
    
    func toggleSessionFavorite(_ session: ProjectSession) {
        repo.toggleSessionFavorite(sessionID: session.id, in: projectID)
        reload()
    }
    
    func duplicateSession(_ session: ProjectSession) {
        repo.duplicateSession(sessionID: session.id, in: projectID)
        reload()
    }

    // MARK: - Archive (typed APIs)
    @MainActor
    func archiveProject(request: ArchiveRequest) async {
        do {
            try await repo.archiveProject(projectID: projectID, request: request)
            reload()
        } catch {
            print("❌ ProjectDetailViewModel: archiveProject failed - \(error)")
        }
    }

    @MainActor
    func unarchiveProject() async {
        do {
            try await repo.unarchiveProject(projectID: projectID)
            reload()
        } catch {
            print("❌ ProjectDetailViewModel: unarchiveProject failed - \(error)")
        }
    }

    @MainActor
    func archiveSession(_ session: ProjectSession, request: ArchiveRequest) async {
        do {
            try await repo.archiveSession(projectID: projectID, sessionID: session.id, request: request)
            reload()
        } catch {
            print("❌ ProjectDetailViewModel: archiveSession failed - \(error)")
        }
    }

    @MainActor
    func unarchiveSession(_ session: ProjectSession) async {
        do {
            try await repo.unarchiveSession(projectID: projectID, sessionID: session.id)
            reload()
        } catch {
            print("❌ ProjectDetailViewModel: unarchiveSession failed - \(error)")
        }
    }

    func exportSession(_ session: ProjectSession) {
        repo.exportSession(sessionID: session.id, from: projectID)
    }
    
    func deleteSession(_ session: ProjectSession) {
        repo.deleteSession(sessionID: session.id, from: projectID)
        reload()
    }
    
    // MARK: - Take Actions
    func playTake(_ take: ProjectTake) {
        // TODO: Implement video playback
        print("🎬 Playing take: \(take.filePath)")
    }
    
    func markTakeAsBest(_ take: ProjectTake, in session: ProjectSession) {
        // CLEANED: Use unified rating system instead of boolean manipulation
        let newRating: TakeRating = take.isBest ? .unrated : .finalSelect
        SessionManager.shared.setRating(
            newRating,
            for: take.id,
            sessionID: session.id,
            projectID: projectID,
            source: "ProjectDetailViewModel.markTakeAsBest"
        )
        
        reload()
        print("⭐ Marked take as final select using unified rating system")
    }
    
    func toggleTakeFavorite(_ take: ProjectTake) {
        // Need to find which session this take belongs to
        if let session = project?.sessions.first(where: { $0.takes.contains(where: { $0.id == take.id }) }) {
            repo.toggleTakeFavorite(takeID: take.id, in: session.id, of: projectID)
            reload()
        }
    }
    
    func showTakeNoteEditor(for take: ProjectTake) {
        // TODO: Show note editor modal
        print("📝 Show note editor for take: \(take.filePath)")
    }
    
    func exportTake(_ take: ProjectTake) {
        if let session = project?.sessions.first(where: { $0.takes.contains(where: { $0.id == take.id }) }) {
            repo.exportTake(takeID: take.id, from: session.id, in: projectID)
        }
    }
    
    func deleteTake(_ take: ProjectTake, from session: ProjectSession) {
        repo.deleteTake(takeID: take.id, from: session.id, in: projectID)
        reload()
    }
    
    // Use the session manager's unified rating setter
    func setUnifiedTakeRating(_ take: ProjectTake, in session: ProjectSession, to rating: TakeRating) {
        SessionManager.shared.setRating(
            rating,
            for: take.id,
            sessionID: session.id,
            projectID: projectID,
            source: "ProjectDetailViewModel.setUnifiedTakeRating"
        )
        reload()
    }
}
