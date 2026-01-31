import Foundation

@MainActor
final class ImportStore: ObservableObject {
    static let shared = ImportStore()
    
    @Published private(set) var jobs: [ImportJob] = []
    @Published private(set) var lastCompletion: ImportCompletion?
    
    private var repository: ProjectsRepository?
    
    private init() {
        Task { await listenForEvents() }
    }
    
    func configure(with repository: ProjectsRepository) {
        self.repository = repository
    }
    
    func activeJobs(for sessionID: UUID) -> [ImportJob] {
        jobs.filter { $0.contextData.sessionID == sessionID && $0.isActive }
    }
    
    func failedJobs(for sessionID: UUID) -> [ImportJob] {
        jobs.filter { $0.contextData.sessionID == sessionID && $0.phase == .failed }
    }
    
    func cancel(jobID: UUID) {
        if let existing = jobs.first(where: { $0.id == jobID }) {
            var updated = existing
            updated.phase = .canceled
            updated.progress = nil
            updated.failure = ImportFailure(code: .canceled, message: "Canceled by user.")
            updated.updatedAt = Date()
            upsert(job: updated)
        }
        Task { await ImportQueue.shared.cancel(jobID: jobID) }
    }
    
    func retry(jobID: UUID) {
        Task { await ImportQueue.shared.retry(jobID: jobID) }
    }

    func registerEnqueuedJob(_ job: ImportJob) {
        upsert(job: job)
    }
    
    private func listenForEvents() async {
        let stream = await ImportQueue.shared.subscribe()
        for await event in stream {
            switch event {
            case .jobUpdated(let job):
                upsert(job: job)
                
            case .jobCompleted(let job, let take):
                upsert(job: job)
                if let repository {
                    repository.addTake(take, to: job.contextData.sessionID, in: job.contextData.projectID)
                }
                lastCompletion = ImportCompletion(
                    jobID: job.id,
                    sessionID: job.contextData.sessionID,
                    projectID: job.contextData.projectID,
                    take: take
                )
                
            case .jobRemoved(let jobID):
                removeJob(jobID: jobID)
            }
        }
    }
    
    private func upsert(job: ImportJob) {
        if let index = jobs.firstIndex(where: { $0.id == job.id }) {
            jobs[index] = job
        } else {
            jobs.append(job)
        }
        jobs.sort { $0.updatedAt > $1.updatedAt }
    }

    private func removeJob(jobID: UUID) {
        jobs.removeAll { $0.id == jobID }
        if let completion = lastCompletion, completion.jobID == jobID {
            lastCompletion = nil
        }
    }
}
