import SwiftUI

struct AudioLevelBar: View {
    let avg: Float  // dBFS
    let peak: Float // dBFS

    private func normalized(_ db: Float) -> CGFloat {
        // Map -60..0 dB to 0..1
        let clamped = max(-60, min(0, db))
        return CGFloat((clamped + 60) / 60.0)
    }

    var body: some View {
        GeometryReader { geo in
            let wAvg = geo.size.width * normalized(avg)
            let wPeak = geo.size.width * normalized(peak)

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4).fill(Color.secondary.opacity(0.2))
                // avg bar
                RoundedRectangle(cornerRadius: 4)
                    .fill(color(for: avg))
                    .frame(width: max(2, wAvg))
                // peak marker
                Rectangle()
                    .fill(.white.opacity(0.9))
                    .frame(width: 2, height: geo.size.height)
                    .offset(x: max(0, wPeak - 1))
            }
        }
    }

    private func color(for db: Float) -> Color {
        if db >= -12 { return .red }
        if db >= -18 { return .yellow }
        return .green
    }
}
