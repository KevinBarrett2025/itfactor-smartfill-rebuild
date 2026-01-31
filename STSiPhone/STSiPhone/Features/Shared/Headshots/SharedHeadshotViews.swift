import SwiftUI

struct SharedHeadshotDeckView: View {
    let headshots: [HeadshotAsset]
    let preferredID: UUID?
    let isImporting: Bool
    let resolveImage: (HeadshotAsset) -> Image?
    let onSelect: (HeadshotAsset) -> Void
    let onSetPreferred: (HeadshotAsset) -> Void
    let onAdd: () -> Void
    let onDelete: ((HeadshotAsset) -> Void)?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(headshots) { asset in
                    SharedHeadshotCard(
                        asset: asset,
                        isPreferred: asset.id == preferredID,
                        image: resolveImage(asset),
                        onTap: { onSelect(asset) },
                        onSetPreferred: { onSetPreferred(asset) },
                        onDelete: onDelete.map { handler in { handler(asset) } }
                    )
                }

                Button(action: onAdd) {
                    VStack(spacing: 8) {
                        if isImporting {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .tint(.white)
                        } else {
                            Image(systemName: "plus")
                                .font(.title)
                                .foregroundStyle(.white)
                        }
                        Text(isImporting ? "Importing…" : "Add Headshot")
                            .font(Theme.Font.caption)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    .frame(width: 150, height: 210)
                    .background(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.35), style: StrokeStyle(lineWidth: 1.5, dash: [8, 6]))
                    )
                }
                .buttonStyle(.plain)
                .disabled(isImporting)
            }
            .padding(.vertical, 4)
        }
    }
}

private struct SharedHeadshotCard: View {
    let asset: HeadshotAsset
    let isPreferred: Bool
    let image: Image?
    let onTap: () -> Void
    let onSetPreferred: () -> Void
    let onDelete: (() -> Void)?

    var body: some View {
        VStack(spacing: 10) {
            headshotThumbnail
                .frame(width: 150, height: 210)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(alignment: .topLeading) {
                    if isPreferred {
                        Label("Profile", systemImage: "star.fill")
                            .font(.caption2)
                            .padding(6)
                            .background(.ultraThinMaterial, in: Capsule())
                            .padding(8)
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
                .overlay(alignment: .topTrailing) {
                    if let onDelete {
                        Button(action: onDelete) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title3)
                                .foregroundStyle(.white.opacity(0.9))
                                .shadow(color: .black.opacity(0.35), radius: 4, x: 0, y: 2)
                        }
                        .buttonStyle(.plain)
                        .padding(10)
                    }
                }
                .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .onTapGesture(perform: onTap)
            Button(isPreferred ? "Profile Photo" : "Set as Profile") {
                onSetPreferred()
            }
            .font(.footnote.weight(.semibold))
            .buttonStyle(.borderedProminent)
            .tint(isPreferred ? Color.green.opacity(0.85) : Theme.primary)
            .disabled(isPreferred)
        }
        .frame(width: 160)
    }

    @ViewBuilder
    private var headshotThumbnail: some View {
        if let image {
            image
                .resizable()
                .scaledToFill()
        } else {
            ZStack {
                Color.white.opacity(0.08)
                Image(systemName: "person.crop.rectangle")
                    .font(.largeTitle)
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
    }
}

struct HeadshotOverlayPanel: View {
    let title: String
    let assets: [HeadshotAsset]
    let preferredID: UUID?
    let isImporting: Bool
    let resolveImage: (HeadshotAsset) -> Image?
    let onSelectPrimary: (HeadshotAsset) -> Void
    let onAdd: () -> Void
    let onClose: () -> Void
    let onDelete: ((HeadshotAsset) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text(title)
                    .font(Theme.Font.headline)
                    .foregroundStyle(.white)
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.white.opacity(0.85))
                }
                .accessibilityLabel("Close overlay")
            }

            Text("Keep your latest looks ready for every opportunity.")
                .font(Theme.Font.body)
                .foregroundStyle(.white.opacity(0.8))

            SharedHeadshotDeckView(
                headshots: assets,
                preferredID: preferredID,
                isImporting: isImporting,
                resolveImage: resolveImage,
                onSelect: onSelectPrimary,
                onSetPreferred: onSelectPrimary,
                onAdd: onAdd,
                onDelete: onDelete
            )
        }
        .padding(24)
        .frame(maxWidth: 520)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.35), radius: 40, x: 0, y: 25)
        )
        .padding(.horizontal, 24)
    }
}
