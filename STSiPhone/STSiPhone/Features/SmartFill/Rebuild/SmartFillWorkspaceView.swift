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
                        primaryControlsSurface
                        exportSurface
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
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(primaryActionTitle) {
                        queueSmartFill()
                    }
                    .fontWeight(.semibold)
                    .disabled(coordinator.stage == .export)
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
                    launchSource: .takeReview,
                    returnTarget: .takeReview
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
                statusMessage = record.destinationSummary
                queueAttempted = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    handleClose()
                }
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
        }
    }

    private var previewSurface: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(context.displayName)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(Theme.textPrimary)

                    Text("Open one take, choose the SmartFill look, then save the landscape version back into this session.")
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

    private var primaryControlsSurface: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Choose the look")
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)

            HStack(spacing: 12) {
                ForEach(SmartFillSettings.Preset.allCases, id: \.rawValue) { preset in
                    Button {
                        applyPreset(preset)
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(presetTitle(for: preset))
                                .font(.subheadline.weight(.semibold))
                            Text(presetCaption(for: preset))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(presetBackground(for: preset), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(presetStroke(for: preset), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            VStack(spacing: 12) {
                summaryRow(
                    icon: "circle.dotted",
                    title: "Blur",
                    value: "\(Int(settings.blurRadius)) px"
                )
                summaryRow(
                    icon: "moon.fill",
                    title: "Darken",
                    value: "\(Int(settings.darkenAmount * 100))%"
                )
                summaryRow(
                    icon: "arrow.up.left.and.arrow.down.right",
                    title: "Background scale",
                    value: String(format: "%.1f×", settings.backgroundScale)
                )
                summaryRow(
                    icon: "rectangle.compress.vertical",
                    title: "Render size",
                    value: "\(Int(settings.renderSize.width))×\(Int(settings.renderSize.height))"
                )
            }

            HStack(spacing: 12) {
                Button {
                    showAdvancedSettings = true
                } label: {
                    Label("Advanced settings", systemImage: "slider.horizontal.3")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Menu {
                    renderSizeButton(width: 1920, height: 1080, label: "1920×1080 (Full HD)")
                    renderSizeButton(width: 1280, height: 720, label: "1280×720 (HD)")
                    renderSizeButton(width: 3840, height: 2160, label: "3840×2160 (4K)")
                } label: {
                    Label("Output size", systemImage: "rectangle.expand.vertical")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(18)
        .background(panelBackground)
    }

    private var exportSurface: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Save back into this session")
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)

            Text("SmartFill keeps the current take context intact. When processing finishes, the updated landscape version returns to this session and stays tied to the original take.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if let statusMessage {
                Text(statusMessage)
                    .font(.caption)
                    .foregroundStyle(stageColor)
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

            Button(primaryActionTitle) {
                queueSmartFill()
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.primary)
            .disabled(coordinator.stage == .export)
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

    private var panelBackground: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(Color.white.opacity(0.06))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
            )
    }

    private var primaryActionTitle: String {
        context.existingSettings == nil ? "Create SmartFill" : "Update SmartFill"
    }

    private var fileNameLabel: String {
        context.previewURL.lastPathComponent
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

    private func presetBackground(for preset: SmartFillSettings.Preset) -> Color {
        activePreset == preset ? Theme.primary.opacity(0.16) : Color.white.opacity(0.02)
    }

    private func presetStroke(for preset: SmartFillSettings.Preset) -> Color {
        activePreset == preset ? Theme.primary.opacity(0.6) : Color.white.opacity(0.10)
    }

    private var activePreset: SmartFillSettings.Preset? {
        SmartFillSettings.Preset.allCases.first { preset in
            settings.presetName?.caseInsensitiveCompare(presetTitle(for: preset)) == .orderedSame
        }
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

    private func renderSizeButton(width: CGFloat, height: CGFloat, label: String) -> some View {
        Button(label) {
            settings.renderSize = CGSize(width: width, height: height)
            markPreviewDirty()
        }
    }

    private func applyPreset(_ preset: SmartFillSettings.Preset) {
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
        statusMessage = "Processing SmartFill for \(context.displayName)…"
        queueAttempted = true
        onQueueSmartFill(clamped)
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
