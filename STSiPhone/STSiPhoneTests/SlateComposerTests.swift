import XCTest
@testable import STSiPhone

final class SlateComposerTests: XCTestCase {
    func testStandardCompositionIncludesSelectedFields() {
        var selections = SlateSelections(include: [.name, .height, .location])
        selections.notes = "thank you for your consideration"
        let context = SlateContext(
            actorName: "Jordan Reeves",
            heightDisplay: "6'1\"",
            baseLocation: "New York",
            defaultUnionStatus: "SAG-AFTRA",
            defaultRepresentation: nil,
            defaultContact: nil,
            selections: selections
        )
        let result = SlateComposer.build(context)
        XCTAssertTrue(result.contains("Hi, my name is Jordan Reeves."))
        XCTAssertTrue(result.contains("I’m 6'1\"."))
        XCTAssertTrue(result.contains("I’m based in New York."))
        XCTAssertTrue(result.contains("Thank you for your consideration."))
    }
    
    func testLocalHireAndContactComposition() {
        var selections = SlateSelections(include: [.name, .localHire, .contact])
        selections.localHireMarket = "Atlanta"
        selections.contact = "jordan@studio.com / (555) 123-0000"
        let context = SlateContext(
            actorName: "Jordan Reeves",
            heightDisplay: nil,
            baseLocation: nil,
            defaultUnionStatus: nil,
            defaultRepresentation: nil,
            defaultContact: nil,
            selections: selections
        )
        let result = SlateComposer.build(context)
        XCTAssertTrue(result.contains("I am available to work as a local hire in Atlanta."))
        XCTAssertTrue(result.contains("You can reach me at jordan@studio.com / (555) 123-0000."))
    }
    
    func testComposerFallsBackToDefaultMessage() {
        let context = SlateContext(
            actorName: "",
            heightDisplay: nil,
            baseLocation: nil,
            defaultUnionStatus: nil,
            defaultRepresentation: nil,
            defaultContact: nil,
            selections: SlateSelections(include: [])
        )
        let result = SlateComposer.build(context)
        XCTAssertEqual(result, "Hi, I'm ready for my audition.")
    }
    
    func testComposerFallsBackToDefaultUnionStatus() {
        var selections = SlateSelections(include: [.name, .unionStatus])
        selections.unionStatus = nil
        let context = SlateContext(
            actorName: "Skylar Lee",
            heightDisplay: nil,
            baseLocation: nil,
            defaultUnionStatus: "SAG-AFTRA",
            defaultRepresentation: nil,
            defaultContact: nil,
            selections: selections
        )
        let result = SlateComposer.build(context)
        XCTAssertTrue(result.contains("SAG-AFTRA"))
    }
    
    func testComposerUsesDefaultRepresentationWhenMissing() {
        var selections = SlateSelections(include: [.name, .representation])
        selections.representation = nil
        let context = SlateContext(
            actorName: "Skylar Lee",
            heightDisplay: nil,
            baseLocation: nil,
            defaultUnionStatus: nil,
            defaultRepresentation: "Gersh • (555) 222-1000",
            defaultContact: nil,
            selections: selections
        )
        let result = SlateComposer.build(context)
        XCTAssertTrue(result.contains("I’m currently represented by Gersh • (555) 222-1000."))
    }
    
    func testNotesAreCapitalizedAndPunctuated() {
        var selections = SlateSelections(include: [.name])
        selections.notes = "available for callbacks same day"
        let context = SlateContext(
            actorName: "Skylar Lee",
            heightDisplay: nil,
            baseLocation: nil,
            defaultUnionStatus: nil,
            defaultRepresentation: nil,
            defaultContact: nil,
            selections: selections
        )
        let result = SlateComposer.build(context)
        XCTAssertTrue(result.contains("Available for callbacks same day."))
        XCTAssertTrue(result.hasSuffix("."))
    }

    func testRepresentationTypeParsing() {
        var selections = SlateSelections(include: [.representation])
        selections.representation = "Theatrical: Brillstein — brig@ex.com"
        let context = SlateContext(
            actorName: "Jordan Reeves",
            heightDisplay: nil,
            baseLocation: nil,
            defaultUnionStatus: nil,
            defaultRepresentation: nil,
            defaultContact: nil,
            selections: selections
        )
        let result = SlateComposer.build(context)
        XCTAssertTrue(result.contains("I’m currently represented theatrically by Brillstein."))
    }
    
    func testRepresentationManagerPhrase() {
        var selections = SlateSelections(include: [.representation])
        selections.representation = "Manager: Jane Smith — jane@example.com"
        let context = SlateContext(
            actorName: "Jordan Reeves",
            heightDisplay: nil,
            baseLocation: nil,
            defaultUnionStatus: nil,
            defaultRepresentation: nil,
            defaultContact: nil,
            selections: selections
        )
        let result = SlateComposer.build(context)
        XCTAssertTrue(result.contains("I’m currently represented by my manager Jane Smith."))
    }
    
    func testLocationPlusLocalHireSentence() {
        var selections = SlateSelections(include: [.location, .localHire])
        selections.localHireMarket = "los angeles"
        let context = SlateContext(
            actorName: "Jordan Reeves",
            heightDisplay: nil,
            baseLocation: "new york",
            defaultUnionStatus: nil,
            defaultRepresentation: nil,
            defaultContact: nil,
            selections: selections
        )
        let result = SlateComposer.build(context)
        XCTAssertTrue(result.contains("I’m based in New York, but I’m available to work as a local hire in Los Angeles.") ||
                      result.contains("I’m based in New York, but I am available to work as a local hire in Los Angeles."))
    }
    
    func testContactPhraseDetectsPhone() {
        var selections = SlateSelections(include: [.contact])
        selections.contact = "(310) 555-1212"
        let context = SlateContext(
            actorName: "Jordan Reeves",
            heightDisplay: nil,
            baseLocation: nil,
            defaultUnionStatus: nil,
            defaultRepresentation: nil,
            defaultContact: nil,
            selections: selections
        )
        let result = SlateComposer.build(context)
        XCTAssertTrue(result.contains("You can reach me at (310) 555-1212."))
    }
}
