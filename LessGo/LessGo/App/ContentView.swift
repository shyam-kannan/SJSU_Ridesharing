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
    @State private var scale: CGFloat = 0.65
    @State private var opacity: Double = 0
    @State private var taglineOpacity: Double = 0
    @State private var ringScale: CGFloat = 0.8
    @State private var ringOpacity: Double = 0.7

    var body: some View {
        ZStack {
            Color.heroGradient.ignoresSafeArea()

            // Subtle background circles for depth
            Circle()
                .fill(DesignSystem.Colors.sjsuGold.opacity(0.08))
                .frame(width: 380)
                .offset(x: 120, y: -180)
                .ignoresSafeArea()

            Circle()
                .fill(Color.white.opacity(0.04))
                .frame(width: 280)
                .offset(x: -130, y: 200)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                ZStack {
                    // Pulsing gold ring
                    Circle()
                        .stroke(DesignSystem.Colors.sjsuGold.opacity(ringOpacity), lineWidth: 2)
                        .frame(width: 128, height: 128)
                        .scaleEffect(ringScale)

                    // Logo card
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .frame(width: 104, height: 104)
                        .overlay(
                            RoundedRectangle(cornerRadius: 30, style: .continuous)
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [DesignSystem.Colors.sjsuGold.opacity(0.6), Color.white.opacity(0.2)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1.5
                                )
                        )
                        .shadow(color: .black.opacity(0.25), radius: 24, x: 0, y: 12)

                    Image(systemName: "car.2.fill")
                        .font(.system(size: 46))
                        .foregroundColor(.white)
                }

                VStack(spacing: 8) {
                    Text("LessGo")
                        .font(.system(size: 46, weight: .black, design: .rounded))
                        .foregroundColor(.white)

                    Text("SJSU Ridesharing")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.75))
                        .opacity(taglineOpacity)
                }
            }
            .scaleEffect(scale)
            .opacity(opacity)
        }
        .onAppear {
            withAnimation(DesignSystem.Animation.heroEntrance) {
                scale = 1
                opacity = 1
            }
            withAnimation(.easeInOut(duration: 0.5).delay(0.35)) {
                taglineOpacity = 1
            }
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true).delay(0.4)) {
                ringScale = 1.18
                ringOpacity = 0.0
            }
        }
    }
}
