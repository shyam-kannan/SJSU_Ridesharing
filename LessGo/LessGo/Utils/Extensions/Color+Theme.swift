import SwiftUI

extension Color {
    // MARK: - SJSU Brand Colors
    static let brand = DesignSystem.Colors.sjsuBlue        // SJSU Blue #0055A2
    static let brandGold = DesignSystem.Colors.sjsuGold    // SJSU Gold #E5A823
    static let brandTeal = DesignSystem.Colors.sjsuTeal    // SJSU Teal #008C95

    // Backwards compatibility aliases
    static let brandGreen = DesignSystem.Colors.success
    static let brandRed = DesignSystem.Colors.error
    static let brandOrange = Color(hex: "F59E0B")

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
                Color(hex: "0A5FB8"),
                Color(hex: "0E7ABF"),
                DesignSystem.Colors.sjsuTeal.opacity(0.95)
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
                DesignSystem.Colors.deepNavy,
                Color(hex: "083C78"),
                DesignSystem.Colors.sjsuBlue,
                DesignSystem.Colors.sjsuTeal
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var canvasGradient: LinearGradient {
        LinearGradient(
            colors: [
                DesignSystem.Colors.background,
                DesignSystem.Colors.surfaceBackground,
                DesignSystem.Colors.cardBackground
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var panelGradient: LinearGradient {
        LinearGradient(
            colors: [
                DesignSystem.Colors.cardBackground,
                DesignSystem.Colors.surfaceBackground.opacity(0.92)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var greenGradient: LinearGradient {
        LinearGradient(
            colors: [Color(hex: "16A34A"), Color(hex: "10B981")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: - Status Gradients
    static var successGradient: LinearGradient {
        LinearGradient(
            colors: [DesignSystem.Colors.emerald, Color.green.opacity(0.85)],
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
