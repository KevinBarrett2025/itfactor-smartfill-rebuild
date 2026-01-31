import Foundation

enum PhotoImportIO {
    static func buildImportedTake(
        tempURL: URL,
        identifiers: ImportIdentifiers,
        contextData: ImportContextData
    ) async throws -> ProjectTake {
        let destination = try savePhotoFile(
            from: tempURL,
            fileName: identifiers.fileName,
            projectID: contextData.projectID,
            sessionID: contextData.sessionID
        )
        let relativePath = VideoVariantResolver.relativePath(from: destination)
        let sceneLabel = max(1, identifiers.sceneNumber)

        return ProjectTake(
            filePath: relativePath,
            durationSeconds: 0,
            takeNotes: "Keyframe photo (scene \(sceneLabel))",
            createdAt: Date(),
            sceneNumber: -1,
            takeNumber: identifiers.takeNumber,
            takeType: .regular
        )
    }

    private static func savePhotoFile(
        from source: URL,
        fileName: String,
        projectID: UUID,
        sessionID: UUID
    ) throws -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let directory = docs.appendingPathComponent("STS_Projects")
            .appendingPathComponent(projectID.uuidString)
            .appendingPathComponent(sessionID.uuidString)
            .appendingPathComponent("KeyframePhotos", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let destination = directory.appendingPathComponent(fileName)
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.copyItem(at: source, to: destination)
        return destination
    }
}
