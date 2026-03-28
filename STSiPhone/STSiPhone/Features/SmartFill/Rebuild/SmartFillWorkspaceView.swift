import AVKit
import Combine
import SwiftUI

private enum SmartFillWorkspacePalette {
    static let theme = STSThemeLibrary.theme(for: .studioLobbyV1)
    static let accent = theme.primaryAccent
    static let textPrimary = theme.textPrimary
    static let textSecondary = theme.textSecondary
    static let background = theme.backgroundGradient
    static let panelFill = Color.white.opacity(0.07)
    static let panelStroke = Color.white.opacity(0.08)
    static let chromeFill = Color(red: 0.03, green: 0.04, blue: 0.08).opacity(0.96)
    static let chromeStroke = Color.white.opacity(0.06)
}

struct SmartFillWorkspaceView: View {
    let context: SmartFillSettingsContext
    let onQueueSmartFill: (SmartFillSettings) -> Void
    let onOpenSavedTake: ((SmartFillResultBridgeRecord) -> Void)?
    let onCancel: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @StateObject private var coordinator = SmartFillWorkspaceCoordinator()
    @State private var settings: SmartFillSettings
    @State private var activeSheet: SmartFillWorkspaceSheet?
    @State private var statusMessage: String?
    @State private var previewErrorMessage: String?
    @State private var queueAttempted = false
    @State private var autoReturnWorkItem: DispatchWorkItem?
    @State private var processingProgress: Double = 0
    @State private var completionBehavior: SmartFillWorkspaceCompletionBehavior
    @State private var activeTool: SmartFillWorkspaceTool = .background
    @State private var activeLookAdjustment: SmartFillWorkspaceLookAdjustment = .blur
    @State private var previewSelectionState = SmartFillWorkspaceCompareViewerSelectionState(selectedMode: .result)
    @State private var previewPinnedWipeProgress: CGFloat = SmartFillWorkspaceCompareWipeState.defaultProgress
    @State private var previewPlaybackState = SmartFillWorkspacePreviewPlaybackState()
    @State private var isHoldingPreviewComparison = false

    private let workspaceDefaults: SmartFillWorkspaceDefaults

