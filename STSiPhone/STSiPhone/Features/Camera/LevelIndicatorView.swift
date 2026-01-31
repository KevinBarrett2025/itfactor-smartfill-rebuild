import SwiftUI
import CoreMotion

// MARK: - Level Indicator View
struct LevelIndicatorView: View {
    @StateObject private var motionManager = DeviceMotionManager()
    @State private var showIndicator = false
    @State private var isLevel = false
    @State private var hideIndicatorTask: Task<Void, Never>?
    @State private var lastReportedVisible = false

    let showInPortrait: Bool
    let showInLandscape: Bool
    let customBottomPadding: CGFloat?
    let isAlwaysOn: Bool
    let onVisibilityChanged: ((Bool) -> Void)?

    init(
        showInPortrait: Bool = true,
        showInLandscape: Bool = true,
        customBottomPadding: CGFloat? = nil,
        isAlwaysOn: Bool = false,
        onVisibilityChanged: ((Bool) -> Void)? = nil
    ) {
        self.showInPortrait = showInPortrait
        self.showInLandscape = showInLandscape
        self.customBottomPadding = customBottomPadding
        self.isAlwaysOn = isAlwaysOn
        self.onVisibilityChanged = onVisibilityChanged
    }

    var body: some View {
        GeometryReader { _ in
            ZStack {
                if shouldDisplayIndicator {
                    levelIndicatorContent
                        .transition(.opacity.combined(with: .scale))
                        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: showIndicator)
                        .animation(.easeInOut(duration: 0.3), value: isLevel)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onReceive(motionManager.$tiltAngle) { angle in
            updateLevelIndicator(angle: angle)
            reportVisibilityChangeIfNeeded()
        }
        .onReceive(motionManager.$isPortrait) { _ in
            if !isAlwaysOn,
               motionManager.isSignificantlyTilted && shouldShowForOrientation {
                showIndicator = true
            }
            reportVisibilityChangeIfNeeded()
        }
        .onAppear {
            motionManager.startUpdates()
            if isAlwaysOn {
                showIndicator = true
            }
            reportVisibilityChangeIfNeeded()
        }
        .onDisappear {
            motionManager.stopUpdates()
            hideIndicatorTask?.cancel()
            lastReportedVisible = false
            onVisibilityChanged?(false)
        }
    }

    private var shouldShowForOrientation: Bool {
        motionManager.isPortrait ? showInPortrait : showInLandscape
    }

    private var shouldDisplayIndicator: Bool {
        if isAlwaysOn {
            return shouldShowForOrientation
        } else {
            return showIndicator && shouldShowForOrientation
        }
    }

    @ViewBuilder
    private var levelIndicatorContent: some View {
        if motionManager.isPortrait {
            portraitLevelIndicator
        } else {
            landscapeLevelIndicator
        }
    }

    private var portraitLevelIndicator: some View {
        VStack {
            Spacer()
            levelBubbleStack
                .padding(.bottom, customBottomPadding ?? 150)
                .animation(.easeInOut(duration: 0.3), value: customBottomPadding)
        }
    }

    private var landscapeLevelIndicator: some View {
        VStack {
            Spacer()
            levelBubbleStack
                .padding(.bottom, customBottomPadding ?? 60)
                .animation(.easeInOut(duration: 0.3), value: customBottomPadding)
        }
    }

    private var levelBubbleStack: some View {
        VStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.black.opacity(0.7))
                    .frame(width: 120, height: 16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                    )

                Rectangle()
                    .fill(Color.white.opacity(0.5))
                    .frame(width: 2, height: 16)

                Circle()
                    .fill(isLevel ? .green : Color(red: 0.85, green: 0.45, blue: 0.2))
                    .frame(width: 12, height: 12)
                    .offset(x: min(max(motionManager.tiltAngle * 200, -54), 54))
                    .shadow(
                        color: isLevel ? .green.opacity(0.5) : .clear,
                        radius: isLevel ? 8 : 0
                    )

                HStack {
                    ForEach(-2...2, id: \.self) { mark in
                        Rectangle()
                            .fill(Color.white.opacity(mark == 0 ? 0.8 : 0.4))
                            .frame(width: 1, height: mark == 0 ? 20 : 12)
                            .offset(x: Double(mark) * 24)
                    }
                }
            }

            HStack(spacing: 12) {
                if isLevel {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption2)
                            .foregroundColor(.green)
                        Text("LEVEL")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.green)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.green.opacity(0.2))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.green.opacity(0.5), lineWidth: 1)
                            )
                    )
                }

                Text("\(abs(motionManager.tiltAngle * 180 / .pi), specifier: "%.1f")°")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(isLevel ? .green : .white)
                    .monospacedDigit()
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.black.opacity(0.7))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(
                                        isLevel
                                            ? Color.green.opacity(0.5)
                                            : Color.white.opacity(0.3),
                                        lineWidth: 1
                                    )
                            )
                    )
            }
        }
    }

    private func updateLevelIndicator(angle: Double) {
        let wasLevel = isLevel
        isLevel = abs(angle) < 0.0873

        if isAlwaysOn {
            showIndicator = shouldShowForOrientation
            hideIndicatorTask?.cancel()
            reportVisibilityChangeIfNeeded()
            return
        }

        if motionManager.isSignificantlyTilted && shouldShowForOrientation {
            showIndicator = true
            hideIndicatorTask?.cancel()
        }

        if isLevel && !wasLevel {
            scheduleIndicatorHide(delay: 4.0)
        } else if !isLevel {
            hideIndicatorTask?.cancel()
        }

        reportVisibilityChangeIfNeeded()
    }

    private func scheduleIndicatorHide(delay: TimeInterval = 3.0) {
        guard !isAlwaysOn else { return }

        hideIndicatorTask?.cancel()
        hideIndicatorTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            await MainActor.run {
                if !Task.isCancelled {
                    withAnimation(.easeOut(duration: 0.5)) {
                        showIndicator = false
                    }
                }
            }
        }
    }

    private func reportVisibilityChangeIfNeeded() {
        let visible = shouldDisplayIndicator
        if visible != lastReportedVisible {
            lastReportedVisible = visible
            onVisibilityChanged?(visible)
        }
    }
}

