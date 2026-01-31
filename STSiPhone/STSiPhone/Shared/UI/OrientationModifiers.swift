import SwiftUI
import UIKit

private struct OrientationLockingModifier: ViewModifier {
    let mask: UIInterfaceOrientationMask
    let label: String
    @State private var token: UUID?

    func body(content: Content) -> some View {
        content
            .onAppear {
                if token == nil {
                    token = OrientationLock.shared.acquire(mask, label: label)
                }
            }
            .onDisappear {
                if let token {
                    OrientationLock.shared.release(token)
                    self.token = nil
                }
            }
    }
}

extension View {
    func stsSupportedOrientations(_ mask: UIInterfaceOrientationMask, label: String? = nil) -> some View {
        let resolvedLabel = label ?? "UnnamedView"
        return modifier(OrientationLockingModifier(mask: mask, label: resolvedLabel))
    }

    func stsPortraitOnly(label: String? = nil) -> some View {
        stsSupportedOrientations(.portrait, label: label)
    }
}
