import Foundation

actor TakePlaybackDiagnostics {
    static let shared = TakePlaybackDiagnostics()

    private var warnedKeys = Set<String>()

    func warnIfUneditedPlayback(take: ProjectTake, fileName: String, reason: String) {
        guard take.hasEdits else { return }
        let editID = take.editMetadata?.editID.uuidString ?? "noedit"
        let key = "\(take.id.uuidString)-\(editID)"
        guard warnedKeys.insert(key).inserted else { return }
        print("⚠️ EDITED PLAYBACK WARNING: take has edits but playback item is URL-only reason=\(reason) take=\(take.id) file=\(fileName)")
    }
}
