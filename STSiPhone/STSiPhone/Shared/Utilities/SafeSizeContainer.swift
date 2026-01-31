import SwiftUI
import AVFoundation

/// 🚨 CRITICAL FIX: Prevents zero-size layout issues and constraint spam
/// Only renders content when container has valid dimensions
public struct SafeSizeContainer<Content: View>: View {
    @State private var hasValidSize = false
    @State private var currentSize: CGSize = .zero
    
    private let minimumSize: CGSize
    private let content: (CGSize) -> Content
    
    public init(
        minimumSize: CGSize = CGSize(width: 100, height: 100),
        @ViewBuilder content: @escaping (CGSize) -> Content
    ) {
        self.minimumSize = minimumSize
        self.content = content
    }
    
    public var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            
            Group {
                if hasValidSize {
                    content(currentSize)
                        .frame(width: currentSize.width, height: currentSize.height)
                } else {
                    // Show loading placeholder while waiting for valid size
                    Rectangle()
                        .fill(Color.black.opacity(0.1))
                        .overlay(
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .gray))
                        )
                }
            }
            .onChange(of: size, initial: false) { _, newSize in
                let isValid = newSize.width >= minimumSize.width &&
                             newSize.height >= minimumSize.height &&
                             newSize.width.isFinite &&
                             newSize.height.isFinite
                
                if isValid != hasValidSize {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        hasValidSize = isValid
                        if isValid {
                            currentSize = newSize
                        }
                    }
                }
            }
            .onAppear {
                // Initial size check
                let isValid = size.width >= minimumSize.width &&
                             size.height >= minimumSize.height &&
                             size.width.isFinite &&
                             size.height.isFinite
                
                hasValidSize = isValid
                if isValid {
                    currentSize = size
                }
            }
        }
    }
}

// MARK: - Toolbar Safe Container

/// 🚨 CRITICAL FIX: Prevents toolbar constraint spam during sheet presentation
public struct SafeToolbarContainer<Content: View>: View {
    @State private var canShowToolbar = false
    
    private let content: Content
    
    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    public var body: some View {
        content
            .toolbar {
                if canShowToolbar {
                    ToolbarItemGroup(placement: .bottomBar) {
                        // Toolbar content goes here
                        Spacer()
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                // Delay toolbar appearance to avoid constraint conflicts
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    canShowToolbar = true
                }
            }
            .onAppear {
                // Delay initial toolbar to ensure proper layout
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    canShowToolbar = true
                }
            }
            .onDisappear {
                canShowToolbar = false
            }
    }
}

// MARK: - UIKit Extensions for Safe Sizing

public extension UIView {
    
    /// 🚨 CRITICAL FIX: Guard against zero/NaN frame dimensions in UIKit
    func setSafeFrame(_ frame: CGRect, context: String = "") {
        let safeFrame = validateFrame(frame, context: context)
        self.frame = safeFrame
    }
    
    /// Validate frame and return safe version
    func validateFrame(_ frame: CGRect, context: String = "") -> CGRect {
        guard frame.size.width > 0 && frame.size.height > 0 &&
              frame.size.width.isFinite && frame.size.height.isFinite &&
              frame.origin.x.isFinite && frame.origin.y.isFinite else {
            
            print("⚠️ SafeSizeContainer: Invalid frame detected in \(context)")
            print("   ❌ Invalid frame: \(frame)")
            
            // Return safe default frame
            let safeFrame = CGRect(x: 0, y: 0, width: 100, height: 100)
            print("   ✅ Using safe frame: \(safeFrame)")
            return safeFrame
        }
        
        return frame
    }
    
    /// Check if view has valid layout dimensions
    var hasValidSize: Bool {
        return bounds.width > 0 && bounds.height > 0 &&
               bounds.width.isFinite && bounds.height.isFinite
    }
}

// MARK: - AVPlayerLayer Safe Setup

public extension AVPlayerLayer {
    
    /// 🚨 CRITICAL FIX: Safe frame setting for player layers
    func setSafeVideoFrame(_ frame: CGRect) {
        guard frame.size.width > 0 && frame.size.height > 0 &&
              frame.size.width.isFinite && frame.size.height.isFinite else {
            
            print("⚠️ AVPlayerLayer: Hiding layer due to invalid frame: \(frame)")
            isHidden = true
            return
        }
        
        isHidden = false
        
        // Use CATransaction to prevent animation glitches during size changes
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        self.frame = frame
        CATransaction.commit()
        
        print("✅ AVPlayerLayer: Frame set safely: \(frame)")
    }
}
