import SwiftUI
import AVKit

// MARK: - Shared Video Surface

struct EnterpriseVideoSurface: View {
    @ObservedObject var context: EnterpriseEditorContext
    var showCenterOverlay: Bool
    var targetHeight: CGFloat
    var waveformToggle: (() -> Void)? = nil
    var waveformActive: Bool = false
    var fullscreenToggle: (() -> Void)? = nil
    var fullscreenActive: Bool = false
    var contentMode: ContentMode = .fit
    var showsTrimOverlay: Bool = true
    var cornerRadius: CGFloat = 20
    var overlayInsets: EdgeInsets = EdgeInsets(top: 18, leading: 18, bottom: 10, trailing: 18)
    var hideOverlayButtonsWhilePlaying: Bool = false
    
    var body: some View {
        ZStack {
            if context.isCropEditing || context.isRotationEditing {
                CropCanvasRepresentable(
                    player: context.player,
                    videoSize: context.videoDimensions,
                    normalizedCrop: context.cropRect,
                    rotationDegrees: context.cropRotationDegrees,
                    mode: context.isRotationEditing ? .rotate : .crop,
                    onCropChange: { rect in
                        Task { @MainActor in
                            context.updateCropRect(rect)
                        }
                    },
                    onRotationChange: { degrees in
                        Task { @MainActor in
                            context.cropRotationDegrees = degrees
                        }
                    },
                    onInteractionStart: {
                        Task { @MainActor in
                            context.cancelPendingCropAutoApply()
                            context.beginCropGestureUndoCapture()
                        }
                    },
                    onInteractionEnd: {
                        Task { @MainActor in
                            context.endCropGestureUndoCapture()
                            context.scheduleCropAutoApply()
                        }
                    }
                )
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .shadow(color: cornerRadius > 0.1 ? Color.black.opacity(0.45) : .clear, radius: 18, y: 10)
            } else {
                GeometryReader { geo in
                    let cropRect = context.cropRect
                    let scaleX = 1 / max(cropRect.width, 0.0001)
                    let scaleY = 1 / max(cropRect.height, 0.0001)
                    let translationX = (0.5 - cropRect.midX) * geo.size.width
                    let translationY = (0.5 - cropRect.midY) * geo.size.height
                    PlayerLayerView(player: context.player)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .scaleEffect(x: scaleX, y: scaleY, anchor: .center)
                        .offset(x: translationX * scaleX, y: translationY * scaleY)
                        .rotationEffect(.degrees(context.cropRotationDegrees))
                        .animation(.easeInOut(duration: 0.15), value: context.cropRotationDegrees)
                        .clipped()
                }
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .overlay(
                    Group {
                        if cornerRadius > 0.1 {
                            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                .stroke(Color.white.opacity(0.12), lineWidth: 1)
                        }
                    }
                )
                .shadow(color: cornerRadius > 0.1 ? Color.black.opacity(0.45) : .clear, radius: 18, y: 10)
            }
            
            VStack {
                Spacer()
                if !(context.isCropEditing || context.isRotationEditing) {
                    if showCenterOverlay {
                        VideoPlaybackOverlay(context: context)
                            .opacity(context.isPlaying ? 0 : 1)
                            .allowsHitTesting(!context.isPlaying)
                            .animation(.easeInOut(duration: 0.15), value: context.isPlaying)
                            .padding(.bottom, 6)
                    }
                    if showsTrimOverlay {
                        OverlayTrimTrack(context: context)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 10)
                    }
                }
            }
        }
        .aspectRatio(context.videoAspectRatio, contentMode: contentMode)
        .frame(maxWidth: .infinity)
        .frame(height: targetHeight)
        .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .onTapGesture {
            guard !context.isCropEditing else { return }
            if context.isPlaying { context.togglePlayback() }
        }
    }
}

// MARK: - Timeline Controls

struct CompactTimelineControls: View {
    @ObservedObject var context: EnterpriseEditorContext
    var showsPlaybackInCard: Bool
    var onSaveAndExit: () -> Void
    private let chipMinWidth: CGFloat = 106
    
