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

    @State private var showIDVerification = false
    @FocusState private var focusedField: Field?

    enum Field { case name, email, password, confirm }

    private var isValid: Bool { !name.isEmpty && !email.isEmpty && !password.isEmpty && !confirm.isEmpty }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {

                    // ── Header ──
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Create account")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.textPrimary)
                        Text("Join thousands of SJSU commuters")
                            .font(.system(size: 16))
                            .foregroundColor(.textSecondary)
                    }
                    .padding(.top, 40)
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
                    .padding(.top, 32)
                    .padding(.horizontal, AppConstants.pagePadding)

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
                if loggedIn {
                    dismiss()
                    // Prompt ID verification after small delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        authVM.showIDVerification = true
                    }
                }
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
        Task { await authVM.register(name: name, email: email, password: password, role: role) }
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
            .background(isSelected ? Color.brand : Color.appBackground)
            .foregroundColor(isSelected ? .white : .textSecondary)
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(isSelected ? Color.clear : Color.gray.opacity(0.2), lineWidth: 1)
            )
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
