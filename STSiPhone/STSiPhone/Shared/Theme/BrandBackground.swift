import SwiftUI

struct BrandBackground: View {
    var body: some View {
        LinearGradient(
            gradient: Gradient(colors: [
                Color(red: 0.19, green: 0.05, blue: 0.25), // deep magenta-purple
                Color(red: 0.11, green: 0.11, blue: 0.27), // navy blue
                Color(red: 0.07, green: 0.08, blue: 0.17)  // almost-black
            ]),
            startPoint: .top,
            endPoint: .bottom
        )
    }
}
