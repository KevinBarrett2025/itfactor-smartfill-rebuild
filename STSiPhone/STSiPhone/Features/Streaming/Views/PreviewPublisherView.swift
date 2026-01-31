import SwiftUI

/// Demo view for testing the preview publisher on iOS
public struct PreviewPublisherView: View {
    @StateObject private var publisher = PreviewPublisher()
    @State private var customMessage = ""
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            ZStack {
                BrandBackground()
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        VStack(spacing: 8) {
                            Image(systemName: "dot.radiowaves.left.and.right")
                                .font(.system(size: 60))
                                .foregroundStyle(Theme.primary)
                            
                            Text("Preview Publisher")
                                .font(Theme.Font.title)
                                .foregroundStyle(Theme.textPrimary)
                            
                            Text("iOS → macOS streaming stub")
                                .font(Theme.Font.body)
                                .foregroundStyle(.gray)
                        }
                        .padding(.top, 20)
                        
                        // Status Card
                        STSCard {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Image(systemName: publisher.status.systemImage)
                                        .foregroundStyle(statusColor)
                                    Text("Status")
                                        .font(Theme.Font.headline)
                                        .foregroundStyle(Theme.textPrimary)
                                    Spacer()
                                    Text(publisher.status.description)
                                        .font(Theme.Font.body)
                                        .foregroundStyle(statusColor)
                                }
                                
                                if publisher.isPublishing {
                                    Divider()
                                    
                                    HStack {
                                        Text("Messages Sent:")
                                            .font(Theme.Font.caption)
                                            .foregroundStyle(.secondary)
                                        Spacer()
                                        Text("\(publisher.messageCount)")
                                            .font(Theme.Font.body)
                                            .foregroundStyle(Theme.textPrimary)
                                    }
                                    
                                    if let duration = publisher.publishingDuration {
                                        HStack {
                                            Text("Duration:")
                                                .font(Theme.Font.caption)
                                                .foregroundStyle(.secondary)
                                            Spacer()
                                            Text("\(Int(duration))s")
                                                .font(Theme.Font.body)
                                                .foregroundStyle(Theme.textPrimary)
                                        }
                                    }
                                }
                            }
                        }
                        
                        // Session Info Card
                        if let sessionInfo = publisher.sessionInfo {
                            STSCard {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Current Session")
                                        .font(Theme.Font.headline)
                                        .foregroundStyle(Theme.textPrimary)
                                    
                                    HStack {
                                        Text("Type:")
                                            .font(Theme.Font.caption)
                                            .foregroundStyle(.secondary)
                                        Spacer()
                                        Text(sessionInfo.sessionType.rawValue)
                                            .font(Theme.Font.body)
                                            .foregroundStyle(Theme.textPrimary)
                                    }
                                    
                                    HStack {
                                        Text("Duration:")
                                            .font(Theme.Font.caption)
                                            .foregroundStyle(.secondary)
                                        Spacer()
                                        Text("\(Int(sessionInfo.duration))s")
                                            .font(Theme.Font.body)
                                            .foregroundStyle(Theme.textPrimary)
                                    }
                                    
                                    HStack {
                                        Text("Session ID:")
                                            .font(Theme.Font.caption)
                                            .foregroundStyle(.secondary)
                                        Spacer()
                                        Text(sessionInfo.sessionID.uuidString.prefix(8))
                                            .font(Theme.Font.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                        
                        // Controls Card
                        STSCard {
                            VStack(spacing: 16) {
                                Text("Controls")
                                    .font(Theme.Font.headline)
                                    .foregroundStyle(Theme.textPrimary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                
                                // Use branded buttons for controls
                                VStack(spacing: 12) {
                                    if publisher.isPublishing {
                                        BrandedSecondaryButton(label: "Stop") {
                                            publisher.stopPublishing()
                                        }
                                    } else {
                                        BrandedPrimaryButton(
                                            label: "Start",
                                            icon: "play.fill"
                                        ) {
                                            let testSession = ProjectSession(type: .selfTape, notes: "Test session")
                                            publisher.startPublishing(for: testSession)
                                        }
                                    }
                                    
                                    BrandedSecondaryButton(label: "Send Test Frame") {
                                        publisher.sendTestFrame()
                                    }
                                    // Disable this button when not publishing
                                    .opacity(publisher.isPublishing ? 1.0 : 0.6)
                                }
                                
                                // Custom Message
                                VStack(spacing: 8) {
                                    TextField("Custom message", text: $customMessage)
                                        .textFieldStyle(.roundedBorder)
                                    
                                    BrandedSecondaryButton(label: "Send Message") {
                                        if !customMessage.isEmpty {
                                            publisher.sendTextMessage(customMessage)
                                            customMessage = ""
                                        }
                                    }
                                    .opacity((!publisher.isPublishing || customMessage.isEmpty) ? 0.6 : 1.0)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 34)
                }
            }
            .navigationTitle("Preview Publisher")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private var statusColor: Color {
        switch publisher.status {
        case .idle:
            return .gray
        case .connecting:
            return .orange
        case .publishing:
            return .green
        case .error:
            return .red
        }
    }
}

#Preview {
    PreviewPublisherView()
}
