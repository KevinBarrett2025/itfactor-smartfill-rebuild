import Foundation

final class SQLiteProjectsRepository: ProjectsRepository {
    private let store: ProjectsStoreSQLite
    private var projects: [Project]

    init(store: ProjectsStoreSQLite) {
        self.store = store
        self.projects = (try? store.fetchAllProjects()) ?? []
        print("📦 SQLiteProjectsRepository: loaded \(projects.count) projects from database")
    }

    // MARK: - Fetching

    func fetchProjects() -> [Project] {
        projects
    }

    func project(by id: UUID) -> Project? {
        projects.first { $0.id == id }
    }

    // MARK: - Project CRUD

    func updateProject(_ project: Project) {
        persist(project)
    }

    func insert(project: Project) {
        persist(project)
    }

    func delete(project: Project) {
        guard let index = projects.firstIndex(where: { $0.id == project.id }) else { return }
        projects.remove(at: index)
        do {
            try store.deleteProject(id: project.id)
        } catch {
            print("❌ SQLiteProjectsRepository: failed to delete project \(project.id) - \(error)")
        }
    }

    func toggleFavorite(project: Project) {
        mutate(projectID: project.id) { $0.isFavorite.toggle() }
    }

    func toggleArchive(project: Project) {
        mutate(projectID: project.id) { $0.isArchived.toggle() }
    }

    func toggleComplete(project: Project) {
        mutate(projectID: project.id) { $0.isCompleted.toggle() }
    }

    func exportProject(_ project: Project) {
        print("📦 SQLiteProjectsRepository: exportProject(\(project.id)) requested")
    }

    // MARK: - Archive (explicit APIs)

    func archiveProject(projectID: UUID, request: ArchiveRequest) async throws {
        try store.setProjectArchived(projectID: projectID, isArchived: true)
        mutate(projectID: projectID) { $0.isArchived = true }
        // Phase B: enqueue export work based on request.options
    }

    func unarchiveProject(projectID: UUID) async throws {
        try store.setProjectArchived(projectID: projectID, isArchived: false)
        mutate(projectID: projectID) { $0.isArchived = false }
    }

    func archiveSession(projectID: UUID, sessionID: UUID, request: ArchiveRequest) async throws {
        try store.setSessionArchived(projectID: projectID, sessionID: sessionID, isArchived: true)
        mutateSession(projectID: projectID, sessionID: sessionID) { $0.isArchived = true }
        // Phase B: enqueue export work based on request.options
    }

    func unarchiveSession(projectID: UUID, sessionID: UUID) async throws {
        try store.setSessionArchived(projectID: projectID, sessionID: sessionID, isArchived: false)
        mutateSession(projectID: projectID, sessionID: sessionID) { $0.isArchived = false }
    }

    func unarchiveAllProjects() async throws {
        try store.unarchiveAllProjects()
        for i in projects.indices {
            projects[i].isArchived = false
        }
    }

    // MARK: - Session CRUD

    func append(session: ProjectSession, to projectID: UUID) {
        mutate(projectID: projectID) { project in
            project.sessions.append(session)
        }
    }

    func updateSession(_ session: ProjectSession, in projectID: UUID) {
        mutate(projectID: projectID) { project in
            guard let index = project.sessions.firstIndex(where: { $0.id == session.id }) else { return }
            project.sessions[index] = session
        }
    }

    func updatePIPSlateSession(projectID: UUID, sessionID: UUID, pipSlateSession: SlatePIPSession?) {
        // Keep in-memory cache in sync without triggering a destructive project upsert.
        if let projectIndex = projects.firstIndex(where: { $0.id == projectID }),
           let sessionIndex = projects[projectIndex].sessions.firstIndex(where: { $0.id == sessionID }) {
            projects[projectIndex].sessions[sessionIndex].pipSlateSession = pipSlateSession
        }

        let json: String?
        if let pipSlateSession {
            do {
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                let data = try encoder.encode(pipSlateSession)
                json = String(data: data, encoding: .utf8)
            } catch {
                print("❌ SQLiteProjectsRepository: Failed to encode PiP slate session: \(error)")
                return
            }
        } else {
            json = nil
        }

        do {
            try store.updatePIPSlateSession(
                projectID: projectID,
                sessionID: sessionID,
                pipSlateSessionJSON: json
            )
        } catch {
            print("❌ SQLiteProjectsRepository: Failed to update PiP slate session in SQLite: \(error)")
        }
    }

