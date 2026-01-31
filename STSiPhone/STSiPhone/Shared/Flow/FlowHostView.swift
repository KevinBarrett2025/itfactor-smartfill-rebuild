import SwiftUI

struct FlowHostView<Content: View>: View {
    @ObservedObject private var coordinator: FlowCoordinator
    private let content: Content
    private let destinationBuilder: (ActiveFlow) -> AnyView?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    init(
        coordinator: FlowCoordinator = .shared,
        @ViewBuilder content: () -> Content,
        @ViewBuilder destination: @escaping (ActiveFlow) -> AnyView? = FlowHostView.defaultDestination
    ) {
        self._coordinator = ObservedObject(wrappedValue: coordinator)
        self.content = content()
        self.destinationBuilder = destination
    }
    
    var body: some View {
        ZStack {
            content
                .zIndex(0)
            
            if let flowView = destinationBuilder(coordinator.activeFlow) {
                flowView
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.clear)
                    .ignoresSafeArea()
                    .transition(reduceMotion ? .identity : .opacity.combined(with: .scale))
                    .zIndex(5)
            }
            
            if coordinator.isProcessing {
                ProcessingOverlay()
                    .transition(.opacity)
                    .zIndex(10)
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.28), value: coordinator.activeFlow.id)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: coordinator.isProcessing)
    }
    
    private static func defaultDestination(for flow: ActiveFlow) -> AnyView? {
        switch flow {
        case .none:
            return nil
        case .takeReview(let payload):
            return payload?.makeView() ?? AnyView(FlowDestinationPlaceholder(flow: flow))
        case .editor(let payload):
            return payload?.makeView() ?? AnyView(FlowDestinationPlaceholder(flow: flow))
        case .smartFill(let payload):
            return payload?.makeView() ?? AnyView(FlowDestinationPlaceholder(flow: flow))
        case .player(let payload):
            return payload?.makeView() ?? AnyView(FlowDestinationPlaceholder(flow: flow))
        case .exportConfirm(let payload):
            return payload?.makeView() ?? AnyView(FlowDestinationPlaceholder(flow: flow))
        }
    }
}

// MARK: - Placeholder Destination

private struct FlowDestinationPlaceholder: View {
    let flow: ActiveFlow
    
    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Preparing \(title(for: flow))…")
                .font(.headline)
                .foregroundStyle(.white)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.5).ignoresSafeArea())
    }
    
    private func title(for flow: ActiveFlow) -> String {
        switch flow {
        case .none: return "flow"
        case .takeReview: return "review"
        case .editor: return "editor"
        case .smartFill: return "SmartFill"
        case .player: return "player"
        case .exportConfirm: return "export"
        }
    }
}
