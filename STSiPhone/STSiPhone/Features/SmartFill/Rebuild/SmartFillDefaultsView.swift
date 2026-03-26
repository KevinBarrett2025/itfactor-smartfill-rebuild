import SwiftUI

struct SmartFillDefaultsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var settings = SmartFillSettings()
    @State private var showAdvancedSettings = false

    var body: some View {
        NavigationStack {
            ZStack {
                BrandBackground()
                    .ignoresSafeArea()

                List {
                    Section("Default Behavior") {
                        Toggle(isOn: isEnabledBinding) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Enable SmartFill by default")
                                    .foregroundStyle(Theme.textPrimary)
                                Text("New SmartFill sessions start from these defaults unless the selected take already has saved settings.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .toggleStyle(SwitchToggleStyle(tint: Theme.primary))
                        .listRowBackground(Color.clear)
                    }

                    Section("Default Look") {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Choose the starting look for new SmartFill sessions.")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            ForEach(SmartFillSettings.Preset.allCases, id: \.rawValue) { preset in
                                Button {
                                    applyPreset(preset)
                                } label: {
                                    HStack(spacing: 12) {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(presetTitle(for: preset))
                                                .font(.body.weight(.semibold))
                                                .foregroundStyle(Theme.textPrimary)
                                            Text(presetCaption(for: preset))
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }

                                        Spacer()

                                        Image(systemName: selectedPresetName == presetTitle(for: preset) ? "checkmark.circle.fill" : "circle")
                                            .foregroundStyle(selectedPresetName == presetTitle(for: preset) ? Theme.primary : .secondary)
                                    }
                                    .padding(.vertical, 6)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .listRowBackground(Color.clear)
                    }

                    Section("Current Defaults") {
                        defaultsSummaryRow(title: "Blur", value: "\(Int(settings.blurRadius)) px")
                        defaultsSummaryRow(title: "Darken", value: "\(Int(settings.darkenAmount * 100))%")
                        defaultsSummaryRow(title: "Background Scale", value: String(format: "%.1f×", settings.backgroundScale))
                        defaultsSummaryRow(title: "Output", value: "\(Int(settings.renderSize.width))×\(Int(settings.renderSize.height))")
                    }

                    Section("Export Defaults") {
                        Menu {
                            Button("1920×1080 (Full HD)") {
                                settings.renderSize = CGSize(width: 1920, height: 1080)
                                persistDefaults()
                            }
                            Button("1280×720 (HD)") {
                                settings.renderSize = CGSize(width: 1280, height: 720)
                                persistDefaults()
                            }
                            Button("3840×2160 (4K)") {
                                settings.renderSize = CGSize(width: 3840, height: 2160)
                                persistDefaults()
                            }
                        } label: {
                            HStack {
                                Text("Render Size")
                                    .foregroundStyle(Theme.textPrimary)
                                Spacer()
                                Text("\(Int(settings.renderSize.width))×\(Int(settings.renderSize.height))")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .listRowBackground(Color.clear)

                        Button {
                            showAdvancedSettings = true
                        } label: {
                            HStack {
                                Text("Advanced Defaults")
                                    .foregroundStyle(Theme.textPrimary)
                                Spacer()
                                Image(systemName: "slider.horizontal.3")
                                    .foregroundStyle(Theme.primary)
                            }
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(Color.clear)
                    }

                    Section("How It Fits") {
                        Text("These defaults seed the rebuild workspace when a take does not already carry its own SmartFill settings. Review, player, and editor entry all share the same starting values.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 6)
                            .listRowBackground(Color.clear)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("SmartFill Defaults")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showAdvancedSettings) {
                SmartFillAdvancedSettingsView(
                    blurRadius: blurRadiusBinding,
                    darkenAmount: darkenAmountBinding,
                    backgroundScale: backgroundScaleBinding
                )
            }
        }
    }

    private var isEnabledBinding: Binding<Bool> {
        Binding(
            get: { settings.isEnabled },
            set: { newValue in
                settings.isEnabled = newValue
                persistDefaults()
            }
        )
    }

    private var blurRadiusBinding: Binding<Double> {
        Binding(
            get: { Double(settings.blurRadius) },
            set: { newValue in
                settings.blurRadius = CGFloat(newValue)
                persistDefaults()
            }
        )
    }

    private var darkenAmountBinding: Binding<Double> {
        Binding(
            get: { Double(settings.darkenAmount) },
            set: { newValue in
                settings.darkenAmount = CGFloat(newValue)
                persistDefaults()
            }
        )
    }

    private var backgroundScaleBinding: Binding<Double> {
        Binding(
            get: { Double(settings.backgroundScale) },
            set: { newValue in
                settings.backgroundScale = CGFloat(newValue)
                persistDefaults()
            }
        )
    }

    private var selectedPresetName: String? {
        settings.presetName?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func defaultsSummaryRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(Theme.textPrimary)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
        }
        .listRowBackground(Color.clear)
    }

    private func applyPreset(_ preset: SmartFillSettings.Preset) {
        settings.blurRadius = preset.blurRadius
        settings.darkenAmount = preset.darkenAmount
        settings.backgroundScale = preset.backgroundScale
        settings.presetName = presetTitle(for: preset)
        persistDefaults()
    }

    private func persistDefaults() {
        settings.forceUpdateToken = UUID()
        settings.saveToUserDefaults()
    }

    private func presetTitle(for preset: SmartFillSettings.Preset) -> String {
        switch preset {
        case .subtle: return "Subtle"
        case .medium: return "Medium"
        case .dramatic: return "Dramatic"
        }
    }

    private func presetCaption(for preset: SmartFillSettings.Preset) -> String {
        switch preset {
        case .subtle:
            return "Light blur and minimal darkening."
        case .medium:
            return "Balanced fill for most sessions."
        case .dramatic:
            return "Stronger blur and heavier background treatment."
        }
    }
}
