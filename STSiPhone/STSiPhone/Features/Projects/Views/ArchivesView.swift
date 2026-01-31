import SwiftUI

public struct ArchivesView: View {
    @State private var projectsVM: ProjectsViewModel
    private let repo: ProjectsRepository
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
    
    public init(repo: ProjectsRepository) {
        self.repo = repo
        _projectsVM = State(initialValue: ProjectsViewModel(repo: repo))
    }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                theme.backgroundGradient
                    .ignoresSafeArea()
                accentGlow
                
                if projectsVM.archivedProjects.isEmpty {
                    EmptyStateView(
                        title: "No Archived Items", 
                        message: "Archived projects will appear here."
                    )
                } else {
                    List {
                        archivedProjectsSection
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .padding(.top)
                }
            }
        .navigationTitle("Archives")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Clear All") {
                        showingClearAllConfirmation = true
                    }
                    .foregroundStyle(.red)
                }
            }
            .onAppear {
                projectsVM.reload()
            }
        }
        .alert("Restore all archived projects?", isPresented: $showingClearAllConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Restore All") {
                Task { await projectsVM.unarchiveAllProjects() }
            }
        } message: {
            Text("This moves all archived projects back to Active Projects.")
        }
    }
    
    @State private var showingClearAllConfirmation = false
    
    @ViewBuilder
    private var archivedProjectsSection: some View {
        if !projectsVM.archivedProjects.isEmpty {
            Section("Archived Projects") {
                ForEach(projectsVM.archivedProjects) { project in
                    NavigationLink {
                        ProjectDetailView(projectID: project.id, repo: repo, mode: .archived)
                    } label: {
                        ArchivedProjectRow(project: project)
                    }
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    // FIXED: Only restore action in archives - no delete
                    .swipeActions(edge: .leading, allowsFullSwipe: false) {
                        Button {
                            Task { await projectsVM.unarchiveProject(project) }
                        } label: {
                            Label("Restore", systemImage: "arrow.uturn.backward")
                        }
                        .tint(Theme.primary)
                    }
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct ArchivedProjectRow: View {
    let project: Project
    @EnvironmentObject private var themeManager: ThemeManager
    private var theme: STSTheme { themeManager.current }
    
    var body: some View {
        STSCard {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text(project.title)
                        .font(Theme.Font.headline)
                        .foregroundStyle(theme.textPrimary)
                    
                    Text(project.createdAt.formatted(date: .abbreviated, time: .omitted))
                        .font(Theme.Font.caption)
                        .foregroundStyle(theme.textSecondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "archivebox.fill")
                            .font(.caption)
                            .foregroundStyle(theme.primaryAccent)
                        
                        if project.isFavorite {
                            Image(systemName: "star.fill")
                                .font(.caption)
                                .foregroundStyle(.yellow)
                        }
                        
                        if project.isCompleted {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.green)
                        }
                    }
                    
                    let sessionCount = project.sessions.count
                    if sessionCount > 0 {
                        Text("\(sessionCount) session\(sessionCount > 1 ? "s" : "")")
                            .font(Theme.Font.caption)
                            .foregroundStyle(theme.textSecondary)
                    }
                }
            }
        }
    }
}

#Preview {
    ArchivesView(repo: ProjectsRepositoryFactory.makePreviewRepository())
        .environmentObject(ThemeManager())
}
