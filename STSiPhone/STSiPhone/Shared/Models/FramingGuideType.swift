import Foundation

/// Framing guide types for camera composition
enum FramingGuideType: String, CaseIterable, Codable {
    case closeUp = "closeUp"
    case mediumShot = "mediumShot"
    case fullShot = "fullShot"
    case ruleOfThirds = "ruleOfThirds"
    
    var displayName: String {
        switch self {
        case .closeUp:
            return "Close Up"
        case .mediumShot:
            return "Medium Shot"
        case .fullShot:
            return "Full Shot"
        case .ruleOfThirds:
            return "Rule of Thirds"
        }
    }
}