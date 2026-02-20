import SwiftUI

/// LessGo Design System
/// Central source of truth for all design tokens including SJSU branding,
/// typography, spacing, corner radii, shadows, and animations.
enum DesignSystem {

    // MARK: - SJSU Brand Colors

    enum Colors {
        // Primary SJSU Colors
        static let sjsuBlue = Color(hex: "0055A2")      // Official SJSU Blue
        static let sjsuGold = Color(hex: "E5A823")      // Official SJSU Gold
        static let sjsuTeal = Color(hex: "008C95")      // SJSU Accent Teal

        // Semantic Colors
        static let primary = sjsuBlue
        static let secondary = sjsuGold
        static let accent = sjsuTeal

        // Status Colors
        static let success = Color.green
        static let warning = sjsuGold
        static let error = Color.red
        static let info = sjsuBlue

        // Grayscale
        static let textPrimary = Color(hex: "1A1A1A")
        static let textSecondary = Color(hex: "6B7280")
        static let textTertiary = Color(hex: "9CA3AF")

        // Backgrounds
        static let background = Color(hex: "F9FAFB")
        static let cardBackground = Color.white
        static let surfaceBackground = Color(hex: "F3F4F6")

        // Interactive
        static let buttonPrimary = sjsuBlue
        static let buttonSecondary = sjsuGold
        static let buttonDisabled = Color(hex: "D1D5DB")

        // Borders
        static let border = Color(hex: "E5E7EB")
        static let borderFocused = sjsuBlue
        static let borderError = Color.red
    }

    // MARK: - Typography

    enum Typography {
        // Headers
        static let largeTitle = Font.system(size: 32, weight: .bold)
        static let title1 = Font.system(size: 28, weight: .bold)
        static let title2 = Font.system(size: 22, weight: .semibold)
        static let title3 = Font.system(size: 20, weight: .semibold)

        // Body Text
        static let body = Font.system(size: 17, weight: .regular)
        static let bodyBold = Font.system(size: 17, weight: .semibold)
        static let callout = Font.system(size: 16, weight: .regular)
        static let calloutBold = Font.system(size: 16, weight: .semibold)

        // Supporting Text
        static let subheadline = Font.system(size: 15, weight: .regular)
        static let footnote = Font.system(size: 13, weight: .regular)
        static let caption = Font.system(size: 12, weight: .regular)
        static let captionBold = Font.system(size: 12, weight: .semibold)

        // Special
        static let button = Font.system(size: 17, weight: .semibold)
        static let buttonSmall = Font.system(size: 15, weight: .semibold)
        static let label = Font.system(size: 12, weight: .bold)
    }

    // MARK: - Spacing

    enum Spacing {
        static let xxxs: CGFloat = 2
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 20
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
        static let xxxl: CGFloat = 40

        // Common Screen Padding
        static let screenPadding: CGFloat = 20
        static let cardPadding: CGFloat = 16
        static let sectionSpacing: CGFloat = 24
        static let elementSpacing: CGFloat = 12
    }

    // MARK: - Corner Radius

    enum CornerRadius {
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
        static let xlarge: CGFloat = 20
        static let button: CGFloat = 16
        static let card: CGFloat = 16
        static let pill: CGFloat = 100
    }

    // MARK: - Shadow

    enum Shadow {
        static let small = (color: Color.black.opacity(0.05), radius: CGFloat(4), x: CGFloat(0), y: CGFloat(2))
        static let medium = (color: Color.black.opacity(0.1), radius: CGFloat(8), x: CGFloat(0), y: CGFloat(2))
        static let large = (color: Color.black.opacity(0.15), radius: CGFloat(12), x: CGFloat(0), y: CGFloat(4))
        static let card = (color: Color.black.opacity(0.08), radius: CGFloat(8), x: CGFloat(0), y: CGFloat(2))
        static let button = (color: Color.black.opacity(0.1), radius: CGFloat(8), x: CGFloat(0), y: CGFloat(2))
    }

    // MARK: - Layout

    enum Layout {
        // Heights
        static let buttonHeight: CGFloat = 56
        static let buttonHeightSmall: CGFloat = 44
        static let textFieldHeight: CGFloat = 52
        static let tabBarHeight: CGFloat = 60

        // Tap Targets (minimum for accessibility)
        static let minTapTarget: CGFloat = 44

        // Icon Sizes
        static let iconSmall: CGFloat = 16
        static let iconMedium: CGFloat = 20
        static let iconLarge: CGFloat = 24
        static let iconXLarge: CGFloat = 32

        // Empty State
        static let emptyStateIconSize: CGFloat = 80
    }

    // MARK: - Animation

    enum Animation {
        static let quick = SwiftUI.Animation.spring(response: 0.3, dampingFraction: 0.7)
        static let standard = SwiftUI.Animation.spring(response: 0.4, dampingFraction: 0.75)
        static let smooth = SwiftUI.Animation.spring(response: 0.5, dampingFraction: 0.8)
        static let buttonPress = SwiftUI.Animation.easeInOut(duration: 0.15)

        static let defaultDuration: Double = 0.3
        static let quickDuration: Double = 0.15
        static let slowDuration: Double = 0.5
    }

    // MARK: - Opacity

    enum Opacity {
        static let disabled: Double = 0.4
        static let secondary: Double = 0.6
        static let subtle: Double = 0.3
        static let overlay: Double = 0.5
    }
}

// MARK: - Hex Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - View Modifiers

extension View {
    /// Apply standard card styling with SJSU design system
    func cardStyle() -> some View {
        self
            .background(DesignSystem.Colors.cardBackground)
            .cornerRadius(DesignSystem.CornerRadius.card)
            .shadow(
                color: DesignSystem.Shadow.card.color,
                radius: DesignSystem.Shadow.card.radius,
                x: DesignSystem.Shadow.card.x,
                y: DesignSystem.Shadow.card.y
            )
    }

    /// Apply button press animation
    func buttonPressAnimation(isPressed: Bool) -> some View {
        self
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .animation(DesignSystem.Animation.buttonPress, value: isPressed)
    }
}
