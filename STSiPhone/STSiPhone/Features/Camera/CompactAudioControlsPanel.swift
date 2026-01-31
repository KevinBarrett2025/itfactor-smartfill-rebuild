import SwiftUI
import AVFoundation

struct CompactAudioControlsPanel: View {
    @ObservedObject var engine: CameraEngine  // Keep for compatibility
    @Binding var isVisible: Bool
    @ObservedObject var audio = STSAudioSubsystem.shared
    @Binding var showInfoPopover: Bool

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 12) {
            // Dismiss handle/X button on top left
            HStack {
                Button(action: { withAnimation { isVisible = false } }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 19, weight: .bold))
                        .foregroundColor(.white)
                }
                
                // Input refresh button
                Button(action: {
                    audio.refreshInputs()
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
                
                Spacer()
            }

            // Audio input picker section
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "mic.fill")
                        .font(.caption)
                        .foregroundColor(.blue)
                    Text("Audio Input")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.9))
                    Spacer()
                    Button(action: { withAnimation { showInfoPopover.toggle() } }) {
                        Image(systemName: "info.circle")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text("Active:")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.7))
                        Text(audio.activeInputName)
                            .font(.caption2.weight(.semibold))
                            .foregroundColor(.white)
                        if audio.isSelectionPendingApply {
                            Text("Applies next take")
                                .font(.caption2.weight(.semibold))
                                .foregroundColor(.yellow)
                        }
                    }

                    if shouldShowSelectedRow {
                        HStack(spacing: 6) {
                            Text("Selected:")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.7))
                            Text(selectedInputName)
                                .font(.caption2.weight(.semibold))
                                .foregroundColor(.white)
                            if !audio.isSelectionPendingApply {
                                Text("Applying…")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundColor(.white.opacity(0.75))
                            }
                        }
                    }
                }

                Picker("Input", selection: Binding<String?>(
                    get: { audio.preferredInputUID },
                    set: { try? audio.setPreferredInput(uid: $0) }
                )) {
                    Text("Automatic").tag(String?.none)
                    ForEach(audio.availableInputs, id: \.uid) { port in
                        Text("\(label(for: port))").tag(Optional(port.uid))
                    }
                }
                .pickerStyle(.menu)
                .accentColor(.white)

                Text(audio.currentRouteSummary)
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.7))
            }

            // Audio level meter
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "waveform")
                        .font(.caption2)
                        .foregroundColor(.green)
                    Text("Level")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.7))
                    Spacer()
                    Text("\(Int(meterLevel)) dB")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.7))
                }
                
                AudioLevelBar(avg: meterLevel, peak: meterLevel)
                    .frame(height: 8)
            }
        }
        .padding(14)
        .background(.ultraThinMaterial.opacity(0.93))
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.white.opacity(0.22), lineWidth: 1)
            )
            .shadow(radius: 7)
            .padding(.bottom, 65)
            .padding(.leading, 15)
            .frame(maxWidth: 200)
            .animation(.easeInOut(duration: 0.21), value: isVisible)
            .onChange(of: isVisible, initial: false) { _, newValue in
                if !newValue { showInfoPopover = false }
            }

            if showInfoPopover {
                callout(text: "Tap the gear on the main page -> Audio to select mic quality. Mic changes apply automatically.")
                    .offset(x: -6, y: -10)
            }
        }
    }

    @ViewBuilder
    private func callout(text: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(text)
                .font(.caption)
                .foregroundColor(.white)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.black.opacity(0.8))
        )
        .overlay(alignment: .topTrailing) {
            Triangle()
                .fill(Color.black.opacity(0.8))
                .frame(width: 14, height: 8)
                .offset(x: -12, y: -8)
        }
    }
    
    private func label(for port: AVAudioSessionPortDescription) -> String {
        let type = port.portType.rawValue.replacingOccurrences(of: "AVAudioSessionPort", with: "")
        return "\(port.portName) (\(type))"
    }

    private var shouldShowSelectedRow: Bool {
        guard let preferred = audio.preferredInputUID else { return false }
        return preferred != audio.activeInputUID || audio.isSelectionPendingApply
    }

    private var selectedInputName: String {
        guard let preferred = audio.preferredInputUID else { return "Automatic" }
        if let port = audio.availableInputs.first(where: { $0.uid == preferred }) {
            return port.portName
        }
        return "Unknown"
    }

    private var meterLevel: Float {
        let level = engine.audioLevel
        if level.isNaN || level.isInfinite {
            return -80
        }
        return level
    }
}

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
