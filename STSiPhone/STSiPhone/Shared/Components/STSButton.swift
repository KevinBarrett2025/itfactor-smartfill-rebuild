import SwiftUI

enum STSButtonStyle {
    case primary
    case secondary
    case destructive
}

struct STSButton: View {
    var title: String
    var icon: String? = nil
    var style: STSButtonStyle = .primary
    var action: () -> Void

    private var backgroundColor: Color {
        switch style {
        case .primary: return Theme.primary
        case .secondary: return Theme.surface
        case .destructive: return .red
        }
    }

    private var foregroundColor: Color {
        switch style {
        case .primary: return .white
        case .secondary: return Theme.textPrimary
        case .destructive: return .white
        }
    }

    var body: some View {
        Button(action: action) {
            HStack {
                if let icon = icon {
                    Image(systemName: icon)
                }
                Text(title)
                    .font(.body.weight(.semibold))
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(backgroundColor)
            .foregroundStyle(foregroundColor)
            .cornerRadius(Theme.Layout.cornerRadius * 2)
            .shadow(radius: style == .primary ? 6 : 0)
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        STSButton(title: "Start Session", icon: "video.fill", style: .primary) {}
        STSButton(title: "Secondary Action", icon: "folder", style: .secondary) {}
        STSButton(title: "Delete", icon: "trash.fill", style: .destructive) {}
    }
    .padding()
    .background(Theme.background.ignoresSafeArea())
}