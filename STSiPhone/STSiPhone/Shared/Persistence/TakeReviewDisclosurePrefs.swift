import Foundation

struct TakeReviewDisclosurePrefs: Codable, Equatable {
    let breakdownExpanded: Bool
    let deliverablesExpanded: Bool
    let pipEditorExpanded: Bool

    static let defaults = TakeReviewDisclosurePrefs(
        breakdownExpanded: false,
        deliverablesExpanded: true,
        pipEditorExpanded: true
    )

    static func key(projectID: UUID?, sessionID: UUID?) -> String {
        let base = "sts.takereview.disclosurePrefs.v1"
        let projectPart = "project_\(sanitizeID(projectID?.uuidString ?? "unknown"))"
        if let sessionID {
            let sessionPart = "session_\(sanitizeID(sessionID.uuidString))"
            return "\(base).\(projectPart).\(sessionPart)"
        }
        return "\(base).\(projectPart)"
    }

    static func load(projectID: UUID?, sessionID: UUID?) -> TakeReviewDisclosurePrefs {
        let storageKey = key(projectID: projectID, sessionID: sessionID)
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let prefs = try? JSONDecoder().decode(TakeReviewDisclosurePrefs.self, from: data)
        else {
            return defaults
        }
        return prefs
    }

    static func save(
        _ prefs: TakeReviewDisclosurePrefs,
        projectID: UUID?,
        sessionID: UUID?
    ) {
        let storageKey = key(projectID: projectID, sessionID: sessionID)
        guard let data = try? JSONEncoder().encode(prefs) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    static func reset(projectID: UUID?, sessionID: UUID?) {
        let storageKey = key(projectID: projectID, sessionID: sessionID)
        UserDefaults.standard.removeObject(forKey: storageKey)
    }

#if DEBUG
    static func resetAll() {
        let prefix = "sts.takereview.disclosurePrefs.v1"
        let defaults = UserDefaults.standard
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix(prefix) {
            defaults.removeObject(forKey: key)
        }
    }
#endif

    private static func sanitizeID(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let scalars = value.unicodeScalars.map { scalar -> UnicodeScalar in
            allowed.contains(scalar) ? scalar : "_"
        }
        return String(String.UnicodeScalarView(scalars))
    }
}
