import SwiftUI

private struct WidthKey: PreferenceKey {
    static var defaultValue: [String: CGFloat] = [:]
    static func reduce(value: inout [String: CGFloat], nextValue: () -> [String: CGFloat]) {
        value.merge(nextValue(), uniquingKeysWith: max)
    }
}

private struct MeasuringLabel: View {
    let id: String
    let text: String

    var body: some View {
        Text(text)
            .background(GeometryReader { geo in
                Color.clear.preference(key: WidthKey.self, value: [id: geo.size.width])
            })
    }
}

struct AdaptiveToolbar: View {
    struct ItemStyle {
        let foreground: Color
        let background: Color
        let border: Color

        static func standard(isSelected: Bool) -> ItemStyle {
            if isSelected {
                return ItemStyle(
                    foreground: .white,
                    background: Color.white.opacity(0.16),
                    border: Color.white.opacity(0.35)
                )
            } else {
                return ItemStyle(
                    foreground: .white,
                    background: Color.black.opacity(0.12),
                    border: Color.white.opacity(0.2)
                )
            }
        }
    }

    let items: [String]
    @Binding var selection: String
    var labelProvider: ((String, Bool) -> String)?
    var iconProvider: ((String, Bool) -> Image?)?
    var styleProvider: ((String, Bool) -> ItemStyle)?
    var disabledProvider: ((String) -> Bool)?

    @State private var measured: [String: CGFloat] = [:]

    var body: some View {
        let filteredItems = items.filter { $0 != "Scene" }
        let displayedItems = filteredItems.isEmpty ? items : filteredItems

        HStack(spacing: 8) {
            ForEach(displayedItems, id: \.self) { item in
                let isSelected = (item == selection)
                let label = resolvedLabel(for: item, isSelected: isSelected)
                let style = resolvedStyle(for: item, isSelected: isSelected)
                let icon = resolvedIcon(for: item, isSelected: isSelected)
                let isDisabled = disabledProvider?(item) ?? false

                Button {
                    guard !isDisabled else { return }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(.snappy) { selection = item }
                } label: {
                    HStack(spacing: 6) {
                        if let icon {
                            icon.imageScale(.medium)
                        }
                        Text(label)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .truncationMode(.tail)
                            .layoutPriority(isSelected ? 1 : 0)
                    }
                    .foregroundStyle(style.foreground)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .frame(minWidth: minWidth(for: item, isSelected: isSelected))
                    .background(style.background, in: Capsule())
                    .overlay(
                        Capsule()
                            .stroke(style.border, lineWidth: isSelected ? 1.5 : 1)
                    )
                }
                .disabled(isDisabled)
                .layoutPriority(isSelected ? 3 : 0)
                .buttonStyle(.plain)
                .accessibilityIdentifier("Toolbar_\(item)")
            }
        }
        .overlay(
            ForEach(displayedItems, id: \.self) { item in
                MeasuringLabel(
                    id: item,
                    text: resolvedLabel(for: item, isSelected: item == selection)
                )
                .hidden()
            }
        )
        .onPreferenceChange(WidthKey.self) { measured = $0 }
    }

    private func resolvedLabel(for item: String, isSelected: Bool) -> String {
        labelProvider?(item, isSelected) ?? item
    }

    private func resolvedIcon(for item: String, isSelected: Bool) -> Image? {
        iconProvider?(item, isSelected) ?? defaultIcon(for: item)
    }

    private func resolvedStyle(for item: String, isSelected: Bool) -> ItemStyle {
        styleProvider?(item, isSelected) ?? ItemStyle.standard(isSelected: isSelected)
    }

    private func minWidth(for item: String, isSelected: Bool) -> CGFloat {
        let measuredLabel = measured[item] ?? 44
        let padded = measuredLabel + 24
        return isSelected ? padded : min(padded, 64)
    }

    private func defaultIcon(for item: String) -> Image? {
        switch item {
        case "Scene": return Image(systemName: "video.fill")
        case "Slate": return Image(systemName: "text.quote")
        case "Keyframe": return Image(systemName: "square.stack.3d.down.forward.fill")
        case "Wrap": return Image(systemName: "flag.checkered")
        default: return nil
        }
    }
}
