import SwiftUI

// MARK: - PHASE 2-4: Enhanced STSCard with Professional Polish and 60fps Animations
struct STSCard<Content: View>: View {
    let content: Content
    let elevation: CardElevation
    let isInteractive: Bool
    let onTap: (() -> Void)?
    
    // PHASE 2-4: Professional interaction states
    @State private var isPressed = false
    @State private var isHovering = false
    
    enum CardElevation {
        case flat
        case subtle
        case elevated
        case floating
        
        // FIXED: Use CGFloat consistently
        var shadow: (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) {
            switch self {
            case .flat:
                return (Color.clear, CGFloat(0), CGFloat(0), CGFloat(0))
            case .subtle:
                return Theme.Shadow.subtle
            case .elevated:
                return Theme.Shadow.medium
            case .floating:
                return Theme.Shadow.floating
            }
        }
    }
    
    // Standard card initializer (most common use case)
    init(
        elevation: CardElevation = .elevated,
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.elevation = elevation
        self.isInteractive = false
        self.onTap = nil
    }
    
    // Interactive card initializer
    init(
        elevation: CardElevation = .elevated,
        onTap: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.elevation = elevation
        self.isInteractive = true
        self.onTap = onTap
    }
    
    var body: some View {
        cardView
            .animation(Theme.Animation.cardAppear, value: isHovering)
    }
    
    @ViewBuilder
    private var cardView: some View {
        if isInteractive, let onTap = onTap {
            Button(action: {
                // PHASE 2-4: Haptic feedback for interactive cards
                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                impactFeedback.impactOccurred()
                onTap()
            }) {
                cardContent
            }
            .buttonStyle(PlainButtonStyle())
            .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
                withAnimation(Theme.Animation.buttonPress) {
                    isPressed = pressing
                }
            }) {
                // Long press handled by onTap for now
            }
        } else {
            cardContent
        }
    }
    
    private var cardContent: some View {
        content
            .padding(Theme.Layout.comfortablePadding)
            .background(cardBackground)
            .cornerRadius(Theme.Layout.cardCornerRadius)
            .shadow(
                color: elevation.shadow.color,
                radius: isHovering ? elevation.shadow.radius * 1.2 : elevation.shadow.radius,
                x: elevation.shadow.x,
                y: isHovering ? elevation.shadow.y * 1.1 : elevation.shadow.y
            )
            .scaleEffect(
                isPressed ? Theme.InteractionState.cardPressScale : 
                isHovering ? 1.02 : 1.0
            )
            .animation(Theme.Animation.smooth, value: isPressed)
            .animation(Theme.Animation.hover, value: isHovering)
            .onHover { hovering in
                if isInteractive {
                    withAnimation(Theme.Animation.hover) {
                        isHovering = hovering
                    }
                }
            }
    }
    
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: Theme.Layout.cardCornerRadius, style: .continuous)
            .fill(Theme.Colors.cardGradient)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Layout.cardCornerRadius, style: .continuous)
                    .stroke(
                        Color.white.opacity(isHovering ? 0.15 : 0.08),
                        lineWidth: 1
                    )
            )
            .overlay(
                // PHASE 2-4: Subtle shine effect for premium feel
                RoundedRectangle(cornerRadius: Theme.Layout.cardCornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.white.opacity(0.1),
                                Color.white.opacity(0.0),
                                Color.white.opacity(0.05)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .opacity(isHovering ? 1.0 : 0.7)
            )
    }
}

// MARK: - PHASE 2-4: Specialized Card Variants for Different Use Cases

// Session Card - optimized for session display with enhanced visual hierarchy
struct STSSessionCard<Content: View>: View {
    let content: Content
    let onTap: (() -> Void)?
    
    @State private var isPressed = false
    
    init(onTap: (() -> Void)? = nil, @ViewBuilder content: () -> Content) {
        self.content = content()
        self.onTap = onTap
    }
    
