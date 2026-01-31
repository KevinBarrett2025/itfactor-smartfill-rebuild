import SwiftUI

struct ImportStatusIndicator: View {
    @StateObject private var importStore = ImportStore.shared
    @EnvironmentObject private var themeManager: ThemeManager
    let sessionID: UUID
    
    @State private var showingJobsList = false
    
    private var theme: STSTheme { themeManager.current }
    
    var body: some View {
        let activeJobs = importStore.activeJobs(for: sessionID)
        let failedJobs = importStore.failedJobs(for: sessionID)
        let totalCount = activeJobs.count + failedJobs.count
        
        if totalCount > 0 {
            Button {
                showingJobsList = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: statusIconName(activeCount: activeJobs.count, failedCount: failedJobs.count))
                        .foregroundStyle(statusIconColor(activeCount: activeJobs.count, failedCount: failedJobs.count))
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(statusText(activeJobs: activeJobs, failedCount: failedJobs.count))
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(theme.textPrimary)
                        
                        if let current = activeJobs.first {
                            Text(current.displayName)
                                .font(.caption2)
                                .foregroundStyle(theme.textSecondary)
                                .lineLimit(1)
                        }
                    }
                    
                    Spacer()
                    
                    if let current = activeJobs.first {
                        if let progress = current.progress, progress > 0 && progress < 1 {
                            ProgressView(value: progress)
                                .frame(width: 60)
                        } else {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                    }
                    
                    if totalCount > 1 || failedJobs.count > 0 {
                        Text("\(totalCount)")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(failedJobs.isEmpty ? theme.primaryAccent : .red, in: Capsule())
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $showingJobsList) {
                ImportJobsListView(sessionID: sessionID)
            }
        }
    }
    
    private func statusText(activeJobs: [ImportJob], failedCount: Int) -> String {
        let activeCount = activeJobs.count
        if activeCount > 0 {
            let photoCount = activeJobs.filter { $0.identifiers.isKeyframePhoto }.count
            let videoCount = activeCount - photoCount
            if photoCount > 0 && videoCount > 0 {
                return "Importing \(activeCount) items"
            }
            if photoCount > 0 {
                return "Importing \(photoCount) photo\(photoCount == 1 ? "" : "s")"
            }
            return "Importing \(videoCount) video\(videoCount == 1 ? "" : "s")"
        }
        if failedCount > 0 {
            return "Import failed"
        }
        return "Import queue"
    }
    
    private func statusIconName(activeCount: Int, failedCount: Int) -> String {
        if failedCount > 0 { return "exclamationmark.triangle.fill" }
        if activeCount > 0 { return "arrow.down.circle.fill" }
        return "checkmark.circle.fill"
    }
    
    private func statusIconColor(activeCount: Int, failedCount: Int) -> Color {
        if failedCount > 0 { return .red }
        if activeCount > 0 { return theme.primaryAccent }
        return .green
    }
}

struct ImportJobsListView: View {
    @StateObject private var importStore = ImportStore.shared
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    let sessionID: UUID
    
    private var theme: STSTheme { themeManager.current }
    
    var body: some View {
        let jobs = importStore.jobs.filter { $0.contextData.sessionID == sessionID }
        
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 12) {
                    if jobs.isEmpty {
                        Text("No imports yet.")
                            .font(.caption)
                            .foregroundStyle(theme.textSecondary)
                            .padding(.top, 24)
                    } else {
                        ForEach(jobs) { job in
                            ImportJobRowView(job: job)
                        }
                    }
                }
                .padding(.horizontal, Theme.Layout.screenPadding)
                .padding(.top, 16)
            }
            .navigationTitle("Import Queue")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(theme.textPrimary)
                    }
                }
            }
        }
    }
}

struct ImportJobRowView: View {
    @StateObject private var importStore = ImportStore.shared
    @EnvironmentObject private var themeManager: ThemeManager
    let job: ImportJob
    
    private var theme: STSTheme { themeManager.current }
    
    var body: some View {
        STSCard(elevation: .subtle) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: iconName(for: job.phase))
                        .foregroundStyle(iconColor(for: job.phase))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(job.displayName)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(theme.textPrimary)
                            .lineLimit(1)
                        Text(job.phase.displayName)
                            .font(.caption2)
                            .foregroundStyle(theme.textSecondary)
                    }
                    Spacer()
                    actionButton
                }
                
                if job.phase.isActive {
                    if let progress = job.progress, progress > 0 {
                        ProgressView(value: progress)
                            .progressViewStyle(.linear)
                    } else {
                        ProgressView()
                            .progressViewStyle(.linear)
                    }
                }
                
                if job.phase == .failed, let failure = job.failure {
                    Text(failure.message)
                        .font(.caption2)
                        .foregroundStyle(.red)
                        .lineLimit(2)
                }
            }
            .padding(.vertical, 4)
        }
    }
    
    @ViewBuilder
    private var actionButton: some View {
        switch job.phase {
        case .failed:
            Button {
                importStore.retry(jobID: job.id)
            } label: {
                Image(systemName: "arrow.clockwise")
                    .foregroundStyle(theme.primaryAccent)
            }
            .buttonStyle(.plain)
            
        case .queued, .preparing, .downloading, .copying, .saving, .processing, .verifying:
            Button {
                importStore.cancel(jobID: job.id)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
            
        case .ready, .canceled:
            EmptyView()
        }
    }
    
    private func iconName(for phase: ImportPhase) -> String {
        switch phase {
        case .failed:
            return "exclamationmark.triangle.fill"
        case .ready:
            return "checkmark.circle.fill"
        case .canceled:
            return "xmark.circle.fill"
        case .downloading:
            return "arrow.down.circle.fill"
        case .copying, .saving, .processing, .verifying, .queued, .preparing:
            return "arrow.down.doc"
        }
    }
    
    private func iconColor(for phase: ImportPhase) -> Color {
        switch phase {
        case .failed:
            return .red
        case .ready:
            return .green
        case .canceled:
            return .orange
        case .downloading:
            return .blue
        default:
            return theme.primaryAccent
        }
    }
}
