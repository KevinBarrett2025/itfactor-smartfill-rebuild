import Foundation

@MainActor
final class ExitProcessingCoordinator: ObservableObject {
    static let shared = ExitProcessingCoordinator()

    private var didShow = false
    private var didHide = false
    private var hideTask: Task<Void, Never>?

    func show(source: String) {
        didShow = true
        didHide = false
        hideTask?.cancel()
        hideTask = nil

        ProcessingOverlayWindow.shared.show(
            message: "Compiling your recording…",
            details: "Saving takes and preparing Take Review"
        )
        print("🟦 [ExitProcessing] SHOW (source=\(source))")

        // Failsafe: hide after 6 seconds to avoid trapping the user.
        hideTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 6_000_000_000)
            self.hide(source: "failsafeTimeout")
        }
    }

    func hide(source: String) {
        guard didShow, !didHide else { return }
        didHide = true
        hideTask?.cancel()
        hideTask = nil

        ProcessingOverlayWindow.shared.hide()
        print("🟩 [ExitProcessing] HIDE (source=\(source))")
    }
}
