// ActorKitSpinnerCoinView.swift (v3)
// Self Tape Studio — ActorKit Badge Fidget Spinner
// iOS 16+ • Swift 5/6 compatible
import SwiftUI
import UIKit
import AVFoundation
import QuartzCore

public struct ActorKitSpinnerCoinView: View {
    // Faces
    public let front: Image           // e.g., Image("AppIconBadgeFilled")
    public let back: Image?           // optional headshot Image

    // Settings
    public var size: CGFloat
    public var edgeThickness: CGFloat
    public var ribs: Int
    public var dragSensitivity: CGFloat        // higher = faster spin per point dragged
    public var frictionPerSecond: CGFloat      // 0.92 -> loses ~8% speed each second
    public var randomNudgeRange: ClosedRange<CGFloat>
    public var whooshAssetName: String?        // e.g., "whoosh.caf" (bundled small < 150ms sfx)
    public var initialImpulse: CGFloat         // deg/sec to add on appear (for launch flourish)
    public var portalIsActive: Bool            // supplied by host when ActorKit is presented

    // Callback: host can start portal transition (e.g., fullScreenCover).
    public var onEnterActorKit: (() -> Void)?

    @AppStorage("ActorKit.disableBadgeAnimation") private var disableAnimation = false
    @AppStorage("ActorKit.badgeStopFace") private var badgeStopFaceRaw: String = ActorKitBadgeStopFace.logo.rawValue
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // State
    @State private var angle: CGFloat = 0           // degrees
    @State private var omega: CGFloat = 0           // deg/sec
    @State private var lastDragX: CGFloat? = nil
    @State private var isDragging = false
    @State private var isPressed = false            // long-press lift
    @State private var didApplyInitialImpulse = false
    @State private var portalTransitioning = false  // lock input, silence haptics, stop physics
    @State private var lastTapTime = Date.distantPast
    @State private var hapticsEnabled = true
    @State private var lastHapticAt: TimeInterval = 0
    @State private var hasSnappedToRest = false

    private let haptics = UIImpactFeedbackGenerator(style: .soft)
    private var sfx = SoundFXPlayer.shared
    private var badgeStopFace: ActorKitBadgeStopFace {
        ActorKitBadgeStopFace(rawValue: badgeStopFaceRaw) ?? .logo
    }

    public init(
        front: Image,
        back: Image?,
        size: CGFloat = 176,
        edgeThickness: CGFloat = 8,
        ribs: Int = 72,
        dragSensitivity: CGFloat = 0.006,
        frictionPerSecond: CGFloat = 0.92,
        randomNudgeRange: ClosedRange<CGFloat> = (-0.6 ... 0.6),
        whooshAssetName: String? = nil,
        initialImpulse: CGFloat = 0,
        portalIsActive: Bool = false,
        onEnterActorKit: (() -> Void)? = nil
    ) {
        self.front = front
        self.back = back
        self.size = size
        self.edgeThickness = edgeThickness
        self.ribs = ribs
        self.dragSensitivity = dragSensitivity
        self.frictionPerSecond = frictionPerSecond
        self.randomNudgeRange = randomNudgeRange
        self.whooshAssetName = whooshAssetName
        self.initialImpulse = initialImpulse
        self.portalIsActive = portalIsActive
        self.onEnterActorKit = onEnterActorKit
    }

    public var body: some View {
        ZStack {
            // Outer ring (subtle parallax spin)
            OuterRing()
                .frame(width: size + 24, height: size + 24)
                .rotationEffect(.degrees(-angle * 0.12))

            // ONE rotating stack: faces + rim + ribbed edge (in UIKit with true backface culling)
            OneStackCoin(
                front: LogoFace(image: front),
                back: (back.map { AnyView(PhotoFace(image: $0, inset: 6)) } ?? AnyView(PlaceholderFace())),
                edgeThickness: edgeThickness,
                ribs: ribs
            )
            .frame(width: size, height: size)
            .rotation3DEffect(.degrees(Double(angle)), axis: (0, 1, 0), perspective: 0.6)
            .accessibilityAddTraits(.isButton)
        }
        .scaleEffect(isPressed ? 1.03 : 1.0) // long-press "lift"
        .animation(.spring(response: 0.28, dampingFraction: 0.82), value: isPressed)
        .contentShape(Circle())
        // Important: tap has higher priority than drag
        .highPriorityGesture(tapGesture)
        .simultaneousGesture(dragGesture)
        .simultaneousGesture(longPressGesture)
        .onAppear {
            haptics.prepare()
            applyInitialImpulseIfNeeded()
            if back == nil {
                print("⚠️ ActorKitSpinnerCoinView back image is nil; showing placeholder.")
            }
            if disableAnimation {
                snapToSelectedFace(animated: false)
            }
        }
        .onChange(of: disableAnimation, initial: false) { _, newValue in
            if newValue {
                snapToSelectedFace(animated: true)
            }
        }
        .onChange(of: badgeStopFaceRaw, initial: false) { _, _ in
            if disableAnimation {
                snapToSelectedFace(animated: true)
            }
        }
        .onAppear {
            syncPortalState(with: portalIsActive)
        }
        .onChange(of: portalIsActive, initial: false) { _, newValue in
            syncPortalState(with: newValue)
        }
        .background(
            PhysicsDriver(isRunning: shouldRunPhysics) { delta in
                stepPhysics(delta: delta)
            }
        )
        .accessibilityLabel(Text("Fidget spinner coin"))
        .accessibilityHint(Text("Swipe left or right to spin, tap to open ActorKit"))
        .allowsHitTesting(!portalTransitioning)
    }

