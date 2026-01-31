import SwiftUI

struct PIPSlateTakeRow: View {
    let take: PIPSlateTake
    let index: Int
    let orientation: VideoOrientation
    let isSelected: Bool
    let onSelect: () -> Void
    var onPreview: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                ThumbnailPreviewView(unifiedTake: makeUnifiedTake())
                    .frame(width: 90, height: 58)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text("Take \(index)")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(orientation == .portrait ? "Full Body" : "Close-Up")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                controlButtons

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(Color.accentColor)
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }

    private func makeUnifiedTake() -> UnifiedTake {
        let fileURL = take.fileURL
        let attributes = (try? FileManager.default.attributesOfItem(atPath: fileURL.path))
        let size = (attributes?[.size] as? NSNumber)?.int64Value ?? 0

        return UnifiedTake(
            id: take.id,
            fileName: fileURL.lastPathComponent,
            projectID: UUID(),
            sessionID: UUID(),
            filePath: fileURL.path,
            duration: take.duration,
            fileSize: size,
            cameraPosition: "back",
            sceneNumber: 0,
            takeNumber: index,
            isSlate: true,
            capturedOrientation: orientation,
                rating: .unrated,
                createdAt: take.createdAt
        )
    }
    
    @ViewBuilder
    private var controlButtons: some View {
        HStack(spacing: 10) {
            if let onPreview {
                Button(action: onPreview) {
                    Image(systemName: "play.rectangle.fill")
                        .font(.title3)
                }
            }
            
            if FileManager.default.fileExists(atPath: take.fileURL.path) {
                ShareLink(item: take.fileURL) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.title3)
                }
            }
            
            if let onDelete {
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                        .font(.title3)
                }
            }
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
    }
}
