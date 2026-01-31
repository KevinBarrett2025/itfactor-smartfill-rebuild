import SwiftUI
import UIKit

struct SizeCardView: View {
    let profile: ActorProfile
    let reps: [RepInfo]
    let config: SizeCardConfig
    private typealias MeasurementEntry = (field: SizeCardMeasurementField, label: String, value: String)
    @State private var autoTier: AutoLayoutTier = .base
    @State private var lastMeasuredDetailHeight: CGFloat = 0
    @State private var autoDetailScale: CGFloat = 1
    @State private var lastMeasuredRawDetailHeight: CGFloat = 0
    @State private var lastAvailableDetailHeight: CGFloat = 0
#if DEBUG
    @Environment(\.sizeCardDebugOverlayEnabled) private var debugOverlayEnabled
    @Environment(\.sizeCardPreviewScale) private var debugPreviewScale
    @Environment(\.sizeCardPreviewIsClipped) private var debugPreviewIsClipped
    @Environment(\.sizeCardPreviewContainerSize) private var debugPreviewContainerSize
    @Environment(\.sizeCardRenderContext) private var debugRenderContext
    @State private var lastRenderedDetailHeight: CGFloat = 0
    @State private var lastRenderedDetailFrame: CGRect = .zero
#endif

    init(profile: ActorProfile, reps: [RepInfo], config: SizeCardConfig) {
        self.profile = profile
        self.reps = reps
        self.config = config
    }

    private var template: SizeCardTemplate {
        SizeCardTemplate(rawValue: config.template.templateID) ?? .classic
    }

    private var effectiveTemplate: SizeCardTemplate {
        guard config.columnStyle == .auto else { return template }
        switch autoTier {
        case .compactTemplate, .scaled, .hideSectionHeaders, .compactLabels, .tightSpacing, .compactReps:
            return template == .compact ? template : .compact
        default:
            return template
        }
    }

    private var tokens: SizeCardTokens {
        effectiveTemplate.tokens(for: config.template.aspect)
    }

    private var theme: SizeCardTheme { config.template.theme }
    private var themeTextColor: Color {
        Color(hex: theme.textHex, fallback: .black)
    }
    private var spacingScale: CGFloat {
        max(0.7, min(1.3, config.spacingScale * autoScale.spacingMultiplier))
    }
    private var labelFontScaleOverride: CGFloat {
        max(0.7, min(1.4, config.labelFontScale * autoScale.labelMultiplier))
    }
    private var valueFontScaleOverride: CGFloat {
        max(0.7, min(1.4, config.valueFontScale * autoScale.valueMultiplier))
    }
    private var columnGutter: CGFloat {
        tokens.gutter * spacingScale
    }
    private var headerSocialIconSize: CGFloat {
        18 * spacingScale
    }

    private var headshotImage: Image {
        SizeCardAssetResolver.headshotImage(profile: profile, preferredFileName: config.preferredHeadshotFileName)
    }

    private var columnStyle: SizeCardColumnStyle {
        config.columnStyle
    }

    private var useDualColumnLayout: Bool {
        switch columnStyle {
        case .single:
            return false
        case .dual:
            return true
        case .auto:
            return autoTier >= .dual
        }
    }

    private var autoScale: AutoScale {
        guard config.columnStyle == .auto else { return AutoScale() }
        switch autoTier {
        case .base:
            return AutoScale()
        case .dual:
            return AutoScale()
        case .compactSpacing:
            return AutoScale(spacingMultiplier: 0.92, labelMultiplier: 0.96, valueMultiplier: 0.96)
        case .compactTemplate, .scaled, .hideSectionHeaders, .compactLabels, .tightSpacing, .compactReps:
            return AutoScale(spacingMultiplier: 0.9, labelMultiplier: 0.94, valueMultiplier: 0.94)
        }
    }

    private var minDetailScale: CGFloat {
        0.85
    }

    private var safeContentSize: CGSize {
        let insets = tokens.contentInsets
        return CGSize(
            width: tokens.pageSize.width - insets.leading - insets.trailing,
            height: tokens.pageSize.height - insets.top - insets.bottom
        )
    }

    private var detailColumnWidth: CGFloat {
        let insets = tokens.contentInsets
        let available = tokens.pageSize.width - insets.leading - insets.trailing - tokens.leftColumnWidth - columnGutter
        return max(0, available)
    }

    private var clampedDetailColumnOffset: CGSize {
        if config.columnStyle != .auto {
            return clampedOffset(config.detailColumnOffset, limit: 80)
        }
        let slack = max(0, safeContentSize.height - lastMeasuredDetailHeight)
        let maxShift = slack / 2
        let clampedY = min(max(CGFloat(config.detailColumnOffset.y), -maxShift), maxShift)
        let clampedX = min(max(CGFloat(config.detailColumnOffset.x), -40), 40)
        return CGSize(width: clampedX, height: clampedY)
    }

    private var clampedLookDetailsOffset: CGSize {
        if config.columnStyle != .auto {
            return clampedOffset(config.lookDetailsOffset, limit: 80)
        }
        return .zero
    }

    private var clampedRepBoxOffset: CGSize {
        if config.columnStyle != .auto {
            return clampedOffset(config.repBoxOffset, limit: 80)
        }
        return .zero
    }

