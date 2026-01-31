import SwiftUI

struct FramingGuideReferenceView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var selectedGuide: FramingGuideExample = .closeUp

    private var theme: STSTheme { themeManager.current }
    private var accentGlow: some View {
        RadialGradient(
            gradient: Gradient(colors: [
                theme.primaryAccent.opacity(theme.id == .studioLobbyV1 ? 0.18 : 0.24),
                Color.clear
            ]),
            center: .center,
            startRadius: 0,
            endRadius: 480
        )
        .blendMode(.screen)
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                theme.backgroundGradient
                    .ignoresSafeArea()
                accentGlow
                
                VStack(spacing: 0) {
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: "graduationcap.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(theme.primaryAccent)
                        
                        Text("Professional Framing Guide")
                            .font(Theme.Font.title)
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                        
                        Text("Learn industry-standard framing for self-tapes")
                            .font(Theme.Font.body)
                            .foregroundStyle(.gray)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                    .padding(.bottom, 24)
                    
                    // Guide Selector
                    guideSelectorView
                    
                    // Content
                    ScrollView {
                        VStack(spacing: 24) {
                            selectedGuideContent
                            
                            // Professional Tips Section
                            professionalTipsSection
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 16)
                    }
                }
            }
            .navigationBarHidden(true)
            .overlay(alignment: .topTrailing) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.white.opacity(0.8))
                        .background(Color.black.opacity(0.3), in: Circle())
                }
                .padding(.top, 50)
                .padding(.trailing, 24)
            }
        }
    }
    
    private var guideSelectorView: some View {
        let selectionColor = theme.primaryAccent

        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(FramingGuideExample.allCases, id: \.self) { guide in
                    let isSelected = selectedGuide == guide
                    
                    Button {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            selectedGuide = guide
                        }
                    } label: {
                        VStack(spacing: 8) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(isSelected ? selectionColor : Color.black.opacity(0.4))
                                    .frame(width: 80, height: 80)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(isSelected ? selectionColor : Color.white.opacity(0.2), lineWidth: 2)
                                    )
                                
                                guide.illustration
                            }
                            
                            Text(guide.displayName)
                                .font(.caption)
                                .fontWeight(isSelected ? .semibold : .medium)
                                .foregroundStyle(isSelected ? .white : .gray)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 24)
        }
        .padding(.bottom, 16)
    }
    
    @ViewBuilder
    private var selectedGuideContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Title and Description
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(selectedGuide.displayName)
                        .font(Theme.Font.title)
                        .foregroundStyle(.white)
                    
                    Spacer()
                    
                    theme.primaryAccent
                        .frame(width: 4, height: 24)
                        .clipShape(RoundedRectangle(cornerRadius: 2))
                }
                
                Text(selectedGuide.description)
                    .font(Theme.Font.body)
                    .foregroundStyle(.gray)
                    .lineSpacing(4)
            }
            
            // Visual Example
            visualExampleCard
            
            // Guidelines
            guidelinesCard
            
            // Do's and Don'ts
            dosAndDontsCard
        }
    }
    
    private var visualExampleCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Visual Example")
                .font(Theme.Font.headline)
                .foregroundStyle(.white)
            
            // Frame visualization
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black.opacity(0.6))
                    .frame(height: 200)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(selectedGuide.accentColor.opacity(0.5), lineWidth: 2)
                    )
                
                selectedGuide.largeIllustration
            }
            
            Text(selectedGuide.visualDescription)
                .font(Theme.Font.caption)
                .foregroundStyle(.gray)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.4))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
    
    private var guidelinesCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Professional Guidelines")
                .font(Theme.Font.headline)
                .foregroundStyle(.white)
            
            VStack(alignment: .leading, spacing: 12) {
                ForEach(selectedGuide.guidelines, id: \.self) { guideline in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(selectedGuide.accentColor)
                            .padding(.top, 2)
                        
                        Text(guideline)
                            .font(Theme.Font.body)
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.leading)
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.4))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
    
    private var dosAndDontsCard: some View {
        HStack(spacing: 16) {
            // Do's
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.green)
                    
                    Text("DO")
                        .font(Theme.Font.headline)
                        .foregroundStyle(.white)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(selectedGuide.dos, id: \.self) { item in
                        Text("• " + item)
                            .font(Theme.Font.caption)
                            .foregroundStyle(.white)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.green.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.green.opacity(0.3), lineWidth: 1)
                    )
            )
            
            // Don'ts
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.red)
                    
                    Text("DON'T")
                        .font(Theme.Font.headline)
                        .foregroundStyle(.white)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(selectedGuide.donts, id: \.self) { item in
                        Text("• " + item)
                            .font(Theme.Font.caption)
                            .foregroundStyle(.white)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.red.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.red.opacity(0.3), lineWidth: 1)
                    )
            )
        }
    }
    
    private var professionalTipsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .font(.title3)
                    .foregroundStyle(theme.primaryAccent)
                
                Text("Professional Tips")
                    .font(Theme.Font.headline)
                    .foregroundStyle(.white)
            }
            
            VStack(alignment: .leading, spacing: 12) {
                ForEach(FramingGuideExample.professionalTips, id: \.self) { tip in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundStyle(theme.primaryAccent)
                            .padding(.top, 2)
                        
                        Text(tip)
                            .font(Theme.Font.body)
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.leading)
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.4))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(theme.primaryAccent.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

// MARK: - Framing Guide Examples Data Model

enum FramingGuideExample: String, CaseIterable {
    case closeUp = "closeUp"
    case medium = "medium"
    case fullBody = "fullBody"
    case twoShot = "twoShot"
    
    var displayName: String {
        switch self {
        case .closeUp: return "Close-up"
        case .medium: return "Medium Shot"
        case .fullBody: return "Full Body"
        case .twoShot: return "Two Shot"
        }
    }

    private var imageAssetName: String {
        switch self {
        case .closeUp: return "FramingGuideCloseUp"
        case .medium: return "FramingGuideMedium"
        case .fullBody: return "FramingGuideFullBody"
        case .twoShot: return "FramingGuideTwoShot"
        }
    }
    
    var description: String {
        switch self {
        case .closeUp:
            return "Frame from the chest up to capture facial expressions and emotions. Most common for dialogue scenes and dramatic moments."
        case .medium:
            return "Frame from the waist up, showing gestures and body language while maintaining facial focus. Great for conversations and monologues."
        case .fullBody:
            return "Show the entire body from head to toe. Used for physical comedy, dance, or when movement is important to the scene."
        case .twoShot:
            return "Frame two actors together in the same shot. Common for scenes with dialogue between characters or relationship dynamics."
        }
    }
    
    var visualDescription: String {
        switch self {
        case .closeUp: return "Shoulders and head visible, tight on facial expressions"
        case .medium: return "Waist up, showing upper body and gestures"
        case .fullBody: return "Full body in frame with some headroom"
        case .twoShot: return "Two people comfortably framed together"
        }
    }
    
    var accentColor: Color {
        switch self {
        case .closeUp: return .blue
        case .medium: return .purple
        case .fullBody: return .green
        case .twoShot: return .orange
        }
    }
    
    @ViewBuilder
    var illustration: some View {
        Image(imageAssetName)
            .resizable()
            .scaledToFill()
            .frame(width: 64, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.25), radius: 6, x: 0, y: 2)
            .accessibilityLabel(Text(displayName + " framing example"))
    }
    
    @ViewBuilder
    var largeIllustration: some View {
        Image(imageAssetName)
            .resizable()
            .scaledToFit()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .accessibilityLabel(Text(displayName + " visual example"))
    }
    
    var guidelines: [String] {
        switch self {
        case .closeUp:
            return [
                "Keep eyes in the upper third of the frame",
                "Leave some headroom but not too much",
                "Ensure shoulders are visible for context",
                "Keep the camera at eye level or slightly below",
                "Focus on facial expressions and emotion"
            ]
            
        case .medium:
            return [
                "Frame from waist to head",
                "Include hands to show gestures",
                "Maintain eye contact with camera",
                "Keep background simple and uncluttered",
                "Allow for natural movement within frame"
            ]
            
        case .fullBody:
            return [
                "Show entire body from head to toe",
                "Leave space above head and below feet",
                "Center the subject in the frame",
                "Use for movement or physical comedy",
                "Maintain consistent lighting throughout"
            ]
            
        case .twoShot:
            return [
                "Position both actors comfortably in frame",
                "Ensure both faces are clearly visible",
                "Avoid one person blocking the other",
                "Consider eye lines and interaction",
                "Frame to show relationship dynamic"
            ]
        }
    }
    
    var dos: [String] {
        switch self {
        case .closeUp:
            return [
                "Keep camera steady",
                "Good lighting on face",
                "Clear audio",
                "Natural expressions"
            ]
            
        case .medium:
            return [
                "Show hand gestures",
                "Maintain posture",
                "Use depth of field",
                "Keep frame centered"
            ]
            
        case .fullBody:
            return [
                "Show full movement",
                "Keep background clean",
                "Maintain proportions",
                "Use wide angle carefully"
            ]
            
        case .twoShot:
            return [
                "Balance both subjects",
                "Clear sight lines",
                "Equal lighting",
                "Natural interaction"
            ]
        }
    }
    
    var donts: [String] {
        switch self {
        case .closeUp:
            return [
                "Cut off at joints",
                "Too much headroom",
                "Harsh shadows",
                "Shaky camera"
            ]
            
        case .medium:
            return [
                "Hide the hands",
                "Tilt the camera",
                "Crowd the frame",
                "Poor background"
            ]
            
        case .fullBody:
            return [
                "Cut off feet/head",
                "Stand too far",
                "Busy background",
                "Uneven lighting"
            ]
            
        case .twoShot:
            return [
                "Block each other",
                "Unequal framing",
                "Poor audio",
                "Awkward positioning"
            ]
        }
    }
    
    static let professionalTips = [
        "Always record multiple takes with different framings to give casting directors options.",
        "Use a tripod or stable surface - handheld footage looks unprofessional.",
        "Record in landscape (horizontal) orientation unless specifically requested otherwise.",
        "Test your setup before the actual take to ensure proper framing and audio levels.",
        "Keep consistent lighting throughout your session - avoid changing conditions.",
        "Leave a few seconds of silence at the beginning and end of each take.",
        "Make sure your background is clean, neutral, and not distracting.",
        "Position the camera at eye level or slightly below for the most flattering angle."
    ]
}

#Preview {
    FramingGuideReferenceView()
}
