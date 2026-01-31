import Foundation

enum RatingEducationGate {
    private static let hasShownKey = "sts.ratingEducationToast.v1"

    static func shouldShow(for rating: TakeRating) -> Bool {
        rating != .unrated && !UserDefaults.standard.bool(forKey: hasShownKey)
    }

    static func markShown() {
        UserDefaults.standard.set(true, forKey: hasShownKey)
    }

    static func triggerIfNeeded(rating: TakeRating) {
        guard shouldShow(for: rating) else { return }
        markShown()
        let payload: [String: Any] = ["rating": rating.rawValue]
        if Thread.isMainThread {
            NotificationCenter.default.post(name: .stsRatingEducationToast, object: nil, userInfo: payload)
        } else {
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .stsRatingEducationToast, object: nil, userInfo: payload)
            }
        }
    }

    static func toastMessage(for rating: TakeRating) -> String {
        let label = rating.displayName
        return "Rated as \(label). Mark Final when it's the one you're sending."
    }
}

