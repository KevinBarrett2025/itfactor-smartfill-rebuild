import SwiftUI

enum STSThemeID: String, CaseIterable, Identifiable {
    case studioLobbyV1
    case studioLobbyNeon
    case takeReviewClassic

    var id: String { rawValue }
}

struct STSTheme {
    let id: STSThemeID

    // Core palette
    let backgroundGradient: LinearGradient
    let primaryAccent: Color
    let cardBackground: Color
    let cardStroke: Color
    let textPrimary: Color
    let textSecondary: Color

    // Buttons
    let primaryButtonForeground: Color
    let primaryButtonBackground: Color
    let primaryButtonStroke: Color
}
