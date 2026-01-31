import SwiftUI
import AVFoundation

/// Professional export interface for Self Tape Studio
/// Provides export options and manages export workflow
/// SURGICAL FIX: Now uses SessionExportManager for professional quality export
///
/// KEYFRAME PHOTOS: Photos are excluded from video export and serve as thumbnail reference images only.
/// Video thumbnails are generated using the app's existing AVAssetImageGenerator-based thumbnail system,
/// following cross-platform best practices for iOS, Android, and PC compatibility.
struct ExportManagerView: View {@State private var exportFilename: String = ""
    @State private var exportThumbnail: UIImage? = nil
    @State private var selectedFormat: OutputFormat = .mp4
    @State private var showPreviewPhotoIntro: Bool = true
    @State private var lastAutoFilename: String = ""

    let takes: [EnhancedTake]
    let project: Project  // STEP 2B: Add direct project parameter
    let session: ProjectSession  // STEP 2B: Add direct session parameter
    let repository: ProjectsRepository  // CRITICAL FIX: Add repository parameter
    let onDismiss: () -> Void
    
    @EnvironmentObject private var themeManager: ThemeManager
    @StateObject private var exportEngine = ExportEngine.shared
    @StateObject private var exportResultsStore = ExportResultsStore()  // SWIFTUI FIX: Observable store for export data
    @State private var exportOptions = ExportOptions(mode: .mergedVideo, quality: .high)
    @State private var showingExportResults = false
    @State private var exportError: ExportEngineError?
    @State private var showingFilePicker = false
    @State private var estimatedFileSize: String = "Calculating..."
    
    // SURGICAL FIX: Add SessionExportManager progress tracking
    @State private var sessionExportProgress: Float = 0.0
    @State private var isSessionExporting = false
    @State private var currentExportOperation = ""
    
    // PERFORMANCE FIX: Cache final select takes to prevent infinite loop
    @State private var cachedGoodTakes: [EnhancedTake] = []
    @State private var cachedSkippedTakes: [EnhancedTake] = []
    @State private var takesProcessed = false
    @State private var separateFileNames: [UUID: String] = [:]
    
    // ENHANCED: Video marker export support
    @State private var videoMarkers: [String: [VideoMarker]] = [:]  // takeID -> markers
    @State private var loadingMarkers = false

    // DRAG & DROP TIMELINE: New state for timeline management
    @State private var timeline = ExportTimeline(items: [])
    @State private var timelineInitialized = false
    
    // PERFORMANCE FIX: Use cached computed properties instead of live computation
    private var goodTakes: [EnhancedTake] {
        return cachedGoodTakes
    }
    
    // DRAG & DROP TIMELINE: Convert final select takes to timeline items
private func initializeTimeline() {
    print("🔧 DEBUG: initializeTimeline() called - timelineInitialized=\(timelineInitialized), finalSelectTakes.count=\(goodTakes.count)")
    guard !timelineInitialized && !goodTakes.isEmpty else {
        print("🚫 DEBUG: Timeline init skipped - already initialized or no final select takes")
        return
    }
    
    print("📋 DEBUG: Processing \(goodTakes.count) final select takes for timeline")
    for (index, take) in goodTakes.enumerated() {
        print("  Take \(index): \(take.fileName) (slate: \(take.isSlate))")
    }
    
    Task {
        var items: [ExportItem] = []
        var successCount = 0
        var failureCount = 0
        let sourceTakes: [EnhancedTake] = timeline.items.isEmpty ? buildInitialOrderedIncludedTakes(from: goodTakes) : orderedIncludedTakes
        
        for take in sourceTakes {
            do {
                // Try to find the matching ProjectTake so we can ask for the best variant
                let matchingProjectTake = session.takes.first(where: { projectTake in
                    projectTake.filePath == take.filePath ||
                    projectTake.filePath.hasSuffix(take.fileName) ||
                    URL(fileURLWithPath: projectTake.filePath).lastPathComponent == take.fileName
                })

                // Start with the original capture URL
                var videoURL = try VideoFileManager.shared.getVideoURL(for: take.fileName)

                // If we have a ProjectTake, prefer the enhanced / SmartFill variant
                if let projectTake = matchingProjectTake {
                    let enhancedURL = VideoVariantResolver.effectiveURL(for: projectTake)
                    if FileManager.default.fileExists(atPath: enhancedURL.path) {
                        print("✅ TIMELINE: Using VideoVariantResolver URL for \(take.fileName): \(enhancedURL.lastPathComponent)")
                        videoURL = enhancedURL
                    } else {
                        print("⚠️ TIMELINE: Enhanced URL missing for \(take.fileName), falling back to original")
                    }
                } else {
                    print("⚠️ TIMELINE: No matching ProjectTake for \(take.fileName); using original capture URL")
                }

                let asset = AVURLAsset(url: videoURL)
                let duration = try await asset.load(.duration)
                let kind: ExportKind = take.isSlate ? .slate : .take
                let label = take.isSlate ? "Slate" : "Take \(take.takeNumber)"
                let item = ExportItem(url: videoURL, kind: kind, label: label, duration: duration, included: true)
                items.append(item)
                successCount += 1
                print("✅ DEBUG: Created timeline item for \(take.fileName) - \(label)")
            } catch {
                failureCount += 1
                print("❌ DEBUG: Failed to create timeline item for \(take.fileName): \(error)")
            }
        }
        await MainActor.run {
            timeline.items = items
            timelineInitialized = true
            print("🎯 DEBUG: Timeline initialized! \(items.count) items total (\(successCount) success, \(failureCount) failures)")
            print("📝 DEBUG: Timeline items: \(items.map { $0.label }.joined(separator: ", "))")
        }
    }
}
    
    private var skippedTakes: [EnhancedTake] {
        return cachedSkippedTakes
    }
    
    // SURGICAL FIX: Use SessionExportManager export status
    private var isExporting: Bool {
        return isSessionExporting || exportEngine.isExporting
    }
    
    private var exportProgress: Float {
        return isSessionExporting ? sessionExportProgress : exportEngine.exportProgress
    }
    
    private var exportOperationText: String {
        return isSessionExporting ? currentExportOperation : exportEngine.currentExportOperation
    }
    
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
    
