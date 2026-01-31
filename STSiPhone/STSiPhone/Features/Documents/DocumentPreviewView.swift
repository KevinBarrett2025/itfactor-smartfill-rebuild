import SwiftUI
import PDFKit
import UniformTypeIdentifiers
import UIKit

struct DocumentPreviewView: View {
    let documentURL: URL
    let documentTitle: String
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    @State private var documentContent: DocumentContent?
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    private var theme: STSTheme { themeManager.current }
    
    private enum DocumentContent {
        case pdf(PDFDocument)
        case text(String)
        case image(UIImage)
        case unsupported
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                theme.backgroundGradient
                    .ignoresSafeArea()
                
                if isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(theme.primaryAccent)
                        
                        Text("Loading document...")
                            .font(Theme.Font.body)
                            .foregroundStyle(theme.textPrimary)
                    }
                } else if let errorMessage = errorMessage {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 60))
                            .foregroundStyle(theme.primaryAccent)
                        
                        Text("Unable to load document")
                            .font(Theme.Font.title)
                            .foregroundStyle(theme.textPrimary)
                        
                        Text(errorMessage)
                            .font(Theme.Font.body)
                            .foregroundStyle(theme.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                } else {
                    documentContentView
                }
            }
            .navigationTitle(documentTitle)
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
                
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    if documentContent != nil {
                        PrintButton(documentURL: documentURL, documentTitle: documentTitle)
                        ShareButton(documentURL: documentURL)
                    }
                }
            }
        }
        .task {
            await loadDocument()
        }
    }
    
    @ViewBuilder
    private var documentContentView: some View {
        switch documentContent {
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
            ZoomableImagePreview(image: image, theme: theme)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            
        case .unsupported:
            VStack(spacing: 16) {
                Image(systemName: "doc.questionmark")
                    .font(.system(size: 60))
                    .foregroundStyle(theme.primaryAccent)
                
                Text("Unsupported file type")
                    .font(Theme.Font.title)
                    .foregroundStyle(theme.textPrimary)
                
                Text("This file type cannot be previewed, but you can still share it.")
                    .font(Theme.Font.body)
                    .foregroundStyle(theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
        case .none:
            EmptyView()
        }
    }
    
    private func loadDocument() async {
        defer { isLoading = false }
        
        // Check if file exists and is accessible
        let needsAccess = documentURL.startAccessingSecurityScopedResource()
        defer {
            if needsAccess {
                documentURL.stopAccessingSecurityScopedResource()
            }
        }
        
        do {
            // Determine file type
            let resourceValues = try documentURL.resourceValues(forKeys: [.contentTypeKey])
            
            if let contentType = resourceValues.contentType {
                if contentType.conforms(to: .pdf) {
                    // Load PDF
                    if let pdfDocument = PDFDocument(url: documentURL) {
                        documentContent = .pdf(pdfDocument)
                    } else {
                        errorMessage = "Invalid or corrupted PDF file."
                    }
                } else if contentType.conforms(to: .text) || contentType.conforms(to: .plainText) {
                    // Load text file
                    let textContent = try String(contentsOf: documentURL, encoding: .utf8)
                    documentContent = .text(textContent)
                } else if contentType.conforms(to: .image) {
                    if let image = loadImage(from: documentURL) {
                        documentContent = .image(image)
                    } else {
                        documentContent = .unsupported
                    }
                } else {
                    documentContent = .unsupported
                }
            } else {
                // Fallback: try to determine by file extension
                let pathExtension = documentURL.pathExtension.lowercased()
                
                switch pathExtension {
                case "pdf":
                    if let pdfDocument = PDFDocument(url: documentURL) {
                        documentContent = .pdf(pdfDocument)
                    } else {
                        errorMessage = "Invalid or corrupted PDF file."
                    }
                case "txt":
                    let textContent = try String(contentsOf: documentURL, encoding: .utf8)
                    documentContent = .text(textContent)
                case "png", "jpg", "jpeg", "heic", "heif":
                    if let image = loadImage(from: documentURL) {
                        documentContent = .image(image)
                    } else {
                        documentContent = .unsupported
                    }
                default:
                    documentContent = .unsupported
                }
            }
        } catch {
            errorMessage = "Error loading document: \(error.localizedDescription)"
        }
    }
    
    private func loadImage(from url: URL) -> UIImage? {
        if let image = UIImage(contentsOfFile: url.path) {
            return image
        }
        if let data = try? Data(contentsOf: url) {
            return UIImage(data: data)
        }
        return nil
    }
}

struct PDFPreviewView: View {
    let pdfDocument: PDFDocument
    
    var body: some View {
        DocumentPDFView(pdfDocument: pdfDocument)
            .background(Color.clear)
    }
}

struct DocumentPDFView: UIViewRepresentable {
    let pdfDocument: PDFDocument
    
    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.document = pdfDocument
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.backgroundColor = .clear
        pdfView.pageShadowsEnabled = false
        return pdfView
    }
    
    func updateUIView(_ pdfView: PDFView, context: Context) {
        pdfView.document = pdfDocument
    }
}

