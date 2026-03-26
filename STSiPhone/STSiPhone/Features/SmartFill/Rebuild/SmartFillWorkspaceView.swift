import SwiftUI

struct SmartFillWorkspaceView: View {
    let context: SmartFillSettingsContext
    let onQueueSmartFill: (SmartFillSettings) -> Void
    let onCancel: () -> Void

    @Environment(\.dismiss) private var dismiss
    @StateObject private var coordinator = SmartFillWorkspaceCoordinator()
    @State private var settings: SmartFillSettings
    @State private var showAdvancedSettings = false
    @State private var statusMessage: String?
    @State private var previewErrorMessage: String?
    @State private var queueAttempted = false
    @State private var autoReturnWorkItem: DispatchWorkItem?
    @State private var processingProgress: Double = 0
    @State private var completionBehavior: SmartFillWorkspaceCompletionBehavior

    private let workspaceDefaults: SmartFillWorkspaceDefaults

    init(
        context: SmartFillSettingsContext,
        onQueueSmartFill: @escaping (SmartFillSettings) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.context = context
        self.onQueueSmartFill = onQueueSmartFill
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
                BrandBackground()
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        previewSurface
                        lookSurface
                        framingSurface
                        outputSurface
                        saveSurface
                    }
                    .padding(.horizontal, Theme.Layout.screenPadding)
                    .padding(.top, 20)
                    .padding(.bottom, 120)
                }
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
            .safeAreaInset(edge: .bottom) {
                actionBar
            }
            .sheet(isPresented: $showAdvancedSettings) {
                SmartFillAdvancedSettingsView(
                    blurRadius: blurRadiusBinding,
                    darkenAmount: darkenAmountBinding,
                    backgroundScale: backgroundScaleBinding
                )
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
                        .font(.title2.weight(.bold))
                        .foregroundStyle(Theme.textPrimary)

                    Text(SmartFillWorkspacePresentation.headerMessage(for: context))
                        .font(.subheadline)
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

            Group {
                SmartFillPreviewPlayer(
                    videoURL: context.previewURL,
                    settings: settings,
                    refreshID: settings.forceUpdateToken
                ) { error in
                    previewErrorMessage = error.localizedDescription
                }
                .frame(maxWidth: .infinity)
                .aspectRatio(16.0 / 9.0, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .overlay(alignment: .bottomLeading) {
                Label(fileNameLabel, systemImage: "video.fill")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white.opacity(0.92))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.black.opacity(0.45), in: Capsule())
                    .padding(14)
            }

            if let previewErrorMessage {
                Label(previewErrorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .padding(18)
        .background(panelBackground)
    }

    private var lookSurface: some View {
            VStack(alignment: .leading, spacing: 16) {
                Text("Background look")
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)

            Text("Pick a starting treatment, then fine-tune blur and background presence if this take needs more separation.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                ForEach(SmartFillWorkspaceBackgroundMode.allCases, id: \.self) { mode in
                    Button {
                        applyBackgroundMode(mode)
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(mode.title)
                                .font(.subheadline.weight(.semibold))
                            Text(mode.caption)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(backgroundModeBackground(for: mode), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(backgroundModeStroke(for: mode), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            summaryRow(
                icon: "wand.and.rays",
                title: "Current mode",
                value: SmartFillWorkspacePresentation.backgroundModeTitle(for: settings)
            )

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Treatment finish")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Spacer()
                    Text(activeTreatmentPreset?.title ?? "Custom")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 12) {
                    ForEach(SmartFillWorkspaceTreatmentPreset.allCases, id: \.self) { preset in
                        Button {
                            applyTreatmentPreset(preset)
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(preset.title)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Theme.textPrimary)
                                Text(preset.caption)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                            .background(treatmentPresetBackground(for: preset), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(treatmentPresetStroke(for: preset), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                Text("Use treatment finish to decide how soft or dramatic the background feels before you fine-tune blur and darkening.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            treatmentSlider(
                icon: "circle.dotted",
                title: "Blur radius",
                valueLabel: "\(Int(settings.blurRadius)) px",
                caption: blurCaption(for: settings.blurRadius),
                value: blurRadiusBinding,
                range: 8...50,
                step: 2
            )
            treatmentSlider(
                icon: "moon.fill",
                title: "Darken amount",
                valueLabel: "\(Int(settings.darkenAmount * 100))%",
                caption: darkenCaption(for: settings.darkenAmount),
                value: darkenAmountBinding,
                range: 0...0.3,
                step: 0.02
            )
            treatmentSlider(
                icon: "arrow.up.left.and.arrow.down.right",
                title: "Background fill",
                valueLabel: String(format: "%.1f×", settings.backgroundScale),
                caption: backgroundScaleCaption(for: settings.backgroundScale),
                value: backgroundScaleBinding,
                range: 1.0...15.0,
                step: 0.5
            )

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Quick fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Spacer()
                    Text(activeFillPreset?.title ?? "Custom")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 12) {
                    ForEach(SmartFillWorkspaceBackgroundFillPreset.allCases, id: \.self) { preset in
                        Button {
                            applyBackgroundFillPreset(preset)
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(preset.title)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Theme.textPrimary)
                                Text(preset.caption)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(String(format: "%.1f×", preset.scale))
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(Theme.primary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                            .background(backgroundFillPresetBackground(for: preset), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(backgroundFillPresetStroke(for: preset), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                Text("Use quick fill when you need to clean up side bars fast. Fine-tune with the slider when the room still shows too much or the crop feels too aggressive.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button {
                showAdvancedSettings = true
            } label: {
                Label("Open detailed tuning sheet", systemImage: "slider.horizontal.3")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.bordered)
        }
        .padding(18)
        .background(panelBackground)
    }

    private var framingSurface: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Subject framing")
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)

            Text(SmartFillWorkspacePresentation.framingCaption(for: settings))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            summaryRow(
                icon: "person.crop.rectangle",
                title: "Subject scale",
                value: String(format: "%.2f×", settings.foregroundScale)
            )

            Slider(value: foregroundScaleBinding, in: 0.85...1.25, step: 0.05) {
                Text("Subject scale")
            }
            .tint(Theme.primary)
        }
        .padding(18)
        .background(panelBackground)
    }

    private var outputSurface: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Output")
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)

            Text(SmartFillWorkspacePresentation.outputCaption(for: settings))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            LazyVGrid(columns: outputOptionColumns, spacing: 12) {
                renderSizeOption(width: 1920, height: 1080, title: "Full HD", subtitle: "1920×1080")
                renderSizeOption(width: 1280, height: 720, title: "HD", subtitle: "1280×720")
                renderSizeOption(width: 3840, height: 2160, title: "4K", subtitle: "3840×2160")
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Processing speed")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)

                Picker("Processing speed", selection: processingPriorityBinding) {
                    ForEach(SmartFillSettings.ProcessingPriority.allCases, id: \.self) { priority in
                        Text(SmartFillWorkspacePresentation.processingPriorityTitle(for: priority))
                            .tag(priority)
                    }
                }
                .pickerStyle(.segmented)

                Text(SmartFillWorkspacePresentation.processingPriorityCaption(for: settings.processingPriority))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(18)
        .background(panelBackground)
    }

    private var saveSurface: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Save back to session")
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)

            Text(
                SmartFillWorkspacePresentation.saveLaneMessage(
                    for: context,
                    adoptionMode: currentAdoptionMode,
                    completionBehavior: completionBehavior
                )
            )
                .font(.subheadline)
                .foregroundStyle(.secondary)

            summaryRow(
                icon: "square.and.arrow.down",
                title: "Destination",
                value: SmartFillWorkspacePresentation.destinationTitle(for: context)
            )
            summaryRow(
                icon: "arrowshape.turn.up.backward",
                title: "Return to",
                value: SmartFillWorkspacePresentation.returnTargetTitle(for: context)
            )
            summaryRow(
                icon: "arrow.triangle.2.circlepath",
                title: "After save behavior",
                value: completionBehavior.summaryTitle
            )
            summaryRow(
                icon: "sparkles.rectangle.stack",
                title: "Current action",
                value: primaryActionTitle
            )

            VStack(alignment: .leading, spacing: 10) {
                Text("After save")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)

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

    private var actionBar: some View {
        HStack(spacing: 12) {
            Button(secondaryActionTitle) {
                handleSecondaryAction()
            }
            .buttonStyle(.bordered)
            .disabled(isCloseDisabled)

            Button(primaryActionTitle) {
                handlePrimaryAction()
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.primary)
            .disabled(isPrimaryActionDisabled)
        }
        .padding(.horizontal, Theme.Layout.screenPadding)
        .padding(.top, 12)
        .padding(.bottom, 16)
        .background(.ultraThinMaterial)
    }

    private var exportProgressPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Save progress")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Text("\(Int((processingProgress * 100).rounded()))%")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.primary)
            }

            ProgressView(value: processingProgress)
                .tint(Theme.primary)

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
                .foregroundStyle(Theme.primary)

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
            .fill(Color.white.opacity(0.06))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
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

    private var secondaryActionTitle: String {
        if hasPendingAutoReturn {
            return "Stay Here"
        }
        if effectiveStage == .completed {
            return "Close"
        }
        return "Cancel"
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

    private var outputOptionColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12)
        ]
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
        case .export: return Theme.primary
        case .preview where hasUnsavedChangesSinceLastSave: return .orange
        default: return .secondary
        }
    }

    private func backgroundModeBackground(for mode: SmartFillWorkspaceBackgroundMode) -> Color {
        activeBackgroundMode == mode ? Theme.primary.opacity(0.16) : Color.white.opacity(0.02)
    }

    private func backgroundModeStroke(for mode: SmartFillWorkspaceBackgroundMode) -> Color {
        activeBackgroundMode == mode ? Theme.primary.opacity(0.6) : Color.white.opacity(0.10)
    }

    private func treatmentPresetBackground(for preset: SmartFillWorkspaceTreatmentPreset) -> Color {
        activeTreatmentPreset == preset ? Theme.primary.opacity(0.16) : Color.white.opacity(0.02)
    }

    private func treatmentPresetStroke(for preset: SmartFillWorkspaceTreatmentPreset) -> Color {
        activeTreatmentPreset == preset ? Theme.primary.opacity(0.6) : Color.white.opacity(0.10)
    }

    private func backgroundFillPresetBackground(for preset: SmartFillWorkspaceBackgroundFillPreset) -> Color {
        activeFillPreset == preset ? Theme.primary.opacity(0.16) : Color.white.opacity(0.02)
    }

    private func backgroundFillPresetStroke(for preset: SmartFillWorkspaceBackgroundFillPreset) -> Color {
        activeFillPreset == preset ? Theme.primary.opacity(0.6) : Color.white.opacity(0.10)
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
                .foregroundStyle(Theme.textPrimary)

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
                .foregroundStyle(Theme.textPrimary)

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
                .foregroundStyle(Theme.primary)
            Text(title)
                .foregroundStyle(Theme.textPrimary)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
        }
        .font(.subheadline)
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
                    .foregroundStyle(Theme.textPrimary)
            }

            Slider(value: value, in: range, step: step) {
                Text(title)
            }
            .tint(Theme.primary)

            Text(caption)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func renderSizeOption(width: CGFloat, height: CGFloat, title: String, subtitle: String) -> some View {
        let isSelected = Int(settings.renderSize.width) == Int(width) && Int(settings.renderSize.height) == Int(height)

        return Button {
            settings.renderSize = CGSize(width: width, height: height)
            markSettingsDirty()
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(isSelected ? Theme.primary.opacity(0.16) : Color.white.opacity(0.02), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isSelected ? Theme.primary.opacity(0.6) : Color.white.opacity(0.10), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
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
            handleClose()
            return
        }

        queueSmartFill()
    }

    private func scheduleAutoReturn() {
        guard completionBehavior == .returnAutomatically else {
            autoReturnWorkItem?.cancel()
            autoReturnWorkItem = nil
            return
        }
        autoReturnWorkItem?.cancel()
        let workItem = DispatchWorkItem {
            handleClose()
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

    private func handleSecondaryAction() {
        if hasPendingAutoReturn {
            cancelAutoReturn()
            return
        }

        handleClose()
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
        context.infoTitle ?? "SmartFill Editor"
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
