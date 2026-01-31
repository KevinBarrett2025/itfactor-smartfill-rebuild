import Foundation
import PDFKit

public struct BreakdownFields {
    public var projectTitle: String?
    public var roleName: String?
    public var castingOffice: String?
    public var castingDirector: String?
    public var contactEmail: String?
    public var contactPhone: String?
    public var locationLabel: String?
    public var locationAddress: String?
    
    public init(projectTitle: String? = nil, roleName: String? = nil, castingOffice: String? = nil, castingDirector: String? = nil, contactEmail: String? = nil, contactPhone: String? = nil, locationLabel: String? = nil, locationAddress: String? = nil) {
        self.projectTitle = projectTitle
        self.roleName = roleName
        self.castingOffice = castingOffice
        self.castingDirector = castingDirector
        self.contactEmail = contactEmail
        self.contactPhone = contactPhone
        self.locationLabel = locationLabel
        self.locationAddress = locationAddress
    }
}

public enum BreakdownParser {
    
    // MARK: - Entry point
    public static func parse(from url: URL) -> BreakdownFields {
        print("🔍 BreakdownParser: Attempting to parse file at \(url)")
        
        let ext = url.pathExtension.lowercased()
        var rawText: String?
        
        // Start accessing security-scoped resource
        let accessing = url.startAccessingSecurityScopedResource()
        defer {
            if accessing {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        if ext == "pdf" {
            print("🔍 BreakdownParser: Processing PDF file")
            if let doc = PDFDocument(url: url) {
                rawText = doc.string
                print("🔍 BreakdownParser: Extracted \(rawText?.count ?? 0) characters from PDF")
            } else {
                print("❌ BreakdownParser: Failed to create PDFDocument")
            }
        } else if ext == "txt" {
            print("🔍 BreakdownParser: Processing TXT file")
            do {
                rawText = try String(contentsOf: url, encoding: .utf8)
                print("🔍 BreakdownParser: Extracted \(rawText?.count ?? 0) characters from TXT")
            } catch {
                print("❌ BreakdownParser: Failed to read TXT file: \(error)")
            }
        } else {
            print("❌ BreakdownParser: Unsupported file extension: \(ext)")
        }
        
        guard let text = rawText, !text.isEmpty else {
            print("⚠️ BreakdownParser: No text extracted, returning empty fields")
            // Future: run OCR fallback here
            return BreakdownFields()
        }
        
        print("🔍 BreakdownParser: Beginning field extraction from text")
        return extractFields(from: text)
    }
    
    // MARK: - Field extraction
    private static func extractFields(from text: String) -> BreakdownFields {
        var fields = BreakdownFields()
        
        func match(_ pattern: String, description: String) -> String? {
            do {
                let regex = try NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .anchorsMatchLines])
                let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
                
                for match in matches {
                    if match.numberOfRanges >= 2, let range = Range(match.range(at: 1), in: text) {
                        let result = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
                        if !result.isEmpty {
                            print("✅ BreakdownParser: Found \(description): '\(result)'")
                            return result
                        }
                    }
                }
            } catch {
                print("❌ BreakdownParser: Regex error for \(description): \(error)")
            }
            return nil
        }
        
        // Enhanced patterns for better matching
        
        // Project title - try multiple patterns
        fields.projectTitle = match(#"(?i)(?:project|title|show)\s*:?\s*(.+?)(?:\n|\r|$)"#, description: "Project Title")
        ?? match(#"(?i)^(.+?)(?:\s*-\s*(?:casting|audition))"#, description: "Project Title (Alt)")
        
        // Role name - try multiple patterns
        fields.roleName = match(#"(?i)(?:role|character|part)\s*:?\s*(.+?)(?:\n|\r|$)"#, description: "Role Name")
        ?? match(#"(?i)seeking\s+(.+?)(?:\n|\r|for|$)"#, description: "Role Name (Alt)")
        
        // Casting office
        fields.castingOffice = match(#"(?i)(?:casting\s+office|casting)\s*:?\s*(.+?)(?:\n|\r|$)"#, description: "Casting Office")
        
        // Casting director
        fields.castingDirector = match(#"(?i)(?:casting\s+director|director)\s*:?\s*(.+?)(?:\n|\r|$)"#, description: "Casting Director")
        ?? match(#"(?i)(?:cd|c\.d\.)\s*:?\s*(.+?)(?:\n|\r|$)"#, description: "Casting Director (Alt)")
        
        // Email - improved pattern
        let emailPattern = #"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}"#
        if let emailMatch = try? NSRegularExpression(pattern: emailPattern).firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let range = Range(emailMatch.range, in: text) {
            fields.contactEmail = String(text[range])
            print("✅ BreakdownParser: Found Email: '\(fields.contactEmail!)'")
        }
        
        // Phone - improved pattern for various formats
        let phonePattern = #"\(?\d{3}\)?[-.\s]?\d{3}[-.\s]?\d{4}"#
        if let phoneMatch = try? NSRegularExpression(pattern: phonePattern).firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let range = Range(phoneMatch.range, in: text) {
            fields.contactPhone = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
            print("✅ BreakdownParser: Found Phone: '\(fields.contactPhone!)'")
        }
        
        // Location
        fields.locationLabel = match(#"(?i)(?:location|address|venue|studio)\s*:?\s*(.+?)(?:\n|\r|$)"#, description: "Location")
        
        // Address - look for typical address patterns
        fields.locationAddress = match(#"(?i)\d+\s+[\w\s]+(?:street|st|avenue|ave|blvd|boulevard|road|rd|drive|dr|lane|ln|way)(?:\s*,?\s*[\w\s]+)?"#, description: "Address")
        
        print("🔍 BreakdownParser: Field extraction complete")
        return fields
    }
    
    // MARK: - Future OCR Integration Point
    private static func parseWithOCR(from url: URL) -> BreakdownFields {
        // TODO: Implement VisionKit OCR for scanned PDFs
        // This will be called when PDFDocument.string is nil/empty
        print("🔮 BreakdownParser: OCR parsing not yet implemented")
        return BreakdownFields()
    }
}