    var body: some View {
        VStack(alignment: .leading, spacing: showsPlaybackInCard ? 14 : 0) {
            HStack(spacing: 0) {
                Spacer(minLength: 0)
                TimelineChipButton(
                    title: "Set In",
                    value: context.inPointTimecode,
                    icon: "arrow.down",
                    minWidth: chipMinWidth,
                    action: { context.setInPointToPlayhead() }
                )
                if showsPlaybackInCard {
                    Spacer(minLength: 18)
                    PlaybackInlineControls(context: context)
                        .frame(maxWidth: .infinity)
                    Spacer(minLength: 18)
                } else {
                    Spacer(minLength: 24)
                }
                TimelineChipButton(
                    title: "Set Out",
                    value: context.outPointTimecode,
                    icon: "arrow.up",
                    minWidth: chipMinWidth,
                    action: { context.setOutPointToPlayhead() }
                )
                Spacer(minLength: 0)
            }
            if showsPlaybackInCard {
                Spacer(minLength: 4)
                HStack(spacing: 10) {
                    Spacer()
                    if context.hasSmartFillAvailable {
                        Button {
                            context.onSmartFillBadgeTapped?()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "person.and.background.dotted")
                                Text("Edit SmartFill")
                                    .font(.caption.weight(.semibold))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(Color.cyan.opacity(0.2))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    IconOnlyButton(systemName: "arrow.uturn.backward") {
                        context.performUndoAction()
                    }
                    TextToolbarButton(
                        title: "Save & Exit",
                        style: context.hasPendingChanges ? .primary : .secondary
                    ) {
                        onSaveAndExit()
                    }
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.02))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }
}

struct LandscapeTrimControls: View {
    @ObservedObject var context: EnterpriseEditorContext
    private let chipMinWidth: CGFloat = 106
    
    var body: some View {
        HStack(spacing: 12) {
            TimelineChipButton(
                title: "Set In",
                value: context.inPointTimecode,
                icon: "arrow.down",
                minWidth: chipMinWidth,
                action: { context.setInPointToPlayhead() }
            )
            TimelineChipButton(
                title: "Set Out",
                value: context.outPointTimecode,
                icon: "arrow.up",
                minWidth: chipMinWidth,
                action: { context.setOutPointToPlayhead() }
            )
            IconOnlyButton(systemName: "arrow.uturn.backward") {
                context.performUndoAction()
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.02))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
        .frame(maxWidth: .infinity, alignment: .center)
    }
}

struct TimelineChipButton: View {
    let title: String
    let value: String
    let icon: String
    var minWidth: CGFloat? = nil
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                VStack(alignment: .leading, spacing: 1) {
                    Text(title.uppercased())
                        .font(.caption2)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                        .foregroundStyle(.white.opacity(0.7))
                    Text(value)
                        .font(.footnote.monospacedDigit())
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .foregroundStyle(.white)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .frame(minWidth: minWidth)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Waveform + Playback

struct WaveformCard: View {
    @ObservedObject var context: EnterpriseEditorContext
    var edgeInsets: EdgeInsets = EdgeInsets()
    var waveformHeight: CGFloat = 54
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                WaveformPlaceholder(
                    samples: context.waveformSamples,
                    playhead: context.playhead,
                    trimRange: context.trimRange
                )
                WaveformTrimOverlay(context: context)
            }
            .frame(height: waveformHeight)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .padding(edgeInsets)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.02))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }
}

struct WaveformPlaceholder: View {
    let samples: [CGFloat]
    let playhead: Double
    let trimRange: ClosedRange<Double>
    
