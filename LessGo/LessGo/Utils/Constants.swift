import Foundation
import CoreLocation

// MARK: - API Configuration
enum APIConfig {
    /// Read API base URL from build settings (via Info.plist)
    /// Configured per-environment using .xcconfig files.
    /// For hosted-only deployments, loopback/localhost values are ignored.
    static var baseURL: String {
        // Priority 1: Build config via Info.plist.
        if let bundleURL = Bundle.main.infoDictionary?["API_BASE_URL"] as? String,
           let safeBundleURL = sanitizeHostedURL(bundleURL) {
            return safeBundleURL
        }

        // Priority 2: Optional scheme override for hosted endpoints only.
        if let override = ProcessInfo.processInfo.environment["LESSGO_API_BASE_URL"],
           let safeOverride = sanitizeHostedURL(override) {
            return safeOverride
        }

        // Priority 3: Hosted fallback.
        return "https://lessgo-zeta.vercel.app/api"
    }

    private static func sanitizeHostedURL(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let url = URL(string: trimmed), let host = url.host?.lowercased() else {
            return nil
        }

        // Never route mobile app traffic to a local gateway in hosted deployments.
        if host == "localhost" || host == "127.0.0.1" || host == "::1" {
            return nil
        }
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
