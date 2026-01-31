import SwiftUI

enum STSThemeLibrary {

    static func theme(for id: STSThemeID) -> STSTheme {
        switch id {
        case .studioLobbyV1:
            return STSTheme(
                id: .studioLobbyV1,
                backgroundGradient: LinearGradient(
                    colors: [
                        Color(red: 0.05, green: 0.05, blue: 0.08),
                        Color(red: 0.02, green: 0.02, blue: 0.04)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                primaryAccent: Color.blue,
                cardBackground: Color.white.opacity(0.08),
                cardStroke: Color.white.opacity(0.08),
                textPrimary: .white,
                textSecondary: .white.opacity(0.65),
                primaryButtonForeground: .white,
                primaryButtonBackground: Color.white.opacity(0.12),
                primaryButtonStroke: Color.white.opacity(0.2)
            )

        case .studioLobbyNeon:
            return STSTheme(
                id: .studioLobbyNeon,
                backgroundGradient: LinearGradient(
                    colors: [
                        Color(red: 0.06, green: 0.00, blue: 0.17),
                        Color(red: 0.20, green: 0.02, blue: 0.35)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                primaryAccent: Color(red: 0.98, green: 0.30, blue: 0.90),
                cardBackground: Color.black.opacity(0.45),
                cardStroke: Color.white.opacity(0.08),
                textPrimary: .white,
                textSecondary: .white.opacity(0.7),
                primaryButtonForeground: .white,
                primaryButtonBackground: Color(red: 0.98, green: 0.30, blue: 0.90),
                primaryButtonStroke: Color.white.opacity(0.2)
            )

        case .takeReviewClassic:
            return STSTheme(
                id: .takeReviewClassic,
                backgroundGradient: LinearGradient(
                    colors: [
                        Color(white: 0.98),
                        Color(white: 0.9)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                primaryAccent: Color.black,
                cardBackground: Color(white: 0.97),
                cardStroke: Color(white: 0.75),
                textPrimary: .black,
                textSecondary: Color.gray,
                primaryButtonForeground: .white,
                primaryButtonBackground: Color.black.opacity(0.92),
                primaryButtonStroke: Color.black.opacity(0.8)
            )
        }
    }
}
