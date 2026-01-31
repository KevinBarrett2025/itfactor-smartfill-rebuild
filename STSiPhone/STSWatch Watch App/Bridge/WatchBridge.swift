import WatchConnectivity
import UIKit
import Combine
import WatchKit

final class WatchBridge: NSObject, WCSessionDelegate, ObservableObject {
    static let shared = WatchBridge()
    
    @Published var thumbnail: UIImage?
    @Published var isRecording = false
    @Published var modeLabel = "SCENE 1"
    @Published var sceneCount: Int = 6
    @Published var hasReceivedStatus: Bool = false
    @Published var remoteModeValue: String = "scene"
    @Published var remoteSceneIndex: Int = 1
    @Published var remoteSlateStyleIndex: Int = 0
    @Published var lastStatusAt: Date? = nil
    
    /// How long we allow the phone to be silent before we consider the remote stale.
    private let statusStaleAfter: TimeInterval = 10
    private var statusWatchdogCancellable: AnyCancellable?
    
    private var pendingMessages: [[String: Any]] = []
    private let session: WCSession? = WCSession.isSupported() ? WCSession.default : nil
    private var didSendInitialHandshake = false
    
    func start() {
        guard let session else { return }
        if session.delegate !== self {
            session.delegate = self
        }
        switch session.activationState {
        case .notActivated:
            session.activate()
        case .inactive:
            break
        case .activated:
            flushPending(on: session)
        @unknown default:
            break
        }
        sendInitialHandshakeIfNeeded()
        startStatusWatchdog()
    }
    
    // MARK: - Watch -> Phone
    
    func record(start: Bool) {
        guard hasFreshStatus, hasReceivedStatus else {
            WKInterfaceDevice.current().play(.failure)
            return
        }
        let message: [String: Any] = [
            "cmd": "record",
            "action": start ? "start" : "stop"
        ]
        sendOrQueue(message)
        isRecording = start
    }
    
    func capturePhoto() {
        guard hasFreshStatus, hasReceivedStatus else {
            WKInterfaceDevice.current().play(.failure)
            return
        }
        let message: [String: Any] = [
            "cmd": "photo"
        ]
        sendOrQueue(message)
    }
    
    func requestStatus() {
        let message: [String: Any] = [
            "cmd": "request_status"
        ]
        sendOrQueue(message)
    }
    
    func setMode(_ value: String, index: Int? = nil) {
        let clampedIndex: Int?
        if value == "scene" {
            let desired = index ?? 1
            clampedIndex = max(1, min(desired, sceneCount))
        } else {
            clampedIndex = index
        }
        var message: [String: Any] = [
            "cmd": "mode",
            "value": value
        ]
        if let clampedIndex {
            message["index"] = clampedIndex
        }
        sendOrQueue(message)
        
        if value == "scene" {
            modeLabel = "SCENE \(clampedIndex ?? 1)"
        } else {
            modeLabel = value.uppercased()
        }
    }
    
    private func sendOrQueue(_ message: [String: Any]) {
        guard let session else { return }

        guard session.activationState == .activated else {
            enqueue(message)
            if session.activationState == .notActivated {
                session.activate()
            }
            return
        }

        guard session.isReachable else {
            enqueue(message)
            return
        }

        session.sendMessage(message, replyHandler: nil) { [weak self] _ in
            self?.enqueue(message)
        }
    }
    
    private func sendInitialHandshakeIfNeeded() {
        guard !didSendInitialHandshake else { return }
        didSendInitialHandshake = true
        sendOrQueue(["cmd": "watchReady"])
    }
    
    // MARK: - Phone -> Watch (thumb + status)
    
