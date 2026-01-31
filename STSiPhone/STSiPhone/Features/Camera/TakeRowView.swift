import SwiftUI

struct TakeRowView: View {
    let take: Take
    @ObservedObject var sessionManager = SessionManager.shared
    
    var body: some View {
        HStack(spacing: 6) {
            // Take name with timestamp
            VStack(alignment: .leading, spacing: 2) {
                Text(takeDisplayName)
                    .font(.caption2)
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text(timeAgo)
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.7))
            }
            
            // Status indicators - UNIFIED: Use TakeRating instead of individual booleans
            HStack(spacing: 4) {
                if take.rating == .finalSelect {
                    Image(systemName: "star.fill")
                        .font(.caption)
                        .foregroundColor(.yellow)
                }
                
                if take.rating == .option {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                }
                
                if take.rating == .rejected {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            
            Spacer()
            
            // Quick action buttons - UNIFIED: Use unified rating system
            HStack(spacing: 8) {
                // Final Select toggle
                Button(action: { 
                    let newRating: TakeRating = take.rating == .finalSelect ? .unrated : .finalSelect
                    updateTakeRating(newRating)
                }) {
                    Image(systemName: take.rating == .finalSelect ? "star.fill" : "star")
                        .font(.caption)
                        .foregroundColor(take.rating == .finalSelect ? .yellow : .white.opacity(0.6))
                }
                
                // Option toggle
                Button(action: { 
                    let newRating: TakeRating = take.rating == .option ? .unrated : .option
                    updateTakeRating(newRating)
                }) {
                    Image(systemName: take.rating == .option ? "checkmark.circle.fill" : "checkmark.circle")
                        .font(.caption)
                        .foregroundColor(take.rating == .option ? .green : .white.opacity(0.6))
                }
                
                // Rejected toggle
                Button(action: { 
                    let newRating: TakeRating = take.rating == .rejected ? .unrated : .rejected
                    updateTakeRating(newRating)
                }) {
                    Image(systemName: take.rating == .rejected ? "xmark.circle.fill" : "xmark.circle")
                        .font(.caption)
                        .foregroundColor(take.rating == .rejected ? .red : .white.opacity(0.6))
                }
                
                // Delete button
                Button(action: { 
                    withAnimation(.easeInOut(duration: 0.3)) {
                        sessionManager.delete(take)
                    }
                }) {
                    Image(systemName: "trash.circle")
                        .font(.caption)
                        .foregroundColor(.red.opacity(0.8))
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial.opacity(0.8), in: Capsule())
        .overlay(
            Capsule().stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
    }
    
    private var takeDisplayName: String {
        // Extract a cleaner name from fileName
        let name = take.fileName.replacingOccurrences(of: ".mov", with: "")
        if name.contains("_Take") {
            let components = name.components(separatedBy: "_Take")
            if components.count > 1 {
                return "Take \(components.last ?? "1")"
            }
        }
        return name
    }
    
    private var timeAgo: String {
        let timeInterval = Date().timeIntervalSince(take.createdAt)
        
        if timeInterval < 60 {
            return "\(Int(timeInterval))s ago"
        } else if timeInterval < 3600 {
            return "\(Int(timeInterval / 60))m ago"
        } else {
            return "\(Int(timeInterval / 3600))h ago"
        }
    }
    
    // UNIFIED: Helper method to update take ratings
    private func updateTakeRating(_ newRating: TakeRating) {
        // For legacy Take model, we need to find project/session context
        // This is a limitation - ideally we'd have that context
        // For now, use SessionManager's legacy methods but log the need for improvement
        
        switch newRating {
        case .finalSelect:
            sessionManager.toggleStar(take)
        case .option:
            sessionManager.toggleGood(take)
        case .rejected:
            sessionManager.markBad(take)
        case .unrated:
            sessionManager.resetRating(take)
        }
        
        print("✅ TakeRowView: Updated take rating to \(newRating.rawValue)")
    }
}

#Preview {
    let sampleTake = Take(
        segmentId: UUID(),
        fileName: "Scene1_Take3.mov",
        duration: 45.2,
        rating: .finalSelect
    )
    
    TakeRowView(take: sampleTake)
}
