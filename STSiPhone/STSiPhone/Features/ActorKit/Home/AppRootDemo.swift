// AppRootDemo.swift
// Example integration of CoinPortalCoordinator and ActorKitView
#if DEBUG
import SwiftUI

/// Reference wiring for the SpinnerCoin handoff.
struct AppRootDemo: View {
    @State private var isProfileComplete = false

    var body: some View {
        CoinPortalCoordinator(
            front: Image("AppIconBadgeFilled"),
            back: Image(systemName: "person.crop.circle"),
            badgeSize: 176,
            whooshAssetName: "whoosh.caf",
            actorKit: {
                DemoActorKitView()
            },
            captionOverlay: { _ in EmptyView() }
        )
    }
}

/// Lightweight stand-in so the demo compiles without the real ActorKitView.
private struct DemoActorKitView: View {
    var body: some View {
        Text("ActorKit Home")
            .font(.largeTitle.bold())
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black.opacity(0.02))
    }
}
#endif
