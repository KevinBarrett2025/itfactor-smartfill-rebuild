import SwiftUI

struct AudioSettingsView: View {
    @State private var selectedQuality = AudioSettings.quality
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Section("Audio Quality") {
                    Picker("Audio Quality", selection: $selectedQuality) {
                        ForEach(AudioQuality.allCases, id: \.self) { quality in
                            Text(quality.displayName).tag(quality)
                        }
                    }
                    .pickerStyle(.inline)
                    .onChange(of: selectedQuality, initial: false) { _, newValue in
                        AudioSettings.quality = newValue
                    }
                    Text("Choose the default microphone encoding quality for new recordings. Stereo, 48 kHz.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                }
                Section("Notes") {
                    Text("Higher quality increases file size. You can adjust camera quality separately in Camera Settings.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 4)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Audio Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .onAppear {
            selectedQuality = AudioSettings.quality
        }
    }
}

#Preview {
    AudioSettingsView()
}
