import Foundation
import AVFoundation

enum RecordingQuality: String, CaseIterable, Codable {
    case pro4K
    case standard1080
    case lite720

    var displayName: String {
        switch self {
        case .pro4K: return "4K (Best) 30 FPS"
        case .standard1080: return "1080p (Standard) 30 FPS"
        case .lite720: return "720p (Lite) 30 FPS"
        }
    }

    var sessionPreset: AVCaptureSession.Preset {
        switch self {
        case .pro4K: return .hd4K3840x2160
        case .standard1080: return .hd1920x1080
        case .lite720: return .hd1280x720
        }
    }

    var audioBitrate: Int {
        switch self {
        case .pro4K: return 256_000
        case .standard1080: return 192_000
        case .lite720: return 128_000
        }
    }
}

enum CameraSettings {
    static let mirrorFrontCameraKey = "camera.mirrorFront"
    static let recordingQualityKey = "camera.recordingQuality"
    static let recordBlinkTorchKey = "camera.recordBlinkTorch"
    
    static var mirrorFrontCameraEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: mirrorFrontCameraKey) == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: mirrorFrontCameraKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: mirrorFrontCameraKey)
            NotificationCenter.default.post(
                name: .cameraSettingsDidChange,
                object: nil,
                userInfo: [CameraSettingsNotificationKeys.mirrorFrontCameraEnabled: newValue]
            )
        }
    }
    
    static var recordingQuality: RecordingQuality {
        get {
            if let raw = UserDefaults.standard.string(forKey: recordingQualityKey),
               let quality = RecordingQuality(rawValue: raw) {
                return quality
            }
            return .standard1080
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: recordingQualityKey)
            NotificationCenter.default.post(
                name: .cameraSettingsDidChange,
                object: nil,
                userInfo: [CameraSettingsNotificationKeys.recordingQuality: newValue.rawValue]
            )
        }
    }

    static var recordBlinkTorchEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: recordBlinkTorchKey) == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: recordBlinkTorchKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: recordBlinkTorchKey)
            NotificationCenter.default.post(
                name: .cameraSettingsDidChange,
                object: nil,
                userInfo: [CameraSettingsNotificationKeys.recordBlinkTorchEnabled: newValue]
            )
        }
    }
}

enum CameraSettingsNotificationKeys {
    static let mirrorFrontCameraEnabled = "mirrorFrontCameraEnabled"
    static let recordingQuality = "recordingQuality"
    static let recordBlinkTorchEnabled = "recordBlinkTorchEnabled"
}

extension Notification.Name {
    static let cameraSettingsDidChange = Notification.Name("CameraSettingsDidChange")
}
