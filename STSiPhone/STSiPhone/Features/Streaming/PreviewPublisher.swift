import Foundation
import Combine

/// iOS-side publisher that simulates streaming preview data to macOS
@MainActor
public final class PreviewPublisher: ObservableObject {
    @Published public var status: PublisherStatus = .idle
    @Published public var isPublishing: Bool = false
    @Published public var messageCount: Int = 0
    @Published public var sessionInfo: SessionInfo?
    
    private var heartbeatTimer: Timer?
    private var startTime: Date?
    
    public init() {
        print("📡 PreviewPublisher initialized")
    }
    
    deinit {
        // Don't call stopPublishing in deinit as it's MainActor isolated
        // Just clean up the timer
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
        print("📡 PreviewPublisher deinitialized")
    }
    
    /// Start publishing heartbeat messages
    public func startPublishing(for session: ProjectSession? = nil) {
        guard !isPublishing else {
            print("📡 Already publishing, ignoring start request")
            return
        }
        
        print("📡 Starting preview publishing...")
        isPublishing = true
        status = .publishing
        startTime = Date()
        messageCount = 0
        
        // Set session info if provided
        if let session = session {
            sessionInfo = SessionInfo(
                sessionID: session.id,
                sessionType: session.type,
                startTime: Date()
            )
            
            // Send session start message
            let startMessage = PreviewMessage.sessionStart(
                projectID: UUID(), // Would be actual project ID
                sessionID: session.id
            )
            publishMessage(startMessage)
        }
        
        // Send initial status
        publishMessage(.text("Preview publishing started"))
        
        // Start heartbeat timer
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.sendHeartbeat()
            }
        }
        
        print("📡 Preview publishing started successfully")
    }
    
    /// Stop publishing messages
    public func stopPublishing() {
        guard isPublishing else { return }
        
        print("📡 Stopping preview publishing...")
        
        // Send session end message if we have session info
        if let sessionInfo = sessionInfo {
            let endMessage = PreviewMessage.sessionEnd(sessionID: sessionInfo.sessionID)
            publishMessage(endMessage)
        }
        
        // Send final status
        publishMessage(.text("Preview publishing stopped"))
        
        // Clean up timer
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
        
        // Update state
        isPublishing = false
        status = .idle
        sessionInfo = nil
        
        print("📡 Preview publishing stopped. Total messages sent: \(messageCount)")
    }
    
    /// Send a heartbeat message with current timestamp
    private func sendHeartbeat() {
        let heartbeat = PreviewMessage.heartbeat(Date())
        publishMessage(heartbeat)
    }
    
    /// Publish a preview message
    private func publishMessage(_ message: PreviewMessage) {
        messageCount += 1
        
        // Post to NotificationCenter for local communication
        NotificationCenter.default.post(
            name: .previewMessageOut,
            object: message
        )
        
        // Log message for debugging
        if message.priority != .low || messageCount % 10 == 0 { // Reduce heartbeat spam
            print("📡 Sent: \(message.description)")
        }
    }
    
    /// Send a custom text message
    public func sendTextMessage(_ text: String) {
        guard isPublishing else { return }
        publishMessage(.text(text))
    }
    
    /// Send a simulated frame (for testing)
    public func sendTestFrame() {
        guard isPublishing else { return }
        let testData = "test frame data".data(using: .utf8) ?? Data()
        publishMessage(.frame(data: testData))
    }
    
    /// Get publishing duration
    public var publishingDuration: TimeInterval? {
        guard let startTime = startTime, isPublishing else { return nil }
        return Date().timeIntervalSince(startTime)
    }
}

// MARK: - Supporting Types

public enum PublisherStatus: String, CaseIterable {
    case idle = "Idle"
    case connecting = "Connecting"
    case publishing = "Publishing"
    case error = "Error"
    
    public var description: String {
        rawValue
    }
    
    public var systemImage: String {
        switch self {
        case .idle:
            return "stop.circle"
        case .connecting:
            return "clock.arrow.2.circlepath"
        case .publishing:
            return "dot.radiowaves.left.and.right"
        case .error:
            return "exclamationmark.triangle"
        }
    }
}

public struct SessionInfo {
    public let sessionID: UUID
    public let sessionType: SessionType
    public let startTime: Date
    
    public var duration: TimeInterval {
        Date().timeIntervalSince(startTime)
    }
}
