import Foundation
import AVFoundation
import UIKit

enum CoordinatorEvent {
    case pendingTrim(CMTimeRange)
    case applyTrim
    case cancelTrim
    case openCrop(frame: UIImage, time: CMTime)
    case applyCrop(CropOperation)
    case smartFillRequested
    case playbackToggled
    case jump(seconds: Double)
    case clearAllEdits
}

@MainActor
protocol EditorCoordinating: AnyObject {
    var mode: EditorMode { get set }
    var assetKind: AssetKind { get set }
    func handle(_ event: CoordinatorEvent)
}

@MainActor
final class EditorCoordinator: EditorCoordinating {
    private weak var host: LightweightEditorViewController?
    var mode: EditorMode = .playback { 
        didSet { 
            host?.updateToolbar(for: mode, kind: assetKind) 
        } 
    }
    var assetKind: AssetKind { 
        didSet { 
            host?.reloadSurface(for: assetKind) 
        } 
    }

    // External single source of truth (already exists in your app)
    let editStack: EditStack

    // Tool controllers
    let playerSurfaceVC = PlayerSurfaceViewController()
    let trimTool = TrimToolController()
    let cropTool = CropToolController()
    init(host: LightweightEditorViewController, editStack: EditStack, initialKind: AssetKind) {
        self.host = host
        self.editStack = editStack
        self.assetKind = initialKind

        // Wire tool events up to coordinator
        trimTool.onEvent = { [weak self] ev in self?.handle(ev) }
        cropTool.onEvent = { [weak self] ev in self?.handle(ev) }
    }

    func attachToolsIntoHost() {
        guard let host = host else { return }
        
        // Mount player surface for video assets
        switch assetKind {
        case .video(_):
            host.mountChild(playerSurfaceVC, into: host.playerContainerView)
            // DISABLED: Don't install modular trimmer - keep original system
            // host.installTrimToolView(trimTool, assetURL: url)
            print("🎛️ COORDINATOR: Using original trimmer system (no duplicate mounting)")
        case .photo(_):
            // Photo mode doesn't need trimmer
            break
        }
        
        host.prepareCropTool(cropTool)
    }

    func handle(_ event: CoordinatorEvent) {
        guard let host = host else { return }
        
        switch event {
        case .pendingTrim(let range):
            host.showTrimApplyCancel(range: range)
            
        case .applyTrim:
            if let range = host.currentPendingTrimRange {
                editStack.replaceTrim(with: range)
                editStack.regeneratePreview()
            }
            host.endPendingTrimUI()
            
        case .cancelTrim:
            host.endPendingTrimUI()

        case .openCrop(let frame, let time):
            // BREAKTHROUGH FIX: Use AssetClassifier to route between video vs photo cropping
            switch assetKind {
            case .photo(_):
                print("📷 COORDINATOR: Using photo crop tool for photo asset")
                host.presentPhotoCrop(cropTool, frame: frame, at: time)
            case .video(let url):
                print("🎬 COORDINATOR: Using video crop tool for video asset")
                let asset = AVURLAsset(url: url)
                host.presentVideoCrop(cropTool, asset: asset)
            }

        case .applyCrop(let cropOperation):
            // CRITICAL FIX: Apply crop operation to edit stack (this was missing!)
            print("✅ COORDINATOR: Applying crop operation to edit stack")
            editStack.apply(operation: cropOperation)
            editStack.regeneratePreview()
            
            // FIXED: Use available internal method instead of private method
            host.refreshToolbarButtons()
            
            print("🎯 CROP APPLIED: Edit stack now has \(editStack.operationCount) operations")
            print("🎯 CROP OPERATIONS: \(editStack.operations.map { $0.displayName })")

        case .smartFillRequested:
            host.modularSmartFillTapped()

        case .playbackToggled:
            playerSurfaceVC.playPauseToggle()
            
        case .jump(let seconds):
            playerSurfaceVC.seek(by: seconds)
            
        case .clearAllEdits:
            editStack.clearAll()
            host.refreshToolbarButtons()
        }
    }
}
