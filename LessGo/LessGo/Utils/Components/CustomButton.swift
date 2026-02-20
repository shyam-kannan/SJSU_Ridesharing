import SwiftUI
import UIKit

// MARK: - Primary Button (Green Gradient / Blue)

struct PrimaryButton: View {
    let title: String
    var icon: String? = nil
    var isLoading: Bool = false
    var isEnabled: Bool = true
    var color: ButtonColor = .blue
    let action: () -> Void

    enum ButtonColor { case green, blue, red }

    private var gradient: LinearGradient {
        switch color {
        case .green: return Color.greenGradient
        case .blue:  return Color.brandGradient
        case .red:
            return LinearGradient(
                colors: [.brandRed, Color(red: 200/255, green: 40/255, blue: 30/255)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        }
    }

    var body: some View {
        Button(action: {
            guard isEnabled && !isLoading else { return }
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            action()
        }) {
            ZStack {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.9)
                } else {
                    HStack(spacing: 8) {
                        if let icon = icon {
                            Image(systemName: icon)
                                .font(.system(size: 17, weight: .semibold))
                        }
                        Text(title)
                            .font(.system(size: 17, weight: .semibold))
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: AppConstants.buttonHeight)
            .background(
                (isEnabled && !isLoading)
                    ? AnyView(gradient)
                    : AnyView(Color.gray.opacity(0.35))
            )
            .foregroundColor(.white)
            .cornerRadius(AppConstants.buttonRadius)
        }
        .disabled(!isEnabled || isLoading)
        .scaleEffect(isEnabled ? 1 : 0.98)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isEnabled)
    }
}

// MARK: - Secondary / Outline Button

struct SecondaryButton: View {
    let title: String
    var icon: String? = nil
    var color: Color = .brand
    let action: () -> Void

    var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        }) {
            HStack(spacing: 8) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 17, weight: .semibold))
                }
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .frame(height: AppConstants.buttonHeight)
            .background(Color.white)
            .foregroundColor(color)
            .overlay(
                RoundedRectangle(cornerRadius: AppConstants.buttonRadius)
                    .strokeBorder(color, lineWidth: 1.5)
            )
            .cornerRadius(AppConstants.buttonRadius)
        }
    }
}

// MARK: - Ghost / Text Button

struct GhostButton: View {
    let title: String
    var color: Color = .brand
    let action: () -> Void

    var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        }) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(color)
        }
    }
}

// MARK: - Icon Button

struct IconButton: View {
    let icon: String
    var color: Color = .brand
    var size: CGFloat = 44
    let action: () -> Void

    var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        }) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(color)
                .frame(width: size, height: size)
                .background(Color.cardBackground)
                .clipShape(Circle())
                .shadow(color: Color.black.opacity(0.1), radius: 6, x: 0, y: 3)
        }
    }
}

// MARK: - Chip / Tag Button

struct ChipButton: View {
    let title: String
    var isSelected: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        }) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(isSelected ? .white : .textSecondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(isSelected ? Color.brand : Color.appBackground)
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(isSelected ? Color.clear : Color.gray.opacity(0.25), lineWidth: 1)
                )
        }
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isSelected)
    }
}
