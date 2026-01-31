import SwiftUI

extension Binding {
    init?(unwrapping source: Binding<Value?>) {
        guard let initialValue = source.wrappedValue else { return nil }
        self.init(
            get: { source.wrappedValue ?? initialValue },
            set: { newValue in
                source.wrappedValue = newValue
            }
        )
    }
}
