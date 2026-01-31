import SwiftUI

struct LandscapeEditorLayout: View {
    @ObservedObject var context: EnterpriseEditorContext
    @Binding var showWaveform: Bool
    let containerSize: CGSize
    let videoHeight: CGFloat
    let horizontalPadding: CGFloat
    let onEnterFullscreen: () -> Void
    let onSaveAndExit: () -> Void
    
    var body: some View {
        let availableWidth = containerSize.width - (horizontalPadding * 2)
        let videoWidth = availableWidth * 0.64
        let rightColumnWidth = max(240, availableWidth - videoWidth - 20)
        let matchedHeight = videoHeight + (showWaveform ? 78 : 0)
        
        HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 0) {
                EnterpriseVideoSurface(
                    context: context,
                    showCenterOverlay: showWaveform,
                    targetHeight: videoHeight,
                    waveformToggle: {
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.88)) {
                            showWaveform.toggle()
                        }
                    },
                    waveformActive: showWaveform,
                    fullscreenToggle: {
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.88)) {
                            onEnterFullscreen()
                        }
                    },
                    fullscreenActive: false
                )
                .frame(height: videoHeight)
                
                if showWaveform {
                    WaveformCard(
                        context: context,
                        edgeInsets: EdgeInsets(top: 0, leading: 0, bottom: 8, trailing: 0)
                    )
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
                
                if !showWaveform {
                    HStack {
                        Spacer()
                        PlaybackInlineControls(context: context, buttonSize: 28, spacing: 6, horizontalPadding: 0)
                            .frame(maxWidth: .infinity)
                        Spacer()
                    }
                    .padding(.top, 16)
                }
            }
            .frame(width: videoWidth, height: matchedHeight, alignment: .top)
            
            VStack(alignment: .trailing, spacing: 12) {
                HStack {
                    Spacer()
                    TextToolbarButton(
                        title: "Save & Exit",
                        style: context.hasPendingChanges ? .primary : .secondary
                    ) {
                        onSaveAndExit()
                    }
                }
                Spacer()
                WaveformToggleButton(showWaveform: $showWaveform)
                    .frame(maxWidth: .infinity, alignment: .center)
                Spacer()
                LandscapeTrimControls(context: context)
                    .frame(maxWidth: .infinity)
            }
            .frame(width: rightColumnWidth, height: matchedHeight)
            .padding(.vertical, 16)
            .padding(.horizontal, 14)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.white.opacity(0.02))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(Color.white.opacity(0.06), lineWidth: 1)
                    )
            )
        }
        .padding(.horizontal, horizontalPadding)
    }
}
