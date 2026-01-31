import SwiftUI

public struct InPersonChecklistView: View {
    @State private var checkedItems: Set<Int> = []
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager
    let onComplete: (() -> Void)?

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
    
    private let inPersonItems = [
        ("Date & Time", "calendar.badge.plus", "Add audition appointment to your calendar app"),
        ("Location & Parking", "map.fill", "Confirm the exact location, allow for traffic, and research parking. Check street signs, payment requirements for meters, validation options, and nearby free parking if available."),
        ("Bring Headshot & Resume", "doc.text.fill", "Bring multiple copies, stapled together"),
        ("Know Your Submitted Materials", "person.crop.square.fill", "Review the headshot/resume you originally submitted"),
        ("ID & Building Access", "checkmark.shield.fill", "Bring a valid form of ID. Studio lots or office buildings may require security check-in before granting access."),
        ("Arrive Early", "clock.badge.checkmark", "Plan to arrive 10–15 minutes early. Casting schedules talent precisely, and waiting areas or lobbies may not be able to accommodate early arrivals unless pre-approved.")
    ]
    
    public init(onComplete: (() -> Void)? = nil) {
        self.onComplete = onComplete
    }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                theme.backgroundGradient
                    .ignoresSafeArea()
                accentGlow
                
                VStack(spacing: 20) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "building.2.crop.circle.badge.checkmark")
                            .font(.system(size: 60))
                            .foregroundStyle(theme.primaryAccent)
                        
                        Text("In-Person Checklist")
                            .font(Theme.Font.title)
                            .foregroundStyle(Theme.textPrimary)
                        
                        Text("Essential preparation for your in-person audition")
                            .font(Theme.Font.body)
                            .foregroundStyle(.gray)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 20)
                    
                    // Checklist
                    List {
                        ForEach(Array(inPersonItems.enumerated()), id: \.offset) { index, item in
                            ChecklistRow(
                                title: item.0,
                                icon: item.1,
                                description: item.2,
                                isChecked: checkedItems.contains(index)
                            ) {
                                if checkedItems.contains(index) {
                                    checkedItems.remove(index)
                                } else {
                                    checkedItems.insert(index)
                                }
                            }
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    
                }
            }
            .navigationBarHidden(true)
        }
    }
    
    private var allItemsChecked: Bool {
        checkedItems.count == inPersonItems.count
    }
}

private struct ChecklistRow: View {
    let title: String
    let icon: String
    let description: String
    let isChecked: Bool
    let onToggle: () -> Void

    @EnvironmentObject private var themeManager: ThemeManager
    private var theme: STSTheme { themeManager.current }
    
    var body: some View {
        Button(action: onToggle) {
            STSCard {
                HStack(spacing: 16) {
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundStyle(theme.primaryAccent)
                        .frame(width: 30)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(Theme.Font.body)
                            .foregroundStyle(Theme.textPrimary)
                        
                        Text(description)
                            .font(Theme.Font.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundStyle(isChecked ? .green : .gray)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    InPersonChecklistView()
        .environmentObject(ThemeManager())
}
