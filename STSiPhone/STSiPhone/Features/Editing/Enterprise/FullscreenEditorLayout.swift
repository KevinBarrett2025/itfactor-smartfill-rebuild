import SwiftUI

struct FullscreenEditorLayout: View {
    @ObservedObject var context: EnterpriseEditorContext
    @Binding var showWaveform: Bool
    let safeAreaInsets: EdgeInsets
    let onExit: () -> Void
    
    var body: some View {
        GeometryReader { geo in
            let baseSize = geo.size
            let needsRotation = baseSize.height > baseSize.width
            let landscapeWidth = max(baseSize.width, baseSize.height)
            let landscapeHeight = min(baseSize.width, baseSize.height)
            let orientedSize = CGSize(width: landscapeWidth, height: landscapeHeight)
            let orientedInsets = rotatedInsets(from: safeAreaInsets, needsRotation: needsRotation)
            
            let content = FullscreenEditorContent(
                context: context,
                showWaveform: $showWaveform,
                size: orientedSize,
                safeAreaInsets: orientedInsets,
                onExit: onExit
            )
            
            ZStack {
                Color.black.ignoresSafeArea()
                if needsRotation {
                    content
                        .frame(width: orientedSize.width, height: orientedSize.height)
                        .rotationEffect(.degrees(90))
                        .frame(width: baseSize.width, height: baseSize.height)
                } else {
                    content
                        .frame(width: baseSize.width, height: baseSize.height)
                }
            }
        }
        .ignoresSafeArea()
    }
    
    private func rotatedInsets(from insets: EdgeInsets, needsRotation: Bool) -> EdgeInsets {
        guard needsRotation else { return insets }
        return EdgeInsets(
            top: insets.leading,
            leading: insets.bottom,
            bottom: insets.trailing,
            trailing: insets.top
        )
    }
}

private struct FullscreenEditorContent: View {
    @ObservedObject var context: EnterpriseEditorContext
    @Binding var showWaveform: Bool
    let size: CGSize
    let safeAreaInsets: EdgeInsets
    let onExit: () -> Void
    
    var body: some View {
        ZStack(alignment: .bottom) {
            EnterpriseVideoSurface(
                context: context,
                showCenterOverlay: false,
                targetHeight: size.height,
                waveformToggle: {
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.88)) {
                        showWaveform.toggle()
                    }
                },
                waveformActive: showWaveform,
                fullscreenToggle: {
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.88)) {
                        onExit()
                    }
                },
                fullscreenActive: true,
                contentMode: .fit,
                showsTrimOverlay: false,
                cornerRadius: 0,
                overlayInsets: EdgeInsets(
                    top: safeAreaInsets.top + 20,
                    leading: safeAreaInsets.leading + 24,
                    bottom: 0,
                    trailing: safeAreaInsets.trailing + 24
                ),
                hideOverlayButtonsWhilePlaying: true
            )
            .frame(width: size.width, height: size.height)
            .clipped()
            
            VStack(spacing: 12) {
                HStack {
                    Spacer()
                    VStack(alignment: .trailing, spacing: 10) {
                        IconOnlyButton(systemName: "arrow.uturn.backward") {
                            context.performUndoAction()
                        }
                        TimelineChipButton(
                            title: "Set In",
                            value: context.inPointTimecode,
                            icon: "arrow.right.to.line",
                            minWidth: 106
                        ) {
                            context.setInPointToPlayhead()
                        }
                        TimelineChipButton(
                            title: "Set Out",
                            value: context.outPointTimecode,
                            icon: "arrow.left.to.line",
                            minWidth: 106
                        ) {
                            context.setOutPointToPlayhead()
                        }
                        WaveformOverlayButton(isActive: showWaveform, action: {
                            withAnimation(.spring(response: 0.45, dampingFraction: 0.88)) {
                                showWaveform.toggle()
                            }
                        })
                    }
                }
                
                VideoPlaybackOverlay(context: context)
                    .opacity(context.isPlaying ? 0 : 1)
                    .allowsHitTesting(!context.isPlaying)
                    .animation(.easeInOut(duration: 0.2), value: context.isPlaying)
                
                OverlayTrimTrack(context: context)
                
                if showWaveform {
                    FullscreenWaveformOverlay(context: context)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
                
            }
            .padding(.horizontal, 32)
            .padding(.bottom, safeAreaInsets.bottom + 28)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if context.isPlaying {
                context.togglePlayback()
            }
        }
        .frame(width: size.width, height: size.height)
    }
}