    init(
        context: SmartFillSettingsContext,
        onQueueSmartFill: @escaping (SmartFillSettings) -> Void,
        onOpenSavedTake: ((SmartFillResultBridgeRecord) -> Void)? = nil,
        onCancel: @escaping () -> Void
    ) {
        self.context = context
        self.onQueueSmartFill = onQueueSmartFill
        self.onOpenSavedTake = onOpenSavedTake
        self.onCancel = onCancel

        let defaults = SmartFillTakeBridge.defaultWorkspaceSettings(for: context.take, in: context.session)
        self.workspaceDefaults = defaults
        let initialSettings = context.existingSettings ?? SmartFillTakeBridge.settings(from: defaults.snapshot)
        self._settings = State(initialValue: initialSettings)
        self._completionBehavior = State(initialValue: SmartFillWorkspaceCompletionBehavior.defaultValue(for: context.returnTarget))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                SmartFillWorkspacePalette.background
                    .ignoresSafeArea()

                VStack(spacing: 14) {
                    previewSurface
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, Theme.Layout.screenPadding)
                .padding(.top, 16)
            }
            .navigationTitle(context.infoTitle ?? "SmartFill")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        handleClose()
                    }
                    .disabled(isCloseDisabled)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(primaryActionTitle) {
                        handlePrimaryAction()
                    }
                    .fontWeight(.semibold)
                    .disabled(isPrimaryActionDisabled)
                }
            }
            .tint(SmartFillWorkspacePalette.accent)
            .safeAreaInset(edge: .bottom) {
                editorChrome
            }
            .sheet(item: $activeSheet) { sheet in
                workspaceSheet(for: sheet)
            }
            .onAppear {
                let launchContext = SmartFillTakeBridge.makeContext(
                    project: context.project,
                    session: context.session,
                    take: context.take,
                    launchSource: context.launchSource,
                    returnTarget: context.returnTarget
                )
                coordinator.begin(context: launchContext, defaults: workspaceDefaults)
                previewErrorMessage = nil
                processingProgress = 0
                autoReturnWorkItem?.cancel()
                autoReturnWorkItem = nil
                activeTool = .background
                activeLookAdjustment = .blur
                previewSelectionState = SmartFillWorkspaceCompareViewerSelectionState(selectedMode: .result)
                previewPinnedWipeProgress = SmartFillWorkspaceCompareWipeState.defaultProgress
                previewPlaybackState = SmartFillWorkspacePreviewPlaybackState()
                activeSheet = nil
            }
            .onChange(of: activeSheet) { oldValue, newValue in
                guard oldValue == .sourcePreview, newValue != .sourcePreview else { return }
                isHoldingPreviewComparison = false
            }
            .onReceive(NotificationCenter.default.publisher(for: .smartFillProcessingProgress)) { notification in
                guard coordinator.stage == .export else { return }
                guard matchesCurrentProcessingNotification(notification) else { return }
                let progress = min(max(notification.userInfo?["progress"] as? Double ?? 0, 0), 1)
                processingProgress = progress
                statusMessage = SmartFillWorkspacePresentation.processingMessage(
                    for: context,
                    progress: progress,
                    completionBehavior: completionBehavior
                )
            }
            .onReceive(NotificationCenter.default.publisher(for: .smartFillDidComplete)) { notification in
                guard matchesCurrentTake(notification) else { return }
                guard let activeContext = coordinator.activeContext,
                      let record = SmartFillResultBridge.makeAdoptionRecord(
                        from: notification,
                        matching: activeContext,
                        settingsSnapshot: SmartFillTakeBridge.snapshot(from: settings)
                      ) else {
                    statusMessage = "SmartFill finished, but the rebuild workspace could not confirm repository adoption."
                    queueAttempted = false
                    return
                }
                coordinator.recordResult(record)
                processingProgress = 1
                statusMessage = SmartFillWorkspacePresentation.completionMessage(
                    for: context,
                    adoptionMode: record.adoptionMode,
                    completionBehavior: completionBehavior,
                    adoptedTakeDisplayName: record.adoptedTakeDisplayName
                )
                queueAttempted = false
                activeTool = .save
                scheduleAutoReturn()
            }
            .onReceive(NotificationCenter.default.publisher(for: .smartFillProcessingFailed)) { notification in
                guard queueAttempted else { return }
                if let takeID = notification.userInfo?["takeID"] as? UUID,
                   takeID != context.take.id {
                    return
                }
                statusMessage = (notification.userInfo?["error"] as? String) ?? "SmartFill couldn't finish for this take."
                coordinator.advance(to: workspaceDefaults.shouldOfferSmartFill ? .configure : .preview)
                processingProgress = 0
                queueAttempted = false
            }
            .onDisappear {
                autoReturnWorkItem?.cancel()
                autoReturnWorkItem = nil
            }
        }
    }

    private var previewSurface: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(SmartFillWorkspacePresentation.headerTitle(for: context))
                        .font(.title3.weight(.bold))
                        .foregroundStyle(SmartFillWorkspacePalette.textPrimary)
                        .lineLimit(1)

                    Text(context.displayName)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Label(stageLabel, systemImage: stageIcon)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(stageColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(stageColor.opacity(0.14), in: Capsule())
            }

            HStack(spacing: 8) {
                Label(fileNameLabel, systemImage: "video.fill")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.04), in: Capsule())

                Spacer()

                Label(effectivePreviewMode.shortTitle, systemImage: effectivePreviewMode.symbolName)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(effectivePreviewMode == .result ? SmartFillWorkspacePalette.accent : SmartFillWorkspacePalette.textPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        (effectivePreviewMode == .result ? SmartFillWorkspacePalette.accent.opacity(0.12) : Color.white.opacity(0.05)),
                        in: Capsule()
                    )
            }

            activePreviewContent
            .frame(maxWidth: .infinity)
            .frame(maxHeight: previewSurfaceMaxHeight)

            if let previewErrorMessage, effectivePreviewMode == .result {
                Label(previewErrorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            previewToolFocusDeck
        }
        .padding(18)
        .background(panelBackground)
    }

    private var editorChrome: some View {
        VStack(spacing: 12) {
            ScrollView(.vertical, showsIndicators: false) {
                activeToolSurface
            }
            .frame(maxHeight: toolTrayHeight)

            toolRail
        }
        .padding(.horizontal, Theme.Layout.screenPadding)
        .padding(.top, 12)
        .padding(.bottom, 16)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(SmartFillWorkspacePalette.chromeFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .stroke(SmartFillWorkspacePalette.chromeStroke, lineWidth: 1)
                )
                .ignoresSafeArea(edges: .bottom)
        )
    }

    @ViewBuilder
    private var activePreviewContent: some View {
        let compareViewerPresented = activeSheet == .sourcePreview
        GeometryReader { geometry in
            pinnedPreviewSurface(
                width: geometry.size.width,
                compareViewerPresented: compareViewerPresented
            )
        }
    }

    private func pinnedPreviewSurface(
        width: CGFloat,
        compareViewerPresented: Bool
    ) -> some View {
        ZStack {
            SmartFillWorkspaceResultPreviewView(
                videoURL: context.previewURL,
                settings: settings,
                refreshID: previewRefreshIdentity,
                playbackState: previewPlaybackState,
                shouldRender: previewSelectionState.isPinnedWipeMode || effectivePreviewMode == .result || compareViewerPresented,
                allowPlayback: (previewSelectionState.isPinnedWipeMode || effectivePreviewMode == .result) && !compareViewerPresented,
                shouldPublishPlaybackState: !compareViewerPresented,
                allowsCanvasScrub: !previewSelectionState.isPinnedWipeMode,
                allowsHoldCompare: !previewSelectionState.isPinnedWipeMode,
                onComparePressingChanged: updatePreviewComparePressing,
                onPlaybackStateChange: updatePreviewPlaybackState
            ) { error in
                previewErrorMessage = error.localizedDescription
            }
            .opacity(previewSelectionState.isPinnedWipeMode || effectivePreviewMode == .result ? 1 : 0)
            .allowsHitTesting(!previewSelectionState.isPinnedWipeMode && effectivePreviewMode == .result)

            SmartFillSourcePreviewView(
                videoURL: context.previewURL,
                playbackState: previewPlaybackState,
                shouldRender: previewSelectionState.isPinnedWipeMode || effectivePreviewMode == .source || compareViewerPresented,
                allowPlayback: (previewSelectionState.isPinnedWipeMode || effectivePreviewMode == .source) && !compareViewerPresented,
                shouldPublishPlaybackState: !compareViewerPresented,
                allowsCanvasScrub: !previewSelectionState.isPinnedWipeMode,
                allowsHoldCompare: !previewSelectionState.isPinnedWipeMode,
                onComparePressingChanged: updatePreviewComparePressing,
                onPlaybackStateChange: updatePreviewPlaybackState
            )
            .opacity(previewSelectionState.isPinnedWipeMode ? 1 : (effectivePreviewMode == .source ? 1 : 0))
            .allowsHitTesting(!previewSelectionState.isPinnedWipeMode && effectivePreviewMode == .source)
            .mask(alignment: .leading) {
                if previewSelectionState.isPinnedWipeMode {
                    Rectangle()
                        .frame(width: width * previewPinnedWipeProgress)
                } else {
                    Rectangle()
                }
            }

            if previewSelectionState.isPinnedWipeMode {
                sharedSplitWipeOverlay(
                    for: SmartFillWorkspaceCompareWipeState(progress: previewPinnedWipeProgress),
                    width: width
                )
            }
        }
        .highPriorityGesture(pinnedPreviewWipeGesture(width: width))
    }

    private var previewToolFocusDeck: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Label(activeTool.shortTitle, systemImage: activeTool.symbolName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(SmartFillWorkspacePalette.textPrimary)

                Spacer()

                if let drillIn = activeToolDrillIn {
                    Button {
                        activeSheet = drillIn.sheet
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: drillIn.symbolName)
                                .font(.caption.weight(.semibold))
                            Text(drillIn.title)
                                .font(.caption.weight(.semibold))
                            Text(drillIn.value)
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        .foregroundStyle(SmartFillWorkspacePalette.textPrimary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.05), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    previewCompareControlGroup(previewCompareGroupState)

                    ForEach(activeToolFocusItems) { item in
                        previewFocusChip(item)
                    }

                    if let record = coordinator.lastResult, activeTool != .save {
                        previewFocusChip(
                            SmartFillWorkspaceFocusItem(
                                title: "Saved",
                                value: record.adoptedTakeDisplayName,
                                symbolName: "sparkles.rectangle.stack"
                            )
                        )
                    }
                }
                .padding(.horizontal, 2)
            }
        }
    }

    @ViewBuilder
    private var activeToolSurface: some View {
        switch activeTool {
        case .background:
            lookSurface
        case .subject:
            framingSurface
        case .output:
            outputSurface
        case .save:
            saveSurface
        }
    }

    private var toolRail: some View {
        HStack(spacing: 10) {
            ForEach(SmartFillWorkspaceTool.allCases, id: \.self) { tool in
                Button {
                    activeTool = tool
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: tool.symbolName)
                            .font(.system(size: 16, weight: .semibold))
                        Text(tool.shortTitle)
                            .font(.caption2.weight(.semibold))
                    }
                    .foregroundStyle(activeTool == tool ? SmartFillWorkspacePalette.textPrimary : .secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(activeTool == tool ? SmartFillWorkspacePalette.accent.opacity(0.18) : Color.white.opacity(0.04))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(activeTool == tool ? SmartFillWorkspacePalette.accent.opacity(0.6) : Color.white.opacity(0.08), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var lookSurface: some View {
        VStack(alignment: .leading, spacing: 14) {
            toolSectionHeader("Background", value: SmartFillWorkspacePresentation.backgroundModeTitle(for: settings))

            compactToolGroup(title: "Mode", value: SmartFillWorkspacePresentation.backgroundModeTitle(for: settings)) {
                ForEach(SmartFillWorkspaceBackgroundMode.allCases, id: \.self) { mode in
                    compactToolChip(
                        title: mode.title,
                        subtitle: nil,
                        systemImage: activeBackgroundMode == mode ? "checkmark.circle.fill" : nil,
                        isSelected: activeBackgroundMode == mode
                    ) {
                        applyBackgroundMode(mode)
                    }
                }
            }

            compactToolGroup(title: "Finish", value: activeTreatmentPreset?.title ?? "Custom") {
                ForEach(SmartFillWorkspaceTreatmentPreset.allCases, id: \.self) { preset in
                    compactToolChip(
                        title: preset.title,
                        subtitle: nil,
                        systemImage: activeTreatmentPreset == preset ? "checkmark.circle.fill" : nil,
                        isSelected: activeTreatmentPreset == preset
                    ) {
                        applyTreatmentPreset(preset)
                    }
                }
            }

            compactToolGroup(title: "More", value: nil) {
                toolLinkChip(
                    title: "Fill",
                    subtitle: activeFillPreset?.title ?? "Custom",
                    systemImage: "arrow.up.left.and.arrow.down.right"
                ) {
                    activeSheet = .backgroundFill
                }

                toolLinkChip(
                    title: "Fine tune",
                    subtitle: activeLookAdjustment.valueLabel(for: settings),
                    systemImage: "slider.horizontal.3"
                ) {
                    activeSheet = .lookAdjustments
                }

                toolLinkChip(
                    title: "Advanced",
                    subtitle: "More",
                    systemImage: "ellipsis.circle"
                ) {
                    activeSheet = .advancedLook
                }
            }
        }
        .padding(18)
        .background(panelBackground)
    }

    private var framingSurface: some View {
        VStack(alignment: .leading, spacing: 16) {
            toolSectionHeader("Subject", value: String(format: "%.2f×", settings.foregroundScale))

            compactToolGroup(title: "Scale", value: String(format: "%.2f×", settings.foregroundScale)) {
                ForEach(SmartFillWorkspaceSubjectPreset.allCases, id: \.self) { preset in
                    compactToolChip(
                        title: preset.title,
                        subtitle: preset.valueLabel,
                        systemImage: nil,
                        isSelected: preset.matches(settings.foregroundScale)
                    ) {
                        applySubjectPreset(preset)
                    }
                }
            }

            compactToolGroup(title: "More", value: nil) {
                toolLinkChip(
                    title: "Precision",
                    subtitle: String(format: "%.2f×", settings.foregroundScale),
                    systemImage: "slider.horizontal.below.rectangle"
                ) {
                    activeSheet = .subjectScale
                }
            }
        }
        .padding(18)
        .background(panelBackground)
    }

    private var outputSurface: some View {
        VStack(alignment: .leading, spacing: 16) {
            toolSectionHeader("Output", value: "\(Int(settings.renderSize.width))×\(Int(settings.renderSize.height))")

            compactToolGroup(title: "Resolution", value: "\(Int(settings.renderSize.width))×\(Int(settings.renderSize.height))") {
                renderSizeChip(width: 1920, height: 1080, title: "Full HD", subtitle: "1080p")
                renderSizeChip(width: 1280, height: 720, title: "HD", subtitle: "720p")
                renderSizeChip(width: 3840, height: 2160, title: "4K", subtitle: "2160p")
            }

            VStack(alignment: .leading, spacing: 10) {
                toolSubheader("Speed", value: SmartFillWorkspacePresentation.processingPriorityTitle(for: settings.processingPriority))

                compactToolGroup(title: nil, value: nil) {
                    toolLinkChip(
                        title: "Processing",
                        subtitle: SmartFillWorkspacePresentation.processingPriorityTitle(for: settings.processingPriority),
                        systemImage: "bolt.fill"
                    ) {
                        activeSheet = .outputOptions
                    }
                }
            }
        }
        .padding(18)
        .background(panelBackground)
    }

    private var saveSurface: some View {
        VStack(alignment: .leading, spacing: 12) {
            toolSectionHeader("Save", value: completionBehavior.summaryTitle)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    statusPill(
                        icon: "square.and.arrow.down",
                        title: "Destination",
                        value: SmartFillWorkspacePresentation.destinationTitle(for: context)
                    )
                    statusPill(
                        icon: "arrowshape.turn.up.backward",
                        title: "Return to",
                        value: SmartFillWorkspacePresentation.returnTargetTitle(for: context)
                    )
                    statusPill(
                        icon: "arrow.triangle.2.circlepath",
                        title: "After save",
                        value: completionBehavior.summaryTitle
                    )
                    statusPill(
                        icon: "sparkles.rectangle.stack",
                        title: "Action",
                        value: primaryActionTitle
                    )
                }
                .padding(.horizontal, 2)
            }

            toolSectionCard {
                VStack(alignment: .leading, spacing: 10) {
                    Text("After save")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(SmartFillWorkspacePalette.textPrimary)

                    Picker("After save", selection: $completionBehavior) {
                        ForEach(SmartFillWorkspaceCompletionBehavior.allCases, id: \.self) { behavior in
                            Text(behavior.pickerTitle)
                                .tag(behavior)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text(completionBehavior.caption(for: context))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            compactToolGroup(title: "More", value: nil) {
                toolLinkChip(
                    title: "Save details",
                    subtitle: completionBehavior.summaryTitle,
                    systemImage: "square.and.arrow.down.on.square"
                ) {
                    activeSheet = .savePlan
                }
            }

            if hasUnsavedChangesSinceLastSave {
                Label(
                    SmartFillWorkspacePresentation.unsavedChangesMessage(
                        for: context,
                        adoptionMode: coordinator.lastResult?.adoptionMode
                    ),
                    systemImage: "exclamationmark.circle.fill"
                )
                .font(.caption)
                .foregroundStyle(.orange)
            } else if let statusMessage {
                Label(statusMessage, systemImage: stageIcon)
                    .font(.caption)
                    .foregroundStyle(stageColor)
            } else {
                Text(
                    SmartFillWorkspacePresentation.saveFootnote(
                        for: context,
                        completionBehavior: completionBehavior
                    )
                )
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(18)
        .background(panelBackground)
    }

    @ViewBuilder
    private func workspaceSheet(for sheet: SmartFillWorkspaceSheet) -> some View {
        switch sheet {
        case .advancedLook:
            SmartFillAdvancedSettingsView(
                blurRadius: blurRadiusBinding,
                darkenAmount: darkenAmountBinding,
                backgroundScale: backgroundScaleBinding
            )
        case .backgroundFill:
            workspaceSheetContainer(
                title: "Background fill",
                subtitle: "Use the quick mode and finish choices in the tray, then pick the fill strength here when the frame needs more or less coverage."
            ) {
                compactToolGroup(title: "Fill", value: activeFillPreset?.title ?? "Custom") {
                    ForEach(SmartFillWorkspaceBackgroundFillPreset.allCases, id: \.self) { preset in
                        compactToolChip(
                            title: preset.title,
                            subtitle: String(format: "%.1f×", preset.scale),
                            systemImage: activeFillPreset == preset ? "checkmark.circle.fill" : nil,
                            isSelected: activeFillPreset == preset
                        ) {
                            applyBackgroundFillPreset(preset)
                        }
                    }
                }
            }
        case .lookAdjustments:
            workspaceSheetContainer(
                title: "Fine tune",
                subtitle: "Adjust blur, darkening, and fill without crowding the main tray."
            ) {
                compactToolGroup(title: "Adjust", value: activeLookAdjustment.valueLabel(for: settings)) {
                    ForEach(SmartFillWorkspaceLookAdjustment.allCases, id: \.self) { adjustment in
                        compactToolChip(
                            title: adjustment.shortTitle,
                            subtitle: adjustment.valueLabel(for: settings),
                            systemImage: adjustment.symbolName,
                            isSelected: activeLookAdjustment == adjustment
                        ) {
                            activeLookAdjustment = adjustment
                        }
                    }
                }

                activeLookAdjustmentControl
            }
        case .subjectScale:
            workspaceSheetContainer(
                title: "Subject scale",
                subtitle: "Use presets in the main tray, then refine the framing here when the subject needs a tighter fit."
            ) {
                toolSectionCard {
                    toolSubheader("Scale", value: String(format: "%.2f×", settings.foregroundScale))

                    Slider(value: foregroundScaleBinding, in: 0.85...1.25, step: 0.05) {
                        Text("Subject scale")
                    }
                    .tint(SmartFillWorkspacePalette.accent)
                }
            }
        case .outputOptions:
            workspaceSheetContainer(
                title: "Processing options",
                subtitle: "Keep resolution in the main tray and change processing speed here."
            ) {
                toolSectionCard {
                    toolSubheader("Speed", value: SmartFillWorkspacePresentation.processingPriorityTitle(for: settings.processingPriority))

                    Picker("Processing speed", selection: processingPriorityBinding) {
                        ForEach(SmartFillSettings.ProcessingPriority.allCases, id: \.self) { priority in
                            Text(SmartFillWorkspacePresentation.processingPriorityTitle(for: priority))
                                .tag(priority)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
        case .savePlan:
            workspaceSheetContainer(
                title: "Save details",
                subtitle: "Review what save does, choose whether to stay or return, and inspect the latest saved result."
            ) {
                toolSectionCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("After save")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(SmartFillWorkspacePalette.textPrimary)

                        Picker("After save", selection: $completionBehavior) {
                            ForEach(SmartFillWorkspaceCompletionBehavior.allCases, id: \.self) { behavior in
                                Text(behavior.pickerTitle)
                                    .tag(behavior)
                            }
                        }
                        .pickerStyle(.segmented)

                        Text(completionBehavior.caption(for: context))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                saveOutcomePanel

                if let record = coordinator.lastResult {
                    latestSavedResultPanel(for: record)
                }

                if coordinator.stage == .export {
                    exportProgressPanel
                } else if hasPendingAutoReturn, let record = coordinator.lastResult {
                    returnControlPanel(for: record)
                } else if effectiveStage == .completed && completionBehavior == .stayHere && !hasUnsavedChangesSinceLastSave, let record = coordinator.lastResult {
                    stayComparisonPanel(for: record)
                }
            }
        case .sourcePreview:
            workspaceSheetContainer(
                title: "Compare",
                subtitle: SmartFillWorkspacePresentation.compareViewerMessage(
                    for: context,
                    adoptedTakeDisplayName: coordinator.lastResult?.adoptedTakeDisplayName
                )
            ) {
                SmartFillWorkspaceCompareViewer(
                    videoURL: context.previewURL,
                    settings: settings,
                    refreshID: previewRefreshIdentity,
                    playbackState: previewPlaybackState,
                    selectionState: $previewSelectionState,
                    pinnedWipeProgress: $previewPinnedWipeProgress,
                    sourceTitle: SmartFillWorkspacePresentation.sourcePreviewTitle(for: context),
                    resultTitle: SmartFillWorkspacePresentation.previewResultTitle(
                        adoptedTakeDisplayName: coordinator.lastResult?.adoptedTakeDisplayName
                    ),
                    previewErrorMessage: previewErrorMessage,
                    onPlaybackStateChange: updatePreviewPlaybackState
                ) { error in
                    previewErrorMessage = error.localizedDescription
                }
            }
        }
    }

    @ViewBuilder
    private var activeLookAdjustmentControl: some View {
        switch activeLookAdjustment {
        case .blur:
            treatmentSlider(
                icon: activeLookAdjustment.symbolName,
                title: "Blur radius",
                valueLabel: activeLookAdjustment.valueLabel(for: settings),
                caption: blurCaption(for: settings.blurRadius),
                value: blurRadiusBinding,
                range: 8...50,
                step: 2
            )
        case .darken:
            treatmentSlider(
                icon: activeLookAdjustment.symbolName,
                title: "Darken amount",
                valueLabel: activeLookAdjustment.valueLabel(for: settings),
                caption: darkenCaption(for: settings.darkenAmount),
                value: darkenAmountBinding,
                range: 0...0.3,
                step: 0.02
            )
        case .fill:
            treatmentSlider(
                icon: activeLookAdjustment.symbolName,
                title: "Background fill",
                valueLabel: activeLookAdjustment.valueLabel(for: settings),
                caption: backgroundScaleCaption(for: settings.backgroundScale),
                value: backgroundScaleBinding,
                range: 1.0...15.0,
                step: 0.5
            )
        }
    }

    private var exportProgressPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Save progress")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(SmartFillWorkspacePalette.textPrimary)
                Spacer()
                Text("\(Int((processingProgress * 100).rounded()))%")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(SmartFillWorkspacePalette.accent)
            }

            ProgressView(value: processingProgress)
                .tint(SmartFillWorkspacePalette.accent)

            Text("SmartFill is rendering the landscape version and preparing the return to \(SmartFillWorkspacePresentation.returnTargetTitle(for: context).lowercased()).")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func returnControlPanel(for record: SmartFillResultBridgeRecord) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Saved and ready", systemImage: "checkmark.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.green)
                Spacer()
                Button("Stay Here") {
                    cancelAutoReturn()
                }
                .font(.caption.weight(.semibold))
            }

            Text(
                SmartFillWorkspacePresentation.returnControlMessage(
                    for: context,
                    adoptionMode: record.adoptionMode,
                    adoptedTakeDisplayName: record.adoptedTakeDisplayName
                )
            )
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func stayComparisonPanel(for record: SmartFillResultBridgeRecord) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Saved and staying here", systemImage: "eye.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(SmartFillWorkspacePalette.accent)

            Text(
                SmartFillWorkspacePresentation.stayComparisonMessage(
                    for: context,
                    adoptionMode: record.adoptionMode,
                    adoptedTakeDisplayName: record.adoptedTakeDisplayName
                )
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var blurRadiusBinding: Binding<Double> {
        Binding(
            get: { Double(settings.blurRadius) },
            set: {
                settings.blurRadius = CGFloat($0)
                markSettingsDirty()
            }
        )
    }

    private var darkenAmountBinding: Binding<Double> {
        Binding(
            get: { Double(settings.darkenAmount) },
            set: {
                settings.darkenAmount = CGFloat($0)
                markSettingsDirty()
            }
        )
    }

    private var backgroundScaleBinding: Binding<Double> {
        Binding(
            get: { Double(settings.backgroundScale) },
            set: {
                settings.backgroundScale = CGFloat($0)
                markSettingsDirty()
            }
        )
    }

    private var foregroundScaleBinding: Binding<Double> {
        Binding(
            get: { Double(settings.foregroundScale) },
            set: {
                settings.foregroundScale = CGFloat($0)
                markSettingsDirty()
            }
        )
    }

    private var processingPriorityBinding: Binding<SmartFillSettings.ProcessingPriority> {
        Binding(
            get: { settings.processingPriority },
            set: {
                settings.processingPriority = $0
                markSettingsDirty()
            }
        )
    }

    private var panelBackground: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(SmartFillWorkspacePalette.panelFill)
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(SmartFillWorkspacePalette.panelStroke, lineWidth: 1)
            )
    }

    private var primaryActionTitle: String {
        SmartFillWorkspacePresentation.actionTitle(
            for: context,
            stage: coordinator.stage,
            completionBehavior: completionBehavior,
            hasUnsavedChanges: hasUnsavedChangesSinceLastSave,
            adoptedTakeDisplayName: coordinator.lastResult?.adoptedTakeDisplayName
        )
    }

    private var isPrimaryActionDisabled: Bool {
        coordinator.stage == .export
    }

    private var isCloseDisabled: Bool {
        coordinator.stage == .export
    }

    private var hasPendingAutoReturn: Bool {
        coordinator.stage == .completed && !hasUnsavedChangesSinceLastSave && autoReturnWorkItem != nil
    }

    private var hasUnsavedChangesSinceLastSave: Bool {
        guard let snapshot = coordinator.lastResult?.settingsSnapshot else { return false }
        return SmartFillTakeBridge.snapshot(from: settings) != snapshot
    }

    private var effectiveStage: SmartFillWorkspaceCoordinator.Stage {
        if coordinator.stage == .completed && hasUnsavedChangesSinceLastSave {
            return .preview
        }
        return coordinator.stage
    }

    private var fileNameLabel: String {
        context.previewURL.lastPathComponent
    }

    private var previewRefreshIdentity: String {
        "\(context.previewURL.path)|\(settings.forceUpdateToken.uuidString)"
    }

    private var previewSurfaceMaxHeight: CGFloat {
        verticalSizeClass == .compact ? 250 : 360
    }

    private var previewCompareState: SmartFillWorkspacePreviewCompareState {
        SmartFillWorkspacePreviewCompareState(
            selectedMode: previewSelectionState.selectedMode,
            isHoldingComparison: isHoldingPreviewComparison,
            isPinnedWipeMode: previewSelectionState.isPinnedWipeMode
        )
    }

    private var effectivePreviewMode: SmartFillWorkspacePreviewMode {
        previewCompareState.effectiveMode
    }

    private var toolTrayHeight: CGFloat {
        switch (verticalSizeClass, activeTool) {
        case (.compact, .save):
            return 205
        case (.compact, .background):
            return 165
        case (.compact, _):
            return 135
        case (_, .save):
            return 235
        case (_, .background):
            return 175
        default:
            return 145
        }
    }

    private var activeToolFocusItems: [SmartFillWorkspaceFocusItem] {
        activeTool.focusItems(
            settings: settings,
            completionBehavior: completionBehavior,
            savedTakeName: coordinator.lastResult?.adoptedTakeDisplayName
        )
    }

    private var previewCompareGroupState: SmartFillWorkspacePreviewCompareGroupState {
        SmartFillWorkspacePreviewCompareGroupState(
            toolbarMode: previewSelectionState.toolbarMode,
            viewerControl: SmartFillWorkspacePreviewCompareControl(
                title: "Viewer",
                value: previewSelectionState.toolbarMode.title,
                symbolName: previewSelectionState.toolbarMode.symbolName,
                compareMode: previewSelectionState.toolbarMode
            )
        )
    }

    private var activeToolDrillIn: SmartFillWorkspaceDrillInDescriptor? {
        activeTool.drillInDescriptor(
            settings: settings,
            completionBehavior: completionBehavior,
            savedTakeName: coordinator.lastResult?.adoptedTakeDisplayName,
            activeLookAdjustment: activeLookAdjustment
        )
    }

    private var stageLabel: String {
        switch effectiveStage {
        case .intake: return "Ready"
        case .configure: return "Configure"
        case .preview:
            return hasUnsavedChangesSinceLastSave ? "Needs Save" : "Preview"
        case .export:
            return "Saving \(Int((processingProgress * 100).rounded()))%"
        case .completed: return "Complete"
        }
    }

    private var stageIcon: String {
        switch effectiveStage {
        case .intake: return "tray.and.arrow.down"
        case .configure: return "wand.and.stars"
        case .preview:
            return hasUnsavedChangesSinceLastSave ? "exclamationmark.circle.fill" : "play.rectangle"
        case .export: return "gearshape.2"
        case .completed: return "checkmark.circle.fill"
        }
    }

    private var stageColor: Color {
        switch effectiveStage {
        case .completed: return .green
        case .export: return SmartFillWorkspacePalette.accent
        case .preview where hasUnsavedChangesSinceLastSave: return .orange
        default: return .secondary
        }
    }

    private var activeBackgroundMode: SmartFillWorkspaceBackgroundMode? {
        SmartFillWorkspaceBackgroundMode.allCases.first { $0.matches(settings) }
    }

    private var activeTreatmentPreset: SmartFillWorkspaceTreatmentPreset? {
        SmartFillWorkspaceTreatmentPreset.allCases.first { $0.matches(settings) }
    }

    private var activeFillPreset: SmartFillWorkspaceBackgroundFillPreset? {
        SmartFillWorkspaceBackgroundFillPreset.allCases.first { $0.matches(settings.backgroundScale) }
    }

    private var currentAdoptionMode: SmartFillResultAdoptionMode {
        coordinator.lastResult?.adoptionMode ?? expectedAdoptionMode
    }

    private var expectedAdoptionMode: SmartFillResultAdoptionMode {
        context.take.isSmartFillVariant ? .updateExistingTakePath : .createStandaloneVariantTake
    }

    @ViewBuilder
    private var saveOutcomePanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("What happens on save")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(SmartFillWorkspacePalette.textPrimary)

            summaryRow(
                icon: "film",
                title: "Source clip",
                value: SmartFillWorkspacePresentation.sourceClipOutcomeTitle()
            )
            summaryRow(
                icon: "sparkles.rectangle.stack",
                title: "SmartFill result",
                value: coordinator.lastResult?.adoptedTakeDisplayName ?? SmartFillWorkspacePresentation.destinationOutcomeTitle(for: currentAdoptionMode)
            )
            summaryRow(
                icon: "arrowshape.turn.up.forward",
                title: "After save",
                value: SmartFillWorkspacePresentation.afterSaveOutcomeTitle(
                    for: context,
                    stage: coordinator.stage,
                    completionBehavior: completionBehavior,
                    hasPendingAutoReturn: hasPendingAutoReturn,
                    hasUnsavedChanges: hasUnsavedChangesSinceLastSave,
                    adoptedTakeDisplayName: coordinator.lastResult?.adoptedTakeDisplayName
                )
            )

            Text(
                SmartFillWorkspacePresentation.saveOutcomeMessage(
                    for: context,
                    adoptionMode: currentAdoptionMode,
                    stage: coordinator.stage,
                    completionBehavior: completionBehavior,
                    hasPendingAutoReturn: hasPendingAutoReturn,
                    hasUnsavedChanges: hasUnsavedChangesSinceLastSave,
                    adoptedTakeDisplayName: coordinator.lastResult?.adoptedTakeDisplayName
                )
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    @ViewBuilder
    private func latestSavedResultPanel(for record: SmartFillResultBridgeRecord) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(SmartFillWorkspacePresentation.destinationOutcomeTitle(for: record.adoptionMode))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(SmartFillWorkspacePalette.textPrimary)

            Text(record.destinationSummary)
                .font(.caption)
                .foregroundStyle(.secondary)

            summaryRow(
                icon: "rectangle.stack.fill",
                title: "Session take",
                value: record.adoptedTakeDisplayName
            )
            summaryRow(
                icon: "film.stack.fill",
                title: "Saved output",
                value: record.outputURL.lastPathComponent
            )
            summaryRow(
                icon: "circle.lefthalf.filled",
                title: "Saved look",
                value: savedSettingsSummary(from: record)
            )

            if hasUnsavedChangesSinceLastSave {
                Label(
                    SmartFillWorkspacePresentation.unsavedChangesMessage(
                        for: context,
                        adoptionMode: record.adoptionMode
                    ),
                    systemImage: "exclamationmark.triangle.fill"
                )
                .font(.caption)
                .foregroundStyle(.orange)
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
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
        case .subtle: return "Light blur and minimal darkening"
        case .medium: return "Balanced blur for most takes"
        case .dramatic: return "Strong blur for more separation"
        }
    }

    @ViewBuilder
    private func summaryRow(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(SmartFillWorkspacePalette.accent)
            Text(title)
                .foregroundStyle(SmartFillWorkspacePalette.textPrimary)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
        }
        .font(.subheadline)
    }

    private func toolSectionHeader(_ title: String, value: String) -> some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundStyle(SmartFillWorkspacePalette.textPrimary)
            Spacer()
            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.05), in: Capsule())
        }
    }

    private func toolSubheader(_ title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(SmartFillWorkspacePalette.textPrimary)
            Spacer()
            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func compactToolGroup<Content: View>(title: String?, value: String?, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if let title, let value {
                toolSubheader(title, value: value)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    content()
                }
                .padding(.horizontal, 2)
            }
        }
    }

    private func compactToolChip(
        title: String,
        subtitle: String?,
        systemImage: String?,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.caption.weight(.semibold))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.caption.weight(.semibold))
                    if let subtitle {
                        Text(subtitle)
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(isSelected ? SmartFillWorkspacePalette.textPrimary.opacity(0.88) : .secondary)
                    }
                }
            }
            .foregroundStyle(isSelected ? SmartFillWorkspacePalette.textPrimary : .secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? SmartFillWorkspacePalette.accent.opacity(0.18) : Color.white.opacity(0.03))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? SmartFillWorkspacePalette.accent.opacity(0.6) : Color.white.opacity(0.10), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func statusPill(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(SmartFillWorkspacePalette.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(SmartFillWorkspacePalette.textPrimary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.05), in: Capsule())
    }

    private func previewFocusChip(_ item: SmartFillWorkspaceFocusItem) -> some View {
        HStack(spacing: 8) {
            Image(systemName: item.symbolName)
                .font(.caption.weight(.semibold))
                .foregroundStyle(SmartFillWorkspacePalette.accent)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(item.value)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(SmartFillWorkspacePalette.textPrimary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.04), in: Capsule())
    }

    private func previewCompareControlGroup(_ state: SmartFillWorkspacePreviewCompareGroupState) -> some View {
        HStack(spacing: 4) {
            previewCompareSegment(
                title: "Source",
                symbolName: "film",
                isSelected: state.selectedSegment == .source
            ) {
                handlePreviewCompareModeSelection(.source)
            }

            previewCompareSegment(
                title: "Current",
                symbolName: "sparkles.tv",
                isSelected: state.selectedSegment == .current
            ) {
                handlePreviewCompareModeSelection(.current)
            }

            previewCompareSegment(
                title: "Wipe",
                symbolName: "rectangle.split.2x1",
                isSelected: state.selectedSegment == .wipe
            ) {
                handlePreviewCompareModeSelection(.wipe)
            }

            previewCompareSegment(
                title: state.viewerControl.title,
                symbolName: state.viewerControl.symbolName,
                isSelected: false,
                showsLaunchGlyph: true
            ) {
                openPreviewCompareViewer()
            }
        }
        .padding(4)
        .background(Color.white.opacity(0.04), in: Capsule())
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private func previewCompareSegment(
        title: String,
        symbolName: String,
        isSelected: Bool,
        showsLaunchGlyph: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: symbolName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(isSelected ? SmartFillWorkspacePalette.accent : .secondary)

                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(isSelected ? SmartFillWorkspacePalette.textPrimary : .secondary)
                    .lineLimit(1)

                if showsLaunchGlyph {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(isSelected ? SmartFillWorkspacePalette.accent.opacity(0.9) : .secondary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? SmartFillWorkspacePalette.accent.opacity(0.18) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }

    private func toolLinkChip(
        title: String,
        subtitle: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .foregroundStyle(SmartFillWorkspacePalette.accent)
                    .font(.subheadline.weight(.semibold))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(subtitle)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(SmartFillWorkspacePalette.textPrimary)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func treatmentSlider(
        icon: String,
        title: String,
        valueLabel: String,
        caption: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Label(title, systemImage: icon)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(valueLabel)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(SmartFillWorkspacePalette.textPrimary)
            }

            Slider(value: value, in: range, step: step) {
                Text(title)
            }
            .tint(SmartFillWorkspacePalette.accent)

            if !caption.isEmpty {
                Text(caption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func toolSectionCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            content()
        }
        .padding(16)
        .background(SmartFillWorkspacePalette.panelFill, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(SmartFillWorkspacePalette.panelStroke, lineWidth: 1)
        )
    }

    private func workspaceSheetContainer<Content: View>(
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        NavigationStack {
            ZStack {
                SmartFillWorkspacePalette.background
                    .ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        content()
                    }
                    .padding(Theme.Layout.screenPadding)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .tint(SmartFillWorkspacePalette.accent)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        activeSheet = nil
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private func renderSizeChip(width: CGFloat, height: CGFloat, title: String, subtitle: String) -> some View {
        let isSelected = Int(settings.renderSize.width) == Int(width) && Int(settings.renderSize.height) == Int(height)

        return compactToolChip(
            title: title,
            subtitle: subtitle,
            systemImage: isSelected ? "checkmark.circle.fill" : nil,
            isSelected: isSelected
        ) {
            settings.renderSize = CGSize(width: width, height: height)
            markSettingsDirty()
        }
    }

    private func applyBackgroundMode(_ mode: SmartFillWorkspaceBackgroundMode) {
        let preset = mode.preset
        settings.blurRadius = preset.blurRadius
        settings.darkenAmount = preset.darkenAmount
        settings.backgroundScale = preset.backgroundScale
        settings.presetName = presetTitle(for: preset)
        settings.processingPriority = .userInitiated
        markSettingsDirty()
    }

    private func applyBackgroundFillPreset(_ preset: SmartFillWorkspaceBackgroundFillPreset) {
        settings.backgroundScale = preset.scale
        settings.forceUpdateToken = UUID()
        markSettingsDirty()
    }

    private func applyTreatmentPreset(_ preset: SmartFillWorkspaceTreatmentPreset) {
        settings.blurRadius = preset.blurRadius
        settings.darkenAmount = preset.darkenAmount
        settings.presetName = preset.presetName
        settings.forceUpdateToken = UUID()
        markSettingsDirty()
    }

    private func applySubjectPreset(_ preset: SmartFillWorkspaceSubjectPreset) {
        settings.foregroundScale = preset.scale
        markSettingsDirty()
    }

    private func queueSmartFill() {
        let clamped = settings.clamped()
        settings = clamped
        settings.saveToUserDefaults()
        coordinator.updateSettings(SmartFillTakeBridge.snapshot(from: clamped))
        coordinator.advance(to: .export)
        processingProgress = 0
        statusMessage = SmartFillWorkspacePresentation.processingMessage(
            for: context,
            progress: 0,
            completionBehavior: completionBehavior
        )
        queueAttempted = true
        onQueueSmartFill(clamped)
    }

    private func handlePrimaryAction() {
        if effectiveStage == .completed {
            autoReturnWorkItem?.cancel()
            autoReturnWorkItem = nil
            performCompletionFollowUp(
                SmartFillWorkspaceCompletionFollowUpAction.primaryAction(
                    hasSavedResult: coordinator.lastResult != nil,
                    canOpenSavedTake: onOpenSavedTake != nil
                )
            )
            return
        }

        queueSmartFill()
    }

    private func scheduleAutoReturn() {
        let action = SmartFillWorkspaceCompletionFollowUpAction.autoReturn(
            completionBehavior: completionBehavior,
            hasSavedResult: coordinator.lastResult != nil,
            canOpenSavedTake: onOpenSavedTake != nil
        )
        guard action != .closeOnly || completionBehavior == .returnAutomatically else {
            autoReturnWorkItem?.cancel()
            autoReturnWorkItem = nil
            return
        }
        autoReturnWorkItem?.cancel()
        let workItem = DispatchWorkItem {
            performCompletionFollowUp(action)
        }
        autoReturnWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + autoReturnDelay, execute: workItem)
    }

    private var autoReturnDelay: TimeInterval {
        switch context.returnTarget {
        case .editor:
            return 0.8
        case .swipeablePlayer, .takeReview:
            return 1.0
        case .projectDetail, .standaloneWorkspace:
            return 0.9
        }
    }

    private func blurCaption(for blurRadius: CGFloat) -> String {
        switch blurRadius {
        case ..<18:
            return "Keeps more of the room detail visible."
        case 18..<34:
            return "Balanced separation for most SmartFill passes."
        default:
            return "Pushes the room further back when the background needs to disappear."
        }
    }

    private func darkenCaption(for darkenAmount: CGFloat) -> String {
        switch darkenAmount {
        case ..<0.08:
            return "Very light darkening keeps the background natural."
        case 0.08..<0.18:
            return "Balanced darkening helps the subject hold focus."
        default:
            return "Heavy darkening creates a more stylized, dramatic contrast."
        }
    }

    private func backgroundScaleCaption(for backgroundScale: CGFloat) -> String {
        switch backgroundScale {
        case ..<2.0:
            return "Minimal fill keeps more of the original room in frame."
        case 2.0..<5.0:
            return "Balanced fill for most portrait-to-landscape conversions."
        case 5.0..<8.0:
            return "Stronger fill removes more empty edges around the subject."
        default:
            return "Maximum fill aggressively hides background gaps."
        }
    }

    private func matchesCurrentTake(_ notification: Notification) -> Bool {
        if let originalTakeID = notification.userInfo?["originalTakeID"] as? UUID {
            return originalTakeID == context.take.id
        }
        if let originalTakeID = notification.userInfo?["originalTakeID"] as? String {
            return UUID(uuidString: originalTakeID) == context.take.id
        }
        return false
    }

    private func matchesCurrentProcessingNotification(_ notification: Notification) -> Bool {
        if let takeID = notification.userInfo?["takeID"] as? UUID {
            return takeID == context.take.id
        }
        if let takeID = notification.userInfo?["takeID"] as? String {
            return UUID(uuidString: takeID) == context.take.id
        }
        return false
    }

    private func markSettingsDirty() {
        settings.forceUpdateToken = UUID()
        previewErrorMessage = nil
        if coordinator.stage == .completed {
            cancelAutoReturn()
        }
    }

    private func handlePreviewCompareModeSelection(_ mode: SmartFillWorkspaceCompareViewerMode) {
        isHoldingPreviewComparison = false
        previewSelectionState.selectToolbarMode(mode)
    }

    private func openPreviewCompareViewer() {
        isHoldingPreviewComparison = false
        activeSheet = .sourcePreview
    }

    private func pinnedPreviewWipeGesture(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { value in
                guard previewSelectionState.isPinnedWipeMode else { return }
                previewPinnedWipeProgress = SmartFillWorkspaceCompareWipeState.clampedProgress(
                    for: value.location.x,
                    width: width
                )
            }
    }

    private func sharedSplitWipeOverlay(
        for wipeState: SmartFillWorkspaceCompareWipeState,
        width: CGFloat
    ) -> some View {
        let clampedX = min(max(width * wipeState.progress, 0), width)

        return ZStack {
            Rectangle()
                .fill(.white.opacity(0.92))
                .frame(width: 2)
                .shadow(color: .black.opacity(0.22), radius: 5, x: 0, y: 0)
                .frame(maxHeight: .infinity)
                .offset(x: clampedX - (width / 2))

            VStack {
                HStack {
                    compareEdgeBadge(title: "Source", alignment: .leading)
                    Spacer()
                    compareEdgeBadge(title: "Current", alignment: .trailing)
                }
                Spacer()
            }
            .padding(12)
        }
        .allowsHitTesting(false)
    }

    private func compareEdgeBadge(
        title: String,
        alignment: Alignment
    ) -> some View {
        Text(title)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color.black.opacity(0.62), in: Capsule())
            .frame(maxWidth: .infinity, alignment: alignment)
    }

    private func updatePreviewComparePressing(_ isPressing: Bool) {
        guard !previewSelectionState.isPinnedWipeMode else {
            isHoldingPreviewComparison = false
            return
        }
        isHoldingPreviewComparison = isPressing
    }

    private func updatePreviewPlaybackState(_ state: SmartFillWorkspacePreviewPlaybackState) {
        guard previewPlaybackState.shouldReplace(with: state) else {
            return
        }
        previewPlaybackState = state
    }

    private func cancelAutoReturn() {
        autoReturnWorkItem?.cancel()
        autoReturnWorkItem = nil
        statusMessage = SmartFillWorkspacePresentation.deferredReturnMessage(
            for: context,
            adoptionMode: coordinator.lastResult?.adoptionMode,
            completionBehavior: completionBehavior,
            adoptedTakeDisplayName: coordinator.lastResult?.adoptedTakeDisplayName
        )
    }

    private func savedSettingsSummary(from record: SmartFillResultBridgeRecord) -> String {
        guard let snapshot = record.settingsSnapshot else {
            return SmartFillWorkspacePresentation.destinationOutcomeTitle(for: record.adoptionMode)
        }

        let savedSettings = SmartFillTakeBridge.settings(from: snapshot)
        let renderSize = "\(Int(savedSettings.renderSize.width))×\(Int(savedSettings.renderSize.height))"
        return "\(SmartFillWorkspacePresentation.backgroundModeTitle(for: savedSettings)) • \(renderSize)"
    }

    private func handleClose() {
        onCancel()
        dismiss()
    }

    private func performCompletionFollowUp(_ action: SmartFillWorkspaceCompletionFollowUpAction) {
        switch action {
        case .openSavedTake:
            if let record = coordinator.lastResult,
               let onOpenSavedTake {
                onOpenSavedTake(record)
            } else {
                handleClose()
            }
        case .closeOnly:
            handleClose()
        }
    }
}

private enum SmartFillWorkspaceBackgroundMode: CaseIterable {
    case natural
    case balanced
    case cinematic

    var preset: SmartFillSettings.Preset {
        switch self {
        case .natural:
            return .subtle
        case .balanced:
            return .medium
        case .cinematic:
            return .dramatic
        }
    }

    var title: String {
        switch self {
        case .natural:
            return "Natural"
        case .balanced:
            return "Balanced"
        case .cinematic:
            return "Cinematic"
        }
    }

    var caption: String {
        switch self {
        case .natural:
            return "Keep more of the original room and texture."
        case .balanced:
            return "Most audition takes look right here."
        case .cinematic:
            return "Push the subject forward with stronger separation."
        }
    }

    func matches(_ settings: SmartFillSettings) -> Bool {
        if let presetName = settings.presetName?.trimmingCharacters(in: .whitespacesAndNewlines),
           !presetName.isEmpty {
            switch self {
            case .natural:
                return presetName.caseInsensitiveCompare("Subtle") == .orderedSame
            case .balanced:
                return presetName.caseInsensitiveCompare("Medium") == .orderedSame
            case .cinematic:
                return presetName.caseInsensitiveCompare("Dramatic") == .orderedSame
            }
        }

        let preset = preset
        return abs(settings.blurRadius - preset.blurRadius) < 0.1 &&
            abs(settings.darkenAmount - preset.darkenAmount) < 0.01 &&
            abs(settings.backgroundScale - preset.backgroundScale) < 0.1
    }
}

struct SmartFillWorkspaceFocusItem: Equatable, Identifiable {
    let title: String
    let value: String
    let symbolName: String

    var id: String { "\(title)|\(value)|\(symbolName)" }
}

struct SmartFillWorkspacePreviewCompareControl: Equatable, Identifiable {
    let title: String
    let value: String
    let symbolName: String
    let compareMode: SmartFillWorkspaceCompareViewerMode

    var id: String { "\(title)|\(value)|\(symbolName)|\(compareMode.title)" }
}

enum SmartFillWorkspacePreviewCompareGroupSelection: Equatable {
    case source
    case current
    case wipe
}

struct SmartFillWorkspacePreviewCompareGroupState: Equatable {
    let toolbarMode: SmartFillWorkspaceCompareViewerMode
    let viewerControl: SmartFillWorkspacePreviewCompareControl

    var selectedSegment: SmartFillWorkspacePreviewCompareGroupSelection {
        switch toolbarMode {
        case .source:
            return .source
        case .current:
            return .current
        case .wipe:
            return .wipe
        }
    }
}

struct SmartFillWorkspaceDrillInDescriptor: Equatable {
    let title: String
    let value: String
    let symbolName: String
    let sheet: SmartFillWorkspaceSheet
}

enum SmartFillWorkspacePreviewMode: String, CaseIterable {
    case result
    case source

    var shortTitle: String {
        switch self {
        case .result:
            return "Result"
        case .source:
            return "Original"
        }
    }

    var symbolName: String {
        switch self {
        case .result:
            return "sparkles.tv"
        case .source:
            return "rectangle.on.rectangle"
        }
    }

    var comparisonMode: SmartFillWorkspacePreviewMode {
        switch self {
        case .result:
            return .source
        case .source:
            return .result
        }
    }
}

struct SmartFillWorkspacePreviewCompareState: Equatable {
    let selectedMode: SmartFillWorkspacePreviewMode
    let isHoldingComparison: Bool
    let isPinnedWipeMode: Bool

    var effectiveMode: SmartFillWorkspacePreviewMode {
        if isPinnedWipeMode {
            return selectedMode
        }
        return isHoldingComparison ? selectedMode.comparisonMode : selectedMode
    }
}

struct SmartFillWorkspacePreviewPlaybackState: Equatable {
    var currentTime: Double = 0
    var shouldPlay = false

    func clamped(to duration: Double) -> SmartFillWorkspacePreviewPlaybackState {
        let safeDuration = max(duration, 0)
        let safeTime = currentTime.isFinite ? max(0, min(currentTime, safeDuration)) : 0
        return SmartFillWorkspacePreviewPlaybackState(currentTime: safeTime, shouldPlay: shouldPlay)
    }

    func shouldReplace(with other: SmartFillWorkspacePreviewPlaybackState, tolerance: Double = 0.12) -> Bool {
        abs(currentTime - other.currentTime) > tolerance || shouldPlay != other.shouldPlay
    }

    func requiresPlayerSync(currentTime: Double, isPlaying: Bool, tolerance: Double = 0.12) -> Bool {
        abs(self.currentTime - currentTime) > tolerance || shouldPlay != isPlaying
    }
}

struct SmartFillWorkspacePreviewCanvasScrubState: Equatable {
    static let minimumSeekSpan: Double = 3.0
    static let maximumSeekSpan: Double = 12.0
    static let durationMultiplier: Double = 0.35

    let anchorTime: Double
    let currentTime: Double
    let resumePlayback: Bool

    static func seekSpan(forDuration duration: Double) -> Double {
        guard duration.isFinite, duration > 0 else {
            return minimumSeekSpan
        }

        return min(
            max(duration * durationMultiplier, minimumSeekSpan),
            maximumSeekSpan
        )
    }

    static func targetTime(
        anchorTime: Double,
        translation: CGFloat,
        width: CGFloat,
        duration: Double
    ) -> Double {
        let safeDuration = max(duration, 0)
        let clampedAnchor = min(max(anchorTime, 0), safeDuration)
        guard width.isFinite, width > 0 else {
            return clampedAnchor
        }

        let progress = Double(translation / width)
        let proposed = clampedAnchor + (progress * seekSpan(forDuration: safeDuration))
        return min(max(proposed, 0), safeDuration)
    }

    static func begin(
        currentTime: Double,
        duration: Double,
        wasPlaying: Bool
    ) -> SmartFillWorkspacePreviewCanvasScrubState {
        let safeDuration = max(duration, 0)
        let clampedCurrentTime = min(max(currentTime, 0), safeDuration)
        return SmartFillWorkspacePreviewCanvasScrubState(
            anchorTime: clampedCurrentTime,
            currentTime: clampedCurrentTime,
            resumePlayback: wasPlaying
        )
    }

    func updated(
        translation: CGFloat,
        width: CGFloat,
        duration: Double
    ) -> SmartFillWorkspacePreviewCanvasScrubState {
        SmartFillWorkspacePreviewCanvasScrubState(
            anchorTime: anchorTime,
            currentTime: Self.targetTime(
                anchorTime: anchorTime,
                translation: translation,
                width: width,
                duration: duration
            ),
            resumePlayback: resumePlayback
        )
    }

    var playbackState: SmartFillWorkspacePreviewPlaybackState {
        SmartFillWorkspacePreviewPlaybackState(
            currentTime: currentTime,
            shouldPlay: false
        )
    }
}

struct SmartFillWorkspaceCompareWipeState: Equatable {
    static let defaultProgress: CGFloat = 0.5

    let progress: CGFloat

    static func clampedProgress(for locationX: CGFloat, width: CGFloat) -> CGFloat {
        guard width.isFinite, width > 0 else { return defaultProgress }
        let rawProgress = locationX / width
        guard rawProgress.isFinite else { return defaultProgress }
        return min(max(rawProgress, 0), 1)
    }

    static func begin(locationX: CGFloat? = nil, width: CGFloat) -> SmartFillWorkspaceCompareWipeState {
        let progress = locationX.map { clampedProgress(for: $0, width: width) } ?? defaultProgress
        return SmartFillWorkspaceCompareWipeState(progress: progress)
    }

    func updated(locationX: CGFloat, width: CGFloat) -> SmartFillWorkspaceCompareWipeState {
        SmartFillWorkspaceCompareWipeState(
            progress: Self.clampedProgress(for: locationX, width: width)
        )
    }
}

enum SmartFillWorkspaceCompareViewerMode: CaseIterable {
    case source
    case current
    case wipe

    var title: String {
        switch self {
        case .source:
            return "Source"
        case .current:
            return "Current"
        case .wipe:
            return "Wipe"
        }
    }

    var symbolName: String {
        switch self {
        case .source:
            return "film"
        case .current:
            return "sparkles.tv"
        case .wipe:
            return "rectangle.split.2x1"
        }
    }
}

struct SmartFillWorkspaceCompareViewerSelectionState: Equatable {
    var selectedMode: SmartFillWorkspacePreviewMode = .source
    var isPinnedWipeMode = false

    var toolbarMode: SmartFillWorkspaceCompareViewerMode {
        if isPinnedWipeMode {
            return .wipe
        }
        return selectedMode == .source ? .source : .current
    }

    mutating func selectToolbarMode(_ mode: SmartFillWorkspaceCompareViewerMode) {
        switch mode {
        case .source:
            selectedMode = .source
            isPinnedWipeMode = false
        case .current:
            selectedMode = .result
            isPinnedWipeMode = false
        case .wipe:
            isPinnedWipeMode = true
        }
    }
}

enum SmartFillWorkspaceTool: CaseIterable {
    case background
    case subject
    case output
    case save

    var shortTitle: String {
        switch self {
        case .background:
            return "Look"
        case .subject:
            return "Subject"
        case .output:
            return "Output"
        case .save:
            return "Save"
        }
    }

    var symbolName: String {
        switch self {
        case .background:
            return "camera.filters"
        case .subject:
            return "person.crop.rectangle"
        case .output:
            return "rectangle.compress.vertical"
        case .save:
            return "square.and.arrow.down"
        }
    }

    func summaryValue(for settings: SmartFillSettings, behavior: SmartFillWorkspaceCompletionBehavior) -> String {
        switch self {
        case .background:
            let presetName = settings.presetName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return presetName.isEmpty ? "Custom" : presetName
        case .subject:
            return String(format: "%.2f×", settings.foregroundScale)
        case .output:
            return "\(Int(settings.renderSize.width))×\(Int(settings.renderSize.height))"
        case .save:
            return behavior.pickerTitle
        }
    }

    func focusItems(
        settings: SmartFillSettings,
        completionBehavior: SmartFillWorkspaceCompletionBehavior,
        savedTakeName: String?
    ) -> [SmartFillWorkspaceFocusItem] {
        switch self {
        case .background:
            let finishTitle = SmartFillWorkspaceTreatmentPreset.allCases.first(where: { $0.matches(settings) })?.title ?? "Custom"
            let fillTitle = SmartFillWorkspaceBackgroundFillPreset.allCases.first(where: { $0.matches(settings.backgroundScale) })?.title ?? String(format: "%.1f×", settings.backgroundScale)
            return [
                SmartFillWorkspaceFocusItem(title: "Mode", value: SmartFillWorkspacePresentation.backgroundModeTitle(for: settings), symbolName: "camera.filters"),
                SmartFillWorkspaceFocusItem(title: "Finish", value: finishTitle, symbolName: "sparkles"),
                SmartFillWorkspaceFocusItem(title: "Fill", value: fillTitle, symbolName: "arrow.up.left.and.arrow.down.right")
            ]
        case .subject:
            let presetTitle = SmartFillWorkspaceSubjectPreset.allCases.first(where: { $0.matches(settings.foregroundScale) })?.title ?? "Custom"
            return [
                SmartFillWorkspaceFocusItem(title: "Preset", value: presetTitle, symbolName: "person.crop.rectangle"),
                SmartFillWorkspaceFocusItem(title: "Scale", value: String(format: "%.2f×", settings.foregroundScale), symbolName: "arrow.up.left.and.arrow.down.right.circle")
            ]
        case .output:
            return [
                SmartFillWorkspaceFocusItem(title: "Resolution", value: "\(Int(settings.renderSize.width))×\(Int(settings.renderSize.height))", symbolName: "rectangle.compress.vertical"),
                SmartFillWorkspaceFocusItem(title: "Speed", value: SmartFillWorkspacePresentation.processingPriorityTitle(for: settings.processingPriority), symbolName: "bolt.fill")
            ]
        case .save:
            return [
                SmartFillWorkspaceFocusItem(title: "After save", value: completionBehavior.summaryTitle, symbolName: "arrowshape.turn.up.forward"),
                SmartFillWorkspaceFocusItem(title: "Destination", value: savedTakeName ?? "Session SmartFill take", symbolName: "sparkles.rectangle.stack")
            ]
        }
    }

    func drillInDescriptor(
        settings: SmartFillSettings,
        completionBehavior: SmartFillWorkspaceCompletionBehavior,
        savedTakeName: String?,
        activeLookAdjustment: SmartFillWorkspaceLookAdjustment
    ) -> SmartFillWorkspaceDrillInDescriptor? {
        switch self {
        case .background:
            return SmartFillWorkspaceDrillInDescriptor(
                title: "Fine tune",
                value: activeLookAdjustment.valueLabel(for: settings),
                symbolName: "slider.horizontal.3",
                sheet: .lookAdjustments
            )
        case .subject:
            return SmartFillWorkspaceDrillInDescriptor(
                title: "Precision",
                value: String(format: "%.2f×", settings.foregroundScale),
                symbolName: "slider.horizontal.below.rectangle",
                sheet: .subjectScale
            )
        case .output:
            return SmartFillWorkspaceDrillInDescriptor(
                title: "Processing",
                value: SmartFillWorkspacePresentation.processingPriorityTitle(for: settings.processingPriority),
                symbolName: "bolt.fill",
                sheet: .outputOptions
            )
        case .save:
            return SmartFillWorkspaceDrillInDescriptor(
                title: "Details",
                value: savedTakeName ?? completionBehavior.summaryTitle,
                symbolName: "square.and.arrow.down.on.square",
                sheet: .savePlan
            )
        }
    }
}

enum SmartFillWorkspaceSheet: String, Identifiable {
    case backgroundFill
    case lookAdjustments
    case advancedLook
    case subjectScale
    case outputOptions
    case savePlan
    case sourcePreview

    var id: String { rawValue }
}

enum SmartFillWorkspaceLookAdjustment: CaseIterable {
    case blur
    case darken
    case fill

    var shortTitle: String {
        switch self {
        case .blur:
            return "Blur"
        case .darken:
            return "Darken"
        case .fill:
            return "Fill"
        }
    }

    var symbolName: String {
        switch self {
        case .blur:
            return "circle.dotted"
        case .darken:
            return "moon.fill"
        case .fill:
            return "arrow.up.left.and.arrow.down.right"
        }
    }

    func valueLabel(for settings: SmartFillSettings) -> String {
        switch self {
        case .blur:
            return "\(Int(settings.blurRadius)) px"
        case .darken:
            return "\(Int(settings.darkenAmount * 100))%"
        case .fill:
            return String(format: "%.1f×", settings.backgroundScale)
        }
    }
}

private enum SmartFillWorkspaceSubjectPreset: CaseIterable {
    case fit
    case balanced
    case close

    var scale: CGFloat {
        switch self {
        case .fit:
            return 0.90
        case .balanced:
            return 1.0
        case .close:
            return 1.10
        }
    }

    var title: String {
        switch self {
        case .fit:
            return "Fit"
        case .balanced:
            return "Balanced"
        case .close:
            return "Close"
        }
    }

    var valueLabel: String {
        String(format: "%.2f×", scale)
    }

    func matches(_ value: CGFloat) -> Bool {
        abs(value - scale) < 0.01
    }
}

private enum SmartFillWorkspaceBackgroundFillPreset: CaseIterable {
    case subtle
    case defaultFill
    case edgeToEdge

    var title: String {
        switch self {
        case .subtle:
            return "Subtle"
        case .defaultFill:
            return "Default"
        case .edgeToEdge:
            return "Edge-to-edge"
        }
    }

    var caption: String {
        switch self {
        case .subtle:
            return "Keeps more of the room visible."
        case .defaultFill:
            return "Best starting point for most takes."
        case .edgeToEdge:
            return "Push harder to hide empty side bars."
        }
    }

    var scale: CGFloat {
        switch self {
        case .subtle:
            return 5.0
        case .defaultFill:
            return 10.0
        case .edgeToEdge:
            return 15.0
        }
    }

    func matches(_ backgroundScale: CGFloat) -> Bool {
        abs(backgroundScale - scale) < 0.26
    }
}

private enum SmartFillWorkspaceTreatmentPreset: CaseIterable {
    case soft
    case balanced
    case bold

    var title: String {
        switch self {
        case .soft:
            return "Soft"
        case .balanced:
            return "Balanced"
        case .bold:
            return "Bold"
        }
    }

    var caption: String {
        switch self {
        case .soft:
            return "Lighter blur and darkening."
        case .balanced:
            return "Best for most takes."
        case .bold:
            return "Stronger separation and focus."
        }
    }

    var blurRadius: CGFloat {
        switch self {
        case .soft:
            return 16
        case .balanced:
            return 24
        case .bold:
            return 34
        }
    }

    var darkenAmount: CGFloat {
        switch self {
        case .soft:
            return 0.08
        case .balanced:
            return 0.14
        case .bold:
            return 0.22
        }
    }

    var presetName: String {
        switch self {
        case .soft:
            return "Subtle"
        case .balanced:
            return "Medium"
        case .bold:
            return "Dramatic"
        }
    }

    func matches(_ settings: SmartFillSettings) -> Bool {
        abs(settings.blurRadius - blurRadius) < 0.6 &&
        abs(settings.darkenAmount - darkenAmount) < 0.021
    }
}

enum SmartFillWorkspaceCompletionBehavior: CaseIterable {
    case returnAutomatically
    case stayHere

    static func defaultValue(for returnTarget: SmartFillReturnTarget) -> Self {
        switch returnTarget {
        case .editor:
            return .stayHere
        case .projectDetail, .takeReview, .swipeablePlayer, .standaloneWorkspace:
            return .returnAutomatically
        }
    }

    var pickerTitle: String {
        switch self {
        case .returnAutomatically:
            return "Return"
        case .stayHere:
            return "Stay"
        }
    }

    var summaryTitle: String {
        switch self {
        case .returnAutomatically:
            return "Return automatically"
        case .stayHere:
            return "Stay in workspace"
        }
    }

    func caption(for context: SmartFillSettingsContext) -> String {
        switch self {
        case .returnAutomatically:
            return "After SmartFill saves, it will head back to \(SmartFillWorkspacePresentation.returnTargetTitle(for: context).lowercased()) unless you cancel the auto-return."
        case .stayHere:
            return "After SmartFill saves, stay here to compare the preview before you decide when to return."
        }
    }
}

enum SmartFillWorkspacePresentation {
    static func headerTitle(for context: SmartFillSettingsContext) -> String {
        guard let infoTitle = context.infoTitle else { return "SmartFill Editor" }
        if infoTitle.localizedCaseInsensitiveContains("required") {
            return "SmartFill"
        }
        if infoTitle.localizedCaseInsensitiveContains("fine-tune") {
            return "SmartFill Editor"
        }
        return infoTitle
    }

    static func headerMessage(for context: SmartFillSettingsContext) -> String {
        context.infoMessage ?? "Open one take, shape the SmartFill look, then save the landscape version back into this session."
    }

    static func actionTitle(for context: SmartFillSettingsContext) -> String {
        actionTitle(for: context, stage: .configure)
    }

    static func actionTitle(
        for context: SmartFillSettingsContext,
        stage: SmartFillWorkspaceCoordinator.Stage,
        completionBehavior: SmartFillWorkspaceCompletionBehavior = .returnAutomatically,
        hasUnsavedChanges: Bool = false,
        adoptedTakeDisplayName: String? = nil
    ) -> String {
        switch stage {
        case .export:
            return "Saving SmartFill…"
        case .completed:
            if !hasUnsavedChanges {
                if let adoptedTakeDisplayName {
                    return "Open \(adoptedTakeDisplayName)"
                }
                return "Return to \(shortReturnTargetTitle(for: context))"
            }
            fallthrough
        default:
            let leadingVerb = context.take.isSmartFillVariant || context.existingSettings != nil ? "Update" : "Save"
            if completionBehavior == .stayHere {
                return "\(leadingVerb) and Stay Here"
            }
            return "\(leadingVerb) and Return to \(shortReturnTargetTitle(for: context))"
        }
    }

    static func destinationTitle(for context: SmartFillSettingsContext) -> String {
        context.take.isSmartFillVariant ? "Update current SmartFill take" : "Create or refresh SmartFill take"
    }

    static func saveLaneMessage(
        for context: SmartFillSettingsContext,
        adoptionMode: SmartFillResultAdoptionMode,
        completionBehavior: SmartFillWorkspaceCompletionBehavior = .returnAutomatically
    ) -> String {
        let outcome: String
        switch adoptionMode {
        case .updateExistingTakePath:
            outcome = "Updating SmartFill keeps the current landscape take in sync"
        case .createStandaloneVariantTake:
            outcome = "Saving SmartFill creates or refreshes the landscape take for this source clip"
        }

        if completionBehavior == .stayHere {
            return "\(outcome) and keeps SmartFill open so you can compare the preview before returning to \(returnTargetTitle(for: context).lowercased())."
        }

        return "\(outcome), then returns you to \(returnTargetTitle(for: context).lowercased())."
    }

    static func saveFootnote(
        for context: SmartFillSettingsContext,
        completionBehavior: SmartFillWorkspaceCompletionBehavior = .returnAutomatically
    ) -> String {
        if completionBehavior == .stayHere {
            return "After save, SmartFill stays in the workspace so you can compare the landscape result before returning to \(returnTargetTitle(for: context).lowercased())."
        }
        return "When processing completes, SmartFill returns to \(returnTargetTitle(for: context).lowercased()) with the landscape result still tied to “\(context.displayName)”."
    }

    static func processingMessage(
        for context: SmartFillSettingsContext,
        progress: Double? = nil,
        completionBehavior: SmartFillWorkspaceCompletionBehavior = .returnAutomatically
    ) -> String {
        guard let progress else {
            if completionBehavior == .stayHere {
                return "Saving SmartFill for “\(context.displayName)” and keeping the workspace open for comparison…"
            }
            return "Saving SmartFill for “\(context.displayName)” and preparing the return to \(returnTargetTitle(for: context).lowercased())…"
        }

        let percent = Int((min(max(progress, 0), 1) * 100).rounded())
        if completionBehavior == .stayHere {
            return "Saving SmartFill for “\(context.displayName)” (\(percent)%) and staying in the workspace for preview review…"
        }
        return "Saving SmartFill for “\(context.displayName)” (\(percent)%) before returning to \(returnTargetTitle(for: context).lowercased())…"
    }

    static func completionMessage(
        for context: SmartFillSettingsContext,
        adoptionMode: SmartFillResultAdoptionMode,
        completionBehavior: SmartFillWorkspaceCompletionBehavior = .returnAutomatically,
        adoptedTakeDisplayName: String? = nil
    ) -> String {
        if completionBehavior == .stayHere {
            switch adoptionMode {
            case .updateExistingTakePath:
                let resultTitle = adoptedTakeDisplayName ?? "SmartFill"
                return "Updated \(resultTitle). Staying here to compare the preview."
            case .createStandaloneVariantTake:
                let resultTitle = adoptedTakeDisplayName ?? "the SmartFill take"
                return "Saved \(resultTitle). Staying here to compare the preview."
            }
        }
        switch adoptionMode {
        case .updateExistingTakePath:
            let resultTitle = adoptedTakeDisplayName ?? "SmartFill"
            return "Updated \(resultTitle). Returning to \(returnTargetTitle(for: context))…"
        case .createStandaloneVariantTake:
            let resultTitle = adoptedTakeDisplayName ?? "the SmartFill take"
            return "Saved \(resultTitle). Returning to \(returnTargetTitle(for: context))…"
        }
    }

    static func deferredReturnMessage(
        for context: SmartFillSettingsContext,
        adoptionMode: SmartFillResultAdoptionMode?,
        completionBehavior: SmartFillWorkspaceCompletionBehavior = .returnAutomatically,
        adoptedTakeDisplayName: String? = nil
    ) -> String {
        let savedResultTitle = adoptedTakeDisplayName ?? "SmartFill"
        if completionBehavior == .stayHere {
            switch adoptionMode {
            case .updateExistingTakePath:
                return "\(savedResultTitle) is updated. Stay here to compare the preview, then open it in \(returnTargetTitle(for: context)) when you're ready."
            case .createStandaloneVariantTake:
                return "\(savedResultTitle) is saved. Stay here to compare the preview, then open it in \(returnTargetTitle(for: context)) when you're ready."
            case nil:
                return "\(savedResultTitle) is ready. Stay here to compare the preview, then open it in \(returnTargetTitle(for: context)) when you're ready."
            }
        }
        switch adoptionMode {
        case .updateExistingTakePath:
            return "\(savedResultTitle) is updated. Open it in \(returnTargetTitle(for: context)) when you're ready."
        case .createStandaloneVariantTake:
            return "\(savedResultTitle) is saved. Open it in \(returnTargetTitle(for: context)) when you're ready."
        case nil:
            return "\(savedResultTitle) is ready. Open it in \(returnTargetTitle(for: context)) when you're ready."
        }
    }

    static func stayComparisonMessage(
        for context: SmartFillSettingsContext,
        adoptionMode: SmartFillResultAdoptionMode,
        adoptedTakeDisplayName: String? = nil
    ) -> String {
        let takeTitle = adoptedTakeDisplayName ?? "The SmartFill take"
        switch adoptionMode {
        case .updateExistingTakePath:
            return "\(takeTitle) is updated and ready in this session. Compare the preview here, then open it in \(returnTargetTitle(for: context)) when you are ready."
        case .createStandaloneVariantTake:
            return "\(takeTitle) is saved into this session. Compare the preview here, then open it in \(returnTargetTitle(for: context)) when you are ready."
        }
    }

    static func returnControlMessage(
        for context: SmartFillSettingsContext,
        adoptionMode: SmartFillResultAdoptionMode,
        adoptedTakeDisplayName: String
    ) -> String {
        switch adoptionMode {
        case .updateExistingTakePath:
            return "\(adoptedTakeDisplayName) is updated and ready in this session. Stay here to compare the preview or use the primary action to open it in \(returnTargetTitle(for: context))."
        case .createStandaloneVariantTake:
            return "\(adoptedTakeDisplayName) is saved into this session. Stay here to compare the preview or use the primary action to open it in \(returnTargetTitle(for: context))."
        }
    }

    static func unsavedChangesMessage(
        for context: SmartFillSettingsContext,
        adoptionMode: SmartFillResultAdoptionMode?
    ) -> String {
        switch adoptionMode {
        case .updateExistingTakePath, .createStandaloneVariantTake, nil:
            return "Changes are not saved yet. Save SmartFill again before returning to \(returnTargetTitle(for: context))."
        }
    }

    static func destinationOutcomeTitle(for adoptionMode: SmartFillResultAdoptionMode) -> String {
        switch adoptionMode {
        case .updateExistingTakePath:
            return "Updated current SmartFill take"
        case .createStandaloneVariantTake:
            return "Created or refreshed SmartFill take"
        }
    }

    static func sourceClipOutcomeTitle() -> String {
        "Stays unchanged"
    }

    static func sourcePreviewTitle(for context: SmartFillSettingsContext) -> String {
        context.displayName
    }

    static func previewResultTitle(adoptedTakeDisplayName: String?) -> String {
        adoptedTakeDisplayName ?? "Live SmartFill"
    }

    static func compareViewerMessage(
        for context: SmartFillSettingsContext,
        adoptedTakeDisplayName: String? = nil
    ) -> String {
        let resultTitle = previewResultTitle(adoptedTakeDisplayName: adoptedTakeDisplayName)
        return "Inspect the untouched source clip for “\(context.displayName)” and \(resultTitle) in a larger compare viewer at the same playhead."
    }

    static func sourcePreviewMessage(
        for context: SmartFillSettingsContext,
        adoptedTakeDisplayName: String? = nil,
        previewMode: SmartFillWorkspacePreviewMode = .result
    ) -> String {
        let resultTitle = previewResultTitle(adoptedTakeDisplayName: adoptedTakeDisplayName)
        if previewMode == .source {
            return "Open the untouched source clip for “\(context.displayName)” in a larger viewer while the main editor stays on the original comparison state."
        }
        return "Scrub the untouched source clip for “\(context.displayName)” here while the main editor keeps showing \(resultTitle)."
    }

    static func afterSaveOutcomeTitle(
        for context: SmartFillSettingsContext,
        stage: SmartFillWorkspaceCoordinator.Stage,
        completionBehavior: SmartFillWorkspaceCompletionBehavior,
        hasPendingAutoReturn: Bool,
        hasUnsavedChanges: Bool,
        adoptedTakeDisplayName: String? = nil
    ) -> String {
        if stage == .export {
            if completionBehavior == .stayHere {
                return "Stay here after save"
            }
            return "Return to \(shortReturnTargetTitle(for: context)) after save"
        }
        if hasPendingAutoReturn {
            if let adoptedTakeDisplayName {
                return "Auto-returning to \(adoptedTakeDisplayName)"
            }
            return "Auto-returning to \(shortReturnTargetTitle(for: context))"
        }
        if stage == .completed && !hasUnsavedChanges {
            if completionBehavior == .stayHere {
                return "Stay here after save"
            }
            if let adoptedTakeDisplayName {
                return "Open \(adoptedTakeDisplayName)"
            }
            return "Return to \(shortReturnTargetTitle(for: context)) when ready"
        }
        if completionBehavior == .stayHere {
            return "Stay here after save"
        }
        return "Return to \(shortReturnTargetTitle(for: context)) after save"
    }

    static func saveOutcomeMessage(
        for context: SmartFillSettingsContext,
        adoptionMode: SmartFillResultAdoptionMode,
        stage: SmartFillWorkspaceCoordinator.Stage,
        completionBehavior: SmartFillWorkspaceCompletionBehavior,
        hasPendingAutoReturn: Bool,
        hasUnsavedChanges: Bool,
        adoptedTakeDisplayName: String? = nil
    ) -> String {
        let destination = sentenceDestinationOutcomeTitle(for: adoptionMode)
        let returnTarget = returnTargetTitle(for: context)

        if hasUnsavedChanges {
            return "The last saved SmartFill result is still available, but these newer changes are not saved yet. Save again before returning to \(returnTarget)."
        }
        if stage == .export {
            if completionBehavior == .stayHere {
                return "SmartFill is saving now. The source clip stays untouched while the session \(destination), and the workspace will stay open so you can compare the preview when save finishes."
            }
            return "SmartFill is saving now. The source clip stays untouched while the session \(destination) before returning to \(returnTarget.lowercased())."
        }
        if hasPendingAutoReturn {
            if let adoptedTakeDisplayName {
                return "Save finished. \(adoptedTakeDisplayName) is ready in \(returnTarget.lowercased()), and SmartFill will return there unless you stay here to compare the preview."
            }
            return "Save finished. The session \(destination), and SmartFill will return to \(returnTarget.lowercased()) unless you stay here to compare the preview."
        }
        if stage == .completed {
            if completionBehavior == .stayHere {
                if let adoptedTakeDisplayName {
                    return "Save finished. \(adoptedTakeDisplayName) is ready in \(returnTarget). SmartFill will stay here so you can compare the preview before opening it."
                }
                return "Save finished. The session \(destination), and SmartFill will stay here so you can compare the preview before returning to \(returnTarget)."
            }
            if let adoptedTakeDisplayName {
                return "Save finished. \(adoptedTakeDisplayName) is ready in \(returnTarget). Open it when you're ready."
            }
            return "Save finished. The session \(destination). Return to \(returnTarget) when you're ready."
        }
        if completionBehavior == .stayHere {
            return "Saving keeps the source clip untouched while the session \(destination), and SmartFill will stay here so you can compare the preview before returning to \(returnTarget)."
        }
        return "Saving keeps the source clip untouched while the session \(destination), then returns you to \(returnTarget.lowercased())."
    }

    private static func sentenceDestinationOutcomeTitle(for adoptionMode: SmartFillResultAdoptionMode) -> String {
        switch adoptionMode {
        case .updateExistingTakePath:
            return "updated current SmartFill take"
        case .createStandaloneVariantTake:
            return "created or refreshed SmartFill take"
        }
    }

    static func returnTargetTitle(for context: SmartFillSettingsContext) -> String {
        switch context.returnTarget {
        case .projectDetail:
            return "Project detail"
        case .takeReview:
            return "Session review"
        case .swipeablePlayer:
            return "Player review"
        case .editor:
            return "Editor"
        case .standaloneWorkspace:
            return "Standalone workspace"
        }
    }

    static func shortReturnTargetTitle(for context: SmartFillSettingsContext) -> String {
        switch context.returnTarget {
        case .projectDetail:
            return "Project"
        case .takeReview:
            return "Review"
        case .swipeablePlayer:
            return "Player"
        case .editor:
            return "Editor"
        case .standaloneWorkspace:
            return "Workspace"
        }
    }

    static func framingCaption(for settings: SmartFillSettings) -> String {
        switch settings.foregroundScale {
        case ..<0.95:
            return "Show more breathing room around the subject."
        case 0.95...1.08:
            return "Keep the subject close to the original framing."
        default:
            return "Push the subject forward for a tighter, more dramatic frame."
        }
    }

    static func outputCaption(for settings: SmartFillSettings) -> String {
        let size = "\(Int(settings.renderSize.width))×\(Int(settings.renderSize.height))"
        return "\(size) output with \(processingPriorityTitle(for: settings.processingPriority).lowercased()) processing."
    }

    static func backgroundModeTitle(for settings: SmartFillSettings) -> String {
        if let mode = SmartFillWorkspaceBackgroundMode.allCases.first(where: { $0.matches(settings) }) {
            return mode.title
        }
        return "Custom"
    }

    static func processingPriorityTitle(for priority: SmartFillSettings.ProcessingPriority) -> String {
        switch priority {
        case .background:
            return "Batch"
        case .userInitiated:
            return "Normal"
        case .high:
            return "Fast"
        }
    }

    static func processingPriorityCaption(for priority: SmartFillSettings.ProcessingPriority) -> String {
        switch priority {
        case .background:
            return "Use the most patient queue when speed is not important."
        case .userInitiated:
            return "Balanced processing for most SmartFill passes."
        case .high:
            return "Prioritize this pass when you need the result quickly."
        }
    }
}

private struct SmartFillWorkspaceResultPreviewRequest: Equatable {
    let videoURL: URL
    let settings: SmartFillSettings
    let refreshID: String
}

private struct SmartFillWorkspaceResultPreviewView: View {
    let videoURL: URL
    let settings: SmartFillSettings
    let refreshID: String
    let playbackState: SmartFillWorkspacePreviewPlaybackState
    let shouldRender: Bool
    let allowPlayback: Bool
    let shouldPublishPlaybackState: Bool
    let allowsCanvasScrub: Bool
    let allowsHoldCompare: Bool
    let onComparePressingChanged: (Bool) -> Void
    let onPlaybackStateChange: (SmartFillWorkspacePreviewPlaybackState) -> Void
    let onError: (Error) -> Void

    @State private var player: ModernSmartFillPlayer?
    @State private var loadedRequest: SmartFillWorkspaceResultPreviewRequest?
    @State private var loadTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 8) {
            if let player {
                SmartFillWorkspaceInteractivePreviewSurface(
                    player: player,
                    allowsCanvasScrub: allowsCanvasScrub,
                    allowsHoldCompare: allowsHoldCompare,
                    onComparePressingChanged: onComparePressingChanged,
                    onPlaybackStateChange: onPlaybackStateChange
                )
                .onReceive(player.$currentTime) { _ in
                    publishPlaybackState()
                }
                .onReceive(player.$isPlaying) { _ in
                    publishPlaybackState()
                }
                .onReceive(player.$isReady) { isReady in
                    guard isReady else { return }
                    applyPlaybackState(playbackState, to: player, allowPlayback: allowPlayback, force: true)
                }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 220)
            }
        }
        .onAppear {
            preparePlayer(forceReload: false)
        }
        .onDisappear {
            loadTask?.cancel()
            player?.pause()
        }
        .onChange(of: shouldRender) { _, shouldRender in
            if shouldRender {
                preparePlayer(forceReload: false)
            } else {
                player?.pause()
            }
        }
        .onChange(of: allowPlayback) { _, allowPlayback in
            guard let player else { return }
            applyPlaybackState(playbackState, to: player, allowPlayback: allowPlayback, force: true)
        }
        .onChange(of: videoURL) { _, _ in
            preparePlayer(forceReload: true)
        }
        .onChange(of: settings) { _, _ in
            preparePlayer(forceReload: true)
        }
        .onChange(of: refreshID) { _, _ in
            preparePlayer(forceReload: true)
        }
        .onChange(of: playbackState) { _, playbackState in
            guard let player else { return }
            applyPlaybackState(playbackState, to: player, allowPlayback: allowPlayback)
        }
    }

    private func preparePlayer(forceReload: Bool) {
        let request = SmartFillWorkspaceResultPreviewRequest(
            videoURL: videoURL,
            settings: settings,
            refreshID: refreshID
        )

        guard shouldRender else { return }
        guard forceReload || loadedRequest != request || player == nil else {
            if let player {
                applyPlaybackState(playbackState, to: player, allowPlayback: allowPlayback, force: true)
            }
            return
        }

        loadedRequest = request
        loadTask?.cancel()
        player?.pause()
        player = nil

        loadTask = Task { @MainActor in
            do {
                let freshPlayer = try await SmartFillManager.shared.createPreviewPlayer(
                    for: videoURL,
                    settings: settings
                )
                guard !Task.isCancelled else { return }

                player = freshPlayer
                applyPlaybackState(playbackState, to: freshPlayer, allowPlayback: allowPlayback, force: true)
                publishPlaybackState()
            } catch {
                guard !Task.isCancelled else { return }
                onError(error)
            }
        }
    }

    private func publishPlaybackState() {
        guard shouldPublishPlaybackState, let player else { return }
        onPlaybackStateChange(
            SmartFillWorkspacePreviewPlaybackState(
                currentTime: max(player.currentTime, 0),
                shouldPlay: player.isPlaying
            )
        )
    }
}

