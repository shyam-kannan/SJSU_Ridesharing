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

    private var canLogin: Bool { !email.isEmpty && !password.isEmpty && !authVM.isLoading }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {

                    // ── Header ──
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Welcome back")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.textPrimary)
                        Text("Log in to continue your journey")
                            .font(.system(size: 16))
                            .foregroundColor(.textSecondary)
                    }
                    .padding(.top, 40)
                    .padding(.horizontal, AppConstants.pagePadding)

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
                    .padding(.top, 36)
                    .padding(.horizontal, AppConstants.pagePadding)

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
                        color: .blue
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
            .background(Color.cardBackground.ignoresSafeArea())
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
        }
        .fullScreenCover(isPresented: $showSignUp) { SignUpView() }
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
