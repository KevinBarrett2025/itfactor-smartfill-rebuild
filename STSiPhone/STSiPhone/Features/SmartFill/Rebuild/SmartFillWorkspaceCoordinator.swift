import Foundation

@MainActor
final class SmartFillWorkspaceCoordinator: ObservableObject {
    enum Stage: String, Sendable {
        case intake
        case configure
        case preview
        case export
        case completed
    }

    @Published private(set) var activeContext: SmartFillSessionContext?
    @Published private(set) var activeSettings: SmartFillSettingsSnapshot?
    @Published private(set) var stage: Stage = .intake
    @Published private(set) var lastResult: SmartFillResultBridgeRecord?

    func begin(
        context: SmartFillSessionContext,
        defaults: SmartFillWorkspaceDefaults
    ) {
        activeContext = context
        activeSettings = defaults.snapshot
        stage = defaults.shouldOfferSmartFill ? .configure : .preview
    }

    func updateSettings(_ snapshot: SmartFillSettingsSnapshot) {
        activeSettings = snapshot
    }

    func advance(to newStage: Stage) {
        stage = newStage
    }

    func recordResult(_ result: SmartFillResultBridgeRecord) {
        lastResult = result
        stage = .completed
    }

    func reset() {
        activeContext = nil
        activeSettings = nil
        lastResult = nil
        stage = .intake
    }
}
