import SwiftUI

struct ThemedSplashView: View {
    let theme: STSTheme
    
    var body: some View {
        ZStack {
            theme.backgroundGradient
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                Spacer()
                
                Image("AppLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 180, height: 180)
                    .shadow(color: .black.opacity(0.4), radius: 18, x: 0, y: 12)
                
                Text("Self Tape Studio")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(theme.textPrimary)
                
                Spacer()
                
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(theme.primaryAccent)
                    .padding(.bottom, 60)
            }
            .padding(.horizontal, 32)
        }
    }
}

