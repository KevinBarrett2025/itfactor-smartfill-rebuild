import SwiftUI

struct ContentView: View {
    let repo: ProjectsRepository
    @State private var profileManager = ActorProfileManager()
    @State private var showProfileWizard = false
    
    var body: some View {
        Group {
            if profileManager.isProfileComplete {
                HomeScreenView(repo: repo)
            } else {
                Color.clear
                    .onAppear {
                        showProfileWizard = true
                    }
            }
        }
        .fullScreenCover(isPresented: $showProfileWizard) {
            ActorProfileWizard(
                startingProfile: profileManager.profile,
                profileManager: profileManager,
                onComplete: {
                showProfileWizard = false
                profileManager = ActorProfileManager() // Reload to get updated status
            })
        }
    }
}

#Preview {
    ContentView(repo: ProjectsRepositoryFactory.makePreviewRepository())
        .environmentObject(ThemeManager())
}
