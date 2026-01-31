import SwiftUI

/// Pill-sized exposure slider for the AE/AF HUD.
/// Uses SwiftUI's built-in Slider for reliable thumb tracking, but stays compact.
/// - value: exposure bias (e.g. -2...2)
struct AEAFExposurePillSlider: View {
    let value: Binding<Double>
    let range: ClosedRange<Double>
    var onInteractionChanged: ((Bool) -> Void)? = nil

    var body: some View {
        VStack(spacing: 0) {
            Image(systemName: "sun.max.fill")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.9))
                .padding(.top, 6)

            Spacer(minLength: 0)

            Slider(value: value, in: range, step: 0.01)
                .tint(.yellow)
                .rotationEffect(.degrees(-90))
                .frame(width: 120, height: 24)
                .contentShape(Rectangle())
                .simultaneousGesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in onInteractionChanged?(true) }
                        .onEnded { _ in onInteractionChanged?(false) }
                )
                .onTapGesture { }

            Spacer(minLength: 0)

            Image(systemName: "sun.min.fill")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.9))
                .padding(.bottom, 6)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 10)
        .frame(width: 64, height: 170)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.35), radius: 8, x: 0, y: 6)
        .accessibilityLabel("Exposure")
    }
}
