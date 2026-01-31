import SwiftUI

// MARK: - Slate Capture Style

enum SlateCaptureStyle: String, CaseIterable, Identifiable {
    case pictureInPicture
    case smartFill
    case standard

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .pictureInPicture:
            return "Picture-in-Picture Slate"
        case .smartFill:
            return "SmartFill Slate"
        case .standard:
            return "Full Body Slate"
        }
    }

    var tagline: String {
        switch self {
        case .pictureInPicture:
            return "Most accepted professional slate — especially when paired with performance scenes."
        case .smartFill:
            return "Traditional full-body slate with elevated production polish."
        case .standard:
            return "Classic full-body slate — simple, fast, reliable."
        }
    }

    var detailedDescription: String {
        switch self {
        case .pictureInPicture:
            return "Capture a full-body and close-up simultaneously for a polished dual-angle slate. Ideal when casting expects both framings without extra takes."
        case .smartFill:
            return "A clean full-body slate recorded like normal Full Body Slate, with the option to apply the polished SmartFill look later when reviewing your takes. Look for the SmartFill icon to instantly enhance the slate with iTFactor's studio-grade SmartFilled background."
        case .standard:
            return "A straightforward vertical full-body slate, commonly requested as a standalone clip or recorded separately from performance sides."
        }
    }

    /// Convenience for deciding aspect ratio of the reference image.
    var referenceAspectRatio: CGFloat {
        switch self {
        case .smartFill, .pictureInPicture:
            return 16.0 / 9.0
        case .standard:
            return 9.0 / 16.0
        }
    }

    var continueActionTitle: String {
        switch self {
        case .pictureInPicture:
            return "Picture-in-Picture"
        case .smartFill:
            return "SmartFill"
        case .standard:
            return "Full Body"
        }
    }
}

// MARK: - Slate Prompt Sheet

struct SlatePromptSheet: View {

    private enum Step {
        case layout
        case script
    }

    @Binding var captureStyle: SlateCaptureStyle
    @Binding var script: String
    @Binding var promptMode: SlatePromptMode
    @Binding var customScript: String
    @Binding var clearCustomDraft: Bool
    let autoScript: String
    let selections: SlateSelections
    @Binding var isOverlayActive: Bool
    let onBegin: () -> Void
    let onDismiss: () -> Void
    let theme: STSTheme

    @State private var currentStep: Step = .layout
    @State private var referenceImageNames: [SlateCaptureStyle: String] = [:]
    @FocusState private var isScriptEditorFocused: Bool

    private let detailColumns = [GridItem(.adaptive(minimum: 110), spacing: 8)]
    private let layoutOrder: [SlateCaptureStyle] = [.pictureInPicture, .smartFill, .standard]

    private let referenceImages: [SlateCaptureStyle: [String]] = [
        .standard: ["slate_standard_1"],
        .smartFill: ["slate_smartfill_1"],
        .pictureInPicture: ["slate_pip_1"]
    ]

