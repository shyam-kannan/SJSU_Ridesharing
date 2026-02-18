import SwiftUI
import UIKit

struct WelcomeView: View {
    @State private var logoOffset: CGFloat = 40
    @State private var logoOpacity: Double = 0
    @State private var buttonsOffset: CGFloat = 60
    @State private var buttonsOpacity: Double = 0
    @State private var taglineOpacity: Double = 0

    @State private var showLogin  = false
    @State private var showSignUp = false

    var body: some View {
        ZStack {
            // Gradient background
            Color.heroGradient
                .ignoresSafeArea()

            // Subtle pattern overlay
            GeometryReader { geo in
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.06))
                        .frame(width: geo.size.width * 1.2)
                        .offset(x: geo.size.width * 0.3, y: -geo.size.height * 0.1)

                    Circle()
                        .fill(Color.white.opacity(0.04))
                        .frame(width: geo.size.width * 0.9)
                        .offset(x: -geo.size.width * 0.3, y: geo.size.height * 0.5)
                }
            }
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // ── Logo + Branding ──
                VStack(spacing: 20) {
                    // Icon with glassmorphism card
                    ZStack {
                        RoundedRectangle(cornerRadius: 28)
                            .fill(.ultraThinMaterial)
                            .frame(width: 100, height: 100)
                            .overlay(
                                RoundedRectangle(cornerRadius: 28)
                                    .strokeBorder(Color.white.opacity(0.35), lineWidth: 1)
                            )
                            .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)

                        Image(systemName: "car.2.fill")
                            .font(.system(size: 44))
                            .foregroundColor(.white)
                    }

                    VStack(spacing: 10) {
                        Text("LessGo")
                            .font(.system(size: 50, weight: .heavy))
                            .foregroundColor(.white)

                        Text("Your Campus Carpool\nConnection")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white.opacity(0.85))
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                            .opacity(taglineOpacity)
                    }
                }
                .offset(y: logoOffset)
                .opacity(logoOpacity)

                Spacer()

                // ── Stats Row ──
                HStack(spacing: 0) {
                    StatPill(value: "2,400+", label: "Rides")
                    Divider().frame(height: 30).overlay(Color.white.opacity(0.3))
                    StatPill(value: "SJSU", label: "Verified")
                    Divider().frame(height: 30).overlay(Color.white.opacity(0.3))
                    StatPill(value: "4.9★", label: "Rating")
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .background(Color.white.opacity(0.12))
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(Color.white.opacity(0.25), lineWidth: 1)
                )
                .padding(.horizontal, 32)
                .opacity(buttonsOpacity)

                Spacer().frame(height: 32)

                // ── Action Buttons ──
                VStack(spacing: 14) {
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        showSignUp = true
                    }) {
                        Text("Get Started")
                            .font(.system(size: 18, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color.white)
                            .foregroundColor(.brand)
                            .cornerRadius(28)
                            .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 6)
                    }

                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        showLogin = true
                    }) {
                        Text("I already have an account")
                            .font(.system(size: 16, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(Color.clear)
                            .foregroundColor(.white)
                            .overlay(
                                RoundedRectangle(cornerRadius: 26)
                                    .strokeBorder(Color.white.opacity(0.5), lineWidth: 1.5)
                            )
                    }
                }
                .padding(.horizontal, 28)
                .offset(y: buttonsOffset)
                .opacity(buttonsOpacity)

                // Footer
                Text("For SJSU students only · Verified rides")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.5))
                    .padding(.top, 20)
                    .padding(.bottom, 36)
                    .opacity(buttonsOpacity)
            }
        }
        .onAppear { animate() }
        .fullScreenCover(isPresented: $showLogin)  { LoginView() }
        .fullScreenCover(isPresented: $showSignUp) { SignUpView() }
    }

    private func animate() {
        withAnimation(.spring(response: 0.7, dampingFraction: 0.75).delay(0.15)) {
            logoOffset  = 0
            logoOpacity = 1
        }
        withAnimation(.easeInOut(duration: 0.5).delay(0.5)) {
            taglineOpacity = 1
        }
        withAnimation(.spring(response: 0.7, dampingFraction: 0.75).delay(0.4)) {
            buttonsOffset  = 0
            buttonsOpacity = 1
        }
    }
}

// MARK: - Stat Pill

private struct StatPill: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
    }
}
