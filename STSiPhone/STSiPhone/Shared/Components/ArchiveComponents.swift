import SwiftUI

// MARK: - Typed archive models (shared by UI and repository)

public enum ArchiveOptionType: String, Codable, CaseIterable, Hashable {
    case exportVideos
    case exportMetadata

    public var title: String {
        switch self {
        case .exportVideos: return "Export Videos"
        case .exportMetadata: return "Metadata"
        }
    }

    public var description: String {
        switch self {
        case .exportVideos:
            return "Include video files in an export bundle (future phase)"
        case .exportMetadata:
            return "Include project/session/take details (future phase)"
        }
    }

    public var icon: String {
        switch self {
        case .exportVideos: return "film"
        case .exportMetadata: return "doc.text"
        }
    }
}

public struct ArchiveRequest: Codable, Hashable {
    public var options: Set<ArchiveOptionType>
    public static let `default` = ArchiveRequest(options: [.exportVideos, .exportMetadata])

    public init(options: Set<ArchiveOptionType>) {
        self.options = options
    }
}

/// UI option model (bridges typed option to view state)
struct ArchiveOption: Identifiable {
    let id = UUID()
    let type: ArchiveOptionType
    var isSelected: Bool = false

    var title: String { type.title }
    var description: String { type.description }
    var icon: String { type.icon }
}

// MARK: - Archive Options Panel
struct ArchiveOptionsPanel: View {
    @Binding var request: ArchiveRequest
    let options: [ArchiveOption]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Archive Options")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.primary)
            
            ForEach(options) { option in
                ArchiveOptionRow(
                    option: option,
                    isSelected: request.options.contains(option.type)
                ) {
                    toggle(option.type)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }

    private func toggle(_ type: ArchiveOptionType) {
        if request.options.contains(type) {
            request.options.remove(type)
        } else {
            request.options.insert(type)
        }
    }
}

// MARK: - Archive Option Row
struct ArchiveOptionRow: View {
    let option: ArchiveOption
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: option.icon)
                    .font(.caption)
                    .foregroundStyle(isSelected ? .blue : .gray)
                    .frame(width: 16)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(option.title)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                    
                    Text(option.description)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.caption)
                    .foregroundStyle(isSelected ? .blue : .gray)
            }
            .padding(.vertical, 6)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Archive Action Button
struct ArchiveActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .foregroundStyle(color)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(color.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(color.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Default Archive Options
extension ArchiveOption {
    static let defaultProjectArchiveOptions: [ArchiveOption] = [
        ArchiveOption(type: .exportVideos, isSelected: true),
        ArchiveOption(type: .exportMetadata, isSelected: true)
    ]
    
    static let defaultSessionArchiveOptions: [ArchiveOption] = [
        ArchiveOption(type: .exportVideos, isSelected: true),
        ArchiveOption(type: .exportMetadata, isSelected: true)
    ]
}

#Preview {
    VStack(spacing: 20) {
        ArchiveOptionsPanel(
            request: .constant(.default),
            options: ArchiveOption.defaultProjectArchiveOptions
        )
        
        HStack(spacing: 12) {
            ArchiveActionButton(
                title: "Archive Project",
                icon: "archivebox.fill",
                color: .blue
            ) {}
            
            ArchiveActionButton(
                title: "Delete Project",
                icon: "trash.fill",
                color: .red
            ) {}
        }
    }
    .padding()
    .background(Color(.systemBackground))
}
