//
//  SafeGeometry.swift
//  STSiPhone
//
//  Safe geometry helpers to eliminate NaN/invalid frame dimensions in wizards
//

import SwiftUI

@inline(__always)
func safeDiv(_ numerator: CGFloat, by denominator: CGFloat, fallback: CGFloat = 0) -> CGFloat {
    guard denominator.isFinite, !denominator.isZero else { return fallback }
    let v = numerator / denominator
    return v.isFinite ? v : fallback
}

@inline(__always)
func safe(_ value: CGFloat, fallback: CGFloat = 0) -> CGFloat {
    value.isFinite ? value : fallback
}

/// Geometry wrapper that only publishes a size once it's valid and stable.
struct StableGeometry: ViewModifier {
    let minWidth: CGFloat
    let minHeight: CGFloat
    func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { proxy in
                    // Force layout to ignore zero or NaN sizes
                    Color.clear
                        .frame(
                            width: max(proxy.size.width, minWidth),
                            height: max(proxy.size.height, minHeight)
                        )
                }
            )
    }
}

extension View {
    func stableGeometry(minWidth: CGFloat = 1, minHeight: CGFloat = 1) -> some View {
        modifier(StableGeometry(minWidth: minWidth, minHeight: minHeight))
    }
}

#if DEBUG
extension CGFloat {
    var assertFinite: CGFloat {
        assert(self.isFinite, "Non-finite CGFloat detected in layout")
        return self
    }
}
#endif
