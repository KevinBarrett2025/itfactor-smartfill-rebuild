import Foundation
import AVFoundation
import Combine
import CoreGraphics
import SwiftUI

enum EnterpriseEditorCloseReason: String, Sendable {
    case saved
    case cancelled
    case discarded
}

@MainActor
/// Shared editing state for the enterprise editor surface.
final class EnterpriseEditorContext: ObservableObject {
    static let fullFrame = CGRect(x: 0, y: 0, width: 1, height: 1)
    
    private struct EditorSnapshot {
        let trimRange: ClosedRange<Double>
        let playhead: Double
        let cropRect: CGRect
        let cropRotation: Double
    }
    
    enum UndoDomain {
        case trim
        case crop
    }
    
    @Published var trimRange: ClosedRange<Double>
    @Published var playhead: Double
    @Published var cropRect: CGRect
    @Published var cropRotationDegrees: Double
    @Published var isCropEditing: Bool = false
    @Published var isRotationEditing: Bool = false
    @Published private(set) var isPlaying: Bool = false
    @Published private(set) var waveformSamples: [CGFloat] = []
    @Published private(set) var hasUnsavedChanges: Bool = false
    var hasSmartFillAvailable: Bool = false
    var onSmartFillBadgeTapped: (() -> Void)?
    var onPlaybackToggle: (() -> Void)?
    
    private let durationSeconds: Double
    private let durationTime: CMTime
    let videoAspectRatio: CGFloat
    private var committedCropRect: CGRect
    private var committedCropRotationDegrees: Double
    private var committedTrimRange: ClosedRange<Double>
    private var undoStack: [EditorSnapshot] = []
    private var activeUndoDomains: Set<UndoDomain> = []
    private let undoStackLimit = 200
    private var trimEndObserver: Any?
    private var cropAutoApplyTask: DispatchWorkItem?
    private let cropAutoApplyDelay: TimeInterval = 1.2
    let player: AVPlayer
    let videoDimensions: CGSize
    private var idleTimerToken: IdleTimerController.Token?

    private let onApplyTrim: (CMTimeRange) -> Void
    private let onRevertTrim: () -> Void
    private let onApplyCrop: (CGRect, Double) -> Void
    private let onClearCrop: () -> Void
    private let onScrub: (CMTime) -> Void
    private let onSeek: ((CMTime, SeekScheduler.Policy) -> Void)?
    private let onUndoAppliedEdit: () -> Void
    private let onSave: () -> Void
    private let onClose: (EnterpriseEditorCloseReason) -> Void
    
