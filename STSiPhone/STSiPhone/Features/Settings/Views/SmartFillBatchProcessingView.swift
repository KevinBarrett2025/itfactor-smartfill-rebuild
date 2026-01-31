import SwiftUI

struct SmartFillBatchProcessingView: View {
    let repository: ProjectsRepository
    
    @State private var selectedProject: Project?
    @State private var allProjects: [Project] = []
    @State private var smartFillStatus: SmartFillSessionStatus = SmartFillSessionStatus()
    @State private var isProcessing = false
    @State private var processingProgress: Double = 0.0
    @State private var processingStatus = ""
    @State private var showingSettings = false
    @State private var migrationCount: Int = 0
    @State private var recoveryCount: Int = 0
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                if allProjects.isEmpty {
                    emptyStateView
                } else {
                    VStack(spacing: 16) {
                        projectSelectionSection
                        
                        if selectedProject != nil {
                            smartFillStatusSection
                            
                            if smartFillStatus.needsProcessing && !isProcessing {
                                batchProcessingSection
                            } else if isProcessing {
                                processingProgressSection
                            } else if !smartFillStatus.needsProcessing {
                                completedSection
                            }
                        }
                        
                        // 🚨 NEW: SmartFill Recovery Section
                        smartFillRecoverySection
                        
                        Spacer()
                    }
                    .padding()
                }
            }
            .navigationTitle("Smart Fill Batch Processing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Settings") {
                        showingSettings = true
                    }
                }
            }
        }
        .sheet(isPresented: $showingSettings) {
            SmartFillSettingsView()
        }
        .onAppear {
            loadProjects()
        }
    }
    
    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "rectangle.slash")
                .font(.system(size: 48))
                .foregroundColor(.gray)
            
            Text("No Projects Found")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text("Create some projects with video takes to use Smart Fill batch processing")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }
    
    @ViewBuilder
    private var projectSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Select Project")
                .font(.headline)
                .foregroundColor(.primary)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(allProjects, id: \.id) { project in
                        ProjectSelectionCard(
                            project: project,
                            isSelected: selectedProject?.id == project.id
                        ) {
                            selectProject(project)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    @ViewBuilder
    private var smartFillStatusSection: some View {
        // SWIFT 6 FIX: Use selectedProject != nil test instead of unused binding
        if selectedProject != nil {
            VStack(alignment: .leading, spacing: 12) {
                Text("Smart Fill Status")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                if let project = selectedProject {
                    ForEach(project.sessions, id: \.id) { session in
                        SessionSmartFillCard(
                            session: session,
                            status: getSessionStatus(session)
                        )
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private var batchProcessingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Batch Processing")
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(spacing: 8) {
                HStack {
                    Text("Portrait Takes Found:")
                    Spacer()
                    Text("\(smartFillStatus.totalPortraitTakes)")
                        .fontWeight(.semibold)
                }
                
                HStack {
                    Text("Already Processed:")
                    Spacer()
                    Text("\(smartFillStatus.smartFilledTakes)")
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                }
                
                HStack {
                    Text("Pending:")
                    Spacer()
                    Text("\(smartFillStatus.pendingTakes)")
                        .fontWeight(.semibold)
                        .foregroundColor(.orange)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(8)
            
            Button(action: startBatchProcessing) {
                HStack {
                    Image(systemName: "rectangle.fill.badge.checkmark")
                    Text("Process \(smartFillStatus.pendingTakes) Portrait Take\(smartFillStatus.pendingTakes == 1 ? "" : "s")")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
        }
    }
    
    @ViewBuilder
    private var processingProgressSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Processing...")
                .font(.headline)
                .foregroundColor(.primary)
            
            ProgressView(value: processingProgress, total: 1.0)
                .progressViewStyle(LinearProgressViewStyle())
            
            Text(processingStatus)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Button("Cancel Processing") {
                cancelProcessing()
            }
            .font(.caption)
            .foregroundColor(.red)
        }
    }
    
    @ViewBuilder
    private var completedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("Smart Fill Complete")
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            
            Text("All portrait takes have been processed with Smart Fill")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.green.opacity(0.1))
        .cornerRadius(8)
    }
    
    // 🚨 NEW: SmartFill Recovery Section
    @ViewBuilder
    private var smartFillRecoverySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("🔄 SmartFill Recovery")
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(spacing: 8) {
                Button(action: {
                    performSmartFillPathMigration()
                }) {
                    Label("Migrate SmartFill Paths", systemImage: "folder.badge.gearshape")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .disabled(isProcessing)
                
                if migrationCount > 0 {
                    Text("Last migration: \(migrationCount) paths fixed")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Button(action: {
                    regenerateMissingSmartFills()
                }) {
                    Label("Regenerate Missing SmartFill", systemImage: "arrow.clockwise.circle")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .disabled(isProcessing)
                
                if recoveryCount > 0 {
                    Text("Regenerated: \(recoveryCount) SmartFill files")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Actions
    
    private func loadProjects() {
        allProjects = repository.fetchProjects().filter { !$0.isArchived }
        
        if let firstProject = allProjects.first {
            selectProject(firstProject)
        }
    }
    
    private func selectProject(_ project: Project) {
        selectedProject = project
        updateSmartFillStatus()
    }
    
    private func updateSmartFillStatus() {
        guard let project = selectedProject else { return }
        
        var totalPortraitTakes = 0
        var smartFilledTakes = 0
        var pendingTakes = 0
        var allPortraitTakes: [ProjectTake] = []
        
        for session in project.sessions {
            let sessionPortraitTakes = session.takes.filter { $0.capturedOrientation == .portrait }
            totalPortraitTakes += sessionPortraitTakes.count
            allPortraitTakes.append(contentsOf: sessionPortraitTakes)
            
            let sessionSmartFilledTakes = sessionPortraitTakes.filter { $0.hasSmartFilledVersion }
            smartFilledTakes += sessionSmartFilledTakes.count
            
            let sessionPendingTakes = sessionPortraitTakes.filter { !$0.hasSmartFilledVersion }
            pendingTakes += sessionPendingTakes.count
        }
        
        smartFillStatus = SmartFillSessionStatus(
            totalPortraitTakes: totalPortraitTakes,
            smartFilledTakes: smartFilledTakes,
            pendingTakes: pendingTakes,
            allPortraitTakes: allPortraitTakes,
            needsProcessing: pendingTakes > 0
        )
    }
    
    private func getSessionStatus(_ session: ProjectSession) -> SmartFillSessionStatus {
        let portraitTakes = session.takes.filter { $0.capturedOrientation == .portrait }
        let smartFilledTakes = portraitTakes.filter { $0.hasSmartFilledVersion }
        let pendingTakes = portraitTakes.filter { !$0.hasSmartFilledVersion }
        
        return SmartFillSessionStatus(
            totalPortraitTakes: portraitTakes.count,
            smartFilledTakes: smartFilledTakes.count,
            pendingTakes: pendingTakes.count,
            allPortraitTakes: portraitTakes,
            needsProcessing: !pendingTakes.isEmpty
        )
    }
    
    private func startBatchProcessing() {
        guard let project = selectedProject else { return }
        
        isProcessing = true
        processingProgress = 0.0
        processingStatus = "Preparing for batch processing..."
        
        Task {
            await performBatchProcessing(for: project)
        }
    }
    
    private func performBatchProcessing(for project: Project) async {
        let pendingTakes = smartFillStatus.allPortraitTakes.filter { !$0.hasSmartFilledVersion }
        let totalTakes = pendingTakes.count
        
        for (index, take) in pendingTakes.enumerated() {
            await MainActor.run {
                processingStatus = "Processing take \(index + 1) of \(totalTakes): \(URL(fileURLWithPath: take.filePath).lastPathComponent)"
                processingProgress = Double(index) / Double(totalTakes)
            }
            
            await processTakeWithSmartFill(take, in: project)
            
            // Check if processing was cancelled
            guard isProcessing else { break }
        }
        
        await MainActor.run {
            isProcessing = false
            processingProgress = 1.0
            processingStatus = "Batch processing completed"
            updateSmartFillStatus()
        }
    }
    
    private func processTakeWithSmartFill(_ take: ProjectTake, in project: Project) async {
        do {
            // Find the session containing this take
            guard let session = project.sessions.first(where: { $0.takes.contains { $0.id == take.id } }) else {
                print("❌ Could not find session for take: \(take.filePath)")
                return
            }
            
            // Create SmartFill output path in same directory as original
            let originalURL = URL(fileURLWithPath: take.filePath)
            let originalDirectory = originalURL.deletingLastPathComponent()
            let baseName = originalURL.deletingPathExtension().lastPathComponent
            let smartFillFileName = "\(baseName)_smartfill.mov" // FIXED: Use consistent _smartfill.mov naming
            let smartFillURL = originalDirectory.appendingPathComponent(smartFillFileName)
            let smartFillPath = smartFillURL.path
            
            print("🎨 Batch processing: \(originalURL.lastPathComponent) → \(smartFillFileName)")

            // 🚀 Plan B API: Use type-safe manager directly
            let result = try await SmartFillProcessingManager.shared.process(
                inputURL: originalURL,
                settings: SmartFillSettings()
            )

            if result.success {
                print("✅ Batch processing completed successfully with \(result.compositorUsed)")
                print("   ⏱️ Processing time: \(String(format: "%.2f", result.processingTime))s")
                
                // Update repository with SmartFill path
                repository.updateTakeWithSmartFillPath(
                    takeID: take.id,
                    smartFilledPath: smartFillPath,
                    in: session.id,
                    in: project.id
                )
                print("✅ Updated repository with SmartFill path for batch processed take")
            } else {
                print("⚠️ Batch processing reported success=false for take: \(take.filePath)")
            }
        } catch {
            print("❌ Batch processing failed for take \(take.filePath): \(error)")
        }
    }
    
    private func cancelProcessing() {
        isProcessing = false
        processingStatus = "Processing cancelled"
    }
    
    // 🚨 NEW: SmartFill path migration function
    private func performSmartFillPathMigration() {
        isProcessing = true
        migrationCount = 0
        
        Task {
            await MainActor.run {
                processingStatus = "Path migration currently unsupported with SQLite repository"
                isProcessing = false
            }
        }
    }
    
    // 🚨 NEW: Regenerate missing SmartFill files
    private func regenerateMissingSmartFills() {
        isProcessing = true
        recoveryCount = 0
        
        Task {
            await MainActor.run {
                processingStatus = "SmartFill regeneration is not yet available for the SQLite repository"
                isProcessing = false
            }
        }
    }
}

// MARK: - Supporting Views

struct ProjectSelectionCard: View {
    let project: Project
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(project.title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
                .lineLimit(2)
            
            Text("\(project.sessions.count) session\(project.sessions.count == 1 ? "" : "s")")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(width: 120, height: 60)
        .padding(8)
        .background(isSelected ? Color.blue.opacity(0.1) : Color(.systemGray6))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
        )
        .cornerRadius(8)
        .onTapGesture(perform: onTap)
    }
}

struct SessionSmartFillCard: View {
    let session: ProjectSession
    let status: SmartFillSessionStatus
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(session.type.rawValue) Session")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(session.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                if status.totalPortraitTakes == 0 {
                    Text("No Portrait Takes")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("\(status.smartFilledTakes)/\(status.totalPortraitTakes)")
                        .font(.caption)
                        .fontWeight(.medium)
                    
                    if status.needsProcessing {
                        Text("Pending")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    } else {
                        Text("Complete")
                            .font(.caption2)
                            .foregroundColor(.green)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

#Preview {
    let sampleRepository = ProjectsRepositoryFactory.makePreviewRepository()
    SmartFillBatchProcessingView(repository: sampleRepository)
}