    // PERFORMANCE FIX: Move take processing to onAppear with caching
    private func processTakes() {
        guard !takesProcessed else { return }
        
        var goodTakesList: [EnhancedTake] = []
        var skippedTakesList: [EnhancedTake] = []
        
        for take in takes {
            // FILTER: Skip merged videos - they shouldn't be re-exported
            if take.fileName.contains("_Merged_") || take.fileName.contains("Merged") {
                print("🚫 ExportManager: Skipping merged video \(take.fileName)")
                skippedTakesList.append(take)
                continue
            }
            
            // CRITICAL FIX: Skip keyframe photos - they are for thumbnail reference only, not video export
            // CORRECTION: Keyframe photos should be handled by AVAssetImageGenerator for thumbnail generation
            if take.fileName.lowercased().hasSuffix(".jpg") || take.fileName.lowercased().hasSuffix(".jpeg") || take.fileName.lowercased().hasSuffix(".png") {
                print("📸 ExportManager: Skipping keyframe photo \(take.fileName) - used for thumbnail reference only")
                skippedTakesList.append(take)
                continue
            }
            
            // Use the passed session data directly
            if let projectTake = session.takes.first(where: { projectTake in
                projectTake.filePath == take.filePath ||
                projectTake.filePath.hasSuffix(take.fileName) ||
                URL(fileURLWithPath: projectTake.filePath).lastPathComponent == take.fileName
            }) {
                print("🎯 Found ProjectTake for \(take.fileName): rating = \(projectTake.rating), takeType = \(projectTake.takeType)")
                
                // CRITICAL FIX: Include BOTH regular takes AND slates with final select ratings
                // ENHANCED: Only process actual video content (no photos)
                if projectTake.isExportSelected &&
                   (projectTake.takeType == .regular || projectTake.takeType.isSlateLike) {
                    goodTakesList.append(take)
                    print("✅ Including \(projectTake.takeType.displayName) video: \(take.fileName) (rating: \(projectTake.rating))")
                } else if projectTake.takeType == .merged {
                    print("🚫 ExportManager: Skipping merged video type \(take.fileName)")
                    skippedTakesList.append(take)
                } else {
                    print("🚫 ExportManager: Skipping take \(take.fileName) - rating: \(projectTake.rating), type: \(projectTake.takeType)")
                    skippedTakesList.append(take)
                }
            } else {
                print("❌ Could not find ProjectTake for \(take.fileName)")
                skippedTakesList.append(take)
            }
        }
        
        cachedGoodTakes = goodTakesList
        cachedSkippedTakes = skippedTakesList
        takesProcessed = true
        
        print("📊 Export processing complete: \(goodTakesList.count) final select video takes, \(skippedTakesList.count) skipped")
        print("📸 Note: Keyframe photos are excluded - they serve as thumbnail reference images")
        if !skippedTakesList.isEmpty {
            let skippedNames = skippedTakesList.map { $0.fileName }
            print("🚫 Skipped: \(skippedNames.joined(separator: ", "))")
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                theme.backgroundGradient
                    .ignoresSafeArea()
                accentGlow
                
                VStack(spacing: 0) {
                    if isExporting {
                        exportProgressView
                    } else {
                        exportConfigurationView
                    }
                }
            }
            .navigationTitle("Export Takes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        if isExporting {
                            // SURGICAL FIX: Cancel appropriate export process
                            if isSessionExporting {
                                SessionExportManager.cancelCurrentExport()
                                isSessionExporting = false
                            } else {
                                exportEngine.cancelExport()
                            }
                        }
                        onDismiss()
                    }
                    .font(.body)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Export") {
                        performExport()
                    }
                    .font(.body)
                    .fontWeight(.semibold)
                    .disabled(isExporting || goodTakes.isEmpty)
                }
            }
        }
        .sheet(isPresented: $showingExportResults) {
            // SWIFTUI FIX: Use ObservableObject store to avoid closure capture issues
            ExportResultsView(
                exportResultsStore: exportResultsStore,
                onDismiss: {
                    showingExportResults = false
                    exportResultsStore.clear() // Clear data when dismissed
                    onDismiss()
                }
            )
        }
        .alert("Export Error", isPresented: Binding(get: { exportError != nil }, set: { _ in exportError = nil })) {
            Button("OK") { exportError = nil }
        } message: {
            Text(exportError?.errorDescription ?? "Unknown error")
        }
        .onAppear {
            SessionManager.shared.ensureSingleFinalSelectKeyframePhoto(
                sessionID: session.id,
                projectID: project.id
            )
            processTakes()  // PERFORMANCE FIX: Cache takes processing on appear
            populateExportHeaderData()  // EXPORT HEADER FIX: Auto-populate filename and thumbnail
            initializeTimeline()  // DRAG & DROP TIMELINE: Initialize timeline
            calculateEstimatedFileSize()
            loadVideoMarkers()
            // STEP 2B: Debug logging
            print("🎬 ExportManager opened with \(takes.count) takes, \(session.takes.count) session takes")
            for (index, take) in takes.enumerated() {
                if let projectTake = session.takes.first(where: { pt in pt.filePath.hasSuffix(take.fileName) }) {
                    print("  Take \(index + 1): \(take.fileName) → rating: \(projectTake.rating)")
                }
            }
        }
        .onChange(of: exportOptions.quality, initial: false) { _, _ in
            calculateEstimatedFileSize()
        }
        .onChange(of: exportOptions.mode, initial: false) { _, newMode in
            calculateEstimatedFileSize()
            if newMode != .separateFiles {
                separateFileNames.removeAll()
            }
        }
        .onChange(of: timeline, initial: false) { _, _ in
            pruneSeparateFileNames()
            refreshAutoFilenameIfNeeded()
        }
    }
    
    // MARK: - Export Configuration View
    
    @ViewBuilder
    private var exportConfigurationView: some View {
        ScrollView {
            VStack(spacing: 20) {
                // FIXED: Better header spacing and sizing
                VStack(spacing: 12) {
                    Image(systemName: "film.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(Theme.primary)
                    
                    VStack(spacing: 6) {
                        if goodTakes.isEmpty {
                            Text("No Takes to Export")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundStyle(.red)
                            
                            Text("Only takes marked with ⭐ will be exported")
                                .font(.subheadline)
                                .foregroundStyle(.gray)
                                .multilineTextAlignment(.center)
                        } else {
                            Text("\(goodTakes.count) \(TakeRating.finalSelect.displayName) Takes Ready")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundStyle(.white)
                            
                            Text("Enhanced professional export")
                                .font(.subheadline)
                                .foregroundStyle(.gray)
                                .multilineTextAlignment(.center)
                        }
                    }
                }
                .padding(.top, 20)
                
                // STEP 2A: Show take filter status
                if !goodTakes.isEmpty || !skippedTakes.isEmpty {
                    takeFilterStatusView
                }
                
                // DRAG & DROP TIMELINE: Replace static preview with draggable timeline
                if timelineInitialized && !timeline.items.isEmpty {
                    VStack(spacing: 12) {
                        Text("🎬 Drag to reorder • Tap and hold to include/exclude")
                            .font(.caption)
                            .foregroundStyle(.pink)
                            .multilineTextAlignment(.center)
                        
                        ExportTimelineStrip(items: $timeline.items)
                    }
                    .frame(height: 120)
                }
                
                // EXPORT HEADER: Filename + Thumbnail Preview (above Export Mode)
                if !goodTakes.isEmpty {
                    exportHeaderView
                        .padding(.horizontal, 24)
                }
                // Export options - only show if we have final select takes
                if !goodTakes.isEmpty {
                    exportOptionsView
                }
                
                if exportOptions.mode == .separateFiles,
                   !orderedIncludedTakes.isEmpty {
                    separateFileNamingView
                        .padding(.horizontal, 24)
                }
                
                // Estimated file size
                if !goodTakes.isEmpty {
                    estimatedFileSizeView
                }
            }
            .padding(.bottom, 32)
        }
    }
    
    // STEP 2A: Take filter status view
    @ViewBuilder
    private var takeFilterStatusView: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Image(systemName: "star.circle.fill")
                            .foregroundStyle(.yellow)
                            .font(.caption)
                        Text("Exporting: \(goodTakes.count) takes")
                            .font(.caption)
                            .foregroundStyle(.white)
                    }
                    
                    if !skippedTakes.isEmpty {
                        HStack(spacing: 8) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.red)
                                .font(.caption)
                            Text("Skipping: \(skippedTakes.count) takes")
                                .font(.caption)
                                .foregroundStyle(.gray)
                        }
                    }
                }
                
                Spacer()
            }
            
            if !skippedTakes.isEmpty {
                Text("💡 Tip: Mark takes with ⭐ to include them in export")
                    .font(.caption2)
                    .foregroundStyle(.gray)
                    .multilineTextAlignment(.center)
            }
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
    }
    
    // FIXED: Smaller font sizes for export options
    @ViewBuilder
    private var exportOptionsView: some View {
        VStack(spacing: 16) {
            // Export mode
            ExportOptionSection(title: "Export Mode") {
                VStack(spacing: 6) {
                    ForEach(ExportMode.allCases, id: \.self) { mode in
                        ExportModeRow(
                            mode: mode,
                            isSelected: exportOptions.mode == mode
                        ) {
                            exportOptions.mode = mode
                        }
                    }
                }
            }
            
            // Quality settings
            ExportOptionSection(title: "Quality") {
                VStack(spacing: 6) {
                    ForEach(ExportQuality.allCases, id: \.self) { quality in
                        ExportQualityRow(
                            quality: quality,
                            isSelected: exportOptions.quality == quality
                        ) {
                            exportOptions.quality = quality
                        }
                    }
                }
            }
            
            // File format
            ExportOptionSection(title: "Format") {
                HStack(spacing: 10) {
                    ForEach(OutputFormat.allCases, id: \.self) { format in
                        Button(action: { exportOptions.outputFormat = format }) {
                            HStack(spacing: 6) {
                                Text(format.displayName)
                                    .font(.subheadline)
                                
                                if exportOptions.outputFormat == format {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(Theme.primary)
                                        .font(.caption)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(exportOptions.outputFormat == format ? Theme.primary.opacity(0.2) : Color.white.opacity(0.1))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(exportOptions.outputFormat == format ? Theme.primary : Color.white.opacity(0.2), lineWidth: 1)
                                    )
                            )
                        }
                        .foregroundStyle(.white)
                    }
                    
                    Spacer()
                }
            }
            
        }
        .padding(.horizontal, 24)
    }
    
    @ViewBuilder
    private var estimatedFileSizeView: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Estimated Size:")
                    .font(.subheadline)
                    .foregroundStyle(.gray)
                
                Spacer()
                
                Text(estimatedFileSize)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 24)
            
            if exportOptions.mode != .separateFiles {
                Text("Merged video may be smaller due to compression")
                    .font(.caption)
                    .foregroundStyle(.gray)
                    .padding(.horizontal, 24)
            }
        }
    }

    @ViewBuilder
    private var separateFileNamingView: some View {
        ExportOptionSection(title: "Separate File Names") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Customize each exported file name. Leave blank to use the automatic naming pattern.")
                    .font(.caption)
                    .foregroundStyle(.gray)
                ForEach(Array(orderedIncludedTakes.enumerated()), id: \.element.id) { index, take in
                    separateFileNameRow(for: take, index: index)
                }
            }
        }
    }
    
    @ViewBuilder
    private func separateFileNameRow(for take: EnhancedTake, index: Int) -> some View {
        let placeholder = autoSeparateNames[take.id] ?? defaultSeparateFilename(for: index)
        let binding = Binding<String>(
            get: { separateFileNames[take.id] ?? "" },
            set: { newValue in
                let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty {
                    separateFileNames.removeValue(forKey: take.id)
                } else {
                    separateFileNames[take.id] = trimmed
                }
            }
        )
        let extensionLabel = exportOptions.outputFormat.fileExtension
        
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(takeDisplayName(for: take))
                    .font(.subheadline)
                    .foregroundStyle(.white)
                Spacer()
                Text(take.formattedDuration)
                    .font(.caption)
                    .foregroundStyle(.gray)
            }
            
            HStack(spacing: 8) {
                TextField("", text: binding, prompt: Text(placeholder).foregroundStyle(.gray))
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.white.opacity(0.05))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
                            )
                    )
                    .foregroundStyle(.white)
                
                Text(".\(extensionLabel)")
                    .font(.subheadline)
                    .foregroundStyle(.gray)
            }
            
            Text("Default: \(placeholder).\(extensionLabel)")
                .font(.caption2)
                .foregroundStyle(.gray)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Export Progress View
    
    @ViewBuilder
    private var exportProgressView: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Progress animation
            VStack(spacing: 24) {
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.2), lineWidth: 8)
                        .frame(width: 120, height: 120)
                    
                    Circle()
                        .trim(from: 0, to: CGFloat(exportProgress))
                        .stroke(Theme.primary, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .frame(width: 120, height: 120)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut, value: exportProgress)
                    
                    VStack(spacing: 4) {
                        Text("\(Int(exportProgress * 100))%")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                        
                        Text("Exporting")
                            .font(.caption)
                            .foregroundStyle(.gray)
                    }
                }
                
                VStack(spacing: 8) {
                    Text(exportOperationText)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                    
                    if !exportOperationText.isEmpty {
                        Text("Please wait while we process your takes...")
                            .font(.body)
                            .foregroundStyle(.gray)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal, 40)
            }
            
            Spacer()
            
            // Cancel button
            Button("Cancel Export") {
                if isSessionExporting {
                    SessionExportManager.cancelCurrentExport()
                    isSessionExporting = false
                } else {
                    exportEngine.cancelExport()
                }
                onDismiss()
            }
            .font(.body)
            .foregroundStyle(.red)
            .padding(.bottom, 32)
        }
    }

    // ENHANCED: Video marker loading and summary
    private var hasVideoMarkers: Bool {
        !videoMarkers.isEmpty
    }
    
    private var totalMarkerCount: Int {
        videoMarkers.values.reduce(0) { $0 + $1.count }
    }
    
    @ViewBuilder
    private var markerSummaryView: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "flag.filled.and.flag.crossed")
                    .font(.title2)
                    .foregroundStyle(.orange)
                
                Text("\(totalMarkerCount) markers across \(videoMarkers.count) takes")
                    .font(.body)
                    .foregroundStyle(.white)
                
                Spacer()
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(videoMarkers.keys), id: \.self) { takeID in
                        if let markers = videoMarkers[takeID],
                           let take = takes.first(where: { $0.id.uuidString == takeID }) {
                            MarkerPreviewBadge(take: take, markers: markers)
                        }
                    }
                }
                .padding(.horizontal, 4)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.orange.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    // ENHANCED: Load video markers for all takes
    private func loadVideoMarkers() {
        loadingMarkers = true
        
        Task { @MainActor in
            var loadedMarkers: [String: [VideoMarker]] = [:]
            
            for take in takes {
                // STEP 2B: Use passed session data directly instead of SessionManager
                if let projectTake = session.takes.first(where: { projectTake in
                    projectTake.filePath == take.filePath ||
                    projectTake.filePath.hasSuffix(take.fileName) ||
                    URL(fileURLWithPath: projectTake.filePath).lastPathComponent == take.fileName
                }) {
                    // Convert TakeVideoMarkers to VideoMarkers
                    let markers = projectTake.videoMarkers.map { takeMarker in
                        VideoMarker(
                            timestamp: takeMarker.timestamp,
                            title: takeMarker.title,
                            description: takeMarker.description,
                            type: VideoMarker.MarkerType(rawValue: takeMarker.type.rawValue) ?? .note
                        )
                    }
                    
                    if !markers.isEmpty {
                        loadedMarkers[take.id.uuidString] = markers
                    }
                }
            }
            
            videoMarkers = loadedMarkers
            loadingMarkers = false
            
            // Update export options to include markers by default if any exist
            if hasVideoMarkers && !exportOptions.includeVideoMarkers {
                exportOptions.includeVideoMarkers = true
            }
            
            print("📍 ExportManager: Loaded markers for \(videoMarkers.count) takes")
        }
    }// SURGICAL FIX: Replace ExportEngine call with SessionExportManager
