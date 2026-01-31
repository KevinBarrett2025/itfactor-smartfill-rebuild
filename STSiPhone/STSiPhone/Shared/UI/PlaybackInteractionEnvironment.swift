import SwiftUI

private struct PlaybackInteractionActiveKey: EnvironmentKey {
    static let defaultValue: Binding<Bool> = .constant(false)
}

extension EnvironmentValues {
    var playbackInteractionActive: Binding<Bool> {
        get { self[PlaybackInteractionActiveKey.self] }
        set { self[PlaybackInteractionActiveKey.self] = newValue }
    }
}
