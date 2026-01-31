import SwiftUI

/// Smart Fill settings configuration view
/// Allows users to configure global Smart Fill behavior and presets
struct SmartFillSettingsView: View {
    @AppStorage("smartFillDefaultEnabled") private var defaultEnabled = true
    @AppStorage("smartFillBlurRadius") private var blurRadius: Double = 24.0
    @AppStorage("smartFillDarkenAmount") private var darkenAmount: Double = 0.12
    @AppStorage("smartFillBackgroundScale") private var backgroundScale: Double = 10.0 // 🎯 ENTERPRISE: Background scale tuning (#275)
    @AppStorage("smartFillRenderWidth") private var renderWidth: Double = 1920
    @AppStorage("smartFillRenderHeight") private var renderHeight: Double = 1080
    @AppStorage("smartFillPresetName") private var selectedPresetName = "Medium"
    
    @State private var showingAdvancedSettings = false
    
    var body: some View {
        ZStack {
            BrandBackground()
                .ignoresSafeArea()
            
            List {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "rectangle.fill.badge.checkmark")
                                .font(.title2)
                                .foregroundStyle(Theme.primary)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Smart Portrait Fill")
                                    .font(.headline)
                                    .foregroundStyle(Theme.textPrimary)
                                
                                Text("Automatically enhance portrait videos in landscape sessions with a blurred background")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.leading)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("Smart Fill")
                }
                .listRowBackground(Color.clear)
                
                if defaultEnabled {
                    Section("Quality Presets") {
                        SmartFillPresetRow(
                            title: "Subtle",
                            description: "Light blur, minimal darkening",
                            isSelected: selectedPresetName == "Subtle",
                            preset: .subtle
                        ) {
                            applyPreset(.subtle)
                        }
                        .listRowBackground(Color.clear)
                        
                        SmartFillPresetRow(
                            title: "Medium",
                            description: "Balanced blur and darkening",
                            isSelected: selectedPresetName == "Medium",
                            preset: .medium
                        ) {
                            applyPreset(.medium)
                        }
                        .listRowBackground(Color.clear)
                        
                        SmartFillPresetRow(
                            title: "Dramatic",
                            description: "Strong blur, pronounced darkening",
                            isSelected: selectedPresetName == "Dramatic",
                            preset: .dramatic
                        ) {
                            applyPreset(.dramatic)
                        }
                        .listRowBackground(Color.clear)
                    }
                    
                    Section("Advanced Settings") {
                        SettingsRow(
                            icon: "slider.horizontal.3",
                            title: "Custom Settings",
                            subtitle: "Fine-tune blur and darkness",
                            action: {
                                showingAdvancedSettings = true
                            }
                        )
                        .listRowBackground(Color.clear)
                    }
                    
                    Section("Export Quality") {
                        HStack {
                            Text("Render Size")
                                .foregroundStyle(Theme.textPrimary)
                            
                            Spacer()
                            
                            Menu {
                                Button("1920×1080 (Full HD)") {
                                    renderWidth = 1920
                                    renderHeight = 1080
                                }
                                Button("1280×720 (HD)") {
                                    renderWidth = 1280
                                    renderHeight = 720
                                }
                                Button("3840×2160 (4K)") {
                                    renderWidth = 3840
                                    renderHeight = 2160
                                }
                            } label: {
                                Text("\(Int(renderWidth))×\(Int(renderHeight))")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .listRowBackground(Color.clear)
                    }
                }
                
                Section("How It Works") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 12) {
                            Image(systemName: "1.circle.fill")
                                .foregroundStyle(Theme.primary)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Detection")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text("App identifies portrait videos in landscape sessions")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        HStack(spacing: 12) {
                            Image(systemName: "2.circle.fill")
                                .foregroundStyle(Theme.primary)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Enhancement")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text("Creates blurred background from the same video")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        HStack(spacing: 12) {
                            Image(systemName: "3.circle.fill")
                                .foregroundStyle(Theme.primary)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Export")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text("Composite preserves your performance while filling the frame")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                    .listRowBackground(Color.clear)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Smart Fill")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingAdvancedSettings) {
            SmartFillAdvancedSettingsView(
                blurRadius: $blurRadius,
                darkenAmount: $darkenAmount,
                backgroundScale: $backgroundScale // 🎯 ENTERPRISE: Pass background scale to advanced settings
            )
        }
        .stsPortraitOnly(label: "SmartFillSettingsView")
    }
    
    private func applyPreset(_ preset: SmartFillSettings.Preset) {
        selectedPresetName = presetName(for: preset)
        blurRadius = Double(preset.blurRadius)
        darkenAmount = Double(preset.darkenAmount)
        backgroundScale = Double(preset.backgroundScale)
        
    }
    
    private func presetName(for preset: SmartFillSettings.Preset) -> String {
        switch preset {
        case .subtle: return "Subtle"
        case .medium: return "Medium"
        case .dramatic: return "Dramatic"
        }
    }
    
    var currentSettings: SmartFillSettings {
        return SmartFillSettings(
            defaultEnabled: defaultEnabled,
            defaultBlurRadius: CGFloat(blurRadius),
            defaultDarkenAmount: CGFloat(darkenAmount),
            defaultRenderSize: CGSize(width: renderWidth, height: renderHeight),
            backgroundScale: CGFloat(backgroundScale) // 🎯 ENTERPRISE: Include background scale in settings
        )
    }
}

