import SwiftUI

/// SmartFill Job Row View
/// Displays individual SmartFill processing job status with controls
struct SmartFillJobRowView: View {
    @StateObject private var processingManager = SmartFillProcessingManager.shared
    let job: SmartFillProcessingManager.SmartFillJob
    
    var body: some View {
        HStack(spacing: 12) {
            // Status icon with animation for processing jobs
            ZStack {
                Image(systemName: job.status.iconName)
                    .font(.title3)
                    .foregroundStyle(job.status.color)
                    .frame(width: 24)
                
                if job.status == .processing {
                    Circle()
                        .stroke(job.status.color.opacity(0.3), lineWidth: 2)
                        .frame(width: 28, height: 28)
                        .overlay(
                            Circle()
                                .trim(from: 0, to: job.progress)
                                .stroke(job.status.color, lineWidth: 2)
                                .rotationEffect(.degrees(-90))
                        )
                        .animation(.linear(duration: 0.3), value: job.progress)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                // File name with take information
                HStack {
                    Text(job.fileName)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Text(timeAgo(from: job.createdAt))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                
                // Status and progress information
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
                    
                    // Orientation indicator
                    if let orientation = job.capturedOrientation {
                        Text("• \(orientation.displayName)")
                            .font(.caption2)
                            .foregroundStyle(orientation == .portrait ? .orange : .gray)
                    }
                    
                    Spacer()
                    
                    // File size estimate
                    if let fileSize = estimateFileSize() {
                        Text(ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                
                // Error message if failed
                if let error = job.lastError {
                    Text(error.localizedDescription)
                        .font(.caption2)
                        .foregroundStyle(.red)
                        .lineLimit(2)
                        .padding(.top, 2)
                }
                
                // Resource constraints indicator
                if job.status == .paused {
                    HStack(spacing: 4) {
                        Image(systemName: "pause.circle.fill")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                        Text("Paused due to resource constraints")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                    .padding(.top, 2)
                }
            }
            
            Spacer()
            
            // Action controls
            VStack(spacing: 6) {
                if job.status == .processing {
                    // Show progress indicator
                    CircularProgressView(progress: job.progress)
                        .frame(width: 20, height: 20)
                } else if job.status == .failed {
                    // Retry button
                    Button("Retry") {
                        processingManager.retryJob(jobID: job.id)
                    }
                    .font(.caption)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.red, in: Capsule())
                } else if job.status == .completed {
                    // Success indicator
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.green)
                } else if job.status == .pending {
                    // Pending indicator
                    Text("Queued")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.orange.opacity(0.2), in: Capsule())
                }
            }
        }
        .padding(.vertical, 8)
    }
    
    private func timeAgo(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 60 { return "now" }
        else if interval < 3600 { return "\(Int(interval / 60))m ago" }
        else { return "\(Int(interval / 3600))h ago" }
    }
    
    private func estimateFileSize() -> Int64? {
        if FileManager.default.fileExists(atPath: job.originalPath) {
            return (try? FileManager.default.attributesOfItem(atPath: job.originalPath)[.size] as? Int64)
        }
        return nil
    }
}

#Preview {
    List {
        SmartFillJobRowView(job: SmartFillProcessingManager.SmartFillJob(
            originalPath: "/path/to/video.mov",
            outputPath: "/path/to/video_smartfill.mov", // FIXED: Use consistent _smartfill.mov naming
            fileName: "Sample_Video.mov",
            takeID: UUID(),
            sessionID: UUID(),
            projectID: UUID(),
            capturedOrientation: .portrait,
            settings: SmartFillSettings(),
            createdAt: Date(),
            settingsSnapshot: SmartFillSettingsSnapshot(
                isEnabled: true,
                blurRadius: 24,
                darkenAmount: 0.12,
                backgroundScale: 10,
                foregroundScale: 1,
                renderWidth: 1920,
                renderHeight: 1080,
                processingPriority: SmartFillSettings.ProcessingPriority.userInitiated.rawValue,
                presetName: nil
            )
        ))
    }
}
