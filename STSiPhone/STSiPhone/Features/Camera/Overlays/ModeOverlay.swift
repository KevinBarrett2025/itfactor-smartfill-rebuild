import SwiftUI
import Combine

public final class ModeOverlayBus {
    public static let shared = ModeOverlayBus()
    private init() {}
    
    public let subject = PassthroughSubject<String, Never>()
    
    public func show(text: String) {
        subject.send(text)
    }
}

public struct ModeOverlayView: View {
    @State private var text: String?
    @State private var isVisible = false
    @State private var hideWorkItem: DispatchWorkItem?
    
    public init() {}
    
    public var body: some View {
        ZStack {
            if isVisible, let text {
                ZStack {
                    Color.black.opacity(0.85).ignoresSafeArea()
                    Text(text)
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding()
                }
                .transition(.opacity)
            }
        }
        .onReceive(ModeOverlayBus.shared.subject) { value in
            text = value
            hideWorkItem?.cancel()
            withAnimation(.easeIn(duration: 0.15)) {
                isVisible = true
            }
            scheduleHide()
        }
    }
    
    private func scheduleHide() {
        let workItem = DispatchWorkItem {
            withAnimation(.easeOut(duration: 0.25)) {
                isVisible = false
            }
        }
        hideWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: workItem)
    }
}
