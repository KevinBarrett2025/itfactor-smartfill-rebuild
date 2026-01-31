import SwiftUI

struct KeyboardDonePill: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("Done")
                .font(.system(size: 15, weight: .semibold))
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .foregroundColor(.white)
                .background(
                    Capsule()
                        .fill(Theme.primary)
                )
                .fixedSize()
        }
        .buttonStyle(.plain)
        .padding(.trailing, 4)
    }
}
