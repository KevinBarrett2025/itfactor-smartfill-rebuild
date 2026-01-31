import SwiftUI
import Combine

final class ThemeManager: ObservableObject {

    @Published var currentID: STSThemeID {
        didSet { persist() }
    }

    var current: STSTheme {
        STSThemeLibrary.theme(for: currentID)
    }

    private let storageKey = "STSThemeID"

    init() {
        if let raw = UserDefaults.standard.string(forKey: storageKey),
           let id = STSThemeID(rawValue: raw) {
            currentID = id
        } else {
            currentID = .studioLobbyV1
        }
    }

    private func persist() {
        UserDefaults.standard.set(currentID.rawValue, forKey: storageKey)
    }
}
