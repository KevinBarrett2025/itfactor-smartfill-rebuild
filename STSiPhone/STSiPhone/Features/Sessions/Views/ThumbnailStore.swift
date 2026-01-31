import UIKit
import AVFoundation
import SwiftUI

@MainActor
public final class ThumbnailStore: ObservableObject {
    public static let shared = ThumbnailStore()

    private let cache = ThumbnailCache()

    public func image(for url: URL, at seconds: Double = 0.25, max: CGFloat = 240) async -> UIImage? {
        let key = url.absoluteString
        if let cached = await cache.image(for: key) { return cached }

        let seconds = seconds
        let maxDimension = max
        let generated: UIImage? = await Task.detached(priority: .userInitiated) {
            let asset = AVURLAsset(url: url)
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: maxDimension, height: maxDimension)
            let time = CMTime(seconds: seconds, preferredTimescale: 600)
            do {
                let result = try await generator.image(at: time)
                return UIImage(cgImage: result.image)
            } catch {
                print("⚠️ Could not generate thumbnail: \(error)")
                return nil
            }
        }.value

        if let image = generated {
            await cache.set(image, for: key)
        }

        return generated
    }
}

public struct AsyncThumbnail: View {
    let url: URL
    let corner: CGFloat
    let sampleTime: Double

    @State private var image: UIImage?

    public init(url: URL, corner: CGFloat = 12, sampleTime: Double = 0.25) {
        self.url = url
        self.corner = corner
        self.sampleTime = sampleTime
    }

    public var body: some View {
        Group {
            if let img = image {
                Image(uiImage: img).resizable().scaledToFill()
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: corner)
                        .fill(.secondary.opacity(0.15))
                    ProgressView()
                }
            }
        }
        .task(id: url) {
            image = await ThumbnailStore.shared.image(for: url, at: sampleTime)
        }
        .clipShape(RoundedRectangle(cornerRadius: corner))
    }
}

private actor ThumbnailCache {
    private let cache = NSCache<NSString, UIImage>()

    func image(for key: String) -> UIImage? {
        cache.object(forKey: key as NSString)
    }

    func set(_ image: UIImage, for key: String) {
        cache.setObject(image, forKey: key as NSString)
    }
}
