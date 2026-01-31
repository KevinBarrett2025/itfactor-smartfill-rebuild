import AVFoundation
import UIKit

/// Utility class for detecting and analyzing video orientation during capture
/// INTEGRATION: Enhanced for SelfTapeStudio capture pipeline
/// UPDATED: iOS 17+ API migration - using videoRotationAngle instead of deprecated AVCaptureVideoOrientation
public class OrientationCapture {
    
    /// Detect video orientation from the current device state and capture session
    /// - Parameters:
    ///   - captureSession: The active AVCaptureSession
    ///   - deviceOrientation: Current UIDevice orientation
    /// - Returns: The detected VideoOrientation for Smart Fill processing
    public static func detectCurrentOrientation(
        from captureSession: AVCaptureSession,
        deviceOrientation: UIDeviceOrientation = UIDevice.current.orientation
    ) -> VideoOrientation {
        
        print("📐 OrientationCapture: Detecting orientation...")
        print("   📱 Device Orientation: \(deviceOrientation.rawValue) (\(deviceOrientationName(deviceOrientation)))")
        
        // Get video connection from the capture session.
        // Prefer AVCaptureVideoDataOutput (current pipeline), fall back to MovieFileOutput.
        let videoConnection: AVCaptureConnection?
        
        if let dataOutput = captureSession.outputs.first(where: { $0 is AVCaptureVideoDataOutput }) as? AVCaptureVideoDataOutput {
            videoConnection = dataOutput.connection(with: .video)
        } else if let movieOutput = captureSession.outputs.first(where: { $0 is AVCaptureMovieFileOutput }) as? AVCaptureMovieFileOutput {
            videoConnection = movieOutput.connection(with: .video)
        } else {
            videoConnection = nil
        }
        
        guard let connection = videoConnection else {
            print("⚠️ OrientationCapture: No video connection found, inferring from device orientation instead")
            let inferred = (deviceOrientation == .portrait || deviceOrientation == .portraitUpsideDown)
                ? VideoOrientation.portrait
                : VideoOrientation.landscape
            print("   ✅ Inferred Smart Fill Orientation from device: \(inferred.displayName)")
            return inferred
        }
        
        var rotationAngle: CGFloat = 0
        
        if #available(iOS 17.0, *), connection.isVideoRotationAngleSupported(connection.videoRotationAngle) {
            rotationAngle = connection.videoRotationAngle
            print("   🎥 Video Connection Rotation Angle: \(rotationAngle)° (\(rotationAngleName(rotationAngle)))")
        } else {
            // Legacy path: approximate from device orientation
            rotationAngle = rotationAngleFromDevice(deviceOrientation)
            print("   🎥 Approximated rotation angle from device: \(rotationAngle)°")
        }
        
        let detectedOrientation = rotationAngleToSmartFillOrientation(rotationAngle)
        print("   ✅ Detected Smart Fill Orientation: \(detectedOrientation.displayName)")
        
