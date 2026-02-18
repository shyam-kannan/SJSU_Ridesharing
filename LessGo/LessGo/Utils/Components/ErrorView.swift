import SwiftUI

// MARK: - Full-Screen Error View

struct FullErrorView: View {
    let message: String
    var retryTitle: String = "Try Again"
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.brandRed.opacity(0.1))
                    .frame(width: 100, height: 100)
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 44))
                    .foregroundColor(.brandRed)
            }

            VStack(spacing: 10) {
                Text("Something Went Wrong")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.textPrimary)

                Text(message)
                    .font(.system(size: 16))
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            PrimaryButton(title: retryTitle, icon: "arrow.clockwise", color: .blue, action: retry)
                .padding(.horizontal, 40)

            Spacer()
        }
    }
}

// MARK: - Empty State View

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.brand.opacity(0.08))
                    .frame(width: 110, height: 110)
                Image(systemName: icon)
                    .font(.system(size: 52))
                    .foregroundColor(.brand.opacity(0.6))
            }

            VStack(spacing: 10) {
                Text(title)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.textPrimary)
                Text(message)
                    .font(.system(size: 16))
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            if let actionTitle = actionTitle, let action = action {
                PrimaryButton(title: actionTitle, action: action)
                    .padding(.horizontal, 40)
            }

            Spacer()
        }
    }
}

// MARK: - Toast / Inline Banner

struct ToastBanner: View {
    let message: String
    var type: ToastType = .info

    enum ToastType {
        case info, success, error, warning

        var color: Color {
            switch self {
            case .info:    return .brand
            case .success: return .brandGreen
            case .error:   return .brandRed
            case .warning: return .brandOrange
            }
        }

        var icon: String {
            switch self {
            case .info:    return "info.circle.fill"
            case .success: return "checkmark.circle.fill"
            case .error:   return "xmark.circle.fill"
            case .warning: return "exclamationmark.triangle.fill"
            }
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: type.icon)
                .foregroundColor(type.color)
            Text(message)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.textPrimary)
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(type.color.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(type.color.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// MARK: - Error Alert Modifier

struct ErrorAlertModifier: ViewModifier {
    @Binding var errorMessage: String?

    func body(content: Content) -> some View {
        content
            .alert("Error", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
    }
}

extension View {
    func errorAlert(message: Binding<String?>) -> some View {
        self.modifier(ErrorAlertModifier(errorMessage: message))
    }
}
