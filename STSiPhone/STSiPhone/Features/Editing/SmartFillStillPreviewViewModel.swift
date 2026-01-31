import Foundation
import UIKit
import Combine
import AVFoundation

/// ViewModel that creates a *still* SmartFill preview image.
/// - Designed to be owned as a @StateObject by the sheet.
@MainActor
final class SmartFillStillPreviewViewModel: ObservableObject {

    struct Input: Equatable {
        let takeID: UUID
        let fileName: String        // e.g., "F038....mov"
        let targetPixelSize: CGSize // final CGImage size in pixels (NOT points)
        let settings: SmartFillSettings
        
        // Custom Equatable implementation
        static func == (lhs: Input, rhs: Input) -> Bool {
            return lhs.takeID == rhs.takeID &&
                   lhs.fileName == rhs.fileName &&
                   lhs.targetPixelSize == rhs.targetPixelSize &&
                   lhs.settings.defaultBlurRadius == rhs.settings.defaultBlurRadius &&
                   lhs.settings.defaultDarkenAmount == rhs.settings.defaultDarkenAmount &&
                   lhs.settings.backgroundScale == rhs.settings.backgroundScale &&
                   lhs.settings.forceUpdateToken == rhs.settings.forceUpdateToken
        }
    }

    @Published var previewImage: UIImage?
    @Published var isGenerating: Bool = false
    @Published var error: String?

    private(set) var input: Input
    private var task: Task<Void, Never>?

    init(input: Input) {
        self.input = input
    }

    deinit { task?.cancel() }

    /// Update the targetPixelSize (e.g., when layout width changes) and optionally regenerate.
    func update(input newInput: Input, regenerateIfSizeChanged: Bool = true) {
        // If nothing changed at all, bail early.
        guard newInput != input else { return }

        // Detect size changes (original behavior).
        let sizeChanged = newInput.targetPixelSize != input.targetPixelSize

        // Detect SmartFill-relevant setting changes.
        let settingsChanged =
            newInput.settings.defaultBlurRadius != input.settings.defaultBlurRadius ||
            newInput.settings.defaultDarkenAmount != input.settings.defaultDarkenAmount ||
            newInput.settings.backgroundScale != input.settings.backgroundScale

        // Store the new input before regenerating.
        self.input = newInput

        // Always regenerate when settings change; also regenerate on size change if requested.
        if settingsChanged || (regenerateIfSizeChanged && sizeChanged) {
            regenerate()
        }
    }

    func regenerate() {
        task?.cancel()
        isGenerating = true
        error = nil
        previewImage = nil

        task = Task { [input] in
            do {
                let url = try VideoFileManager.shared.urlForDocumentsFile(named: input.fileName)
                let asset = AVURLAsset(url: url)
                let generator = SmartFillStillPreviewGenerator(
                    asset: asset,
                    targetPixelSize: input.targetPixelSize,
                    blurRadius: input.settings.defaultBlurRadius,
                    darkenAmount: input.settings.defaultDarkenAmount,
                    scaleFactor: input.settings.backgroundScale
                )
                let image = try await generator.makePreviewImage()
                self.previewImage = image
                self.isGenerating = false
                NotificationCenter.default.post(name: .SmartFillPreviewDidUpdate,
                                                object: nil,
                                                userInfo: ["takeID": input.takeID.uuidString])
            } catch {
                self.error = error.localizedDescription
                self.isGenerating = false
            }
        }
    }
}

extension Notification.Name {
    static let SmartFillPreviewDidUpdate = Notification.Name("SmartFillPreviewDidUpdate")
}
