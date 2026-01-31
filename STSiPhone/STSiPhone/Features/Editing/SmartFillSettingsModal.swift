import SwiftUI
import AVFoundation

/// Smart Fill Settings Modal for Editor Integration
/// ENHANCED: Processing animation and state management
struct SmartFillSettingsModal: View {
    @State private var settings: SmartFillSettings
    @Environment(\.dismiss) private var dismiss
    private static let bannerPreferenceKey = "smartFillSettings_hideInfoBanner"
    
    // PHASE 3: Real preview support
    let previewVideoURL: URL?
    let originalVideoSize: CGSize?
    let infoTitle: String?
    let infoMessage: String?
    @State private var pipSlateSession: SlatePIPSession?
    
    // 🔄 PROCESSING ANIMATION STATE
    @State private var isProcessing = false
    @State private var processingProgress: Double? = nil
    @State private var processingTitle = "Preparing SmartFill..."
    @State private var showInfoBanner: Bool
    @State private var showingHideBannerPrompt = false
    @State private var hideInfoBanner = UserDefaults.standard.bool(forKey: SmartFillSettingsModal.bannerPreferenceKey)
    
    // Callback for applying settings
    var onApplySettings: ((SmartFillSettings) -> Void)?
    var onCancel: (() -> Void)?
    var onRevertSmartFill: (() -> Void)?
    var onUpdatePIPSlateSession: ((SlatePIPSession?) -> Void)?
    
    private var pipSlateSessionBinding: Binding<SlatePIPSession>? {
        Binding(unwrapping: $pipSlateSession)
    }
    
