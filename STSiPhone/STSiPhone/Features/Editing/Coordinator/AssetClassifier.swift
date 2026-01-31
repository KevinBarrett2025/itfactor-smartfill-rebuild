import AVFoundation
import UIKit

enum AssetKind: Equatable {
    case video(url: URL)
    case photo(url: URL)
}

enum EditorMode: Equatable {
    case playback, trim, crop, smartFill
}

struct AssetClassifier {
    @MainActor
    static func classify(fallbackURL: URL) async -> AssetKind {
        let ext = fallbackURL.pathExtension.lowercased()
        // Check for image extensions
        if ["png","jpg","jpeg","heic","heif","tiff","gif","bmp"].contains(ext) {
            return .photo(url: fallbackURL)
        }
        
        let asset = AVURLAsset(url: fallbackURL)
        do {
            let tracks = try await asset.loadTracks(withMediaType: .video)
            guard let track = tracks.first else {
                return .video(url: fallbackURL)
            }
            
            let naturalSize = try await track.load(.naturalSize)
            let preferredTransform = try await track.load(.preferredTransform)
            
            // Check if video is rotated (portrait recorded as landscape with transform)
            let isRotated = abs(preferredTransform.b) == 1.0 && abs(preferredTransform.c) == 1.0
            let width = isRotated ? naturalSize.height : naturalSize.width
            let height = isRotated ? naturalSize.width : naturalSize.height
            
            if height > width {
                print("⚠️ AssetClassifier: Portrait video detected for \(fallbackURL.lastPathComponent). SmartFill should convert to landscape before editing.")
            }
            return .video(url: fallbackURL)
        } catch {
            print("⚠️ AssetClassifier: Failed to analyze asset, defaulting to video: \(error)")
            return .video(url: fallbackURL)
        }
    }
}
