import Foundation
import SwiftUI

// MARK: - Navigation Context Types

public enum SourceView: String, Codable, CaseIterable {
    case takeReview
    case cameraCapture
    case sessionTakesModal
    case player
}

public enum ViewType: String, Codable, CaseIterable {
    case scenes
    case slates
    case photos
    case keyframes
}

// Bridge old names (if any call-sites use them)
public typealias NavigationSourceView = SourceView
public typealias NavigationViewType = ViewType

public struct NavigationContext: Codable, Identifiable, Equatable {
    public let id: UUID
    public let sourceView: SourceView
    public var viewType: ViewType
    public var sceneNumber: Int
    public var takeIndex: Int?
    public let sessionID: UUID
    public let projectID: UUID
    public let timestamp: Date
    public var metadata: [String: String]?

    public init(sourceView: SourceView,
                viewType: ViewType,
                sceneNumber: Int,
                takeIndex: Int? = nil,
                sessionID: UUID,
                projectID: UUID,
                timestamp: Date = Date(),
                metadata: [String: String]? = nil) {
        self.id = UUID()
        self.sourceView = sourceView
        self.viewType = viewType
        self.sceneNumber = sceneNumber
        self.takeIndex = takeIndex
        self.sessionID = sessionID
        self.projectID = projectID
        self.timestamp = timestamp
        self.metadata = metadata
    }

    public static func == (lhs: NavigationContext, rhs: NavigationContext) -> Bool {
        return lhs.sourceView == rhs.sourceView &&
        lhs.viewType == rhs.viewType &&
        lhs.sceneNumber == rhs.sceneNumber &&
        lhs.takeIndex == rhs.takeIndex &&
        lhs.sessionID == rhs.sessionID &&
        lhs.projectID == rhs.projectID &&
        lhs.metadata == rhs.metadata
    }
}

// MARK: - Manager

@MainActor
public final class NavigationContextManager: ObservableObject {
    // Nested types for backward compatibility
    public typealias SourceView = STSiPhone.SourceView
    public typealias ViewType = STSiPhone.ViewType
    
    public static let shared = NavigationContextManager()

    @Published private(set) var contextStack: [NavigationContext] = []

    private let persistenceKey = "sts.navContextStack.v1"
    private let maxDepth = 32
    private let staleInterval: TimeInterval = 60 * 60

    private init() {
        load()
        cleanupStaleContexts()
    }

    // MARK: Preserve

    public func preserve(_ ctx: NavigationContext) {
        if let last = contextStack.last, last == ctx { return }
        contextStack.append(ctx)
        if contextStack.count > maxDepth {
            contextStack.removeFirst(contextStack.count - maxDepth)
        }
        #if DEBUG
        debugLog("Preserved \(ctx.sourceView.rawValue) → \(ctx.viewType.rawValue) scene=\(ctx.sceneNumber) takeIndex=\(ctx.takeIndex ?? -1) meta=\(ctx.metadata ?? [:]) stack=\(contextStack.count)")
        #endif
        save()
    }

    public func preserveFromTakeReview(viewType: ViewType,
                                       scene: Int,
                                       takeIndex: Int? = nil,
                                       sessionID: UUID,
                                       projectID: UUID,
                                       metadata: [String: String]? = nil) {
        let ctx = NavigationContext(sourceView: .takeReview,
                                    viewType: viewType,
                                    sceneNumber: scene,
                                    takeIndex: takeIndex,
                                    sessionID: sessionID,
                                    projectID: projectID,
                                    metadata: metadata)
        preserve(ctx)
    }

    public func preserveFromCamera(scene: Int,
                                   viewType: ViewType,
                                   sessionID: UUID,
                                   projectID: UUID,
                                   metadata: [String: String]? = nil) {
        let ctx = NavigationContext(sourceView: .cameraCapture,
                                    viewType: viewType,
                                    sceneNumber: scene,
                                    sessionID: sessionID,
                                    projectID: projectID,
                                    metadata: metadata)
        preserve(ctx)
    }

    public func preserveFromModal(scene: Int,
                                  viewType: ViewType,
                                  sessionID: UUID,
                                  projectID: UUID,
                                  metadata: [String: String]? = nil) {
        let ctx = NavigationContext(sourceView: .sessionTakesModal,
                                    viewType: viewType,
                                    sceneNumber: scene,
                                    sessionID: sessionID,
                                    projectID: projectID,
                                    metadata: metadata)
        preserve(ctx)
    }

    public func preserveFromPlayer(scene: Int,
                                   viewType: ViewType,
                                   takeIndex: Int?,
                                   sessionID: UUID,
                                   projectID: UUID,
                                   metadata: [String: String]? = nil) {
        let ctx = NavigationContext(sourceView: .player,
                                    viewType: viewType,
                                    sceneNumber: scene,
                                    takeIndex: takeIndex,
                                    sessionID: sessionID,
                                    projectID: projectID,
                                    metadata: metadata)
        preserve(ctx)
    }

