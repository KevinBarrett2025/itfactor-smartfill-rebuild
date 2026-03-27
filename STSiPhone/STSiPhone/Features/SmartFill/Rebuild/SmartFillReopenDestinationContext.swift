import Foundation

struct SmartFillReopenDestinationContext: Equatable, Sendable {
    let badgeTitle: String
    let title: String
    let message: String

    static func player(adoptedTakeDisplayName: String) -> SmartFillReopenDestinationContext {
        SmartFillReopenDestinationContext(
            badgeTitle: "Saved SmartFill Result",
            title: adoptedTakeDisplayName,
            message: "This is the SmartFill take you just saved. Review it here or open editing again if you want another pass."
        )
    }

    static func editor(adoptedTakeDisplayName: String) -> SmartFillReopenDestinationContext {
        SmartFillReopenDestinationContext(
            badgeTitle: "Saved SmartFill Result",
            title: "Opened \(adoptedTakeDisplayName)",
            message: "You are now editing the saved SmartFill take. Keep trimming, cropping, or exporting from this updated result."
        )
    }
}
