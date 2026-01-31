import SwiftUI

/// Minimal, HIG-safe loader with an SF Symbol and a circular ring.
/// - Shows indeterminate spin when `progress == nil`.
/// - Shows determinate ring when `progress` in [0,1].
/// - Auto-hides under a minimum display if the job finishes instantly.
public struct MiniProcessingBadge: View {
    public enum Icon: String {
        case clapper = "clapperboard.fill"
        case sparkles = "sparkles"
        case smartFill = "person.and.background.dotted"
        case video = "video.fill"
        case export = "square.and.arrow.up"
    }
    
    // CONTROL
    @Binding private var isVisible: Bool
    private var icon: Icon
    private var progress: Double?            // nil = indeterminate
    private var size: CGFloat                // overall diameter
    private var lineWidth: CGFloat
    private var minimumDisplay: Double       // seconds to avoid flash
    private var title: String?              // optional title below badge

    // INTERNAL
    @State private var appearDate: Date?
    @State private var shouldShow = false
    @State private var spin = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    public init(
        isVisible: Binding<Bool>,
        icon: Icon = .clapper,
        progress: Double? = nil,
        size: CGFloat = 64,
        lineWidth: CGFloat = 4,
        minimumDisplay: Double = 0.35,
        title: String? = nil
    ) {
        self._isVisible = isVisible
        self.icon = icon
        self.progress = progress
        self.size = size
        self.lineWidth = lineWidth
        self.minimumDisplay = minimumDisplay
        self.title = title
    }
    
    public var body: some View {
        Group {
            if shouldShow {
                mainContent
            }
        }
        .onChange(of: isVisible, initial: false) { _, new in
            if new { show() } else { hideRespectingMinimum() }
        }
        .task {
            if isVisible { show() }
        }
    }
    
    @ViewBuilder
    private var mainContent: some View {
        VStack(spacing: 12) {
            badgeCircle
            
            // Optional title
            if let titleText = title {
                Text(titleText)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
            }
        }
        .transition(.opacity.combined(with: .scale(0.95)))
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(accessibilityValue ?? "")
    }
    
    @ViewBuilder
    private var badgeCircle: some View {
        ZStack {
            // Background puck
            Circle()
                .fill(.regularMaterial)
                .shadow(radius: 6, y: 3)
            
            // Progress ring
            ringView
                .frame(width: size * 0.86, height: size * 0.86)
            
            // Center symbol
            Image(systemName: icon.rawValue)
                .symbolRenderingMode(.hierarchical)
                .font(.system(size: size * 0.4, weight: .semibold))
                .foregroundStyle(.primary)
                .accessibilityHidden(true)
                .modifier(PulsingIfAllowed())
        }
        .frame(width: size, height: size)
    }
    
    @ViewBuilder
    private var ringView: some View {
        if let progressValue = progress {
            // Determinate progress ring
            ZStack {
                // Background ring
                Circle()
                    .stroke(Color.secondary.opacity(0.2), lineWidth: lineWidth)
                
                // Progress ring
                Circle()
                    .trim(from: 0, to: max(0, min(1, progressValue)))
                    .stroke(Theme.primary, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.3), value: progressValue)
            }
        } else {
            // Indeterminate spinning ring
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [.secondary.opacity(0.2), Theme.primary],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: lineWidth
                )
                .rotationEffect(.degrees(reduceMotion ? 0 : (spin ? 360 : 0)))
                .animation(
                    !reduceMotion && spin ? 
                    .linear(duration: 1.2).repeatForever(autoreverses: false) : 
                    .default,
                    value: spin
                )
        }
    }
    
    private var accessibilityLabel: String {
        if let title = title {
            return "\(title) - \(progress == nil ? "Processing" : "Progress")"
        }
        return progress == nil ? "Processing" : "Progress"
    }
    
    private var accessibilityValue: String? {
        if let p = progress { return "\(Int(p * 100)) percent complete" }
        return nil
    }
    
    private func show() {
        appearDate = Date()
        shouldShow = true
        if progress == nil && !reduceMotion { spin = true }
    }
    
    private func hideRespectingMinimum() {
        let elapsed = Date().timeIntervalSince(appearDate ?? Date())
        let delay = max(0, minimumDisplay - elapsed)
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            spin = false
            withAnimation(.easeOut(duration: 0.3)) {
                shouldShow = false
            }
        }
    }
}

private struct PulsingIfAllowed: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func body(content: Content) -> some View {
        if reduceMotion {
            content
        } else {
            if #available(iOS 17.0, *) {
                content.symbolEffect(.breathe, options: .repeating)
            } else {
                content
            }
        }
    }
}

// MARK: - Convenience Extensions

public extension MiniProcessingBadge {
    
    /// SmartFill processing badge
    static func smartFillProcessor(
        isVisible: Binding<Bool>, 
        progress: Double? = nil,
        title: String = "Processing SmartFill"
    ) -> MiniProcessingBadge {
        MiniProcessingBadge(
            isVisible: isVisible,
            icon: .smartFill,
            progress: progress,
            size: 68,
            title: title
        )
    }
    
    /// Export processing badge  
    static func exportProcessor(
        isVisible: Binding<Bool>,
        progress: Double? = nil,
        title: String = "Exporting Video"
    ) -> MiniProcessingBadge {
        MiniProcessingBadge(
            isVisible: isVisible,
            icon: .export,
            progress: progress,
            size: 64,
            title: title
        )
    }
}

#Preview {
    VStack(spacing: 40) {
        MiniProcessingBadge(
            isVisible: .constant(true),
            icon: .smartFill,
            progress: nil,
            title: "Processing SmartFill"
        )
        
        MiniProcessingBadge(
            isVisible: .constant(true),
            icon: .smartFill,
            progress: 0.65,
            title: "65% Complete"
        )
        
        MiniProcessingBadge(
            isVisible: .constant(true),
            icon: .export,
            progress: 0.3,
            size: 48
        )
    }
    .padding()
    .background(BrandBackground())
}