// MARK: - Export Dispatch
private func performExport() {
    switch exportOptions.mode {
    case .mergedVideo:
        performMergedExportUsingSessionExportManager()
    case .separateFiles:
        performSeparateFilesExportUsingExportEngine()
    }
}

// Existing merged export path kept intact
private func performMergedExportUsingSessionExportManager() {

    print("🚀 SURGICAL FIX: Using SessionExportManager instead of ExportEngine")
    print("🚀 ExportManager: Starting export with \(goodTakes.count) final select takes")
    print("🚀 ExportManager: Final select takes: \(goodTakes.map { $0.fileName }.joined(separator: ", "))")
    
    // 🎯 TIMELINE ORDER FIX: Use reordered timeline items instead of original goodTakes
    let orderedTimelineItems = timeline.items.filter { $0.included }
    print("🎬 TIMELINE ORDER: Export will use \(orderedTimelineItems.count) timeline items in user order:")
    for (index, item) in orderedTimelineItems.enumerated() {
        print("  Position \(index + 1): \(item.label) (\(item.url.lastPathComponent))")
    }

    // SURGICAL FIX: Convert to SessionExportManager format
    isSessionExporting = true
    sessionExportProgress = 0.0
    currentExportOperation = "Preparing export..."
    
    Task {
        do {
            // STEP 1: Convert timeline items to SessionExportManager.TakeMetadata IN USER ORDER
            let takeMetadataList: [SessionExportManager.TakeMetadata] = try await convertTimelineItemsToTakeMetadata(orderedTimelineItems)
            
            // STEP 3: Convert export options to SessionExportManager format
            var mergedExportOptions = exportOptions
            mergedExportOptions.includeSlate = false
            let sessionExportOptions = convertToSessionExportOptions(mergedExportOptions)
            
            // STEP 4: Generate professional output filename
            let outputFileName = generateOutputFileName()
            
            await MainActor.run {
                currentExportOperation = "Starting SessionExportManager export..."
            }
            
            print("✅ SURGICAL FIX: Calling SessionExportManager.exportMergedAudition with \(takeMetadataList.count) items in timeline order")
            

            // 🖼️ Create thumbnail metadata and keyframe photo URL
            var thumbnailMetadata: [AVMetadataItem] = []
            var keyframePhotoURL: URL? = nil

            if showPreviewPhotoIntro {
                if let thumbnail = exportThumbnail {
                    print("🖼️ DEBUG: Creating thumbnail metadata for export (photo intro enabled)")
                    thumbnailMetadata = createThumbnailMetadata(from: thumbnail)
                } else {
                    print("⚠️ DEBUG: Photo intro enabled but no exportThumbnail available")
                }

                keyframePhotoURL = resolvedKeyframePhotoURL()
            } else {
                // When the photo intro is disabled, do NOT embed the still photo as artwork.
                // The system and in-app thumbnail generators should use video frames instead.
                thumbnailMetadata = []
                keyframePhotoURL = nil
                print("ℹ️ Photo intro disabled – skipping thumbnail artwork metadata")
            }

            if let repoKeyframeURL = keyframePhotoURL {
                print("🖼️ DEBUG: Using keyframe intro photo \(repoKeyframeURL.lastPathComponent)")
            } else {
                print("⚠️ DEBUG: Preview photo intro disabled or no keyframe photo available")
            }

            // STEP 5: Call SessionExportManager with all the sophisticated features
            SessionExportManager.exportMergedAudition(
                from: takeMetadataList,
                outputFileName: outputFileName,
                options: sessionExportOptions,
                pipSlateSession: nil,
                thumbnailMetadata: thumbnailMetadata,
                keyframePhotoURL: keyframePhotoURL,
                progressHandler: { progress in
                    DispatchQueue.main.async {
                        self.sessionExportProgress = progress
                        self.currentExportOperation = "Processing with SessionExportManager... \(Int(progress * 100))%"
                    }
                }
            ) { result in
                DispatchQueue.main.async {
                    self.isSessionExporting = false
                    
                    switch result {
                    case .success(let outputURL):
                        print("✅ SURGICAL FIX: SessionExportManager export SUCCESS")
                        self.handleSessionExportSuccess(outputURL: outputURL)
                        
                    case .failure(let error):
                        print("❌ SURGICAL FIX: SessionExportManager export FAILURE - \(error.localizedDescription)")
                        self.exportError = ExportEngineError.processingFailed(error.localizedDescription)
                    }
                }
            }
            
        } catch {
            await MainActor.run {
                self.isSessionExporting = false
                self.exportError = ExportEngineError.processingFailed("SessionExportManager preparation failed: \(error.localizedDescription)")
                print("❌ SURGICAL FIX: SessionExportManager preparation failed - \(error)")
            }
        }
    }
}

