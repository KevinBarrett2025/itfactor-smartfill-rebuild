import Foundation

// MARK: - Actor Profile Models
struct ActorProfile: Codable {
    var id = UUID()
    
    // Basic Info
    var name: String = ""
    var email: String = ""
    var phone: String = ""
    var sagStatus: SAGStatus = .nonUnion
    var sagNumber: String = ""
    var ageRange: String = ""
    var sex: ActorSex = .undisclosed
    var primaryLocation: String = ""
    var localHireMarket: String = ""
    
    // Appearance/Stats
    var height: String = ""
    var weight: String = ""
    var hairColor: String = ""
    var eyeColor: String = ""
    var shirtSize: String = ""
    var pantSize: String = ""
    var shoeSize: String = ""
    var measurements: ActorMeasurements = .init()
    
    // Uploads (stored as file names/paths)
    var headshots: [HeadshotAsset] = []
    var sizeCards: [String] = []
    var resumes: [String] = []
    var sizeCardConfig: SizeCardConfig = .default
    var profileHeadshotTransform: HeadshotTransform = .identity
    
    // Social
    var socialLinks: SocialLinks = .init()
    
    // Slate learning
    var preferredSlatePhrasing: String? = nil
    var preferredSlateFields: [SlateField]? = nil
    
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    
    // Computed properties for display
    var displayName: String {
        name.isEmpty ? "Anonymous Actor" : name
    }
    
    var sagDisplayStatus: String {
        switch sagStatus {
        case .member:
            return sagNumber.isEmpty ? "SAG-AFTRA Member" : "SAG-AFTRA Member #\(sagNumber)"
        case .eligible:
            return "SAG-AFTRA Eligible"
        case .nonUnion:
            return "Non-Union"
        }
    }
    
    var preferredHeadshot: HeadshotAsset? {
        headshots.first(where: { $0.isProfilePhoto }) ?? headshots.first
    }

    mutating func ensurePreferredHeadshotFlag() {
        guard !headshots.isEmpty else { return }
        if !headshots.contains(where: { $0.isProfilePhoto }) {
            headshots = headshots.enumerated().map { index, asset in
                var copy = asset
                copy.isProfilePhoto = index == 0
                return copy
            }
        }
    }
    
    private enum CodingKeys: String, CodingKey {
        case id, name, email, phone, sagStatus, sagNumber, ageRange, sex, primaryLocation, localHireMarket, height, weight, hairColor, eyeColor, shirtSize, pantSize, shoeSize, measurements, headshots, sizeCards, resumes, sizeCardConfig, profileHeadshotTransform, socialLinks, preferredSlatePhrasing, preferredSlateFields, createdAt, updatedAt
    }
    
    init() {}
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        email = try container.decodeIfPresent(String.self, forKey: .email) ?? ""
        phone = try container.decodeIfPresent(String.self, forKey: .phone) ?? ""
        sagStatus = try container.decodeIfPresent(SAGStatus.self, forKey: .sagStatus) ?? .nonUnion
        sagNumber = try container.decodeIfPresent(String.self, forKey: .sagNumber) ?? ""
        ageRange = try container.decodeIfPresent(String.self, forKey: .ageRange) ?? ""
        sex = try container.decodeIfPresent(ActorSex.self, forKey: .sex) ?? .undisclosed
        primaryLocation = try container.decodeIfPresent(String.self, forKey: .primaryLocation) ?? ""
        localHireMarket = try container.decodeIfPresent(String.self, forKey: .localHireMarket) ?? ""
        height = try container.decodeIfPresent(String.self, forKey: .height) ?? ""
        weight = try container.decodeIfPresent(String.self, forKey: .weight) ?? ""
        hairColor = try container.decodeIfPresent(String.self, forKey: .hairColor) ?? ""
        eyeColor = try container.decodeIfPresent(String.self, forKey: .eyeColor) ?? ""
        shirtSize = try container.decodeIfPresent(String.self, forKey: .shirtSize) ?? ""
        pantSize = try container.decodeIfPresent(String.self, forKey: .pantSize) ?? ""
        shoeSize = try container.decodeIfPresent(String.self, forKey: .shoeSize) ?? ""
        measurements = try container.decodeIfPresent(ActorMeasurements.self, forKey: .measurements) ?? .init()
        sizeCards = try container.decodeIfPresent([String].self, forKey: .sizeCards) ?? []
        resumes = try container.decodeIfPresent([String].self, forKey: .resumes) ?? []
        socialLinks = try container.decodeIfPresent(SocialLinks.self, forKey: .socialLinks) ?? .init()
        preferredSlatePhrasing = try container.decodeIfPresent(String.self, forKey: .preferredSlatePhrasing)
        preferredSlateFields = try container.decodeIfPresent([SlateField].self, forKey: .preferredSlateFields)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
        sizeCardConfig = try container.decodeIfPresent(SizeCardConfig.self, forKey: .sizeCardConfig) ?? .default
        profileHeadshotTransform = try container.decodeIfPresent(HeadshotTransform.self, forKey: .profileHeadshotTransform) ?? .identity
        if let richHeadshots = try? container.decode([HeadshotAsset].self, forKey: .headshots) {
            headshots = richHeadshots
        } else if let legacyHeadshots = try? container.decode([String].self, forKey: .headshots) {
            headshots = legacyHeadshots.enumerated().map { index, file in
                HeadshotAsset(fileName: file, isProfilePhoto: index == 0)
            }
        } else {
            headshots = []
        }
        ensurePreferredHeadshotFlag()
    }
}

