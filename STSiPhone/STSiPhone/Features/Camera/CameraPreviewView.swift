import SwiftUI
import AVFoundation

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession
    @Binding var previewLayerOut: AVCaptureVideoPreviewLayer?

    func makeUIView(context: Context) -> Preview {
        let view = Preview()
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspect
        view.backgroundColor = .black
        view.videoPreviewLayer.backgroundColor = UIColor.black.cgColor
        
        // FIXED: Only set initial orientation once in makeUIView
        view.updateOrientationOnce()

        DispatchQueue.main.async {
            previewLayerOut = view.videoPreviewLayer
        }
        
        return view
    }

    func updateUIView(_ uiView: Preview, context: Context) {
        // FIXED: Remove redundant orientation updates to break the loop
        // Only update if the session has changed (which it shouldn't in practice)
        if uiView.videoPreviewLayer.session != session {
            uiView.videoPreviewLayer.session = session
            DispatchQueue.main.async {
                previewLayerOut = uiView.videoPreviewLayer
            }
        }
    }

    final class Preview: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var videoPreviewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
        
        private var lastOrientation: UIDeviceOrientation?
        private var orientationUpdateTimer: Timer?
        
        override func layoutSubviews() {
            super.layoutSubviews()
            // FIXED: Use throttled orientation updates instead of immediate updates
            scheduleOrientationUpdate()
        }
        
        private func scheduleOrientationUpdate() {
            // Cancel any existing timer
            orientationUpdateTimer?.invalidate()
            
            // Schedule a single update after a short delay to batch multiple layout calls
            orientationUpdateTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: false) { [weak self] _ in
                self?.updateOrientationIfNeeded()
            }
        }
        
        func updateOrientationOnce() {
            // FIXED: Initial setup - force one orientation update
            updateOrientation()
        }
        
        private func updateOrientationIfNeeded() {
            let currentOrientation = UIDevice.current.orientation
            
            // FIXED: Only update if orientation actually changed
            guard currentOrientation != lastOrientation else {
                return
            }
            
            lastOrientation = currentOrientation
            updateOrientation()
        }
        
        
        // FRONT CAMERA FIX: Detect current camera position from session inputs
        private func getCurrentCameraPosition() -> AVCaptureDevice.Position {
            guard let session = videoPreviewLayer.session else {
                return .back // Default fallback
            }
            
            // Find video input device from session inputs
            for input in session.inputs {
                if let deviceInput = input as? AVCaptureDeviceInput,
                   deviceInput.device.hasMediaType(.video) {
                    return deviceInput.device.position
                }
            }
            
            return .back // Default fallback if no video input found
        }
        private func updateOrientation() {
            guard let connection = videoPreviewLayer.connection else {
                print("⚠️ No video preview connection available")
                return
            }
            
            let deviceOrientation = UIDevice.current.orientation
            
            // FRONT CAMERA FIX: Use camera position-aware rotation angles
            let cameraPosition = getCurrentCameraPosition()
            let rotationAngle: CGFloat
            
            if cameraPosition == .front {
                // Front camera needs different angles to match CameraEngine recording
                switch deviceOrientation {
                case .portrait:
                    rotationAngle = 90   // Front camera portrait (CORRECTED: same as back camera)
                    print("📱 Setting FRONT camera rotation angle: 90° (Portrait)")
                case .portraitUpsideDown:
                    rotationAngle = 90   // Front camera portrait upside down
                    print("📱 Setting FRONT camera rotation angle: 90° (Portrait Upside Down)")
                case .landscapeLeft:
                    rotationAngle = 180  // Front camera landscape left (matches CameraEngine)
                    print("📱 Setting FRONT camera rotation angle: 180° (Landscape Left)")
                case .landscapeRight:
                    rotationAngle = 0    // Front camera landscape right (matches CameraEngine)
                    print("📱 Setting FRONT camera rotation angle: 0° (Landscape Right)")
                default:
                    rotationAngle = 90   // Default to front camera portrait (CORRECTED)
                    print("📱 Using FRONT camera default rotation angle: 90° (Device orientation: (deviceOrientation.rawValue))")
                }
            } else {
                // Back camera uses original working angles
                switch deviceOrientation {
                case .portrait:
                    rotationAngle = 90
                    print("📱 Setting BACK camera rotation angle: 90° (Portrait)")
                case .portraitUpsideDown:
                    rotationAngle = 270
                    print("📱 Setting BACK camera rotation angle: 270° (Portrait Upside Down)")
                case .landscapeLeft:
                    rotationAngle = 0    // Back camera landscape left
                    print("📱 Setting BACK camera rotation angle: 0° (Landscape Left)")
                case .landscapeRight:
                    rotationAngle = 180  // Back camera landscape right
                    print("📱 Setting BACK camera rotation angle: 180° (Landscape Right)")
                default:
                    rotationAngle = 90   // Default to back camera portrait
                    print("📱 Using BACK camera default rotation angle: 90° (Device orientation: (deviceOrientation.rawValue))")
                }
            }
            
            // UPDATED: Check if rotation angle is supported before setting
            if connection.isVideoRotationAngleSupported(rotationAngle) {
                if connection.videoRotationAngle != rotationAngle {
                    connection.videoRotationAngle = rotationAngle
                    videoPreviewLayer.setNeedsLayout()
                }
            } else if #available(iOS 17.0, *) {
                // rotationAngle path already failed; nothing further for iOS 17+
            } else {
                if connection.isVideoOrientationSupported, let fallback = avCaptureOrientation(for: deviceOrientation) {
                    if connection.videoOrientation != fallback {
                        connection.videoOrientation = fallback
                    }
                } else {
                    print("⚠️ Video rotation angle \(rotationAngle)° not supported by preview connection")
                }
            }
        }

        /// Legacy helper for mapping device orientation to `AVCaptureVideoOrientation` (deprecated in iOS 17).
        /// Retained for pre-iOS-17 preview configuration until rotation coordinator migration.
        @available(iOS, introduced: 11.0, deprecated: 17.0, message: "Use AVCaptureDeviceRotationCoordinator for iOS 17+")
        private func avCaptureOrientation(for deviceOrientation: UIDeviceOrientation) -> AVCaptureVideoOrientation? {
            switch deviceOrientation {
            case .portrait: return .portrait
            case .portraitUpsideDown: return .portraitUpsideDown
            case .landscapeLeft: return .landscapeRight   // device left, home on right
            case .landscapeRight: return .landscapeLeft   // device right, home on left
            default: return nil
            }
        }
        
        deinit {
            orientationUpdateTimer?.invalidate()
        }
    }
}
