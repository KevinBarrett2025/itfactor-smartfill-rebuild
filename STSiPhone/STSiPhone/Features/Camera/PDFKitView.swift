import SwiftUI
import PDFKit

// MARK: - PDFKit UIViewRepresentable
// RESTORED: Professional PDF viewing for script synchronization
struct PDFKitView: UIViewRepresentable {
    let pdfDocument: PDFDocument
    @Binding var currentPage: Int
    
    init(pdfDocument: PDFDocument, currentPage: Binding<Int> = .constant(0)) {
        self.pdfDocument = pdfDocument
        self._currentPage = currentPage
    }
    
    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.document = pdfDocument
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        
        // Configure for professional script viewing
        pdfView.backgroundColor = UIColor.white
        pdfView.usePageViewController(true, withViewOptions: nil)
        pdfView.minScaleFactor = 0.5
        pdfView.maxScaleFactor = 4.0
        pdfView.pageBreakMargins = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        
        return pdfView
    }
    
    func updateUIView(_ pdfView: PDFView, context: Context) {
        // Update current page if needed - with bounds checking
        if let document = pdfView.document,
           currentPage >= 0,
           currentPage < document.pageCount,
           let page = document.page(at: currentPage) {
            pdfView.go(to: page)
        }
    }
}

// MARK: - Simplified initializer
extension PDFKitView {
    init(pdfDocument: PDFDocument) {
        self.init(pdfDocument: pdfDocument, currentPage: .constant(0))
    }
}