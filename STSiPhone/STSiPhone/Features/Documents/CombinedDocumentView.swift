import SwiftUI
import PDFKit
import UIKit
import UniformTypeIdentifiers

struct CombinedDocumentView: View {
    let documents: [DocumentReference]
    let initialSelectedIndex: Int
    let onAddDocument: ((DocumentType) -> Void)?
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    @State private var selectedDocument: Int
    @State private var isLoading = true
    @State private var loadedDocuments: [LoadedDocument] = []
    
    private var theme: STSTheme { themeManager.current }
    
    init(documents: [DocumentReference], initialSelectedIndex: Int = 0, onAddDocument: ((DocumentType) -> Void)? = nil) {
        self.documents = documents
        self.initialSelectedIndex = min(max(initialSelectedIndex, 0), max(documents.count - 1, 0))
        self.onAddDocument = onAddDocument
        _selectedDocument = State(initialValue: self.initialSelectedIndex)
    }
    
    struct DocumentReference {
        let url: URL
        let title: String
        let type: DocumentType
    }
    
    enum DocumentType {
        case breakdown
        case sides
        case script
        case other(String)
        
        var displayName: String {
            switch self {
            case .breakdown: return "Breakdown"
            case .sides: return "Sides"
            case .script: return "Script"
            case .other(let name): return name
            }
        }
        
        var iconName: String {
            switch self {
            case .breakdown: return "doc.text"
            case .sides: return "theatermasks"
            case .script: return "doc.richtext"
            case .other: return "doc"
            }
        }
        
        var color: Color {
            switch self {
            case .breakdown: return .blue
            case .sides: return .purple
            case .script: return .green
            case .other: return .orange
            }
        }
    }
    
    private struct LoadedDocument {
        let reference: DocumentReference
        let content: DocumentContent
    }
    
    private enum DocumentContent {
        case pdf(PDFDocument)
        case text(String)
        case image(UIImage)
        case error(String)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                theme.backgroundGradient
                    .ignoresSafeArea()
                
