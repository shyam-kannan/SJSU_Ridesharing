import SwiftUI
import UIKit

struct WelcomeView: View {
    @State private var logoOffset: CGFloat = 40
    @State private var logoOpacity: Double = 0
    @State private var buttonsOffset: CGFloat = 60
    @State private var buttonsOpacity: Double = 0
    @State private var taglineOpacity: Double = 0
    @State private var patternOpacity: Double = 0

    @State private var showLogin  = false
    @State private var showSignUp = false

    var body: some View {
        ZStack {
            // SJSU Gradient background
            Color.heroGradient
                .ignoresSafeArea()

            // SJSU Pattern overlay with subtle tower silhouette
            GeometryReader { geo in
                ZStack {
                    // Gold accent circles
                    Circle()
                        .fill(DesignSystem.Colors.sjsuGold.opacity(0.08))
                        .frame(width: geo.size.width * 1.2)
                        .offset(x: geo.size.width * 0.3, y: -geo.size.height * 0.1)

                    Circle()
                        .fill(Color.white.opacity(0.05))
                        .frame(width: geo.size.width * 0.9)
                        .offset(x: -geo.size.width * 0.3, y: geo.size.height * 0.5)

                    // SJSU Tower silhouette (subtle)
                    Image(systemName: "building.2.fill")
                        .font(.system(size: 200))
                        .foregroundColor(Color.white.opacity(0.03))
                        .offset(x: geo.size.width * 0.5, y: geo.size.height * 0.3)
                        .opacity(patternOpacity)
                }
            }
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // ── Logo + SJSU Branding ──
                VStack(spacing: 20) {
                    // Icon with SJSU-themed glassmorphism card
                    ZStack {
                        RoundedRectangle(cornerRadius: 28)
                            .fill(.ultraThinMaterial)
                            .frame(width: 100, height: 100)
                            .overlay(
                                RoundedRectangle(cornerRadius: 28)
                                    .strokeBorder(DesignSystem.Colors.sjsuGold.opacity(0.4), lineWidth: 2)
                            )
                            .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)

                        Image(systemName: "car.2.fill")
                            .font(.system(size: 44))
                            .foregroundColor(.white)
                    }

                    VStack(spacing: 12) {
                        Text("LessGo")
                            .font(.system(size: 52, weight: .heavy))
                            .foregroundColor(.white)

                        // SJSU Tagline
                        Text("Carpooling Made Easy\nfor Spartans")
                            .font(.system(size: 19, weight: .semibold))
                            .foregroundColor(.white.opacity(0.95))
                            .multilineTextAlignment(.center)
                            .lineSpacing(6)
                            .opacity(taglineOpacity)

                        // Subtle SJSU badge
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 12))
                            Text("Official SJSU Student Platform")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundColor(DesignSystem.Colors.sjsuGold)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(DesignSystem.Colors.sjsuGold.opacity(0.15))
                        .cornerRadius(12)
                        .opacity(taglineOpacity)
                    }
                }
                .offset(y: logoOffset)
                .opacity(logoOpacity)

                Spacer()

                // ── SJSU Stats Row ──
                HStack(spacing: 0) {
                    StatPill(value: "3,200+", label: "Rides", icon: "car.fill")
                    Divider().frame(height: 36).overlay(DesignSystem.Colors.sjsuGold.opacity(0.3))
                    StatPill(value: "100%", label: "SJSU", icon: "checkmark.shield.fill")
                    Divider().frame(height: 36).overlay(DesignSystem.Colors.sjsuGold.opacity(0.3))
                    StatPill(value: "4.9★", label: "Rated", icon: "star.fill")
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(
                    DesignSystem.Colors.sjsuGold.opacity(0.12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .strokeBorder(DesignSystem.Colors.sjsuGold.opacity(0.3), lineWidth: 1.5)
                        )
                )
                .cornerRadius(20)
                .shadow(color: DesignSystem.Colors.sjsuGold.opacity(0.1), radius: 12, x: 0, y: 4)
                .padding(.horizontal, 28)
                .opacity(buttonsOpacity)

                Spacer().frame(height: 36)

                // ── Action Buttons ──
                VStack(spacing: 14) {
                    // Get Started button with SJSU Gold
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        showSignUp = true
                    }) {
                        HStack(spacing: 8) {
                            Text("Get Started")
                                .font(DesignSystem.Typography.button)
                            Image(systemName: "arrow.right")
                                .font(.system(size: 16, weight: .bold))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: DesignSystem.Layout.buttonHeight)
                        .background(DesignSystem.Colors.sjsuGold)
                        .foregroundColor(.white)
                        .cornerRadius(28)
                        .shadow(color: DesignSystem.Colors.sjsuGold.opacity(0.3), radius: 15, x: 0, y: 8)
                    }

                    // Login button
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        showLogin = true
                    }) {
                        Text("I already have an account")
                            .font(.system(size: 16, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(Color.white.opacity(0.08))
                            .foregroundColor(.white)
                            .cornerRadius(26)
                            .overlay(
                                RoundedRectangle(cornerRadius: 26)
                                    .strokeBorder(Color.white.opacity(0.3), lineWidth: 1.5)
                            )
                    }
                }
                .padding(.horizontal, 28)
                .offset(y: buttonsOffset)
                .opacity(buttonsOpacity)

                // Footer with SJSU branding
                VStack(spacing: 8) {
                    HStack(spacing: 12) {
                        Image(systemName: "shield.checkered")
                            .font(.system(size: 12))
                        Text("Verified SJSU Students Only")
                            .font(.system(size: 13, weight: .medium))
                        Image(systemName: "lock.shield")
                            .font(.system(size: 12))
                        Text("Safe & Secure")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundColor(.white.opacity(0.7))

                    Text("🎓 Powered by SJSU Students")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.5))
                }
                .padding(.top, 24)
                .padding(.bottom, 40)
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
        withAnimation(.easeInOut(duration: 0.8).delay(0.3)) {
            patternOpacity = 1
        }
        withAnimation(.easeInOut(duration: 0.6).delay(0.5)) {
            taglineOpacity = 1
        }
        withAnimation(.spring(response: 0.7, dampingFraction: 0.75).delay(0.5)) {
            buttonsOffset  = 0
            buttonsOpacity = 1
        }
    }
}

// MARK: - SJSU Stat Pill

private struct StatPill: View {
    let value: String
    let label: String
    let icon: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(DesignSystem.Colors.sjsuGold)
            Text(value)
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(.white)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.75))
        }
        .frame(maxWidth: .infinity)
    }
}
