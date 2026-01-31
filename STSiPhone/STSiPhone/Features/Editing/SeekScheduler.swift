import Foundation
import AVFoundation

@MainActor
final class SeekScheduler {
    enum Policy {
        case scrub
        case settle
    }

    struct Request {
        let time: CMTime
        let policy: Policy
        let completion: (() -> Void)?
    }

    private weak var player: AVPlayer?
    private var isSeeking = false
    private var pendingRequest: Request?
    private var scheduledWorkItem: DispatchWorkItem?

    var scrubCoalesceInterval: TimeInterval = 0.03
    var scrubTolerance: CMTime = CMTime(seconds: 0.05, preferredTimescale: 600)
    var settleTolerance: CMTime = .zero

    init(player: AVPlayer?) {
        self.player = player
    }

    func updatePlayer(_ player: AVPlayer?) {
        self.player = player
    }

    func request(_ request: Request) {
        pendingRequest = request
        scheduleIfNeeded(for: request.policy)
    }

    func cancelPending() {
        pendingRequest = nil
        scheduledWorkItem?.cancel()
        scheduledWorkItem = nil
    }

    private func scheduleIfNeeded(for policy: Policy) {
        scheduledWorkItem?.cancel()
        scheduledWorkItem = nil

        switch policy {
        case .scrub:
            let workItem = DispatchWorkItem { [weak self] in
                self?.performPendingSeek()
            }
            scheduledWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + scrubCoalesceInterval, execute: workItem)
        case .settle:
            performPendingSeek()
        }
    }

    private func performPendingSeek() {
        guard !isSeeking else { return }
        guard let player = player, let request = pendingRequest else { return }
        pendingRequest = nil
        isSeeking = true

        let tolerance = request.policy == .scrub ? scrubTolerance : settleTolerance
        player.seek(to: request.time, toleranceBefore: tolerance, toleranceAfter: tolerance) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.isSeeking = false
                request.completion?()
                if let next = self.pendingRequest {
                    self.scheduleIfNeeded(for: next.policy)
                }
            }
        }
    }
}
