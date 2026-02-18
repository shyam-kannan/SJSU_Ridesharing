import SwiftUI
import UIKit

// MARK: - View Modifiers

extension View {

    // MARK: - Card Style
    func cardStyle(padding: CGFloat = 16, cornerRadius: CGFloat = 16) -> some View {
        self
            .padding(padding)
            .background(Color.cardBackground)
            .cornerRadius(cornerRadius)
            .shadow(color: Color.black.opacity(0.07), radius: 12, x: 0, y: 4)
    }

    // MARK: - Press Animation
    func pressAnimation(scale: CGFloat = 0.97, onPress: @escaping () -> Void) -> some View {
        self.modifier(PressAnimationModifier(scale: scale, onPress: onPress))
    }

    // MARK: - Haptic Feedback
    func haptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }

    func successHaptic() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    func errorHaptic() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }

    // MARK: - Keyboard Dismiss
    func dismissKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil
        )
    }

    // MARK: - Hide Keyboard on Tap
    func hideKeyboardOnTap() -> some View {
        self.onTapGesture { dismissKeyboard() }
    }

    // MARK: - Shimmer
    func shimmer(isActive: Bool = true) -> some View {
        self.modifier(ShimmerModifier(isActive: isActive))
    }

    // MARK: - Conditional Modifier
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }

    // MARK: - Navigation Bar Transparent
    func transparentNavBar() -> some View {
        self.modifier(TransparentNavBarModifier())
    }
}

// MARK: - Press Animation Modifier
struct PressAnimationModifier: ViewModifier {
    let scale: CGFloat
    let onPress: () -> Void
    @GestureState private var isPressed = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? scale : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .updating($isPressed) { _, state, _ in state = true }
                    .onEnded { _ in onPress() }
            )
    }
}

// MARK: - Shimmer Modifier
struct ShimmerModifier: ViewModifier {
    let isActive: Bool
    @State private var phase: CGFloat = -1

    func body(content: Content) -> some View {
        if isActive {
            content
                .overlay(
                    GeometryReader { geo in
                        LinearGradient(
                            colors: [.clear,
                                     .white.opacity(0.5),
                                     .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: geo.size.width * 2)
                        .offset(x: phase * geo.size.width * 2)
                    }
                    .mask(content)
                )
                .onAppear {
                    withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
                        phase = 1
                    }
                }
        } else {
            content
        }
    }
}

// MARK: - Transparent Nav Bar Modifier
struct TransparentNavBarModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .onAppear {
                let appearance = UINavigationBarAppearance()
                appearance.configureWithTransparentBackground()
                UINavigationBar.appearance().standardAppearance = appearance
                UINavigationBar.appearance().scrollEdgeAppearance = appearance
            }
    }
}

// MARK: - Skeleton Row View
struct SkeletonRow: View {
    var height: CGFloat = 80
    var cornerRadius: CGFloat = 12

    @State private var isAnimating = false

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Color.gray.opacity(isAnimating ? 0.12 : 0.2))
            .frame(height: height)
            .animation(
                .easeInOut(duration: 0.9).repeatForever(autoreverses: true),
                value: isAnimating
            )
            .onAppear { isAnimating = true }
    }
}

// MARK: - Rounded Corners (specific corners only)

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCornerShape(radius: radius, corners: corners))
    }
}

struct RoundedCornerShape: Shape {
    let radius: CGFloat
    let corners: UIRectCorner
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}

// MARK: - Star Rating View
struct StarRatingView: View {
    let rating: Double
    let size: CGFloat

    init(rating: Double, size: CGFloat = 14) {
        self.rating = rating
        self.size = size
    }

    var body: some View {
        HStack(spacing: 2) {
            ForEach(1...5, id: \.self) { index in
                Image(systemName: starName(for: index))
                    .font(.system(size: size))
                    .foregroundColor(.brandOrange)
            }
        }
    }

    private func starName(for index: Int) -> String {
        if Double(index) <= rating { return "star.fill" }
        if Double(index) - 0.5 <= rating { return "star.leadinghalf.filled" }
        return "star"
    }
}