// New: separate-files export path using ExportEngine
private func performSeparateFilesExportUsingExportEngine() {
    print("🚀 SEPARATE: Using ExportEngine for per-take export")
    
    // Respect user timeline order and include toggles
    let orderedItems = timeline.items.filter { $0.included }
    guard !orderedItems.isEmpty else {
        self.exportError = .processingFailed("No takes selected for export.")
        return
    }
    
    // Map timeline items -> EnhancedTake (by filename)
    let orderedEnhancedTakes: [EnhancedTake] = orderedIncludedTakes
    if orderedEnhancedTakes.isEmpty {
        self.exportError = .processingFailed("Could not resolve selected takes.")
        return
    }
    
    // Build UnifiedTake list for engine
    let unified: [UnifiedTake] = orderedEnhancedTakes.map { UnifiedTake(from: $0) }
    
    // Ensure markers are passed when present
    var engineOptions = exportOptions
    engineOptions.customBaseFilename = resolvedExportBaseFilename()
    let keyframePhotoURL = showPreviewPhotoIntro ? resolvedKeyframePhotoURL() : nil
    engineOptions.keyframePhotoURL = keyframePhotoURL
    engineOptions.keyframeIntroDuration = keyframePhotoURL != nil ? 0.55 : nil
    
    var customNames: [UUID: String] = autoSeparateNames

    // Manual overrides from the Separate File Names UI take precedence
    for take in orderedEnhancedTakes {
        guard var raw = separateFileNames[take.id]?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty else { continue }
        if raw.last == "." {
            raw.removeLast()
        }
        raw = (raw as NSString).deletingPathExtension

        let sanitized = sanitizeFilenameComponent(raw)
        if !sanitized.isEmpty {
            customNames[take.id] = sanitized
        }
    }

    engineOptions.customSeparateFilenames = customNames.isEmpty ? nil : customNames
    
    if let keyframePhotoURL {
        print("🖼️ SEPARATE EXPORT: Using keyframe intro photo \(keyframePhotoURL.lastPathComponent)")
    } else {
        print("⚠️ SEPARATE EXPORT: No keyframe intro photo available")
    }
    
    if hasVideoMarkers { engineOptions.includeVideoMarkers = true; engineOptions.videoMarkers = videoMarkers }
    
    // Start ExportEngine job
    exportEngine.exportTakes(unified, options: engineOptions) { result in
        DispatchQueue.main.async {
            switch result {
            case .success(let files):
                print("✅ ExportEngine completed with \(files.count) file(s)")
                self.handleExportEngineSuccess(files: files)
            case .failure(let err):
                print("❌ ExportEngine failed: \(err)")
                self.exportError = err
            }
        }
    }
}

// ExportEngine success -> present results view
private func handleExportEngineSuccess(files: [ExportedFile]) {
    exportResultsStore.setExportResults(
        files: files,
        project: project,
        session: session,
        originalTakes: goodTakes,
        repository: repository
    )
    showingExportResults = true
}

