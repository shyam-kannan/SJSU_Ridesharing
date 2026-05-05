import Foundation
import CoreLocation

// MARK: - API Configuration
enum APIConfig {
    /// Read API base URL from build settings (via Info.plist key API_BASE_URL,
    /// set by Config.Dev.xcconfig / Config.Prod.xcconfig).
    /// Falls back to localhost if the plist key is missing or malformed.
    static var baseURL: String {
        // Priority 1: xcconfig → Info.plist (API_BASE_URL build setting).
        if let bundleURL = Bundle.main.infoDictionary?["API_BASE_URL"] as? String,
           let safe = sanitizeURL(bundleURL) {
            return safe
        }

        // Priority 2: Xcode scheme environment variable override.
        if let override = ProcessInfo.processInfo.environment["LESSGO_API_BASE_URL"],
           let safe = sanitizeURL(override) {
            return safe
        }

        // Priority 3: Local dev fallback.
        return "http://127.0.0.1:3000/api"
    }

    private static func sanitizeURL(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, URL(string: trimmed) != nil else { return nil }
        return trimmed
    }
}

// MARK: - Stripe Configuration
enum StripeConfig {
    static let publishableKey = "pk_test_YOUR_STRIPE_PUBLISHABLE_KEY"
}

// MARK: - App-Wide Constants
enum AppConstants {
    static let defaultSearchRadiusMeters = 8000
    static let maxSeats = 8
    static let minPasswordLength = 8

    // SJSU Campus coordinates
    static let sjsuCoordinate = CLLocationCoordinate2D(latitude: 37.3352, longitude: -121.8811)

    // Animation durations
    static let animationFast:   Double = 0.2
    static let animationNormal: Double = 0.35
    static let animationSlow:   Double = 0.5

    // UI Dimensions
    static let buttonHeight:    CGFloat = 56
    static let buttonRadius:    CGFloat = 28
    static let cardRadius:      CGFloat = 16
    static let inputRadius:     CGFloat = 14
    static let pagePadding:     CGFloat = 20
    static let cardPadding:     CGFloat = 16
    static let itemSpacing:     CGFloat = 12
}
