import AVFoundation
import UIKit

final class PreviewThumbnailer {
    private let queue = DispatchQueue(label: "preview.thumb.encode")
    private var lastSent = Date.distantPast
    
    /// Call from AVCaptureVideoDataOutputSampleBufferDelegate
    func process(_ sampleBuffer: CMSampleBuffer) {
        queue.async { [weak self] in
            self?.encodeFrame(sampleBuffer)
        }
    }
    
    private func encodeFrame(_ sampleBuffer: CMSampleBuffer) {
        let minInterval: TimeInterval = 0.25 // ~4 fps
        let now = Date()
        guard now.timeIntervalSince(lastSent) > minInterval else { return }
        lastSent = now
        
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        
        let targetWidth: CGFloat = 320
        let scale = targetWidth / max(ciImage.extent.width, 1)
        let resized = ciImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        
        let context = CIContext(options: [.useSoftwareRenderer: false])
        guard let cgImage = context.createCGImage(resized, from: resized.extent) else { return }
        let uiImage = UIImage(cgImage: cgImage)
        
        guard let jpeg = uiImage.jpegData(compressionQuality: 0.45) else { return }
        
        WatchBridge.shared.sendThumbnail(
            jpeg,
            width: Int(uiImage.size.width),
            height: Int(uiImage.size.height)
        )
    }
}