    init(currentSettings: SmartFillSettings = SmartFillSettings(),
         previewVideoURL: URL? = nil,
         originalVideoSize: CGSize? = nil,
         infoTitle: String? = nil,
         infoMessage: String? = nil,
         pipSlateSession: SlatePIPSession? = nil,
         onApplySettings: ((SmartFillSettings) -> Void)? = nil,
         onCancel: (() -> Void)? = nil,
         onRevertSmartFill: (() -> Void)? = nil,
         onUpdatePIPSession: ((SlatePIPSession?) -> Void)? = nil) {
        self._settings = State(initialValue: currentSettings)
        self.previewVideoURL = previewVideoURL
        self.originalVideoSize = originalVideoSize
        self.infoTitle = infoTitle
        self.infoMessage = infoMessage
        self.onApplySettings = onApplySettings
        self.onCancel = onCancel
        self.onRevertSmartFill = onRevertSmartFill
        self._pipSlateSession = State(initialValue: pipSlateSession)
        self.onUpdatePIPSlateSession = onUpdatePIPSession
        
        let hasInfoContent = (infoTitle != nil || infoMessage != nil)
        let shouldShowBanner = hasInfoContent && !UserDefaults.standard.bool(forKey: SmartFillSettingsModal.bannerPreferenceKey)
        self._showInfoBanner = State(initialValue: shouldShowBanner)
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                BrandBackground()
                    .ignoresSafeArea()
                
                VStack(spacing: 16) {
                    if showInfoBanner {
                        infoBanner
                            .padding(.horizontal, Theme.Layout.screenPadding)
                            .padding(.top)
                    }
                    
                    SmartFillSettingsContent(
                        settings: $settings,
                        previewVideoURL: previewVideoURL,
                        originalVideoSize: originalVideoSize,
                        pipSession: pipSlateSessionBinding
                    )
                }
                
                // 🎬 PROCESSING OVERLAY - Professional full-screen animation
                if isProcessing {
                    processingOverlay
                        .transition(.opacity.combined(with: .scale(0.98)))
                        .zIndex(1000) // Ensure it's on top
                }
            }
            .navigationTitle("Smart Fill Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        if isProcessing {
                            // Don't allow cancel during processing
                            return
                        }
                        onCancel?()
                        dismiss()
                    }
                    .disabled(isProcessing)
                    .foregroundStyle(isProcessing ? .secondary : .primary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 12) {
                        if onRevertSmartFill != nil {
                            Button("Revert") {
                                guard !isProcessing else { return }
                                onRevertSmartFill?()
                                dismiss()
                            }
                            .foregroundStyle(.red)
                        }
                        Button("Apply") {
                            if isProcessing {
                                return
                            }
                            startProcessingAnimation()
                            onApplySettings?(settings)
                        }
                        .disabled(isProcessing)
                        .fontWeight(.semibold)
                        .foregroundStyle(isProcessing ? .secondary : Theme.primary)
                    }
                }
            }
        }
        .interactiveDismissDisabled(isProcessing) // Prevent swipe-to-dismiss during processing
        // Listen for processing completion with proper notification names
        .onReceive(NotificationCenter.default.publisher(for: .smartFillProcessingComplete)) { notification in
            handleProcessingComplete(notification)
        }
        .onReceive(NotificationCenter.default.publisher(for: .smartFillProcessingProgress)) { notification in
            handleProcessingProgress(notification)
        }
        .onReceive(NotificationCenter.default.publisher(for: .smartFillProcessingFailed)) { notification in
            handleProcessingFailed(notification)
        }
        .alert("Hide this SmartFill reminder?", isPresented: $showingHideBannerPrompt) {
            Button("Yes, don't show again") {
                hideInfoBanner = true
                UserDefaults.standard.set(true, forKey: SmartFillSettingsModal.bannerPreferenceKey)
                withAnimation(.spring()) {
                    showInfoBanner = false
                }
            }
            Button("No, just close", role: .cancel) {
                withAnimation(.spring()) {
                    showInfoBanner = false
                }
            }
        } message: {
            Text("This banner explains why SmartFill runs first. You can hide it permanently if you already know the flow.")
        }
        .onChange(of: pipSlateSession, initial: false) { _, newValue in
            onUpdatePIPSlateSession?(newValue)
        }
    }
    
    private var infoBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.title3)
                    .foregroundStyle(.yellow)
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        if let infoTitle {
                            Text(infoTitle)
                                .font(.headline)
                                .foregroundStyle(.primary)
                        }
                        Spacer()
                        Button {
                            showingHideBannerPrompt = true
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Close SmartFill reminder")
                    }
                    if let infoMessage {
                        Text(infoMessage)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
        )
    }
    
    // 🎬 PROFESSIONAL PROCESSING OVERLAY
    private var processingOverlay: some View {
        ZStack {
            // Backdrop blur with subtle darkening
            Color.black.opacity(0.3)
                .background(.ultraThinMaterial)
                .ignoresSafeArea()
            
            // Processing badge with professional styling
            VStack(spacing: 24) {
                MiniProcessingBadge.smartFillProcessor(
                    isVisible: .constant(true),
                    progress: processingProgress,
                    title: processingTitle
                )
                
                // Progress details
                VStack(spacing: 8) {
                    if let progress = processingProgress {
                        Text("\(Int(progress * 100))% Complete")
                            .font(.headline)
                            .foregroundStyle(.primary)
                    }
                    
                    Text("Converting portrait video to landscape format with enhanced background")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: processingProgress)
    }
    
    // MARK: - Processing Animation Methods
    
    private func startProcessingAnimation() {
        withAnimation(.easeInOut(duration: 0.3)) {
            isProcessing = true
            processingProgress = nil // Start indeterminate
            processingTitle = "Preparing SmartFill..."
        }
        
        // Simulate preparation phase
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.easeInOut(duration: 0.3)) {
                processingProgress = 0.1
                processingTitle = "Processing Video..."
            }
        }
    }
    
    private func handleProcessingProgress(_ notification: Notification) {
        guard let progress = notification.userInfo?["progress"] as? Double else { return }
        
        withAnimation(.easeInOut(duration: 0.2)) {
            processingProgress = progress
            
            // Update title based on progress - UPDATED for landscape conversion context
            switch progress {
            case 0.0..<0.2:
                processingTitle = "Analyzing Portrait Video..."
            case 0.2..<0.5:
                processingTitle = "Creating Landscape Canvas..."
            case 0.5..<0.8:
                processingTitle = "Applying Background Effects..."
            case 0.8..<1.0:
                processingTitle = "Finalizing Landscape Video..."
            default:
                processingTitle = "Converting to Landscape..."
            }
        }
    }
    
    private func handleProcessingComplete(_ notification: Notification) {
        // Show completion state briefly
        withAnimation(.easeInOut(duration: 0.3)) {
            processingProgress = 1.0
            processingTitle = "Portrait → Landscape Complete! ✨"
        }
        
        // Dismiss after brief success display
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeOut(duration: 0.4)) {
                isProcessing = false
            }
            
            // Dismiss modal after animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                dismiss()
            }
        }
    }
    
    private func handleProcessingFailed(_ notification: Notification) {
        let _ = notification.userInfo?["error"] as? String ?? "Processing failed" // FIXED: Mark as intentionally unused
        
        withAnimation(.easeInOut(duration: 0.3)) {
            processingProgress = nil
            processingTitle = "Conversion Failed"
        }
        
        // Show error briefly, then allow user to dismiss
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeOut(duration: 0.4)) {
                isProcessing = false
            }
        }
    }
}

