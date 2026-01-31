import Foundation

enum AudioQuality: String, CaseIterable, Codable {
    case studio
    case standard
    case lite

    var displayName: String {
        switch self {
        case .studio: return "Studio"
        case .standard: return "Standard"
        case .lite: return "Lite"
        }
    }

    var audioBitrate: Int {
        switch self {
        case .studio: return 256_000
        case .standard: return 192_000
        case .lite: return 128_000
        }
    }
}

enum AudioSettings {
    private static let audioQualityKey = "audio.quality"

    static var quality: AudioQuality {
        get {
            if let raw = UserDefaults.standard.string(forKey: audioQualityKey),
               let quality = AudioQuality(rawValue: raw) {
                return quality
            }
            return .standard
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: audioQualityKey)
        }
    }
}