enum SAGStatus: String, CaseIterable, Codable {
    case member = "Member"
    case eligible = "Eligible"
    case nonUnion = "Non-Union"
    
    var displayName: String {
        return rawValue
    }
}

enum ActorSex: String, CaseIterable, Codable {
    case male = "Male"
    case female = "Female"
    case undisclosed = "Prefer not to say"
    
    var displayName: String { rawValue }
}

struct SocialLinks: Codable, Equatable {
    var instagram: String = ""
    var facebook: String = ""
    var tiktok: String = ""
    var imdb: String = ""
}

struct ActorMeasurements: Codable, Equatable {
    var waist: String = ""
    var inseam: String = ""
    var glove: String = ""
    var hat: String = ""
    
    var chest: String = ""
    var neck: String = ""
    var sleeve: String = ""
    var coat: String = ""
    var mensTShirt: String = ""
    var mensShoe: String = ""
    var mensShoeWidth: String = ""
    
    var dress: String = ""
    var bust: String = ""
    var underbust: String = ""
    var cup: String = ""
    var hip: String = ""
    var womensTShirt: String = ""
    var womensPants: String = ""
    var womensShoe: String = ""
    var womensShoeWidth: String = ""
    
    var boys: String = ""
    var girls: String = ""
    var toddlers: String = ""
    var infants: String = ""
    var kidsShoe: String = ""
    var kidsSpecial: String = ""
}

struct HeadshotAsset: Identifiable, Codable, Equatable {
    var id = UUID()
    var fileName: String
    var displayName: String?
    var tags: [String] = []
    var isProfilePhoto: Bool = false
    var createdAt: Date = Date()
    
    init(id: UUID = UUID(),
         fileName: String,
         displayName: String? = nil,
         tags: [String] = [],
         isProfilePhoto: Bool = false,
         createdAt: Date = Date()) {
        self.id = id
        self.fileName = fileName
        self.displayName = displayName
        self.tags = tags
        self.isProfilePhoto = isProfilePhoto
        self.createdAt = createdAt
    }
}

extension HeadshotAsset {
    var title: String {
        if let displayName = displayName, !displayName.isEmpty {
            return displayName
        }
        return URL(fileURLWithPath: fileName).deletingPathExtension().lastPathComponent
    }
}

extension ActorProfile {
    var isYouthTalent: Bool {
        let digits = ageRange
            .components(separatedBy: CharacterSet.decimalDigits.inverted)
            .compactMap { Int($0) }
        if let maxAge = digits.max(), maxAge > 0 {
            return maxAge < 18
        }
        let lower = ageRange.lowercased()
        return lower.contains("teen") || lower.contains("kid") || lower.contains("child") || lower.contains("youth")
    }
}

// MARK: - Actor Profile Manager
@Observable
class ActorProfileManager {
    private(set) var profile: ActorProfile = ActorProfile()
    private(set) var isProfileComplete: Bool = false
    
    private let userDefaults = UserDefaults.standard
    private let profileKey = "ActorProfile"
    private let completionKey = "ActorProfileComplete"
    
    init() {
        loadProfile()
    }
    
    func saveProfile(_ newProfile: ActorProfile) {
        var updatedProfile = newProfile
        updatedProfile.updatedAt = Date()
        updatedProfile.ensurePreferredHeadshotFlag()
        self.profile = updatedProfile
        
        if let encoded = try? JSONEncoder().encode(updatedProfile) {
            userDefaults.set(encoded, forKey: profileKey)
        }
        
        updateCompletionStatus()
        
        NotificationCenter.default.post(name: .actorProfileDidUpdate, object: updatedProfile)
    }
    
    func markProfileComplete() {
        isProfileComplete = true
        userDefaults.set(true, forKey: completionKey)
    }
    
    func resetProfile() {
        profile = ActorProfile()
        isProfileComplete = false
        userDefaults.removeObject(forKey: profileKey)
        userDefaults.removeObject(forKey: completionKey)
    }
    
