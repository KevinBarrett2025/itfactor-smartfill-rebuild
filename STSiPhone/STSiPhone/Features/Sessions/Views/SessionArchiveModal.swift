import SwiftUI

struct SessionArchiveModal: View {
    let session: ProjectSession
    let onDismiss: () -> Void
    let onDelete: () -> Void
    let onArchive: (ArchiveRequest) -> Void
    
    @State private var selectedAction: SessionAction = .archive
    @State private var request: ArchiveRequest = .default
    @State private var showDeleteConfirmation = false
    
    enum SessionAction: CaseIterable {
        case archive
        case delete
        
        var title: String {
            switch self {
            case .archive: return "Archive Session"
            case .delete: return "Delete Session"
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
            case .archive: return "Move session to Archives with export options"
            case .delete: return "Permanently delete session and all takes"
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 16) {
                    HStack {
                        Image(systemName: sessionTypeIcon)
                            .font(.title2)
                            .foregroundStyle(.blue)
                        
                        Text("Manage Session")
                            .font(.headline)
                            .fontWeight(.bold)
                    }
                    
                    VStack(spacing: 4) {
                        Text(session.type.rawValue)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        if let roleName = session.roleName {
                            Text(roleName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Text(session.date.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
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
                            
                            ForEach(SessionAction.allCases, id: \.self) { action in
                                SessionActionRow(
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
                                    options: ArchiveOption.defaultSessionArchiveOptions
                                )
                                .padding(.horizontal)
                            }
                        }
                        
                        // Session Summary
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Session Summary")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(.primary)
                            
                            VStack(spacing: 6) {
                                HStack {
                                    Text("Takes:")
                                    Spacer()
                                    Text("\(session.takes.count)")
                                        .foregroundStyle(.secondary)
                                }
                                
                                HStack {
                                    Text("Duration:")
                                    Spacer()
                                    Text(totalDurationString)
                                        .foregroundStyle(.secondary)
                                }
                                
                                if let notes = session.notes, !notes.isEmpty {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Notes:")
                                            .fontWeight(.medium)
                                        Text(notes)
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
        .alert("Delete Session?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete Forever", role: .destructive) {
                onDelete()
            }
        } message: {
            Text("This will permanently delete this \(session.type.rawValue) session and all \(session.takes.count) take\(session.takes.count == 1 ? "" : "s").")
        }
    }
    
    private var sessionTypeIcon: String {
        switch session.type {
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
    
    private var totalDurationString: String {
        let totalDuration = session.takes.reduce(0) { $0 + $1.durationSeconds }
        let minutes = Int(totalDuration) / 60
        let seconds = Int(totalDuration) % 60
        return String(format: "%d:%02d", minutes, seconds)
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

// MARK: - Session Action Row
struct SessionActionRow: View {
    let action: SessionArchiveModal.SessionAction
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
    SessionArchiveModal(
        session: ProjectSession(type: .selfTape, notes: "Sample session"),
        onDismiss: {},
        onDelete: {},
        onArchive: { _ in }
    )
}
