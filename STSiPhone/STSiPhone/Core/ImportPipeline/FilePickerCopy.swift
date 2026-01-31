import Foundation

enum FilePickerCopyError: Error {
    case copyFailed(String)
}

enum FilePickerCopy {
    static func stagingURL(jobID: UUID, fileExtension: String) -> URL {
        let ext = fileExtension.isEmpty ? "mov" : fileExtension.lowercased()
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent("STS_FileImportStaging", isDirectory: true)
        return base.appendingPathComponent("STS_FileImport_\(jobID.uuidString).\(ext)")
    }

    static func copyToTemp(from pickedURL: URL, to destURL: URL) throws {
        ImportLog.files.info(
            "copy begin src=\(pickedURL.path, privacy: .public) dest=\(destURL.path, privacy: .public)"
        )
        let didAccess = pickedURL.startAccessingSecurityScopedResource()
        defer { if didAccess { pickedURL.stopAccessingSecurityScopedResource() } }
        ImportLog.files.info("security scope started=\(didAccess)")

        let fm = FileManager.default

        if fm.isUbiquitousItem(at: pickedURL) {
            ImportLog.files.info("ubiquitous item detected")
            let status = (try? pickedURL.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey]))?.ubiquitousItemDownloadingStatus
            if let status {
                ImportLog.files.info("ubiquitous status before download=\(status.rawValue, privacy: .public)")
            }
            try? fm.startDownloadingUbiquitousItem(at: pickedURL)
            let deadline = Date().addingTimeInterval(2.0)
            while Date() < deadline {
                let current = (try? pickedURL.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey]))?.ubiquitousItemDownloadingStatus
                if current == .current { break }
                Thread.sleep(forTimeInterval: 0.05)
            }
            let after = (try? pickedURL.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey]))?.ubiquitousItemDownloadingStatus
            if let after {
                ImportLog.files.info("ubiquitous status after download=\(after.rawValue, privacy: .public)")
            }
        }

        try fm.createDirectory(at: destURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        if fm.fileExists(atPath: destURL.path) {
            try fm.removeItem(at: destURL)
        }

        let coordinator = NSFileCoordinator()
        var coordinationError: NSError?
        var blockError: NSError?

        coordinator.coordinate(readingItemAt: pickedURL, options: [], error: &coordinationError) { coordinatedURL in
            do {
                try fm.copyItem(at: coordinatedURL, to: destURL)
            } catch {
                blockError = error as NSError
            }
        }

        if let blockError {
            coordinationError = blockError
        }
        if let coordinationError {
            ImportLog.files.error("copy failed: \(coordinationError.localizedDescription, privacy: .public)")
            throw FilePickerCopyError.copyFailed(coordinationError.localizedDescription)
        }

        let destSize = (try? destURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? -1
        if destSize <= 0 {
            ImportLog.files.error("copy produced empty file destSize=\(destSize)")
            throw FilePickerCopyError.copyFailed("Selected file could not be downloaded. Open it in Files to download, then try again.")
        }
        ImportLog.files.info("copy complete destSize=\(destSize)")
    }

    static func cleanupStagedFileIfNeeded(_ url: URL) {
        let stagingDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("STS_FileImportStaging", isDirectory: true)
        guard url.path.hasPrefix(stagingDir.path) else { return }
        try? FileManager.default.removeItem(at: url)
    }
}
