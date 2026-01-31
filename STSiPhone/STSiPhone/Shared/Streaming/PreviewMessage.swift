import Foundation

/// Message contract for preview streaming communication between iOS and macOS
public enum PreviewMessage: Codable {
    case frame(data: Data)      // Future: compressed video frame data
    case heartbeat(Date)        // Connection keepalive with timestamp
    case text(String)          // Debug/status text messages
    case sessionStart(projectID: UUID, sessionID: UUID)
    case sessionEnd(sessionID: UUID)
    case error(String)         // Error messages
}

extension PreviewMessage {
    /// User-friendly description for debugging
    public var description: String {
        switch self {
        case .frame(let data):
            return "Frame (\(data.count) bytes)"
        case .heartbeat(let date):
            return "Heartbeat @ \(date.formatted(date: .omitted, time: .standard))"
        case .text(let message):
            return "Text: \(message)"
        case .sessionStart(let projectID, let sessionID):
            return "Session Started (Project: \(projectID.uuidString.prefix(8)), Session: \(sessionID.uuidString.prefix(8)))"
        case .sessionEnd(let sessionID):
            return "Session Ended (\(sessionID.uuidString.prefix(8)))"
        case .error(let errorMessage):
            return "Error: \(errorMessage)"
        }
    }
    
    /// Message priority for UI updates
    public var priority: MessagePriority {
        switch self {
        case .error:
            return .high
        case .sessionStart, .sessionEnd:
            return .medium
        case .frame, .heartbeat, .text:
            return .low
        }
    }
}

public enum MessagePriority {
    case high, medium, low
}

/// Notification names for message passing
public extension Notification.Name {
    static let previewMessageOut = Notification.Name("PreviewMessageOut")
    static let previewConnectionStatusChanged = Notification.Name("PreviewConnectionStatusChanged")
}