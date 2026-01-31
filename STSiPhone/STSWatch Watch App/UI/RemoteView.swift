import SwiftUI
import WatchKit

enum RemoteMode: CaseIterable {
    case scene, slate, photo
    
    var label: String {
        switch self {
        case .scene: return "Scene"
        case .slate: return "Slate"
        case .photo: return "Photo"
        }
    }
}
@available(watchOS 10.0, *)
@available(watchOS 10.0, *)
struct RemoteView: View {
    @StateObject private var bridge = WatchBridge.shared
    @State private var mode: RemoteMode = .scene
    @State private var sceneIndex: Int = 1
    @State private var crownSceneValue: Double = 1
    @State private var isShowingSceneOverlay = false
    @State private var sceneOverlayHideWorkItem: DispatchWorkItem?
    @State private var sceneChangeOrigin: SceneChangeOrigin = .remote
    @State private var slateStyleIndex: Int = 0
    @State private var isShowingInfo: Bool = false
    @State private var isShowingQuickModeMenu: Bool = false
    
    private var sceneRange: ClosedRange<Int> {
        let maxScenes = max(1, min(bridge.sceneCount, 10))
        return 1...maxScenes
    }

    private var isCameraReady: Bool {
        bridge.hasReceivedStatus
    }

    private var statusDotColor: Color {
        isCameraReady ? .green : .orange
    }

    /// Temporary feature flag to allow fallback to the old layout if needed.
    private let useCoinRemote: Bool = true
    
    private enum SceneChangeOrigin {
        case crown
        case picker
        case remote
    }
    
    @available(watchOS 10.0, *)
    @available(watchOS 10.0, *)
    @available(watchOS 10.0, *)
    @available(watchOS 10.0, *)
    @available(watchOS 10.0, *)
    var body: some View {
        ZStack {
            remoteBackground

            let content = remoteContent

            Group {
                if useCoinRemote {
                    content
                        .focusable(mode == .scene)
                        .digitalCrownRotation(
                            $crownSceneValue,
                            from: Double(sceneRange.lowerBound),
                            through: Double(sceneRange.upperBound),
                            by: 1,
                            sensitivity: .medium,
                            isContinuous: false,
                            isHapticFeedbackEnabled: true
                        )
                        .onChange(of: crownSceneValue, initial: false) { _, newValue in
                            handleCrownChange(newValue)
                        }
                } else {
                    content
                        .highPriorityGesture(swipeGesture)
                        .focusable(mode == .scene)
                        .digitalCrownRotation(
                            $crownSceneValue,
                            from: Double(sceneRange.lowerBound),
                            through: Double(sceneRange.upperBound),
                            by: 1,
                            sensitivity: .medium,
                            isContinuous: false,
                            isHapticFeedbackEnabled: true
                        )
                        .onChange(of: crownSceneValue, initial: false) { _, newValue in
                            handleCrownChange(newValue)
                        }
                }
            }
            .overlay(alignment: .topLeading) {
                Button {
                    bridge.requestStatus()
                    WKInterfaceDevice.current().play(.click)
                } label: {
                    statusIndicator
                }
                .buttonStyle(.plain)
            }
            .overlay(alignment: .bottomLeading) {
                infoChip
            }
        }
    .overlay(sceneOverlayLayer)
.overlay(alignment: .center) {
    if isShowingQuickModeMenu {
        quickModeMenu
            .transition(
                .scale(scale: 0.85)
                .combined(with: .opacity)
            )
    }
}
.animation(
    .spring(response: 0.35, dampingFraction: 0.8),
    value: isShowingQuickModeMenu
)
.sheet(isPresented: $isShowingInfo) {
    infoSheet
}
        .onAppear {
            bridge.start()
            applyMode()
            handleSceneCountChange(bridge.sceneCount)
        }
        .onDisappear {
            sceneOverlayHideWorkItem?.cancel()
        }
        .onChange(of: mode, initial: false) { _, newMode in
            handleModeChange(newMode)
        }
        .onChange(of: sceneIndex, initial: false) { oldValue, newValue in
            handleSceneIndexChange(from: oldValue, to: newValue)
        }
        .onChange(of: slateStyleIndex, initial: false) { _, newValue in
            handleSlateStyleIndexChange(newValue)
        }
        .onChange(of: bridge.sceneCount, initial: false) { _, newValue in
            handleSceneCountChange(newValue)
        }
        .onChange(of: bridge.remoteModeValue, initial: true) { _, newValue in
            syncModeFromBridge(newValue)
        }
        .onChange(of: bridge.remoteSceneIndex, initial: true) { _, newValue in
            syncSceneIndexFromBridge(newValue)
        }
        .onChange(of: bridge.remoteSlateStyleIndex, initial: true) { _, newValue in
            syncSlateStyleIndexFromBridge(newValue)
        }
    }

