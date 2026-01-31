import SwiftUI
import AVKit
import UIKit

struct SessionTakesModalView: View {
    @Binding var isPresented: Bool
    @State private var currentProject: Project
    @State private var currentSession: ProjectSession
    let repository: ProjectsRepository
    let onThatSAWrap: (() -> Void)?

    @EnvironmentObject private var navCtx: NavigationContextManager

    enum ViewType: CaseIterable {
        case scenes
        case slates
        case keyframes

        var displayName: String {
            switch self {
            case .scenes: return "Scenes"
            case .slates: return "Slates"
            case .keyframes: return "Photos"
            }
        }

        var icon: String {
            switch self {
            case .scenes: return "video.fill"
            case .slates: return "tv"
            case .keyframes: return "camera"
            }
        }
    }

    enum SlateFilter: String, CaseIterable {
        case standard
        case pipFullBody
        case pipCloseUp
    }

    @State private var selectedViewType: ViewType = .scenes
    @State private var selectedScene: Int = 1
    @State private var selectedIndex: Int = 0
    @State private var chromeVisible: Bool = true
    @State private var didPreserveContext = false
    @State private var isMediaPlaying = false
    @State private var chromeAutoHideTask: DispatchWorkItem?
    @State private var showScenePicker = false
    @State private var showPIPPicker = false
    @State private var slateFilter: SlateFilter = .standard
    @State private var isLandscape = UIDevice.current.orientation.isValidInterfaceOrientation ? UIDevice.current.orientation.isLandscape : false
    @State private var viewerReloadToken: Int = 0
    @State private var pendingReloadTask: Task<Void, Never>?
    @State private var isPlaybackInteracting = false
    @State private var deferredReloadReason: String?
    @State private var pendingViewerReload = false
    @State private var didConfigureReviewAudioSession = false
    @State private var priorAudioCategory: AVAudioSession.Category?
    @State private var priorAudioMode: AVAudioSession.Mode?
    @State private var priorAudioOptions: AVAudioSession.CategoryOptions?
    @State private var audioRouteObserver: NSObjectProtocol?
#if DEBUG
    @State private var audioDiagnosticsTokens: [NSObjectProtocol] = []
#endif
    private let chromeHorizontalPadding: CGFloat = 16
    private let chromeBottomPadding: CGFloat = 24
    private let ratingsColumnWidth: CGFloat = 60
    private let ratingsColumnSpacing: CGFloat = 12
    private let trayHeight: CGFloat = 64

    init(
        isPresented: Binding<Bool>,
        project: Project,
        session: ProjectSession,
        repository: ProjectsRepository,
        onThatSAWrap: (() -> Void)? = nil
    ) {
        self._isPresented = isPresented
        self._currentProject = State(initialValue: project)
        self._currentSession = State(initialValue: session)
        self.repository = repository
        self.onThatSAWrap = onThatSAWrap
    }

