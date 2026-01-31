import Foundation
import AVFoundation
import UIKit

enum KeyframeIntroClipBuilder {
    enum BuilderError: LocalizedError {
        case imageLoadFailed
        case writerCreationFailed
        case pixelBufferCreationFailed

        var errorDescription: String? {
            switch self {
            case .imageLoadFailed:
                return "Unable to load keyframe photo data."
            case .writerCreationFailed:
                return "Failed to configure video writer for keyframe intro clip."
            case .pixelBufferCreationFailed:
                return "Failed to build pixel buffer for keyframe intro clip."
            }
        }
    }

    static func buildIntroClip(
        from photoURL: URL,
        renderSize: CGSize,
        duration: TimeInterval = 0.5,
        frameRate: Int32 = 30
    ) async throws -> URL {
        let data = try Data(contentsOf: photoURL)
        guard let image = UIImage(data: data) else {
            throw BuilderError.imageLoadFailed
        }

        let sanitizedSize = CGSize(
            width: max(1, renderSize.width),
            height: max(1, renderSize.height)
        )
        let fittedImage = makeCanvasImage(from: image, targetSize: sanitizedSize)
        guard let cgImage = fittedImage.cgImage else {
            throw BuilderError.imageLoadFailed
        }

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("keyframe_intro_\(UUID().uuidString).mp4")
        try? FileManager.default.removeItem(at: outputURL)

        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: Int(sanitizedSize.width),
            AVVideoHeightKey: Int(sanitizedSize.height),
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: 2_000_000,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel
            ]
        ]

        let writerInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        writerInput.expectsMediaDataInRealTime = false

        let pixelAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
            kCVPixelBufferWidthKey as String: Int(sanitizedSize.width),
            kCVPixelBufferHeightKey as String: Int(sanitizedSize.height)
        ]

        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: writerInput,
            sourcePixelBufferAttributes: pixelAttributes
        )

        guard writer.canAdd(writerInput) else {
            throw BuilderError.writerCreationFailed
        }
        writer.add(writerInput)

        guard writer.startWriting() else {
            throw writer.error ?? BuilderError.writerCreationFailed
        }
        writer.startSession(atSourceTime: .zero)

        return try await withCheckedThrowingContinuation { continuation in
            let queue = DispatchQueue(label: "com.sts.keyframeIntroClipBuilder", qos: .userInitiated)
            writerInput.requestMediaDataWhenReady(on: queue) {
                var frame = 0
                let totalFrames = max(1, Int(ceil(duration * Double(frameRate))))
                let frameDuration = CMTime(value: 1, timescale: frameRate)

                while writerInput.isReadyForMoreMediaData && frame < totalFrames {
                    guard let pixelBuffer = makePixelBuffer(from: cgImage, size: sanitizedSize, pool: adaptor.pixelBufferPool) else {
                        writerInput.markAsFinished()
                        writer.cancelWriting()
                        continuation.resume(throwing: BuilderError.pixelBufferCreationFailed)
                        return
                    }

                    let presentationTime = CMTimeMultiply(frameDuration, multiplier: Int32(frame))
                    if !adaptor.append(pixelBuffer, withPresentationTime: presentationTime) {
                        writerInput.markAsFinished()
                        writer.cancelWriting()
                        continuation.resume(throwing: writer.error ?? BuilderError.writerCreationFailed)
                        return
                    }
                    frame += 1
                }

                if frame >= totalFrames {
                    writerInput.markAsFinished()
                    writer.finishWriting {
                        if let error = writer.error {
                            continuation.resume(throwing: error)
                        } else {
                            continuation.resume(returning: outputURL)
                        }
                    }
                }
            }
        }
    }

    private static func makeCanvasImage(from image: UIImage, targetSize: CGSize) -> UIImage {
        guard targetSize.width > 0, targetSize.height > 0 else { return image }
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { ctx in
            UIColor.black.setFill()
            ctx.fill(CGRect(origin: .zero, size: targetSize))

            let aspect = min(targetSize.width / image.size.width, targetSize.height / image.size.height)
            let scaledSize = CGSize(width: image.size.width * aspect, height: image.size.height * aspect)
            let origin = CGPoint(
                x: (targetSize.width - scaledSize.width) / 2,
                y: (targetSize.height - scaledSize.height) / 2
            )
            image.draw(in: CGRect(origin: origin, size: scaledSize))
        }
    }

    private static func makePixelBuffer(
        from cgImage: CGImage,
        size: CGSize,
        pool: CVPixelBufferPool?
    ) -> CVPixelBuffer? {
#if DEBUG
        if size.width <= 0 || size.height <= 0 {
            print("🧪 CGContext[KeyframeIntroClipBuilder.makePixelBuffer] invalid size=\(size) cgImage=\(cgImage.width)x\(cgImage.height)")
        }
#endif
        var pixelBuffer: CVPixelBuffer?
        let status: CVReturn
        if let pool = pool {
            status = CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &pixelBuffer)
        } else {
            status = CVPixelBufferCreate(
                kCFAllocatorDefault,
                Int(size.width),
                Int(size.height),
                kCVPixelFormatType_32ARGB,
                [
                    kCVPixelBufferCGImageCompatibilityKey: true,
                    kCVPixelBufferCGBitmapContextCompatibilityKey: true,
                    kCVPixelBufferIOSurfacePropertiesKey: [:]
                ] as CFDictionary,
                &pixelBuffer
            )
        }

        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            return nil
        }

        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }

        guard let context = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer),
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
        ) else {
            return nil
        }

        context.draw(cgImage, in: CGRect(origin: .zero, size: size))
        return buffer
    }
}
