import Foundation

struct Talent: Identifiable, Codable {
    let id: UUID
    var name: String
    var headshot: String?   // Reference to image asset (optional)

    init(id: UUID = UUID(), name: String, headshot: String? = nil) {
        self.id = id
        self.name = name
        self.headshot = headshot
    }
}