    var body: some View {
        GeometryReader { geo in
            Canvas { context, size in
                guard size.width > 0, size.height > 0 else { return }
                
                let barWidth: CGFloat = 3
                let spacing: CGFloat = 2
                let effectiveSamples = samples.isEmpty ? placeholderSamples(count: max(50, Int(size.width / (barWidth + spacing)))) : samples
                let sampleCount = effectiveSamples.count
                let denominator = CGFloat(max(sampleCount - 1, 1))
                let playX = size.width * playhead
                let trimStartX = size.width * trimRange.lowerBound
                let trimEndX = size.width * trimRange.upperBound
                
                for (index, sample) in effectiveSamples.enumerated() {
                    let fraction = CGFloat(index) / denominator
                    let x = fraction * size.width
                    let amplitude = CGFloat(sample)
                    let height = max(4, amplitude * (size.height - 6))
                    let rect = CGRect(
                        x: x,
                        y: (size.height - height) / 2,
                        width: barWidth,
                        height: height
                    )
                    let isTrimmed = (x >= trimStartX && x <= trimEndX)
                    let fillColor = isTrimmed ? Color.white : Color.white.opacity(0.25)
                    context.fill(
                        Path(roundedRect: rect, cornerRadius: barWidth / 2),
                        with: .color(fillColor)
                    )
                }
                
                let trimLineWidth: CGFloat = 2
                let trimLineHeight = size.height + 6
                let startRectX = max(0, trimStartX - trimLineWidth / 2)
                let endRectX = min(size.width - trimLineWidth, trimEndX - trimLineWidth / 2)
                let trimRectY = (size.height - trimLineHeight) / 2
                
                let startRect = CGRect(x: startRectX, y: trimRectY, width: trimLineWidth, height: trimLineHeight)
                let endRect = CGRect(x: endRectX, y: trimRectY, width: trimLineWidth, height: trimLineHeight)
                context.fill(Path(startRect), with: .color(Color.white.opacity(0.85)))
                context.fill(Path(endRect), with: .color(Color.white.opacity(0.85)))
                
                let playheadRect = CGRect(
                    x: max(0, min(size.width - 1, playX)),
                    y: 0,
                    width: 2,
                    height: size.height
                )
                context.fill(Path(playheadRect), with: .color(.cyan.opacity(0.9)))
            }
        }
    }
    
    private func placeholderSamples(count: Int) -> [CGFloat] {
        guard count > 0 else { return [] }
        return (0..<count).map { index in
            let fraction = CGFloat(index) / CGFloat(max(count - 1, 1))
            let fast = sin((fraction * 12) + 1.3) * 0.4
            let slow = sin((fraction * 5.5) + 0.7) * 0.6
            return abs(fast + slow)
        }
    }
}

struct WaveformTrimOverlay: View {
    @ObservedObject var context: EnterpriseEditorContext
    @State private var draggingHandle: DragHandle?
    
    private enum DragHandle {
        case start, end, playhead
    }
    
    var body: some View {
        GeometryReader { geo in
            let width = max(geo.size.width, 1)
            let height = geo.size.height
            let startX = width * context.trimRange.lowerBound
            let endX = width * context.trimRange.upperBound
            let playheadX = width * context.playhead
            
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.clear)
                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: max(0, endX - startX), height: height)
                    .offset(x: startX)
                Rectangle()
                    .fill(Color.white.opacity(0.85))
                    .frame(width: 2, height: height + 6)
                    .offset(x: max(0, min(width - 2, startX)))
                Rectangle()
                    .fill(Color.white.opacity(0.85))
                    .frame(width: 2, height: height + 6)
                    .offset(x: max(0, min(width - 2, endX - 2)))
                Rectangle()
                    .fill(Color.cyan.opacity(0.9))
                    .frame(width: 2, height: height + 10)
                    .offset(x: max(0, min(width - 2, playheadX)))
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if draggingHandle == nil {
                            context.beginTrimGestureUndoCapture()
                            draggingHandle = determineHandle(
                                startLocation: value.startLocation.x,
                                width: width,
                                startX: startX,
                                endX: endX,
                                playheadX: playheadX
                            )
                        }
                        guard let draggingHandle else { return }
                        let normalized = normalizedValue(for: value.location.x, width: width)
                        switch draggingHandle {
                        case .start:
                            updateStartHandle(to: normalized)
                        case .end:
                            updateEndHandle(to: normalized)
                        case .playhead:
                            context.setPlayhead(to: normalized)
                        }
                    }
                    .onEnded { _ in
                        draggingHandle = nil
                        context.endTrimGestureUndoCapture()
                    }
            )
        }
    }
    
    private func normalizedValue(for x: CGFloat, width: CGFloat) -> Double {
        guard width > 0 else { return 0 }
        return Double(min(max(0, x / width), 1))
    }
    
    private func determineHandle(startLocation: CGFloat, width: CGFloat, startX: CGFloat, endX: CGFloat, playheadX: CGFloat) -> DragHandle {
        let threshold: CGFloat = 24
        if abs(startLocation - startX) <= threshold {
            return .start
        }
        if abs(startLocation - endX) <= threshold {
            return .end
        }
        if abs(startLocation - playheadX) <= threshold {
            return .playhead
        }
        return .playhead
    }
    
    private func updateStartHandle(to value: Double) {
        let upper = context.trimRange.upperBound
        let newLower = min(value, upper - 0.01)
        context.updateTrimRange(to: newLower...upper)
        context.setPlayhead(to: newLower)
    }
    
    private func updateEndHandle(to value: Double) {
        let lower = context.trimRange.lowerBound
        let newUpper = max(value, lower + 0.01)
        context.updateTrimRange(to: lower...newUpper)
        context.setPlayhead(to: newUpper)
    }
}

