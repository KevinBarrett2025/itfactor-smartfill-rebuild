import XCTest
@testable import STSiPhone

final class ProjectSlatePersistenceTests: XCTestCase {
    func testProjectEncodesSlateSelections() throws {
        var selections = SlateSelections(include: [.name, .localHire, .contact])
        selections.localHireMarket = "Atlanta"
        selections.contact = "skylar@studio.com / (555) 555-0001"
        selections.notes = "ready for callbacks"
        var project = Project(title: "Persistence Test")
        project.slateSelections = selections
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(project)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(Project.self, from: data)
        XCTAssertEqual(decoded.slateSelections, selections)
    }
    
    func testRepositoryPersistsSlatePromptUpdates() throws {
        let tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".sqlite")
        defer { try? FileManager.default.removeItem(at: tempDirectory) }
        let repository = try ProjectsRepositoryFactory.makeSQLiteRepository(at: tempDirectory)
        let session = ProjectSession(type: .selfTape)
        var project = Project(title: "Repository Test", sessions: [session])
        repository.insert(project: project)
        repository.updateSlatePrompt("Booked and excited", for: session.id, in: project.id)
        let reloadedRepository = try ProjectsRepositoryFactory.makeSQLiteRepository(at: tempDirectory)
        let persistedPrompt = reloadedRepository.project(by: project.id)?.sessions.first?.slatePrompt
        XCTAssertEqual(persistedPrompt, "Booked and excited")
    }

    func testRepositoryPersistsSessionLocation() throws {
        let tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".sqlite")
        defer { try? FileManager.default.removeItem(at: tempDirectory) }
        let repository = try ProjectsRepositoryFactory.makeSQLiteRepository(at: tempDirectory)
        var session = ProjectSession(type: .selfTape)
        session.location = LocationInfo(label: "Chicago", address: "123 Wacker Dr")
        let project = Project(title: "Location Test", sessions: [session])
        repository.insert(project: project)
        let reloadedRepository = try ProjectsRepositoryFactory.makeSQLiteRepository(at: tempDirectory)
        let persistedLocation = reloadedRepository.project(by: project.id)?.sessions.first?.location
        XCTAssertEqual(persistedLocation, session.location)
    }

    func testRepositoryPersistsSlatePromptMetadata() throws {
        let tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".sqlite")
        defer { try? FileManager.default.removeItem(at: tempDirectory) }
        let repository = try ProjectsRepositoryFactory.makeSQLiteRepository(at: tempDirectory)
        var session = ProjectSession(type: .selfTape)
        session.slatePromptMode = .custom
        session.slatePromptOverride = "Custom slate prompt"
        session.slatePromptInputsHash = "hash-v1"
        session.slatePromptUpdatedAt = Date(timeIntervalSince1970: 1234)
        session.lastCustomSlatePrompt = "Previous custom"
        let project = Project(title: "Slate Meta Test", sessions: [session])
        repository.insert(project: project)
        let reloadedRepository = try ProjectsRepositoryFactory.makeSQLiteRepository(at: tempDirectory)
        let persistedSession = reloadedRepository.project(by: project.id)?.sessions.first
        XCTAssertEqual(persistedSession?.slatePromptMode, session.slatePromptMode)
        XCTAssertEqual(persistedSession?.slatePromptOverride, session.slatePromptOverride)
        XCTAssertEqual(persistedSession?.slatePromptInputsHash, session.slatePromptInputsHash)
        XCTAssertEqual(persistedSession?.slatePromptUpdatedAt, session.slatePromptUpdatedAt)
        XCTAssertEqual(persistedSession?.lastCustomSlatePrompt, session.lastCustomSlatePrompt)
    }
}
