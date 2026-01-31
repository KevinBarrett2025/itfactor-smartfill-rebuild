import CoreGraphics
import Foundation

enum ActorKitBadgeStopFace: String, CaseIterable, Identifiable {
    case logo
    case profile

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .logo:
            return "Logo Face"
        case .profile:
            return "Profile Photo"
        }
    }

    var description: String {
        switch self {
        case .logo:
            return "Show the I.T. Actor logo when the spinner is stopped."
        case .profile:
            return "Show your back face or profile photo when motion pauses."
        }
    }

    var restAngleDegrees: CGFloat {
        switch self {
        case .logo:
            return 0
        case .profile:
            return 180
        }
    }
}