private struct SmartFillSourcePreviewView: View {
    let videoURL: URL
    let playbackState: SmartFillWorkspacePreviewPlaybackState
    let shouldRender: Bool
    let allowPlayback: Bool
    let shouldPublishPlaybackState: Bool
    let allowsCanvasScrub: Bool
    let allowsHoldCompare: Bool
    let onComparePressingChanged: (Bool) -> Void
    let onPlaybackStateChange: (SmartFillWorkspacePreviewPlaybackState) -> Void

    @State private var player: ModernSmartFillPlayer?
    @State private var loadedURL: URL?

    var body: some View {
        VStack(spacing: 8) {
            if let player {
                SmartFillWorkspaceInteractivePreviewSurface(
                    player: player,
                    allowsCanvasScrub: allowsCanvasScrub,
                    allowsHoldCompare: allowsHoldCompare,
                    onComparePressingChanged: onComparePressingChanged,
                    onPlaybackStateChange: onPlaybackStateChange
                )
                .onReceive(player.$currentTime) { _ in
                    publishPlaybackState()
                }
                .onReceive(player.$isPlaying) { _ in
                    publishPlaybackState()
                }
                .onReceive(player.$isReady) { isReady in
                    guard isReady else { return }
                    applyPlaybackState(playbackState, to: player, allowPlayback: allowPlayback, force: true)
                }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 220)
            }
        }
        .onAppear {
            if shouldRender {
                preparePlayer(forceReload: false)
            }
        }
        .onDisappear {
            player?.pause()
        }
        .onChange(of: shouldRender) { _, shouldRender in
            if shouldRender {
                preparePlayer(forceReload: false)
            } else {
                player?.pause()
            }
        }
        .onChange(of: allowPlayback) { _, allowPlayback in
            guard let player else { return }
            applyPlaybackState(playbackState, to: player, allowPlayback: allowPlayback, force: true)
        }

