import SwiftUI
import AVFoundation

/// Integrated Export View with Drag & Drop Timeline
/// This demonstrates the timeline working with real export data
struct ExportTimelineIntegrated: View {
    let takes: [EnhancedTake]
    let project: Project
    let session: ProjectSession
    let repository: ProjectsRepository
    let onDismiss: () -> Void
    
    @State private var timeline = ExportTimeline(items: [])
    @State private var timelineInitialized = false
    @State private var exportOptions = ExportOptions()
    
    // Filter to final select takes only (matching existing logic)
    private var finalSelectTakes: [EnhancedTake] {
        takes.filter { take in
            // Skip merged videos and photos
            guard !take.fileName.contains("_Merged_") && !take.fileName.contains("Merged") else { return false }
            guard !take.fileName.lowercased().hasSuffix(".jpg") && !take.fileName.lowercased().hasSuffix(".jpeg") && !take.fileName.lowercased().hasSuffix(".png") else { return false }
            
            // Find corresponding project take
            if let projectTake = session.takes.first(where: { projectTake in
                projectTake.filePath == take.filePath ||
                projectTake.filePath.hasSuffix(take.fileName) ||
                URL(fileURLWithPath: projectTake.filePath).lastPathComponent == take.fileName
            }) {
                return projectTake.isExportSelected && (projectTake.takeType == .regular || projectTake.takeType.isSlateLike)
            }
            return false
        }
    }
    
    // Get included items from timeline
    private var includedItems: [ExportItem] {
        timeline.items.filter { $0.included }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Header
                        VStack(spacing: 12) {
                            Image(systemName: "film.fill")
                                .font(.system(size: 50))
                                .foregroundStyle(.pink)
                            
                            VStack(spacing: 6) {
                                if includedItems.isEmpty && timelineInitialized {
                                    Text("No Takes Selected")
                                        .font(.title3)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.red)
                                    
                                    Text("Tap thumbnails to include takes in export")
                                        .font(.subheadline)
                                        .foregroundStyle(.gray)
                                        .multilineTextAlignment(.center)
                                } else if timelineInitialized {
                                    Text("\(includedItems.count) \(TakeRating.finalSelect.displayName) Takes Ready")
                                        .font(.title3)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.white)
                                    
                                    Text("🎬 NEW: Drag to reorder export sequence")
                                        .font(.subheadline)
                                        .foregroundStyle(.pink)
                                        .multilineTextAlignment(.center)
                                } else {
                                    Text("Loading...")
                                        .font(.title3)
                                        .foregroundStyle(.gray)
                                }
                            }
                        }
                        .padding(.top, 20)
                        
                        // Status
                        VStack(spacing: 12) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "star.circle.fill")
                                            .foregroundStyle(.yellow)
                                            .font(.caption)
                                        Text("Exporting: \(includedItems.count) takes")
                                            .font(.caption)
                                            .foregroundStyle(.white)
                                    }
                                    
                                    let excludedCount = timeline.items.count - includedItems.count
                                    if excludedCount > 0 {
                                        HStack(spacing: 8) {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundStyle(.red)
                                                .font(.caption)
                                            Text("Skipping: \(excludedCount) takes")
                                                .font(.caption)
                                                .foregroundStyle(.gray)
                                        }
                                    }
                                }
                                Spacer()
                            }
                            
                            Text("💡 NEW FEATURE: Drag to reorder • Tap to include/exclude • Drag slate to end for 'tail slate'")
                                .font(.caption2)
                                .foregroundStyle(.pink)
                                .multilineTextAlignment(.center)
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.white.opacity(0.05))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                )
                        )
                        .padding(.horizontal, 24)
                        
                        // 🎬 THE NEW TIMELINE!
                        if timelineInitialized && !timeline.items.isEmpty {
                            VStack(spacing: 16) {
                                Text("🎬 DRAG & DROP TIMELINE")
                                    .font(.headline)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.pink)
                                
                                Text("This replaces the static Take 1, Take 2, Slate badges!")
                                    .font(.caption)
                                    .foregroundStyle(.gray)
                                    .multilineTextAlignment(.center)
                                
                                ExportTimelineStrip(items: $timeline.items)
                                    .frame(height: 120)
                                
                                // Show export order
                                if !includedItems.isEmpty {
                                    VStack(spacing: 8) {
                                        Text("Export Order:")
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                            .foregroundStyle(.white)
                                        
                                        VStack(alignment: .leading, spacing: 4) {
                                            ForEach(includedItems.indices, id: \.self) { index in
                                                let item = includedItems[index]
                                                HStack {
                                                    Text("\(index + 1).")
                                                        .foregroundStyle(.gray)
                                                        .frame(width: 20, alignment: .leading)
                                                    Text(item.label)
                                                        .foregroundStyle(.white)
                                                    Spacer()
                                                    Text(item.duration.asClockString)
                                                        .foregroundStyle(.gray)
                                                        .font(.caption)
                                                }
                                            }
                                        }
                                    }
                                    .padding()
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color.pink.opacity(0.1))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(Color.pink.opacity(0.3), lineWidth: 1)
                                            )
                                    )
                                }
                            }
                            .padding(.horizontal, 24)
                        }
                        
                        // Export Mode (Simplified - removed "Merged with Slate")
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Export Mode")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(.white)
                            
                            VStack(spacing: 6) {
                                // Only show Separate Files and Merged Video
                                ForEach([ExportMode.separateFiles, ExportMode.mergedVideo], id: \.self) { mode in
                                    Button(action: { exportOptions.mode = mode }) {
                                        HStack(spacing: 12) {
                                            Image(systemName: mode.icon)
                                                .font(.body)
                                                .foregroundStyle(exportOptions.mode == mode ? .pink : .white.opacity(0.6))
                                                .frame(width: 24)
                                            
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(mode.displayName)
                                                    .font(.subheadline)
                                                    .fontWeight(.medium)
                                                    .foregroundStyle(.white)
                                                
                                                Text(mode == .separateFiles ? "Export each take as individual files" : "Combine all takes into one video")
                                                    .font(.caption)
                                                    .foregroundStyle(.gray)
                                            }
                                            
                                            Spacer()
                                            
                                            if exportOptions.mode == mode {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .font(.body)
                                                    .foregroundStyle(.pink)
                                            }
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 10)
                                        .background(
                                            RoundedRectangle(cornerRadius: 10)
                                                .fill(exportOptions.mode == mode ? Color.pink.opacity(0.2) : Color.white.opacity(0.05))
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 10)
                                                        .stroke(exportOptions.mode == mode ? .pink : Color.white.opacity(0.1), lineWidth: 1)
                                                )
                                        )
                                    }
                                }
                                
                                // Show that Merged with Slate is now handled by timeline
                                VStack(spacing: 8) {
                                    HStack {
                                        Image(systemName: "arrow.up.arrow.down")
                                            .foregroundStyle(.pink)
                                        Text("\"Merged with Slate\" replaced by drag & drop!")
                                            .font(.caption)
                                            .foregroundStyle(.pink)
                                        Spacer()
                                    }
                                    Text("Simply drag the slate to wherever you want it in the timeline")
                                        .font(.caption2)
                                        .foregroundStyle(.gray)
                                        .multilineTextAlignment(.leading)
                                }
                                .padding(.horizontal, 12)
                            }
                        }
                        .padding(.horizontal, 24)
                    }
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("🎬 NEW Export Timeline")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Back") { onDismiss() }
                        .font(.body)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Export \(includedItems.count)") {
                        // This would call the actual export with timeline order
                        print("Would export in timeline order:")
                        includedItems.enumerated().forEach { index, item in
                            print("\(index + 1). \(item.label) - \(item.duration.asClockString)")
                        }
                    }
                    .font(.body)
                    .fontWeight(.semibold)
                    .disabled(includedItems.isEmpty)
                }
            }
        }
        .onAppear {
            initializeTimeline()
        }
    }
    
    private func initializeTimeline() {
        guard !timelineInitialized else { return }
        
        Task {
            var items: [ExportItem] = []
            
            for take in finalSelectTakes {
                do {
                    let videoURL = try VideoFileManager.shared.getVideoURL(for: take.fileName)
                    let asset = AVURLAsset(url: videoURL)
                    let duration = try await asset.load(.duration)
                    
                    let kind: ExportKind = take.isSlate ? .slate : .take
                    let label = take.isSlate ? "Slate" : "Take \(take.takeNumber)"
                    
                    let item = ExportItem(
                        url: videoURL,
                        kind: kind,
                        label: label,
                        duration: duration,
                        included: true
                    )
                    
                    items.append(item)
                } catch {
                    print("❌ Failed to create timeline item for \(take.fileName): \(error)")
                }
            }
            
            await MainActor.run {
                timeline.items = items
                timelineInitialized = true
                print("✅ Timeline initialized with \(items.count) items")
            }
        }
    }
}

