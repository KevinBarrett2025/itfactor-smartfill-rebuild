import SwiftUI

struct Theme {
    static let primary = Color("BrandPrimaryColor")
    static let secondary = Color("BrandSecondaryColor")
    static let background = Color("BackgroundColor")
    static let surface = Color("SurfaceColor")
    static let textPrimary = Color("TextPrimaryColor")
    
    // MARK: - System Colors (for fallbacks and secondary usage)
    struct Colors {
        static let accent = Color.orange
        static let success = Color.green
        static let warning = Color.yellow
        static let danger = Color.red
        
        // Text colors
        static let secondaryText = Color(.secondaryLabel)
        static let tertiaryText = Color(.tertiaryLabel)
        
        // PHASE 2-4: Enhanced color palette for professional polish
        static let successSoft = Color.green.opacity(0.8)
        static let warningSoft = Color.yellow.opacity(0.8)
        static let dangerSoft = Color.red.opacity(0.8)
        static let accentSoft = Color.orange.opacity(0.8)
        
        // Professional gradients
        static let primaryGradient = LinearGradient(
            gradient: Gradient(colors: [
                Color(red: 0.6, green: 0.2, blue: 0.8),
                Color(red: 0.8, green: 0.3, blue: 0.7)
            ]),
            startPoint: .leading,
            endPoint: .trailing
        )
        
