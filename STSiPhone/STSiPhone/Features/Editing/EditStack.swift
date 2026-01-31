import Foundation
import AVFoundation
import UIKit

// MARK: - Edit Stack Protocol

protocol EditStackDelegate: AnyObject {
    func editStackDidChange(_ editStack: EditStack)
    func editStackPreviewDidUpdate(_ editStack: EditStack, composition: AVMutableComposition?, videoComposition: AVVideoComposition?)
}

// MARK: - Edit Stack

/// Non-destructive edit stack that manages a sequence of edit operations
final class EditStack: ObservableObject {
    
    // MARK: - Properties
    
    /// The original source asset (never modified)
    private let sourceAsset: AVAsset
    
    /// Stack of applied operations (for undo)
    private var operationStack: [EditOperation] = []
    
    /// Stack of undone operations (for redo)
    private var redoStack: [EditOperation] = []
    
    /// Maximum number of operations to keep in history
    private let maxHistorySize: Int = 50
    
    /// Delegate for edit stack changes
    weak var delegate: EditStackDelegate?
    
    /// Current preview composition (lazy-loaded)
    private var _previewComposition: AVMutableComposition?
    
    /// Current video composition for visual effects (lazy-loaded)
    private var _previewVideoComposition: AVVideoComposition?
    
    // MARK: - Published Properties for SwiftUI
    
    @Published var canUndo: Bool = false
    @Published var canRedo: Bool = false
    @Published var operationCount: Int = 0
    @Published var hasUnsavedChanges: Bool = false
    @Published var isGeneratingPreview: Bool = false
    
    // MARK: - Computed Properties
    
    /// All operations currently applied
    var operations: [EditOperation] {
        return operationStack
    }
    
    /// Whether there are any operations applied
    var hasOperations: Bool {
        return !operationStack.isEmpty
    }
    
    /// Current preview composition combining all operations (async)
    func getPreviewComposition() async -> (composition: AVMutableComposition?, videoComposition: AVVideoComposition?) {
        if _previewComposition == nil {
            isGeneratingPreview = true
            let result = await createPreviewComposition()
            _previewComposition = result.composition
            _previewVideoComposition = result.videoComposition
            isGeneratingPreview = false
        }
        return (composition: _previewComposition, videoComposition: _previewVideoComposition)
    }
    
    /// Legacy method for compatibility
    func getPreviewCompositionLegacy() async -> AVMutableComposition? {
        let result = await getPreviewComposition()
        return result.composition
    }
    
    /// Description of current edit stack
    var stackDescription: String {
        if operationStack.isEmpty {
            return "No edits applied"
        } else {
            let descriptions = operationStack.map { $0.operationDescription }
            return descriptions.joined(separator: " → ")
        }
    }
    
    /// Quick access to current composition duration (async)
    func getCurrentCompositionDuration() async -> CMTime {
        do {
            if let composition = await getPreviewComposition().composition {
                return try await composition.load(.duration)
            } else {
                return try await sourceAsset.load(.duration)
            }
        } catch {
            print("❌ Failed to load composition duration: \(error)")
            return .zero
        }
    }
    
    // MARK: - Initialization
    
    init(sourceAsset: AVAsset) {
        self.sourceAsset = sourceAsset
        updatePublishedProperties()
    }
    
    // MARK: - Operation Management
    
    /// Apply a new edit operation to the stack
    func apply(operation: EditOperation) {
        guard operation.canApplyToAsset(sourceAsset) else {
            print("⚠️ EDIT STACK: Cannot apply \(operation.displayName) to current asset")
            return
        }
        
        print("✅ EDIT STACK: Applying \(operation.displayName)")
        
        // Add operation to stack
        operationStack.append(operation)
        
        // Clear redo stack when new operation is applied
        redoStack.removeAll()
        
        // Limit history size
        if operationStack.count > maxHistorySize {
            operationStack.removeFirst(operationStack.count - maxHistorySize)
        }
        
        // Invalidate preview compositions
        _previewComposition = nil
        _previewVideoComposition = nil
        
        // Update state and notify delegates
        updatePublishedProperties()
        notifyDelegateOfChanges()
        
        print("📊 EDIT STACK: \(operationStack.count) operations, last: \(operation.operationDescription)")
    }
    
