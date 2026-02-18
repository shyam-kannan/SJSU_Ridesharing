import SwiftUI

extension Color {
    // MARK: - Brand Colors
    static let brand     = Color(red: 0/255, green: 122/255, blue: 255/255)   // #007AFF
    static let brandGreen = Color(red: 52/255, green: 199/255, blue: 89/255)  // #34C759
    static let brandRed  = Color(red: 255/255, green: 59/255,  blue: 48/255)  // #FF3B30
    static let brandOrange = Color(red: 255/255, green: 149/255, blue: 0/255) // #FF9500

    // MARK: - Background
    static let appBackground   = Color(red: 0.95, green: 0.95, blue: 0.97)
    static let cardBackground  = Color.white
    static let sheetBackground = Color(red: 0.97, green: 0.97, blue: 0.99)

    // MARK: - Text
    static let textPrimary   = Color(red: 0.11, green: 0.11, blue: 0.12)
    static let textSecondary = Color(red: 0.24, green: 0.24, blue: 0.26)
    static let textTertiary  = Color(red: 0.56, green: 0.56, blue: 0.58)

    // MARK: - Gradients
    static var brandGradient: LinearGradient {
        LinearGradient(
            colors: [Color(red: 0/255, green: 122/255, blue: 255/255),
                     Color(red: 0/255, green: 80/255, blue: 200/255)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var greenGradient: LinearGradient {
        LinearGradient(
            colors: [Color(red: 52/255, green: 199/255, blue: 89/255),
                     Color(red: 40/255, green: 170/255, blue: 70/255)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var heroGradient: LinearGradient {
        LinearGradient(
            colors: [Color(red: 0/255, green: 122/255, blue: 255/255),
                     Color(red: 88/255, green: 86/255, blue: 214/255)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