struct FullscreenWaveformOverlay: View {
    @ObservedObject var context: EnterpriseEditorContext
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            WaveformPlaceholder(
                samples: context.waveformSamples,
                playhead: context.playhead,
                trimRange: context.trimRange
            )
            .frame(height: 36)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.black.opacity(0.45))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
    }
}

struct WaveformOverlayButton: View {
    var isActive: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: "waveform.circle")
                .font(.system(size: 16, weight: .semibold))
                .padding(9)
                .background(
                    Circle()
                        .fill(isActive ? Color.cyan.opacity(0.9) : Color.black.opacity(0.55))
                )
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(isActive ? 0 : 0.2), lineWidth: 1)
                )
                .foregroundStyle(isActive ? Color.black : Color.white.opacity(0.9))
        }
        .buttonStyle(.plain)
    }
}

struct FullscreenOverlayButton: View {
    var isActive: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: isActive ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                .font(.system(size: 16, weight: .semibold))
                .padding(9)
                .background(
                    Circle()
                        .fill(isActive ? Color.white.opacity(0.25) : Color.black.opacity(0.55))
                )
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
                .foregroundStyle(isActive ? Color.white : Color.white.opacity(0.9))
        }
        .buttonStyle(.plain)
    }
}

struct WaveformToggleButton: View {
    @Binding var showWaveform: Bool
    
    var body: some View {
        Button {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                showWaveform.toggle()
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: showWaveform ? "waveform.circle.fill" : "waveform.circle")
                    .font(.system(size: 18, weight: .semibold))
                Text(showWaveform ? "Hide audio waveform" : "Show audio waveform")
                    .font(.callout.weight(.medium))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.white.opacity(0.08))
                    .overlay(
                        Capsule().stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

struct PlaybackInlineControls: View {
    @ObservedObject var context: EnterpriseEditorContext
    var buttonSize: CGFloat = 34
    var spacing: CGFloat = 14
    var horizontalPadding: CGFloat = 12
    
    var body: some View {
        HStack(spacing: spacing) {
            IconOnlyButton(
                systemName: "minus.arrow.trianglehead.counterclockwise",
                diameter: buttonSize
            ) {
                context.jump(by: -2)
            }
            IconOnlyButton(
                systemName: context.isPlaying ? "pause.fill" : "play.fill",
                diameter: buttonSize + 8
            ) {
                context.togglePlayback()
            }
            IconOnlyButton(
                systemName: "plus.arrow.trianglehead.clockwise",
                diameter: buttonSize
            ) {
                context.jump(by: 2)
            }
        }
        .padding(.horizontal, horizontalPadding)
    }
}

// MARK: - Buttons & Helpers

struct TextToolbarButton: View {
    enum Style {
        case primary
        case secondary
    }
    
    let title: String
    let style: Style
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.callout.weight(.semibold))
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(style == .primary ? Color.cyan : Color.white.opacity(0.08))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(
                            style == .primary ? Color.cyan.opacity(0.4) : Color.white.opacity(0.15),
                            lineWidth: 1
                        )
                )
                .foregroundStyle(style == .primary ? Color.black : Color.white)
        }
        .buttonStyle(.plain)
    }
}

