import Foundation

enum SlateComposer {
    static func build(_ context: SlateContext, style: SlateStyle = .standard) -> String {
        var parts: [String] = []
        
        if context.selections.include.contains(.name), !context.actorName.isEmpty {
            parts.append("\(greeting(for: style)) my name is \(context.actorName).")
        }
        
        if context.selections.include.contains(.height),
           let height = context.heightDisplay?.slateTrimmedNonEmpty {
            parts.append("I’m \(height).")
        }
        
        appendLocationAndLocalHire(context: context, style: style, parts: &parts)
        
        if context.selections.include.contains(.unionStatus) {
            if let unionText = (context.selections.unionStatus ?? context.defaultUnionStatus)?.slateTrimmedNonEmpty {
                parts.append(unionPhrase(for: unionText))
            }
        }
        
        if context.selections.include.contains(.representation) {
            if let rep = context.selections.representation ?? context.defaultRepresentation,
               let repText = rep.slateTrimmedNonEmpty {
                parts.append(representationPhrase(from: repText))
            }
        }
        
        if context.selections.include.contains(.contact) {
            if let contact = context.selections.contact ?? context.defaultContact,
               let contactText = contact.slateTrimmedNonEmpty {
                parts.append(contactPhrase(from: contactText))
            }
        }

        if context.selections.includePassport,
           context.selections.hasValidPassport == true {
            parts.append("I have a valid passport.")
        }

        if context.selections.includeCitizenship,
           context.selections.isLegalCitizen == true,
           let country = context.selections.citizenshipCountry?.slateTrimmedNonEmpty {
            parts.append("I am a legal citizen of \(country).")
        }
        
        if let notes = context.selections.notes?.slateTrimmedNonEmpty {
            parts.append(notes.slateEnsureSentence)
        }
        
        let resolved = collapseSpaces(parts.joined(separator: " "))
        if resolved.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Hi, I'm ready for my audition."
        }
        return resolved
    }
    
    private static func greeting(for style: SlateStyle) -> String {
        switch style {
        case .standard:
            return "Hi,"
        }
    }
    
    private static func appendLocationAndLocalHire(
        context: SlateContext,
        style: SlateStyle,
        parts: inout [String]
    ) {
        let includeLocation = context.selections.include.contains(.location)
        let includeLocal = context.selections.include.contains(.localHire)
        let baseLocation = context.baseLocation?.slateTrimmedNonEmpty?.titleCasedLocation()
        let localMarket = context.selections.localHireMarket?.slateTrimmedNonEmpty?.titleCasedLocation()
        
        switch (includeLocation, includeLocal, baseLocation, localMarket) {
        case (true, true, let loc?, let local?):
            let verb = style == .standard ? "I’m" : "I am"
            parts.append("I’m based in \(loc), but \(verb) available to work as a local hire in \(local).")
        case (true, _, let loc?, _):
            parts.append("I’m based in \(loc).")
        case (_, true, _, let local?):
            parts.append("I am available to work as a local hire in \(local).")
        default:
            break
        }
    }
    
    private static func unionPhrase(for text: String) -> String {
        let lower = text.lowercased()
        if lower.contains("non") && lower.contains("union") {
            return "I’m non-union."
        }
        if lower.contains("sag") {
            return "I’m SAG-AFTRA."
        }
        return text.slateSentenceCapped()
    }
    
    private static func representationPhrase(from raw: String) -> String {
        let (type, name) = parseRepTypeAndName(raw)
        if let name {
            if let type {
                let normalized = normalizedRepType(type)
                if normalized == "by" {
                    return "I’m currently represented by \(name)."
                } else if normalized == "by my manager" {
                    return "I’m currently represented by my manager \(name)."
                } else {
                    return "I’m currently represented \(normalized) by \(name)."
                }
            } else {
                return "I’m currently represented by \(name)."
            }
        }
        return raw.slateSentenceCapped()
    }
    
    private static func contactPhrase(from raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasAt = trimmed.contains("@")
        let digitCount = trimmed.filter(\.isNumber).count
        if hasAt && digitCount >= 7 {
            return "You can reach me at \(trimmed)."
        } else if hasAt {
            return "You can reach me at \(trimmed)."
        } else if digitCount >= 7 {
            return "You can reach me at \(trimmed)."
        }
        return "Contact: \(trimmed)."
    }
    
    private static func parseRepTypeAndName(_ raw: String) -> (type: String?, name: String?) {
        let colonSplit = raw.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: true)
        if colonSplit.count == 2 {
            let type = String(colonSplit[0]).slateTrimmedNonEmpty
            let remainder = String(colonSplit[1]).slateTrimmedNonEmpty ?? ""
            let name = remainder.split(separator: "—", maxSplits: 1, omittingEmptySubsequences: true)
                .first
                .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            return (type, name)
        }
        let dashSplit = raw.split(separator: "—", maxSplits: 1, omittingEmptySubsequences: true)
        if dashSplit.count == 2 {
            let type = String(dashSplit[0]).slateTrimmedNonEmpty
            let name = String(dashSplit[1]).slateTrimmedNonEmpty
            return (type, name)
        }
        return (nil, raw.slateTrimmedNonEmpty)
    }
    
    private static func normalizedRepType(_ raw: String) -> String {
        let lower = raw.lowercased()
        if lower.contains("theatrical") {
            return "theatrically"
        }
        if lower.contains("commercial") {
            return "commercially"
        }
        if lower.contains("voice") || lower.contains("vo") {
            return "for voiceover"
        }
        if lower.contains("print") {
            return "for print"
        }
        if lower.contains("manager") {
            return "by my manager"
        }
        return "by"
    }
    
    private static func collapseSpaces(_ text: String) -> String {
        text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }
}
