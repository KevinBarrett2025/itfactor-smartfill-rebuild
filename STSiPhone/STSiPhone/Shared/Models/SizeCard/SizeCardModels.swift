import SwiftUI

// MARK: - Size Card Custom Fields
struct SizeCardCustomField: Identifiable, Codable, Hashable {
    var id: UUID = .init()
    var label: String
    var value: String
    var isVisible: Bool = true
    var order: Int = 0
}

// MARK: - Visibility Configuration
struct SizeCardVisibility: Codable, Hashable {
    var showUnion: Bool = true
    var showPrimaryLocation: Bool = true
    var showLocalHire: Bool = false
    var showContact: Bool = false // legacy flag
    var showEmail: Bool = true
    var showPhone: Bool = true
    var showWardrobe: Bool = true
    var showReps: Bool = true
    var showLinks: Bool = true
    var showInstagram: Bool = true
    var showFacebook: Bool = true
    var showTiktok: Bool = true
    var showImdb: Bool = true
    var showWatermarkQR: Bool = false

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        showUnion = try container.decodeIfPresent(Bool.self, forKey: .showUnion) ?? true
        showPrimaryLocation = try container.decodeIfPresent(Bool.self, forKey: .showPrimaryLocation) ?? true
        showLocalHire = try container.decodeIfPresent(Bool.self, forKey: .showLocalHire) ?? false
        let legacyContact = try container.decodeIfPresent(Bool.self, forKey: .showContact)
        showContact = legacyContact ?? false
        showEmail = try container.decodeIfPresent(Bool.self, forKey: .showEmail) ?? (legacyContact ?? true)
        showPhone = try container.decodeIfPresent(Bool.self, forKey: .showPhone) ?? (legacyContact ?? true)
        showWardrobe = try container.decodeIfPresent(Bool.self, forKey: .showWardrobe) ?? true
        showReps = try container.decodeIfPresent(Bool.self, forKey: .showReps) ?? true
        showLinks = try container.decodeIfPresent(Bool.self, forKey: .showLinks) ?? true
        showInstagram = try container.decodeIfPresent(Bool.self, forKey: .showInstagram) ?? true
        showFacebook = try container.decodeIfPresent(Bool.self, forKey: .showFacebook) ?? true
        showTiktok = try container.decodeIfPresent(Bool.self, forKey: .showTiktok) ?? true
        showImdb = try container.decodeIfPresent(Bool.self, forKey: .showImdb) ?? true
        showWatermarkQR = try container.decodeIfPresent(Bool.self, forKey: .showWatermarkQR) ?? (try container.decodeIfPresent(Bool.self, forKey: .showWatermark) ?? false || (try container.decodeIfPresent(Bool.self, forKey: .showQR) ?? false))
    }

    private enum CodingKeys: String, CodingKey {
        case showUnion, showPrimaryLocation, showLocalHire, showContact, showEmail, showPhone, showWardrobe, showReps, showLinks, showInstagram, showFacebook, showTiktok, showImdb, showWatermarkQR, showWatermark, showQR
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(showUnion, forKey: .showUnion)
        try container.encode(showPrimaryLocation, forKey: .showPrimaryLocation)
        try container.encode(showLocalHire, forKey: .showLocalHire)
        try container.encode(showContact, forKey: .showContact)
        try container.encode(showEmail, forKey: .showEmail)
        try container.encode(showPhone, forKey: .showPhone)
        try container.encode(showWardrobe, forKey: .showWardrobe)
        try container.encode(showReps, forKey: .showReps)
        try container.encode(showLinks, forKey: .showLinks)
        try container.encode(showInstagram, forKey: .showInstagram)
        try container.encode(showFacebook, forKey: .showFacebook)
        try container.encode(showTiktok, forKey: .showTiktok)
        try container.encode(showImdb, forKey: .showImdb)
        try container.encode(showWatermarkQR, forKey: .showWatermarkQR)
    }
}

// MARK: - Aspect Ratios
enum SizeCardAspect: String, Codable, CaseIterable {
    case usLetter = "US Letter (2550×3300 px)"
    case a4       = "A4 (2480×3508 px)"
    case social   = "Social 1080×1350"
    case half     = "Half Letter Landscape (8.5 × 5.5)"

    var canvasSize: CGSize {
        switch self {
        case .usLetter: return .init(width: 850, height: 1100)
        case .a4:       return .init(width: 842, height: 1191)
        case .social:   return .init(width: 1080, height: 1350)
        case .half:     return .init(width: 612, height: 396) // 8.5" x 5.5"
        }
    }
}

// MARK: - Theme Tokens
struct SizeCardTheme: Codable, Hashable {
    var primaryHex: String = "#101010"
    var accentHex: String  = "#C084FC"
    var textHex: String    = "#101010"
    var backgroundHex: String = "#FFFFFF"
    var cornerRadius: CGFloat = 20
    var dividerOpacity: Double = 0.15
    var fontScale: Double = 1.0
    var includeShadow: Bool = true
    var includeHeadshotBorder: Bool = false
}

// MARK: - Template Reference
struct SizeCardTemplateRef: Codable, Hashable {
    var templateID: String = SizeCardTemplate.compact.rawValue
    var aspect: SizeCardAspect = .half
    var theme: SizeCardTheme = .init()
}

enum SizeCardMeasurementField: String, Codable, CaseIterable, Hashable {
    case height, weight
    case waist, inseam, glove, hat
    case shirt, pant, shoe
    case chest, neck, sleeve, coat
    case mensTShirt, mensShoe, mensShoeWidth
    case dress, bust, underbust, cup, hip
    case womensTShirt, womensPants, womensShoe, womensShoeWidth
    case boys, girls, toddlers, infants, kidsShoe, kidsSpecial

