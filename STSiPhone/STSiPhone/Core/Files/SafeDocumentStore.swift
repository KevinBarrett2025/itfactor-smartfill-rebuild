import Foundation
import UniformTypeIdentifiers

enum SafeDocumentStore {
    /// Copies a picked file (Files/iCloud) into the app's Documents and returns the local URL + fileName.
    /// Handles security-scoped access, iCloud download, and file coordination.
    static func importFromPicker(url: URL, preferredName: String? = nil, subfolder: String? = nil) throws -> (localURL: URL, fileName: String) {
        let fm = FileManager.default
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first!
        let baseDir = (subfolder != nil) ? docs.appendingPathComponent(subfolder!, isDirectory: true) : docs

        if subfolder != nil && !fm.fileExists(atPath: baseDir.path) {
            try fm.createDirectory(at: baseDir, withIntermediateDirectories: true)
        }

        let stop = url.startAccessingSecurityScopedResource()
        defer { if stop { url.stopAccessingSecurityScopedResource() } }

        // Ensure iCloud files are local
        if fm.isUbiquitousItem(at: url) {
            try? fm.startDownloadingUbiquitousItem(at: url)
            // Light wait loop (bounded) for small docs
            let deadline = Date().addingTimeInterval(3.0)
            while Date() < deadline {
                let values = try? url.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey])
                if values?.ubiquitousItemDownloadingStatus == URLUbiquitousItemDownloadingStatus.current { break }
                RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.05))
            }
        }

        var suggestedName = preferredName ?? url.lastPathComponent
        if suggestedName.isEmpty { suggestedName = "Imported-\(UUID().uuidString.prefix(6))" }

        var destURL = baseDir.appendingPathComponent(suggestedName)
        // Avoid collisions
        if fm.fileExists(atPath: destURL.path) {
            let stem = destURL.deletingPathExtension().lastPathComponent
            let ext = destURL.pathExtension
            let uniqued = "\(stem)_\(Int(Date().timeIntervalSince1970)).\(ext.isEmpty ? "dat" : ext)"
            destURL = baseDir.appendingPathComponent(uniqued)
        }

        var readError: NSError?
        var data: Data?

        let coordinator = NSFileCoordinator()
        coordinator.coordinate(readingItemAt: url, options: [], error: &readError) { (readingURL) in
            data = try? Data(contentsOf: readingURL, options: [.mappedIfSafe])
        }
        if let readError { throw readError }

        guard let blob = data, !blob.isEmpty else {
            throw NSError(domain: "STS.SafeDocumentStore", code: -10, userInfo: [NSLocalizedDescriptionKey: "Could not read source data"])
        }

        try blob.write(to: destURL, options: [.atomic])

        return (destURL, destURL.lastPathComponent)
    }
    
    /// Writes raw data into the app's Documents directory and returns the saved URL + file name.
    /// Useful for assets coming from PhotosPicker or custom generators.
    static func save(data: Data, preferredFileName: String, subfolder: String? = nil) throws -> (localURL: URL, fileName: String) {
        guard !data.isEmpty else {
            throw NSError(domain: "STS.SafeDocumentStore", code: -20, userInfo: [NSLocalizedDescriptionKey: "No data to save"])
        }
        
        let fm = FileManager.default
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first!
        let baseDir = (subfolder != nil) ? docs.appendingPathComponent(subfolder!, isDirectory: true) : docs
        
        if subfolder != nil && !fm.fileExists(atPath: baseDir.path) {
            try fm.createDirectory(at: baseDir, withIntermediateDirectories: true)
        }
        
        var sanitizedName = preferredFileName.isEmpty ? "Imported-\(UUID().uuidString.prefix(6))" : preferredFileName
        if sanitizedName.contains("/") {
            sanitizedName = sanitizedName.replacingOccurrences(of: "/", with: "-")
        }
        
        var destURL = baseDir.appendingPathComponent(sanitizedName)
        if fm.fileExists(atPath: destURL.path) {
            let stem = destURL.deletingPathExtension().lastPathComponent
            let ext = destURL.pathExtension
            let uniqued = "\(stem)_\(Int(Date().timeIntervalSince1970)).\(ext.isEmpty ? "dat" : ext)"
            destURL = baseDir.appendingPathComponent(uniqued)
        }
        
        try data.write(to: destURL, options: [.atomic])
        return (destURL, destURL.lastPathComponent)
    }
}