    private let timeFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.zeroFormattingBehavior = [.pad]
        return formatter
    }()
    
    init(asset: AVAsset,
         player: AVPlayer,
         existingTrimRange: CMTimeRange?,
         existingCropRect: CGRect?,
         existingCropRotation: Double = 0,
         onApplyTrim: @escaping (CMTimeRange) -> Void,
         onRevertTrim: @escaping () -> Void,
         onApplyCrop: @escaping (CGRect, Double) -> Void,
         onClearCrop: @escaping () -> Void,
         onScrub: @escaping (CMTime) -> Void,
         onSeek: ((CMTime, SeekScheduler.Policy) -> Void)? = nil,
         onUndoApplied: @escaping () -> Void,
         onSave: @escaping () -> Void,
         onClose: @escaping (EnterpriseEditorCloseReason) -> Void) async {
        self.player = player
        self.onApplyTrim = onApplyTrim
        self.onRevertTrim = onRevertTrim
        self.onApplyCrop = onApplyCrop
        self.onClearCrop = onClearCrop
        self.onScrub = onScrub
        self.onSeek = onSeek
        self.onUndoAppliedEdit = onUndoApplied
        self.onSave = onSave
        self.onClose = onClose
        
        let duration = (try? await asset.load(.duration)) ?? CMTime(seconds: 1.0, preferredTimescale: 600)
        let seconds = CMTimeGetSeconds(duration)
        let safeDurationSeconds = seconds.isNormal && seconds > 0 ? seconds : 1.0
        self.durationSeconds = safeDurationSeconds
        self.durationTime = seconds.isNormal && seconds > 0 ? duration : CMTime(seconds: 1.0, preferredTimescale: 600)
        let dimensions = await EnterpriseEditorContext.resolveDimensions(for: asset)
        self.videoDimensions = dimensions
        self.videoAspectRatio = dimensions.width / max(0.001, dimensions.height)
        
        let normalizedTrim = EnterpriseEditorContext.normalize(range: existingTrimRange, durationSeconds: safeDurationSeconds)
        self.trimRange = normalizedTrim
        self.playhead = normalizedTrim.lowerBound
        let sanitizedCrop = EnterpriseEditorContext.sanitizeCrop(existingCropRect ?? Self.fullFrame)
        self.cropRect = sanitizedCrop
        self.cropRotationDegrees = existingCropRotation
        self.committedCropRect = sanitizedCrop
        self.committedCropRotationDegrees = existingCropRotation
        self.committedTrimRange = normalizedTrim
        
        scheduleWaveformGeneration(for: asset)
    }
    
    // MARK: - Undo Snapshot Management
    
    private func pushSnapshot() {
        let snapshot = EditorSnapshot(
            trimRange: trimRange,
            playhead: playhead,
            cropRect: cropRect,
            cropRotation: cropRotationDegrees
        )
        undoStack.append(snapshot)
        if undoStack.count > undoStackLimit {
            undoStack.removeFirst(undoStack.count - undoStackLimit)
        }
    }
    
    func beginTrimGestureUndoCapture() {
        beginUndoCapture(for: .trim)
    }
    
    func endTrimGestureUndoCapture() {
        endUndoCapture(for: .trim)
    }
    
    func beginCropGestureUndoCapture() {
        beginUndoCapture(for: .crop)
    }
    
    func endCropGestureUndoCapture() {
        endUndoCapture(for: .crop)
    }
    
    func recordDiscreteTrimSnapshot() {
        pushSnapshot()
    }
    
    func recordDiscreteCropSnapshot() {
        pushSnapshot()
    }
    
    private func beginUndoCapture(for domain: UndoDomain) {
        if activeUndoDomains.contains(domain) { return }
        pushSnapshot()
        activeUndoDomains.insert(domain)
    }
    
    private func endUndoCapture(for domain: UndoDomain) {
        activeUndoDomains.remove(domain)
    }
    
    // MARK: - Playback
    
    @MainActor
    deinit {
        removeTrimBoundaryObserver()
        idleTimerToken?.release()
    }
    
    func togglePlayback() {
        requestTogglePlayback()
    }

    func requestTogglePlayback() {
        if let onPlaybackToggle {
            onPlaybackToggle()
            return
        }
        performTogglePlayback()
    }

    func performTogglePlayback() {
#if DEBUG
        let playerID = ObjectIdentifier(player)
        let itemID = player.currentItem.map { ObjectIdentifier($0) }
        print("🎮 ENTERPRISE PLAY: player=\(String(describing: playerID)) item=\(String(describing: itemID)) rate=\(player.rate) status=\(player.timeControlStatus.rawValue) time=\(player.currentTime().seconds)")
#endif
        if isPlaying {
            player.pause()
            removeTrimBoundaryObserver()
        } else {
            let startTime = cmTime(for: trimRange.lowerBound)
            let endTime = cmTime(for: trimRange.upperBound)
            let currentTime = player.currentTime()
            let nearEnd = CMTimeCompare(currentTime, endTime) >= 0 || abs(playhead - trimRange.upperBound) < 0.001
            if CMTimeCompare(currentTime, startTime) < 0 || CMTimeCompare(currentTime, endTime) > 0 || nearEnd {
                if let onSeek {
                    onSeek(startTime, .settle)
                } else {
                    player.seek(to: startTime, toleranceBefore: .zero, toleranceAfter: .zero)
                }
                playhead = trimRange.lowerBound
            }
            installTrimBoundaryObserver(at: endTime)
            player.play()
        }
        updatePlaybackStateFromPlayer()
    }
    
    func updatePlaybackStateFromPlayer() {
        let playing = (player.rate > 0.01)
        if isPlaying != playing {
            isPlaying = playing
            if !playing {
                removeTrimBoundaryObserver()
            }
        }
        updateIdleTimer(playing)
    }

    private func updateIdleTimer(_ isPlaying: Bool) {
        if isPlaying {
            if idleTimerToken == nil {
                idleTimerToken = IdleTimerController.shared.acquire(reason: "EnterpriseEditor")
            }
        } else {
            idleTimerToken?.release()
            idleTimerToken = nil
        }
    }
    
    func updatePlayhead(with time: CMTime) {
        guard durationSeconds > 0 else { return }
        let normalized = clamp(CMTimeGetSeconds(time) / durationSeconds)
        let trimmed = min(max(normalized, trimRange.lowerBound), trimRange.upperBound)
        if abs(trimmed - playhead) > 0.0005 {
            playhead = trimmed
        }
    }
    
    // MARK: - Trim
    
    func updateTrimRange(to newRange: ClosedRange<Double>) {
        let clamped = clampedRange(newRange)
        trimRange = clamped
        playhead = min(max(playhead, clamped.lowerBound), clamped.upperBound)
        if isPlaying {
            let endTime = cmTime(for: clamped.upperBound)
            installTrimBoundaryObserver(at: endTime)
        }
    }
    
    func setPlayhead(to normalizedValue: Double) {
        let clamped = clamp(normalizedValue)
        let trimmed = min(max(clamped, trimRange.lowerBound), trimRange.upperBound)
        playhead = trimmed
        onScrub(cmTime(for: trimmed))
    }
    
    func setInPointToPlayhead() {
        recordDiscreteTrimSnapshot()
        updateTrimRange(to: clampRange(start: playhead, end: trimRange.upperBound))
    }
    
    func setOutPointToPlayhead() {
        recordDiscreteTrimSnapshot()
        updateTrimRange(to: clampRange(start: trimRange.lowerBound, end: playhead))
    }
    
    func jump(by seconds: Double) {
        guard durationSeconds > 0 else { return }
        let offset = playhead + (seconds / durationSeconds)
        setPlayhead(to: offset)
    }
    
    func applyTrim() {
        guard hasPendingTrimChanges else { return }
        let startTime = cmTime(for: trimRange.lowerBound)
        let endTime = cmTime(for: trimRange.upperBound)
        guard endTime > startTime else { return }
        onApplyTrim(CMTimeRange(start: startTime, end: endTime))
        committedTrimRange = trimRange
        markUnsavedChanges()
    }
    
    func revertTrim() {
        recordDiscreteTrimSnapshot()
        trimRange = 0.0...1.0
        playhead = trimRange.lowerBound
        onRevertTrim()
        committedTrimRange = trimRange
        markUnsavedChanges()
    }
    
    // MARK: - Crop
    
    func updateCropRect(_ newRect: CGRect) {
        cropRect = EnterpriseEditorContext.sanitizeCrop(newRect)
    }
    
    func resetCrop() {
        recordDiscreteCropSnapshot()
        cropRect = Self.fullFrame
        markUnsavedChanges()
    }
    
    func applyCropAspectRatio(_ aspectRatio: CGFloat?) {
        guard let ratio = aspectRatio else {
            resetCrop()
            return
        }
        
        var targetWidth: CGFloat = 1.0
        var targetHeight: CGFloat = targetWidth / ratio
        if targetHeight > 1.0 {
            targetHeight = 1.0
            targetWidth = targetHeight * ratio
        }
        if targetWidth > 1.0 {
            targetWidth = 1.0
            targetHeight = targetWidth / ratio
        }
        
        let center = CGPoint(x: cropRect.midX, y: cropRect.midY)
        var newRect = CGRect(
            x: center.x - targetWidth / 2,
            y: center.y - targetHeight / 2,
            width: targetWidth,
            height: targetHeight
        )
        newRect = EnterpriseEditorContext.sanitizeCrop(newRect)
        cropRect = newRect
        markUnsavedChanges()
    }
    
    func applyCrop() {
        cancelPendingCropAutoApply()
        let sanitized = EnterpriseEditorContext.sanitizeCrop(cropRect)
        onApplyCrop(sanitized, cropRotationDegrees)
        committedCropRect = cropRect
        committedCropRotationDegrees = cropRotationDegrees
        withAnimation(.easeInOut(duration: 0.45)) {
            isCropEditing = false
            isRotationEditing = false
        }
        markUnsavedChanges()
    }
    
    func clearCrop() {
        recordDiscreteCropSnapshot()
        cropRect = Self.fullFrame
        cropRotationDegrees = 0
        onClearCrop()
        committedCropRect = Self.fullFrame
        committedCropRotationDegrees = 0
        isCropEditing = false
        markUnsavedChanges()
    }
    
    func toggleCropMode() {
        cancelPendingCropAutoApply()
        if isCropEditing {
            if hasPendingCropChanges {
                applyCrop()
            } else {
                withAnimation(.easeInOut(duration: 0.45)) {
                    isCropEditing = false
                }
            }
        } else {
            isRotationEditing = false
            withAnimation(.easeInOut(duration: 0.35)) {
                isCropEditing = true
            }
            cropAutoApplyTask?.cancel()
        }
    }
    
    func toggleRotationMode() {
        cancelPendingCropAutoApply()
        if isRotationEditing {
            if hasPendingCropChanges {
                applyCrop()
            } else {
                withAnimation(.easeInOut(duration: 0.45)) {
                    isRotationEditing = false
                }
            }
        } else {
            isCropEditing = false
            withAnimation(.easeInOut(duration: 0.35)) {
                isRotationEditing = true
            }
            cropAutoApplyTask?.cancel()
        }
    }
    
    func isCropMatching(ratio: CGFloat, tolerance: CGFloat = 0.02) -> Bool {
        guard !isCropFullFrame else { return false }
        let current = cropAspectRatio
        return abs(current - ratio) < tolerance
    }
    
    // MARK: - External Sync
    
    func syncWithEditStack(trimRange range: CMTimeRange?, cropRect rect: CGRect?, cropRotation rotation: Double?) {
        let normalizedTrim = EnterpriseEditorContext.normalize(range: range, durationSeconds: durationSeconds)
        trimRange = normalizedTrim
        playhead = min(max(playhead, normalizedTrim.lowerBound), normalizedTrim.upperBound)
        committedTrimRange = normalizedTrim
        
        if let rect {
            let sanitized = EnterpriseEditorContext.sanitizeCrop(rect)
            cropRect = sanitized
            committedCropRect = sanitized
        } else {
            cropRect = Self.fullFrame
            committedCropRect = Self.fullFrame
        }
        if let rotation {
            cropRotationDegrees = rotation
            committedCropRotationDegrees = rotation
        } else {
            cropRotationDegrees = 0
            committedCropRotationDegrees = 0
        }
        hasUnsavedChanges = false
    }
    
    func commitPendingEdits() {
        if hasPendingTrimChanges {
            applyTrim()
        }
        if hasPendingCropChanges {
            applyCrop()
        }
    }
    
    func performUndoAction() {
        if let snapshot = undoStack.popLast() {
            trimRange = snapshot.trimRange
            playhead = snapshot.playhead
            cropRect = snapshot.cropRect
            cropRotationDegrees = snapshot.cropRotation
            markUnsavedChanges()
        } else if hasPendingChanges {
            trimRange = committedTrimRange
            playhead = trimRange.lowerBound
            cropRect = committedCropRect
            cropRotationDegrees = committedCropRotationDegrees
            markUnsavedChanges()
        } else {
            onUndoAppliedEdit()
            markUnsavedChanges()
        }
    }
    
    func saveEdits() {
        commitPendingEdits()
        onSave()
        hasUnsavedChanges = false
    }
    
    func requestClose(reason: EnterpriseEditorCloseReason) {
        onClose(reason)
    }
    
    // MARK: - Time Formatting
    
    var inPointTimecode: String { formatSeconds(trimRange.lowerBound * durationSeconds) }
    var outPointTimecode: String { formatSeconds(trimRange.upperBound * durationSeconds) }
    var playheadTimecode: String { formatSeconds(playhead * durationSeconds) }
    var clipDurationTimecode: String { formatSeconds(durationSeconds) }
    var trimmedDurationTimecode: String {
        let trimmedSeconds = max(0, (trimRange.upperBound - trimRange.lowerBound) * durationSeconds)
        return formatSeconds(trimmedSeconds)
    }
    var committedTrimTimeRange: CMTimeRange? {
        guard !EnterpriseEditorContext.rangesApproximatelyEqual(committedTrimRange, 0.0...1.0) else { return nil }
        let startTime = cmTime(for: committedTrimRange.lowerBound)
        let endTime = cmTime(for: committedTrimRange.upperBound)
        return CMTimeRange(start: startTime, end: endTime)
    }
    var committedCropRectValue: CGRect? {
        EnterpriseEditorContext.isApproximatelyFullFrame(committedCropRect) ? nil : committedCropRect
    }
    var committedCropRotationValue: Double? {
        abs(committedCropRotationDegrees) > 0.01 ? committedCropRotationDegrees : nil
    }
    var hasPendingCropChanges: Bool {
        !EnterpriseEditorContext.rectApproximatelyEqual(cropRect, committedCropRect) || abs(cropRotationDegrees - committedCropRotationDegrees) > 0.01
    }
    var hasPendingTrimChanges: Bool {
        !EnterpriseEditorContext.rangesApproximatelyEqual(trimRange, committedTrimRange)
    }
    var hasPendingChanges: Bool {
        hasPendingTrimChanges || hasPendingCropChanges
    }
    var hasCommittedCrop: Bool {
        !EnterpriseEditorContext.isApproximatelyFullFrame(committedCropRect)
    }
    var isTrimFullRange: Bool {
        EnterpriseEditorContext.rangesApproximatelyEqual(trimRange, 0.0...1.0)
    }
    var canApplyTrim: Bool {
        hasPendingTrimChanges
    }
    var cropAspectRatio: CGFloat {
        let height = max(0.001, cropRect.height)
        return cropRect.width / height
    }
    var isCropFullFrame: Bool {
        Self.isApproximatelyFullFrame(cropRect)
    }
    
    // MARK: - Helpers
    
    private func cmTime(for normalizedValue: Double) -> CMTime {
        let seconds = durationSeconds * clamp(normalizedValue)
        return CMTime(seconds: seconds, preferredTimescale: durationTime.timescale == 0 ? 600 : durationTime.timescale)
    }
    
    private func formatSeconds(_ seconds: Double) -> String {
        return timeFormatter.string(from: seconds) ?? "00:00"
    }
    
    private func clamp(_ value: Double) -> Double {
        min(max(0.0, value), 1.0)
    }
    
    private func clampRange(start: Double, end: Double) -> ClosedRange<Double> {
        let minGap: Double = 0.005
        let clampedStart = clamp(start)
        let clampedEnd = max(clamp(end), clampedStart + minGap)
        return clampedStart...min(clampedEnd, 1.0)
    }
    
    private func clampedRange(_ range: ClosedRange<Double>) -> ClosedRange<Double> {
        clampRange(start: range.lowerBound, end: range.upperBound)
    }
    
    private func installTrimBoundaryObserver(at endTime: CMTime) {
        removeTrimBoundaryObserver()
        trimEndObserver = player.addBoundaryTimeObserver(forTimes: [NSValue(time: endTime)], queue: .main) { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.player.pause()
                self.removeTrimBoundaryObserver()
                self.updatePlaybackStateFromPlayer()
                self.playhead = self.trimRange.upperBound
            }
        }
    }
    
    private func removeTrimBoundaryObserver() {
        if let observer = trimEndObserver {
            player.removeTimeObserver(observer)
            trimEndObserver = nil
        }
    }
    
    func scheduleCropAutoApply() {
        guard isCropEditing || isRotationEditing else { return }
        cropAutoApplyTask?.cancel()
        let task = DispatchWorkItem { [weak self] in
            guard let self else { return }
            if self.isCropEditing || self.isRotationEditing {
                if self.hasPendingCropChanges {
                    self.applyCrop()
                } else {
                    withAnimation(.easeInOut(duration: 0.35)) {
                        if self.isCropEditing { self.isCropEditing = false }
                        if self.isRotationEditing { self.isRotationEditing = false }
                    }
                }
            }
        }
        cropAutoApplyTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + cropAutoApplyDelay, execute: task)
    }
    
    func cancelPendingCropAutoApply() {
        cropAutoApplyTask?.cancel()
        cropAutoApplyTask = nil
    }
    
    private static func sanitizeCrop(_ rect: CGRect) -> CGRect {
        var sanitized = rect
        sanitized.origin.x = max(0.0, min(1.0, sanitized.origin.x))
        sanitized.origin.y = max(0.0, min(1.0, sanitized.origin.y))
        sanitized.size.width = max(0.05, min(1.0 - sanitized.origin.x, sanitized.size.width))
        sanitized.size.height = max(0.05, min(1.0 - sanitized.origin.y, sanitized.size.height))
        return sanitized
    }
    
    private static func resolveDimensions(for asset: AVAsset) async -> CGSize {
        do {
            let tracks = try await asset.loadTracks(withMediaType: .video)
            guard let track = tracks.first else {
                return CGSize(width: 16, height: 9)
            }
            let naturalSize = try await track.load(.naturalSize)
            let transform = try await track.load(.preferredTransform)
            let transformedSize = naturalSize.applying(transform)
            let width = abs(transformedSize.width)
            let height = abs(transformedSize.height)
            guard width > 0.01, height > 0.01 else {
                return CGSize(width: 16, height: 9)
            }
            return CGSize(width: width, height: height)
        } catch {
            return CGSize(width: 16, height: 9)
        }
    }
    
    private static func normalize(range: CMTimeRange?, durationSeconds: Double) -> ClosedRange<Double> {
        guard let range = range, durationSeconds > 0 else {
            return 0.0...1.0
        }
        
        let startNorm = max(0, min(1, CMTimeGetSeconds(range.start) / durationSeconds))
        let endNorm = max(startNorm, min(1, CMTimeGetSeconds(range.end) / durationSeconds))
        return startNorm...max(endNorm, startNorm + 0.01)
    }
    
    private static func isApproximatelyFullFrame(_ rect: CGRect, tolerance: CGFloat = 0.005) -> Bool {
        let originCheck = rect.origin.x < tolerance && rect.origin.y < tolerance
        let sizeCheck = abs(rect.width - 1.0) < tolerance && abs(rect.height - 1.0) < tolerance
        return originCheck && sizeCheck
    }
    
    private static func rectApproximatelyEqual(_ lhs: CGRect, _ rhs: CGRect, tolerance: CGFloat = 0.002) -> Bool {
        abs(lhs.origin.x - rhs.origin.x) < tolerance &&
        abs(lhs.origin.y - rhs.origin.y) < tolerance &&
        abs(lhs.size.width - rhs.size.width) < tolerance &&
        abs(lhs.size.height - rhs.size.height) < tolerance
    }
    
