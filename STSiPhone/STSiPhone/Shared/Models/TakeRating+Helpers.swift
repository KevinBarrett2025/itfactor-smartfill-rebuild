import Foundation

public protocol TakeRatingContaining {
    var rating: TakeRating { get }
}

public extension TakeRating {
    static var displayOrder: [TakeRating] {
        [.finalSelect, .option, .unrated, .rejected]
    }

    var isFinalSelect: Bool { self == .finalSelect }
    var isOption: Bool { self == .option }
    var isRejected: Bool { self == .rejected }
    var isExportSelected: Bool { self == .finalSelect }
}

public extension TakeRatingContaining {
    var isFinalSelect: Bool { rating.isFinalSelect }
    var isOption: Bool { rating.isOption }
    var isRejected: Bool { rating.isRejected }
    var isExportSelected: Bool { rating.isExportSelected }
}

extension ProjectTake: TakeRatingContaining {}
extension UnifiedTake: TakeRatingContaining {}
extension EnhancedTake: TakeRatingContaining {}
extension Take: TakeRatingContaining {}
