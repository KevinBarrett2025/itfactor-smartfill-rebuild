import Foundation
import AVFoundation

@MainActor
final class EditorCore {
    enum InteractionMode: String {
        case draggingPlayhead
        case draggingTrimStart
        case draggingTrimEnd
        case scrollingTimeline
        case idle
    }

    struct State {
        let playhead: CMTime
        let trimRange: CMTimeRange
        let duration: CMTime
        let isPlaying: Bool
        let interaction: InteractionMode
    }

    private(set) var playhead: CMTime
    private(set) var trimRange: CMTimeRange
    private(set) var duration: CMTime
    private(set) var isPlaying: Bool
    private(set) var interaction: InteractionMode

    var minDuration: CMTime
    var roundingTimescale: CMTimeScale

    var onStateChange: ((State) -> Void)?
    var onSeekRequested: ((CMTime, SeekScheduler.Policy) -> Void)?

    init(
        duration: CMTime,
        trimRange: CMTimeRange? = nil,
        minDuration: CMTime = CMTime(seconds: 0.3, preferredTimescale: 600),
        roundingTimescale: CMTimeScale = 600
    ) {
        self.duration = duration
        let fullRange = CMTimeRange(start: .zero, duration: duration)
        self.trimRange = trimRange ?? fullRange
        self.playhead = self.trimRange.start
        self.isPlaying = false
        self.interaction = .idle
        self.minDuration = minDuration
        self.roundingTimescale = roundingTimescale
        notifyStateChange()
    }

    func updateDuration(_ newDuration: CMTime) {
        duration = newDuration
        trimRange = clampTrimRange(trimRange)
        playhead = clampPlayhead(playhead)
        notifyStateChange()
    }

    func setPlaying(_ playing: Bool) {
        guard isPlaying != playing else { return }
        isPlaying = playing
        notifyStateChange()
    }

    func beginInteraction(_ mode: InteractionMode) {
        guard interaction != mode else { return }
        interaction = mode
        if isPlaying {
            isPlaying = false
        }
        notifyStateChange()
    }

    func endInteraction(finalPlayhead: CMTime? = nil) {
        if let finalPlayhead {
            setPlayhead(finalPlayhead, policy: .settle)
        } else if !contains(playhead, in: trimRange) {
            let clamped = clampPlayhead(playhead)
            playhead = clamped
            onSeekRequested?(clamped, .settle)
        }
        interaction = .idle
        notifyStateChange()
    }

    func updatePlayheadFromPlayer(_ time: CMTime) {
        guard interaction == .idle else { return }
        let clamped = clampPlayhead(time)
        if CMTimeCompare(playhead, clamped) != 0 {
            playhead = clamped
            notifyStateChange()
        }
    }

    @discardableResult
    func ingestPlayerTime(_ time: CMTime) -> CMTime? {
        guard isPlaying, interaction == .idle else { return nil }
        let clamped = clampPlayhead(time)
        if CMTimeCompare(playhead, clamped) != 0 {
            playhead = clamped
            notifyStateChange()
        }
        return clamped
    }

    func setPlayhead(_ time: CMTime, policy: SeekScheduler.Policy) {
        let clamped = clampPlayhead(time)
        if CMTimeCompare(playhead, clamped) != 0 {
            playhead = clamped
            notifyStateChange()
        }
        onSeekRequested?(clamped, policy)
    }

    func setTrimRange(_ range: CMTimeRange, clampPlayhead: Bool) {
        trimRange = clampTrimRange(range)
        if clampPlayhead {
            playhead = clampPlayheadToRange(playhead, range: trimRange)
        }
        notifyStateChange()
    }

    func updateTrimRange(start: CMTime, end: CMTime, isFinal: Bool) {
        trimRange = clampTrimRange(CMTimeRange(start: start, end: end))
        if isFinal {
            playhead = clampPlayheadToRange(playhead, range: trimRange)
        }
        notifyStateChange()
    }

    private func notifyStateChange() {
        onStateChange?(State(
            playhead: playhead,
            trimRange: trimRange,
            duration: duration,
            isPlaying: isPlaying,
            interaction: interaction
        ))
    }

    private func clampPlayhead(_ time: CMTime) -> CMTime {
        clampPlayheadToRange(time, range: trimRange)
    }

    private func clampPlayheadToRange(_ time: CMTime, range: CMTimeRange) -> CMTime {
        let start = range.start
        let end = CMTimeAdd(range.start, range.duration)
        if CMTimeCompare(time, start) < 0 {
            return start
        }
        if CMTimeCompare(time, end) > 0 {
            return end
        }
        return rounded(time)
    }

    private func clampTrimRange(_ range: CMTimeRange) -> CMTimeRange {
        let durationSeconds = max(duration.seconds, 0)
        let minDurationSeconds = max(minDuration.seconds, 0)
        var startSeconds = max(0, min(range.start.seconds, durationSeconds))
        var endSeconds = max(0, min(range.end.seconds, durationSeconds))
        if endSeconds - startSeconds < minDurationSeconds {
            if endSeconds + minDurationSeconds <= durationSeconds {
                endSeconds = startSeconds + minDurationSeconds
            } else if startSeconds - minDurationSeconds >= 0 {
                startSeconds = endSeconds - minDurationSeconds
            } else {
                startSeconds = 0
                endSeconds = min(durationSeconds, minDurationSeconds)
            }
        }
        let start = rounded(CMTime(seconds: startSeconds, preferredTimescale: roundingTimescale))
        let end = rounded(CMTime(seconds: endSeconds, preferredTimescale: roundingTimescale))
        return CMTimeRange(start: start, end: end)
    }

    private func rounded(_ time: CMTime) -> CMTime {
        guard time.isNumeric else { return time }
        return CMTimeConvertScale(time, timescale: roundingTimescale, method: .roundHalfAwayFromZero)
    }

    private func contains(_ time: CMTime, in range: CMTimeRange) -> Bool {
        let start = range.start
        let end = CMTimeAdd(range.start, range.duration)
        return CMTimeCompare(time, start) >= 0 && CMTimeCompare(time, end) <= 0
    }
}
