import SwiftUI

struct PIPSlateTakeRow: View {
    let take: PIPSlateTake
    let index: Int
    let orientation: VideoOrientation
    let isSelected: Bool
    var isEdited: Bool = false
    let onSelect: () -> Void
    var onPreview: (() -> Void)? = nil
    var onShare: (() -> Void)? = nil
    var onSaveToPhotos: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 12) {
            previewThumbnail
            selectionContent
            Spacer(minLength: 8)
            trailingIndicators
        }
        .padding(.vertical, 4)
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
    
    private var thumbnailContent: some View {
        ThumbnailPreviewView(unifiedTake: makeUnifiedTake())
            .frame(width: 90, height: 58)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var semanticTakeLabel: String {
        orientation == .landscape ? "Close-Up" : "Full Body"
    }

    @ViewBuilder
    private var previewThumbnail: some View {
        if let onPreview {
            Button(action: onPreview) {
                thumbnailContent
                    .allowsHitTesting(false)
                    .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.borderless)
        } else {
            thumbnailContent
        }
    }

    private var selectionContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Take \(index)")
                .font(.headline)
                .foregroundStyle(.primary)
            Text(semanticTakeLabel)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
    }

    @ViewBuilder
    private var trailingIndicators: some View {
        HStack(spacing: 6) {
            if isEdited {
                Image(systemName: "pencil.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.orange)
            }

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(Color.accentColor)
            }

            if onShare == nil && FileManager.default.fileExists(atPath: take.fileURL.path) {
                ShareLink(item: take.fileURL) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.title3)
                }
            }

            if hasMenuActions {
                Menu {
                    if let onShare {
                        Button(action: onShare) {
                            Label("Share", systemImage: "square.and.arrow.up.fill")
                        }
                    }

                    if let onSaveToPhotos {
                        Button(action: onSaveToPhotos) {
                            Label("Save to Photos", systemImage: "square.and.arrow.down")
                        }
                    }

                    if let onDelete {
                        Button(role: .destructive, action: onDelete) {
                            Label("Delete", systemImage: "trash.fill")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
            }
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
    }

    private var hasMenuActions: Bool {
        onShare != nil || onSaveToPhotos != nil || onDelete != nil
    }
}
