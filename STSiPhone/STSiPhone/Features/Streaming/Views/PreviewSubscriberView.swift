import SwiftUI

/// Demo view for testing the preview subscriber (designed for macOS but works on iOS)
public struct PreviewSubscriberView: View {
    @StateObject private var subscriber = PreviewSubscriber()
    @State private var autoScroll = true
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            ZStack {
                BrandBackground()
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header
                    VStack(spacing: 16) {
                        VStack(spacing: 8) {
                            Image(systemName: "tv")
                                .font(.system(size: 40))
                                .foregroundStyle(Theme.primary)
                            
                            Text("Preview Subscriber")
                                .font(Theme.Font.title)
                                .foregroundStyle(Theme.textPrimary)
                            
                            Text("macOS preview client stub")
                                .font(Theme.Font.body)
                                .foregroundStyle(.gray)
                        }
                        
                        // Connection Status
                        HStack(spacing: 12) {
                            Circle()
                                .fill(subscriber.isConnected ? .green : .red)
                                .frame(width: 12, height: 12)
                            
                            Text(subscriber.connectionStatus)
                                .font(Theme.Font.body)
                                .foregroundStyle(Theme.textPrimary)
                            
                            Spacer()
                        }
                        .padding(.horizontal, 24)
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 16)
                    
                    // Current Message
                    STSCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Latest Message")
                                .font(Theme.Font.headline)
                                .foregroundStyle(Theme.textPrimary)
                            
                            Text(subscriber.lastMessage)
                                .font(Theme.Font.body)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(.horizontal, 24)
                    
                    // Session Info
                    if let session = subscriber.currentSession {
                        STSCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Active Session")
                                    .font(Theme.Font.headline)
                                    .foregroundStyle(Theme.textPrimary)
                                
                                HStack {
                                    Text("Type:")
                                        .font(Theme.Font.caption)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Text(session.sessionType.rawValue)
                                        .font(Theme.Font.body)
                                        .foregroundStyle(Theme.textPrimary)
                                }
                                
                                HStack {
                                    Text("Duration:")
                                        .font(Theme.Font.caption)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Text("\(Int(session.duration))s")
                                        .font(Theme.Font.body)
                                        .foregroundStyle(Theme.textPrimary)
                                }
                            }
                        }
                        .padding(.horizontal, 24)
                    }
                    
                    // Message History Header
                    HStack {
                        Text("Message History")
                            .font(Theme.Font.headline)
                            .foregroundStyle(Theme.textPrimary)
                        
                        Spacer()
                        
                        Button("Clear") {
                            subscriber.clearHistory()
                        }
                        .foregroundStyle(Theme.primary)
                        
                        Toggle("Auto-scroll", isOn: $autoScroll)
                            .toggleStyle(SwitchToggleStyle())
                            .scaleEffect(0.8)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                    
                    // Message History
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 8) {
                                ForEach(subscriber.messageHistory) { item in
                                    MessageHistoryRow(item: item)
                                        .id(item.id)
                                }
                            }
                            .padding(.horizontal, 24)
                            .padding(.bottom, 34)
                        }
                        .onChange(of: subscriber.messageHistory.count, initial: false) { _, newCount in
                            if autoScroll && newCount > 0 {
                                withAnimation(.easeOut(duration: 0.3)) {
                                    proxy.scrollTo(subscriber.messageHistory.last?.id, anchor: .bottom)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Preview Subscriber")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct MessageHistoryRow: View {
    let item: MessageHistoryItem
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Priority indicator
            Circle()
                .fill(priorityColor)
                .frame(width: 8, height: 8)
                .padding(.top, 6)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.message)
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Text(item.timeString)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Theme.surface.opacity(0.3))
        )
    }
    
    private var priorityColor: Color {
        switch item.priority {
        case .high:
            return .red
        case .medium:
            return .orange
        case .low:
            return .green
        }
    }
}

#Preview {
    PreviewSubscriberView()
}