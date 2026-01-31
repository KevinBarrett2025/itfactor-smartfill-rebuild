import SwiftUI
import Combine

// MARK: - Active Flow Definitions

public enum ActiveFlow: Identifiable {
    case none
    case takeReview(payload: TakeReviewPayload? = nil)
    case editor(payload: EditorPayload? = nil)
    case smartFill(payload: SmartFillPayload? = nil)
    case player(payload: PlayerPayload? = nil)
    case exportConfirm(payload: ExportPayload? = nil)
    
    public var id: String {
        switch self {
        case .none: return "none"
        case .takeReview: return "takeReview"
        case .editor: return "editor"
        case .smartFill: return "smartFill"
        case .player: return "player"
        case .exportConfirm: return "exportConfirm"
        }
    }
}

public struct TakeReviewPayload {
    private let builder: () -> AnyView
    public init<Content: View>(@ViewBuilder builder: @escaping () -> Content) {
        self.builder = { AnyView(builder()) }
    }
    func makeView() -> AnyView { builder() }
}

public struct EditorPayload {
    private let builder: () -> AnyView
    public init<Content: View>(@ViewBuilder builder: @escaping () -> Content) {
        self.builder = { AnyView(builder()) }
    }
    func makeView() -> AnyView { builder() }
}

public struct SmartFillPayload {
    private let builder: () -> AnyView
    public init<Content: View>(@ViewBuilder builder: @escaping () -> Content) {
        self.builder = { AnyView(builder()) }
    }
    func makeView() -> AnyView { builder() }
}

public struct PlayerPayload {
    private let builder: () -> AnyView
    public init<Content: View>(@ViewBuilder builder: @escaping () -> Content) {
        self.builder = { AnyView(builder()) }
    }
    func makeView() -> AnyView { builder() }
}

public struct ExportPayload {
    private let builder: () -> AnyView
    public init<Content: View>(@ViewBuilder builder: @escaping () -> Content) {
        self.builder = { AnyView(builder()) }
    }
    func makeView() -> AnyView { builder() }
}

// MARK: - Coordinator

public final class FlowCoordinator: ObservableObject {
    public static let shared = FlowCoordinator()
    
    @Published public var activeFlow: ActiveFlow = .none
    @Published public var isProcessing: Bool = false
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {}
    
    // MARK: Presentation
    
    public func present(_ flow: ActiveFlow, animated: Bool = true) {
        if animated {
            withAnimation(.easeInOut(duration: 0.32)) {
                activeFlow = flow
            }
        } else {
            activeFlow = flow
        }
    }
    
    public func dismiss(animated: Bool = true) {
        if case .none = activeFlow { return }
        if animated {
            withAnimation(.easeInOut(duration: 0.28)) {
                activeFlow = .none
            }
        } else {
            activeFlow = .none
        }
    }
    
    public func transition(to: ActiveFlow,
                           viaProcessingOverlay: Bool = true,
                           processingDelay: TimeInterval = 0.45) {
        if viaProcessingOverlay {
            isProcessing = true
            withAnimation(.easeInOut(duration: 0.22)) {
                activeFlow = .none
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + processingDelay) { [weak self] in
                guard let self else { return }
                withAnimation(.easeInOut(duration: 0.32)) {
                    self.activeFlow = to
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.easeOut(duration: 0.2)) {
                        self.isProcessing = false
                    }
                }
            }
        } else {
            withAnimation(.easeInOut(duration: 0.3)) {
                activeFlow = to
            }
        }
    }
}
