import SwiftUI

public struct WrapHStack<Content: View>: View {
    let content: Content
    let spacing: CGFloat
    
    public init(spacing: CGFloat = 8, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }
    
    public var body: some View {
        _WrapHStack(spacing: spacing) {
            content
        }
    }
}

private struct _WrapHStack<Content: View>: View {
    let content: Content
    let spacing: CGFloat
    
    init(spacing: CGFloat, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }
    
    var body: some View {
        GeometryReader { geometry in
            self.content
                .frame(width: geometry.size.width, alignment: .leading)
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

// Alternative simpler implementation using LazyVGrid
public struct SimpleWrapHStack<Content: View>: View {
    let content: Content
    let spacing: CGFloat
    
    public init(spacing: CGFloat = 8, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }
    
    public var body: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible()), count: 1),
            alignment: .leading,
            spacing: spacing
        ) {
            content
        }
    }
}

#Preview {
    WrapHStack(spacing: 8) {
        ForEach(["Agent", "Manager", "Casting Director"], id: \.self) { role in
            Text(role)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.blue.opacity(0.1))
                .foregroundColor(.blue)
                .clipShape(Capsule())
        }
    }
    .padding()
    .background(Color.gray.opacity(0.1))
}
