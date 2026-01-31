import SwiftUI

/// Unified rating button component for consistent rating UI across all video players
struct UnifiedRatingButtons: View {
    let currentRating: TakeRating
    let layout: RatingLayout
    let size: RatingSize
    let onRatingChange: (TakeRating) -> Void
    
    enum RatingLayout {
        case horizontal
        case vertical
    }
    
    enum RatingSize {
        case small
        case medium  
        case large
        
        var buttonSize: CGFloat {
            switch self {
            case .small: return 40
            case .medium: return 60
            case .large: return 70
            }
        }
        
        var iconSize: CGFloat {
            switch self {
            case .small: return 16
            case .medium: return 20
            case .large: return 24
            }
        }
        
        var spacing: CGFloat {
            switch self {
            case .small: return 12
            case .medium: return 16
            case .large: return 20
            }
        }
        
        var padding: CGFloat {
            switch self {
            case .small: return 10
            case .medium: return 12
            case .large: return 16
            }
        }
    }
    
    init(
        currentRating: TakeRating,
        layout: RatingLayout = .horizontal,
        size: RatingSize = .medium,
        onRatingChange: @escaping (TakeRating) -> Void
    ) {
        self.currentRating = currentRating
        self.layout = layout
        self.size = size
        self.onRatingChange = onRatingChange
    }
    
    var body: some View {
        Group {
            if layout == .horizontal {
                HStack(spacing: size.spacing) {
                    ratingButtonsContent
                }
            } else {
                VStack(spacing: size.spacing) {
                    ratingButtonsContent
                }
            }
        }
    }
    
    @ViewBuilder
    private var ratingButtonsContent: some View {
        // Order based on layout preference
        if layout == .vertical {
            // Vertical: Most important at top
            ratingButton(.finalSelect, "star.fill", .yellow)
            ratingButton(.option, "checkmark.circle.fill", .green)
            ratingButton(.unrated, "circle", .gray)
            ratingButton(.rejected, "xmark.circle.fill", .red)
        } else {
            // Horizontal: Final Select → Option → Unrated → Rejected
            ratingButton(.finalSelect, "star.fill", .yellow)
            ratingButton(.option, "checkmark.circle.fill", .green)
            ratingButton(.unrated, "circle", .gray)
            ratingButton(.rejected, "xmark.circle.fill", .red)
        }
    }
    
    @ViewBuilder
    private func ratingButton(_ rating: TakeRating, _ iconName: String, _ color: Color) -> some View {
        Button(action: {
            print("🎯 Unified Rating Button Tapped: \(rating.rawValue)")
            onRatingChange(rating)
        }) {
            VStack(spacing: 6) {
                Image(systemName: iconName)
                    .font(.system(size: size.iconSize, weight: .medium))
                    .foregroundColor(currentRating == rating ? color : Color.white.opacity(0.8))
                    .shadow(color: .black.opacity(0.8), radius: 3, x: 0, y: 1)
                
                if size != .small {
                    Text(rating.displayName)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(.white.opacity(0.9))
                        .shadow(color: .black.opacity(0.8), radius: 2, x: 0, y: 1)
                }
            }
            .padding(size.padding)
            .background(
                Circle()
                    .fill(
                        currentRating == rating 
                            ? color.opacity(0.3)
                            : Color.black.opacity(0.5)
                    )
                    .frame(width: size.buttonSize, height: size.buttonSize)
            )
            .contentShape(Circle())
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(currentRating == rating ? 1.1 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: currentRating)
        .allowsHitTesting(true)
    }
}

/// Simplified unified rating component for compact spaces (like TakeRowView)
struct CompactUnifiedRatingButtons: View {
    let currentRating: TakeRating
    let onRatingChange: (TakeRating) -> Void
    
    var body: some View {
        HStack(spacing: 8) {
            // Final Select toggle
            Button(action: { 
                let newRating: TakeRating = currentRating == .finalSelect ? .unrated : .finalSelect
                onRatingChange(newRating)
            }) {
                Image(systemName: currentRating == .finalSelect ? "star.fill" : "star")
                    .font(.caption)
                    .foregroundColor(currentRating == .finalSelect ? .yellow : .white.opacity(0.6))
            }
            
            // Option toggle
            Button(action: { 
                let newRating: TakeRating = currentRating == .option ? .unrated : .option
                onRatingChange(newRating)
            }) {
                Image(systemName: currentRating == .option ? "checkmark.circle.fill" : "checkmark.circle")
                    .font(.caption)
                    .foregroundColor(currentRating == .option ? .green : .white.opacity(0.6))
            }
            
            // Rejected toggle
            Button(action: { 
                let newRating: TakeRating = currentRating == .rejected ? .unrated : .rejected
                onRatingChange(newRating)
            }) {
                Image(systemName: currentRating == .rejected ? "xmark.circle.fill" : "xmark.circle")
                    .font(.caption)
                    .foregroundColor(currentRating == .rejected ? .red : .white.opacity(0.6))
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

/// Unified rating display component (non-interactive)
struct UnifiedRatingDisplay: View {
    let rating: TakeRating
    let size: DisplaySize
    
    enum DisplaySize {
        case small
        case medium
        
        var iconSize: CGFloat {
            switch self {
            case .small: return 12
            case .medium: return 16
            }
        }
    }
    
    var body: some View {
        if rating != .unrated {
            Image(systemName: rating.iconName)
                .font(.system(size: size.iconSize))
                .foregroundColor(rating.color)
        }
    }
}

// MARK: - Previews

#Preview("Vertical Large") {
    ZStack {
        Color.black.ignoresSafeArea()
        
        HStack {
            Spacer()
            
            UnifiedRatingButtons(
                currentRating: .finalSelect,
                layout: .vertical,
                size: .large
            ) { newRating in
                print("Rating changed to: \(newRating)")
            }
            .padding(.trailing, 20)
        }
    }
}

#Preview("Horizontal Medium") {
    ZStack {
        Color.black.ignoresSafeArea()
        
        VStack {
            Spacer()
            
            UnifiedRatingButtons(
                currentRating: .option,
                layout: .horizontal,
                size: .medium
            ) { newRating in
                print("Rating changed to: \(newRating)")
            }
            .padding(.bottom, 40)
        }
    }
}

#Preview("Compact Row") {
    ZStack {
        Color.black.ignoresSafeArea()
        
        CompactUnifiedRatingButtons(
            currentRating: .finalSelect
        ) { newRating in
            print("Compact rating changed to: \(newRating)")
        }
        .padding()
        .background(.ultraThinMaterial.opacity(0.8), in: Capsule())
    }
}
