import SwiftUI

struct ExternalAudioMeter: View {
    @ObservedObject var engine: CameraEngine  // Keep for compatibility
    @Binding var isVisible: Bool
    
    var body: some View {
        if isVisible {
            HStack(spacing: 4) {
                // Compact level indicator with 10 segments
                HStack(spacing: 1) {
                    ForEach(0..<10, id: \.self) { i in
                        Rectangle()
                            .fill(segmentColor(for: i))
                            .frame(width: 3, height: 12)
                            .opacity(i < compactSegmentCount ? 1.0 : 0.3)
                            .cornerRadius(1)
                    }
                }
                .animation(.linear(duration: 0.05), value: meterLevel)
                
                // dB reading
                Text("\(Int(meterLevel))")
                    .font(.caption2)
                    .foregroundColor(.white)
                    .frame(width: 24, alignment: .trailing)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(.ultraThinMaterial.opacity(0.8))
            .cornerRadius(8)
            .transition(.move(edge: .leading).combined(with: .opacity))
            .onTapGesture {
                withAnimation { isVisible = false }
            }
        }
    }
    
    private var compactSegmentCount: Int {
        // Guard against NaN values that cause CoreGraphics errors
        guard !meterLevel.isNaN && !meterLevel.isInfinite else {
            return 0
        }
        
        // Convert dB (-60 to 0) to compact segment count (0 to 10)
        let percentage = (meterLevel + 60) / 60
        let clampedPercentage = max(0, min(1, percentage))
        return Int(clampedPercentage * 10)
    }

    private var meterLevel: Float {
        let level = engine.audioLevel
        if level.isNaN || level.isInfinite {
            return -80
        }
        return level
    }
    
    private func segmentColor(for index: Int) -> Color {
        if index < 6 {
            return .green // Normal levels (segments 0-5)
        } else if index < 8 {
            return .orange // Good levels (segments 6-7)
        } else {
            return .red // High levels (segments 8-9)
        }
    }
}
