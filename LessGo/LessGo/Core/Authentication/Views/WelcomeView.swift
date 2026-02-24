import SwiftUI
import UIKit

struct WelcomeView: View {
    @State private var logoOffset: CGFloat = 40
    @State private var logoOpacity: Double = 0
    @State private var buttonsOffset: CGFloat = 60
    @State private var buttonsOpacity: Double = 0
    @State private var taglineOpacity: Double = 0
    @State private var patternOpacity: Double = 0

    // Gold pulsing ring animation
    @State private var glowScale: CGFloat = 1.0
    @State private var glowOpacity: Double = 0.4

    @State private var showLogin  = false
    @State private var showSignUp = false

    var body: some View {
        ZStack {
            Color(hex: "F5F7F2").ignoresSafeArea()

            GeometryReader { geo in
                ZStack {
                    Circle()
                        .fill(Color(hex: "A3E635").opacity(0.20))
                        .frame(width: geo.size.width * 1.05)
                        .offset(x: geo.size.width * 0.45, y: geo.size.height * 0.72)

                    Circle()
                        .fill(Color.black.opacity(0.03))
                        .frame(width: geo.size.width * 1.15)
                        .offset(x: geo.size.width * 0.55, y: -geo.size.height * 0.22)

                    RoundedRectangle(cornerRadius: 120, style: .continuous)
                        .fill(Color.brand.opacity(0.05))
                        .frame(width: geo.size.width * 0.95, height: geo.size.height * 0.42)
                        .offset(x: geo.size.width * 0.38, y: geo.size.height * 0.30)
                        .rotationEffect(.degrees(-18))
                }
            }
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // ── Logo + SJSU Branding ──
                VStack(spacing: 20) {
                    // Icon with ring animation
                    ZStack {
                        Circle()
                            .stroke(Color(hex: "A3E635").opacity(glowOpacity), lineWidth: 2)
                            .frame(width: 120, height: 120)
                            .scaleEffect(glowScale)

                        RoundedRectangle(cornerRadius: 28)
                            .fill(Color.white)
                            .frame(width: 100, height: 100)
                            .overlay(
                                RoundedRectangle(cornerRadius: 28)
                                    .strokeBorder(Color.black.opacity(0.08), lineWidth: 1)
                            )
                            .shadow(color: .black.opacity(0.10), radius: 20, x: 0, y: 10)

                        Image(systemName: "car.2.fill")
                            .font(.system(size: 44))
                            .foregroundColor(.black.opacity(0.85))
                    }

                    VStack(spacing: 12) {
                        Text("LessGo")
                            .font(.system(size: 54, weight: .black, design: .rounded))
                            .foregroundColor(.black.opacity(0.9))

                        Text("Carpooling Made Easy\nfor Spartans")
                            .font(.system(size: 19, weight: .semibold))
                            .foregroundColor(.black.opacity(0.75))
                            .multilineTextAlignment(.center)
                            .lineSpacing(6)
                            .opacity(taglineOpacity)

                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 12))
                            Text("Official SJSU Student Platform")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundColor(Color(hex: "6B7280"))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.85))
                        .overlay(
                            Capsule().strokeBorder(Color.black.opacity(0.06), lineWidth: 1)
                        )
                        .cornerRadius(12)
                        .opacity(taglineOpacity)
                    }
                }
                .offset(y: logoOffset)
                .opacity(logoOpacity)

                Spacer()

                // ── Stats Row ──
                HStack(spacing: 0) {
                    StatPill(value: "3,200+", label: "Rides", icon: "car.fill")
                        .staggeredAppear(index: 0)
                    Divider().frame(height: 36).overlay(Color.black.opacity(0.08))
                    StatPill(value: "100%", label: "SJSU", icon: "checkmark.shield.fill")
                        .staggeredAppear(index: 1)
                    Divider().frame(height: 36).overlay(Color.black.opacity(0.08))
                    StatPill(value: "4.9★", label: "Rated", icon: "star.fill")
                        .staggeredAppear(index: 2)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(
                    Color.white
                        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Color.black.opacity(0.06), lineWidth: 1))
                )
                .cornerRadius(20)
                .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 4)
                .padding(.horizontal, 28)
                .opacity(buttonsOpacity)

                Spacer().frame(height: 36)

                // ── Action Buttons ──
                VStack(spacing: 14) {
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
                        .frame(height: DesignSystem.Layout.buttonHeightLarge)
                        .background(Color(hex: "A3E635"))
                        .foregroundColor(.black.opacity(0.88))
                        .cornerRadius(28)
                        .shadow(color: Color(hex: "A3E635").opacity(0.35), radius: 18, x: 0, y: 10)
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
                            .background(Color.black.opacity(0.85))
                            .foregroundColor(.white)
                            .cornerRadius(26)
                    }
                }
                .padding(.horizontal, 28)
                .offset(y: buttonsOffset)
                .opacity(buttonsOpacity)

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
                    .foregroundColor(.black.opacity(0.58))

                    Text("Powered by SJSU Students")
                        .font(.system(size: 12))
                        .foregroundColor(.black.opacity(0.42))
                }
                .padding(.top, 24)
                .padding(.bottom, 40)
                .opacity(buttonsOpacity)
            }
        }
        .onAppear {
            animate()
            // Start pulsing ring animation
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                glowScale = 1.15
                glowOpacity = 0.0
            }
        }
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
                .foregroundColor(Color(hex: "84CC16"))
            Text(value)
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(.black.opacity(0.88))
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.black.opacity(0.52))
        }
        .frame(maxWidth: .infinity)
    }
}
