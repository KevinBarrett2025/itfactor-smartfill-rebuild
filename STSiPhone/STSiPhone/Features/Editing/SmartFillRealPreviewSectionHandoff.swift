import SwiftUI

/// A lightweight, dynamic preview that renders at the *displayed* size, not 1080p.
/// 🔄 REAL-TIME UPDATE FIX: Responds to settings changes immediately
struct SmartFillRealPreviewSectionHandoff: View {
    @StateObject private var vm: SmartFillStillPreviewViewModel

    let take: UnifiedTake
    let settings: SmartFillSettings

    init(take: UnifiedTake, settings: SmartFillSettings) {
        self.take = take
        self.settings = settings
        _vm = StateObject(wrappedValue: SmartFillStillPreviewViewModel(
            input: .init(takeID: take.id,
                         fileName: take.fileName,
                         targetPixelSize: CGSize(width: 960, height: 540), // safe default
                         settings: settings)
        ))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            GeometryReader { geo in
                // Compute the actual display size (points) with a 16:9 frame.
                let widthPts = geo.size.width
                let heightPts = widthPts / 16 * 9
                // Convert to pixels using screen scale. Cap to 1MP and 960x540 to keep it snappy.
                let scale = UIScreen.main.scale
                let pxWidth  = min(max(320, widthPts * scale), 960)
                let pxHeight = min(max(180, heightPts * scale), 540)
                // Update VM when size changes.
                Color.clear
                    .onAppear { updateTarget(CGSize(width: pxWidth, height: pxHeight)) }
                    .onChange(of: geo.size, initial: false) { oldValue, newValue in
                        updateTarget(CGSize(width: pxWidth, height: pxHeight))
                    }
                    // 🔄 CRITICAL FIX: Update when settings change
                    .onChange(of: settings.defaultBlurRadius, initial: false) { oldValue, newValue in
                        updateTarget(CGSize(width: pxWidth, height: pxHeight))
                    }
                    .onChange(of: settings.defaultDarkenAmount, initial: false) { oldValue, newValue in
                        updateTarget(CGSize(width: pxWidth, height: pxHeight))
                    }
                    .onChange(of: settings.backgroundScale, initial: false) { oldValue, newValue in
                        updateTarget(CGSize(width: pxWidth, height: pxHeight))
                    }
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(16/9, contentMode: .fit)
            .overlay(previewContent())
            .clipped()

            // 🔄 Status and regenerate button
            HStack {
                if vm.isGenerating {
                    HStack(spacing: 8) {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Updating...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Button("Regenerate") { 
                        vm.regenerate() 
                    }
                    .font(.caption)
                    .foregroundStyle(Theme.primary)
                }
                Spacer()
            }
        }
        .onAppear { 
            if vm.previewImage == nil { 
                vm.regenerate() 
            }
        }
    }

    @ViewBuilder
    private func previewContent() -> some View {
        if let img = vm.previewImage {
            Image(uiImage: img)
                .resizable()
                .aspectRatio(16/9, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.08)))
                .transition(.opacity)
        } else if let err = vm.error {
            VStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.title2)
                    .foregroundStyle(.orange)
                Text("Preview Error")
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                Text(err)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.secondary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        } else {
            // Loading placeholder with shimmer effect
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.secondary.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
                .shimmer() // Add shimmer effect while loading
        }
    }

    /// 🔄 CRITICAL: Update target with current settings to trigger regeneration
    private func updateTarget(_ pixelSize: CGSize) {
        print("🔄 Preview updating with new settings: blur=\(settings.defaultBlurRadius), darken=\(settings.defaultDarkenAmount), scale=\(settings.backgroundScale)")
        vm.update(input: .init(takeID: take.id,
                               fileName: take.fileName,
                               targetPixelSize: pixelSize,
                               settings: settings), 
                   regenerateIfSizeChanged: true) // Force regeneration
    }
}

// MARK: - Shimmer Effect Extension
extension View {
    func shimmer() -> some View {
        self.modifier(ShimmerModifier())
    }
}

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .overlay(
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [.clear, .white.opacity(0.1), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .rotationEffect(.degrees(30))
                    .offset(x: phase)
                    .clipped()
            )
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = 300
                }
            }
    }
}