    // MARK: - Effective friction honoring Reduce Motion
    private var effectiveFriction: CGFloat {
        reduceMotion ? 0.80 : frictionPerSecond
    }

    private var shouldRunPhysics: Bool {
        !(portalTransitioning || disableAnimation || portalIsActive)
    }

    private func applyInitialImpulseIfNeeded() {
        guard !didApplyInitialImpulse, initialImpulse != 0, !disableAnimation else { return }
        didApplyInitialImpulse = true
        omega += initialImpulse
        hasSnappedToRest = false
    }

    // MARK: - Tap gesture: stop-then-enter
    private var tapGesture: some Gesture {
        TapGesture()
            .onEnded {
                guard !portalTransitioning else { return }
                let now = Date()
                if now.timeIntervalSince(lastTapTime) < 0.35 { return } // debounce
                lastTapTime = now

                if !disableAnimation, abs(omega) > tapStopThreshold {
                    // First tap while spinning: stop only
                    omega = 0
                    hasSnappedToRest = false
                    debugLog("Tap received while spinning — stopping spin (omega=\(Int(omega)))")
                    return
                }
                // Coin is near-stopped -> enter ActorKit
                portalTransitioning = true
                hapticsEnabled = false
                omega = 0
                hasSnappedToRest = false
                debugLog("Tap recognized -> entering ActorKit")
                onEnterActorKit?()
            }
    }

    // MARK: - Drag gesture
    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { value in
                guard !disableAnimation, !portalTransitioning else { return }
                if let lx = lastDragX {
                    let dx = value.location.x - lx
                    // Add impulse proportional to dx
                    omega += dx * (dragSensitivity * 100)   // convert to deg/sec-ish
                    isDragging = true
                    hasSnappedToRest = false
                }
                lastDragX = value.location.x
            }
            .onEnded { _ in
                lastDragX = nil
                isDragging = false
                guard !disableAnimation, !portalTransitioning else { return }
                // Add a small random nudge so stops aren’t deterministic
                let nudge = CGFloat.random(in: randomNudgeRange)
                omega += nudge * 90.0
                hasSnappedToRest = false
                // Soft whoosh if provided and good flick velocity
                if let name = whooshAssetName, abs(omega) > 250 {
                    sfx.play(named: name)
                }
            }
    }

    // MARK: - Long press "lift"
    private var longPressGesture: some Gesture {
        LongPressGesture(minimumDuration: 0.18)
            .onChanged { _ in
                guard !disableAnimation, !portalTransitioning else { return }
                isPressed = true
                if hapticsEnabled && !reduceMotion {
                    haptics.impactOccurred(intensity: 0.35)
                }
            }
            .onEnded { _ in
                isPressed = false
            }
    }

    // MARK: - Haptic events when crossing faces (throttled)
    private func handleFaceCrossing(_ newAngle: CGFloat, _ oldAngle: CGFloat) {
        guard hapticsEnabled, !portalTransitioning, !reduceMotion else { return }
        let t = CACurrentMediaTime()
        guard t - lastHapticAt > 0.12 else { return } // max ~8/sec
        let crossings = [0.0, 180.0, 360.0]
        for c in crossings {
            let was = normalized(oldAngle - c)
            let now = normalized(newAngle - c)
            if abs(was) < 8 || abs(now) < 8 {
                haptics.impactOccurred(intensity: 0.5)
                lastHapticAt = t
                break
            }
        }
    }

    private func handleSettle(_ finalAngle: CGFloat) {
        guard hapticsEnabled, !portalTransitioning, !reduceMotion else { return }
        haptics.impactOccurred(intensity: 0.8)
    }

    private func normalized(_ a: CGFloat) -> CGFloat {
        var x = a.truncatingRemainder(dividingBy: 360)
        if x > 180 { x -= 360 }
        if x < -180 { x += 360 }
        return x
    }

    private let settleSpeed: CGFloat = 15
    private let snapThreshold: CGFloat = 22
    private let tapStopThreshold: CGFloat = 80

    private func stepPhysics(delta: Double) {
        guard shouldRunPhysics else {
            omega = 0
            hasSnappedToRest = true
            return
        }

        let frameDuration = max(1.0 / 240.0, min(delta, 1.0 / 20.0))
        let oldAngle = angle

        angle += omega * CGFloat(frameDuration)
        handleFaceCrossing(angle, oldAngle)

        let friction = pow(effectiveFriction, CGFloat(frameDuration))
        omega *= friction

        if abs(omega) < 0.3 {
            omega = 0
        }

        if abs(omega) < settleSpeed {
            let mod = angle.truncatingRemainder(dividingBy: 360)
            let distTo0 = abs(mod - 0).minAbs360()
            let distTo180 = abs(mod - 180).minAbs360()
            if min(distTo0, distTo180) < snapThreshold {
                let target = (distTo180 < distTo0) ? 180.0 : 0.0
                angle += (target - mod)
                omega = 0
                if !hasSnappedToRest {
                    handleSettle(angle)
                    hasSnappedToRest = true
                }
            }
        } else {
            hasSnappedToRest = false
        }
    }

    private func debugLog(_ message: String) {
        #if DEBUG
        print("[ActorKitSpinnerCoinView] \(message)")
        #endif
    }

    private func snapToSelectedFace(animated: Bool) {
        let target = badgeStopFace.restAngleDegrees
        let apply = {
            angle = target
            omega = 0
            hasSnappedToRest = true
        }
        if animated {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
                apply()
            }
        } else {
            apply()
        }
    }

    private func syncPortalState(with active: Bool) {
        if active {
            portalTransitioning = true
            hapticsEnabled = false
            omega = 0
            lastDragX = nil
            isPressed = false
            hasSnappedToRest = true
        } else {
            portalTransitioning = false
            hapticsEnabled = true
        }
    }
}