struct IconOnlyButton: View {
    let systemName: String
    var diameter: CGFloat = 34
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: diameter * 0.4, weight: .semibold))
                .frame(width: diameter, height: diameter)
                .background(
                    Circle()
                        .fill(Color.white.opacity(0.12))
                        .overlay(
                            Circle().stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                )
                .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
    }
}

struct FloatingCropButton: View {
    var isActive: Bool
    var isDisabled: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: "crop")
                .font(.system(size: 16, weight: .semibold))
                .padding(10)
                .background(
                    Circle()
                        .fill(isActive ? Color.cyan : Color.black.opacity(0.55))
                )
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(isActive ? 0.0 : 0.2), lineWidth: 1)
                )
                .foregroundStyle(isActive ? Color.black : Color.white)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.9 : 1.0)
    }
}

struct FloatingRotateButton: View {
    var isActive: Bool
    var isDisabled: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: "crop.rotate")
                .font(.system(size: 16, weight: .semibold))
                .padding(10)
                .background(
                    Circle()
                        .fill(isActive ? Color.purple : Color.black.opacity(0.55))
                )
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(isActive ? 0.0 : 0.2), lineWidth: 1)
                )
                .foregroundStyle(isActive ? Color.black : Color.white)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.9 : 1.0)
    }
}

struct VideoPlaybackOverlay: View {
    @ObservedObject var context: EnterpriseEditorContext
    
