import SwiftUI

struct ActorKitBadgeControlsPanel: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @AppStorage("ActorKit.disableBadgeAnimation") private var disableBadgeAnimation = false
    @AppStorage("ActorKit.badgeSpeedMultiplier") private var badgeSpeedMultiplier: Double = 1.0
    @AppStorage("ActorKit.badgeStopFace") private var badgeStopFaceRaw: String = ActorKitBadgeStopFace.logo.rawValue

    private var theme: STSTheme { themeManager.current }
    private var secondaryColor: Color {
        theme.id == .takeReviewClassic ? Color.black.opacity(0.65) : .white.opacity(0.65)
    }
    private var selectedStopFace: ActorKitBadgeStopFace {
        ActorKitBadgeStopFace(rawValue: badgeStopFaceRaw) ?? .logo
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Toggle("Stop badge animation", isOn: $disableBadgeAnimation)
                .toggleStyle(SwitchToggleStyle(tint: Theme.primary))

            Text("Spinner motion also respects Reduce Motion in Accessibility settings.")
                .font(Theme.Font.caption2)
                .foregroundStyle(secondaryColor)

            VStack(alignment: .leading, spacing: 8) {
                Text("Resting Face")
                    .font(Theme.Font.caption)
                    .foregroundStyle(.white.opacity(0.85))

                Picker("Resting Face", selection: $badgeStopFaceRaw) {
                    ForEach(ActorKitBadgeStopFace.allCases) { face in
                        Text(face.displayName).tag(face.rawValue)
                    }
                }
                .pickerStyle(.segmented)

                Text(selectedStopFace.description)
                    .font(Theme.Font.caption2)
                    .foregroundStyle(secondaryColor)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Animation Speed")
                        .font(Theme.Font.caption)
                        .foregroundStyle(secondaryColor)
                    Spacer()
                    Text(String(format: "%.2fx", badgeSpeedMultiplier))
                        .font(Theme.Font.caption)
                        .foregroundStyle(secondaryColor)
                }
                Slider(value: $badgeSpeedMultiplier, in: 0.25...2.5, step: 0.05)
                    .disabled(disableBadgeAnimation)
                    .opacity(disableBadgeAnimation ? 0.4 : 1)
                HStack {
                    Text("Slower")
                    Spacer()
                    Text("Faster")
                }
                .font(Theme.Font.caption2)
                .foregroundStyle(secondaryColor)
            }
        }
    }
}