fileprivate extension CGFloat {
    func minAbs360() -> CGFloat {
        var x = self
        if x > 180 { x = 360 - x }
        return abs(x)
    }
}

// MARK: - Faces & Edge (same aesthetics as before)
private struct LogoFace: View {
    let image: Image
    var body: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(
                    colors: [Color(red: 0.18, green: 0.12, blue: 0.30),
                             Color(red: 0.08, green: 0.03, blue: 0.16)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))
                .overlay(Circle().stroke(Color.white.opacity(0.25), lineWidth: 2))
            image
                .renderingMode(.original)
                .resizable().scaledToFit().padding(26)
                .shadow(color: .black.opacity(0.35), radius: 5, x: 0, y: 3)
        }
        .clipShape(Circle())
    }
}

private struct PhotoFace: View {
    let image: Image
    var inset: CGFloat = 6
    var body: some View {
        ZStack {
            Circle().fill(Color.black.opacity(0.10))
            image.resizable().scaledToFill().padding(inset).clipShape(Circle())
            Circle().strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
        }
        .clipShape(Circle())
    }
}

private struct PlaceholderFace: View {
    var body: some View {
        ZStack {
            RadialGradient(colors: [Color.gray.opacity(0.35), Color.gray.opacity(0.6)],
                           center: .center, startRadius: 0, endRadius: 120)
            Image(systemName: "person.crop.circle.fill")
                .resizable().scaledToFit().padding(24).foregroundStyle(.white.opacity(0.9))
        }
        .clipShape(Circle())
    }
}