    var body: some View {
        HStack(spacing: 24) {
            IconOnlyButton(systemName: "minus.arrow.trianglehead.counterclockwise") {
                context.jump(by: -2)
            }
            IconOnlyButton(systemName: context.isPlaying ? "pause.fill" : "play.fill", diameter: 48) {
                context.togglePlayback()
            }
            IconOnlyButton(systemName: "plus.arrow.trianglehead.clockwise") {
                context.jump(by: 2)
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 10)
        .background(
            Capsule(style: .continuous)
                .fill(Color.black.opacity(0.35))
                .overlay(
                    Capsule().stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
        )
    }
}

// MARK: - Trim Track with Gestures

struct OverlayTrimTrack: View {
    @ObservedObject var context: EnterpriseEditorContext
    @State private var draggingHandle: DragHandle?
    private let labelHalfWidth: CGFloat = 34
    
    enum DragHandle {
        case start, end, playhead
    }
    
    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let baseHeight: CGFloat = 24
            let handleWidth: CGFloat = 12
            let handleHeight = baseHeight + 10
            let startX = width * context.trimRange.lowerBound
            let endX = width * context.trimRange.upperBound
            let playheadX = width * context.playhead
            let trimmedWidth = max(0, endX - startX)
            let topLabelY = baseHeight / 2 + 18
            let bottomLabelY = baseHeight / 2 + handleHeight / 2 + 10
            let isHandleInteraction = (draggingHandle == .start || draggingHandle == .end)
            
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.1))
                    .frame(height: baseHeight)
                Capsule()
                    .fill(Color.cyan.opacity(0.35))
                    .frame(width: trimmedWidth, height: baseHeight - 4)
                    .offset(x: startX)
                    .overlay {
                        if trimmedWidth > 24 {
                            Text(context.trimmedDurationTimecode)
                                .font(.caption2.monospacedDigit())
                                .foregroundColor(.black.opacity(0.75))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.white.opacity(0.6), in: Capsule())
                                .position(
                                    x: clampedLabelX(startX + trimmedWidth / 2, width: width),
                                    y: (baseHeight - 4) / 2
                                )
                        }
                    }
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Color.white.opacity(0.95))
                    .frame(width: handleWidth, height: handleHeight)
                    .offset(x: max(0, startX - handleWidth / 2), y: -(handleHeight - baseHeight) / 2)
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Color.white.opacity(0.95))
                    .frame(width: handleWidth, height: handleHeight)
                    .offset(x: min(width - handleWidth, endX - handleWidth / 2), y: -(handleHeight - baseHeight) / 2)
                if !isHandleInteraction {
                    Rectangle()
                        .fill(Color.white)
                        .frame(width: 2, height: baseHeight + 6)
                        .offset(x: playheadX - 1)
                    
                    // Playhead timecode (top)
                    Text(context.playheadTimecode)
                        .font(.caption2.monospacedDigit())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.black.opacity(0.65), in: Capsule())
                        .foregroundColor(.white)
                        .position(
                            x: clampedLabelX(playheadX, width: width),
                            y: topLabelY
                        )
                }
                
                if isHandleInteraction {
                    // Handle timecodes (bottom)
                    Text(context.inPointTimecode)
                        .font(.caption2.monospacedDigit())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.black.opacity(0.65), in: Capsule())
                        .foregroundColor(.white)
                        .position(
                            x: clampedLabelX(startX, width: width),
                            y: bottomLabelY
                        )
                    Text(context.outPointTimecode)
                        .font(.caption2.monospacedDigit())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.black.opacity(0.65), in: Capsule())
                        .foregroundColor(.white)
                        .position(
                            x: clampedLabelX(endX, width: width),
                            y: bottomLabelY
                        )
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if draggingHandle == nil {
                            context.beginTrimGestureUndoCapture()
                            draggingHandle = determineHandle(
                                startLocation: value.startLocation.x,
                                width: width,
                                startX: startX,
                                endX: endX,
                                playheadX: playheadX
                            )
                        }
                        guard let draggingHandle else { return }
                        let normalized = normalizedValue(for: value.location.x, width: width)
                        switch draggingHandle {
                        case .start:
                            updateStartHandle(to: normalized)
                        case .end:
                            updateEndHandle(to: normalized)
                        case .playhead:
                            context.setPlayhead(to: normalized)
                        }
                    }
                    .onEnded { _ in
                        draggingHandle = nil
                        context.endTrimGestureUndoCapture()
                    }
            )
        }
        .frame(height: 84)
    }
    
    private func normalizedValue(for x: CGFloat, width: CGFloat) -> Double {
        guard width > 0 else { return 0 }
        return Double(min(max(0, x / width), 1))
    }
    
    private func determineHandle(startLocation: CGFloat, width: CGFloat, startX: CGFloat, endX: CGFloat, playheadX: CGFloat) -> DragHandle {
        let threshold: CGFloat = 24
        if abs(startLocation - startX) <= threshold {
            return .start
        }
        if abs(startLocation - endX) <= threshold {
            return .end
        }
        if abs(startLocation - playheadX) <= threshold {
            return .playhead
        }
        return .playhead
    }
    
    private func updateStartHandle(to value: Double) {
        let upper = context.trimRange.upperBound
        let newLower = min(value, upper - 0.01)
        context.updateTrimRange(to: newLower...upper)
        context.setPlayhead(to: newLower)
    }
    
    private func updateEndHandle(to value: Double) {
        let lower = context.trimRange.lowerBound
        let newUpper = max(value, lower + 0.01)
        context.updateTrimRange(to: lower...newUpper)
        context.setPlayhead(to: newUpper)
    }
    
    private func clampedLabelX(_ x: CGFloat, width: CGFloat) -> CGFloat {
        guard width > 0 else { return 0 }
        return min(max(labelHalfWidth, x), width - labelHalfWidth)
    }
}


// MARK: - Crop Canvas

struct CropCanvasRepresentable: View {
    enum Mode {
        case crop
        case rotate
    }
    
