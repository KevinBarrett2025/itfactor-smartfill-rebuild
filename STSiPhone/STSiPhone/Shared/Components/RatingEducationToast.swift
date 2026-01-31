import SwiftUI

private struct RatingEducationToast: View {
    let message: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(Color.white.opacity(0.9))

            Text(message)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.white)

            Spacer(minLength: 0)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.black.opacity(0.78))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.25), radius: 10, x: 0, y: 6)
    }
}

private struct RatingEducationToastHost: ViewModifier {
    @State private var showToast = false
    @State private var message = ""
    @State private var dismissWorkItem: DispatchWorkItem?

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if showToast {
                    RatingEducationToast(message: message)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .padding(.top, 8)
                        .padding(.horizontal, 12)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .stsRatingEducationToast)) { notification in
                let ratingRaw = notification.userInfo?["rating"] as? String
                let rating = ratingRaw.flatMap { TakeRating(rawValue: $0) }
                let toastMessage = rating.map { RatingEducationGate.toastMessage(for: $0) }
                    ?? "Rated. Mark Final when it's the one you're sending."
                show(toastMessage)
            }
    }

    private func show(_ message: String) {
        dismissWorkItem?.cancel()
        self.message = message
        withAnimation(.easeInOut(duration: 0.2)) {
            showToast = true
        }

        let workItem = DispatchWorkItem {
            withAnimation(.easeInOut(duration: 0.2)) {
                showToast = false
            }
        }
        dismissWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4, execute: workItem)
    }
}

extension View {
    func ratingEducationToastHost() -> some View {
        modifier(RatingEducationToastHost())
    }
}