    func updatePreferredSlateVoice(text: String?, fields: Set<SlateField>) {
        var updatedProfile = profile
        if let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty {
            updatedProfile.preferredSlatePhrasing = trimmed
            updatedProfile.preferredSlateFields = Array(fields)
        } else {
            updatedProfile.preferredSlatePhrasing = nil
            updatedProfile.preferredSlateFields = nil
        }
        saveProfile(updatedProfile)
    }
    
    func clearPreferredSlateVoice() {
        updatePreferredSlateVoice(text: nil, fields: [])
    }

    func updateSizeCardConfig(_ config: SizeCardConfig) {
        var updatedProfile = profile
        updatedProfile.sizeCardConfig = config
        saveProfile(updatedProfile)
    }

    func updateProfileHeadshotTransform(_ transform: HeadshotTransform) {
        var updatedProfile = profile
        var normalized = transform
        normalized.migrateLegacyOffsetsIfNeeded()
        updatedProfile.profileHeadshotTransform = normalized
        saveProfile(updatedProfile)
    }
    
    func addHeadshot(fileName: String, displayName: String? = nil, tags: [String] = []) {
        addHeadshotAssets([
            HeadshotAsset(fileName: fileName, displayName: displayName, tags: tags)
        ])
    }
    
    func addHeadshots(fileNames: [String]) {
        let assets = fileNames.map { HeadshotAsset(fileName: $0) }
        addHeadshotAssets(assets)
    }
    
    func addResume(named fileName: String) {
        addResumes([fileName])
    }
    
    func addResumes(_ fileNames: [String]) {
        var updatedProfile = profile
        for name in fileNames {
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            if !updatedProfile.resumes.contains(trimmed) {
                updatedProfile.resumes.append(trimmed)
            }
        }
        saveProfile(updatedProfile)
    }
    
    func removeResume(named fileName: String) {
        var updatedProfile = profile
        updatedProfile.resumes.removeAll { $0 == fileName }
        saveProfile(updatedProfile)
        
        let fm = FileManager.default
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first!
        let subfolder = docs.appendingPathComponent("ActorProfile", isDirectory: true)
        let candidates = [
            subfolder.appendingPathComponent(fileName),
            docs.appendingPathComponent(fileName)
        ]
        for url in candidates {
            try? fm.removeItem(at: url)
        }
    }

    func removeHeadshot(id: UUID) {
        var updatedProfile = profile
        guard let index = updatedProfile.headshots.firstIndex(where: { $0.id == id }) else { return }
        let removed = updatedProfile.headshots.remove(at: index)
        updatedProfile.ensurePreferredHeadshotFlag()
        saveProfile(updatedProfile)
        
        if let url = resolveHeadshotURL(named: removed.fileName) {
            try? FileManager.default.removeItem(at: url)
        }
    }
    
    func setPreferredHeadshot(named name: String) {
        var updatedProfile = profile
        updatedProfile.headshots = updatedProfile.headshots.map { asset in
            var copy = asset
            copy.isProfilePhoto = (asset.fileName == name)
            return copy
        }
        updatedProfile.ensurePreferredHeadshotFlag()
        saveProfile(updatedProfile)
    }
    
    func updateHeadshotDisplayName(id: UUID, newName: String) {
        var updatedProfile = profile
        guard let index = updatedProfile.headshots.firstIndex(where: { $0.id == id }) else { return }
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        updatedProfile.headshots[index].displayName = trimmed.isEmpty ? nil : trimmed
        saveProfile(updatedProfile)
    }
    
    private func loadProfile() {
        // Load completion status
        isProfileComplete = userDefaults.bool(forKey: completionKey)
        
        // Load profile data
        guard let data = userDefaults.data(forKey: profileKey),
              let decoded = try? JSONDecoder().decode(ActorProfile.self, from: data) else {
            return
        }
        
        var hydrated = decoded
        hydrated.ensurePreferredHeadshotFlag()
        hydrated.profileHeadshotTransform.migrateLegacyOffsetsIfNeeded()
        hydrated.sizeCardConfig.headshotTransform.migrateLegacyOffsetsIfNeeded()
        profile = hydrated
    }
    
    private func updateCompletionStatus() {
        let isComplete = !profile.name.isEmpty && !profile.email.isEmpty
        if isComplete != isProfileComplete {
            markProfileComplete()
        }
    }
    
    private func addHeadshotAssets(_ assets: [HeadshotAsset]) {
        guard !assets.isEmpty else { return }
        var updatedProfile = profile
        var copies = assets
        if updatedProfile.headshots.isEmpty {
            copies[0].isProfilePhoto = true
        }
        updatedProfile.headshots.append(contentsOf: copies)
        saveProfile(updatedProfile)
    }
}

extension Notification.Name {
    static let actorProfileDidUpdate = Notification.Name("ActorProfileDidUpdate")
}