// CORRECTED: Only processes video takes - keyframe photos are for thumbnail reference only
private func convertToTakeMetadata(_ enhancedTakes: [EnhancedTake]) async throws -> [SessionExportManager.TakeMetadata] {
    var takeMetadataList: [SessionExportManager.TakeMetadata] = []
    
    for enhancedTake in enhancedTakes {
        do {
            // CRITICAL FIX: Only process video files - photos are filtered out in processTakes()
            let videoURL = try VideoFileManager.shared.getVideoURL(for: enhancedTake.fileName)
            // MODERNIZED: Use AVURLAsset instead of deprecated AVAsset(url:)
            let asset = AVURLAsset(url: videoURL)
            
            print("🎬 Loaded video asset: \(enhancedTake.fileName)")
            
            // Find corresponding ProjectTake for Smart Fill data
            let projectTake = session.takes.first { projectTake in
                projectTake.filePath == enhancedTake.filePath ||
                projectTake.filePath.hasSuffix(enhancedTake.fileName) ||
                URL(fileURLWithPath: projectTake.filePath).lastPathComponent == enhancedTake.fileName
            }
            
            let trimRange: CMTimeRange?
            if let metadata = projectTake?.editMetadata,
               metadata.hasTrimming,
               let start = metadata.trimStartTime,
               let end = metadata.trimEndTime,
               end > start {
                let startTime = CMTime(seconds: start, preferredTimescale: 600)
                let duration = CMTime(seconds: end - start, preferredTimescale: 600)
                trimRange = CMTimeRange(start: startTime, duration: duration)
            } else {
                trimRange = nil
            }
            
            let takeMetadata = SessionExportManager.TakeMetadata(
                asset: asset,
                isFinalSelect: true, // All takes in goodTakes are already filtered to be final select
                trimRange: trimRange,
                cropRect: projectTake?.editMetadata?.cropRect,
                cropRotationDegrees: projectTake?.editMetadata?.cropRotationDegrees,
                isSlatePhoto: false, // CORRECTION: No photos are processed here anymore
                thumbnailImage: nil, // CORRECTION: Thumbnails generated by AVAssetImageGenerator from video
                takeNumber: enhancedTake.takeNumber,
                fileName: enhancedTake.fileName,
                projectTake: projectTake
            )
            
            takeMetadataList.append(takeMetadata)
            print("✅ Converted \(enhancedTake.fileName) to TakeMetadata (isFinalSelect: true, video only)")
            
        } catch {
            print("❌ Failed to convert \(enhancedTake.fileName) to TakeMetadata: \(error)")
            throw error
        }
    }
    
    print("🎯 SessionExportManager will process \(takeMetadataList.count) video takes only")
    print("📸 Keyframe photos remain as separate reference images for thumbnail generation")
    
    return takeMetadataList
}

// 🎯 TIMELINE ORDER FIX: Convert timeline items to SessionExportManager.TakeMetadata in user order
private func convertTimelineItemsToTakeMetadata(_ timelineItems: [ExportItem]) async throws -> [SessionExportManager.TakeMetadata] {
    var takeMetadataList: [SessionExportManager.TakeMetadata] = []
    
    print("🎬 TIMELINE CONVERTER: Converting \(timelineItems.count) timeline items to metadata")
    
    for (index, item) in timelineItems.enumerated() {
        // Create asset from the timeline item URL (already resolved)
        let asset = AVURLAsset(url: item.url)
        
        let fileName = item.url.lastPathComponent
        
        print("🎬 Timeline item \(index + 1): \(item.label) -> \(fileName)")
        
        // 🚨 CONSERVATIVE DEBUG: Log original export behavior
        print("🔍 ORIGINAL EXPORT: item.url = \(item.url.path)")
        print("🔍 ORIGINAL EXPORT: File exists = \(FileManager.default.fileExists(atPath: item.url.path))")
        print("🔍 ORIGINAL EXPORT: Asset created for \(fileName)")
        
        // Find corresponding ProjectTake for metadata by filename
        let projectTake = session.takes.first { projectTake in
            projectTake.filePath.hasSuffix(fileName) ||
            URL(fileURLWithPath: projectTake.filePath).lastPathComponent == fileName
        }
        
        // 🚨 SMART ENHANCEMENT: Try to get better video file if projectTake exists
        var finalAsset = asset  // Start with original asset
        
        if let projectTake = projectTake {
            // Try VideoVariantResolver for edited/smartfill versions
            let enhancedURL = VideoVariantResolver.effectiveURL(for: projectTake)
            if FileManager.default.fileExists(atPath: enhancedURL.path) {
                finalAsset = AVURLAsset(url: enhancedURL)
                print("✅ ENHANCEMENT: Using VideoVariantResolver URL: \(enhancedURL.lastPathComponent)")
            } else {
                print("⚠️ ENHANCEMENT: VideoVariantResolver URL not found, using original")
            }
        } else {
            print("⚠️ ENHANCEMENT: No ProjectTake found, using original asset")
        }
        // Extract take number from label or use index
        var takeNumber = index + 1
        if item.kind == .slate {
            takeNumber = 0 // Slates typically use takeNumber 0
        } else if item.label.contains("Take ") {
            // Try to extract take number from label like "Take 1"
            let components = item.label.components(separatedBy: " ")
            if components.count >= 2, let extractedNumber = Int(components[1]) {
                takeNumber = extractedNumber
            }
        }
        
        let trimRange: CMTimeRange?
        if let projectTake = projectTake,
           let metadata = projectTake.editMetadata,
           metadata.hasTrimming,
           let start = metadata.trimStartTime,
           let end = metadata.trimEndTime,
           end > start {
            let startTime = CMTime(seconds: start, preferredTimescale: 600)
            let duration = CMTime(seconds: end - start, preferredTimescale: 600)
            trimRange = CMTimeRange(start: startTime, duration: duration)
        } else {
            trimRange = nil
        }
        
        let takeMetadata = SessionExportManager.TakeMetadata(
            asset: finalAsset,
            isFinalSelect: true, // All timeline items are already filtered to included ones
            trimRange: trimRange,
            cropRect: projectTake?.editMetadata?.cropRect,
            cropRotationDegrees: projectTake?.editMetadata?.cropRotationDegrees,
            isSlatePhoto: false, // Only video items in timeline
            thumbnailImage: nil, // Thumbnails generated by AVAssetImageGenerator
            takeNumber: takeNumber,
            fileName: fileName,
            projectTake: projectTake
        )
        
        takeMetadataList.append(takeMetadata)
        print("✅ Timeline item \(index + 1) converted: \(item.label) -> TakeMetadata (takeNumber: \(takeNumber))")
    }
    
    print("🎯 TIMELINE CONVERTER: Successfully converted \(takeMetadataList.count) timeline items to metadata in user order")
    return takeMetadataList
}
    
    // SURGICAL FIX: Convert ExportOptions to SessionExportManager.ExportOptions
    private func convertToSessionExportOptions(_ options: ExportOptions) -> SessionExportManager.ExportOptions {
        // Map quality levels
        let sessionQuality: SessionExportManager.ExportQuality
        switch options.quality {
        case .low:
            sessionQuality = .low
        case .medium:
            sessionQuality = .medium
        case .high:
            sessionQuality = .high
        case .maximum:
            sessionQuality = .maximum
        }
        
        // Map format
        let sessionFormat: SessionExportManager.ExportFormat
        switch options.outputFormat {
        case .mov:
            sessionFormat = .mov
        case .mp4:
            sessionFormat = .mp4
        }
        
        return SessionExportManager.ExportOptions(
            quality: sessionQuality,
            format: sessionFormat,
            includeSlate: options.includeSlate,
            slateDuration: options.includeSlate ? SessionExportManager.ExportOptions.defaultOptions.slateDuration : 0,
            includeAudio: true,
            renderSize: CGSize(width: 1920, height: 1080)
        )
    }
    
    // SURGICAL FIX: Use user-edited filename with format extension

    private func resolvedKeyframePhotoURL() -> URL? {
        if let repoProject = repository.project(by: project.id),
           let repoSession = repoProject.sessions.first(where: { $0.id == session.id }),
           let repoURL = repoSession.keyframeThumbnailPhotoURL {
        return repoURL
        }
        return session.keyframeThumbnailPhotoURL
    }

    /// Generate a unique filename inside the STS_Exports directory.
    /// If `base.ext` already exists, create `base_2.ext`, `base_3.ext`, etc.
    private func generateUniqueOutputFilename(base: String, format: OutputFormat) -> String {
        let ext = format.rawValue.lowercased()
        let baseNoExt = (base as NSString).deletingPathExtension
        let sanitizedBase = sanitizeFilenameComponent(baseNoExt)
        let safeBase = sanitizedBase.isEmpty
            ? sanitizeFilenameComponent(autoGeneratedBaseFilename())
            : sanitizedBase

        let fm = FileManager.default
        let documentsURL = fm.urls(for: .documentDirectory, in: .userDomainMask).first!
        let exportsURL = documentsURL.appendingPathComponent("STS_Exports")

        // Ensure the directory exists
        try? fm.createDirectory(at: exportsURL, withIntermediateDirectories: true)

        // Candidate filename
        var candidate = "\(safeBase).\(ext)"
        var counter = 2

        // Bump suffix until unused
        while fm.fileExists(atPath: exportsURL.appendingPathComponent(candidate).path) {
            candidate = "\(safeBase)_\(counter).\(ext)"
            counter += 1
        }

        print("🔧 DEBUG: Unique export filename resolved: \(candidate)")
        return candidate
    }

    private func generateOutputFileName() -> String {
        let format = selectedFormat

        // Determine the visible base name (either user-edited or default)
        let base: String
        if !exportFilename.isEmpty {
            base = (exportFilename as NSString).deletingPathExtension
            print("🔧 DEBUG: Using user-edited filename base: \(base)")
        } else {
            base = defaultMergedFilenameBase()
            print("🔧 DEBUG: Using auto-generated filename base: \(base)")
        }

        // IMPORTANT: ensure uniqueness on disk
        let uniqueFilename = generateUniqueOutputFilename(base: base, format: format)

        print("🔧 DEBUG: Final merged export filename: \(uniqueFilename)")
        return uniqueFilename
    }

