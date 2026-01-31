import XCTest
@testable import STSiPhone

final class ProjectSessionMergeTests: XCTestCase {

    // Helper: make a stub session with a stable ID
    private func makeSession(id: UUID = UUID(), label: String) -> ProjectSession {
        var session = ProjectSession(
            id: id,
            type: .selfTape,
            date: Date(),
            location: nil,
            contact: nil,
            notes: label,
            takes: [],
            roleName: nil,
            callbackNotes: nil,
            parkingInfo: nil,
            primaryOrientation: nil,
            smartFillEnabled: nil,
            slatePrompt: nil,
            sidesFileName: nil,
            breakdownFileName: nil,
            breakdownNotes: nil,
            pipSlateSession: nil
        )
        session.location = LocationInfo(label: label)
        return session
    }

    // Helper: build an "existing" project with two sessions
    private func makeExistingProject() -> Project {
        let s1ID = UUID()
        let s2ID = UUID()

        let s1 = makeSession(id: s1ID, label: "Scene 1")
        let s2 = makeSession(id: s2ID, label: "Scene 2")

        var project = Project(title: "Existing Project", sessions: [s1, s2])
        project.sceneCount = 2
        return project
    }

    /// Simulate the same merge behavior as NewProjectWizard.buildProject()
    private func mergeEditingProject(
        original existingProject: Project,
        editedStub: Project,
        sidesFileName: String?,
        breakdownFileName: String?,
        breakdownNotes: String?,
        slatePrompt: String?,
        location: LocationInfo?
    ) -> Project {
        var project = editedStub

        // Use original ID (wizard preserves project identity)
        project.id = existingProject.id

        if !existingProject.sessions.isEmpty {
            project.sessions = existingProject.sessions.enumerated().map { index, session in
                var updated = session
                if index == 0 {
                    updated.sidesFileName = sidesFileName
                    updated.breakdownFileName = breakdownFileName
                    updated.breakdownNotes = breakdownNotes
                    updated.slatePrompt = slatePrompt
                    updated.location = location
                }
                return updated
            }
        }

        return project
    }

    func testEditingDoesNotChangeSessionCount() {
        // Arrange
        let existing = makeExistingProject()
        XCTAssertEqual(existing.sessions.count, 2, "Precondition failed: expected 2 sessions")

        var editedStub = existing
        editedStub.sceneCount = 5 // User increases scenes

        // Act
        let merged = mergeEditingProject(
            original: existing,
            editedStub: editedStub,
            sidesFileName: "sides.pdf",
            breakdownFileName: "breakdown.pdf",
            breakdownNotes: "New breakdown notes",
            slatePrompt: "New slate prompt",
            location: nil
        )

        // Assert
        XCTAssertEqual(
            merged.sessions.count,
            existing.sessions.count,
            "Editing should not change the number of sessions"
        )
    }

    func testEditingDoesNotChangeExistingSessionIDs() {
        // Arrange
        let existing = makeExistingProject()
        let originalIDs = existing.sessions.map(\.id)

        var editedStub = existing
        editedStub.sceneCount = 5

        // Act
        let merged = mergeEditingProject(
            original: existing,
            editedStub: editedStub,
            sidesFileName: "sides.pdf",
            breakdownFileName: "breakdown.pdf",
            breakdownNotes: "New breakdown notes",
            slatePrompt: "New slate prompt",
            location: nil
        )

        let newIDs = merged.sessions.map(\.id)

        // Assert
        XCTAssertEqual(
            newIDs,
            originalIDs,
            "Editing should never change existing session IDs (or order)"
        )
    }

    func testEditingUpdatesSessionLocation() {
        // Arrange
        let existing = makeExistingProject()
        var editedStub = existing
        editedStub.sceneCount = 3
        let newLocation = LocationInfo(label: "Atlanta", address: "123 Peachtree St")

        // Act
        let merged = mergeEditingProject(
            original: existing,
            editedStub: editedStub,
            sidesFileName: nil,
            breakdownFileName: nil,
            breakdownNotes: nil,
            slatePrompt: nil,
            location: newLocation
        )

        // Assert
        XCTAssertEqual(merged.sessions.first?.location, newLocation)
    }
}