        .onChange(of: videoURL) { _, _ in
            preparePlayer(forceReload: true)
        }
        .onChange(of: playbackState) { _, playbackState in
            guard let player else { return }
            applyPlaybackState(playbackState, to: player, allowPlayback: allowPlayback)
        }
    }

    private func preparePlayer(forceReload: Bool) {
        guard shouldRender else { return }
        guard forceReload || loadedURL != videoURL || player == nil else {
            if let player {
                applyPlaybackState(playbackState, to: player, allowPlayback: allowPlayback, force: true)
            }
            return
        }

        loadedURL = videoURL
        let item = AVPlayerItem(url: videoURL)
        let freshPlayer = ModernSmartFillPlayer(playerItem: item)
        freshPlayer.player.actionAtItemEnd = .pause
        player = freshPlayer
        applyPlaybackState(playbackState, to: freshPlayer, allowPlayback: allowPlayback, force: true)
    }

    private func publishPlaybackState() {
        guard shouldPublishPlaybackState, let player else { return }
        onPlaybackStateChange(
            SmartFillWorkspacePreviewPlaybackState(
                currentTime: max(player.currentTime, 0),
                shouldPlay: player.isPlaying
            )
        )
    }
}

private struct SmartFillWorkspaceCompareViewer: View {
    let videoURL: URL
    let settings: SmartFillSettings
    let refreshID: String
    let playbackState: SmartFillWorkspacePreviewPlaybackState
    @Binding var selectionState: SmartFillWorkspaceCompareViewerSelectionState
    @Binding var pinnedWipeProgress: CGFloat
    let sourceTitle: String
    let resultTitle: String
    let previewErrorMessage: String?
    let onPlaybackStateChange: (SmartFillWorkspacePreviewPlaybackState) -> Void
    let onError: (Error) -> Void

