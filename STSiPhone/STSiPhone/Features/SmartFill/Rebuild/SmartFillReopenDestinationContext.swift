import Foundation

struct SmartFillReopenDestinationContext: Equatable, Sendable {
    let badgeTitle: String
    let title: String
    let message: String
    let sourceTakeID: UUID?
    let sourceTakeDisplayName: String?

    var playerComparisonActionTitle: String? {
        guard let sourceTakeDisplayName else { return nil }
        return "Compare with \(sourceTakeDisplayName)"
    }

    var editorComparisonActionTitle: String? {
        guard let sourceTakeDisplayName else { return nil }
        return "Open \(sourceTakeDisplayName)"
    }

    static func player(
        adoptedTakeDisplayName: String,
        sourceTakeID: UUID? = nil,
        sourceTakeDisplayName: String? = nil
    ) -> SmartFillReopenDestinationContext {
        SmartFillReopenDestinationContext(
            badgeTitle: "Saved SmartFill Result",
            title: adoptedTakeDisplayName,
            message: sourceTakeDisplayName.map {
                "This is the SmartFill take you just saved. Swipe or tap Compare with \($0) to judge it against the original source take."
            } ?? "This is the SmartFill take you just saved. Review it here or open editing again if you want another pass.",
            sourceTakeID: sourceTakeID,
            sourceTakeDisplayName: sourceTakeDisplayName
        )
    }

    static func editor(
        adoptedTakeDisplayName: String,
        sourceTakeID: UUID? = nil,
        sourceTakeDisplayName: String? = nil
    ) -> SmartFillReopenDestinationContext {
        SmartFillReopenDestinationContext(
            badgeTitle: "Saved SmartFill Result",
            title: "Opened \(adoptedTakeDisplayName)",
            message: sourceTakeDisplayName.map {
                "You are now editing the saved SmartFill take. Open \($0) if you want to compare it against the original source take."
            } ?? "You are now editing the saved SmartFill take. Keep trimming, cropping, or exporting from this updated result.",
            sourceTakeID: sourceTakeID,
            sourceTakeDisplayName: sourceTakeDisplayName
        )
    }
}