                if isLoading {
                    loadingView
                } else {
                    VStack(spacing: 0) {
                        // Document Selector
                        documentSelector
                        
                        // Document Content
                        documentContentView
                    }
                }
            }
            .navigationTitle("Combined Documents")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(theme.textPrimary.opacity(0.85))
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !loadedDocuments.isEmpty, selectedDocument < loadedDocuments.count {
                        ShareButton(documentURL: loadedDocuments[selectedDocument].reference.url)
                    }
                }
            }
        }
        .task {
            await loadAllDocuments()
            clampSelection()
        }
        .onChange(of: loadedDocuments.count, initial: false) { _, _ in
            clampSelection()
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(theme.primaryAccent)
            
            Text("Loading documents...")
                .font(Theme.Font.body)
                .foregroundStyle(theme.textPrimary)
            
            Text("Combining \(documents.count) document\(documents.count == 1 ? "" : "s")")
                .font(Theme.Font.caption)
                .foregroundStyle(theme.textSecondary)
        }
    }
    
    private var documentSelector: some View {
        HStack(spacing: 12) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(0..<loadedDocuments.count, id: \.self) { index in
                        let document = loadedDocuments[index]
                        let isSelected = selectedDocument == index
                        let accent = document.reference.type.color
                        
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedDocument = index
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: document.reference.type.iconName)
                                    .font(.caption)
                                    .foregroundStyle(isSelected ? theme.textPrimary : accent)
                                
                                Text(document.reference.type.displayName)
                                    .font(.caption)
                                    .fontWeight(isSelected ? .semibold : .medium)
                                    .foregroundStyle(isSelected ? theme.textPrimary : accent)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(isSelected ? accent.opacity(0.85) : accent.opacity(0.12))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 20)
                                            .stroke(accent.opacity(0.35), lineWidth: 1)
                                    )
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 16)
            }
            
        }
        .padding(.vertical, 12)
        .background(
            theme.cardBackground
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(theme.cardStroke.opacity(0.6))
                }
        )
    }
    
    @ViewBuilder
    private var documentContentView: some View {
        if !loadedDocuments.isEmpty, selectedDocument < loadedDocuments.count {
            let selectedDoc = loadedDocuments[selectedDocument]
            
            switch selectedDoc.content {
            case .pdf(let pdfDocument):
                PDFPreviewView(pdfDocument: pdfDocument)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(theme.cardBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(theme.cardStroke.opacity(0.9), lineWidth: 1)
                            )
                    )
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                
            case .text(let textContent):
                TextPreviewView(content: textContent)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(theme.cardBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(theme.cardStroke.opacity(0.9), lineWidth: 1)
                            )
                    )
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                
            case .image(let image):
                DocumentImageView(image: image)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(theme.cardBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(theme.cardStroke.opacity(0.9), lineWidth: 1)
                            )
                    )
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                
            case .error(let errorMessage):
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 40))
                        .foregroundStyle(theme.primaryAccent)
                    
                    Text("Error loading document")
                        .font(Theme.Font.headline)
                        .foregroundStyle(theme.textPrimary)
                    
                    Text(errorMessage)
                        .font(Theme.Font.caption)
                        .foregroundStyle(theme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        } else if isLoading && !documents.isEmpty {
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.4)
                    .tint(theme.primaryAccent)
                
                Text("Fetching session documents…")
                    .font(Theme.Font.body)
                    .foregroundStyle(theme.textPrimary.opacity(0.9))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack(spacing: 16) {
                Image(systemName: "doc.questionmark")
                    .font(.system(size: 60))
                    .foregroundStyle(theme.textSecondary)
                
                Text("No documents available")
                    .font(Theme.Font.title)
                    .foregroundStyle(theme.textPrimary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    
    private struct DocumentImageView: View {
        let image: UIImage
        @EnvironmentObject private var themeManager: ThemeManager

        @State private var scale: CGFloat = 1.0
        @State private var lastScale: CGFloat = 1.0

        private var theme: STSTheme { themeManager.current }

        var body: some View {
            ScrollView([.horizontal, .vertical], showsIndicators: true) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    // Anchor zoom at the top so the image starts at the top of the view.
                    .scaleEffect(scale, anchor: .top)
                    .frame(maxWidth: .infinity, alignment: .top)
                    .padding(.top, 8)
                    .padding(.horizontal, 8)
                    .gesture(
                        MagnificationGesture()
                            .onChanged { value in
                                let clamped = min(max(lastScale * value, 0.5), 4.0)
                                scale = clamped
                            }
                            .onEnded { _ in
                                lastScale = scale
                            }
                    )
            }
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(theme.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(theme.cardStroke.opacity(0.9), lineWidth: 1)
                    )
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    
    private func loadAllDocuments() async {
        defer { isLoading = false }
        
        var loaded: [LoadedDocument] = []
        
        for document in documents {
            let hasAccess = document.url.startAccessingSecurityScopedResource()
            defer {
                if hasAccess {
                    document.url.stopAccessingSecurityScopedResource()
                }
            }
            
            do {
                let resourceValues = try document.url.resourceValues(forKeys: [.contentTypeKey])
                
                if let contentType = resourceValues.contentType {
                    if contentType.conforms(to: .pdf) {
                        if let pdfDocument = PDFDocument(url: document.url) {
                            loaded.append(LoadedDocument(
                                reference: document,
                                content: .pdf(pdfDocument)
                            ))
                        } else {
                            loaded.append(LoadedDocument(
                                reference: document,
                                content: .error("Invalid PDF file")
                            ))
                        }
                    } else if contentType.conforms(to: .text) || contentType.conforms(to: .plainText) {
                        let textContent = try String(contentsOf: document.url, encoding: .utf8)
                        loaded.append(LoadedDocument(
                            reference: document,
                            content: .text(textContent)
                        ))
                    } else if contentType.conforms(to: .image) {
                        if let image = loadImage(from: document.url) {
                            loaded.append(LoadedDocument(
                                reference: document,
                                content: .image(image)
                            ))
                        } else {
                            loaded.append(LoadedDocument(
                                reference: document,
                                content: .error("Unsupported image format")
                            ))
                        }
                    } else {
                        loaded.append(LoadedDocument(
                            reference: document,
                            content: .error("Unsupported file type")
                        ))
                    }
                } else {
                    // Fallback by extension
                    let pathExtension = document.url.pathExtension.lowercased()
                    
                    switch pathExtension {
                    case "pdf":
                        if let pdfDocument = PDFDocument(url: document.url) {
                            loaded.append(LoadedDocument(
                                reference: document,
                                content: .pdf(pdfDocument)
                            ))
                        } else {
                            loaded.append(LoadedDocument(
                                reference: document,
                                content: .error("Invalid PDF file")
                            ))
                        }
                    case "txt":
                        let textContent = try String(contentsOf: document.url, encoding: .utf8)
                        loaded.append(LoadedDocument(
                            reference: document,
                            content: .text(textContent)
                        ))
                    case "png", "jpg", "jpeg", "heic", "heif":
                        if let image = loadImage(from: document.url) {
                            loaded.append(LoadedDocument(
                                reference: document,
                                content: .image(image)
                            ))
                        } else {
                            loaded.append(LoadedDocument(
                                reference: document,
                                content: .error("Unsupported image format")
                            ))
                        }
                    default:
                        loaded.append(LoadedDocument(
                            reference: document,
                            content: .error("Unsupported file type")
                        ))
                    }
                }
            } catch {
                loaded.append(LoadedDocument(
                    reference: document,
                    content: .error("Error loading: \(error.localizedDescription)")
                ))
            }
        }
        
        await MainActor.run {
            loadedDocuments = loaded
        }
    }
}

// MARK: - Helper Extensions
private extension CombinedDocumentView {
    func clampSelection() {
        if loadedDocuments.isEmpty {
            selectedDocument = 0
        } else {
            selectedDocument = min(max(selectedDocument, 0), loadedDocuments.count - 1)
        }
    }
    
    func triggerAddDocument(_ type: DocumentType, onAddDocument: @escaping (DocumentType) -> Void) {
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            onAddDocument(type)
        }
    }
    
    func loadImage(from url: URL) -> UIImage? {
        if let image = UIImage(contentsOfFile: url.path) {
            return image
        }
        if let data = try? Data(contentsOf: url) {
            return UIImage(data: data)
        }
        return nil
    }
}

extension CombinedDocumentView.DocumentType {
    static func from(fileName: String) -> CombinedDocumentView.DocumentType {
        let lowercased = fileName.lowercased()
        
        if lowercased.contains("breakdown") {
            return .breakdown
        } else if lowercased.contains("sides") {
            return .sides
        } else if lowercased.contains("script") {
            return .script
        } else {
            return .other(fileName)
        }
    }
}

extension CombinedDocumentView.DocumentType: Equatable {
    static func == (lhs: CombinedDocumentView.DocumentType, rhs: CombinedDocumentView.DocumentType) -> Bool {
        switch (lhs, rhs) {
        case (.breakdown, .breakdown),
             (.sides, .sides),
             (.script, .script):
            return true
        case (.other(let l), .other(let r)):
            return l == r
        default:
            return false
        }
    }
}

#Preview {
    CombinedDocumentView(documents: [
        CombinedDocumentView.DocumentReference(
            url: URL(fileURLWithPath: "/path/to/breakdown.pdf"),
            title: "Character Breakdown",
            type: .breakdown
        ),
        CombinedDocumentView.DocumentReference(
            url: URL(fileURLWithPath: "/path/to/sides.pdf"),
            title: "Scene Sides",
            type: .sides
        )
    ], initialSelectedIndex: 0)
    .environmentObject(ThemeManager())
}
