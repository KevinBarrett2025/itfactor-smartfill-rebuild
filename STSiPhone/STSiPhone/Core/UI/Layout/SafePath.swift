//
//  SafePath.swift
//  STSiPhone
//
//  NaN-proof path and geometry helpers for wizard UI stability
//

import SwiftUI

@inline(__always) func clampFinite(_ v: CGFloat, min: CGFloat = 0, max: CGFloat = .greatestFiniteMagnitude, fallback: CGFloat = 0) -> CGFloat {
    guard v.isFinite else { return fallback }
    return Swift.max(min, Swift.min(max, v))
}

@inline(__always) func safeDiv(_ a: CGFloat, _ b: CGFloat, fallback: CGFloat = 0) -> CGFloat {
    guard b.isFinite, !b.isZero else { return fallback }
    let r = a / b
    return r.isFinite ? r : fallback
}

extension Path {
    mutating func safeMove(to p: CGPoint) {
        guard p.x.isFinite, p.y.isFinite else { return }
        move(to: p)
    }
    
    mutating func safeAddLine(to p: CGPoint) {
        guard p.x.isFinite, p.y.isFinite else { return }
        addLine(to: p)
    }
    
    mutating func safeAddLines(_ points: [CGPoint]) {
        for p in points where p.x.isFinite && p.y.isFinite {
            addLine(to: p)
        }
    }
}

extension CGRect {
    var finiteRectOrUnit: CGRect {
        let w = clampFinite(width,  min: 1, fallback: 1)
        let h = clampFinite(height, min: 1, fallback: 1)
        let x = clampFinite(origin.x, fallback: 0)
        let y = clampFinite(origin.y, fallback: 0)
        return CGRect(x: x, y: y, width: w, height: h)
    }
}

/// Generic wrapper to make any Shape NaN-safe
struct SafeShape<S: Shape>: Shape {
    var inner: S
    
    func path(in rect: CGRect) -> Path {
        inner.path(in: rect.finiteRectOrUnit)
    }
}

/// Rounded rectangle shape that clamps radius against the safe rect size.
struct SafeRoundedRectangle: Shape {
    var cornerRadius: CGFloat
    var style: RoundedCornerStyle = .continuous
    
    func path(in rect: CGRect) -> Path {
        let safeRect = rect.finiteRectOrUnit
        let maxRadius = max(0, min(cornerRadius, min(safeRect.width, safeRect.height) * 0.5))
        return RoundedRectangle(cornerRadius: maxRadius, style: style).path(in: safeRect)
    }
}

/// Capsule shape backed by a safe rounded rectangle.
struct SafeCapsule: Shape {
    func path(in rect: CGRect) -> Path {
        let safeRect = rect.finiteRectOrUnit
        let radius = min(safeRect.width, safeRect.height) * 0.5
        return RoundedRectangle(cornerRadius: radius, style: .continuous).path(in: safeRect)
    }
}

/// Circle shape that clamps to the smallest dimension and remains centered.
struct SafeCircle: Shape {
    func path(in rect: CGRect) -> Path {
        let safeRect = rect.finiteRectOrUnit
        let diameter = max(1, min(safeRect.width, safeRect.height))
        let circleRect = CGRect(
            x: safeRect.midX - diameter * 0.5,
            y: safeRect.midY - diameter * 0.5,
            width: diameter,
            height: diameter
        )
        return Circle().path(in: circleRect)
    }
}

// Convenience extensions for common geometry calculations
extension CGSize {
    var finiteOrUnit: CGSize {
        CGSize(
            width: clampFinite(width, min: 1, fallback: 1),
            height: clampFinite(height, min: 1, fallback: 1)
        )
    }
    
    var safeAspectRatio: CGFloat {
        safeDiv(width, height, fallback: 1.0)
    }
}

extension CGPoint {
    var isFinite: Bool {
        x.isFinite && y.isFinite
    }
    
    var finiteOrZero: CGPoint {
        CGPoint(
            x: x.isFinite ? x : 0,
            y: y.isFinite ? y : 0
        )
    }
}
