import SwiftUI
import AVKit
import AVFoundation

struct PIPSlateEditorScreen: View {
    @Binding var session: SlatePIPSession?
    let project: Project
    let projectSession: ProjectSession
    var onCompositeSaved: (() -> Void)?
    
    var body: some View {
        PIPSlateEditorContainer(
            session: $session,
            project: project,
            projectSession: projectSession,
            isEmbedded: false,
            onCompositeSaved: onCompositeSaved
        )
        .navigationTitle("Picture-in-Picture Editor")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct PIPSlateEditorContainer: View {
    @Binding var session: SlatePIPSession?
    let project: Project
    let projectSession: ProjectSession
    var isEmbedded: Bool
    var onCompositeSaved: (() -> Void)?
    
    var body: some View {
        Group {
            if let binding = Binding(unwrapping: $session) {
                PIPSlateEditorCore(
                    session: binding,
                    project: project,
                    projectSession: projectSession,
                    isEmbedded: isEmbedded,
                    externalSaveTrigger: nil,
                    onCompositeSaved: onCompositeSaved
                )
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "rectangle.split.3x3")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("No Picture-in-Picture slate data yet.")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                .padding()
            }
        }
        .onChange(of: session, initial: false) { _, newValue in
            guard let value = newValue else { return }
            SessionManager.shared.savePIPSlateSession(
                value,
                projectID: project.id,
                sessionID: projectSession.id
            )
        }
    }
}

struct PIPSlateEditorCore: View {
    @Binding var session: SlatePIPSession
    let project: Project
    let projectSession: ProjectSession
    var isEmbedded: Bool
    var externalSaveTrigger: Binding<Int>? = nil
    var onCompositeSaved: (() -> Void)?
    
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @State private var selectedTab: EditorTab = .landscape
    @State private var isExporting = false
    @State private var exportStatus: String?
    @State private var previewURL: URL?
    @State private var takePendingDeletion: (PIPSlateTake, VideoOrientation)?
    @State private var showAudioSelection = false
    @State private var pendingExportPortrait: PIPSlateTake?
    @State private var pendingExportLandscape: PIPSlateTake?
    @State private var audioSelection = AudioSelectionChoice()
    
    enum EditorTab: Hashable {
        case landscape
        case portrait
        
        var title: String {
            switch self {
            case .landscape: return "Close-Up"
            case .portrait: return "Full Body"
            }
        }
    }
    
    var body: some View {
        GeometryReader { geo in
            Group {
                if verticalSizeClass == .regular || verticalSizeClass == nil {
                    portraitLayout(geo: geo)
                } else {
                    landscapeLayout(geo: geo)
                }
            }
        }
        .background {
            if isEmbedded {
                Color.clear
            } else {
                BrandBackground().ignoresSafeArea(edges: .bottom)
            }
        }
        .onAppear { syncSelectedTabWithAvailableTakes() }
        .onChange(of: session.portraitTakes.count, initial: false) { _, _ in syncSelectedTabWithAvailableTakes() }
        .onChange(of: session.landscapeTakes.count, initial: false) { _, _ in syncSelectedTabWithAvailableTakes() }
        .sheet(isPresented: Binding(
            get: { previewURL != nil },
            set: { if !$0 { previewURL = nil } }
        )) {
            if let url = previewURL {
                VideoPreviewSheet(url: url)
            }
        }
        .confirmationDialog("Delete take?", isPresented: Binding(
            get: { takePendingDeletion != nil },
            set: { if !$0 { takePendingDeletion = nil } }
        ), titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let (take, orientation) = takePendingDeletion {
                    deleteTake(take, orientation: orientation)
                    takePendingDeletion = nil
                }
            }
            Button("Cancel", role: .cancel) {
                takePendingDeletion = nil
            }
        }
        .overlay {
            if showAudioSelection {
                Color.black.opacity(0.45)
                    .ignoresSafeArea()
                    .overlay(
                        PIPAudioSelectionModal(
                            session: $session,
                            choice: $audioSelection,
                            onCancel: {
                                showAudioSelection = false
                                pendingExportPortrait = nil
                                pendingExportLandscape = nil
                            },
                            onSave: {
                                guard let portrait = pendingExportPortrait,
                                      let landscape = pendingExportLandscape else { return }
                                showAudioSelection = false
                                let selection = audioSelection
                                session.portraitAudioMuted = !selection.usePortrait
                                session.landscapeAudioMuted = !selection.useLandscape
                                pendingExportPortrait = nil
                                pendingExportLandscape = nil
                                exportComposite(
                                    pipSession: session,
                                    portrait: portrait,
                                    landscape: landscape,
                                    audioChoice: selection
                                )
                            }
                        )
                        .frame(maxWidth: 360)
                        .padding()
                    )
            }
        }
        .onChange(of: externalSaveTrigger?.wrappedValue ?? 0, initial: false) { _, newValue in
            guard externalSaveTrigger != nil, newValue > 0 else { return }
            if showAudioSelection {
                return
            }
            presentAudioSelectionFlow()
        }
    }
    