    func deleteSession(sessionID: UUID, from projectID: UUID) {
        mutate(projectID: projectID) { project in
            project.sessions.removeAll { $0.id == sessionID }
        }
    }

    func updateSlatePrompt(_ prompt: String?, for sessionID: UUID, in projectID: UUID) {
        mutateSession(projectID: projectID, sessionID: sessionID) { session in
            session.slatePrompt = prompt
        }
    }

    func archiveSession(sessionID: UUID, in projectID: UUID) {
        mutateSession(projectID: projectID, sessionID: sessionID) { session in
            session.isArchived = true
        }
    }

    func unarchiveSession(sessionID: UUID, in projectID: UUID) {
        mutateSession(projectID: projectID, sessionID: sessionID) { session in
            session.isArchived = false
        }
    }

    func toggleSessionFavorite(sessionID: UUID, in projectID: UUID) {
        mutateSession(projectID: projectID, sessionID: sessionID) { session in
            session.isFavorite.toggle()
        }
    }

    func duplicateSession(sessionID: UUID, in projectID: UUID) {
        guard var project = project(by: projectID),
              let session = project.sessions.first(where: { $0.id == sessionID }) else { return }
        var duplicate = session
        duplicate.id = UUID()
        duplicate.takes = []
        project.sessions.append(duplicate)
        persist(project)
    }

    func exportSession(sessionID: UUID, from projectID: UUID) {
        print("📦 SQLiteProjectsRepository: exportSession \(sessionID)")
    }

    func exportSession(sessionID: UUID, projectID: UUID, takeIDs: [UUID]) {
        print("📦 SQLiteProjectsRepository: exportSession with takeIDs count \(takeIDs.count)")
    }

    // MARK: - Take CRUD

    func addTake(_ take: ProjectTake, to sessionID: UUID, in projectID: UUID) {
        mutateSession(projectID: projectID, sessionID: sessionID) { session in
            session.takes.append(take)
        }
    }

    func updateTake(_ take: ProjectTake, in sessionID: UUID, in projectID: UUID) {
        mutateTake(projectID: projectID, sessionID: sessionID, takeID: take.id) { existing in
            existing = take
        }
    }

    func deleteTake(_ take: ProjectTake, from sessionID: UUID, in projectID: UUID) {
        let projectSnapshot = project(by: projectID)
        var removedTake: ProjectTake?
        mutateSession(projectID: projectID, sessionID: sessionID) { session in
            if let index = session.takes.firstIndex(where: { $0.id == take.id }) {
                removedTake = session.takes.remove(at: index)
            }
        }
        guard let removedTake, let projectSnapshot else { return }
        cleanupDeletedTake(
            removedTake,
            sessionID: sessionID,
            projectID: projectID,
            projectSnapshot: projectSnapshot
        )
    }

    func deleteTake(takeID: UUID, from sessionID: UUID, in projectID: UUID) {
        let projectSnapshot = project(by: projectID)
        var removedTake: ProjectTake?
        mutateSession(projectID: projectID, sessionID: sessionID) { session in
            if let index = session.takes.firstIndex(where: { $0.id == takeID }) {
                removedTake = session.takes.remove(at: index)
            }
        }
        guard let removedTake, let projectSnapshot else { return }
        cleanupDeletedTake(
            removedTake,
            sessionID: sessionID,
            projectID: projectID,
            projectSnapshot: projectSnapshot
        )
    }

