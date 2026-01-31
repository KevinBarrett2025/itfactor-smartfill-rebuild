// ActorKitPortalHost.swift
// Presents ActorKit full screen when coin requests entry. Ensures parent owns presentation.
// iOS 16+ • SwiftUI
import SwiftUI

public struct ActorKitPortalHost<ActorKit: View, ProjectList: View, CaptionOverlay: View>: View {
    // Inputs
    let front: Image
    let back: Image?
    let actorKit: () -> ActorKit
    let projectList: () -> ProjectList
    let captionOverlay: (_ badgeSize: CGFloat) -> CaptionOverlay
    var badgeSize: CGFloat = 176
    var whooshAssetName: String? = "whoosh.caf"

    // State
    @State private var isPresentingActorKit = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(front: Image,
                back: Image?,
                badgeSize: CGFloat = 176,
                whooshAssetName: String? = "whoosh.caf",
                @ViewBuilder actorKit: @escaping () -> ActorKit,
                @ViewBuilder projectList: @escaping () -> ProjectList,
                @ViewBuilder captionOverlay: @escaping (_ badgeSize: CGFloat) -> CaptionOverlay) {
        self.front = front
        self.back = back
        self.badgeSize = badgeSize
        self.whooshAssetName = whooshAssetName
        self.actorKit = actorKit
        self.projectList = projectList
        self.captionOverlay = captionOverlay
    }

    public var body: some View {
        ZStack {
            projectList()
                .opacity(isPresentingActorKit ? 0 : 1)

            // Badge + caption stack
            ZStack {
                ActorKitSpinnerCoinView(
                    front: front,
                    back: back,
                    size: badgeSize * 0.90,
                    whooshAssetName: whooshAssetName,
                    initialImpulse: reduceMotion ? 0 : 240,
                    portalIsActive: isPresentingActorKit
                ) {
                    // onEnterActorKit
                    withAnimation(.easeIn(duration: reduceMotion ? 0.20 : 0.42)) {
                        isPresentingActorKit = true
                    }
                }

                captionOverlay(badgeSize)
                    .frame(width: badgeSize, height: badgeSize)
                    .allowsHitTesting(false)
            }
            .frame(width: badgeSize, height: badgeSize)
        }
        .fullScreenCover(isPresented: $isPresentingActorKit) {
            actorKit()
                .ignoresSafeArea()
        }
    }
}