private var orderedIncludedTakes: [EnhancedTake] {
    let includedItems = timeline.items.filter { $0.included }
    
    return includedItems.compactMap { item in
        let timelineName = item.url.lastPathComponent

        // Exact/path matches first
        if let exact = goodTakes.first(where: { take in
            take.fileName == timelineName ||
            take.filePath == item.url.path ||
            URL(fileURLWithPath: take.filePath).lastPathComponent == timelineName
        }) {
            return exact
        }

        // Fallback: match by capture basename ignoring variant suffixes
        let timelineBase = URL(fileURLWithPath: timelineName)
            .deletingPathExtension()
            .lastPathComponent

        if let byBase = goodTakes.first(where: { take in
            let captureName = URL(fileURLWithPath: take.filePath).lastPathComponent
            let captureBase = URL(fileURLWithPath: captureName)
                .deletingPathExtension()
                .lastPathComponent
            return captureBase == timelineBase
        }) {
            print("🔗 ExportManager: Fallback-mapped timeline item '\(timelineName)' → take '\(byBase.fileName)'")
            return byBase
        }

        print("⚠️ ExportManager: Could not map timeline item '\(timelineName)' to any EnhancedTake")
        return nil
    }
}

    private func refreshAutoFilenameIfNeeded() {
        let newAuto = defaultMergedFilenameBase()
        if exportFilename.isEmpty || exportFilename == lastAutoFilename {
            exportFilename = newAuto
        }
        lastAutoFilename = newAuto
    }

    private var autoSeparateNames: [UUID: String] {
        let timelineTakes = orderedIncludedTakes.isEmpty ? buildInitialOrderedIncludedTakes(from: goodTakes) : orderedIncludedTakes
        return buildSeparateAutoNames(for: timelineTakes)
    }

    // MARK: - Initial timeline ordering
    private func buildInitialOrderedIncludedTakes(from allEnhancedTakes: [EnhancedTake]) -> [EnhancedTake] {
        let slates = allEnhancedTakes.filter { $0.isSlate }
        let nonSlates = allEnhancedTakes.filter { !$0.isSlate }
        
        let sortedSlates = slates.sorted { lhs, rhs in
            let l = lhs.takeNumber
            let r = rhs.takeNumber
            if l != r { return l < r }
            return lhs.id.uuidString < rhs.id.uuidString
        }
        
        let sortedNonSlates = nonSlates.sorted { lhs, rhs in
            let ls = lhs.sceneNumber
            let rs = rhs.sceneNumber
            if ls != rs { return ls < rs }
            
            let lt = lhs.takeNumber
            let rt = rhs.takeNumber
            if lt != rt { return lt < rt }
            
            return lhs.id.uuidString < rhs.id.uuidString
        }
        
        return sortedSlates + sortedNonSlates
    }

    private func defaultSeparateFilename(for index: Int) -> String {
        let base = resolvedExportBaseFilename()
        return index == 0 ? base : "\(base)\(index + 1)"
    }

    private func takeDisplayName(for take: EnhancedTake) -> String {
        if take.isSlate {
            return "Slate • Take \(take.takeNumber)"
        } else {
            let sceneNumber = resolvedSceneNumber(for: take)
            return "Scene \(sceneNumber) • Take \(take.takeNumber)"
        }
    }
    
    private func pruneSeparateFileNames() {
        let validIDs = Set(orderedIncludedTakes.map { $0.id })
        separateFileNames = separateFileNames.filter { validIDs.contains($0.key) }
    }

    // MARK: - Scene/Take suffix builder

    /// Builds ordered take tokens like ["S1T1","S1T2","S2T1"], skipping slates.
    private func buildSceneTakeTokens<T: Collection>(for enhancedTakes: T) -> [String] where T.Element == EnhancedTake {
        var perSceneCounters: [Int: Int] = [:]
        var segments: [String] = []

        for take in enhancedTakes {
            if take.isSlate { continue }

            let sceneNumber = resolvedSceneNumber(for: take)
            let nextCount = (perSceneCounters[sceneNumber] ?? 0) + 1
            perSceneCounters[sceneNumber] = nextCount

            segments.append("S\(sceneNumber)T\(nextCount)")
        }

        return segments
    }

    // MARK: - Scene / Take resolution helpers

    /// Resolves the authoritative scene number for a given EnhancedTake
    /// by consulting the backing ProjectTake in this session when possible.
    private func resolvedSceneNumber(for take: EnhancedTake) -> Int {
        if let projectTake = session.takes.first(where: { projectTake in
            projectTake.filePath == take.filePath ||
            URL(fileURLWithPath: projectTake.filePath).lastPathComponent == take.fileName ||
            URL(fileURLWithPath: projectTake.filePath).lastPathComponent == URL(fileURLWithPath: take.filePath).lastPathComponent
        }) {
            if projectTake.sceneNumber > 0 {
                return projectTake.sceneNumber
            }
        }
        
        if take.sceneNumber > 0 {
            return take.sceneNumber
        }
        
        return 1
    }

    /// Builds default per-take filenames (timeline order), including slates.
    private func buildSeparateAutoNames(for timelineTakes: [EnhancedTake]) -> [UUID: String] {
        var perSceneCounters: [Int: Int] = [:]
        var slateCounter: Int = 0
        var result: [UUID: String] = [:]

        let actorName = resolvedActorDisplayName()
        let roleName = resolvedRoleDisplayName()

        for take in timelineTakes {
            let token: String
            if take.isSlate {
                slateCounter += 1
                token = "SlateT\(slateCounter)"
            } else {
                let sceneNumber = resolvedSceneNumber(for: take)
                let nextCount = (perSceneCounters[sceneNumber] ?? 0) + 1
                perSceneCounters[sceneNumber] = nextCount
                token = "S\(sceneNumber)T\(nextCount)"
            }

            let name = ExportFilenameBuilder.buildBase(
                actorName: actorName,
                roleName: roleName,
                takeTokens: [token]
            )
            result[take.id] = name.isEmpty ? token : name
        }

        return result
    }

    // MARK: - Filename helpers

    /// Sanitize a string so it's safe for use in filenames.
    /// - Replaces illegal filesystem characters with hyphens
    /// - Preserves spaces and commas
    private func sanitizeFilenameComponent(_ raw: String) -> String {
        ExportFilenameBuilder.sanitizeFilename(raw)
    }

    /// Resolves the actor display name for export filenames.
    private func resolvedActorDisplayName() -> String? {
        ActorProfileManager().profile.name.slateTrimmedNonEmpty
    }

    /// Resolves the role display name for export filenames.
    private func resolvedRoleDisplayName() -> String? {
        let sessionRole = session.roleName?.slateTrimmedNonEmpty
        let projectRole = project.roles.first?.name.slateTrimmedNonEmpty
        return sessionRole ?? projectRole
    }

    /// Default base filename for merged export.
    private func defaultMergedFilenameBase() -> String {
        let actorName = resolvedActorDisplayName()
        let roleName = resolvedRoleDisplayName()

        // Prefer current timeline order; fall back to final select takes if timeline is empty.
        let enhancedTakesToUse = orderedIncludedTakes.isEmpty ? goodTakes : orderedIncludedTakes
        let tokens = buildSceneTakeTokens(for: enhancedTakesToUse)

        let combined = ExportFilenameBuilder.buildBase(
            actorName: actorName,
            roleName: roleName,
            takeTokens: tokens
        )

        if combined.isEmpty {
            return sanitizeFilenameComponent(autoGeneratedBaseFilename())
        }

        return combined
    }

    private func resolvedExportBaseFilename() -> String {
        let base: String
        if !exportFilename.isEmpty {
            base = (exportFilename as NSString).deletingPathExtension
        } else {
            base = defaultMergedFilenameBase()
        }

        let sanitized = sanitizeFilenameComponent(base)
        if sanitized.isEmpty {
            return sanitizeFilenameComponent(autoGeneratedBaseFilename())
        }
        return sanitized
    }

    private func autoGeneratedBaseFilename() -> String {
        let projectName = project.title.replacingOccurrences(of: " ", with: "_")
        let sessionTypeName: String
        switch session.type {
        case .selfTape:
            sessionTypeName = "SelfTape"
        case .callback:
            sessionTypeName = "Callback"
        case .chemistryRead:
            sessionTypeName = "ChemistryRead"
        case .inPerson:
            sessionTypeName = "InPerson"
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd_HHmm"
        let timestamp = dateFormatter.string(from: Date())
        return "STS_\(projectName)_\(sessionTypeName)_\(timestamp)"
    }
    
    // SURGICAL FIX: Handle SessionExportManager success
    private func handleSessionExportSuccess(outputURL: URL) {
        // Convert to ExportedFile format that ExportResultsStore expects
        let fileSize = (try? FileManager.default.attributesOfItem(atPath: outputURL.path)[.size] as? Int64) ?? 0
        
        // Convert final select takes to UnifiedTake format for ExportedFile
        let unifiedTakes = goodTakes.map { enhancedTake in
            UnifiedTake(from: enhancedTake)
        }
        
        let exportedFile = ExportedFile(
            url: outputURL,
            filename: outputURL.lastPathComponent,
            fileSize: fileSize,
            unifiedTakes: unifiedTakes,
            exportOptions: exportOptions,
            createdAt: Date()
        )
        
        print("✅ SURGICAL FIX: SessionExportManager success converted to ExportedFile")
        
        // Post notification
        NotificationCenter.default.post(
            name: Notification.Name("STSExportCompleted"),
            object: nil,
            userInfo: [
                "sessionID": session.id,
                "projectID": project.id,
                "exportedFiles": 1
            ]
        )
        
        // Set results for display
        exportResultsStore.setExportResults(
            files: [exportedFile],
            project: project,
            session: session,
            originalTakes: goodTakes,
            repository: repository
        )
        
        showingExportResults = true
        print("✅ SURGICAL FIX: Export results displayed")
    }
    
    // CRITICAL FIX: Calculate actual file sizes from filesystem instead of using take.fileSize (which defaults to 0)
    private func calculateEstimatedFileSize() {
        // Show "Calculating..." while we determine actual sizes
        estimatedFileSize = "Calculating..."
        
        Task { @MainActor in
            var totalActualSize: Int64 = 0
            var calculatedTakes = 0
            
            // Calculate actual file sizes from filesystem
            for take in goodTakes {
                do {
                    // CRITICAL: Use VideoFileManager to find the actual video file
                    let videoURL = try VideoFileManager.shared.getVideoURL(for: take.fileName)
                    let resources = try videoURL.resourceValues(forKeys: [.fileSizeKey])
                    let actualFileSize = resources.fileSize ?? 0
                    
                    totalActualSize += Int64(actualFileSize)
                    calculatedTakes += 1
                    
                    print("📊 ExportManager: \(take.fileName) actual size: \(ByteCountFormatter.string(fromByteCount: Int64(actualFileSize), countStyle: .file))")
                    
                } catch {
                    print("❌ ExportManager: Could not get file size for \(take.fileName): \(error)")
                    // Fallback to stored file size if filesystem calculation fails
                    totalActualSize += take.fileSize
                }
            }
            
            let compressionRatio = exportOptions.quality.estimatedCompressionRatio
            let estimatedBytes: Int64
            
            if exportOptions.mode == .separateFiles {
                estimatedBytes = Int64(Double(totalActualSize) * compressionRatio)
            } else {
                // Merged videos are typically smaller due to eliminating duplicate headers/metadata
                estimatedBytes = Int64(Double(totalActualSize) * compressionRatio * 0.9)
            }
            
            estimatedFileSize = ByteCountFormatter.string(fromByteCount: estimatedBytes, countStyle: .file)
            
            print("✅ ExportManager: File size calculation complete - \(calculatedTakes) takes, total: \(ByteCountFormatter.string(fromByteCount: totalActualSize, countStyle: .file)), estimated: \(estimatedFileSize)")
        }
    }
    private func updateExportHeader(filename: String, thumbnail: UIImage?) {
    self.exportFilename = filename
    self.exportThumbnail = thumbnail
}

// MARK: - Export Header Auto-Population
private func populateExportHeaderData() {
    // Auto-generate filename using Actor + Role + Scene/Take summary,
    // falling back to the legacy pattern if needed.
    let autoFilename = defaultMergedFilenameBase()
    exportFilename = autoFilename
    lastAutoFilename = autoFilename
    
    // Load thumbnail from final select photo
    loadThumbnailFromFinalSelectPhoto()
    
    // Sync format with existing export options
    selectedFormat = exportOptions.outputFormat
}

private func loadThumbnailFromFinalSelectPhoto() {
    // Find first photo with final select rating
    let finalSelectPhoto = session.takes.first { take in
        take.isFinalSelect && take.durationSeconds == 0.0 // Photos have duration 0
    }
    
    if let photo = finalSelectPhoto {
        Task {
            do {
                let photoURL = try VideoFileManager.shared.getVideoURL(for: URL(fileURLWithPath: photo.filePath).lastPathComponent)
                let image = UIImage(contentsOfFile: photoURL.path)
                await MainActor.run {
                    exportThumbnail = image
                }
            } catch {
                print("⚠️ Could not load photo thumbnail: \(error)")
            }
        }
    }
}// MARK: - Export Header with Context & Format Binding// MARK: - Thumbnail Metadata Creation

/// Creates AVMetadataItem for video artwork from UIImage thumbnail
/// Compatible with iOS 18+ metadata handling
private func createThumbnailMetadata(from thumbnail: UIImage) -> [AVMetadataItem] {
        // Build dual artwork metadata to maximize compatibility (MOV + MP4).
        // 1) QuickTime common artwork ("covr" under udta/meta/ilst)
        // 2) iTunes cover art (widely recognized by MP4 readers)
        let jpegData = thumbnail.jpegData(compressionQuality: 0.92)
        let imageData = jpegData ?? thumbnail.pngData()
        guard let data = imageData else { return [] }

        var items: [AVMetadataItem] = []

        // QuickTime common artwork
        let qtArtwork = AVMutableMetadataItem()
        qtArtwork.keySpace = .quickTimeMetadata
        qtArtwork.identifier = .commonIdentifierArtwork
        qtArtwork.value = data as (NSCopying & NSObjectProtocol)?
        qtArtwork.dataType = (jpegData != nil) ? kCMMetadataBaseDataType_JPEG as String : kCMMetadataBaseDataType_PNG as String
        items.append(qtArtwork)

        // iTunes cover art
        let itArtwork = AVMutableMetadataItem()
        itArtwork.keySpace = .iTunes
        itArtwork.identifier = .iTunesMetadataCoverArt
        itArtwork.value = data as (NSCopying & NSObjectProtocol)?
        itArtwork.dataType = (jpegData != nil) ? kCMMetadataBaseDataType_JPEG as String : kCMMetadataBaseDataType_PNG as String
        items.append(itArtwork)

        // Optional: title
        let title = AVMutableMetadataItem()
        title.keySpace = .common
        title.key = AVMetadataKey.commonKeyTitle as (NSCopying & NSObjectProtocol)?
        title.value = exportFilename as (NSCopying & NSObjectProtocol)?
        title.dataType = kCMMetadataBaseDataType_UTF8 as String
        items.append(title)

        return items
}
private var exportHeaderView: some View {
    ExportHeaderView(
        filename: $exportFilename,
        thumbnail: $exportThumbnail,
        selectedFormat: Binding(
            get: { selectedFormat },
            set: { newFormat in
                selectedFormat = newFormat
                exportOptions.outputFormat = newFormat
            }
        )
    )
    .overlay(alignment: .topTrailing) {
        // Controls whether we include the preview photo intro in exported videos
        Toggle(isOn: $showPreviewPhotoIntro) {
            Text("Photo intro")
                .font(.caption)
                .foregroundColor(.white)
        }
        .toggleStyle(.switch)
        .labelsHidden()
        .padding(12)
        .onChange(of: showPreviewPhotoIntro) { _, newValue in
            if newValue {
                // Re-load thumbnail from the actor's final select photo
                loadThumbnailFromGoodPhoto()
            } else {
                // Clear the header thumbnail so the UI matches the export behavior
                exportThumbnail = nil
            }
        }
    }
}

// Backward-compatible alias for older call sites.
private func loadThumbnailFromGoodPhoto() {
    loadThumbnailFromFinalSelectPhoto()
}
}

