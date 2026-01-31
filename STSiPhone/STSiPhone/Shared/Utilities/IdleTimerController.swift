import UIKit

@MainActor
final class IdleTimerController {
    static let shared = IdleTimerController()

    final class Token {
        private let id: UUID
        private let reason: String
        private weak var controller: IdleTimerController?
        private var isReleased = false

        fileprivate init(id: UUID, reason: String, controller: IdleTimerController) {
            self.id = id
            self.reason = reason
            self.controller = controller
#if DEBUG
            debugLog("init")
#endif
        }

        /// Must be called on MainActor.
        @MainActor
        func release() {
            guard !isReleased else { return }
            isReleased = true
            guard let controller = controller else { return }
            controller.release(id: id, reason: reason)
        }

        deinit {
#if DEBUG
            debugLog("deinit")
            if !isReleased {
                print("⚠️ IdleTimerToken deinit without explicit release() reason=\(reason)")
            }
#endif
        }

#if DEBUG
        private func debugLog(_ event: String) {
            print("IdleTimerToken \(event) reason=\(reason) main=\(Thread.isMainThread)")
        }
#endif
    }

    private var tokens: [UUID: String] = [:]
    private var isAppActive = true
    private var observers: [NSObjectProtocol] = []

    private init() {
        installLifecycleObservers()
    }

    func acquire(reason: String) -> Token {
        let id = UUID()
        tokens[id] = reason
        applyIdleTimerState()
        debugLog("Acquire", reason: reason)
        return Token(id: id, reason: reason, controller: self)
    }

    func forceReleaseAll() {
        tokens.removeAll()
        applyIdleTimerState()
        debugLog("ForceReleaseAll", reason: nil)
    }

    private func release(id: UUID, reason: String) {
        tokens.removeValue(forKey: id)
        applyIdleTimerState()
        debugLog("Release", reason: reason)
    }

    private func applyIdleTimerState() {
        let shouldDisable = isAppActive && !tokens.isEmpty
        if UIApplication.shared.isIdleTimerDisabled != shouldDisable {
            UIApplication.shared.isIdleTimerDisabled = shouldDisable
        }
    }

    private func installLifecycleObservers() {
        let center = NotificationCenter.default
        observers.append(
            center.addObserver(forName: UIApplication.willResignActiveNotification, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.handleAppActiveChanged(false)
                }
            }
        )
        observers.append(
            center.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.handleAppActiveChanged(false)
                }
            }
        )
        observers.append(
            center.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.handleAppActiveChanged(true)
                }
            }
        )
    }

    private func handleAppActiveChanged(_ active: Bool) {
        isAppActive = active
        applyIdleTimerState()
        debugLog(active ? "AppActive" : "AppInactive", reason: nil)
    }

    private func debugLog(_ event: String, reason: String?) {
#if DEBUG
        let count = tokens.count
        if let reason {
            print("🛌 IdleTimerController: \(event) (\(reason)) count=\(count) active=\(isAppActive)")
        } else {
            print("🛌 IdleTimerController: \(event) count=\(count) active=\(isAppActive)")
        }
#endif
    }
}
