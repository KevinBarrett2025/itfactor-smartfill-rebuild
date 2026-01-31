import XCTest
@testable import STSiPhone

final class SlatePromptResolverTests: XCTestCase {
    func testResolverHashStableForSameInputs() {
        var profile = ActorProfile()
        profile.name = "Jack Barrett"
        profile.email = "jack@example.com"
        profile.phone = "555-0100"
        profile.height = "6'0\""
        profile.primaryLocation = "Los Angeles"

        var selections = SlateSelections()
        selections.include = [.name, .height, .location]
        selections.localHireMarket = "Atlanta"

        let project = Project(title: "Prompt Test", sessions: [ProjectSession(type: .selfTape)])
        let session = project.sessions.first

        let first = SlatePromptResolver.resolve(
            profile: profile,
            project: project,
            session: session,
            selections: selections,
            fallbackLocation: "Los Angeles"
        )
        let second = SlatePromptResolver.resolve(
            profile: profile,
            project: project,
            session: session,
            selections: selections,
            fallbackLocation: "Los Angeles"
        )

        XCTAssertEqual(first.inputsHash, second.inputsHash)
        XCTAssertEqual(first.prompt, second.prompt)
    }

    func testResolverHashChangesWhenProfileChanges() {
        var profile = ActorProfile()
        profile.name = "Jack Barrett"

        var selections = SlateSelections()
        selections.include = [.name]

        let first = SlatePromptResolver.resolve(
            profile: profile,
            project: nil,
            session: nil,
            selections: selections
        )

        profile.name = "Rachel Melvin"

        let second = SlatePromptResolver.resolve(
            profile: profile,
            project: nil,
            session: nil,
            selections: selections
        )

        XCTAssertNotEqual(first.inputsHash, second.inputsHash)
    }
}
