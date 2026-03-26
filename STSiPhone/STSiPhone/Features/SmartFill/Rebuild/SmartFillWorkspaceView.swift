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
                statusMessage = SmartFillWorkspacePresentation.completionMessage(
                    for: context,
                    adoptionMode: record.adoptionMode
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

            Text(SmartFillWorkspacePresentation.saveLaneMessage(for: context))
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
                icon: "sparkles.rectangle.stack",
                title: "Current action",
                value: primaryActionTitle
            )

            if let statusMessage {
                Label(statusMessage, systemImage: stageIcon)
                    .font(.caption)
                    .foregroundStyle(stageColor)
            } else {
                Text(SmartFillWorkspacePresentation.saveFootnote(for: context))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(18)
        .background(panelBackground)
    }

    private var actionBar: some View {
        HStack(spacing: 12) {
            Button("Cancel") {
                handleClose()
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

    private var blurRadiusBinding: Binding<Double> {
        Binding(
            get: { Double(settings.blurRadius) },
            set: {
                settings.blurRadius = CGFloat($0)
                markPreviewDirty()
            }
        )
    }

    private var darkenAmountBinding: Binding<Double> {
        Binding(
            get: { Double(settings.darkenAmount) },
            set: {
                settings.darkenAmount = CGFloat($0)
                markPreviewDirty()
            }
        )
    }

    private var backgroundScaleBinding: Binding<Double> {
        Binding(
            get: { Double(settings.backgroundScale) },
            set: {
                settings.backgroundScale = CGFloat($0)
                markPreviewDirty()
            }
        )
    }

    private var foregroundScaleBinding: Binding<Double> {
        Binding(
            get: { Double(settings.foregroundScale) },
            set: {
                settings.foregroundScale = CGFloat($0)
                markPreviewDirty()
            }
        )
    }

    private var processingPriorityBinding: Binding<SmartFillSettings.ProcessingPriority> {
        Binding(
            get: { settings.processingPriority },
            set: { settings.processingPriority = $0 }
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
        SmartFillWorkspacePresentation.actionTitle(for: context, stage: coordinator.stage)
    }

    private var isPrimaryActionDisabled: Bool {
        coordinator.stage == .export
    }

    private var isCloseDisabled: Bool {
        coordinator.stage == .export
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
        switch coordinator.stage {
        case .intake: return "Ready"
        case .configure: return "Configure"
        case .preview: return "Preview"
        case .export: return "Processing"
        case .completed: return "Complete"
        }
    }

    private var stageIcon: String {
        switch coordinator.stage {
        case .intake: return "tray.and.arrow.down"
        case .configure: return "wand.and.stars"
        case .preview: return "play.rectangle"
        case .export: return "gearshape.2"
        case .completed: return "checkmark.circle.fill"
        }
    }

    private var stageColor: Color {
        switch coordinator.stage {
        case .completed: return .green
        case .export: return Theme.primary
        default: return .secondary
        }
    }

    private func backgroundModeBackground(for mode: SmartFillWorkspaceBackgroundMode) -> Color {
        activeBackgroundMode == mode ? Theme.primary.opacity(0.16) : Color.white.opacity(0.02)
    }

    private func backgroundModeStroke(for mode: SmartFillWorkspaceBackgroundMode) -> Color {
        activeBackgroundMode == mode ? Theme.primary.opacity(0.6) : Color.white.opacity(0.10)
    }

    private var activeBackgroundMode: SmartFillWorkspaceBackgroundMode? {
        SmartFillWorkspaceBackgroundMode.allCases.first { $0.matches(settings) }
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
            markPreviewDirty()
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
        markPreviewDirty()
    }

    private func queueSmartFill() {
        let clamped = settings.clamped()
        settings = clamped
        settings.saveToUserDefaults()
        coordinator.updateSettings(SmartFillTakeBridge.snapshot(from: clamped))
        coordinator.advance(to: .export)
        statusMessage = SmartFillWorkspacePresentation.processingMessage(for: context)
        queueAttempted = true
        onQueueSmartFill(clamped)
    }

    private func handlePrimaryAction() {
        if coordinator.stage == .completed {
            handleClose()
            return
        }

        queueSmartFill()
    }

    private func scheduleAutoReturn() {
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

    private func markPreviewDirty() {
        settings.forceUpdateToken = UUID()
        previewErrorMessage = nil
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
        stage: SmartFillWorkspaceCoordinator.Stage
    ) -> String {
        switch stage {
        case .export:
            return "Saving SmartFill…"
        case .completed:
            return "Return to \(shortReturnTargetTitle(for: context))"
        default:
            let leadingVerb = context.take.isSmartFillVariant || context.existingSettings != nil ? "Update" : "Save"
            return "\(leadingVerb) and Return to \(shortReturnTargetTitle(for: context))"
        }
    }

    static func destinationTitle(for context: SmartFillSettingsContext) -> String {
        context.take.isSmartFillVariant ? "Update current SmartFill take" : "Create or refresh SmartFill take"
    }

    static func saveLaneMessage(for context: SmartFillSettingsContext) -> String {
        if context.take.isSmartFillVariant {
            return "Updating SmartFill keeps the current landscape take in sync, then returns you to \(returnTargetTitle(for: context).lowercased())."
        }

        return "Saving SmartFill creates or refreshes the landscape take for this source clip, then returns you to \(returnTargetTitle(for: context).lowercased())."
    }

    static func saveFootnote(for context: SmartFillSettingsContext) -> String {
        "When processing completes, SmartFill returns to \(returnTargetTitle(for: context).lowercased()) with the landscape result still tied to “\(context.displayName)”."
    }

    static func processingMessage(for context: SmartFillSettingsContext) -> String {
        "Saving SmartFill for “\(context.displayName)” and preparing the return to \(returnTargetTitle(for: context).lowercased())…"
    }

    static func completionMessage(
        for context: SmartFillSettingsContext,
        adoptionMode: SmartFillResultAdoptionMode
    ) -> String {
        switch adoptionMode {
        case .updateExistingTakePath:
            return "Updated SmartFill. Returning to \(returnTargetTitle(for: context))…"
        case .createStandaloneVariantTake:
            return "Saved the SmartFill take. Returning to \(returnTargetTitle(for: context))…"
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
