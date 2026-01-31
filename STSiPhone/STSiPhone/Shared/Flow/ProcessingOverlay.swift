import SwiftUI

struct ProcessingOverlay: View {
    var message: String = "Processing…"
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
            VStack(spacing: 12) {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(.white)
                Text(message)
                    .font(.headline)
                    .foregroundStyle(.white)
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.black.opacity(0.65))
            )
            .shadow(radius: 20)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(message))
    }
}
