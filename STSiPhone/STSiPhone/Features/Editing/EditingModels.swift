import Foundation
import CoreGraphics
import AVFoundation

// MARK: - Editing Mode Enum
enum EditingMode: String, CaseIterable {
    case trim = "trim"
    case crop = "crop"
    case filters = "filters"
    case markers = "markers"
    
    var displayName: String {
        switch self {
        case .trim:
            return "Trim"
        case .crop:
            return "Crop"
        case .filters:
            return "Filters"
        case .markers:
            return "Markers"
        }
    }
    
    var icon: String {
        switch self {
        case .trim:
            return "scissors"
        case .crop:
            return "crop"
        case .filters:
            return "camera.filters"
        case .markers:
            return "bookmark"
        }
    }
}

// MARK: - Crop Preset
struct CropPreset: Identifiable, Hashable {
    let id = UUID()
    let displayName: String
    let aspectRatio: Double
    
    static let common: [CropPreset] = [
        CropPreset(displayName: "Original", aspectRatio: 0.0), // Special case for no crop
        CropPreset(displayName: "16:9", aspectRatio: 16.0/9.0),
        CropPreset(displayName: "4:3", aspectRatio: 4.0/3.0),
        CropPreset(displayName: "1:1", aspectRatio: 1.0),
        CropPreset(displayName: "9:16", aspectRatio: 9.0/16.0),
        CropPreset(displayName: "3:4", aspectRatio: 3.0/4.0)
    ]
}

// Note: VideoMarker is defined in UnifiedVideoOverlay.swift
// Note: VideoFile is defined in VideoFileManager.swift  
// Note: ExportQuality is defined in ExportEngine.swift
// These types are used here but defined elsewhere to avoid conflicts

// MARK: - Edited Video Result
struct EditedVideoResult: Identifiable {
    let id = UUID()
    let originalVideoFile: VideoFile
    let trimRange: CMTimeRange?
    let cropRect: CGRect
    let cropRotationDegrees: Double
    let markers: [VideoMarker]
    let brightness: Float
    let contrast: Float
    let saturation: Float
    let hasEdits: Bool
    
    // Export settings
    var exportQuality: ExportQuality = .high
    var exportFormat: ExportFormat = .mp4
    
    var formattedTrimRange: String? {
        guard let range = trimRange else { return nil }
        
        let start = CMTimeGetSeconds(range.start)
        let duration = CMTimeGetSeconds(range.duration)
        let end = start + duration
        
        let startMinutes = Int(start) / 60
        let startSeconds = Int(start) % 60
        let endMinutes = Int(end) / 60
        let endSeconds = Int(end) % 60
        
        return String(format: "%d:%02d - %d:%02d", startMinutes, startSeconds, endMinutes, endSeconds)
    }
    
    var hasCrop: Bool {
        return cropRect != .zero
    }
    
    var hasMarkers: Bool {
        return !markers.isEmpty
    }
    
    var hasFilters: Bool {
        return brightness != 0.0 || contrast != 1.0 || saturation != 1.0
    }
}

// MARK: - Export Format
enum ExportFormat: String, CaseIterable {
    case mp4 = "mp4"
    case mov = "mov"
    
    var displayName: String {
        switch self {
        case .mp4:
            return "MP4"
        case .mov:
            return "MOV"
        }
    }
    
    var fileExtension: String {
        switch self {
        case .mp4:
            return "mp4"
        case .mov:
            return "mov"
        }
    }
    
    var AVFileType: AVFileType {
        switch self {
        case .mp4:
            return .mp4
        case .mov:
            return .mov
        }
    }
}

// MARK: - Export Progress
struct ExportProgress: Identifiable {
    let id = UUID()
    var progress: Double = 0.0
    var status: ExportStatus = .preparing
    var error: Error?
    
    enum ExportStatus {
        case preparing
        case exporting
        case completed
        case failed
        case cancelled
        
        var displayName: String {
            switch self {
            case .preparing:
                return "Preparing..."
            case .exporting:
                return "Exporting..."
            case .completed:
                return "Completed"
            case .failed:
                return "Failed"
            case .cancelled:
                return "Cancelled"
            }
        }
    }
}