/// ENTERPRISE UX REDESIGN: Professional single-screen layout with real-time preview
/// FIXES: 1) Locked preview at top, 2) Immediate preset feedback, 3) Real-time preview updates
struct SmartFillSettingsContent: View {
    @Binding var settings: SmartFillSettings
    
    // PHASE 3: Real preview support
    let previewVideoURL: URL?
    let originalVideoSize: CGSize?
    let pipSession: Binding<SlatePIPSession>?
    
    // Local state for UI bindings with real-time updates
    @State private var defaultEnabled: Bool
    @State private var blurRadius: Double
    @State private var darkenAmount: Double
    @State private var backgroundScale: Double
    @State private var renderWidth: Double
    @State private var renderHeight: Double
    @State private var selectedPresetName: String
    @State private var isApplyingPreset: Bool = false
    @State private var previewErrorMessage: String? = nil
    
    // 🔄 REAL-TIME PREVIEW: State to trigger preview updates
    @State private var previewRefreshID: UUID = UUID()
    
    init(settings: Binding<SmartFillSettings>,
         previewVideoURL: URL? = nil,
         originalVideoSize: CGSize? = nil,
         pipSession: Binding<SlatePIPSession>? = nil) {
        self._settings = settings
        self.previewVideoURL = previewVideoURL
        self.originalVideoSize = originalVideoSize
        self.pipSession = pipSession
        
        // Initialize local state from settings
        let currentSettings = settings.wrappedValue
        self._defaultEnabled = State(initialValue: currentSettings.defaultEnabled)
        self._blurRadius = State(initialValue: Double(currentSettings.defaultBlurRadius))
        self._darkenAmount = State(initialValue: Double(currentSettings.defaultDarkenAmount))
        self._backgroundScale = State(initialValue: Double(currentSettings.backgroundScale))
        self._renderWidth = State(initialValue: Double(currentSettings.defaultRenderSize.width))
        self._renderHeight = State(initialValue: Double(currentSettings.defaultRenderSize.height))
        
        // Determine current preset
        let preset = SmartFillSettings.Preset.allCases.first { preset in
            preset.blurRadius == currentSettings.defaultBlurRadius &&
            preset.darkenAmount == currentSettings.defaultDarkenAmount
        }
        
        let presetName: String
        if let preset = preset {
            switch preset {
            case .subtle: presetName = "Subtle"
            case .medium: presetName = "Medium"
            case .dramatic: presetName = "Dramatic"
            }
        } else {
            presetName = "Custom"
        }
        
        self._selectedPresetName = State(initialValue: presetName)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 🔒 LOCKED PREVIEW - Always visible at top, non-scrollable
            if let previewURL = previewVideoURL {
                VStack(spacing: 16) {
                    HStack {
                        Image(systemName: "photo.on.rectangle.angled")
                            .foregroundStyle(Theme.primary)
                        Text("Live Preview")
                            .fontWeight(.medium)
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.top)
                    
                    // 🔄 REAL-TIME PREVIEW with settings trigger
                    if let smartFillPreview = SmartFillVideoPreview.makeIfAvailable(
                        url: previewURL,
                        settings: settings,
                        errorMessage: $previewErrorMessage,
                        refreshID: previewRefreshID
                    ) {
                        smartFillPreview
                            .padding(.horizontal)
                    } else if VideoFileManager.shared.fileExists(named: previewURL.lastPathComponent) {
                        SmartFillRealPreviewSectionHandoff(
                            take: UnifiedTake(
                                fileName: previewURL.lastPathComponent,
                                projectID: UUID(),
                                sessionID: UUID(),
                                filePath: previewURL.path,
                                duration: 0,
                                fileSize: 0,
                                cameraPosition: "back",
                                sceneNumber: 1,
                                takeNumber: 1,
                                isSlate: false,
                                isPhoto: false,
                                isKeyframePhoto: false,
                                capturedOrientation: .portrait,
                                rating: .unrated,
                                notes: nil
                            ),
                            settings: settings
                        )
                        .id(previewRefreshID)
                        .padding(.horizontal)
                    } else {
                        VStack(spacing: 8) {
                            Image(systemName: "video.slash")
                                .font(.largeTitle)
                                .foregroundStyle(.secondary)
                            Text("Preview Unavailable")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(height: 160)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                        .padding(.horizontal)
                    }
                }
                .padding(.bottom)
                .background(BrandBackground()) // Same background as scrollable content
            }
            
            // 📜 SCROLLABLE SETTINGS CONTENT
            List {
                // SMART FILL ENABLE/DISABLE
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "person.and.background.dotted")
                                .font(.title2)
                                .foregroundStyle(Theme.primary)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Smart Portrait Fill")
                                    .font(.headline)
                                    .foregroundStyle(Theme.textPrimary)
                                
                                Text("Automatically enhance portrait videos with blurred background")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        if false {
                            Toggle("Enable by Default", isOn: $defaultEnabled)
                                .tint(Theme.primary)
                                .onChange(of: defaultEnabled, initial: false) { _, _ in
                                    updateSettingsWithPreview()
                                }
                        }
                    }
                    .padding(.vertical, 8)
                }
                .listRowBackground(Color.clear)
                