struct SmartFillPresetRow: View {
    let title: String
    let description: String
    let isSelected: Bool
    let preset: SmartFillSettings.Preset
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.body)
                        .foregroundStyle(Theme.textPrimary)
                    
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    HStack(spacing: 8) {
                        HStack(spacing: 4) {
                            Image(systemName: "circle.dotted")
                                .font(.caption2)
                            Text("\(Int(preset.blurRadius))px")
                                .font(.caption2)
                        }
                        .foregroundStyle(.secondary)
                        
                        HStack(spacing: 4) {
                            Image(systemName: "moon.fill")
                                .font(.caption2)
                            Text("\(Int(preset.darkenAmount * 100))%")
                                .font(.caption2)
                        }
                        .foregroundStyle(.secondary)
                        
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                .font(.caption2)
                            Text(String(format: "%.1f×", preset.backgroundScale))
                                .font(.caption2)
                        }
                        .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(Theme.primary)
                } else {
                    Image(systemName: "circle")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Advanced Settings Sheet

struct SmartFillAdvancedSettingsView: View {
    @Binding var blurRadius: Double
    @Binding var darkenAmount: Double
    @Binding var backgroundScale: Double // 🎯 ENTERPRISE: Background scale slider (#275)
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                BrandBackground()
                    .ignoresSafeArea()
                
                List {
                    Section("Blur Settings") {
                        VStack(spacing: 16) {
                            HStack {
                                Text("Blur Radius")
                                    .foregroundStyle(Theme.textPrimary)
                                Spacer()
                                Text("\(Int(blurRadius))px")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Slider(value: $blurRadius, in: 8...50, step: 2) {
                                Text("Blur Radius")
                            }
                            .tint(Theme.primary)
                        }
                        .padding(.vertical, 8)
                        .listRowBackground(Color.clear)
                    }
                    
                    Section("Darkening Settings") {
                        VStack(spacing: 16) {
                            HStack {
                                Text("Darken Amount")
                                    .foregroundStyle(Theme.textPrimary)
                                Spacer()
                                Text("\(Int(darkenAmount * 100))%")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Slider(value: $darkenAmount, in: 0...0.3, step: 0.02) {
                                Text("Darken Amount")
                            }
                            .tint(Theme.primary)
                        }
                        .padding(.vertical, 8)
                        .listRowBackground(Color.clear)
                    }
                    
                    // 🎯 ENTERPRISE: Background scale section (#275)
                    Section {
                        VStack(spacing: 16) {
                            HStack {
                                Text("Background Scale")
                                    .foregroundStyle(Theme.textPrimary)
                                Spacer()
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("\(String(format: "%.1f", backgroundScale))×")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(backgroundScaleDescription)
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            
                            Slider(value: $backgroundScale, in: 1.0...15.0, step: 0.5) {
                                Text("Background Scale")
                            }
                            .tint(Theme.primary)
                        }
                        .padding(.vertical, 8)
                        .listRowBackground(Color.clear)
                    } header: {
                        Text("Background Scaling")
                    } footer: {
                        Text("Controls how much the background image is scaled to fill the frame. Higher values eliminate black bars but crop more of the source.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Section("Preview") {
                        VStack(spacing: 12) {
                            Text("Effect Preview")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(Theme.textPrimary)
                            
                            HStack(spacing: 16) {
                                // Mock preview rectangles with background scale visual
                                ZStack {
                                    // Background layer - shows scaling effect
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(.secondary.opacity(0.3))
                                        .blur(radius: CGFloat(blurRadius / 8))
                                        .overlay(
                                            Color.black.opacity(darkenAmount)
                                        )
                                        .scaleEffect(min(backgroundScale / 5, 2.0)) // Visual representation of scaling
                                        .clipped()
                                    
                                    // Foreground layer
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Theme.primary.opacity(0.8))
                                        .frame(width: 40, height: 60)
                                }
                                .frame(width: 80, height: 60)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Background")
                                        .font(.caption2)
                                        .fontWeight(.medium)
                                    Text("Blur: \(Int(blurRadius))px")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                    Text("Dark: \(Int(darkenAmount * 100))%")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                    Text("Scale: \(String(format: "%.1f", backgroundScale))×")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                
                                Spacer()
                            }
                        }
                        .padding(.vertical, 8)
                        .listRowBackground(Color.clear)
                    }
                    
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Advanced Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    // 🎯 ENTERPRISE: Helpful descriptions for background scale values
    private var backgroundScaleDescription: String {
        switch backgroundScale {
        case 1.0..<2.0:
            return "Minimal"
        case 2.0..<5.0:
            return "Light"
        case 5.0..<8.0:
            return "Moderate"
        case 8.0..<12.0:
            return "Strong"
        default:
            return "Maximum"
        }
    }
}

#Preview {
    NavigationView {
        SmartFillSettingsView()
    }
}
