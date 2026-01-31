import SwiftUI
import AuthenticationServices

enum OnboardingStep: Equatable {
    case signIn
    case profile
    case tour
    case completed
}

struct OnboardingState {
    private let defaults = UserDefaults.standard
    private let signInKey = "Onboarding.SignInCompleted"
    private let userIDKey = "Onboarding.AppleUserIdentifier"
    private let fullNameKey = "Onboarding.LastKnownFullName"
    private let emailKey = "Onboarding.LastKnownEmail"
    private let tourKey = "Onboarding.ProductTourCompleted"
    
    var step: OnboardingStep = .signIn
    
    init(profileManager: ActorProfileManager) {
        sync(profileManager: profileManager)
    }
    
    mutating func sync(profileManager: ActorProfileManager) {
        let signedIn = defaults.bool(forKey: signInKey)
        let profileComplete = profileManager.isProfileComplete
        let tourComplete = defaults.bool(forKey: tourKey)
        
        if !signedIn {
            step = .signIn
        } else if !profileComplete {
            step = .profile
        } else if !tourComplete {
            step = .tour
        } else {
            step = .completed
        }
    }
    
    mutating func markSignedIn(userIdentifier: String?, fullName: String?, email: String?) {
        defaults.set(true, forKey: signInKey)
        
        if let userIdentifier, !userIdentifier.isEmpty {
            defaults.set(userIdentifier, forKey: userIDKey)
        }
        
        if let fullName, !fullName.isEmpty {
            defaults.set(fullName, forKey: fullNameKey)
        }
        
        if let email, !email.isEmpty {
            defaults.set(email, forKey: emailKey)
        }
    }
    
    mutating func markTourComplete() {
        defaults.set(true, forKey: tourKey)
        step = .completed
    }
    
    func storedFullName() -> String? {
        defaults.string(forKey: fullNameKey)
    }
    
    func storedEmail() -> String? {
        defaults.string(forKey: emailKey)
    }
}

struct OnboardingSignInData {
    let profile: ActorProfile
    let userIdentifier: String?
    let fullName: String?
    let email: String?
}

struct OnboardingCoordinator: View {
    let repo: ProjectsRepository
    
    @State private var profileManager: ActorProfileManager
    @State private var onboardingState: OnboardingState
    @State private var profilePrefill: ActorProfile?
    @State private var signInError: String?
    
    init(repo: ProjectsRepository) {
        self.repo = repo
        let manager = ActorProfileManager()
        _profileManager = State(initialValue: manager)
        _onboardingState = State(initialValue: OnboardingState(profileManager: manager))
        _profilePrefill = State(initialValue: nil)
        _signInError = State(initialValue: nil)
    }
    
    var body: some View {
        Group {
            switch onboardingState.step {
            case .signIn:
                OnboardingSignInView(
                    errorMessage: $signInError,
                    storedName: onboardingState.storedFullName(),
                    storedEmail: onboardingState.storedEmail(),
                    onSignedIn: handleSignInSuccess,
                    onSkip: handleSignInSkip
                )
            case .profile:
                ActorProfileWizard(
                    startingProfile: profilePrefill ?? profileManager.profile,
                    profileManager: profileManager,
                    onComplete: handleProfileComplete
                )
            case .tour:
                ProductTourView(
                    onFinish: handleTourFinished,
                    onSkip: handleTourFinished
                )
            case .completed:
                HomeScreenView(repo: repo)
            }
        }
        .onAppear {
            onboardingState.sync(profileManager: profileManager)
        }
    }
    
    private func handleSignInSuccess(_ data: OnboardingSignInData) {
        signInError = nil
        onboardingState.markSignedIn(
            userIdentifier: data.userIdentifier,
            fullName: data.fullName,
            email: data.email
        )
        
        var updatedProfile = profileManager.profile
        if updatedProfile.name.isEmpty, !data.profile.name.isEmpty {
            updatedProfile.name = data.profile.name
        }
        if updatedProfile.email.isEmpty, !data.profile.email.isEmpty {
            updatedProfile.email = data.profile.email
        }
        profilePrefill = updatedProfile
        
        onboardingState.sync(profileManager: profileManager)
    }
    
