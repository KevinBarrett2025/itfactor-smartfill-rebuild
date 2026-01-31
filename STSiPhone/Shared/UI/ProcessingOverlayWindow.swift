import SwiftUI
import UIKit

final class ProcessingOverlayWindow {
    static let shared = ProcessingOverlayWindow()

    private var window: UIWindow?
    private var host: UIHostingController<OverlayView>?

    func show(message: String = "Compiling your recording…",
              details: String = "Saving takes and preparing Take Review") {
        DispatchQueue.main.async {
            if let host = self.host {
                host.rootView = OverlayView(message: message, details: details)
                self.window?.isHidden = false
                return
            }

            guard let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive }) else {
                return
            }

            let root = OverlayView(message: message, details: details)
            let host = UIHostingController(rootView: root)
            host.view.backgroundColor = .clear

            let window = UIWindow(windowScene: scene)
            window.rootViewController = host
            window.windowLevel = .alert + 1
            window.backgroundColor = .clear
            window.isHidden = false

            window.alpha = 0
            UIView.animate(withDuration: 0.15) {
                window.alpha = 1
            }

            self.window = window
            self.host = host
        }
    }

    func hide() {
        DispatchQueue.main.async {
            guard let window = self.window else { return }
            UIView.animate(withDuration: 0.15, animations: {
                window.alpha = 0
            }, completion: { _ in
                window.isHidden = true
                self.window = nil
                self.host = nil
            })
        }
    }

    private struct OverlayView: View {
        let message: String
        let details: String

        var body: some View {
            ZStack {
                Color.black.ignoresSafeArea()
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.4)
                        .tint(.white)

                    VStack(spacing: 6) {
                        Text(message)
                            .font(.headline)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)

                        Text(details)
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.75))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 28)
                    }
                }
            }
            .allowsHitTesting(true)
            .accessibilityAddTraits(.isModal)
        }
    }
}
