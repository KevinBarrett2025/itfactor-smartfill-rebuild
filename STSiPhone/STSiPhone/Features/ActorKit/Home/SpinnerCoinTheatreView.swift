import SwiftUI

struct SpinnerCoinTheatreView: View {
    @Environment(\.dismiss) private var dismiss

    let headshot: UIImage?
    let headshotTransform: HeadshotTransform?
    var onClose: (() -> Void)?

    @AppStorage("SpinnerCoinPresetID") private var spinnerPresetID = SpinnerCoinPreset.turnstile.id
    @AppStorage("SpinnerCoinAcceleration") private var spinnerAcceleration: Double = 1.0
    @AppStorage("SpinnerCoinGlow") private var spinnerGlow: Double = 0.35
    @AppStorage("SpinnerCoinHaptics") private var spinnerHaptics: Double = 0.6
    @AppStorage("SpinnerCoinSparks") private var spinnerSparks: Double = 0.5
    @AppStorage("SpinnerCoinSparkSpread") private var spinnerSparkSpread: Double = 0.6
    @AppStorage("SpinnerCoinGlowEnabled") private var spinnerGlowEnabled: Bool = true
    @AppStorage("SpinnerCoinHapticsEnabled") private var spinnerHapticsEnabled: Bool = true
    @AppStorage("SpinnerCoinSparksEnabled") private var spinnerSparksEnabled: Bool = true
    @AppStorage("SpinnerCoinYoYoEnabled") private var spinnerYoYoEnabled: Bool = SpinnerYoYoConfig.default.isEnabled
    @AppStorage("SpinnerCoinYoYoDepth") private var spinnerYoYoDepth: Double = 0.18
    @AppStorage("SpinnerCoinYoYoLift") private var spinnerYoYoLift: Double = 0.22
    @AppStorage("SpinnerCoinYoYoFrequency") private var spinnerYoYoFrequency: Double = 3.5
    @AppStorage("SpinnerCoinYoYoDamping") private var spinnerYoYoDamping: Double = 0.65
    @AppStorage("SpinnerCoinYoYoThreshold") private var spinnerYoYoThreshold: Double = 600
    @AppStorage("ActorKit.disableBadgeAnimation") private var disableBadgeAnimation = false
    @AppStorage("ActorKit.badgeStopFace") private var badgeStopFaceRaw: String = ActorKitBadgeStopFace.logo.rawValue

    private var badgeStopFace: ActorKitBadgeStopFace {
        ActorKitBadgeStopFace(rawValue: badgeStopFaceRaw) ?? .logo
    }

    private var spinnerPreset: SpinnerCoinPreset {
        SpinnerCoinPreset.preset(for: spinnerPresetID)
    }

    private var spinnerTuning: SpinnerCoinTuning {
        SpinnerCoinTuning(
            acceleration: CGFloat(spinnerAcceleration),
            glow: CGFloat(spinnerGlow),
            haptics: CGFloat(spinnerHaptics),
            sparks: CGFloat(spinnerSparks),
            sparkSpread: CGFloat(spinnerSparkSpread),
            glowEnabled: spinnerGlowEnabled,
            hapticsEnabled: spinnerHapticsEnabled,
            sparksEnabled: spinnerSparksEnabled
        )
    }

    private var spinnerYoYoConfig: SpinnerYoYoConfig {
        SpinnerYoYoConfig(
            isEnabled: spinnerYoYoEnabled,
            maxDepthOffset: CGFloat(spinnerYoYoDepth),
            maxVerticalOffset: CGFloat(spinnerYoYoLift),
            flingVelocityThreshold: CGFloat(spinnerYoYoThreshold),
            springFrequency: CGFloat(spinnerYoYoFrequency),
            springDampingRatio: CGFloat(spinnerYoYoDamping)
        )
    }

