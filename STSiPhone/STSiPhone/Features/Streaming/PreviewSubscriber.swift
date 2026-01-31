import Foundation
import Combine

/// Subscriber that receives preview messages (designed for macOS but works on iOS for testing)
@MainActor
public final class PreviewSubscriber: ObservableObject {
    @Published public var lastMessage: String = "No messages yet"
    @Published public var isConnected: Bool = false
    @Published public var messageHistory: [MessageHistoryItem] = []
    @Published public var currentSession: SessionInfo?
    
    private var messageCancellable: AnyCancellable?
    private var connectionTimer: Timer?
    private var lastHeartbeatTime: Date?
    
    private let maxHistoryCount = 50
    private let heartbeatTimeout: TimeInterval = 5.0
    
    public init() {
        print("📺 PreviewSubscriber initialized")
        startListening()
    }
    
    deinit {
        // Don't call stopListening in deinit as it's MainActor isolated
        // Just clean up the cancellable and timer
        messageCancellable?.cancel()
        messageCancellable = nil
        connectionTimer?.invalidate()
        connectionTimer = nil
        print("📺 PreviewSubscriber deinitialized")
    }
    
    /// Start listening for preview messages
    public func startListening() {
        print("📺 Starting to listen for preview messages...")
        
        messageCancellable = NotificationCenter.default
            .publisher(for: .previewMessageOut)
            .compactMap { $0.object as? PreviewMessage }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] message in
                self?.handleMessage(message)
            }
        
        // Start connection monitoring
        connectionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.checkConnection()
            }
        }
        
        addToHistory("Started listening for preview messages", priority: .medium)
    }
    
    /// Stop listening for messages
    public func stopListening() {
        print("📺 Stopping preview message listening...")
        
        messageCancellable?.cancel()
        messageCancellable = nil
        
        connectionTimer?.invalidate()
        connectionTimer = nil
        
        isConnected = false
        lastMessage = "Stopped listening"
        
        addToHistory("Stopped listening for preview messages", priority: .medium)
    }
    
    /// Handle incoming preview message
    private func handleMessage(_ message: PreviewMessage) {
        lastMessage = message.description
        
        switch message {
        case .heartbeat(let date):
            lastHeartbeatTime = date
            isConnected = true
            // Only add heartbeats to history occasionally to avoid spam
            if messageHistory.count % 10 == 0 {
                addToHistory(message.description, priority: message.priority)
            }
            
        case .sessionStart(_, let sessionID):
            currentSession = SessionInfo(
                sessionID: sessionID,
                sessionType: .selfTape, // Default, would be passed in real implementation
                startTime: Date()
            )
            addToHistory(message.description, priority: message.priority)
            
        case .sessionEnd(let sessionID):
            if currentSession?.sessionID == sessionID {
                let duration = currentSession?.duration ?? 0
                addToHistory("Session ended after \(Int(duration))s", priority: .medium)
                currentSession = nil
            }
            
        case .frame(let data):
            addToHistory("Received frame (\(data.count) bytes)", priority: message.priority)
            
        case .text(let text):
            addToHistory("Text: \(text)", priority: message.priority)
            
        case .error(let error):
            addToHistory("ERROR: \(error)", priority: message.priority)
        }
        
        // Log high and medium priority messages
        if message.priority != .low {
            print("📺 Received: \(message.description)")
        }
    }
    
    /// Check connection status based on heartbeat timing
    private func checkConnection() {
        guard let lastHeartbeat = lastHeartbeatTime else {
            if isConnected {
                isConnected = false
                addToHistory("Connection lost - no heartbeat received", priority: .medium)
            }
            return
        }
        
        let timeSinceHeartbeat = Date().timeIntervalSince(lastHeartbeat)
        
        if timeSinceHeartbeat > heartbeatTimeout && isConnected {
            isConnected = false
            addToHistory("Connection lost - heartbeat timeout", priority: .medium)
            print("📺 Connection lost - no heartbeat for \(Int(timeSinceHeartbeat))s")
        }
    }
    
    /// Add message to history with automatic cleanup
    private func addToHistory(_ message: String, priority: MessagePriority) {
        let item = MessageHistoryItem(
            message: message,
            timestamp: Date(),
            priority: priority
        )
        
        messageHistory.append(item)
        
        // Keep history size manageable
        if messageHistory.count > maxHistoryCount {
            messageHistory.removeFirst()
        }
    }
    
    /// Clear message history
    public func clearHistory() {
        messageHistory.removeAll()
        addToHistory("Message history cleared", priority: .low)
    }
    
    /// Get connection status description
    public var connectionStatus: String {
        if isConnected {
            if let lastHeartbeat = lastHeartbeatTime {
                let secondsAgo = Int(Date().timeIntervalSince(lastHeartbeat))
                return "Connected (last heartbeat \(secondsAgo)s ago)"
            } else {
                return "Connected"
            }
        } else {
            return "Disconnected"
        }
    }
}

// MARK: - Supporting Types

public struct MessageHistoryItem: Identifiable {
    public let id = UUID()
    public let message: String
    public let timestamp: Date
    public let priority: MessagePriority
    
    public var timeString: String {
        timestamp.formatted(date: .omitted, time: .standard)
    }
}
