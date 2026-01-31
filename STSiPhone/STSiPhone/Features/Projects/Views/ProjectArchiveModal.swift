import SwiftUI

struct ProjectArchiveModal: View {
    let project: Project
    let onDismiss: () -> Void
    let onDelete: () -> Void
    let onArchive: (ArchiveRequest) -> Void
    
    @State private var selectedAction: ArchiveAction = .archive
    @State private var request: ArchiveRequest = .default
    @State private var showDeleteConfirmation = false
    
    enum ArchiveAction: CaseIterable {
        case archive
        case delete
        
        var title: String {
            switch self {
            case .archive: return "Archive Project"
            case .delete: return "Delete Project"
            }
        }
        
        var icon: String {
            switch self {
            case .archive: return "archivebox.fill"
            case .delete: return "trash.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .archive: return .blue
            case .delete: return .red
            }
        }
        
        var description: String {
            switch self {
            case .archive: return "Move project to Archives with export options"
            case .delete: return "Permanently delete project and all sessions"
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 16) {
                    HStack {
                        Image(systemName: "archivebox.fill")
                            .font(.title2)
                            .foregroundStyle(.blue)
                        
                        Text("Manage Project")
                            .font(.headline)
                            .fontWeight(.bold)
                    }
                    
                    Text(project.title)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                
                Divider()
                
                // Action Selection
                ScrollView {
                    LazyVStack(spacing: 16) {
                        // Action Selection
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Select Action")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(.primary)
                            
                            ForEach(ArchiveAction.allCases, id: \.self) { action in
                                ActionSelectionRow(
                                    action: action,
                                    isSelected: selectedAction == action
                                ) {
                                    selectedAction = action
                                }
                            }
                        }
                        .padding(.horizontal)
                        
                        // Archive Options (only show for archive action)
                        if selectedAction == .archive {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Export Options")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.primary)
                                    .padding(.horizontal)
                                
                                ArchiveOptionsPanel(
                                    request: $request,
                                    options: ArchiveOption.defaultProjectArchiveOptions
                                )
                                .padding(.horizontal)
                            }
                        }
                        
                        // Project Summary
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Project Summary")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(.primary)
                            
                            VStack(spacing: 6) {
                                HStack {
                                    Text("Sessions:")
                                    Spacer()
                                    Text("\(project.sessions.count)")
                                        .foregroundStyle(.secondary)
                                }
                                
                                HStack {
                                    Text("Total Takes:")
                                    Spacer()
                                    Text("\(project.sessions.flatMap { $0.takes }.count)")
                                        .foregroundStyle(.secondary)
                                }
                                
                                if let castingOffice = project.castingOffice {
                                    HStack {
                                        Text("Casting Office:")
                                        Spacer()
                                        Text(castingOffice)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .font(.caption)
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.systemGray6))
                        )
                        .padding(.horizontal)
                    }
                }
                
                // Action Buttons
                VStack(spacing: 12) {
                    Button(selectedAction.title) {
                        executeSelectedAction()
                    }
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(selectedAction.color)
                    .cornerRadius(12)
                    
                    Button("Cancel") {
                        onDismiss()
                    }
                    .font(.headline)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
                }
                .padding()
            }
            .navigationBarHidden(true)
        }
        .alert("Delete Project?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete Forever", role: .destructive) {
                onDelete()
            }
        } message: {
            Text("This will permanently delete \"\(project.title)\" and all \(project.sessions.count) session\(project.sessions.count == 1 ? "" : "s"). This action cannot be undone.")
        }
    }
    
    private func executeSelectedAction() {
        switch selectedAction {
        case .archive:
            onArchive(request)
        case .delete:
            showDeleteConfirmation = true
        }
    }
}

// MARK: - Action Selection Row
struct ActionSelectionRow: View {
    let action: ProjectArchiveModal.ArchiveAction
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: action.icon)
                    .font(.title3)
                    .foregroundStyle(isSelected ? action.color : .gray)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(action.title)
                        .font(.headline)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                    
                    Text(action.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? action.color : .gray)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? action.color.opacity(0.1) : Color(.systemGray6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? action.color.opacity(0.3) : Color.clear, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    ProjectArchiveModal(
        project: Project(title: "Sample Project", castingOffice: "Sample Casting"),
        onDismiss: {},
        onDelete: {},
        onArchive: { _ in }
    )
}
