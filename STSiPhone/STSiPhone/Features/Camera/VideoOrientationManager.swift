import SwiftUI
import UIKit

// MARK: - Video Orientation Manager - SIMPLIFIED approach
@MainActor
class VideoOrientationManager: ObservableObject {
    @Published var isLocked = false
    @Published var lockedOrientation: UIDeviceOrientation?
    
    func lockCurrentOrientation() {
        guard !isLocked else { return }
        
        let currentOrientation = UIDevice.current.orientation
        
        // Only lock if we're in a valid orientation
        guard currentOrientation.isValidInterfaceOrientation else { return }
        
        lockedOrientation = currentOrientation
        isLocked = true
        
        print("🔒 Orientation locked to: \(currentOrientation.description)")
        
        // SIMPLIFIED: Just notify that we want to lock orientation
        // The actual locking will be handled by the app's natural orientation system
        NotificationCenter.default.post(name: .orientationLockRequested, object: currentOrientation)
    }
    
    func unlockOrientation() {
        guard isLocked else { return }
        
        isLocked = false
        lockedOrientation = nil
        
        print("🔓 Orientation unlocked - allowing natural rotation")
        
        // SIMPLIFIED: Just notify that we want to unlock orientation
        NotificationCenter.default.post(name: .orientationUnlockRequested, object: nil)
    }
}

// MARK: - Device Orientation Extensions
extension UIDeviceOrientation {
    var isValidInterfaceOrientation: Bool {
        switch self {
        case .portrait, .landscapeLeft, .landscapeRight, .portraitUpsideDown:
            return true
        default:
            return false
        }
    }
    
    // NEW: Helper property for landscape detection
    var isLandscape: Bool {
        return self == .landscapeLeft || self == .landscapeRight
    }
    
    var description: String {
        switch self {
        case .portrait: return "Portrait"
        case .landscapeLeft: return "Landscape Left"
        case .landscapeRight: return "Landscape Right"
        case .portraitUpsideDown: return "Portrait Upside Down"
        default: return "Unknown"
        }
    }
    
    var interfaceOrientationMask: UIInterfaceOrientationMask {
        switch self {
        case .portrait: return .portrait
        case .landscapeLeft: return .landscapeLeft
        case .landscapeRight: return .landscapeRight
        case .portraitUpsideDown: return .portraitUpsideDown
        default: return .portrait
        }
    }
}

// MARK: - Orientation Lock Modifier - SIMPLIFIED
struct OrientationLockModifier: ViewModifier {
    @StateObject private var orientationManager = VideoOrientationManager()
    let autoLock: Bool
    
    init(autoLock: Bool = true) {
        self.autoLock = autoLock
    }
    
    func body(content: Content) -> some View {
        content
            .environmentObject(orientationManager)
            .onAppear {
                if autoLock {
                    // FIXED: Small delay to ensure view is ready
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        orientationManager.lockCurrentOrientation()
                    }
                }
            }
            .onDisappear {
                orientationManager.unlockOrientation()
            }
    }
}

// MARK: - View Extension
extension View {
    func lockVideoOrientation(autoLock: Bool = true) -> some View {
        modifier(OrientationLockModifier(autoLock: autoLock))
    }
}

// MARK: - Orientation Lock Controls - SIMPLIFIED
struct OrientationLockControls: View {
    @EnvironmentObject var orientationManager: VideoOrientationManager
    @State private var deviceOrientation = UIDevice.current.orientation
    
    var body: some View {
        HStack {
            if orientationManager.isLocked {
                // Locked State
                HStack(spacing: 8) {
                    Image(systemName: "lock.rotation")
                        .font(.caption)
                        .foregroundColor(.yellow)
                    
                    Text("Locked: \(orientationManager.lockedOrientation?.description ?? "Unknown")")
                        .font(.caption)
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.black.opacity(0.7), in: RoundedRectangle(cornerRadius: 16))
                
                Button("Unlock") {
                    orientationManager.unlockOrientation()
                }
                .font(.caption)
                .foregroundColor(.yellow)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                
            } else {
                // Unlocked State
                Button("Lock Orientation") {
                    orientationManager.lockCurrentOrientation()
                }
                .font(.caption)
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
            deviceOrientation = UIDevice.current.orientation
        }
    }
}

// MARK: - Notification Extensions
extension Notification.Name {
    static let orientationLockRequested = Notification.Name("orientationLockRequested")
    static let orientationUnlockRequested = Notification.Name("orientationUnlockRequested")
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        
        VStack {
            Text("Video Player with Orientation Lock")
                .font(.headline)
                .foregroundColor(.white)
            
            Spacer()
            
            OrientationLockControls()
        }
        .padding()
    }
    .environmentObject(VideoOrientationManager())
}
