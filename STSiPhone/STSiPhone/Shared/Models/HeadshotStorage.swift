import Foundation

func resolveHeadshotURL(named name: String?) -> URL? {
    guard var raw = name?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
        return nil
    }
    let fm = FileManager.default
    var candidates: [URL] = []
    
    raw = (raw as NSString).expandingTildeInPath
    
    func appendCandidate(_ url: URL) {
        let normalized = url.standardizedFileURL
        guard !normalized.path.isEmpty else { return }
        candidates.append(normalized)
    }
    
    if raw.hasPrefix("file://"), let url = URL(string: raw) {
        appendCandidate(url)
    }
    
    if raw.hasPrefix("/") {
        appendCandidate(URL(fileURLWithPath: raw))
    }
    
    if let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first {
        let sanitized = raw.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        appendCandidate(docs.appendingPathComponent(sanitized))
        
        if !sanitized.hasPrefix("ActorProfile/") {
            appendCandidate(docs.appendingPathComponent("ActorProfile").appendingPathComponent(sanitized))
        }
        
        if let documentsRange = sanitized.range(of: "Documents/") {
            let relativePath = String(sanitized[documentsRange.upperBound...])
            appendCandidate(docs.appendingPathComponent(relativePath))
        }
    }
    
    var inspected = Set<String>()
    for url in candidates {
        let path = url.path
        if inspected.insert(path).inserted, fm.fileExists(atPath: path) {
            return url
        }
    }
    return nil
}
