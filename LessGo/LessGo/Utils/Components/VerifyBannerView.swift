import SwiftUI
import UIKit

// MARK: - Verify Banner View
//
// Reusable banner that appears below the status bar on any screen.
// Uses UIWindowScene.keyWindow to read the actual top safe-area inset so
// it always sits below the notch/Dynamic Island regardless of SwiftUI layout context.

struct VerifyBannerView: View {
    let status: SJSUIDStatus
    let action: () -> Void

    var body: some View {
        bannerContent
    }

    // MARK: - Safe-area helper

    /// The key window's top safe-area height. Reliable even inside ignoresSafeArea contexts.
    static var windowTopInset: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.keyWindow?.safeAreaInsets.top ?? 44
    }

    // MARK: - Appearance

    private var isRejected: Bool { status == .rejected }
    private var bannerColor: Color { isRejected ? .brandRed : .brandOrange }
    private var icon: String {
        isRejected ? "exclamationmark.shield.fill" : "shield.lefthalf.filled.badge.checkmark"
    }
    private var message: String {
        isRejected
            ? "ID verification failed — Tap to retry"
            : "Verify your SJSU ID to book rides"
    }
    private var buttonLabel: String { isRejected ? "Retry" : "Verify" }

    private var bannerContent: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(bannerColor)
            Text(message)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.textPrimary)
            Spacer()
            Button(buttonLabel) { action() }
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(bannerColor)
                .cornerRadius(10)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(bannerColor.opacity(0.1))
        .overlay(
            Rectangle()
                .fill(bannerColor.opacity(0.3))
                .frame(height: 1),
            alignment: .bottom
        )
    }
}
