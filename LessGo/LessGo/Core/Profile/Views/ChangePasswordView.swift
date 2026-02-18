import SwiftUI

struct ChangePasswordView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showSuccess = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Icon header
                    ZStack {
                        Circle()
                            .fill(Color.brand.opacity(0.1))
                            .frame(width: 72, height: 72)
                        Image(systemName: "lock.rotation")
                            .font(.system(size: 30))
                            .foregroundColor(.brand)
                    }
                    .padding(.top, 8)

                    // Fields
                    VStack(spacing: 16) {
                        SecureInputField(label: "Current Password", placeholder: "Enter current password", text: $currentPassword)

                        VStack(alignment: .leading, spacing: 6) {
                            SecureInputField(label: "New Password", placeholder: "Enter new password", text: $newPassword)
                            if !newPassword.isEmpty {
                                PasswordStrengthBar(password: newPassword)
                            }
                        }

                        SecureInputField(label: "Confirm New Password", placeholder: "Re-enter new password", text: $confirmPassword)

                        if let mismatch = confirmMismatch {
                            Text(mismatch)
                                .font(.system(size: 12))
                                .foregroundColor(.brandRed)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }

                    // Error
                    if let err = errorMessage {
                        ToastBanner(message: err, type: .error)
                    }

                    // Requirements hint
                    VStack(alignment: .leading, spacing: 4) {
                        requirementRow("At least 8 characters", met: newPassword.count >= 8)
                        requirementRow("One uppercase letter", met: newPassword.contains(where: { $0.isUppercase }))
                        requirementRow("One number", met: newPassword.contains(where: { $0.isNumber }))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .cardStyle(padding: 14)

                    // Submit
                    PrimaryButton(title: "Update Password", isLoading: isLoading, color: .green) {
                        Task { await submit() }
                    }
                    .disabled(!canSubmit)
                    .opacity(canSubmit ? 1 : 0.5)

                    Spacer()
                }
                .padding()
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("Change Password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .alert("Password Updated", isPresented: $showSuccess) {
                Button("Done") { dismiss() }
            } message: {
                Text("Your password has been changed successfully.")
            }
        }
    }

    // MARK: - Computed

    private var confirmMismatch: String? {
        guard !confirmPassword.isEmpty, confirmPassword != newPassword else { return nil }
        return "Passwords do not match"
    }

    private var canSubmit: Bool {
        !currentPassword.isEmpty &&
        newPassword.count >= 8 &&
        newPassword == confirmPassword &&
        !isLoading
    }

    // MARK: - Submit

    private func submit() async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }
        do {
            try await AuthService.shared.changePassword(
                currentPassword: currentPassword,
                newPassword: newPassword
            )
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            showSuccess = true
        } catch let error as NetworkError {
            errorMessage = error.localizedDescription
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        } catch {
            errorMessage = error.localizedDescription
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func requirementRow(_ text: String, met: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: met ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 13))
                .foregroundColor(met ? .brandGreen : .textTertiary)
            Text(text)
                .font(.system(size: 13))
                .foregroundColor(met ? .textPrimary : .textTertiary)
        }
    }
}

// MARK: - Secure Input Field

private struct SecureInputField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    @State private var isVisible = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.textTertiary)

            HStack {
                Group {
                    if isVisible {
                        TextField(placeholder, text: $text)
                    } else {
                        SecureField(placeholder, text: $text)
                    }
                }
                .font(.system(size: 16))
                .autocapitalization(.none)
                .autocorrectionDisabled()

                Button(action: { isVisible.toggle() }) {
                    Image(systemName: isVisible ? "eye.slash" : "eye")
                        .foregroundColor(.textTertiary)
                }
            }
            .padding()
            .background(Color.cardBackground)
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.15), lineWidth: 1))
        }
    }
}

// MARK: - Password Strength Bar

private struct PasswordStrengthBar: View {
    let password: String

    private var strength: (level: Int, label: String, color: Color) {
        var score = 0
        if password.count >= 8 { score += 1 }
        if password.contains(where: { $0.isUppercase }) { score += 1 }
        if password.contains(where: { $0.isNumber }) { score += 1 }
        if password.contains(where: { "!@#$%^&*()_+-=[]{}|;':\",./<>?".contains($0) }) { score += 1 }

        switch score {
        case 4: return (4, "Strong", .brandGreen)
        case 3: return (3, "Good", .brand)
        case 2: return (2, "Medium", .brandOrange)
        default: return (1, "Weak", .brandRed)
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            ForEach(1...4, id: \.self) { i in
                RoundedRectangle(cornerRadius: 2)
                    .fill(i <= strength.level ? strength.color : Color.gray.opacity(0.2))
                    .frame(height: 4)
            }
            Text(strength.label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(strength.color)
                .frame(width: 44, alignment: .trailing)
        }
    }
}
