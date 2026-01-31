import UIKit

@MainActor
final class OrientationLock {
    static let shared = OrientationLock()

    let defaultMask: UIInterfaceOrientationMask = .all
    private struct Entry {
        let token: UUID
        let mask: UIInterfaceOrientationMask
        let label: String
    }
    private var stack: [Entry] = []

    private init() {}

    func acquire(_ mask: UIInterfaceOrientationMask, label: String) -> UUID {
        let previousMask = currentMask
        let token = UUID()
        stack.append(Entry(token: token, mask: mask, label: label))
#if DEBUG
        logState(action: "acquire \(label)", previousMask: previousMask)
#endif
        return token
    }

    func release(_ token: UUID) {
        let previousMask = currentMask
        let label = stack.first(where: { $0.token == token })?.label ?? "unknown"
        if let index = stack.firstIndex(where: { $0.token == token }) {
            stack.remove(at: index)
        }
#if DEBUG
        logState(action: "release \(label)", previousMask: previousMask)
#endif
    }

    var currentMask: UIInterfaceOrientationMask {
        stack.last?.mask ?? defaultMask
    }
}

#if DEBUG
private extension OrientationLock {
    func logState(action: String, previousMask: UIInterfaceOrientationMask) {
        let current = currentMask
        let stackSummary = stack
            .map { "\($0.label)=\(maskDescription($0.mask))" }
            .joined(separator: " → ")
        let summary = stackSummary.isEmpty ? "empty" : stackSummary
        let changed = previousMask != current ? "changed" : "unchanged"
        print("🧭 OrientationLock \(action): current=\(maskDescription(current)) (\(changed)) stack=\(summary)")
    }

    func maskDescription(_ mask: UIInterfaceOrientationMask) -> String {
        if mask == .all { return "all" }
        if mask == .portrait { return "portrait" }
        if mask == .landscape { return "landscape" }
        if mask == .portraitUpsideDown { return "portraitUpsideDown" }
        if mask == .landscapeLeft { return "landscapeLeft" }
        if mask == .landscapeRight { return "landscapeRight" }
        return "mask(\(mask.rawValue))"
    }
}
#endif