    @ViewBuilder
    private var remoteContent: some View {
        if useCoinRemote {
            coinRemoteContent
        } else {
            legacyRemoteContent
        }
    }

    private var legacyRemoteContent: some View {
        VStack(spacing: 12) {
            previewSection
            
            Text(bridge.modeLabel)
                .font(.caption)
                .opacity(0.8)
            
            recordButton
            
            modePicker
                .frame(maxWidth: .infinity)
            
            if mode == .scene {
                scenePicker
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 12)
    }
    
    private var coinRemoteContent: some View {
        GeometryReader { proxy in
            SpinnerRemoteCoinView(
                mode: $mode,
                sceneIndex: $sceneIndex,
                slateStyleIndex: $slateStyleIndex,
                maxSceneCount: sceneRange.upperBound,
                isRecording: Binding(
                    get: { bridge.isRecording },
                    set: { _ in }
                ),
                isCameraReady: isCameraReady,
                onModeOffset: { offset in
                    moveMode(offset: offset)
                },
                onSceneChanged: { newScene in
                    sceneChangeOrigin = .remote
                    sceneIndex = newScene
                },
                onSlateStyleChanged: { newIndex in
                    slateStyleIndex = newIndex
                },
                onRecordTapped: {
                    handlePrimaryTap()
                },
                onQuickAdvance: {
                    quickAdvanceForCurrentMode()
                },
                onLongPress: {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        isShowingQuickModeMenu = true
                    }
                }
            )
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .center)
        }
        .padding(.horizontal, 2)
        .padding(.vertical, 2)
    }
    
    private var previewSection: some View {
        Group {
            if let thumbnail = bridge.thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .scaledToFit()
                    .cornerRadius(8)
                    .frame(maxHeight: 100)
            } else {
                Text("Preview")
                    .font(.headline)
                    .frame(height: 80)
                    .frame(maxWidth: .infinity)
                    .background(Color.black.opacity(0.2), in: RoundedRectangle(cornerRadius: 10))
            }
        }
    }
    
    private var recordButton: some View {
        Button(action: toggleRecording) {
            Text(bridge.isRecording ? "Stop" : "Record")
                .font(.headline)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(bridge.isRecording ? .red : .green)
    }
    
    private var modePicker: some View {
        Picker("Mode", selection: $mode) {
            ForEach(RemoteMode.allCases, id: \.self) { value in
                Text(value.label).tag(value)
            }
        }
        .labelsHidden()
    }
    
    private var scenePicker: some View {
        Picker("Scene", selection: sceneSelectionBinding) {
            ForEach(sceneRange, id: \.self) { index in
                Text("Scene \(index)").tag(index)
            }
        }
        .labelsHidden()
    }
    
    private var sceneSelectionBinding: Binding<Int> {
        Binding(
            get: { sceneIndex },
            set: { newValue in
                sceneChangeOrigin = .picker
                sceneIndex = newValue
            }
        )
    }
    
    @ViewBuilder
    private var sceneOverlayLayer: some View {
        if isShowingSceneOverlay {
            VStack {
                Spacer()
                Text("Scene \(sceneIndex)")
                    .font(.headline)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.black.opacity(0.6), in: Capsule())
                    .shadow(radius: 6)
                    .padding(.bottom, 12)
            }
            .transition(.opacity)
            .animation(.easeInOut(duration: 0.2), value: isShowingSceneOverlay)
            .allowsHitTesting(false)
        }
    }

private var infoChip: some View {
    Button(action: {
        isShowingInfo = true
    }) {
        Image(systemName: "info.circle")
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(.white.opacity(0.9))
    }
    .buttonStyle(.plain)
    .padding(.leading, 10)
    .padding(.bottom, 12)
}