// Quick test view
struct ExportTimelineIntegratedPreview: View {
    var body: some View {
        let sampleTakes = [
            EnhancedTake(
                fileName: "Take1.mov",
                projectID: UUID(),
                sessionID: UUID(),
                filePath: "/path/to/take1.mov",
                duration: 30.0,
                fileSize: 15_000_000,
                cameraPosition: "back",
                sceneNumber: 1,
                takeNumber: 1
            ),
            EnhancedTake(
                fileName: "Take2.mov",
                projectID: UUID(),
                sessionID: UUID(),
                filePath: "/path/to/take2.mov",
                duration: 45.0,
                fileSize: 20_000_000,
                cameraPosition: "back",
                sceneNumber: 1,
                takeNumber: 2
            ),
            EnhancedTake(
                fileName: "Slate.mov",
                projectID: UUID(),
                sessionID: UUID(),
                filePath: "/path/to/slate.mov",
                duration: 8.0,
                fileSize: 3_000_000,
                cameraPosition: "back",
                sceneNumber: 1,
                takeNumber: 0,
                isSlate: true
            )
        ]
        
        let sampleSession = ProjectSession(
            type: .selfTape,
            takes: [
                ProjectTake(filePath: "/path/to/take1.mov", durationSeconds: 30.0, rating: .finalSelect),
                ProjectTake(filePath: "/path/to/take2.mov", durationSeconds: 45.0, rating: .finalSelect),
                ProjectTake(filePath: "/path/to/slate.mov", durationSeconds: 8.0, rating: .finalSelect, takeType: .slate)
            ]
        )
        
        ExportTimelineIntegrated(
            takes: sampleTakes,
            project: Project(title: "Test Project"),
            session: sampleSession,
            repository: ProjectsRepositoryFactory.makePreviewRepository(),
            onDismiss: { print("Dismissed") }
        )
    }
}

#Preview {
    ExportTimelineIntegratedPreview()
}
