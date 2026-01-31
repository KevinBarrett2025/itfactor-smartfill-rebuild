// CoinPortalCoordinator.swift
// Orchestrates: Launch mirror -> settle to badge -> interactive spinner -> tap zoom to ActorKit
// iOS 16+ • SwiftUI
import SwiftUI

public struct CoinPortalCoordinator<ActorKit: View, CaptionOverlay: View>: View {
    // Inputs
    let front: Image
    let back: Image?
    let actorKit: () -> ActorKit
    let captionOverlay: (_ badgeSize: CGFloat) -> CaptionOverlay

    // Layout
    var badgeSize: CGFloat = 176
    var whooshAssetName: String? = "whoosh.caf"
    var useLaunchBackground: Bool = true

    // State
    @State private var phase: Phase = .launchMirror
    @Namespace private var coinNS
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(front: Image,
                back: Image?,
                badgeSize: CGFloat = 176,
                whooshAssetName: String? = "whoosh.caf",
                useLaunchBackground: Bool = true,
                @ViewBuilder actorKit: @escaping () -> ActorKit,
                @ViewBuilder captionOverlay: @escaping (_ badgeSize: CGFloat) -> CaptionOverlay) {
        self.front = front
        self.back = back
        self.badgeSize = badgeSize
        self.whooshAssetName = whooshAssetName
        self.useLaunchBackground = useLaunchBackground
        self.actorKit = actorKit
        self.captionOverlay = captionOverlay
    }

    public var body: some View {
        ZStack(alignment: .center) {
            switch phase {
            case .launchMirror, .settling, .interactive:
                launchAndBadgeLayer
            case .portal:
                portalZoomLayer
            case .actorKit:
                actorKitAnchor
            }
        }
        .background(portalBackground)
        .overlay(actorKitOverlay)
    }

    // MARK: - Layer with coin + caption
    private var launchAndBadgeLayer: some View {
        ZStack {
            GeometryReader { geo in
                let center = CGPoint(x: geo.size.width/2, y: geo.size.height/2)
                // Where the badge should live in final layout
                let badgeFrame = CGRect(
                    x: (geo.size.width - badgeSize)/2,
                    y: (geo.size.height * 0.25), // tweak to taste
                    width: badgeSize, height: badgeSize
                )

                ZStack {
                    captionOverlay(badgeSize)
                        .frame(width: badgeSize, height: badgeSize)
                        .position(badgeFrame.center)
                        .allowsHitTesting(false)
                        .opacity(phase == .interactive ? 1 : 0)
                        .animation(.easeInOut(duration: 0.25), value: phase)

                    coinView
                        .matchedGeometryEffect(id: "coin", in: coinNS)
                        .frame(width: coinSizeForPhase, height: coinSizeForPhase)
                        .position(positionForPhase(center: center, badge: badgeFrame.center))
                        .contentShape(Circle())
                        .allowsHitTesting(phase == .interactive)
                        .onTapGesture {
                            guard phase == .interactive else { return }
                            debugLog("Coin tap gesture fired")
                            onTapCoin()
                        }
                }
                .onAppear { startLaunchSequence() }
            }
        }
    }

    // MARK: - Coin
    private var coinView: some View {
        ActorKitSpinnerCoinView(
            front: front,
            back: back,
            size: coinSizeForPhase,
            whooshAssetName: whooshAssetName,
            initialImpulse: reduceMotion ? 0 : 240,
            portalIsActive: isPortalPhase // gentle spin at entry
        )
        .accessibilityAddTraits(.isButton)
    }

    private var portalZoomLayer: some View {
        ZStack {
            if useLaunchBackground {
                launchBackground
            }
            coinView
                .frame(width: coinSizeForPhase, height: coinSizeForPhase)
                .transition(.scale(scale: 1.2).combined(with: .opacity))
        }
        .ignoresSafeArea()
    }

    @ViewBuilder
    private var actorKitOverlay: some View {
        if phase == .actorKit {
            actorKit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(.opacity)
                .ignoresSafeArea()
                .onDisappear {
                    if phase == .actorKit {
                        debugLog("ActorKit overlay disappeared -> returning to interactive")
                        animateBackToInteractive()
                    }
                }
        }
    }

    private var actorKitAnchor: some View {
        Color.clear
            .frame(width: 1, height: 1)
            .accessibilityHidden(true)
    }

    // MARK: - Background that matches LaunchScreen
    @ViewBuilder
    private var portalBackground: some View {
        if useLaunchBackground {
            launchBackground
        } else {
            Color.clear
        }
    }

    private var launchBackground: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.08, green: 0.03, blue: 0.16),
                         Color(red: 0.18, green: 0.12, blue: 0.30)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            RadialGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.06, green: 0.73, blue: 0.80).opacity(0.22),
                    Color.clear
                ]),
                center: .center,
                startRadius: 0,
                endRadius: 520
            )
            .blendMode(.screen)
            .allowsHitTesting(false)
        }
        .ignoresSafeArea()
    }

    // MARK: - Phase helpers
    private enum Phase: String { case launchMirror, settling, interactive, portal, actorKit }

    private var coinSizeForPhase: CGFloat {
        switch phase {
        case .launchMirror: return badgeSize * 1.6
        case .settling:     return badgeSize * 1.05
        case .interactive:  return badgeSize * 0.90
        case .portal:       return badgeSize * 3.2
        case .actorKit:     return 0
        }
    }

    private var isPortalPhase: Bool {
        phase == .portal || phase == .actorKit
    }

    private func positionForPhase(center: CGPoint, badge: CGPoint) -> CGPoint {
        switch phase {
        case .launchMirror: return center
        case .settling, .interactive, .portal: return badge
        case .actorKit: return badge
        }
    }

    private func startLaunchSequence() {
        guard phase == .launchMirror else { return }
        // After a short delay to mirror static LaunchScreen, move to badge
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            transition(to: .settling, animation: .spring(response: 0.6, dampingFraction: 0.85))
            // Then fade to interactive size
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                transition(to: .interactive, animation: .spring(response: 0.45, dampingFraction: 0.9))
            }
        }
    }

    private func onTapCoin() {
        guard phase == .interactive else { return }
        debugLog("Tap recognized, advancing to portal")
        // Zoom forward portal
        transition(to: .portal, animation: .easeIn(duration: reduceMotion ? 0.20 : 0.42))
        DispatchQueue.main.asyncAfter(deadline: .now() + (reduceMotion ? 0.20 : 0.45)) {
            transition(to: .actorKit, animation: .easeOut(duration: 0.25))
        }
    }

    private func animateBackToInteractive() {
        guard phase == .actorKit else { return }
        transition(to: .interactive, animation: .spring(response: 0.5, dampingFraction: 0.85))
    }

    private func transition(to newPhase: Phase, animation: Animation? = nil) {
        guard phase != newPhase else { return }
        let change = {
            phase = newPhase
            debugLog("phase -> \(newPhase.rawValue)")
        }
        if let animation {
            withAnimation(animation, change)
        } else {
            change()
        }
    }

    private func debugLog(_ message: String) {
        #if DEBUG
        print("[CoinPortalCoordinator] \(message)")
        #endif
    }
}

// MARK: - Helpers
private extension CGRect {
    var center: CGPoint { CGPoint(x: midX, y: midY) }
}
