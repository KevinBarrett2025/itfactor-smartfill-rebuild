import Foundation

// MARK: - EffectiveSessionContext
/// Single source of truth for session + project “effective” values.
/// - Rule: Session overrides win; otherwise inherit from Project; otherwise default.
/// - No UI, no persistence — pure resolution logic.
public struct EffectiveSessionContext: Sendable {
    public let project: Project
    public let session: any SessionContextSource
    public let effective: EffectiveValues

    public init(project: Project, session: any SessionContextSource) {
        self.project = project
        self.session = session
        self.effective = EffectiveValues(project: project, session: session)
    }
}

// MARK: - Value Origin Metadata
public enum ValueOrigin: String, Codable, Sendable {
    case sessionOverride
    case sessionValue
    case projectValue
    case defaultValue
}

public struct Resolved<Value>: Sendable where Value: Sendable {
    public let value: Value
    public let origin: ValueOrigin

    public init(_ value: Value, origin: ValueOrigin) {
        self.value = value
        self.origin = origin
    }
}

// MARK: - SessionContextSource
/// Abstraction allowing this resolver to work with:
/// - Persisted ProjectSession
/// - Draft wizard session models (future)
public protocol SessionContextSource: Sendable {
    var id: UUID { get }
    var type: SessionType { get }
    var date: Date { get }

    // Existing session fields
    var location: LocationInfo? { get }
    var contact: Contact? { get }
    var notes: String? { get }

    var roleName: String? { get }
    var sidesFileName: String? { get }
    var breakdownFileName: String? { get }
    var breakdownNotes: String? { get }
    var slatePrompt: String? { get }

    // Future override hooks (safe stubs for now)
    var auditionDueDateOverride: Date? { get }
    var sceneCountOverride: Int? { get }
    var submittedHeadshotIDOverride: UUID? { get }
    var slateSelectionsOverride: SlateSelections? { get }
}


// MARK: - EffectiveValues
public struct EffectiveValues: Sendable {
    public let auditionDueDate: Resolved<Date?>
    public let sidesFileName: Resolved<String?>
    public let breakdownFileName: Resolved<String?>
    public let breakdownNotes: Resolved<String?>

    public let roleName: Resolved<String?>
    public let submittedHeadshotID: Resolved<UUID?>
    public let sceneCount: Resolved<Int>
    public let slateSelections: Resolved<SlateSelections>
    public let slatePrompt: Resolved<String?>

    public let sessionDate: Date
    public let sessionType: SessionType
    public let location: LocationInfo?
    public let contact: Contact?
    public let notes: String?

    public let displayTitle: String

    public init(project: Project, session: any SessionContextSource) {
        self.sessionType = session.type
        self.sessionDate = session.date
        self.location = session.location
        self.contact = session.contact
        self.notes = session.notes

        // Due date
        if let override = session.auditionDueDateOverride {
            self.auditionDueDate = Resolved(override, origin: .sessionOverride)
        } else if let projectDate = project.auditionDueDate {
            self.auditionDueDate = Resolved(projectDate, origin: .projectValue)
        } else {
            self.auditionDueDate = Resolved(nil, origin: .defaultValue)
        }

        // Sides
        if let s = session.sidesFileName, !s.isEmpty {
            self.sidesFileName = Resolved(s, origin: .sessionValue)
        } else if let p = project.sidesFileName, !p.isEmpty {
            self.sidesFileName = Resolved(p, origin: .projectValue)
        } else {
            self.sidesFileName = Resolved(nil, origin: .defaultValue)
        }

        // Breakdown
        if let s = session.breakdownFileName, !s.isEmpty {
            self.breakdownFileName = Resolved(s, origin: .sessionValue)
        } else if let p = project.breakdownFileName, !p.isEmpty {
            self.breakdownFileName = Resolved(p, origin: .projectValue)
        } else {
            self.breakdownFileName = Resolved(nil, origin: .defaultValue)
        }

        if let s = session.breakdownNotes, !s.isEmpty {
            self.breakdownNotes = Resolved(s, origin: .sessionValue)
        } else if let p = project.breakdownNotes, !p.isEmpty {
            self.breakdownNotes = Resolved(p, origin: .projectValue)
        } else {
            self.breakdownNotes = Resolved(nil, origin: .defaultValue)
        }

        // Role
        if let r = session.roleName, !r.isEmpty {
            self.roleName = Resolved(r, origin: .sessionValue)
        } else if let pr = project.roles.first?.name, !pr.isEmpty {
            self.roleName = Resolved(pr, origin: .projectValue)
        } else {
            self.roleName = Resolved(nil, origin: .defaultValue)
        }

        // Headshot
        if let override = session.submittedHeadshotIDOverride {
            self.submittedHeadshotID = Resolved(override, origin: .sessionOverride)
        } else if let p = project.submittedHeadshotID {
            self.submittedHeadshotID = Resolved(p, origin: .projectValue)
        } else {
            self.submittedHeadshotID = Resolved(nil, origin: .defaultValue)
        }

        // Scene count
        if let override = session.sceneCountOverride {
            self.sceneCount = Resolved(override, origin: .sessionOverride)
        } else {
            self.sceneCount = Resolved(project.sceneCount, origin: .projectValue)
        }

        // Slate selections
        if let override = session.slateSelectionsOverride {
            self.slateSelections = Resolved(override, origin: .sessionOverride)
        } else {
            self.slateSelections = Resolved(project.slateSelections, origin: .projectValue)
        }

        // Slate prompt
        if let s = session.slatePrompt, !s.isEmpty {
            self.slatePrompt = Resolved(s, origin: .sessionValue)
        } else {
            self.slatePrompt = Resolved(nil, origin: .defaultValue)
        }

        self.displayTitle = [project.title, session.type.rawValue, roleName.value]
            .compactMap { $0 }
            .joined(separator: " • ")
    }
}

// MARK: - Debug / Review Helpers
extension EffectiveSessionContext {
    public func originSummary() -> [String: ValueOrigin] {
        [
            "Due Date": effective.auditionDueDate.origin,
            "Sides": effective.sidesFileName.origin,
            "Breakdown": effective.breakdownFileName.origin,
            "Breakdown Notes": effective.breakdownNotes.origin,
            "Role": effective.roleName.origin,
            "Headshot": effective.submittedHeadshotID.origin,
            "Scene Count": effective.sceneCount.origin,
            "Slate Selections": effective.slateSelections.origin,
            "Slate Prompt": effective.slatePrompt.origin
        ]
    }
}
