import Foundation

// FIXED: Shared ProjectSessionData struct to eliminate @State capture bug in sheet closures
// This replaces the pattern of separate @State variables that cause nil values in sheet closures
public struct ProjectSessionData: Identifiable {
    public let id = UUID()
    public let project: Project
    public let session: ProjectSession
    
    public init(project: Project, session: ProjectSession) {
        self.project = project
        self.session = session
    }
}