    func setUnifiedTakeRating(takeID: UUID, sessionID: UUID, projectID: UUID, rating: TakeRating) {
        mutateTake(projectID: projectID, sessionID: sessionID, takeID: takeID) { take in
            take.rating = rating
        }
    }

    func toggleTakeFavorite(takeID: UUID, in sessionID: UUID, of projectID: UUID) {
        mutateTake(projectID: projectID, sessionID: sessionID, takeID: takeID) { take in
            take.rating = take.rating == .option ? .unrated : .option
        }
    }

    func exportTake(takeID: UUID, from sessionID: UUID, in projectID: UUID) {
        print("📦 SQLiteProjectsRepository: exportTake \(takeID)")
    }

    func addTakeNote(takeID: UUID, in sessionID: UUID, of projectID: UUID, note: String) {
        mutateTake(projectID: projectID, sessionID: sessionID, takeID: takeID) { take in
            take.takeNotes = note
        }
    }

    // MARK: - Take Queries

    func takesForScene(_ sceneNumber: Int, in sessionID: UUID, in projectID: UUID) -> [ProjectTake] {
        guard let session = session(projectID: projectID, sessionID: sessionID) else { return [] }
        return session.takes.filter { $0.sceneNumber == sceneNumber }.sorted { $0.takeNumber < $1.takeNumber }
    }

    func takesByScene(in sessionID: UUID, in projectID: UUID) -> [Int: [ProjectTake]] {
        guard let session = session(projectID: projectID, sessionID: sessionID) else { return [:] }
        return Dictionary(grouping: session.takes, by: { $0.sceneNumber })
    }

    func maxSceneNumber(in sessionID: UUID, in projectID: UUID) -> Int {
        guard let session = session(projectID: projectID, sessionID: sessionID) else { return 1 }
        return session.takes.map { $0.sceneNumber }.max() ?? 1
    }

    func slateTakes(in sessionID: UUID, in projectID: UUID) -> [ProjectTake] {
        guard let session = session(projectID: projectID, sessionID: sessionID) else { return [] }
        return session.takes.filter { $0.takeType.isSlateLike }.sorted { $0.createdAt < $1.createdAt }
    }

    func keyframePhotoTakes(in sessionID: UUID, in projectID: UUID) -> [ProjectTake] {
        guard let session = session(projectID: projectID, sessionID: sessionID) else { return [] }
        return session.takes.filter { $0.takeNotes?.contains("keyframe") == true || $0.takeNotes?.contains("photo") == true }
    }

    func nextTakeNumber(for sceneNumber: Int, in sessionID: UUID, in projectID: UUID) -> Int {
        let takes = takesForScene(sceneNumber, in: sessionID, in: projectID)
        return (takes.map { $0.takeNumber }.max() ?? 0) + 1
    }

    func nextSlateNumber(in sessionID: UUID, in projectID: UUID) -> Int {
        let slates = slateTakes(in: sessionID, in: projectID)
        let numbers = slates.compactMap { $0.slateNumber }.compactMap { Int($0.filter(\.isNumber)) }
        return (numbers.max() ?? 0) + 1
    }

    // MARK: - SmartFill & Editing

    func saveMergedVideo(filePath: String, duration: Double, exportMetadata: ExportMetadata, to sessionID: UUID, in projectID: UUID) {
        let take = ProjectTake(
            filePath: normalizeToRelativePath(filePath),
            durationSeconds: duration,
            takeNotes: exportMetadata.exportType.displayName,
            exportMetadata: exportMetadata,
            takeType: .merged
        )
        addTake(take, to: sessionID, in: projectID)
    }

    func updateTakeWithSmartFillPath(takeID: UUID, smartFilledPath: String, in sessionID: UUID, in projectID: UUID) {
        mutateTake(projectID: projectID, sessionID: sessionID, takeID: takeID) { take in
            take.smartFilledFilePath = normalizeToRelativePath(smartFilledPath)
            ProjectTake.invalidateSmartFillCache(for: takeID)
        }
    }

