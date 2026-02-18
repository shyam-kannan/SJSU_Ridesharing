import Foundation
import CoreLocation

// MARK: - API Configuration
enum APIConfig {
    // For iOS Simulator → 127.0.0.1
    static let baseURL = "http://127.0.0.1:3000/api"

    // For physical device → replace with your machine's local IP:
    // static let baseURL = "http://192.168.1.X:3000/api"
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