    var body: some View {
        Group {
            if let onTap = onTap {
                Button(action: onTap) {
                    sessionCardContent
                }
                .buttonStyle(PlainButtonStyle())
            } else {
                sessionCardContent
            }
        }
    }
    
    private var sessionCardContent: some View {
        content
            .padding(Theme.Layout.comfortablePadding)
            .background(
                RoundedRectangle(cornerRadius: Theme.Layout.cardCornerRadius, style: .continuous)
                    .fill(Theme.Colors.surfaceGradient)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Layout.cardCornerRadius, style: .continuous)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
            )
            .shadow(
                color: Theme.Shadow.elevated.color,
                radius: Theme.Shadow.elevated.radius,
                x: Theme.Shadow.elevated.x,
                y: Theme.Shadow.elevated.y
            )
            .scaleEffect(isPressed ? Theme.InteractionState.cardPressScale : 1.0)
            .animation(Theme.Animation.smooth, value: isPressed)
            .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
                if onTap != nil {
                    withAnimation(Theme.Animation.buttonPress) {
                        isPressed = pressing
                    }
                }
            }) {
                // Handled by button action
            }
    }
}

// Take Card - specialized for take display with rating integration
struct STSTakeCard<Content: View>: View {
    let content: Content
    let takeRating: TakeRating
    let onTap: (() -> Void)?
    
    @State private var isPressed = false
    
    init(
        takeRating: TakeRating = .unrated,
        onTap: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.takeRating = takeRating
        self.onTap = onTap
    }
    
    var body: some View {
        Group {
            if let onTap = onTap {
                Button(action: onTap) {
                    takeCardContent
                }
                .buttonStyle(PlainButtonStyle())
            } else {
                takeCardContent
            }
        }
    }
    
    private var takeCardContent: some View {
        content
            .padding(Theme.Layout.padding)
            .background(takeCardBackground)
            .cornerRadius(Theme.Layout.smallCornerRadius)
            .overlay(
                // PHASE 2-4: Rating indicator border
                RoundedRectangle(cornerRadius: Theme.Layout.smallCornerRadius)
                    .stroke(ratingBorderColor, lineWidth: ratingBorderWidth)
            )
            .shadow(
                color: Theme.Shadow.small.color,
                radius: Theme.Shadow.small.radius,
                x: Theme.Shadow.small.x,
                y: Theme.Shadow.small.y
            )
            .scaleEffect(isPressed ? Theme.InteractionState.cardPressScale : 1.0)
            .animation(Theme.Animation.quick, value: isPressed)
            .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
                if onTap != nil {
                    withAnimation(Theme.Animation.buttonPress) {
                        isPressed = pressing
                    }
                }
            }) {
                // Handled by button action
            }
    }
    
    private var takeCardBackground: Color {
        switch takeRating {
        case .finalSelect:
            return Color.yellow.opacity(0.08)
        case .option:
            return Theme.Colors.successSoft.opacity(0.08)
        case .rejected:
            return Theme.Colors.dangerSoft.opacity(0.08)
        case .unrated:
            return Color.white.opacity(0.03)
        }
    }
    
    private var ratingBorderColor: Color {
        switch takeRating {
        case .finalSelect:
            return Color.yellow.opacity(0.4)
        case .option:
            return Theme.Colors.successSoft.opacity(0.3)
        case .rejected:
            return Theme.Colors.dangerSoft.opacity(0.3)
        case .unrated:
            return Color.clear
        }
    }
    
    private var ratingBorderWidth: CGFloat {
        switch takeRating {
        case .unrated:
            return 0
        default:
            return 1
        }
    }
}

// MARK: - PHASE 2-4: Loading State Card with Skeleton Animation
struct STSLoadingCard: View {
    let height: CGFloat
    
    @State private var shimmerOffset: CGFloat = -1
    
    init(height: CGFloat = 100) {
        self.height = height
    }
    
