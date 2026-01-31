import Foundation

struct Constants {
    
    // MARK: - App Information
    struct App {
        static let name = "STS iPhone"
        static let version = "1.0.0"
        static let buildNumber = "1"
    }
    
    // MARK: - UserDefaults Keys
    struct UserDefaultsKeys {
        static let hasSeenOnboarding = "hasSeenOnboarding"
        static let preferredQuality = "preferredQuality"
        static let autoSave = "autoSave"
        static let lastSync = "lastSync"
    }
    
    // MARK: - Networking
    struct Network {
        static let baseURL = "https://api.selftapestudio.com"
        static let timeout: TimeInterval = 30.0
    }
    
    // MARK: - File Paths
    struct FilePaths {
        static let documentsDirectory = "Documents"
        static let sessionsDirectory = "Sessions"
        static let exportsDirectory = "Exports"
        static let cacheDirectory = "Cache"
    }
    
    // MARK: - Animation Durations
    struct Animation {
        static let short: Double = 0.2
        static let medium: Double = 0.3
        static let long: Double = 0.5
    }
    
    // MARK: - Recording Settings
    struct Recording {
        static let defaultDuration: TimeInterval = 300 // 5 minutes
        static let maxDuration: TimeInterval = 1800 // 30 minutes
        static let minDuration: TimeInterval = 10 // 10 seconds
    }
    
    // MARK: - System Identifiers
    struct Identifiers {
        // Tab bar items
        static let dashboardTab = "dashboard_tab"
        static let sessionManagerTab = "session_manager_tab"
        static let settingsTab = "settings_tab"
        
        // Notification names
        static let sessionStarted = "session_started"
        static let sessionEnded = "session_ended"
        static let sessionSaved = "session_saved"
    }
}