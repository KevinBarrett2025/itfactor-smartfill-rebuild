import SwiftUI

/// PHASE 2: Simplified SmartFill Dashboard - Kevin's Standalone Approach
/// Removed complex migration logic, now shows simple SmartFill status and controls
struct SmartFillMigrationDashboard: View {
    
    @State private var smartFillSettings = SmartFillSettings()
    @State private var showingSettingsSheet = false
    
    var body: some View {
        ZStack {
            BrandBackground()
                .ignoresSafeArea()
            
            List {
                // PHASE 2: SmartFill Status
                Section("SmartFill Status") {
                    smartFillStatusCard
                        .listRowBackground(Color.clear)
                }
                
                // PHASE 2: System Configuration
                Section("System Configuration") {
                    systemConfigurationCard
                        .listRowBackground(Color.clear)
                }
                
                // PHASE 2: Settings Access
                Section("Settings") {
                    Button("Advanced SmartFill Settings") {
                        showingSettingsSheet = true
                    }
                    .foregroundStyle(Theme.primary)
                    .listRowBackground(Color.clear)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("SmartFill Dashboard")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingSettingsSheet) {
            SmartFillSettingsView()
        }
        .onAppear {
            refreshSettings()
        }
    }
    
    // MARK: - Phase 2: SmartFill Status Card
    
    @ViewBuilder
    private var smartFillStatusCard: some View {
        STSCard(elevation: .elevated) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "rectangle.portrait.on.rectangle.landscape.fill")
                        .font(.title2)
                        .foregroundStyle(smartFillSettings.defaultEnabled ? Theme.primary : .secondary)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("SmartFill System")
                            .font(.headline)
                            .foregroundStyle(Theme.textPrimary)
                        
                        Text(smartFillSettings.defaultEnabled ? "Active" : "Disabled")
                            .font(.caption)
                            .foregroundStyle(smartFillSettings.defaultEnabled ? .green : .secondary)
                    }
                    
                    Spacer()
                    
                    Button("Refresh") {
                        refreshSettings()
                    }
                    .font(.caption)
                    .foregroundStyle(Theme.primary)
                }
                
                // PHASE 2: SmartFill Statistics
                HStack(spacing: 20) {
                    statusStatCard(
                        title: "System Status",
                        value: smartFillSettings.defaultEnabled ? "Enabled" : "Disabled",
                        icon: smartFillSettings.defaultEnabled ? "checkmark.circle.fill" : "xmark.circle.fill",
                        color: smartFillSettings.defaultEnabled ? .green : .red
                    )
                    
                    statusStatCard(
                        title: "Background Scale",
                        value: "\(String(format: "%.0f", smartFillSettings.backgroundScale))x",
                        icon: "viewfinder",
                        color: .blue
                    )
                }
            }
        }
    }
    
    // MARK: - Phase 2: System Configuration Card
    
    @ViewBuilder
    private var systemConfigurationCard: some View {
        STSCard(elevation: .elevated) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "gearshape.fill")
                        .font(.title2)
                        .foregroundStyle(Theme.primary)
                    
                    Text("Configuration")
                        .font(.headline)
                        .foregroundStyle(Theme.textPrimary)
                }
                
                // PHASE 2: Enable/Disable Toggle
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Enable SmartFill")
                            .font(.subheadline)
                            .foregroundStyle(Theme.textPrimary)
                        
                        Text("Automatically convert portrait videos to landscape format")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    Toggle("", isOn: $smartFillSettings.defaultEnabled)
                        .onChange(of: smartFillSettings.defaultEnabled, initial: false) { _, newValue in
                            smartFillSettings.saveToUserDefaults()
                        }
                }
                
                Divider()
                
                // PHASE 2: Background Scale Slider
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Background Scale")
                            .font(.subheadline)
                            .foregroundStyle(Theme.textPrimary)
                        
                        Spacer()
                        
                        Text("\(String(format: "%.1f", smartFillSettings.backgroundScale))x")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(Theme.primary)
                    }
                    
                    Slider(value: $smartFillSettings.backgroundScale, in: 1.0...20.0, step: 0.5)
                        .tint(Theme.primary)
                        .onChange(of: smartFillSettings.backgroundScale, initial: false) { _, newValue in
                            smartFillSettings.saveToUserDefaults()
                        }
                    
                    Text("Higher values create more dramatic edge-to-edge fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                // PHASE 2: Quick presets
                HStack(spacing: 12) {
                    Button("Subtle (5x)") {
                        smartFillSettings.backgroundScale = 5.0
                        smartFillSettings.saveToUserDefaults()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    
                    Button("Default (10x)") {
                        smartFillSettings.backgroundScale = 10.0
                        smartFillSettings.saveToUserDefaults()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    
                    Button("Dramatic (15x)") {
                        smartFillSettings.backgroundScale = 15.0
                        smartFillSettings.saveToUserDefaults()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
    }
    
    // MARK: - Phase 2: Helper Views
    
    private func statusStatCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
            
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundStyle(Theme.textPrimary)
            
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Phase 2: Actions
    
    private func refreshSettings() {
        smartFillSettings = SmartFillSettings()
    }
}

#Preview {
    NavigationView {
        SmartFillMigrationDashboard()
    }
}