    var body: some View {
        RoundedRectangle(cornerRadius: Theme.Layout.cardCornerRadius)
            .fill(Color.gray.opacity(0.1))
            .frame(height: height)
            .overlay(
                Rectangle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.white.opacity(0.0),
                                Color.white.opacity(0.3),
                                Color.white.opacity(0.0)
                            ]),
                            startPoint: .init(x: shimmerOffset, y: 0.5),
                            endPoint: .init(x: shimmerOffset + 0.3, y: 0.5)
                        )
                    )
                    .animation(Theme.Animation.shimmer, value: shimmerOffset)
                    .onAppear {
                        withAnimation(Theme.Animation.shimmer) {
                            shimmerOffset = 1.3
                        }
                    }
            )
            .clipped()
            .cornerRadius(Theme.Layout.cardCornerRadius)
    }
}

// MARK: - Convenience Extensions
extension View {
    func stsSessionCard() -> some View {
        STSSessionCard {
            self
        }
    }
    
    func stsTakeCard(rating: TakeRating = .unrated) -> some View {
        STSTakeCard(takeRating: rating) {
            self
        }
    }
}

#Preview("Enhanced STSCard Variants") {
    ScrollView {
        VStack(spacing: Theme.Layout.sectionSpacing) {
            // Standard card
            STSCard {
                VStack(alignment: .leading, spacing: Theme.Layout.spacing) {
                    Text("Standard Card")
                        .font(Theme.Font.headline)
                        .foregroundColor(Theme.textPrimary)
                    Text("This demonstrates the enhanced STSCard with professional polish and smooth animations.")
                        .font(Theme.Font.body)
                        .foregroundColor(Theme.Colors.secondaryText)
                }
            }
            
            // Interactive card
            STSCard(onTap: {
                print("Interactive card tapped")
            }) {
                VStack(alignment: .leading, spacing: Theme.Layout.spacing) {
                    Text("Interactive Card")
                        .font(Theme.Font.headline)
                        .foregroundColor(Theme.textPrimary)
                    Text("This card responds to taps with haptic feedback and smooth animations.")
                        .font(Theme.Font.body)
                        .foregroundColor(Theme.Colors.secondaryText)
                }
            }
            
            // Session card
            STSSessionCard {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Session Card")
                            .font(Theme.Font.cardTitle)
                            .foregroundColor(.white)
                        Text("Specialized for session display")
                            .font(Theme.Font.cardSubtitle)
                            .foregroundColor(Theme.Colors.secondaryText)
                    }
                    Spacer()
                    Image(systemName: "video.fill")
                        .foregroundColor(Theme.primary)
                }
            }
            
            // Take cards with different ratings
            STSTakeCard(takeRating: .finalSelect) {
                HStack {
                    Text(TakeRating.finalSelect.displayName)
                        .font(Theme.Font.body)
                        .foregroundColor(Theme.textPrimary)
                    Spacer()
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                }
            }
            
            STSTakeCard(takeRating: .option) {
                HStack {
                    Text(TakeRating.option.displayName)
                        .font(Theme.Font.body)
                        .foregroundColor(Theme.textPrimary)
                    Spacer()
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
            }
            
            STSTakeCard(takeRating: .rejected) {
                HStack {
                    Text(TakeRating.rejected.displayName)
                        .font(Theme.Font.body)
                        .foregroundColor(Theme.textPrimary)
                    Spacer()
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                }
            }
            
            // Loading state
            STSLoadingCard(height: 80)
            
            // Different elevations
            VStack(spacing: Theme.Layout.cardSpacing) {
                STSCard(elevation: .flat) {
                    Text("Flat Elevation").font(Theme.Font.body)
                }
                
                STSCard(elevation: .subtle) {
                    Text("Subtle Elevation").font(Theme.Font.body)
                }
                
                STSCard(elevation: .floating) {
                    Text("Floating Elevation").font(Theme.Font.body)
                }
            }
        }
        .padding()
    }
    .background(Theme.background)
}
