import SwiftUI
import UIKit

/// Full-width brand banner aligned to the card inset with optional overlap and min height.
struct BrandHeaderImage: View {
    let imageName: String
    let cardInset: CGFloat
    let overlapDepth: CGFloat
    let minVisualHeight: CGFloat

    @State private var aspectRatio: CGFloat?

    init(
        imageName: String,
        cardInset: CGFloat = 20,
        overlapDepth: CGFloat = 18,
        minVisualHeight: CGFloat = 150
    ) {
        self.imageName = imageName
        self.cardInset = cardInset
        self.overlapDepth = overlapDepth
        self.minVisualHeight = minVisualHeight
    }

    var body: some View {
        let screenWidth = UIScreen.main.bounds.width
        let targetWidth = max(0, screenWidth - (cardInset * 2))

        VStack(spacing: 0) {
            Image(imageName)
                .resizable()
                .renderingMode(.original)
                .interpolation(.high)
                .aspectRatio(aspectRatio ?? 3.0, contentMode: .fit)
                .frame(width: targetWidth)
                .frame(minHeight: minVisualHeight)
                .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .padding(.horizontal, cardInset)
        .padding(.bottom, -overlapDepth)
        .zIndex(10)
        .task {
            if aspectRatio == nil, let image = UIImage(named: imageName) {
                aspectRatio = image.size.width / max(image.size.height, 1)
            }
        }
    }
}

enum StickyHeaderBehavior {
    case pinned
    case scrollsWithContent
}

/// Sticky container that pins the header under the toolbar without showing duplicates.
struct StickyHeaderScroll<Header: View, Content: View>: View {
    let topOffset: CGFloat
    let pinnedOverlapDepth: CGFloat
    let behavior: StickyHeaderBehavior
    let headerBuilder: () -> Header
    let contentBuilder: () -> Content

    @State private var headerMinY: CGFloat = 0

    init(
        topOffset: CGFloat = -6,
        pinnedOverlapDepth: CGFloat = 8,
        behavior: StickyHeaderBehavior = .pinned,
        @ViewBuilder header: @escaping () -> Header,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.topOffset = topOffset
        self.pinnedOverlapDepth = pinnedOverlapDepth
        self.behavior = behavior
        self.headerBuilder = header
        self.contentBuilder = content
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                headerBuilder()
                    .background(
                        GeometryReader { proxy in
                            Color.clear.preference(
                                key: StickyHeaderMinYKey.self,
                                value: proxy.frame(in: .named("StickyHeaderScroll")).minY
                            )
                        }
                    )
                    .opacity(inlineHeaderOpacity)
                    .zIndex(inlineHeaderZIndex)

                contentBuilder()
                    .zIndex(1)
            }
            .padding(.horizontal, 0)
        }
        .coordinateSpace(name: "StickyHeaderScroll")
        .onPreferenceChange(StickyHeaderMinYKey.self) { headerMinY = $0 }
        .overlay(alignment: .top) {
            if behavior == .pinned {
                headerBuilder()
                    .opacity(headerMinY < 0 ? 1 : 0)
                    .allowsHitTesting(false)
                    .frame(maxWidth: .infinity, alignment: .top)
                    .ignoresSafeArea(edges: .horizontal)
                    .padding(.top, topOffset)
                    .padding(.bottom, -pinnedOverlapDepth)
                    .zIndex(20)
            }
        }
    }

    private var inlineHeaderOpacity: Double {
        guard behavior == .pinned else { return 1 }
        let clamp = max(-60, min(0, headerMinY))
        let progress = 1 + clamp / 60
        return Double(max(0, min(1, progress)))
    }

    private var inlineHeaderZIndex: Double {
        if behavior == .pinned {
            return headerMinY < 0 ? 0 : 10
        }
        return 10
    }
}

private struct StickyHeaderMinYKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
