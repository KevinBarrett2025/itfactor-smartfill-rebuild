import Foundation

@Observable
public class ProjectsViewModel {
    private let repo: ProjectsRepository
    private var allProjects: [Project] = []
    
    public init(repo: ProjectsRepository) {
        self.repo = repo
        reload()
    }
    
    // MARK: - Computed Properties
    
    /// Active (non-archived) projects for main view - sorted by most recent activity
    var projects: [Project] {
        allProjects
            .filter { !$0.isArchived }
            .sorted { project1, project2 in
                // Sort by most recent activity (latest session date, then creation date)
                let date1 = project1.sessions.map { $0.date }.max() ?? project1.createdAt
                let date2 = project2.sessions.map { $0.date }.max() ?? project2.createdAt
                return date1 > date2  // Most recent first
            }
    }
    
    /// Archived projects for archives view - also sorted by most recent activity
    var archivedProjects: [Project] {
        allProjects
            .filter { $0.isArchived }
            .sorted { project1, project2 in
                // Sort by most recent activity (latest session date, then creation date)
                let date1 = project1.sessions.map { $0.date }.max() ?? project1.createdAt
                let date2 = project2.sessions.map { $0.date }.max() ?? project2.createdAt
                return date1 > date2  // Most recent first
            }
    }
    
    /// All projects (for admin/debug purposes)
    var allProjectsIncludingArchived: [Project] {
        allProjects
    }
    
    // MARK: - Methods
    
    public func reload() {
        allProjects = repo.fetchProjects()
    }
    
    // Legacy compatibility methods
    public func addProject(_ project: Project) {
        repo.insert(project: project)
        reload()
    }
    
    public func refreshProjects() {
        reload()
    }
    
    public func deleteProject(_ project: Project) {
        repo.delete(project: project)
        reload()
    }
    
    public func toggleFavorite(_ project: Project) {
        repo.toggleFavorite(project: project)
        reload()
    }
    
    public func toggleArchive(_ project: Project) {
        repo.toggleArchive(project: project)
        reload()
    }
    
    public func toggleComplete(_ project: Project) {
        repo.toggleComplete(project: project)
        reload()
    }
    
    public func exportProject(_ project: Project) {
        repo.exportProject(project)
    }

    // MARK: - Archive helpers (typed APIs)
    @MainActor
    public func archiveProject(_ project: Project, request: ArchiveRequest) async {
        do {
            try await repo.archiveProject(projectID: project.id, request: request)
            reload()
        } catch {
            print("❌ ProjectsViewModel: archiveProject failed - \(error)")
        }
    }

    @MainActor
    public func unarchiveProject(_ project: Project) async {
        do {
            try await repo.unarchiveProject(projectID: project.id)
            reload()
        } catch {
            print("❌ ProjectsViewModel: unarchiveProject failed - \(error)")
        }
    }

    @MainActor
    public func unarchiveAllProjects() async {
        do {
            try await repo.unarchiveAllProjects()
            reload()
        } catch {
            print("❌ ProjectsViewModel: unarchiveAllProjects failed - \(error)")
        }
    }
}
