import SwiftUI

struct SceneSelectorView: View {
    @ObservedObject var sessionManager = SessionManager.shared
    @State private var showWrapConfirmation = false
    @State private var wrapMessage = ""
    @State private var showScenePopover = false
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    
    var onComplete: (() -> Void)?
    var onSlateAction: (() -> Void)?
    var onKeyframeAction: (() -> Void)?
    var debugCameraID: String?
    
    init(
        onComplete: (() -> Void)? = nil,
        onSlateAction: (() -> Void)? = nil,
        onKeyframeAction: (() -> Void)? = nil,
        debugCameraID: String? = nil
    ) {
        self.onComplete = onComplete
        self.onSlateAction = onSlateAction
        self.onKeyframeAction = onKeyframeAction
        self.debugCameraID = debugCameraID
    }
    
    var body: some View {
        GeometryReader { geometry in
            let isPortrait = geometry.size.width < geometry.size.height
            
            HStack(spacing: isPortrait ? 6 : 8) {
                sceneControl(isPortrait: isPortrait)
                
                pillButton(
                    title: "Slate",
                    systemImage: "tv",
                    isDone: slateDone,
                    isActive: sessionManager.isRecordingSlate,
                    isPortrait: isPortrait
                ) {
                    onSlateAction?() ?? sessionManager.switchToSlateMode()
                }
                
                pillButton(
                    title: isPortrait ? "Photo" : "Keyframe",
                    systemImage: "camera.fill",
                    isDone: keyframeDone,
                    isActive: sessionManager.isRecordingKeyframePhoto,
                    isPortrait: isPortrait
                ) {
                    if let onKeyframeAction {
                        onKeyframeAction()
                    } else {
                        sessionManager.switchToKeyframePhotoMode()
                    }
                }
                
                pillButton(
                    title: "Wrap",
                    systemImage: "sharedwithyou",
                    isDone: allCategoriesComplete,
                    isActive: false,
                    isPortrait: isPortrait
                ) {
                    handleWrapAction()
                }
            }
            .padding(.horizontal, isPortrait ? 6 : 8)
            .padding(.vertical, isPortrait ? 8 : 6)
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .center)
        }
        .frame(height: 40)
        .background(.ultraThinMaterial.opacity(0.9), in: Capsule())
        .alert("Complete Session", isPresented: $showWrapConfirmation) {
            Button("Exit Camera Session", role: .destructive) {
                debugLog("Wrap prompt: user confirmed exit – calling onComplete")
                onComplete?()
            }
            Button("Keep Recording", role: .cancel) {
                debugLog("Wrap prompt: user chose to keep recording")
            }
        } message: {
            Text(wrapMessage)
        }
    }
    
    private func sceneControl(isPortrait: Bool) -> some View {
        let title = isPortrait ? "S\(sessionManager.currentScene)" : "Scene \(sessionManager.currentScene)"
        let isSceneActive = !sessionManager.isRecordingSlate && !sessionManager.isRecordingKeyframePhoto
        
        return Group {
            if sessionManager.totalScenes > 1 {
                SceneSelectorButton(
                    isShowingScenes: $showScenePopover,
                    title: title,
                    isDone: progress.allScenesComplete,
                    isActive: isSceneActive,
                    isPortrait: isPortrait
                ) {
                    scenePickerPopover(isPortrait: isPortrait)
                }
            } else {
                Button {
                    sessionManager.switchToSceneMode()
                } label: {
                    pillLabel(title: title, systemImage: "video.fill", isDone: sceneHasVideo, isActive: isSceneActive, isPortrait: isPortrait)
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private func scenePickerPopover(isPortrait: Bool) -> some View {
        let maxHeight: CGFloat = {
            let screenHeight = UIScreen.main.bounds.height
            return screenHeight * (isPortrait ? 0.65 : 0.5)
        }()

        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Select Scene")
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.85))
                
                ForEach(1...sessionManager.totalScenes, id: \.self) { scene in
                    scenePickerRow(for: scene)
                }
            }
            .padding(18)
        }
        .frame(width: isPortrait ? 260 : 280, alignment: .top)
        .frame(maxHeight: maxHeight, alignment: .top)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.black.opacity(0.8))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.25), lineWidth: 1)
                )
        )
    }

    @ViewBuilder
    private func scenePickerRow(for scene: Int) -> some View {
        let isCurrent = scene == sessionManager.currentScene
        let hasSceneTake = progress.scenesWithRegularTakes.contains(scene)
        Button {
            selectScene(scene)
        } label: {
            HStack {
                Text(sceneLabel(for: scene))
                    .font(.body.weight(isCurrent ? .semibold : .regular))
                    .foregroundStyle(.white)

                Spacer()

                if hasSceneTake {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.green)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                Capsule()
                    .fill(hasSceneTake ? Color.green.opacity(0.2) : Color.black.opacity(isCurrent ? 0.55 : 0.35))
            )
            .overlay(
                Capsule()
                    .stroke(hasSceneTake ? Color.green.opacity(0.8) : Color.white.opacity(isCurrent ? 0.55 : 0.25), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("ScenePicker_\(scene)")
    }
    
    private func selectScene(_ scene: Int) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        sessionManager.switchToScene(scene)
        sessionManager.switchToSceneMode()
        showScenePopover = false
    }
    
    private func pillButton(
        title: String,
        systemImage: String,
        isDone: Bool,
        isActive: Bool,
        isPortrait: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        }) {
            pillLabel(title: title, systemImage: systemImage, isDone: isDone, isActive: isActive, isPortrait: isPortrait)
        }
        .buttonStyle(.plain)
    }
    
    private func pillLabel(
        title: String,
        systemImage: String,
        isDone: Bool,
        isActive: Bool = false,
        isPortrait: Bool = false
    ) -> some View {
        HStack(spacing: isPortrait ? 4 : 6) {
            Image(systemName: systemImage)
                .imageScale(isPortrait ? .small : .medium)
                .font(isPortrait ? .caption : .body)
            
            if !isPortrait || title.count <= 5 {
                Text(title)
                    .font(.system(size: isPortrait ? 11 : 14, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .padding(.horizontal, isPortrait ? 6 : 10)
        .padding(.vertical, isPortrait ? 6 : 7)
        .foregroundColor(isActive ? .white : .primary)
        .background(
            isActive
            ? Color.blue.opacity(0.8)
            : isDone
                ? Color.green.opacity(0.28)
                : Color.secondary.opacity(0.15)
        )
        .overlay(
            Capsule().stroke(
                isActive
                ? Color.white.opacity(0.6)
                : isDone
                    ? Color.green
                    : Color.white.opacity(0.25),
                lineWidth: isActive ? 1.5 : 1
            )
        )
        .clipShape(Capsule())
        .scaleEffect(isActive ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isActive)
    }
    
    // MARK: - Wrap helpers
    private func handleWrapAction() {
        debugLog("Wrap tapped – evaluating recording state")
        let missingItems = progress.missingCategories
        if missingItems.isEmpty {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            debugLog("Wrap tapped – all categories complete, exiting immediately")
            onComplete?()
        } else {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            wrapMessage = createWrapMessage(for: missingItems)
            debugLog("Wrap tapped – missing categories: \(missingItems)")
            debugLog("Wrap prompt message: \(wrapMessage)")
            showWrapConfirmation = true
            debugLog("Wrap prompt presented: \(showWrapConfirmation)")
        }
    }

    private func debugLog(_ message: String) {
        if let debugCameraID {
            print("🎬 [SceneSelectorView] \(message) – cameraID = \(debugCameraID)")
        } else {
            print("🎬 [SceneSelectorView] \(message)")
        }
    }
    
    private func createWrapMessage(for missing: [SessionProgress.MissingCategory]) -> String {
        let missingScenes = missing.compactMap { category -> [Int]? in
            if case .scenes(let scenes) = category {
                return scenes
            }
            return nil
        }.flatMap { $0 }

        let hasSlate = missing.contains { category in
            if case .slate = category { return true }
            return false
        }

        let hasKeyframe = missing.contains { category in
            if case .keyframe = category { return true }
            return false
        }

        var parts: [String] = []
        if !missingScenes.isEmpty {
            let sceneList = missingScenes.map { "Scene \($0)" }.joined(separator: ", ")
            parts.append("takes for \(sceneList)")
        }
        if hasSlate {
            parts.append("a slate")
        }
        if hasKeyframe {
            parts.append("a photo for your thumbnail")
        }

        if parts.isEmpty {
            return "Are you sure you want to wrap?"
        }

        let description = joinForSentence(parts)
        return "You haven't recorded \(description). Are you sure you want to wrap?"
    }

    private func joinForSentence(_ parts: [String]) -> String {
        guard let first = parts.first else { return "" }
        if parts.count == 1 { return first }
        if parts.count == 2 { return "\(first) and \(parts[1])" }
        let allButLast = parts.dropLast().joined(separator: ", ")
        return "\(allButLast), and \(parts.last!)"
    }
    
    private var sceneHasVideo: Bool {
        progress.scenesWithRegularTakes.contains(sessionManager.currentScene)
    }
    
    private var slateDone: Bool {
        !sessionManager.getSlateTakesAsTakes().isEmpty
    }
    
    private var keyframeDone: Bool {
        !sessionManager.getKeyframePhotoTakesAsTakes().isEmpty
    }
    
    private var allCategoriesComplete: Bool {
        progress.allCategoriesComplete
    }

    private var progress: SessionProgress {
        sessionManager.effectiveSessionProgress
    }
    
    private func sceneLabel(for scene: Int) -> String {
        if scene == sessionManager.currentScene && isSceneModeActive {
            return "Scene \(scene) ✓"
        }
        return "Scene \(scene)"
    }

    private var isSceneModeActive: Bool {
        !sessionManager.isRecordingSlate && !sessionManager.isRecordingKeyframePhoto
    }
}
