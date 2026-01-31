import UIKit
import AVFoundation

@MainActor
final class PlayerSurfaceViewController: UIViewController {
    private(set) var player: AVPlayer?
    private var layerView = UIView()
    private var layer: AVPlayerLayer?
    private var idleTimerToken: IdleTimerController.Token?
    private var timeControlObservation: NSKeyValueObservation?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        view.addSubview(layerView)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        layerView.frame = view.bounds.inset(by: view.safeAreaInsets)
        layer?.frame = layerView.bounds
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        Task { @MainActor in
            releaseIdleTimer()
        }
    }

    func attach(asset: AVAsset, gravity: AVLayerVideoGravity, videoComposition: AVVideoComposition? = nil) {
        let item = AVPlayerItem(asset: asset)
        item.videoComposition = videoComposition
        let newPlayer = AVPlayer(playerItem: item)
        self.player = newPlayer
        installIdleTimerObservation(for: newPlayer)
        
        if layer == nil {
            let newLayer = AVPlayerLayer(player: newPlayer)
            newLayer.videoGravity = gravity
            layerView.layer.addSublayer(newLayer)
            self.layer = newLayer
        } else {
            layer?.player = newPlayer
            layer?.videoGravity = gravity
        }
        
        view.setNeedsLayout()
        print("✅ PLAYER SURFACE: Attached asset with gravity \(gravity)")
    }

    func replace(with url: URL, gravity: AVLayerVideoGravity, videoComposition: AVVideoComposition? = nil) {
        let asset = AVURLAsset(url: url)
        attach(asset: asset, gravity: gravity, videoComposition: videoComposition)
        print("🔄 PLAYER SURFACE: Replaced asset with \(url.lastPathComponent)")
    }

    func playPauseToggle() {
        guard let player = player else { return }
        if player.timeControlStatus == .playing { 
            player.pause() 
        } else { 
            player.play() 
        }
    }

    func seek(by seconds: Double) {
        guard let player = player else { return }
        let current = player.currentTime()
        let newTime = CMTime(seconds: max(0, current.seconds + seconds), preferredTimescale: 600)
        player.seek(to: newTime, toleranceBefore: .zero, toleranceAfter: .zero)
    }

    private func installIdleTimerObservation(for player: AVPlayer) {
        timeControlObservation?.invalidate()
        timeControlObservation = player.observe(\.timeControlStatus, options: [.initial, .new]) { [weak self] player, _ in
            let isPlaying = player.timeControlStatus == .playing
            Task { @MainActor [weak self] in
                self?.updateIdleTimer(isPlaying)
            }
        }
    }

    @MainActor
    private func updateIdleTimer(_ isPlaying: Bool) {
        if isPlaying {
            if idleTimerToken == nil {
                idleTimerToken = IdleTimerController.shared.acquire(reason: "EditorPlayerSurface")
            }
        } else {
            releaseIdleTimer()
        }
    }

    @MainActor
    private func releaseIdleTimer() {
        idleTimerToken?.release()
        idleTimerToken = nil
    }

    deinit {
        timeControlObservation?.invalidate()
        let token = idleTimerToken
        Task { @MainActor in
            token?.release()
        }
    }
}
