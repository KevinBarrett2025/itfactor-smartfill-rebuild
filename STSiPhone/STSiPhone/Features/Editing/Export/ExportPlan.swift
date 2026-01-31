import Foundation
import AVFoundation

public struct ExportPlan: @unchecked Sendable {
    public let asset: AVAsset
    public let videoComposition: AVVideoComposition?
    public let audioMix: AVAudioMix?
    public let outputURL: URL
    public let presetName: String
    public let outputFileType: AVFileType
    public let timeRange: CMTimeRange?
    public let metadata: [AVMetadataItem]

    public init(asset: AVAsset,
                videoComposition: AVVideoComposition?,
                audioMix: AVAudioMix?,
                outputURL: URL,
                presetName: String,
                outputFileType: AVFileType,
                timeRange: CMTimeRange? = nil,
                metadata: [AVMetadataItem] = []) {
        self.asset = asset
        self.videoComposition = videoComposition
        self.audioMix = audioMix
        self.outputURL = outputURL
        self.presetName = presetName
        self.outputFileType = outputFileType
        self.timeRange = timeRange
        self.metadata = metadata
    }
}

public struct SessionExportActorOptions: Sendable {
    public let progressIntervalMilliseconds: Int

    public init(progressIntervalMilliseconds: Int = 250) {
        self.progressIntervalMilliseconds = progressIntervalMilliseconds
    }
}
