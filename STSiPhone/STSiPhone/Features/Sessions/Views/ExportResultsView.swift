import SwiftUI
import AVKit
import Foundation
import UIKit

/// Display export results and provide sharing options
struct ExportResultsView: View {
    @ObservedObject var exportResultsStore: ExportResultsStore  // SWIFTUI FIX: Use ObservableObject instead of direct parameters
    let onDismiss: () -> Void
    @EnvironmentObject private var themeManager: ThemeManager
    
    @State private var sharePayload: SharePayload?
    @State private var processingResults = false
    
    // ASYNC TIMING FIX: Use @State to control merged files computation and avoid race conditions
    @State private var computedMergedFiles: [ExportedFile] = []
    @State private var mergedFilesCalculated = false
    @State private var retryCount = 0  // SWIFTUI FIX: Prevent infinite retries

    // NEW: Preview sheet payload for tapping thumbnails
    @State private var previewPayload: PreviewPayload?
    
    // Computed properties for easier access to store data
    private var exportedFiles: [ExportedFile] {
        exportResultsStore.exportedFiles
    }

    private var estimatedTotal: String {
        exportResultsStore.estimatedTotal ?? "—"
    }
    
    private var project: Project? {
        exportResultsStore.project
    }
    
    private var session: ProjectSession? {
        exportResultsStore.session
    }
    
    private var originalTakes: [EnhancedTake]? {
        exportResultsStore.originalTakes.isEmpty ? nil : exportResultsStore.originalTakes
    }
    
    private var repository: ProjectsRepository? {
        exportResultsStore.repository
    }
    