    @State private var isHoldingComparison = false
    @State private var temporaryWipeState: SmartFillWorkspaceCompareWipeState?

    init(
        videoURL: URL,
        settings: SmartFillSettings,
        refreshID: String,
        playbackState: SmartFillWorkspacePreviewPlaybackState,
        selectionState: Binding<SmartFillWorkspaceCompareViewerSelectionState>,
        pinnedWipeProgress: Binding<CGFloat>,
        sourceTitle: String,
        resultTitle: String,
        previewErrorMessage: String?,
        onPlaybackStateChange: @escaping (SmartFillWorkspacePreviewPlaybackState) -> Void,
        onError: @escaping (Error) -> Void
    ) {
        self.videoURL = videoURL
        self.settings = settings
        self.refreshID = refreshID
        self.playbackState = playbackState
        self._selectionState = selectionState
        self._pinnedWipeProgress = pinnedWipeProgress
        self.sourceTitle = sourceTitle
        self.resultTitle = resultTitle
        self.previewErrorMessage = previewErrorMessage
        self.onPlaybackStateChange = onPlaybackStateChange
        self.onError = onError
    }

    private var compareState: SmartFillWorkspacePreviewCompareState {
        SmartFillWorkspacePreviewCompareState(
            selectedMode: selectionState.selectedMode,
            isHoldingComparison: isHoldingComparison,
            isPinnedWipeMode: selectionState.isPinnedWipeMode
        )
    }

