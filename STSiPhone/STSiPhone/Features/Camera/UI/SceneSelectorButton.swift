import SwiftUI

struct SceneSelectorButton<Content: View>: View {
    @Binding private var isShowingScenes: Bool
    let title: String
    let isDone: Bool
    let isActive: Bool
    let isPortrait: Bool
    let popoverContent: () -> Content

    @State private var buttonFrame: CGRect = .zero

    init(
        isShowingScenes: Binding<Bool>,
        title: String,
        isDone: Bool,
        isActive: Bool,
        isPortrait: Bool,
        @ViewBuilder popoverContent: @escaping () -> Content
    ) {
        self._isShowingScenes = isShowingScenes
        self.title = title
        self.isDone = isDone
        self.isActive = isActive
        self.isPortrait = isPortrait
        self.popoverContent = popoverContent
    }

    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.snappy) { isShowingScenes.toggle() }
        } label: {
            HStack(spacing: isPortrait ? 4 : 6) {
                Image(systemName: "video.fill")
                    .imageScale(isPortrait ? .small : .medium)
                    .font(isPortrait ? .caption : .body)
                Text(title)
                    .font(.system(size: isPortrait ? 11 : 14, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .padding(.horizontal, isPortrait ? 6 : 10)
            .padding(.vertical, isPortrait ? 6 : 7)
            .foregroundColor(isActive ? .white : .primary)
            .background(
                isActive
                ? Color.blue.opacity(0.8)
                : isDone
                    ? Color.green.opacity(0.28)
                    : Color.secondary.opacity(0.15)
            )
            .overlay(
                Capsule().stroke(
                    isActive
                    ? Color.white.opacity(0.6)
                    : isDone
                        ? Color.green
                        : Color.white.opacity(0.25),
                    lineWidth: isActive ? 1.5 : 1
                )
            )
            .clipShape(Capsule())
            .scaleEffect(isActive ? 1.05 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: isActive)
        }
        .captureGlobalFrame($buttonFrame)
        .popover(
            isPresented: $isShowingScenes,
            attachmentAnchor: .rect(.bounds),
            arrowEdge: preferredArrowEdge(for: buttonFrame)
        ) {
            popoverContent()
                .presentationCompactAdaptation(.popover)
                .presentationBackground(.ultraThinMaterial)
        }
        .accessibilityIdentifier("SceneSelectorButton")
    }

    private func preferredArrowEdge(for frame: CGRect) -> Edge {
        let screenMidY = UIScreen.main.bounds.midY
        return frame.midY < screenMidY ? .top : .bottom
    }
}