private var statusIndicator: some View {
    Circle()
        .fill(statusDotColor)
        .frame(width: 10, height: 10)
        .padding(.top, 6)
        .padding(.leading, 6)
}

    private var infoSheet: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text("Apple Watch Remote Coin")
                    .font(.headline)
                    .padding(.bottom, 4)

                Group {
                    Text("Current Controls")
                        .font(.subheadline.weight(.semibold))

                    Text("• Swipe left/right to switch: Scene • Slate • Photo.")
                    Text("• Swipe up/down in Scene mode to change Scene #.")
                    Text("• Swipe up/down in Slate mode to switch: Original • SmartFill • PiP.")
                    Text("• Turn the Digital Crown in Scene mode to change Scene #.")
                    Text("• Tap the coin to start/stop recording (only when ready).")
                    Text("• Double-tap for quick advance (next scene / next slate style).")
                    Text("• Long-press to open Quick Mode.")
                }

                Group {
                    Text("Quick Mode")
                        .font(.subheadline.weight(.semibold))
                        .padding(.top, 6)

                    Text("• Long-press the coin to jump to Scene, Slate, or Photo instantly.")
                }

                Group {
                    Text("Status Dot")
                        .font(.subheadline.weight(.semibold))
                        .padding(.top, 6)

                    Text("• 🟠 Orange: Waiting — open the iTFactor camera to go live.")
                    Text("• 🟢 Green: Live — remote is controlling the iTFactor camera.")
                }

                Group {
                    Text("Tips")
                        .font(.subheadline.weight(.semibold))
                        .padding(.top, 6)

                    Text("• If the iPhone app closes, the remote will return to idle automatically.")
                    Text("• If taps don’t respond, Close and re-Open the iTFactor camera and wait for 🟢.")
                }
            }
            .padding()
        }
    }
    
    private var remoteBackground: some View {
        LinearGradient(
            colors: [
                Color(red: 0.05, green: 0.06, blue: 0.15),
                Color(red: 0.10, green: 0.15, blue: 0.30),
                Color(red: 0.07, green: 0.05, blue: 0.20)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
    
    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 20)
            .onEnded { value in
                handleSwipe(translation: value.translation)
            }
    }
    
    private func toggleRecording() {
        let shouldStart = !bridge.isRecording
        bridge.record(start: shouldStart)
        WKInterfaceDevice.current().play(shouldStart ? .start : .stop)
    }
    
    private func handlePrimaryTap() {
        guard isCameraReady else { return }
        if mode == .photo {
            bridge.capturePhoto()
            WKInterfaceDevice.current().play(.click)
        } else {
            toggleRecording()
        }
    }
    
    private func handleModeChange(_ newMode: RemoteMode) {
        if newMode == .scene {
            crownSceneValue = Double(sceneIndex)
        } else {
            hideSceneOverlay()
        }
        applyMode()
    }
    
    private func handleCrownChange(_ newValue: Double) {
        guard mode == .scene else { return }
        let rounded = round(newValue)
        let clamped = min(Double(sceneRange.upperBound), max(Double(sceneRange.lowerBound), rounded))
        let newScene = Int(clamped)
        guard newScene != sceneIndex else { return }
        sceneChangeOrigin = .crown
        sceneIndex = newScene
    }
    
    private func handleSceneIndexChange(from oldValue: Int, to newValue: Int) {
        guard newValue != oldValue else { return }
        crownSceneValue = Double(newValue)
        applyMode()
        if mode == .scene && sceneChangeOrigin != .remote {
            showSceneOverlayWithAutoHide()
            if sceneChangeOrigin == .crown {
                WKInterfaceDevice.current().play(.click)
            }
        }
        sceneChangeOrigin = .remote
    }
    
    private func handleSceneCountChange(_ newValue: Int) {
        let limited = max(1, min(newValue, 10))
        var adjustedIndex = sceneIndex
        if adjustedIndex > limited {
            adjustedIndex = limited
        }
        if adjustedIndex < 1 {
            adjustedIndex = 1
        }
        if adjustedIndex != sceneIndex {
            sceneChangeOrigin = .remote
            sceneIndex = adjustedIndex
        }
        crownSceneValue = Double(sceneIndex)
    }
    
    private func showSceneOverlayWithAutoHide() {
        isShowingSceneOverlay = true
        sceneOverlayHideWorkItem?.cancel()
        
        let workItem = DispatchWorkItem {
            withAnimation(.easeOut(duration: 0.2)) {
                isShowingSceneOverlay = false
            }
        }
        sceneOverlayHideWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0, execute: workItem)
    }
    
    private func hideSceneOverlay() {
        sceneOverlayHideWorkItem?.cancel()
        sceneOverlayHideWorkItem = nil
        withAnimation(.easeOut(duration: 0.2)) {
            isShowingSceneOverlay = false
        }
    }
    
    private func applyMode() {
        switch mode {
        case .scene:
            bridge.setMode("scene", index: sceneIndex)
        case .slate:
            bridge.setMode("slate", index: slateStyleIndex)
        case .photo:
            bridge.setMode("photo")
        }
    }
    
    private func handleSlateStyleIndexChange(_ newValue: Int) {
        guard mode == .slate else { return }
        bridge.setMode("slate", index: newValue)
    }
    
    private func syncModeFromBridge(_ value: String) {
        guard let target = RemoteMode(bridgeValue: value) else { return }
        guard target != mode else { return }
        mode = target
    }
    
    private func syncSceneIndexFromBridge(_ newValue: Int) {
        let clamped = min(sceneRange.upperBound, max(sceneRange.lowerBound, newValue))
        guard clamped != sceneIndex else { return }
        sceneChangeOrigin = .remote
        sceneIndex = clamped
    }
    
    private func syncSlateStyleIndexFromBridge(_ newValue: Int) {
        let clamped = min(2, max(0, newValue))
        guard clamped != slateStyleIndex else { return }
        slateStyleIndex = clamped
    }
    
