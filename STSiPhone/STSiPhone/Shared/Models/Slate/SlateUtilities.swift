import Foundation

extension String {
    var slateTrimmedNonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
    
    var slateEnsureSentence: String {
        guard let last = trimmingCharacters(in: .whitespacesAndNewlines).last else { return self }
        if [".", "!", "?"].contains(last) {
            return self
        }
        return self + "."
    }
    
    var slateNormalizedNotes: String {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        let normalized = trimmed.prefix(1).uppercased() + trimmed.dropFirst()
        return normalized.slateEnsureSentence
    }
    
    func slateTrimmed() -> String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    func slateSentenceCapped() -> String {
        let trimmed = slateTrimmed()
        guard !trimmed.isEmpty else { return trimmed }
        let first = trimmed.prefix(1).uppercased()
        let remainder = trimmed.dropFirst()
        let needsPeriod = ![".", "!", "?"].contains(trimmed.last ?? ".")
        return first + remainder + (needsPeriod ? "." : "")
    }
    
    func titleCasedLocation() -> String {
        let smallWords: Set<String> = ["of", "in", "and", "the", "for", "on", "at", "to", "a", "an"]
        let tokens = self.split(separator: " ")
        guard !tokens.isEmpty else { return self }
        return tokens.enumerated().map { idx, token in
            let word = String(token)
            let isAllCaps = word == word.uppercased() && word.count > 1
            if isAllCaps { return word }
            let lower = word.lowercased()
            if idx > 0, smallWords.contains(lower) { return lower }
            return lower.prefix(1).uppercased() + lower.dropFirst()
        }
        .joined(separator: " ")
    }
}
