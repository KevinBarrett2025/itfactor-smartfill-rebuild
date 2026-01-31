import SwiftUI
import AVFoundation

public struct TimelineChip: View {
    let item: ExportItem
    let isDragging: Bool
    let onToggleInclude: () -> Void

    init(item: ExportItem, isDragging: Bool, onToggleInclude: @escaping () -> Void) {
        self.item = item
        self.isDragging = isDragging
        self.onToggleInclude = onToggleInclude
    }

    public var body: some View {
        VStack(spacing: 6) {
            ZStack {
                AsyncThumbnail(url: item.url)
                    .overlay {
                        if isDragging {
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(style: StrokeStyle(lineWidth: 2, dash: [6,4]))
                                .foregroundStyle(.tint)
                        }
                    }
                    .overlay(alignment: .bottomTrailing) {
                        Button(action: onToggleInclude) {
                            Image(systemName: item.included ? "star.circle.fill" : "xmark.circle")
                                .imageScale(.large)
                                .symbolRenderingMode(.hierarchical)
                                .foregroundStyle(item.included ? .yellow : .red)
                                .padding(6)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(item.included ? "Included (\(TakeRating.finalSelect.displayName))" : "Excluded")
                    }
            }
            .frame(width: 92, height: 84)

            Text(item.label)
                .font(.footnote).lineLimit(1)
                .foregroundStyle(.white)

            Text(item.duration.asClockString)
                .font(.caption2).foregroundStyle(.secondary)
        }
        .padding(6)
        .accessibilityLabel("\(item.label), \(Int(item.duration.seconds)) seconds, \(item.included ? "included (\(TakeRating.finalSelect.displayName))" : "excluded")")
        .accessibilityAddTraits(.isButton)
    }
}

public struct ExportTimelineStrip: View {
    @Binding var items: [ExportItem]
    @State private var dragging: ExportItem?
    @State private var selected: ExportItem.ID?

    init(items: Binding<[ExportItem]>) {
        self._items = items
    }

    public var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(items) { item in
                    TimelineChip(item: item, isDragging: dragging?.id == item.id) {
                        if let idx = items.firstIndex(where: { $0.id == item.id }) {
                            items[idx].included.toggle()
                        }
                    }
                    .contextMenu {
                        Button(item.included ? "Exclude" : "Include") {
                            if let idx = items.firstIndex(where: { $0.id == item.id }) {
                                items[idx].included.toggle()
                            }
                        }
                    }
                    .draggable(item)
                    .dropDestination(for: ExportItem.self) { dropped, _ in
                        guard let from = dropped.first,
                              let src = items.firstIndex(where: { $0.id == from.id }),
                              let dst = items.firstIndex(where: { $0.id == item.id }) else { return false }
                        withAnimation(.snappy) {
                            let moving = items.remove(at: src)
                            items.insert(moving, at: dst)
                        }
                        return true
                    } isTargeted: { hovering in
                        dragging = hovering ? item : nil
                    }
                    .onTapGesture { selected = item.id }
                }
            }
            .padding(.horizontal)
        }
    }
}
