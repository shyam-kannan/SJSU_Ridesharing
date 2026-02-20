import SwiftUI

extension Color {
    // MARK: - SJSU Brand Colors
    static let brand = DesignSystem.Colors.sjsuBlue        // SJSU Blue #0055A2
    static let brandGold = DesignSystem.Colors.sjsuGold    // SJSU Gold #E5A823
    static let brandTeal = DesignSystem.Colors.sjsuTeal    // SJSU Teal #008C95

    // Backwards compatibility aliases
    static let brandGreen = Color.green
    static let brandRed = Color.red
    static let brandOrange = Color.orange

    // MARK: - Background
    static let appBackground = DesignSystem.Colors.background
    static let cardBackground = DesignSystem.Colors.cardBackground
    static let sheetBackground = DesignSystem.Colors.surfaceBackground

    // MARK: - Text
    static let textPrimary = DesignSystem.Colors.textPrimary
    static let textSecondary = DesignSystem.Colors.textSecondary
    static let textTertiary = DesignSystem.Colors.textTertiary

    // MARK: - SJSU Gradients
    static var brandGradient: LinearGradient {
        LinearGradient(
            colors: [
                DesignSystem.Colors.sjsuBlue,
                DesignSystem.Colors.sjsuBlue.opacity(0.8)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var goldGradient: LinearGradient {
        LinearGradient(
            colors: [
                DesignSystem.Colors.sjsuGold,
                DesignSystem.Colors.sjsuGold.opacity(0.8)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var heroGradient: LinearGradient {
        LinearGradient(
            colors: [
                DesignSystem.Colors.sjsuBlue,
                DesignSystem.Colors.sjsuTeal
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var greenGradient: LinearGradient {
        LinearGradient(
            colors: [Color.green, Color.green.opacity(0.8)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: - Status Gradients
    static var successGradient: LinearGradient {
        LinearGradient(
            colors: [Color.green, Color.green.opacity(0.8)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var warningGradient: LinearGradient {
        LinearGradient(
            colors: [
                DesignSystem.Colors.sjsuGold,
                DesignSystem.Colors.sjsuGold.opacity(0.8)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