    // MARK: Restore

    public func restore(to target: SourceView? = nil,
                        sessionID: UUID? = nil,
                        projectID: UUID? = nil) -> NavigationContext? {
        guard !contextStack.isEmpty else { return nil }

        if let target = target,
           let idx = contextStack.lastIndex(where: { $0.sourceView == target }) {
            let ctx = contextStack[idx]
            if let s = sessionID, ctx.sessionID != s { return nil }
            if let p = projectID, ctx.projectID != p { return nil }
            contextStack.removeSubrange(idx..<contextStack.count)
            save()
            return ctx
        }

        let ctx = contextStack.removeLast()
        save()

        if let s = sessionID, ctx.sessionID != s { return nil }
        if let p = projectID, ctx.projectID != p { return nil }
        #if DEBUG
        debugLog("Restored \(ctx.sourceView.rawValue) for session=\(ctx.sessionID.shortID) project=\(ctx.projectID.shortID) -> \(ctx.viewType.rawValue)")
        #endif
        return ctx
    }

    public func peek() -> NavigationContext? { contextStack.last }
    
    public func preferredContext(sessionID: UUID,
                                 projectID: UUID,
                                 prioritizedSources: [SourceView] = [.sessionTakesModal, .cameraCapture, .takeReview, .player]) -> NavigationContext? {
        let reversed = contextStack.reversed()
        var candidate: NavigationContext?
        if !prioritizedSources.isEmpty {
            for source in prioritizedSources {
                if let match = reversed.first(where: { $0.sourceView == source && $0.sessionID == sessionID && $0.projectID == projectID }) {
                    candidate = match
                    break
                }
            }
        }
        let fallback = candidate ?? reversed.first(where: { $0.sessionID == sessionID && $0.projectID == projectID })
        #if DEBUG
        let stackSummary = contextStack
            .filter { $0.sessionID == sessionID && $0.projectID == projectID }
            .map { "\($0.sourceView.rawValue):\($0.viewType.rawValue)#\($0.sceneNumber)" }
            .joined(separator: ", ")
        debugLog("Preferred lookup session=\(sessionID.shortID) project=\(projectID.shortID) sources=\(prioritizedSources.map { $0.rawValue }) stack=[\(stackSummary)] -> \(fallback.map { "\($0.sourceView.rawValue):\($0.viewType.rawValue)" } ?? "nil")")
        #endif
        return fallback
    }
    
    public func removeContext(id: UUID) {
        if let index = contextStack.firstIndex(where: { $0.id == id }) {
            let removed = contextStack.remove(at: index)
            #if DEBUG
            debugLog("Removed \(removed.sourceView.rawValue) context for session=\(removed.sessionID.shortID) project=\(removed.projectID.shortID)")
            #endif
            save()
        }
    }

    public func clearAll() {
        contextStack.removeAll()
        save()
    }

    public func clearContexts(source: SourceView, sessionID: UUID, projectID: UUID) {
        let before = contextStack.count
        contextStack.removeAll { $0.sourceView == source && $0.sessionID == sessionID && $0.projectID == projectID }
        if contextStack.count != before {
            #if DEBUG
            debugLog("Cleared \(before - contextStack.count) \(source.rawValue) contexts for session=\(sessionID.shortID) project=\(projectID.shortID)")
            #endif
        }
        save()
    }

    public func clearMismatched(sessionID: UUID, projectID: UUID) {
        contextStack.removeAll { $0.sessionID != sessionID || $0.projectID != projectID }
        #if DEBUG
        debugLog("Cleared mismatched contexts – remaining \(contextStack.count) entries")
        #endif
        save()
    }

    public func cleanupStaleContexts(now: Date = Date()) {
        contextStack.removeAll { now.timeIntervalSince($0.timestamp) > staleInterval }
        if contextStack.count > maxDepth {
            contextStack.removeFirst(contextStack.count - maxDepth)
        }
        save()
    }

    // MARK: Persistence

    private func save() {
        do {
            let data = try JSONEncoder().encode(contextStack)
            UserDefaults.standard.set(data, forKey: persistenceKey)
        } catch {
            #if DEBUG
            print("NavigationContextManager save error: \(error)")
            #endif
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: persistenceKey) else { return }
        do {
            let stack = try JSONDecoder().decode([NavigationContext].self, from: data)
            contextStack = stack
        } catch {
            contextStack = []
            UserDefaults.standard.removeObject(forKey: persistenceKey)
        }
    }

    #if DEBUG
    private func debugLog(_ message: String) {
        print("🧭 NavCtx: \(message)")
    }
    #endif
}

private extension UUID {
    var shortID: String {
        return uuidString.split(separator: "-").first.map(String.init) ?? uuidString
    }
}
