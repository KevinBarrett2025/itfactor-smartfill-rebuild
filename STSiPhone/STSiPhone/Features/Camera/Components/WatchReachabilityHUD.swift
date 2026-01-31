import SwiftUI

public struct WatchReachabilityHUD: View {
    @ObservedObject private var bridge = WatchBridge.shared
    
    public init() {}
    
    private var isConnected: Bool {
        bridge.isSessionActive || bridge.isReachable || bridge.didReceiveWatchReady
    }
    
    public var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "applewatch")
                .imageScale(.medium)
            Text(isConnected ? "Connected" : "Not Connected")
                .font(.caption2)
                .bold(isConnected)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(isConnected ? Color.green.opacity(0.2) : Color.gray.opacity(0.2))
        .foregroundColor(isConnected ? .green : .secondary)
        .clipShape(Capsule())
        .overlay(
            Capsule().stroke(isConnected ? Color.green : Color.gray, lineWidth: 1)
        )
        .accessibilityLabel(
            Text("Apple Watch \(isConnected ? "connected" : "not connected")")
        )
    }
}

private extension View {
    @ViewBuilder func bold(_ active: Bool) -> some View {
        if active {
            self.fontWeight(.semibold)
        } else {
            self
        }
    }
}
