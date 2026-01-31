import SwiftUI

/// Export header with editable filename, thumbnail preview, and format toggle
struct ExportHeaderView: View {
    @Binding var filename: String
    @Binding var thumbnail: UIImage?
    @Binding var selectedFormat: OutputFormat
    
    @State private var isEditingFilename = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Thumbnail Preview Section
            HStack(spacing: 16) {
                // Thumbnail preview
                Group {
                    if let thumbnail = thumbnail {
                        Image(uiImage: thumbnail)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.white.opacity(0.1))
                            .overlay {
                                Image(systemName: "film")
                                    .font(.title2)
                                    .foregroundColor(.gray)
                            }
                    }
                }
                .frame(width: 80, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Export Preview")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text("Thumbnail will be generated from your final selected (⭐) photo")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
            }
            
            // Filename Editor Section
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Filename")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    // Format Toggle Buttons
                    HStack(spacing: 8) {
                        ForEach(OutputFormat.allCases, id: \.self) { format in
                            Button(action: { selectedFormat = format }) {
                                Text(format.rawValue.uppercased())
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(selectedFormat == format ? Theme.primary : Color.white.opacity(0.1))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 6)
                                                    .stroke(selectedFormat == format ? Theme.primary : Color.white.opacity(0.3), lineWidth: 1)
                                            )
                                    )
                                    .foregroundColor(selectedFormat == format ? .white : .secondary)
                            }
                        }
                    }
                }
                
                // Filename Input Field
                HStack {
                    TextField("Enter filename", text: $filename)
                        .font(.body)
                        .textFieldStyle(PlainTextFieldStyle())
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.white.opacity(0.05))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(isEditingFilename ? Theme.primary : Color.white.opacity(0.2), lineWidth: 1)
                                )
                        )
                        .foregroundColor(.white)
                        .onTapGesture {
                            isEditingFilename = true
                        }
                        .onSubmit {
                            isEditingFilename = false
                        }
                    
                    Text(".\(selectedFormat.rawValue.lowercased())")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .padding(.leading, 4)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
}

#Preview {
    VStack {
        ExportHeaderView(
            filename: .constant("TestProject_SelfTape_20241004"),
            thumbnail: .constant(nil),
            selectedFormat: .constant(.mp4)
        )
        .padding()
    }
    .background(BrandBackground())
}
