import UIKit
import AVKit
import SwiftUI

final class ChromeInsetContainerViewController: UIViewController {
    let playerViewController: AVPlayerViewController

    private var playbackInsets: EdgeInsets = EdgeInsets()
    private var outerSafeAreaInsets: UIEdgeInsets = .zero
    private var lastAppliedChromeTopInset: CGFloat = -1
    private var lastAppliedPlayerInsets: UIEdgeInsets = UIEdgeInsets(top: -1, left: -1, bottom: -1, right: -1)
    private let landscapeChromeTopInset: CGFloat
    private let landscapeTopThreshold: CGFloat = 12

    @available(iOS 17.0, *)
    private var traitChangeRegistration: UITraitChangeRegistration?

    init(playerViewController: AVPlayerViewController, landscapeTopInset: CGFloat = 18) {
        self.playerViewController = playerViewController
        self.landscapeChromeTopInset = landscapeTopInset
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .black

        addChild(playerViewController)
        view.addSubview(playerViewController.view)
        playerViewController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            playerViewController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            playerViewController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            playerViewController.view.topAnchor.constraint(equalTo: view.topAnchor),
            playerViewController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        playerViewController.didMove(toParent: self)

        if #available(iOS 17.0, *) {
            traitChangeRegistration = registerForTraitChanges([UITraitHorizontalSizeClass.self, UITraitVerticalSizeClass.self]) { [weak self] (_: ChromeInsetContainerViewController, _: UITraitCollection) in
                self?.applyChromeInsetsIfNeeded()
#if DEBUG
                self?.debugLogLayout(context: "traitChange")
#endif
            }
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        applyChromeInsetsIfNeeded()
#if DEBUG
        debugLogLayout(context: "viewDidLayoutSubviews")
#endif
    }

    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        applyChromeInsetsIfNeeded()
#if DEBUG
        debugLogLayout(context: "viewSafeAreaInsetsDidChange")
#endif
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: nil) { [weak self] _ in
            self?.applyChromeInsetsIfNeeded()
#if DEBUG
            self?.debugLogLayout(context: "rotation")
#endif
        }
    }

    func updatePlaybackInsets(_ insets: EdgeInsets) {
        playbackInsets = insets
        outerSafeAreaInsets = UIEdgeInsets(top: insets.top,
                                           left: insets.leading,
                                           bottom: insets.bottom,
                                           right: insets.trailing)
        applyChromeInsetsIfNeeded()
    }

    private func applyChromeInsetsIfNeeded() {
        let topInset = computeChromeTopInset()
        if abs(topInset - lastAppliedChromeTopInset) > 0.5 {
            lastAppliedChromeTopInset = topInset
            additionalSafeAreaInsets = UIEdgeInsets(top: topInset, left: 0, bottom: 0, right: 0)
        }
        applyPlayerSafeAreaInsets(chromeTopInset: topInset)
    }

    private func applyPlayerSafeAreaInsets(chromeTopInset: CGFloat) {
        let containerSafe = view.safeAreaInsets
        let delta = UIEdgeInsets(
            top: max(0, outerSafeAreaInsets.top - containerSafe.top),
            left: max(0, outerSafeAreaInsets.left - containerSafe.left),
            bottom: max(0, outerSafeAreaInsets.bottom - containerSafe.bottom),
            right: max(0, outerSafeAreaInsets.right - containerSafe.right)
        )
        if let enhanced = playerViewController as? EnhancedAVPlayerViewController {
            enhanced.updateExternalSafeAreaInsets(delta)
            enhanced.updateChromeInsets(using: playbackInsets)
            return
        }

        let combined = UIEdgeInsets(
            top: delta.top + chromeTopInset,
            left: delta.left,
            bottom: delta.bottom,
            right: delta.right
        )
        guard !combined.isApproximatelyEqual(to: lastAppliedPlayerInsets) else { return }
        lastAppliedPlayerInsets = combined
        playerViewController.additionalSafeAreaInsets = combined
        playerViewController.view.setNeedsLayout()
    }

    private func computeChromeTopInset() -> CGFloat {
        let size = view.bounds.size
        let isLandscape = size.width > size.height
        let hasLandscapeNotch = playbackInsets.leading > 0 || playbackInsets.trailing > 0
        let topIsZeroish = playbackInsets.top <= landscapeTopThreshold
        guard isLandscape, hasLandscapeNotch, topIsZeroish else { return 0 }
        return landscapeChromeTopInset
    }

