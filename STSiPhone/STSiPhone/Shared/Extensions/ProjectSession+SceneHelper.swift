import Foundation

extension ProjectSession {
    /// Returns the current scene number for this session, defaulting to 1.
    func sceneNumber(for _: UUID) -> Int {
        return takes.first?.sceneNumber ?? 1
    }
}
