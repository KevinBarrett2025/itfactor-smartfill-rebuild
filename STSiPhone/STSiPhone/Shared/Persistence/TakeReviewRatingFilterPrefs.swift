import Foundation

struct TakeReviewRatingFilterPrefs: Codable, Equatable {
    let ratingFilters: [String]

    static let defaults = TakeReviewRatingFilterPrefs(ratingFilters: [])

    static func key(projectID: UUID?, sessionID: UUID?) -> String {
        let base = "sts.takereview.ratingFilters.v1"
        let projectPart = "project_\(sanitizeID(projectID?.uuidString ?? "unknown"))"
        if let sessionID {
            let sessionPart = "session_\(sanitizeID(sessionID.uuidString))"
            return "\(base).\(projectPart).\(sessionPart)"
        }
        return "\(base).\(projectPart)"
    }

    static func load(projectID: UUID?, sessionID: UUID?) -> TakeReviewRatingFilterPrefs {
        let storageKey = key(projectID: projectID, sessionID: sessionID)
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let prefs = try? JSONDecoder().decode(TakeReviewRatingFilterPrefs.self, from: data)
        else {
            return defaults
        }
        return prefs
    }

    static func save(
        _ prefs: TakeReviewRatingFilterPrefs,
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

    private static func sanitizeID(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let scalars = value.unicodeScalars.map { scalar -> UnicodeScalar in
            allowed.contains(scalar) ? scalar : "_"
        }
        return String(String.UnicodeScalarView(scalars))
    }
}