    // SWIFTUI FIX: Simplified initializer using only the store
    init(
        exportResultsStore: ExportResultsStore,
        onDismiss: @escaping () -> Void
    ) {
        self.exportResultsStore = exportResultsStore
        self.onDismiss = onDismiss
        
        print("📊 ExportResultsView INIT: Using ObservableObject store")
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
    
    var body: some View {
        NavigationStack {
            ZStack {
                theme.backgroundGradient
                    .ignoresSafeArea()
                accentGlow
                
                VStack(spacing: 24) {
                    // Success header
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(.green)
                        
                        VStack(spacing: 8) {
                            Text("Export Complete!")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                            
                            if processingResults {
                                Text("Saving to project...")
                                    .font(.body)
                                    .foregroundStyle(.yellow)
                            } else {
                                Text("\(exportedFiles.count) file\(exportedFiles.count == 1 ? "" : "s") exported successfully")
                                    .font(.body)
                                    .foregroundStyle(.gray)
                            }

                            // Estimated vs actual breakdown
                            if !exportedFiles.isEmpty {
                                HStack(spacing: 12) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Estimated")
                                            .font(.caption)
                                            .foregroundStyle(.gray)
                                        Text(estimatedTotal)
                                            .font(.headline)
                                            .foregroundStyle(.white)
                                    }
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Actual")
                                            .font(.caption)
                                            .foregroundStyle(.gray)
                                        let total = exportedFiles.reduce(Int64(0)) { $0 + ($1.fileSize) }
                                        Text(ByteCountFormatter.string(fromByteCount: total, countStyle: .file))
                                            .font(.headline)
                                            .foregroundStyle(.white)
                                    }
                                    Spacer()
                                }
                                .padding(.top, 4)
                            }
                        }
                    }
                    .padding(.top, 32)
                    
                    // ASYNC TIMING FIX: Use computedMergedFiles instead of live computation
                    if !computedMergedFiles.isEmpty && mergedFilesCalculated {
                        resultsSummaryView(mergedFiles: computedMergedFiles)
                    }
                    
                    // File list
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(exportedFiles) { file in
                                ExportedFileRow(
                                    file: file,
                                    onShare: { shareFile(file) },
                                    onPreview: { previewFile(file) }
                                )
                            }
                        }
                        .padding(.horizontal, 24)
                    }
                    
                    // Action buttons
                    VStack(spacing: 12) {
                        // Share all button
                        BrandedPrimaryButton(
                            label: "Share All Files",
                            icon: "square.and.arrow.up"
                        ) {
                            shareAllFiles()
                        }
                        .disabled(processingResults)
                        
                        // Done button
                        BrandedSecondaryButton(label: "Done") {
                            handleDone()
                        }
                        .disabled(processingResults)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Export Results")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        handleDone()
                    }
                    .disabled(processingResults)
                }
            }
        }
        .sheet(item: $sharePayload) { payload in
            ActivityViewController(activityItems: payload.items)
        }
        // NEW: Preview sheet for tapping exported thumbnails
        .sheet(item: $previewPayload) { payload in
            ExportPreviewPlayerView(file: payload.file)
        }
        .onAppear {
            print("📊 ExportResultsView.onAppear: Store data ready = \(exportResultsStore.isDataReady)")
            print("📊 ExportResultsView.onAppear: Starting with \(exportedFiles.count) files")
            
            // SWIFTUI FIX: Process immediately if data is ready, otherwise wait for store update
            if exportResultsStore.isDataReady && !exportedFiles.isEmpty {
                print("📊 ExportResultsView: Data ready immediately, processing...")
                calculateMergedFiles()
            } else {
                print("📊 ExportResultsView: Waiting for export results store to populate...")
            }
        }
        .onChange(of: exportResultsStore.isDataReady, initial: false) { _, isReady in
            if isReady && !exportedFiles.isEmpty {
                print("📊 ExportResultsView: Store data became ready, processing \(exportedFiles.count) files...")
                calculateMergedFiles()
            }
        }
        .onChange(of: exportResultsStore.exportedFiles, initial: false) { _, files in
            if !files.isEmpty && exportResultsStore.isDataReady {
                print("📊 ExportResultsView: Export files updated, processing \(files.count) files...")
                calculateMergedFiles()
            }
        }
        .stsSupportedOrientations(.all, label: "ExportResultsView")
    }
    
    // SWIFTUI FIX: Enhanced merged files calculation using store data
    private func calculateMergedFiles() {
        print("📊 ExportResults: Calculating merged files from \(exportedFiles.count) exported files (store ready: \(exportResultsStore.isDataReady))")
        
        // SWIFTUI FIX: Don't retry if using ObservableObject - data will come via onChange
        guard !exportedFiles.isEmpty else {
            print("⚠️ ExportResults: No exported files yet from store")
            return
        }
        
        print("✅ ExportResults: Processing \(exportedFiles.count) exported files from store")
        retryCount = 0 // Reset counter since we have data
        
        Task { @MainActor in
            let mergedFiles = exportedFiles.filter { exportedFile in
                let isMultiTake = exportedFile.isMultiTake
                print("📊 ExportResults: File \(exportedFile.filename) - isMultiTake: \(isMultiTake), unifiedTakes: \(exportedFile.unifiedTakes.count)")
                return isMultiTake
            }
            
            // NEW: Also identify separate files
            let separateFiles = exportedFiles.filter { exportedFile in
                let isSeparate = !exportedFile.isMultiTake
                print("📊 ExportResults: File \(exportedFile.filename) - isSeparate: \(isSeparate)")
                return isSeparate
            }
            
            computedMergedFiles = mergedFiles
            mergedFilesCalculated = true
            
            print("📊 ExportResults: Calculated \(mergedFiles.count) merged files and \(separateFiles.count) separate files")
            for (index, file) in mergedFiles.enumerated() {
                print("📊 ExportResults: Merged file \(index + 1): \(file.filename), size: \(file.formattedFileSize)")
            }
            for (index, file) in separateFiles.enumerated() {
                print("📊 ExportResults: Separate file \(index + 1): \(file.filename), size: \(file.formattedFileSize)")
            }
            
            // Save both merged and separate files to repository
            if !mergedFiles.isEmpty {
                await saveMergedVideosToRepository(mergedFiles: mergedFiles)
            }
            if !separateFiles.isEmpty {
                await saveSeparateFilesToRepository(separateFiles: separateFiles)
            }
            
            if mergedFiles.isEmpty && separateFiles.isEmpty {
                print("ℹ️ ExportResults: No files to save to repository")
            }
        }
    }
    
    // NEW: Save separate exported files to repository
    private func saveSeparateFilesToRepository(separateFiles: [ExportedFile]) async {
        guard let project = project,
              let session = session,
              let originalTakes = originalTakes,
              let repository = repository,
              !separateFiles.isEmpty else {
            print("📁 ExportResults: No separate files to save or missing context")
            print("📁 ExportResults Debug: project=\(project != nil), session=\(session != nil), originalTakes=\(originalTakes != nil), repository=\(repository != nil), separateFiles=\(separateFiles.count)")
            return
        }
        
        print("📁 ExportResults: Starting save process with \(separateFiles.count) separate files")
        await MainActor.run {
            processingResults = true
        }
        
        // Save each separate file as an individual take
        for separateFile in separateFiles {
            // CRITICAL FIX: Register exported video with VideoPlayerService to apply iOS bug workaround
            VideoPlayerService.shared.registerExportedVideo(separateFile.url)
            
            // Create export metadata for the separate file
            let originalTakeIDs = getOriginalTakeIDs(for: separateFile, from: originalTakes)
            let exportOptions = createExportOptionsSnapshot(from: separateFile)
            
            let exportMetadata = ExportMetadata(
                exportDate: separateFile.createdAt,
                exportType: .separate, // Mark as separate export type
                originalTakeIDs: originalTakeIDs,
                exportOptions: exportOptions
            )
            
            // Create ProjectTake from exported file
            let exportedTake = ProjectTake(
                filePath: relativePathFromExportURL(separateFile.url),
                durationSeconds: estimateDuration(for: separateFile),
                takeNotes: createTakeNotes(for: separateFile),
                createdAt: separateFile.createdAt,
                rating: .unrated, // Separate files start unrated (can be rated later)
                exportMetadata: exportMetadata,
                takeType: .exported // Mark as exported take type
            )
            
            // Add the exported take to repository
            repository.addTake(exportedTake, to: session.id, in: project.id)
            
            print("✅ ExportResults: Saved separate file '\(separateFile.filename)' as relative path: \(relativePathFromExportURL(separateFile.url))")
        }
        
        await MainActor.run {
            processingResults = false
            
            // CRITICAL FIX: Send both project reload and export completion notifications
            NotificationCenter.default.post(
                name: Notification.Name("STSProjectsListShouldReload"),
                object: nil
            )
            
            // CRITICAL FIX: Notify TakeReviewPage that export is complete and new takes are available
            NotificationCenter.default.post(
                name: Notification.Name("STSExportCompleted"),
                object: nil,
                userInfo: [
                    "sessionID": session.id,
                    "projectID": project.id,
                    "exportedFiles": separateFiles.count,
                    "exportType": "separate"
                ]
            )
            
            print("🎬 ExportResults: Completed saving \(separateFiles.count) separate files to repository")
        }
    }
    
    // NEW: Helper method to create take notes for separate files
    private func createTakeNotes(for separateFile: ExportedFile) -> String {
        let sourceFile = separateFile.unifiedTakes.first?.fileName ?? "Unknown"
        let quality = separateFile.exportOptions.quality.displayName
        let format = separateFile.exportOptions.outputFormat.displayName
        
        return "Exported from \(sourceFile) • \(quality) quality • \(format) format"
    }
    
    // NEW: Computed property for merged files - DEPRECATED in favor of @State approach
    private var mergedFiles: [ExportedFile] {
        return computedMergedFiles
    }
    
    // NEW: Results summary view
    @ViewBuilder
    private func resultsSummaryView(mergedFiles: [ExportedFile]) -> some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "film.stack.fill")
                    .font(.title2)
                    .foregroundStyle(.green)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Merged Videos Created")
                        .font(.headline)
                        .foregroundStyle(.white)
                    
                    Text("\(mergedFiles.count) merged video\(mergedFiles.count == 1 ? "" : "s") from \(totalOriginalTakes) take\(totalOriginalTakes == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(.gray)
                }
                
                Spacer()
                
                if processingResults {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.title2)
                }
            }
            
            if !processingResults {
                Text("✅ Merged video has been added to your Session and will appear in your Deliverables folder")
                    .font(.caption)
                    .foregroundStyle(.gray)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.green.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.green.opacity(0.3), lineWidth: 1)
                )
        )
        .padding(.horizontal, 24)
    }
    
    // NEW: Computed property for total original takes - ASYNC TIMING FIX: Use computedMergedFiles
    private var totalOriginalTakes: Int {
        computedMergedFiles.reduce(0) { $0 + $1.unifiedTakes.count }
    }
    
    // SWIFTUI FIX: Updated repository save method using store data
    private func saveMergedVideosToRepository(mergedFiles: [ExportedFile]) async {
        guard let project = project,
              let session = session,
              let originalTakes = originalTakes,
              let repository = repository,
              !mergedFiles.isEmpty else {
            print("📁 ExportResults: No merged videos to save or missing context")
            print("📁 ExportResults Debug: project=\(project != nil), session=\(session != nil), originalTakes=\(originalTakes != nil), repository=\(repository != nil), mergedFiles=\(mergedFiles.count)")
            return
        }
        
        print("📁 ExportResults: Starting save process with \(mergedFiles.count) merged files")
        await MainActor.run {
            processingResults = true
        }
        
        // Use the repository from the store
        for mergedFile in mergedFiles {
            // CRITICAL FIX: Register exported video with VideoPlayerService to apply iOS bug workaround
            VideoPlayerService.shared.registerExportedVideo(mergedFile.url)
            
            // Create export metadata
            let originalTakeIDs = getOriginalTakeIDs(for: mergedFile, from: originalTakes)
            let exportOptions = createExportOptionsSnapshot(from: mergedFile)
            
            let exportMetadata = ExportMetadata(
                exportDate: mergedFile.createdAt,
                exportType: getExportType(from: mergedFile),
                originalTakeIDs: originalTakeIDs,
                exportOptions: exportOptions
            )
            
            // Save merged video to repository using store instance
            repository.saveMergedVideo(
                filePath: mergedFile.url.path,
                duration: estimateDuration(for: mergedFile),
                exportMetadata: exportMetadata,
                to: session.id,
                in: project.id
            )
            
            print("✅ ExportResults: Saved merged video '\(mergedFile.filename)' with \(originalTakeIDs.count) source takes to repository \(type(of: repository))")
        }
        
        await MainActor.run {
            processingResults = false
            
            // CRITICAL FIX: Send both project reload and export completion notifications
            NotificationCenter.default.post(
                name: Notification.Name("STSProjectsListShouldReload"),
                object: nil
            )
            
            // CRITICAL FIX: Notify TakeReviewPage that export is complete and new takes are available
            NotificationCenter.default.post(
                name: Notification.Name("STSExportCompleted"),
                object: nil,
                userInfo: [
                    "sessionID": session.id,
                    "projectID": project.id,
                    "exportedFiles": mergedFiles.count,
                    "exportType": "merged"
                ]
            )
            
            print("🎬 ExportResults: Completed saving \(mergedFiles.count) merged videos to repository")
        }
    }
    
    // DEPRECATED: Remove this method since we're using the new async approach
    // NEW: Save merged videos to repository
    private func saveMergedVideosToRepository() {
        // This method is now deprecated - using calculateMergedFiles() -> saveMergedVideosToRepository(mergedFiles:) instead
    }
    
    // NEW: Helper methods for export metadata creation
    private func getOriginalTakeIDs(for mergedFile: ExportedFile, from originalTakes: [EnhancedTake]) -> [UUID] {
        // Match original takes that were used in this export
        let ids: [UUID] = mergedFile.unifiedTakes.compactMap { exportedTake in
            originalTakes.first { originalTake in
                originalTake.fileName == exportedTake.fileName ||
                originalTake.filePath == exportedTake.filePath
            }?.id
        }
        return ids
    }
    
    private func createExportOptionsSnapshot(from file: ExportedFile) -> ExportOptionsSnapshot {
        return ExportOptionsSnapshot(
            quality: file.exportOptions.quality.displayName,
            format: file.exportOptions.outputFormat.displayName,
            includedMarkers: file.exportOptions.includeVideoMarkers,
            takeCount: file.unifiedTakes.count
        )
    }
    
    private func getExportType(from file: ExportedFile) -> ExportMetadata.ExportType {
        switch file.exportOptions.mode {
        case .mergedVideo:
            return .merged
        case .separateFiles:
            return .separate
        }
    }
    
    private func estimateDuration(for file: ExportedFile) -> Double {
        file.unifiedTakes.reduce(0.0) { $0 + $1.duration }
    }
    
    // NEW: Enhanced done handling with repository save
    private func handleDone() {
        if processingResults {
            return // Don't dismiss while processing
        }
        onDismiss()
    }
    
    // MARK: - Actions
    
    private func shareFile(_ file: ExportedFile) {
        sharePayload = SharePayload(items: [file.url])
    }
    
    // NEW: Open a lightweight preview player for the exported video
    private func previewFile(_ file: ExportedFile) {
        previewPayload = PreviewPayload(file: file)
    }
    
    // CRITICAL FIX: Convert absolute export URL to relative path for repository storage
    private func relativePathFromExportURL(_ url: URL) -> String {
        // Export URLs are in format: /path/to/Documents/STS_Exports/filename.mov
        // We want relative path: STS_Exports/filename.mov
        let pathComponents = url.pathComponents
        if let exportsIndex = pathComponents.firstIndex(of: "STS_Exports"),
           exportsIndex < pathComponents.count - 1 {
            let relativeComponents = Array(pathComponents[exportsIndex...])
            return relativeComponents.joined(separator: "/")
        }
        // Fallback: just use the filename (but this shouldnt happen for exports)
        return url.lastPathComponent
    }
    private func shareAllFiles() {
        let urls = exportedFiles.map { $0.url }
        guard !urls.isEmpty else { return }
        sharePayload = SharePayload(items: urls)
    }
}

