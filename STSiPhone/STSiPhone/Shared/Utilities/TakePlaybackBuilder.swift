import Foundation
import AVFoundation
import CoreGraphics

enum TakePlaybackBuilder {
    static func makePlayerItem(for take: ProjectTake) async -> AVPlayerItem {
        let videoURL = URL(fileURLWithPath: take.effectiveFilePath)
        let metadata = take.editMetadata
        let needsTrim = metadata?.hasTrimming == true
        let needsCrop = metadata?.hasCropping == true
        if !needsTrim && !needsCrop {
            return AVPlayerItem(url: videoURL)
        }

        let baseAsset = AVURLAsset(url: videoURL)
        let (workingAsset, videoComposition) = await buildAssetApplyingEdits(
            from: baseAsset,
            metadata: metadata
        )

        let playerItem = await MainActor.run {
            AVPlayerItem(asset: workingAsset)
        }
        if let composition = videoComposition {
            playerItem.videoComposition = composition
        }

        return playerItem
    }
    
    // MARK: - Private helpers
    
    private static func buildAssetApplyingEdits(
        from asset: AVURLAsset,
        metadata: TakeEditMetadata?
    ) async -> (AVAsset, AVVideoComposition?) {
        var workingAsset: AVAsset = asset

        if metadata?.hasTrimming == true {
            let assetDurationSeconds: Double
            if let duration = try? await asset.load(.duration) {
                assetDurationSeconds = duration.secondsOrZero
            } else {
                assetDurationSeconds = 0
            }
            if let timeRange = trimTimeRange(from: metadata, assetDuration: assetDurationSeconds) {
                workingAsset = await makeTrimmedComposition(from: asset, timeRange: timeRange) ?? asset
            }
        }

        let videoComposition = await makeVideoCompositionIfNeeded(
            asset: workingAsset,
            metadata: metadata
        )

        return (workingAsset, videoComposition)
    }
    
    private static func makeTrimmedComposition(
        from asset: AVURLAsset,
        timeRange: CMTimeRange
    ) async -> AVMutableComposition? {
        let composition = AVMutableComposition()
        
        if let videoTracks = try? await asset.loadTracks(withMediaType: .video),
           let videoTrack = videoTracks.first,
           let compositionVideoTrack = composition.addMutableTrack(
                withMediaType: .video,
                preferredTrackID: kCMPersistentTrackID_Invalid
           ) {
            try? compositionVideoTrack.insertTimeRange(timeRange, of: videoTrack, at: .zero)
        }
        
        if let audioTracks = try? await asset.loadTracks(withMediaType: .audio),
           let audioTrack = audioTracks.first,
           let compositionAudioTrack = composition.addMutableTrack(
                withMediaType: .audio,
                preferredTrackID: kCMPersistentTrackID_Invalid
           ) {
            try? compositionAudioTrack.insertTimeRange(timeRange, of: audioTrack, at: .zero)
        }
        
        return composition
    }
    
    private static func makeVideoCompositionIfNeeded(
        asset: AVAsset,
        metadata: TakeEditMetadata?
    ) async -> AVMutableVideoComposition? {
        guard
            let metadata,
            metadata.hasCropping,
            let cropRect = metadata.cropRect
        else {
            return nil
        }
        
        guard let videoTracks = try? await asset.loadTracks(withMediaType: .video),
              let videoTrack = videoTracks.first else {
            return nil
        }
        
        let naturalSize = (try? await videoTrack.load(.naturalSize)) ?? CGSize(width: 1920, height: 1080)
        let preferredTransform = (try? await videoTrack.load(.preferredTransform)) ?? .identity
        let renderSize = NormalizeOrientation.uprightExtent(
            naturalSize: naturalSize,
            preferred: preferredTransform
        )
        
        let instruction = AVMutableVideoCompositionInstruction()
        let assetDuration = (try? await asset.load(.duration)) ?? .zero
        instruction.timeRange = CMTimeRange(start: .zero, duration: assetDuration)
        
        let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)
        let cropTransform = createCropTransform(
            naturalSize: naturalSize,
            preferredTransform: preferredTransform,
            cropRect: cropRect,
            renderSize: renderSize,
            rotationDegrees: CGFloat(metadata.cropRotationDegrees ?? 0)
        )
        let finalTransform = cropTransform
        layerInstruction.setTransform(finalTransform, at: .zero)
        
        instruction.layerInstructions = [layerInstruction]
        
        let composition = AVMutableVideoComposition()
        composition.frameDuration = CMTime(value: 1, timescale: 30)
        composition.renderSize = renderSize
        composition.instructions = [instruction]
        
        return composition
    }
    
    private static func trimTimeRange(from metadata: TakeEditMetadata?, assetDuration: Double) -> CMTimeRange? {
        guard
            let metadata,
            metadata.hasTrimming,
            let start = metadata.trimStartTime,
            let end = metadata.trimEndTime,
            end > start
        else {
            return nil
        }
        
        let clampedStart = max(0, min(start, assetDuration))
        let clampedEnd = max(clampedStart, min(end, assetDuration))
        guard clampedEnd > clampedStart else { return nil }
        
        let startTime = CMTime(seconds: clampedStart, preferredTimescale: 600)
        let duration = CMTime(seconds: clampedEnd - clampedStart, preferredTimescale: 600)
        return CMTimeRange(start: startTime, duration: duration)
    }
    
    private static func createCropTransform(
        naturalSize: CGSize,
        preferredTransform: CGAffineTransform,
        cropRect: CGRect,
        renderSize: CGSize,
        rotationDegrees: CGFloat
    ) -> CGAffineTransform {
        var workingTransform = NormalizeOrientation.aspectFitTransform(
            naturalSize: naturalSize,
            preferred: preferredTransform,
            renderSize: renderSize
        )
        
        let rotationRadians = rotationDegrees * (.pi / 180)
        if abs(rotationRadians) > 0.0001 {
            let center = CGPoint(x: renderSize.width / 2, y: renderSize.height / 2)
            let rotationTransform = CGAffineTransform(translationX: center.x, y: center.y)
                .rotated(by: rotationRadians)
                .translatedBy(x: -center.x, y: -center.y)
            workingTransform = workingTransform.concatenating(rotationTransform)
        }
        
        let cropScaleX = 1.0 / cropRect.width
        let cropScaleY = 1.0 / cropRect.height
        let cropTranslateX = -cropRect.origin.x * cropScaleX
        let cropTranslateY = -cropRect.origin.y * cropScaleY
        
        let cropTransform = CGAffineTransform(scaleX: cropScaleX, y: cropScaleY)
            .translatedBy(x: cropTranslateX, y: cropTranslateY)
        
        return workingTransform.concatenating(cropTransform)
    }
}

private extension CMTime {
    var secondsOrZero: Double {
        let value = CMTimeGetSeconds(self)
        return value.isFinite && !value.isNaN ? value : 0
    }
}
