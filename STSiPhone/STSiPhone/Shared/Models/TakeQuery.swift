import Foundation

public enum TakeQueryContext: Equatable {
    case scenes
    case scene(sceneNumber: Int)
    case slates
    case slate(filter: TakeSlateFilter)
    case photosKeyframes
}

public enum TakeSlateFilter: String, CaseIterable, Equatable {
    case pip
    case smartFill
    case standard
}

public enum TakeRatingFilter: Hashable {
    case star
    case check
    case x
    case unrated
}

public extension TakeRatingFilter {
    var persistenceKey: String {
        switch self {
        case .star:
            return "star"
        case .check:
            return "check"
        case .x:
            return "x"
        case .unrated:
            return "unrated"
        }
    }

    static func fromPersistenceKey(_ key: String) -> TakeRatingFilter? {
        switch key {
        case "star":
            return .star
        case "check":
            return .check
        case "x":
            return .x
        case "unrated":
            return .unrated
        default:
            return nil
        }
    }

    var displayName: String {
        switch self {
        case .star:
            return "Final"
        case .check:
            return "Selects"
        case .x:
            return "Pass"
        case .unrated:
            return "Unrated"
        }
    }
}

public struct TakeFilter: Equatable {
    public var allowedRatings: Set<TakeRatingFilter>

    public init(allowedRatings: Set<TakeRatingFilter> = []) {
        self.allowedRatings = allowedRatings
    }
}
