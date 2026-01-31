import SwiftUI
import WatchKit

/// A coin-based remote control suitable for use inside RemoteView.
/// Pure UI: state + callbacks are driven by RemoteView.
@available(watchOS 10.0, *)
struct SpinnerRemoteCoinView: View {

    // MARK: - External State

    @Binding var mode: RemoteMode
    @Binding var sceneIndex: Int
    @Binding var slateStyleIndex: Int

    let maxSceneCount: Int
    @Binding var isRecording: Bool
    let isCameraReady: Bool

    // MARK: - Callbacks

    let onModeOffset: (Int) -> Void
    let onSceneChanged: (Int) -> Void
    let onSlateStyleChanged: (Int) -> Void
    let onRecordTapped: () -> Void
    let onQuickAdvance: () -> Void
    let onLongPress: () -> Void

    // MARK: - Local Visual State

    @State private var xRotation: Double = 0
    @State private var yRotation: Double = 0
    @State private var isShowingLogoSide = true
    @State private var hasPlayedCameraReadyFlip = false
    @State private var isShining: Bool = false
    @State private var shinePhase: Double = 0

    private enum FaceState {
        case idle
        case armed
        case recording
    }

    @State private var faceState: FaceState = .idle

    // MARK: - Body

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            let coinSize = size * 0.94

