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
