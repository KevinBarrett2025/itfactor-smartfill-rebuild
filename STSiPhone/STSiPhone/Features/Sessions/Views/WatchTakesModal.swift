import SwiftUI

struct WatchTakesModal: View {
    let session: ProjectSession
    let project: Project
    let onDismiss: () -> Void
    
    @State private var selectedSceneNumber = 1
    @State private var takes: [ProjectTake] = []
    
    var body: some View {
        NavigationView {
            ZStack {
                BrandBackground()
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Scene selector if multiple scenes
                    if project.sceneCount > 1 {
                        sceneSelector
                    }
                    
                    // Takes list
                    if takes.isEmpty {
                        emptyState
                    } else {
                        takesList
                    }
                }
            }
            .navigationTitle("Watch Takes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Text("\(project.title)")
                        .font(.caption)
                        .foregroundStyle(.gray)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        onDismiss()
                    }
                    .foregroundStyle(Theme.primary)
                }
            }
        }
        .onAppear {
            loadTakes()
        }
        .ratingEducationToastHost()
    }
    
    @ViewBuilder
    private var sceneSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(1...project.sceneCount, id: \.self) { sceneNum in
                    Button {
                        selectedSceneNumber = sceneNum
                        loadTakes()
                    } label: {
                        Text("Scene \(sceneNum)")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(selectedSceneNumber == sceneNum ? .white : .gray)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(selectedSceneNumber == sceneNum ? Theme.primary : Color.clear)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(selectedSceneNumber == sceneNum ? Color.clear : Color.gray.opacity(0.3), lineWidth: 1)
                                    )
                            )
                    }
                }
            }
            .padding(.horizontal, 24)
        }
        .padding(.vertical, 16)
    }
    
    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 24) {
            Image(systemName: "video.slash")
                .font(.system(size: 60))
                .foregroundStyle(.gray)
            
            VStack(spacing: 8) {
                Text("No Takes Yet")
                    .font(Theme.Font.title)
                    .foregroundStyle(.white)
                
                if project.sceneCount > 1 {
                    Text("No takes recorded for Scene \(selectedSceneNumber)")
                        .font(Theme.Font.body)
                        .foregroundStyle(.gray)
                        .multilineTextAlignment(.center)
                } else {
                    Text("Record your first take to see it here")
                        .font(Theme.Font.body)
                        .foregroundStyle(.gray)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    @ViewBuilder
    private var takesList: some View {
        List {
            ForEach(Array(takes.enumerated()), id: \.element.id) { index, take in
                WatchTakeRow(
                    take: take,
                    takeNumber: index + 1,
                    sceneNumber: selectedSceneNumber,
                    onQuickAction: { action in
                        handleQuickAction(action, for: take)
                    }
                )
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
    
    private func loadTakes() {
        // Filter takes by scene number (this would integrate with actual take data)
        // For now, using session takes as placeholder
        takes = session.takes
        print("Loading takes for scene \(selectedSceneNumber)")
    }
    
    private func handleQuickAction(_ action: TakeQuickAction, for take: ProjectTake) {
        switch action {
        case .markBest:
            // UNIFIED: Use SessionManager's unified rating system
            SessionManager.shared.setUnifiedTakeRating(
                takeID: take.id,
                sessionID: session.id, 
                projectID: project.id,
                rating: take.isBest ? .unrated : .finalSelect
            )
        case .favorite:
            // UNIFIED: Use SessionManager's unified rating system
            SessionManager.shared.setUnifiedTakeRating(
                takeID: take.id,
                sessionID: session.id,
                projectID: project.id,
                rating: take.isFavorite ? .unrated : .option
            )
        case .reject:
            // UNIFIED: Use SessionManager's unified rating system
            SessionManager.shared.setUnifiedTakeRating(
                takeID: take.id,
                sessionID: session.id,
                projectID: project.id,
                rating: take.isRejected ? .unrated : .rejected
            )
        case .play:
            print("Playing take: \(take.id)")
        }
        
        print("✅ WatchTakesModal: Updated unified take rating for \(take.id)")
    }
}

enum TakeQuickAction {
    case markBest, favorite, reject, play
}

struct WatchTakeRow: View {
    let take: ProjectTake
    let takeNumber: Int
    let sceneNumber: Int
    let onQuickAction: (TakeQuickAction) -> Void
    
    @State private var showQuickActions = false
    
    var body: some View {
        HStack(spacing: 16) {
            // Thumbnail placeholder
            thumbnailView
            
            // Take info
            takeInfo
            
            Spacer()
            
            // Quick actions (always visible in this modal)
            quickActions
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
        .onTapGesture {
            onQuickAction(.play)
        }
    }
    
    @ViewBuilder
    private var thumbnailView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black.opacity(0.3))
                .frame(width: 80, height: 60)
            
            Image(systemName: "play.fill")
                .font(.title2)
                .foregroundStyle(Theme.primary)
        }
    }
    
    @ViewBuilder
    private var takeInfo: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                if sceneNumber > 1 {
                    Text("Scene \(sceneNumber) • Take \(takeNumber)")
                        .font(Theme.Font.headline)
                        .foregroundStyle(.white)
                } else {
                    Text("Take \(takeNumber)")
                        .font(Theme.Font.headline)
                        .foregroundStyle(.white)
                }
                
                // Status indicators
                HStack(spacing: 4) {
                    if take.isBest {
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundStyle(.yellow)
                    }
                    
                    if take.isFavorite {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                    
                    if take.isRejected {
                        Image(systemName: "xmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
            
            Text(formattedDuration(take.effectiveDurationSeconds))
                .font(Theme.Font.caption)
                .foregroundStyle(.gray)
            
            if let notes = take.takeNotes, !notes.isEmpty {
                Text(notes)
                    .font(.caption)
                    .foregroundStyle(.gray)
                    .lineLimit(1)
            }
        }
    }
    
    @ViewBuilder
    private var quickActions: some View {
        HStack(spacing: 12) {
            // Star (Final Select)
            QuickActionButton(
                icon: take.isBest ? "star.fill" : "star",
                color: take.isBest ? .yellow : .gray,
                isActive: take.isBest
            ) {
                onQuickAction(.markBest)
            }
            
            // Check (Option)
            QuickActionButton(
                icon: take.isFavorite ? "checkmark.circle.fill" : "checkmark.circle",
                color: take.isFavorite ? .green : .gray,
                isActive: take.isFavorite
            ) {
                onQuickAction(.favorite)
            }
            
            // X (Reject)
            QuickActionButton(
                icon: take.isRejected ? "xmark.circle.fill" : "xmark.circle",
                color: take.isRejected ? .red : .gray,
                isActive: take.isRejected
            ) {
                onQuickAction(.reject)
            }
        }
    }
    
    private func formattedDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct QuickActionButton: View {
    let icon: String
    let color: Color
    let isActive: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(color)
                .padding(8)
                .background(
                    Circle()
                        .fill(isActive ? color.opacity(0.2) : Color.clear)
                        .overlay(
                            Circle()
                                .stroke(color.opacity(0.3), lineWidth: 1)
                        )
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    let sampleProject = Project(title: "Feature Film")

    let sampleSession = ProjectSession(
        id: UUID(),
        type: .selfTape,
        date: Date(),
        takes: [
            ProjectTake(filePath: "sample1.mov", durationSeconds: 45.0, rating: .finalSelect),
            ProjectTake(filePath: "sample2.mov", durationSeconds: 38.5, rating: .option),
            ProjectTake(filePath: "sample3.mov", durationSeconds: 52.0, rating: .rejected)
        ],
        roleName: "Detective Ramos"
    )
    
    WatchTakesModal(
        session: sampleSession,
        project: sampleProject,
        onDismiss: { print("Dismiss tapped") }
    )
}