private struct SharePayload: Identifiable {
    let id = UUID()
    let items: [Any]
}

// NEW: Sheet payload for previewing a single exported video
private struct PreviewPayload: Identifiable {
    let id = UUID()
    let file: ExportedFile
}

// MARK: - Export Preview Player

/// Simple AVPlayer-based preview for a single exported video
private struct ExportPreviewPlayerView: View {
    let file: ExportedFile

    @Environment(\.dismiss) private var dismiss
    @State private var player: AVPlayer
    @State private var idleTimerToken: IdleTimerController.Token?
    @State private var playbackObservation: NSKeyValueObservation?

    init(file: ExportedFile) {
        self.file = file
        _player = State(initialValue: AVPlayer(url: file.url))
    }

    var body: some View {
        NavigationStack {
            PlaybackSurface(
                background: {
                    Color.black
                },
                video: {
                    PlaybackAVPlayerViewControllerHost(player: player)
                },
                overlay: {
                    EmptyView()
                }
            )
            .onAppear {
                startPlaybackObservation()
                player.seek(to: .zero)
                player.play()
            }
            .onDisappear {
                stopPlaybackObservation()
                Task { @MainActor in
                    releaseIdleTimer()
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        player.pause()
                        dismiss()
                    }
                }
            }
        }
    }

    private func startPlaybackObservation() {
        playbackObservation?.invalidate()
        playbackObservation = player.observe(\.timeControlStatus, options: [.initial, .new]) { [weak player] _, _ in
            guard let player else { return }
            let isPlaying = player.timeControlStatus == .playing
            Task { @MainActor in
                updateIdleTimer(isPlaying)
            }
        }
    }

    private func stopPlaybackObservation() {
        playbackObservation?.invalidate()
        playbackObservation = nil
    }

    @MainActor
    private func updateIdleTimer(_ isPlaying: Bool) {
        if isPlaying {
            if idleTimerToken == nil {
                idleTimerToken = IdleTimerController.shared.acquire(reason: "ExportPreview")
            }
        } else {
            releaseIdleTimer()
        }
    }

    @MainActor
    private func releaseIdleTimer() {
        idleTimerToken?.release()
        idleTimerToken = nil
    }
}

