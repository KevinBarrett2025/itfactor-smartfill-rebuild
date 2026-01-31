import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var showingCameraSettings = false
    @State private var showingAudioSettings = false
    @State private var showingSmartFillSettings = false  // NEW: Smart Fill settings
    @ObservedObject private var watchBridge = WatchBridge.shared
    @AppStorage("WatchRemote.showHUDMaster") private var showWatchHUDMaster = true
    @AppStorage("PreferredMapsApp") private var preferredMapsAppRaw: String = MapsAppPreference.google.rawValue
    private var theme: STSTheme { themeManager.current }
    private var labelColor: Color { theme.id == .takeReviewClassic ? .black : .primary }
    private var secondaryLabelColor: Color { theme.id == .takeReviewClassic ? Color.black.opacity(0.6) : .secondary }
    private var isWatchConnected: Bool {
        watchBridge.isSessionActive || watchBridge.isReachable || watchBridge.didReceiveWatchReady
    }
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
    private let themeOptions: [(id: STSThemeID, title: String, subtitle: String)] = [
        (.studioLobbyV1, "Cinematic Studio", "Teal / Navy"),
        (.studioLobbyNeon, "Pop Culture", "Magenta Glow"),
        (.takeReviewClassic, "Classic Paper", "Monochrome")
    ]
    
    var body: some View {
        ZStack {
            theme.backgroundGradient
                .ignoresSafeArea()
            accentGlow
            
            List {
                Section("Appearance") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(themeOptions, id: \.id) { option in
                                let optionTheme = STSThemeLibrary.theme(for: option.id)
                                let isClassicPaper = option.id == .takeReviewClassic

                                Button {
                                    guard !isClassicPaper else { return }
                                    themeManager.currentID = option.id
                                } label: {
                                    ThemePreviewCard(
                                        theme: optionTheme,
                                        title: option.title,
                                        subtitle: isClassicPaper ? "Coming soon" : option.subtitle,
                                        isSelected: themeManager.currentID == option.id
                                    )
                                    .overlay {
                                        if isClassicPaper {
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .fill(Color.black.opacity(0.35))
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                                .disabled(isClassicPaper)
                            }
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 4)
                    }
                }
                .listRowBackground(Color.clear)

                Section("Recording & Export") {
                    SettingsRow(
                        icon: "camera.fill",
                        title: "Camera",
                        subtitle: "Recording quality & mirroring",
                        action: { showingCameraSettings = true }
                    )
                    .listRowBackground(Color.clear)

                    SettingsRow(
                        icon: "waveform",
                        title: "Audio",
                        subtitle: "Mic quality presets",
                        action: { showingAudioSettings = true }
                    )
                    .listRowBackground(Color.clear)
                }
                
                Section("Navigation") {
                    Picker("Default Maps App", selection: $preferredMapsAppRaw) {
                        ForEach(MapsAppPreference.allCases, id: \.rawValue) { option in
                            Text(option.title).tag(option.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                    
                    Text("Used when opening directions to reps and other addresses.")
                        .font(.caption2)
                        .foregroundStyle(secondaryLabelColor)
                        .padding(.top, 4)
                }
                .listRowBackground(Color.clear)
                
                Section("Apple Watch Remote") {
                    HStack {
                        Label("Connection", systemImage: "applewatch")
                            .foregroundStyle(Theme.primary)
                        Spacer()
                        Text(isWatchConnected ? "Connected" : "Not Connected")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(isWatchConnected ? .green : .secondary)
                    }
                    
                    Toggle(isOn: $showWatchHUDMaster) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Show HUD in Camera")
                            Text("Display watch connection badge in the camera view.")
                                .font(.caption)
                                .foregroundStyle(secondaryLabelColor)
                        }
                    }
                    .toggleStyle(SwitchToggleStyle(tint: Theme.primary))
                }
                .listRowBackground(Color.clear)
                
                Section("Support") {
                    SettingsRow(
                        icon: "questionmark.circle",
                        title: "Help & FAQ",
                        subtitle: "Get help using the app",
                        action: {
                            // TODO: Help system
                        }
                    )
                    .listRowBackground(Color.clear)
                    
                    SettingsRow(
                        icon: "envelope",
                        title: "Contact Support",
                        subtitle: "Report issues or feedback",
                        action: {
                            // TODO: Support contact
                        }
                    )
                    .listRowBackground(Color.clear)
                }
                
                Section("About") {
                    SettingsRow(
                        icon: "info.circle",
                        title: "Version",
                        subtitle: "1.0.0 (Phase 4 - Smart Fill)",
                        action: {
                            // TODO: About/version info
                        }
                    )
                    .listRowBackground(Color.clear)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingCameraSettings) {
            CameraSettingsView()
        }
        .sheet(isPresented: $showingAudioSettings) {
            AudioSettingsView()
        }
        // NEW: Smart Fill settings sheet
        .sheet(isPresented: $showingSmartFillSettings) {
            NavigationView {
                SmartFillSettingsView()
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") {
                                showingSmartFillSettings = false
                            }
                        }
                    }
            }
        }
    }
}

private enum MapsAppPreference: String, CaseIterable {
    case google
    case apple
    
    var title: String {
        switch self {
        case .google: return "Google Maps"
        case .apple: return "Apple Maps"
        }
    }
}

// Simple replacement for RowIconButton
struct SettingsRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            SettingsRowContent(icon: icon, title: title, subtitle: subtitle)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

private struct SettingsRowContent: View {
    let icon: String
    let title: String
    let subtitle: String
    @EnvironmentObject private var themeManager: ThemeManager
    
    private var labelColor: Color { themeManager.current.id == .takeReviewClassic ? .black : .primary }
    private var secondaryLabelColor: Color { themeManager.current.id == .takeReviewClassic ? Color.black.opacity(0.6) : .secondary }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(Theme.primary)
                .frame(width: 28, height: 28)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                    .foregroundStyle(labelColor)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(secondaryLabelColor)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
    .environmentObject(ThemeManager())
}

private struct ThemePreviewCard: View {
    let theme: STSTheme
    let title: String
    let subtitle: String
    let isSelected: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                theme.backgroundGradient
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Circle()
                            .fill(theme.cardBackground)
                            .overlay(Circle().stroke(theme.cardStroke, lineWidth: 1))
                            .frame(width: 36, height: 36)
                        Spacer()
                        Circle()
                            .fill(theme.primaryAccent.opacity(0.5))
                            .frame(width: 12, height: 12)
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(theme.cardBackground)
                            .frame(height: 46)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(theme.cardStroke, lineWidth: 1)
                            )
                        
                        RoundedRectangle(cornerRadius: 10)
                            .fill(theme.cardBackground)
                            .frame(height: 26)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(theme.cardStroke, lineWidth: 1)
                            )
                            .overlay(
                                Capsule()
                                    .fill(theme.primaryButtonBackground)
                                    .overlay(Capsule().stroke(theme.primaryButtonStroke, lineWidth: 1))
                                    .frame(width: 84, height: 26)
                                    .padding(.horizontal, 6),
                                alignment: .trailing
                            )
                    }
                    Spacer()
                }
                .padding(12)
            }
            .frame(width: 130, height: 190)
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? theme.primaryAccent : theme.cardStroke, lineWidth: isSelected ? 3 : 1)
            )
            .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 6)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 2)
        }
    }
}
