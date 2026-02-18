import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @State private var isCheckingAuth = true

    var body: some View {
        ZStack {
            if isCheckingAuth {
                // ── Splash Screen ──
                SplashScreen()
                    .transition(.opacity)
            } else if authVM.isAuthenticated {
                // ── Main App ──
                HomeView()
                    .environmentObject(authVM)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal: .opacity
                    ))
            } else {
                // ── Onboarding ──
                WelcomeView()
                    .environmentObject(authVM)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: isCheckingAuth)
        .animation(.easeInOut(duration: 0.35), value: authVM.isAuthenticated)
        .task {
            // Brief delay to show splash then check auth
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            withAnimation { isCheckingAuth = false }
        }
    }
}

// MARK: - Splash Screen

struct SplashScreen: View {
    @State private var scale: CGFloat = 0.7
    @State private var opacity: Double = 0

    var body: some View {
        ZStack {
            Color.heroGradient.ignoresSafeArea()

            VStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 28)
                        .fill(.ultraThinMaterial)
                        .frame(width: 100, height: 100)
                        .overlay(
                            RoundedRectangle(cornerRadius: 28)
                                .strokeBorder(Color.white.opacity(0.3), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)

                    Image(systemName: "car.2.fill")
                        .font(.system(size: 44))
                        .foregroundColor(.white)
                }

                Text("LessGo")
                    .font(.system(size: 42, weight: .heavy))
                    .foregroundColor(.white)
            }
            .scaleEffect(scale)
            .opacity(opacity)
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                scale = 1
                opacity = 1
            }
        }
    }
}