// MARK: - Outer ring + edge visuals
private struct OuterRing: View {
    var body: some View {
        Circle()
            .fill(LinearGradient(colors: [Color.white.opacity(0.10), Color.black.opacity(0.25)],
                                 startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay(Circle().strokeBorder(Color.white.opacity(0.15), lineWidth: 1))
            .overlay(Circle().strokeBorder(Color.black.opacity(0.25), lineWidth: 2))
    }
}

private struct Rim: View {
    var body: some View {
        Circle()
            .strokeBorder(AngularGradient(
                gradient: Gradient(colors: [
                    Color.white.opacity(0.55),
                    Color.black.opacity(0.45),
                    Color.white.opacity(0.35),
                    Color.black.opacity(0.6)
                ]),
                center: .center
            ), lineWidth: 6)
            .overlay(Circle().stroke(Color.black.opacity(0.08), lineWidth: 1))
            .overlay(Circle().stroke(Color.white.opacity(0.10), lineWidth: 3).blur(radius: 1))
            .allowsHitTesting(false)
    }
}

private struct EdgeBand: View {
    var thickness: CGFloat = 8
    var ribs: Int = 72
    var body: some View {
        ZStack {
            Circle().inset(by: thickness/2).stroke(
                LinearGradient(colors: [Color.black.opacity(0.6),
                                        Color.black.opacity(0.3),
                                        Color.white.opacity(0.22),
                                        Color.black.opacity(0.5)],
                               startPoint: .top, endPoint: .bottom),
                lineWidth: thickness
            )
            Circle().inset(by: thickness/2).stroke(
                AngularGradient(gradient: Gradient(colors: (0..<ribs).map { i in
                    (i % 2 == 0) ? Color.white.opacity(0.14) : Color.black.opacity(0.18)
                }), center: .center),
                lineWidth: thickness * 0.55
            )
            .opacity(0.7).blendMode(.overlay)
        }
        .allowsHitTesting(false)
    }
}

// MARK: - OneStackCoin (UIKit host, true backface culling)
private struct OneStackCoin<Front: View, Back: View>: UIViewRepresentable {
    let front: Front
    let back: Back
    var edgeThickness: CGFloat = 8
    var ribs: Int = 72

    func makeCoordinator() -> Coord { Coord() }

    func makeUIView(context: Context) -> UIView {
        let container = UIView()
        container.backgroundColor = .clear
        container.layer.sublayerTransform = CATransform3D.withPerspective(0.6)

        let frontHost = UIHostingController(rootView: front)
        frontHost.view.backgroundColor = .clear
        frontHost.view.layer.isDoubleSided = false

        let backHost = UIHostingController(rootView: back)
        backHost.view.backgroundColor = .clear
        backHost.view.layer.isDoubleSided = false
        backHost.view.layer.transform = CATransform3DMakeRotation(.pi, 0, 1, 0)

        let edgeHost = UIHostingController(rootView: AnyView(ZStack { Rim(); EdgeBand(thickness: edgeThickness, ribs: ribs) }))
        edgeHost.view.backgroundColor = .clear
        edgeHost.view.isUserInteractionEnabled = false

        for v in [frontHost.view!, backHost.view!, edgeHost.view!] {
            v.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(v)
            NSLayoutConstraint.activate([
                v.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                v.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                v.topAnchor.constraint(equalTo: container.topAnchor),
                v.bottomAnchor.constraint(equalTo: container.bottomAnchor)
            ])
        }

        context.coordinator.frontHost = frontHost
        context.coordinator.backHost  = backHost
        context.coordinator.edgeHost  = edgeHost
        return container
    }

    func updateUIView(_ view: UIView, context: Context) {
        context.coordinator.frontHost?.rootView = front
        context.coordinator.backHost?.rootView  = back
        context.coordinator.edgeHost?.rootView  = AnyView(ZStack { Rim(); EdgeBand(thickness: edgeThickness, ribs: ribs) })
    }

    final class Coord {
        var frontHost: UIHostingController<Front>?
        var backHost:  UIHostingController<Back>?
        var edgeHost:  UIHostingController<AnyView>?
    }
}

fileprivate extension CATransform3D {
    static func withPerspective(_ p: CGFloat) -> CATransform3D {
        var t = CATransform3DIdentity
        t.m34 = -1.0 / max(p * 500, 1)
        return t
    }
}

// MARK: - Lightweight SFX helper (optional)
final class SoundFXPlayer {
    static let shared = SoundFXPlayer()
    private var cache: [String: AVAudioPlayer] = [:]
    private init() {}

    /// Plays a short bundled audio by filename (e.g., "whoosh.caf").
    func play(named filename: String) {
        #if os(iOS)
        guard let url = Bundle.main.url(forResource: filename, withExtension: nil) else { return }
        if let existing = cache[filename] {
            existing.currentTime = 0
            existing.play()
            return
        }
        do {
            let p = try AVAudioPlayer(contentsOf: url)
            p.prepareToPlay()
            cache[filename] = p
            p.play()
        } catch {
            // Silent fail—sound is purely additive
        }
        #endif
    }
}

// MARK: - Timeline-based physics driver
private struct PhysicsDriver: View {
    var isRunning: Bool
    var step: (Double) -> Void
    @State private var lastDate: Date?

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 120.0)) { context in
            Color.clear
                .task(id: context.date) {
                    guard isRunning else {
                        lastDate = context.date
                        return
                    }
                    let previous = lastDate ?? context.date
                    var delta = context.date.timeIntervalSince(previous)
                    if !delta.isFinite || delta <= 0 {
                        delta = 1.0 / 60.0
                    }
                    delta = min(max(delta, 1.0 / 240.0), 1.0 / 20.0)
                    lastDate = context.date
                    step(delta)
                }
        }
        .frame(width: 0, height: 0)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
