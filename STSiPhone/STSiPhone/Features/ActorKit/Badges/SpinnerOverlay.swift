import SwiftUI
import UIKit
import SpriteKit

/// SwiftUI overlay that listens for spinner effect notifications (crack + toast) and renders UI.
public struct SpinnerOverlay: View {
    @State private var crackOpacity: Double = 0
    @State private var crackScale: CGFloat = 1
    @State private var showConfetti = false
    @State private var confettiID = UUID()
    @State private var confettiHideWorkItem: DispatchWorkItem?
    
    public init() {}
    
    public var body: some View {
        GeometryReader { proxy in
            ZStack {
                if showConfetti {
                    SpriteView(scene: makeConfettiScene(size: proxy.size))
                        .id(confettiID)
                        .ignoresSafeArea()
                        .transition(.opacity)
                }
                crackLayer
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .allowsHitTesting(false)
        .onReceive(NotificationCenter.default.publisher(for: .spinnerCrack)) { _ in
            triggerCrack()
        }
        .onReceive(NotificationCenter.default.publisher(for: .spinnerCelebrate)) { _ in
            triggerConfetti()
        }
    }
    
    // MARK: - Layers
    
    private var crackLayer: some View {
        Group {
            if let overlayImage = crackedImage {
                overlayImage
                    .resizable()
                    .scaledToFit()
            } else {
                fallbackCrack
            }
        }
        .opacity(crackOpacity)
        .scaleEffect(crackScale)
        .animation(.spring(response: 0.5, dampingFraction: 0.65), value: crackScale)
    }
    
    private var fallbackCrack: some View {
        ZStack {
            ForEach(0..<5, id: \.self) { index in
                Capsule()
                    .fill(Color.white.opacity(0.35))
                    .frame(width: 4, height: 180)
                    .rotationEffect(.degrees(Double(index) * 33))
            }
        }
    }
    
    private var crackedImage: Image? {
        guard let uiImage = UIImage(named: "CrackedScreenOverlay") else {
            return nil
        }
        return Image(uiImage: uiImage)
    }
    
    // MARK: - Triggers
    
    private func triggerCrack() {
        withAnimation(.easeOut(duration: 0.18)) {
            crackOpacity = 1
            crackScale = 1.05
        }
        // Pulse scale for impact then fade.
        Task {
            try await Task.sleep(nanoseconds: 400_000_000)
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                crackScale = 1
            }
            try await Task.sleep(nanoseconds: 900_000_000)
            withAnimation(.easeInOut(duration: 0.35)) {
                crackOpacity = 0
            }
        }
    }

    private func triggerConfetti() {
        confettiHideWorkItem?.cancel()
        confettiID = UUID()
        withAnimation(.easeOut(duration: 0.2)) {
            showConfetti = true
        }

        let work = DispatchWorkItem {
            withAnimation(.easeIn(duration: 0.3)) {
                showConfetti = false
            }
        }
        confettiHideWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5, execute: work)
    }

    private func makeConfettiScene(size: CGSize) -> SKScene {
        let resolvedSize = size == .zero ? UIScreen.main.bounds.size : size
        return SpinnerConfettiScene(size: resolvedSize)
    }
    
}
