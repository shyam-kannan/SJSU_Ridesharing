import SwiftUI
import UIKit

struct LoginView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var email    = ""
    @State private var password = ""
    @State private var showSignUp = false

    // Field-level errors
    @State private var emailError: String?
    @State private var passwordError: String?

    // Keyboard focus
    @FocusState private var focusedField: Field?
    enum Field { case email, password }

    // Animated shimmer on hero gradient
    @State private var shimmerOffset: CGFloat = -200

    private var canLogin: Bool { !email.isEmpty && !password.isEmpty && !authVM.isLoading }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {

                    // ── Header ──
                    headerHero
                    .padding(.top, 14)
                    .padding(.horizontal, AppConstants.pagePadding)

                    HStack(spacing: 8) {
                        loginTrustChip("Verified SJSU", icon: "checkmark.seal.fill")
                        loginTrustChip("Saved Accounts", icon: "person.crop.circle.badge.checkmark")
                        loginTrustChip("Secure", icon: "lock.shield.fill")
                    }
                    .padding(.top, 12)
                    .padding(.horizontal, AppConstants.pagePadding)

                    if !authVM.savedLoginProfiles.isEmpty {
                        savedAccountsSection
                            .padding(.top, 20)
                    }

                    // ── Form ──
                    VStack(spacing: 16) {
                        LabeledTextField(
                            label: "Email",
                            placeholder: "your@sjsu.edu",
                            text: $email,
                            icon: "envelope",
                            keyboardType: .emailAddress,
                            errorMessage: emailError
                        )
                        .focused($focusedField, equals: .email)
                        .onChange(of: email) { _ in emailError = nil }
                        .submitLabel(.next)
                        .onSubmit { focusedField = .password }

                        LabeledTextField(
                            label: "Password",
                            placeholder: "Enter password",
                            text: $password,
                            isSecure: true,
                            icon: "lock",
                            errorMessage: passwordError
                        )
                        .focused($focusedField, equals: .password)
                        .onChange(of: password) { _ in passwordError = nil }
                        .submitLabel(.go)
                        .onSubmit { attemptLogin() }

                        HStack {
                            Spacer()
                            GhostButton(title: "Forgot Password?") {
                                // TODO: forgot password flow
                            }
                        }
                    }
                    .padding(.top, 26)
                    .padding(.horizontal, AppConstants.pagePadding)
                    .padding(.bottom, 18)
                    .background(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .fill(Color.white.opacity(0.98))
                            .overlay(
                                RoundedRectangle(cornerRadius: 28, style: .continuous)
                                    .strokeBorder(Color.black.opacity(0.06), lineWidth: 1)
                            )
                            .shadow(color: .black.opacity(0.08), radius: 20, x: 0, y: 10)
                    )
                    .padding(.horizontal, AppConstants.pagePadding)
                    .padding(.top, 16)

                    // ── Error Banner ──
                    if let err = authVM.errorMessage {
                        ToastBanner(message: err, type: .error)
                            .padding(.top, 16)
                            .padding(.horizontal, AppConstants.pagePadding)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    // ── Login Button ──
                    PrimaryButton(
                        title: "Log In",
                        isLoading: authVM.isLoading,
                        isEnabled: canLogin,
                        color: .green
                    ) { attemptLogin() }
                    .padding(.top, 28)
                    .padding(.horizontal, AppConstants.pagePadding)

                    // ── Divider ──
                    HStack {
                        Rectangle().fill(Color.gray.opacity(0.2)).frame(height: 1)
                        Text("or").font(.system(size: 13)).foregroundColor(.textTertiary).padding(.horizontal, 12)
                        Rectangle().fill(Color.gray.opacity(0.2)).frame(height: 1)
                    }
                    .padding(.vertical, 24)
                    .padding(.horizontal, AppConstants.pagePadding)

                    // ── Sign Up ──
                    HStack(spacing: 6) {
                        Text("Don't have an account?")
                            .foregroundColor(.textSecondary)
                        Button("Sign Up for Free") {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            showSignUp = true
                        }
                        .fontWeight(.bold)
                        .foregroundColor(.brand)
                    }
                    .font(.system(size: 15))
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 32)
                }
            }
            .background(
                ZStack {
                    Color(hex: "F5F7F2").ignoresSafeArea()
                    Circle()
                        .fill(Color(hex: "A3E635").opacity(0.12))
                        .frame(width: 320)
                        .offset(x: -130, y: 120)
                        .ignoresSafeArea()
                    Circle()
                        .fill(Color.black.opacity(0.03))
                        .frame(width: 280)
                        .offset(x: 120, y: 420)
                        .ignoresSafeArea()
                }
            )
            .scrollDismissesKeyboard(.interactively)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.textSecondary)
                            .padding(8)
                            .background(Color.appBackground)
                            .clipShape(Circle())
                    }
                }
            }
            .onChange(of: authVM.isAuthenticated) { loggedIn in
                if loggedIn { dismiss() }
            }
            .onAppear {
                authVM.refreshSavedLoginProfiles()
                // Start shimmer sweep animation
                withAnimation(.linear(duration: 2.2).repeatForever(autoreverses: false)) {
                    shimmerOffset = 200
                }
            }
        }
        .fullScreenCover(isPresented: $showSignUp) { SignUpView() }
    }

    private var headerHero: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(Color(hex: "17191E"))
                .frame(height: 212)
                .overlay(
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.18), radius: 22, x: 0, y: 14)
                .overlay(
                    GeometryReader { geo in
                        LinearGradient(
                            colors: [.clear, Color.white.opacity(0.12), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: geo.size.width * 0.6)
                        .offset(x: shimmerOffset)
                        .blendMode(.plusLighter)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                )

            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.black.opacity(0.02), Color.black.opacity(0.18)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(height: 212)

            Circle()
                .fill(Color.white.opacity(0.12))
                .frame(width: 120, height: 120)
                .offset(x: 44, y: -34)

            Circle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 150, height: 150)
                .offset(x: 185, y: 35)

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.white.opacity(0.18))
                            .frame(width: 36, height: 36)
                        Image(systemName: "car.2.fill")
                            .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    }
                    Text("LessGo")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.96))
                }
                Text("Welcome Back")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text("Log in to manage rides, bookings, chat, and live tracking.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.84))
                    .lineLimit(2)
                HStack(spacing: 8) {
                    HStack(spacing: 6) {
                        Circle().fill(Color(hex: "A3E635")).frame(width: 8, height: 8)
                        Text("Saved account switching")
                    }
                    HStack(spacing: 6) {
                        Circle().fill(Color.white.opacity(0.7)).frame(width: 8, height: 8)
                        Text("SJSU verification")
                    }
                }
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white.opacity(0.8))
            }
            .padding(18)
        }
    }

    private func loginTrustChip(_ title: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
            Text(title)
                .font(.system(size: 11, weight: .semibold))
        }
        .foregroundColor(.textSecondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color.white)
                .overlay(
                    Capsule().strokeBorder(Color.black.opacity(0.06), lineWidth: 1)
                )
        )
    }

    private var savedAccountsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Saved Accounts")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.textPrimary)
                Spacer()
                Text("Tap to switch")
                    .font(.system(size: 11))
                    .foregroundColor(.textTertiary)
            }
            .padding(.horizontal, AppConstants.pagePadding)

            VStack(spacing: 10) {
                ForEach(Array(authVM.savedLoginProfiles.prefix(5).enumerated()), id: \.element.id) { index, profile in
                    HStack(spacing: 12) {
                        Button(action: {
                            focusedField = nil
                            Task { await authVM.loginWithSavedProfile(profile) }
                        }) {
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(Color.brand.opacity(0.12))
                                        .frame(width: 42, height: 42)
                                    Text(profile.name.prefix(1).uppercased())
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(.brand)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(profile.name)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.textPrimary)
                                        .lineLimit(1)
                                    Text(profile.email)
                                        .font(.system(size: 12))
                                        .foregroundColor(.textSecondary)
                                        .lineLimit(1)
                                }
                                Spacer()
                                Text(profile.role.rawValue)
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.brand)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 5)
                                    .background(Color.brand.opacity(0.1))
                                    .cornerRadius(999)
                            }
                        }
                        .buttonStyle(.plain)

                        Button(action: {
                            authVM.removeSavedLoginProfile(profile)
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 18))
                                .foregroundColor(.textTertiary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.panelGradient)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .strokeBorder(Color.brand.opacity(0.08), lineWidth: 1)
                            )
                    )
                    .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 3)
                    .staggeredAppear(index: index)
                }
            }
            .padding(.horizontal, AppConstants.pagePadding)
        }
    }

    private func attemptLogin() {
        var valid = true

        if let err = AuthViewModel.validateEmail(email) {
            emailError = err; valid = false
        }
        if password.isEmpty {
            passwordError = "Password is required"; valid = false
        }

        guard valid else {
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            return
        }

        focusedField = nil
        Task { await authVM.login(email: email, password: password) }
    }
}
