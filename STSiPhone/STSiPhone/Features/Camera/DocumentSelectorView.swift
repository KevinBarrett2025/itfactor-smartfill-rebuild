import SwiftUI

struct DocumentSelectorView: View {
    struct DocumentOption: Identifiable, Hashable {
        let id: String
        let title: String
        let subtitle: String
        let iconName: String
    }

    let documents: [DocumentOption]
    let hasBreakdownNotes: Bool
    let showsBreakdownNotesRow: Bool
    let isTeleprompterVisible: Bool
    let onDocumentSelected: (DocumentOption) -> Void
    let onShowBreakdownNotes: () -> Void
    let onToggleTeleprompter: () -> Void
    let onShowTeleprompterControls: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Documents")
                .font(.headline)
                .foregroundStyle(.white.opacity(0.9))

            if documents.isEmpty {
                Text("No sides or breakdowns available.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
            } else {
                ForEach(documents) { option in
                    selectorRow(
                        title: option.title,
                        subtitle: option.subtitle,
                        systemImage: option.iconName
                    ) {
                        onDocumentSelected(option)
                    }
                }
            }

            if showsBreakdownNotesRow {
                selectorRow(
                    title: "Breakdown Notes",
                    subtitle: hasBreakdownNotes ? "View notes" : "No notes yet",
                    systemImage: "note.text"
                ) {
                    onShowBreakdownNotes()
                }
            }

            Divider()
                .background(Color.white.opacity(0.2))
                .padding(.vertical, 2)

            let teleprompterCurrentlyVisible = isTeleprompterVisible
            teleToggleRow(title: "Teleprompter", isOn: teleprompterCurrentlyVisible) { desiredState in
                guard desiredState != teleprompterCurrentlyVisible else { return }
                if desiredState {
                    onToggleTeleprompter()
                    onShowTeleprompterControls()
                } else {
                    onToggleTeleprompter()
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.black.opacity(0.88))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        )
    }

    @ViewBuilder
    private func selectorRow(
        title: String,
        subtitle: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: systemImage)
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 22)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body.weight(.semibold))
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                }
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .foregroundStyle(.white)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.08))
            )
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func teleToggleRow(
        title: String,
        isOn: Bool,
        onToggle: @escaping (Bool) -> Void
    ) -> some View {
        let binding = Binding<Bool>(
            get: { isOn },
            set: { newValue in
                onToggle(newValue)
            }
        )

        Toggle(isOn: binding) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 10) {
                    Image(systemName: "text.bubble")
                        .font(.body)
                    Text(title)
                        .font(.body.weight(.semibold))
                }
                .foregroundStyle(.white)
            }
        }
        .toggleStyle(SwitchToggleStyle(tint: Theme.primary))
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.08))
        )
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
        .frame(maxWidth: .infinity, alignment: .leading)
        .transition(.opacity)
    }
}

#Preview {
    DocumentSelectorView(
        documents: [
            .init(id: "sides-preview", title: "Sides", subtitle: "Pilot_Sides.pdf", iconName: "doc.text"),
            .init(id: "breakdown-preview", title: "Breakdown", subtitle: "Casting_Breakdown.pdf", iconName: "text.book.closed")
        ],
        hasBreakdownNotes: false,
        showsBreakdownNotesRow: true,
        isTeleprompterVisible: true,
        onDocumentSelected: { _ in },
        onShowBreakdownNotes: {},
        onToggleTeleprompter: {},
        onShowTeleprompterControls: {}
    )
    .background(Color.black)
}
