import Foundation
import WatchConnectivity
import Combine

extension Notification.Name {
    static let watchBridgeRemoteModeSelected = Notification.Name("WatchBridgeRemoteModeSelected")
}

final class WatchBridge: NSObject, WCSessionDelegate, ObservableObject {
    static let shared = WatchBridge()
    
    private let session: WCSession? = WCSession.isSupported() ? WCSession.default : nil
    private var lastKnownRecordingState: Bool = false
    private var lastSceneIndex: Int = 1
    private var lastCameraReady: Bool = false
    private var lastModeLabel: String = "SCENE 1"
    private var lastModeValue: String = "scene"
    private var lastSlateStyleIndex: Int = 0
    private var heartbeatTimer: Timer?
    private var heartbeatInterval: TimeInterval = 2.5
    
    // Session state for Settings / Camera HUD
    @Published private(set) var isSessionActive: Bool = false
    @Published private(set) var isReachable: Bool = false
    @Published private(set) var didReceiveWatchReady: Bool = false
    
    weak var cameraController: CameraControlling?
    weak var modeController: ModeControlling?
    
    func start() {
        guard let session else { return }
        if session.delegate !== self {
            session.delegate = self
        }
        switch session.activationState {
        case .notActivated:
            session.activate()
        case .inactive, .activated:
            break
        @unknown default:
            break
        }
        isReachable = session.isReachable
        isSessionActive = (session.activationState == .activated)
    }
    
    // MARK: - Phone -> Watch
    
    func sendStatus(_ payload: [String: Any]) {
        var enriched = payload
        enriched["sceneCount"] = currentSceneCount()
        sendMessage(enriched)
    }
    