    /// Undo the last operation
    func undo() -> EditOperation? {
        guard !operationStack.isEmpty else {
            print("⚠️ EDIT STACK: Cannot undo - no operations in stack")
            return nil
        }
        
        let operation = operationStack.removeLast()
        redoStack.append(operation)
        
        print("↩️ EDIT STACK: Undid \(operation.displayName)")
        
        // Invalidate preview compositions
        _previewComposition = nil
        _previewVideoComposition = nil
        
        // Update state and notify delegates
        updatePublishedProperties()
        notifyDelegateOfChanges()
        
        return operation
    }
    
    /// Redo the last undone operation
    func redo() -> EditOperation? {
        guard !redoStack.isEmpty else {
            print("⚠️ EDIT STACK: Cannot redo - no operations in redo stack")
            return nil
        }
        
        let operation = redoStack.removeLast()
        operationStack.append(operation)
        
        print("↪️ EDIT STACK: Redid \(operation.displayName)")
        
        // Invalidate preview compositions
        _previewComposition = nil
        _previewVideoComposition = nil
        
        // Update state and notify delegates
        updatePublishedProperties()
        notifyDelegateOfChanges()
        
        return operation
    }
    
    /// Remove a specific operation from the stack
    func remove(operationWithId id: UUID) -> EditOperation? {
        guard let index = operationStack.firstIndex(where: { $0.id == id }) else {
            return nil
        }
        
        let operation = operationStack.remove(at: index)
        
        print("🗑️ EDIT STACK: Removed \(operation.displayName)")
        
        // Clear redo stack when modifying history
        redoStack.removeAll()
        
        // Invalidate preview compositions
        _previewComposition = nil
        _previewVideoComposition = nil
        
        // Update state and notify delegates
        updatePublishedProperties()
        notifyDelegateOfChanges()
        
        return operation
    }
    
    /// Clear all operations
    func clearAll() {
        guard !operationStack.isEmpty || !redoStack.isEmpty else { return }
        
        print("🧹 EDIT STACK: Clearing all operations")
        
        operationStack.removeAll()
        redoStack.removeAll()
        
        // Invalidate preview compositions
        _previewComposition = nil
        _previewVideoComposition = nil
        
        // Update state and notify delegates
        updatePublishedProperties()
        notifyDelegateOfChanges()
    }
    
    /// Replace an existing operation with a new one
    func replace(operationWithId id: UUID, with newOperation: EditOperation) -> Bool {
        guard let index = operationStack.firstIndex(where: { $0.id == id }),
              newOperation.canApplyToAsset(sourceAsset) else {
            return false
        }
        
        let oldOperation = operationStack[index]
        operationStack[index] = newOperation
        
        print("🔄 EDIT STACK: Replaced \(oldOperation.displayName) with \(newOperation.displayName)")
        
        // Clear redo stack when modifying history
        redoStack.removeAll()
        
        // Invalidate preview compositions
        _previewComposition = nil
        _previewVideoComposition = nil
        
        // Update state and notify delegates
        updatePublishedProperties()
        notifyDelegateOfChanges()
        
        return true
    }
    
    /// Replace existing trim operation with a new one from CMTimeRange
    func replaceTrim(with range: CMTimeRange) {
        // Remove existing TrimOperation if any and append a new one
        operationStack.removeAll { ($0 as? TrimOperation) != nil }
        
        Task {
            do {
                let originalDuration = try await sourceAsset.load(.duration)
                let endTime = CMTimeAdd(range.start, range.duration)
                let op = TrimOperation(startTime: range.start, endTime: endTime, originalDuration: originalDuration)
                
                await MainActor.run {
                    self.operationStack.append(op)
                    
                    // Invalidate preview compositions
                    self._previewComposition = nil
                    self._previewVideoComposition = nil
                    self.updatePublishedProperties()
                    self.notifyDelegateOfChanges()
                    
        print("✂️ EDIT STACK: Replaced trim with range \(range.start.seconds)-\(endTime.seconds)s")
                }
            } catch {
                print("❌ Failed to load source asset duration for trim: \(error)")
            }
        }
    }
    
