import SwiftUI
import UIKit

// MARK: - Custom Text Field

struct CustomTextField: View {
    let placeholder: String
    @Binding var text: String
    var icon: String? = nil
    var isSecure: Bool = false
    var keyboardType: UIKeyboardType = .default
    var autocapitalization: TextInputAutocapitalization = .never
    var errorMessage: String? = nil
    var isFocused: Bool = false

    @State private var showPassword = false
    @FocusState private var fieldFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 17))
                        .foregroundColor(fieldFocused ? .brand : .textTertiary)
                        .frame(width: 22)
                        .animation(.easeInOut(duration: 0.2), value: fieldFocused)
                }

                Group {
                    if isSecure && !showPassword {
                        SecureField(placeholder, text: $text)
                    } else {
                        TextField(placeholder, text: $text)
                            .keyboardType(keyboardType)
                    }
                }
                .textInputAutocapitalization(autocapitalization)
                .focused($fieldFocused)
                .font(.system(size: 16))
                .foregroundColor(.textPrimary)

                if isSecure {
                    Button(action: { showPassword.toggle() }) {
                        Image(systemName: showPassword ? "eye.slash" : "eye")
                            .font(.system(size: 16))
                            .foregroundColor(.textTertiary)
                    }
                }

                if !text.isEmpty && !isSecure {
                    Button(action: { text = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.textTertiary)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: AppConstants.inputRadius, style: .continuous)
                    .fill(Color.panelGradient)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppConstants.inputRadius, style: .continuous)
                            .strokeBorder(
                                errorMessage != nil ? Color.brandRed.opacity(0.7) :
                                    fieldFocused ? Color.brand.opacity(0.65) : Color.brand.opacity(0.08),
                                lineWidth: fieldFocused || errorMessage != nil ? 1.5 : 1
                            )
                    )
                    .shadow(color: fieldFocused ? Color.brand.opacity(0.12) : .black.opacity(0.04),
                            radius: fieldFocused ? 14 : 8,
                            x: 0,
                            y: fieldFocused ? 6 : 3)
            )
            .animation(.easeInOut(duration: 0.2), value: fieldFocused)

            if let error = errorMessage {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 12))
                    Text(error)
                        .font(.system(size: 12))
                }
                .foregroundColor(.brandRed)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: errorMessage)
    }
}

// MARK: - Search Field

struct SearchTextField: View {
    let placeholder: String
    @Binding var text: String
    var onSubmit: (() -> Void)? = nil
    /// When true, uses glassmorphism + elevated shadow — for floating over maps
    var isFloating: Bool = false

    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(isFocused ? .brand : .textTertiary)
                .animation(.easeInOut(duration: 0.18), value: isFocused)

            TextField(placeholder, text: $text)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.textPrimary)
                .autocapitalization(.none)
                .focused($isFocused)
                .submitLabel(.search)
                .onSubmit { onSubmit?() }

            if !text.isEmpty {
                Button(action: { text = ""; UIImpactFeedbackGenerator(style: .light).impactOccurred() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 17))
                        .foregroundColor(.textTertiary)
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            Group {
                if isFloating {
                    AnyView(
                        Capsule(style: .continuous)
                            .fill(.ultraThinMaterial)
                            .overlay(Capsule().strokeBorder(Color.white.opacity(0.55), lineWidth: 1))
                            .shadow(color: .black.opacity(0.14), radius: 20, x: 0, y: 8)
                    )
                } else {
                    AnyView(
                        Capsule(style: .continuous)
                            .fill(Color.panelGradient)
                            .overlay(Capsule().strokeBorder(Color.brand.opacity(0.09), lineWidth: 1))
                            .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 4)
                    )
                }
            }
        )
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: text.isEmpty)
    }
}

// MARK: - Labeled Text Field

struct LabeledTextField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var isSecure: Bool = false
    var icon: String? = nil
    var keyboardType: UIKeyboardType = .default
    var errorMessage: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.textSecondary)
                .textCase(.uppercase)
                .kerning(0.5)

            CustomTextField(
                placeholder: placeholder,
                text: $text,
                icon: icon,
                isSecure: isSecure,
                keyboardType: keyboardType,
                errorMessage: errorMessage
            )
        }
    }
}
