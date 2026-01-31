import Foundation

struct WizardChecklistSignals {
    var editedSubmissionWindow: Bool
    var editedSlateDetails: Bool
    var touchedBreakdownNotes: Bool
}

extension ChecklistProgress {
    mutating func applyAutoFlags(
        from project: Project,
        session: ProjectSession,
        signals: WizardChecklistSignals
    ) {
        func mark(_ item: Item, when condition: Bool) {
            guard condition else { return }
            if checks[item] != true {
                checks[item] = true
            }
        }
        
        let projectNotes = project.breakdownNotes?.slateTrimmedNonEmpty
        let sessionNotes = session.breakdownNotes?.slateTrimmedNonEmpty
        let effectiveNotes = sessionNotes ?? projectNotes
        
        let hasBreakdownFile =
            (session.breakdownFileName ?? project.breakdownFileName)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .isEmpty == false
        
        let breakdownHasContent = hasBreakdownFile || (effectiveNotes?.isEmpty == false)
        
        mark(.characterBreakdown, when: breakdownHasContent)
        
        let slateSelections = project.slateSelections
        let hasSlateFields = !slateSelections.include.isEmpty
            || slateSelections.includePassport
            || slateSelections.includeCitizenship
        let slateTextFields = [
            slateSelections.localHireMarket,
            slateSelections.unionStatus,
            slateSelections.representation,
            slateSelections.contact,
            slateSelections.notes
        ]
        let hasSlateText = slateTextFields
            .compactMap { $0?.slateTrimmedNonEmpty }
            .isEmpty == false
        let hasPassport = slateSelections.includePassport && slateSelections.hasValidPassport == true
        let hasCitizenship = slateSelections.includeCitizenship
            && slateSelections.isLegalCitizen == true
            && slateSelections.citizenshipCountry?.slateTrimmedNonEmpty != nil
        let alreadyCheckedSlate = checks[.slateEssentials] == true
        
        mark(
            .slateEssentials,
            when: signals.editedSlateDetails
                && (hasSlateFields || hasSlateText || hasPassport || hasCitizenship || alreadyCheckedSlate)
        )
        
        let alreadyCheckedSubmission = checks[.submissionWindow] == true
        
        mark(
            .submissionWindow,
            when: signals.editedSubmissionWindow || alreadyCheckedSubmission
        )
    }
}
