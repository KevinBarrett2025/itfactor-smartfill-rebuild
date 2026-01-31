import Foundation
import SwiftUI

/// Observable store for export results data - fixes SwiftUI sheet closure capture issues
class ExportResultsStore: ObservableObject {
    @Published var exportedFiles: [ExportedFile] = []
    @Published var project: Project?
    @Published var session: ProjectSession?
    @Published var originalTakes: [EnhancedTake] = []
    @Published var repository: ProjectsRepository?
    @Published var isDataReady: Bool = false
    @Published var estimatedTotal: String?
    
    func setExportResults(
        files: [ExportedFile],
        project: Project,
        session: ProjectSession,
        originalTakes: [EnhancedTake],
        repository: ProjectsRepository,
        estimatedTotal: String? = nil
    ) {
        print("📦 ExportResultsStore: Setting export results with \(files.count) files")
        for (index, file) in files.enumerated() {
            print("📦 ExportResultsStore: File \(index + 1): \(file.filename), size: \(file.formattedFileSize), isMultiTake: \(file.isMultiTake)")
        }
        
        self.exportedFiles = files
        self.project = project
        self.session = session
        self.originalTakes = originalTakes
        self.repository = repository
        self.estimatedTotal = estimatedTotal
        self.isDataReady = true
        
        print("📦 ExportResultsStore: Data ready = true")
    }
    
    func clear() {
        print("📦 ExportResultsStore: Clearing data")
        exportedFiles = []
        project = nil
        session = nil
        originalTakes = []
        repository = nil
        isDataReady = false
    }
}
