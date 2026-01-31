import UIKit

/// A view that only intercepts touches when an interactive subview would receive them.
/// Otherwise, touches pass through to underlying views (e.g., zooming scroll views).
final class PassthroughOverlayView: UIView {
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        for sub in subviews where !sub.isHidden && sub.alpha > 0.01 && sub.isUserInteractionEnabled {
            let convertedPoint = convert(point, to: sub)
            if sub.point(inside: convertedPoint, with: event) {
                return true
            }
        }
        return false
    }
}
