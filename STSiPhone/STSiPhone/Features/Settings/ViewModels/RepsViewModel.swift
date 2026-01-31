import Foundation
import Observation

public struct RepInfo: Identifiable, Codable, Equatable {
    public var id = UUID()
    public var category: String
    public var name: String
    public var email: String?
    public var phone: String?
    public var companyName: String?
    public var companyAddress: String?
    
    public init(
        id: UUID = UUID(),
        category: String,
        name: String,
        email: String? = nil,
        phone: String? = nil,
        companyName: String? = nil,
        companyAddress: String? = nil
    ) {
        self.id = id
        self.category = category
        self.name = name
        self.email = email
        self.phone = phone
        self.companyName = companyName
        self.companyAddress = companyAddress
    }
}

@Observable
public final class RepsViewModel {
    public var reps: [RepInfo] = []
    
    public init() {
        loadReps()
    }
    
    public func addRep(
        category: String,
        name: String,
        email: String? = nil,
        phone: String? = nil,
        companyName: String? = nil,
        companyAddress: String? = nil
    ) {
        // Remove existing rep in same category
        reps.removeAll { $0.category == category }
        
        // Add new rep if name is not empty
        if !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            reps.append(RepInfo(
                category: category,
                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                email: email?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true ? nil : email?.trimmingCharacters(in: .whitespacesAndNewlines),
                phone: phone?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true ? nil : phone?.trimmingCharacters(in: .whitespacesAndNewlines),
                companyName: companyName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true ? nil : companyName?.trimmingCharacters(in: .whitespacesAndNewlines),
                companyAddress: companyAddress?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true ? nil : companyAddress?.trimmingCharacters(in: .whitespacesAndNewlines)
            ))
        }
        
        saveReps()
    }
    
    public func updateRep(_ rep: RepInfo) {
        if let index = reps.firstIndex(where: { $0.id == rep.id }) {
            reps[index] = rep
            saveReps()
        }
    }
    
    public func deleteRep(_ rep: RepInfo) {
        reps.removeAll { $0.id == rep.id }
        saveReps()
    }
    
    public func getRep(for category: String) -> RepInfo? {
        return reps.first { $0.category == category }
    }
    
    // MARK: - Persistence (Simple UserDefaults for now)
    private func saveReps() {
        if let data = try? JSONEncoder().encode(reps) {
            UserDefaults.standard.set(data, forKey: "SavedReps")
        }
    }
    
    private func loadReps() {
        guard let data = UserDefaults.standard.data(forKey: "SavedReps"),
              let savedReps = try? JSONDecoder().decode([RepInfo].self, from: data) else {
            reps = []
            return
        }
        reps = savedReps
    }
}

// MARK: - Rep Categories
extension RepsViewModel {
    public static let categories = [
        "Film/TV Agent",
        "Commercial Agent", 
        "Manager",
        "Publicist",
        "Attorney",
        "Business Manager"
    ]
}
