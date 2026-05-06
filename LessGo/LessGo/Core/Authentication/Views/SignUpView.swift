import SwiftUI
import UIKit

struct SignUpView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var name     = ""
    @State private var email    = ""
    @State private var password = ""
    @State private var confirm  = ""
    @State private var role: UserRole = .rider

    @State private var nameError:     String?
    @State private var emailError:    String?
    @State private var passwordError: String?
    @State private var confirmError:  String?


    @State private var showDuplicateEmailAlert = false
    @FocusState private var focusedField: Field?

    enum Field { case name, email, password, confirm }

    private var isValid: Bool { !name.isEmpty && !email.isEmpty && !password.isEmpty && !confirm.isEmpty }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    signupHeroHeader
                        .padding(.top, 14)
                        .padding(.horizontal, AppConstants.pagePadding)

                    // ── Role Selector ──
                    VStack(alignment: .leading, spacing: 10) {
                        Text("I AM A")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.textTertiary)
                            .kerning(1)

                        HStack(spacing: 12) {
                            RolePill(title: "Rider", icon: "person.fill", isSelected: role == .rider) {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { role = .rider }
                            }
                            RolePill(title: "Driver", icon: "car.fill", isSelected: role == .driver) {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { role = .driver }
                            }
                        }
                    }
                    .padding(.top, 18)
                    .padding(.horizontal, AppConstants.pagePadding)
                    .padding(.bottom, 4)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(Color.cardBackground.opacity(0.88))
                            .overlay(
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                                    .strokeBorder(DesignSystem.Colors.border.opacity(0.7), lineWidth: 1)
                            )
                    )
                    .padding(.horizontal, AppConstants.pagePadding)
                    .padding(.top, 14)

                    // ── Form Fields ──
                    VStack(spacing: 16) {
                        LabeledTextField(
                            label: "Full Name",
                            placeholder: "Jane Doe",
                            text: $name,
                            icon: "person",
                            errorMessage: nameError
                        )
                        .focused($focusedField, equals: .name)
                        .onChange(of: name) { _ in nameError = nil }
                        .submitLabel(.next)
                        .onSubmit { focusedField = .email }

                        LabeledTextField(
                            label: "SJSU Email",
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
                            placeholder: "At least 8 characters",
                            text: $password,
                            isSecure: true,
                            icon: "lock",
                            errorMessage: passwordError
                        )
                        .focused($focusedField, equals: .password)
                        .onChange(of: password) { _ in passwordError = nil }
                        .submitLabel(.next)
                        .onSubmit { focusedField = .confirm }

                        LabeledTextField(
                            label: "Confirm Password",
                            placeholder: "Re-enter your password",
                            text: $confirm,
                            isSecure: true,
                            icon: "lock.shield",
                            errorMessage: confirmError
                        )
                        .focused($focusedField, equals: .confirm)
                        .onChange(of: confirm) { _ in confirmError = nil }
                        .submitLabel(.go)
                        .onSubmit { attemptRegister() }

                        // Password strength hint
                        if !password.isEmpty {
                            PasswordStrengthIndicator(password: password)
                                .transition(.move(edge: .top).combined(with: .opacity))
                        }
                    }
                    .padding(.top, 24)
                    .padding(.horizontal, AppConstants.pagePadding)
                    .padding(.bottom, 18)
                    .background(
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .fill(Color.cardBackground.opacity(0.97))
                            .overlay(
                                RoundedRectangle(cornerRadius: 26, style: .continuous)
                                    .strokeBorder(DesignSystem.Colors.border.opacity(0.7), lineWidth: 1)
                            )
                    )
                    .padding(.horizontal, AppConstants.pagePadding)
                    .padding(.top, 14)
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: password.isEmpty)

                    // ── Error Banner ──
                    if let err = authVM.errorMessage {
                        ToastBanner(message: err, type: .error)
                            .padding(.top, 16)
                            .padding(.horizontal, AppConstants.pagePadding)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    // ── Terms ──
                    Text("By signing up, you agree to our **Terms of Service** and **Privacy Policy**.")
                        .font(.system(size: 12))
                        .foregroundColor(.textTertiary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 28)
                        .padding(.top, 20)

                    // ── Sign Up Button ──
                    PrimaryButton(
                        title: "Create Account",
                        icon: "arrow.right",
                        isLoading: authVM.isLoading,
                        isEnabled: isValid
                    ) { attemptRegister() }
                    .padding(.top, 20)
                    .padding(.horizontal, AppConstants.pagePadding)
                    .padding(.bottom, 32)
                }
            }
            .background(
                ZStack {
                    Color.appBackground.ignoresSafeArea()
                    Circle()
                        .fill(DesignSystem.Colors.accentLime.opacity(0.12))
                        .frame(width: 280)
                        .offset(x: 140, y: 520)
                        .ignoresSafeArea()
                    Circle()
                        .fill(DesignSystem.Colors.textPrimary.opacity(0.03))
                        .frame(width: 340)
                        .offset(x: -140, y: 60)
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
                if loggedIn {
                    dismiss()
                }
            }
            .alert("Email Already Registered", isPresented: $showDuplicateEmailAlert) {
                Button("Go to Login") {
                    dismiss()
                }
                Button("Try Different Email", role: .cancel) {
                    email = ""
                    emailError = "This email is already registered"
                    focusedField = .email
                }
            } message: {
                Text("An account with this email already exists. Please login instead or use a different email address.")
            }
        }
    }

    private func attemptRegister() {
        var valid = true

        if let err = AuthViewModel.validateName(name) { nameError = err; valid = false }
        if let err = AuthViewModel.validateEmail(email) { emailError = err; valid = false }
        if let err = AuthViewModel.validatePassword(password) { passwordError = err; valid = false }
        if confirm != password { confirmError = "Passwords don't match"; valid = false }

        guard valid else {
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            return
        }

        focusedField = nil
        Task {
            await authVM.register(name: name, email: email, password: password, role: role)

            // Check for duplicate email error
            if let errorMsg = authVM.errorMessage,
               errorMsg.lowercased().contains("email already exists") ||
               errorMsg.lowercased().contains("account with this email") {
                emailError = "This email is already registered"
                showDuplicateEmailAlert = true
            }
        }
    }

    private var signupHeroHeader: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Create account")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Spacer()
                HStack(spacing: 6) {
                    Image(systemName: "graduationcap.fill")
                    Text("SJSU")
                }
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(DesignSystem.Colors.onAccentLime)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(DesignSystem.Colors.accentLime)
                .clipShape(Capsule())
            }

            Text("Join verified campus riders and drivers with one account.")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.textSecondary)

            HStack(spacing: 8) {
                signupChip("Rider", icon: "person.fill")
                signupChip("Driver", icon: "car.fill")
                signupChip("Live Chat", icon: "message.fill")
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(DesignSystem.Colors.darkBrandSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(DesignSystem.Colors.onDark.opacity(0.08), lineWidth: 1)
                )
        )
    }

    private func signupChip(_ title: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
            Text(title)
                .font(.system(size: 11, weight: .semibold))
        }
        .foregroundColor(DesignSystem.Colors.onDark.opacity(0.8))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(DesignSystem.Colors.onDark.opacity(0.07))
        .clipShape(Capsule())
    }
}

