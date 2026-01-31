import Foundation
import SwiftUI
import PhotosUI

enum KeyframePhotoUploadIO {
    static func importKeyframePhotosFromFileURLs(
        _ urls: [URL],
        sceneNumber: Int,
        project: Project,
        session: ProjectSession,
        repository: ProjectsRepository
    ) async throws {
        for url in urls {
            let didStart = url.startAccessingSecurityScopedResource()
            defer { if didStart { url.stopAccessingSecurityScopedResource() } }

            var readError: NSError?
            var data: Data?

            let coordinator = NSFileCoordinator()
            coordinator.coordinate(readingItemAt: url, options: [], error: &readError) { coordinatedURL in
                data = try? Data(contentsOf: coordinatedURL)
            }

            if let readError { throw readError }
            guard let finalData = data else {
                throw NSError(
                    domain: "STS.KeyframeImport",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "Could not read selected file."]
                )
            }
            try await saveAndPersistPhoto(
                data: finalData,
                preferredExtension: url.pathExtension.isEmpty ? "jpg" : url.pathExtension,
                sceneNumber: sceneNumber,
                project: project,
                session: session,
                repository: repository
            )
        }
    }

    static func importKeyframePhotosFromPhotoPickerItems(
        _ items: [PhotosPickerItem],
        sceneNumber: Int,
        project: Project,
        session: ProjectSession,
        repository: ProjectsRepository
    ) async throws {
        for item in items {
            guard let data = try await item.loadTransferable(type: Data.self) else { continue }
            let ext = item.supportedContentTypes.first?.preferredFilenameExtension ?? "jpg"
            try await saveAndPersistPhoto(
                data: data,
                preferredExtension: ext,
                sceneNumber: sceneNumber,
                project: project,
                session: session,
                repository: repository
            )
        }
    }

    // MARK: - Helpers

    private static func saveAndPersistPhoto(
        data: Data,
        preferredExtension: String,
        sceneNumber: Int,
        project: Project,
        session: ProjectSession,
        repository: ProjectsRepository
    ) async throws {
        let savedURL = try savePhotoData(
            data: data,
            fileExtension: preferredExtension,
            projectID: project.id,
            sessionID: session.id,
            sceneNumber: sceneNumber
        )

        let relativePath = VideoVariantResolver.relativePath(from: savedURL)
        let keyframeSceneNumber = -1  // Use sentinel to mark keyframe photos
        let photoTakes = session.takes.filter { $0.durationSeconds == 0 && !$0.takeType.isSlateLike }
        let takeNumber = (photoTakes.map { $0.takeNumber }.max() ?? 0) + 1

        let take = ProjectTake(
            filePath: relativePath,
            durationSeconds: 0,
            takeNotes: "Keyframe photo (scene \(sceneNumber))",
            createdAt: Date(),
            sceneNumber: keyframeSceneNumber,
            takeNumber: takeNumber,
            takeType: .regular
        )

        await MainActor.run {
            repository.addTake(take, to: session.id, in: project.id)
        }
    }

    private static func savePhotoData(
        data: Data,
        fileExtension: String,
        projectID: UUID,
        sessionID: UUID,
        sceneNumber: Int
    ) throws -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let base = docs.appendingPathComponent("STS_Projects")
            .appendingPathComponent(projectID.uuidString)
            .appendingPathComponent(sessionID.uuidString)
            .appendingPathComponent("KeyframePhotos", isDirectory: true)

        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)

        let cleanExt = fileExtension.isEmpty ? "jpg" : fileExtension
        let fileName = "KeyframePhoto_scene\(sceneNumber)_\(UUID().uuidString.prefix(8)).\(cleanExt)"
        let destination = base.appendingPathComponent(fileName)

        try data.write(to: destination)
        return destination
    }
}
