import SwiftUI

struct CameraSettingsView: View {
    @State private var mirrorFrontCamera = CameraSettings.mirrorFrontCameraEnabled
    @State private var selectedQuality = CameraSettings.recordingQuality
    @AppStorage("WatchRemote.showHUDMaster") private var showWatchHUDMaster = true
    @AppStorage("WatchRemote.showHUD") private var showWatchHUD = true
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            List {
                Section("Recording Quality") {
                    Picker("Recording Quality", selection: $selectedQuality) {
                        ForEach(RecordingQuality.allCases, id: \.self) { quality in
                            Text(quality.displayName).tag(quality)
                        }
                    }
                    .pickerStyle(.inline)
                    .onChange(of: selectedQuality, initial: false) { _, newValue in
                        CameraSettings.recordingQuality = newValue
                    }
                    Text("Choose the default video resolution used when recording.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                }

                Section("Camera Controls") {
                    Toggle(isOn: $mirrorFrontCamera) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Mirror Front Camera")
                                .font(.body)
                            Text("Match the preview style used by FaceTime and selfie cameras.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .toggleStyle(SwitchToggleStyle(tint: Theme.primary))
                    .onChange(of: mirrorFrontCamera, initial: false) { _, newValue in
                        CameraSettings.mirrorFrontCameraEnabled = newValue
                    }

                    if showWatchHUDMaster {
                        Toggle(isOn: $showWatchHUD) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Show Watch HUD")
                                    .font(.body)
                                Text("Display Apple Watch connection badge in camera view.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .toggleStyle(SwitchToggleStyle(tint: Theme.primary))
                    } else {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Watch HUD")
                                .font(.body)
                            Text("Enable from App Settings to manage in camera.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Camera Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .onAppear {
            mirrorFrontCamera = CameraSettings.mirrorFrontCameraEnabled
            selectedQuality = CameraSettings.recordingQuality
        }
    }
}

#Preview {
    CameraSettingsView()
}
