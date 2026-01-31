import UIKit
import SwiftUI

/// Utility for preventing invalid frame dimensions and layout crashes
public struct FrameSafety {
    
    /// Ensures frame dimensions are never negative or non-finite
    public static func safeFrame(_ frame: CGRect) -> CGRect {
        let safeX = frame.origin.x.isFinite ? frame.origin.x : 0
        let safeY = frame.origin.y.isFinite ? frame.origin.y : 0
        let safeWidth = max(0, frame.size.width.isFinite ? frame.size.width : 0)
        let safeHeight = max(0, frame.size.height.isFinite ? frame.size.height : 0)
        
        let result = CGRect(x: safeX, y: safeY, width: safeWidth, height: safeHeight)
        
        // Log if we had to fix an invalid frame
        if result != frame {
            print("🔧 FrameSafety: Fixed invalid frame")
            print("   ❌ Original: \(frame)")
            print("   ✅ Fixed: \(result)")
        }
        
        return result
    }
    
    /// Safe size calculation with minimum values
    public static func safeSize(_ size: CGSize, minimum: CGSize = CGSize(width: 1, height: 1)) -> CGSize {
        let safeWidth = max(minimum.width, size.width.isFinite ? size.width : minimum.width)
        let safeHeight = max(minimum.height, size.height.isFinite ? size.height : minimum.height)
        
        let result = CGSize(width: safeWidth, height: safeHeight)
        
        if result != size {
            print("🔧 FrameSafety: Fixed invalid size")
            print("   ❌ Original: \(size)")
            print("   ✅ Fixed: \(result)")
        }
        
        return result
    }
    
    /// Safe bounds calculation from view
    public static func safeBounds(from view: UIView) -> CGRect {
        let bounds = view.bounds
        return safeFrame(bounds)
    }
    
    /// Safe center calculation for positioning
    public static func safeCenter(in containerSize: CGSize, for itemSize: CGSize) -> CGPoint {
        let centerX = max(itemSize.width / 2, (containerSize.width - itemSize.width) / 2 + itemSize.width / 2)
        let centerY = max(itemSize.height / 2, (containerSize.height - itemSize.height) / 2 + itemSize.height / 2)
        
        return CGPoint(
            x: centerX.isFinite ? centerX : itemSize.width / 2,
            y: centerY.isFinite ? centerY : itemSize.height / 2
        )
    }
    
    /// Safe offset calculation (prevents negative positioning that could cause layout issues)
    public static func safeOffset(container: CGSize, item: CGSize) -> CGPoint {
        let x = max(0, (container.width - item.width) / 2)
        let y = max(0, (container.height - item.height) / 2)
        
        return CGPoint(
            x: x.isFinite ? x : 0,
            y: y.isFinite ? y : 0
        )
    }
}

// MARK: - SwiftUI Extensions

public extension View {
    
    /// Safe frame modifier that prevents invalid dimensions
    func safeFrame(width: CGFloat? = nil, height: CGFloat? = nil, alignment: Alignment = .center) -> some View {
        let safeWidth = width.map { max(0, $0.isFinite ? $0 : 0) }
        let safeHeight = height.map { max(0, $0.isFinite ? $0 : 0) }
        
        return frame(width: safeWidth, height: safeHeight, alignment: alignment)
    }
    
    /// Safe frame modifier with minimum dimensions
    func safeFrame(minWidth: CGFloat? = nil, maxWidth: CGFloat? = nil, minHeight: CGFloat? = nil, maxHeight: CGFloat? = nil, alignment: Alignment = .center) -> some View {
        let safeMinWidth = minWidth.map { max(0, $0.isFinite ? $0 : 0) }
        let safeMaxWidth = maxWidth.map { max(safeMinWidth ?? 0, $0.isFinite ? $0 : .infinity) }
        let safeMinHeight = minHeight.map { max(0, $0.isFinite ? $0 : 0) }
        let safeMaxHeight = maxHeight.map { max(safeMinHeight ?? 0, $0.isFinite ? $0 : .infinity) }
        
        return frame(minWidth: safeMinWidth, maxWidth: safeMaxWidth, minHeight: safeMinHeight, maxHeight: safeMaxHeight, alignment: alignment)
    }
}

// MARK: - UIKit Extensions

public extension UIView {
    
    /// Safely set frame with validation
    func setSafeFrame(_ frame: CGRect) {
        self.frame = FrameSafety.safeFrame(frame)
    }
    
    /// Safely set bounds with validation  
    func setSafeBounds(_ bounds: CGRect) {
        self.bounds = FrameSafety.safeFrame(bounds)
    }
    
    /// Get safe bounds (never invalid)
    var safeBounds: CGRect {
        return FrameSafety.safeBounds(from: self)
    }
}

// MARK: - Auto Layout Constraint Helpers

public extension NSLayoutConstraint {
    
    /// Create constraint with safe constant (prevents NaN/infinite values)
    static func safeConstant(_ constant: CGFloat) -> CGFloat {
        return constant.isFinite ? constant : 0
    }
    
    /// Safe priority value (prevents invalid constraint priorities)
    static func safePriority(_ priority: UILayoutPriority) -> UILayoutPriority {
        let rawValue = priority.rawValue
        if rawValue.isFinite && rawValue >= 1 && rawValue <= 1000 {
            return priority
        } else {
            print("🔧 FrameSafety: Fixed invalid constraint priority \(rawValue) -> 750")
            return .defaultHigh
        }
    }
}

#if DEBUG
// MARK: - Debug Helpers

public extension FrameSafety {
    
    /// Validate frame and print detailed info if invalid
    static func validateFrame(_ frame: CGRect, context: String = "") -> Bool {
        let isValid = frame.size.width >= 0 && 
                     frame.size.height >= 0 && 
                     frame.origin.x.isFinite && 
                     frame.origin.y.isFinite &&
                     frame.size.width.isFinite && 
                     frame.size.height.isFinite
        
        if !isValid {
            print("❌ FrameSafety: Invalid frame detected")
            print("   📍 Context: \(context)")
            print("   📐 Frame: \(frame)")
            print("   🔍 Issues:")
            
            if !frame.origin.x.isFinite { print("     • X origin is not finite") }
            if !frame.origin.y.isFinite { print("     • Y origin is not finite") }
            if !frame.size.width.isFinite { print("     • Width is not finite") }
            if !frame.size.height.isFinite { print("     • Height is not finite") }
            if frame.size.width < 0 { print("     • Width is negative") }
            if frame.size.height < 0 { print("     • Height is negative") }
        }
        
        return isValid
    }
}
#endif