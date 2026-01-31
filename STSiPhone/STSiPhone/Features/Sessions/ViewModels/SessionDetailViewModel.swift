import Foundation
import Observation

@Observable
public final class SessionDetailViewModel {
    public private(set) var session: ProjectSession
    
    public init(session: ProjectSession) { 
        self.session = session 
    }
    
    public var displayTitle: String { 
        session.type.rawValue 
    }
}