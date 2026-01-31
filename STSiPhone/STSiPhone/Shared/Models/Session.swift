import Foundation
import SwiftUI

struct Session: Identifiable, Codable {
    var id: UUID
    var projectName: String
    var role: String
    var talentName: String
    var createdAt: Date
    var segments: [Segment] // New
    var exportPreference: ExportPreference // New
    
    init(id: UUID = UUID(), projectName: String, role: String, talentName: String, createdAt: Date = Date(), segments: [Segment] = [], exportPreference: ExportPreference = .mergedWithChapters) {
        self.id = id
        self.projectName = projectName
        self.role = role
        self.talentName = talentName
        self.createdAt = createdAt
        self.segments = segments
        self.exportPreference = exportPreference
    }
}

struct Segment: Identifiable, Codable {
    var id: UUID
    var name: String
    var takes: [Take] = []
    
    init(id: UUID = UUID(), name: String, takes: [Take] = []) {
        self.id = id
        self.name = name
        self.takes = takes
    }
}

struct Take: Identifiable, Codable {
    var id: UUID
    var segmentId: UUID
    var fileName: String
    var filePath: String // Add missing filePath property
    var duration: TimeInterval
    var takeNumber: Int
    var sceneNumber: Int // Add scene number for compatibility
    var rating: TakeRating
    var createdAt: Date
    
    // Computed properties for compatibility
    var isGood: Bool {
        rating == .finalSelect
    }
    
    var isStarred: Bool {
        rating == .option
    }
    
    init(id: UUID = UUID(), segmentId: UUID, fileName: String, filePath: String? = nil, duration: TimeInterval = 0, takeNumber: Int = 1, sceneNumber: Int = 1, rating: TakeRating = .unrated, createdAt: Date = Date()) {
        self.id = id
        self.segmentId = segmentId
        self.fileName = fileName
        self.filePath = filePath ?? fileName // Use fileName as fallback for filePath
        self.duration = duration
        self.takeNumber = takeNumber
        self.sceneNumber = sceneNumber
        self.rating = rating
        self.createdAt = createdAt
    }
}

enum ExportPreference: String, Codable, CaseIterable {
    case mergedWithChapters
    case separateFiles
    
    var displayName: String {
        switch self {
        case .mergedWithChapters:
            return "One File (with Skip Markers)"
        case .separateFiles:
            return "Separate Files by Segment"
        }
    }
    
    var icon: String {
        switch self {
        case .mergedWithChapters:
            return "🎬"
        case .separateFiles:
            return "📂"
        }
    }
}

public enum TakeRating: String, Codable, CaseIterable, Sendable {
    case finalSelect = "good"
    case option = "favorite"
    case unrated = "unrated"
    case rejected = "bad"
    
    public var icon: String {
        switch self {
        case .unrated:
            return "⚪"
        case .finalSelect:
            return "⭐"
        case .option:
            return "✅"
        case .rejected:
            return "❌"
        }
    }
    
    // ENHANCED: Professional rating system with full interface support
    public var displayName: String {
        switch self {
        case .unrated:
            return "Unrated"
        case .finalSelect:
            return "Final"
        case .option:
            return "Selects"
        case .rejected:
            return "Pass"
        }
    }
    
    public var color: Color {
        switch self {
        case .unrated:
            return .gray
        case .finalSelect:
            return .yellow
        case .option:
            return .green
        case .rejected:
            return .red
        }
    }
    
    public var iconName: String {
        switch self {
        case .unrated:
            return "circle"
        case .finalSelect:
            return "star.circle"
        case .option:
            return "checkmark.circle"
        case .rejected:
            return "x.circle"
        }
    }
}
