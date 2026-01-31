import SwiftUI

/// A one-time educational sheet explaining the Keyframe Photo feature.
struct KeyframePromptSheet: View {
    let onGotIt: () -> Void
    let onDontShowAgain: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            // Header
            VStack(spacing: 12) {
                Text("✨ Keyframe Photo")
                    .font(.title2.weight(.semibold))
                    .multilineTextAlignment(.center)

                Image("Keyframe_Thumbnail_Example")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 260)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .shadow(radius: 6)
            }
            .padding(.top, 4)

            // Scroll-safe body
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Take a clean, confident landscape (horizontal) photo.")
                    Text("This will become the keyframe at the start of your submission video — meaning your casting thumbnail will show your real first impression, not a random mid-sentence moment.")
                    Text("Bad thumbnails cost actors great auditions. This feature helps your thumbnail work for you, not against you.")
                }
                .font(.body)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 4)
            }
            .frame(maxHeight: 240)
            .layoutPriority(1)

            // Buttons row
            HStack(spacing: 16) {
                Button {
                    onDontShowAgain()
                } label: {
                    Text("Don’t show again")
                        .font(.subheadline)
                }

                Spacer()

                Button {
                    onGotIt()
                } label: {
                    Text("Got it")
                        .font(.headline)
                        .frame(minWidth: 80)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.top, 6)
        }
        .padding(.top, 20)
        .padding(.horizontal, 20)
        .padding(.bottom, 18)
        // Detents are controlled by the presenting view.
    }
}