struct TextPreviewView: View {
    let content: String
    @State private var fontSize: Double = 16
    @EnvironmentObject private var themeManager: ThemeManager
    
    private var theme: STSTheme { themeManager.current }
    
    var body: some View {
        VStack(spacing: 0) {
            // Font size controls
            HStack {
                Text("Text Size")
                    .font(.caption)
                    .foregroundStyle(theme.textSecondary)
                
                Spacer()
                
                HStack(spacing: 16) {
                    Button {
                        fontSize = max(12, fontSize - 2)
                    } label: {
                        Image(systemName: "textformat.size.smaller")
                            .font(.caption)
                            .foregroundStyle(fontSize > 12 ? theme.primaryAccent : theme.textSecondary.opacity(0.6))
                    }
                    .disabled(fontSize <= 12)
                    
                    Text("\(Int(fontSize))")
                        .font(.caption)
                        .foregroundStyle(theme.textPrimary)
                        .frame(minWidth: 20)
                    
                    Button {
                        fontSize = min(24, fontSize + 2)
                    } label: {
                        Image(systemName: "textformat.size.larger")
                            .font(.caption)
                            .foregroundStyle(fontSize < 24 ? theme.primaryAccent : theme.textSecondary.opacity(0.6))
                    }
                    .disabled(fontSize >= 24)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(theme.cardBackground.opacity(0.85))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(theme.cardStroke.opacity(0.5), lineWidth: 1)
                    )
            )
            .padding(.bottom, 12)
            
            // Text content
            ScrollView {
                Text(content)
                    .font(.system(size: fontSize))
                    .foregroundStyle(theme.textPrimary)
                    .multilineTextAlignment(.leading)
                    .lineSpacing(4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(theme.cardBackground.opacity(0.9))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(theme.cardStroke.opacity(0.4), lineWidth: 1)
                            )
                    )
            }
        }
    }
}

private struct ZoomableImagePreview: View {
    let image: UIImage
    let theme: STSTheme

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0

    var body: some View {
        ScrollView([.horizontal, .vertical], showsIndicators: true) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .scaleEffect(scale, anchor: .top)
                .frame(maxWidth: .infinity, alignment: .top)
                .padding(.top, 8)
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
    }
}

struct ShareButton: View {
    let documentURL: URL
    @State private var showShareSheet = false
    @EnvironmentObject private var themeManager: ThemeManager
    
    var body: some View {
        Button {
            showShareSheet = true
        } label: {
            Image(systemName: "square.and.arrow.up")
                .font(.title2)
                .foregroundStyle(themeManager.current.textPrimary.opacity(0.85))
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(activityItems: [documentURL])
        }
    }
}

struct PrintButton: View {
    let documentURL: URL
    let documentTitle: String
    @State private var showPrintSheet = false
    @EnvironmentObject private var themeManager: ThemeManager
    
    var body: some View {
        Button {
            showPrintSheet = true
        } label: {
            Image(systemName: "printer")
                .font(.title2)
                .foregroundStyle(themeManager.current.textPrimary.opacity(0.85))
        }
        .sheet(isPresented: $showPrintSheet) {
            PrintSheetController(documentURL: documentURL, documentTitle: documentTitle)
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let activityViewController = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )
        return activityViewController
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct PrintSheetController: UIViewControllerRepresentable {
    let documentURL: URL
    let documentTitle: String
    
    func makeUIViewController(context: Context) -> PrintHostViewController {
        PrintHostViewController(documentURL: documentURL, documentTitle: documentTitle)
    }
    
    func updateUIViewController(_ uiViewController: PrintHostViewController, context: Context) {}
}

final class PrintHostViewController: UIViewController {
    private let documentURL: URL
    private let documentTitle: String
    private var hasPresented = false
    
    init(documentURL: URL, documentTitle: String) {
        self.documentURL = documentURL
        self.documentTitle = documentTitle
        super.init(nibName: nil, bundle: nil)
        view.backgroundColor = .clear
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        presentPrinter()
    }
    
    private func presentPrinter() {
        guard !hasPresented else { return }
        hasPresented = true
        guard let data = try? Data(contentsOf: documentURL) else {
            dismiss(animated: true)
            return
        }
        let controller = UIPrintInteractionController()
        controller.printingItem = data
        let info = UIPrintInfo(dictionary: nil)
        info.outputType = .general
        info.jobName = documentTitle
        controller.printInfo = info
        controller.present(animated: true) { [weak self] _, _, _ in
            self?.dismiss(animated: true)
        }
    }
}

#Preview {
    // Create a sample text file for preview
    if let sampleURL = Bundle.main.url(forResource: "sample", withExtension: "txt") {
        DocumentPreviewView(documentURL: sampleURL, documentTitle: "Sample Document")
            .environmentObject(ThemeManager())
    } else {
        Text("No sample document available")
    }
}
