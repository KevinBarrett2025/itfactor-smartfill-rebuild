import SwiftUI
import UIKit

struct LayoutDesignerView: View {
    let profile: ActorProfile
    let reps: [RepInfo]
    @Binding var config: SizeCardConfig
    let onClose: () -> Void

    @State private var measurementExpanded = true
#if DEBUG
    @State private var debugPreviewMode: DebugPreviewMode = .worstCase
    @State private var debugOverlayEnabled = true
#endif

    private static let coreFields: [SizeCardMeasurementField] = [
        .waist, .inseam, .glove, .hat, .shirt, .pant, .shoe
    ]
    private static let menFields: [SizeCardMeasurementField] = [
        .chest, .neck, .sleeve, .coat, .mensTShirt, .mensShoe, .mensShoeWidth
    ]
    private static let womenFields: [SizeCardMeasurementField] = [
        .dress, .bust, .underbust, .cup, .hip,
        .womensTShirt, .womensPants, .womensShoe, .womensShoeWidth
    ]
    private static let youthFields: [SizeCardMeasurementField] = [
        .boys, .girls, .toddlers, .infants, .kidsShoe, .kidsSpecial
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    ScaledSizeCardPreview(
                        profile: profile,
                        reps: reps,
                        config: config,
                        maxWidth: min(UIScreen.main.bounds.width - 48, 820),
                        maxHeight: 420
                    )
                    .padding(.top, 16)
#if DEBUG
                    .environment(\.sizeCardDebugOverlayEnabled, debugOverlayEnabled)
#endif

                    VStack(spacing: 18) {
                        let isAutoLayout = config.columnStyle == .auto
                        Picker("Columns", selection: $config.columnStyle) {
                            ForEach(SizeCardColumnStyle.allCases, id: \.self) { style in
                                Text(style.displayName).tag(style)
                            }
                        }
                        .pickerStyle(.segmented)

                        LayoutSliderControl(
                            title: "Bold label size",
                            value: $config.labelFontScale,
                            range: 0.8...1.4
                        )

                        LayoutSliderControl(
                            title: "Plain value size",
                            value: $config.valueFontScale,
                            range: 0.8...1.4
                        )

                        LayoutSliderControl(
                            title: "Spacing",
                            value: $config.spacingScale,
                            range: 0.7...1.3
                        )

                        LayoutSliderControl(
                            title: "Likeness details offset",
                            value: Binding(
                                get: { CGFloat(config.lookDetailsOffset.y) },
                                set: { config.lookDetailsOffset.y = Double($0) }
                            ),
                            range: -150...150
                        )
                        .disabled(isAutoLayout)

                        LayoutSliderControl(
                            title: "Detail column offset",
                            value: Binding(
                                get: { CGFloat(config.detailColumnOffset.y) },
                                set: { config.detailColumnOffset.y = Double($0) }
                            ),
                            range: -150...150
                        )
                        .disabled(isAutoLayout)

                        LayoutSliderControl(
                            title: "Rep box offset",
                            value: Binding(
                                get: { CGFloat(config.repBoxOffset.y) },
                                set: { config.repBoxOffset.y = Double($0) }
                            ),
                            range: -150...150
                        )
                        .disabled(isAutoLayout)

                        if isAutoLayout {
                            Text("Offsets are clamped in Auto layout to keep content within safe margins.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        DisclosureGroup(isExpanded: $measurementExpanded) {
                            VStack(spacing: 16) {
                                MeasurementToggleSection(
                                    title: "Core Sizes",
                                    fields: Self.coreFields,
                                    profile: profile,
                                    config: $config
                                )
                                if profile.sex == .male || profile.sex == .undisclosed {
                                    MeasurementToggleSection(
                                        title: "Men's Sizes",
                                        fields: Self.menFields,
                                        profile: profile,
                                        config: $config
                                    )
                                }
                                if profile.sex == .female || profile.sex == .undisclosed {
                                    MeasurementToggleSection(
                                        title: "Women's Sizes",
                                        fields: Self.womenFields,
                                        profile: profile,
                                        config: $config
                                    )
                                }
                                if profile.isYouthTalent {
                                    MeasurementToggleSection(
                                        title: "Youth Sizes",
                                        fields: Self.youthFields,
                                        profile: profile,
                                        config: $config
                                    )
                                }
                            }
                            .padding(.top, 8)
                        } label: {
                            Label("Show / Hide Measurements", systemImage: "checklist")
                                .font(.headline)
                        }
                    }
                    .padding(.horizontal)
#if DEBUG
                    debugWorstCaseSection
#endif
                }
                .padding(.bottom, 32)
            }
            .navigationTitle("Layout Designer")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { onClose() }
                }
            }
        }
    }

#if DEBUG
    private enum DebugPreviewMode: String, CaseIterable {
        case worstCase = "Worst Case"
        case currentProfile = "Current Profile"
    }

    private var debugWorstCaseSection: some View {
        let previewProfile = debugPreviewMode == .worstCase ? SizeCardDebugFixtures.worstCaseProfile : profile
        let previewReps = debugPreviewMode == .worstCase ? SizeCardDebugFixtures.worstCaseReps : reps
        let previewConfig = debugPreviewMode == .worstCase ? SizeCardDebugFixtures.worstCaseConfig : config

        return VStack(alignment: .leading, spacing: 12) {
            Text("Worst Case Auto-Fit (Debug)")
                .font(.headline)
            Picker("Debug Data", selection: $debugPreviewMode) {
                ForEach(DebugPreviewMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            Toggle("Show Fit Overlay", isOn: $debugOverlayEnabled)
                .font(.caption)
            ScaledSizeCardPreview(
                profile: previewProfile,
                reps: previewReps,
                config: previewConfig,
                maxWidth: min(UIScreen.main.bounds.width - 48, 820),
                maxHeight: 420
            )
            .environment(\.sizeCardDebugOverlayEnabled, debugOverlayEnabled)
            Text("Toggle between worst-case fields and current profile data.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }
#endif
}

private struct LayoutSliderControl: View {
    let title: String
    @Binding var value: CGFloat
    let range: ClosedRange<CGFloat>

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                let span = max(range.upperBound - range.lowerBound, 0.0001)
                let progress = (value - range.lowerBound) / span
                Text(String(format: "%.0f%%", progress * 100))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Slider(value: Binding(
                get: { Double(value) },
                set: { value = CGFloat($0) }
            ), in: Double(range.lowerBound)...Double(range.upperBound))
        }
    }
}

private struct MeasurementToggleSection: View {
    let title: String
    let fields: [SizeCardMeasurementField]
    let profile: ActorProfile
    @Binding var config: SizeCardConfig

    var body: some View {
        let entries = fields.compactMap { field -> (SizeCardMeasurementField, String)? in
            let value = field.value(from: profile).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !value.isEmpty else { return nil }
            return (field, value)
        }
        if entries.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Text(title.uppercased())
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                ForEach(entries, id: \.0) { entry in
                    Toggle(entry.0.displayLabel, isOn: Binding(
                        get: { !config.hiddenMeasurementFields.contains(entry.0) },
                        set: { newValue in
                            if newValue {
                                config.hiddenMeasurementFields.remove(entry.0)
                            } else {
                                config.hiddenMeasurementFields.insert(entry.0)
                            }
                        }
                    ))
                }
            }
        }
    }
}
