import UIKit
import SwiftUI

/// Debug utilities for tracking down layout and constraint issues
public struct LayoutDebugger {
    
    /// Enable constraint debugging for unsatisfiable constraints
    public static func enableConstraintDebugging() {
        #if DEBUG
        // This can be enabled in development to pause on constraint issues
        // Set a symbolic breakpoint on UIViewAlertForUnsatisfiableConstraints
        print("🔧 LayoutDebugger: Constraint debugging available")
        print("   📋 To debug: Add symbolic breakpoint on UIViewAlertForUnsatisfiableConstraints")
        print("   🔍 Or add environment variable: CG_NUMERICS_SHOW_BACKTRACE=1")
        #endif
    }
    
    /// Log view hierarchy for debugging
    public static func logViewHierarchy(_ view: UIView, indent: String = "") {
        #if DEBUG
        let frameInfo = "frame: \(view.frame)"
        let boundsInfo = "bounds: \(view.bounds)"
        let constraintsInfo = "constraints: \(view.constraints.count)"
        
        print("\(indent)📱 \(type(of: view)) - \(frameInfo), \(boundsInfo), \(constraintsInfo)")
        
        for subview in view.subviews {
            logViewHierarchy(subview, indent: indent + "  ")
        }
        #endif
    }
    
    /// Find views with potentially problematic frames
    public static func findProblematicFrames(in view: UIView) -> [UIView] {
        #if DEBUG
        var problematic: [UIView] = []
        
        func checkView(_ view: UIView) {
            let frame = view.frame
            let hasInvalidFrame = !frame.size.width.isFinite || 
                                 !frame.size.height.isFinite ||
                                 !frame.origin.x.isFinite ||
                                 !frame.origin.y.isFinite ||
                                 frame.size.width < 0 ||
                                 frame.size.height < 0
            
            if hasInvalidFrame {
                problematic.append(view)
                print("❌ LayoutDebugger: Found problematic frame in \(type(of: view)): \(frame)")
            }
            
            for subview in view.subviews {
                checkView(subview)
            }
        }
        
        checkView(view)
        return problematic
        #else
        return []
        #endif
    }
    
    /// Monitor constraint changes
    public static func monitorConstraints(for view: UIView) {
        #if DEBUG
        let initialConstraintCount = view.constraints.count
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let currentConstraintCount = view.constraints.count
            if currentConstraintCount != initialConstraintCount {
                print("🔄 LayoutDebugger: Constraint count changed for \(type(of: view))")
                print("   📊 Before: \(initialConstraintCount), After: \(currentConstraintCount)")
            }
        }
        #endif
    }
    
    /// Safe constraint priority helper
    public static func safeConstraintPriority(_ priority: Float) -> UILayoutPriority {
        let clampedPriority = max(1.0, min(1000.0, priority))
        if clampedPriority != priority {
            print("🔧 LayoutDebugger: Adjusted constraint priority \(priority) -> \(clampedPriority)")
        }
        return UILayoutPriority(clampedPriority)
    }
    
    /// Check for common constraint issues
    public static func validateConstraints(for view: UIView) {
        #if DEBUG
        print("🔍 LayoutDebugger: Validating constraints for \(type(of: view))")
        
        // Check for potential width/height conflicts
        let widthConstraints = view.constraints.filter { 
            $0.firstAttribute == .width || $0.secondAttribute == .width 
        }
        let heightConstraints = view.constraints.filter { 
            $0.firstAttribute == .height || $0.secondAttribute == .height 
        }
        
        if widthConstraints.count > 3 {
            print("⚠️ LayoutDebugger: Potentially conflicting width constraints (\(widthConstraints.count))")
        }
        
        if heightConstraints.count > 3 {
            print("⚠️ LayoutDebugger: Potentially conflicting height constraints (\(heightConstraints.count))")
        }
        
        // Check for constraints with invalid constants
        for constraint in view.constraints {
            if !constraint.constant.isFinite {
                print("❌ LayoutDebugger: Invalid constraint constant: \(constraint.constant)")
            }
        }
        #endif
    }
}

// MARK: - SwiftUI Debugging Extensions

public extension View {
    
    /// Debug modifier to log layout changes
    func debugLayout(_ label: String = "") -> some View {
        #if DEBUG
        return self.onAppear {
            print("📱 SwiftUI Layout: \(label) appeared")
        }
        .onDisappear {
            print("📱 SwiftUI Layout: \(label) disappeared")
        }
        #else
        return self
        #endif
    }
    
    /// Debug frame changes
    func debugFrame(_ label: String = "") -> some View {
        #if DEBUG
        return self.background(
            GeometryReader { geometry in
                Color.clear.onAppear {
                    print("📐 SwiftUI Frame (\(label)): \(geometry.size)")
                }
                .onChange(of: geometry.size, initial: false) { _, newSize in
                    print("📐 SwiftUI Frame Changed (\(label)): \(newSize)")
                }
            }
        )
        #else
        return self
        #endif
    }
}

#if DEBUG
// MARK: - Development Helpers

public extension LayoutDebugger {
    
    /// Quick constraint debugging setup
    static func setupDevelopmentDebugging() {
        // Enable metal validation for GPU debugging
        setenv("METAL_DEVICE_WRAPPER_TYPE", "1", 1)
        
        // Enable core graphics debugging
        setenv("CG_NUMERICS_SHOW_BACKTRACE", "1", 1)
        
        // Enable constraint debugging
        enableConstraintDebugging()
        
        print("🔧 LayoutDebugger: Development debugging enabled")
    }
    
    /// Performance monitoring for layout
    static func measureLayoutTime<T>(_ operation: () -> T, label: String = "") -> T {
        let startTime = CACurrentMediaTime()
        let result = operation()
        let duration = CACurrentMediaTime() - startTime
        
        if duration > 0.016 { // More than one frame (60fps)
            print("⏱️ LayoutDebugger: Slow layout operation (\(label)): \(String(format: "%.3f", duration * 1000))ms")
        }
        
        return result
    }
}
#endif