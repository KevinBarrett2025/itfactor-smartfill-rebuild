import SwiftUI

struct SlatePIPEditorViewLandscape: View {
    @Binding var session: SlatePIPSession
    var onDelete: (PIPSlateTake) -> Void = { _ in }
    var onPreview: (PIPSlateTake) -> Void = { _ in }

    var body: some View {
        List {
            Section(header: Text("Landscape Takes")) {
                if session.landscapeTakes.isEmpty {
                    Text("Record at least one close-up landscape slate to continue.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 8)
                } else {
                    ForEach(Array(session.landscapeTakes.enumerated()), id: \.element.id) { index, take in
                        PIPSlateTakeRow(
                            take: take,
                            index: index + 1,
                            orientation: .landscape,
                            isSelected: take.id == session.selectedLandscapeID,
                            onSelect: { session.selectedLandscapeID = take.id },
                            onPreview: { onPreview(take) },
                            onDelete: { onDelete(take) }
                        )
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .frame(minHeight: min(CGFloat(max(session.landscapeTakes.count, 1)) * 78, 300))
    }
}