    private var effectiveMode: SmartFillWorkspacePreviewMode {
        compareState.effectiveMode
    }

    private var activeWipeState: SmartFillWorkspaceCompareWipeState? {
        if let temporaryWipeState {
            return temporaryWipeState
        }
        if selectionState.isPinnedWipeMode {
            return SmartFillWorkspaceCompareWipeState(progress: pinnedWipeProgress)
        }
        return nil
    }

    private var isShowingWipeCompare: Bool {
        activeWipeState != nil
    }

    private var toolbarMode: SmartFillWorkspaceCompareViewerMode {
        selectionState.toolbarMode
    }

    private var comparePlaybackState: SmartFillWorkspacePreviewPlaybackState {
        if isShowingWipeCompare {
            return SmartFillWorkspacePreviewPlaybackState(
                currentTime: playbackState.currentTime.isFinite ? max(playbackState.currentTime, 0) : 0,
                shouldPlay: false
            )
        }
        return playbackState
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    compareToolbar
                    Spacer(minLength: 0)
                    compareReferencePill(
                        title: compareModeSummaryTitle,
                        value: compareModeSummaryValue,
                        symbolName: compareModeSummarySymbolName,
                        isSelected: true
                    )
                }

                HStack(spacing: 8) {
                    compareReferencePill(
                        title: "Source",
                        value: sourceTitle,
                        symbolName: "film",
                        isSelected: toolbarMode == .source
                    )
                    compareReferencePill(
                        title: "Current",
                        value: resultTitle,
                        symbolName: "sparkles.tv",
                        isSelected: toolbarMode == .current
                    )
                }
            }

            GeometryReader { geometry in
                compareViewerSurface(width: geometry.size.width)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 360)

            if let previewErrorMessage, effectiveMode == .result {
                Label(previewErrorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
    }

    private var compareToolbar: some View {
        HStack(spacing: 6) {
            ForEach(SmartFillWorkspaceCompareViewerMode.allCases, id: \.self) { mode in
                compareModeButton(mode)
            }
        }
        .padding(4)
        .background(Color.white.opacity(0.05), in: Capsule())
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func compareViewerSurface(width: CGFloat) -> some View {
        if selectionState.isPinnedWipeMode {
            baseCompareSurface(width: width)
                .highPriorityGesture(pinnedWipeGesture(width: width))
        } else {
            baseCompareSurface(width: width)
                .highPriorityGesture(temporaryWipeGesture(width: width))
        }
    }

    private func baseCompareSurface(width: CGFloat) -> some View {
        ZStack {
            SmartFillWorkspaceResultPreviewView(
                videoURL: videoURL,
                settings: settings,
                refreshID: refreshID,
                playbackState: comparePlaybackState,
                shouldRender: isShowingWipeCompare || effectiveMode == .result,
                allowPlayback: isShowingWipeCompare || effectiveMode == .result,
                shouldPublishPlaybackState: true,
                allowsCanvasScrub: !isShowingWipeCompare,
                allowsHoldCompare: !isShowingWipeCompare,
                onComparePressingChanged: updateComparePressing,
                onPlaybackStateChange: onPlaybackStateChange,
                onError: onError
            )
            .opacity(isShowingWipeCompare || effectiveMode == .result ? 1 : 0)
            .allowsHitTesting(!isShowingWipeCompare && effectiveMode == .result)

            SmartFillSourcePreviewView(
                videoURL: videoURL,
                playbackState: comparePlaybackState,
                shouldRender: isShowingWipeCompare || effectiveMode == .source,
                allowPlayback: isShowingWipeCompare || effectiveMode == .source,
                shouldPublishPlaybackState: true,
                allowsCanvasScrub: !isShowingWipeCompare,
                allowsHoldCompare: !isShowingWipeCompare,
                onComparePressingChanged: updateComparePressing,
                onPlaybackStateChange: onPlaybackStateChange
            )
            .opacity(isShowingWipeCompare ? 1 : (effectiveMode == .source ? 1 : 0))
            .allowsHitTesting(!isShowingWipeCompare && effectiveMode == .source)
            .mask(alignment: .leading) {
                if let activeWipeState {
                    Rectangle()
                        .frame(width: width * activeWipeState.progress)
                } else {
                    Rectangle()
                }
            }

            if let activeWipeState {
                sharedSplitWipeOverlay(
                    for: activeWipeState,
                    width: width
                )
            }
        }
        .contentShape(Rectangle())
    }

    private func compareModeButton(
        _ mode: SmartFillWorkspaceCompareViewerMode
    ) -> some View {
        let isSelected = toolbarMode == mode

        return Button {
            selectionState.selectToolbarMode(mode)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: mode.symbolName)
                    .font(.caption2.weight(.semibold))
                Text(mode.title)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
            }
            .foregroundStyle(isSelected ? SmartFillWorkspacePalette.textPrimary : .secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                isSelected ? SmartFillWorkspacePalette.accent.opacity(0.14) : Color.clear,
                in: Capsule()
            )
        }
        .buttonStyle(.plain)
    }

    private func compareReferencePill(
        title: String,
        value: String,
        symbolName: String,
        isSelected: Bool = false
    ) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbolName)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(isSelected ? SmartFillWorkspacePalette.accent : .secondary)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(SmartFillWorkspacePalette.textPrimary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            isSelected ? SmartFillWorkspacePalette.accent.opacity(0.14) : Color.white.opacity(0.04),
            in: Capsule()
        )
        .overlay(
            Capsule()
                .stroke(
                    isSelected ? SmartFillWorkspacePalette.accent.opacity(0.4) : Color.white.opacity(0.08),
                    lineWidth: 1
                )
        )
    }

    private var compareModeSummaryTitle: String {
        switch toolbarMode {
        case .source:
            return "Viewing"
        case .current:
            return "Viewing"
        case .wipe:
            return "Mode"
        }
    }

    private var compareModeSummaryValue: String {
        switch toolbarMode {
        case .source:
            return sourceTitle
        case .current:
            return resultTitle
        case .wipe:
            return "Wipe compare"
        }
    }

    private var compareModeSummarySymbolName: String {
        switch toolbarMode {
        case .source:
            return "film"
        case .current:
            return "sparkles.tv"
        case .wipe:
            return "rectangle.lefthalf.filled"
        }
    }

    private func temporaryWipeGesture(width: CGFloat) -> some Gesture {
        LongPressGesture(minimumDuration: 0.12, maximumDistance: 40)
            .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .local))
            .onChanged { value in
                switch value {
                case .first(true):
                    if temporaryWipeState == nil {
                        temporaryWipeState = SmartFillWorkspaceCompareWipeState.begin(width: width)
                    }
                case .second(true, let drag?):
                    let baseState = temporaryWipeState ?? SmartFillWorkspaceCompareWipeState.begin(
                        locationX: drag.location.x,
                        width: width
                    )
                    temporaryWipeState = baseState.updated(
                        locationX: drag.location.x,
                        width: width
                    )
                default:
                    break
                }
            }
            .onEnded { _ in
                temporaryWipeState = nil
            }
    }

    private func pinnedWipeGesture(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { value in
                pinnedWipeProgress = SmartFillWorkspaceCompareWipeState.clampedProgress(
                    for: value.location.x,
                    width: width
                )
            }
    }

    private func updateComparePressing(_ isPressing: Bool) {
        isHoldingComparison = isPressing
    }

    private func sharedSplitWipeOverlay(
        for wipeState: SmartFillWorkspaceCompareWipeState,
        width: CGFloat
    ) -> some View {
        let clampedX = min(max(width * wipeState.progress, 0), width)

        return ZStack {
            Rectangle()
                .fill(.white.opacity(0.92))
                .frame(width: 2)
                .shadow(color: .black.opacity(0.22), radius: 5, x: 0, y: 0)
                .frame(maxHeight: .infinity)
                .offset(x: clampedX - (width / 2))

            VStack {
                HStack {
                    compareEdgeBadge(title: "Source", alignment: .leading)
                    Spacer()
                    compareEdgeBadge(title: "Current", alignment: .trailing)
                }
                Spacer()
            }
            .padding(12)
        }
        .allowsHitTesting(false)
    }

    private func compareEdgeBadge(
        title: String,
        alignment: Alignment
    ) -> some View {
        Text(title)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color.black.opacity(0.62), in: Capsule())
            .frame(maxWidth: .infinity, alignment: alignment)
    }
}

