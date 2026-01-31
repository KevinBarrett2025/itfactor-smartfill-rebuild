import SwiftUI
import UIKit

enum SizeCardRenderer {
    enum RenderError: Error {
        case renderFailed
    }

    @MainActor
    static func renderPNG(profile: ActorProfile, reps: [RepInfo], config: SizeCardConfig, scale: CGFloat = 3.0) throws -> URL {
#if DEBUG
        let canvas = config.template.aspect.canvasSize
        print(String(format: "🧪 SizeCardRender PNG page=%.0fx%.0f scale=%.2f", canvas.width, canvas.height, scale))
#endif
        let renderer = ImageRenderer(content: renderableView(profile: profile, reps: reps, config: config))
        renderer.scale = scale
        guard let image = renderer.uiImage else { throw RenderError.renderFailed }
#if DEBUG
        print(String(format: "🧪 SizeCardRender PNG imageSize=%.0fx%.0f", image.size.width, image.size.height))
#endif
        let url = temporaryURL(ext: "png", profile: profile)
        guard let data = image.pngData() else { throw RenderError.renderFailed }
        try data.write(to: url)
        return url
    }

    @MainActor
    static func renderPDF(profile: ActorProfile, reps: [RepInfo], config: SizeCardConfig) throws -> URL {
#if DEBUG
        let canvas = config.template.aspect.canvasSize
        print(String(format: "🧪 SizeCardRender PDF page=%.0fx%.0f scale=%.2f", canvas.width, canvas.height, 2.0))
#endif
        let renderer = ImageRenderer(content: renderableView(profile: profile, reps: reps, config: config))
        renderer.scale = 2.0
        guard let image = renderer.uiImage else { throw RenderError.renderFailed }
#if DEBUG
        print(String(format: "🧪 SizeCardRender PDF imageSize=%.0fx%.0f", image.size.width, image.size.height))
#endif
        let bounds = CGRect(origin: .zero, size: image.size)
        let pdfURL = temporaryURL(ext: "pdf", profile: profile)
        let pdfRenderer = UIGraphicsPDFRenderer(bounds: bounds)
        try pdfRenderer.writePDF(to: pdfURL) { ctx in
            ctx.beginPage()
            image.draw(in: bounds)
        }
        return pdfURL
    }

    @MainActor
    static func presentShareSheet(profile: ActorProfile,
                                  reps: [RepInfo],
                                  config: SizeCardConfig,
                                  from controller: UIViewController? = nil) {
        Task {
            do {
                let pdfURL = try renderPDF(profile: profile, reps: reps, config: config)
                let pngURL = try renderPNG(profile: profile, reps: reps, config: config)
                let activity = UIActivityViewController(activityItems: [pdfURL, pngURL], applicationActivities: nil)
                (controller ?? UIApplication.sts_topMostController)?.present(activity, animated: true)
            } catch {
                print("❌ SizeCard export failed: \(error)")
            }
        }
    }

    private static func renderableView(profile: ActorProfile, reps: [RepInfo], config: SizeCardConfig) -> some View {
        SizeCardView(profile: profile, reps: reps, config: config)
            .environment(\.legibilityWeight, .regular)
            .environment(\.dynamicTypeSize, .xSmall)
#if DEBUG
            .environment(\.sizeCardRenderContext, .export)
#endif
    }

    private static func temporaryURL(ext: String, profile: ActorProfile) -> URL {
        let name = profile.displayName.replacingOccurrences(of: "\\W+", with: "_", options: .regularExpression)
        return FileManager.default.temporaryDirectory.appendingPathComponent("SizeCard_\(name)_\(UUID().uuidString).\(ext)")
    }
}

private extension UIApplication {
    static var sts_topMostController: UIViewController? {
        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }),
              let root = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController else {
            return nil
        }
        var top = root
        while let presented = top.presentedViewController {
            top = presented
        }
        return top
    }
}
