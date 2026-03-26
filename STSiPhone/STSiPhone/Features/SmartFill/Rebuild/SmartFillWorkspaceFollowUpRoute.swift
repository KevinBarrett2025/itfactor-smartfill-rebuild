import Foundation

enum SmartFillWorkspaceFollowUpRoute: Equatable, Sendable {
    case closeOnly
    case editor
    case player(returnToTakeReviewOnDismiss: Bool)

    static func resolve(for returnTarget: SmartFillReturnTarget) -> Self {
        switch returnTarget {
        case .editor:
            return .editor
        case .takeReview, .swipeablePlayer:
            return .player(returnToTakeReviewOnDismiss: true)
        case .projectDetail:
            return .player(returnToTakeReviewOnDismiss: false)
        case .standaloneWorkspace:
            return .closeOnly
        }
    }
}

enum SmartFillWorkspaceCompletionFollowUpAction: Equatable, Sendable {
    case closeOnly
    case openSavedTake

    static func primaryAction(hasSavedResult: Bool, canOpenSavedTake: Bool) -> Self {
        guard hasSavedResult, canOpenSavedTake else { return .closeOnly }
        return .openSavedTake
    }

    static func autoReturn(
        completionBehavior: SmartFillWorkspaceCompletionBehavior,
        hasSavedResult: Bool,
        canOpenSavedTake: Bool
    ) -> Self {
        guard completionBehavior == .returnAutomatically else { return .closeOnly }
        return primaryAction(hasSavedResult: hasSavedResult, canOpenSavedTake: canOpenSavedTake)
    }
}