    /// Replace existing crop operation with a normalized rectangle
    func replaceCrop(with normalizedRect: CGRect, rotationDegrees: CGFloat = 0) {
        let sanitizedRect = sanitizeCropRect(normalizedRect)
        let originalCount = operationStack.count
        operationStack.removeAll { ($0 as? CropOperation) != nil }
        if operationStack.count != originalCount {
            print("🧹 EDIT STACK: Removed existing crop operations before applying new one")
        }
        
        let cropOperation = CropOperation(normalizedCropRect: sanitizedRect, rotationDegrees: rotationDegrees)
        operationStack.append(cropOperation)
        
        redoStack.removeAll()
        _previewComposition = nil
        _previewVideoComposition = nil
        updatePublishedProperties()
        notifyDelegateOfChanges()
        
        print("🖼️ EDIT STACK: Replaced crop with rect \(sanitizedRect), rotation \(rotationDegrees)")
    }
    
    /// Remove any crop operation from the stack
    func clearCrop() {
        let originalCount = operationStack.count
        operationStack.removeAll { ($0 as? CropOperation) != nil }
        guard operationStack.count != originalCount else { return }
        
        redoStack.removeAll()
        _previewComposition = nil
        _previewVideoComposition = nil
        updatePublishedProperties()
        notifyDelegateOfChanges()
        
        print("🧼 EDIT STACK: Cleared crop operation")
    }
    
    /// Remove any applied trim operations and revert to the full clip
    func clearTrim() {
        let originalCount = operationStack.count
        operationStack.removeAll { ($0 as? TrimOperation) != nil }
        guard operationStack.count != originalCount else { return }
        redoStack.removeAll()
        _previewComposition = nil
        _previewVideoComposition = nil
        updatePublishedProperties()
        notifyDelegateOfChanges()
        print("🧹 EDIT STACK: Cleared trim operation")
    }
    
    /// Current trim range if one is applied
    var currentTrimRange: CMTimeRange? {
        return operationStack.compactMap { ($0 as? TrimOperation)?.trimRange }.last
    }
    
    // MARK: - Preview Composition

    /// Create a preview composition combining all current operations WITH video composition support
    private func createPreviewComposition() async -> (composition: AVMutableComposition?, videoComposition: AVVideoComposition?) {
        print("🎬 EDIT STACK: Creating preview composition with \(operationStack.count) operations")
        
        let composition = AVMutableComposition()
        
        do {
            // STEP 1: Build the timeline composition (handles trim operations)
            if operationStack.isEmpty {
                // No operations - return composition with original tracks
                try await addOriginalTracksToComposition(composition)
            } else {
                // First, add original tracks to the composition
                try await addOriginalTracksToComposition(composition)
                
                // CRITICAL FIX: Properly await timeline operations sequentially
                for operation in operationStack {
                    if operation is TrimOperation {
                        print("  ✂️ Applying timeline operation: \(operation.displayName)")
                        try await operation.applyToComposition(composition, sourceAsset: sourceAsset)
                    }
                }
                
                print("✅ TIMELINE OPERATIONS: All timeline operations completed, composition ready")
            }
            
            // STEP 2: Create video composition for visual effects (handles crop operations)
            let videoComposition = await createVideoComposition(for: composition)
            
            let duration = try await composition.load(.duration)
            print("✅ EDIT STACK: Preview composition created (duration: \(CMTimeGetSeconds(duration))s, videoComp: \(videoComposition != nil))")
            return (composition: composition, videoComposition: videoComposition)
            
        } catch {
            print("❌ EDIT STACK: Failed to create preview composition: \(error)")
            return (composition: nil, videoComposition: nil)
        }
    }

    /// Add original asset tracks to composition
    private func addOriginalTracksToComposition(_ composition: AVMutableComposition) async throws {
        // Add video tracks using modern async API
        let videoTracks = try await sourceAsset.loadTracks(withMediaType: .video)
        for videoTrack in videoTracks {
            let compositionVideoTrack = composition.addMutableTrack(
                withMediaType: .video,
                preferredTrackID: kCMPersistentTrackID_Invalid
            )
            try compositionVideoTrack?.insertTimeRange(
                CMTimeRange(start: .zero, duration: try await sourceAsset.load(.duration)),
                of: videoTrack,
                at: .zero
            )
        }
        
        // Add audio tracks using modern async API
        let audioTracks = try await sourceAsset.loadTracks(withMediaType: .audio)
        for audioTrack in audioTracks {
            let compositionAudioTrack = composition.addMutableTrack(
                withMediaType: .audio,
                preferredTrackID: kCMPersistentTrackID_Invalid
            )
            try compositionAudioTrack?.insertTimeRange(
                CMTimeRange(start: .zero, duration: try await sourceAsset.load(.duration)),
                of: audioTrack,
                at: .zero
            )
        }
    }