    func getSmartFillStatus(for sessionID: UUID, in projectID: UUID) -> SmartFillSessionStatus {
        guard let session = session(projectID: projectID, sessionID: sessionID) else {
            return SmartFillSessionStatus()
        }
        let portrait = session.takes.filter { $0.capturedOrientation == .portrait }
        let smartFilled = portrait.filter { $0.hasSmartFilledVersion }
        let pending = portrait.filter { !$0.hasSmartFilledVersion }
        return SmartFillSessionStatus(
            totalPortraitTakes: portrait.count,
            smartFilledTakes: smartFilled.count,
            pendingTakes: pending.count,
            allPortraitTakes: portrait,
            needsProcessing: !pending.isEmpty
        )
    }

    func markTakeForBatchSmartFill(takeID: UUID, in sessionID: UUID, in projectID: UUID) {
        mutateTake(projectID: projectID, sessionID: sessionID, takeID: takeID) { take in
            let tag = "BATCH_SMARTFILL_PENDING"
            let notes = take.takeNotes ?? ""
            if !notes.contains(tag) {
                take.takeNotes = (notes + " " + tag).trimmingCharacters(in: .whitespaces)
            }
        }
    }

    func clearBatchSmartFillFlag(takeID: UUID, in sessionID: UUID, in projectID: UUID) {
        mutateTake(projectID: projectID, sessionID: sessionID, takeID: takeID) { take in
            if let notes = take.takeNotes?.replacingOccurrences(of: "BATCH_SMARTFILL_PENDING", with: "").trimmingCharacters(in: .whitespacesAndNewlines),
               !notes.isEmpty {
                take.takeNotes = notes
            } else {
                take.takeNotes = nil
            }
        }
    }

    func createStandaloneSmartFillTake(originalTakeID: UUID, smartFillPath: String, duration: Double, settings: SmartFillSettingsSnapshot?, in sessionID: UUID, in projectID: UUID) -> UUID? {
        guard var project = project(by: projectID),
              let sessionIndex = project.sessions.firstIndex(where: { $0.id == sessionID }),
              let takeIndex = project.sessions[sessionIndex].takes.firstIndex(where: { $0.id == originalTakeID }) else {
            return nil
        }

        let original = project.sessions[sessionIndex].takes[takeIndex]
        let relativePath = normalizeToRelativePath(smartFillPath)
        let metadataTag = "[SMARTFILL_ORIGINAL:\(originalTakeID.uuidString)]"
        let note = "\(metadataTag) SmartFill processed from original portrait video"
        let smartFillTake = ProjectTake(
            filePath: relativePath,
            durationSeconds: duration,
            takeNotes: note,
            videoMarkers: original.videoMarkers,
            rating: original.rating,
            sceneNumber: original.sceneNumber,
            takeNumber: original.takeNumber,
            slateNumber: original.slateNumber,
            slateID: original.slateID,
            capturedOrientation: .landscape,
            overrideSmartFill: .off,
            takeType: original.takeType,
            smartFillSettings: settings
        )

        project.sessions[sessionIndex].takes.append(smartFillTake)
        if var notes = original.takeNotes, !notes.contains(metadataTag) {
            notes.append(" \(metadataTag)")
            project.sessions[sessionIndex].takes[takeIndex].takeNotes = notes
        }
        persist(project)
        return smartFillTake.id
    }

    func createSmartFillTake(from takeID: UUID, fileURL: URL) {
        guard let context = locateTake(takeID: takeID) else { return }
        _ = createStandaloneSmartFillTake(
            originalTakeID: takeID,
            smartFillPath: fileURL.path,
            duration: context.take.durationSeconds,
            settings: nil,
            in: context.sessionID,
            in: context.projectID
        )
    }