    let player: AVPlayer
    let videoSize: CGSize
    let normalizedCrop: CGRect
    let rotationDegrees: Double
    let mode: Mode
    let onCropChange: (CGRect) -> Void
    let onRotationChange: (Double) -> Void
    let onInteractionStart: () -> Void
    let onInteractionEnd: () -> Void
    
    @State private var visibleFrame: CGRect = .zero
    @State private var cropFrame: CGRect = .zero
    @State private var isInteracting = false
    @State private var dragStartFrame: CGRect = .zero
    @State private var scaleStartFrame: CGRect = .zero
    
    private let minNormalizedSize: CGFloat = 0.05
    
    var body: some View {
        GeometryReader { geo in
            let canvasSize = geo.size
            let fitted = fitRect(videoSize: videoSize, in: canvasSize)
            
            ZStack(alignment: .topLeading) {
                PlayerLayerView(player: player)
                    .frame(width: fitted.width, height: fitted.height)
                    .rotationEffect(.degrees(rotationDegrees))
                    .offset(x: fitted.origin.x, y: fitted.origin.y)
                    .clipped()
                
                cropOverlay(in: canvasSize)
            }
            .onAppear {
                visibleFrame = fitted
                cropFrame = rect(for: normalizedCrop, in: fitted)
            }
            .onChange(of: fitted) { _, newValue in
                visibleFrame = newValue
                cropFrame = rect(for: normalizedCrop, in: newValue)
            }
            .onChange(of: normalizedCrop) { _, newValue in
                cropFrame = rect(for: newValue, in: visibleFrame)
            }
        }
    }
    
    @ViewBuilder
    private func cropOverlay(in canvasSize: CGSize) -> some View {
        let dimPath = Path { path in
            path.addRect(CGRect(origin: .zero, size: canvasSize))
            path.addRect(cropFrame)
        }
        
        dimPath
            .fill(style: FillStyle(eoFill: true))
            .foregroundStyle(Color.black.opacity(0.4))
            .allowsHitTesting(false)
        
        ZStack {
            RoundedRectangle(cornerRadius: 3)
                .stroke(Color.white.opacity(0.9), lineWidth: 2)
                .frame(width: cropFrame.width, height: cropFrame.height)
                .position(x: cropFrame.midX, y: cropFrame.midY)
            
            ForEach(Corner.allCases, id: \.self) { corner in
                handle(at: corner, size: 12)
            }
        }
        .contentShape(Rectangle())
        .gesture(mode == .crop ? dragGesture() : nil)
        .simultaneousGesture(mode == .crop ? pinchGesture() : nil)
    }
    
    private func handle(at corner: Corner, size: CGFloat) -> some View {
        let handleRect = corner.rect(for: cropFrame, size: size)
        return Rectangle()
            .fill(Color.white)
            .frame(width: handleRect.width, height: handleRect.height)
            .position(x: handleRect.midX, y: handleRect.midY)
    }
    
    private func dragGesture() -> some Gesture {
        DragGesture()
            .onChanged { value in
                if !isInteracting {
                    isInteracting = true
                    onInteractionStart()
                    dragStartFrame = cropFrame
                }
                
                var newFrame = dragStartFrame
                newFrame.origin.x += value.translation.width
                newFrame.origin.y += value.translation.height
                
                newFrame = clamped(frame: newFrame, in: visibleFrame)
                cropFrame = newFrame
                onCropChange(normalized(for: newFrame, in: visibleFrame))
            }
            .onEnded { _ in
                if isInteracting {
                    isInteracting = false
                    onInteractionEnd()
                }
            }
    }
    
    private func pinchGesture() -> some Gesture {
        MagnificationGesture()
            .onChanged { scale in
                if !isInteracting {
                    isInteracting = true
                    onInteractionStart()
                    scaleStartFrame = cropFrame
                }
                
                var newFrame = scaleStartFrame
                let center = CGPoint(x: newFrame.midX, y: newFrame.midY)
                newFrame.size.width *= scale
                newFrame.size.height *= scale
                newFrame.origin.x = center.x - newFrame.size.width / 2
                newFrame.origin.y = center.y - newFrame.size.height / 2
                
                newFrame = clamped(frame: newFrame, in: visibleFrame)
                cropFrame = newFrame
                onCropChange(normalized(for: newFrame, in: visibleFrame))
            }
            .onEnded { _ in
                if isInteracting {
                    isInteracting = false
                    onInteractionEnd()
                }
            }
    }
    
