import SwiftUI

struct SizeCardTokens {
    let pageSize: CGSize
    let leftColumnWidth: CGFloat
    let gutter: CGFloat
    let contentInsets: EdgeInsets
    let headerSpacing: CGFloat
    let bodySpacing: CGFloat
}

enum SizeCardTemplate: String, CaseIterable {
    case classic
    case compact
    case slateBar
    case boldCasting

    func tokens(for aspect: SizeCardAspect) -> SizeCardTokens {
        let baseSize = aspect.canvasSize
        switch self {
        case .classic:
            return SizeCardTokens(
                pageSize: baseSize,
                leftColumnWidth: min(360, baseSize.width * 0.42),
                gutter: 24,
                contentInsets: EdgeInsets(top: 36, leading: 36, bottom: 36, trailing: 36),
                headerSpacing: 14,
                bodySpacing: 12
            )
        case .compact:
            return SizeCardTokens(
                pageSize: baseSize,
                leftColumnWidth: min(300, baseSize.width * 0.38),
                gutter: 18,
                contentInsets: EdgeInsets(top: 28, leading: 28, bottom: 28, trailing: 28),
                headerSpacing: 10,
                bodySpacing: 10
            )
        case .slateBar:
            return SizeCardTokens(
                pageSize: baseSize,
                leftColumnWidth: min(280, baseSize.width * 0.33),
                gutter: 20,
                contentInsets: EdgeInsets(top: 24, leading: 32, bottom: 24, trailing: 32),
                headerSpacing: 8,
                bodySpacing: 10
            )
        case .boldCasting:
            return SizeCardTokens(
                pageSize: baseSize,
                leftColumnWidth: min(320, baseSize.width * 0.4),
                gutter: 26,
                contentInsets: EdgeInsets(top: 32, leading: 32, bottom: 32, trailing: 32),
                headerSpacing: 16,
                bodySpacing: 14
            )
        }
    }
}