    private func handleSignInSkip() {
        signInError = nil
        onboardingState.step = .profile
    }
    
    private func handleProfileComplete() {
        profileManager = ActorProfileManager()
        profilePrefill = nil
        onboardingState.sync(profileManager: profileManager)
    }
    
    private func handleTourFinished() {
        onboardingState.markTourComplete()
        onboardingState.sync(profileManager: profileManager)
    }
}

struct OnboardingSignInView: View {
    @Binding var errorMessage: String?
    let storedName: String?
    let storedEmail: String?
    let onSignedIn: (OnboardingSignInData) -> Void
    let onSkip: () -> Void
    
    var body: some View {
        NavigationStack {
            ZStack {
                BrandBackground()
                    .ignoresSafeArea()
                
                VStack(spacing: 28) {
                    Spacer(minLength: 32)
                    
                    Image("AppLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 180, height: 180)
                        .shadow(radius: 10)
                    
                    VStack(spacing: 12) {
                        Text("Welcome to Self Tape Studio")
                            .font(Theme.Font.title)
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                        
                        Text("Sign in to unlock your ActorKit, personalized sessions, and secure profile syncing.")
                            .font(Theme.Font.body)
                            .foregroundStyle(.white.opacity(0.75))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 24)
                    
                    VStack(spacing: 16) {
                        SignInWithAppleButton(.continue) { request in
                            request.requestedScopes = [.fullName, .email]
                        } onCompletion: { result in
                            switch result {
                            case .success(let auth):
                                guard let credential = auth.credential as? ASAuthorizationAppleIDCredential else {
                                    errorMessage = "Unable to complete Sign in with Apple. Please try again."
                                    return
                                }
                                
                                let resolvedName = formattedName(from: credential.fullName) ?? storedName ?? ""
                                let resolvedEmail = credential.email ?? storedEmail ?? ""
                                
                                var profile = ActorProfile()
                                profile.name = resolvedName
                                profile.email = resolvedEmail
                                
                                let data = OnboardingSignInData(
                                    profile: profile,
                                    userIdentifier: credential.user,
                                    fullName: resolvedName.isEmpty ? storedName : resolvedName,
                                    email: resolvedEmail.isEmpty ? storedEmail : resolvedEmail
                                )
                                
                                errorMessage = nil
                                onSignedIn(data)
                                
                            case .failure(let error):
                                errorMessage = friendlyMessage(for: error)
                            }
                        }
                        .frame(height: 52)
                        .clipShape(Capsule())
                        .padding(.horizontal, 24)
                        .signInWithAppleButtonStyle(.whiteOutline)
                        
                        if let storedName, !storedName.isEmpty {
                            Text("Signed in before as \(storedName)")
                                .font(Theme.Font.caption)
                                .foregroundStyle(.white.opacity(0.6))
                        }
                    }
                    
                    if let errorMessage, !errorMessage.isEmpty {
                        Text(errorMessage)
                            .font(Theme.Font.caption)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                    
                    VStack(spacing: 12) {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "person.crop.circle.badge.plus")
                                .foregroundStyle(Theme.primary)
                                .font(.title3)
                            Text("Capture your Actor Profile once to personalize your ActorKit across the app.")
                                .font(Theme.Font.caption)
                                .foregroundStyle(.white.opacity(0.7))
                        }
                        
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "sparkles.rectangle.stack")
                                .foregroundStyle(Theme.primary)
                                .font(.title3)
                            Text("Short tour shows you how to reach sessions, ActorKit, and industry resources fast.")
                                .font(Theme.Font.caption)
                                .foregroundStyle(.white.opacity(0.7))
                        }
                    }
                    .padding(.horizontal, 24)
                    
                    BrandedSecondaryButton(label: "Set up manually") {
                        onSkip()
                    }
                    .padding(.horizontal, 24)
                    
                    Spacer()
                }
                .padding(.bottom, 32)
            }
        }
    }
    
    private func formattedName(from components: PersonNameComponents?) -> String? {
        guard let components else { return nil }
        return components.formatted(.name(style: .long))
    }
    
    private func friendlyMessage(for error: Error) -> String {
        if let authorizationError = error as? ASAuthorizationError {
            switch authorizationError.code {
            case .canceled:
                return ""
            case .unknown:
                return "Sign in with Apple isn't available in this build or environment. You can continue with \"Set up manually\" and link your Apple ID later."
            case .invalidResponse, .notHandled:
                return "Sign in with Apple returned an unexpected response. Please try again or continue with manual setup."
            case .failed:
                return "Sign in with Apple failed. Check your Apple ID settings and try again."
            case .notInteractive, .matchedExcludedCredential, .credentialImport, .credentialExport, .preferSignInWithApple, .deviceNotConfiguredForPasskeyCreation:
                return "Sign in with Apple isn't available right now. Please continue with \"Set up manually\" and try linking later."
            @unknown default:
                return "Sign in with Apple encountered an unknown issue. Try again or continue manually."
            }
        }
        
        let nsError = error as NSError
        if nsError.domain == ASAuthorizationError.errorDomain {
            return "Sign in with Apple reported error \(nsError.code). Try again or continue manually."
        }
        
        return "We couldn't complete Sign in with Apple. Please try again or choose \"Set up manually\"."
    }
}

