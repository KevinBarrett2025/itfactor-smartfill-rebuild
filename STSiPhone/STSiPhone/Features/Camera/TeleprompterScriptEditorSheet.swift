import SwiftUI

struct TeleprompterScriptEditorSheet: View {
    let autoScript: String
    let isRecording: Bool
    let isLandscape: Bool
    let theme: STSTheme
    let onSave: (SlatePromptMode, String, Bool) -> Void
    let onAutoSave: (SlatePromptMode, String) -> Void
    let onCancel: () -> Void

    @State private var mode: SlatePromptMode
    @State private var customDraft: String
    @State private var suppressNextAutoSave = false
    @State private var didRequestClearCustomDraft = false
    @State private var showDraftClearedToast = false
    @State private var toastDismissWorkItem: DispatchWorkItem?
    @FocusState private var isFocused: Bool

    init(
        autoScript: String,
        initialMode: SlatePromptMode,
        initialCustomScript: String?,
        isRecording: Bool,
        isLandscape: Bool,
        theme: STSTheme,
        onSave: @escaping (SlatePromptMode, String, Bool) -> Void,
        onAutoSave: @escaping (SlatePromptMode, String) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.autoScript = autoScript
        self.isRecording = isRecording
        self.isLandscape = isLandscape
        self.theme = theme
        self.onSave = onSave
        self.onAutoSave = onAutoSave
        self.onCancel = onCancel
        _mode = State(initialValue: initialMode)
        _customDraft = State(initialValue: initialCustomScript ?? autoScript)
    }

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
        Group {
            if isLandscape {
                landscapeRotatePrompt()
            } else {
                portraitLayout(isLandscape: false)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: mode, initial: false) { _, newMode in
            if newMode == .auto {
                isFocused = false
                guard !isRecording else { return }
                onAutoSave(newMode, customDraft)
            } else {
                didRequestClearCustomDraft = false
                if customDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    suppressNextAutoSave = true
                    customDraft = autoScript
                }
            }
        }
        .onChange(of: customDraft, initial: false) { _, newValue in
            if suppressNextAutoSave {
                suppressNextAutoSave = false
                return
            }
            if !newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                didRequestClearCustomDraft = false
            }
            guard !isRecording, mode == .custom else { return }
            onAutoSave(mode, newValue)
        }
    }

    private var saveDisabled: Bool {
        if isRecording { return true }
        if mode == .custom {
            return customDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return false
    }

    private func handleSave() {
        onSave(mode, customDraft, didRequestClearCustomDraft)
    }

    private func portraitLayout(isLandscape: Bool) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                portraitHeader
                    .frame(maxWidth: .infinity)
                modePicker
                statusLine
                scriptCard(isLandscape: isLandscape)
                footerActions
                actionButtons(isLandscape: false)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .padding(.bottom, 400)
        }
        .scrollDismissesKeyboard(.interactively)
        .scrollIndicators(.hidden)
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }

    private func landscapeRotatePrompt() -> some View {
        VStack(spacing: 16) {
            Image(systemName: "iphone")
                .font(.system(size: 36, weight: .semibold))
                .foregroundStyle(theme.primaryAccent)

            Text("Rotate to Portrait")
                .font(Theme.Font.title)
                .foregroundStyle(theme.textPrimary)

            Text("To edit the slate script, please rotate your device to portrait orientation.")
                .font(.footnote)
                .foregroundStyle(theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)

            Button("Close") {
                onCancel()
            }
            .buttonStyle(.bordered)
            .tint(theme.primaryAccent)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var portraitHeader: some View {
        VStack(spacing: 10) {
            Image("AppLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 72, height: 72)
                .shadow(radius: 8, y: 4)

            Text("Slate Script")
                .font(Theme.Font.title)
                .foregroundStyle(theme.textPrimary)

            Text("Keep your teleprompter synced to your profile or tailor a custom version.")
                .font(Theme.Font.body)
                .foregroundStyle(theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
        }
    }

    private var modePicker: some View {
        Picker("Mode", selection: $mode) {
            Text("Auto").tag(SlatePromptMode.auto)
            Text("Custom").tag(SlatePromptMode.custom)
        }
        .pickerStyle(.segmented)
        .tint(theme.primaryAccent)
        .disabled(isRecording)
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
        .padding(12)
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
        if isRecording {
            return "Editing is locked while recording."
        }
        switch mode {
        case .auto:
            return "Auto stays synced to profile and wizard changes."
        case .custom:
            return "Custom overrides auto for this project session."
        }
    }

    private var statusIconName: String {
        if isRecording { return "lock.fill" }
        switch mode {
        case .auto: return "arrow.triangle.2.circlepath"
        case .custom: return "pencil.line"
        }
    }

    private func scriptCard(isLandscape: Bool) -> some View {
        let minHeight: CGFloat = isLandscape ? 180 : 200
        return VStack(alignment: .leading, spacing: 10) {
            Text(mode == .auto ? "Auto Script" : "Custom Script")
                .font(Theme.Font.headline)
                .foregroundStyle(theme.textPrimary)

            if mode == .auto {
                Text(autoScript.isEmpty ? "Auto script will appear here." : autoScript)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(theme.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(cardBackground)
                    .overlay(cardStroke)
            } else {
                ZStack(alignment: .topLeading) {
                    if customDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("Type your custom slate script.")
                            .font(.body)
                            .foregroundStyle(theme.textSecondary)
                            .padding(18)
                    }
                    TextEditor(text: $customDraft)
                        .focused($isFocused)
                        .font(.body)
                        .foregroundStyle(theme.textPrimary)
                        .padding(12)
                        .disabled(isRecording)
                        .toolbar {
                            ToolbarItemGroup(placement: .keyboard) {
                                Spacer()
                                Button {
                                    isFocused = false
                                } label: {
                                    Image(systemName: "checkmark")
                                }
                                .accessibilityLabel("Dismiss Keyboard")
                            }
                        }
                }
                .frame(minHeight: minHeight)
                .background(cardBackground)
                .overlay(cardStroke)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var footerActions: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                if mode == .custom {
                    Button("Reset to Auto") {
                        customDraft = autoScript
                        didRequestClearCustomDraft = false
                    }
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(theme.primaryAccent)
                    .disabled(isRecording)
                }

                if customDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
                    Button("Clear") {
                        customDraft = ""
                        didRequestClearCustomDraft = false
                        triggerDraftClearedToast()
                    }
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(theme.textSecondary)
                    .disabled(isRecording)
                }

                Spacer(minLength: 0)

                if mode == .custom {
                    Text("\(customDraft.count) chars")
                        .font(.footnote)
                        .foregroundStyle(theme.textSecondary)
                }
            }
        }
    }

    private func actionButtons(isLandscape: Bool) -> some View {
        Group {
            if isLandscape {
                VStack(spacing: 10) {
                    Button("Cancel") {
                        onCancel()
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)

                    Button("Save") {
                        handleSave()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(saveDisabled)
                    .frame(maxWidth: .infinity)
                }
            } else {
                HStack {
                    Button("Cancel") {
                        onCancel()
                    }
                    .buttonStyle(.bordered)

                    Spacer(minLength: 12)

                    Button("Save") {
                        handleSave()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(saveDisabled)
                }
            }
        }
        .tint(theme.primaryAccent)
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
}