    func startHeartbeat(interval: TimeInterval = 2.5) {
        heartbeatInterval = interval
        stopHeartbeat()
        
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.sendStatusSnapshot(reason: "heartbeat")
        }
        if let timer = heartbeatTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
        sendStatusSnapshot(reason: "heartbeat-start")
    }
    
    func stopHeartbeat() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
    }
    
    func sendThumbnail(_ jpegData: Data, width: Int, height: Int) {
        guard let session, session.isReachable else { return }
        let payload: [String: Any] = [
            "cmd": "thumb",
            "bytes": jpegData.base64EncodedString(),
            "w": width,
            "h": height
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: payload) else { return }
        session.sendMessageData(data, replyHandler: nil, errorHandler: nil)
    }
    
    /// Call from camera stack when recording starts/stops
    func notifyRecordingState(_ isRecording: Bool) {
        lastKnownRecordingState = isRecording
        lastKnownRecordingState = isRecording
        sendStatus([
            "cmd": "status",
            "recording": isRecording,
            "event": isRecording ? "record_started" : "record_stopped"
        ])
    }
    
    func notifyCameraReady(_ isReady: Bool) {
        if !isReady {
            lastKnownRecordingState = false
        }
        lastCameraReady = isReady
        sendStatus([
            "cmd": "status",
            "cameraReady": isReady,
            "event": isReady ? "camera_ready" : "camera_closed",
            "recording": isReady ? lastKnownRecordingState : false
        ])
    }
    
    /// Call from anywhere (or via mode commands) when mode changes
    func notifyRemoteState(label: String, modeValue: String, sceneIndex: Int, slateStyleIndex: Int) {
        lastSceneIndex = sceneIndex
        lastModeLabel = label
        lastModeValue = modeValue
        lastSlateStyleIndex = slateStyleIndex
        sendStatus([
            "cmd": "status",
            "mode": label,
            "modeValue": modeValue,
            "sceneIndex": sceneIndex,
            "slateStyleIndex": slateStyleIndex,
            "event": "mode_changed"
        ])
    }
    
    // MARK: - Watch -> Phone
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        guard let cmd = message["cmd"] as? String else { return }
        
        switch cmd {
        case "record":
            let action = (message["action"] as? String) ?? ""
            if action == "start" { cameraController?.startRecording() }
            if action == "stop" { cameraController?.stopRecording() }
        case "request_status":
            sendStatusSnapshot(reason: "manual-request")
            
        case "photo":
            cameraController?.capturePhotoViaRemote()
            
        case "mode":
            guard let value = message["value"] as? String else { return }
            let index = message["index"] as? Int
            
            switch value {
            case "scene":
                let n = index ?? 1
                modeController?.setMode(.scene(n))
                notifyRemoteState(label: "SCENE \(n)", modeValue: "scene", sceneIndex: n, slateStyleIndex: 0)
                postRemoteModeNotification(value: value, index: n)
            case "slate":
                modeController?.setMode(.slate)
                let slateIndex = index ?? 0
                notifyRemoteState(label: "SLATE", modeValue: "slate", sceneIndex: lastSceneIndex, slateStyleIndex: slateIndex)
                postRemoteModeNotification(value: value, index: index)
            case "photo":
                modeController?.setMode(.photo)
                notifyRemoteState(label: "PHOTO", modeValue: "photo", sceneIndex: lastSceneIndex, slateStyleIndex: 0)
                postRemoteModeNotification(value: value, index: nil)
            default:
                break
            }
            
        case "ping":
            sendStatus(["cmd": "status", "ok": true])
            
        case "watchReady":
            DispatchQueue.main.async {
                self.didReceiveWatchReady = true
                self.isReachable = true
            }
            
        default:
            break
        }
    }
    
    // MARK: - Reachability
    
    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async { [weak self] in
            self?.isReachable = session.isReachable
        }
    }
    
    // MARK: - WCSessionDelegate stubs
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            self.isSessionActive = (activationState == .activated)
            if activationState != .activated {
                self.isReachable = false
                self.didReceiveWatchReady = false
            }
        }
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        // Maintain delegate symmetry with the watch target even though the phone currently ignores context payloads.
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}
    
    func sessionDidDeactivate(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isSessionActive = false
            self.isReachable = false
            self.didReceiveWatchReady = false
        }
        switch session.activationState {
        case .activated:
            break
        default:
            session.activate()
        }
    }

    // MARK: - Private helpers

    private func sendMessage(_ payload: [String: Any]) {
        guard let session else { return }

        guard session.activationState == .activated else {
            start()
            return
        }

        guard session.isReachable else {
            queueApplicationContextUpdate(payload, on: session)
            return
        }

        session.sendMessage(payload, replyHandler: nil) { _ in
            // Ignore transient failures; session reachability callbacks will retry via context.
        }
    }

    private func queueApplicationContextUpdate(_ payload: [String: Any], on session: WCSession) {
        guard !payload.isEmpty else { return }
        do {
            var context = session.applicationContext
            payload.forEach { context[$0.key] = $0.value }
            try session.updateApplicationContext(context)
        } catch {
            // Silently ignore – context updates are best-effort.
        }
    }
    
    private func currentSceneCount() -> Int {
        let total = SessionManager.shared.totalScenes
        return max(1, min(total, 10))
    }
    
    private func sendStatusSnapshot(reason: String) {
        let payload: [String: Any] = [
            "cmd": "status",
            "cameraReady": lastCameraReady,
            "recording": lastCameraReady ? lastKnownRecordingState : false,
            "mode": lastModeLabel,
            "modeValue": lastModeValue,
            "sceneIndex": lastSceneIndex,
            "slateStyleIndex": lastSlateStyleIndex,
            "sceneCount": currentSceneCount(),
            "reason": reason
        ]
        sendMessage(payload)
    }
    
    private func postRemoteModeNotification(value: String, index: Int?) {
        DispatchQueue.main.async {
            var info: [String: Any] = ["mode": value]
            if let index {
                info["index"] = index
            }
            NotificationCenter.default.post(
                name: .watchBridgeRemoteModeSelected,
                object: nil,
                userInfo: info
            )
        }
    }
}
