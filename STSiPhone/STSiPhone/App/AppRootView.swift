import SwiftUI

struct AppRootView: View {
    let repo: ProjectsRepository
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var showSplash = true
    
    var body: some View {
        ZStack {
            OnboardingCoordinator(repo: repo)
                .zIndex(0)
            
            if showSplash {
                ThemedSplashView(theme: themeManager.current)
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .task {
            guard showSplash else { return }
            try? await Task.sleep(for: .milliseconds(650))
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.35)) {
                    showSplash = false
                }
            }
        }
    }
}