    init(
        script: Binding<String>,
        selections: SlateSelections,
        captureStyle: Binding<SlateCaptureStyle>,
        promptMode: Binding<SlatePromptMode>,
        customScript: Binding<String>,
        clearCustomDraft: Binding<Bool>,
        autoScript: String,
        isOverlayActive: Binding<Bool>,
        onBegin: @escaping () -> Void,
        onDismiss: @escaping () -> Void,
        theme: STSTheme
    ) {
        self._script = script
        self.selections = selections
        self._captureStyle = captureStyle
        self._promptMode = promptMode
        self._customScript = customScript
        self._clearCustomDraft = clearCustomDraft
        self.autoScript = autoScript
        self._isOverlayActive = isOverlayActive
        self.onBegin = onBegin
        self.onDismiss = onDismiss
        self.theme = theme
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                headerIcon

                headerText

                ScrollView {
                    VStack(spacing: 24) {
                        VStack(spacing: 20) {
                            switch currentStep {
                            case .layout:
                                layoutStepContent
                            case .script:
                                scriptStepContent
                            }
                        }
                        footerButtons
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
                }
            }
            .padding(.top, 12)
            .background(
                theme.backgroundGradient
                    .ignoresSafeArea()
            )
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: onDismiss) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(theme.textSecondary)
                    }
                    .buttonStyle(.plain)
                }

                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        isScriptEditorFocused = false
                    }
                }
            }
            .onAppear {
                DispatchQueue.main.async {
                    prepareReferenceImagesIfNeeded()
                }
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .interactiveDismissDisabled(true)
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }

    // MARK: Header

    private var headerIcon: some View {
        Image("AppLogo")
            .resizable()
            .scaledToFit()
            .frame(width: 116, height: 116)
            .shadow(radius: 8, y: 4)
    }

    private var headerTitle: String {
        switch currentStep {
        case .layout:
            return "Slate Layout"
        case .script:
            return "Slate Script"
        }
    }

    private var headerSubtitle: String {
        switch currentStep {
        case .layout:
            return "Choose the layout that best showcases you for the booking."
        case .script:
            return "Review your slate script and teleprompter options."
        }
    }

    private var headerStepIndicator: String {
        currentStep == .layout ? "Step 1 of 2" : "Step 2 of 2"
    }

    private var headerText: some View {
        VStack(spacing: 8) {
            Text(headerTitle)
                .font(Theme.Font.title)
                .foregroundStyle(theme.textPrimary)
                .multilineTextAlignment(.center)

            Text(headerSubtitle)
                .font(Theme.Font.body)
                .foregroundStyle(theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)

            Text(headerStepIndicator)
                .font(.caption.weight(.semibold))
                .foregroundStyle(theme.primaryAccent.opacity(0.85))
        }
    }

    // MARK: Layout Step

    @ViewBuilder
    private var layoutStepContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(layoutOrder) { style in
                layoutCard(for: style)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func layoutCard(for style: SlateCaptureStyle) -> some View {
        let isSelected = captureStyle == style

        VStack(spacing: 12) {
            VStack(spacing: 14) {
                Text(style.displayName)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(theme.textPrimary)
                    .multilineTextAlignment(.center)

                if let name = imageName(for: style) {
                    ZStack {
                        Color.clear
                        Image(name)
                            .resizable()
                            .scaledToFit()
                            .padding(style.referenceAspectRatio > 1 ? 0 : 8)
                    }
                    .aspectRatio(style.referenceAspectRatio, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(theme.cardStroke.opacity(0.35), lineWidth: 1)
                    )
                }

                VStack(spacing: 8) {
                    Text(style.tagline)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(theme.primaryButtonBackground)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(style.detailedDescription)
                        .font(.subheadline)
                        .foregroundStyle(theme.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity)

                Button {
                    captureStyle = style
                    currentStep = .script
                } label: {
                    HStack(spacing: 6) {
                        Text("Continue with \(style.continueActionTitle)")
                            .font(.system(size: 14, weight: .semibold))
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 16)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(theme.primaryAccent.opacity(0.18))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(theme.primaryAccent.opacity(0.4), lineWidth: 1)
                    )
                    .foregroundStyle(theme.primaryAccent)
                }
                .buttonStyle(.plain)
                .padding(.top, 8)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .center)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(isSelected ? theme.primaryAccent.opacity(0.18) : theme.cardBackground.opacity(0.95))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(isSelected ? theme.primaryAccent : theme.cardStroke.opacity(0.45), lineWidth: isSelected ? 1.5 : 1)
            )
            .contentShape(Rectangle())
            .onTapGesture {
                captureStyle = style
            }
        }
    }

    // MARK: Script Step

    @ViewBuilder
    private var scriptStepContent: some View {
        VStack(spacing: 20) {
            includedDetailsSection
            SlateScriptModeEditor(
                previewScript: $script,
                mode: $promptMode,
                customScript: $customScript,
                clearCustomDraft: $clearCustomDraft,
                autoScript: autoScript,
                isFocused: $isScriptEditorFocused,
                theme: theme
            )
            if captureStyle == .pictureInPicture {
                pipTeleprompterGuide
            } else {
                teleprompterToggleCard
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var includedDetailsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Included Details")
                .font(Theme.Font.headline)
                .foregroundStyle(theme.textPrimary)

            LazyVGrid(columns: detailColumns, alignment: .leading, spacing: 8) {
                ForEach(SlateField.allCases, id: \.self) { field in
                    if selections.include.contains(field) {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(theme.primaryAccent.opacity(0.55))
                                .frame(width: 6, height: 6)

                            Text(fieldDisplayName(field))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(theme.textPrimary)
                        }
                        .padding(.vertical, 4)
                    }
                }

                if selections.includePassport, selections.hasValidPassport == true {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(theme.primaryAccent.opacity(0.55))
                            .frame(width: 6, height: 6)
                        Text("Passport")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(theme.textPrimary)
                    }
                    .padding(.vertical, 4)
                }

                if selections.includeCitizenship,
                   selections.isLegalCitizen == true,
                   selections.citizenshipCountry?.slateTrimmedNonEmpty != nil {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(theme.primaryAccent.opacity(0.55))
                            .frame(width: 6, height: 6)
                        Text("Citizenship")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(theme.textPrimary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private var teleprompterToggleCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(isOn: $isOverlayActive) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Show Slate Teleprompter")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(theme.textPrimary)
                    Text("Your slate lines, right where you need them.")
                        .font(.subheadline)
                        .foregroundStyle(theme.textSecondary)
                }
            }
            .toggleStyle(SwitchToggleStyle(tint: theme.primaryAccent))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(theme.cardBackground.opacity(0.95))
        )
    }

    private var pipTeleprompterGuide: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Teleprompter Access")
                .font(.headline.weight(.semibold))
                .foregroundStyle(theme.textPrimary)

            Text("To access the Slate Teleprompter while in Picture-in-Picture slates")
                .font(.subheadline)
                .foregroundStyle(theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 6) {
                Image(systemName: "film")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(theme.primaryAccent)
                Text("Tap the Film strip icon → Slate Teleprompter")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(theme.primaryAccent)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(theme.cardBackground.opacity(0.95))
        )
    }

    // MARK: Footer

    @ViewBuilder
    private var footerButtons: some View {
        VStack(spacing: 12) {
            switch currentStep {
            case .layout:
                EmptyView()
            case .script:
                BrandedPrimaryButton(label: "Continue: Record Your Slate", icon: "video.fill") {
                    onBegin()
                }

                Button("Back to Layout") {
                    currentStep = .layout
                }
                .font(Theme.Font.body)
                .foregroundStyle(theme.textSecondary.opacity(0.95))
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
    }

    // MARK: Helpers

    private func prepareReferenceImagesIfNeeded() {
        guard referenceImageNames.isEmpty else { return }

        var map: [SlateCaptureStyle: String] = [:]
        for (style, names) in referenceImages {
            if let random = names.randomElement() {
                map[style] = random
            }
        }
        referenceImageNames = map
    }

    private func imageName(for style: SlateCaptureStyle) -> String? {
        if let name = referenceImageNames[style] {
            return name
        }
        guard let candidates = referenceImages[style], let random = candidates.randomElement() else {
            return nil
        }
        DispatchQueue.main.async {
            referenceImageNames[style] = random
        }
        return random
    }

    private func fieldDisplayName(_ field: SlateField) -> String {
        switch field {
        case .name: return "Name"
        case .height: return "Height"
        case .location: return "Location"
        case .localHire: return "Local Hire"
        case .unionStatus: return "Union"
        case .representation: return "Representation"
        case .contact: return "Contact"
        }
    }
}

// MARK: - Script Mode Editor

private struct SlateScriptModeEditor: View {
    @Binding var previewScript: String
    @Binding var mode: SlatePromptMode
    @Binding var customScript: String
    @Binding var clearCustomDraft: Bool
    let autoScript: String
    let isFocused: FocusState<Bool>.Binding
    let theme: STSTheme
    @State private var showDraftClearedToast = false
    @State private var toastDismissWorkItem: DispatchWorkItem?

    var body: some View {
        ZStack(alignment: .top) {
            content

            if showDraftClearedToast {
                draftClearedToast
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Slate Script Preview")
                .font(Theme.Font.headline)
                .foregroundStyle(theme.textPrimary)

            Picker("Mode", selection: $mode) {
                Text("Auto").tag(SlatePromptMode.auto)
                Text("Custom").tag(SlatePromptMode.custom)
            }
            .pickerStyle(.segmented)
            .tint(theme.primaryAccent)

            statusLine

            if mode == .auto {
                Text(autoScript.isEmpty ? "Auto script will appear here." : autoScript)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(theme.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(cardBackground)
                    .overlay(cardStroke)
            } else {
                ZStack(alignment: .topLeading) {
                    if customScript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("Type your custom slate script.")
                            .font(.body)
                            .foregroundStyle(theme.textSecondary)
                            .padding(18)
                    }
                    TextEditor(text: $customScript)
                        .focused(isFocused)
                        .font(.body)
                        .foregroundStyle(theme.textPrimary)
                        .padding(12)
                        .toolbar {
                            ToolbarItemGroup(placement: .keyboard) {
                                Spacer()
                                Button {
                                    isFocused.wrappedValue = false
                                } label: {
                                    Image(systemName: "checkmark")
                                }
                                .accessibilityLabel("Dismiss Keyboard")
                            }
                        }
                }
                .frame(minHeight: 140)
                .background(cardBackground)
                .overlay(cardStroke)
            }

            footerActions
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            syncPreview()
        }
        .onChange(of: mode, initial: false) { _, newMode in
            if newMode == .auto {
                isFocused.wrappedValue = false
                syncPreview()
            } else {
                clearCustomDraft = false
                if customScript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    customScript = autoScript
                }
                syncPreview()
            }
        }
        .onChange(of: customScript, initial: false) { _, newValue in
            if !newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                clearCustomDraft = false
            }
            if mode == .custom {
                syncPreview()
            }
        }
        .onChange(of: autoScript, initial: false) { _, _ in
            syncPreview()
        }
    }

    private var statusLine: some View {
        HStack(spacing: 8) {
            Image(systemName: statusIconName)
                .foregroundStyle(theme.primaryAccent)

            Text(statusText)
                .font(.footnote)
                .foregroundStyle(theme.textSecondary)

            Spacer(minLength: 0)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(theme.cardBackground.opacity(0.9))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(theme.cardStroke.opacity(0.35), lineWidth: 1)
        )
    }

    private var statusText: String {
        switch mode {
        case .auto:
            return "Auto stays synced to profile and wizard changes."
        case .custom:
            return "Custom overrides auto for this project session."
        }
    }

    private var statusIconName: String {
        switch mode {
        case .auto: return "arrow.triangle.2.circlepath"
        case .custom: return "pencil.line"
        }
    }

    private var footerActions: some View {
        HStack(spacing: 12) {
            if mode == .custom {
                Button("Reset to Auto") {
                    customScript = autoScript
                    clearCustomDraft = false
                    syncPreview()
                }
                .font(.footnote.weight(.semibold))
                .foregroundStyle(theme.primaryAccent)
            }

            if customScript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
                Button("Clear") {
                    customScript = ""
                    clearCustomDraft = false
                    triggerDraftClearedToast()
                    syncPreview()
                }
                .font(.footnote.weight(.semibold))
                .foregroundStyle(theme.textSecondary)
            }

            Spacer(minLength: 0)

            if mode == .custom {
                Text("\(customScript.count) chars")
                    .font(.footnote)
                    .foregroundStyle(theme.textSecondary)
            }
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(theme.cardBackground.opacity(0.95))
    }

    private var cardStroke: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .stroke(theme.cardStroke.opacity(0.4), lineWidth: 1)
    }

    private var draftClearedToast: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(theme.primaryAccent)

            Text("Custom draft cleared")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(theme.textPrimary)

            Spacer(minLength: 0)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(theme.cardBackground.opacity(0.95))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(theme.cardStroke.opacity(0.4), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 6)
        .padding(.top, 8)
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity)
    }

    private func triggerDraftClearedToast() {
        toastDismissWorkItem?.cancel()
        withAnimation(.easeInOut(duration: 0.2)) {
            showDraftClearedToast = true
        }
        let workItem = DispatchWorkItem {
            withAnimation(.easeInOut(duration: 0.2)) {
                showDraftClearedToast = false
            }
        }
        toastDismissWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6, execute: workItem)
    }

    private func syncPreview() {
        let resolved: String
        if mode == .custom {
            resolved = customScript.slateTrimmedNonEmpty ?? autoScript
        } else {
            resolved = autoScript
        }
        if previewScript != resolved {
            previewScript = resolved
        }
    }
}
