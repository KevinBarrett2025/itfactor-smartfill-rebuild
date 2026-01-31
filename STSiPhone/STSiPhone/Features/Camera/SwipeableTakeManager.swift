import SwiftUI

struct SwipeableTakeManager: View {
    @ObservedObject var sessionManager = SessionManager.shared
    @State private var isHidden = false
    @State private var dragOffset: CGFloat = 0
    
    private let hideThreshold: CGFloat = 100
    
    var body: some View {
        ZStack(alignment: .trailing) {
            // Main take manager panel
            if !isHidden && !currentSceneTakes.isEmpty {
                VStack(spacing: 8) {
                    // Header with scene info
                    HStack {
                        Text(sessionManager.totalScenes > 1 ? "Scene \(sessionManager.currentScene) Takes" : "Takes")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.white.opacity(0.9))
                        
                        Spacer()
                        
                        // Hide button
                        Button(action: { hidePanel() }) {
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                    
                    // Takes list
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(spacing: 6) {
                            ForEach(currentSceneTakes.reversed()) { take in
                                TakeRowView(take: take)
                            }
                        }
                        .padding(.horizontal, 8)
                    }
                    .frame(maxHeight: 120)
                    .padding(.bottom, 8)
                }
                .background(Color.black.opacity(0.4))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
                .offset(x: dragOffset)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            // Only allow rightward drag
                            dragOffset = max(0, value.translation.width)
                        }
                        .onEnded { value in
                            if value.translation.width > hideThreshold {
                                hidePanel()
                            } else {
                                withAnimation(.easeOut(duration: 0.3)) {
                                    dragOffset = 0
                                }
                            }
                        }
                )
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
            
            // Show button when hidden
            if isHidden && !currentSceneTakes.isEmpty {
                VStack {
                    Button(action: { showPanel() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                            .frame(width: 32, height: 40)
                            .background(.ultraThinMaterial.opacity(0.8), in: RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                    }
                    
                    // Take count indicator
                    Text("\(currentSceneTakes.count)")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .frame(width: 20, height: 20)
                        .background(Color.blue.opacity(0.8), in: Circle())
                        .offset(y: -4)
                }
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .padding(.trailing, 16)
    }
    
    private var currentSceneTakes: [Take] {
        return sessionManager.getTakesForScene(sessionManager.currentScene)
    }
    
    private func hidePanel() {
        withAnimation(.easeInOut(duration: 0.4)) {
            isHidden = true
            dragOffset = 0
        }
    }
    
    private func showPanel() {
        withAnimation(.easeInOut(duration: 0.4)) {
            isHidden = false
        }
    }
}

#Preview {
    SwipeableTakeManager()
        .background(.black)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
}