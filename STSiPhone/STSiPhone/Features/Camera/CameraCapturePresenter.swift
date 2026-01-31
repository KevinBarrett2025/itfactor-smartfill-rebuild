import SwiftUI
import UIKit

// MARK: - Full-screen hosting controller for CameraCaptureView

/// A UIHostingController that:
/// - Hides the status bar
/// - Forces its view to fill the entire screen
/// - Eliminates extra safe-area padding imposed by SwiftUI containers
final class FullScreenCameraController<Content: View>: UIHostingController<Content> {
    override var prefersStatusBarHidden: Bool { true }
    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        additionalSafeAreaInsets = .zero
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        if let windowScene = view.window?.windowScene {
            let bounds = windowScene.screen.bounds
            if view.frame != bounds {
                view.frame = bounds
            }
        } else {
            let bounds = UIScreen.main.bounds
            if view.frame != bounds {
                view.frame = bounds
            }
        }

        additionalSafeAreaInsets = .zero
    }
}

// MARK: - UIApplication helpers

private extension UIApplication {
    var stsKeyWindow: UIWindow? {
        connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first(where: { $0.isKeyWindow })
    }

    var stsTopViewController: UIViewController? {
        guard let root = stsKeyWindow?.rootViewController else { return nil }
        return UIApplication.topViewController(from: root)
    }

    static func topViewController(from root: UIViewController?) -> UIViewController? {
        if let nav = root as? UINavigationController {
            return topViewController(from: nav.visibleViewController)
        } else if let tab = root as? UITabBarController {
            return topViewController(from: tab.selectedViewController)
        } else if let presented = root?.presentedViewController {
            return topViewController(from: presented)
        }
        return root
    }
}

// MARK: - CameraCapturePresenter

/// Central presenter for the camera capture screen.
///
/// This bypasses SwiftUI sheets and presents a true full-screen UIKit modal with CameraCaptureView inside.
enum CameraCapturePresenter {
    private static weak var currentHost: UIViewController?
    private static var isDismissing = false

    private static var cameraAnimationsEnabled: Bool {
        #if DEBUG
        return true
        #else
        return true
        #endif
    }

    private static func logState(_ message: String) {
        let hostExists = currentHost != nil
        print("📺 CameraCapturePresenter: \(message) | hostExists: \(hostExists) isDismissing: \(isDismissing)")
    }

    private static func dumpViewControllerHierarchy(label: String) {
        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }),
              let window = windowScene.windows.first(where: { $0.isKeyWindow }),
              let root = window.rootViewController else {
            print("🧭 [CameraCapturePresenter] \(label): Unable to locate rootViewController")
            return
        }

        print("🧭 [CameraCapturePresenter] \(label): View controller hierarchy")
        dumpViewController(root, level: 0)
    }

    private static func dumpViewController(_ controller: UIViewController, level: Int) {
        let indent = String(repeating: "  ", count: level)
        let typeName = String(describing: type(of: controller))
        let presentedName = controller.presentedViewController.map { String(describing: type(of: $0)) } ?? "none"
        print("\(indent)• \(typeName) – presented: \(presentedName)")

        for child in controller.children {
            dumpViewController(child, level: level + 1)
        }

        if let presented = controller.presentedViewController {
            dumpViewController(presented, level: level + 1)
        }
    }

    @MainActor
    static func present(
        project: Project,
        session: ProjectSession,
        sidesURL: URL? = nil,
        breakdownURL: URL? = nil,
        sidesFileName: String? = nil,
        breakdownFileName: String? = nil,
        navContext: NavigationContextManager? = nil,
        autoPresentSlatePrompt: Bool = false,
        debugSource: String = #function,
        onComplete: (() -> Void)? = nil
    ) {
        dumpViewControllerHierarchy(label: "BEFORE present – source: \(debugSource)")
        logState("present requested – source: \(debugSource)")

        guard let presenter = UIApplication.shared.stsTopViewController else {
            print("⚠️ CameraCapturePresenter: no presenter available for source \(debugSource)")
            onComplete?()
            return
        }

        if project.isArchived || session.isArchived {
            print("🚫 CameraCapturePresenter: blocked because project/session archived – source: \(debugSource)")
            let alert = UIAlertController(
                title: "Project is archived",
                message: "Restore this project to record new takes.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
            presenter.present(alert, animated: true)
            onComplete?()
            return
        }

        guard CameraCapturePresenter.currentHost == nil, !CameraCapturePresenter.isDismissing else {
            logState("duplicate present ignored – source: \(debugSource)")
            dumpViewControllerHierarchy(label: "DUPLICATE present ignored – source: \(debugSource)")
            print("⚠️ CameraCapturePresenter already presenting or dismissing. Ignoring duplicate request.")
            return
        }

        var didDismiss = false

        let dismissCamera = {
            logState("dismissCamera invoked – source: \(debugSource) didDismiss: \(didDismiss)")
            guard !didDismiss else { return }
            didDismiss = true
            CameraCapturePresenter.isDismissing = true
            ExitProcessingCoordinator.shared.show(source: "CameraCapturePresenter.dismissCamera.\(debugSource)")
            guard let host = CameraCapturePresenter.currentHost else {
                logState("dismissCamera missing host – source: \(debugSource)")
                onComplete?()
                CameraCapturePresenter.isDismissing = false
                return
            }
            dumpViewControllerHierarchy(label: "BEFORE dismiss – source: \(debugSource)")
            print("🎬 Dismissing CameraCapture host")
            host.dismiss(animated: cameraAnimationsEnabled) {
                print("🎬 CameraCapture host dismissed")
                dumpViewControllerHierarchy(label: "AFTER dismiss – source: \(debugSource)")
                CameraCapturePresenter.currentHost = nil
                CameraCapturePresenter.isDismissing = false
                Task { @MainActor in
                    ExitProcessingCoordinator.shared.hide(source: "presenter.dismissCompletion.\(debugSource)")
                }
                onComplete?()
            }
        }

        let baseView = CameraCaptureView(
            project: project,
            session: session,
            slateConfiguration: nil,
            autoPresentSlatePrompt: autoPresentSlatePrompt,
            sidesURL: sidesURL,
            breakdownURL: breakdownURL,
            sidesFileName: sidesFileName,
            breakdownFileName: breakdownFileName,
            onComplete: dismissCamera
        )

        let navProvider = navContext ?? NavigationContextManager.shared
        let themeProvider = ThemeManager()
        let cameraView = AnyView(baseView.environmentObject(navProvider).environmentObject(themeProvider))

        let host = FullScreenCameraController(rootView: cameraView)
        host.modalPresentationStyle = UIModalPresentationStyle.fullScreen
        host.modalTransitionStyle = UIModalTransitionStyle.crossDissolve
        CameraCapturePresenter.currentHost = host
        logState("assigned host – source: \(debugSource)")
        print("🎬 Presenting CameraCapture host")
        presenter.present(host, animated: cameraAnimationsEnabled, completion: nil)
    }
}

// MARK: - Processing Overlay Window (global, stays above dismissal transitions)
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
