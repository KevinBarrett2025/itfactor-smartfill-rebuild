import SwiftUI

/// SmartFill Status Indicator
/// Shows processing status and progress for SmartFill background jobs
struct SmartFillStatusIndicator: View {
    @StateObject private var processingManager = SmartFillProcessingManager.shared
    let sessionID: UUID
    
    @State private var showingJobsList = false
    @State private var animationOffset: CGFloat = 0
    @State private var showDetailedStatus = false // DEBUG: Toggle for detailed status
    
    var body: some View {
        let activeJobs = processingManager.getActiveJobs(for: sessionID)
        let completedJobs = processingManager.getCompletedJobs(for: sessionID)
        let statusSummary = processingManager.statusSummary
        
        if !activeJobs.isEmpty || statusSummary.failed > 0 || showDetailedStatus {
            VStack(spacing: 8) {
                // Main status indicator
                Button(action: { 
                    showingJobsList = true 
                    // DEBUG: Also toggle detailed status
                    showDetailedStatus.toggle()
                }) {
                    HStack(spacing: 8) {
                        // Animated processing icon
                        if statusSummary.processing > 0 {
                            Image(systemName: "waveform.path")
                                .foregroundStyle(Theme.primary)
                                .offset(x: animationOffset)
                                .animation(
                                    Animation.easeInOut(duration: 1.0)
                                        .repeatForever(autoreverses: true),
                                    value: animationOffset
                                )
                        } else if statusSummary.pending > 0 {
                            Image(systemName: "clock")
                                .foregroundStyle(.orange)
                        } else if statusSummary.failed > 0 {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundStyle(.red)
                        } else {
                            Image(systemName: "checkmark.circle")
                                .foregroundStyle(.green)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(statusText)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(Theme.textPrimary)
                            
                            // DEBUG: Show detailed status
                            if showDetailedStatus {
                                Text("Active: \(activeJobs.count), Completed: \(completedJobs.count)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            
                            if let currentJob = processingManager.currentJob,
                               currentJob.sessionID == sessionID {
                                Text(currentJob.fileName)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        
                        Spacer()
                        
                        // Progress indicator
                        if let currentJob = processingManager.currentJob,
                           currentJob.sessionID == sessionID,
                           currentJob.status == .processing {
                            CircularProgressView(progress: currentJob.progress)
                                .frame(width: 16, height: 16)
                        }
                        
                        // Queue count badge
                        if statusSummary.active > 1 || statusSummary.failed > 0 {
                            Text("\(statusSummary.active + statusSummary.failed)")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(statusSummary.failed > 0 ? .red : Theme.primary, in: Capsule())
                        }
                        
                        // DEBUG: Add debug indicator
                        if showDetailedStatus {
                            Image(systemName: "ladybug.fill")
                                .font(.caption2)
                                .foregroundStyle(.orange)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(PlainButtonStyle())
                
                // DEBUG: Show detailed job status
                if showDetailedStatus && (!activeJobs.isEmpty || !completedJobs.isEmpty) {
                    detailedJobStatus
                }
                
                // Resource constraints warning
                if processingManager.processingPaused {
                    resourceConstraintsWarning
                }
            }
            .onAppear {
                startAnimation()
            }
        }
    }
    
    // DEBUG: Detailed job status view
    @ViewBuilder
    private var detailedJobStatus: some View {
        let activeJobs = processingManager.getActiveJobs(for: sessionID)
        let completedJobs = processingManager.getCompletedJobs(for: sessionID)
        
        VStack(alignment: .leading, spacing: 4) {
            Text("DEBUG: SmartFill Job Status")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.orange)
            
            if !activeJobs.isEmpty {
                ForEach(activeJobs, id: \.id) { job in
                    HStack(spacing: 6) {
                        Image(systemName: job.status.iconName)
                            .font(.caption2)
                            .foregroundStyle(job.status.color)
                        
                        Text("\(job.fileName): \(job.status.displayName)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        
                        Spacer()
                        
                        if job.status == .processing {
                            Text("\(Int(job.progress * 100))%")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            
            if !completedJobs.isEmpty {
                Text("Completed: \(completedJobs.count) jobs")
                    .font(.caption2)
                    .foregroundStyle(.green)
            }
        }
        .padding(8)
        .background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
    }
    
    @ViewBuilder
    private var resourceConstraintsWarning: some View {
        HStack(spacing: 6) {
            Image(systemName: "pause.circle.fill")
                .foregroundStyle(.orange)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Processing Paused")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(.orange)
                
                Text(pauseReason)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
    }
    
    private var statusText: String {
        let summary = processingManager.statusSummary
        
        if summary.processing > 0 {
            return "Processing SmartFill..."
        } else if summary.pending > 0 {
            return "SmartFill Queued"
        } else if summary.failed > 0 {
            return "SmartFill Failed"
        } else {
            return "SmartFill Complete"
        }
    }
    
    private var pauseReason: String {
        if processingManager.batteryLevel < 0.20 {
            return "Low battery (\(Int(processingManager.batteryLevel * 100))%)"
        } else if processingManager.isLowPowerModeEnabled {
            return "Low power mode enabled"
        } else if processingManager.thermalState == .critical || processingManager.thermalState == .serious {
            return "Device too hot"
        } else {
            return "Resource constraints"
        }
    }
    
    private func startAnimation() {
        withAnimation {
            animationOffset = 3
        }
    }
}

/// Circular Progress View for SmartFill processing
struct CircularProgressView: View {
    let progress: Double
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.3), lineWidth: 2)
            
            Circle()
                .trim(from: 0, to: progress)
                .stroke(Theme.primary, lineWidth: 2)
                .rotationEffect(.degrees(-90))
        }
    }
}

/// SmartFill Jobs List Sheet
struct SmartFillJobsListView: View {
    @StateObject private var processingManager = SmartFillProcessingManager.shared
    let sessionID: UUID
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                BrandBackground()
                    .ignoresSafeArea()
                
                List {
                    let sessionJobs = processingManager.jobs.filter { $0.sessionID == sessionID }
                    
                    if sessionJobs.isEmpty {
                        ContentUnavailableView(
                            "No SmartFill Jobs",
                            systemImage: "rectangle.fill.badge.checkmark",
                            description: Text("SmartFill processing jobs will appear here")
                        )
                    } else {
                        ForEach(sessionJobs) { job in
                            SmartFillJobRow(job: job)
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("SmartFill Processing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

/// SmartFill Job Row
struct SmartFillJobRow: View {
    @StateObject private var processingManager = SmartFillProcessingManager.shared
    let job: SmartFillProcessingManager.SmartFillJob
    
    var body: some View {
        HStack(spacing: 12) {
            // Status icon
            Image(systemName: job.status.iconName)
                .font(.title3)
                .foregroundStyle(job.status.color)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(job.fileName)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    Text(job.status.displayName)
                        .font(.caption)
                        .foregroundStyle(job.status.color)
                    
                    if job.status == .processing {
                        Text("\(Int(job.progress * 100))%")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if job.retryCount > 0 {
                        Text("Retry \(job.retryCount)")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                    
                    Spacer()
                    
                    Text(RelativeDateTimeFormatter().localizedString(for: job.createdAt, relativeTo: Date()))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                
                if let error = job.lastError {
                    Text(error.localizedDescription)
                        .font(.caption2)
                        .foregroundStyle(.red)
                        .lineLimit(2)
                }
            }
            
            Spacer()
            
            // Progress indicator
            if job.status == .processing {
                CircularProgressView(progress: job.progress)
                    .frame(width: 20, height: 20)
            } else if job.status == .failed {
                Button("Retry") {
                    processingManager.retryJob(jobID: job.id)
                }
                .font(.caption)
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.red, in: Capsule())
            }
        }
        .padding(.vertical, 8)
        .listRowBackground(Color.clear)
    }
}

// MARK: - Extensions

extension SmartFillProcessingManager.SmartFillJob.JobStatus {
    var iconName: String {
        switch self {
        case .pending: return "clock"
        case .processing: return "waveform.path"
        case .completed: return "checkmark.circle.fill"
        case .failed: return "xmark.circle.fill"
        case .paused: return "pause.circle.fill"
        case .cancelled: return "minus.circle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .pending: return .orange
        case .processing: return Theme.primary
        case .completed: return .green
        case .failed: return .red
        case .paused: return .orange
        case .cancelled: return .gray
        }
    }
}

#Preview {
    SmartFillStatusIndicator(sessionID: UUID())
}
