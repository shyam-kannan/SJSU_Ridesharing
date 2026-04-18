import Foundation
import CoreLocation

// MARK: - API Configuration
enum APIConfig {
    /// Read API base URL from build settings (via Info.plist)
    /// Configured per-environment using .xcconfig files (Config.Dev/Staging/Prod.xcconfig)
    /// Falls back to environment variable or hardcoded default
    static var baseURL: String {
        // Priority 1: Read from Info.plist (set via xcconfig build settings)
        if let bundleURL = Bundle.main.infoDictionary?["API_BASE_URL"] as? String, !bundleURL.isEmpty {
            return bundleURL
        }
        
        // Priority 2: Read from environment variable (for Xcode Scheme overrides)
        if let override = ProcessInfo.processInfo.environment["LESSGO_API_BASE_URL"], !override.isEmpty {
            return override
        }

        // Priority 3: Safe fallback differs by build configuration.
        #if DEBUG
        #if targetEnvironment(simulator)
        return "http://127.0.0.1:3000/api"
        #else
        return "https://lessgo-zeta.vercel.app/api"
        #endif
        #else
        return "https://lessgo-zeta.vercel.app/api"
        #endif
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