            ZStack {
                coinImage
                    .resizable()
                    .scaledToFit()
                    .frame(width: coinSize, height: coinSize)
                    .shadow(radius: 6)

                if isCameraReady {
                    faceLabel
                }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(
            shineOverlay
                .mask(
                    Circle()
                )
        )
        .rotation3DEffect(.degrees(xRotation), axis: (x: 1, y: 0, z: 0), perspective: 0.7)
        .rotation3DEffect(.degrees(yRotation), axis: (x: 0, y: 1, z: 0), perspective: 0.7)
        .scaleEffect(isRecording ? 1.05 : 1.0)
            .padding(4)
            .animation(.spring(response: 0.45, dampingFraction: 0.85), value: xRotation)
            .animation(.spring(response: 0.45, dampingFraction: 0.85), value: yRotation)
            .animation(.easeInOut(duration: 0.25), value: isRecording)
            .contentShape(Rectangle())
            .allowsHitTesting(isCameraReady)
            .gesture(dragGesture)
            .simultaneousGesture(tapGestures)
            .simultaneousGesture(longPressGesture)
            .onAppear {
                updateFaceState()
            }
            .onChange(of: isRecording) { _, _ in
                updateFaceState()
            }
        .onChange(of: mode) { _, _ in
            guard isCameraReady else { return }
            flipHorizontally()
            updateFaceState()
            triggerShine()
        }
        .onChange(of: sceneIndex) { _, _ in
            guard isCameraReady, mode == .scene else { return }
            flipVertically()
            updateFaceState()
            triggerShine()
        }
        .onChange(of: slateStyleIndex) { _, _ in
            guard isCameraReady, mode == .slate else { return }
            flipVertically()
            updateFaceState()
            triggerShine()
        }
        .onChange(of: isCameraReady) { oldValue, newValue in
            guard newValue, !oldValue, !hasPlayedCameraReadyFlip else { return }
            hasPlayedCameraReadyFlip = true
            performCameraReadyFlip()
            triggerShine()
        }
        }
    }

    // MARK: - Coin Assets

    private var coinImage: Image {
        if !isCameraReady || isShowingLogoSide {
            return Image("remote_coin_logo")
        }

        switch faceState {
        case .idle:
            return Image("remote_coin_blank")
        case .armed:
            return Image("remote_coin_blank_armed")
        case .recording:
            return Image("remote_coin_blank_recording")
        }
    }

    @ViewBuilder
    private var faceLabel: some View {
        VStack(spacing: 4) {
            Text(primaryLabelText)
                .font(.system(size: primaryFontSize, weight: .bold, design: .rounded))
                .tracking(0.5)
                .minimumScaleFactor(0.5)

            if let secondary = secondaryLabelText {
                Text(secondary)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .opacity(0.8)
                    .minimumScaleFactor(0.5)
            }
        }
        .foregroundColor(.black.opacity(0.85))
        .padding(12)
        .multilineTextAlignment(.center)
    }

    private var shineOverlay: some View {
        GeometryReader { proxy in
            let size = max(proxy.size.width, proxy.size.height)

            LinearGradient(
                gradient: Gradient(stops: [
                    .init(color: Color.white.opacity(0.0), location: 0.0),
                    .init(color: Color.white.opacity(0.65), location: 0.45),
                    .init(color: Color.white.opacity(0.0), location: 1.0)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(width: size * 1.6, height: size * 1.6)
            .rotationEffect(.degrees(30))
            .offset(x: CGFloat(shinePhase - 0.5) * size * 1.8)
            .blendMode(.screen)
            .opacity(isShining ? 0.7 : 0.0)
        }
    }

    private var primaryLabelText: String {
        switch mode {
        case .scene:
            return "SCENE \(sceneIndex)"
        case .slate:
            return slateModeTitle
        case .photo:
            return "PHOTO"
        }
    }

    private var secondaryLabelText: String? {
        switch mode {
        case .scene:
            return nil
        case .slate:
            return "SLATE"
        case .photo:
            return nil
        }
    }
    
    private var primaryFontSize: CGFloat {
        if mode == .slate && slateStyleIndex == 1 {
            return 16
        }
        return 18
    }

    private var slateModeTitle: String {
        switch slateStyleIndex {
        case 1: return "SMARTFILL"
        case 2: return "PIP"
        default: return "NORMAL"
        }
    }

    // MARK: - Gestures

    private var tapGestures: some Gesture {
        TapGesture(count: 2)
            .onEnded {
                guard isCameraReady else { return }
                onQuickAdvance()
            }
            .exclusively(before:
                TapGesture(count: 1)
                    .onEnded {
                        guard isCameraReady else { return }
                        onRecordTapped()
                    }
            )
    }

    private var longPressGesture: some Gesture {
        LongPressGesture(minimumDuration: 0.45)
            .onEnded { _ in
                guard isCameraReady else { return }
                onLongPress()
            }
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 10)
            .onEnded { value in
                guard isCameraReady else { return }

                let dx = value.translation.width
                let dy = value.translation.height

                if abs(dx) > abs(dy) * 1.4, abs(dx) > 10 {
                    let offset = dx < 0 ? +1 : -1
                    onModeOffset(offset)
                    WKInterfaceDevice.current().play(.click)
                } else if abs(dy) > 10 {
                    let direction = dy < 0 ? +1 : -1
                    handleVerticalStep(direction: direction)
                }
            }
    }

    private func handleVerticalStep(direction: Int) {
        switch mode {
        case .scene:
            let next = min(maxSceneCount, max(1, sceneIndex + direction))
            guard next != sceneIndex else { return }
            onSceneChanged(next)

        case .slate:
            let maxIndex = 2
            let next = min(maxIndex, max(0, slateStyleIndex + direction))
            guard next != slateStyleIndex else { return }
            onSlateStyleChanged(next)

        case .photo:
            break
        }
    }

    // MARK: - Animation Helpers

    private func performCameraReadyFlip() {
        isShowingLogoSide = true
        withAnimation(.easeInOut(duration: 0.8)) {
            yRotation += 360
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            isShowingLogoSide = false
            updateFaceState()
        }
    }

    private func flipHorizontally() {
        isShowingLogoSide = true
        withAnimation(.easeInOut(duration: 0.8)) {
            yRotation += 360
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            isShowingLogoSide = false
        }
    }

    private func flipVertically() {
        isShowingLogoSide = true
        withAnimation(.easeInOut(duration: 0.8)) {
            xRotation += 360
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            isShowingLogoSide = false
        }
    }

    private func updateFaceState() {
        guard isCameraReady else {
            faceState = .idle
            return
        }
        faceState = isRecording ? .recording : .armed
    }

    /// Triggers a short diagonal shine sweep across the coin.
    private func triggerShine() {
        guard !isShining else { return }

        isShining = true
        shinePhase = -0.2

        withAnimation(.easeInOut(duration: 0.65)) {
            shinePhase = 1.2
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            isShining = false
        }
    }
}