// MARK: - Supporting Extensions

extension DateFormatter {
    func then(_ closure: (DateFormatter) -> Void) -> DateFormatter {
        closure(self)
        return self
    }
}

// MARK: - Supporting Views

struct TakePreviewCard: View {
    let take: EnhancedTake
    
    var body: some View {
        VStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 8)
                .fill(take.isSlate ? Theme.primary.opacity(0.3) : Color.white.opacity(0.2))
                .frame(width: 60, height: 40)
                .overlay(
                    VStack(spacing: 2) {
                        Image(systemName: take.isSlate ? "person.crop.rectangle" : "video.fill")
                            .font(.caption)
                            .foregroundStyle(.white)
                        
                        Text(take.formattedDuration)
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                )
            
            Text(take.isSlate ? "Slate" : "Take \(take.takeNumber)")
                .font(.caption2)
                .foregroundStyle(.gray)
        }
    }
}

struct ExportOptionSection<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.white)
            
            content
        }
    }
}

struct ExportModeRow: View {
    let mode: ExportMode
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                Image(systemName: mode.icon)
                    .font(.body)
                    .foregroundStyle(isSelected ? Theme.primary : .white.opacity(0.6))
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(mode.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.white)
                    
                    Text(modeDescription(for: mode))
                        .font(.caption)
                        .foregroundStyle(.gray)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.body)
                        .foregroundStyle(Theme.primary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Theme.primary.opacity(0.2) : Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(isSelected ? Theme.primary : Color.white.opacity(0.1), lineWidth: 1)
                    )
            )
        }
    }
    
    private func modeDescription(for mode: ExportMode) -> String {
        switch mode {
        case .separateFiles:
            return "Export each take as individual files"
        case .mergedVideo:
            return "Combine all takes into one video"
        }
    }
}

