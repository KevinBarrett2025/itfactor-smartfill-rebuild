import SwiftUI

struct EnterpriseEditorView: View {
    @ObservedObject var context: EnterpriseEditorContext
    @State private var showWaveform = false
    @State private var isFullscreenPreview = false
    @State private var showSavePrompt = false
    
    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let safeInsets = geometry.safeAreaInsets
            let isLandscape = size.width > size.height
            let videoHeight = computeVideoHeight(for: size, isLandscape: isLandscape)
            let useFullscreen = isFullscreenPreview || isLandscape
            
            ZStack(alignment: .topLeading) {
                background
                
                // Push main content down so the close button sits above it.
                VStack(spacing: 0) {
                    if !useFullscreen {
                        Spacer()
                            .frame(height: safeInsets.top + 44)
                    }
                    
                    if useFullscreen {
                        FullscreenEditorLayout(
                            context: context,
                            showWaveform: $showWaveform,
                            safeAreaInsets: safeInsets,
                            onExit: { isFullscreenPreview = false }
                        )
                        .transition(.opacity.combined(with: .scale))
                        .zIndex(1)
                    } else {
                        VStack(spacing: 18) {
                            PortraitEditorLayout(
                                context: context,
                                showWaveform: $showWaveform,
                                videoHeight: videoHeight,
                                horizontalPadding: 20,
                                onEnterFullscreen: { isFullscreenPreview = true },
                                onSaveAndExit: saveAndExit
                            )
                            Spacer(minLength: 0)
                        }
                        .padding(.bottom, max(20, safeInsets.bottom + 12))
                    }
                }
                
                // Safe-area header
                if !useFullscreen {
                    HStack {
                        CloseButton { handleCloseTapped() }
                        Spacer()
                    }
                    .padding(.top, safeInsets.top + 10)
                    .padding(.leading, safeInsets.leading + 16)
                    .zIndex(2)
                }
            }
            .frame(width: size.width, height: size.height)
            .confirmationDialog("Save changes before closing?", isPresented: $showSavePrompt, titleVisibility: .visible) {
                Button("Save", role: .none) {
                    context.saveEdits()
                    context.requestClose(reason: .saved)
                }
                Button("Discard", role: .destructive) {
                    context.requestClose(reason: .discarded)
                }
                Button("Cancel", role: .cancel) { }
            }
        }
    }
    
    private var background: some View {
        LinearGradient(
            colors: [Color.black.opacity(0.95), Color(red: 0.07, green: 0.08, blue: 0.15)],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
    
    private func handleCloseTapped() {
        if context.hasPendingChanges || context.hasUnsavedChanges {
            showSavePrompt = true
        } else {
            context.requestClose(reason: .cancelled)
        }
    }
    
    private func computeVideoHeight(for size: CGSize, isLandscape: Bool) -> CGFloat {
        let targetFraction: CGFloat = isLandscape ? 0.62 : 0.55
        let clamped = min(size.height * targetFraction, max(220, size.height - 160))
        return max(220, clamped)
    }
    
    private func saveAndExit() {
        context.saveEdits()
        context.requestClose(reason: .saved)
    }
}

// MARK: - Close Button

struct CloseButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: 14, weight: .semibold))
                .padding(10)
                .background(Circle().fill(Color.white.opacity(0.08)))
                .overlay(Circle().stroke(Color.white.opacity(0.12), lineWidth: 1))
                .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
    }
}
