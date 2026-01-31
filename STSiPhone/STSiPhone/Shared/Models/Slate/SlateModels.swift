import Foundation

public enum SlateField: String, Codable, CaseIterable, Sendable {
    case name
    case height
    case location
    case localHire
    case unionStatus
    case representation
    case contact
}

public enum SlateStyle: String, Codable, Sendable {
    case standard
}

public enum SlateFramingSelection: String, Codable, Sendable, CaseIterable {
    case closeUp
    case fullBody
    case both
}

public struct SlateSelections: Codable, Sendable, Equatable {
    public var include: Set<SlateField>
    public var localHireMarket: String?
    public var unionStatus: String?
    public var representation: String?
    public var contact: String?
    public var notes: String?
    public var framingSelection: SlateFramingSelection
    public var includePassport: Bool
    public var hasValidPassport: Bool?
    public var includeCitizenship: Bool
    public var isLegalCitizen: Bool?
    public var citizenshipCountry: String?
    
    public init(
        include: Set<SlateField> = [.name, .height, .location],
        localHireMarket: String? = nil,
        unionStatus: String? = nil,
        representation: String? = nil,
        contact: String? = nil,
        notes: String? = nil,
        framingSelection: SlateFramingSelection = .both,
        includePassport: Bool = false,
        hasValidPassport: Bool? = nil,
        includeCitizenship: Bool = false,
        isLegalCitizen: Bool? = nil,
        citizenshipCountry: String? = nil
    ) {
        self.include = include
        self.localHireMarket = localHireMarket
        self.unionStatus = unionStatus
        self.representation = representation
        self.contact = contact
        self.notes = notes
        self.framingSelection = framingSelection
        self.includePassport = includePassport
        self.hasValidPassport = hasValidPassport
        self.includeCitizenship = includeCitizenship
        self.isLegalCitizen = isLegalCitizen
        self.citizenshipCountry = citizenshipCountry
    }

    private enum CodingKeys: String, CodingKey {
        case include
        case localHireMarket
        case unionStatus
        case representation
        case contact
        case notes
        case framingSelection
        case includePassport
        case hasValidPassport
        case includeCitizenship
        case isLegalCitizen
        case citizenshipCountry
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        include = try container.decodeIfPresent(Set<SlateField>.self, forKey: .include)
            ?? [.name, .height, .location]
        localHireMarket = try container.decodeIfPresent(String.self, forKey: .localHireMarket)
        unionStatus = try container.decodeIfPresent(String.self, forKey: .unionStatus)
        representation = try container.decodeIfPresent(String.self, forKey: .representation)
        contact = try container.decodeIfPresent(String.self, forKey: .contact)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        framingSelection = try container.decodeIfPresent(SlateFramingSelection.self, forKey: .framingSelection)
            ?? .both
        includePassport = try container.decodeIfPresent(Bool.self, forKey: .includePassport) ?? false
        hasValidPassport = try container.decodeIfPresent(Bool.self, forKey: .hasValidPassport)
        includeCitizenship = try container.decodeIfPresent(Bool.self, forKey: .includeCitizenship) ?? false
        isLegalCitizen = try container.decodeIfPresent(Bool.self, forKey: .isLegalCitizen)
        citizenshipCountry = try container.decodeIfPresent(String.self, forKey: .citizenshipCountry)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(include, forKey: .include)
        try container.encodeIfPresent(localHireMarket, forKey: .localHireMarket)
        try container.encodeIfPresent(unionStatus, forKey: .unionStatus)
        try container.encodeIfPresent(representation, forKey: .representation)
        try container.encodeIfPresent(contact, forKey: .contact)
        try container.encodeIfPresent(notes, forKey: .notes)
        try container.encode(framingSelection, forKey: .framingSelection)
        try container.encode(includePassport, forKey: .includePassport)
        try container.encodeIfPresent(hasValidPassport, forKey: .hasValidPassport)
        try container.encode(includeCitizenship, forKey: .includeCitizenship)
        try container.encodeIfPresent(isLegalCitizen, forKey: .isLegalCitizen)
        try container.encodeIfPresent(citizenshipCountry, forKey: .citizenshipCountry)
    }
}

public struct SlateContext: Sendable, Equatable {
    public var actorName: String
    public var heightDisplay: String?
    public var baseLocation: String?
    public var defaultUnionStatus: String?
    public var defaultRepresentation: String?
    public var defaultContact: String?
    public var selections: SlateSelections
    
    public init(
        actorName: String,
        heightDisplay: String?,
        baseLocation: String?,
        defaultUnionStatus: String?,
        defaultRepresentation: String?,
        defaultContact: String?,
        selections: SlateSelections
    ) {
        self.actorName = actorName
        self.heightDisplay = heightDisplay
        self.baseLocation = baseLocation
        self.defaultUnionStatus = defaultUnionStatus
        self.defaultRepresentation = defaultRepresentation
        self.defaultContact = defaultContact
        self.selections = selections
    }
}

extension SlateContext {
    static func make(
        profile: ActorProfile,
        project: Project?,
        session: ProjectSession?,
        selections: SlateSelections,
        fallbackLocation: String? = nil
    ) -> SlateContext {
        var locationSources: [String?] = [session?.location?.label]
        if let projectLocations = project?.sessions.compactMap({ $0.location?.label }) {
            locationSources.append(contentsOf: projectLocations)
        }
        locationSources.append(fallbackLocation)
        
        let baseLocation = locationSources.compactMap { $0?.slateTrimmedNonEmpty }.first
        let contactPieces = [profile.email.slateTrimmedNonEmpty, profile.phone.slateTrimmedNonEmpty].compactMap { $0 }
        let defaultContact = contactPieces.isEmpty ? nil : contactPieces.joined(separator: " / ")
        let defaultRepresentation = project?.representation?.slateSummary
        
        return SlateContext(
            actorName: profile.displayName,
            heightDisplay: profile.height.slateTrimmedNonEmpty,
            baseLocation: baseLocation,
            defaultUnionStatus: profile.sagDisplayStatus.slateTrimmedNonEmpty,
            defaultRepresentation: defaultRepresentation,
            defaultContact: defaultContact,
            selections: selections
        )
    }
}

private extension Contact {
    var slateSummary: String? {
        var components: [String] = []
        components.append(name)
        if let email = email?.slateTrimmedNonEmpty {
            components.append(email)
        }
        if let phone = phone?.slateTrimmedNonEmpty {
            components.append(phone)
        }
        let joined = components.joined(separator: " • ")
        return joined.slateTrimmedNonEmpty
    }
}