// MARK: - Device Motion Manager

@MainActor
class DeviceMotionManager: ObservableObject {
    @Published var tiltAngle: Double = 0
    @Published var isPortrait: Bool = true
    @Published var isSignificantlyTilted: Bool = false

    private let motionManager = CMMotionManager()
    private let updateInterval: TimeInterval = 1.0 / 30.0

    func startUpdates() {
        guard motionManager.isDeviceMotionAvailable else {
            print("⚠️ Device motion not available")
            return
        }

        motionManager.deviceMotionUpdateInterval = updateInterval

        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let self = self, let motion = motion else { return }

            let attitude = motion.attitude
            let currentOrientation = UIDevice.current.orientation
            self.isPortrait = currentOrientation.isPortrait || currentOrientation == .unknown

            let angle: Double
            if self.isPortrait {
                angle = attitude.roll
            } else {
                angle = attitude.pitch
            }

            self.tiltAngle = angle
            self.isSignificantlyTilted = abs(angle) > 0.1
        }
    }

    func stopUpdates() {
        motionManager.stopDeviceMotionUpdates()
    }
}

extension UIDeviceOrientation {
    var isPortrait: Bool {
        self == .portrait || self == .portraitUpsideDown
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()

        VStack {
            Text("Level Indicator Preview")
                .font(.headline)
                .foregroundColor(.white)

            Spacer()

            Text("Tilt your device to see the level indicator")
                .font(.caption)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .padding()

        LevelIndicatorView(showInPortrait: true, showInLandscape: true)
    }
}