struct ExportQualityRow: View {
    let quality: ExportQuality
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                VStack(spacing: 1) {
                    ForEach(0..<qualityBars(for: quality), id: \.self) { _ in
                        Rectangle()
                            .fill(isSelected ? Theme.primary : .white.opacity(0.6))
                            .frame(width: 3, height: 4)
                    }
                    ForEach(qualityBars(for: quality)..<4, id: \.self) { _ in
                        Rectangle()
                            .fill(.white.opacity(0.2))
                            .frame(width: 3, height: 4)
                    }
                }
                .frame(width: 24, height: 20)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(quality.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.white)
                    
                    Text(qualityDescription(for: quality))
                        .font(.caption)
                        .foregroundStyle(.gray)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.body)
                        .foregroundStyle(Theme.primary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Theme.primary.opacity(0.2) : Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(isSelected ? Theme.primary : Color.white.opacity(0.1), lineWidth: 1)
                    )
            )
        }
    }
    
    private func qualityBars(for quality: ExportQuality) -> Int {
        switch quality {
        case .low: return 1
        case .medium: return 2
        case .high: return 3
        case .maximum: return 4
        }
    }
    
    private func qualityDescription(for quality: ExportQuality) -> String {
        switch quality {
        case .low:
            return "Good for sharing, smaller files"
        case .medium:
            return "Balanced quality and file size"
        case .high:
            return "Best for most uses"
        case .maximum:
            return "No compression, largest files"
        }
    }
}

// MARK: - Marker Preview Badge
struct MarkerPreviewBadge: View {
    let take: EnhancedTake
    let markers: [VideoMarker]
    
    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 2) {
                ForEach(Array(markers.prefix(3)), id: \.id) { marker in
                    Circle()
                        .fill(marker.type.color)
                        .frame(width: 4, height: 4)
                }
                
                if markers.count > 3 {
                    Text("+\(markers.count - 3)")
                        .font(.system(size: 8))
                        .foregroundStyle(.white)
                }
            }
            
            Text("T\(take.takeNumber)")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.8))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.black.opacity(0.3))
        )
    }
}

// MARK: - Preview

// STEP 2B: Update preview to include required parameters
#Preview {
    let sampleSession = ProjectSession(
        type: .selfTape,
        takes: [
            ProjectTake(filePath: "/path/to/take1.mov", durationSeconds: 45.2, rating: .finalSelect),
            ProjectTake(filePath: "/path/to/slate.mov", durationSeconds: 8.5, rating: .unrated)
        ]
    )
    
    let sampleProject = Project(title: "Test Project")
    
    ExportManagerView(
        takes: [
            EnhancedTake(
                fileName: "Test_Take1.mov",
                projectID: UUID(),
                sessionID: UUID(),
                filePath: "/path/to/take1.mov",
                duration: 45.2,
                fileSize: 15_000_000,
                cameraPosition: "back",
                sceneNumber: 1,
                takeNumber: 1
            ),
            EnhancedTake(
                fileName: "SLATE_Test.mov",
                projectID: UUID(),
                sessionID: UUID(),
                filePath: "/path/to/slate.mov",
                duration: 8.5,
                fileSize: 3_000_000,
                cameraPosition: "back",
                sceneNumber: 1,
                takeNumber: 0,
                isSlate: true
            )
        ],
        project: sampleProject,
        session: sampleSession,
        repository: ProjectsRepositoryFactory.makePreviewRepository()
    ) {
        print("Export dismissed")
    }
}
