import SwiftUI

extension View {
    func captureGlobalFrame(_ rect: Binding<CGRect>) -> some View {
        background(
            GeometryReader { geo in
                Color.clear
                    .onAppear { rect.wrappedValue = geo.frame(in: .global) }
                    .onChange(of: geo.frame(in: .global), initial: false) { _, newValue in rect.wrappedValue = newValue }
            }
        )
    }
}
