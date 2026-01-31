import Foundation
import CryptoKit

struct SlatePromptResolver {
    struct Result: Sendable {
        let prompt: String
        let inputsHash: String
    }

    static func resolve(
        profile: ActorProfile,
        project: Project?,
        session: ProjectSession?,
        selections: SlateSelections,
        fallbackLocation: String? = nil,
        heightOverride: String? = nil,
        locationOverride: String? = nil,
        style: SlateStyle = .standard
    ) -> Result {
        var context = SlateContext.make(
            profile: profile,
            project: project,
            session: session,
            selections: selections,
            fallbackLocation: fallbackLocation
        )

        if let trimmedHeight = heightOverride?.slateTrimmedNonEmpty {
            context.heightDisplay = trimmedHeight
        }

        if let trimmedLocation = locationOverride?.slateTrimmedNonEmpty {
            context.baseLocation = trimmedLocation
        }

        let prompt = SlateComposer.build(context, style: style)
        let inputsHash = inputsHash(for: context, style: style)
        return Result(prompt: prompt, inputsHash: inputsHash)
    }

    private struct SelectionsSnapshot: Codable, Sendable {
        let include: [String]
        let localHireMarket: String?
        let unionStatus: String?
        let representation: String?
        let contact: String?
        let notes: String?
        let framingSelection: String
        let includePassport: Bool
        let hasValidPassport: Bool?
        let includeCitizenship: Bool
        let isLegalCitizen: Bool?
        let citizenshipCountry: String?
    }

    private struct InputsSnapshot: Codable, Sendable {
        let version: Int
        let style: String
        let actorName: String
        let heightDisplay: String?
        let baseLocation: String?
        let defaultUnionStatus: String?
        let defaultRepresentation: String?
        let defaultContact: String?
        let selections: SelectionsSnapshot
    }

    private static func inputsHash(for context: SlateContext, style: SlateStyle) -> String {
        let snapshot = InputsSnapshot(
            version: 3,
            style: style.rawValue,
            actorName: context.actorName.trimmingCharacters(in: .whitespacesAndNewlines),
            heightDisplay: normalized(context.heightDisplay),
            baseLocation: normalized(context.baseLocation),
            defaultUnionStatus: normalized(context.defaultUnionStatus),
            defaultRepresentation: normalized(context.defaultRepresentation),
            defaultContact: normalized(context.defaultContact),
            selections: snapshotSelections(context.selections)
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(snapshot) else {
            return ""
        }
        return sha256Hex(data)
    }

    private static func snapshotSelections(_ selections: SlateSelections) -> SelectionsSnapshot {
        SelectionsSnapshot(
            include: selections.include.map(\.rawValue).sorted(),
            localHireMarket: normalized(selections.localHireMarket),
            unionStatus: normalized(selections.unionStatus),
            representation: normalized(selections.representation),
            contact: normalized(selections.contact),
            notes: normalized(selections.notes),
            framingSelection: selections.framingSelection.rawValue,
            includePassport: selections.includePassport,
            hasValidPassport: selections.hasValidPassport,
            includeCitizenship: selections.includeCitizenship,
            isLegalCitizen: selections.isLegalCitizen,
            citizenshipCountry: normalized(selections.citizenshipCountry)
        )
    }

    private static func normalized(_ value: String?) -> String? {
        value?.slateTrimmedNonEmpty
    }

    private static func sha256Hex(_ data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
