import SwiftUI

struct PortraitEditorLayout: View {
    @ObservedObject var context: EnterpriseEditorContext
    @Binding var showWaveform: Bool
    let videoHeight: CGFloat
    let horizontalPadding: CGFloat
    let onEnterFullscreen: () -> Void
    let onSaveAndExit: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(spacing: showWaveform ? 8 : 0) {
                EnterpriseVideoSurface(
                    context: context,
                    showCenterOverlay: false,
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
                        waveformHeight: 27
                    )
                    .frame(maxWidth: .infinity)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            
            VStack(alignment: .leading, spacing: 10) {
                WaveformToggleButton(showWaveform: $showWaveform)
                CompactTimelineControls(
                    context: context,
                    showsPlaybackInCard: true,
                    onSaveAndExit: onSaveAndExit
                )
            }
        }
        .padding(.horizontal, horizontalPadding)
    }
}
