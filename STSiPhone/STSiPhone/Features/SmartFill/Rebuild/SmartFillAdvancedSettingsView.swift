import SwiftUI

private enum SmartFillAdvancedPalette {
    static let theme = STSThemeLibrary.theme(for: .studioLobbyV1)
    static let accent = theme.primaryAccent
    static let textPrimary = theme.textPrimary
    static let textSecondary = theme.textSecondary
    static let background = theme.backgroundGradient
    static let panelFill = Color.white.opacity(0.07)
    static let panelStroke = Color.white.opacity(0.08)
    static let chipFill = Color.white.opacity(0.05)
}

struct SmartFillAdvancedSettingsView: View {
    @Binding var blurRadius: Double
    @Binding var darkenAmount: Double
    @Binding var backgroundScale: Double
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                SmartFillAdvancedPalette.background
                    .ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        studioIntroCard

                        adjustmentCard(
                            title: "Blur",
                            valueLabel: "\(Int(blurRadius)) px",
                            caption: blurCaption,
                            systemImage: "circle.dotted",
                            value: $blurRadius,
                            range: 8...50,
                            step: 2
                        )

                        adjustmentCard(
                            title: "Darken",
                            valueLabel: "\(Int(darkenAmount * 100))%",
                            caption: darkenCaption,
                            systemImage: "moon.fill",
                            value: $darkenAmount,
                            range: 0...0.3,
                            step: 0.02
                        )

                        adjustmentCard(
                            title: "Background Fill",
                            valueLabel: "\(String(format: "%.1f", backgroundScale))×",
                            caption: backgroundScaleCaption,
                            systemImage: "arrow.up.left.and.arrow.down.right",
                            value: $backgroundScale,
                            range: 1.0...15.0,
                            step: 0.5
                        )

                        previewCard
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 28)
                }
            }
            .navigationTitle("Studio Adjustments")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
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
            .tint(SmartFillAdvancedPalette.accent)
        }
    }

    private var studioIntroCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Background Studio")
                .font(.headline.weight(.semibold))
                .foregroundStyle(SmartFillAdvancedPalette.textPrimary)

            Text("Use these deeper backdrop controls when the main tray presets need more precision.")
                .font(.subheadline)
                .foregroundStyle(SmartFillAdvancedPalette.textSecondary)
        }
        .padding(18)
        .background(cardBackground)
    }

    private func adjustmentCard(
        title: String,
        valueLabel: String,
        caption: String,
        systemImage: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(SmartFillAdvancedPalette.accent)
                    .frame(width: 28, height: 28)
                    .background(SmartFillAdvancedPalette.chipFill, in: Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(SmartFillAdvancedPalette.textPrimary)

                    Text(caption)
                        .font(.caption)
                        .foregroundStyle(SmartFillAdvancedPalette.textSecondary)
                }

                Spacer()

                Text(valueLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(SmartFillAdvancedPalette.textPrimary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(SmartFillAdvancedPalette.chipFill, in: Capsule())
            }

            Slider(value: value, in: range, step: step) {
                Text(title)
            }
            .tint(SmartFillAdvancedPalette.accent)
        }
        .padding(18)
        .background(cardBackground)
    }

    private var previewCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Studio Preview")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(SmartFillAdvancedPalette.textPrimary)
                Spacer()
                Text("\(Int(blurRadius)) px • \(Int(darkenAmount * 100))%")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(SmartFillAdvancedPalette.textSecondary)
            }

            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white.opacity(0.06))
                        .blur(radius: CGFloat(blurRadius / 8))
                        .overlay(Color.black.opacity(darkenAmount))
                        .scaleEffect(min(backgroundScale / 5, 2.0))
                        .clipped()

                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(SmartFillAdvancedPalette.accent.opacity(0.85))
                        .frame(width: 48, height: 72)
                }
                .frame(width: 104, height: 76)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    previewLine(title: "Blur", value: "\(Int(blurRadius)) px")
                    previewLine(title: "Darken", value: "\(Int(darkenAmount * 100))%")
                    previewLine(title: "Fill", value: "\(String(format: "%.1f", backgroundScale))×")
                }

                Spacer(minLength: 0)
            }
        }
        .padding(18)
        .background(cardBackground)
    }

    private func previewLine(title: String, value: String) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(SmartFillAdvancedPalette.textPrimary)
            Text(value)
                .font(.caption)
                .foregroundStyle(SmartFillAdvancedPalette.textSecondary)
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(SmartFillAdvancedPalette.panelFill)
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(SmartFillAdvancedPalette.panelStroke, lineWidth: 1)
            )
    }

    private var blurCaption: String {
        switch blurRadius {
        case ..<18:
            return "Keep more room detail visible."
        case 18..<32:
            return "Balanced separation for most SmartFill passes."
        default:
            return "Push the room further back behind the subject."
        }
    }

    private var darkenCaption: String {
        switch darkenAmount {
        case ..<0.08:
            return "Very light darkening keeps the room natural."
        case 0.08..<0.18:
            return "Balanced darkening keeps attention on the subject."
        default:
            return "Strong darkening hides distracting room detail."
        }
    }

    private var backgroundScaleCaption: String {
        switch backgroundScale {
        case 1.0..<2.0:
            return "Minimal fill keeps more of the source visible."
        case 2.0..<5.0:
            return "Light fill removes modest edge gaps."
        case 5.0..<8.0:
            return "Balanced fill is a good studio default."
        case 8.0..<12.0:
            return "Strong fill hides most room edges."
        default:
            return "Maximum fill aggressively removes background gaps."
        }
    }
}
