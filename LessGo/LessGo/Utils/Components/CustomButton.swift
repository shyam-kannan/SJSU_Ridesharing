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

    @GestureState private var isPressed = false

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

    private var shadowColor: Color {
        switch color {
        case .green: return Color.brandGreen.opacity(0.38)
        case .blue:  return DesignSystem.Colors.sjsuBlue.opacity(0.38)
        case .red:   return Color.brandRed.opacity(0.38)
        }
    }

    var body: some View {
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
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: DesignSystem.Layout.buttonHeightLarge)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: AppConstants.buttonRadius, style: .continuous)
                    .fill((isEnabled && !isLoading) ? AnyShapeStyle(gradient) : AnyShapeStyle(Color.gray.opacity(0.28)))
                // Inner highlight shimmer
                RoundedRectangle(cornerRadius: AppConstants.buttonRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.22), .clear],
                            startPoint: .top,
                            endPoint: .center
                        )
                    )
                RoundedRectangle(cornerRadius: AppConstants.buttonRadius, style: .continuous)
                    .strokeBorder(Color.white.opacity(isEnabled ? 0.35 : 0), lineWidth: 1)
            }
        )
        .foregroundColor(.white)
        .shadow(
            color: (isEnabled && !isLoading) ? shadowColor : .clear,
            radius: isPressed ? 8 : 16,
            x: 0,
            y: isPressed ? 4 : 10
        )
        .scaleEffect(isPressed && isEnabled ? 0.96 : (isEnabled ? 1.0 : 0.985))
        .opacity(isEnabled ? 1 : 0.72)
        .animation(.spring(response: 0.22, dampingFraction: 0.72), value: isPressed)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isEnabled)
        .gesture(
            DragGesture(minimumDistance: 0)
                .updating($isPressed) { _, state, _ in state = true }
                .onEnded { _ in
                    guard isEnabled && !isLoading else { return }
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    action()
                }
        )
        .allowsHitTesting(isEnabled && !isLoading)
    }
}

// MARK: - Secondary / Outline Button

struct SecondaryButton: View {
    let title: String
    var icon: String? = nil
    var color: Color = .brand
    let action: () -> Void

    @GestureState private var isPressed = false

    var body: some View {
        HStack(spacing: 8) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .semibold))
            }
            Text(title)
                .font(.system(size: 17, weight: .semibold, design: .rounded))
        }
        .frame(maxWidth: .infinity)
        .frame(height: DesignSystem.Layout.buttonHeightLarge)
        .background(
            RoundedRectangle(cornerRadius: AppConstants.buttonRadius, style: .continuous)
                .fill(Color.cardBackground)
        )
        .foregroundColor(color)
        .overlay(
            RoundedRectangle(cornerRadius: AppConstants.buttonRadius, style: .continuous)
                .strokeBorder(color.opacity(0.45), lineWidth: 1.25)
        )
        .shadow(color: .black.opacity(isPressed ? 0.02 : 0.07), radius: isPressed ? 6 : 12, x: 0, y: isPressed ? 2 : 5)
        .scaleEffect(isPressed ? 0.97 : 1.0)
        .animation(.spring(response: 0.22, dampingFraction: 0.72), value: isPressed)
        .gesture(
            DragGesture(minimumDistance: 0)
                .updating($isPressed) { _, state, _ in state = true }
                .onEnded { _ in
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    action()
                }
        )
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
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(color.opacity(0.08))
                .cornerRadius(10)
        }
        .buttonStyle(.plain)
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

// MARK: - Floating Action Button

struct FloatingActionButton: View {
    let icon: String
    var color: Color = .brand
    var badgeCount: Int = 0
    let action: () -> Void

    @GestureState private var isPressed = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [color, color.opacity(0.78)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: DesignSystem.Layout.fabSize, height: DesignSystem.Layout.fabSize)
                    .shadow(
                        color: color.opacity(isPressed ? 0.2 : 0.38),
                        radius: isPressed ? 10 : 18,
                        x: 0,
                        y: isPressed ? 4 : 10
                    )

                Image(systemName: icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.white)
            }
            .scaleEffect(isPressed ? 0.93 : 1.0)
            .animation(.spring(response: 0.22, dampingFraction: 0.7), value: isPressed)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .updating($isPressed) { _, state, _ in state = true }
                    .onEnded { _ in
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        action()
                    }
            )

            if badgeCount > 0 {
                ZStack {
                    Circle()
                        .fill(Color.brandRed)
                        .frame(width: 20, height: 20)
                    Text("\(min(badgeCount, 9))")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                }
                .offset(x: 4, y: -4)
            }
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
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(isSelected ? .white : .textSecondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 9)
                .background(
                    Group {
                        if isSelected {
                            AnyView(
                                LinearGradient(
                                    colors: [DesignSystem.Colors.sjsuBlue, DesignSystem.Colors.sjsuTeal],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                        } else {
                            AnyView(Color.appBackground)
                        }
                    }
                )
                .cornerRadius(999)
                .overlay(
                    Capsule()
                        .strokeBorder(isSelected ? Color.clear : Color.gray.opacity(0.22), lineWidth: 1)
                )
                .shadow(color: isSelected ? DesignSystem.Colors.sjsuBlue.opacity(0.25) : .clear, radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isSelected)
    }
}