    /// Create video composition with layer instructions for visual effects AND orientation correction
    private func createVideoComposition(for composition: AVMutableComposition) async -> AVVideoComposition? {
        do {
            let videoTracks = try await composition.loadTracks(withMediaType: .video)
            guard let firstVideoTrack = videoTracks.first else {
                print("❌ No video tracks found for video composition")
                return nil
            }
            
            // Get video properties from the source asset (for original transform)
            let sourceVideoTracks = try await sourceAsset.loadTracks(withMediaType: .video)
            guard let sourceVideoTrack = sourceVideoTracks.first else {
                print("❌ No source video tracks found")
                return nil
            }
            
            let naturalSize = try await sourceVideoTrack.load(.naturalSize)
            let preferredTransform = try await sourceVideoTrack.load(.preferredTransform)
            let duration = try await composition.load(.duration)
            
            // CRITICAL PORTRAIT FIX: Check if we need video composition for orientation OR visual effects
            let visualEffectsOperations = operationStack.filter { operation in
                return operation is CropOperation || operation is SmartFillOperation
            }
            
            // Check if video needs orientation correction (non-identity transform)
            let needsOrientationCorrection = !preferredTransform.isIdentity
            
            guard !visualEffectsOperations.isEmpty || needsOrientationCorrection else {
                print("🎬 No visual effects or orientation correction needed - skipping video composition")
                return nil
            }
            
            print("🎨 EDIT STACK: Creating video composition for:")
            print("   🎭 Visual effects: \(visualEffectsOperations.count)")
            print("   📱 Orientation correction needed: \(needsOrientationCorrection)")
            
            // Calculate render size from natural size and transform
            let renderSize = calculateRenderSize(naturalSize: naturalSize, transform: preferredTransform)
            
            // Create video composition
            let videoComposition = AVMutableVideoComposition()
            videoComposition.frameDuration = CMTime(value: 1, timescale: 30) // 30 FPS
            videoComposition.renderSize = renderSize
            
            // Create main instruction covering the entire duration
            let instruction = AVMutableVideoCompositionInstruction()
            instruction.timeRange = CMTimeRange(start: .zero, duration: duration)
            
            // Create layer instruction for the video track
            let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: firstVideoTrack)
            
            // CRITICAL FIX: Apply ONLY the preferred transform for orientation, no additional scaling
            var finalTransform = preferredTransform
            print("📐 ORIENTATION: Applying preferred transform without additional scaling")
            print("   🎯 Transform: \(preferredTransform)")
            
            // Only apply visual effects operations if they exist
            for operation in visualEffectsOperations {
                if let cropOperation = operation as? CropOperation {
                    print("✂️ Applying crop transform to video composition")
                    let cropTransform = createCropTransform(
                        naturalSize: naturalSize,
                        preferredTransform: preferredTransform,
                        cropRect: cropOperation.normalizedCropRect,
                        renderSize: renderSize,
                        rotationDegrees: cropOperation.rotationAngleDegrees
                    )
                    finalTransform = finalTransform.concatenating(cropTransform)
                } else if let smartFillOperation = operation as? SmartFillOperation {
                    print("🤖 SmartFill operation present – preview remains unscaled (export handles composite)")
                    print("   🎯 SmartFill settings in stack: blur=\(smartFillOperation.smartFillSettings.defaultBlurRadius), scale=\(smartFillOperation.smartFillSettings.backgroundScale)")
                }
            }
            
            // Set the final combined transform (orientation + visual effects)
            layerInstruction.setTransform(finalTransform, at: .zero)
            
            instruction.layerInstructions = [layerInstruction]
            videoComposition.instructions = [instruction]
            
            print("✅ EDIT STACK: Video composition created - render size: \(renderSize)")
            print("   🎯 Final transform applied for proper display scaling")
            return videoComposition
            
        } catch {
            print("❌ EDIT STACK: Failed to create video composition: \(error)")
            return nil
        }
    }
    
    /// Calculate render size based on natural size and transform - PORTRAIT FIX
    private func calculateRenderSize(naturalSize: CGSize, transform: CGAffineTransform) -> CGSize {
        // CRITICAL FIX: Use upright size but ensure it fits properly for display
        let uprightSize = NormalizeOrientation.uprightExtent(naturalSize: naturalSize, preferred: transform)
        
        print("📐 RENDER SIZE: Natural: \(naturalSize) -> Upright: \(uprightSize)")
        
        // For portrait videos, we want to maintain the aspect ratio but ensure full visibility
        // The render size should be the upright size to maintain proper aspect ratio
        return uprightSize
    }
    
    /// Create crop transform that properly scales and translates the video - PORTRAIT FIX
    private func createCropTransform(naturalSize: CGSize,
                                     preferredTransform: CGAffineTransform,
                                     cropRect: CGRect,
                                     renderSize: CGSize,
                                     rotationDegrees: CGFloat) -> CGAffineTransform {
        print("✂️ CROP TRANSFORM: Creating for portrait-aware cropping")
        print("   📐 Natural: \(naturalSize), Crop: \(cropRect), Render: \(renderSize)")
        
        // CRITICAL FIX: Use NormalizeOrientation.aspectFitTransform for proper orientation handling
        let baseTransform = NormalizeOrientation.aspectFitTransform(
            naturalSize: naturalSize,
            preferred: preferredTransform,
            renderSize: renderSize
        )
        
        var workingTransform = baseTransform
        let rotationRadians = rotationDegrees * (.pi / 180)
        if abs(rotationRadians) > 0.0001 {
            let center = CGPoint(x: renderSize.width / 2, y: renderSize.height / 2)
            let rotationTransform = CGAffineTransform(translationX: center.x, y: center.y)
                .rotated(by: rotationRadians)
                .translatedBy(x: -center.x, y: -center.y)
            workingTransform = workingTransform.concatenating(rotationTransform)
            print("   🔁 Applying rotation: \(rotationDegrees)°")
        }
        
        // Apply crop adjustments to the base transform
        let cropScaleX = 1.0 / cropRect.width
        let cropScaleY = 1.0 / cropRect.height
        let cropTranslateX = -cropRect.origin.x * cropScaleX
        let cropTranslateY = -cropRect.origin.y * cropScaleY
        
        let cropTransform = CGAffineTransform(scaleX: cropScaleX, y: cropScaleY)
            .translatedBy(x: cropTranslateX, y: cropTranslateY)
        
        // Combine base orientation transform with crop transform
        let finalTransform = workingTransform.concatenating(cropTransform)
        
        print("✅ CROP TRANSFORM: Portrait-aware transform created")
        print("   🎯 Base transform for orientation correction applied")
        print("   ✂️ Crop scale: (\(cropScaleX), \(cropScaleY)), translate: (\(cropTranslateX), \(cropTranslateY))")
        
        return finalTransform
    }

    /// Force regenerate preview composition
    func regeneratePreview() {
        print("🔄 EDIT STACK: Regenerating preview composition")
        _previewComposition = nil
        _previewVideoComposition = nil
        Task { @MainActor in
            let result = await self.getPreviewComposition()
            self.delegate?.editStackPreviewDidUpdate(self, composition: result.composition, videoComposition: result.videoComposition)
        }
    }
    
    // MARK: - Export
    
    /// Create final composition for export with all operations applied
    func createExportComposition() async -> AVMutableComposition? {
        print("📤 EDIT STACK: Creating export composition")
        let result = await createPreviewComposition()
        return result.composition
    }
    
    /// Export the current edit stack to a URL
    func exportToURL(
        _ outputURL: URL,
        quality: String = AVAssetExportPresetHighestQuality,
        progress: @escaping (Double) -> Void = { _ in },
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        Task {
            guard let exportComposition = await createExportComposition() else {
                completion(.failure(EditStackError.failedToCreateComposition))
                return
            }
            
            print("📤 EDIT STACK: Starting export with \(operationStack.count) operations")
            
            // Create export session
            guard let exportSession = AVAssetExportSession(
                asset: exportComposition,
                presetName: quality
            ) else {
                completion(.failure(EditStackError.failedToCreateExportSession))
                return
            }
            
            exportSession.outputURL = outputURL
            exportSession.outputFileType = .mov
            exportSession.shouldOptimizeForNetworkUse = true
            
            // Handle SmartFill operations during export if needed
            handleSmartFillDuringExport(exportSession)
            
            // MODERNIZED: Replace deprecated exportAsynchronously with STSExporter.run
            do {
                try await STSExporter.run(session: exportSession, to: outputURL, as: .mov) { progressValue in
                    progress(progressValue)
                }
                
                print("✅ EDIT STACK: Export completed successfully")
                completion(.success(outputURL))
                
            } catch {
                print("❌ EDIT STACK: Export failed: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
    }
    
    /// Handle SmartFill operations during export
    private func handleSmartFillDuringExport(_ exportSession: AVAssetExportSession) {
        // Check if we have any SmartFill operations
        let smartFillOps = operationStack.compactMap { $0 as? SmartFillOperation }
        
        if !smartFillOps.isEmpty {
            print("🤖 EDIT STACK: \(smartFillOps.count) SmartFill operations will be processed during export")
            // SmartFill processing would be integrated here
            // For now, we'll just log that it would happen
        }
    }
    
    // MARK: - Private Helpers
    
    private func updatePublishedProperties() {
        canUndo = !operationStack.isEmpty
        canRedo = !redoStack.isEmpty
        operationCount = operationStack.count
        hasUnsavedChanges = !operationStack.isEmpty
    }
    
    private func notifyDelegateOfChanges() {
        delegate?.editStackDidChange(self)
        
        // SWIFT 6 FIX: Use Task { @MainActor } to avoid @Sendable requirement
        Task { @MainActor in
            let result = await self.getPreviewComposition()
            // Direct delegate call - no cross-boundary capture issues
            self.delegate?.editStackPreviewDidUpdate(self, composition: result.composition, videoComposition: result.videoComposition)
        }
    }
}

// MARK: - Edit Stack Errors

enum EditStackError: LocalizedError {
    case failedToCreateComposition
    case failedToCreateExportSession
    case exportFailed
    case exportCancelled
    
    var errorDescription: String? {
        switch self {
        case .failedToCreateComposition:
            return "Failed to create video composition from edit operations"
        case .failedToCreateExportSession:
            return "Failed to create export session"
        case .exportFailed:
            return "Video export failed"
        case .exportCancelled:
            return "Video export was cancelled"
        }
    }
}

// MARK: - Convenience Extensions

extension EditStack {
    
    /// Quick access to the most recent operation
    var lastOperation: EditOperation? {
        return operationStack.last
    }
    
    /// Quick access to trim operations
    var trimOperations: [TrimOperation] {
        return operationStack.compactMap { $0 as? TrimOperation }
    }
    
    /// Quick access to crop operations
    var cropOperations: [CropOperation] {
        return operationStack.compactMap { $0 as? CropOperation }
    }
    
    /// Current crop rectangle if one is active
    var currentCropRect: CGRect? {
        return cropOperations.last?.normalizedCropRect
    }
    
    var currentCropRotationDegrees: CGFloat? {
        return cropOperations.last?.rotationAngleDegrees
    }
    
    /// Quick access to SmartFill operations
    var smartFillOperations: [SmartFillOperation] {
        return operationStack.compactMap { $0 as? SmartFillOperation }
    }
    
    /// Get operation by ID
    func operation(withId id: UUID) -> EditOperation? {
        return operationStack.first { $0.id == id }
    }
}

// MARK: - Crop Helpers

private extension EditStack {
    func sanitizeCropRect(_ rect: CGRect) -> CGRect {
        var sanitized = rect
        sanitized.origin.x = max(0.0, min(1.0, sanitized.origin.x))
        sanitized.origin.y = max(0.0, min(1.0, sanitized.origin.y))
        sanitized.size.width = max(0.01, min(1.0 - sanitized.origin.x, sanitized.size.width))
        sanitized.size.height = max(0.01, min(1.0 - sanitized.origin.y, sanitized.size.height))
        return sanitized
    }
}