                    // 🎯 ENTERPRISE: PRESET BUTTONS - Clean, no descriptions needed
                    Section {
                        HStack(spacing: 12) {
                            EnterprisePresetButton(
                                title: "Subtle",
                                isSelected: selectedPresetName == "Subtle"
                            ) {
                                applyPresetImmediately(.subtle)
                            }
                            
                            EnterprisePresetButton(
                                title: "Medium",
                                isSelected: selectedPresetName == "Medium"
                            ) {
                                applyPresetImmediately(.medium)
                            }
                            
                            EnterprisePresetButton(
                                title: "Dramatic",
                                isSelected: selectedPresetName == "Dramatic"
                            ) {
                                applyPresetImmediately(.dramatic)
                            }
                        }
                        .listRowBackground(Color.clear)
                    } header: {
                        Text("Quality Presets")
                            .fontWeight(.medium)
                    } footer: {
                        Text("If Live preview does not update, tap the desired preset a second time.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    // 🎛️ REAL-TIME SLIDERS - Professional inline controls
                    Section {
                        VStack(spacing: 20) {
                            // Blur Radius Slider
                            VStack(spacing: 12) {
                                HStack {
                                    Label("Blur Radius", systemImage: "circle.dotted")
                                        .foregroundStyle(Theme.textPrimary)
                                    Spacer()
                                    Text("\(Int(blurRadius))px")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .monospacedDigit()
                                }
                                
                                Slider(value: $blurRadius, in: 8...50, step: 2) {
                                    Text("Blur")
                                }
                                .tint(Theme.primary)
                                .onChange(of: blurRadius, initial: false) { _, _ in
                                    guard !isApplyingPreset else { return }
                                    selectedPresetName = "Custom"
                                    updateSettingsWithPreview()
                                }
                            }
                            
                            // Darken Amount Slider
                            VStack(spacing: 12) {
                                HStack {
                                    Label("Darken Amount", systemImage: "moon.fill")
                                        .foregroundStyle(Theme.textPrimary)
                                    Spacer()
                                    Text("\(Int(darkenAmount * 100))%")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .monospacedDigit()
                                }
                                
                                Slider(value: $darkenAmount, in: 0...0.3, step: 0.01) {
                                    Text("Darken")
                                }
                                .tint(Theme.primary)
                                .onChange(of: darkenAmount, initial: false) { _, _ in
                                    guard !isApplyingPreset else { return }
                                    selectedPresetName = "Custom"
                                    updateSettingsWithPreview()
                                }
                            }
                            
                            // Background Scale Slider - ENTERPRISE FEATURE
                            VStack(spacing: 12) {
                                HStack {
                                    Label("Background Scale", systemImage: "viewfinder")
                                        .foregroundStyle(Theme.textPrimary)
                                    Spacer()
                                    VStack(alignment: .trailing, spacing: 2) {
                                        Text("\(String(format: "%.1f", backgroundScale))×")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .monospacedDigit()
                                        Text(backgroundScaleDescription)
                                            .font(.caption2)
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                                
                                Slider(value: $backgroundScale, in: 1.0...15.0, step: 0.5) {
                                    Text("Scale")
                                }
                                .tint(Theme.primary)
                                .onChange(of: backgroundScale, initial: false) { _, _ in
                                    guard !isApplyingPreset else { return }
                                    selectedPresetName = "Custom"
                                    updateSettingsWithPreview()
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    } header: {
                        Text("Custom Settings")
                            .fontWeight(.medium)
                    } footer: {
                        Text("Adjust settings to see real-time preview changes above")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .listRowBackground(Color.clear)
                    
                    // EXPORT QUALITY
                    Section("Export Quality") {
                        HStack {
                            Text("Render Size")
                                .foregroundStyle(Theme.textPrimary)
                            
                            Spacer()
                            
                            Menu {
                                Button("1920×1080 (Full HD)") {
                                    renderWidth = 1920
                                    renderHeight = 1080
                                    updateSettingsWithPreview()
                                }
                                Button("1280×720 (HD)") {
                                    renderWidth = 1280
                                    renderHeight = 720
                                    updateSettingsWithPreview()
                                }
                                Button("3840×2160 (4K)") {
                                    renderWidth = 3840
                                    renderHeight = 2160
                                    updateSettingsWithPreview()
                                }
                            } label: {
                                Text("\(Int(renderWidth))×\(Int(renderHeight))")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .listRowBackground(Color.clear)
            }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
    .onAppear {
        if defaultEnabled == false {
            defaultEnabled = true
        }
        forcePreviewRefresh("onAppear – SmartFill settings sheet opened")
    }
}
    
    // MARK: - Enterprise Helper Methods
    
    /// 🔄 IMMEDIATE PRESET APPLICATION - Fixes lag issue
    private func applyPresetImmediately(_ preset: SmartFillSettings.Preset) {
        guard !isApplyingPreset else { return }
        isApplyingPreset = true
        
        selectedPresetName = presetName(for: preset) ?? "Custom"
        blurRadius = Double(preset.blurRadius)
        darkenAmount = Double(preset.darkenAmount)
        backgroundScale = Double(preset.backgroundScale)
        
        // Update settings and trigger preview refresh
        updateSettingsWithPreview()
        DispatchQueue.main.async { isApplyingPreset = false }
    }
    
    private func presetName(for preset: SmartFillSettings.Preset?) -> String? {
        guard let preset = preset else { return nil }
        switch preset {
        case .subtle: return "Subtle"
        case .medium: return "Medium"
        case .dramatic: return "Dramatic"
        }
    }
    
    private var backgroundScaleDescription: String {
        switch backgroundScale {
        case 1.0..<3.0: return "Minimal"
        case 3.0..<6.0: return "Light"
        case 6.0..<9.0: return "Moderate"
        case 9.0..<12.0: return "Strong"
        default: return "Maximum"
        }
    }
    
    @MainActor
    private func forcePreviewRefresh(_ reason: String, id: UUID = UUID()) {
        print("🔄 SmartFillSettingsContent.forcePreviewRefresh – \(reason) id=\(id)")
        previewRefreshID = id
    }
    
    /// 🔄 CRITICAL: Update settings AND trigger preview refresh
    private func updateSettingsWithPreview() {
        let newToken = UUID()
        settings = SmartFillSettings(
            defaultEnabled: defaultEnabled,
            defaultBlurRadius: CGFloat(blurRadius),
            defaultDarkenAmount: CGFloat(darkenAmount),
            defaultRenderSize: CGSize(width: renderWidth, height: renderHeight),
            backgroundScale: CGFloat(backgroundScale),
            processingPriority: settings.processingPriority,
            forceUpdateToken: newToken
        )
        
        // 🔄 Force preview to regenerate with new settings
        forcePreviewRefresh("updateSettingsWithPreview – user adjusted SmartFill controls", id: newToken)
    }
}

// MARK: - Video Preview Wrapper

private struct SmartFillVideoPreview: View {
        let videoURL: URL
        let settings: SmartFillSettings
        let refreshID: UUID
        @Binding var errorMessage: String?
        
        var body: some View {
            ZStack {
                SmartFillPreviewPlayer(
                    videoURL: videoURL,
                    settings: settings,
                    refreshID: refreshID,
                    onError: { error in
                        errorMessage = error.localizedDescription
                    }
                )
                .frame(maxWidth: .infinity)
                .aspectRatio(16/9, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
                
                if let error = errorMessage, !error.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.title3)
                            .foregroundStyle(.orange)
                        Text("Preview Error")
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.regularMaterial)
                    )
                }
            }
            .id(refreshID)
            .animation(.easeInOut(duration: 0.2), value: errorMessage)
        }
        
        static func makeIfAvailable(
            url: URL,
            settings: SmartFillSettings,
            errorMessage: Binding<String?>,
            refreshID: UUID
        ) -> AnyView? {
            guard FileManager.default.fileExists(atPath: url.path) else { return nil }
            let view = SmartFillVideoPreview(
                videoURL: url,
                settings: settings,
                refreshID: refreshID,
                errorMessage: errorMessage
            )
            return AnyView(view)
        }
    }
    
    // MARK: - Enterprise Preset Button Component
    
    struct EnterprisePresetButton: View {
        let title: String
        let isSelected: Bool
        let action: () -> Void
        
        var body: some View {
            Button(action: action) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(isSelected ? Color.white : Theme.textPrimary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(isSelected ? Theme.primary : Color.white.opacity(0.1))
                            .stroke(isSelected ? Color.clear : Color.white.opacity(0.2), lineWidth: 1)
                    )
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    // HANDOFF FIX: The old SmartFillRealPreviewSection has been replaced with a new implementation
    // in SmartFillRealPreviewSectionHandoff.swift that fixes the spinner issue using @StateObject
    // and decouples preview visibility from smartFilledFilePath gating.
    
    // MARK: - Extensions for Preset Support
    extension SmartFillSettings.Preset {
        public static var allCases: [SmartFillSettings.Preset] {
            return [.subtle, .medium, .dramatic]
        }
    }
    
// MARK: - Processing Notifications
#Preview {
    SmartFillSettingsModal()
}