        static let surfaceGradient = LinearGradient(
            gradient: Gradient(colors: [
                Color(.systemIndigo).opacity(0.15),
                Color(.systemIndigo).opacity(0.08)
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        
        static let cardGradient = LinearGradient(
            gradient: Gradient(colors: [
                Color.white.opacity(0.08),
                Color.white.opacity(0.02)
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    // MARK: - Typography
    struct Font {
        static let title = SwiftUI.Font.system(size: 28, weight: .bold)
        static let body = SwiftUI.Font.system(size: 16, weight: .regular)
        static let caption = SwiftUI.Font.system(size: 13, weight: .light)
        static let caption2 = SwiftUI.Font.system(size: 12, weight: .regular)
        
        // Additional font sizes
        static let largeTitle = SwiftUI.Font.system(size: 34, weight: .bold)
        static let headline = SwiftUI.Font.system(size: 18, weight: .semibold)
        static let subheadline = SwiftUI.Font.system(size: 15, weight: .medium)
        static let callout = SwiftUI.Font.system(size: 16, weight: .medium)
        
        // PHASE 2-4: Enhanced typography with better hierarchy
        static let heroTitle = SwiftUI.Font.system(size: 36, weight: .heavy)
        static let cardTitle = SwiftUI.Font.system(size: 20, weight: .semibold)
        static let cardSubtitle = SwiftUI.Font.system(size: 14, weight: .medium)
        static let buttonLabel = SwiftUI.Font.system(size: 16, weight: .semibold)
        static let smallCaption = SwiftUI.Font.system(size: 11, weight: .medium)
    }
    
    // MARK: - Layout
    struct Layout {
        static let cornerRadius: CGFloat = 12
        static let padding: CGFloat = 16
        static let spacing: CGFloat = 8
        
        // Additional layout values
        static let smallPadding: CGFloat = 8
        static let largePadding: CGFloat = 24
        static let smallCornerRadius: CGFloat = 8
        static let largeCornerRadius: CGFloat = 20
        
        // PHASE 2-4: Enhanced layout system for professional consistency
        static let tinyCornerRadius: CGFloat = 6
        static let cardCornerRadius: CGFloat = 16
        static let modalCornerRadius: CGFloat = 24
        
        static let tinyPadding: CGFloat = 4
        static let compactPadding: CGFloat = 12
        static let comfortablePadding: CGFloat = 20
        static let spaciousPadding: CGFloat = 28
        
        static let cardSpacing: CGFloat = 12
        static let sectionSpacing: CGFloat = 20
        static let screenPadding: CGFloat = 16
    }
    
    // MARK: - Spacing (keeping existing for compatibility)
    struct Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
        
        // PHASE 2-4: Enhanced spacing scale
        static let tiny: CGFloat = 2
        static let huge: CGFloat = 64
        static let massive: CGFloat = 96
    }
    
    // MARK: - Shadow - FIXED: Use consistent CGFloat types
    struct Shadow {
        static let small = (color: Color.black.opacity(0.1), radius: CGFloat(2.0), x: CGFloat(0.0), y: CGFloat(1.0))
        static let medium = (color: Color.black.opacity(0.15), radius: CGFloat(4.0), x: CGFloat(0.0), y: CGFloat(2.0))
        static let large = (color: Color.black.opacity(0.2), radius: CGFloat(8.0), x: CGFloat(0.0), y: CGFloat(4.0))
        
        // PHASE 2-4: Enhanced shadow system for depth hierarchy - FIXED: CGFloat types
        static let subtle = (color: Color.black.opacity(0.06), radius: CGFloat(1.0), x: CGFloat(0.0), y: CGFloat(0.5))
        static let elevated = (color: Color.black.opacity(0.12), radius: CGFloat(6.0), x: CGFloat(0.0), y: CGFloat(3.0))
        static let floating = (color: Color.black.opacity(0.25), radius: CGFloat(12.0), x: CGFloat(0.0), y: CGFloat(6.0))
        static let dramatic = (color: Color.black.opacity(0.35), radius: CGFloat(20.0), x: CGFloat(0.0), y: CGFloat(10.0))
    }
    
    // MARK: - PHASE 2-4: Professional 60FPS Animation System
    struct Animation {
        // Optimized for 60fps performance
        static let instant = SwiftUI.Animation.easeInOut(duration: 0.0)
        static let quick = SwiftUI.Animation.easeInOut(duration: 0.15)
        static let smooth = SwiftUI.Animation.easeInOut(duration: 0.25)
        static let comfortable = SwiftUI.Animation.easeInOut(duration: 0.35)
        static let relaxed = SwiftUI.Animation.easeInOut(duration: 0.5)
        
        // Specialized animations for different UI elements
        static let buttonPress = SwiftUI.Animation.easeOut(duration: 0.1)
        static let buttonRelease = SwiftUI.Animation.easeInOut(duration: 0.2)
        static let cardAppear = SwiftUI.Animation.easeOut(duration: 0.3).delay(0.05)
        static let modalPresent = SwiftUI.Animation.spring(response: 0.5, dampingFraction: 0.8)
        static let modalDismiss = SwiftUI.Animation.easeInOut(duration: 0.25)
        
        // Micro-interactions for enterprise polish
        static let hover = SwiftUI.Animation.easeInOut(duration: 0.12)
        static let focus = SwiftUI.Animation.easeInOut(duration: 0.18)
        static let selection = SwiftUI.Animation.spring(response: 0.25, dampingFraction: 0.7)
        
        // Loading and transition animations
        static let loadingPulse = SwiftUI.Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: true)
        static let recordingPulse = SwiftUI.Animation.easeInOut(duration: 0.6).repeatForever(autoreverses: true)
        static let shimmer = SwiftUI.Animation.linear(duration: 1.5).repeatForever(autoreverses: false)
    }
    
    // MARK: - PHASE 2-4: Professional Interaction States
    struct InteractionState {
        // Scale factors for press states (optimized for visual feedback)
        static let buttonPressScale: CGFloat = 0.96
        static let cardPressScale: CGFloat = 0.98
        static let thumbnailPressScale: CGFloat = 0.94
        
        // Opacity states for subtle feedback
        static let pressedOpacity: CGFloat = 0.85
        static let disabledOpacity: CGFloat = 0.4
        static let subtleOpacity: CGFloat = 0.6
        
        // Color adjustments for interaction states
        static let highlightBrightness: CGFloat = 0.1
        static let pressedBrightness: CGFloat = -0.05
    }
    
    // MARK: - PHASE 2-4: Enterprise Performance Settings
    struct Performance {
        // Drawing performance optimizations
        static let preferredFrameRate = 60.0
        static let animationCurve = UnitCurve.easeInOut
        
        // Memory and rendering optimizations
        static let maxCachedImages = 50
        static let thumbnailCacheSize = 100
        
        // Background task priorities
        static let exportPriority = TaskPriority.userInitiated
        static let thumbnailPriority = TaskPriority.utility
    }
}

// MARK: - PHASE 2-4: Enhanced View Extensions for Professional Polish
extension View {
    // Enhanced card styles with professional polish
    func stsCard() -> some View {
        self
            .padding(Theme.Layout.padding)
            .background(
                RoundedRectangle(cornerRadius: Theme.Layout.cardCornerRadius)
                    .fill(Theme.Colors.cardGradient)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Layout.cardCornerRadius)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
            )
            .shadow(
                color: Theme.Shadow.medium.color,
                radius: Theme.Shadow.medium.radius,
                x: Theme.Shadow.medium.x,
                y: Theme.Shadow.medium.y
            )
    }
    
    // Enhanced button styles with 60fps animations
    func stsPrimaryButton() -> some View {
        self
            .padding(Theme.Layout.comfortablePadding)
            .background(Theme.Colors.primaryGradient)
            .foregroundColor(Theme.textPrimary)
            .cornerRadius(Theme.Layout.cardCornerRadius)
            .shadow(
                color: Theme.Shadow.elevated.color,
                radius: Theme.Shadow.elevated.radius,
                x: Theme.Shadow.elevated.x,
                y: Theme.Shadow.elevated.y
            )
    }
    
    func stsSecondaryButton() -> some View {
        self
            .padding(Theme.Layout.comfortablePadding)
            .background(
                RoundedRectangle(cornerRadius: Theme.Layout.cardCornerRadius)
                    .stroke(Theme.secondary.opacity(0.5), lineWidth: 1)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.Layout.cardCornerRadius)
                            .fill(Theme.secondary.opacity(0.1))
                    )
            )
            .foregroundColor(Theme.textPrimary)
    }
    
    // PHASE 2-4: Professional interaction modifiers
    func stsButtonStyle() -> some View {
        self
            .scaleEffect(1.0)
            .opacity(1.0)
            .animation(Theme.Animation.buttonPress, value: false)
    }
    
    func stsCardStyle() -> some View {
        self
            .scaleEffect(1.0)
            .animation(Theme.Animation.cardAppear, value: true)
    }
    
    func stsHoverEffect() -> some View {
        self
            .scaleEffect(1.0)
            .animation(Theme.Animation.hover, value: false)
    }
    
    // Professional loading state
    func stsLoadingShimmer() -> some View {
        self
            .overlay(
                Rectangle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.white.opacity(0.0),
                                Color.white.opacity(0.1),
                                Color.white.opacity(0.0)
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .animation(Theme.Animation.shimmer, value: true)
                    .clipped()
            )
    }
    
    // Enhanced shadow variants
    func stsSubtleShadow() -> some View {
        self.shadow(
            color: Theme.Shadow.subtle.color,
            radius: Theme.Shadow.subtle.radius,
            x: Theme.Shadow.subtle.x,
            y: Theme.Shadow.subtle.y
        )
    }
    
    func stsFloatingShadow() -> some View {
        self.shadow(
            color: Theme.Shadow.floating.color,
            radius: Theme.Shadow.floating.radius,
            x: Theme.Shadow.floating.x,
            y: Theme.Shadow.floating.y
        )
    }
    
    func stsDramaticShadow() -> some View {
        self.shadow(
            color: Theme.Shadow.dramatic.color,
            radius: Theme.Shadow.dramatic.radius,
            x: Theme.Shadow.dramatic.x,
            y: Theme.Shadow.dramatic.y
        )
    }
    
    // Performance-optimized animations
    func stsQuickTransition() -> some View {
        self.animation(Theme.Animation.quick, value: true)
    }
    
    func stsSmoothTransition() -> some View {
        self.animation(Theme.Animation.smooth, value: true)
    }
    
    func stsComfortableTransition() -> some View {
        self.animation(Theme.Animation.comfortable, value: true)
    }
}

// MARK: - PHASE 2-4: Professional Card Style for Consistent Polish
struct STSCardStyle: ViewModifier {
    let elevation: CardElevation
    
    enum CardElevation {
        case flat
        case subtle
        case elevated
        case floating
        
        var shadow: (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) {
            switch self {
            case .flat:
                return Theme.Shadow.subtle
            case .subtle:
                return Theme.Shadow.small
            case .elevated:
                return Theme.Shadow.medium
            case .floating:
                return Theme.Shadow.floating
            }
        }
    }
    
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: Theme.Layout.cardCornerRadius)
                    .fill(Theme.Colors.cardGradient)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Layout.cardCornerRadius)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
            )
            .shadow(
                color: elevation.shadow.color,
                radius: elevation.shadow.radius,
                x: elevation.shadow.x,
                y: elevation.shadow.y
            )
    }
}

extension View {
    func stsCard(elevation: STSCardStyle.CardElevation = .elevated) -> some View {
        self.modifier(STSCardStyle(elevation: elevation))
    }
}
