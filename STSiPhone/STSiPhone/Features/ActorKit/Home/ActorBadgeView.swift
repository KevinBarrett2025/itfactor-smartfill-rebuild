
import SwiftUI
import UIKit

// MARK: - Public Entry (drop-in)
public struct ActorBadgeView: View {
    public let logo: Image              // use a filled logo (non-transparent)
    public let headshot: Image?         // nil -> placeholder on back face

    @AppStorage("ActorKit.disableBadgeAnimation") private var disableAnimation = false
    @AppStorage("ActorKit.badgeSpeedMultiplier")  private var speedMultiplier: Double = 1.0
    @AppStorage("ActorKit.badgeStopFace") private var badgeStopFaceRaw: String = ActorKitBadgeStopFace.logo.rawValue

    @State private var spin: Double = 0
    private var badgeStopFace: ActorKitBadgeStopFace {
        ActorKitBadgeStopFace(rawValue: badgeStopFaceRaw) ?? .logo
    }

    public init(logo: Image, headshot: Image?) {
        self.logo = logo
        self.headshot = headshot
    }

    public var body: some View {
        ZStack {
            // Outer glass ring (optional slow counter spin for parallax)
            OuterRing()
                .frame(width: 200, height: 200)
                .rotationEffect(.degrees(disableAnimation ? 0 : -spin * 0.12))

            // Build a single back face type using AnyView to avoid generic mismatch
            let backFace: AnyView = {
                if let img = headshot {
                    return AnyView(CoinImageFace(image: img, inset: 6))
                } else {
                    return AnyView(PlaceholderFace())
                }
            }()

            // ONE rotating stack (faces + edge + rim)
            CoinStack(
                front: LogoCoinFace(image: logo),
                back: backFace,                               // <-- AnyView fixes the error
                edgeThickness: 8,
                ribs: 72
            )
            .frame(width: 176, height: 176)
            .modifier(Spin3D(spin: spin))            // rotate the WHOLE coin stack
        }
        .onAppear { startOrStopAnimation() }
        .onChange(of: disableAnimation, initial: false) { _, _ in startOrStopAnimation() }
        .onChange(of: speedMultiplier, initial: false)  { _, _ in startOrStopAnimation() }
        .onChange(of: badgeStopFaceRaw, initial: false) { _, _ in
            if disableAnimation {
                snapToSelectedFace(animated: true)
            }
        }
        .accessibilityLabel(Text("Actor badge"))
        .accessibilityHidden(false)
    }

    private func startOrStopAnimation() {
        if disableAnimation {
            snapToSelectedFace(animated: true)
            return
        }
        let clamped = max(0.25, min(speedMultiplier, 2.5))
        let duration = 6.0 / clamped
        withAnimation(.linear(duration: duration).repeatForever(autoreverses: false)) {
            spin = 360
        }
    }

    private func snapToSelectedFace(animated: Bool) {
        let target = Double(badgeStopFace.restAngleDegrees)
        if animated {
            withAnimation(.easeOut(duration: 0.25)) {
                spin = target
            }
        } else {
            spin = target
        }
    }
}

// MARK: - CoinStack (UIKit host) — SDK-agnostic backface culling
private struct CoinStack<Front: View, Back: View>: UIViewRepresentable {
    let front: Front
    let back: Back
    var edgeThickness: CGFloat = 7
    var ribs: Int = 64

    func makeCoordinator() -> Coord { Coord() }

    func makeUIView(context: Context) -> UIView {
        let container = UIView()
        container.backgroundColor = .clear
        container.layer.sublayerTransform = CATransform3D.withPerspective(0.6)

        // FRONT host
        let frontHost = UIHostingController(rootView: front)
        frontHost.view.backgroundColor = .clear
        frontHost.view.layer.isDoubleSided = false

        // BACK host (pre-rotate 180 deg so it faces viewer at coin 180 deg)
        let backHost = UIHostingController(rootView: back)
        backHost.view.backgroundColor = .clear
        backHost.view.layer.isDoubleSided = false
        backHost.view.layer.transform = CATransform3DMakeRotation(.pi, 0, 1, 0)

        // EDGE + RIM host (rotates with faces)
        let edgeHost = UIHostingController(rootView: AnyView(ZStack {
            Rim(); EdgeBand(thickness: edgeThickness, ribs: ribs)
        }))
        edgeHost.view.backgroundColor = .clear
        edgeHost.view.isUserInteractionEnabled = false

        for v in [frontHost.view!, backHost.view!, edgeHost.view!] {
            v.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(v)
            NSLayoutConstraint.activate([
                v.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                v.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                v.topAnchor.constraint(equalTo: container.topAnchor),
                v.bottomAnchor.constraint(equalTo: container.bottomAnchor)
            ])
        }

        context.coordinator.frontHost = frontHost
        context.coordinator.backHost  = backHost
        context.coordinator.edgeHost  = edgeHost
        return container
    }

