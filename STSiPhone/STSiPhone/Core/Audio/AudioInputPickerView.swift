import SwiftUI
import AVFoundation

struct AudioInputPickerView: View {
    @ObservedObject private var routing = STSAudioSubsystem.shared
    @ObservedObject private var levels = STSAudioManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "mic.fill")
                Text("Audio Input")
                Spacer()
                Button {
                    routing.refreshInputs()
                } label: { Image(systemName: "arrow.clockwise") }
            }

            Picker("Input", selection: Binding<String?>(
                get: { routing.preferredInputUID },
                set: { try? routing.setPreferredInput(uid: $0) }
            )) {
                Text("Automatic").tag(String?.none)
                ForEach(routing.availableInputs, id: \.uid) { port in
                    Text("\(label(for: port))").tag(Optional(port.uid))
                }
            }
            .pickerStyle(.menu)

            Text(routing.currentRouteSummary)
                .font(.footnote)
                .foregroundStyle(.secondary)

            AudioLevelBar(avg: levels.avgdB, peak: levels.peakdB)
                .frame(height: 8)
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func label(for port: AVAudioSessionPortDescription) -> String {
        let type = port.portType.rawValue.replacingOccurrences(of: "AVAudioSessionPort", with: "")
        return "\(port.portName) (\(type))"
    }
}
