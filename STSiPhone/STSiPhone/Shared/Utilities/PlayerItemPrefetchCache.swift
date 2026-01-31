import Foundation
import AVFoundation
import UIKit

actor PlayerItemPrefetchCache {
    static let shared = PlayerItemPrefetchCache(maxEntries: 5, maxInFlight: 2)

    private let maxEntries: Int
    private let maxInFlight: Int
    private var items: [String: AVPlayerItem] = [:]
    private var order: [String] = []
    private var inFlight: Set<String> = []

    init(maxEntries: Int, maxInFlight: Int) {
        self.maxEntries = maxEntries
        self.maxInFlight = maxInFlight

        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task {
                await PlayerItemPrefetchCache.shared.clear()
            }
        }
    }

    func prefetch(take: ProjectTake) async {
        let key = cacheKey(for: take)
        guard items[key] == nil, !inFlight.contains(key) else { return }
        guard inFlight.count < maxInFlight else { return }

        inFlight.insert(key)
        let fileName = URL(fileURLWithPath: take.effectiveFilePath).lastPathComponent
        let durationSeconds = take.effectiveDurationSeconds
        let shouldHotLoad = durationSeconds > 0 && durationSeconds < 300
#if DEBUG
        print("🧪 Prefetch start file=\(fileName) hot=\(shouldHotLoad) dur=\(String(format: "%.2f", durationSeconds))")
#endif
        Task.detached(priority: .utility) { [key] in
            let start = CFAbsoluteTimeGetCurrent()
            let item = await TakePlaybackBuilder.makePlayerItem(for: take)
            if shouldHotLoad {
                let asset = await MainActor.run { item.asset }
                do {
                    _ = try await asset.load(.isPlayable)
                    _ = try await asset.load(.duration)
                    _ = try await asset.load(.tracks)
#if DEBUG
                    print("🧪 Prefetch hot asset ready file=\(fileName)")
#endif
                } catch {
#if DEBUG
                    print("🧪 Prefetch hot asset load failed file=\(fileName) err=\(error)")
#endif
                }
            }
            let elapsed = CFAbsoluteTimeGetCurrent() - start
            await PlayerItemPrefetchCache.shared.store(item: item, key: key, fileName: fileName, elapsed: elapsed)
        }
    }

    func popItem(for take: ProjectTake) -> AVPlayerItem? {
        let key = cacheKey(for: take)
        if let item = items.removeValue(forKey: key) {
            order.removeAll { $0 == key }
#if DEBUG
            let fileName = URL(fileURLWithPath: take.effectiveFilePath).lastPathComponent
            print("🧪 Prefetch hit file=\(fileName)")
#endif
            return item
        }
        return nil
    }

    func clear() {
        items.removeAll()
        order.removeAll()
        inFlight.removeAll()
    }

    private func store(item: AVPlayerItem, key: String, fileName: String, elapsed: Double) {
        inFlight.remove(key)
        if items[key] != nil {
            return
        }
        items[key] = item
        order.append(key)
        trimIfNeeded()
#if DEBUG
        print(String(format: "🧪 Prefetch ready file=%@ %.3f s", fileName, elapsed))
#endif
    }

    private func trimIfNeeded() {
        while order.count > maxEntries {
            let oldestKey = order.removeFirst()
            items.removeValue(forKey: oldestKey)
        }
    }

    private func cacheKey(for take: ProjectTake) -> String {
        let editID = take.editMetadata?.editID.uuidString ?? "noedit"
        return "\(take.id.uuidString)-\(editID)"
    }
}