private struct SmartFillWorkspaceInteractivePreviewSurface: View {
    @ObservedObject var player: ModernSmartFillPlayer
    let allowsCanvasScrub: Bool
    let allowsHoldCompare: Bool
    let onComparePressingChanged: (Bool) -> Void
    let onPlaybackStateChange: (SmartFillWorkspacePreviewPlaybackState) -> Void

    @State private var canvasScrubState: SmartFillWorkspacePreviewCanvasScrubState?

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                interactiveVideoSurface(width: geometry.size.width)

                if let canvasScrubState {
                    canvasScrubHUD(for: canvasScrubState)
                        .padding(.top, 16)
                        .frame(maxHeight: .infinity, alignment: .top)
                }

                if player.isReady && !player.isPlaying && canvasScrubState == nil {
                    Button(action: togglePlayback) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(18)
                            .background(Color.black.opacity(0.52), in: Circle())
                    }
                    .buttonStyle(.plain)
                }

                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        ModernSmartFillPreviewControls(player: player)
                            .frame(maxWidth: 440)
                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 14)
                }
            }
        }
        .aspectRatio(16 / 9, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .background(Color.black, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    @ViewBuilder
    private func interactiveVideoSurface(width: CGFloat) -> some View {
        let surface = SmartFillWorkspaceVideoSurface(player: player.player)
            .contentShape(Rectangle())
            .onTapGesture {
                togglePlayback()
            }
            .onLongPressGesture(minimumDuration: 0.12, maximumDistance: 30, perform: { }) { isPressing in
                guard allowsHoldCompare else { return }
                onComparePressingChanged(isPressing)
            }

        if allowsCanvasScrub {
            surface.highPriorityGesture(canvasScrubGesture(width: width))
        } else {
            surface
        }
    }

    private func togglePlayback() {
        if player.isPlaying {
            player.pause()
        } else {
            player.play()
        }
    }

    private func canvasScrubGesture(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                updateCanvasScrub(
                    translation: value.translation.width,
                    width: width
                )
            }
            .onEnded { value in
                finishCanvasScrub(
                    translation: value.translation.width,
                    width: width
                )
            }
    }

    private func updateCanvasScrub(translation: CGFloat, width: CGFloat) {
        let baseState = canvasScrubState ?? beginCanvasScrub()
        let updatedState = baseState.updated(
            translation: translation,
            width: width,
            duration: player.duration
        )

        if updatedState.currentTime != canvasScrubState?.currentTime {
            player.seek(to: CMTime(seconds: updatedState.currentTime, preferredTimescale: 600))
            onPlaybackStateChange(updatedState.playbackState)
        }

        canvasScrubState = updatedState
    }

    private func finishCanvasScrub(translation: CGFloat, width: CGFloat) {
        guard let baseState = canvasScrubState else { return }
        let finalState = baseState.updated(
            translation: translation,
            width: width,
            duration: player.duration
        )

        player.seek(to: CMTime(seconds: finalState.currentTime, preferredTimescale: 600))
        onPlaybackStateChange(
            SmartFillWorkspacePreviewPlaybackState(
                currentTime: finalState.currentTime,
                shouldPlay: finalState.resumePlayback
            )
        )

        if finalState.resumePlayback {
            player.play()
        } else {
            player.pause()
        }

        canvasScrubState = nil
    }

    private func beginCanvasScrub() -> SmartFillWorkspacePreviewCanvasScrubState {
        let state = SmartFillWorkspacePreviewCanvasScrubState.begin(
            currentTime: player.currentTime,
            duration: player.duration,
            wasPlaying: player.isPlaying
        )

        if player.isPlaying {
            player.pause()
        }

        onPlaybackStateChange(state.playbackState)
        canvasScrubState = state
        return state
    }

    private func canvasScrubHUD(
        for state: SmartFillWorkspacePreviewCanvasScrubState
    ) -> some View {
        VStack(spacing: 4) {
            Text("Scrub Preview")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.75))

            Text(formatPreviewTime(state.currentTime))
                .font(.callout.weight(.semibold).monospacedDigit())
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.62), in: Capsule())
    }

    private func formatPreviewTime(_ seconds: Double) -> String {
        guard seconds.isFinite && seconds >= 0 else { return "0:00" }
        let minutes = Int(seconds) / 60
        let remainingSeconds = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
}

private struct SmartFillWorkspaceVideoSurface: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .black

        let playerLayer = AVPlayerLayer(player: player)
        playerLayer.videoGravity = .resizeAspect
        view.layer.addSublayer(playerLayer)

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        if let playerLayer = uiView.layer.sublayers?.first as? AVPlayerLayer {
            playerLayer.player = player
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            playerLayer.frame = uiView.bounds
            CATransaction.commit()
        }
    }
}

@MainActor
private func applyPlaybackState(
    _ playbackState: SmartFillWorkspacePreviewPlaybackState,
    to player: ModernSmartFillPlayer,
    allowPlayback: Bool,
    force: Bool = false
) {
    let normalizedState = playbackState.clamped(to: player.duration)

    if force || normalizedState.requiresPlayerSync(currentTime: player.currentTime, isPlaying: allowPlayback ? player.isPlaying : false) {
        player.seek(to: CMTime(seconds: normalizedState.currentTime, preferredTimescale: 600))
    }

    if allowPlayback && normalizedState.shouldPlay {
        if !player.isPlaying || force {
            player.play()
        }
    } else if player.isPlaying || force {
        player.pause()
    }
}
