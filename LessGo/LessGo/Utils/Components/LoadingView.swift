import SwiftUI
import Combine
// MARK: - Full Screen Loading Overlay

struct LoadingOverlay: View {
    var message: String = "Loading..."

    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.3)

                Text(message)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white)
            }
            .padding(28)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
            )
        }
    }
}

// MARK: - Skeleton Trip Card

struct SkeletonTripCard: View {
    @State private var isAnimating = false
    var index: Int = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Top: time pill + countdown
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 999)
                    .fill(Color.gray.opacity(shimmerOpacity))
                    .frame(width: 90, height: 28)
                RoundedRectangle(cornerRadius: 999)
                    .fill(Color.gray.opacity(shimmerOpacity * 0.7))
                    .frame(width: 70, height: 28)
                Spacer()
                RoundedRectangle(cornerRadius: 999)
                    .fill(Color.gray.opacity(shimmerOpacity * 0.6))
                    .frame(width: 58, height: 24)
            }

            // Driver row
            HStack(spacing: 12) {
                Circle()
                    .fill(Color.gray.opacity(shimmerOpacity))
                    .frame(width: 50, height: 50)

                VStack(alignment: .leading, spacing: 6) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(shimmerOpacity))
                        .frame(width: 110, height: 14)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(shimmerOpacity * 0.7))
                        .frame(width: 75, height: 11)
                }
                Spacer()
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.gray.opacity(shimmerOpacity))
                    .frame(width: 36, height: 36)
            }

            // Route
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.gray.opacity(shimmerOpacity * 0.5))
                .frame(maxWidth: .infinity)
                .frame(height: 56)

            // Bottom row
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 999)
                    .fill(Color.gray.opacity(shimmerOpacity * 0.7))
                    .frame(width: 80, height: 26)
                Spacer()
                RoundedRectangle(cornerRadius: 999)
                    .fill(Color.gray.opacity(shimmerOpacity * 0.6))
                    .frame(width: 56, height: 26)
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.97))
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.08), radius: 16, x: 0, y: 6)
        .staggeredAppear(index: index, delay: 0.1)
        .onAppear { startAnimation() }
    }

    private var shimmerOpacity: Double { isAnimating ? 0.08 : 0.18 }

    private func startAnimation() {
        withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
            isAnimating = true
        }
    }
}

// MARK: - Skeleton List (3 cards)

struct SkeletonTripList: View {
    var body: some View {
        VStack(spacing: 14) {
            ForEach(0..<4, id: \.self) { i in
                SkeletonTripCard(index: i)
            }
        }
        .padding(.horizontal, AppConstants.pagePadding)
    }
}

// MARK: - Inline Loading Row

struct LoadingRow: View {
    var message: String = "Loading..."

    var body: some View {
        HStack(spacing: 12) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .brand))
            Text(message)
                .font(.system(size: 15))
                .foregroundColor(.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
}

// MARK: - Dots Loading Animation

struct DotsLoadingView: View {
    @State private var animationStep = 0
    let timer = Timer.publish(every: 0.4, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Color.brand)
                    .frame(width: 8, height: 8)
                    .scaleEffect(animationStep == index ? 1.4 : 1.0)
                    .animation(.spring(response: 0.3), value: animationStep)
            }
        }
        .onReceive(timer) { _ in
            animationStep = (animationStep + 1) % 3
        }
    }
}