    func loadSmartFillTakes(for takeID: UUID) -> [ProjectTake] {
        projects.flatMap { $0.sessions }.flatMap { $0.takes }.filter { take in
            guard take.id != takeID else { return false }
            return take.smartFilledFilePath != nil || take.filePath.lowercased().contains("_smartfill")
        }
    }

    func smartFillExists(for takeID: UUID, fileName: String) -> Bool {
        loadSmartFillTakes(for: takeID).contains { take in
            filename(of: take.smartFilledFilePath ?? take.filePath) == fileName
        }
    }

    func updateTakeEditMetadata(takeID: UUID, sessionID: UUID, projectID: UUID, editMetadata: TakeEditMetadata) {
        mutateTake(projectID: projectID, sessionID: sessionID, takeID: takeID) { take in
            take.editMetadata = editMetadata.hasEdits ? editMetadata : nil
        }
    }

    func updateTakeWithEditedVersion(takeID: UUID, sessionID: UUID, projectID: UUID, editedFilePath: String, editMetadata: TakeEditMetadata) {
        mutateTake(projectID: projectID, sessionID: sessionID, takeID: takeID) { take in
            let relative = normalizeToRelativePath(editedFilePath)
            let fileName = URL(fileURLWithPath: editedFilePath).lastPathComponent
            let tag = "Edited Version: \(fileName)"
            let existing = take.takeNotes ?? ""
            if !existing.contains(tag) {
                take.takeNotes = existing.isEmpty ? tag : "\(existing) • \(tag)"
            }
            take.editMetadata = editMetadata
            take.editedFilePath = relative
            take.lastExportDate = Date()
        }
    }

    func updateTakeOrientation(takeID: UUID, sessionID: UUID, projectID: UUID, newOrientation: VideoOrientation) {
        mutateTake(projectID: projectID, sessionID: sessionID, takeID: takeID) { take in
            take.capturedOrientation = newOrientation
            ProjectTake.invalidateSmartFillCache(for: takeID)
        }
    }

    func clearSmartFill(takeID: UUID, sessionID: UUID, projectID: UUID) {
        mutateTake(projectID: projectID, sessionID: sessionID, takeID: takeID) { take in
            if let path = take.smartFilledFilePath {
                let url = VideoVariantResolver.urlForRelativePath(path)
                try? FileManager.default.removeItem(at: url)
            }
            take.smartFilledFilePath = nil
            take.capturedOrientation = .portrait
            ProjectTake.invalidateSmartFillCache(for: takeID)
        }
    }

    // MARK: - Unified markers (stubbed)

    func getUnifiedVideoMarkers(for takeID: UUID, in sessionID: UUID, of projectID: UUID) -> [UnifiedVideoMarker] {
        []
    }

    func addUnifiedVideoMarker(_ marker: UnifiedVideoMarker, to takeID: UUID, in sessionID: UUID, of projectID: UUID) {
        print("📦 SQLiteProjectsRepository: addUnifiedVideoMarker (not yet persisted)")
    }

    func enableUnifiedModelSupport() {
        print("📦 SQLiteProjectsRepository: unified model support enabled")
    }

    // MARK: - Helpers

    private func persist(_ project: Project) {
        if let index = projects.firstIndex(where: { $0.id == project.id }) {
            projects[index] = project
        } else {
            projects.append(project)
        }
        do {
            try store.upsertProject(project)
        } catch {
            print("❌ SQLiteProjectsRepository: failed to persist project \(project.id) - \(error)")
        }
    }

    private func mutate(projectID: UUID, _ block: (inout Project) -> Void) {
        guard var project = project(by: projectID) else { return }
        block(&project)
        persist(project)
    }

    private func mutateSession(projectID: UUID, sessionID: UUID, _ block: (inout ProjectSession) -> Void) {
        mutate(projectID: projectID) { project in
            guard let index = project.sessions.firstIndex(where: { $0.id == sessionID }) else { return }
            block(&project.sessions[index])
        }
    }