    @ViewBuilder
    private func portraitLayout(geo: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            PIPSlateLivePreview(
                session: $session,
                liveSession: nil,
                activeLiveMode: nil,
                usesPassiveLivePreview: false
            )
            .frame(height: geo.size.height * 0.45)
            editorControls()
                .frame(maxHeight: .infinity)
        }
    }
    
    @ViewBuilder
    private func landscapeLayout(geo: GeometryProxy) -> some View {
        HStack(spacing: 0) {
            PIPSlateLivePreview(
                session: $session,
                liveSession: nil,
                activeLiveMode: nil,
                usesPassiveLivePreview: false
            )
            .frame(width: geo.size.width * 0.55)
            editorControls()
                .frame(maxWidth: .infinity)
        }
    }
    
    @ViewBuilder
    private func editorControls() -> some View {
        VStack(spacing: Theme.Layout.smallPadding) {
            Picker("Orientation", selection: $selectedTab) {
                Text(EditorTab.landscape.title).tag(EditorTab.landscape)
                Text(EditorTab.portrait.title).tag(EditorTab.portrait)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.top, 8)
            
            Divider()
            
            switch selectedTab {
            case .landscape:
                SlatePIPEditorViewLandscape(
                    session: $session,
                    onDelete: { take in takePendingDeletion = (take, .landscape) },
                    onPreview: { take in previewURL = take.fileURL }
                )
            case .portrait:
                SlatePIPEditorViewPortrait(
                    session: $session,
                    onDelete: { take in takePendingDeletion = (take, .portrait) },
                    onPreview: { take in previewURL = take.fileURL }
                )
            }
            
            if let status = exportStatus {
                Text(status)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            }
            
            let canSave = session.selectedPortraitTake != nil && session.selectedLandscapeTake != nil
            Button {
                presentAudioSelectionFlow()
            } label: {
                HStack(spacing: 6) {
                    if isExporting {
                        ProgressView()
                            .scaleEffect(0.7)
                            .tint(.white)
                    } else {
                        Image(systemName: "square.and.arrow.down.on.square")
                    }
                    Text(isExporting ? "Saving…" : "Save Slate as new video")
                        .font(.caption.weight(.semibold))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .background(
                    Capsule()
                        .fill((canSave && !isExporting) ? Theme.primary : Theme.primary.opacity(0.35))
                )
                .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .disabled(isExporting || !canSave)
            .padding([.horizontal, .bottom])
        }
        .background {
            if isEmbedded {
                Color.clear
            } else {
                BrandBackground()
            }
        }
    }
    
    private func presentAudioSelectionFlow() {
        guard let portrait = session.selectedPortraitTake,
              let landscape = session.selectedLandscapeTake else { return }
        pendingExportPortrait = portrait
        pendingExportLandscape = landscape
        audioSelection = AudioSelectionChoice(
            usePortrait: !session.portraitAudioMuted,
            useLandscape: true
        )
        showAudioSelection = true
    }
    
    private func exportComposite(
        pipSession: SlatePIPSession,
        portrait: PIPSlateTake,
        landscape: PIPSlateTake,
        audioChoice: AudioSelectionChoice? = nil
    ) {
        var sessionConfig = pipSession
        if let audioChoice {
            sessionConfig.portraitAudioMuted = !audioChoice.usePortrait
            sessionConfig.landscapeAudioMuted = !audioChoice.useLandscape
        }
        
        isExporting = true
        exportStatus = "Preparing export…"
        print("🎬 PIPSlateEditor: Starting export with portrait=\(portrait.filePath), landscape=\(landscape.filePath), portraitAudioEnabled=\(!sessionConfig.portraitAudioMuted), landscapeAudioEnabled=\(!sessionConfig.landscapeAudioMuted)")
        
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("pip_slate_preview_\(UUID().uuidString).mp4")
        
        let audioMetadata = PIPSlateCompositeMetadata(
            portraitTakeID: portrait.id,
            landscapeTakeID: landscape.id,
            portraitAudioEnabled: !sessionConfig.portraitAudioMuted,
            landscapeAudioEnabled: !sessionConfig.landscapeAudioMuted
        )
        
        PIPSlateExporter.exportPIPSlate(
            pipSession: sessionConfig,
            portraitURL: portrait.fileURL,
            landscapeURL: landscape.fileURL,
            outputURL: tempURL
        ) { result in
            switch result {
            case .success(let url):
                print("✅ PIPSlateEditor: Export succeeded at \(url.lastPathComponent)")
                persistCompositeOutput(
                    at: url,
                    portrait: portrait,
                    landscape: landscape,
                    audioMetadata: audioMetadata
                )
            case .failure(let error):
                DispatchQueue.main.async {
                    self.isExporting = false
                    self.exportStatus = "Export failed: \(error.localizedDescription)"
                    self.mutePreviewAudio()
                    print("❌ PIPSlateEditor: Export failed with error \(error)")
                }
            }
        }
    }
    
    private func persistCompositeOutput(
        at url: URL,
        portrait: PIPSlateTake,
        landscape: PIPSlateTake,
        audioMetadata: PIPSlateCompositeMetadata
    ) {
        Task(priority: .userInitiated) {
            do {
                let asset = AVURLAsset(url: url)
                let duration = try await asset.load(.duration).seconds
                let savedTake = try SessionManager.shared.storePIPCompositeTake(
                    from: url,
                    duration: duration,
                    project: project,
                    session: projectSession,
                    selectedPortrait: portrait,
                    selectedLandscape: landscape,
                    pipMetadata: audioMetadata
                )

                await MainActor.run {
                    self.isExporting = false
                    let label = savedTake.slateID ?? savedTake.slateNumber ?? "PiP Slate"
                    self.exportStatus = "Saved \(label)"
                    self.onCompositeSaved?()
                    self.mutePreviewAudio()
                }
            } catch {
                await MainActor.run {
                    self.isExporting = false
                    self.exportStatus = "Save failed: \(error.localizedDescription)"
                    self.mutePreviewAudio()
                }
            }
        }
    }
    
    private func deleteTake(_ take: PIPSlateTake, orientation: VideoOrientation) {
        switch orientation {
        case .portrait:
            session.portraitTakes.removeAll { $0.id == take.id }
            if session.selectedPortraitID == take.id {
                session.selectedPortraitID = session.portraitTakes.last?.id
            }
        case .landscape:
            session.landscapeTakes.removeAll { $0.id == take.id }
            if session.selectedLandscapeID == take.id {
                session.selectedLandscapeID = session.landscapeTakes.last?.id
            }
        }
    }
    
    private func syncSelectedTabWithAvailableTakes() {
        let portraitCount = session.portraitTakes.count
        let landscapeCount = session.landscapeTakes.count

        print("🧭 PIPSlateEditor: syncSelectedTabWithAvailableTakes portrait=\(portraitCount) landscape=\(landscapeCount) currentTab=\(selectedTab)")

        if session.selectedPortraitTake == nil,
           let firstPortrait = session.portraitTakes.first {
            session.selectedPortraitID = firstPortrait.id
            print("🧭 PIPSlateEditor: set selectedPortraitID -> \(firstPortrait.id)")
        }
        if session.selectedLandscapeTake == nil,
           let firstLandscape = session.landscapeTakes.first {
            session.selectedLandscapeID = firstLandscape.id
            print("🧭 PIPSlateEditor: set selectedLandscapeID -> \(firstLandscape.id)")
        }
        
        if session.selectedPortraitTake == nil &&
            session.selectedLandscapeTake != nil {
            selectedTab = .landscape
        } else if session.selectedLandscapeTake == nil &&
                    session.selectedPortraitTake != nil {
            selectedTab = .portrait
        } else if session.selectedPortraitTake != nil {
            selectedTab = .portrait
        } else {
            selectedTab = .landscape
        }

        print("🧭 PIPSlateEditor: resolvedTab=\(selectedTab)")
    }

    private func mutePreviewAudio() {
        session.portraitAudioMuted = true
        session.landscapeAudioMuted = true
    }
}

struct AudioSelectionChoice {
    var usePortrait: Bool = false
    var useLandscape: Bool = true
}

struct VideoPreviewSheet: UIViewControllerRepresentable {
    let url: URL
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        if #available(iOS 16.0, *) {
            controller.allowsVideoFrameAnalysis = false
        }
        controller.player = AVPlayer(url: url)
        controller.player?.play()
        context.coordinator.observe(player: controller.player)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {}
    
    static func dismantleUIViewController(_ uiViewController: AVPlayerViewController, coordinator: Coordinator) {
#if DEBUG
        let teardownID = UUID().uuidString
        let playerID = uiViewController.player.map { String(describing: ObjectIdentifier($0)) } ?? "nil"
        let itemStatus = uiViewController.player?.currentItem?.status.rawValue ?? -1
        print("🧪 VideoPreviewSheet.dismantle id=\(teardownID) isPiP=true player=\(playerID) item=\(itemStatus) main=\(Thread.isMainThread)")
        print("🧪 VideoPreviewSheet.pause id=\(teardownID) player=\(playerID)")
#endif
        uiViewController.player?.pause()
        coordinator.stopObserving()
    }

    final class Coordinator {
        private var idleTimerToken: IdleTimerController.Token?
        private var timeControlObservation: NSKeyValueObservation?

        func observe(player: AVPlayer?) {
            guard let player else { return }
            timeControlObservation?.invalidate()
            timeControlObservation = player.observe(\.timeControlStatus, options: [.initial, .new]) { [weak self] player, _ in
                let isPlaying = player.timeControlStatus == .playing
                Task { @MainActor [weak self] in
                    self?.updateIdleTimer(isPlaying)
                }
            }
        }

        func stopObserving() {
            timeControlObservation?.invalidate()
            timeControlObservation = nil
            Task { @MainActor [weak self] in
                self?.releaseIdleTimer()
            }
        }

        @MainActor
        private func updateIdleTimer(_ isPlaying: Bool) {
            if isPlaying {
                if idleTimerToken == nil {
                    idleTimerToken = IdleTimerController.shared.acquire(reason: "PiPVideoPreview")
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

        deinit {
            stopObserving()
        }
    }
}

struct PIPAudioSelectionModal: View {
    @Binding var session: SlatePIPSession
    @Binding var choice: AudioSelectionChoice
    let onCancel: () -> Void
    let onSave: () -> Void
    
    private var canSave: Bool { choice.usePortrait || choice.useLandscape }
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Select PiP Audio")
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Button(action: onCancel) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            
            PIPSlateLivePreview(
                session: $session,
                liveSession: nil,
                activeLiveMode: nil,
                usesPassiveLivePreview: true,
                isModeSelectionEnabled: false,
                showsAudioControls: false
            )
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .frame(height: 240)
            
            VStack(spacing: 12) {
                audioSelectionToggle(for: .portrait)
                audioSelectionToggle(for: .landscape)
            }
            .padding(.horizontal)
            
            Text("Select the video angles that should provide audio in the final video.")
                .font(.caption)
                .foregroundStyle(Theme.Colors.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button(action: onSave) {
                Text("Finalize Picture-in-Picture Slate")
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(canSave ? Theme.primary : Theme.primary.opacity(0.4))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(!canSave)
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .shadow(color: .black.opacity(0.4), radius: 20, x: 0, y: 10)
    }
    
    private enum AudioOrientation {
        case portrait
        case landscape
    }
    
    private func binding(for orientation: AudioOrientation) -> Binding<Bool> {
        Binding(
            get: {
                switch orientation {
                case .portrait: return choice.usePortrait
                case .landscape: return choice.useLandscape
                }
            },
            set: { newValue in
                var portrait = choice.usePortrait
                var landscape = choice.useLandscape
                
                switch orientation {
                case .portrait:
                    portrait = newValue
                case .landscape:
                    landscape = newValue
                }
                choice.usePortrait = portrait
                choice.useLandscape = landscape
            }
        )
    }
    
    private func audioSelectionToggle(for orientation: AudioOrientation) -> some View {
        let title = orientation == .portrait ? "Full Body Audio" : "Close-Up Audio"
        let binding = binding(for: orientation)
        let icon = binding.wrappedValue ? "waveform.badge.checkmark" : "waveform.badge.xmark"
        
        return Toggle(isOn: binding) {
            Label(title, systemImage: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.textPrimary)
        }
        .toggleStyle(SwitchToggleStyle(tint: Theme.primary))
    }
}
