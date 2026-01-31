import Foundation

enum AddressParsingService {
    /// Lightweight, best-effort parser for comma-separated addresses.
    /// Expected formats:
    /// - "123 Main St, Apt 5, Los Angeles, CA 90001, USA"
    /// - "456 Broadway, New York, NY 10012"
    static func parse(_ raw: String) -> InPersonAddress {
        let parts = raw
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        func part(_ index: Int) -> String? {
            guard parts.indices.contains(index) else { return nil }
            return parts[index]
        }

        var address = InPersonAddress()
        guard !parts.isEmpty else { return address }

        address.street1 = part(0) ?? ""
        address.street2 = part(1) ?? ""
        address.city = part(2) ?? ""

        if let statePostal = part(3) {
            let tokens = statePostal.split(separator: " ").map { String($0) }
            if tokens.count >= 2 {
                address.state = tokens.dropLast().joined(separator: " ")
                address.postalCode = tokens.last ?? ""
            } else {
                address.state = statePostal
            }
        }

        address.country = part(4) ?? ""
        return address
    }
}