// MARK: - Role Pill

private struct RolePill: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: { UIImpactFeedbackGenerator(style: .light).impactOccurred(); action() }) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(isSelected ? DesignSystem.Colors.accentLime : Color.cardBackground)
            .foregroundColor(isSelected ? DesignSystem.Colors.onAccentLime : .textSecondary)
            .cornerRadius(18)
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(isSelected ? Color.clear : DesignSystem.Colors.border.opacity(0.7), lineWidth: 1)
            )
            .shadow(color: isSelected ? DesignSystem.Colors.accentLime.opacity(0.25) : .black.opacity(0.04), radius: 8, x: 0, y: 4)
        }
    }
}

// MARK: - Password Strength Indicator

private struct PasswordStrengthIndicator: View {
    let password: String

    private var strength: Int {
        var score = 0
        if password.count >= 8 { score += 1 }
        if password.first(where: { $0.isUppercase }) != nil { score += 1 }
        if password.first(where: { $0.isNumber }) != nil { score += 1 }
        if password.first(where: { "!@#$%^&*".contains($0) }) != nil { score += 1 }
        return score
    }

    private var label: String {
        ["Too weak", "Weak", "Fair", "Strong", "Very strong"][strength]
    }

    private var color: Color {
        [Color.brandRed, .brandOrange, .brandOrange, .brandGreen, .brandGreen][strength]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                ForEach(1...4, id: \.self) { i in
                    Capsule()
                        .fill(i <= strength ? color : Color.gray.opacity(0.2))
                        .frame(maxWidth: .infinity, maxHeight: 4)
                }
            }
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(color)
        }
    }
}

#Preview {
    SignUpView()
        .environmentObject(AuthViewModel())
}