    var body: some View {
        ZStack {
            chromeAnchoringContainer

            if shouldShowChromeRatingsOverlay, let take = currentTake {
                SessionTakesModalRatingsOverlay(
                    take: take,
                    onRatingChange: { newRating in
                        handleSwipeablePlayerAction(.setRating(newRating), for: take)
                    }
                )
                .id(take.id)
                .transition(.opacity)
                .frame(width: ratingsColumnWidth)
                .padding(.trailing, chromeHorizontalPadding)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                .zIndex(1)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.ignoresSafeArea())
        .environment(\.playbackInteractionActive, $isPlaybackInteracting)
        .onAppear {
#if DEBUG
            ThumbnailPreviewView.resetDebugAppearCount()
            print("🧪 SessionTakesModal open start view=\(selectedViewType) takes=\(contextualTakes.count)")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                let count = ThumbnailPreviewView.currentDebugAppearCount()
                print("🧪 SessionTakesModal thumbAppear200ms=\(count) of \(contextualTakes.count)")
            }
            audioDiagnosticsTokens = AudioSessionDiagnostics.installObservers(
                context: "SessionTakesModal",
                includeRouteChange: false
            )
            AudioSessionDiagnostics.snapshot("SessionTakesModal/present/before")
#endif
            configureReviewAudioSessionIfNeeded(reason: "present")
#if DEBUG
            AudioSessionDiagnostics.snapshot("SessionTakesModal/present/after")
#endif
            reloadSessionData()
            restoreNavigationContext()
            preserveModalContextIfNeeded()
            Task {
                await ThumbnailWorkLimiter.shared.setInteractionActive(false)
            }
        }
        .onChange(of: selectedViewType, initial: false) { _, newValue in
            selectedIndex = 0
            if newValue == .scenes {
                selectedScene = sceneNumbersWithTakes.first ?? selectedScene
            }
            clampSelectedIndex()
            if newValue != .scenes {
                showScenePicker = false
            }
            if newValue != .slates {
                showPIPPicker = false
            } else {
                ensureValidSlateFilter()
            }
            viewerReloadToken += 1
            refreshModalContext()
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("STSTakeRatingUpdated"))) { notification in
            guard let sessionID = notification.userInfo?["sessionID"] as? UUID,
                  sessionID == currentSession.id else { return }
            scheduleReload(reason: "take-rating-updated")
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("STSExportCompleted"))) { notification in
            guard let sessionID = notification.userInfo?["sessionID"] as? UUID,
                  sessionID == currentSession.id else { return }
            scheduleReload(reason: "export-completed")
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("SmartFillProcessingDidComplete"))) { notification in
            guard let sessionID = notification.userInfo?["sessionID"] as? UUID,
                  sessionID == currentSession.id else { return }
            scheduleReload(reason: "smartfill-processing-complete")
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("SmartFillJobStatusDidChange"))) { notification in
            guard let sessionID = notification.userInfo?["sessionID"] as? UUID,
                  sessionID == currentSession.id,
                  let status = notification.userInfo?["status"] as? String,
                  status == "completed" else { return }
            scheduleReload(reason: "smartfill-job-complete")
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("STSSmartFillCompleted"))) { notification in
            guard let sessionID = notification.userInfo?["sessionID"] as? UUID,
                  sessionID == currentSession.id else { return }
            scheduleReload(reason: "smartfill-completed")
        }
        .onReceive(NotificationCenter.default.publisher(for: .stsMediaPlaybackStateChanged)) { note in
            if let isPlaying = note.userInfo?["isPlaying"] as? Bool {
                isMediaPlaying = isPlaying
                cancelChromeAutoHide()

                if isPlaying {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        chromeVisible = false
                    }
                } else {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        chromeVisible = true
                    }
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .stsMediaChromeRevealRequested)) { _ in
            showChromeTemporarily()
        }
        .onChange(of: currentSession.id, initial: false) { _, _ in
            clampSelectedIndex()
        }
        .onChange(of: selectedScene, initial: false) { _, _ in
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedIndex = 0
            }
            clampSelectedIndex()
            refreshModalContext()
        }
        .onChange(of: slateFilter, initial: false) { _, _ in
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedIndex = 0
            }
            clampSelectedIndex()
            showPIPPicker = false
            refreshModalContext()
        }
        .onChange(of: isPresented, initial: false) { _, newValue in
            if !newValue {
                _ = navCtx.restore(to: .sessionTakesModal,
                                   sessionID: currentSession.id,
                                   projectID: currentProject.id)
                didPreserveContext = false
            }
        }
        .onChange(of: isPlaybackInteracting, initial: false) { _, newValue in
            Task {
                await ThumbnailWorkLimiter.shared.setInteractionActive(newValue)
            }
#if DEBUG
            print("🧪 SessionTakesModal playbackInteraction=\(newValue)")
#endif
            if newValue {
                pendingReloadTask?.cancel()
            } else {
                if pendingViewerReload {
                    pendingViewerReload = false
                    viewerReloadToken += 1
                }
                if let reason = deferredReloadReason {
                    deferredReloadReason = nil
                    scheduleReload(reason: "interaction-end:\(reason)")
                }
            }
        }
        .onDisappear {
            cancelChromeAutoHide()
            pendingReloadTask?.cancel()
            isPlaybackInteracting = false
#if DEBUG
            AudioSessionDiagnostics.snapshot("SessionTakesModal/dismiss/before")
#endif
            restoreReviewAudioSessionIfNeeded(reason: "dismiss")
#if DEBUG
            AudioSessionDiagnostics.snapshot("SessionTakesModal/dismiss/after")
            AudioSessionDiagnostics.removeObservers(&audioDiagnosticsTokens)
#endif
            Task {
                await ThumbnailWorkLimiter.shared.setInteractionActive(false)
            }
#if DEBUG
            print("🧪 SessionTakesModal dismissed")
#endif
        }
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
            let orientation = UIDevice.current.orientation
            guard orientation.isValidInterfaceOrientation else { return }
            withAnimation(.easeInOut(duration: 0.2)) {
                isLandscape = orientation.isLandscape
            }
        }
        .ratingEducationToastHost()
    }

    private var chromeAnchoringContainer: some View {
        mediaViewer
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(alignment: .top) {
                if chromeVisible {
                    chromeTopOverlay
                }
            }
            .overlay(alignment: .bottom) {
                if chromeVisible {
                    chromeBottomOverlay
                }
            }
    }

    private var mediaViewer: some View {
        Group {
            let takes = contextualTakes
            if takes.isEmpty {
                emptyStateView
            } else {
                let safeIndexBinding = Binding<Int>(
                    get: {
                        guard !takes.isEmpty else { return 0 }
                        return min(max(0, selectedIndex), takes.count - 1)
                    },
                    set: { newValue in
                        guard !takes.isEmpty else {
                            selectedIndex = 0
                            return
                        }
                        selectedIndex = min(max(0, newValue), takes.count - 1)
                    }
                )

                SwipeableMediaPlayerView(
                    takes: takes,
                    session: currentSession,
                    project: currentProject,
                    initialIndex: safeIndexBinding.wrappedValue,
                    currentIndexBinding: safeIndexBinding,
                    onDismiss: { isPresented = false },
                    onTakeAction: handleSwipeablePlayerAction,
                    ratingsOverlayMode: .swiftUIChromeAnchored,
                    manageAudioSession: false,
                    showsTitleOverlay: false
                )
                .id(mediaViewerIdentity)
            }
        }
    }

    private var chromeTopOverlay: some View {
        VStack(spacing: 0) {
            topBarOverlay
            pillToolbarOverlay
            if selectedViewType == .scenes && sceneNumbersWithTakes.count > 1 {
                sceneSelectorOverlay
            }
            if selectedViewType == .slates && pipFilterAvailable {
                pipSelectorOverlay
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, chromeHorizontalPadding)
        .transition(.opacity)
    }

    private var chromeBottomOverlay: some View {
        VStack(spacing: 8) {
            takeMetadataBand
            trayWithRatingsRow
            footerCountersOverlay
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, chromeHorizontalPadding)
        .padding(.bottom, chromeBottomPadding)
        .transition(.opacity)
    }

    private var currentTakes: [ProjectTake] {
        switch selectedViewType {
        case .scenes:
            return currentSession.takes
                .filter { isSceneTake($0) && $0.sceneNumber == selectedScene }
                .sorted { $0.createdAt < $1.createdAt }
        case .slates:
            let standardSlates = currentSession.takes
                .filter { $0.takeType.isSlateLike && !isPIPComponent($0) }
                .sorted { $0.createdAt < $1.createdAt }
            switch slateFilter {
            case .standard:
                return standardSlates
            case .pipFullBody:
                let reviewTakes = pipPortraitReviewTakes
                return reviewTakes.isEmpty ? standardSlates : reviewTakes
            case .pipCloseUp:
                let reviewTakes = pipLandscapeReviewTakes
                return reviewTakes.isEmpty ? standardSlates : reviewTakes
            }
        case .keyframes:
            return currentSession.takes
                .filter { isPhotoTake($0) }
                .sorted { $0.createdAt < $1.createdAt }
        }
    }

    private var contextualTakes: [ProjectTake] { currentTakes }

    private var mediaViewerIdentity: String {
        switch selectedViewType {
        case .scenes:
            return "scenes-\(currentSession.id)-\(selectedScene)-\(viewerReloadToken)"
        case .slates:
            return "slates-\(currentSession.id)-\(slateFilter.rawValue)-\(viewerReloadToken)"
        case .keyframes:
            return "photos-\(currentSession.id)-\(viewerReloadToken)"
        }
    }

    private var pipPortraitReviewTakes: [ProjectTake] {
        guard let pipSession = currentSession.pipSlateSession else { return [] }
        return buildSyntheticPIPTakes(from: pipSession.portraitTakes, orientation: .portrait)
    }

    private var pipLandscapeReviewTakes: [ProjectTake] {
        guard let pipSession = currentSession.pipSlateSession else { return [] }
        return buildSyntheticPIPTakes(from: pipSession.landscapeTakes, orientation: .landscape)
    }

    private var pipComponentBasenames: Set<String> {
        guard let pip = currentSession.pipSlateSession else { return [] }
        let components = pip.portraitTakes + pip.landscapeTakes
        return Set(components.map { URL(fileURLWithPath: $0.filePath).lastPathComponent.lowercased() })
    }

    private func isPIPComponent(_ take: ProjectTake) -> Bool {
        if take.takeType.isPIPComponent { return true }
        let name = URL(fileURLWithPath: take.filePath).lastPathComponent.lowercased()
        return pipComponentBasenames.contains(name)
    }

    private func buildSyntheticPIPTakes(from source: [PIPSlateTake], orientation: VideoOrientation) -> [ProjectTake] {
        source
            .sorted { $0.createdAt < $1.createdAt }
            .enumerated()
            .map { index, take in
                makeSyntheticPIPTake(from: take, orientation: orientation, index: index)
            }
    }

    private func makeSyntheticPIPTake(from pipTake: PIPSlateTake, orientation: VideoOrientation, index: Int) -> ProjectTake {
        let normalizedPath = normalizePIPPath(pipTake.filePath)
        let note = orientation == .portrait ? "PiP Full Body" : "PiP Close-Up"
        return ProjectTake(
            id: pipTake.id,
            filePath: normalizedPath,
            durationSeconds: max(0, pipTake.duration),
            takeNotes: note,
            createdAt: pipTake.createdAt,
            sceneNumber: orientation == .portrait ? -101 : -102,
            takeNumber: index + 1,
            slateNumber: note,
            capturedOrientation: orientation,
            takeType: .pipSlate
        )
    }

    private func normalizePIPPath(_ path: String) -> String {
        if path.hasPrefix("/") {
            return VideoVariantResolver.relativePath(from: URL(fileURLWithPath: path))
        }
        return path
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: currentViewEmptyStateIcon)
                .font(.system(size: 48, weight: .semibold))
                .foregroundColor(.gray)
            Text(currentViewEmptyStateTitle)
                .font(.headline)
                .foregroundColor(.white)
            Text(currentViewEmptyStateMessage)
                .font(.caption)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .padding(32)
    }

    private var topBarOverlay: some View {
        HStack(spacing: 12) {
            Button {
                isPresented = false
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .padding(8)
                    .background(Color.black.opacity(0.65), in: Circle())
            }

            Spacer()
        }
        .padding(.top, 20)
        .padding(.leading, isLandscape ? 16 : 0)
    }

    private var pillToolbarOverlay: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(ViewType.allCases, id: \.self) { type in
                    Button {
                        if selectedViewType != type {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedViewType = type
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: type.icon)
                            Text(type.displayName)
                            let count = getCountForViewType(type)
                            if count > 0 {
                                Text("(\(count))")
                            }
                        }
                        .font(.subheadline.weight(.medium))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(selectedViewType == type ? Color.white : Color.white.opacity(0.25))
                        )
                        .foregroundColor(selectedViewType == type ? .black : .white)
                    }
                    .buttonStyle(.plain)
                }
                Spacer(minLength: 0)
            }
        }
        .frame(height: 44)
        .padding(.top, 16)
    }

    private var sceneSelectorOverlay: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("Scene")
                    .font(.caption)
                    .foregroundStyle(.gray)

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showScenePicker.toggle()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text("Scene \(selectedScene)")
                            .font(.caption.weight(.medium))
                        Image(systemName: showScenePicker ? "chevron.up" : "chevron.down")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.white.opacity(0.15))
                    )
                }
                .buttonStyle(.plain)

                Spacer()
            }

            if showScenePicker {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(sceneNumbersWithTakes, id: \.self) { sceneNum in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedScene = sceneNum
                                selectedIndex = 0
                                clampSelectedIndex()
                                showScenePicker = false
                            }
                        } label: {
                            HStack {
                                Text("Scene \(sceneNum)")
                                    .font(.subheadline.weight(sceneNum == selectedScene ? .semibold : .regular))
                                Spacer()
                                if sceneNum == selectedScene {
                                    Image(systemName: "checkmark")
                                }
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(sceneNum == selectedScene ? Color.white.opacity(0.2) : Color.white.opacity(0.08))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.black.opacity(0.65))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color.white.opacity(0.15), lineWidth: 1)
                        )
                )
            }
        }
        .padding(.top, 12)
    }

    private var pipSelectorOverlay: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("Picture-in-Picture")
                    .font(.caption)
                    .foregroundStyle(.gray)

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showPIPPicker.toggle()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(pipFilterLabel)
                            .font(.caption.weight(.medium))
                        Image(systemName: showPIPPicker ? "chevron.up" : "chevron.down")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.white.opacity(0.15))
                    )
                }
                .buttonStyle(.plain)

                Spacer()
            }

            if showPIPPicker {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(pipPickerFilters, id: \.self) { filter in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                slateFilter = filter
                            }
                        } label: {
                            HStack {
                                Text(pipFilterButtonLabel(for: filter))
                                    .font(.subheadline.weight(filter == slateFilter ? .semibold : .regular))
                                Spacer()
                                if filter == slateFilter {
                                    Image(systemName: "checkmark")
                                }
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(filter == slateFilter ? Color.white.opacity(0.2) : Color.white.opacity(0.08))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.black.opacity(0.65))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color.white.opacity(0.15), lineWidth: 1)
                        )
                )
            }
        }
        .padding(.top, 12)
    }

    private var compactCarouselTray: some View {
        let takes = contextualTakes
        guard !takes.isEmpty else { return AnyView(EmptyView()) }

        return AnyView(
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 10) {
                    ForEach(Array(takes.enumerated()), id: \.element.id) { index, take in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedIndex = index
                            }
                        } label: {
                            ZStack {
                                ThumbnailPreviewView(unifiedTake: makeUnifiedTake(for: take, index: index))
                                    .frame(width: 70, height: 40)
                                    .clipShape(RoundedRectangle(cornerRadius: 9))

                                VStack {
                                    HStack {
                                        if take.rating == .finalSelect {
                                            Image(systemName: "star.fill")
                                                .font(.system(size: 9))
                                                .foregroundColor(.yellow)
                                        }
                                        if take.rating == .option {
                                            Image(systemName: "checkmark.circle.fill")
                                                .font(.system(size: 9))
                                                .foregroundColor(.green)
                                        }
                                        Spacer()
                                    }
                                    Spacer()
                                }
                                .padding(4)
                            }
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(
                                        index == selectedIndex ? Color.white : Color.white.opacity(0.35),
                                        lineWidth: index == selectedIndex ? 2 : 1
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
            }
            .frame(height: trayHeight)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
        )
    }

    private var trayWithRatingsRow: some View {
        HStack(spacing: ratingsColumnSpacing) {
            compactCarouselTray
                .frame(maxWidth: .infinity, alignment: .leading)
                .layoutPriority(1)
            if shouldShowChromeRatingsOverlay {
                Color.clear
                    .frame(width: ratingsColumnWidth, height: trayHeight)
                    .allowsHitTesting(false)
            }
        }
    }

    @ViewBuilder
    private var takeMetadataBand: some View {
        if let metadata = currentTakeMetadata {
            let label = TakeDisplayFormatter.label(for: metadata.take, in: currentSession)
            let countText = "\(metadata.index + 1) of \(metadata.total)"
            let durationSeconds = metadata.take.effectiveDurationSeconds
            let subtitle = durationSeconds > 0 ? "\(formattedDuration(durationSeconds)) • \(countText)" : countText

            HStack(spacing: 12) {
                Text(label)
                    .font(.callout.weight(.semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                Spacer()
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.85))
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.black.opacity(0.55))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
            )
            .transaction { $0.animation = nil }
        } else {
            EmptyView()
        }
    }

    private var footerCountersOverlay: some View {
        HStack(spacing: 12) {
            Label("\(currentTakes.count) takes", systemImage: "film")
            Label("\(finalSelectCount) final select", systemImage: "star.fill")
            Label("\(optionCount) option", systemImage: "checkmark.circle.fill")
        }
        .font(.caption)
        .foregroundColor(.white.opacity(0.85))
    }

    private var pipFilterAvailable: Bool {
        pipPickerFilters.contains { $0 != .standard }
    }

    private var pipPickerFilters: [SlateFilter] {
        var filters: [SlateFilter] = [.standard]
        if !pipPortraitReviewTakes.isEmpty {
            filters.append(.pipFullBody)
        }
        if !pipLandscapeReviewTakes.isEmpty {
            filters.append(.pipCloseUp)
        }
        return filters
    }

    private var pipFilterLabel: String {
        pipFilterButtonLabel(for: slateFilter)
    }

    private func pipFilterButtonLabel(for filter: SlateFilter) -> String {
        switch filter {
        case .standard:
            return "Standard Slates"
        case .pipFullBody:
            return "Full Body"
        case .pipCloseUp:
            return "Close-Up"
        }
    }

    // MARK: - Filtering Helpers
    private func isPhotoTake(_ take: ProjectTake) -> Bool {
        guard take.durationSeconds == 0 else { return false }
        if take.takeType.isSlateLike { return false }

        let lowerPath = take.filePath.lowercased()
        if lowerPath.hasSuffix(".jpg") || lowerPath.hasSuffix(".jpeg") || lowerPath.hasSuffix(".png") {
            return true
        }

        if take.isKeyframePhoto { return true }

        if let notes = take.takeNotes?.lowercased(),
           notes.contains("photo") || notes.contains("keyframe") {
            return true
        }

        return !lowerPath.hasSuffix(".mov") && !lowerPath.hasSuffix(".mp4")
    }

    private var currentTakeMetadata: (take: ProjectTake, index: Int, total: Int)? {
        let takes = contextualTakes
        guard !takes.isEmpty else { return nil }
        let safeIndex = min(max(0, selectedIndex), takes.count - 1)
        return (takes[safeIndex], safeIndex, takes.count)
    }

    private var currentTake: ProjectTake? {
        currentTakeMetadata?.take
    }

    private var shouldShowChromeRatingsOverlay: Bool {
        guard chromeVisible else { return false }
        guard let take = currentTake else { return false }
        return shouldShowRatings(for: take)
    }

    private func formattedDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func shouldShowRatings(for take: ProjectTake) -> Bool {
        guard take.takeType == .regular || take.takeType.isSlateLike else { return false }
        if take.takeType == .pipSlate || take.takeType.isPIPComponent { return false }
        return true
    }

    private func isSceneTake(_ take: ProjectTake) -> Bool {
        take.takeType == .regular &&
        take.sceneNumber > 0 &&
        !isPhotoTake(take)
    }

    private var sceneNumbersWithTakes: [Int] {
        let numbers = Set(
            currentSession.takes
                .filter { isSceneTake($0) }
                .map { $0.sceneNumber }
        )
        return numbers.sorted()
    }
    
    private var standardSlateTakes: [ProjectTake] {
        currentSession.takes.filter { $0.takeType.isSlateLike && !isPIPComponent($0) }
    }
    
    private var hasSceneContent: Bool { !sceneNumbersWithTakes.isEmpty }
    private var hasSlateContent: Bool {
        !standardSlateTakes.isEmpty || !pipPortraitReviewTakes.isEmpty || !pipLandscapeReviewTakes.isEmpty
    }
    private var hasPhotoContent: Bool {
        currentSession.takes.contains { isPhotoTake($0) }
    }
    
    private func bestAvailableSlateFilter(preferred: SlateFilter?) -> SlateFilter {
        if let preferred, pipPickerFilters.contains(preferred) {
            return preferred
        }
        if pipPickerFilters.contains(.pipCloseUp) {
            return .pipCloseUp
        }
        if pipPickerFilters.contains(.pipFullBody) {
            return .pipFullBody
        }
        return .standard
    }

    private var currentViewEmptyStateIcon: String {
        switch selectedViewType {
        case .keyframes: return "photo"
        case .slates: return "person.crop.rectangle.badge.exclam"
        case .scenes: return "video.slash"
        }
    }

    private var currentViewEmptyStateTitle: String {
        switch selectedViewType {
        case .keyframes: return "No Keyframe Photos Yet"
        case .slates: return "No Slate Takes Yet"
        case .scenes: return "No Takes Yet"
        }
    }

    private var currentViewEmptyStateMessage: String {
        switch selectedViewType {
        case .keyframes: return "Capture keyframe photos to see them here."
        case .slates: return "Record your slate to populate this view."
        case .scenes: return "Start recording to see your takes here."
        }
    }

    private func getCountForViewType(_ viewType: ViewType) -> Int {
        switch viewType {
        case .scenes:
            return currentSession.takes.filter { isSceneTake($0) }.count
        case .slates:
            let storedSlates = standardSlateTakes.count
            let pipSources = pipPortraitReviewTakes.count + pipLandscapeReviewTakes.count
            return storedSlates + pipSources
        case .keyframes:
            return currentSession.takes.filter { isPhotoTake($0) }.count
        }
    }

    private var finalSelectCount: Int {
        currentTakes.filter { $0.rating == .finalSelect }.count
    }

    private var optionCount: Int {
        currentTakes.filter { $0.rating == .option }.count
    }

    private func makeUnifiedTake(for take: ProjectTake, index: Int) -> UnifiedTake {
        UnifiedTake(
            from: take,
            projectID: currentProject.id,
            sessionID: currentSession.id,
            fileName: URL(fileURLWithPath: take.filePath).lastPathComponent,
            takeNumber: index + 1
        )
    }

    private func isRepositoryBackedTake(_ take: ProjectTake) -> Bool {
        currentSession.takes.contains { $0.id == take.id }
    }

    private func handleSwipeablePlayerAction(_ action: TakeAction, for take: ProjectTake) {
        switch action {
        case .setRating(let rating):
            guard isRepositoryBackedTake(take) else {
                print("ℹ️ SessionTakesModal: Ignoring rating update for PiP source take \(take.id)")
                if isPlaybackInteracting {
                    pendingViewerReload = true
                } else {
                    viewerReloadToken += 1
                }
                return
            }
            repository.setUnifiedTakeRating(
                takeID: take.id,
                sessionID: currentSession.id,
                projectID: currentProject.id,
                rating: rating
            )

            NotificationCenter.default.post(
                name: Notification.Name("STSTakeRatingUpdated"),
                object: nil,
                userInfo: [
                    "takeID": take.id,
                    "sessionID": currentSession.id,
                    "projectID": currentProject.id,
                    "rating": rating.rawValue
                ]
            )
        case .share,
             .play,
             .delete,
             .editSmartFill,
             .playOriginal,
             .markBest,
             .favorite,
             .addNote,
             .export,
             .deleteTake,
             .setSubmitted:
            break
        }

        scheduleReload(reason: "player-action")
    }

    private func reloadSessionData() {
        let reloadStart = CFAbsoluteTimeGetCurrent()

        let repoLookupStart = CFAbsoluteTimeGetCurrent()
        let refreshedProject = repository.project(by: currentProject.id)
        let repoLookupDuration = CFAbsoluteTimeGetCurrent() - repoLookupStart

        var sessionLookupDuration: Double = 0
        if let refreshedProject,
           let refreshedSession = refreshedProject.sessions.first(where: { $0.id == currentSession.id }) {
            let sessionApplyStart = CFAbsoluteTimeGetCurrent()
            if refreshedProject != currentProject {
                currentProject = refreshedProject
            }
            if refreshedSession != currentSession {
                currentSession = refreshedSession
            }
            sessionLookupDuration = CFAbsoluteTimeGetCurrent() - sessionApplyStart
        }

        let sceneGuardStart = CFAbsoluteTimeGetCurrent()
        ensureValidSceneSelection()
        let sceneGuardDuration = CFAbsoluteTimeGetCurrent() - sceneGuardStart

        let slateGuardStart = CFAbsoluteTimeGetCurrent()
        ensureValidSlateFilter()
        let slateGuardDuration = CFAbsoluteTimeGetCurrent() - slateGuardStart

        let clampStart = CFAbsoluteTimeGetCurrent()
        clampSelectedIndex()
        let clampDuration = CFAbsoluteTimeGetCurrent() - clampStart

        let elapsed = CFAbsoluteTimeGetCurrent() - reloadStart
        print(
            String(
                format: "⏱️ SessionTakesModalView reloadSessionData completed in %.2f s (takes=%d | repo=%.3f s, sessionApply=%.3f s, sceneGuard=%.3f s, slateGuard=%.3f s, clamp=%.3f s)",
                elapsed,
                currentTakes.count,
                repoLookupDuration,
                sessionLookupDuration,
                sceneGuardDuration,
                slateGuardDuration,
                clampDuration
            )
        )
    }

    private func scheduleReload(reason: String) {
        if isPlaybackInteracting {
            deferredReloadReason = reason
#if DEBUG
            print("🧪 SessionTakesModal deferReload reason=\(reason)")
#endif
            return
        }
        pendingReloadTask?.cancel()
#if DEBUG
        print("🧪 SessionTakesModal scheduleReload reason=\(reason)")
#endif
        pendingReloadTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 200_000_000)
            reloadSessionData()
        }
    }

    private func clampSelectedIndex() {
        let count = currentTakes.count
        if count == 0 {
            selectedIndex = 0
        } else if selectedIndex >= count {
            selectedIndex = max(0, count - 1)
        }
    }

    private func restoreNavigationContext() {
        let preferredSources: [NavigationContextManager.SourceView] = [.sessionTakesModal, .cameraCapture, .takeReview, .player]
        #if DEBUG
        print("📼 SessionTakes: restoreNavigationContext start session=\(currentSession.id) project=\(currentProject.id)")
        #endif
        while let context = navCtx.preferredContext(sessionID: currentSession.id,
                                                   projectID: currentProject.id,
                                                   prioritizedSources: preferredSources) {
            if applyNavigationContext(context) {
                navCtx.removeContext(id: context.id)
                #if DEBUG
                print("📼 SessionTakes: applied preferred context from \(context.sourceView.rawValue)")
                #endif
                return
            } else {
                navCtx.removeContext(id: context.id)
            }
        }
        #if DEBUG
        print("📼 SessionTakes: no preferred context available, falling back to defaults")
        #endif
        applyDefaultNavigationContext()
    }

    private func applyDefaultNavigationContext() {
        if hasSceneContent {
            selectedViewType = .scenes
            selectedScene = sceneNumbersWithTakes.first ?? selectedScene
        } else if hasSlateContent {
            selectedViewType = .slates
            slateFilter = bestAvailableSlateFilter(preferred: nil)
        } else if hasPhotoContent {
            selectedViewType = .keyframes
        } else {
            selectedViewType = .scenes
            selectedScene = 1
        }
        selectedIndex = 0
        clampSelectedIndex()
    }

    @discardableResult
    private func applyNavigationContext(_ context: NavigationContext) -> Bool {
        let desired = fromNavViewType(context.viewType)
        #if DEBUG
        print("📼 SessionTakes: trying context \(context.sourceView.rawValue) → \(desired) scene=\(context.sceneNumber) meta=\(context.metadata ?? [:])")
        #endif
        switch desired {
        case .scenes:
            guard hasSceneContent else {
                #if DEBUG
                print("📼 SessionTakes: context requested scenes but there is no scene content")
                #endif
                return false
            }
            selectedViewType = .scenes
            let targetScene = max(1, context.sceneNumber)
            if sceneNumbersWithTakes.contains(targetScene) {
                selectedScene = targetScene
            } else {
                selectedScene = sceneNumbersWithTakes.first ?? targetScene
            }
        case .slates:
            guard hasSlateContent else {
                #if DEBUG
                print("📼 SessionTakes: context requested slates but there is no slate content")
                #endif
                return false
            }
            selectedViewType = .slates
            let metadataFilter = context.metadata?["slateFilter"]
            let preferredFilter = metadataFilter.flatMap { SlateFilter(rawValue: $0) }
            slateFilter = bestAvailableSlateFilter(preferred: preferredFilter)
        case .keyframes:
            guard hasPhotoContent else {
                #if DEBUG
                print("📼 SessionTakes: context requested photos but there is no photo content")
                #endif
                return false
            }
            selectedViewType = .keyframes
        }
        if let takeIndex = context.takeIndex {
            selectedIndex = takeIndex
        } else {
            selectedIndex = 0
        }
        clampSelectedIndex()
        #if DEBUG
        print("📼 SessionTakes: applied context with takeIndex=\(context.takeIndex ?? -1) currentView=\(selectedViewType) scene=\(selectedScene) slateFilter=\(slateFilter.rawValue)")
        #endif
        return true
    }

    private func ensureValidSceneSelection() {
        guard selectedViewType == .scenes else { return }
        let scenes = sceneNumbersWithTakes
        if scenes.isEmpty {
            selectedScene = 1
        } else if !scenes.contains(selectedScene) {
            selectedScene = scenes.first!
        }
    }

    private func ensureValidSlateFilter() {
        guard slateFilter != .standard else { return }
        if slateFilter == .pipFullBody && pipPortraitReviewTakes.isEmpty {
            slateFilter = bestAvailableSlateFilter(preferred: nil)
        } else if slateFilter == .pipCloseUp && pipLandscapeReviewTakes.isEmpty {
            slateFilter = bestAvailableSlateFilter(preferred: nil)
        }
    }

    private func fromNavViewType(_ viewType: NavigationContextManager.ViewType) -> ViewType {
        switch viewType {
        case .scenes:
            return .scenes
        case .slates:
            return .slates
        case .keyframes, .photos:
            return .keyframes
        }
    }

    private func toNavViewType(_ viewType: ViewType) -> NavigationContextManager.ViewType {
        switch viewType {
        case .scenes:
            return .scenes
        case .slates:
            return .slates
        case .keyframes:
            return .keyframes
        }
    }

    // MARK: - Audio Session (SessionTakesModal scoped)
    private func configureReviewAudioSessionIfNeeded(reason: String) {
        guard !didConfigureReviewAudioSession else { return }
        let session = AVAudioSession.sharedInstance()
        priorAudioCategory = session.category
        priorAudioMode = session.mode
        priorAudioOptions = session.categoryOptions
        do {
            try session.setCategory(.playback, mode: .moviePlayback, options: [.allowAirPlay])
            try session.setActive(true, options: [])
            didConfigureReviewAudioSession = true
#if DEBUG
            print("🔊 SessionTakesModal audio configure reason=\(reason) category=playback mode=moviePlayback")
            AudioSessionDiagnostics.snapshot("SessionTakesModal/configure/\(reason)")
#endif
        } catch {
#if DEBUG
            print("❌ SessionTakesModal audio configure failed reason=\(reason) err=\(error)")
#endif
        }

        if audioRouteObserver == nil {
            audioRouteObserver = NotificationCenter.default.addObserver(
                forName: AVAudioSession.routeChangeNotification,
                object: nil,
                queue: .main
            ) { notification in
                let reasonValue = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt
                let reason = reasonValue.flatMap { AVAudioSession.RouteChangeReason(rawValue: $0) }
                let currentRoute = AVAudioSession.sharedInstance().currentRoute
#if DEBUG
                let outputs = currentRoute.outputs.map { "\($0.portType.rawValue)" }.joined(separator: ",")
                let reasonText = reason.map { String($0.rawValue) } ?? "nil"
                print("🔊 SessionTakesModal audio route change reason=\(reasonText) outputs=\(outputs)")
#endif
            }
        }
    }

    private func restoreReviewAudioSessionIfNeeded(reason: String) {
        if let observer = audioRouteObserver {
            NotificationCenter.default.removeObserver(observer)
            audioRouteObserver = nil
        }
        guard didConfigureReviewAudioSession,
              let category = priorAudioCategory,
              let mode = priorAudioMode else { return }
        let options = priorAudioOptions ?? []
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(category, mode: mode, options: options)
            try session.setActive(true, options: [])
#if DEBUG
            print("🔊 SessionTakesModal audio restore reason=\(reason) category=\(category.rawValue) mode=\(mode.rawValue)")
            AudioSessionDiagnostics.snapshot("SessionTakesModal/restore/\(reason)")
#endif
        } catch {
#if DEBUG
            print("❌ SessionTakesModal audio restore failed reason=\(reason) err=\(error)")
#endif
        }
        didConfigureReviewAudioSession = false
    }

    private func preserveModalContextIfNeeded() {
        guard !didPreserveContext else { return }
        var metadata: [String: String]? = nil
        if selectedViewType == .slates {
            metadata = ["slateFilter": slateFilter.rawValue]
        }
        navCtx.preserveFromModal(
            scene: selectedScene,
            viewType: toNavViewType(selectedViewType),
            sessionID: currentSession.id,
            projectID: currentProject.id,
            metadata: metadata
        )
        didPreserveContext = true
    }

    private func refreshModalContext() {
        _ = navCtx.restore(to: .sessionTakesModal,
                           sessionID: currentSession.id,
                           projectID: currentProject.id)
        didPreserveContext = false
        preserveModalContextIfNeeded()
    }

    private func showChromeTemporarily() {
        withAnimation(.easeInOut(duration: 0.25)) {
            chromeVisible = true
        }
        scheduleChromeAutoHide()
    }

    private func scheduleChromeAutoHide() {
        chromeAutoHideTask?.cancel()
        guard isMediaPlaying else { return }
        let task = DispatchWorkItem {
            if isMediaPlaying {
                withAnimation(.easeInOut(duration: 0.25)) {
                    chromeVisible = false
                }
            }
        }
        chromeAutoHideTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: task)
    }

    private func cancelChromeAutoHide() {
        chromeAutoHideTask?.cancel()
        chromeAutoHideTask = nil
    }

}

