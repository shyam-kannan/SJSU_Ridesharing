import SwiftUI
import UIKit

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
        static let ink = Color(hex: "111827")
        static let mint = Color(hex: "14B8A6")
        static let lime = Color(hex: "84CC16")
        static let sand = Color(hex: "F7F5EF")
        static let mist = Color(hex: "EDF2F8")
        static let deepNavy = Color(hex: "071A2E")
        static let sky = Color(hex: "DCEEFF")
        static let emerald = Color(hex: "10B981")
        static let accentLime = lime
        static let onAccentLime = Color(hex: "111827")
        static let darkBrandSurface = Color(hex: "17191E")
        static let actionDarkSurface = Color(hex: "0F172A")
        static let tabBarSurface = Color(hex: "15171B")
        static let cautionOrange = Color(hex: "E67E22")
        static let runningBlue = Color(hex: "1A73E8")
        static let onDark = Color.white

        // Semantic Colors
        static let primary = sjsuBlue
        static let secondary = sjsuGold
        static let accent = sjsuTeal

        // Status Colors
        static let success = Color(hex: "16A34A")
        static let warning = sjsuGold
        static let error = Color(hex: "DC2626")
        static let info = sjsuBlue

        // Grayscale
        static let textPrimary = dynamicColor(light: "111827", dark: "F3F4F6")
        static let textSecondary = dynamicColor(light: "5B6472", dark: "CDD5E1")
        static let textTertiary = dynamicColor(light: "8D97A6", dark: "9AA7BA")

        // Backgrounds
        static let background = dynamicColor(light: "F7F5EF", dark: "0F141B")
        static let cardBackground = dynamicColor(light: "FFFFFF", dark: "171D26", lightAlpha: 0.96, darkAlpha: 0.96)
        static let surfaceBackground = dynamicColor(light: "EDF2F8", dark: "111827")
        static let fieldBackground = dynamicColor(light: "F8FAFC", dark: "1E2733")
        static let groupedBackground = dynamicColor(light: "F0F2F0", dark: "1B2430")
        static let selectedTabBackground = dynamicColor(light: "F4F7EE", dark: "E7F7D7")

        // Interactive
        static let buttonPrimary = sjsuBlue
        static let buttonSecondary = sjsuGold
        static let buttonDisabled = dynamicColor(light: "D1D5DB", dark: "475569")

        // Borders
        static let border = dynamicColor(light: "DDE3EC", dark: "2A3442")
        static let borderFocused = sjsuBlue
        static let borderError = error

        private static func dynamicColor(
            light: String,
            dark: String,
            lightAlpha: CGFloat = 1,
            darkAlpha: CGFloat = 1
        ) -> Color {
            Color(
                uiColor: UIColor { trait in
                    if trait.userInterfaceStyle == .dark {
                        return uiColor(from: dark, alpha: darkAlpha)
                    }
                    return uiColor(from: light, alpha: lightAlpha)
                }
            )
        }

        private static func uiColor(from hex: String, alpha: CGFloat = 1) -> UIColor {
            let sanitized = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
            var int: UInt64 = 0
            Scanner(string: sanitized).scanHexInt64(&int)

            let r, g, b: UInt64
            switch sanitized.count {
            case 3:
                r = (int >> 8) * 17
                g = (int >> 4 & 0xF) * 17
                b = (int & 0xF) * 17
            default:
                r = int >> 16
                g = int >> 8 & 0xFF
                b = int & 0xFF
            }

            return UIColor(
                red: CGFloat(r) / 255,
                green: CGFloat(g) / 255,
                blue: CGFloat(b) / 255,
                alpha: alpha
            )
        }
    }

    // MARK: - Typography

    enum Typography {
        // Headers
        static let largeTitle = Font.system(size: 34, weight: .bold, design: .rounded)
        static let title1 = Font.system(size: 28, weight: .bold, design: .rounded)
        static let title2 = Font.system(size: 22, weight: .semibold, design: .rounded)
        static let title3 = Font.system(size: 20, weight: .semibold, design: .rounded)

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
        static let button = Font.system(size: 17, weight: .semibold, design: .rounded)
        static let buttonSmall = Font.system(size: 15, weight: .semibold, design: .rounded)
        static let label = Font.system(size: 12, weight: .bold, design: .rounded)
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
        static let card = (color: Color.black.opacity(0.08), radius: CGFloat(22), x: CGFloat(0), y: CGFloat(10))
        static let button = (color: DesignSystem.Colors.sjsuBlue.opacity(0.22), radius: CGFloat(18), x: CGFloat(0), y: CGFloat(10))
        // New elevated shadows for premium depth
        static let elevated = (color: Color.black.opacity(0.16), radius: CGFloat(24), x: CGFloat(0), y: CGFloat(12))
        static let floating = (color: Color.black.opacity(0.22), radius: CGFloat(32), x: CGFloat(0), y: CGFloat(16))
        static let sheet = (color: Color.black.opacity(0.18), radius: CGFloat(28), x: CGFloat(0), y: CGFloat(-8))
    }

    // MARK: - Layout

    enum Layout {
        // Heights
        static let buttonHeight: CGFloat = 56
        static let buttonHeightLarge: CGFloat = 60        // Figma-quality 60pt buttons
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

        // Map-first layout
        static let bottomSheetPeek: CGFloat = 320        // Visible at bottom when collapsed
        static let bottomSheetCornerRadius: CGFloat = 28 // Top corners of bottom sheet
        static let searchBarFloatTop: CGFloat = 16       // Offset from safe area top
        static let fabSize: CGFloat = 56                 // Floating action button size
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

        // New premium animations
        static let staggerBase: Double = 0.06            // Delay per card in stagger sequence
        static let successExpand = SwiftUI.Animation.spring(response: 0.6, dampingFraction: 0.62)
        static let pinBounce = SwiftUI.Animation.spring(response: 0.4, dampingFraction: 0.5)
        static let sheetSnap = SwiftUI.Animation.spring(response: 0.38, dampingFraction: 0.84)
        static let heroEntrance = SwiftUI.Animation.spring(response: 0.7, dampingFraction: 0.78)
    }

    // MARK: - Glass

    enum Glass {
        static let fill: Material = .ultraThinMaterial
        static let borderOpacity: Double = 0.45
        static let overlayOpacity: Double = 0.15
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
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                DesignSystem.Colors.background,
                                DesignSystem.Colors.cardBackground,
                                DesignSystem.Colors.surfaceBackground.opacity(0.45)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card, style: .continuous)
                            .strokeBorder(DesignSystem.Colors.border.opacity(0.7), lineWidth: 1)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card, style: .continuous)
                            .strokeBorder(DesignSystem.Colors.border.opacity(0.45), lineWidth: 0.6)
                    )
            )
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

    /// Glassmorphism overlay — frosted glass look with white border
    func glassMorphism(cornerRadius: CGFloat = 20) -> some View {
        self
            .background(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.5), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    /// Elevated card with generous shadow depth
    func elevatedCard(cornerRadius: CGFloat = 20) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                DesignSystem.Colors.cardBackground,
                                DesignSystem.Colors.surfaceBackground.opacity(0.92)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .strokeBorder(DesignSystem.Colors.border.opacity(0.7), lineWidth: 1)
                    )
            )
            .shadow(
                color: DesignSystem.Shadow.elevated.color,
                radius: DesignSystem.Shadow.elevated.radius,
                x: DesignSystem.Shadow.elevated.x,
                y: DesignSystem.Shadow.elevated.y
            )
    }

    /// Staggered appear: slides up + fades in with per-index delay
    func staggeredAppear(index: Int, delay: Double = 0) -> some View {
        self.modifier(StaggeredAppearModifier(index: index, extraDelay: delay))
    }

    /// Bottom sheet drag handle capsule overlaid at top
    func bottomSheetHandle() -> some View {
        self.overlay(alignment: .top) {
            Capsule()
                .fill(Color.gray.opacity(0.28))
                .frame(width: 40, height: 5)
                .padding(.top, 10)
        }
    }
}

// MARK: - Staggered Appear Modifier

struct StaggeredAppearModifier: ViewModifier {
    let index: Int
    let extraDelay: Double
    @State private var appeared = false

    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 18)
            .onAppear {
                withAnimation(
                    .spring(response: 0.42, dampingFraction: 0.76)
                    .delay(Double(index) * DesignSystem.Animation.staggerBase + extraDelay)
                ) {
                    appeared = true
                }
            }
    }
}