        return detectedOrientation
    }
    
    /// Detect orientation from a completed video file using preferredTransform
    /// - Parameter videoURL: URL of the video file to analyze
    /// - Returns: The detected VideoOrientation
    public static func detectOrientationFromFile(at videoURL: URL) async throws -> VideoOrientation {
        let asset = AVURLAsset(url: videoURL)
        let analysis = try await NormalizeOrientation.analyzeVideoOrientation(from: asset)
        
        print("📐 OrientationCapture: File analysis completed for \(videoURL.lastPathComponent)")
        print("   📏 Natural Size: \(analysis.naturalSize)")
        print("   📐 Transform: \(analysis.transformType.displayName)")
        print("   ✅ Detected Orientation: \(analysis.capturedOrientation.displayName)")
        
        return analysis.capturedOrientation
    }
    
    /// Setup proper video orientation for capture session based on device state
    /// - Parameters:
    ///   - captureSession: The capture session to configure
    ///   - preferredOrientation: Optional preferred orientation (defaults to current device)
    public static func configureVideoOrientation(
        in captureSession: AVCaptureSession,
        preferredOrientation: UIDeviceOrientation? = nil
    ) {
        let targetOrientation = preferredOrientation ?? UIDevice.current.orientation
        
        guard let movieOutput = captureSession.outputs.first(where: { $0 is AVCaptureMovieFileOutput }) as? AVCaptureMovieFileOutput,
              let videoConnection = movieOutput.connection(with: .video) else {
            print("⚠️ OrientationCapture: Cannot configure orientation - no video connection")
            return
        }
        
        // UPDATED: Use isVideoRotationAngleSupported() with rotation angle parameter
        let rotationAngle = rotationAngleFromDevice(targetOrientation)
        if videoConnection.isVideoRotationAngleSupported(rotationAngle) {
            videoConnection.videoRotationAngle = rotationAngle
            print("✅ OrientationCapture: Configured video rotation angle: \(rotationAngle)°")
        } else {
            print("⚠️ OrientationCapture: Video rotation angle \(rotationAngle)° not supported by connection")
        }
    }
    
    // MARK: - Orientation Conversion Helpers - UPDATED for iOS 17+
    
    /// Convert rotation angle to Smart Fill VideoOrientation
    /// UPDATED: New method for iOS 17+ videoRotationAngle API
    private static func rotationAngleToSmartFillOrientation(_ rotationAngle: CGFloat) -> VideoOrientation {
        // Normalize angle to 0-360 range
        let normalizedAngle = rotationAngle.truncatingRemainder(dividingBy: 360)
        let positiveAngle = normalizedAngle < 0 ? normalizedAngle + 360 : normalizedAngle
        
        switch positiveAngle {
        case 45..<135, 225..<315:  // Portrait ranges (90° ± 45°, 270° ± 45°)
            return .portrait
        default:  // Landscape ranges (0° ± 45°, 180° ± 45°)
            return .landscape
        }
    }
    
    /// Convert UIDeviceOrientation to rotation angle in degrees
    /// UPDATED: FIXED landscape orientation mapping - corrects upside-down video issue
    private static func rotationAngleFromDevice(_ deviceOrientation: UIDeviceOrientation) -> CGFloat {
        switch deviceOrientation {
        case .portrait:
            return 90  // Portrait
        case .portraitUpsideDown:
            return 270  // Portrait Upside Down
        case .landscapeLeft:
            return 0   // Landscape Left (device rotated left, home button on right)
        case .landscapeRight:
            return 180 // Landscape Right (device rotated right, home button on left)
        default:
            return 90  // Default to portrait
        }
    }
    
    // MARK: - Debug Helpers - UPDATED
    
    private static func deviceOrientationName(_ orientation: UIDeviceOrientation) -> String {
        switch orientation {
        case .portrait: return "Portrait"
        case .portraitUpsideDown: return "Portrait Upside Down"
        case .landscapeLeft: return "Landscape Left"
        case .landscapeRight: return "Landscape Right"
        case .faceUp: return "Face Up"
        case .faceDown: return "Face Down"
        default: return "Unknown"
        }
    }
    
    /// Debug helper for rotation angles
    /// NEW: Helper for iOS 17+ videoRotationAngle debugging
    private static func rotationAngleName(_ angle: CGFloat) -> String {
        let normalizedAngle = angle.truncatingRemainder(dividingBy: 360)
        let positiveAngle = normalizedAngle < 0 ? normalizedAngle + 360 : normalizedAngle
        
        switch positiveAngle {
        case 0: return "Landscape Right (0°)"
        case 90: return "Portrait (90°)"
        case 180: return "Landscape Left (180°)"
        case 270: return "Portrait Upside Down (270°)"
        default: return "Custom (\(positiveAngle)°)"
        }
    }
}

// MARK: - CameraEngine Integration Extensions - UPDATED

extension CameraEngine {
    
    /// Get current video orientation that will be captured
    var currentCaptureOrientation: VideoOrientation {
        return OrientationCapture.detectCurrentOrientation(from: session)
    }
    
    /// Configure video orientation for optimal Smart Fill capture
    /// UPDATED: Uses iOS 17+ rotation angle API
    func configureOrientationForCapture(preferredOrientation: UIDeviceOrientation? = nil) {
        // FIXED: Use DispatchQueue directly since sessionQueue is private
        DispatchQueue(label: "orientation.config").async { [weak self] in
            guard let self = self else { return }
            OrientationCapture.configureVideoOrientation(in: self.session, preferredOrientation: preferredOrientation)
        }
    }
}

// MARK: - SessionManager Integration Extensions

extension SessionManager {
    
    /// Add a take with automatic orientation detection
    func addTakeWithOrientationDetection(
        fileName: String,
        projectID: UUID,
        sessionID: UUID,
        filePath: String,
        duration: TimeInterval = 0,
        fileSize: Int64 = 0,
        cameraPosition: String = "back",
        notes: String? = nil
    ) async {
        
        // Detect orientation from the file
        let detectedOrientation: VideoOrientation
        
        do {
            let videoURL = URL(fileURLWithPath: filePath)
            detectedOrientation = try await OrientationCapture.detectOrientationFromFile(at: videoURL)
        } catch {
            print("❌ SessionManager: Failed to detect orientation, using landscape default: \(error)")
            detectedOrientation = .landscape
        }
        
        let relativeFilePath = VideoVariantResolver.relativePath(from: URL(fileURLWithPath: filePath))

        // Add the take with detected orientation - FIXED: Use new method name
        await MainActor.run {
            self.addUnifiedTakeWithOrientation(
                fileName: fileName,
                projectID: projectID,
                sessionID: sessionID,
                filePath: relativeFilePath, // FIX: pass relative path here
                duration: duration,
                fileSize: fileSize,
                cameraPosition: cameraPosition,
                capturedOrientation: detectedOrientation,
                notes: notes
            )
        }
        
        print("✅ SessionManager: Added take with auto-detected orientation: \(fileName) (\(detectedOrientation.displayName))")
    }
}