private struct SessionTakesModalRatingsOverlay: View {
    let take: ProjectTake
    let onRatingChange: (TakeRating) -> Void

    @State private var currentRating: TakeRating

    private let ratingButtonSize: CGFloat = 46
    private let ratingIconPointSize: CGFloat = 20
    private let ratingStackSpacing: CGFloat = 14

    init(take: ProjectTake, onRatingChange: @escaping (TakeRating) -> Void) {
        self.take = take
        self.onRatingChange = onRatingChange
        self._currentRating = State(initialValue: SessionManager.shared.effectiveRating(for: take) ?? take.rating)
    }

    var body: some View {
        ratingButtonsOverlay
            .padding(.vertical, 20)
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("STSTakeRatingUpdated"))) { notification in
                if let takeID = notification.userInfo?["takeID"] as? UUID,
                   takeID == take.id,
                   let ratingRawValue = notification.userInfo?["rating"] as? String,
                   let newRating = TakeRating(rawValue: ratingRawValue) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        currentRating = newRating
                    }
                }
            }
            .onAppear {
                currentRating = SessionManager.shared.effectiveRating(for: take) ?? take.rating
            }
    }

    private var ratingButtonsOverlay: some View {
        VStack(spacing: ratingStackSpacing) {
            enhancedRatingButton(.finalSelect, "star.fill", .yellow)
            enhancedRatingButton(.option, "checkmark.circle.fill", .green)
            enhancedRatingButton(.unrated, "circle", .gray)
            enhancedRatingButton(.rejected, "xmark.circle.fill", .red)
        }
        .frame(width: ratingContainerSize.width)
        .background(Color.clear)
        .allowsHitTesting(true)
    }

    private var ratingContainerSize: CGSize {
        let contentHeight = (ratingButtonSize * 4) + (ratingStackSpacing * 3)
        let paddedHeight = contentHeight + 40
        return CGSize(width: 60, height: paddedHeight)
    }

    @ViewBuilder
    private func enhancedRatingButton(_ rating: TakeRating, _ iconName: String, _ color: Color) -> some View {
        Button(action: {
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()

            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                currentRating = rating
            }

            onRatingChange(rating)
        }) {
            ZStack {
                Circle()
                    .fill(Color.clear)
                    .frame(width: ratingButtonSize + 20, height: ratingButtonSize + 20)

                Image(systemName: iconName)
                    .font(.system(size: ratingIconPointSize, weight: .medium))
                    .foregroundColor(currentRating == rating ? color : Color.white.opacity(0.9))
                    .frame(width: ratingButtonSize, height: ratingButtonSize)
                    .background(
                        Circle()
                            .fill(
                                currentRating == rating
                                    ? color.opacity(0.6)
                                    : Color.black.opacity(0.8)
                            )
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.3), lineWidth: 2)
                            )
                    )
                    .shadow(color: .black.opacity(0.9), radius: 8, x: 0, y: 4)
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(currentRating == rating ? 1.2 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentRating)
        .contentShape(Circle())
        .allowsHitTesting(true)
    }
}