private func handleSwipe(translation: CGSize) {
    guard abs(translation.width) > abs(translation.height),
          abs(translation.width) > 20 else { return }
    if translation.width < 0 {
        moveMode(offset: 1)
    } else {
        moveMode(offset: -1)
    }
}

private var quickModeMenu: some View {
    VStack(spacing: 8) {
        Text("Quick Mode")
            .font(.system(size: 13, weight: .semibold))

        HStack(spacing: 8) {
            quickModeButton(title: "Scene", mode: .scene, systemImage: "video.fill")
            quickModeButton(title: "Slate", mode: .slate, systemImage: "person.crop.rectangle.badge.video")
            quickModeButton(title: "Photo", mode: .photo, systemImage: "camera.fill")
        }
    }
    .padding(10)
    .background(Color.black.opacity(0.86))
    .clipShape(RoundedRectangle(cornerRadius: 12))
    .overlay(
        RoundedRectangle(cornerRadius: 12)
            .stroke(Color.white.opacity(0.25), lineWidth: 1)
    )
    .padding(8)
    .scaleEffect(isShowingQuickModeMenu ? 1.0 : 0.9)
}

private func quickModeButton(title: String, mode target: RemoteMode, systemImage: String) -> some View {
    Button(action: {
        jumpToModeFromQuickMenu(target)
    }) {
        VStack(spacing: 3) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .medium))
            Text(title)
                .font(.system(size: 11, weight: .semibold))
        }
        .frame(minWidth: 42)
        .padding(6)
        .background(self.mode == target ? Color.white.opacity(0.16) : Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
    .buttonStyle(.plain)
}

private func quickAdvanceForCurrentMode() {
    switch mode {
    case .scene:
        let next = min(sceneRange.upperBound, sceneIndex + 1)
        guard next != sceneIndex else { return }
        sceneChangeOrigin = .remote
        sceneIndex = next
    case .slate:
        let maxIndex = 2
        let next = (slateStyleIndex + 1) > maxIndex ? 0 : (slateStyleIndex + 1)
        slateStyleIndex = next
    case .photo:
        WKInterfaceDevice.current().play(.click)
    }
}

private func moveMode(offset: Int) {
    guard let currentIndex = RemoteMode.allCases.firstIndex(of: mode) else { return }
    let newIndex = currentIndex + offset
    guard RemoteMode.allCases.indices.contains(newIndex) else { return }
    mode = RemoteMode.allCases[newIndex]
}

private func jumpToModeFromQuickMenu(_ target: RemoteMode) {
    defer {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
            isShowingQuickModeMenu = false
        }
    }
    if target == mode { return }

    let ordered: [RemoteMode] = [.scene, .slate, .photo]
    guard let currentIndex = ordered.firstIndex(of: mode),
          let targetIndex = ordered.firstIndex(of: target) else { return }

    let diff = targetIndex - currentIndex
    if diff > 0 {
        for _ in 0..<diff { moveMode(offset: 1) }
    } else if diff < 0 {
        for _ in 0..<(-diff) { moveMode(offset: -1) }
    }
}
}

private extension RemoteMode {
    init?(bridgeValue: String) {
        switch bridgeValue.lowercased() {
        case "scene":
            self = .scene
        case "slate":
            self = .slate
        case "photo":
            self = .photo
        default:
            return nil
        }
    }
}