    private var detailColumnMeasurementView: some View {
        // Measure the same tree we render; fixedSize keeps Spacer from inflating the height.
        detailColumnContent(includeSpacer: true)
            .frame(width: detailColumnWidth, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            .foregroundStyle(themeTextColor)
            .font(.system(size: 14 * effectiveFontScale, weight: .regular, design: .rounded))
            .background(
                GeometryReader { proxy in
                    Color.clear.preference(key: SizeCardDetailSizeKey.self, value: proxy.size)
                }
            )
            .opacity(0.01)
            .allowsHitTesting(false)
    }

#if DEBUG
    private var debugOverlay: some View {
        let available = lastAvailableDetailHeight > 0 ? lastAvailableDetailHeight : safeContentSize.height
        let measured = lastMeasuredRawDetailHeight
        let effective = lastMeasuredDetailHeight
        let fits = available > 0 ? effective <= available + 1 : true
        let rendered = lastRenderedDetailHeight
        let previewScale = debugPreviewScale
        let summary = String(
            format: "Auto %@ | measured %.1f | rendered %.1f | avail %.1f | scale %.3f | preview %.3f | fits %@",
            String(describing: autoTier),
            measured,
            rendered,
            available,
            autoDetailScale,
            previewScale,
            fits ? "YES" : "NO"
        )
        let contextLine = "ctx=\(debugRenderContext.rawValue) clipped=\(debugPreviewIsClipped ? "YES" : "NO") container=\(Int(debugPreviewContainerSize.width))x\(Int(debugPreviewContainerSize.height))"
        return VStack(alignment: .leading, spacing: 4) {
            Text(summary)
            Text(contextLine)
        }
        .font(.system(size: 9, weight: .semibold, design: .monospaced))
        .foregroundStyle(Color.white)
        .padding(6)
        .background(Color.black.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .padding(8)
    }

    private var debugGeometryOverlay: some View {
        let cardRect = CGRect(origin: .zero, size: tokens.pageSize)
        let safeRect = CGRect(
            x: tokens.contentInsets.leading,
            y: tokens.contentInsets.top,
            width: safeContentSize.width,
            height: safeContentSize.height
        )
        let detailOrigin = CGPoint(
            x: tokens.contentInsets.leading + tokens.leftColumnWidth + columnGutter + clampedDetailColumnOffset.width,
            y: tokens.contentInsets.top + clampedDetailColumnOffset.height
        )
        let measuredRect = CGRect(
            x: detailOrigin.x,
            y: detailOrigin.y,
            width: detailColumnWidth,
            height: max(0, lastMeasuredRawDetailHeight)
        )
        let renderedRect = lastRenderedDetailFrame

        return ZStack(alignment: .topLeading) {
            debugLabeledRect(cardRect, label: "Card", color: .white)
            debugLabeledRect(safeRect, label: "Safe", color: .blue)
            if measuredRect.height > 0 {
                debugLabeledRect(measuredRect, label: "Measured", color: .orange)
            }
            if renderedRect.height > 0, renderedRect.width > 0 {
                debugLabeledRect(renderedRect, label: "Rendered", color: .green)
            }
        }
        .allowsHitTesting(false)
    }

    private func debugLabeledRect(_ rect: CGRect, label: String, color: Color) -> some View {
        ZStack(alignment: .topLeading) {
            Rectangle()
                .path(in: rect)
                .stroke(color, lineWidth: 1)
            Text(label)
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundStyle(color)
                .padding(2)
                .background(Color.black.opacity(0.5))
                .offset(x: rect.origin.x + 2, y: rect.origin.y + 2)
        }
    }
#endif

    var body: some View {
        let background = Color(hex: theme.backgroundHex, fallback: .white)
        ZStack {
            background
            HStack(spacing: columnGutter) {
                headshotColumn
                detailColumn
                    .offset(clampedDetailColumnOffset)
            }
            .padding(tokens.contentInsets)
        }
        .frame(width: tokens.pageSize.width, height: tokens.pageSize.height)
#if DEBUG
        .coordinateSpace(name: SizeCardDebugCoordinateSpace.name)
#endif
        .environment(\.colorScheme, .light)
        .environment(\.dynamicTypeSize, .xSmall)
        .overlay {
            if config.columnStyle == .auto {
                detailColumnMeasurementView
            }
        }
#if DEBUG
        .overlay(alignment: .bottomLeading) {
            if debugOverlayEnabled {
                debugOverlay
            }
        }
        .overlay {
            if debugOverlayEnabled {
                debugGeometryOverlay
            }
        }
#endif
        .onChange(of: config.columnStyle, initial: false) { _, newValue in
            if newValue != .auto {
                autoTier = .base
                autoDetailScale = 1
                lastMeasuredDetailHeight = 0
                lastMeasuredRawDetailHeight = 0
                lastAvailableDetailHeight = 0
            }
        }
        .onPreferenceChange(SizeCardDetailSizeKey.self) { size in
            guard config.columnStyle == .auto else { return }
            guard size.height > 0, safeContentSize.height > 0 else { return }
            updateAutoTierIfNeeded(measuredHeight: size.height)
        }
#if DEBUG
        .onPreferenceChange(SizeCardRenderedDetailFrameKey.self) { frame in
            lastRenderedDetailFrame = frame
            lastRenderedDetailHeight = frame.height
        }
#endif
    }

    private var headshotColumn: some View {
        VStack(alignment: .leading, spacing: 12 * spacingScale) {
            headshotFrame
            if hasAppearanceHighlights {
                appearanceHighlights
            }
            Spacer(minLength: 0)
        }
        .frame(width: tokens.leftColumnWidth, alignment: .top)
    }

    private var headshotFrame: some View {
        let width = tokens.leftColumnWidth
        let height = width * (10.0 / 8.0)
        let offsets = config.headshotTransform.offset(width: width, height: height)
        return ZStack {
            Color.black
            headshotImage
                .resizable()
                .scaledToFill()
                .scaleEffect(config.headshotTransform.scale)
                .offset(x: offsets.width, y: offsets.height)
        }
        .frame(width: width, height: height)
        .clipped()
        .cornerRadius(theme.cornerRadius)
        .overlay(
            theme.includeHeadshotBorder ?
            RoundedRectangle(cornerRadius: theme.cornerRadius)
                .stroke(Color(hex: theme.accentHex, fallback: .purple), lineWidth: 3)
                : nil
        )
        .shadow(color: .black.opacity(theme.includeShadow ? 0.18 : 0),
                radius: theme.includeShadow ? 16 : 0,
                x: 0, y: theme.includeShadow ? 8 : 0)
    }

    private var hasAppearanceHighlights: Bool {
        genderDisplay != nil ||
        !trimmedHeight.isEmpty ||
        !trimmedWeight.isEmpty ||
        trimmedHairColor != nil ||
        trimmedEyeColor != nil
    }

    private var appearanceHighlights: some View {
        VStack(alignment: .leading, spacing: 8 * spacingScale) {
            if let gender = genderDisplay {
                Text(gender.uppercased())
                    .font(.system(size: 11 * labelFontScaleOverride, weight: .semibold))
                    .tracking(1)
                    .foregroundStyle(themeTextColor)
            }
            infoPairRow(
                primary: ("Height", trimmedHeight.isEmpty ? "—" : trimmedHeight),
                secondary: ("Weight", trimmedWeight.isEmpty ? "—" : trimmedWeight)
            )
            infoPairRow(
                primary: ("Hair", trimmedHairColor ?? "—"),
                secondary: ("Eyes", trimmedEyeColor ?? "—")
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 12)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(themeTextColor.opacity(0.08))
        )
        .offset(clampedLookDetailsOffset)
    }

    @ViewBuilder
    private var detailColumn: some View {
        let base = detailColumnContent(includeSpacer: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .foregroundStyle(themeTextColor)
            .font(.system(size: 14 * effectiveFontScale, weight: .regular, design: .rounded))
            .scaleEffect(autoDetailScale, anchor: .topLeading)
#if DEBUG
        base.background(
            GeometryReader { proxy in
                Color.clear.preference(
                    key: SizeCardRenderedDetailFrameKey.self,
                    value: proxy.frame(in: .named(SizeCardDebugCoordinateSpace.name))
                )
            }
        )
#else
        base
#endif
    }

    private func detailColumnContent(includeSpacer: Bool) -> some View {
        VStack(alignment: .leading, spacing: dynamicBodySpacing) {
            headerSection
            Divider().opacity(dynamicDividerOpacity)
            Group {
                if useDualColumnLayout {
                    dualColumnContent
                } else {
                    singleColumnContent
                }
            }
            if includeSpacer {
                Spacer(minLength: dynamicBodySpacing)
            }
            if showRepsSection {
                repsPinnedBox
            }
            if config.visibility.showWatermarkQR {
                watermarkBadge
            }
        }
    }

    private var singleColumnContent: some View {
        VStack(alignment: .leading, spacing: dynamicBodySpacing) {
            if showWardrobeSection {
                wardrobeSection
            }
            if !visibleCustomFields.isEmpty {
                customFieldSection
            }
        }
    }

    private var dualColumnContent: some View {
        HStack(alignment: .top, spacing: columnGutter) {
            VStack(alignment: .leading, spacing: dynamicBodySpacing) {
                if showWardrobeSection {
                    wardrobeSection
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: dynamicBodySpacing) {
                if !visibleCustomFields.isEmpty {
                    customFieldSection
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var watermarkBadge: some View {
        HStack {
            Spacer()
            WatermarkBadge(
                qrURL: watermarkDestinationURL,
                qrSize: qrSize,
                textColor: Color(hex: theme.textHex, fallback: .black),
                density: densityFactor
            )
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: dynamicHeaderSpacing) {
            HStack(alignment: .bottom, spacing: 12) {
                Text(profile.displayName)
                    .font(.system(size: 36 * theme.fontScale, weight: .heavy, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
                if hasLocationBadges {
                    Spacer(minLength: 8)
                    locationBadges
                }
            }
            if config.visibility.showUnion {
                Text(profile.sagDisplayStatus)
                    .font(.system(size: 16 * labelFontScaleOverride, weight: .semibold))
                    .foregroundStyle(themeTextColor.opacity(0.9))
                    .frame(maxWidth: .infinity)
            }
            if showEmailField || showPhoneField || !socialLinkItems.isEmpty {
                VStack(alignment: .leading, spacing: 4 * spacingScale * tightSpacingFactor) {
                    if showEmailField || (config.visibility.showLinks && !socialLinkItems.isEmpty) {
                        HStack(alignment: .center, spacing: 8 * spacingScale) {
                            if showEmailField {
                                contactText(profile.email)
                            }
                            if config.visibility.showLinks && !socialLinkItems.isEmpty {
                                Spacer(minLength: 4)
                                headerSocialIcons
                            }
                        }
                    }
                    if showPhoneField {
                        contactText(profile.phone)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
    }
    
    private var primaryLocation: String? {
        let trimmedProfileLocation = profile.primaryLocation.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedProfileLocation.isEmpty {
            return trimmedProfileLocation
        }
        if let locationField = config.customFields.first(where: {
            $0.isVisible && $0.label.lowercased().contains("location") && !$0.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }) {
            return locationField.value
        }
        return nil
    }

    private var localHireLocation: String? {
        let override = config.localHireOverride.trimmingCharacters(in: .whitespacesAndNewlines)
        if !override.isEmpty { return override }
        let profileValue = profile.localHireMarket.trimmingCharacters(in: .whitespacesAndNewlines)
        return profileValue.isEmpty ? nil : profileValue
    }

    private var hasLocationBadges: Bool {
        (config.visibility.showPrimaryLocation && primaryLocation != nil) ||
        (config.visibility.showLocalHire && localHireLocation != nil)
    }

    @ViewBuilder
    private var locationBadges: some View {
        let primary = config.visibility.showPrimaryLocation ? primaryLocation : nil
        let local = config.visibility.showLocalHire ? localHireLocation : nil
        if primary == nil && local == nil {
            EmptyView()
        } else if let primary = primary, let local = local {
            VStack(alignment: .leading, spacing: 4) {
                BadgeCapsule(text: primary, fontScale: chipFontScale, color: themeTextColor)
                BadgeCapsule(text: local, fontScale: chipFontScale, color: themeTextColor)
            }
        } else if let primary = primary {
            BadgeCapsule(text: primary, fontScale: chipFontScale, color: themeTextColor)
        } else if let local = local {
            BadgeCapsule(text: local, fontScale: chipFontScale, color: themeTextColor)
        }
    }

    @ViewBuilder
    private var headerSocialIcons: some View {
        if config.visibility.showLinks {
            let icons = socialLinkItems
            if !icons.isEmpty {
                HStack(spacing: 6 * spacingScale) {
                    ForEach(icons) { item in
                        SocialIconButton(item: item, size: headerSocialIconSize)
                    }
                }
            }
        }
    }

    private var trimmedHeight: String {
        profile.height.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedWeight: String {
        profile.weight.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var showWardrobeSection: Bool {
        guard config.visibility.showWardrobe else { return false }
        return !generalMeasurementFields.isEmpty ||
            !menMeasurementFields.isEmpty ||
            !womenMeasurementFields.isEmpty ||
            !childMeasurementFields.isEmpty
    }

    private var displayableReps: [RepInfo] {
        guard config.visibility.showReps else { return [] }
        if config.hiddenRepIDs.isEmpty { return reps }
        return reps.filter { !config.hiddenRepIDs.contains($0.id) }
    }

    private var showRepsSection: Bool {
        !displayableReps.isEmpty
    }

    private var showEmailField: Bool {
        config.visibility.showEmail && !profile.email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var showPhoneField: Bool {
        config.visibility.showPhone && !profile.phone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var visibleCustomFields: [SizeCardCustomField] {
        config.customFields.filter { field in
            guard field.isVisible else { return false }
            let value = field.value.trimmingCharacters(in: .whitespacesAndNewlines)
            if config.visibility.showPrimaryLocation, field.label.lowercased().contains("location") { return false }
            return !value.isEmpty
        }
    }

    private var wardrobeSection: some View {
        VStack(alignment: .leading, spacing: dynamicBodySpacing * 0.65) {
            if showSectionHeaders {
                Text("SIZES & MEASUREMENTS")
                    .font(.system(size: 11 * labelFontScaleOverride, weight: .heavy))
                    .foregroundStyle(Color(hex: theme.textHex, fallback: .black).opacity(0.65))
                    .tracking(1)
                    .padding(.bottom, 2)
            }
            if !generalMeasurementFields.isEmpty {
                measurementList(for: generalMeasurementFields)
            }
            if shouldShowMenMeasurements, !menMeasurementFields.isEmpty {
                measurementList(for: menMeasurementFields)
            }
            if shouldShowWomenMeasurements, !womenMeasurementFields.isEmpty {
                measurementList(for: womenMeasurementFields)
            }
            if shouldShowChildMeasurements, !childMeasurementFields.isEmpty {
                measurementList(for: childMeasurementFields)
            }
        }
    }

    private var repsPinnedBox: some View {
        HStack {
            Spacer()
            VStack(alignment: .leading, spacing: 6 * spacingScale * tightSpacingFactor) {
                if showSectionHeaders {
                    Text("REPRESENTATION")
                        .font(.system(size: 10 * labelFontScaleOverride, weight: .bold))
                        .foregroundStyle(themeTextColor.opacity(0.7))
                }
                ForEach(displayableReps) { rep in
                    VStack(alignment: .leading, spacing: 2 * spacingScale * tightSpacingFactor) {
                        Text(rep.category.uppercased())
                            .font(.system(size: 9 * labelFontScaleOverride, weight: .bold))
                            .foregroundStyle(themeTextColor.opacity(0.6))
                        Text(rep.name)
                            .font(.system(size: 12 * valueFontScaleOverride, weight: .semibold))
                            .foregroundStyle(themeTextColor)
                        if useCompactReps {
                            if let contactLine = rep.email ?? rep.phone {
                                Text(contactLine)
                                    .font(.system(size: 11 * valueFontScaleOverride))
                                    .foregroundStyle(themeTextColor.opacity(0.85))
                            }
                        } else {
                            if let email = rep.email {
                                Text(email)
                                    .font(.system(size: 11 * valueFontScaleOverride))
                                    .foregroundStyle(themeTextColor.opacity(0.85))
                            }
                            if let phone = rep.phone {
                                Text(phone)
                                    .font(.system(size: 11 * valueFontScaleOverride))
                                    .foregroundStyle(themeTextColor.opacity(0.85))
                            }
                        }
                    }
                    .padding(.bottom, 2 * spacingScale * tightSpacingFactor)
                }
            }
            .padding(.vertical, 12 * tightSpacingFactor)
            .padding(.horizontal, 14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(themeTextColor.opacity(0.06))
            )
            .offset(clampedRepBoxOffset)
        }
    }

    private var customFieldSection: some View {
        VStack(alignment: .leading, spacing: rowSpacing) {
            ForEach(visibleCustomFields.sorted(by: { $0.order < $1.order })) { field in
                labeled(field.label, field.value)
            }
        }
    }
    
    private var contactFieldCount: Int {
        var count = 0
        if showEmailField { count += 1 }
        if showPhoneField { count += 1 }
        return count
    }

    private var repUnitEstimate: CGFloat {
        guard config.visibility.showReps else { return 0 }
        return displayableReps.reduce(0) { partial, rep in
            var units: CGFloat = 2 // category + name
            if let email = rep.email?.trimmingCharacters(in: .whitespacesAndNewlines), !email.isEmpty {
                units += 0.8
            }
            if let phone = rep.phone?.trimmingCharacters(in: .whitespacesAndNewlines), !phone.isEmpty {
                units += 0.8
            }
            return partial + units
        }
    }

    private var socialLinkUnitCount: CGFloat {
        guard config.visibility.showLinks else { return 0 }
        return CGFloat(socialLinkItems.count)
    }

    private var measurementUnitCount: CGFloat {
        CGFloat(
            generalMeasurementFields.count +
            menMeasurementFields.count +
            womenMeasurementFields.count +
            childMeasurementFields.count +
            visibleCustomFields.count
        )
    }

    private var totalContentUnits: CGFloat {
        var units = measurementUnitCount
        units += CGFloat(contactFieldCount)
        units += socialLinkUnitCount
        units += repUnitEstimate
        if config.visibility.showWatermarkQR { units += 1.2 }
        if config.visibility.showPrimaryLocation, primaryLocation != nil {
            units += 0.4
        }
        if config.visibility.showLocalHire, localHireLocation != nil {
            units += 0.4
        }
        return max(units, 1)
    }

    private var densityFactor: CGFloat {
        let comfortable: CGFloat = 32
        if totalContentUnits <= comfortable { return 1.0 }
        let ratio = comfortable / totalContentUnits
        return max(0.62, ratio)
    }

    private var tightSpacingFactor: CGFloat {
        guard config.columnStyle == .auto, autoTier >= .tightSpacing else { return 1.0 }
        return 0.85
    }

    private var rowSpacing: CGFloat {
        4 * (0.7 + 0.3 * densityFactor) * spacingScale * tightSpacingFactor
    }

    private var showSectionHeaders: Bool {
        !(config.columnStyle == .auto && autoTier >= .hideSectionHeaders)
    }

    private var useCompactLabels: Bool {
        config.columnStyle == .auto && autoTier >= .compactLabels
    }

    private var useCompactReps: Bool {
        config.columnStyle == .auto && autoTier >= .compactReps
    }

    private var dynamicBodySpacing: CGFloat {
        tokens.bodySpacing * (0.55 + 0.45 * densityFactor) * spacingScale * tightSpacingFactor
    }

    private var dynamicHeaderSpacing: CGFloat {
        tokens.headerSpacing * (0.5 + 0.5 * densityFactor) * spacingScale * tightSpacingFactor
    }

    private var dynamicChipSpacing: CGFloat {
        8 * (0.6 + 0.4 * densityFactor) * spacingScale
    }

    private var dynamicLabelWidth: CGFloat {
        let minWidth: CGFloat = 76
        let maxWidth: CGFloat = 102
        return minWidth + (maxWidth - minWidth) * densityFactor
    }

    private var dynamicDividerOpacity: Double {
        theme.dividerOpacity * (0.6 + 0.4 * densityFactor)
    }

    private var chipFontScale: CGFloat {
        (0.8 + (0.2 * densityFactor)) * labelFontScaleOverride
    }

    private var qrSize: CGFloat {
        let minSize: CGFloat = 60
        let maxSize: CGFloat = 88
        let base = minSize + (maxSize - minSize) * densityFactor
        return base * (0.85 + 0.15 * spacingScale)
    }

    private var footerSpacerHeight: CGFloat {
        max(8, 28 * densityFactor * spacingScale)
    }
    
    private var shareableLinkURL: URL? {
        socialLinkItems.first?.url
    }

    private var watermarkDestinationURL: URL? {
        URL(string: "https://selftapestudio.app")
    }

    private var genderDisplay: String? {
        let value = profile.sex.displayName
        return value.isEmpty ? nil : value
    }

    private var trimmedHairColor: String? {
        let trimmed = profile.hairColor.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private var trimmedEyeColor: String? {
        let trimmed = profile.eyeColor.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func lookDetailRow(label: String, value: String) -> some View {
        HStack(spacing: 6 * spacingScale) {
            Text(label.uppercased())
                .font(.system(size: 9 * labelFontScaleOverride, weight: .bold))
                .foregroundStyle(themeTextColor.opacity(0.7))
            Spacer(minLength: 8 * spacingScale)
            Text(value)
                .font(.system(size: 11 * valueFontScaleOverride, weight: .semibold))
                .foregroundStyle(themeTextColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func infoPairRow(primary: (String, String), secondary: (String, String)) -> some View {
        HStack(spacing: 12 * spacingScale) {
            lookDetailRow(label: primary.0, value: primary.1.isEmpty ? "—" : primary.1)
            Divider()
                .frame(height: 14)
                .background(themeTextColor.opacity(0.2))
            lookDetailRow(label: secondary.0, value: secondary.1.isEmpty ? "—" : secondary.1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func contactText(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13 * valueFontScaleOverride, weight: .medium))
            .foregroundStyle(themeTextColor.opacity(0.85))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
    }

    private static let compactLabelOverrides: [SizeCardMeasurementField: String] = [
        .mensTShirt: "Men's Tee",
        .womensTShirt: "Women's Tee",
        .mensShoeWidth: "Men's Shoe W.",
        .womensShoeWidth: "Women's Shoe W.",
        .kidsSpecial: "Special"
    ]

    private func displayLabel(for field: SizeCardMeasurementField) -> String {
        if useCompactLabels, let compact = Self.compactLabelOverrides[field] {
            return compact
        }
        return field.displayLabel
    }
    
    private var generalMeasurementFields: [MeasurementEntry] {
        measurementEntries(for: [
            .waist, .inseam, .glove, .hat,
            .shirt, .pant, .shoe
        ])
    }
    
    private var effectiveFontScale: CGFloat {
        max(0.65, theme.fontScale * densityFactor)
    }
    
    private var menMeasurementFields: [MeasurementEntry] {
        guard shouldShowMenMeasurements else { return [] }
        return measurementEntries(for: [
            .chest, .neck, .sleeve, .coat,
            .mensTShirt, .mensShoe, .mensShoeWidth
        ])
    }
    
    private var womenMeasurementFields: [MeasurementEntry] {
        guard shouldShowWomenMeasurements else { return [] }
        return measurementEntries(for: [
            .dress, .bust, .underbust, .cup, .hip,
            .womensTShirt, .womensPants, .womensShoe, .womensShoeWidth
        ])
    }
    
    private var childMeasurementFields: [MeasurementEntry] {
        guard shouldShowChildMeasurements else { return [] }
        return measurementEntries(for: [
            .boys, .girls, .toddlers, .infants, .kidsShoe, .kidsSpecial
        ])
    }
    
    private var shouldShowMenMeasurements: Bool {
        profile.sex == .male || profile.sex == .undisclosed
    }
    
    private var shouldShowWomenMeasurements: Bool {
        profile.sex == .female || profile.sex == .undisclosed
    }
    
    private var shouldShowChildMeasurements: Bool {
        profile.isYouthTalent
    }
    
    private func measurementEntries(for fields: [SizeCardMeasurementField]) -> [MeasurementEntry] {
        fields.compactMap { field in
            guard !config.hiddenMeasurementFields.contains(field) else { return nil }
            let value = field.value(from: profile).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !value.isEmpty else { return nil }
            return (field, displayLabel(for: field), value)
        }
    }

    private func measurementList(for fields: [MeasurementEntry]) -> some View {
        VStack(alignment: .leading, spacing: rowSpacing) {
            ForEach(fields, id: \.field) { field in
                labeled(field.label, field.value)
            }
        }
    }
    
    private var socialLinkItems: [SocialLinkItem] {
        guard config.visibility.showLinks else { return [] }
        var items: [SocialLinkItem] = []
        if config.visibility.showInstagram,
           let url = normalizedSocialURL(base: "https://instagram.com/", value: profile.socialLinks.instagram) {
            items.append(SocialLinkItem(brand: .instagram, url: url))
        }
        if config.visibility.showFacebook,
           let url = normalizedSocialURL(base: "https://facebook.com/", value: profile.socialLinks.facebook) {
            items.append(SocialLinkItem(brand: .facebook, url: url))
        }
        if config.visibility.showTiktok,
           let url = normalizedSocialURL(base: "https://tiktok.com/@",
                                         value: profile.socialLinks.tiktok,
                                         trimmingPrefix: "@") {
            items.append(SocialLinkItem(brand: .tiktok, url: url))
        }
        if config.visibility.showImdb,
           let url = normalizedSocialURL(base: "https://www.imdb.com/name/", value: profile.socialLinks.imdb) {
            items.append(SocialLinkItem(brand: .imdb, url: url))
        }
        return items
    }
    
    private func normalizedSocialURL(base: String, value: String, trimmingPrefix: String = "") -> URL? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if trimmed.lowercased().hasPrefix("http") {
            return URL(string: trimmed)
        }
        let cleaned = trimmingPrefix.isEmpty ? trimmed : trimmed.trimmingCharacters(in: CharacterSet(charactersIn: trimmingPrefix))
        guard !base.isEmpty else {
            return URL(string: cleaned)
        }
        return URL(string: base + cleaned.replacingOccurrences(of: "@", with: ""))
    }

    struct SocialLinkItem: Identifiable {
        let id = UUID()
        let brand: SocialBrand
        let url: URL
    }

    enum SocialBrand {
        case instagram, facebook, tiktok, imdb

        var accessibilityLabel: String {
            switch self {
            case .instagram: return "Open Instagram profile"
            case .facebook: return "Open Facebook profile"
            case .tiktok: return "Open TikTok profile"
            case .imdb: return "Open IMDb page"
            }
        }
    }

    private func labeled(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label + ":")
                .font(.system(size: 13 * effectiveFontScale * labelFontScaleOverride, weight: .semibold))
                .frame(width: dynamicLabelWidth, alignment: .leading)
                .minimumScaleFactor(useCompactLabels ? 0.65 : 0.75)
                .lineLimit(useCompactLabels ? 1 : nil)
            Text(value)
                .font(.system(size: 13 * effectiveFontScale * valueFontScaleOverride))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func clampedOffset(_ offset: LayoutOffset, limit: CGFloat) -> CGSize {
        let clampedX = min(max(CGFloat(offset.x), -limit), limit)
        let clampedY = min(max(CGFloat(offset.y), -limit), limit)
        return CGSize(width: clampedX, height: clampedY)
    }

    private func updateAutoTierIfNeeded(measuredHeight: CGFloat) {
        guard config.columnStyle == .auto else { return }
        guard safeContentSize.height > 0, measuredHeight > 0 else { return }

        let availableHeight = safeContentSize.height
        let requiredScale = availableHeight / measuredHeight
        let appliedScale: CGFloat
        if autoTier >= .scaled {
            appliedScale = min(1, max(minDetailScale, requiredScale))
        } else {
            appliedScale = 1
        }

        if abs(appliedScale - autoDetailScale) > 0.005 {
            autoDetailScale = appliedScale
        }

        lastMeasuredRawDetailHeight = measuredHeight
        lastAvailableDetailHeight = availableHeight
        lastMeasuredDetailHeight = measuredHeight * appliedScale

        let overflow = lastMeasuredDetailHeight - availableHeight
        let needsUpgrade = overflow > 1
        let hasRoomToDowngrade = overflow < -20
        let scalingNeeded = requiredScale < 0.995

        if needsUpgrade, let next = autoTier.next {
            autoTier = next
        } else if hasRoomToDowngrade, let previous = autoTier.previous {
            if previous < .scaled && scalingNeeded {
                return
            }
            autoTier = previous
        }

#if DEBUG
        if debugOverlayEnabled {
            let fits = overflow <= 1
            let safeRect = CGRect(
                x: tokens.contentInsets.leading,
                y: tokens.contentInsets.top,
                width: safeContentSize.width,
                height: safeContentSize.height
            )
            let previewSize = debugPreviewContainerSize
            let record = String(
                format: "FITREC mode=%@ tier=%@ page=(%.0f,%.0f) safeRect=(%.0f,%.0f,%.0f,%.0f) detailW=%.1f measuredH=%.1f renderedH=%.1f scale=%.3f previewScale=%.3f previewContainer=(%.0f,%.0f) clipped=%@ renderCtx=%@ fits=%@",
                config.columnStyle.displayName,
                String(describing: autoTier),
                tokens.pageSize.width,
                tokens.pageSize.height,
                safeRect.origin.x,
                safeRect.origin.y,
                safeRect.width,
                safeRect.height,
                detailColumnWidth,
                measuredHeight,
                lastRenderedDetailHeight,
                appliedScale,
                debugPreviewScale,
                previewSize.width,
                previewSize.height,
                debugPreviewIsClipped ? "YES" : "NO",
                debugRenderContext.rawValue,
                fits ? "YES" : "NO"
            )
            print(record)
        }
#endif
    }
}

private enum AutoLayoutTier: Int, Comparable {
    case base
    case dual
    case compactSpacing
    case compactTemplate
    case scaled
    case hideSectionHeaders
    case compactLabels
    case tightSpacing
    case compactReps

    static func < (lhs: AutoLayoutTier, rhs: AutoLayoutTier) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var next: AutoLayoutTier? {
        AutoLayoutTier(rawValue: rawValue + 1)
    }

    var previous: AutoLayoutTier? {
        AutoLayoutTier(rawValue: rawValue - 1)
    }
}

private struct AutoScale {
    var spacingMultiplier: CGFloat = 1.0
    var labelMultiplier: CGFloat = 1.0
    var valueMultiplier: CGFloat = 1.0
}

private struct SizeCardDetailSizeKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}

#if DEBUG
private enum SizeCardDebugCoordinateSpace {
    static let name = "SizeCardDebugCanvas"
}

private struct SizeCardRenderedDetailFrameKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

private struct SizeCardDebugOverlayEnabledKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var sizeCardDebugOverlayEnabled: Bool {
        get { self[SizeCardDebugOverlayEnabledKey.self] }
        set { self[SizeCardDebugOverlayEnabledKey.self] = newValue }
    }
}

enum SizeCardRenderContext: String {
    case live
    case preview
    case export
}

private struct SizeCardPreviewScaleKey: EnvironmentKey {
    static let defaultValue: CGFloat = 1.0
}

private struct SizeCardPreviewIsClippedKey: EnvironmentKey {
    static let defaultValue = false
}

private struct SizeCardPreviewContainerSizeKey: EnvironmentKey {
    static let defaultValue: CGSize = .zero
}

private struct SizeCardRenderContextKey: EnvironmentKey {
    static let defaultValue: SizeCardRenderContext = .live
}

extension EnvironmentValues {
    var sizeCardPreviewScale: CGFloat {
        get { self[SizeCardPreviewScaleKey.self] }
        set { self[SizeCardPreviewScaleKey.self] = newValue }
    }
    var sizeCardPreviewIsClipped: Bool {
        get { self[SizeCardPreviewIsClippedKey.self] }
        set { self[SizeCardPreviewIsClippedKey.self] = newValue }
    }
    var sizeCardPreviewContainerSize: CGSize {
        get { self[SizeCardPreviewContainerSizeKey.self] }
        set { self[SizeCardPreviewContainerSizeKey.self] = newValue }
    }
    var sizeCardRenderContext: SizeCardRenderContext {
        get { self[SizeCardRenderContextKey.self] }
        set { self[SizeCardRenderContextKey.self] = newValue }
    }
}
#endif

// MARK: - Supporting Views
private struct Chip: View {
    let text: String
    let fontScale: CGFloat

    var body: some View {
        let clampedScale = max(0.7, min(1.1, fontScale))
        Text(text)
            .font(.system(size: 12 * clampedScale, weight: .semibold))
            .padding(.horizontal, 8 * clampedScale)
            .padding(.vertical, 4 * max(0.6, clampedScale))
            .lineLimit(2)
            .minimumScaleFactor(0.75)
            .multilineTextAlignment(.center)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
    }
}

private struct BadgeCapsule: View {
    let text: String
    let fontScale: CGFloat
    let color: Color

    var body: some View {
        let clampedScale = max(0.65, min(1.1, fontScale))
        Text(text)
            .font(.system(size: 11 * clampedScale, weight: .semibold))
            .padding(.horizontal, 10 * clampedScale)
            .padding(.vertical, 5 * clampedScale)
            .foregroundStyle(color)
            .background(
                Capsule()
                    .fill(color.opacity(0.08))
            )
            .overlay(
                Capsule()
                    .stroke(color.opacity(0.25), lineWidth: 1)
            )
    }
}

private struct SocialIconButton: View {
    let item: SizeCardView.SocialLinkItem
    let size: CGFloat

    var body: some View {
        Link(destination: item.url) {
            icon
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.brand.accessibilityLabel)
    }

    @ViewBuilder
    private var icon: some View {
        switch item.brand {
        case .instagram:
            Circle()
                .fill(
                    AngularGradient(
                        gradient: Gradient(colors: [
                            Color(red: 0.99, green: 0.55, blue: 0.25),
                            Color(red: 0.85, green: 0.19, blue: 0.41),
                            Color(red: 0.56, green: 0.18, blue: 0.60)
                        ]),
                        center: .center
                    )
                )
                .overlay(
                    Image(systemName: "camera.aperture")
                        .font(.system(size: size * 0.42, weight: .bold))
                        .foregroundStyle(.white)
                )
                .frame(width: size, height: size)
        case .facebook:
            Circle()
                .fill(Color(red: 0.10, green: 0.45, blue: 0.95))
                .overlay(
                    Text("f")
                        .font(.system(size: size * 0.6, weight: .heavy))
                        .foregroundStyle(.white)
                )
                .frame(width: size, height: size)
        case .tiktok:
            RoundedRectangle(cornerRadius: size * 0.3, style: .continuous)
                .fill(Color.black)
                .overlay(
                    Image(systemName: "music.note")
                        .font(.system(size: size * 0.45, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.98, green: 0.24, blue: 0.36),
                                    Color(red: 0.07, green: 0.88, blue: 0.87)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .shadow(color: Color(red: 0.07, green: 0.88, blue: 0.87).opacity(0.4), radius: 1, x: 0, y: 1)
                )
                .frame(width: size, height: size)
        case .imdb:
            RoundedRectangle(cornerRadius: size * 0.2, style: .continuous)
                .fill(Color(red: 0.96, green: 0.77, blue: 0.09))
                .overlay(
                    Text("IMDb")
                        .font(.system(size: size * 0.32, weight: .black, design: .rounded))
                        .foregroundStyle(.black)
                )
                .frame(width: size, height: size)
        }
    }
}

private struct QRCodeView: View {
    let url: URL

    var body: some View {
        #if os(iOS)
        if let image = QRGenerator.makeQRCode(from: url.absoluteString) {
            Image(uiImage: image)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
        } else {
            EmptyView()
        }
        #else
        EmptyView()
        #endif
    }
}

private struct WatermarkBadge: View {
    let qrURL: URL?
    let qrSize: CGFloat
    let textColor: Color
    let density: CGFloat

    var body: some View {
        HStack(alignment: .center, spacing: 8 * (0.7 + 0.3 * density)) {
            if let url = qrURL {
                QRCodeView(url: url)
                    .frame(width: qrSize * 0.55, height: qrSize * 0.55)
                    .padding(4)
                    .background(Color.white.opacity(0.9))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            VStack(alignment: .trailing, spacing: 2) {
                Text("iTFactor")
                    .font(.system(size: 12 * (0.8 + 0.2 * density), weight: .semibold, design: .rounded))
                Text("Self Tape Studio iOS")
                    .font(.system(size: 10 * (0.8 + 0.2 * density), weight: .regular, design: .rounded))
            }
            .foregroundStyle(textColor.opacity(0.7 + 0.3 * density))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.08 + 0.05 * (1 - density)))
        )
    }
}

// MARK: - Helpers
private enum SizeCardAssetResolver {
    static func headshotImage(profile: ActorProfile, preferredFileName: String?) -> Image {
        let fileName = preferredFileName ?? profile.preferredHeadshot?.fileName
        guard let fileName, let url = resolveHeadshotURL(named: fileName),
              let uiImage = UIImage(contentsOfFile: url.path) else {
            return Image(systemName: "person.crop.square.fill")
        }
        return Image(uiImage: uiImage)
    }
}

private enum QRGenerator {
    #if os(iOS)
    static func makeQRCode(from string: String) -> UIImage? {
        guard let data = string.data(using: .ascii) else { return nil }
        guard let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("Q", forKey: "inputCorrectionLevel")
        guard let output = filter.outputImage else { return nil }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 6, y: 6))
        return UIImage(ciImage: scaled)
    }
    #endif
}