private static func rangesApproximatelyEqual(_ lhs: ClosedRange<Double>, _ rhs: ClosedRange<Double>, tolerance: Double = 0.001) -> Bool {
        abs(lhs.lowerBound - rhs.lowerBound) < tolerance &&
        abs(lhs.upperBound - rhs.upperBound) < tolerance
    }
    
    // MARK: - Waveform Generation
    
    private func scheduleWaveformGeneration(for asset: AVAsset) {
        let weakContext = WeakEnterpriseEditorContext(self)
        Task.detached(priority: .utility) {
            let samples = await Self.generateWaveformSamples(from: asset, desiredCount: 240)
            guard !Task.isCancelled else { return }
            if let context = weakContext.context {
                await context.applyWaveformSamples(samples)
            }
        }
    }
    
    @MainActor
    private func applyWaveformSamples(_ samples: [CGFloat]) {
        waveformSamples = samples
    }
    
    private func markUnsavedChanges() {
        hasUnsavedChanges = true
    }
    
    nonisolated private static func generateWaveformSamples(from asset: AVAsset, desiredCount: Int) async -> [CGFloat] {
        do {
            let tracks = try await asset.loadTracks(withMediaType: .audio)
            guard let audioTrack = tracks.first else { return [] }
            
            let reader = try AVAssetReader(asset: asset)
            let outputSettings: [String: Any] = [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVLinearPCMIsFloatKey: true,
                AVLinearPCMBitDepthKey: 32,
                AVLinearPCMIsBigEndianKey: false,
                AVLinearPCMIsNonInterleaved: false
            ]
            let output = AVAssetReaderTrackOutput(track: audioTrack, outputSettings: outputSettings)
            output.alwaysCopiesSampleData = false
            guard reader.canAdd(output) else { return [] }
            reader.add(output)
            reader.startReading()
            
            var collected: [CGFloat] = []
            while reader.status == .reading {
                guard let sampleBuffer = output.copyNextSampleBuffer(),
                      let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer)
                else {
                    break
                }
                
                let length = CMBlockBufferGetDataLength(blockBuffer)
                var data = Data(count: length)
                data.withUnsafeMutableBytes { ptr in
                    guard let addr = ptr.baseAddress else { return }
                    CMBlockBufferCopyDataBytes(blockBuffer, atOffset: 0, dataLength: length, destination: addr)
                }
                
                let floatCount = length / MemoryLayout<Float32>.size
                data.withUnsafeBytes { rawBuffer in
                    guard let base = rawBuffer.baseAddress else { return }
                    let floatPointer = base.assumingMemoryBound(to: Float32.self)
                    for i in stride(from: 0, to: floatCount, by: 2) { // assume stereo interleaved; sample one channel
                        let sample = abs(floatPointer[i])
                        collected.append(CGFloat(sample))
                    }
                }
                
                CMSampleBufferInvalidate(sampleBuffer)
            }
            
            guard !collected.isEmpty else { return [] }
            let downsampled = downsample(samples: collected, target: desiredCount)
            let maxValue = downsampled.max() ?? 0.0001
            return downsampled.map { min(1, $0 / maxValue) }
        } catch {
            print("Waveform generation failed: \(error)")
            return []
        }
    }
    
    nonisolated private static func downsample(samples: [CGFloat], target: Int) -> [CGFloat] {
        guard samples.count > target, target > 0 else { return samples }
        let bucketSize = max(1, samples.count / target)
        var result: [CGFloat] = []
        result.reserveCapacity(target)
        var index = 0
        while index < samples.count {
            let end = min(samples.count, index + bucketSize)
            let slice = samples[index..<end]
            result.append(slice.max() ?? 0)
            index += bucketSize
        }
        return result
    }
}

private final class WeakEnterpriseEditorContext: @unchecked Sendable {
    weak var context: EnterpriseEditorContext?
    init(_ context: EnterpriseEditorContext) {
        self.context = context
    }
}
