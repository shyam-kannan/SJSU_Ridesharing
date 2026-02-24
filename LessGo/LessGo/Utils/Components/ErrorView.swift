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

    @State private var appeared = false

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            // Icon with layered circles
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.brand.opacity(0.12), Color.brand.opacity(0.03)],
                            center: .center,
                            startRadius: 10,
                            endRadius: 65
                        )
                    )
                    .frame(width: 130, height: 130)

                Circle()
                    .fill(Color.brand.opacity(0.08))
                    .frame(width: 96, height: 96)

                Image(systemName: icon)
                    .font(.system(size: 44, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [DesignSystem.Colors.sjsuBlue, DesignSystem.Colors.sjsuTeal],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .scaleEffect(appeared ? 1 : 0.7)
            .opacity(appeared ? 1 : 0)

            VStack(spacing: 12) {
                Text(title)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.textPrimary)
                Text(message)
                    .font(.system(size: 15))
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 32)
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 12)

            if let actionTitle = actionTitle, let action = action {
                PrimaryButton(title: actionTitle, action: action)
                    .padding(.horizontal, 40)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 10)
            }

            Spacer()
        }
        .onAppear {
            withAnimation(DesignSystem.Animation.standard.delay(0.1)) { appeared = true }
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
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(type.color.opacity(0.14))
                    .frame(width: 32, height: 32)
                Image(systemName: type.icon)
                    .foregroundColor(type.color)
                    .font(.system(size: 14, weight: .bold))
            }

            Text(message)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.textPrimary)
                .lineLimit(2)

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.97), type.color.opacity(0.08)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(type.color.opacity(0.28), lineWidth: 1)
                )
        )
        .shadow(color: type.color.opacity(0.12), radius: 12, x: 0, y: 4)
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
