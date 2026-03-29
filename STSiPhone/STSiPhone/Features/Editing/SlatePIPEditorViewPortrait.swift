import SwiftUI

struct SlatePIPEditorViewPortrait: View {
    @Binding var session: SlatePIPSession
    var isTakeEdited: (PIPSlateTake) -> Bool = { _ in false }
    var onDelete: (PIPSlateTake) -> Void = { _ in }
    var onPreview: (PIPSlateTake) -> Void = { _ in }
    var onShare: (PIPSlateTake) -> Void = { _ in }
    var onSaveToPhotos: (PIPSlateTake) -> Void = { _ in }

    var body: some View {
        List {
            Section(header: Text("Portrait Takes")) {
                if session.portraitTakes.isEmpty {
                    Text("Capture a full-body portrait slate before finishing.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 8)
                } else {
                    ForEach(Array(session.portraitTakes.enumerated()), id: \.element.id) { index, take in
                        PIPSlateTakeRow(
                            take: take,
                            index: index + 1,
                            orientation: .portrait,
                            isSelected: take.id == session.selectedPortraitID,
                            isEdited: isTakeEdited(take),
                            onSelect: { session.selectedPortraitID = take.id },
                            onPreview: { onPreview(take) },
                            onShare: { onShare(take) },
                            onSaveToPhotos: { onSaveToPhotos(take) },
                            onDelete: { onDelete(take) }
                        )
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .frame(minHeight: min(CGFloat(max(session.portraitTakes.count, 1)) * 78, 300))
    }
}
