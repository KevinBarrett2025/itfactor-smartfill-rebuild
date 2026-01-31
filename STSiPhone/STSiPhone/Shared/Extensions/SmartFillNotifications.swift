import Foundation

// MARK: - SmartFill Processing Notifications

extension Notification.Name {
    static let smartFillProcessingComplete = Notification.Name("SmartFillProcessingComplete")
    static let smartFillProcessingProgress = Notification.Name("SmartFillProcessingProgress")
    static let smartFillProcessingFailed = Notification.Name("SmartFillProcessingFailed")
}