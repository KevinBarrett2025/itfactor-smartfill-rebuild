import SwiftUI

// MARK: - Branded Row Card (Global Project/Session Style)
struct BrandedRowCard: View {
    var title: String
    var subtitle: String
    var roles: String
    var sessionsCount: Int? = nil
    var onTap: (() -> Void)? = nil
    var isInteractive: Bool = true
    
    var body: some View {
        if isInteractive && onTap != nil {
            Button(action: onTap ?? {}) {
                cardContent
            }
            .buttonStyle(PlainButtonStyle())
        } else {
            cardContent
        }
    }
    
    private var cardContent: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                
                Text(subtitle.isEmpty ? "No casting office" : subtitle)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.leading)
                    .lineLimit(1)
                
                if !roles.isEmpty {
                    Text("Roles: \(roles)")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(.gray.opacity(0.8))
                        .lineLimit(1)
                        .multilineTextAlignment(.leading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                if let count = sessionsCount {
                    Text("\(count) session\(count > 1 ? "s" : "")")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.gray)
                }
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.gray.opacity(0.6))
            }
        }
        .padding(.vertical, 12) // RESTORED: Professional card padding now that duplicate IDs are fixed
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.systemIndigo).opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
        .shadow(color: Color.black.opacity(0.15), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Branded Archive Row (Faded Style)
struct BrandedArchiveRow: View {
    var title: String
    var date: String
    var onTap: (() -> Void)? = nil
    var isInteractive: Bool = true
    
    var body: some View {
        if isInteractive && onTap != nil {
            Button(action: onTap ?? {}) {
                archiveContent
            }
            .buttonStyle(PlainButtonStyle())
        } else {
            archiveContent
        }
    }
    
    private var archiveContent: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.leading)
                
                Text(date)
                    .font(.caption)
                    .foregroundColor(.gray.opacity(0.7))
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Spacer()
            
            Image(systemName: "archivebox.fill")
                .foregroundColor(.gray.opacity(0.6))
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.black.opacity(0.2))
        )
    }
}

// MARK: - Branded Primary Button (Global CTA)
struct BrandedPrimaryButton: View {
    var label: String
    var icon: String = "plus.circle.fill"
    var action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                Text(label)
                    .fontWeight(.semibold)
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.6, green: 0.2, blue: 0.8), // purple
                        Color(red: 0.8, green: 0.3, blue: 0.7)  // pink
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .foregroundColor(.white)
            .cornerRadius(10)
            .shadow(color: Color.black.opacity(0.25), radius: 8, x: 0, y: 4)
        }
        .padding(.horizontal)
    }
}

// MARK: - Branded Secondary Button (Sub Action)
struct BrandedSecondaryButton: View {
    var label: String
    var action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(label)
                .fontWeight(.medium)
                .padding(.vertical, 14)
                .padding(.horizontal, 24)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.black.opacity(0.1))
                        )
                )
        }
        .foregroundColor(.gray)
        .padding(.horizontal)
    }
}

// MARK: - Branded Modal Action Button (For modals with multiple actions)
struct BrandedModalActionButton: View {
    var label: String
    var style: ButtonStyle = .primary
    var action: () -> Void
    
    enum ButtonStyle {
        case primary
        case secondary
        case completion // For "That's a Wrap" style actions
        
        var backgroundColor: Color {
            switch self {
            case .primary:
                return Color(red: 0.6, green: 0.2, blue: 0.8) // Theme purple
            case .secondary:
                return Color.white.opacity(0.9)
            case .completion:
                return Color.orange.opacity(0.9)
            }
        }
        
        var foregroundColor: Color {
            switch self {
            case .primary:
                return .white
            case .secondary:
                return .black
            case .completion:
                return .white
            }
        }
    }
    
    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(style.foregroundColor)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .background(style.backgroundColor)
                .cornerRadius(8)
        }
    }
}

// MARK: - Preview Helpers
#Preview("BrandedRowCard") {
    VStack(spacing: 12) {
        BrandedRowCard(
            title: "Feature Film - The Midnight Hour",
            subtitle: "Premium Casting",
            roles: "Sarah Mitchell, Background Detective",
            sessionsCount: 2
        )
        
        BrandedRowCard(
            title: "Commercial – Running Shoes",
            subtitle: "",
            roles: "",
            sessionsCount: 1
        )
        
        BrandedArchiveRow(
            title: "Archived Project – Silver Lake Pilot",
            date: "Sept 2024"
        )
    }
    .padding()
    .background(BrandBackground())
}

#Preview("BrandedButtons") {
    VStack(spacing: 16) {
        BrandedPrimaryButton(label: "New Session") {}
        BrandedSecondaryButton(label: "Cancel") {}
    }
    .padding()
    .background(BrandBackground())
}