#if DEBUG
    private var lastLayoutDebugSignature: String?

    private func debugLogLayout(context: String) {
        guard let playerView = playerViewController.viewIfLoaded else { return }
        let playerSafe = playerView.safeAreaInsets
        let playerAdditional = playerViewController.additionalSafeAreaInsets
        let viewSignature = "\(Int(view.bounds.width))x\(Int(view.bounds.height))"
        let containerSafeSignature = "\(Int(view.safeAreaInsets.top))\(Int(view.safeAreaInsets.left))\(Int(view.safeAreaInsets.bottom))\(Int(view.safeAreaInsets.right))"
        let playerSafeSignature = "\(Int(playerSafe.top))\(Int(playerSafe.left))\(Int(playerSafe.bottom))\(Int(playerSafe.right))"
        let additionalSignature = "\(Int(playerAdditional.top))\(Int(playerAdditional.left))\(Int(playerAdditional.bottom))\(Int(playerAdditional.right))"
        let signatureComponents = [
            context,
            viewSignature,
            containerSafeSignature,
            playerSafeSignature,
            additionalSignature
        ]
        let signature = signatureComponents.joined(separator: "-")
        guard signature != lastLayoutDebugSignature else { return }
        lastLayoutDebugSignature = signature

        print("🧭 ChromeContainer[\(context)] self=\(type(of: self)) frame=\(view.frame) bounds=\(view.bounds)")
        print("🧭 ChromeContainer[\(context)] safeArea=\(view.safeAreaInsets) additional=\(additionalSafeAreaInsets)")
        print("🧭 ChromeContainer[\(context)] playerVC=\(type(of: playerViewController)) viewFrame=\(playerView.frame) safe=\(playerSafe) additional=\(playerAdditional)")
        print("🧭 ChromeContainer[\(context)] transportControlsInPlayerView=\(containsTransportControlsView(in: playerView))")
        logSuperviewChain(startingAt: playerView, context: context)
    }

    private func logSuperviewChain(startingAt view: UIView, context: String) {
        var current: UIView? = view
        var depth = 0
        while let node = current, depth < 12 {
            let className = String(describing: type(of: node))
            let frameDesc = NSCoder.string(for: node.frame)
            let boundsDesc = NSCoder.string(for: node.bounds)
            let safeInsets = node.safeAreaInsets
            let clips = node.clipsToBounds
            let masksToBounds = node.layer.masksToBounds
            let cornerRadius = node.layer.cornerRadius
            let hasMask = node.layer.mask != nil
            print("🧭 ChromeChain[\(context)] \(depth): \(className) frame=\(frameDesc) bounds=\(boundsDesc) safe=\(safeInsets) clips=\(clips) masks=\(masksToBounds) corner=\(cornerRadius) mask=\(hasMask)")
            current = node.superview
            depth += 1
        }
    }

    private func containsTransportControlsView(in view: UIView) -> Bool {
        let className = String(describing: type(of: view))
        if className.contains("Transport") || className.contains("Controls") || className.contains("Playback") || className.contains("Route") {
            return true
        }
        for subview in view.subviews {
            if containsTransportControlsView(in: subview) {
                return true
            }
        }
        return false
    }
#endif
}

private extension UIEdgeInsets {
    func isApproximatelyEqual(to other: UIEdgeInsets, epsilon: CGFloat = 0.5) -> Bool {
        abs(top - other.top) <= epsilon
            && abs(left - other.left) <= epsilon
            && abs(bottom - other.bottom) <= epsilon
            && abs(right - other.right) <= epsilon
    }
}