    private func mutateTake(projectID: UUID, sessionID: UUID, takeID: UUID, _ block: (inout ProjectTake) -> Void) {
        mutate(projectID: projectID) { project in
            guard let sessionIndex = project.sessions.firstIndex(where: { $0.id == sessionID }),
                  let takeIndex = project.sessions[sessionIndex].takes.firstIndex(where: { $0.id == takeID }) else {
                return
            }
            var take = project.sessions[sessionIndex].takes[takeIndex]
            block(&take)
            project.sessions[sessionIndex].takes[takeIndex] = take
        }
    }

    private func session(projectID: UUID, sessionID: UUID) -> ProjectSession? {
        project(by: projectID)?.sessions.first { $0.id == sessionID }
    }

    private func locateTake(takeID: UUID) -> (projectID: UUID, sessionID: UUID, take: ProjectTake)? {
        for project in projects {
            for session in project.sessions {
                if let take = session.takes.first(where: { $0.id == takeID }) {
                    return (project.id, session.id, take)
                }
            }
        }
        return nil
    }

    private func normalizeToRelativePath(_ path: String) -> String {
        guard path.hasPrefix("/") else { return path }
        let url = URL(fileURLWithPath: path)
        return VideoVariantResolver.relativePath(from: url)
    }

    private func filename(of path: String) -> String {
        (path as NSString).lastPathComponent
    }

    private func cleanupDeletedTake(
        _ take: ProjectTake,
        sessionID: UUID,
        projectID: UUID,
        projectSnapshot: Project
    ) {
        let fileName = filename(of: take.filePath)
        Task {
            await ImportQueue.shared.removeJobs(
                matching: { job in
                    job.contextData.sessionID == sessionID && job.identifiers.fileName == fileName
                },
                deleteTempFiles: true
            )
        }

        var candidatePaths: [String] = []
        candidatePaths.append(take.filePath)
        if let editedPath = take.editedFilePath { candidatePaths.append(editedPath) }
        if let smartFillPath = take.smartFilledFilePath { candidatePaths.append(smartFillPath) }
        if let thumbnailPath = take.thumbnailPath { candidatePaths.append(thumbnailPath) }

        var seen: Set<String> = []
        for path in candidatePaths {
            let normalized = normalizePathForComparison(path)
            guard !normalized.isEmpty else { continue }
            guard !seen.contains(normalized) else { continue }
            seen.insert(normalized)

            if isPathShared(normalized, in: projectSnapshot, excluding: take.id) {
                continue
            }
            deleteFileIfExists(at: normalized)
        }
    }

    private func normalizePathForComparison(_ path: String) -> String {
        guard !path.isEmpty else { return "" }
        let url = path.hasPrefix("/") ? URL(fileURLWithPath: path) : VideoVariantResolver.urlForRelativePath(path)
        return url.standardizedFileURL.path
    }

    private func isPathShared(_ normalizedPath: String, in project: Project, excluding takeID: UUID) -> Bool {
        for session in project.sessions {
            for take in session.takes where take.id != takeID {
                let candidates = [
                    take.filePath,
                    take.editedFilePath,
                    take.smartFilledFilePath,
                    take.thumbnailPath
                ].compactMap { $0 }
                for candidate in candidates {
                    if normalizePathForComparison(candidate) == normalizedPath {
                        return true
                    }
                }
            }
        }
        return false
    }

    private func deleteFileIfExists(at normalizedPath: String) {
        let url = URL(fileURLWithPath: normalizedPath)
        guard FileManager.default.fileExists(atPath: url.path) else { return }

        let ext = url.pathExtension.lowercased()
        if ["mov", "mp4", "m4v"].contains(ext) {
            try? VideoFileManager.shared.deleteVideo(at: url.path)
        } else {
            try? FileManager.default.removeItem(at: url)
        }
#if DEBUG
        print("🧹 Deleted take asset: \(url.path)")
#endif
    }
}