private struct PlaybackAVPlayerViewControllerHost: UIViewControllerRepresentable {
    let player: AVPlayer
    @Environment(\.playbackSafeAreaInsets) private var playbackSafeAreaInsets
    func makeUIViewController(context: Context) -> ChromeInsetContainerViewController {
        let controller = AVPlayerViewController()
        if #available(iOS 16.0, *) {
            controller.allowsVideoFrameAnalysis = false
        }
        controller.player = player
        controller.showsPlaybackControls = true
        let container = ChromeInsetContainerViewController(playerViewController: controller)
        container.updatePlaybackInsets(playbackSafeAreaInsets)
        return container
    }

    func updateUIViewController(_ uiViewController: ChromeInsetContainerViewController, context: Context) {
        if uiViewController.playerViewController.player !== player {
            uiViewController.playerViewController.player = player
        }
        uiViewController.updatePlaybackInsets(playbackSafeAreaInsets)
    }
}

// MARK: - Exported File Row

struct ExportedFileRow: View {
    let file: ExportedFile
    let onShare: () -> Void
    let onPreview: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            if isVideoFile {
                tappableVideoPreview
            } else {
                fallbackIcon
                    .frame(width: 50)
            }
            
            // File details
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top, spacing: 8) {
                    Text(file.filename)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundStyle(.white)
                        // Allow the name to wrap to as many lines as needed, no truncation
                        .lineLimit(nil)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    // NEW: Merged video indicator
                    if file.isMultiTake {
                        Image(systemName: "film.stack.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                            .padding(.top, 2)
                    }
                }
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        Label(file.formattedFileSize, systemImage: "doc")
                            .font(.caption)
                            .foregroundStyle(.gray)
                        
                        if file.isMultiTake {
                            Label("\(file.unifiedTakes.count) takes merged", systemImage: "arrow.triangle.merge")
                                .font(.caption)
                                .foregroundStyle(.green)
                        }
                        
                        Label(
                            file.createdAt.formatted(date: .omitted, time: .shortened),
                            systemImage: "clock"
                        )
                        .font(.caption)
                        .foregroundStyle(.gray)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            
            Spacer()
            
            // Share button
            Button(action: onShare) {
                Image(systemName: "square.and.arrow.up")
                    .font(.title3)
                    .foregroundStyle(Theme.primary)
                    .padding(12)
                    .background(
                        Circle()
                            .fill(Theme.primary.opacity(0.2))
                    )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(file.isMultiTake ? 0.08 : 0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(file.isMultiTake ? Color.green.opacity(0.3) : Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
    
    private var fileIcon: String {
        if file.isMultiTake {
            return "film.stack.fill"
        } else {
            switch file.url.pathExtension.lowercased() {
            case "mp4":
                return "film.fill"
            case "mov":
                return "video.fill"
            default:
                return "doc.fill"
            }
        }
    }
    
    private var videoPreview: some View {
        AsyncThumbnail(url: file.url, corner: 12, sampleTime: 0.02)
            .frame(width: 100, height: 64)
            .overlay(alignment: .bottomLeading) {
                HStack(spacing: 6) {
                    Image(systemName: fileIcon)
                        .font(.caption)
                    Text(extensionLabel)
                        .font(.caption2)
                        .fontWeight(.semibold)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.black.opacity(0.65))
                .clipShape(Capsule())
                .padding(6)
            }
    }
    
    private var fallbackIcon: some View {
        VStack(spacing: 4) {
            Image(systemName: fileIcon)
                .font(.title2)
                .foregroundStyle(file.isMultiTake ? .green : Theme.primary)
            
            Text(extensionLabel)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundStyle(.white)
        }
    }

    // Tappable video preview that opens the Export preview sheet
    private var tappableVideoPreview: some View {
        Button(action: onPreview) {
            videoPreview
        }
        .buttonStyle(.plain)
    }
    
    private var isVideoFile: Bool {
        switch file.url.pathExtension.lowercased() {
        case "mp4", "mov":
            return true
        default:
            return false
        }
    }
    
    private var extensionLabel: String {
        file.url.pathExtension.uppercased()
    }
}

// MARK: - Preview

#Preview {
    let store: ExportResultsStore = ExportResultsStore()
    let fakeUnifiedTakes1: [UnifiedTake] = [
        UnifiedTake(
            fileName: "Take1.mov",
            projectID: UUID(),
            sessionID: UUID(),
            filePath: "/path/to/take1.mov",
            duration: 45.2,
            fileSize: 8_000_000,
            cameraPosition: "back",
            sceneNumber: 1,
            takeNumber: 1
        ),
        UnifiedTake(
            fileName: "Take2.mov",
            projectID: UUID(),
            sessionID: UUID(),
            filePath: "/path/to/take2.mov",
            duration: 52.8,
            fileSize: 9_000_000,
            cameraPosition: "back",
            sceneNumber: 1,
            takeNumber: 2
        )
    ]
    let fakeUnifiedTakes2: [UnifiedTake] = [
        UnifiedTake(
            fileName: "Take1.mov",
            projectID: UUID(),
            sessionID: UUID(),
            filePath: "/path/to/take1.mov",
            duration: 45.2,
            fileSize: 8_000_000,
            cameraPosition: "back",
            sceneNumber: 1,
            takeNumber: 1
        )
    ]
    let files: [ExportedFile] = [
        ExportedFile(
            url: URL(fileURLWithPath: "/path/to/export1.mp4"),
            filename: "TestProject_Merged_3takes_20241213_143022.mp4",
            fileSize: 25_000_000,
            unifiedTakes: fakeUnifiedTakes1,
            exportOptions: ExportOptions(mode: .mergedVideo, quality: .high),
            createdAt: Date()
        ),
        ExportedFile(
            url: URL(fileURLWithPath: "/path/to/export2.mp4"),
            filename: "TestProject_Take1_20241213_143022.mp4",
            fileSize: 8_000_000,
            unifiedTakes: fakeUnifiedTakes2,
            exportOptions: ExportOptions(mode: .separateFiles, quality: .high),
            createdAt: Date()
        )
    ]
    store.setExportResults(
        files: files,
        project: Project(title: "Test Project"),
        session: ProjectSession(type: .selfTape, takes: []),
        originalTakes: [EnhancedTake](),
        repository: ProjectsRepositoryFactory.makePreviewRepository()
    )

    return ExportResultsView(
        exportResultsStore: store
    ) {
        print("Export results dismissed")
    }
}