    var displayLabel: String {
        switch self {
        case .height: return "Height"
        case .weight: return "Weight"
        case .waist: return "Waist"
        case .inseam: return "Inseam"
        case .glove: return "Glove"
        case .hat: return "Hat"
        case .shirt: return "Top"
        case .pant: return "Bottom"
        case .shoe: return "Shoes"
        case .chest: return "Chest"
        case .neck: return "Neck"
        case .sleeve: return "Sleeve"
        case .coat: return "Coat"
        case .mensTShirt: return "Men's T-Shirt"
        case .mensShoe: return "Men's Shoes"
        case .mensShoeWidth: return "Men's Shoe Width"
        case .dress: return "Dress"
        case .bust: return "Bust"
        case .underbust: return "Underbust"
        case .cup: return "Cup"
        case .hip: return "Hip"
        case .womensTShirt: return "Women's T-Shirt"
        case .womensPants: return "Women's Pants"
        case .womensShoe: return "Women's Shoes"
        case .womensShoeWidth: return "Women's Shoe Width"
        case .boys: return "Boys"
        case .girls: return "Girls"
        case .toddlers: return "Toddlers"
        case .infants: return "Infants"
        case .kidsShoe: return "Kids Shoes"
        case .kidsSpecial: return "Special Sizing"
        }
    }
}

enum SizeCardColumnStyle: String, Codable, CaseIterable {
    case auto
    case single
    case dual

    var displayName: String {
        switch self {
        case .auto: return "Auto"
        case .single: return "Single"
        case .dual: return "Dual"
        }
    }
}

struct HeadshotTransform: Codable, Hashable {
    var scale: CGFloat = 1.0
    /// Normalized horizontal offset (relative to view width)
    var offsetX: CGFloat = 0
    /// Normalized vertical offset (relative to view height)
    var offsetY: CGFloat = 0
    
    static let identity = HeadshotTransform()
    private static let migrationThreshold: CGFloat = 2.0
    private static let legacyReference: CGFloat = 320.0
    private static let offsetLimit: CGFloat = 1.2
    
    mutating func migrateLegacyOffsetsIfNeeded() {
        if abs(offsetX) > Self.migrationThreshold || abs(offsetY) > Self.migrationThreshold {
            offsetX /= Self.legacyReference
            offsetY /= Self.legacyReference
        }
        clampOffsets()
    }
    
    mutating func clampOffsets() {
        offsetX = min(max(offsetX, -Self.offsetLimit), Self.offsetLimit)
        offsetY = min(max(offsetY, -Self.offsetLimit), Self.offsetLimit)
    }
    
    func offset(width: CGFloat, height: CGFloat) -> CGSize {
        CGSize(width: offsetX * width, height: offsetY * height)
    }
}

struct LayoutOffset: Codable, Hashable {
    var x: Double = 0
    var y: Double = 0
    
    static let zero = LayoutOffset()
    
    var cgSize: CGSize {
        CGSize(width: x, height: y)
    }
}

// MARK: - Config Root
struct SizeCardConfig: Codable, Hashable {
    var visibility: SizeCardVisibility = .init()
    var template: SizeCardTemplateRef = .init()
    var customFields: [SizeCardCustomField] = []
    var preferredHeadshotFileName: String? = nil
    var headshotTransform: HeadshotTransform = .identity
    var localHireOverride: String = ""
    var columnStyle: SizeCardColumnStyle = .auto
    var hiddenRepIDs: Set<UUID> = []
    var labelFontScale: CGFloat = 1.0
    var valueFontScale: CGFloat = 1.0
    var spacingScale: CGFloat = 1.0
    var hiddenMeasurementFields: Set<SizeCardMeasurementField> = []
    var lookDetailsOffset: LayoutOffset = .zero
    var detailColumnOffset: LayoutOffset = .zero
    var repBoxOffset: LayoutOffset = .zero

    static var `default`: SizeCardConfig { SizeCardConfig() }
}

extension SizeCardMeasurementField {
    func value(from profile: ActorProfile) -> String {
        let measurements = profile.measurements
        switch self {
        case .height: return profile.height
        case .weight: return profile.weight
        case .waist: return measurements.waist
        case .inseam: return measurements.inseam
        case .glove: return measurements.glove
        case .hat: return measurements.hat
        case .shirt: return profile.shirtSize
        case .pant: return profile.pantSize
        case .shoe: return profile.shoeSize
        case .chest: return measurements.chest
        case .neck: return measurements.neck
        case .sleeve: return measurements.sleeve
        case .coat: return measurements.coat
        case .mensTShirt: return measurements.mensTShirt
        case .mensShoe: return measurements.mensShoe
        case .mensShoeWidth: return measurements.mensShoeWidth
        case .dress: return measurements.dress
        case .bust: return measurements.bust
        case .underbust: return measurements.underbust
        case .cup: return measurements.cup
        case .hip: return measurements.hip
        case .womensTShirt: return measurements.womensTShirt
        case .womensPants: return measurements.womensPants
        case .womensShoe: return measurements.womensShoe
        case .womensShoeWidth: return measurements.womensShoeWidth
        case .boys: return measurements.boys
        case .girls: return measurements.girls
        case .toddlers: return measurements.toddlers
        case .infants: return measurements.infants
        case .kidsShoe: return measurements.kidsShoe
        case .kidsSpecial: return measurements.kidsSpecial
        }
    }
}
