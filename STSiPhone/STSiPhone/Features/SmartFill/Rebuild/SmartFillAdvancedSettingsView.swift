import SwiftUI

struct SmartFillAdvancedSettingsView: View {
    @Binding var blurRadius: Double
    @Binding var darkenAmount: Double
    @Binding var backgroundScale: Double
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
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(.secondary.opacity(0.3))
                                        .blur(radius: CGFloat(blurRadius / 8))
                                        .overlay(
                                            Color.black.opacity(darkenAmount)
                                        )
                                        .scaleEffect(min(backgroundScale / 5, 2.0))
                                        .clipped()

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
