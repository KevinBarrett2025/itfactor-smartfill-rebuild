import SwiftUI
import UIKit

private struct PlaybackSafeAreaInsetsKey: EnvironmentKey {
    static let defaultValue = EdgeInsets()
}

extension EnvironmentValues {
    var playbackSafeAreaInsets: EdgeInsets {
        get { self[PlaybackSafeAreaInsetsKey.self] }
        set { self[PlaybackSafeAreaInsetsKey.self] = newValue }
    }
}

private struct PlaybackOverlayTopComfortKey: EnvironmentKey {
    static let defaultValue: CGFloat = 0
}

extension EnvironmentValues {
    var playbackOverlayTopComfort: CGFloat {
        get { self[PlaybackOverlayTopComfortKey.self] }
        set { self[PlaybackOverlayTopComfortKey.self] = newValue }
    }
}

private func activeKeyWindow() -> UIWindow? {
    let scenes = UIApplication.shared.connectedScenes
        .compactMap { $0 as? UIWindowScene }
        .filter { $0.activationState == .foregroundActive || $0.activationState == .foregroundInactive }

    for scene in scenes {
        if let key = scene.windows.first(where: { $0.isKeyWindow }) {
            return key
        }
        if let first = scene.windows.first {
            return first
        }
    }

    return nil
}

private func resolveInsets(proxyInsets: EdgeInsets, windowInsets: UIEdgeInsets) -> UIEdgeInsets {
    let proxyAllZero = proxyInsets.top == 0
        && proxyInsets.bottom == 0
        && proxyInsets.leading == 0
        && proxyInsets.trailing == 0
    let windowAllZero = windowInsets.top == 0
        && windowInsets.bottom == 0
        && windowInsets.left == 0
        && windowInsets.right == 0

    if !proxyAllZero {
        return UIEdgeInsets(
            top: proxyInsets.top,
            left: proxyInsets.leading,
            bottom: proxyInsets.bottom,
            right: proxyInsets.trailing
        )
    }
    if !windowAllZero {
        return windowInsets
    }
    return .zero
}

private struct WindowSafeAreaReader: UIViewRepresentable {
    var onChange: (UIEdgeInsets) -> Void

    func makeUIView(context: Context) -> UIView {
        let view = ReaderView()
        view.onChange = onChange
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}

    private final class ReaderView: UIView {
        var onChange: ((UIEdgeInsets) -> Void)?

        override func didMoveToWindow() {
            super.didMoveToWindow()
            report()
        }

        override func safeAreaInsetsDidChange() {
            super.safeAreaInsetsDidChange()
            report()
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            report()
        }

        private func report() {
            let insets: UIEdgeInsets
            if let window {
                insets = window.safeAreaInsets
            } else if let window = activeKeyWindow() {
                insets = window.safeAreaInsets
            } else {
                insets = .zero
            }
            onChange?(insets)
        }
    }
}

/// Canonical playback container that owns safe-area policy.
/// Video content is full-bleed; overlays are safe-area aware.
struct PlaybackSurface<Background: View, Video: View, Overlay: View>: View {
    let background: Background
    let video: Video
    let overlay: Overlay
    @State private var windowInsets: UIEdgeInsets = .zero

    init(
        @ViewBuilder background: () -> Background,
        @ViewBuilder video: () -> Video,
        @ViewBuilder overlay: () -> Overlay
    ) {
        self.background = background()
        self.video = video()
        self.overlay = overlay()
    }

    var body: some View {
        GeometryReader { proxy in
            let proxyInsets = proxy.safeAreaInsets
            let resolvedInsets = resolveInsets(proxyInsets: proxyInsets, windowInsets: windowInsets)
            let isLandscape = proxy.size.width > proxy.size.height
            let landscapeTopComfort: CGFloat = 12
            let shouldApplyLandscapeComfort = isLandscape
                && resolvedInsets.top == 0
                && (resolvedInsets.left > 0 || resolvedInsets.right > 0)
            let effectiveTop = resolvedInsets.top + (shouldApplyLandscapeComfort ? landscapeTopComfort : 0)
            let playbackInsets = EdgeInsets(
                top: effectiveTop,
                leading: resolvedInsets.left,
                bottom: resolvedInsets.bottom,
                trailing: resolvedInsets.right
            )
            let overlayTopComfort: CGFloat = shouldApplyLandscapeComfort ? 18 : 0
            let overlayInsets = EdgeInsets(
                top: resolvedInsets.top,
                leading: resolvedInsets.left,
                bottom: resolvedInsets.bottom,
                trailing: resolvedInsets.right
            )
            ZStack {
                background
                    .ignoresSafeArea()

                video
                    .ignoresSafeArea()

                overlay
                    .padding(overlayInsets)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                WindowSafeAreaReader { newInsets in
                    if windowInsets != newInsets {
                        windowInsets = newInsets
                    }
                }
                .ignoresSafeArea()
                .allowsHitTesting(false)
            }
            .environment(\.playbackSafeAreaInsets, playbackInsets)
            .environment(\.playbackOverlayTopComfort, overlayTopComfort)
        }
    }
}
