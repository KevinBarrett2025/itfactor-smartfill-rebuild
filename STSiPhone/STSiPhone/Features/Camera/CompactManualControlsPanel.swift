import SwiftUI

struct CompactManualControlsPanel: View {
    @ObservedObject var engine: CameraEngine
    @Binding var isVisible: Bool

    // Accept lock state as binding from parent for persistence / display
    @Binding var isLocked: Bool
    @Binding var showInfoPopover: Bool

    // Modern iPhones support exposure bias controls on both cameras
    private var currentDeviceSupportsManualControls: Bool {
        true
    }

    private var supportsExposureControl: Bool {
        true
    }

    var body: some View {
        VStack {
            Spacer() // Push panel to bottom

            ZStack(alignment: .bottomTrailing) {
                VStack(spacing: 8) {
                    // Top row: Lock, Auto, Close
                    HStack {
                        // Lock button – drives engine lock via parent binding
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isLocked.toggle()
                            }
                        }) {
                            Image(systemName: isLocked ? "lock.fill" : "lock.open")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(isLocked ? .yellow : .gray)
                                .padding(6)
                                .background(
                                    Circle()
                                        .fill(isLocked ? Color.yellow.opacity(0.18) : Color.gray.opacity(0.15))
                                        .overlay(
                                            Circle()
                                                .stroke(isLocked ? Color.yellow.opacity(0.35) : Color.gray.opacity(0.3), lineWidth: 1)
                                        )
                                )
                        }
                        .opacity(currentDeviceSupportsManualControls ? 1.0 : 0.5)
                        .disabled(!currentDeviceSupportsManualControls)

                        Spacer()

                        // Auto button – reset to full auto + clear AE/AF lock
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                // Clear any UI lock state
                                isLocked = false

                                // Return engine to full auto behavior (AF/AE/AWB)
                                engine.unlockAEAF()

                                // Let the engine re-evaluate / normalize exposure & WB
                                engine.autoCorrectCamera()

                                // Reset exposure bias to neutral
                                engine.setExposure(compensation: 0.0)
                            }
                        }) {
                            let autoActive = engine.isAutoMode
                            HStack(spacing: 4) {
                                Image(systemName: "wand.and.stars")
                                    .font(.system(size: 12, weight: .semibold))
                                Text("Auto")
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            .foregroundColor(autoActive ? .blue : .gray)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill((autoActive ? Color.blue : Color.gray).opacity(0.12))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke((autoActive ? Color.blue : Color.gray).opacity(0.3), lineWidth: 1)
                                    )
                            )
                        }
                        .opacity(currentDeviceSupportsManualControls ? 1.0 : 0.7)
                        .disabled(!currentDeviceSupportsManualControls)

                        Spacer()

                        // Close button
                        Button(action: { withAnimation { isVisible = false } }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }

                    // Manual controls: Apple-style brightness bias only
                    if currentDeviceSupportsManualControls {
                        VStack(spacing: 8) {
                            if supportsExposureControl {
                                // Subtle exposure bias slider (old-school brightness control)
                                HStack(spacing: 8) {
                                    Image(systemName: "sun.max")
                                        .font(.caption2)
                                        .foregroundColor(.yellow)
                                        .frame(width: 16)

                                    Slider(
                                        value: Binding(
                                            get: { Double(engine.exposureValue) },
                                            set: { newValue in
                                                engine.setExposure(compensation: Float(newValue))
                                            }
                                        ),
                                        in: -1.5...1.5,
                                        step: 0.05
                                    )
                                    .accentColor(.yellow)

                                    Text(String(format: "%.1f", engine.exposureValue))
                                        .font(.caption2)
                                        .foregroundColor(.white)
                                        .frame(width: 32, alignment: .trailing)
                                        .monospacedDigit()
                                }
                            }

                            HStack(spacing: 8) {
                                Spacer()
                                Text(currentRecordingQualityDescription)
                                    .font(.caption2.weight(.semibold))
                                    .foregroundColor(.white.opacity(0.85))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(Color.white.opacity(0.12), in: Capsule())
                                Button(action: { showInfoPopover.toggle() }) {
                                    Image(systemName: "info.circle")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.8))
                                        .padding(6)
                                        .background(Circle().fill(Color.white.opacity(0.12)))
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        if showInfoPopover {
                            callout(
                                text: "Tap and hold in the preview to lock focus & exposure, then drag the sun slider to adjust brightness. Use Auto to return to full automatic camera behavior."
                            )
                            .offset(x: -8, y: -8)
                        }
                    } else {
                        // Very rare on modern devices
                        VStack(spacing: 8) {
                            HStack {
                                Image(systemName: "info.circle")
                                    .font(.caption2)
                                    .foregroundColor(.orange)
                                Text("Manual controls not available")
                                    .font(.caption2)
                                    .foregroundColor(.white.opacity(0.8))
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial.opacity(0.93))
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.22), lineWidth: 1)
                )
                .shadow(radius: 7)
                .padding(.horizontal, 12)
                .padding(.bottom, 20) // Move to bottom of screen, minimal padding for safe area
                .animation(.easeInOut(duration: 0.21), value: isVisible)
                .onChange(of: isVisible, initial: false) { _, newValue in
                    if !newValue { showInfoPopover = false }
                }
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
                .fill(Color.black.opacity(0.85))
        )
        .overlay(alignment: .bottomTrailing) {
            Triangle()
                .fill(Color.black.opacity(0.85))
                .frame(width: 14, height: 8)
                .offset(x: -8, y: 8)
        }
    }

    private var currentRecordingQualityDescription: String {
        engine.recordingQuality.displayName
    }
}
