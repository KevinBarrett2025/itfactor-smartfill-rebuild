import SwiftUI

public struct EmptyStateView: View {
    let title: String
    let message: String
    
    public init(title: String, message: String) {
        self.title = title
        self.message = message
    }
    
    public var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "square.stack.3d.up.slash")
                .font(.system(size: 48))
                .foregroundStyle(.gray)
            
            VStack(spacing: 8) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)
                
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 32)
    }
}

#Preview {
    EmptyStateView(title: "No Projects", message: "Create or import your first breakdown to begin.")
        .background(BrandBackground())
}