import CoreGraphics
import AVFoundation

/// Geometry helpers for SmartFill exports.
/// Provides rotation-aware, perfectly-centered transforms for portrait to landscape rendering.
enum STSSmartFillGeometry {
    
    static func centeredTransform(
        natural: CGSize,
        render: CGSize,
        rotation: STSRotation,
        mode: STSAspectMode = .aspectFit
    ) -> CGAffineTransform {
        let scale: CGFloat
        switch rotation {
        case .right90, .left90:
            let widthScale = render.width / natural.height
            let heightScale = render.height / natural.width
            scale = (mode == .aspectFit) ? min(widthScale, heightScale) : max(widthScale, heightScale)
        case .none, .halfTurn:
            let widthScale = render.width / natural.width
            let heightScale = render.height / natural.height
            scale = (mode == .aspectFit) ? min(widthScale, heightScale) : max(widthScale, heightScale)
        }
        
        let scaled = CGSize(width: natural.width * scale, height: natural.height * scale)
        let rotatedSize: CGSize = {
            switch rotation {
            case .right90, .left90:
                return CGSize(width: scaled.height, height: scaled.width)
            case .none, .halfTurn:
                return scaled
            }
        }()
        
        let centerTx = (render.width - rotatedSize.width) / 2.0
        let centerTy = (render.height - rotatedSize.height) / 2.0
        
        var transform = CGAffineTransform.identity
        transform = transform.translatedBy(
            x: centerTx + rotatedSize.width / 2.0,
            y: centerTy + rotatedSize.height / 2.0
        )
        
        switch rotation {
        case .right90:
            transform = transform.rotated(by: .pi / 2)
        case .left90:
            transform = transform.rotated(by: -.pi / 2)
        case .halfTurn:
            transform = transform.rotated(by: .pi)
        case .none:
            break
        }
        
        transform = transform.scaledBy(x: scale, y: scale)
        transform = transform.translatedBy(x: -natural.width / 2.0, y: -natural.height / 2.0)
        return transform
    }
    
    static func makeVideoComposition(
        for asset: AVAsset,
        renderSize: CGSize,
        rotation: STSRotation,
        mode: STSAspectMode = .aspectFit,
        frameRate: Int32 = 30
    ) async throws -> (AVMutableComposition, AVMutableVideoComposition) {
        let videoTracks = try await asset.loadTracks(withMediaType: .video)
        guard let videoTrack = videoTracks.first else {
            throw NSError(
                domain: "STSSmartFillGeometry",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "No video track"]
            )
        }
        let assetDuration = try await asset.load(.duration)
        
        let composition = AVMutableComposition()
        guard let compTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            throw NSError(
                domain: "STSSmartFillGeometry",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Unable to create composition track"]
            )
        }
        
        try compTrack.insertTimeRange(
            CMTimeRange(start: .zero, duration: assetDuration),
            of: videoTrack,
            at: .zero
        )
        compTrack.preferredTransform = .identity
        
        let transform = centeredTransform(
            natural: try await videoTrack.load(.naturalSize),
            render: renderSize,
            rotation: rotation,
            mode: mode
        )
        
        let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: compTrack)
        layerInstruction.setTransform(transform, at: .zero)
        
        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRange(start: .zero, duration: assetDuration)
        instruction.layerInstructions = [layerInstruction]
        
        let videoComposition = AVMutableVideoComposition()
        videoComposition.renderSize = renderSize
        videoComposition.frameDuration = CMTime(value: 1, timescale: CMTimeScale(frameRate))
        videoComposition.instructions = [instruction]
        
        return (composition, videoComposition)
    }
}

enum STSRotation {
    case none
    case right90
    case left90
    case halfTurn
}

enum STSAspectMode {
    case aspectFit
    case aspectFill
}