    func session(_ session: WCSession, didReceiveMessageData messageData: Data) {
        guard
            let json = try? JSONSerialization.jsonObject(with: messageData) as? [String: Any],
            let command = json["cmd"] as? String
        else { return }
        
        if command == "thumb",
           let base64 = json["bytes"] as? String,
           let bytes = Data(base64Encoded: base64),
           let image = UIImage(data: bytes) {
            DispatchQueue.main.async {
                self.thumbnail = image
            }
        }
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        guard let command = message["cmd"] as? String else { return }
        
        if command == "status" {
            if let isRecording = message["recording"] as? Bool {
                DispatchQueue.main.async {
                    self.isRecording = isRecording
                }
            }
            if let mode = message["mode"] as? String {
                DispatchQueue.main.async {
                    self.modeLabel = mode
                }
            }
            if let count = message["sceneCount"] as? Int {
                DispatchQueue.main.async {
                    self.sceneCount = max(1, min(count, 10))
                }
            }
            if let modeValue = message["modeValue"] as? String {
                DispatchQueue.main.async {
                    self.remoteModeValue = modeValue
                }
            }
            if let sceneIndex = message["sceneIndex"] as? Int {
                DispatchQueue.main.async {
                    self.remoteSceneIndex = max(1, min(10, sceneIndex))
                }
            }
            if let slateIndex = message["slateStyleIndex"] as? Int {
                DispatchQueue.main.async {
                    self.remoteSlateStyleIndex = max(0, min(2, slateIndex))
                }
            }
            if message["error"] is String {
                DispatchQueue.main.async {
                    WKInterfaceDevice.current().play(.failure)
                }
            }
            if let ready = message["cameraReady"] as? Bool {
                DispatchQueue.main.async {
                    self.hasReceivedStatus = ready
                    if !ready {
                        self.isRecording = false
                    }
                }
            }
            DispatchQueue.main.async {
                self.lastStatusAt = Date()
            }
        }
    }
    
    // MARK: - Required stubs
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        guard activationState == .activated else { return }
        flushPending(on: session)
    }
    
    func sessionReachabilityDidChange(_ session: WCSession) {
        flushPending(on: session)
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        DispatchQueue.main.async {
            if let isRecording = applicationContext["recording"] as? Bool {
                self.isRecording = isRecording
            }
            if let mode = applicationContext["mode"] as? String {
                self.modeLabel = mode
            }
            if let count = applicationContext["sceneCount"] as? Int {
                let clamped = max(1, min(10, count))
                self.sceneCount = clamped
            }
            if let modeValue = applicationContext["modeValue"] as? String {
                self.remoteModeValue = modeValue
            }
            if let sceneIndex = applicationContext["sceneIndex"] as? Int {
                self.remoteSceneIndex = max(1, min(10, sceneIndex))
            }
            if let slateIndex = applicationContext["slateStyleIndex"] as? Int {
                self.remoteSlateStyleIndex = max(0, min(2, slateIndex))
            }
            if let ready = applicationContext["cameraReady"] as? Bool {
                self.hasReceivedStatus = ready
                if !ready {
                    self.isRecording = false
                }
            }
            self.lastStatusAt = Date()
        }
    }

    private func enqueue(_ message: [String: Any]) {
        if pendingMessages.count >= 8 {
            pendingMessages.removeFirst()
        }
        pendingMessages.append(message)
    }

    private func flushPending(on session: WCSession) {
        guard session.isReachable, !pendingMessages.isEmpty else { return }
        let messages = pendingMessages
        pendingMessages.removeAll()
        for message in messages {
            session.sendMessage(message, replyHandler: nil, errorHandler: nil)
        }
    }

    private func startStatusWatchdog() {
        statusWatchdogCancellable?.cancel()
        statusWatchdogCancellable = Timer
            .publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.checkStatusFreshness()
            }
    }

    private var hasFreshStatus: Bool {
        guard let last = lastStatusAt else { return false }
        return Date().timeIntervalSince(last) <= statusStaleAfter
    }

    private func checkStatusFreshness() {
        guard let last = lastStatusAt else { return }
        let age = Date().timeIntervalSince(last)
        if age > statusStaleAfter {
            forceIdle(reason: "stale_status_age_\(Int(age))")
        }
    }

    private func forceIdle(reason: String) {
        // No-op if we are already idle
        if hasReceivedStatus == false && isRecording == false { return }

        hasReceivedStatus = false
        isRecording = false
        // Keep other UI state as-is to avoid jarring transitions; message is only for debugging
        print("🕐 WatchBridge: forcing idle due to \(reason)")
    }

    deinit {
        statusWatchdogCancellable?.cancel()
    }
}