    var body: some View {
        GeometryReader { geo in
            let portrait = geo.size.height >= geo.size.width
            let spinnerHeight = portrait
                ? min(geo.size.width, geo.size.height) - 60
                : min(geo.size.width, geo.size.height) - 20
            let topSpacing = portrait ? geo.size.height * 0.04 : geo.size.height * 0.12
            let bottomSpacing = portrait ? geo.size.height * 0.22 : geo.size.height * 0.12

            ZStack {
                Color.black.opacity(0.85).ignoresSafeArea()
                VStack {
                    HStack {
                        Spacer()
                        Button(action: handleClose) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(.white.opacity(0.95))
                                .padding(24)
                        }
                    }

                    Spacer(minLength: topSpacing)

                    SpinnerCoinView(
                        headshot: headshot,
                        transform: headshotTransform,
                        height: spinnerHeight,
                        animationDisabled: disableBadgeAnimation,
                        restAngleDegrees: badgeStopFace.restAngleDegrees,
                        preset: spinnerPreset,
                        tuning: spinnerTuning,
                        yoYoConfig: spinnerYoYoConfig
                    )
                    .overlay(SpinnerOverlay())
                    .padding(24)
                    .background(spinnerBackdrop(spinnerHeight: spinnerHeight))
                    .padding(.bottom, portrait ? geo.size.height * 0.04 : geo.size.height * 0.01)

                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: portrait ? 24 : 18) {
                            presetSelector
                            tuningControls
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, portrait ? geo.size.height * 0.04 : geo.size.height * 0.02)
                        .padding(.bottom, portrait ? geo.size.height * 0.12 : geo.size.height * 0.06)
                    }

                    Spacer(minLength: portrait ? geo.size.height * 0.03 : bottomSpacing)
                }
            }
        }
        .ignoresSafeArea()
    }

    private func spinnerBackdrop(spinnerHeight: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.05, green: 0.04, blue: 0.08).opacity(0.8),
                            Color(red: 0.12, green: 0.08, blue: 0.16).opacity(0.5)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: spinnerHeight, height: spinnerHeight)
                .shadow(color: Color.black.opacity(0.35), radius: 40, x: 0, y: 30)

            Circle()
                .strokeBorder(Color.black.opacity(0.75), lineWidth: 3)
                .frame(width: spinnerHeight - 30, height: spinnerHeight - 30)
        }
        .opacity(0.85)
    }

    private var presetSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Spin Modes")
                .font(.caption.weight(.semibold))
                .foregroundColor(.white.opacity(0.85))

            HStack(spacing: 10) {
                ForEach(SpinnerCoinPreset.allPresets) { preset in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            spinnerPresetID = preset.id
                        }
                    } label: {
                        Text(preset.name)
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule().fill(
                                    spinnerPreset.id == preset.id
                                    ? Color.white.opacity(0.3)
                                    : Color.white.opacity(0.12)
                                )
                            )
                            .foregroundColor(.white)
                    }
                    .accessibilityLabel("Select \(preset.name) spin mode")
                }
            }

            Text(spinnerPreset.description)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.7))
                .padding(.top, 4)
        }
    }

    private var tuningControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tuning Playground")
                .font(.caption.weight(.semibold))
                .foregroundColor(.white.opacity(0.85))

            tuningSliderRow(
                title: "Acceleration",
                symbol: "speedometer",
                value: Binding(
                    get: { spinnerAcceleration },
                    set: { spinnerAcceleration = $0 }
                ),
                display: { String(format: "%.1fx", $0) },
                range: 0.6...1.6
            )

            tuningToggleRow(
                title: "Glow FX",
                symbol: "wand.and.stars",
                isOn: Binding(
                    get: { spinnerGlowEnabled },
                    set: { spinnerGlowEnabled = $0 }
                )
            )

            tuningSliderRow(
                title: "Glow Intensity",
                symbol: "sparkles",
                value: Binding(
                    get: { spinnerGlow },
                    set: { spinnerGlow = $0 }
                ),
                display: { String(format: "%.0f%%", $0 * 100) },
                range: 0...1,
                isDisabled: !spinnerGlowEnabled
            )

            tuningToggleRow(
                title: "Haptics",
                symbol: "hand.tap",
                isOn: Binding(
                    get: { spinnerHapticsEnabled },
                    set: { spinnerHapticsEnabled = $0 }
                )
            )

            tuningSliderRow(
                title: "Haptics",
                symbol: "waveform.path",
                value: Binding(
                    get: { spinnerHaptics },
                    set: { spinnerHaptics = $0 }
                ),
                display: { newValue in
                    newValue <= 0.05 ? "Off" : String(format: "%.0f%%", newValue * 100)
                },
                range: 0...1,
                isDisabled: !spinnerHapticsEnabled
            )

            tuningToggleRow(
                title: "Sparks",
                symbol: "flame",
                isOn: Binding(
                    get: { spinnerSparksEnabled },
                    set: { spinnerSparksEnabled = $0 }
                )
            )

            tuningSliderRow(
                title: "Sparks",
                symbol: "sparkles",
                value: Binding(
                    get: { spinnerSparks },
                    set: { spinnerSparks = $0 }
                ),
                display: { String(format: "%.0f%%", $0 * 100) },
                range: 0...1,
                isDisabled: !spinnerSparksEnabled
            )

            tuningSliderRow(
                title: "Spark Spread",
                symbol: "circle.dashed",
                value: Binding(
                    get: { spinnerSparkSpread },
                    set: { spinnerSparkSpread = $0 }
                ),
                display: { spread in
                    let degrees = 20 + spread * 70
                    return String(format: "%.0f°", degrees)
                },
                range: 0...1,
                isDisabled: !spinnerSparksEnabled
            )

            Divider().background(Color.white.opacity(0.1))

            tuningToggleRow(
                title: "Yo-Yo Motion",
                symbol: "arrow.triangle.2.circlepath",
                isOn: Binding(
                    get: { spinnerYoYoEnabled },
                    set: { spinnerYoYoEnabled = $0 }
                )
            )

            tuningSliderRow(
                title: "Yo-Yo Depth Travel",
                symbol: "arrow.down.right.and.arrow.up.left",
                value: Binding(
                    get: { spinnerYoYoDepth },
                    set: { spinnerYoYoDepth = $0 }
                ),
                display: { depth in
                    let millimeters = depth * 1000
                    return String(format: "%.0f mm", millimeters)
                },
                range: 0...0.35,
                isDisabled: !spinnerYoYoEnabled
            )

            tuningSliderRow(
                title: "Yo-Yo Lift",
                symbol: "arrow.up.and.down",
                value: Binding(
                    get: { spinnerYoYoLift },
                    set: { spinnerYoYoLift = $0 }
                ),
                display: { lift in
                    let millimeters = lift * 1000
                    return String(format: "%.0f mm", millimeters)
                },
                range: 0...0.35,
                isDisabled: !spinnerYoYoEnabled
            )

            tuningSliderRow(
                title: "Yo-Yo Bounce",
                symbol: "waveform",
                value: Binding(
                    get: { spinnerYoYoFrequency },
                    set: { spinnerYoYoFrequency = $0 }
                ),
                display: { freq in
                    String(format: "%.1f Hz", freq)
                },
                range: 1.5...6.0,
                isDisabled: !spinnerYoYoEnabled
            )

            tuningSliderRow(
                title: "Yo-Yo Damping",
                symbol: "drop",
                value: Binding(
                    get: { spinnerYoYoDamping },
                    set: { spinnerYoYoDamping = $0 }
                ),
                display: { value in
                    String(format: "%.2f", value)
                },
                range: 0.3...0.95,
                isDisabled: !spinnerYoYoEnabled
            )

            tuningSliderRow(
                title: "Fling Sensitivity",
                symbol: "bolt",
                value: Binding(
                    get: { spinnerYoYoThreshold },
                    set: { spinnerYoYoThreshold = $0 }
                ),
                display: { value in
                    String(format: "%.0f pts/s", value)
                },
                range: 300...1400,
                isDisabled: !spinnerYoYoEnabled
            )
        }
    }

    private func tuningSliderRow(title: String,
                                 symbol: String,
                                 value: Binding<Double>,
                                 display: @escaping (Double) -> String,
                                 range: ClosedRange<Double>,
                                 isDisabled: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Label(title, systemImage: symbol)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
                    .labelStyle(.titleAndIcon)
                Spacer()
                Text(display(value.wrappedValue))
                    .font(.caption2.monospacedDigit())
                    .foregroundColor(.white.opacity(0.8))
            }

            Slider(value: value, in: range)
                .tint(.white)
                .disabled(isDisabled)
        }
    }

    private func tuningToggleRow(title: String,
                                 symbol: String,
                                 isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            Label(title, systemImage: symbol)
                .font(.caption)
                .foregroundColor(.white.opacity(0.85))
        }
        .toggleStyle(SwitchToggleStyle(tint: .white))
        .padding(.top, 4)
    }

    private func handleClose() {
        if let onClose {
            onClose()
        } else {
            dismiss()
        }
    }
}