    private func fitRect(videoSize: CGSize, in container: CGSize) -> CGRect {
        guard videoSize.width > 0, videoSize.height > 0 else {
            return CGRect(origin: .zero, size: container)
        }
        let aspect = videoSize.width / videoSize.height
        let containerAspect = container.width / container.height
        
        if containerAspect > aspect {
            let height = container.height
            let width = height * aspect
            let originX = (container.width - width) / 2
            return CGRect(x: originX, y: 0, width: width, height: height)
        } else {
            let width = container.width
            let height = width / aspect
            let originY = (container.height - height) / 2
            return CGRect(x: 0, y: originY, width: width, height: height)
        }
    }
    
    private func rect(for normalized: CGRect, in visibleFrame: CGRect) -> CGRect {
        let origin = CGPoint(
            x: visibleFrame.origin.x + normalized.origin.x * visibleFrame.width,
            y: visibleFrame.origin.y + normalized.origin.y * visibleFrame.height
        )
        let size = CGSize(
            width: normalized.size.width * visibleFrame.width,
            height: normalized.size.height * visibleFrame.height
        )
        return CGRect(origin: origin, size: size)
    }
    
    private func normalized(for frame: CGRect, in visibleFrame: CGRect) -> CGRect {
        let origin = CGPoint(
            x: (frame.origin.x - visibleFrame.origin.x) / max(visibleFrame.width, 0.0001),
            y: (frame.origin.y - visibleFrame.origin.y) / max(visibleFrame.height, 0.0001)
        )
        let size = CGSize(
            width: frame.width / max(visibleFrame.width, 0.0001),
            height: frame.height / max(visibleFrame.height, 0.0001)
        )
        return CGRect(origin: origin, size: size)
    }
    
    private func clamped(frame: CGRect, in visibleFrame: CGRect) -> CGRect {
        var rect = frame
        
        let minWidth = visibleFrame.width * minNormalizedSize
        let minHeight = visibleFrame.height * minNormalizedSize
        rect.size.width = max(minWidth, rect.size.width)
        rect.size.height = max(minHeight, rect.size.height)
        
        rect.origin.x = min(max(rect.origin.x, visibleFrame.minX), visibleFrame.maxX - rect.size.width)
        rect.origin.y = min(max(rect.origin.y, visibleFrame.minY), visibleFrame.maxY - rect.size.height)
        
        return rect
    }
    
    private enum Corner: CaseIterable {
        case topLeft, topRight, bottomLeft, bottomRight
        
        func rect(for frame: CGRect, size: CGFloat) -> CGRect {
            switch self {
            case .topLeft:
                return CGRect(x: frame.minX, y: frame.minY, width: size, height: size)
            case .topRight:
                return CGRect(x: frame.maxX - size, y: frame.minY, width: size, height: size)
            case .bottomLeft:
                return CGRect(x: frame.minX, y: frame.maxY - size, width: size, height: size)
            case .bottomRight:
                return CGRect(x: frame.maxX - size, y: frame.maxY - size, width: size, height: size)
            }
        }
    }
}

// MARK: - Player Layer + Crop Overlay

struct PlayerLayerView: UIViewRepresentable {
    let player: AVPlayer
    
    func makeUIView(context: Context) -> PlayerContainerView {
        let view = PlayerContainerView()
        view.playerLayer.player = player
        view.playerLayer.videoGravity = .resizeAspect
        return view
    }
    
    func updateUIView(_ uiView: PlayerContainerView, context: Context) {
        if uiView.playerLayer.player !== player {
            uiView.playerLayer.player = player
        }
    }
    
    final class PlayerContainerView: UIView {
        override class var layerClass: AnyClass { AVPlayerLayer.self }
        var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    }
}
