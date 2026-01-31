import SwiftUI

struct UnifiedSessionReview: View {
    let project: Project
    let session: ProjectSession
    
    @State private var takes: [ProjectTake]
    @State private var selectedTakes: Set<UUID> = []
    @State private var selectedSceneNumber = 1
    @State private var showingAddNoteAlert = false
    @State private var noteText = ""
    @State private var selectedTakeForNote: ProjectTake?
    
    // ENHANCED: Advanced video player integration with navigation support
    @State private var showVideoPlayer = false
    @State private var selectedTake: ProjectTake?
    @State private var videoPlayerTakes: [ProjectTake] = [] // For seamless navigation
    @State private var currentVideoIndex = 0
    
    @ObservedObject private var sessionManager = SessionManager.shared
    @Environment(\.dismiss) private var dismiss
    
    // ENHANCED: Repository integration for persistence
    private let repository: ProjectsRepository
    
    init(project: Project, session: ProjectSession, repository: ProjectsRepository) {
        self.project = project
        self.session = session
        self.repository = repository
        self._takes = State(initialValue: session.takes)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                BrandBackground()
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    headerSection
                    
                    // Scene selector for multi-scene projects
                    if project.sceneCount > 1 {
                        sceneSelector
                    }
                    
                    // Takes content
                    if filteredTakes.isEmpty {
                        emptyState
                    } else {
                        takesContent
                    }
                    
                    // Bottom actions
                    bottomActions
                }
            }
            .navigationBarHidden(true)
        }
        .fullScreenCover(isPresented: $showVideoPlayer, onDismiss: {
            selectedTake = nil
            videoPlayerTakes = []
            currentVideoIndex = 0
        }) {
            // ENHANCED: Advanced video player with seamless navigation
            if !videoPlayerTakes.isEmpty {
                EnhancedUnifiedVideoPlayerView(
                    takes: videoPlayerTakes,
                    initialIndex: currentVideoIndex,
                    project: project,
                    session: session,
                    repository: repository,
                    onDismiss: {
                        showVideoPlayer = false
                    },
                    onTakeChange: { newIndex in
                        currentVideoIndex = newIndex
                        if newIndex < videoPlayerTakes.count {
                            selectedTake = videoPlayerTakes[newIndex]
                        }
                    },
                    onRatingChange: { takeId, rating in
                        handleVideoPlayerRatingChange(takeId, rating)
                    },
                    onMarkerChange: {
                        // Reload takes after marker changes
                        reloadTakesFromRepository()
                    }
                )
            }
        }
        .alert("Add Note", isPresented: $showingAddNoteAlert) {
            TextField("Take notes...", text: $noteText)
            Button("Save") {
                if let take = selectedTakeForNote {
                    saveTakeNote(take, note: noteText)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Add a note for this take")
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("STSTakeRatingUpdated"))) { notification in
            // STEP 3C: Enhanced notification handling with comprehensive validation
            handleEnhancedRatingNotification(notification)
        }
        .onAppear {
            // STEP 3C: Enhanced view appearance handling
            setupEnhancedRatingSystem()
        }
        .ratingEducationToastHost()
    }
    
    // MARK: - Header Section
    @ViewBuilder
    private var headerSection: some View {
        VStack(spacing: 16) {
            HStack {
                Button("← Back") {
                    DispatchQueue.main.async {
                        dismiss()
                    }
                }
                .font(Theme.Font.body)
                .foregroundStyle(Theme.primary)
                
                Spacer()
                
                Button("Export All") {
                    exportAllTakes()
                }
                .font(Theme.Font.body)
                .foregroundStyle(Theme.primary)
                .opacity(takes.isEmpty ? 0.6 : 1.0)
                .disabled(takes.isEmpty)
            }
            
            VStack(spacing: 8) {
                Image(systemName: "video.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(Theme.primary)
                
                Text("Review and Export")
                    .font(Theme.Font.title)
                    .foregroundStyle(.white)
                
                Text(project.title)
                    .font(Theme.Font.headline)
                    .foregroundStyle(.gray)
                
                if let roleName = session.roleName {
                    Text("Role: \(roleName)")
                        .font(Theme.Font.body)
                        .foregroundStyle(.gray)
                }
                
                Text(session.date.formatted(date: .abbreviated, time: .shortened))
                    .font(Theme.Font.caption)
                    .foregroundStyle(.gray)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
    }
    
    // MARK: - Scene Selector
    @ViewBuilder
    private var sceneSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(1...project.sceneCount, id: \.self) { sceneNum in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedSceneNumber = sceneNum
                        }
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
    
    // MARK: - Empty State
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
    
    // MARK: - Takes Content
    @ViewBuilder
    private var takesContent: some View {
        VStack(spacing: 0) {
            // Take count and selection info
            HStack {
                Text("Takes (\(filteredTakes.count))")
                    .font(Theme.Font.headline)
                    .foregroundStyle(.white)
                
                Spacer()
                
                if !selectedTakes.isEmpty {
                    Text("\(selectedTakes.count) selected")
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.primary)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
            
            // Takes list
            List {
                ForEach(Array(filteredTakes.enumerated()), id: \.element.id) { index, take in
                    UnifiedTakeRow(
                        take: take,
                        takeNumber: index + 1,
                        sceneNumber: selectedSceneNumber,
                        isSelected: selectedTakes.contains(take.id),
                        onToggleSelected: {
                            toggleTakeSelection(take.id)
                        },
                        onPlayTake: {
                            playTakeWithNavigation(take, at: index)
                        },
                        onQuickAction: { action in
                            handleQuickAction(action, for: take)
                        }
                    )
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            deleteTake(take)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        
                        Button {
                            exportSingleTake(take)
                        } label: {
                            Label("Export", systemImage: "square.and.arrow.up")
                        }
                        .tint(.blue)
                    }
                    .swipeActions(edge: .leading, allowsFullSwipe: false) {
                        Button {
                            selectedTakeForNote = take
                            noteText = take.takeNotes ?? ""
                            showingAddNoteAlert = true
                        } label: {
                            Label("Note", systemImage: "pencil")
                        }
                        .tint(.purple)
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
    }
    
    // MARK: - Bottom Actions
    @ViewBuilder
    private var bottomActions: some View {
        VStack(spacing: 16) {
            if !selectedTakes.isEmpty {
                BrandedPrimaryButton(
                    label: "Export Selected (\(selectedTakes.count))",
                    icon: "square.and.arrow.up.fill"
                ) {
                    exportSelectedTakes()
                }
                
                BrandedSecondaryButton(
                    label: "Clear Selection"
                ) {
                    selectedTakes.removeAll()
                }
            } else if !takes.isEmpty {
                BrandedPrimaryButton(
                    label: "Export All Takes",
                    icon: "square.and.arrow.up.fill"
                ) {
                    exportAllTakes()
                }
                
                BrandedSecondaryButton(
                    label: "Select Takes"
                ) {
                    // Select all visible takes
                    selectedTakes = Set(filteredTakes.map { $0.id })
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 34)
    }
    
    // MARK: - Computed Properties
    private var filteredTakes: [ProjectTake] {
        // ENHANCED: Robust scene filtering with proper error handling
        return takes.filter { take in
            // Strategy 1: Try UnifiedTake conversion for accurate scene detection
            do {
                let fileName = URL(fileURLWithPath: take.filePath).lastPathComponent
                let unifiedTake = try UnifiedTake.safeConversion(
                    from: take,
                    projectID: project.id,
                    sessionID: session.id,
                    fileName: fileName
                )
                
                // Filter by scene and exclude slates for scene view
                let matchesScene = unifiedTake.sceneNumber == selectedSceneNumber
                let notSlate = !unifiedTake.isSlate
                
                print("🔍 UnifiedSessionReview: Filtering take \(fileName) - Scene: \(unifiedTake.sceneNumber), Selected: \(selectedSceneNumber), Match: \(matchesScene && notSlate)")
                
                return matchesScene && notSlate
                
            } catch {
                print("⚠️ UnifiedSessionReview: UnifiedTake conversion failed for \(take.filePath), using fallback filtering")
                
                // Strategy 2: Fallback - try direct filename analysis
                let fileName = URL(fileURLWithPath: take.filePath).lastPathComponent
                
                // Extract scene number using same logic as UnifiedTake
                let extractedScene = extractSceneNumberFallback(from: fileName)
                let isSlateFile = fileName.lowercased().contains("slate")
                
                let matchesScene = extractedScene == selectedSceneNumber
                let notSlate = !isSlateFile
                
                print("🔄 UnifiedSessionReview: Fallback filtering for \(fileName) - Scene: \(extractedScene), Match: \(matchesScene && notSlate)")
                
                return matchesScene && notSlate
            }
        }
    }
    
    /// Fallback scene number extraction for when UnifiedTake conversion fails
    private func extractSceneNumberFallback(from fileName: String) -> Int {
        // Look for "Scene#" pattern
        if let sceneMatch = fileName.range(of: #"Scene(\d+)"#, options: .regularExpression) {
            let sceneString = String(fileName[sceneMatch]).replacingOccurrences(of: "Scene", with: "")
            if let sceneNumber = Int(sceneString), sceneNumber > 0 {
                return sceneNumber
            }
        }
        
        // Look for "S#" pattern
        if let sMatch = fileName.range(of: #"S(\d+)"#, options: .regularExpression) {
            let sString = String(fileName[sMatch]).replacingOccurrences(of: "S", with: "")
            if let sceneNumber = Int(sString), sceneNumber > 0 {
                return sceneNumber
            }
        }
        
        // Default fallback - assume scene 1
        return 1
    }
    
    // MARK: - Enhanced Video Player Actions
    
    /// ENHANCED: Play take with seamless navigation support
    private func playTakeWithNavigation(_ take: ProjectTake, at index: Int) {
        // Setup navigation-ready takes list (filtered takes for current scene)
        videoPlayerTakes = filteredTakes
        currentVideoIndex = index
        selectedTake = take
        
        // Trigger enhanced video player
        showVideoPlayer = true
        
        print("🎬 UnifiedSessionReview: Starting enhanced video player")
        print("   📹 Current take: \(take.filePath)")
        print("   🎯 Index: \(index) of \(videoPlayerTakes.count)")
        print("   🎨 Scene: \(selectedSceneNumber)")
    }
    
    /// Handle rating changes from video player
    private func handleVideoPlayerRatingChange(_ takeId: UUID, _ rating: TakeRating) {
        // Update through SessionManager for consistency
        SessionManager.shared.setUnifiedTakeRating(
            takeID: takeId,
            sessionID: session.id,
            projectID: project.id,
            rating: rating
        )
        
        // Reload local state
        reloadTakesFromRepository()
        
        print("✅ UnifiedSessionReview: Updated rating from video player - Take: \(takeId), Rating: \(rating)")
    }
    
    // STEP 3C: Enhanced notification handling for bulletproof cross-view consistency
    private func handleEnhancedRatingNotification(_ notification: Notification) {
        guard let userInfo = notification.userInfo else {
            print("⚠️ UnifiedSessionReview: Rating notification missing userInfo")
            return
        }
        
        // STEP 3C: Validate notification data
        guard let takeID = userInfo["takeID"] as? UUID,
              let sessionID = userInfo["sessionID"] as? UUID,
              let projectID = userInfo["projectID"] as? UUID,
              let ratingString = userInfo["rating"] as? String,
              let rating = TakeRating(rawValue: ratingString) else {
            print("⚠️ UnifiedSessionReview: Invalid rating notification data")
            return
        }
        
        // STEP 3C: Only update if this notification is for our current session
        guard sessionID == session.id && projectID == project.id else {
            print("📋 UnifiedSessionReview: Rating notification not for current session, ignoring")
            return
        }
        
        // STEP 3C: Find and update the take with enhanced validation
        if let takeIndex = takes.firstIndex(where: { $0.id == takeID }) {
            let previousRating = takes[takeIndex].rating
            takes[takeIndex].rating = rating
            
            // STEP 3C: Log the change for debugging
            print("✅ UnifiedSessionReview: Updated take rating \(takeID) - \(previousRating) → \(rating)")
        } else {
            print("⚠️ UnifiedSessionReview: Take \(takeID) not found in current takes list")
            // STEP 3C: Reload from repository as fallback
            reloadTakesFromRepository()
        }
    }
    
    // STEP 3C: Enhanced setup for rating system
    private func setupEnhancedRatingSystem() {
        // STEP 3C: Ensure takes are loaded from repository
        reloadTakesFromRepository()
        
        print("✅ UnifiedSessionReview: Enhanced rating system initialized for session \(session.id)")
    }
    
    /// Reload takes from repository after changes - STEP 3C: Enhanced with error handling
    private func reloadTakesFromRepository() {
        guard let updatedProject = repository.project(by: project.id) else {
            print("⚠️ UnifiedSessionReview: Project not found during reload: \(project.id)")
            return
        }
        
        guard let updatedSession = updatedProject.sessions.first(where: { $0.id == session.id }) else {
            print("⚠️ UnifiedSessionReview: Session not found during reload: \(session.id)")
            return
        }
        
        // STEP 3C: Update takes with validation
        let previousCount = takes.count
        takes = updatedSession.takes
        
        print("🔄 UnifiedSessionReview: Enhanced reload completed - \(previousCount) → \(takes.count) takes")
    }
    
    // MARK: - Actions
    private func toggleTakeSelection(_ takeID: UUID) {
        withAnimation(.easeInOut(duration: 0.2)) {
            if selectedTakes.contains(takeID) {
                selectedTakes.remove(takeID)
            } else {
                selectedTakes.insert(takeID)
            }
        }
    }
    
    private func playTake(_ take: ProjectTake) {
        // Find index for navigation
        if let index = filteredTakes.firstIndex(where: { $0.id == take.id }) {
            playTakeWithNavigation(take, at: index)
        }
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
            playTake(take)
        }
        
        // Force reload of local state to reflect changes
        reloadTakesFromRepository()
        
        print("✅ UnifiedSessionReview: Updated unified take rating for \(take.id)")
    }
    
    private func markTakeAsBest(_ take: ProjectTake) {
        // CLEANED: Use unified rating system through repository
        let newRating: TakeRating = take.isBest ? .unrated : .finalSelect
        
        repository.setUnifiedTakeRating(
            takeID: take.id,
            sessionID: session.id,
            projectID: project.id,
            rating: newRating
        )
        
        // Reload local state to reflect changes
        reloadTakesFromRepository()
    }
    
    private func toggleTakeFavorite(_ take: ProjectTake) {
        // CLEANED: Use unified rating system through repository
        let newRating: TakeRating = take.isFavorite ? .unrated : .option
        
        repository.setUnifiedTakeRating(
            takeID: take.id,
            sessionID: session.id,
            projectID: project.id,
            rating: newRating
        )
        
        // Reload local state to reflect changes
        reloadTakesFromRepository()
    }
    
    private func toggleTakeRejected(_ take: ProjectTake) {
        // CLEANED: Use unified rating system through repository
        let newRating: TakeRating = take.isRejected ? .unrated : .rejected
        
        repository.setUnifiedTakeRating(
            takeID: take.id,
            sessionID: session.id,
            projectID: project.id,
            rating: newRating
        )
        
        // Reload local state to reflect changes
        reloadTakesFromRepository()
    }
    
    private func deleteTake(_ take: ProjectTake) {
        withAnimation(.easeInOut(duration: 0.25)) {
            takes.removeAll { $0.id == take.id }
            selectedTakes.remove(take.id)
            
            // Update in repository
            repository.deleteTake(
                takeID: take.id,
                from: session.id,
                in: project.id
            )
        }
    }
    
    private func saveTakeNote(_ take: ProjectTake, note: String) {
        if let index = takes.firstIndex(where: { $0.id == take.id }) {
            takes[index].takeNotes = note.isEmpty ? nil : note
            
            // Update in repository
            repository.addTakeNote(
                takeID: take.id,
                in: session.id,
                of: project.id,
                note: note
            )
        }
    }
    
    private func exportAllTakes() {
        print("📤 Exporting all \(takes.count) takes")
        // PHASE 3: Properly delegate to ExportManagerView or repository export
        if !takes.isEmpty {
            // Option 1: Push a notification or navigate to ExportManagerView if applicable
            // Option 2: Use repository to trigger actual export
            // Here we just print for placeholder, real logic should show export UI or call infrastructure.
            repository.exportSession(
                sessionID: session.id,
                projectID: project.id,
                takeIDs: takes.map { $0.id }
            )
        }
    }
    
    private func exportSelectedTakes() {
        let selectedTakesList = takes.filter { selectedTakes.contains($0.id) }
        print("📤 Exporting \(selectedTakesList.count) selected takes")
        if !selectedTakesList.isEmpty {
            repository.exportSession(
                sessionID: session.id,
                projectID: project.id,
                takeIDs: selectedTakesList.map { $0.id }
            )
        }
    }
    
    private func exportSingleTake(_ take: ProjectTake) {
        print("📤 Exporting single take: \(take.id)")
        repository.exportTake(
            takeID: take.id,
            from: session.id,
            in: project.id
        )
    }
    
    private func convertToUnifiedTake(_ take: ProjectTake) -> UnifiedTake {
        let fileName = URL(fileURLWithPath: take.filePath).lastPathComponent
        let takeIndex = takes.firstIndex(of: take) ?? 0
        
        return UnifiedTake(
            from: take,
            projectID: project.id,
            sessionID: session.id,
            fileName: fileName,
            takeNumber: takeIndex + 1
        )
    }
}

// MARK: - Unified Take Row
struct UnifiedTakeRow: View {
    let take: ProjectTake
    let takeNumber: Int
    let sceneNumber: Int
    let isSelected: Bool
    let onToggleSelected: () -> Void
    let onPlayTake: () -> Void
    let onQuickAction: (TakeQuickAction) -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            // Enhanced play button with video markers indicator
            Button(action: onPlayTake) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.black.opacity(0.3))
                        .frame(width: 80, height: 60)
                    
                    VStack(spacing: 2) {
                        Image(systemName: "play.fill")
                            .font(.title2)
                            .foregroundStyle(Theme.primary)
                        
                        // Video markers indicator
                        if !take.videoMarkers.isEmpty {
                            HStack(spacing: 2) {
                                Image(systemName: "flag.fill")
                                    .font(.caption2)
                                Text("\(take.videoMarkers.count)")
                                    .font(.caption2)
                            }
                            .foregroundStyle(.orange)
                        }
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            // Take info
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
                    
                    // Status indicators matching WatchTakesModal
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
                
                HStack(spacing: 8) {
                    Text(formattedDuration(take.effectiveDurationSeconds))
                        .font(Theme.Font.caption)
                        .foregroundStyle(.gray)
                    
                    // Enhanced indicators
                    if !take.videoMarkers.isEmpty {
                        Text("• \(take.videoMarkers.count) marker\(take.videoMarkers.count == 1 ? "" : "s")")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                }
                
                if let notes = take.takeNotes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption)
                        .foregroundStyle(.gray)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Quick actions (consistent with WatchTakesModal)
            HStack(spacing: 12) {
                // Star (Final Select) - consistent with WatchTakesModal
                QuickActionButton(
                    icon: take.isBest ? "star.fill" : "star",
                    color: take.isBest ? .yellow : .gray,
                    isActive: take.isBest
                ) {
                    onQuickAction(.markBest)
                }
                
                // Check (Option) - consistent with WatchTakesModal
                QuickActionButton(
                    icon: take.isFavorite ? "checkmark.circle.fill" : "checkmark.circle",
                    color: take.isFavorite ? .green : .gray,
                    isActive: take.isFavorite
                ) {
                    onQuickAction(.favorite)
                }
                
                // X (Reject) - consistent with WatchTakesModal
                QuickActionButton(
                    icon: take.isRejected ? "xmark.circle.fill" : "xmark.circle",
                    color: take.isRejected ? .red : .gray,
                    isActive: take.isRejected
                ) {
                    onQuickAction(.reject)
                }
                
                // Selection toggle
                Button(action: onToggleSelected) {
                    Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                        .font(.system(size: 20))
                        .foregroundStyle(isSelected ? Theme.primary : .gray)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(isSelected ? 0.1 : 0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? Theme.primary.opacity(0.5) : Color.white.opacity(0.1), lineWidth: isSelected ? 2 : 1)
                )
        )
    }
    
    private func formattedDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Enhanced Unified Video Player View
struct EnhancedUnifiedVideoPlayerView: View {
    let takes: [ProjectTake]
    @State private var currentIndex: Int
    let project: Project
    let session: ProjectSession
    let repository: ProjectsRepository
    
    let onDismiss: () -> Void
    let onTakeChange: (Int) -> Void
    let onRatingChange: (UUID, TakeRating) -> Void
    let onMarkerChange: () -> Void
    
    @State private var currentUnifiedTake: UnifiedTake?
    @State private var isLoading = true
    
    // ENHANCED: Video player controls
    @State private var showControls = true
    @State private var showRatingPicker = false
    @State private var showNavigationHint = true
    
    @StateObject private var videoPlayerService = VideoPlayerService.shared
    
    init(takes: [ProjectTake], initialIndex: Int, project: Project, session: ProjectSession, repository: ProjectsRepository, onDismiss: @escaping () -> Void, onTakeChange: @escaping (Int) -> Void, onRatingChange: @escaping (UUID, TakeRating) -> Void, onMarkerChange: @escaping () -> Void) {
        self.takes = takes
        self._currentIndex = State(initialValue: initialIndex)
        self.project = project
        self.session = session
        self.repository = repository
        self.onDismiss = onDismiss
        self.onTakeChange = onTakeChange
        self.onRatingChange = onRatingChange
        self.onMarkerChange = onMarkerChange
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if isLoading {
                loadingView
            } else if let unifiedTake = currentUnifiedTake {
                // ENHANCED: Video player with navigation
                UnifiedTakePlayerView(unifiedTake: unifiedTake) {
                    ZStack {
                        if showControls {
                            enhancedVideoOverlay(for: unifiedTake)
                        }
                        if showNavigationHint {
                            navigationHintOverlay
                        }
                    }
                }
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showControls.toggle()
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .gesture(
            DragGesture()
                .onEnded { value in
                    handleSwipeGesture(value)
                }
        )
        .onAppear {
            loadCurrentTake()
            
            // Hide navigation hint after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                withAnimation(.easeOut(duration: 0.5)) {
                    showNavigationHint = false
                }
            }
        }
        .onChange(of: currentIndex, initial: false) { oldValue, newValue in
            loadCurrentTake()
            onTakeChange(newValue)
        }
    }
    
    // MARK: - Enhanced Video Overlay
    @ViewBuilder
    private func enhancedVideoOverlay(for unifiedTake: UnifiedTake) -> some View {
        VStack {
            // Top controls
            HStack {
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.title2)
                        .foregroundColor(.white)
                        .padding(12)
                        .background(.ultraThinMaterial, in: Circle())
                }
                
                Spacer()
                
                // Take info
                VStack(alignment: .trailing, spacing: 4) {
                    Text(project.title)
                        .font(.headline)
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Text("Take \(unifiedTake.takeNumber) • Scene \(unifiedTake.sceneNumber)")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                    
                    Text("(\(currentIndex + 1) of \(takes.count))")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.6))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.black.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
                
                // Rating button
                Button(action: { showRatingPicker = true }) {
                    Image(systemName: unifiedTake.rating.iconName)
                        .font(.title3)
                        .foregroundColor(unifiedTake.rating.color)
                        .padding(8)
                        .background(.ultraThinMaterial, in: Circle())
                }
            }
            .padding()
            
            Spacer()
            
            // Navigation controls
            HStack {
                // Previous take
                Button(action: previousTake) {
                    Image(systemName: "chevron.left")
                        .font(.title2)
                        .foregroundColor(.white)
                        .padding(16)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .disabled(currentIndex <= 0)
                .opacity(currentIndex <= 0 ? 0.5 : 1.0)
                
                Spacer()
                
                // Next take
                Button(action: nextTake) {
                    Image(systemName: "chevron.right")
                        .font(.title2)
                        .foregroundColor(.white)
                        .padding(16)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .disabled(currentIndex >= takes.count - 1)
                .opacity(currentIndex >= takes.count - 1 ? 0.5 : 1.0)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 100)
        }
        .transition(.opacity)
        .sheet(isPresented: $showRatingPicker) {
            RatingPickerView(
                currentRating: unifiedTake.rating,
                onRatingSelected: { rating in
                    onRatingChange(unifiedTake.id, rating)
                    // Update local state
                    currentUnifiedTake?.rating = rating
                    showRatingPicker = false
                }
            )
            .presentationDetents([.height(300)])
        }
    }
    
    // MARK: - Navigation Hint
    @ViewBuilder
    private var navigationHintOverlay: some View {
        VStack {
            Spacer()
            
            HStack(spacing: 20) {
                HStack(spacing: 8) {
                    Image(systemName: "chevron.left")
                    Text("Swipe")
                }
                .font(.caption)
                .foregroundColor(.white.opacity(0.8))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.black.opacity(0.6), in: Capsule())
                
                Text("Navigate Between Takes")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
                
                HStack(spacing: 8) {
                    Text("Swipe")
                    Image(systemName: "chevron.right")
                }
                .font(.caption)
                .foregroundColor(.white.opacity(0.8))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.black.opacity(0.6), in: Capsule())
            }
            .padding(.bottom, 50)
        }
        .transition(.opacity)
    }
    
    // MARK: - Navigation Functions
    private func nextTake() {
        guard currentIndex < takes.count - 1 else { return }
        withAnimation(.easeInOut(duration: 0.3)) {
            currentIndex += 1
        }
    }
    
    private func previousTake() {
        guard currentIndex > 0 else { return }
        withAnimation(.easeInOut(duration: 0.3)) {
            currentIndex -= 1
        }
    }
    
    private func handleSwipeGesture(_ value: DragGesture.Value) {
        let horizontalDistance = value.translation.width
        let verticalDistance = abs(value.translation.height)
        
        // Only handle horizontal swipes (not vertical)
        guard abs(horizontalDistance) > 50 && abs(horizontalDistance) > verticalDistance else { return }
        
        if horizontalDistance > 0 {
            // Swipe right - previous take
            previousTake()
        } else {
            // Swipe left - next take
            nextTake()
        }
    }
    
    // MARK: - Loading Functions
    private func loadCurrentTake() {
        guard currentIndex < takes.count else { return }
        
        isLoading = true
        let take = takes[currentIndex]
        
        Task { @MainActor in
            do {
                let fileName = URL(fileURLWithPath: take.filePath).lastPathComponent
                let unifiedTake = try UnifiedTake.safeConversion(
                    from: take,
                    projectID: project.id,
                    sessionID: session.id,
                    fileName: fileName,
                    takeNumber: currentIndex + 1
                )
                
                currentUnifiedTake = unifiedTake
                isLoading = false
                
                print("✅ Enhanced Video Player: Loaded take \(currentIndex + 1): \(fileName)")
                
            } catch {
                print("❌ Enhanced Video Player: Failed to load take \(currentIndex + 1): \(error)")
                isLoading = false
            }
        }
    }
    
    // MARK: - UI Components
    @ViewBuilder
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(.white)
            
            Text("Loading take \(currentIndex + 1)...")
                .font(.headline)
                .foregroundColor(.white)
        }
    }
}

// MARK: - Rating Picker View
struct RatingPickerView: View {
    let currentRating: TakeRating
    let onRatingSelected: (TakeRating) -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Rate This Take")
                .font(.headline)
                .foregroundColor(.white)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                ForEach(TakeRating.displayOrder, id: \.self) { rating in
                    Button(action: {
                        onRatingSelected(rating)
                    }) {
                        VStack(spacing: 8) {
                            Image(systemName: rating.iconName)
                                .font(.system(size: 32))
                                .foregroundColor(rating.color)
                            
                            Text(rating.displayName)
                                .font(.caption)
                                .foregroundColor(.white)
                        }
                        .frame(width: 80, height: 80)
                        .background(
                            currentRating == rating 
                            ? Color.white.opacity(0.1)
                            : Color.clear,
                            in: RoundedRectangle(cornerRadius: 12)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(
                                    currentRating == rating 
                                    ? Color.white.opacity(0.5)
                                    : Color.white.opacity(0.1),
                                    lineWidth: 1
                                )
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .padding(24)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    let sampleProject = Project(title: "Feature Film Test")
    
    let sampleSession = ProjectSession(
        type: .selfTape,
        date: Date(),
        takes: [
            ProjectTake(filePath: "sample1.mov", durationSeconds: 45.0, rating: .finalSelect),
            ProjectTake(filePath: "sample2.mov", durationSeconds: 38.5, rating: .option),
            ProjectTake(filePath: "sample3.mov", durationSeconds: 52.0, rating: .rejected)
        ],
        roleName: "Detective Brooks"
    )
    
    UnifiedSessionReview(
        project: sampleProject,
        session: sampleSession,
        repository: ProjectsRepositoryFactory.makePreviewRepository()
    )
}
