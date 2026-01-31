import SwiftUI
import AVFoundation
import PryntTrimmerView

struct STSResilientTrimmerRepresentable: UIViewRepresentable {
    let url: URL
    var height: CGFloat = 60
    var onRangeChanged: ((CMTimeRange) -> Void)? = nil
    var onScrubbed: ((CMTime) -> Void)? = nil

    func makeUIView(context: Context) -> STSResilientTrimmerView {
        let v = STSResilientTrimmerView(frame: .zero)
        v.desiredHeight = height
        v.delegate = context.coordinator
        
        // PROFESSIONAL: Use STS Theme branding colors instead of debug colors
        v.handleColor = UIColor(red: 0.6, green: 0.2, blue: 0.8, alpha: 1.0) // Theme primary purple
        v.mainColor = UIColor(red: 0.8, green: 0.3, blue: 0.7, alpha: 0.8) // Theme secondary pink
        v.positionBarColor = UIColor.systemOrange // STS accent color
        v.maxDuration = 60.0
        
        // PROFESSIONAL: Remove debug styling - use subtle professional background
        v.backgroundColor = UIColor.clear
        v.layer.borderWidth = 0
        v.layer.borderColor = UIColor.clear.cgColor
        
        // PROFESSIONAL: Add subtle shadow for depth
        v.layer.shadowColor = UIColor.black.cgColor
        v.layer.shadowOffset = CGSize(width: 0, height: 2)
        v.layer.shadowRadius = 4
        v.layer.shadowOpacity = 0.1
        v.layer.cornerRadius = 8
        
        // Defer URL assignment until layoutSubviews runs with non-zero size
        v.pendingURL = url
        
        print("🎬 PROFESSIONAL TRIMMER: Created with STS branding colors")
        
        return v
    }

    func updateUIView(_ uiView: STSResilientTrimmerView, context: Context) {
        // If URL changes, update pendingURL; the view will rebuild when sized.
        if uiView.pendingURL != url {
            uiView.pendingURL = url
            uiView.setNeedsLayout()
            print("🔄 PROFESSIONAL TRIMMER: Updated pendingURL")
        }
        uiView.desiredHeight = height
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onRangeChanged: onRangeChanged, onScrubbed: onScrubbed)
    }

    final class Coordinator: NSObject, TrimmerViewDelegate {
        var onRangeChanged: ((CMTimeRange) -> Void)?
        var onScrubbed: ((CMTime) -> Void)?
        
        init(onRangeChanged: ((CMTimeRange) -> Void)?, onScrubbed: ((CMTime) -> Void)?) {
            self.onRangeChanged = onRangeChanged
            self.onScrubbed = onScrubbed
        }

        func trimmerView(_ trimmerView: TrimmerView, didChangeLeftPosition leftPosition: CMTime, rightPosition: CMTime) {
            let l = CMTimeGetSeconds(leftPosition)
            let r = CMTimeGetSeconds(rightPosition)
            let d = CMTimeGetSeconds(CMTimeSubtract(rightPosition, leftPosition))
            print(String(format: "🎯 PROFESSIONAL HANDLE: left=%.3f right=%.3f Δ=%.3f", l, r, d))
            
            onRangeChanged?(CMTimeRange(start: leftPosition, end: rightPosition))
        }

        func didChangePositionBar(_ playerTime: CMTime) {
            print("🎯 PROFESSIONAL POSITION: \(playerTime.seconds)s")
            onScrubbed?(playerTime)
        }
        
        func positionBarStoppedMoving(_ playerTime: CMTime) {
            print("🎯 PROFESSIONAL POSITION STOPPED: \(playerTime.seconds)s")
            // Can also notify if needed
        }
    }
}