struct ProductTourView: View {
    let onFinish: () -> Void
    let onSkip: () -> Void
    
    @State private var currentPage = 0
    
    private let pages: [ProductTourPage] = [
        ProductTourPage(
            title: "Command Center",
            subtitle: "Manage projects, sessions, and deliverables from one branded hub.",
            icon: "rectangle.grid.2x2.fill",
            accentColor: Color.blue
        ),
        ProductTourPage(
            title: "ActorKit",
            subtitle: "Your headshots, reps, and must-know references are one tap away.",
            icon: "person.crop.circle.fill.badge.checkmark",
            accentColor: Color.purple
        ),
        ProductTourPage(
            title: "Session Flow",
            subtitle: "Guided checklists and Smart Fill tools help you nail every self tape.",
            icon: "video.fill.badge.checkmark",
            accentColor: Color.green
        )
    ]
    
    var body: some View {
        NavigationStack {
            ZStack {
                BrandBackground()
                    .ignoresSafeArea()
                
                VStack(spacing: 24) {
                    HStack {
                        Spacer()
                        Button("Skip") {
                            onSkip()
                        }
                        .foregroundStyle(.white.opacity(0.7))
                        .font(Theme.Font.body)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    
                    TabView(selection: $currentPage) {
                        ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                            VStack(spacing: 24) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 24)
                                        .fill(page.accentColor.opacity(0.2))
                                        .frame(height: 220)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 24)
                                                .stroke(page.accentColor.opacity(0.5), lineWidth: 1.5)
                                        )
                                    
                                    Image(systemName: page.icon)
                                        .font(.system(size: 72, weight: .medium))
                                        .foregroundStyle(.white)
                                        .shadow(radius: 6)
                                }
                                
                                VStack(spacing: 12) {
                                    Text(page.title)
                                        .font(Theme.Font.title)
                                        .foregroundStyle(.white)
                                    
                                    Text(page.subtitle)
                                        .font(Theme.Font.body)
                                        .foregroundStyle(.white.opacity(0.75))
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal, 24)
                                }
                            }
                            .tag(index)
                        }
                    }
                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                    .frame(height: 360)
                    
                    HStack(spacing: 8) {
                        ForEach(pages.indices, id: \.self) { index in
                            Circle()
                                .fill(index == currentPage ? Theme.primary : .white.opacity(0.3))
                                .frame(width: index == currentPage ? 12 : 8, height: index == currentPage ? 12 : 8)
                                .animation(.easeInOut(duration: 0.2), value: currentPage)
                        }
                    }
                    
                    BrandedPrimaryButton(
                        label: currentPage == pages.count - 1 ? "Finish Tour" : "Next",
                        icon: currentPage == pages.count - 1 ? "checkmark.circle.fill" : "arrow.right"
                    ) {
                        if currentPage < pages.count - 1 {
                            withAnimation(.easeInOut) {
                                currentPage += 1
                            }
                        } else {
                            onFinish()
                        }
                    }
                    .padding(.horizontal, 24)
                    
                    Spacer()
                }
            }
        }
    }
}

private struct ProductTourPage {
    let title: String
    let subtitle: String
    let icon: String
    let accentColor: Color
}