    func updateUIView(_ view: UIView, context: Context) {
        context.coordinator.frontHost?.rootView = front
        context.coordinator.backHost?.rootView  = back
        context.coordinator.edgeHost?.rootView  = AnyView(ZStack {
            Rim(); EdgeBand(thickness: edgeThickness, ribs: ribs)
        })
    }

    final class Coord {
        var frontHost: UIHostingController<Front>?
        var backHost:  UIHostingController<Back>?
        var edgeHost:  UIHostingController<AnyView>?
    }
}

// MARK: - Faces
private struct LogoCoinFace: View {
    let image: Image
    var body: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(
                    colors: [Color(red: 0.18, green: 0.12, blue: 0.30),
                             Color(red: 0.08, green: 0.03, blue: 0.16)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))
                .overlay(Circle().stroke(Color.white.opacity(0.25), lineWidth: 2))
            image
                .renderingMode(.original)
                .resizable().scaledToFit().padding(26)
                .shadow(color: .black.opacity(0.35), radius: 5, x: 0, y: 3)
        }
        .clipShape(Circle())
    }
}

private struct CoinImageFace: View {
    let image: Image
    var inset: CGFloat = 6
    var body: some View {
        ZStack {
            Circle().fill(Color.black.opacity(0.10))
            image.resizable().scaledToFill().padding(inset).clipShape(Circle())
            Circle().strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
        }
        .clipShape(Circle())
    }
}

private struct PlaceholderFace: View {
    var body: some View {
        ZStack {
            RadialGradient(colors: [Color.gray.opacity(0.35), Color.gray.opacity(0.6)],
                           center: .center, startRadius: 0, endRadius: 120)
            Image(systemName: "person.crop.circle.fill")
                .resizable().scaledToFit().padding(24).foregroundStyle(.white.opacity(0.9))
        }
        .clipShape(Circle())
    }
}

// MARK: - 3D spin (no wobble)
private struct Spin3D: ViewModifier {
    let spin: Double
    func body(content: Content) -> some View {
        content.rotation3DEffect(.degrees(spin), axis: (x: 0, y: 1, z: 0), perspective: 0.6)
    }
}

// MARK: - Decorative ring + edge
private struct OuterRing: View {
    var body: some View {
        Circle()
            .fill(LinearGradient(colors: [Color.white.opacity(0.10), Color.black.opacity(0.25)],
                                 startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay(Circle().strokeBorder(Color.white.opacity(0.15), lineWidth: 1))
            .overlay(Circle().strokeBorder(Color.black.opacity(0.25), lineWidth: 2))
            .blur(radius: 0.2)
    }
}

private struct Rim: View {
    var body: some View {
        Circle()
            .strokeBorder(AngularGradient(
                gradient: Gradient(colors: [
                    Color.white.opacity(0.55),
                    Color.black.opacity(0.45),
                    Color.white.opacity(0.35),
                    Color.black.opacity(0.6)
                ]),
                center: .center
            ), lineWidth: 6)
            .overlay(Circle().stroke(Color.black.opacity(0.08), lineWidth: 1))
            .overlay(Circle().stroke(Color.white.opacity(0.10), lineWidth: 3).blur(radius: 1))
            .allowsHitTesting(false)
    }
}

private struct EdgeBand: View {
    var thickness: CGFloat = 8
    var ribs: Int = 72
    var body: some View {
        ZStack {
            Circle().inset(by: thickness/2).stroke(
                LinearGradient(colors: [Color.black.opacity(0.6),
                                        Color.black.opacity(0.3),
                                        Color.white.opacity(0.22),
                                        Color.black.opacity(0.5)],
                               startPoint: .top, endPoint: .bottom),
                lineWidth: thickness
            )
            Circle().inset(by: thickness/2).stroke(
                AngularGradient(gradient: Gradient(colors: (0..<ribs).map { i in
                    (i % 2 == 0) ? Color.white.opacity(0.14) : Color.black.opacity(0.18)
                }), center: .center),
                lineWidth: thickness * 0.55
            )
            .opacity(0.7).blendMode(.overlay)
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Helpers
fileprivate extension CATransform3D {
    static func withPerspective(_ p: CGFloat) -> CATransform3D {
        var t = CATransform3DIdentity
        t.m34 = -1.0 / max(p * 500, 1)
        return t
    }
}
