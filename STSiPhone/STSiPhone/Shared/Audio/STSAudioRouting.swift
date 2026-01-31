import AVFoundation

protocol STSAudioRouting: AnyObject {
    var availableInputs: [AVAudioSessionPortDescription] { get }
    var preferredInputUID: String? { get }
    var activeInputUID: String? { get }
    var activeInputName: String { get }
    var currentRouteSummary: String { get }
    var isSelectionPendingApply: Bool { get }

    func setPreferredInput(uid: String?) throws
    func refreshInputs()
    func setSelectionPendingApply(_ pending: Bool)
}

extension Notification.Name {
    static let stsAudioRouteDidChange = Notification.Name("stsAudioRouteDidChange")
    static let stsAudioPreferredInputDidChange = Notification.Name("stsAudioPreferredInputDidChange")
    static let stsAudioPendingApplyDidChange = Notification.Name("stsAudioPendingApplyDidChange")
}
